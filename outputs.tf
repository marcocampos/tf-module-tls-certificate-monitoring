output "monitor_id" {
  description = "GUID of the cert-check monitor."
  value       = newrelic_synthetics_cert_check_monitor.this.id
}

output "monitor_internal_id" {
  description = "Internal monitor_id of the cert-check monitor."
  value       = newrelic_synthetics_cert_check_monitor.this.monitor_id
}

output "policy_id" {
  description = "ID of the alert policy."
  value       = newrelic_alert_policy.this.id
}

output "condition_id" {
  description = "ID of the NRQL alert condition."
  value       = newrelic_nrql_alert_condition.this.id
}

output "workflow_id" {
  description = "ID of the notification workflow."
  value       = newrelic_workflow.this.id
}

output "email_channel_id" {
  description = "ID of the email notification channel, or null when email is disabled."
  value       = local.enable_email ? newrelic_notification_channel.email[0].id : null
}

output "opsgenie_channel_id" {
  description = "ID of the OpsGenie notification channel, or null when OpsGenie is disabled."
  value       = local.enable_opsgenie ? newrelic_notification_channel.opsgenie[0].id : null
}
