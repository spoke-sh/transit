# Remote Authority Contract And Consumer Wiring - SRS

## Summary

Epic: VGh59soBt
Goal: Define how external control planes publish consumer-owned records to hosted Transit and consume acknowledgements, replay, and thin client surfaces without local embedded authority.

## Scope

### In Scope

- [SCOPE-01] Hosted server and client configuration surfaces required for external workload producers and readers.
- [SCOPE-02] Thin remote authority proofs showing append, replay, and acknowledgement handling through a running transit server.
- [SCOPE-03] Migration guidance that makes local embedded authority an anti-pattern for Hub-like consumers.

### Out of Scope

- [SCOPE-04] Object-store durability redesign and cache-recovery behavior covered by voyage `VGh5BgrVO`.
- [SCOPE-05] Consumer-specific domain semantics, entitlement policy, or business rules in Transit core.
- [SCOPE-06] Browser or application UX work in downstream consumers.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Define the hosted authority configuration contract external consumers use to target transit-server for consumer-owned writes and reads, including transport endpoint, authentication token, and durability labeling expectations. | SCOPE-01 | FR-01 | docs + proof |
| SRS-02 | Provide a remote authority proof that appends representative consumer-owned records to a running transit server and replays the acknowledged history back without opening local embedded Transit storage. | SCOPE-02 | FR-04 | test + proof |
| SRS-03 | Ensure acknowledgement, replay, and error envelopes remain visible to external consumers without client-side reinterpretation or hidden local fallback. | SCOPE-02 | FR-01 | test + proof |
| SRS-04 | Document the migration boundary for Hub-like consumers so local embedded storage is no longer treated as the authority for hosted consumer-owned workloads. | SCOPE-03 | FR-01 | docs |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The hosted authority path must remain a thin protocol and server contract, not a second storage engine embedded in the consumer. | SCOPE-01 | NFR-01 | code review |
| SRS-NFR-02 | Hosted authority proofs must state whether observed durability is `local` or `tiered`; they must not imply remote-tier safety before object-store publication exists. | SCOPE-02 | NFR-02 | proof |
| SRS-NFR-03 | Reference workloads may be informed by downstream domains such as Spoke auth, but consumer-specific policy and schema ownership must stay outside Transit core. | SCOPE-03 | NFR-03 | code review |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
