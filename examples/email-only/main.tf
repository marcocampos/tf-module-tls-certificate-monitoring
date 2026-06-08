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

# Monitor a single domain at one threshold with email alerting only (no OpsGenie).
# Omitting opsgenie_api_key disables the OpsGenie channel entirely.
module "example_com_tls" {
  source = "../../"

  account_id     = var.newrelic_account_id
  domain         = "www.example.com"
  threshold_days = 30

  email_recipients = ["sre@example.com"]

  tags = {
    team = "platform"
    env  = "production"
  }
}

output "monitor_id" {
  value = module.example_com_tls.monitor_id
}

output "email_channel_id" {
  value = module.example_com_tls.email_channel_id
}
