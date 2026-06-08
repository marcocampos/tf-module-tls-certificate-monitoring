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
  default   = ""
}

# Each module instance handles ONE threshold. To alert at 30/15/5 days, use
# for_each over the thresholds — one monitor + policy + workflow per threshold.
module "example_com_tls" {
  source   = "../../"
  for_each = toset(["30", "15", "5"])

  account_id     = var.newrelic_account_id
  domain         = "www.example.com"
  threshold_days = tonumber(each.value)

  locations_public = ["US_EAST_1", "EU_WEST_1"]
  check_period     = "EVERY_6_HOURS"

  email_recipients = ["sre@example.com", "oncall@example.com"]

  opsgenie_api_key  = var.opsgenie_api_key
  opsgenie_region   = "US"
  opsgenie_priority = "P2"

  tags = {
    team = "platform"
    env  = "production"
  }
}

output "monitor_ids" {
  value = { for k, m in module.example_com_tls : k => m.monitor_id }
}

output "policy_ids" {
  value = { for k, m in module.example_com_tls : k => m.policy_id }
}
