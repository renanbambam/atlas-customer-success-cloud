# ADR-0006: Billing sync is an idempotent REST upsert keyed by External_Id__c

Status: Accepted

## Context

The billing system is the source of truth for subscriptions and must push create/update events
into Salesforce. Message delivery is at-least-once; duplicates and replays are guaranteed to
happen.

## Decision

Custom Apex REST resource `POST /services/apexrest/atlas/v1/subscriptions`:

- Payload carries the billing system's own subscription key → `Subscription__c.External_Id__c`
  (unique, external ID, indexed) and the account's billing key → `Account.Billing_System_Id__c`.
- The handler performs an upsert on `External_Id__c`; replaying the same payload N times yields
  one record and a 200 — idempotency by key, not by dedupe log.
- Error mapping: 400 malformed JSON / missing key, 404 unknown account key, 200 with per-item
  results for partial batches, 500 only for unexpected faults (logged via `Logger`).

## Alternatives rejected

- **Standard REST sObject API**: cannot enforce the account-key resolution, per-item error
  contract, or domain validation in one round trip; pushes orchestration onto the billing team.
- **Change Data Capture / middleware-owned sync**: assumes an integration platform owns the
  flow; the contract here is billing pushes to Salesforce. CDC solves the outbound direction,
  which v1 does not need.
- **Platform event inbound**: fire-and-forget with no synchronous per-record acknowledgment;
  the billing system requires a response contract.

## Consequences

- (+) Replay-safe, self-describing errors, one round trip per batch.
- (−) A custom endpoint to document and version (`/v1/` in the path from day one).
