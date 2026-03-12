# Research Agent Runtime And Model Harness Workloads — Brief

## Context

The repo repeatedly describes AI model harnesses and agent runtimes as primary target workloads, but it does not yet define one canonical reference trace. This bearing exists to turn that thesis into a concrete workload model for task traces, retries, critiques, evaluations, and artifact references.

## Objectives

- Describe a canonical event model for task roots, retries, critique branches, tool calls, and evaluation artifacts.
- Identify which engine capabilities must exist before `transit` can credibly claim AI-harness fit.

## Scope

### In Scope

- Root-stream and branch patterns for agent tasks, retries, alternate plans, and evaluator decisions.
- Artifact-reference conventions for large model outputs, prompts, or tool attachments.
- The specific benchmark and demo shape needed to keep the core API honest.

### Out Of Scope

- Building an application framework for agent orchestration.
- Locking the core engine to one model vendor, prompt schema, or workflow style.
- Implementing the full workload while the single-node kernel is still incomplete.

## Research Questions

- What should be the canonical root stream for AI workloads: one task, one conversation, one run, or one evaluation set?
- Which artifacts should live outside the log as object-store references versus inline metadata?

## Open Questions

- Which workflow should be the first canonical trace: agent orchestration, evaluation harnesses, or a hybrid of both?
- How opinionated should `transit` examples become before they start looking like an application framework instead of a storage substrate?
