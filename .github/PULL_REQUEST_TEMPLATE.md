<!-- Keep PRs focused: one concern, with the tests that prove it. -->

## What and why

<!-- What does this change do, and what problem does it solve? Link the issue if there is one. -->

## Type of change

- [ ] Feature
- [ ] Fix
- [ ] Refactor (no behavior change)
- [ ] Docs / ADR
- [ ] DevOps / tooling

## Checklist

- [ ] `prettier:verify`, `lint` and `test:unit` pass locally
- [ ] Apex changes covered by meaningful assertions (not assert-free coverage), incl. a bulk case
- [ ] No SOQL outside a selector; no DML outside `UnitOfWork`
- [ ] Any new system-mode path is added to [ADR-0005](../docs/adr/ADR-0005-user-mode-by-default.md)
- [ ] No hardcoded IDs, stage names, or magic numbers (metadata / constants instead)
- [ ] Docs updated (guide/ADR) if this changes a decision or a contract

## Notes for the reviewer

<!-- Anything worth calling out: trade-offs, follow-ups, areas you're unsure about. -->
