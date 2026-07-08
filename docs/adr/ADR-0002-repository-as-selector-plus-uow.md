# ADR-0002: The Repository pattern is realized as Selector + Unit of Work

Status: Accepted

## Context

The specification requires both a "Repository layer" and a "Selector layer". In classic DDD,
Repository abstracts persistence behind a collection-like interface. In Apex, persistence is
already abstracted by the platform: SOQL is the query interface, DML the write interface, and
neither can be swapped for another store.

## Decision

Do not build a generic `Repository` class hierarchy. The pattern's intent — a single,
mockable, security-consistent gateway to persistence — is delivered by:

- **Selectors** (read side): every SOQL statement in the codebase lives in a selector; callers
  never inline queries. Field lists, sharing and FLS policy are centralized per object.
- **UnitOfWork** (write side): every DML statement goes through `UnitOfWork.commitWork()`,
  which orders operations by dependency, deduplicates dirty registrations and applies a single
  access-level policy.

## Rationale

A `SubscriptionRepository` delegating to `SubscriptionSelector` and `UnitOfWork` adds a class
per object whose methods are one-line pass-throughs. An architecture review would delete it.
This is also exactly how Salesforce's Apex Enterprise Patterns decompose Repository.

## Consequences

- (+) One obvious place per object for queries; one write pipeline to audit for security.
- (−) Purists looking for a class literally named `*Repository` won't find one; this ADR is the
  answer.
