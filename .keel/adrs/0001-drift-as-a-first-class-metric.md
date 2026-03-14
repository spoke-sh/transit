---
id: 0001
title: Drift as a First-Class Operational Metric
status: proposed
date_at: 2026-03-13T22:30:00
---

# ADR 0001: Drift as a First-Class Operational Metric

## Status

proposed

## Context

Current agentic workflows often struggle with the balance between autonomy and alignment. An agent working too long without feedback creates a large "drift" from the user's current intent, leading to expensive merges or rejections. `transit` provides the lineage-aware storage needed to capture the history of this interaction.

## Decision

We will treat **Drift**—the divergence between Execution and Intent—as a first-class metric for agentic operations in this repository.

1.  Agents should monitor the drift magnitude (commits/time since last user check-in).
2.  Agents should use `LineageCheckpoint`s not just for data integrity, but as "Intent Anchors" verified by the user.
3.  Future work (e.g., `dojo`) will use `transit` lineage data to train agents in "Learned Verification" to minimize this drift.

## Constraints

- Agents must not sacrifice technical integrity (CI/tests) for alignment.
- Drift measurement must remain provider-neutral and compatible with both local and remote execution.

## Verification

- Implementation of Drift visuals in `transit mission status`.
- Training success in future `dojo` environments.

## Consequences

*   **Positive:** Reduces the cost of re-work by surfacing alignment issues earlier.
*   **Positive:** Provides a concrete metric for adjusting agent autonomy levels.
*   **Neutral:** Requires agents to be more self-aware of their own execution vector relative to the communication channel.
*   **Negative:** Adds a layer of conceptual overhead to the "Verification" loop beyond simple CI/test passing.
