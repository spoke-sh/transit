# Explore Transit Strategic Bearings - Charter

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Assess branch-aware materialization and processing so `transit` can decide whether to create a first-party `transit-materialize` execution epic after the single-node kernel stabilizes. | board: VDd0u3PFg |
| MG-02 | Assess verifiable lineage and cryptographic integrity so segment, manifest, and checkpoint hardening can be sequenced without contaminating the hot append path prematurely. | board: VDd1F1tUe |
| MG-03 | Assess agent runtime and model harness workloads so the reference AI workload remains concrete enough to shape the core API and evaluation suite. | board: VDd1EybWm |
| MG-04 | Assess auto-threaded communication and collaboration so the branch-as-thread thesis is translated into a real workload model instead of staying a slogan. | board: VDd1F0OXH |
| MG-05 | Assess high-throughput CRDT and collaborative state overlays so `transit` can decide whether CRDT support belongs in core semantics, materialization, or application-level overlays. | board: VDd1IzACq |
| MG-06 | Assess multi-node replication and server semantics so future networked and replicated work preserves the one-engine thesis and stages delivery sanely. | board: VDd1J2IDM |

## Constraints

- Mission `VDcx0jbsJ` remains the primary delivery mission; this research mission must inform, not delay, the single-node kernel.
- Every bearing must end in an explicit recommendation: `Proceed`, `Park`, or `Decline`.
- Research must preserve the current constitutional invariants around one engine, explicit lineage, immutable acknowledged history, and object storage as native architecture.
- Bearings may propose future epics, but they must not smuggle speculative semantics into the current hot append path without evidence.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when all mission bearings have current briefs, evidence, and assessments with selected recommendations
- YIELD to human when a bearing requires external product or market evidence that is not discoverable from repo context
