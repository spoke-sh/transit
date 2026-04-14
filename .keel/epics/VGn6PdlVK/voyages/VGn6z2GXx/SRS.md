# Hosted Tiered Durability Proof - SRS

## Summary

Epic: VGn6PdlVK
Goal: Make hosted server acknowledgements, probes, and recovery proofs match the real remote-authority runtime behavior.

## Scope

### In Scope

- [SCOPE-01] Ensure hosted runtime surfaces only claim durability levels the
  runtime actually satisfies.
- [SCOPE-02] Make storage probe output honest for hosted providers and tiered
  config.
- [SCOPE-03] Prove warm-cache recovery from authoritative remote storage in the
  hosted runtime path.

### Out of Scope

- [SCOPE-04] Consumer-specific application semantics.
- [SCOPE-05] Deployment-repo rollout.
- [SCOPE-06] New transport/auth semantics unrelated to durability truthfulness.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Hosted append/recovery paths must not label responses `tiered` unless the runtime has actually reached the authoritative remote tier required by that claim. | SCOPE-01 | FR-03 | tests |
| SRS-02 | `transit storage probe` must report explicit guarantee and non-claim language for hosted providers instead of pretending local-only semantics still apply. | SCOPE-02 | FR-03 | tests |
| SRS-03 | Hosted proof coverage must demonstrate restart and warm-cache recovery from authoritative remote storage after local cache loss. | SCOPE-03 | FR-03 | tests |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Guarantee labels and proof text must remain aligned so operators and downstream repos can rely on one literal contract. | SCOPE-01, SCOPE-02, SCOPE-03 | NFR-01 | review |
| SRS-NFR-02 | Recovery proof paths must preserve the replaceable-cache architecture rather than entrenching local filesystem state as hidden authority. | SCOPE-03 | NFR-02 | tests |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
