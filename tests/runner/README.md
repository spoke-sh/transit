# Test runner and execution inventory

This directory owns local validation orchestration, task inputs and its regression
checks. Semantic oracles and runtime fixtures stay with their test domains.

| File | Purpose |
| --- | --- |
| [checks.json](checks.json) | Ordered fast checks and generated-contract validators |
| [checks.py](checks.py) | Execute the inventory, propagate child failures and retain stage timings |
| [capture.py](capture.py) | Stream diagnostics, preserve automatic run artifacts and verify their identity/completion |
| [launch.py](launch.py), [paths.py](paths.py) | Explicit Python test import root and shared repository coordinates |
| [layout.json](layout.json), [layout.py](layout.py), [test_layout.py](test_layout.py) | Domain owners, explicit migration exceptions and real file-layout regression controls |
| [suite.json](suite.json) | Required lanes, environments, task nesting and focused/external owners |
| [task_coverage.py](task_coverage.py), [test_task_coverage.py](test_task_coverage.py) | Check task registration and required coverage against real Just recipes |
| [ci-budgets.json](ci-budgets.json) | Measured CI cost limits and the inventory qualified by those observations |
| [test_checks.py](test_checks.py) | Real subprocess controls for generator/validator failures and incomplete evidence |
| [ci.py](ci.py) | Execute the shared lane inventory with checkpointed task outcomes |
| [ci_clean.py](ci_clean.py) | Qualify committed HEAD in a separate clone with scoped dependency preparation |
| [ci_select.py](ci_select.py) | Conservative changed-path selection; unknown or shared inputs select full CI |
| [ci_cost.py](ci_cost.py) | Read hosted setup, execution and cache costs without treating missing lanes as success |
| [ci_runner.py](ci_runner.py) | Selection, inventory, aggregate gate, interruption and clean-run regression controls |
| [external_profiles.py](external_profiles.py) | Execute explicit deployment profiles and discovery campaigns with separate completion records |
| [test_nix_inputs.py](test_nix_inputs.py) | Real Nix source invalidation controls for package manifests, assets, native code and retained evidence |

Run `just check fast` in `nix develop` for formatting, tooling, independent Python
oracle checks, diagnostic inventory/mappings and documentation links. It builds
no runtime binaries and starts no Transit services. It does not replace compiled
contract checks, package tests, disk/recovery proofs or frontend validation.
`just check all` and the hosted core lane retain those broader checks.

Launch migrated Python drivers through `python3 -B tests/runner/launch.py`,
followed by their repository-relative path and arguments. For example,
`python3 -B tests/runner/launch.py tests/verification/check.py` runs the catalog
check. Absolute paths inside `tests/` also work. The launcher preserves arguments,
exit status and the caller's working directory. Import shared helpers by their
owner (`harness.services`, `runner.paths`) and use `runner.paths.ROOT` for
repository coordinates. Avoid per-file parent-depth calculations and `sys.path`
edits in domain drivers. The import root affects this interpreter only; child
SDK consumers resolve their installed packages independently.

The layout check includes tracked and untracked, non-ignored test files. Put new
work in a named owner with a README and AGENTS file. The completed directory
migration has no exceptions; keep root files limited to README.md and AGENTS.md.

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

Each check or CI invocation keeps a private, unique directory under
`.cache/checks/runs/` or `.cache/ci/runs/`. The top-level profile/lane JSON points
to the latest invocation; rerunning does not overwrite earlier results. Records
include source revision/dirty state, pinned lockfile hash, resolved tool paths,
commands, outcomes and stage timings. They begin incomplete and checkpoint before
each command. Missing completion and failed stages cannot pass.

Command output streams to the console and a diagnostic log. Each log retains up
to 16 MiB of original output, keeping its beginning and end with an explicit
omission count. Generator stdout is saved separately and passed unchanged to its
validator; it is never truncated or mixed with diagnostics. Logs and generated
inputs have recorded byte counts and SHA-256 identities. To check a retained
invocation, run `python3 -B tests/runner/capture.py PATH_TO_RUN_DIRECTORY`.
Missing or changed artifacts and incomplete runs fail this check.

Clean qualification preserves these records and preparation logs before removing
a successful clone. Failed clones remain private at the reported path. Local
records remain until explicitly removed; hosted CI uploads run records and the
selected proof artifacts with 14-day retention. Durable scientific citations need
a specifically retained record and identity beyond that expiry; see
[results and reproducibility](../evidence/README.md). Do not commit ordinary run
output or write a manual pass ledger.

Glob inputs expand without a shell and must match at least one file. Only a
successful generator can supply bytes to its independent validator.

Use `python3 -B tests/runner/test_checks.py` to check the runner. Add new checks
to the owning profile with a distinct ID; keep standalone domain commands usable.

Run `python3 -B tests/runner/ci_runner.py` for CI orchestration changes, then the
affected real clean check/lane. [CI commands](../../tasks/ci.just) and
[hosted workflows](../../.github/workflows/ci.yml) use these same owners. The
[verification catalog](../verification/README.md) owns invariants, bounds, models
and scenario definitions; this directory owns how their required tasks execute.
The [task coverage checker](task_coverage.py) verifies direct
recipe nesting and required tier ownership before expensive qualification.

`just bindings::runtime-boundary` checks Nix input selection, then builds and
exercises the actual packaged runtime and SQL gateway. Its input controls use
small independent trees and the pinned Nix library; they do not compile a runtime
and are not part of `just check fast`. The subsequent package builds qualify the
selected real source trees. Neither check requalifies unrelated SDK languages.

The [migration map](../../docs/roadmap/development-workflow-migration.json)
accounts for the original test inventory. Layout checks reject missing or
duplicate dispositions and changes to retained observation identities.
`python3 -B tests/runner/layout.py --archive-integrity` verifies the raw archived
bytes against the original Git revision; ordinary output stays in runner artifacts. Use
`python3 -B tests/runner/layout.py --complete` for the final destination audit;
it fails while old paths or migration exceptions remain.
