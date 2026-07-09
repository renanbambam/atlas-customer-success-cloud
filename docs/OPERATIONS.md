# Operations Guide

Runbook for the two scheduled pipelines, the inbound API and the log trail.

## 1. Job inventory

| Job                 | Class                                                                 | Suggested cron | Chain                                                                                      |
| ------------------- | --------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------ |
| Telemetry ingestion | `TelemetryIngestionScheduler` → `TelemetryIngestionBatch` (scope 100) | `0 0 1 * * ?`  | 5xx/timeout pages retry via `TelemetryRetryQueueable`, capped by `Max_Callout_Attempts__c` |
| Health scoring      | `HealthScoreScheduler` → `HealthScoreBatch` (scope 200)               | `0 0 2 * * ?`  | `finish()` chains `HealthSnapshotPurgeBatch` (scope 2000)                                  |

Order matters: telemetry lands before scoring so the adoption dimension reads today's usage.

## 2. Failure modes and responses

| Symptom                                                             | Meaning                                                | Response                                                                                                                               |
| ------------------------------------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| `App_Log__c` ERROR "Telemetry ingestion abandoned after attempt N"  | Provider was down past the retry budget for that page  | Nothing to fix in-org: those accounts score on yesterday's telemetry; verify provider status, optionally re-run the batch              |
| `App_Log__c` ERROR "Scoring chunk failed"                           | One 200-account chunk threw; the run continued         | Read the stack trace, fix, re-run the batch for the day — snapshots are per-day, a re-run overwrites nothing and adds the missing rows |
| `App_Log__c` ERROR from `AtlasSubscriptionRestApi` with referenceId | Unexpected fault answering the billing system          | Correlate referenceId with the billing team's request log; the payload is replayable by contract                                       |
| Churn tasks not appearing                                           | Flow `Churn Risk Alert Handler` failing or deactivated | Setup → Flows → check version/errors; events are durable but flow-retry semantics apply                                                |
| Apex Jobs shows the purge batch aborted                             | Retention query took too long or hit locks             | Re-run `Database.executeBatch(new HealthSnapshotPurgeBatch(), 2000);` off-hours                                                        |

## 3. Replays and manual runs

```apex
// Re-run scoring now (whole portfolio)
Database.executeBatch(new HealthScoreBatch(), HealthScoreBatch.BATCH_SCOPE);

// Re-run telemetry for everything
Database.executeBatch(new TelemetryIngestionBatch(), TelemetryIngestionScheduler.BATCH_SCOPE);

// Re-score one account immediately (also available to admins via the invocable)
new HealthScoreService().calculate(new Set<Id>{ '<accountId>' }, System.AccessLevel.SYSTEM_MODE);
```

Billing replays: POST the same payload again — the upsert key makes it safe (ADR-0006).

## 4. Data migration mode

Suppress Atlas automation during bulk loads, always in try/finally:

```apex
AtlasTriggerHandler.bypass('SubscriptionTriggerHandler');
AtlasTriggerHandler.bypass('SurveyResponseTriggerHandler');
try {
    // load
} finally {
    AtlasTriggerHandler.clearBypass('SubscriptionTriggerHandler');
    AtlasTriggerHandler.clearBypass('SurveyResponseTriggerHandler');
}
```

Then run the scoring batch once to rebuild current state.

## 5. Capacity notes

- `Health_Score_Snapshot__c` size is bounded by `Snapshot_Retention_Months__c` × daily scored
  accounts (one row per account per run). If retention has to stay long at a high account count,
  execute the Big Object exit in [ADR-0008](adr/ADR-0008-snapshot-retention.md) _before_ reports
  slow down.
- The telemetry callout sends up to 100 account keys per GET; if the provider adds a POST
  bulk endpoint, only `TelemetryClient` changes.
- OFFSET pagination in the dashboards is capped at 2,000 rows by the platform — the triage
  lists are worklists, not exports; full lists live in reports.
