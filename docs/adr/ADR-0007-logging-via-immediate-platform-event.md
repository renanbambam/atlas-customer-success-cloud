# ADR-0007: Logging publishes an immediate platform event persisted by a subscriber trigger

Status: Accepted

## Context

Operational errors (failed callouts after retry exhaustion, REST faults, batch failures) must be
persisted for support and audits. Writing a log record with plain DML fails exactly when it
matters most: if the transaction rolls back, the log rolls back with it.

## Decision

`Logger` publishes `Log_Event__e` configured **Publish Immediately**; a subscriber trigger
persists `App_Log__c` in system mode. Publish-immediately events are delivered even if the
publishing transaction subsequently rolls back — which is the entire requirement.

## Alternatives rejected

- **Direct DML to `App_Log__c`**: lost on rollback; adds DML (and potential mixed-DML surprises)
  to exception paths.
- **Nebula Logger (open source)**: excellent, but a large dependency; this domain needs level,
  message, source, reference ID and stack trace. The seam is one class — swapping Nebula in
  later touches only `Logger`.
- **Custom setting + debug logs**: debug logs are developer tooling, not an audit trail.

## Consequences

- (+) Logs survive rollback; log writes never interfere with business transaction limits.
- (−) `EventBus.publish` limits still apply; `Logger` buffers per transaction and publishes once.
- (−) Async delivery means logs lag by seconds; acceptable for an error/audit trail.
