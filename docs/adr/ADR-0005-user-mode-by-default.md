# ADR-0005: User-mode data access by default; system mode is an explicit, listed exception

Status: Accepted

## Context

Apex runs in system mode unless told otherwise. Enterprise security review requires CRUD/FLS and
sharing to be enforced on user-driven paths, with any privileged path justified.

## Decision

- Selectors query `WITH USER_MODE` (preferred over `WITH SECURITY_ENFORCED`: it also enforces
  sharing and produces catchable, field-specific exceptions).
- `UnitOfWork` defaults to `AccessLevel.USER_MODE` DML.
- System-mode is allowed only where listed below, always via an explicit
  `UnitOfWork(AccessLevel.SYSTEM_MODE)` / `WITH SYSTEM_MODE` construction at the call site:

| Path                                                                               | Why system mode is required                                                                                                                                                                                                                                                                                                                |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Log_Event__e` subscriber persisting `App_Log__c`                                  | Runs as Automated Process user; log persistence must never depend on the failing user's permissions                                                                                                                                                                                                                                        |
| `HealthScoreBatch` writes                                                          | Runs in a system context on the whole portfolio; scores/snapshots must be complete regardless of which user scheduled the job. Read access is still constrained by the integration user's permission set in production scheduling                                                                                                          |
| REST inbound upsert field writes                                                   | Executes as the dedicated `Atlas_Integration` user whose permission set grants exactly the writable fields; `Security.stripInaccessible` is applied to the deserialized payload as defense in depth                                                                                                                                        |
| Telemetry ingestion writes (`TelemetryIngestionService`)                           | Async integration job updating Account usage fields across the whole portfolio; same integration-user rationale as the REST path                                                                                                                                                                                                           |
| Account NPS rollup read (`SurveyResponseSelector.aggregateNpsByAccountSystemMode`) | `Account.NPS__c` is a system-maintained aggregate; the rollup must include every response regardless of the running user's FLS or sharing on `Survey_Response__c`, exactly like a native Roll-Up Summary. Reached from both the nightly batch and the survey trigger — the `SystemMode` suffix makes the bypass explicit at each call site |

This table is the single source of truth for privileged paths. Prose elsewhere links here
instead of restating a count, so the documentation and the code cannot drift out of agreement.

## Consequences

- (+) A security auditor reads one table to find every privileged path.
- (−) Developers must consciously choose the access level when constructing a UnitOfWork; the
  default constructor is user mode, so the safe choice is the lazy one.
