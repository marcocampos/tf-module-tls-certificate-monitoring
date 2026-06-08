# terraform-newrelic-tls-certificate-monitoring

A Terraform module that monitors a single domain's TLS certificate for upcoming
expiration using a **New Relic Synthetics cert-check monitor**, and alerts at a
single day-threshold (e.g. 30 days before expiry) through **email** and/or
**OpsGenie**.

Each module instance handles **one threshold**. To alert at multiple thresholds
(e.g. 30/15/5 days), instantiate the module once per threshold — see
[Multiple thresholds](#multiple-thresholds).

## How it works

The module creates:

1. A `newrelic_synthetics_cert_check_monitor` with `certificate_expiration` set
   to `threshold_days`. It reports `FAILED` once the certificate on `domain` is
   within that many days of expiring.
2. A `newrelic_alert_policy` + `newrelic_nrql_alert_condition` that opens an
   issue when the monitor produces a `FAILED` check.
3. A `newrelic_workflow` routing the issue to all enabled notification channels.

```
cert_check_monitor ─ nrql_alert_condition ─ alert_policy ─ workflow ─┬─ email
                                                                     └─ OpsGenie (webhook)
```

The alert condition uses `event_timer` aggregation and a
`filter(count(*), WHERE result='FAILED')` query so that (a) sparse cert checks
evaluate reliably and (b) the incident auto-closes when the certificate is
renewed.

### OpsGenie delivery

The current New Relic provider has no native OpsGenie destination type, so
OpsGenie alerts are delivered via a `WEBHOOK` destination that POSTs to the
OpsGenie Alert API (`https://api.opsgenie.com/v2/alerts`, or the EU endpoint
when `opsgenie_region = "EU"`). Authentication uses the `Authorization:
GenieKey <opsgenie_api_key>` header. Provide an **API integration key** from an
OpsGenie *API* integration.

## Usage

```hcl
module "tls" {
  source = "github.com/marcocampos/tf-module-tls-certificate-monitoring"

  account_id     = 1234567
  domain         = "www.example.com"
  threshold_days = 30

  email_recipients = ["sre@example.com"]

  # Optional: enable OpsGenie by supplying an API key
  opsgenie_api_key  = var.opsgenie_api_key
  opsgenie_region   = "US"
  opsgenie_priority = "P2"
}
```

At least one notification channel must be configured: set `email_recipients`,
`opsgenie_api_key`, or both.

### Multiple thresholds

Instantiate the module once per threshold with `for_each`:

```hcl
module "tls" {
  source   = "github.com/marcocampos/tf-module-tls-certificate-monitoring"
  for_each = toset(["30", "15", "5"])

  account_id       = 1234567
  domain           = "www.example.com"
  threshold_days   = tonumber(each.value)
  email_recipients = ["sre@example.com"]
}
```

See [`examples/complete`](./examples/complete) and
[`examples/email-only`](./examples/email-only).

## Requirements

- Terraform >= 1.5.0
- `newrelic/newrelic` provider >= 3.27.0
- A New Relic NerdGraph user API key configured on the provider

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `account_id` | New Relic account ID. | `number` | n/a (required) |
| `domain` | Bare host to check (no scheme/path), e.g. `www.example.com`. | `string` | n/a (required) |
| `threshold_days` | Days-before-expiry threshold for this instance. | `number` | `30` |
| `name` | Base name for created resources. | `string` | `tls-cert-<domain>-<threshold_days>d` |
| `enabled` | Enable monitor and workflow. | `bool` | `true` |
| `check_period` | Monitor run interval (e.g. `EVERY_6_HOURS`). | `string` | `EVERY_6_HOURS` |
| `locations_public` | Public synthetics locations. | `list(string)` | `["US_EAST_1"]` |
| `locations_private` | Private synthetics location GUIDs. | `list(string)` | `[]` |
| `runtime_type` | Synthetics runtime type. | `string` | `NODE_API` |
| `runtime_type_version` | Synthetics runtime version. | `string` | `22.20.0` |
| `tags` | Tags applied to the monitor (`key => value`). | `map(string)` | `{}` |
| `email_recipients` | Alert email addresses; enables email when non-empty. | `list(string)` | `[]` |
| `email_subject` | Email subject template. | `string` | see variables.tf |
| `opsgenie_api_key` | OpsGenie API key; enables OpsGenie when non-empty. | `string` (sensitive) | `""` |
| `opsgenie_region` | `US` or `EU`. | `string` | `US` |
| `opsgenie_priority` | OpsGenie priority `P1`–`P5`. | `string` | `P3` |
| `muting_rules_handling` | Workflow muted-issue handling. | `string` | `NOTIFY_ALL_ISSUES` |

## Outputs

| Name | Description |
|------|-------------|
| `monitor_id` | Cert-check monitor GUID. |
| `monitor_internal_id` | Internal `monitor_id`. |
| `policy_id` | Alert policy ID. |
| `condition_id` | NRQL condition ID. |
| `workflow_id` | Notification workflow ID. |
| `email_channel_id` | Email channel ID (or `null`). |
| `opsgenie_channel_id` | OpsGenie channel ID (or `null`). |

## Notes

- To monitor several domains, or one domain at several thresholds, instantiate
  this module multiple times.
- The OpsGenie webhook payload uses New Relic notification template variables
  (`{{ annotations.title.[0] }}`, `{{ issuePageUrl }}`, etc.); adjust
  `notifications.tf` if your account exposes different variable names.
