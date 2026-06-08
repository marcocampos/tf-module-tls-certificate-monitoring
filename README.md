# terraform-newrelic-tls-certificate-monitoring

A Terraform module that monitors a single domain's TLS certificate for upcoming
expiration using **New Relic Synthetics cert-check monitors**, and raises alerts
through **email** and/or **OpsGenie** at one or more day-thresholds (e.g. 30/15/5
days before expiry).

## How it works

For each value in `thresholds_days` the module creates:

1. A `newrelic_synthetics_cert_check_monitor` with `certificate_expiration` set
   to that threshold. The monitor reports `FAILED` once the certificate on
   `domain` is within that many days of expiring.
2. A `newrelic_nrql_alert_condition` that opens an issue when that monitor
   produces a `FAILED` `SyntheticCheck` result.

All conditions live in **one** `newrelic_alert_policy` (per module instance /
domain). A single `newrelic_workflow` filters on that policy and routes every
issue to all enabled notification channels — so each threshold fires its own
alert at its own day count, and they all notify the same way (no severity
coupling).

```
threshold 30d ─ monitor ─ condition ┐
threshold 15d ─ monitor ─ condition ├─ alert policy ─ workflow ─┬─ email
threshold  5d ─ monitor ─ condition ┘                           └─ OpsGenie (webhook)
```

### OpsGenie delivery

The current New Relic provider has no native OpsGenie destination type, so
OpsGenie alerts are delivered via a `WEBHOOK` destination that POSTs to the
OpsGenie Alert API (`https://api.opsgenie.com/v2/alerts`, or the EU endpoint
when `opsgenie_region = "EU"`). Authentication uses the `Authorization:
GenieKey <opsgenie_api_key>` header. Provide an **API integration key** from an
OpsGenie *API* integration (not the legacy New Relic integration).

## Usage

```hcl
module "tls" {
  source = "github.com/<org>/tf-module-tls-certificate-monitoring"

  account_id      = 1234567
  domain          = "www.example.com"
  thresholds_days = [30, 15, 5]

  email_recipients = ["sre@example.com"]

  opsgenie_api_key  = var.opsgenie_api_key
  opsgenie_region   = "US"
  opsgenie_priority = "P2"
}
```

At least one notification channel must be configured: set `email_recipients`,
`opsgenie_api_key`, or both. See [`examples/complete`](./examples/complete) for a
full root configuration including the provider block.

## Requirements

- Terraform >= 1.5.0
- `newrelic/newrelic` provider >= 3.27.0
- A New Relic NerdGraph user API key configured on the provider

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `account_id` | New Relic account ID. | `number` | n/a (required) |
| `domain` | Bare host to check (no scheme/path), e.g. `www.example.com`. | `string` | n/a (required) |
| `name` | Base name for created resources. | `string` | `tls-cert-<domain>` |
| `thresholds_days` | Day-before-expiry thresholds; one monitor + condition each. | `list(number)` | `[30, 15, 5]` |
| `enabled` | Enable monitors and workflow. | `bool` | `true` |
| `check_period` | Monitor run interval (e.g. `EVERY_6_HOURS`). | `string` | `EVERY_6_HOURS` |
| `locations_public` | Public synthetics locations. | `list(string)` | `["US_EAST_1"]` |
| `locations_private` | Private synthetics location GUIDs. | `list(string)` | `[]` |
| `runtime_type` | Synthetics runtime type. | `string` | `NODE_API` |
| `runtime_type_version` | Synthetics runtime version. | `string` | `22.20.0` |
| `tags` | Tags applied to each monitor (`key => value`). | `map(string)` | `{}` |
| `email_recipients` | Alert email addresses; enables email when non-empty. | `list(string)` | `[]` |
| `email_subject` | Email subject template. | `string` | see variables.tf |
| `opsgenie_api_key` | OpsGenie API key; enables OpsGenie when non-empty. | `string` (sensitive) | `""` |
| `opsgenie_region` | `US` or `EU`. | `string` | `US` |
| `opsgenie_priority` | OpsGenie priority `P1`–`P5`. | `string` | `P3` |
| `muting_rules_handling` | Workflow muted-issue handling. | `string` | `NOTIFY_ALL_ISSUES` |

## Outputs

| Name | Description |
|------|-------------|
| `monitor_ids` | threshold => cert-check monitor GUID. |
| `monitor_internal_ids` | threshold => internal `monitor_id`. |
| `policy_id` | Alert policy ID. |
| `condition_ids` | threshold => NRQL condition ID. |
| `workflow_id` | Notification workflow ID. |
| `email_channel_id` | Email channel ID (or `null`). |
| `opsgenie_channel_id` | OpsGenie channel ID (or `null`). |

## Notes

- To monitor several domains, instantiate this module once per domain.
- The alert NRQL matches failures by `monitorId`. The OpsGenie webhook payload
  uses New Relic notification template variables (`{{ annotations.title.[0] }}`,
  `{{ issuePageUrl }}`, etc.); adjust `notifications.tf` if your account exposes
  different variable names.
