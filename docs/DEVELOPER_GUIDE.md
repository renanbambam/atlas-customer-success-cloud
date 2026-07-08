# Developer Guide

How to work on this codebase without breaking its architecture. Read
[ARCHITECTURE.md](ARCHITECTURE.md) first; this document is the "how", that one is the "why".

## 1. Layer rules (enforced in code review)

- **No SOQL outside `classes/selectors/`.** Add a method to the object's selector; suffix it
  `SystemMode` if and only if it belongs to a path listed in
  [ADR-0005](adr/ADR-0005-user-mode-by-default.md) — and if you're adding a new system-mode
  path, extend that ADR's table in the same PR.
- **No DML outside `UnitOfWork`** (the one exception: `LogEventTriggerHandler`, documented).
  Construct the UoW with the SObjectType order you need; user mode is the default constructor.
- **No logic in triggers.** One trigger per object, one line: `new XTriggerHandler().run();`.
- **Domain classes never query.** `SubscriptionDomain` and the health dimensions operate on
  what they're handed. If a rule needs more data, the service loads it and passes it in.
- **Controllers shape, services decide.** An `@AuraEnabled` method may validate inputs, call
  one service/selector, and map to a DTO. If you're writing an `if` about business state in a
  controller, it belongs in a service or domain class.

## 2. Adding a health dimension

1. Create a class implementing `IHealthDimension` — a pure function over `HealthScoreContext`.
   Return `null` when the account has no signal for your dimension (weights renormalize).
2. If it needs new inputs, extend `HealthScoreContext` and load them (bulk, aggregate SOQL) in
   `HealthScoreService.buildContexts`.
3. Add a `Health_Dimension__mdt` record: DeveloperName, calculator class name, weight, active.
4. Optionally add a snapshot column and a case in `applyToSnapshot` — without one, the
   dimension still contributes to the composite.
5. Unit-test the math in `HealthDimensionsTest` style: hand-built context, no DML.

## 3. Adding an integration

Follow the telemetry shape: DTO (provider vocabulary stops there) → client (Named Credential,
timeout from `Atlas_Setting__mdt`, returns a Result with `retryable`, never throws across the
boundary) → service (mapping + UoW writes) → batch or queueable chassis. Retry only what is
transient; log and stop on deterministic failures; `Logger.flush()` in a `finally`.

## 4. Conventions

| Thing                          | Convention                                                                                  | Example                                 |
| ------------------------------ | ------------------------------------------------------------------------------------------- | --------------------------------------- |
| Selector methods               | `select…` / `count…` / `sum…`, `SystemMode` suffix for ADR-0005 paths                       | `selectByChurnRiskPaged`                |
| Services                       | Verb-first public methods, orchestrate only                                                 | `syncRenewalOpportunities`              |
| Tests                          | One class per unit, name states the behavior                                                | `activationIsIdempotentOnRepeatedSaves` |
| Record types / queues / groups | Resolved by DeveloperName at runtime, never by Id                                           | `getRecordTypeInfosByDeveloperName()`   |
| Trigger bypass                 | `AtlasTriggerHandler.bypass('XTriggerHandler')` in migration scripts, always in try/finally | —                                       |
| LWC ↔ LWC on the same page     | Lightning Message Service (`HealthScoreRefresh__c`)                                         | health panel → subscription list        |

## 5. Local loop

```bash
npm install
npm run lint            # ESLint on LWCs
npm run test:unit       # Jest
npm run prettier:verify # formatting gate (CI runs the same)

sf org create scratch -f config/project-scratch-def.json -a atlas --set-default
sf project deploy start
sf org assign permset --name Atlas_CS_Base --name Atlas_CSM --name Atlas_Integration
sf apex run test --code-coverage --result-format human --wait 30
```

Assigning the permission sets is not optional: selectors run `WITH USER_MODE`, and a freshly
deployed field grants FLS to no one — including the admin running the tests. That's the
security model working, not a bug.

PMD rules live in `pmd/ruleset.xml`; CI fails on severity ≥ 3 via Salesforce Code Analyzer.
What PMD can't see (layer rules above) is on the reviewer.

## 6. Things you might be tempted to do — don't

- Add a repository class over a selector (see [ADR-0002](adr/ADR-0002-repository-as-selector-plus-uow.md)).
- Recalculate the full health score synchronously in a trigger (review finding R9 — partial
  updates only; the batch and the invocable own full recalcs).
- Query inside a dimension, a flow loop, or `TelemetryUsageDTO` mapping. Bulk first, always.
- Hardcode an Id, a stage name in multiple places, or a retry count. Constants and metadata exist.
- Name a framework class something generic. `TriggerHandler` and `TestDataFactory` collided
  with another codebase sharing a dev org and silently replaced its classes on deploy — that's
  why ours are `AtlasTriggerHandler` and `AtlasTestDataFactory`. App-prefix anything that
  isn't domain-specific.
