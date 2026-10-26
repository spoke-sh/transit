# Working on verification

Follow [test instructions](../AGENTS.md). Read the [verification guide](README.md),
[invariant catalog](invariants.json) and owning public contract before changing a
model, oracle, simulation or execution profile.

Keep finite formal exploration, deductive proofs, implementation correspondence,
simulated faults and real integration checks distinct. State bounds, assumptions,
fairness and omitted behavior beside each claim. A model pass does not prove
filesystem behavior or every production execution.

Register scenarios in the existing suite/invariant catalogs. Keep small regression
profiles independently runnable; expanded exploration has explicit budgets and
ownership. Preserve deterministic replay and saved counterexamples. Share harness
mechanics without deriving expected semantics from the implementation under test.

Record direct Just nesting in the [runner inventory](../runner/suite.json)'s
`recipe_nested_tasks`; keep indirect
build/runner nesting in `nested_tasks`. Required tier coverage must retain the
actual invocations and cannot be satisfied by a focused-only command. Run
`python3 -B tests/runner/test_task_coverage.py` when changing this inventory.

Run the affected driver, its negative controls and the catalog checker:
`python3 -B tests/verification/check.py` inside `nix develop`. Timeouts, compiler
errors, missing completion and malformed traces are inconclusive failures. A
mutation is detected only by the intended executed assertion, not a build failure.

Use [model instructions](models/AGENTS.md) for formal work and
[evidence instructions](results/AGENTS.md) for records. Keep navigation concise;
qualification history belongs in the [topic archive](../../docs/history/qualification/README.md).
