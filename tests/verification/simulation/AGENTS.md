# Working on deterministic schedules

Follow the [verification rules](../AGENTS.md) and [scenario index](README.md).
Select the transition, storage/resource, shared-client or component owner by the
assertion being checked. Keep saved JSON schedules with that owner's corpus.

Run Python drivers through `tests/runner/launch.py`; use `runner.paths.ROOT` and
qualified imports. Give shared Zig fixtures explicit modules in the build graph.
Keep expected state independent of production code and distinguish atomic-store
premises from physical WAL, disk and process-death experiments.

Preserve generator identities, seeds, limits, saved counterexamples and negative
controls when moving or consolidating tests. Require identical repeated replay,
all requested faults to fire and a complete observation sequence. Tool failures,
timeouts and incomplete traces cannot establish correspondence or detect a mutant.
Run the affected ordinary schedule and its committed-source mutation campaign;
retain the original failure before attempting minimization or a repair.
