# ADR-0003: Renewals and expansions are Opportunity record types, not custom objects

Status: Accepted

## Context

The renewal/upsell pipeline could be modeled as a custom `Renewal__c` object or on the standard
`Opportunity` object.

## Decision

Use `Opportunity` with record types `New_Business`, `Renewal`, `Expansion`, sharing one
Business Process (standard stage set) in v1.

## Rationale

- Forecasting, pipeline reports, dashboards, territory management, collaborative forecasts and
  every AppExchange sales tool operate on Opportunity. A custom object forks all of it.
- Renewal revenue _is_ pipeline. Splitting it into a custom object forces every revenue report
  to union two objects forever.
- Record types give distinct page layouts, picklists and processes per motion at zero code cost.

## Alternatives rejected

- `Renewal__c` custom object: total loss of native pipeline tooling — not worth that cost for a
  motion that is, commercially, still pipeline.
- Salesforce CPQ renewal automation: correct at CPQ shops, but v1 does not assume CPQ is licensed.

## Consequences

- (+) One pipeline, native reporting, standard forecast categories.
- (−) Record-type-conditional logic must resolve IDs by DeveloperName at runtime (never
  hardcoded); enforced in code review and PMD.
