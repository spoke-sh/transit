---
id: VDd1F0OXH
---

# Research Auto-Threaded Communication And Collaboration — Evidence

## Sources

| ID | Class | Provenance | Location | Observed / Published | Retrieved | Authority | Freshness | Notes |
|----|-------|------------|----------|----------------------|-----------|-----------|-----------|-------|
| SRC-01 | manual | manual:repo-read | README.md | 2026-03-11 | 2026-03-11 | high | high | The README says channels should map to root streams, threads to native branches, and classifier-driven auto-threading is a core design motivator. |
| SRC-02 | manual | manual:repo-read | ARCHITECTURE.md | 2026-03-11 | 2026-03-11 | high | high | The architecture document explicitly describes conversations as root streams, threads as child branches, and classifier metadata recorded on branch creation. |
| SRC-03 | manual | manual:repo-read | GUIDE.md | 2026-03-11 | 2026-03-11 | high | high | The guide provides example message and branch metadata for channel/thread modeling and classifier-created thread splits. |
| SRC-04 | manual | manual:repo-read | EVALUATIONS.md | 2026-03-11 | 2026-03-11 | high | high | The evaluation guide defines auto-threading as a signature workload with classifier-to-branch latency and threaded replay correctness. |

## Technical Research

### Feasibility
Feasibility is high as a reference workload because the repo already maps communication semantics directly onto streams and branches. The remaining work is to define the minimal event vocabulary and decide where UI-level behavior stops and storage semantics begin [SRC-01] [SRC-02] [SRC-03] [SRC-04].

## Key Findings

1. Auto-threaded communication is already one of the clearest product narratives in the repo, not an afterthought: the README, architecture, guide, and evaluation plan all treat it as a signature use case [SRC-01] [SRC-02] [SRC-03] [SRC-04].
2. The storage mapping is simple and coherent today: channel equals root stream, thread equals branch, and classifier evidence attaches to branch creation rather than rewriting history [SRC-01] [SRC-02] [SRC-03].
3. The unresolved questions are product-boundary questions, such as summaries, backlinks, manual overrides, and whether thread reconciliation should be modeled as explicit merge artifacts [SRC-02] [SRC-04].

## Unknowns

- How much thread lifecycle policy should the core engine understand beyond branch creation and explicit merge metadata?
- Should auto-threading be evaluated primarily as latency/correctness infrastructure or as a first-party product demo?
