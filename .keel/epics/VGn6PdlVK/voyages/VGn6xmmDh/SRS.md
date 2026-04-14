# Object Store Runtime Bootstrap - SRS

## Summary

Epic: VGn6PdlVK
Goal: Resolve authored object-store providers from config and boot hosted Transit with honest runtime guarantees.

## Scope

### In Scope

- [SCOPE-01] Build a runtime object-store factory from authored Transit config.
- [SCOPE-02] Support hosted server bootstrap for tiered/object-store
  configurations.
- [SCOPE-03] Fail clearly when the authored provider configuration is
  incomplete or unsupported at runtime.

### Out of Scope

- [SCOPE-04] Consumer-specific schema or policy.
- [SCOPE-05] Rollout wiring in external deployment repos.
- [SCOPE-06] Overclaiming tiered durability before append and recovery
  semantics are proven.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Runtime bootstrap must resolve `filesystem`, `s3`, `gcs`, or `azure` storage configuration into a generic object-store client abstraction. | SCOPE-01 | FR-01 | tests |
| SRS-02 | `transit server run` must accept tiered/object-store config and bind the hosted server without forcing `durability = local`. | SCOPE-02 | FR-02 | tests |
| SRS-03 | Bootstrap failures must identify which config field or provider capability is missing instead of silently downgrading the runtime. | SCOPE-03 | FR-02 | tests |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Provider resolution must remain generic and reusable by runtime, proof, and future server surfaces. | SCOPE-01 | NFR-03 | review |
| SRS-NFR-02 | Bootstrap must stay explicit about any provider or durability path that is configured but not yet fully proven. | SCOPE-02, SCOPE-03 | NFR-01 | review |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
