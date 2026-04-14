# Publish Upstream Consumer Client And Direct Cutover Proof - Software Design Description

> Define the reusable upstream client surface and the proof path downstream consumers will follow to cut directly off duplicate transit-server runtime and local hosted client semantics.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage defines the reusable upstream client boundary and the downstream
direct-cutover proof surface that lets consumers delete duplicate local runtime
and private hosted client semantics without guesswork or transitionary debt.

## Context & Boundaries

In scope: upstream client surface expectations and the cross-repo proof
contract for completing direct cutover off duplicate local ownership.

Out of scope: implementing downstream cutover or preserving consumer-specific
behavior that Transit does not intend to own.

```
┌────────────────────────────────────────────────────────────┐
│                         This Voyage                        │
│                                                            │
│  upstream client surface -> downstream direct-cutover      │
│  proof -> deletion of duplicate local ownership            │
└────────────────────────────────────────────────────────────┘
          ↑                                   ↑
      Transit crates                      downstream repos
```

## Dependencies

<!-- External systems, libraries, services this design relies on -->

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| Voyage `VGj3HXPMa` | sibling voyage | Supplies the authoritative hosted endpoint and acknowledgement contract this client surface must reflect. | current epic |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Client owner | Publish the reusable consumer client surface upstream in Transit | Gives downstream repos one place to import hosted semantics |
| Cutover posture | Downstream repos cut directly from duplicate local runtime/client ownership to the upstream client surface; no duplicate lineage survives | Prevents the duplicate-runtime problem from ossifying |
| Proof shape | Downstream cutover should cite upstream-authored proofs and contract docs | Keeps the cutover inspectable across repos |

## Architecture

The voyage defines two contract surfaces:

- `Upstream consumer client boundary`
  Purpose: specify the importable client/API layer downstream repos should use.
- `Direct cutover proof path`
  Purpose: specify how a downstream repo proves it can delete duplicate local
  runtime/client ownership without losing contract fidelity.

## Components

- `Client surface contract`
  Purpose: spell out which hosted operations belong in the reusable client
  layer.
- `Direct cutover proof contract`
  Purpose: define the evidence and checkpoints a downstream repo should cite
  when deleting duplicate local runtime/client ownership.

## Interfaces

- The upstream client surface should answer:
  - which hosted operations a downstream consumer may rely on
  - how endpoint and auth configuration are represented
  - which acknowledgement or error values pass through unchanged
- The direct cutover proof should answer:
  - what it means for a downstream consumer to stop owning a duplicate local runtime
  - what it means for a downstream consumer to stop owning a private hosted client contract
  - which upstream docs, tests, or proofs support that cutover

## Data Flow

1. Transit authors the canonical hosted endpoint and ack/error contract.
2. Transit defines the reusable client surface that reflects that contract.
3. A downstream consumer consumes the upstream surface instead of preserving a
   repo-local protocol lineage.
4. The downstream consumer cites the upstream direct-cutover proof when deleting the duplicate local
   runtime and hosted client behavior.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| The upstream client boundary is still too abstract for downstream cutover | A downstream consumer cannot map its callsites onto the authored surface | Treat the voyage as incomplete | Refine the client contract before consumer work begins |
| Direct cutover proof is missing or chat-only | Downstream repos lack stable evidence for deleting duplicate local ownership | Reject the migration as unsafe | Add explicit upstream proof artifacts and checklist language |
| Transit bakes consumer-specific behavior into the reusable client | Review finds consumer-specific surface area with no generic hosted rationale | Treat as overscoped | Move consumer-specific behavior back out of Transit |
