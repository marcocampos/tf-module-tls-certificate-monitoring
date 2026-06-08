terraform {
  required_version = ">= 1.5.0"

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = ">= 3.27.0"
    }
  }
}

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key # NerdGraph user key (NRAK-...)
  region     = "US"
}

variable "newrelic_account_id" {
  type = number
}

variable "newrelic_api_key" {
  type      = string
  sensitive = true
}

variable "opsgenie_api_key" {
  type      = string
  sensitive = true
}

# Escalating notifications for one domain:
#   - 30 and 15 days before expiry -> email only (early warning)
#   - 5 days before expiry        -> email AND an OpsGenie incident (urgent)
#
# Each threshold is its own module instance. The `opsgenie` flag decides whether
# that instance gets an OpsGenie key: the module enables OpsGenie only when
# opsgenie_api_key is non-empty, so passing "" keeps a threshold email-only.
locals {
  thresholds = {
    "30" = { opsgenie = false }
    "15" = { opsgenie = false }
    "5"  = { opsgenie = true }
  }
}

module "tls" {
  source   = "../../"
  for_each = local.thresholds

  account_id     = var.newrelic_account_id
  domain         = "www.example.com"
  threshold_days = tonumber(each.key)

  email_recipients = ["sre@example.com"]

  # Only the 5-day threshold pages OpsGenie; the others stay email-only.
  opsgenie_api_key  = each.value.opsgenie ? var.opsgenie_api_key : ""
  opsgenie_region   = "EU"
  opsgenie_priority = "P2"
}

output "monitor_ids" {
  value = { for k, m in module.tls : k => m.monitor_id }
}

output "opsgenie_channel_ids" {
  description = "Non-null only for thresholds wired to OpsGenie (the 5-day one)."
  value       = { for k, m in module.tls : k => m.opsgenie_channel_id }
}
