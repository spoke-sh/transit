# Deliver Remote-Tier Replication Handoff Foundations - Software Design Description

> Implement the first clustered handoff path by reusing shared-engine publication and restore semantics, adding explicit follower catch-up and replicated acknowledgement boundaries without consensus or multi-primary behavior.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage turns the replication planning slice into the first executable delivery track. It keeps the single-primary model from `VF5GTdm4X`, reuses remote-tier publication as the clustered handoff boundary, and stages three bounded implementation concerns: surfacing the published frontier, bootstrapping read-only followers from that frontier, and exposing an explicit `replicated` acknowledgement mode. The output is still below consensus and multi-primary behavior.

## Context & Boundaries

In scope: shared-engine publication metadata, read-only follower restore/catch-up from published history, explicit replicated acknowledgement semantics, and proof/inspection surfaces that keep those guarantees legible.

Out of scope: consensus, quorum writes, failover, writable followers, direct record push replication, or any alternate replicated storage layer.

```
┌────────────────────────────────────────────────────────────────┐
│         Remote-Tier Replication Handoff Foundations           │
│                                                                │
│ primary append -> publish frontier -> remote tier -> follower  │
│        ack modes  -> proof surface    -> restore/catch-up      │
└────────────────────────────────────────────────────────────────┘
           ↑                                          ↑
   shared-engine manifests                    read-only replicas
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `VF5GTdm4X` | planning voyage | Supplies the selected clustered model, commitment boundaries, and preserved invariants | board artifact |
| `VDeYUdLSW` / `VDeb794qi` | completed mission/voyage | Established tiered publication and cold-restore semantics that follower catch-up must reuse | board artifact |
| `VDfEs25yS` / `VDfEx13Wu` | completed mission/epic | Established explicit remote acknowledgement surfaces that the replicated mode must extend | board artifact |
| `ARCHITECTURE.md` | repo document | Preserves one-engine, immutable history, and explicit durability modes | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Replication handoff unit | Published rolled segment plus manifest update | Reuses the object-store-native history unit already proven by the engine |
| Follower bootstrap path | Followers restore and catch up from remote-tier history in read-only mode | Keeps clustered replicas on the shared-engine restore path instead of inventing a second replica log |
| Replicated acknowledgement trigger | `replicated` waits for publication of the handoff unit, not follower hydration | Makes the commitment explicit without smuggling in failover or quorum claims |
| Proof boundary | Upgrade inspection/proof surfaces alongside runtime work | Keeps operator meaning explicit and testable as the cluster slice lands |
| Exclusions | No elections, lease transfer, quorum acknowledgement, or writable followers | Preserves the bounded first slice defined by the planning voyage |

## Architecture

The voyage has three tightly coupled layers:

- `published frontier surface`
  Exposes the latest immutable segment and manifest state that define the clustered handoff boundary.
- `read-only follower path`
  Restores and advances follower state from published history without granting write ownership.
- `replicated guarantee surface`
  Extends append/inspection results so operators can see when work is only local versus published for clustered handoff versus durable for tiered restore.

## Components

- `frontier descriptor`
  Shared-engine metadata that names the published segment range, manifest root, and positions eligible for clustered handoff.
- `follower restore bootstrap`
  Read-only node path that initializes from published history and advances by consuming newer published frontier descriptors.
- `acknowledgement adapter`
  Append and remote surfaces that map shared-engine publication completion into explicit `replicated` acknowledgement results.
- `proof and inspection path`
  Human-facing and test-facing surfaces that report frontier state, follower posture, and commitment level without implying consensus behavior.

## Interfaces

This voyage is expected to touch:

- shared-engine publication and restore descriptors
- server/client acknowledgement results for append workflows
- proof commands such as `just screen` or adjacent mission proof helpers
- any operator inspection path needed to show follower/read-only posture and published frontier state

## Data Flow

1. The primary accepts an append and durably commits it on the local writable head.
2. The engine rolls the relevant immutable segment and publishes that segment plus its manifest update into the remote tier.
3. A frontier descriptor captures the published range and manifest state that define the clustered handoff boundary.
4. `replicated` acknowledgement waits for that published frontier to exist and reports it explicitly without claiming follower hydration.
5. Followers bootstrap or catch up by restoring from the published frontier through the shared-engine restore path and remain read-only.
6. Proof and inspection surfaces expose whether a record is only `local`, has reached `replicated`, or has satisfied the `tiered` restore contract.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Published frontier is ambiguous or hidden | Append/inspection surfaces cannot name the published segment and manifest state | Block replicated-ack work until one handoff descriptor exists | Re-anchor on shared-engine publication metadata |
| Follower catch-up invents a second replica log | Design or implementation adds follower-only persistence or record fan-out assumptions | Reject as architecture drift | Rework around restore-from-published-history semantics |
| `replicated` acknowledgement overclaims durability | Proof/output implies follower hydration, failover readiness, or quorum semantics | Treat as incorrect guarantee language | Rewrite result surfaces and proof notes until non-claims are explicit |
| Proof path hides commitment boundaries | Human verification cannot distinguish local, replicated, and tiered states | Treat the slice as incomplete | Extend proof output and tests before closing the voyage |
