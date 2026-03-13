# Research Auto-Threaded Communication And Collaboration — Brief

## Hypothesis

The Slack-like communication product and classifier-driven auto-threading idea are already central to the `transit` narrative. This bearing exists to make that narrative precise by mapping channels, thread branches, classifier evidence, summaries, and explicit merge behavior onto a concrete workload model.

## Problem Space

- Define a minimal event model for channels, thread branches, classifier evidence, and optional summaries or backlinks.
- Decide which collaboration behaviors belong in `transit` lineage primitives versus application-level conventions.

## Success Criteria

- [ ] Define a minimal communication workload contract for channels, branches-as-threads, classifier evidence, and optional summaries or backlinks.
- [ ] Make the boundary explicit between storage-level lineage primitives and application-level collaboration policy.

## Scope

### In Scope

- Channel and thread event modeling on top of root streams and branches.
- Metadata required for classifier-created thread splits and human overrides.
- Where explicit merge artifacts might matter for summaries, reconciliations, or moderation workflows.

### Out Of Scope

- Designing a full chat product UI.
- Teaching the storage engine about presentation details or moderation policy.
- Replacing explicit lineage with opaque application-level threading tables.

## Research Questions

- Do thread merges belong in the storage model, the collaboration application, or only in special workflows such as summaries and reconciliations?
- What metadata is required for classifier audit, human override, and moderation without bloating every message append?

## Open Questions

- Should auto-threading be treated primarily as a latency-and-correctness benchmark or as a first-party product demonstration?
- How much thread lifecycle policy should the core engine understand beyond branch creation and explicit merge metadata?
