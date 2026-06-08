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

variable "domain" {
  type = string
}

variable "email" {
  type = string
}

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key
  region     = var.newrelic_region
}

module "tls" {
  source = "../"

  account_id      = var.newrelic_account_id
  domain          = var.domain
  thresholds_days = [30, 15, 5]
  check_period    = "EVERY_5_MINUTES"

  email_recipients = [var.email]
}

output "monitor_ids" {
  value = module.tls.monitor_ids
}

output "policy_id" {
  value = module.tls.policy_id
}

output "workflow_id" {
  value = module.tls.workflow_id
}

output "email_channel_id" {
  value = module.tls.email_channel_id
}
