# Test runner and execution inventory

This directory owns local validation orchestration, task inputs and its regression
checks. Semantic oracles and runtime fixtures stay with their test domains.

| File | Purpose |
| --- | --- |
| [checks.json](checks.json) | Ordered fast checks and generated-contract validators |
| [Native scopes](native-checks.md) | Compiled components, independent fixtures and local process faults, with a complete aggregate |
| [checks.py](checks.py) | Execute the inventory, propagate child failures and retain stage timings |
| [capture.py](capture.py) | Stream diagnostics, preserve automatic run artifacts and verify their identity/completion |
| [launch.py](launch.py), [paths.py](paths.py) | Explicit Python test import root and shared repository coordinates |
| [layout.json](layout.json), [layout.py](layout.py), [test_layout.py](test_layout.py) | Domain owners, explicit migration exceptions and real file-layout regression controls |
| [suite.json](suite.json) | Required lanes, environments, task nesting and focused/external owners |
| [task_coverage.py](task_coverage.py), [test_task_coverage.py](test_task_coverage.py) | Check task registration and required coverage against real Just recipes |
| [ci-budgets.json](ci-budgets.json) | Measured CI cost limits and the inventory qualified by those observations |
| [package-checks.md](package-checks.md) | Standalone package roots, real I/O boundaries and exporter/validator overlap |
| [packages.py](packages.py), [test_packages.py](test_packages.py) | Bounded standalone compilation, per-package diagnostics and cancellation controls |
| [imports.py](imports.py), [test_imports.py](test_imports.py) | Check local modules and declared exports, including imports inside rarely executed functions |
| [test_checks.py](test_checks.py) | Real subprocess controls for generator/validator failures and incomplete evidence |
| [ci.py](ci.py) | Execute the shared lane inventory with checkpointed task outcomes |
| [ci_clean.py](ci_clean.py) | Qualify committed HEAD in a separate clone with scoped dependency preparation |
| [ci_select.py](ci_select.py), [test_selection.py](test_selection.py) | Reviewed dependency selection, source-bound plans and conservative fallback controls |
| [ci_cost.py](ci_cost.py) | Read hosted setup, execution and cache costs without treating missing lanes as success |
| [ci_runner.py](ci_runner.py) | Selection, inventory, aggregate gate, interruption and clean-run regression controls |
| [external_profiles.py](external_profiles.py) | Execute explicit deployment profiles and discovery campaigns with separate completion records |
| [test_nix_inputs.py](test_nix_inputs.py) | Real Nix source invalidation controls for package manifests, assets, native code and retained evidence |

Run `just check fast` in `nix develop` for formatting, tooling, independent Python
oracle checks, diagnostic inventory/mappings and documentation links. It builds
no runtime binaries and starts no Transit services. It does not replace compiled
contract checks, package tests, disk/recovery proofs or frontend validation.
`just check all` and the hosted core lane retain those broader checks.
`just check native` runs the complete native aggregate; append `components`,
`fixtures` or `faults` for a focused scope. Component tests can use local files;
none of these names promises an in-memory-only unit suite.

Launch migrated Python drivers through `python3 -B tests/runner/launch.py`,
followed by their repository-relative path and arguments. For example,
`python3 -B tests/runner/launch.py tests/verification/check.py` runs the catalog
check. Absolute paths inside `tests/` also work. The launcher preserves arguments,
exit status and the caller's working directory. Import shared helpers by their
owner (`harness.services`, `runner.paths`) and use `runner.paths.ROOT` for
repository coordinates. Avoid per-file parent-depth calculations and `sys.path`
edits in domain drivers. The import root affects this interpreter only; child
SDK consumers resolve their installed packages independently.

The fast import audit reads tracked and non-ignored Python sources without
executing them. It checks explicit local imports, namespace modules, relative
imports and declared exports, including imports inside fault branches. Shared
SDK schedules use an [explicit consumer registry](../sdk/consumer_registry.py).
Computed module names require explicit registration. `imports.py --json` exposes
the observed edges for dependency review. These are static declarations, not proof
of runtime conditions, generated child scripts or installed package resolution;
the actual scenario remains required.

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
Preparation and fixture lifetime observations are kept separately under
`.cache/checks/phases/`; see [phase boundaries and limits](../harness/README.md).
Hosted uploads and clean-source retention include these records.

Command output streams to the console and a diagnostic log. Each log retains up
to 16 MiB of original output, keeping its beginning and end with an explicit
omission count. Generator stdout is saved separately and passed unchanged to its
validator; it is never truncated or mixed with diagnostics. Logs and generated
inputs have recorded byte counts and SHA-256 identities. To check a retained
invocation, run `python3 -B tests/runner/capture.py PATH_TO_RUN_DIRECTORY`.
Missing or changed artifacts and incomplete runs fail this check.

