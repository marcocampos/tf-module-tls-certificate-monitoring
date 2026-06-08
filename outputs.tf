output "monitor_ids" {
  description = "Map of threshold (days, as string) => cert-check monitor GUID."
  value       = { for k, m in newrelic_synthetics_cert_check_monitor.this : k => m.id }
}

output "monitor_internal_ids" {
  description = "Map of threshold (days, as string) => cert-check monitor internal monitor_id."
  value       = { for k, m in newrelic_synthetics_cert_check_monitor.this : k => m.monitor_id }
}

output "policy_id" {
  description = "ID of the alert policy holding all threshold conditions."
  value       = newrelic_alert_policy.this.id
}

output "condition_ids" {
  description = "Map of threshold (days, as string) => NRQL alert condition ID."
  value       = { for k, c in newrelic_nrql_alert_condition.this : k => c.id }
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
  # enable_opsgenie derives from the sensitive opsgenie_api_key, which taints the
  # ternary; the channel ID itself is not sensitive, so unwrap it.
  value = nonsensitive(local.enable_opsgenie ? newrelic_notification_channel.opsgenie[0].id : null)
}
