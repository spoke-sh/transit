# Deliver Per-Stream Retention Configuration And Visibility - Software Design Description

> Let operators configure per-stream retention with no default policy, enforce age/size-based retention in the shared engine, and surface retention policy plus retained start offset in list and status outputs.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage adds explicit per-stream retention policy to the shared engine, threads that policy through stream creation and inspection surfaces, and exposes the retained frontier so operators understand when replay is bounded. The design keeps Transit’s current default semantics by making retention opt-in and enforcing it through whole-segment lifecycle management rather than compaction.

## Context & Boundaries

- In scope:
  - retention metadata for streams
  - create-time CLI/protocol surface for age- and size-based retention
  - shared-engine trimming of oldest rolled segments
  - list and status fields for configured retention and retained frontier
  - proof and docs explaining bounded replay
- Out of scope:
  - Kafka-style compaction and tombstones
  - global default retention windows
  - in-place rewrite of active or retained records
  - selective privacy erasure semantics above coarse-grained retention

```
┌────────────────────────────────────────────────────────────┐
│                    This Voyage                            │
│                                                            │
│  CLI / Protocol  ->  Shared Engine Policy  ->  Status UX   │
│  create flags        retention trimming       list/status   │
│                                                            │
└────────────────────────────────────────────────────────────┘
              ↑                                ↑
        Stream authors                   Operators / proofs
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-core` storage state and manifest model | Internal | Stores retention metadata, evaluates eligible rolled segments, and computes retained-frontier status. | Current workspace crate API |
| `transit-cli` command surface | Internal | Accepts retention flags and renders retention/frontier status. | Current workspace crate API |
| Hosted server protocol surfaces | Internal | Carries stream status and create-time retention options for downstream clients. | Current workspace crate API |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Default retention posture | `none` | Preserves existing Transit replay semantics unless a stream is explicitly opted into bounded history. |
| Retention granularity | Whole rolled segments only | Keeps enforcement deterministic and append-only without introducing record-level compaction semantics. |
| Active segment behavior | Never partially trimmed | Avoids rewriting hot append state and preserves the current append path contract. |
| Frontier visibility | Expose configured retention plus `retained_start_offset` or equivalent earliest-available field | Once replay is bounded, operators need explicit visibility into where retained history begins. |

## Architecture

The design threads one policy through three layers:

- Stream creation layer:
  - accepts optional retention flags
  - stores policy alongside stream metadata
- Shared engine lifecycle layer:
  - evaluates retention eligibility against rolled segments only
  - trims oldest eligible segments under age and/or size limits
  - recomputes earliest retained offset after enforcement
- Operator visibility layer:
  - includes retention policy in `streams list`
  - includes retained frontier in stream status
  - documents bounded replay and cursor fallout

## Components

- Retention policy model:
  - purpose: represent `none`, `max_age_days`, and `max_bytes`
  - interface: stream metadata and create surfaces
  - behavior: absent policy means no trimming
- Retention evaluator:
  - purpose: determine which oldest rolled segments are eligible to drop
  - interface: shared engine storage lifecycle
  - behavior: applies age and size limits without touching the active segment
- Frontier reporter:
  - purpose: compute earliest retained replay position
  - interface: status/list surfaces
  - behavior: surfaces retained-frontier state explicitly so bounded replay is visible
- Proof/docs surface:
  - purpose: explain semantics and prove expected behavior
  - interface: CLI proof path and public docs
  - behavior: distinguishes retention from compaction and describes retained-frontier consequences

## Interfaces

- Stream creation:
  - add optional `--retention-max-age-days <days>`
  - add optional `--retention-max-bytes <bytes>`
- Streams list:
  - add `retention_age`
  - add `retention_bytes`
- Stream status:
  - add `retained_start_offset` or equivalent earliest-retained field
  - include configured retention policy so the frontier is interpretable
- Internal engine/state:
  - persist retention policy with stream metadata
  - expose retained-frontier status alongside `next_offset`, active-head, and manifest data

## Data Flow

- Operator creates a stream with no retention flags:
  - stream metadata persists `retention = none`
  - list/status surfaces report no retention and unbounded replay semantics remain
- Operator creates a stream with age and/or size retention:
  - stream metadata persists the configured policy
  - append/maintenance lifecycle evaluates oldest rolled segments against the policy
  - eligible oldest rolled segments are removed
  - retained frontier advances to the earliest remaining offset
  - list/status surfaces report configured retention and new retained frontier
- Operator inspects the stream:
  - `streams list` shows retention policy
  - status surface shows earliest retained offset so replay bounds are explicit

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Invalid retention input such as zero/negative age or bytes | CLI/parser validation or config validation | Reject stream creation/update request with explicit validation error | Operator corrects the supplied policy |
| Size policy smaller than current active segment footprint | Retention evaluator sees no eligible rolled segments to drop | Preserve active segment and report retained frontier based on remaining history | Retention catches up after future segment rolls create eligible old segments |
| Cursor or replay request falls behind retained frontier | Status/frontier comparison during read/cursor validation | Return explicit out-of-retention error or earliest-retained guidance | Operator resets the cursor/read start to the retained frontier |
| Operator misreads retention as compaction | Proof/docs review and status field naming | Publish explicit documentation and proof coverage | Maintain vocabulary separation between retention and compaction |
