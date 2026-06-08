locals {
  enable_email    = length(var.email_recipients) > 0
  enable_opsgenie = var.opsgenie_api_key != ""

  opsgenie_url = {
    US = "https://api.opsgenie.com/v2/alerts"
    EU = "https://api.eu.opsgenie.com/v2/alerts"
  }[upper(var.opsgenie_region)]

  # Payload posted to the OpsGenie Alert API. The {{ ... }} tokens are New Relic
  # notification template variables, resolved per-issue at send time.
  opsgenie_payload = jsonencode({
    message     = "{{ annotations.title.[0] }}"
    alias       = "newrelic-tls-${var.domain}-{{ issueId }}"
    description = "{{ annotations.description.[0] }}\n\nDomain: ${var.domain}\nIssue: {{ issuePageUrl }}"
    priority    = upper(var.opsgenie_priority)
    tags        = ["newrelic", "tls-certificate-expiry", var.domain]
    details = {
      domain       = var.domain
      issuePageUrl = "{{ issuePageUrl }}"
      state        = "{{ state }}"
    }
  })
}

# --- Guard: require at least one notification channel -----------------------

# Fails the plan unless email_recipients and/or opsgenie_api_key is provided.
# Implemented as a resource precondition (not a variable validation) so the
# module still passes `terraform validate` with its empty defaults.
resource "terraform_data" "require_notification_channel" {
  lifecycle {
    precondition {
      condition     = local.enable_email || local.enable_opsgenie
      error_message = "Configure at least one notification channel: pass a non-empty email_recipients list and/or an opsgenie_api_key."
    }
  }
}

# --- Email destination + channel --------------------------------------------

resource "newrelic_notification_destination" "email" {
  count = local.enable_email ? 1 : 0

  account_id = var.account_id
  name       = "${local.name} email"
  type       = "EMAIL"

  property {
    key   = "email"
    value = join(",", var.email_recipients)
  }
}

resource "newrelic_notification_channel" "email" {
  count = local.enable_email ? 1 : 0

  account_id     = var.account_id
  name           = "${local.name} email"
  type           = "EMAIL"
  product        = "IINT"
  destination_id = newrelic_notification_destination.email[0].id

  property {
    key   = "subject"
    value = var.email_subject
  }
}

# --- OpsGenie destination + channel (via webhook to the OpsGenie Alert API) ---

resource "newrelic_notification_destination" "opsgenie" {
  count = local.enable_opsgenie ? 1 : 0

  account_id = var.account_id
  name       = "${local.name} opsgenie"
  type       = "WEBHOOK"

  property {
    key   = "url"
    value = local.opsgenie_url
  }

  # Authorization: GenieKey <api-key>
  auth_token {
    prefix = "GenieKey"
    token  = var.opsgenie_api_key
  }
}

resource "newrelic_notification_channel" "opsgenie" {
  count = local.enable_opsgenie ? 1 : 0

  account_id     = var.account_id
  name           = "${local.name} opsgenie"
  type           = "WEBHOOK"
  product        = "IINT"
  destination_id = newrelic_notification_destination.opsgenie[0].id

  property {
    key   = "payload"
    label = "Payload"
    value = local.opsgenie_payload
  }
}

# --- Workflow: route every condition in the policy to all enabled channels ---

resource "newrelic_workflow" "this" {
  account_id            = var.account_id
  name                  = "${local.name} TLS expiry"
  enabled               = var.enabled
  muting_rules_handling = var.muting_rules_handling

  issues_filter {
    name = "${local.name}-policy-filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.this.id]
    }
  }

  dynamic "destination" {
    for_each = local.enable_email ? [newrelic_notification_channel.email[0].id] : []
    content {
      channel_id = destination.value
    }
  }

  dynamic "destination" {
    for_each = local.enable_opsgenie ? [newrelic_notification_channel.opsgenie[0].id] : []
    content {
      channel_id = destination.value
    }
  }
}