CI lane metadata includes initial and current resource observations at task
checkpoints. Child CPU and block-I/O counters are cumulative for children waited
by the runner. Maximum child RSS is the largest child high-water mark, not the
sum of concurrent resident memory (KiB on Linux, bytes on macOS). Linux available
memory and workspace free space are boundary snapshots, not interval minima.
Linux I/O pressure totals are whole-host cumulative stall seconds; their delta
includes other host work. Unsupported or unreadable host observations are null.
These measurements cover lane execution, while hosted setup/cache costs come
from job records. They do not establish isolated workload throughput.

`just ci cost RUN_ID` reports job/setup/cache costs and the first successfully
completed ordinary lane. That first-lane time includes queue and preparation;
it is not the time of the first assertion. Budget eligibility requires the same
ordered task lists and lane allocation, including the browser continuation.
Missing or foreign inventory identities leave the measured costs visible but
cannot meet a budget. The reporter reads the measured revision's inventory as
data and records its own source separately; it executes no code from that run.
An unavailable source inventory leaves the result inconclusive.
[CI budgets](ci-budgets.json) identify the calibrated inventory and separate warm
and cold thresholds; the earlier 33-task limits retain their historical source.
The command reports `budget_met`; a cost overrun alone does not fail the required
correctness gate. These thresholds allow regression headroom and are distinct
from faster feedback targets. A matching inventory hash confirms registration,
not identical internal assertions or workload sizes. Review source, toolchain
and workload changes before attributing a timing difference. The
[calibration account](../../docs/history/qualification/verification.md#test-ownership-and-development-workflow--2026-10-27)
records the measurements and their limits.
Warm cache classification requires every configured GitHub cache to restore its
matching key. Formal explicitly uses upstream Nix substitutes in both modes and
has only a Zig GitHub cache; its policy is recorded separately. An undeclared
missing Nix restore remains unknown or partial. Cache-miss runs disable GitHub
restores/saves and retain upstream Nix substitutes. Neither mode promises empty
upstream caches or a particular provider download rate.

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

`just ci select BASE HEAD` reports the changed inputs, transitive consumer groups,
proposed tasks and enforced lanes from `suite.json`. Changes confined to the
reviewed formal-model or Go SDK inputs execute their dependent tasks. Other code
changes retain the full ordinary inventory; documentation-only changes run the
documentation checks. Main, release, merge-group and manually dispatched qualification stay full.
Both ends of a rename are inputs; a missing comparison revision fails planning.

The reviewed graph is deliberately small. The Authority, WAL, Console and Delivery
specifications feed their model drivers and formal tasks. The Go module feeds its
archive builder, then the installed Go consumer and example in
`bindings::go-sdk-test`. That task includes formatting, vet, race/cgo checks,
foreign-definition rejection and the disk-backed raw-client recovery schedule.
Changes to Go's generated ABI declarations also select `bindings::check` for
generation drift; shared generators and authoritative contracts select full CI.
The [task recipes](../../tasks/bindings.just), [native registration](../../build/checks.zig)
and [consumer registry](../sdk/consumer_registry.py) are the audited callers; Go
does not participate in the Station interoperability ring. Other SDKs and native
packages still select full qualification. Shared harnesses, contracts, fixtures,
active budgets, build/runner policy and unknown files also stay full.

Adding a reviewed group requires its input owners, dependency edges, executable
consumers and resource classes. Test changed dependencies, new/deleted inputs,
rename endpoints and unknown paths, then compare the proposed task set with
complete successful runs before enabling it. Directory location alone is not
evidence that no other caller exists. CI records the proposal with the executed
tasks; the runner rejects plans for another commit, unowned/omitted tasks or a
different policy. A scoped successful result cannot qualify a full-suite budget.
Hosted work schedules eight lanes within the existing seven-job ceiling; each
lane remains sequential, with isolated mutable state and one writer per selected
Nix cache group; formal does not write a Nix cache. Storage/catalog/query tasks belong to `growth`;
SQL protocol/relational and HTTP/gRPC tasks belong to `interfaces`. These split
the former 39-task growth lane at existing task boundaries. Formal feedback stays
early. The additional job repeats its shell/cache and native preparation; cost
comparisons must include that work as well as elapsed-time changes.

`just bindings::runtime-boundary` checks Nix input selection, then builds and
exercises the actual packaged runtime and SQL gateway without test or SDK source.
It also checks that disabled test registration and missing test inputs fail.
Its input controls use
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

Release metadata and installer controls run in the fast profile through
[test_versions.py](test_versions.py), [test_release.py](test_release.py) and
[test_publication.py](test_publication.py). The publication controls reject
ambiguous registry failures, corrupted downloads and conflicting published images.
The distribution workflow separately builds static executables, exercises
[test::release](../../tasks/test.just) outside the checkout, validates Helm and
runs container SQL before any tag publication. These checks do not establish
macOS/Windows support or a completed registry publication.

The release workflow additionally runs `test::release-install` on downloaded
artifacts on a fresh runner without Nix. The published path uses anonymous HTTPS,
then checks the exact expected release/commit, installed binary hashes, embedded
Board assets and inspection, SQL and retained restart. Public registry checks use
empty Docker and Helm credential stores; failure does not retract published bytes.
