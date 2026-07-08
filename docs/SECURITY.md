# Security Architecture

## 1. Sharing model (OWD)

| Object                                            | Internal OWD         | Rationale                                                                                              |
| ------------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------ |
| Account / Contact / Opportunity / Contract / Case | Private              | Book-of-business isolation between CSM teams; role hierarchy grants management visibility              |
| `Subscription__c`                                 | Private              | Commercial terms follow account visibility; lookup (not MD) to Account requires its own OWD            |
| `Subscription_Item__c`                            | Controlled by Parent | Master-Detail to Subscription                                                                          |
| `Health_Score_Snapshot__c`                        | Controlled by Parent | Master-Detail to Account: visibility follows the customer exactly; cascade delete keeps purges trivial |
| `Survey_Response__c`                              | Controlled by Parent | Master-Detail to Account: raw feedback is visible only to whoever can see the customer                 |
| `App_Log__c`                                      | Private              | Operational data; admin/integration eyes only                                                          |

## 2. Role hierarchy (reference design)

```
CS Executive
├── CS Regional Director (AMER / EMEA / APAC)
│   └── CS Team Manager
│       └── Customer Success Manager
├── Support Director
│   └── Support Manager
│       └── Support Engineer (Tier 1 / Tier 2)
└── Revenue Operations
```

Roles grant _vertical_ visibility. Horizontal exceptions use sharing rules, not role hacks.

## 3. Sharing rules

- `Subscription__c`: criteria-based rule shares **Active** subscriptions read-only with the
  public group `Atlas CS Leadership` (versioned in this repo) so portfolio reviews don't require
  ownership transfers.
- Account team-based sharing (AccountTeamMember) is the mechanism for cross-functional pods
  (CSM + Support + AE on one customer) — org configuration, documented here rather than
  versioned, because team membership is data, not metadata.
- Manual sharing remains available for one-off exceptions; audited quarterly.

## 4. Permission sets and groups (versioned in repo)

| Artifact            | Type                 | Grants                                                                                                                                    |
| ------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `Atlas_CS_Base`     | Permission set       | Read on the Atlas schema, run LWC controllers (Apex class access)                                                                         |
| `Atlas_CSM`         | Permission set       | Base + create/edit Subscription, Survey, Opportunity work                                                                                 |
| `Atlas_CS_Manager`  | Permission set group | `Atlas_CS_Base` + `Atlas_CSM` (managers additionally receive report/dashboard folder access as org config)                                |
| `Atlas_Integration` | Permission set       | Exactly the objects/fields the billing sync and telemetry jobs touch, plus the REST resource class. Assigned to the integration user only |

Profiles are login/UI shells; **no CRUD/FLS is granted via profiles.**

## 5. Apex enforcement

- Read: selectors use `WITH USER_MODE` (sharing + CRUD + FLS, catchable exceptions).
- Write: `UnitOfWork` defaults to `AccessLevel.USER_MODE`.
- System-mode exceptions are enumerated in [ADR-0005](adr/ADR-0005-user-mode-by-default.md) —
  three paths, each justified.
- Inbound REST applies `Security.stripInaccessible(AccessType.UPSERTABLE, ...)` to deserialized
  payloads before DML (defense in depth on top of the integration user's minimal permission set).
- No hardcoded IDs: record types via `getRecordTypeInfosByDeveloperName()`, queues/groups by
  DeveloperName. PMD rules in CI flag violations.

## 6. Approval process (org configuration, by design)

Renewal opportunities with a discount ≥ 20% require CS Director approval. Approval processes
bind to specific users/roles per environment, so the definition is an org-config runbook item,
not repo metadata (architecture review finding R8):

- Entry: Opportunity record type = Renewal AND `Discount_Percent__c >= 0.20`
- Step 1: submitter's manager; Step 2 (≥ 35%): CS Regional Director
- Field update on final approval: `Approval_Status__c = Approved`; rejection returns to draft.

## 7. Integration security

- Outbound: Named Credential + External Credential; secrets never in code, metadata or logs.
- Inbound: dedicated integration user, `Atlas_Integration` permission set, IP-restricted
  connected app with client-credentials flow; the Apex REST class is the only class it can run.

## 8. Audit posture

- Field history tracking on `Subscription__c.Status__c` and Account risk fields.
- `App_Log__c` retains integration/system errors with reference IDs for correlation.
- Setup Audit Trail + permission set assignments reviewed quarterly (runbook).
