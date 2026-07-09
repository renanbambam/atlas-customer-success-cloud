# Contributing

Thanks for looking at Atlas. This repository follows a small set of architectural rules that the
CI pipeline and code review enforce together — the point of the rules is that the codebase reads
the same no matter who wrote the change.

## Before you open a PR

Run the same gates CI runs:

```bash
npm ci
npm run prettier:verify   # formatting (prettier-plugin-apex included)
npm run lint              # ESLint on the LWCs
npm run test:unit         # Jest
```

Apex changes are validated in a scratch org (`sf project deploy validate --test-level RunLocalTests`);
CI does this automatically when a Dev Hub secret is configured.

## The rules that matter

The full "how" is in the [Developer Guide](docs/DEVELOPER_GUIDE.md); the "why" is in
[ARCHITECTURE.md](docs/ARCHITECTURE.md) and the [ADRs](docs/adr). In short:

- **No SOQL outside a selector, no DML outside `UnitOfWork`.** System-mode paths carry the
  `SystemMode` suffix and must appear in [ADR-0005](docs/adr/ADR-0005-user-mode-by-default.md).
- **No logic in triggers.** One trigger per object, delegating to its handler.
- **Domain classes and health dimensions never query** — the service pre-loads their context.
- **No hardcoded IDs, stage names, or magic numbers.** Resolve by DeveloperName; put tunables in
  Custom Metadata.
- **A new architectural decision is a new ADR**, added in the same PR that introduces it.

## Commits and releases

Conventional Commits; releases are tag-driven (`v*`) and deploy check-only first. Keep PRs
focused — one concern per PR, with the tests that prove it.
