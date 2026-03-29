# Enable Controlled Primary Transfer - Software Design Description

> Promote a caught-up follower into the writable primary role through explicit lease transfer and frontier checks while fencing the former primary and keeping failover guarantees below quorum and multi-primary behavior.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage is the next bounded execution slice after the replicated handoff foundations. It uses the published frontier and read-only follower catch-up path from the prior voyage as the promotion boundary, adds an explicit lease-backed transfer path to move writable ownership to an eligible follower, and then fences the former primary. The result is a controlled primary handoff flow with explicit failover language that still stays below quorum acknowledgement and multi-primary behavior.

## Context & Boundaries

In scope: promotion eligibility derived from published frontier plus ownership state, explicit lease transfer, former-primary fencing/demotion, and proof surfaces that show readiness and handoff posture.

Out of scope: majority elections, quorum acknowledgement, concurrent writable nodes, alternate replicated storage engines, and broad failover orchestration beyond the first controlled transfer path.

```
┌──────────────────────────────────────────────────────────────┐
│             Controlled Replicated Primary Handoff           │
│                                                              │
│ follower catch-up -> eligibility -> lease transfer -> fence  │
│      proof/readiness -> writable role -> stale primary off   │
└──────────────────────────────────────────────────────────────┘
          ↑                         ↑
 published frontier          ownership/lease state
```

## Dependencies

<!-- External systems, libraries, services this design relies on -->

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `VDssqtPXS` / `VDssrPWoX` | completed mission/epic | Established the lease-backed ownership model the transfer flow must reuse | board artifact |
| `VDd1J2IDM` / `VF7VP3H4s` | completed epic/voyage | Established published frontier, read-only follower catch-up, and explicit `replicated` acknowledgement boundaries | board artifact |
| `ARCHITECTURE.md` | repo document | Preserves one-engine, immutable history, and explicit durability semantics | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Promotion boundary | A follower is eligible only when it has caught up to the published frontier required by the current primary/ownership state | Reuses the first clustered handoff unit rather than inventing a second readiness model |
| Transfer mechanism | Writable ownership moves through an explicit lease-backed handoff instead of implicit failover | Keeps promotion auditable and aligned with existing ownership semantics |
| Former-primary posture | The old primary is fenced and demoted after transfer | Prevents stale acknowledged writes and makes split-brain protection explicit |
| Scope ceiling | The voyage does not add quorum acknowledgement, majority election, or multi-primary behavior | Preserves the bounded replication track defined by prior planning |

## Architecture

The voyage has four tightly-coupled layers:

- `promotion eligibility surface`
  Computes or exposes whether a follower is caught up enough to be promoted based on published frontier and ownership state.
- `lease-backed handoff path`
  Transfers writable-role ownership to an eligible follower through explicit command or orchestration logic.
- `former-primary fencing`
  Demotes the previous primary and prevents further acknowledged writes until ownership is explicitly regained.
- `proof and inspection surface`
  Shows readiness, transfer result, and bounded failover semantics to humans and tests.

## Components

- `eligibility descriptor`
  Shared state or inspection output that reports the follower frontier, owner posture, and whether transfer preconditions are satisfied.
- `handoff controller`
  Runtime path that checks eligibility and executes the lease transfer for the promoted follower.
- `fencing guard`
  Enforcement path that rejects or downgrades stale-primary writes after ownership has moved.
- `proof adapter`
  Operator-facing output and proof helpers that report the handoff state and make non-claims explicit.

## Interfaces

This voyage is expected to touch:

- inspection or status surfaces that expose promotion readiness
- ownership-transfer APIs or command paths that move the writable lease
- append/write paths that must respect former-primary fencing
- proof commands such as `just screen` or focused mission proofs that demonstrate the controlled handoff

## Data Flow

1. The current primary publishes the relevant frontier and followers catch up through the existing read-only replication path.
2. Promotion eligibility logic compares the follower frontier and current ownership posture against the transfer contract.
3. An explicit handoff path moves the writable lease to an eligible follower.
4. The newly promoted node becomes the writable primary for subsequent acknowledged writes.
5. The former primary is fenced or demoted so stale ownership cannot continue acknowledged writes.
6. Proof and inspection surfaces report readiness, handoff completion, and the bounded failover semantics that now apply.

## Error Handling

<!-- What can go wrong, how we detect it, how we recover -->

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Promotion readiness is ambiguous or based on node-local heuristics | Inspection or transfer paths cannot explain why a follower is promotable | Reject handoff as unsafe | Re-anchor eligibility on published frontier plus ownership state |
| Handoff proceeds to an ineligible follower | Transfer path succeeds while follower remains behind or ownership state is incompatible | Treat as a correctness bug | Tighten eligibility checks and proof coverage before mission closeout |
| Former primary can still produce acknowledged writes after transfer | Post-handoff proof surfaces or tests show stale-primary acceptance | Treat as a fencing failure | Harden ownership checks on the write path and re-prove the demotion contract |
| Operator output overclaims failover semantics | Docs or proof surfaces imply quorum acknowledgement, automatic election, or multi-primary behavior | Treat as contract drift | Rewrite output and docs until the bounded non-claims are explicit |
