locals {
  name   = coalesce(var.name, "tls-cert-${var.domain}-${var.threshold_days}d")
  status = var.enabled ? "ENABLED" : "DISABLED"
}

# A single cert-check monitor: reports FAILED once the certificate on var.domain
# is within var.threshold_days of expiring.
resource "newrelic_synthetics_cert_check_monitor" "this" {
  account_id             = var.account_id
  name                   = local.name
  domain                 = var.domain
  certificate_expiration = tostring(var.threshold_days)
  period                 = var.check_period
  status                 = local.status
  runtime_type           = var.runtime_type
  runtime_type_version   = var.runtime_type_version

  # The provider rejects empty lists for these (min 1 item); send null to omit.
  locations_public  = length(var.locations_public) > 0 ? var.locations_public : null
  locations_private = length(var.locations_private) > 0 ? var.locations_private : null

  dynamic "tag" {
    for_each = var.tags
    content {
      key    = tag.key
      values = [tag.value]
    }
  }

  lifecycle {
    precondition {
      condition     = length(var.locations_public) > 0 || length(var.locations_private) > 0
      error_message = "At least one of locations_public or locations_private must be set."
    }
  }
}

resource "newrelic_alert_policy" "this" {
  account_id          = var.account_id
  name                = "${local.name} TLS expiry"
  incident_preference = "PER_CONDITION"
}

# Opens an issue when the monitor reports a FAILED cert check.
resource "newrelic_nrql_alert_condition" "this" {
  account_id = var.account_id
  policy_id  = newrelic_alert_policy.this.id
  type       = "static"
  name       = "TLS cert for ${var.domain} expires within ${var.threshold_days} days"
  enabled    = var.enabled

  # Cert checks are sparse (default every 6h), so use event_timer: a window is
  # evaluated a fixed time after a data point arrives rather than waiting for the
  # next event to flush it (which event_flow does, stalling on sparse signals).
  aggregation_method           = "event_timer"
  aggregation_timer            = 60
  aggregation_window           = 60
  fill_option                  = "none"
  violation_time_limit_seconds = 86400

  # filter(count(...)) emits 0 on a successful check (not a gap), so the signal
  # returns to 0 and the incident auto-closes once the certificate is renewed.
  nrql {
    query = "SELECT filter(count(*), WHERE result = 'FAILED') FROM SyntheticCheck WHERE monitorId = '${newrelic_synthetics_cert_check_monitor.this.monitor_id}'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
}
