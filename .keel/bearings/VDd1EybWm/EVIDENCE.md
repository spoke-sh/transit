---
id: VDd1EybWm
---

# Research Agent Runtime And Model Harness Workloads — Evidence

## Sources

| ID | Class | Provenance | Location | Observed / Published | Retrieved | Authority | Freshness | Notes |
|----|-------|------------|----------|----------------------|-----------|-----------|-----------|-------|
| SRC-01 | manual | manual:repo-read | README.md | 2026-03-11 | 2026-03-11 | high | high | The README names AI model harnesses and agent runtimes as direct target workloads and ties branching, merging, and replayable traces to that thesis. |
| SRC-02 | manual | manual:repo-read | GUIDE.md | 2026-03-11 | 2026-03-11 | high | high | The guide recommends one root stream per task or conversation, one child branch per retry or alternate plan, and explicit tool-call and evaluator metadata. |
| SRC-03 | manual | manual:repo-read | EVALUATIONS.md | 2026-03-11 | 2026-03-11 | high | high | The evaluation guide requires mixed AI workloads with root streams, many branch creations, interleaved readers, and large artifact references. |
| SRC-04 | manual | manual:repo-read | CONSTITUTION.md | 2026-03-11 | 2026-03-11 | high | high | The constitution explicitly defines AI and communication systems as reference workloads rather than edge cases. |

## Technical Research

### Feasibility
Feasibility is high because the current docs already contain most of the workload primitives. What is missing is a concrete reference contract that engineering, benchmarks, and future demos can all share [SRC-01] [SRC-02] [SRC-03] [SRC-04].

## Key Findings

1. AI harnesses are not a speculative bolt-on; they are embedded in the product thesis, constitutional priorities, and evaluation plan [SRC-01] [SRC-03] [SRC-04].
2. The guide already sketches the right usage model for retries and alternate plans, so the next step is to formalize a canonical event vocabulary rather than invent a new architecture [SRC-02].
3. A concrete AI workload would sharpen evaluation and API decisions by making branch creation, artifact references, and replay semantics measurable instead of aspirational [SRC-03].

## Unknowns

- Which workflow should be the primary reference trace: agent orchestration, model evaluation harnesses, or both?
- How much schema opinion should `transit` ship in examples without turning the core engine into an application framework?
