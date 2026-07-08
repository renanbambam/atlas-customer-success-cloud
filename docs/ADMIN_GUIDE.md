# Administrator Guide

What an org admin owns after deployment. Everything here is configuration by design —
none of it requires a deployment.

## 1. Post-deployment checklist

1. **Assign permission sets**
   - CS users: `Atlas_CS_Base` + `Atlas_CSM` (or the `Atlas_CS_Manager` permission set group for managers).
   - Integration user: `Atlas_Integration` only.
2. **Schedule the nightly jobs** (Execute Anonymous, once per org):
   ```apex
   System.schedule('Atlas Health Scoring', '0 0 2 * * ?', new HealthScoreScheduler());
   System.schedule('Atlas Telemetry Ingestion', '0 0 1 * * ?', new TelemetryIngestionScheduler());
   ```
   Telemetry runs before scoring so the adoption dimension sees fresh usage.
3. **Configure the telemetry credential**: Setup → Named Credentials → External Credential
   `Telemetry Auth` → add the principal's secret; grant the integration user access to the
   principal via permission set mapping.
4. **Activate the Customer 360 page**: Setup → Lightning App Builder → `Atlas Customer 360` →
   Activation → assign as org default for Account, or per the Atlas app.
5. **Quick action for the screen flow**: add an Account action launching the `Log NPS Response`
   flow and place it on the page layout.
6. **Populate leadership**: add the CS Directors to the public group `Atlas CS Leadership`
   (drives the Account and Subscription sharing rules).
7. **Approval process** (org-specific, see SECURITY.md §6): build the renewal discount
   approval with your real role names.

## 2. Tuning without deployment

| Lever                     | Where                                     | Effect                                 |
| ------------------------- | ----------------------------------------- | -------------------------------------- |
| Dimension weights, on/off | Custom Metadata → Health Dimension        | Next nightly run uses new weights      |
| Callout retries / timeout | Custom Metadata → Atlas Setting → Default | Telemetry client behavior              |
| Snapshot retention        | Custom Metadata → Atlas Setting → Default | Purge window for trend history         |
| NPS window                | Custom Metadata → Atlas Setting → Default | Which responses count toward the score |
| Churn playbook            | Flow → Churn Risk Alert Handler           | Task subject, due date, extra steps    |
| Case routing              | Setup → Case Assignment Rules             | Queue targets and criteria             |
| Renewal reminder cadence  | Flow → Weekly NPS Coverage                | Entry filters, task fields, schedule   |

## 3. Data expectations

- `Account.Billing_System_Id__c` must be populated (by the billing sync or data load) for
  telemetry ingestion to match accounts.
- `Account.CSM__c` drives the Weekly NPS Coverage flow and is the natural task owner in
  playbook extensions.
- Subscriptions arrive from billing; manual creation is possible (CSM permission set) but the
  billing system remains source of truth — expect manual records to be overwritten if their
  `External_Id__c` collides.

## 4. Monitoring

- **App Logs tab**: ERROR entries mean an integration gave up after retries or an unexpected
  fault occurred; `Reference_Id__c` correlates with billing-system support tickets.
- Setup → Scheduled Jobs / Apex Jobs: both nightly jobs should show green daily; the scoring
  batch chains a purge batch you'll also see there.
- Setup → Platform Events: `Churn_Risk_Alert__e` subscribers (the flow) surface here if they
  start failing.

## 5. Sandbox refreshes

After a refresh: re-enter the external credential secret (secrets don't copy), re-run the two
`System.schedule` calls, and re-point the billing system's endpoint at the sandbox My Domain.
