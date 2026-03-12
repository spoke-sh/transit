# Canonical AI Trace Contract - Software Design Description

> Codify a canonical AI workload model that can drive examples, benchmarks, and future engine interfaces.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage is a contract-definition slice. It does not implement the AI runtime itself. Instead, it defines the canonical event taxonomy, artifact envelope, and evaluation mapping that future `transit` engine, CLI, and fixture work should share.

## Context & Boundaries

The boundary is deliberate:

- `transit` core semantics remain streams, branches, merges, segments, manifests, and object-store-backed artifacts.
- This voyage translates those semantics into an AI workload contract without adding new storage behavior.
- Future code work can then implement examples, fixtures, and APIs against one agreed trace model.

```
┌───────────────────────────────────────────────────────────────┐
│                    Canonical AI Trace Contract               │
│                                                               │
│  Event Taxonomy   Metadata Envelope   Evaluation Mapping      │
│  root/branch/     lineage/tool/       examples + benchmark    │
│  merge entities   artifact fields      fixtures                │
└───────────────────────────────────────────────────────────────┘
               ↑                                 ↑
         transit core model               docs / evaluations
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `README.md`, `GUIDE.md`, `EVALUATIONS.md` | repo docs | Source workload intent and current usage patterns | current |
| Mission `VDcx0jbsJ` | board | Defines the kernel semantics this contract depends on | active |
| `object_store`-native storage thesis | architecture | Constrains how artifacts should be referenced | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| AI workload root | Use a task or run root stream with explicit child branches for retries, critiques, and alternate plans | Matches current docs and preserves lineage clarity |
| Merge semantics | Model AI reconciliation as explicit merge artifacts rather than silent overwrites | Keeps provenance auditable and aligned with core design |
| Large payload handling | Reference large prompts, outputs, and traces through object-store-backed envelopes | Preserves append-path efficiency and matches storage thesis |
| Voyage scope | Stay contract-first rather than implementation-first | This epic should guide future code, not outrun the kernel mission |

## Architecture

The voyage produces three coordinated artifacts:

1. Event taxonomy: the canonical trace entities and their lineage relationships.
2. Metadata envelope: required fields and large-artifact reference rules.
3. Evaluation mapping: how the canonical trace becomes examples and benchmark fixtures.

## Components

### Event Taxonomy

- Defines root streams, branch types, merge artifacts, tool calls, evaluator decisions, and completion checkpoints.
- Anchors AI behavior in `transit` lineage primitives instead of application-specific hidden state.

### Metadata Envelope

- Defines the required metadata for actor identity, branch reason, tool context, evaluator provenance, and artifact references.
- Keeps the distinction clear between inline metadata and object-store-backed payloads.

### Evaluation Mapping

- Maps the canonical trace contract onto docs and future evaluation workloads.
- Ensures branch-heavy AI traces become a reusable proof surface rather than one-off examples.

## Interfaces

This voyage defines documentation and planning interfaces, not wire protocols:

- epic PRD requirements
- voyage SRS requirements
- story acceptance criteria
- future example and benchmark fixture shapes

## Data Flow

1. Start from the current `transit` lineage model.
2. Define canonical AI trace entities that fit that model.
3. Define metadata and artifact envelopes that preserve hot-path and object-store expectations.
4. Map those entities and envelopes into example and evaluation guidance for later implementation.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| The contract drifts into application-framework territory | Scope review against constitution and PRD | Keep examples schematic and storage-centered | Re-scope to core trace entities and envelopes |
| The contract invents new storage semantics | Review against architecture and mission `VDcx0jbsJ` | Reject changes that bypass stream/branch/merge/manifests | Rewrite around existing engine invariants |
| Evaluation mapping becomes detached from the canonical trace | Story verification fails to link workloads back to the SRS | Update evaluation alignment before planning completes | Re-run `keel doctor` and inspect epic coverage |
