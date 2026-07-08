# Atlas REST API

## POST /services/apexrest/atlas/v1/subscriptions

Idempotent billing-system sync. The billing system is the source of truth for
subscriptions; Salesforce keeps an operational copy keyed by the billing
system's own identifiers.

Authentication: OAuth 2.0 client-credentials flow through a connected app
bound to the dedicated integration user (`Atlas_Integration` permission set).

### Request

```json
{
  "subscriptions": [
    {
      "externalId": "SUB-88112",
      "accountBillingId": "BILL-4471",
      "status": "Active",
      "startDate": "2026-01-01",
      "endDate": "2026-12-31",
      "renewalDate": "2026-12-31",
      "autoRenew": true
    }
  ]
}
```

| Field                   | Required | Notes                                                                           |
| ----------------------- | -------- | ------------------------------------------------------------------------------- |
| `externalId`            | yes      | Billing system subscription key; upsert key on `Subscription__c.External_Id__c` |
| `accountBillingId`      | yes      | Must match an `Account.Billing_System_Id__c`                                    |
| `status`                | no       | `Draft` (default), `Active`, `Renewed`, `Churned`, `Expired`                    |
| `startDate` / `endDate` | yes      | ISO-8601 dates                                                                  |
| `renewalDate`           | no       | Defaults to `endDate` when the subscription is `Active`                         |
| `autoRenew`             | no       | Defaults to `false`                                                             |

### Responses

`200` — processed; per-item outcomes:

```json
{
  "results": [
    { "externalId": "SUB-88112", "outcome": "created", "message": null },
    { "externalId": "SUB-99999", "outcome": "error", "message": "Unknown accountBillingId: BILL-XXXX" }
  ]
}
```

`400` — unparseable body or empty `subscriptions` array.
`500` — unexpected fault; the body carries a `referenceId` that matches an
`App_Log__c` record for support correlation.

### Idempotency contract

Replaying any payload is safe: the upsert key guarantees one record per
`externalId`, and `outcome` distinguishes `created` from `updated`. The
billing system should retry `error` items after correcting them and may
retry the whole batch on network failures.

### Side effects

A subscription arriving as `Active` (or transitioning to it) opens a Renewal
opportunity through the same trigger pipeline the UI uses; `Churned` closes
the open renewal as lost. There is no API-only code path.
