# Drift Management

In `transit`, drift is defined as the pressure differential between the **Lineage of Execution** (what the agent is doing) and the **Lineage of Intent** (what the user wants).

## The Drift Vector

A drift vector has two primary components:

1.  **Magnitude:** The distance (in time, commits, or complexity) since the last explicit "merge" or alignment point with the user.
2.  **Direction:** The divergence between the current execution path and the evolving user requirements.

## Learned Verification

Drift management requires **Learned Verification**: the ability for an agent to predict the user's acceptance of a branch based on historical alignment tapes (stored in `transit` streams).

## Autonomy vs. Alignment

- **Low Drift (High Communication):** Maximize velocity. The agent and user are tightly coupled.
- **High Drift (Low Communication):** Decrease velocity. The agent should surface "checkpoints" or "integrity proofs" more frequently to reduce the cost of eventual reconciliation.

## Operational Metrics

`transit` aims to make drift measurable through:
- **Verification Maps:** Visualizing the integrity of history.
- **Lineage Checkpoints:** Binding execution heads to verified intent.
- **Reconciliation Tapes:** Recording how drift was resolved during merges.
