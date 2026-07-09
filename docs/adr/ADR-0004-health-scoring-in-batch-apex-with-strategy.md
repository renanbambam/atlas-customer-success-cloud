# ADR-0004: Health scoring runs in Batch Apex with metadata-driven Strategy dimensions

Status: Accepted

## Context

The health score is a weighted composite of adoption, support, engagement and financial signals
computed nightly for every account with an active subscription, with per-dimension auditability
and business-tunable weights.

## Decision

- `HealthScoreBatch` (Schedulable-driven, scope 200) → `HealthScoreService.calculate(accountIds)`.
- Each dimension implements `IHealthDimension.score(HealthScoreContext)`; implementations are
  discovered from `Health_Dimension__mdt` (calculator class name, weight, active flag) via
  `Type.forName` — Strategy + Factory, metadata-driven.
- The service bulk-loads one `HealthScoreContext` per account (aggregate SOQL for cases and
  surveys, subscription rollups, account telemetry fields) **before** invoking any dimension;
  dimensions are pure functions and cannot query.
- Results: update Account current-state fields, insert one `Health_Score_Snapshot__c` per run,
  publish `Churn_Risk_Alert__e` when risk escalates to High.

## Alternatives rejected

- **Scheduled Flow**: no aggregate queries, no unit tests for the math, weaker control over
  chunking as the data set grows.
- **Rollup fields / formula**: the score spans four objects and time windows; not expressible.
- **Einstein/CRM Analytics**: valid future layer, but the deterministic operational score must
  not depend on an add-on license.
- **Synchronous recalculation in triggers**: adds user-facing save time and shares the
  transaction's governor budget; the survey trigger is therefore restricted to a cheap partial
  update (the `NPS__c` field only), and full recalculation stays async.

## Consequences

- (+) New dimension = one class + one metadata record; re-weighting = metadata edit, no deploy.
- (+) Score math is unit-testable in isolation with a hand-built context.
- (−) Scores are as fresh as the schedule; an Invocable action exposes on-demand recalculation
  for a single account where CSMs need it now.
