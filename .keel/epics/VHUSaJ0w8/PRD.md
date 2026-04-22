# Implement Shared-Engine Segment Compression - Product Requirements

## Problem Statement

Transit already advertises segment compression in configuration, but rolled segments are still stored as raw bytes with no explicit codec metadata. We need to make immutable segment compression real in the shared engine without changing logical record semantics, making zstd the default codec for sealed segments while preserving replay, lineage, tiered storage, and hosted behavior.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Let operators and downstream applications use real shared-engine segment compression with `zstd` as the default sealed-segment codec and no change to logical record semantics. | Targeted tests and proof flows show rolled segments are stored compressed by default, replay/restore return original records unchanged, and operator surfaces expose explicit codec and size metadata. | Voyage `VHUSdlUHb` planned |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Transit Operator | Engineer running Transit with local and tiered history costs that should benefit from compression without changing replay semantics. | Real segment compression that reduces stored footprint while keeping durability and recovery behavior explicit. |
| Downstream Application Engineer | Engineer consuming Transit through embedded or hosted paths who needs stable logical record behavior. | Compression that is transparent to reads, tails, and client code rather than a new message-format contract. |
| Transit Maintainer | Engineer responsible for shared-engine storage semantics and integrity. | A compression design that fits immutable segments, manifests, retention, and integrity without creating server-only behavior. |

## Scope

### In Scope

- [SCOPE-01] A typed segment-compression contract with `zstd` as the default sealed-segment codec and an explicit `none` mode.
- [SCOPE-02] Segment descriptor and manifest metadata that surface the codec plus stored and uncompressed byte lengths.
- [SCOPE-03] Shared-engine roll-time compression for immutable segments while keeping the active head uncompressed.
- [SCOPE-04] Transparent replay, recovery, tiered publication, and hydration behavior for compressed segments.
- [SCOPE-05] Proof coverage and operator guidance that explain segment compression boundaries and preserved logical semantics.

### Out of Scope

- [SCOPE-06] Per-record payload compression or schema-aware message encoding.
- [SCOPE-07] Hosted request/response compression or transport-level negotiation.
- [SCOPE-08] Compression of the active writable head.
- [SCOPE-09] Multi-codec negotiation beyond the scoped `zstd` and `none` storage contract.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Add a typed segment-compression configuration surface that makes `zstd` the default codec for newly sealed segments while still allowing an explicit uncompressed `none` mode. | GOAL-01 | must | Transit already claims segment compression in config; the implementation needs a concrete and explicit storage contract. |
| FR-02 | Surface segment compression metadata in storage descriptors and manifests, including codec and both stored and uncompressed byte lengths. | GOAL-01 | must | Operators and downstream tooling need to inspect what was stored and how retention/accounting should interpret segment size. |
| FR-03 | Compress rolled immutable segments in the shared engine while keeping the active head uncompressed and append semantics unchanged. | GOAL-01 | must | Compression belongs at the immutable boundary where Transit already seals, verifies, and publishes segment objects. |
| FR-04 | Make replay, recovery, tiered publication, and hydration transparently verify and decompress compressed segments so consumers still observe the original logical records. | GOAL-01 | must | Compression should reduce storage footprint without turning into a new client-visible message contract. |
| FR-05 | Ensure size-sensitive surfaces such as retention and status/accounting use stored bytes explicitly while preserving original logical record counts and offsets. | GOAL-01 | must | Compression changes physical storage footprint, so Transit must stay explicit about which size is being measured. |
| FR-06 | Publish proof coverage and operator guidance that distinguish immutable segment compression from payload compression or hosted transport compression. | GOAL-01 | must | Without explicit guidance, operators will conflate storage compression with message or wire compression and misunderstand the feature boundary. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | `zstd` must be the default codec for newly sealed segments across shared-engine embedded and hosted usage; no server-only compression semantics are allowed. | GOAL-01 | must | This repository treats embedded and hosted mode as packaging choices over one storage engine. |
| NFR-02 | Checksums and content digests must continue to validate the concrete stored segment bytes, and manifest metadata must bind the codec needed to decode them. | GOAL-01 | must | Integrity should stay attached to the immutable stored artifact instead of inventing a second proof surface in this slice. |
| NFR-03 | Compression must not change logical record payloads, offsets, replay order, branch ancestry, merge ancestry, or hosted read/tail semantics. | GOAL-01 | must | Transit cannot trade storage footprint for hidden semantic drift. |
| NFR-04 | Operator-facing docs and proof output must use vocabulary that clearly says this feature is immutable segment compression, not payload compaction or wire compression. | GOAL-01 | must | Clear language prevents downstream design drift and incorrect expectations. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Compression contract | Targeted config and descriptor tests plus storage-surface review | Story-level evidence under voyage `VHUSdlUHb` |
| Shared-engine behavior | Targeted engine and server tests covering compressed roll, replay, and tiered restore | Story-level evidence under voyage `VHUSdlUHb` |
| Operator visibility | CLI proof coverage and docs review for compression metadata and boundary explanations | Story-level evidence under voyage `VHUSdlUHb` |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Compressing immutable segments at roll time is sufficient to capture the near-term storage benefit without needing transport compression in the same slice. | The epic could underdeliver for users whose primary pain is network bandwidth rather than storage footprint. | Keep hosted wire compression explicitly out of scope and revisit only after the storage slice lands. |
| Retention and storage-accounting behavior can remain explicit if Transit exposes both stored and uncompressed byte lengths on segment metadata. | Operators may otherwise misread retention-by-size or footprint reporting. | Bind both sizes into the metadata contract and docs. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should status/proof output surface compression ratio directly or rely on stored versus uncompressed byte fields? | Epic owner | Open |
| Do any existing proof flows assume rolled segment files remain plain JSONL on disk? | Epic owner | Open |
| How should mixed historical segments be handled when a stream has older uncompressed segments and newer compressed ones? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Newly sealed segments default to `zstd` compression unless configuration explicitly selects `none`.
- [ ] Segment descriptors expose codec plus stored and uncompressed byte lengths.
- [ ] Replay, recovery, tiered publication, and hydration return original logical records over compressed segments.
- [ ] Size-based behavior continues to operate on stored bytes explicitly rather than silently switching to logical size.
- [ ] Docs and proof coverage explain that this feature compresses immutable segments only and does not compress payloads or hosted transport envelopes.
<!-- END SUCCESS_CRITERIA -->
