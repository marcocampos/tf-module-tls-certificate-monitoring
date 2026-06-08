terraform {
  required_version = ">= 1.5.0"

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = ">= 3.27.0"
    }
  }
}

variable "newrelic_account_id" {
  type = number
}

variable "newrelic_api_key" {
  type      = string
  sensitive = true
}

variable "newrelic_region" {
  type    = string
  default = "US" # "US" or "EU"
}

variable "domains" {
  description = "List of domains (bare hosts) to monitor."
  type        = list(string)
}

variable "email" {
  type = string
}

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key
  region     = var.newrelic_region
}

# One module block per threshold; each iterates over the list of domains.
# For N domains this creates 3 * N cert-check monitors (30/15/5 days each).
module "tls_30" {
  source   = "../"
  for_each = toset(var.domains)

  account_id       = var.newrelic_account_id
  domain           = each.value
  threshold_days   = 30
  check_period     = "EVERY_30_MINUTES"
  email_recipients = [var.email]
}

module "tls_15" {
  source   = "../"
  for_each = toset(var.domains)

  account_id       = var.newrelic_account_id
  domain           = each.value
  threshold_days   = 15
  check_period     = "EVERY_30_MINUTES"
  email_recipients = [var.email]
}

module "tls_5" {
  source   = "../"
  for_each = toset(var.domains)

  account_id       = var.newrelic_account_id
  domain           = each.value
  threshold_days   = 5
  check_period     = "EVERY_30_MINUTES"
  email_recipients = [var.email]
}

output "monitor_ids" {
  description = "Monitor GUIDs grouped by threshold, then by domain."
  value = {
    "30d" = { for k, m in module.tls_30 : k => m.monitor_id }
    "15d" = { for k, m in module.tls_15 : k => m.monitor_id }
    "5d"  = { for k, m in module.tls_5 : k => m.monitor_id }
  }
}
