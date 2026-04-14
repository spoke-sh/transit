# Replay-Driven Projection Consumer API - SRS

## Summary

Epic: VGnPIhJl2
Goal: Publish a generic transit-client projection consumer surface that derives replaceable views from authoritative replay without creating a projection-only server truth path.

## Scope

### In Scope

- [SCOPE-01] Generic projection-consumer request, reducer, and outcome types published from `transit-client`.
- [SCOPE-02] Hosted client logic that replays authoritative projection streams and derives a current view without reopening embedded authority.
- [SCOPE-03] Proof or test coverage demonstrating a downstream-style reference projection read through the published client surface.

### Out of Scope

- [SCOPE-04] Consumer-specific auth, account, or session schemas encoded inside Transit crates.
- [SCOPE-05] A projection-only server-owned truth table or mutable hosted read store.
- [SCOPE-06] Downstream repo cutover implementation beyond validating the upstream client capability.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | `transit-client` publishes a generic projection-consumer API that lets downstream Rust code reduce authoritative hosted replay into a current projection view. | SCOPE-01, SCOPE-02 | FR-01 | test |
| SRS-02 | The projection-consumer API preserves the hosted acknowledgement boundary while surfacing projection revision/output metadata a downstream wrapper can reuse. | SCOPE-01, SCOPE-02 | FR-01 | test |
| SRS-03 | A proof or example flow demonstrates that a hosted client can derive an expected reference projection view from authoritative replay through the new API. | SCOPE-03 | FR-02 | test + proof |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Reducer logic and projection payload meaning remain consumer-owned; Transit only publishes generic replay/consumer mechanics. | SCOPE-01, SCOPE-03 | NFR-01 | code review |
| SRS-NFR-02 | Projection reads remain replay-driven and rebuildable from authoritative history instead of depending on a projection-only server truth path. | SCOPE-02, SCOPE-03 | NFR-02 | test + code review |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
