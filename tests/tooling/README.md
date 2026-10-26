# Repository check tooling

This directory owns local validation orchestration, task inputs and its regression
checks. Semantic oracles and runtime fixtures stay with their test domains.

| File | Purpose |
| --- | --- |
| [checks.json](checks.json) | Ordered fast checks and generated-contract validators |
| [checks.py](checks.py) | Execute the inventory, propagate child failures and retain stage timings |
| [test_checks.py](test_checks.py) | Real subprocess controls for generator/validator failures and incomplete evidence |
| [ci.py](ci.py) | Execute the shared lane inventory with checkpointed task outcomes |
| [ci_clean.py](ci_clean.py) | Qualify committed HEAD in a separate clone with scoped dependency preparation |
| [ci_select.py](ci_select.py) | Conservative changed-path selection; unknown or shared inputs select full CI |
| [ci_cost.py](ci_cost.py) | Read hosted setup, execution and cache costs without treating missing lanes as success |
| [ci_runner.py](ci_runner.py) | Selection, inventory, aggregate gate, interruption and clean-run regression controls |

Run `just check fast` in `nix develop` for formatting, tooling, independent Python
oracle checks, diagnostic inventory/mappings and documentation links. It builds
no runtime binaries and starts no Transit services. It does not replace compiled
contract checks, package tests, disk/recovery proofs or frontend validation.
`just check all` and the hosted core lane retain those broader checks.

`just check contracts` compiles the nine schema exporters in one Zig build graph
and runs the existing 18 independent checks. The runner receives immutable build
artifact paths and keeps generation separate from validation. Cached compilation
does not skip validation. Focused generation/check commands remain in the
[contract module](../../tasks/contract.just).
Install its pinned TypeScript checker once with
`vp install --frozen-lockfile --filter transit --filter @transit/client`.
Clean contract/core qualification and hosted core CI prepare these dependencies
explicitly; the fast check has no frontend dependency installation.

`just ci clean --check fast` and `just ci clean --check contracts` repeat those
scopes from committed HEAD without workspace outputs. Use `--lane NAME` for CI
inventory qualification; neither a check scope nor a single lane is full CI.

Reports under `.cache/checks/` record the source revision/dirty state, expected check IDs,
completion and generation/validation times. Missing completion and failed stages
cannot pass. Glob inputs expand without a shell and must match at least one file.
Only a successful generator can supply bytes to its independent validator.

Use `python3 -B tests/tooling/test_checks.py` to check the runner. Add new checks
to the owning profile with a distinct ID; keep standalone domain commands usable.

Run `python3 -B tests/tooling/ci_runner.py` for CI orchestration changes, then the
affected real clean check/lane. [CI commands](../../tasks/ci.just) and
[hosted workflows](../../.github/workflows/ci.yml) use these same owners. The
[verification catalog](../verification/README.md) owns invariants, bounds, models
and scenario definitions; this directory owns how their required tasks execute.
