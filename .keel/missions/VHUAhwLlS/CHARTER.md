# Add Explicit Per-Stream Retention To Transit - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Add explicit per-stream retention to Transit so operators can keep the default history-unbounded model, opt specific streams into age- or size-based retention, and observe retained-frontier state through stream list and status surfaces. | board: VHUAlZWZG |

## Constraints

- Preserve the current default semantics: streams without an explicit retention policy must continue to retain history indefinitely.
- Treat retention as coarse-grained lifecycle control, not compaction. This mission does not introduce key-aware latest-value semantics, tombstones, or selective erasure.
- Enforce retention only by trimming oldest eligible rolled segments. The active segment must remain append-only and must never be partially rewritten.
- Keep retention semantics shared across embedded and hosted usage by implementing them in the shared engine model first, then surfacing them through CLI and protocol status paths.
- Surface retention policy and retained-frontier information explicitly in operator-facing list and status output so bounded replay is visible rather than implicit.
- Verification must include targeted automated coverage and operator-facing proof/guidance that explains bounded replay, retained-start semantics, and the distinction from compaction.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when epic `VHUAlZWZG` is complete, mission verification is recorded, and `keel doctor` reports no blocking board-health errors
- YIELD to human when satisfying the mission would require introducing key-aware compaction semantics, making `30 days` the global default retention policy, or rewriting acknowledged records inside retained segments
