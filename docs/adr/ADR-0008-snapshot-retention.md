# ADR-0008: Health snapshots use a purge-window retention policy, with a Big Object exit path

Status: Accepted

## Context

`Health_Score_Snapshot__c` gains one row per scored account per nightly run, so it only ever
grows. Without a retention policy it becomes an LDV problem that degrades reports, backups and
storage cost.

## Decision

- Retention window (months) lives in `Atlas_Setting__mdt` (`Snapshot_Retention_Months__c`).
- `HealthScoreBatch.finish()` chains a lightweight purge batch that deletes snapshots older than
  the window using a selective `CreatedDate` range filter.
- Reporting needs beyond the window are an analytics concern: the documented exit is streaming
  snapshots to a Big Object or external warehouse; the write seam is isolated in
  `HealthScoreService` so the destination can change without touching scoring.

## Consequences

- (+) Table size is bounded and configurable per environment without deployment.
- (−) Trend history is finite in-org; accepted, with the exit path documented before it hurts.
