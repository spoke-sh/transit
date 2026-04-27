# Harden Hosted Protocol Auth And Lease Fencing - Software Design Description

> Make hosted acknowledgement, auth, stream ownership, and proof APIs explicit enough for downstream systems that need finality, reorg handling, or auditability.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage hardens the hosted authority boundary. Token auth becomes enforced protocol behavior, stream ownership uses conditional remote state rather than blind lease overwrites, and finality/fork proof vocabulary is documented for blockchain-style downstream systems.

## Context & Boundaries

The server remains a wrapper over the shared engine. Auth and lease checks gate requests and publication; they do not change record, stream, branch, segment, manifest, or checkpoint semantics.

```text
client request -> auth check -> shared engine operation -> ack/error envelope
primary lease -> conditional object-store update -> manifest publication fence
stream lineage -> checkpoint/proof envelope -> downstream finality inspection
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core::server` | internal protocol | Framed request, response, and error envelopes | workspace |
| `transit-core::consensus` | internal Rust API | Stream lease acquisition, heartbeat, and handoff | workspace |
| `object_store` | crate | Remote lease and manifest authority | workspace |
| `INTEGRITY.md` | contract | Checkpoint and manifest-root proof vocabulary | repository |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Token auth first | Enforce `auth_mode = token`; keep mTLS as a documented non-claim until scoped | Delivers immediate hosted hardening without inventing transport TLS lifecycle. |
| Fencing fails closed | Reject writes/publication if current lease proof cannot be verified | Preserves durability honesty. |
| Blockchain support is a contract, not a runtime | Document block/fork/finality mapping over Transit lineage | Avoids overclaiming application consensus. |

## Architecture

Token auth should be part of the framed protocol handshake or request envelope, not an HTTP header convention. Remote auth failures should preserve request correlation and use a stable error code.

Object-store consensus should avoid blind overwrites. Where backend conditional operations are available, acquire, heartbeat, and handoff should compare generation/e-tag or equivalent state before write. If a backend cannot provide this, the provider should surface a weaker explicit capability rather than pretending to offer strong fencing.

Finality proof contracts should reuse `LineageCheckpoint`, manifest roots, stream positions, branch/merge metadata, and optional application block metadata.

## Components

| Component | Purpose | Behavior |
|-----------|---------|----------|
| Auth config/runtime | Enforce declared hosted token mode | Rejects unauthenticated requests before shared-engine mutation. |
| Remote auth error | Preserve client semantics | Returns request id, topology, code, and message. |
| Conditional lease provider | Harden stream ownership | Uses backend condition checks for acquire, heartbeat, and handoff. |
| Finality/fork proof vocabulary | Support durable external systems | Maps records, branches, checkpoints, and merge/selection artifacts to inspectable proof envelopes. |

## Interfaces

Candidate surfaces:

- Protocol request auth field or initial auth frame.
- New remote error code such as `unauthorized`.
- Consensus provider capability or conditional-write abstraction.
- Finality/fork proof structs in an integrity or proof module.

## Data Flow

```text
request with credential -> server auth check -> operation or unauthorized error
lease read -> conditional update -> handle version -> manifest publication fence
record append/branch/checkpoint -> proof envelope -> downstream finality inspection
```

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Missing or invalid token | Server auth check | Remote unauthorized error | Retry with valid credential |
| Lease generation mismatch | Conditional update failure | Reject acquire, heartbeat, handoff, or publication | Refresh lease and retry if still eligible |
| Backend lacks conditional writes | Provider capability check | Surface explicit weaker capability or configuration error | Choose a supported backend for strong fencing |
| Finality proof mismatch | Manifest/checkpoint verification | Reject proof | Rebuild proof from authoritative history |
