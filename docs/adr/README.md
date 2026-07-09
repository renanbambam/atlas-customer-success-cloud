# Architecture Decision Records

Each ADR captures one significant decision: the context that forced a choice, the option taken,
and the trade-off accepted. They are immutable once accepted — a decision that changes gets a new
ADR that supersedes the old one, so the history of _why_ stays intact.

Format: [Michael Nygard's ADR template](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions).

| ADR                                                            | Decision                                                                          | Status   |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------- | -------- |
| [0001](ADR-0001-lean-enterprise-patterns-over-fflib.md)        | Lean in-house enterprise patterns instead of the fflib library                    | Accepted |
| [0002](ADR-0002-repository-as-selector-plus-uow.md)            | The Repository pattern is realized as Selector + Unit of Work                     | Accepted |
| [0003](ADR-0003-renewals-as-opportunity-record-types.md)       | Renewals and expansions are Opportunity record types, not custom objects          | Accepted |
| [0004](ADR-0004-health-scoring-in-batch-apex-with-strategy.md) | Health scoring runs in Batch Apex with metadata-driven Strategy dimensions        | Accepted |
| [0005](ADR-0005-user-mode-by-default.md)                       | User-mode data access by default; system mode is an explicit, listed exception    | Accepted |
| [0006](ADR-0006-idempotent-rest-upsert-for-billing-sync.md)    | Billing sync is an idempotent REST upsert keyed by `External_Id__c`               | Accepted |
| [0007](ADR-0007-logging-via-immediate-platform-event.md)       | Logging publishes an immediate platform event persisted by a subscriber trigger   | Accepted |
| [0008](ADR-0008-snapshot-retention.md)                         | Health snapshots use a purge-window retention policy, with a Big Object exit path | Accepted |
