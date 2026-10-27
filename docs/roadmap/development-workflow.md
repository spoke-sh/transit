# Development workflow and test ownership implementation

[Roadmap](README.md) · **Status: In Progress**

This supporting engineering plan completes the test organization and development
feedback work begun in PRs #175–#181. It does not insert or renumber a product
milestone. The intended outcome is that contributors can find a declaration's
checks, run the appropriate scope, and inspect complete, attributable results
without unnecessary compilation, packaging or environment setup.

Deliver the remaining work on one feature branch, in logical commits, followed
by one PR that closes this plan. Update this checklist as work is implemented and
qualified. A merged earlier slice, a registered command, a successful compilation
or a partial CI run cannot complete an unchecked acceptance criterion.

## Source basis and scope

The starting revision is `a610ecd5dcff22f2d0177b61b905a8e985252c13` (PR #181).
Its tracked inventory contains 1,405 files under `tests/`, including 487 root
files: 276 Python and 107 Zig files. Ordinary CI selects 103 tasks in seven lanes.
The retained performance budgets qualify an earlier 33-task inventory, not this
expanded suite. These counts describe the starting revision, not a future quota.
The [source and execution baseline](development-workflow-baseline.json) preserves
every tracked test file's size/hash and the original check/lane/nesting catalogs.
It is a migration audit record, not another live execution inventory or a passing
qualification result. The [file disposition map](development-workflow-migration.json)
records every original file's planned destination, role and observed reference
consumers. Dynamic task and artifact dependencies still require the P1.1 audit.

The user paused the separate storage milestone work so this branch can migrate
the storage/query test owners as well as the other domains. Preserve any work
outside this checkout. The local Argon review transcript is an untracked input;
do not commit it or treat its proposed speedups and task counts as measurements.

Current ownership references are the [test index](../../tests/README.md),
[contributor guide](../handbook/guides/contributing.md),
[verification limits](../handbook/reference/verification.md),
[task guide](../../tasks/README.md), and [toolchain guide](../../nix/README.md).
Current semantics continue to belong to the handbook and owning packages.

### Delivered foundation

- [x] Preserve the former root test ledger, rewrite its inbound links and make
  `tests/README.md` a navigation index ([PR #175](https://github.com/spoke-sh/transit/pull/175)).
- [x] Run formal feedback independently of SDK qualification
  ([PR #176](https://github.com/spoke-sh/transit/pull/176)).
- [x] Establish listing defaults for `just check` and `just ci`, explicit check
  scopes, clean-source checking and a shared contract-exporter build graph
  ([PR #177](https://github.com/spoke-sh/transit/pull/177)).
- [x] Group orchestration and check tools under their current `tests/tooling/`
  owner ([PR #178](https://github.com/spoke-sh/transit/pull/178)). This owner moves
  to `runner/` below; the earlier change does not complete the final layout.
- [x] Remove the second ordinary execution of the SDK catalog aggregate while
  checking the required nested language schedules
  ([PR #179](https://github.com/spoke-sh/transit/pull/179)).
- [x] Separate generic service helpers from the explicit Ursula fixture and add
  package/interface contribution instructions
  ([PR #180](https://github.com/spoke-sh/transit/pull/180)).
- [x] Separate frontend dependency, Board asset and runtime Nix inputs, with
  source-invalidation controls and clean package builds
  ([PR #181](https://github.com/spoke-sh/transit/pull/181)). Runtime source still
  contains executable tests; runtime/test build separation remains below.

## Required final layout

Only `README.md` and `AGENTS.md` remain as tracked files at the test root. The
allowed immediate directories are exactly the following owners. Create nested
directories for real groups of work; package units and SDK language-only units
remain with their implementations outside this tree.

```text
tests/
  README.md
  AGENTS.md
  runner/
  harness/
  catalog/
  storage/
  query/
  runtime/
  interfaces/
  sdk/
  verification/
    README.md
    AGENTS.md
    models/
    simulation/
    mutations/
  fixtures/
  performance/
  evidence/
```

| Owner | Responsibility and migration sources |
| --- | --- |
| `runner/` | Selection, execution inventories, timing, reporting, layout checks and orchestration controls; current `tooling/`, CI budgets and execution bookkeeping |
| `harness/` | Processes, readiness, explicit provider/environment setup, faults and artifact mechanics; reusable parts of mixed server/ABI fixtures |
| `catalog/` | Object/definition identities, schemas, dependencies, lifecycle declarations and current policy |
| `storage/` | Direct WAL/Table acceptance, objects, segments, physical codecs, retention and recovery; explicit local and Ursula profiles |
| `query/` | Planning, execution, logical values, source cuts and result semantics; independent SQL/relational oracles |
| `runtime/` | Station, delivery, supervision, application execution and recorded effects |
| `interfaces/` | Native wire, SQL protocols/sessions, CLI, Board, HTTP/gRPC, Flight, reactive interfaces, installation, launchers and public diagnostics |
| `sdk/` | Installed consumers, language peers, shared conformance, ABI/host boundaries and interoperability |
| `verification/` | Semantic invariants and limits, formal models, deterministic schedules and mutation campaigns; task execution metadata belongs to `runner/` |
| `fixtures/` | Shared independent test inputs; canonical contract fixtures keep their existing contract/package owner |
| `performance/` | Workloads, benchmark drivers, comparisons and active budgets from the existing benchmark families |
| `evidence/` | Navigation and specifically justified reproducibility records; ordinary run output belongs in ignored runner output and CI artifacts |

Classify by assertion and boundary, not a filename prefix. For example,
`storage.py` exercises Ursula, `fixtures.py` verifies canonical signing vectors,
and `operations/` contains both drivers and domain behavior. The latter must not
become a generic-harness dumping ground. Direct data-plane tests do not acquire
Station actors merely because they share process helpers.

## Execution rules

- Preserve required scenarios, assertions, seeds, bounds, deadlines, backend
  profiles, language coverage and current-policy/recovery gates. Removal or
  consolidation requires an explicit coverage mapping and executed replacement.
- Keep pure moves/path fixes, harness refactors, behavior fixes and performance
  changes in distinct commits. Move all active callers with their owner; do not
  leave forwarding scripts, fallback imports or duplicate implementations.
- Use existing Just modules. Defaults list commands; do not add top-level
  aliases such as `check-fast` or `ci-clean`. Keep focused commands executable.
- Keep independent expected values independent of production implementations.
  Share mechanics and immutable build outputs, not another scenario's state.
- A new fast/unit profile must be audited for disk, process and external-service
  work, including tests embedded inside packages. Preserve the broad aggregate.
- Compilation caches distinguish profiles. Measure compilation, installation
  and packaging separately; do not assume every profile switch recompiles code.
- Retain standalone package-manifest checks and actual packaged-runtime builds.
  A root module build or static import check establishes a different boundary.
- Never skip missing test inputs to make a runtime package build succeed.
  Separate the build graphs explicitly and fail missing inputs in their owner.
- Retained observations and live benchmark budgets have different owners. Never
  move active inputs into evidence-only CI selection or Nix exclusions.
- Preserve existing evidence hashes, failures and original attribution. When
  removing routine generated output from the current tree, link its immutable
  archived source revision. Keep original commands and identities intact. Do not
  treat manually authored pass records as a substitute for runner results.
- Do not mark models planned in later milestones as implemented or proved.
  Keep finite exploration, implementation correspondence, disk recovery,
  process death and power-loss claims distinct.

## Implementation checklist

Checkbox identifiers are stable review references. Record completion with the
implementing commit and a concise validation reference in the progress table.
Detailed execution logs belong in ignored run artifacts, then selected evidence;
this plan is not another chronological test transcript.

### P0 — Establish the plan and qualified baseline

- [x] P0.1 Inspect current task/build/source ownership and the Argon review;
  reconcile its suggestions against current code and the agreed directory tree.
- [x] P0.2 Create the implementation branch and this acceptance checklist.
- [x] P0.3 Capture a tracked file/task baseline, existing nested executions,
  language/backend coverage and retained-evidence hashes at the starting revision.
- [x] P0.4 Diagnose and repair the existing collation-cutover qualification gaps
  in separate commits: the unified SDK Table source and independent query-plan
  fingerprint oracle. Audit other affected callers of the same contract.
  Source serializers, new bundle plans and lookup consistency checks preserve
  the declared vector across all ten Station SDKs; four independently encoded
  collation fixtures exercise every installed consumer.
- [ ] P0.5 Establish a comparable successful baseline for the current inventory
  before performance changes. Record source, toolchain, workload, profiles,
  machine and cache conditions. Failed or incomplete runs remain incomplete.

### P1 — File inventory, runner and layout enforcement

- [ ] P1.1 Map every tracked test file to destination, owner and role: executable,
  helper, oracle, input, model, active budget or retained observation. Identify
  its scenario/task, consumers, required artifacts and qualification boundary.
- [x] P1.2 Move `tooling/` to `runner/`; move execution inventory, task ownership
  checks and CI budget/report machinery there. Keep semantic invariants and
  classified limits with verification; keep one current authority per catalog.
- [x] P1.3 Add a layout check to the existing fast inventory. Initially permit
  only enumerated unmigrated root files/directories, shrinking those exceptions
  per batch. Reject new root files, unknown owners and stale inventory entries.
- [x] P1.4 Test the check with actual added/moved files, missing owners, duplicate
  destinations and stale exceptions. Verify nested task ownership after moves.
- [x] P1.5 Update workflow callers, Just recipes, Python roots, formatter globs,
  docs and build references. Run runner regressions and committed-source fast
  checks before continuing.

### P2 — Shared harness and invocation boundaries

- [x] P2.1 Audit reusable mechanics in `server.py`, ABI/host helpers and native
  operation drivers. Extract process/environment/artifact ownership while
  leaving assertions and expected outcomes in their domains.
- [x] P2.2 Standardize an explicit Python test import root and supported launch
  convention. Update nested scripts and example consumers together; remove
  accidental working-directory and per-file depth assumptions.
- [ ] P2.3 Give fixtures explicit matching binary paths and explicit backends.
  Keep mutable installations, ports, credentials and durable state private to
  their scenarios. Preserve failed installations when investigation needs them.
- [ ] P2.4 Preserve bounded startup, child-exit detection, signal/restart behavior
  and joined cleanup. Execute failure controls and real local/Ursula schedules.
- [ ] P2.5 Measure setup separately. Share a running service only if reset and
  isolation are demonstrated, including grants, quotas, snapshots and background
  work; run independent/order controls. Keep destructive recovery isolated.

### P3 — Verification organization and evidence integrity

- [x] P3.1 Group formal runners with their models/configurations; keep canonical
  Lean contract specifications with their owning contract where appropriate.
- [x] P3.2 Move deterministic drivers, replay corpora and implementation schedules
  into `simulation/`, with explicit domain subgroups.
- [x] P3.3 Move mutation campaigns and negative controls into `mutations/`.
  Preserve source-edit matching, committed clone isolation and detection rules.
- [x] P3.4 Make verification README/AGENTS navigational and instructional. Move
  reusable methods beside their owners and historical accounts to history.
- [x] P3.5 Execute affected models, replay/determinism controls and mutation
  campaigns at their existing bounds. Compiler failures do not detect mutations.

### P4 — Performance inputs, automatic results and archival references

- [x] P4.1 Consolidate benchmark families under `performance/`, separating
  drivers, workloads, active budgets and tests from recorded observations.
- [x] P4.2 Audit existing records by purpose. Remove routine generated run output
  from the current tree after preserving immutable source-revision links and
  hashes. Keep active inputs and specifically justified reproducibility data with
  their owners; moving every historical log into a new folder is insufficient.
- [ ] P4.3 Update consumers of active budget/reference data, source selectors,
  CI routing, artifact publication paths and current documentation links.
- [ ] P4.4 Verify that executable inputs still invalidate owning builds/checks
  while inert evidence does not. Exercise renamed-file and unknown-input controls.
- [ ] P4.5 Run benchmark runner/oracle checks and affected real workloads. Keep
  old driver hashes intact and establish current baseline identities explicitly.
- [ ] P4.6 Standardize automatic per-task result, log and artifact capture across
  local, clean and hosted runs. Preserve failure and interruption status, source,
  command, toolchain and completion metadata. Test missing/incomplete artifacts;
  ordinary results must not require manually authored evidence files or commits.
- [ ] P4.7 Publish runner-generated summaries and artifacts with an explicit
  retention policy. Long-lived scientific or regression references need a stable
  archived identity; a temporary CI URL alone does not replace a required input.

### P5 — Installed SDK ownership

- [x] P5.1 Move shared conformance schedules and language-specific peers into
  `sdk/`, retaining installed-consumer separation from SDK implementation units.
- [x] P5.2 Update all package builders, native fixture inputs, language compiler
  commands, temporary projects, examples, interop and scenario catalogs.
- [ ] P5.3 Preserve every required SDK family, direct catalog nested execution,
  incompatible-definition rejection, ownership/lifetime and uncertain-call check.
- [ ] P5.4 Execute migrated installed consumers outside the source tree against
  explicit matching artifacts. Run actual example binaries and interop schedules.

### P6 — Public interfaces

- [x] P6.1 Move native/wire checks, SQL sessions and protocols into interface
  owners; move SQL planning/result oracles to query rather than protocol folders.
- [x] P6.2 Group CLI/console, Board, HTTP/gRPC, reactive and Flight peers and
  schedules with their owning interface. Preserve read-only inspection gates.
- [x] P6.3 Group installation, launcher, configuration and reference deployment
  checks. Keep reusable provisioning in harness and installation assertions here.
- [ ] P6.4 Execute affected protocol, installed, browser, launcher and external
  provider profiles. Record unavailable infrastructure as unqualified, not passed.

### P7 — Catalog and query semantics

- [x] P7.1 Move identity, definition, dependency, schema and current-policy
  scenarios into catalog, with their independent contract validators.
- [x] P7.2 Move planning, logical values, execution, snapshot and result scenarios
  into query, including SQL/relational oracles and their native drivers.
- [ ] P7.3 Split mixed operation modules by responsibility using explicit Zig
  module interfaces where needed; preserve test executable targets and behavior.
- [ ] P7.4 Execute declaration, authorization, snapshot, bounded query, complete
  result, lifetime and recovery scenarios affected by the moves.

### P8 — Storage and application runtime

- [x] P8.1 Move WAL, object, segment, codec, retention and direct Table recovery
  checks into storage with explicit local/provider ownership.
- [x] P8.2 Move Station, delivery, supervision, application lifecycle and effect
  scenarios into runtime. Assign mixed core tests by the boundary they assert.
- [x] P8.3 Preserve supported provider tests and retained actor-runtime checks.
  Remove superseded data-path checks only with an identified, executed replacement.
- [ ] P8.4 Execute local and Ursula disk/restart/fault coverage and affected
  application runtime schedules. Keep tmpfs and physical-disk evidence distinct.
- [x] P8.5 Reach the exact final root/owner layout. Remove all migration exceptions,
  old directory aliases and temporary forwarding mechanisms.

### P9 — Honest test profiles and runtime build inputs

- [ ] P9.1 Inventory the root test graph and package-embedded tests by component,
  disk integration, process faults, external services and contract validation.
- [x] P9.2 Establish truthful focused profiles, retaining the complete aggregate
  and assigning every moved check to required CI execution. Keep package-local
  checks discoverable without inventing redundant root task aliases.
- [x] P9.3 Separate runtime and test build registration explicitly so runtime
  packaging can omit test source. Missing requested test inputs must still fail.
- [ ] P9.4 Audit remaining exporter/validator duplication against exact commands,
  arguments, input definitions and validators before consolidating executions.
- [x] P9.5 Qualify runtime/gateway packages from committed source without tests or
  SDKs; test invalidation for runtime, assets, manifests, fixtures and evidence.
- [x] P9.6 Execute every redistributed disk/fault/contract check and prove full
  inventory coverage. A smaller fast profile does not establish an overall speedup.

### P10 — Artifact reuse and phase measurements

- [ ] P10.1 Record relevant source/input identity, compiler, target/CPU, options,
  optimization profile, ABI/definition and output hashes for shared artifact sets.
  Prefer existing Zig/Nix artifacts to a new general-purpose cache framework.
- [ ] P10.2 Keep Debug and ReleaseSafe sets distinct. Pass immutable outputs to
  SDK builders and scenarios instead of depending on mutable `zig-out` contents.
- [ ] P10.3 Avoid repeated native/package work only for matching inputs. Never
  reuse test outcomes, mutable installations or incomplete build publications.
- [ ] P10.4 Add wrong-source/profile/definition and interrupted-build controls;
  verify concurrent callers cannot observe partial or mismatched artifact sets.
- [ ] P10.5 Record compilation, installation, packaging, provisioning, scenario
  execution and teardown separately, including failures and incomplete work.
- [ ] P10.6 Measure bounded concurrency for independent package checks while
  retaining each package's own manifest boundary and controlling resource use.
- [ ] P10.7 Evaluate local documentation cache reuse with clean production checks
  retained. Verify generated references/search/specification invalidation before
  adopting it; record a measured decision if no safe improvement is established.
- [ ] P10.8 Run the same required SDK schedules and compare work/time against the
  qualified baseline. Do not equate a profile switch with a compilation cache miss.

### P11 — Dependency-aware selection and resource scheduling

- [ ] P11.1 Extend current execution metadata with reviewed input/dependency and
  resource ownership, including shared fixtures, generated contracts and consumers.
- [ ] P11.2 Compute affected PR coverage transitively; shared/unknown inputs and
  unavailable comparison data must never silently select less qualification.
  Keep main/release full qualification and preserve both rename endpoints.
- [ ] P11.3 Exercise changed package, SDK, fixture, budget, model, contract, build,
  harness, evidence, deletion, rename and unknown-path selection controls.
- [ ] P11.4 Compare proposed scoped selections with full runs before enabling
  them. Document selection limits; a directory match is not a dependency proof.
- [ ] P11.5 Schedule heavy disk/build workloads within measured resource limits;
  keep formal feedback early and mutable outputs isolated. Preserve all scenarios.

### P12 — Qualification and final PR

- [ ] P12.1 Audit the complete migration map, final directory policy, task/scenario
  coverage, current links and immutable evidence hashes. Account for every original
  file and required execution, including deliberate replacements/consolidations.
- [ ] P12.2 Freeze the qualification inventory and relevant source/toolchain/
  workload profiles. Run affected complete/browser and external profiles as well
  as ordinary CI; state each scope and actual result explicitly.
- [ ] P12.3 Collect at least three successful ordinary warm samples and one
  dependency-cache-miss sample. Record GitHub cache and upstream Nix substitute
  conditions separately; one cold run does not establish cold variance.
- [ ] P12.4 Report first useful feedback, required completion, aggregate runner
  time, phase costs, cache transfer and relevant peak memory/disk pressure.
  Compare like workloads and publish remaining bottlenecks and regressions.
- [ ] P12.5 Establish current regression budgets from that evidence. Preserve
  the old 33-task qualification as historical; do not silently certify 103 tasks.
- [ ] P12.6 Finish owner README/AGENTS, contributor/task/toolchain documentation,
  and one concise qualification account with selected raw evidence. Keep current
  workflows discoverable without this plan or a chat transcript.
- [ ] P12.7 Clean up only this work's temporary clones, artifacts requiring no
  retention and stale branches/worktrees. Preserve user notes and unrelated work.
- [ ] P12.8 Submit the final review-ready PR with completed checklist, logical
  commit map, executed evidence and comparison results. Mark this plan Completed
  only when every required acceptance item is satisfied.

## Validation and completion policy

Use the pinned Nix environment. During each batch run the smallest meaningful
owning checks, then affected real callers/fault schedules from committed source.
Run clean check/lane qualification through `just ci clean`; a selected check is
not the complete suite. Preserve original failures and diagnostics before retry.
Do not increase deadlines, drop scenarios or weaken a budget to hide a regression.

Timing samples must identify their source, workload, toolchain, profile, backend,
machine and cache conditions. Compare a frozen scenario inventory. When a
necessary baseline bug fix changes behavior, apply the same fix to the comparison
basis before attributing a performance difference to this work.

Failure, cancellation, missing completion, skipped checks and unavailable external
infrastructure remain distinct. Unmet required gates keep this plan In Progress;
they are not automatically deferred to a later milestone or follow-up PR.

## Progress and evidence

| Stage | Status | Implementation and validation reference |
| --- | --- | --- |
| Delivered foundation | Completed | PRs #175–#181 above; each records its scoped qualification |
| P0 | In Progress | Repairs: `945101ead`, `251f15195`, `c61a3f546`. File-query oracle: 190 cases; native/port codec: 143 cases; ten installed consumers: four collation vectors each; TypeScript: 39 adapter tests; Python types pass. KV, direct Table and Document unified live schedules now pass across all ten SDKs. [Earlier run](https://github.com/spoke-sh/transit/actions/runs/40404745910) was canceled after stale adapter failures; [corrected frozen baseline](https://github.com/spoke-sh/transit/actions/runs/40409695176) at `e61ef1891` has passed core, formal, launcher and both SDK lanes. Growth also passed; the browser profile failed because its reactive-view Board configuration omitted the required collation vector. `f85a5edf2` repairs the fixture and the actual browser scenario passes locally. The same correction is applied to comparison revision `cbf04c0e7`; [replacement baseline](https://github.com/spoke-sh/transit/actions/runs/40423756480) is running. Neither earlier failed run is a successful full baseline. |
| P1 | In Progress | Runner, lane inventory, task coverage, CI cost policy and external-profile orchestration moved together; 26 fast checks pass, including real runner failure/interruption and clean-clone controls. The layout guard passes eight actual-file regression controls and the expanded 28-check fast profile; 775 enumerated migration exceptions remain. The 1,405-file disposition map is recorded; eleven layout controls cover duplicate destinations, missing dispositions and retained-evidence integrity. Dynamic task/artifact dependency auditing remains pending. Committed-source checks pass after the runner move. The final directory audit now accounts for all 1,405 original files, with 712 current test files, no migration exceptions and all 734 archived hashes verified; earlier counts describe intermediate batches. |
| P2 | In Progress | Linux child discovery/joining extracted in `e61ef1891`; real child-death and adopted-grandchild controls pass. All 29 fast checks pass from clean committed source. The shared Python launcher has real controls for moved drivers, subdirectory invocation, arguments, failures and installed-child import isolation; the catalog uses it and the expanded 30-check fast scope passes locally. All drivers now use domain-qualified imports and the supported launcher. `5442d843f` extracts private installation setup, frozen executable copies and manager cleanup into the harness; real child/isolation/restart and early-exit controls pass, and all remaining installation methods retain identical syntax trees. The expanded 31-check fast profile passes. The server schedule passes startup/configuration/host checks, then fails the SQL reply-observation control with `SqlOutcomeUnknown`; the private failed installation is preserved. Installation/provider qualification remains incomplete. |
| P4 | In Progress | 734 historical/generated records leave the current tree with immutable Git links and original hashes; archive integrity checks verify all original blobs. Twelve layout controls and 29 fast checks pass. Active budgets remain executable inputs; 22 Nix invalidation controls pass. Automatic per-task capture is implemented in `81823b2e5`: local and clean-source fast/contract runs preserve logs, exact generator inputs and verifiable completion; missing/changed artifacts and interruption controls pass. Hosted publication paths include these records with 14-day retention. Benchmark families and active budgets now use performance owners; shared HTTP instrumentation belongs to harness. All 30 fast checks and 22 Nix input controls pass, and the original active-budget hashes are unchanged. At `261595975`, seven ReleaseSafe native benchmark targets build; declarative, SQL and all file-query comparator workloads pass. Small physical-disk storage (36 samples) and ingestion/reopen (18 samples) profiles pass; these do not recalibrate default performance budgets. Remaining affected workloads, final hosted and packaged-runtime qualification are pending. |
| P3 | Completed | Forty formal runner, simulation, Zig fixture and corpus files moved to their owners with explicit imports and updated build/callers. All 24 saved replay JSON inputs retain their original hashes. The five-task formal lane passes: Authority 7,867 states and four replayed controls; WAL 201,771 states and six controls; Console 5,278 states / 91,198 replayed edges and six controls; Delivery and four Lean theorems pass. All 30 fast checks pass. Verification is now a navigation index; deterministic methods sit beside their scenarios and historical narratives retain an immutable source citation. Concrete schedules pass: 40 authority traces / 1,687 events, 14 delivery / 749, 204 resource / 3,958, eight scheduler / 542 and ten component schedules with identical replay. Mutation qualification exposed stale revision/permission patterns and a missing active-credential denial case; `bf9605ef0` and `3a4e3909d` repair those controls. All 19 production mutants are now detected across five campaigns from committed source. At committed `3a4e3909d`, the updated authority profile passes 41 traces / 1,697 events and the complete five-task formal lane passes; automatic artifacts are retained locally. |
| P5 | In Progress | 158 scenario, ABI, installer and language-consumer files now have SDK ownership. Dynamic imports, copied compiler inputs, isolated retry processes, scenario catalogs and task/build callers follow the move. At `eb72e53f2`, all 30 fast checks and the complete 11-task bindings-1 lane pass from clean committed source, including native boundaries, installed Python/Node/Rust/Ruby consumers, the complete ten-edge language ring, SQL oracles, gRPC faults and connector preparation. The second SDK lane and final-source qualification remain pending. |
| P6 | In Progress | 161 Python/Node/C interface drivers, inputs and guides move under native, CLI, Board, SQL, serving, installation and deployment owners. Import roots, generated fault wrappers, nested capacity invocations, Node imports, build/task callers and contract validators follow the move. Fast (30) and compiled contract (18) scopes pass locally. The remaining native fixtures now use 53 explicit shared modules across domain owners, including embedded gRPC descriptors and generated provider-root paths. Integration probes and all nine provider executables compile; gRPC generation and 3,411 diagnostic outcome projections pass. Real interface/fault qualification remains pending. |
| P7 | In Progress | 51 catalog/query drivers and SQL guides now have domain ownership, with independent SQL helpers qualified explicitly and installed fault peers kept standalone. Fast checks pass. The actual SQL aggregate passes 174 compiler ASTs, 142 plans/Arrow results, 72 unified results, 280 DDL cases, 44 DML cases and parameter controls; independent grammar and all four Lean rewrite theorems pass. Native fixtures now use explicit cross-domain modules with shared type identities. The private operation driver compiles; live domain qualification remains pending. |
| P8 | In Progress | 49 storage/runtime drivers and shared ABI/artifact helpers move to explicit owners. Backend choices, saved operation identities and schedules are preserved. The audit places Station provisioning, delivery receipt controls and query recovery assertions with their actual semantic owners. All 30 fast checks and 23 Nix input-selection controls pass. All 109 remaining Zig files move, provider-backed page/growth/collection tests are classified separately from local storage, and the structural page-layout experiment belongs to performance. The final root contains only the two indexes and 12 owners. The actual local direct Table schedule passes 1,942 typed calls, including retained history, current-policy denial, exact retry and three restarts. All redistributed native scopes now pass: 34 component roots (including physical-disk tests), 14 independent fixture/codec groups and four process-fault groups. Native fault schedules include 92 WAL/Table crash boundaries, 15 collection cases and three 12-race object-publication schedules. Remaining Ursula/application qualification is pending. |
| P9 | In Progress | `f902b7a0a` separates runtime/test registration while retaining all 188 previous named steps. At committed `d326243ac`, actual Transit and SQL gateway packages build and run without test/SDK source, and disabled/missing checks reject; 23 source-invalidation controls pass. `61a63e235` partitions all 52 original aggregate edges into explicit component, fixture and fault scopes with automatic capture; all three scopes pass. Clean fast qualification passes at that commit. Full package/duplication auditing remains. |
| P10 | In Progress | Clean setup previously waited 466.7 seconds behind a concurrent Nix evaluation-cache reader; `7207c6f61` bypasses that mutable cache while preserving store/compiler caches. The actual clean run at `61a63e235` spends 4.1 seconds entering the shell and 26.6 seconds on 30 checks; these are scoped observations under concurrent host work, not a whole-suite benchmark. `a7734ae8d` adds a passing real isolated cache-lock/value-preservation control. Remaining artifact and phase work is unchecked above. |
| P11–P12 | Planned | Checklists above; no complete execution or performance qualification claimed |

The final PR closes the work only when the proposed structure exists, every
required scenario has an executable owner, source-clean checks pass, retained
evidence is intact, and measured workflow improvements preserve coverage.
