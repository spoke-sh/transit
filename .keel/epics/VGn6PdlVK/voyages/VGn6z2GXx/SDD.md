# Hosted Tiered Durability Proof - Software Design Description

> Make hosted server acknowledgements, probes, and recovery proofs match the real remote-authority runtime behavior.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage aligns runtime truthfulness with the tiered architecture. The
server, probe, and proof surfaces must all describe the same guarantee:
object storage is authoritative, local state is warm cache plus working set,
and `tiered` cannot be a label-only configuration artifact.

## Context & Boundaries

- In scope: hosted ack semantics, storage probe truthfulness, recovery proofs.
- Out of scope: downstream adoption code and external rollout plumbing.

```
append/recovery -> guarantee decision -> ack/probe/proof surfaces
remote object store --------------------^
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| hosted runtime bootstrap | internal | Supplies provider-backed server context | voyage `VGn6xmmDh` |
| `transit-core::engine` | internal | Remote publication and replica recovery primitives | existing |
| `transit-cli` proofs | internal | Operator-visible verification output | existing |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Durability truth | `tiered` is only surfaced after remote authority participation reaches the configured claim. | Prevents config-only durability lies. |
| Probe posture | Probe output includes explicit non-claims for partially-proven or provider-limited paths. | Operators need honest rollout language. |
| Recovery proof | Use cache-loss recovery as the canonical evidence shape. | It demonstrates the actual authority boundary. |

## Architecture

The hosted runtime carries enough context to:
1. publish/consult authoritative remote state
2. decide what durability label is truthful
3. expose matching probe and proof output

## Components

- hosted append/recovery path
  Determines when remote publication is required for a truthful ack.
- storage probe
  Reports provider, durability, guarantee, and non-claim data.
- warm-cache recovery proof
  Demonstrates bootstrap after local cache removal.

## Interfaces

- `RemoteAcknowledgement.durability`
- `transit storage probe`
- hosted proof outputs under `transit proof ...`

These surfaces must agree on the meaning of `local`, `replicated`, `quorum`,
and `tiered`.

## Data Flow

Hosted write/restart -> remote publication or hydration -> guarantee decision
-> ack/probe/proof rendering.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Remote publication missing for tiered claim | Publication/frontier check fails | downgrade claim or fail request, never overclaim | operator fixes runtime/config |
| Probe cannot validate hosted provider | Probe runtime error | return explicit non-claim/error | supply valid provider config |
| Cache-loss restart cannot rehydrate | Recovery proof fails | surface failure as proof breakage | inspect object-store authority and manifest state |
