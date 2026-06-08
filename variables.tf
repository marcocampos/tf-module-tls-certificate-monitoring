variable "account_id" {
  description = "New Relic account ID in which all resources are created."
  type        = number
}

variable "domain" {
  description = "The domain (host) whose TLS certificate is monitored, e.g. \"www.example.com\". Do not include a scheme or path."
  type        = string

  validation {
    condition     = !can(regex("://|/", var.domain))
    error_message = "domain must be a bare host (e.g. \"www.example.com\"), not a URL with a scheme or path."
  }
}

variable "name" {
  description = "Base name used to label all created resources. Defaults to \"tls-cert-<domain>\"."
  type        = string
  default     = null
}

variable "threshold_days" {
  description = "Days-before-expiry threshold. Alerts when the certificate is within this many days of expiry. To alert at multiple thresholds (e.g. 30/15/5), instantiate this module once per threshold."
  type        = number
  default     = 30

  validation {
    condition     = var.threshold_days > 0 && floor(var.threshold_days) == var.threshold_days
    error_message = "threshold_days must be a positive whole number of days."
  }
}

variable "enabled" {
  description = "Whether the monitors and the notification workflow are enabled."
  type        = bool
  default     = true
}

variable "check_period" {
  description = "How often each cert-check monitor runs."
  type        = string
  default     = "EVERY_6_HOURS"

  validation {
    condition = contains([
      "EVERY_MINUTE", "EVERY_5_MINUTES", "EVERY_10_MINUTES", "EVERY_15_MINUTES",
      "EVERY_30_MINUTES", "EVERY_HOUR", "EVERY_6_HOURS", "EVERY_12_HOURS", "EVERY_DAY",
    ], var.check_period)
    error_message = "check_period must be one of the New Relic synthetics period values (e.g. EVERY_6_HOURS, EVERY_DAY)."
  }
}

variable "locations_public" {
  description = "Public New Relic synthetics location(s) the TLS check runs from. Accepts more than one (e.g. [\"EU_WEST_1\", \"US_EAST_1\"]). Leave empty only if locations_private is set."
  type        = list(string)
  default     = ["EU_WEST_1"]
}

variable "locations_private" {
  description = "Private synthetics location GUIDs to run the checks from. At least one of locations_public/locations_private must be non-empty."
  type        = list(string)
  default     = []
}

variable "runtime_type" {
  description = "Synthetics runtime type for the monitors."
  type        = string
  default     = "NODE_API"
}

variable "runtime_type_version" {
  description = "Synthetics runtime version for the monitors."
  type        = string
  default     = "22.20.0"
}

variable "tags" {
  description = "Tags applied to every cert-check monitor as key => value."
  type        = map(string)
  default     = {}
}

# --- Email notifications -----------------------------------------------------

variable "email_recipients" {
  description = "Email addresses that receive alerts. Email notifications are enabled when this list is non-empty."
  type        = list(string)
  default     = []
}

variable "email_subject" {
  description = "Subject line template for alert emails. Supports New Relic notification template variables."
  type        = string
  default     = "[New Relic] TLS certificate alert: {{ annotations.title.[0] }}"
}

# --- OpsGenie notifications --------------------------------------------------

variable "opsgenie_api_key" {
  description = "OpsGenie API integration key (GenieKey). OpsGenie notifications are enabled when this is non-empty. Delivered via a webhook destination to the OpsGenie Alert API."
  type        = string
  default     = ""
  sensitive   = true
}

variable "opsgenie_region" {
  description = "OpsGenie account region, used to select the API endpoint. One of \"US\" or \"EU\"."
  type        = string
  default     = "EU"

  validation {
    condition     = contains(["US", "EU"], upper(var.opsgenie_region))
    error_message = "opsgenie_region must be \"US\" or \"EU\"."
  }
}

variable "opsgenie_priority" {
  description = "OpsGenie alert priority (P1-P5) assigned to alerts raised by this module."
  type        = string
  default     = "P3"

  validation {
    condition     = contains(["P1", "P2", "P3", "P4", "P5"], upper(var.opsgenie_priority))
    error_message = "opsgenie_priority must be one of P1, P2, P3, P4, P5."
  }
}

variable "muting_rules_handling" {
  description = "How the workflow treats muted issues."
  type        = string
  default     = "NOTIFY_ALL_ISSUES"

  validation {
    condition = contains([
      "NOTIFY_ALL_ISSUES",
      "DONT_NOTIFY_FULLY_MUTED_ISSUES",
      "DONT_NOTIFY_FULLY_OR_PARTIALLY_MUTED_ISSUES",
    ], var.muting_rules_handling)
    error_message = "muting_rules_handling must be a valid New Relic workflow muting value."
  }
}
