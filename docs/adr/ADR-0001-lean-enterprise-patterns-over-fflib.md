# ADR-0001: Lean in-house enterprise patterns instead of the fflib library

Status: Accepted

## Context

The architecture mandates Selector, Unit of Work, Domain, Service and Trigger Handler patterns.
The reference implementation of these patterns is fflib (Apex Enterprise Patterns / Apex Common),
~100+ classes including mocks, bindings and a full DI container.

## Decision

Implement the patterns in-house, minimally:

- `AtlasTriggerHandler` — virtual base with event routing, bypass API, reentrancy guard
  (~1 class; app-prefixed because a bare "TriggerHandler" collides with sibling codebases in
  shared orgs)
- Selectors — one concrete class per object, `WITH USER_MODE` by default
- `UnitOfWork` — register-new/dirty/delete with insertion-order dependency resolution and
  configurable access level
- Services/Domain — plain classes, dependencies injected via `@TestVisible` seams where mocking
  is genuinely needed (callout clients)

## Rationale

- The domain has four services. A DI container and generic domain bindings serve codebases with
  dozens of domains; here they are surface area without consumers.
- fflib is a third-party dependency to track, upgrade and teach. The concepts transfer; the
  library weight does not pay for itself at this scope.
- If the application grows to the point where fflib's mocking/binding machinery earns its keep,
  the class responsibilities map 1:1 and migration is mechanical.

## Consequences

- (+) The framework is small enough to read in full; there is no third-party layer to learn.
- (−) No `fflib_ApexMocks`; tests use real DML plus `HttpCalloutMock`/`Test.getEventBus()`.
  Accepted: integration-style Apex tests are also what verifies FLS/sharing behavior.
