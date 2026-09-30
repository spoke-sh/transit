# Validation and milestone evidence

Evidence is scoped to each recorded revision or definition. “Current” in an
earlier entry refers to that entry's source, not automatically to HEAD. The latest
[publication-domain cutover](#publication-domains-and-coordinated-caller-cutover)
records its reruns and remaining qualification separately; earlier consolidation
results do not qualify the changed stored layout by inheritance.

## Declarative benchmark components

The [component harness](benchmarks/README.md) measures synthetic SQL compilation,
paged Fuze/Arrow execution, declarations and private Station mutation proposals.
It enumerates all 151 full-workload units across TPC-C/E/H/DS as blocked.
Component correctness never changes full-suite coverage or implies a TPC score.
Executed in the pinned development shell, using locked frontend dependencies:

- Eight report/inventory tests pass, including missing/duplicate results,
  incompatible definitions, wrong build mode, absent timings and failure reports.
- The 28 components pass independent SQLite/PyArrow results, declaration schema
  checks and mutation-byte oracles. Smoke runs cover zero rows/page width one,
  one null row, 17 rows with the maximum uint32 seed, and 257 rows/page width
  three. Nine exact rejection probes pass; `--require-full` exits 2.
- `just test::sql` passes its 49 public examples, 104 SELECT AST cases,
  86 plan/Arrow cases, 24 unified results, 31 mutation cases and 182 declaration
  cases. These remain component/grammar proofs, not complete TPC execution.

Full `just check` passes, including the unit/protocol checks, 346 CLI diagnostic
cases, generated contracts, frontend tests/types and production handbook build.
The final report tests and a 17-row/three-row-page smoke pass after report
validation was tightened to reject missing timings and retain decoded outputs.
Logs: `/tmp/transit-benchmark-check.log`, `/tmp/transit-benchmark-sql.log`,
`/tmp/transit-benchmark-smoke.log` and `/tmp/transit-benchmark-final-smoke.log`.

At clean committed source `8446688afda8d0662bea1503ec8151fd3a6ac942`,
`just test::declarative-benchmark` passes all 28 components and nine blocker probes
with five samples, 8192 synthetic rows, eight-row pages, seed 42, ten query
executions and 2000 compilations/proposals. The
[retained report](benchmarks/results/2026-09-30.json) has `dirty: false`, all 52
timed phases, independently verified query outputs and mutation proposals,
fixture/build/source hashes and host metadata. Binary SHA-256 is
`4b8457964e12931d1058c2149d6483676e54618890863bb45959d600e2023e19`.
The [public summary](../docs/reference/benchmarks.md#recorded-component-measurements)
reports the exact scope and shared-host limits. Measurement log:
`/tmp/transit-benchmark-measurement.log`. These are unpaired component timings;
all 151 complete-workload units remain blocked. Native authority, disk durability
and public transport latency are outside this harness's measured boundary.
A separate fresh clone of `95d0107797551fbf6e4c7d0a47c72aa0e26830c1` builds
`transit-declarative-benchmark` without inherited workspace outputs and passes
all component oracles with 257 rows, three-row pages, one sample/execution and
50 compilations/proposals. The copied report is
`.cache/verification/benchmarks/clean-smoke.json` with `dirty: false`.
Broader committed-HEAD clean-lane outcomes are recorded in PR #38 after
those runs; they do not expand the benchmark's execution boundary.

After rebasing onto `main` at `4c22b426058c7299af62a8cba03ab5925336ba44`,
the default measurement repeats at clean source
`bc9476ba7c9613df625a28e9277bf10e568e0f6c`. The
[second raw report](benchmarks/results/2026-09-30-main.json) retains five samples,
all 52 timed phases and the same 28 passing components/nine rejection probes.
The executable, fixture, manifest, harness, driver and lock hashes match the
earlier report, as do independently decoded query outputs. The new SDK catalog
metadata readers do not change the measured Fuze/Station implementation or
remove any full-workload blocker. Both reports preserve their original source
identity; the public summary uses this repeat without claiming a speedup.
Log: `/tmp/transit-benchmark-rebased-measurement.log`.

The rebased executable also passes zero-row/one-row-page, one-null-row,
maximum-uint32-seed and 257-row/three-row-page cases; `--require-full` writes a
component-success/full-workloads-blocked report and exits 2. These focused
runs use one sample/execution and 50 compilations/proposals; documentation/report
updates are present in the working tree and their reports record `dirty: true`.
Log: `/tmp/transit-benchmark-rebased-edges.log`.

With these report/documentation updates, `just transit-board::install`, full
`just check` and `just test::sql` pass in the pinned shell. This includes all
eight report tests, 399 CLI diagnostics, generated contracts, frontend checks,
the production handbook and the same SQL case counts listed above. Log:
`/tmp/transit-benchmark-rebased-check.log`. Committed-HEAD clean-lane outcomes
remain separately recorded in PR #38; earlier clean runs do not qualify
the rebased source by inheritance.

## Handbook grammar inventory and implementation plan

The documentation-first work for issue #31 starts from PR #27's pushed
`9051f0a4209b874ebb4c1ba69aecd50fa7c8225a`. The handbook checkpoint `37996e4f`
adds the public implemented/planned inventory and navigation, corrects stale
state-declaration descriptions, and reconciles system-time comments without
changing any accepted grammar rule or production execution. M38 now consumes
that inventory with staged ledger/semantic/historical work and explicit exits;
no runtime work package is marked complete by this documentation.

Executed in the pinned development shell with locked frontend dependencies:

- Full `just check` passes for the handbook checkpoint, including generated
  contracts, unit/CLI checks, frontend types/tests and production documentation.
  The documentation check reports 4642 local links across 484 files.
- `just test::sql` passes: 49 published SQL examples, 104 SELECT AST comparisons,
  16 syntax exclusions, 14 extensions, 86 actual plans/Arrow checks, 24 unified
  results across three bases/eight page widths, 31 mutation outcome/rejection
  cases, and 182 declaration cases. Proposed syntax uses explicitly labeled text
  blocks; these checks do not accept or qualify the proposed graph/branch forms.
- The initial `just transit-docs::browser` run has two passes and two failures:
  inherited assertions expect the SQL index's old label and still describe
  CREATE TABLE as grammar-only. `7316a9e5` corrects those expectations, retains
  the grammar-only connection check and exercises the new inventory through
  navigation/search with distinct Table-publication and KV/Document labels.
  The corrected root-hosting run passes all four browser tests in 15.6 s.
- `just transit-docs::check` passes after the browser changes; the subsequent
  repository link check, including the roadmap sequence, passes 4647 links
  across 484 files. These are working-tree documentation results, not new
  runtime qualification.

Committed-HEAD `just ci-clean --lane experience` at `37996e4f` **fails** in
`transit-board::query-test`: `tests/board_query.py` receives HTTP 503
`Unavailable` while observing an upload. Board check, documentation check, Node
binding check, observability and Board inspection pass first; the final local
Station launcher task does not run. The failed checkout and task timings remain
at `/var/tmp/transit-ci-e1al9pr1`; the log is
`/tmp/rey-grammar-ci-clean-inventory.log`. A focused rerun of the unchanged query
test in that checkout fails with the same response; its log is
`/tmp/rey-grammar-query-rerun.log`. The failure is unresolved. Neither that run
nor the focused documentation/browser passes establish a clean-lane or complete
clean-suite pass. No graph, foreign-capture, historical-query, branch, merge or
standards-conformance execution is claimed.

## Conditional declarative catalog

The additive `transit-catalog` package composes Fuze's declaration compiler with
Station's existing two-column Table and four-mutation turn. It publishes the
Table descriptor, immutable definition, name binding and attributed receipt at
one commit. It is an explicit Zig integration API; the initial helper proofs do
not establish a supplied catalog host, signed caller, SQL administrative endpoint
or CLI/SDK route. The signed caller's separate evidence is recorded below.
Native/ABI definitions and existing stored formats
are unchanged. The [contract](../contracts/DECLARATIVE_CATALOG_V1.md) owns the
current profile; `SQL-CATALOG-01` maps its proof obligations.

Executed in the pinned bindings shell on development source based on `ef3053af`:

- Standalone `transit-catalog` `zig build test` passes ten component tests.
  Independent Python fixtures pin every record kind, key and definition digest.
  Tests cover full-width application IDs, mandatory definition checks, orphan
  namespace/row refusal, exact application retries, changed intent, three terminal
  conflicts, separate conditional policies, changed scope/schema/digest, private
  rollback and poisoned reads at every point-read boundary. A successful new
  creation performs seven private point-read callbacks, one bounded row-prefix
  page check and four writes. A private mutation before creation rejects the
  committed page check; a page-read failure poisons the turn.
- A dynamic-map component store holds 257 objects and lists them in 33 pages,
  each with at most eight definitions. Changed revisions, revoked inspection,
  private writes and malformed page shapes reject. This is bounded helper
  evidence, not native disk growth or performance evidence.
- Full `just check` passes, including package/unit and generated contract checks,
  frontend checks/tests and the production documentation build. This run preceded
  registration of the native proof and the following evidence documentation.
- Final `just check-core` passes after the orphan-row check. The independent
  `just test::sql` oracle also passes, including 182 declaration cases and the
  existing SELECT, unified-source and mutation schedules. Inventory/docs checks
  cover 52 invariants, 52 classified bounds, 12 SDK scenarios and 4509 links
  across 474 files.
- `TMPDIR=/var/tmp just test::catalog` passes against the real native authority
  and disk-backed Ursula. It loses one accepted caller-send receipt and one
  owner-commit receipt, restarts node/storage separately at both boundaries, and
  recovers the original frozen signed requests and exact receipts. An independent
  Python oracle checks all four stored records at one resource revision. Input
  progress, no-write application duplicates and terminal name conflicts agree.
  Changed native retry, stale ownership, revoked write authority and revoked
  reads reject; restoring write permission permits the same unaccepted request.

The final native schedule takes **2.406 seconds** with **155 reads**, **6 accepted turn
responses**, **8 resident authority pages**, at most **4 mutations** and **127
value bytes** for this fixture. Component maximum-name fixtures separately check
138-byte requests, 163-byte definitions and 155-byte receipts. The native timing
includes provisioning/recovery and is not a service latency or throughput result.
The report `.cache/verification/catalog/native.json` records source/dirty status,
counts and frozen binary hashes:

| Binary        | SHA-256                                                            |
| ------------- | ------------------------------------------------------------------ |
| Node          | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Catalog proof | `ac649f3e3410924cb1e03c58da4e1c975f8e209b6e3907f21fc280955be1f7a9` |

Logs are `/tmp/transit-sql-catalog-orphan-components.log`,
`/tmp/transit-sql-catalog-check.log`, `/tmp/transit-sql-catalog-final-checks.log`
and `/tmp/transit-sql-catalog-orphan-native-check.log`.
The native proof is registered in the growth lane. It creates two applied Tables;
it does not establish native catalog growth, host power-loss recovery or installed
caller compatibility. Native page scans may cross the catalog prefix; the helper
does not decode or return those other values, but cannot promise zero row-byte
I/O at the boundary. Current proofs do not qualify the remaining declaration,
dependency, lifecycle, maintained-query or effect systems.

At committed `97378a8e`, **`just ci-clean --lane core` passes all 18 tasks**
without inherited workspace build outputs in **702.52 seconds**. Independent
package builds take 139.81 seconds, Station 148.66 seconds and disk storage
213.72 seconds, including the 129.21-second readiness write. Completion metadata
and per-task results are retained under
`.cache/ci/clean/97378a8e43a2-transit-ci-twnd5sz1/`; the log is
`/tmp/transit-sql-catalog-ci-clean.log`. The following evidence-only commit changes
no production code. This is a clean core-lane pass plus the focused native/SQL
proofs above, not a complete clean-suite or administrative-surface qualification.

### Shared signed catalog caller

The additive `transit-catalog.Client` now prepares owned signed creation commands,
restores exact saved bytes, submits explicitly and separates admission/input
processing from original-request status. Description and status use bounded
current native metadata batches; they retain no snapshot or permission cache.
This does not enable a supplied host, neutral ABI, CLI or language SDK route.

On development source based on `97378a8e`, both new caller component tests pass
alongside the ten helper tests. They verify full-width identities, owned restored
bytes, canonical complete input, missing/foreign nested definitions and local
connection/signature rejection before transport. Full `just check` passes,
including 52 invariants, 53 classified bounds, 12 SDK scenarios, 4509 local links,
frontend checks/tests and the production documentation build.

The expanded `just test::catalog` schedule uses the shared caller for preparation,
saved-command restore, submission, observation and status. It preserves the exact
prepared bytes after caller/node/store replacement, returns pending/null before
application and processed/applied afterward, retains the original attributed
receipt on an application duplicate and rejects changed operation intent. Current
catalog inspection revocation hides old status while native reads still work;
revoked create policy blocks preparation while inspection remains available.
Native read revocation also prevents status disclosure. The earlier atomicity,
conflict, owner fencing and lost native receipt cases remain in the schedule.

The run passes in **3.310 seconds**, with **227 reads**, **9 accepted turn
responses**, eight resident pages, four mutations and 127-byte maximum fixture
values. It adds policy and observation operations, so its duration is not an
equivalent-workload comparison with the helper-only run. The proof binary SHA-256
is `a81fbd9cb9662196c91df512d4a6740e334e0dd7b7a85730ba9ac28c9ba6a82d`;
the node hash is unchanged. Logs are `/tmp/transit-sql-catalog-client-components.log`,
`/tmp/transit-sql-catalog-client-native.log` and
`/tmp/transit-sql-catalog-client-check.log`. This development evidence does not
extend the preceding committed clean checkpoint to the caller changes.

At committed `149bbe41`, **`just ci-clean --lane core` passes all 18 tasks**
for the signed caller in **717.91 seconds**. Package checks take 141.36 seconds,
Station 146.71 seconds and disk storage 229.67 seconds. Exact revision,
completion and per-task evidence are retained under
`.cache/ci/clean/149bbe41f0a0-transit-ci-l0fprhu0/`; the log is
`/tmp/transit-sql-catalog-client-ci-clean.log`. The following evidence-only commit
changes no production source. This qualifies the core lane and the focused caller
schedule above, not a full clean suite or a supplied catalog host.

### Supplied catalog host and explicit committed sources

The `catalog` role in the supplied `transit-query-host` now runs the shared
catalog behavior through GenServer. Initial framework/configuration/policy/input
disposition publication fits one four-mutation turn. Creation keeps its original
operation receipt; policy controls and rejected inputs retain separate attributed
dispositions. No neutral administrative ABI or CLI/language SDK route is implied.

`Turn.committed()` supplies the initialization composition's explicit read-only
captured source. A new Station component test proves private inserts, updates and
deletes stay out of both its point reads and pages, its view binding cannot change,
reader failures poison the original proposal, and ordinary Table/Turn pages still
reject after private mutations. The standalone Station tests pass. Catalog
components pass 17 tests, including independent policy-command/disposition bytes,
three-write helper composition, four-write behavior initialization, whole-proposal
rollback, process/effect-origin rejection, stale controls, manual-catalog adoption
refusal and poison at every behavior point-read boundary. Those private-store
tests do not independently establish native authority or durability.

On development source based on `bea9ed2f`, the expanded **`just test::catalog`
passes against the actual supplied host** and disk-backed Ursula. It loses the
host's initialization and creation commit receipts separately, holds exact retries,
kills the worker, restarts node/storage, and recovers each original signed commit
and receipt. Independent Python bytes verify the complete four-record initial
publication at one resource revision. Reusing the old activation rejects;
replacement workers run under fresh ownership. Duplicate initialization leaves
policy unchanged. A revoked create policy causes a recorded denial even for a
raw signed input that bypasses caller preparation. A later authorized input can
apply the same operation while the original input disposition remains unchanged.
Current native read denial also protects the signed caller's disposition API.
The earlier manual-owner and signed-caller schedules still run in the same proof.

The schedule takes **6.712 seconds**, with **512 reads**, **18 accepted turn
responses**, one lost caller receipt, three lost owner receipts, eight resident
authority pages, four mutations and a 127-byte maximum fixture value. It creates
four applied Tables across two resources. The read count includes host polling
and proof inspection; this expanded schedule is not an equivalent-workload
latency comparison or a native catalog growth/power-loss proof. The catalog role
allocates neither the query host's 4 MiB Arrow workspace nor its 1 MiB source
adapter. ReleaseSafe binary hashes are:

| Binary        | SHA-256                                                            |
| ------------- | ------------------------------------------------------------------ |
| Node          | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Catalog proof | `7a1070c7f73412109396917041bfb136c0cde0b99a6c154dc496f78194db810e` |
| Supplied host | `85aab2f0bd50c9e37f2cca4367dbb5fa028137a962ddd96526554fdbaf4a1c0d` |

The first native attempt failed in a fixture metadata read with
`StaleStateResource`: policy publication advanced the resource between acquiring
its revision and reading a disposition. The fixture now uses the shared atomic
metadata-batch API, preserving stale-cut rejection. Failure and corrected logs
are `/tmp/transit-sql-catalog-host-native.log` and
`/tmp/transit-sql-catalog-host-native-batches.log`. Full `just check` also passes,
including package/contract checks, frontend checks/tests and the documentation
build (`/tmp/transit-sql-catalog-host-check.log`). The real `just test::station`
regression also passes, covering Tables, exact retries, policy changes, captured
Arrow replies, worker/store recovery, fencing, registry, supervision and lifetime
(`/tmp/transit-sql-catalog-host-station.log`). Final independent SQL, documentation
and inventory checks pass: 182 declaration cases, 31 mutation cases, 4513 local
links across 474 files, 52 invariants, 53 classified bounds and 12 SDK scenarios
(`/tmp/transit-sql-catalog-host-final-checks.log`). The final component run also
passes after expanding read-failure injection across initialization, creation and
policy controls (`/tmp/transit-sql-catalog-host-poison-final.log`).
No existing native/ABI definition or
stored record layout changes; commands/dispositions and the explicit source are
additive, and existing creation requests keep their exact bytes.

At committed `fefb42c3`, **`just ci-clean --lane core` passes all 18 tasks**
for the supplied host and explicit committed source in **727.49 seconds**.
Independent package builds take 142.97 seconds, Station 148.36 seconds and disk
storage 230.44 seconds. The readiness write takes 147.48 seconds. Exact revision,
completion and per-task results are retained under
`.cache/ci/clean/fefb42c33b92-transit-ci-2j8mr2ji/`; the log is
`/tmp/transit-sql-catalog-host-ci-clean.log`. The following evidence-only commit
changes no production source. This is a clean core-lane pass plus the focused
host proof above, not a full clean suite or administrative CLI/SDK qualification.

### Signed initialization and policy controls

The shared catalog caller now prepares initialization and conditional policy
commands, using the same owned `Prepared` envelope, exact submission, input
observation and current-policy disposition reads as creation. Initialization
checks its connection/configuration binding; policy preparation reads the exact
configuration and target policy in one current native batch. The configured
administrator can restore application rights after self-revocation, while
disposition inspection remains denied until the restoration applies. Existing
creation bytes, native/ABI definitions and stored record layouts are unchanged.

On development source based on `3dea7fad`, standalone catalog tests pass **18
named component cases** (19 including the root import test). The saved-command
matrix now covers initialization, creation and full-width policy revisions,
owned restoration, missing/foreign definitions, altered identities and canonical
input. Invalid administrator/owner/scope and policy revisions reject before
transport. Full **`just check` passes**, including generated contracts, frontend
checks/tests and the production documentation build; later proof/documentation
edits receive their focused checks.

The final **`just test::catalog` passes in 9.918 seconds**, with **776 reads**,
**25 accepted turn responses**, two lost caller receipts and three lost owner
receipts. It restores a saved initialization send after caller/node/store
replacement, then preserves the supplied host's initialization/creation recovery
schedule. Two controls prepared at the same policy revision queue before the host
starts: the second records `stale_policy` after the first changes policy. Separate
target principals, absent-policy creation, exact policy duplicates and stale
preparation checks pass. Self-revocation denies creation and disposition reads;
duplicate initialization cannot restore those rights, but an explicit next policy
can. Four Tables, eight resident authority pages, four mutations and the fixture's
127-byte maximum value remain unchanged. The added controls, restart and polling
make this an expanded recovery schedule, not an equivalent-workload speed result.

The first control run returned `CatalogDenied` when the fixture attempted result
inspection before restoration had been processed. The fixture now waits for
explicit input observation before acquiring a newly authorized disposition;
the caller's current-policy rejection is preserved. The ordered run passes, then
the final run above adds independent target-principal cases. Logs are
`/tmp/transit-sql-catalog-controls-components.log`,
`/tmp/transit-sql-catalog-controls-check.log`,
`/tmp/transit-sql-catalog-controls-native.log` (failed),
`/tmp/transit-sql-catalog-controls-native-ordered.log` and
`/tmp/transit-sql-catalog-controls-native-targets.log` (final pass).
The proof binary SHA-256 is
`3d7ac8adf5b9a0d4d782b40c48bfbd3d26529f3c6bf882595cca550dfa3c798e`;
node and host hashes match the supplied-host entry above. This development result
does not extend that earlier clean checkpoint or qualify neutral administrative
bindings, CLI/SDK routes or general SQL grants.

At committed `98ddd4cb`, **`just ci-clean --lane core` passes all 18 tasks**
for signed administrative controls in **702.27 seconds**. Independent package
builds take 140.97 seconds, Station 149.08 seconds and disk storage 211.88 seconds.
Completion and per-task evidence are retained under
`.cache/ci/clean/98ddd4cbad77-transit-ci-cjfwraqj/`; the log is
`/tmp/transit-sql-catalog-controls-ci-clean.log`. This qualifies that committed
control caller and core lane, not the subsequent neutral bridge or native ABI.

### Neutral catalog caller values

The shared `Bridge.Action`/`Result` now covers offline creation compilation,
description, signed initialization/creation/policy preparation, exact submission,
observation and separate application/disposition reads. Full-width IDs and policy
revisions cross JSON as canonical decimal strings; native counters remain bounded
numbers and saved commands remain opaque. It delegates remote behavior to the
existing signed client and defines no new native/stored format.

Standalone catalog tests pass **21 total tests** including the root import test
on development source based on `98ddd4cb`. Two new bridge cases compare typed
neutral values with independently generated Python records, preserve owned names
and full-width values after source mutation, and reject numeric application IDs,
quoted native IDs, malformed decimal strings, changed scope and invalid saved
commands before transport. The local compile/capabilities cases use no transport.
The generated fixture owner is `tests/catalog_contract.py`; component output is
`/tmp/transit-sql-catalog-bridge-components.log`. Native ABI/port and idiomatic
language reachability are not established by these component tests.

### Catalog C ABI and native port

The additive `station_catalog_create/call/destroy` exports and `catalog_client`
port profile use the neutral bridge and shared signed client. Catalog calls
validate local recovery before dispatch and preserve `uncertain` after a valid
submission has begun. One operation per handle, bounded I/O, joined destruction,
key wiping and independently owned result buffers follow the existing binding
contract. Three new generated schemas and the optional catalog host profile are
propagated to every generated language resource. Comparing parsed ABI contracts
with the preceding revision shows no existing export-signature, status, definition
or existing schema change outside additive `HostConfig`/`HostRequest` fields.

On development source based on `d7b99144`, standalone binding tests pass **12
tests**, including the new catalog output-ownership, overlap, malformed recovery,
signature rejection and uncertain transport case. Full **`just check` passes**,
including contract generation/drift, native units, frontend checks/tests and the
production documentation build. `just bindings::node-check` passes its strict
TypeScript checks and 17 tests. Logs are
`/tmp/transit-sql-catalog-abi-components.log`,
`/tmp/transit-sql-catalog-abi-generate.log`,
`/tmp/transit-sql-catalog-abi-check.log` and
`/tmp/transit-sql-catalog-abi-node-check.log`.

The expanded **`just test::catalog` passes in 13.799 seconds**, with **1075
reads**, **33 accepted turn responses**, four lost caller receipts and three lost
owner receipts. Both a real C ABI handle and native-port child compile the same
independently encoded creation record, apply typed initialization/policy controls,
recover an unchanged saved send after caller/node/store replacement and preserve
the original creation outcome. The port is killed during uncertainty. Mixed
profiles, catalog calls on a query profile, numeric full-width IDs and quoted
native numbers reject. Current application inspection and native-read revocation
each hide earlier outcomes through both transports. Explicit port shutdown joins
cleanup. Earlier manual/shared-Zig and supplied-host cases remain in the schedule.

This run creates six Tables across two resources with eight resident authority
pages, four mutations and a 132-byte maximum fixture value. Its expanded work and
polling count do not establish an equivalent-workload speedup, catalog growth or
power-loss guarantee. The report remains `.cache/verification/catalog/native.json`;
the log is `/tmp/transit-sql-catalog-abi-native.log`. ReleaseSafe binary hashes:

| Binary        | SHA-256                                                            |
| ------------- | ------------------------------------------------------------------ |
| Node          | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Catalog proof | `3d7ac8adf5b9a0d4d782b40c48bfbd3d26529f3c6bf882595cca550dfa3c798e` |
| Catalog host  | `85aab2f0bd50c9e37f2cca4367dbb5fa028137a962ddd96526554fdbaf4a1c0d` |
| Native port   | `37b44139c09058e863d63c07a3cc78aa7edb803fb48b4ed2eafe384a8df68091` |
| Station ABI   | `98c76da16161abae1ab0fb1f91a9d2613f720b6acabb8e81c729fc9b3c7585f1` |

`just bindings::native` also passes the existing native/port local-codec,
gated-control, scoped-page, capture, exact host/disk recovery, current-policy,
Arrow query and materialization schedules
(`/tmp/transit-sql-catalog-abi-regression.log`). All eight language-package build
recipes pass, covering Python, TypeScript, Rust, Ruby, C/C++, Java, .NET and
Erlang/Elixir against the regenerated resources
(`/tmp/transit-sql-catalog-abi-sdk-builds.log`). These are package builds, not
installed catalog SDK qualification. Final docs/inventory/format checks pass
4521 local links across 475 files, 52 invariants, 53 classified bounds and 12 SDK
scenarios (`/tmp/transit-sql-catalog-abi-final-checks.log`).

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at `2ecf2457`**
with no inherited workspace build outputs, in **701.65 seconds**. Independent
packages take 141.20 s, Station 147.35 s and disk storage 213.40 s. Evidence is
`.cache/ci/clean/2ecf24572ae5-transit-ci-62kkqyq2/core.json` and
`core.meta.json`; the full log is `/tmp/transit-sql-catalog-abi-ci-clean.log`.
The following evidence-only commit changes no production code. This is a clean
core lane plus the focused native/port schedule above; it does not qualify
idiomatic catalog SDKs, a catalog CLI or a complete clean suite.

### Explicit catalog CLI

`transit catalog` now uses the shared neutral bridge and signed caller. Offline
compilation accepts a scope-only connection without loading a key or contacting
an endpoint. Initialization, creation and conditional policy preparation require
new private saved artifacts; submission restores those exact commands. Typed
compiled fields must agree with current-definition canonical bytes. Input
processing, control/rejection dispositions and original creation outcomes remain
separate. The extracted private-file writer also preserves mutation CLI behavior.

On development source based on `8054f127`, the expanded **`just test::catalog`
passes in 15.439 seconds**, with **1204 reads**, **36 accepted turn responses**,
**five lost caller receipts** and **three lost owner receipts**. The added CLI
case uses its own 0600 output files again after caller/node/store replacement,
recovers the exact admission receipt and original creation result, then rejects
status disclosure after catalog inspection and native read revocation. The
schedule exercises seven applied Tables across two resources; maximum mutations
remain **four**, maximum fixture value **132 bytes** within the 256-byte bound,
and the authority uses **eight resident pages**. This enlarged recovery schedule
includes provisioning and polling; it is not a latency comparison, native catalog
growth proof or host power-loss guarantee.

The report is `.cache/verification/catalog/native.json`, with source revision,
dirty status and frozen executable hashes. The log is
`/tmp/transit-sql-catalog-cli-native.log`. ReleaseSafe node, proof and catalog-host
hashes match the preceding ABI schedule. Updated caller hashes are:

| Artifact        | SHA-256                                                            |
| --------------- | ------------------------------------------------------------------ |
| Native port     | `4bc5ed8c56b5302379c6c597ecd55d7bfecf89c86ffb4e03c63e864edf754622` |
| Station library | `3d668634629fe306a9628ea11b50ebd790783686a333e8e87a37980eb9083b93` |
| CLI             | `2a53d92f5383f3a3b9002531262272437fc6eaff900a1b145a9c02a6d4222572` |

The real CLI diagnostics now cover **346 cases**, including JSON/YAML offline
compilation, full-width IDs, file privacy/non-replacement, malformed and foreign
artifacts before key loading, invalid options and offline help. This extends
caller evidence; idiomatic catalog SDKs and native catalog growth remain.

Full **`just check` passes**, including generated contracts, 346 diagnostics,
4534 local links across 476 files, the verification inventory, frontend tests
and the documentation build (`/tmp/transit-sql-catalog-cli-check.log`). The
existing native/port/CLI **`just test::table-mutation` passes in 23.776 seconds**,
including exact saved-file recovery after the writer extraction: 1664 reads,
48 accepted turn responses, four lost caller receipts and one lost owner receipt,
four mutations, 256-byte values and eight resident pages. Its frozen CLI/library
hashes match this catalog run; its log is
`/tmp/transit-sql-catalog-cli-mutation-regression.log`. These are development
checks and focused proofs; committed-HEAD clean validation follows separately.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at `e107fe7d`**
without inherited workspace build outputs, in **710.32 seconds**.
Evidence is `.cache/ci/clean/e107fe7df44b-transit-ci-48en01yu/core.json` and
`core.meta.json`; the full log is `/tmp/transit-sql-catalog-cli-ci-clean.log`.
The following evidence-only commit changes no production code. This qualifies
the CLI core lane and focused recovery above, not idiomatic catalog SDKs or a
complete clean suite.

### Python catalog callers

The typed Python `catalog.Client` and `AsyncClient` compose the shared catalog
ABI. Immutable owned values retain full-width application IDs, current native
bounds and exact opaque prepared bytes. Both callers separate admission, input
processing, control/rejection dispositions and original creation receipts.
Cancellation of an await leaves the native worker owned; close joins cleanup.

On development source based on `e107fe7d`, strict mypy passes **22 source files**,
matching Python wheels build, and **`just test::catalog --sdk python` passes in
22.855 seconds**, including **1.859 seconds** of isolated package installation.
The script copies and hashes four wheels into the fixture, installs without
checkout imports, and uses both public synchronous and asynchronous APIs.
Initialization and conditional policy controls precede full-width creation;
lost admission recovery replaces caller/node/store and restores original saved
commands. Original-request status, current catalog-policy denial and current
native denial pass through every caller.

The combined schedule performs **1515 reads**, **42 accepted turn responses**,
**seven lost caller receipts** and **three lost owner receipts**. It creates nine
applied Tables across two resources, with **four mutations**, **133-byte maximum
fixture values** and **eight resident authority pages**. These times include
installation, provisioning and recovery; they do not establish latency targets,
equivalent-workload speedups, native catalog growth or host power-loss recovery.
All six frozen executable hashes match the preceding CLI schedule. The package
hashes in `.cache/verification/catalog/native.json` are:

| Wheel                    | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station`        | `7bd67ecab612be7df8204b181d2c1a5cdb37288c09d0da3fab6b3fbed3e23da5` |
| `transit-native-station` | `5380949f2c664d9418734f2f348fe37a304763fda1de9b4b341fe975d95ef022` |
| `transit-client`         | `be974f85e6ba910846dad633b5cdbb390e619a88bccbbefea72a83f865a48cc7` |
| `transit-native-client`  | `72ee6e0924bb4f9479fe630450dcefddd5f6d450d9489429f38a9b45b1252ba3` |

The installed value test independently checks byte/name ownership, canonical
full-width response strings and numeric types, malformed success responses and
injected response allocation failure preserving submission uncertainty. A blocked
adapter verifies cancelled-await overlap rejection and joined destruction. Those
injected cases establish Python ownership/error behavior, not authority outcomes;
the real disk schedule establishes exact admitted-command recovery separately.

Full **`just check` passes**, including generated resources, 346 CLI diagnostics,
4544 local links across 477 files, 52 invariants, 53 classified bounds, 13 SDK
scenarios, frontend checks and documentation build. Logs are
`/tmp/transit-sql-catalog-python-final-native.log` and
`/tmp/transit-sql-catalog-python-check.log`. The focused
`just bindings::catalog-python` recipe builds and runs this installed schedule;
`bindings::python-test` also includes it. Other nine idiomatic catalog SDKs and
committed-HEAD clean qualification for this Python increment remain separate.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at `70919367`**
without inherited workspace build outputs, in **706.64 seconds**.
Evidence is `.cache/ci/clean/70919367bbec-transit-ci-cian9wcj/core.json` and
`core.meta.json`; the full log is `/tmp/transit-sql-catalog-python-ci-clean.log`.
The following evidence-only commit changes no production code. This qualifies
the core lane plus the installed Python schedule above, not a complete clean
suite or the other nine catalog SDKs.

### TypeScript catalog caller

The public TypeScript `catalog.Client` uses the existing owned native port and
shared generated catalog request/result schemas. Frozen typed declarations and
controls retain full-width `bigint` identities; canonical byte getters return
copies and prepared text stays opaque. The client distinguishes original creation
receipts from input dispositions and preserves uncertain submissions, including
malformed successful native responses. Status decoding checks the complete
original request. No shared protocol definition changes.

On development source based on `70919367`, **`just bindings::node-check` passes
28 tests**, including 11 new catalog value/port-boundary cases and existing
mutation/runner ownership tests. Cases cover mutable input copies, native-number
versus bigint boundaries, invalid revisions, unknown observations, malformed
admission receipts and missing/foreign native definitions. Generated schemas
validate the real port path; injected hosts do not establish authority outcomes.

The final combined **`just test::catalog --sdk python --sdk node` passes in
29.190 seconds**, including **4.662 seconds** of isolated package installation.
It uses frozen, hashed Python wheels and TypeScript tarballs outside the checkout.
The new TypeScript caller prepares initialization/policy controls, compiles and
creates a full-width request, loses its admission response, replaces caller/node/
store and recovers the same saved command and original receipt. Current catalog
and native disclosure revocation still hide earlier results. Python sync/async
callers pass in the same schedule.

The schedule records **1863 reads**, **45 accepted turn responses**, **eight lost
caller receipts** and **three lost owner receipts**, with ten applied Tables over
two resources. Bounds remain **four mutations**, **133-byte maximum fixture values**
and **eight resident authority pages**. Installation and expanded recovery work
are included; the interval is not an equivalent-workload speedup, latency target,
native growth proof or host power-loss guarantee. The six frozen executable hashes
and four Python wheel hashes match the preceding Python schedule. TypeScript
package hashes in `.cache/verification/catalog/native.json` are:

| Tarball                  | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station`        | `1ddd05e7a8da2f506c658dc3b72dfac2ebfee377e5effcbed6a9fe98fb63aa56` |
| `transit-native-station` | `f738de57b1c4912b0787c37a0e42303fb4230f41c80db1a88ce16ae0145171b5` |
| `transit-client`         | `263043a2da762afd3771dbfd8d6c411a8195ba017ba877ffeca0dae385bb901e` |
| `transit-native-client`  | `815e315a33426f171954cd5763d87e1c39fe0e7001889ea1d8d859f96cd25f0d` |

The packaged catalog guide and README also match the working sources. Logs are
`/tmp/transit-sql-catalog-node-check.log`,
`/tmp/transit-sql-catalog-node-final-native.log` and
`/tmp/transit-sql-catalog-node-final-format.log`.

Full **`just check` passes**, including generated contracts, 346 CLI diagnostics,
4551 local links across 478 files, 52 invariants, 53 classified bounds, 13 SDK
scenarios, frontend checks and documentation build
(`/tmp/transit-sql-catalog-node-full-check.log`). The focused
`bindings::catalog-node` recipe and regular `bindings::node-sdk-test` include
installed catalog recovery. These are development and focused checks; the other
eight catalog SDKs remain.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at
`6ba60509162e57d3c0c6bfbe17ce9da0e768e788` in 718.92 s**. The clone inherits
no workspace build outputs. Completion and per-task timings are recorded in
`.cache/ci/clean/6ba60509162e-transit-ci-lpweqipr/core.meta.json` and `core.json`;
the log is `/tmp/transit-sql-catalog-node-ci-clean.log`. This qualifies the core
lane plus the focused TypeScript/Python schedule, not a full clean suite or
the remaining catalog SDKs. The following commit records evidence only.

### Rust catalog caller

The public `transit_station_sdk::catalog::Client` uses the shared generated ABI
on one owned blocking worker. Typed declarations and controls own full-width
`u64` identities and their strings; prepared commands are borrowed unchanged by
submission. Response adapters check exact field sets, canonical decimal IDs,
bounds and original-request status matching. A malformed success receipt or
failure of an admitted worker job remains `UnknownOutcome`; definite native
rejections keep their category, status and code. Shared Zig retains signing,
policy, publication and recovery semantics. No definition or native binary
changes in this increment.

Executed on development source based on `c904ae08` in the pinned bindings shell:

- Full **`just check` passes**, including generated contracts, 346 CLI diagnostic
  cases, 4558 local links across 479 files, 52 invariants, 53 classified bounds,
  13 SDK scenarios, frontend checks and documentation build. The log is
  `/tmp/transit-sql-catalog-rust-full-check.log`.
- Rust formatting and verification inventory checks pass. Three component
  tests pass both in source and from the installed crate: owned maximum-width
  values/strict decoding, malformed successful receipt uncertainty, and an
  injected worker panic after admission that preserves recovery. Definite
  errors remain unchanged. An initial source invocation without embedded native
  artifacts failed in native-package build scripts; the documented `TRANSIT_LIBRARY_DIR`
  development override passes. Installed tests remove that override and use
  the packaged libraries.
- Final **`just test::catalog --sdk python --sdk node --sdk rust` passes in
  46.173 s**, including 20.142 s isolated installation. The Rust consumer builds
  from copied, hashed crates outside the checkout with pinned registry checksums
  and no Arrow dependency. Compiler rejection checks prevent overlapping
  mutable caller borrows and reuse after consuming `close`. Extracted sources
  and build outputs are removed before running the packaged native consumer.
- The shared disk schedule exercises Rust initialization, conditional policy,
  full-width creation and exact saved-command recovery after lost admission and
  caller/node/store replacement. Original outcomes match independent records;
  current catalog and native denial still hide them. Python sync/async and
  TypeScript repeat the same schedule. It records **1994 reads, 48 accepted turn
  responses, nine lost caller replies and three lost owner replies**, with at
  most four mutations, 133-byte values and eight resident authority pages.
  Eleven applied Tables across two resources do not establish native catalog
  growth or host power-loss recovery. The interval includes provisioning,
  compilation and recovery; it is not an SDK latency comparison.

Final Rust crate SHA-256 values:

| Artifact                 | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station-sdk`    | `cdfb35189dc89b59893380339d3f0efd05708ddee04444812c156d05252ee600` |
| `transit-native-station` | `8c26d46b678cc8714e6444b84052ac502a54a03c2d552d5bd819f6a42f8cb34d` |
| `transit-client`         | `5f546a83afe1eba98b7c8504d4fca550ccb383a4c2bfa4df0affd2bd3399a57f` |
| `transit-native-client`  | `6d83bab01c95822a9daf8db22bf59c46a88e55c31a56b1560a69792e55275c42` |

All six executables/libraries, four Python wheels and four TypeScript tarballs
match the preceding TypeScript schedule. Packaged Rust sources, README and catalog
guide match the working files. Logs are
`/tmp/transit-sql-catalog-rust-worker-native.log`,
`/tmp/transit-sql-catalog-rust-worker-test.log` and
`/tmp/transit-sql-catalog-rust-final-format.log`; the initial source artifact failure
is retained in `/tmp/transit-sql-catalog-rust-components.log`.
`bindings::catalog-rust` and regular `bindings::rust-sdk-test` include installed
catalog recovery. These development and focused passes cover Rust; the other
seven catalog SDKs remain.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at
`f77fcc29dd6eeb0c98670d4f4f3b1212129bb55a` in 710.42 s**. The clone inherits
no workspace build outputs. Completion and per-task timings are recorded in
`.cache/ci/clean/f77fcc29dd6e-transit-ci-2wn0hfvk/core.meta.json` and `core.json`;
the log is `/tmp/transit-sql-catalog-rust-ci-clean.log`. This qualifies the core
lane plus the focused Python/TypeScript/Rust schedule, not a full clean suite
or the remaining catalog SDKs. The following commit records evidence only.

### Ruby catalog caller

The public `Transit::Station::Catalog::Client` uses the existing owned worker
and native port. Frozen typed declarations, controls and copied recovery strings
retain full-width integers. Generated request/response schemas validate the port;
public adapters validate canonical IDs, exact result fields and original-request
status matching. `Catalog::Uncertain` retains the original prepared object after
unconfirmed submission, malformed success or allocation failure. Definite native
rejections preserve their category, status and code. The Zig definition and
native binaries are unchanged.

Executed on development source based on `f77fcc29` in the pinned bindings shell:

- Full **`just check` passes**, including generated contracts, 346 CLI diagnostic
  cases, 4565 local links across 480 files, 52 invariants, 53 classified bounds,
  13 SDK scenarios, frontend checks and documentation build. Ruby source/fixture
  syntax and the final verification inventory also pass.
- Installed gems pass owned/frozen value checks, maximum-width identities,
  malformed successful receipts, unchanged definite denial and original-request
  matching. An injected allocation failure retains uncertainty. Real owned child
  processes exercise generated response validation and child loss. A separately
  injected blocked operation keeps the worker busy after its waiting thread is
  killed, and explicit close joins active work and child cleanup.
- Final **`just test::catalog --sdk python --sdk node --sdk rust --sdk ruby`
  passes in 54.910 s**, including 24.273 s isolated package installation. Each
  artifact is copied and hashed outside the checkout. The Ruby consumer verifies
  it loaded the installed gem; its native host uses the installed matching gem.
  It prepares initialization and conditional policy, compiles full-width creation,
  recovers exact saved submission after lost admission and caller/node/store
  replacement, observes the original result, then checks current catalog/native
  denial. Python sync/async, TypeScript and Rust repeat the shared schedule.
- The report records **2151 reads, 51 accepted turn responses, ten lost caller
  replies and three lost owner replies**, with at most four mutations, 133-byte
  values and eight resident authority pages. Twelve applied Tables across two
  resources do not establish native growth or host power-loss recovery. The
  interval includes installation, provisioning and recovery, and is not an SDK
  latency comparison.

Final Ruby gem SHA-256 values:

| Artifact                 | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station`        | `2e43bc199d383643280deb893d0101b6d6abd7c88bcd1072bc145d9dd5181424` |
| `transit-native-station` | `4653bccd2758a788ec99f0df17407ca772942b3e1a8513d84eb41306ef1a2570` |
| `transit-client`         | `e627518b495c150e8661d233e4b8856c806b9bc239b13d6396b6fc6b82953725` |
| `transit-native-client`  | `71894ce4dba5fe70942c1b8ad2fb5bdf36c3c72cb8e5d0133fb888b38d8f52fc` |

All six native executables/libraries and the Python, TypeScript and Rust artifacts
match the preceding Rust schedule. The packaged Ruby README, catalog guide and
sources match the working files. Logs are
`/tmp/transit-sql-catalog-ruby-full-check.log`,
`/tmp/transit-sql-catalog-ruby-final-native.log` and
`/tmp/transit-sql-catalog-ruby-syntax.log`. `bindings::catalog-ruby` and regular
`bindings::ruby-sdk-test` include the installed schedule. Committed-HEAD
`just ci-clean --lane core` subsequently passes all 18 tasks at `eb25b6fd` in
707.48 s. Evidence is `.cache/ci/clean/eb25b6fd4a66-transit-ci-t_rx2nl0/` and
`/tmp/transit-sql-catalog-ruby-ci-clean.log`. This predates the PR #33 rebase and
does not qualify its expanded 22-task core lane. The other six catalog SDKs remain.

### C and C++ catalog callers

`transit/catalog.h` adds typed C11 catalog values and explicit owned handles;
`transit/catalog.hpp` adds C++17 owned values, optional outcomes and move-only
callers/commands. Both use the existing bounded C worker and shared Zig catalog
ABI. No protocol/schema definition changes. Saved bytes remain borrowed unchanged
on submission; malformed successful receipts and post-dispatch result-copy
failure retain uncertainty through the existing native result boundary. Metadata
and status outputs publish only after complete parsing; failures clear C outputs.

Executed on development source based on `08fd00a6` (with evidence-only
`12c892e9` subsequently recording the simulation checkpoint), in the pinned
bindings shell:

- `just bindings::c-build` builds independent C/C++ packages and example binaries.
  Installed consumers are compiled as C11/C++17 with warnings treated as errors,
  using only copied archives and their pkg-config dependencies. Source fixtures
  are removed before execution. All six selected archives are hashed. C++
  compiler checks reject copies of `Client`, `Compiled` and `Prepared`.
- Value checks cover maximum-width catalog/operation/object/Table IDs, owned
  request/canonical/saved data after the source changes, oversized/empty commands,
  unterminated C names, unsupported schema types and access after moving an owner.
  Prepared and compiled owners remain readable after native close. C failure
  outputs clear before return; exact borrowed commands survive uncertain sends.
- `just test::catalog --sdk c --sdk cpp` passes in **21.896 s**, including
  **6.669 s** installation: **1452 reads, 42 accepted turn responses, seven lost
  caller receipts and three lost owner receipts**. The installed callers prepare
  initialization/policy, compile creation, recover original admission and result
  after caller/node/store replacement and preserve current catalog/native denial.
  Nine Tables across two resources do not establish native growth. Bounds remain
  four mutations, 133-byte values and eight resident authority pages.
- The existing `just test::table-mutation --sdk c --sdk cpp` regression passes in
  **27.884 s**, including **4.341 s** installation, 2028 reads, 56 turn responses
  and seven lost receipts. The same C library handles saved UPDATE recovery,
  caller replacement and current denial. This interval includes native/port/CLI
  cases and provisioning; it is not a C-versus-C++ latency comparison.
- Full `just check` passes, including generated contracts, unit/CLI checks,
  frontend tests and the documentation build. Final ownership/doc checks pass
  56 invariants, 53 bounds, 13 SDK scenarios and 4596 local links across 482 files.

An initial installed C++ fixture failed compilation on aggregate initializer
warnings and use of C fields as accessor methods. The fixture was corrected;
that failed attempt is not recovery evidence. Logs are
`/tmp/transit-sql-catalog-cpp-native.log`,
`/tmp/transit-sql-catalog-cpp-native-rerun.log`,
`/tmp/transit-sql-catalog-cpp-native-fixed.log`,
`/tmp/transit-sql-catalog-cpp-final-native.log` and
`/tmp/transit-sql-catalog-cpp-full-check.log`. The final report is copied to
`/tmp/transit-sql-catalog-cpp-final-native.json`. Native binary hashes match the
rebased four-language report below. Final SDK archive SHA-256 values:

| Archive | SHA-256 |
| --- | --- |
| `transit-client-c-0.2.0-linux-x86_64.tar.gz` | `90c820a934d5a0d2a8aea65e70a6f1ec28dd5f0044c351f80bc156cbdcd3d4a0` |
| `transit-client-cpp-0.2.0.tar.gz` | `24b3d7944ae2899f914dce09edfbbb00744579d3e76dceaee973f23f7dd86f99` |
| `transit-native-client-c-0.2.0-linux-x86_64.tar.gz` | `a435721d4ee2561818adde127a0a098f4d49daf69176c192f305294a83f5857e` |
| `transit-native-station-c-0.2.0-linux-x86_64.tar.gz` | `fbd4acaf89f0e8d6aaf4b5819a3c1af4162594cf9a9a2fa5b6ab532bcbf3690f` |
| `transit-station-c-0.2.0-linux-x86_64.tar.gz` | `84594774cd5c7de7efd4b94ba9d2be35b6e3d21c90792a8d00aa62ca70a346fd` |
| `transit-station-cpp-0.2.0.tar.gz` | `04be1174bd6ccd8137de0972027ec10a092a885291bc874a58dfeb6bbb5ce152` |

`bindings::catalog-c` owns this focused installed schedule; the regular C SDK
regression also includes it. Committed-HEAD `just ci-clean --lane core` passes
all **22 tasks at `4ecef2ff` in 737.81 s**, from an isolated clone without inherited
build outputs. Evidence is `.cache/ci/clean/4ecef2ffe5f1-transit-ci-78lwlq08/` and
`/tmp/transit-sql-catalog-cpp-ci-clean.log`. This is the expanded core lane plus
focused installed catalog/mutation proofs, not the full clean suite. The four
Java/.NET/Erlang/Elixir catalog callers remain. No catalog-specific host
cancellation or allocator-fault injection is claimed by these C/C++ fixtures.

### Java catalog caller

`io.transit.sdk.station.Catalog` exposes immutable typed values and bounded
futures through the existing Java worker/native port. Positive `BigInteger`
identities retain the full uint64 range; copied lists/`Bytes` retain ownership.
The generated host request/response schemas and strict adapter result fields
validate boundaries. Signing, policy and exact recovery stay in shared Zig.
Successful receipt decoding failures remain `UNKNOWN_OUTCOME`; original prepared
commands stay immutable. Definite native error categories/status/codes remain.

Executed on development source based on `4ecef2ff`, with the evidence-only
`cb23fd69` published during the final run, in the pinned bindings shell:

- `just bindings::java-build` compiles Java 21 JARs/examples with all warnings
  treated as errors. The installed catalog proof copies and hashes four Transit
  JARs plus pinned Gson, compiles outside the checkout and removes Java sources
  before execution. The normal recovery consumer uses its packaged native host.
- Installed value checks cover maximum-width identities, immutable/copied
  declarations and recovery data, malformed/extra-field successful receipts,
  original-request matching, noncanonical decimal values and an injected result
  allocation error. Definite access denial preserves the original exception.
- A separate actual port wrapper uses the installed native artifact for
  handshakes, joins that helper, then injects child loss, malformed replies,
  definite denial and a blocked successful submission. Cancelling its Java
  future preserves `BUSY`; close waits until the explicit release and joins the
  port and worker threads. This checks the owned process and host scheduling,
  not remote cancellation or recovery under general heap exhaustion.
- Focused `just test::catalog --sdk java` passes in **17.126 s**, including
  **2.470 s** installation, 1459 reads, 39 accepted turn responses, six lost
  caller receipts and three lost owner receipts.
- The final **seven-language** schedule (`just test::catalog --sdk python --sdk
  node --sdk rust --sdk ruby --sdk c --sdk cpp --sdk java`) passes in **73.578 s**,
  including **33.900 s** installation. It records **2655 reads, 60 accepted turn
  responses, thirteen lost caller receipts and three lost owner receipts**.
  Every selected caller recovers the original operation after caller/node/store
  replacement and preserves current catalog/native denial. Python includes both
  synchronous and asynchronous callers. Fifteen Tables across two resources do
  not establish native catalog growth. Bounds remain four mutations, 134-byte
  observed values and eight resident authority pages. Timings include package
  installation and recovery; they are not cross-language latency comparisons.
- Full `just check` passes: unit/generated-contract/CLI checks, frontend checks
  and documentation build. Final direct checks pass 4603 links across 483 files,
  56 invariants, 53 bounds and 13 SDK scenarios.
- The existing `just test::table-mutation --sdk java` regression passes in
  **22.624 s**, including **0.856 s** installation, 1879 reads, 52 turn responses
  and six lost receipts. Installed Java retains exact UPDATE recovery through
  the same bridge; native/port/CLI mutation cases also pass. The log is
  `/tmp/transit-sql-catalog-java-mutation-regression.log`.

The initial fixture compilation exposed deprecated Gson construction and missing
optional annotation metadata under `-Werror`; it now uses the existing supported
Gson entry point and the real submission conversion helper for injected failure.
A subsequent port-fixture cleanup assertion failed because its handshake
subprocess had not been joined before the wrapper could be killed. Joining that
helper before admitting faults fixes the fixture. Neither failed attempt counts
as executed recovery proof. Logs are
`/tmp/transit-sql-catalog-java-native.log`,
`/tmp/transit-sql-catalog-java-native-fixed.log`,
`/tmp/transit-sql-catalog-java-native-joined.log`,
`/tmp/transit-sql-catalog-java-all-native.log` and
`/tmp/transit-sql-catalog-java-full-check.log`. Reports are copied to
`/tmp/transit-sql-catalog-java-native.json` and
`/tmp/transit-sql-catalog-java-all-native.json`; both retain exact SDK/native
hashes. Native binary hashes match the rebased report below. Final Java artifacts:

| JAR | SHA-256 |
| --- | --- |
| `transit-client-0.2.0.jar` | `8775ebc5cdb52de401f426f03d7d9496c15307089be60884685e078edd5ed89f` |
| `transit-native-client-0.2.0.jar` | `66132be7fb9bec1018bdc867a1165593db00b0f41fae70330f8025c8489c52ae` |
| `transit-station-sdk-0.2.0.jar` | `b966c9f485827ce4e1d19046b26031a9c2813d98381d11361e21120a4595fb26` |
| `transit-native-station-0.2.0.jar` | `70c1cc5e8f6612fb84c89cd64eedb5e024932a4588d3ed76627d902f9687b7d6` |
| `gson-2.12.1.jar` | `ebee13d5fb7477cd7f1cc010e0c356df8ca80709715248da97f79e35ccb4fbec` |

`bindings::catalog-java` owns the focused installed schedule; the regular Java
SDK regression also includes it. These are development and focused passes.
Committed `66d0a97e` passes `just ci-clean --lane core`: all **22 tasks**
complete in **742.17 s** without inherited build outputs, including the new
resource, scheduler, domain and Vortex simulation tasks. Evidence is under
`.cache/ci/clean/66d0a97e4044-transit-ci-137qp_eh/` (`core.json` and
`core.meta.json`); the log is `/tmp/transit-sql-catalog-java-ci-clean.log`.
This is the expanded core lane and focused installed checks above, not the
full clean suite. .NET/Erlang/Elixir catalog callers remain. The following
commit records this evidence only.

### .NET catalog caller

`Transit.Station.Sdk.Catalog` exposes immutable typed records and bounded tasks
through the existing .NET worker and generated native C ABI. Positive `ulong`
identities retain the full uint64 range. Copied name lists and `Bytes` retain
ownership; schema equality compares names by value so decoded original requests
can be checked against independently reconstructed callers. Generated action and
result schemas plus strict adapter fields validate boundaries. Shared Zig owns
signing, current policy and exact recovery. Successful receipt decoding failure
remains `UnknownOutcome`; explicit native rejection retains its category/code.

Executed in the pinned bindings shell on development source based on `66d0a97e`:

- `just bindings::catalog-dotnet` builds four NuGets and installs exact package
  versions from an isolated local feed. The consumer compiles with warnings as
  errors, then runs after removing its source and package cache. Package hashes
  are retained in the native report.
- Installed checks cover copied immutable declarations/prepared bytes, maximum
  identities, original-request equality, noncanonical decimal strings and
  malformed/extra-field successful receipt uncertainty. Decoder fault inputs
  use the installed assembly through reflection; they are not forged native
  ABI outputs or allocator-failure injection.
- A local TCP peer blocks an actual native catalog HTTP read. A previously
  cancelled token admits no request. Cancelling the admitted wait preserves
  `Busy`; disposal remains pending until the peer releases the read, then joins
  the owned worker. Post-disposal calls fail `Closed`. This tests read
  cancellation and local ownership, not cancellation of admitted mutations.
- The focused native catalog schedule passes in **17.031 s**, including
  **3.035 s** installation: **1395 reads, 39 turn responses, six lost caller
  receipts and three lost owner receipts**. The installed .NET caller recovers
  its original creation after caller/node/store replacement and respects current
  catalog/native disclosure denial. The native ABI, port and CLI cases also
  pass. Eight Tables across two resources do not establish native catalog growth.
  Bounds remain four mutations, 133-byte observed values and eight resident
  authority pages. This timing includes installation and recovery, not a
  cross-language latency comparison.
- The existing `just test::table-mutation --sdk dotnet` regression passes in
  **24.302 s**, including **2.543 s** installation, 1849 reads, 52 turn responses
  and six lost receipts. Exact UPDATE recovery and current denial remain intact
  through the shared bridge.

The first installed fixture supplied managed numeric nodes directly to the
wire-result decoder, which correctly rejected their differing runtime types.
The fixture now serializes and parses JSON before decoder checks. The first
full check also found the new task absent from the suite inventory; the task and
invariant inventories now agree. Those attempts are failures, not proof passes.
Logs are `/tmp/transit-sql-catalog-dotnet-build.log`,
`/tmp/transit-sql-catalog-dotnet-native.log` (initial fixture failure),
`/tmp/transit-sql-catalog-dotnet-native-fixed.log`,
`/tmp/transit-sql-catalog-dotnet-mutation-regression.log`,
`/tmp/transit-sql-catalog-dotnet-full-check.log` (inventory failure) and
`/tmp/transit-sql-catalog-dotnet-full-check-fixed.log`. The focused report is
copied to `/tmp/transit-sql-catalog-dotnet-native.json`; native hashes match the
rebased report below. Installed package hashes:

| NuGet | SHA-256 |
| --- | --- |
| `Transit.Client.0.2.0.nupkg` | `9c1c8db6507b0a76e43fd17b3504c7d44c6cad7495e3ba09dd453820f970eb2a` |
| `Transit.Native.Client.0.2.0.nupkg` | `9b906b7103a2fe0c27612a8bdda09fd6cf84ba6d8dc0612aca1d08d9cdc6d445` |
| `Transit.Station.Sdk.0.2.0.nupkg` | `56576b6978e2fae0a340e7e6e6dbad314c761db4411809de4676e5c18066fc5b` |
| `Transit.Native.Station.0.2.0.nupkg` | `b034cd99a5fbefc2b0c2227fec50a100e1e06be86d5190efbaeeeb61acaafdd6` |

`bindings::catalog-dotnet` owns the focused installed schedule; the regular .NET
SDK regression also includes it. Full `just check` passes unit/generated-contract
and CLI checks, frontend checks and the documentation build. Final direct checks
cover 4609 links across 484 files, 56 invariants, 53 bounds and 13 SDK scenarios.
Committed `7ec2e0e1` passes `just ci-clean --lane core`: all **22 tasks**
complete in **758.12 s** without inherited build outputs, including the new
simulation tasks. Evidence is under
`.cache/ci/clean/7ec2e0e11b24-transit-ci-v67ub5ds/` (`core.json` and
`core.meta.json`); the log is `/tmp/transit-sql-catalog-dotnet-ci-clean.log`.
This is the expanded core lane plus the focused checks above, not the full clean
suite. Erlang/Elixir catalog callers remain. The following commit records only
this clean evidence.

### Erlang/Elixir catalog callers and combined installed schedule

`transit_catalog` and `Transit.Station.Sdk.Catalog` expose immutable records and
structs through the existing BEAM worker/native port. Full-width identities,
fixed allowed atoms, generated boundary schemas and exact original-request
matching preserve the shared catalog contract. Signing, authorization and
recovery remain in Zig. An uncertain submit returns the original prepared value;
native rejection retains its category, status and code. `close` joins admitted
work after a waiting process dies.

Executed in the pinned bindings shell on development source based on `7ec2e0e1`:

- `just bindings::beam-build` compiles OTP applications and real examples with
  warnings as errors. The focused installed schedule copies/hashes four Erlang
  artifacts and six Elixir artifacts, compiles consumers outside the checkout,
  removes consumer source files and uses the installed native host. Elixir
  formatting checks pass.
- Installed value checks compile maximum-width catalog/operation/object/Table
  IDs and reject invalid integers and saved bytes. Real owned ports use native
  handshakes, join that helper, then inject malformed replies, child loss,
  explicit denial and a blocked successful submit. Uncertainty retains the
  identical prepared record/struct. Killing the waiting process retains `busy`;
  close waits for explicit release, and the child is gone after cleanup. The
  Java fixture is renamed `catalog_port_host.py` for shared use and handles
  explicit shutdown. Java's installed fault checks pass with the shared fixture.
  These cases do not prove general allocator exhaustion or remote cancellation.
- The focused Erlang/Elixir catalog schedule passes in **21.772 s**, including
  **5.334 s** installation: 1574 reads, 42 turn responses, seven lost caller
  receipts and three lost owner receipts. It creates nine Tables. The final
  combined run below uses rebuilt artifacts including the published guides.
- **All ten SDKs** pass the combined catalog schedule in **108.574 s**, including
  **43.699 s** installation: **4095 reads, 69 turn responses, sixteen lost caller
  receipts and three lost owner receipts**. Python includes both sync and async
  callers. Every selected caller recovers its original creation after
  caller/node/store replacement and respects current catalog/native disclosure
  denial. The native ABI, native port and CLI cases also pass. Eighteen Tables
  across two resources do not establish native catalog growth. Bounds remain
  four mutations, 134-byte observed values and eight resident authority pages.
  These local timings include installation and recovery while independent
  repository/regression checks run; they are not cross-language latency rankings.
- The existing Erlang/Elixir mutation regression passes in **28.509 s**, including
  **2.159 s** installation, 2127 reads, 56 turn responses and seven lost receipts.
  Exact UPDATE recovery and current denial remain intact through the shared port.
- Full `just check` passes unit/generated-contract and CLI checks, frontend
  checks and the documentation build. Direct checks cover 4625 links across 486
  files, 56 invariants, 53 bounds and 13 SDK scenarios. The SDK proof inventory
  now records C/C++/Java/.NET/BEAM ownership evidence and its distinct limits.

The initial combined run stopped during Rust's compile-rejection assertion while
`/tmp` was under disk pressure; the captured output reports Ursula disk pressure,
but the assertion did not preserve compiler stderr. The concurrent full check
failed copying the CLI binary with `ENOSPC`. Both attempts remain failed. The
Rust fixture now includes compiler exit/stderr on an unexpected result. Repeating
both checks with `TMPDIR=/var/tmp` passes; no deployment quotas or resident bounds
were raised. The failure does not establish a Rust ownership regression or a
catalog recovery pass.

Logs are `/tmp/transit-sql-catalog-beam-build.log`,
`/tmp/transit-sql-catalog-beam-final-build.log`,
`/tmp/transit-sql-catalog-beam-native.log`,
`/tmp/transit-sql-catalog-beam-mutation-regression.log`,
`/tmp/transit-sql-catalog-all-ten-native.log` (failed),
`/tmp/transit-sql-catalog-all-ten-native-var.log`,
`/tmp/transit-sql-catalog-beam-full-check.log` (failed) and
`/tmp/transit-sql-catalog-beam-full-check-var.log`. Reports are copied to
`/tmp/transit-sql-catalog-beam-native.json` and
`/tmp/transit-sql-catalog-all-ten-native.json`. The combined report retains all
selected package hashes; earlier eight SDK identities and native binary hashes
match the recorded checkpoints above/below. Final BEAM artifacts:

| OTP artifact | SHA-256 |
| --- | --- |
| `transit_native_client-0.2.0.tar.gz` | `c4436c6ec88f4e0a838e88c0214521cced7d527a1bca8343a2eb43c5e0712529` |
| `transit_client-0.2.0.tar.gz` | `7ef15b4c716177372dc39dcca2230ef2878e118bdf430176ce86e8e15a26e0aa` |
| `transit_native_station-0.2.0.tar.gz` | `8e8aba003040a0924bc78b3383fcee833f3652ccf115f76c7a48de35b799c6d2` |
| `transit_station_sdk-0.2.0.tar.gz` | `b60cb4c0eee515d4d8af515d23843a0fb54525e03d2fdb30668fc5d0a386493e` |
| `transit_client_elixir-0.2.0.tar.gz` | `adc379bfc22a4027c5caf26bc2c03062981b2a4cc50500bc50d32d413a830b36` |
| `transit_station_elixir-0.2.0.tar.gz` | `5a72442a18d3527740e4571f07ae0438c7a464b7c04f97b4d97298aa30de564d` |

`bindings::catalog-beam` owns the focused installed schedule; the regular BEAM
SDK regression also includes it. All ten SDKs expose this catalog profile;
native catalog growth/paged callers and broader declaration operations remain.

Committed-HEAD `TMPDIR=/var/tmp nix develop --option eval-cache false .#bindings
--command just ci-clean --lane core` passes all **22 tasks** at `3c11f9c3` in
**1371.72 s** without inherited workspace outputs. The completion and task timing
records are `.cache/ci/clean/3c11f9c3c3ed-transit-ci-ble3b_wo/core.meta.json`
and `core.json`; the log is `/tmp/transit-sql-catalog-beam-ci-clean.log`.
Concurrent workloads make this unpaired duration unsuitable for a performance
regression claim. This is the expanded core lane, not a full clean suite. The
following evidence-only commit records the result; signed metadata work remains
separate from this checkpoint.

### Signed catalog metadata

The Zig signed caller shares `Inspection` validation with the private-turn
catalog helper for name lookup, exact definition reads and eight-entry pages.
Each call acquires current configuration/policy and checks the native writer;
subsequent reads enforce the same resource revision. Current inspection rights
precede cursor checks. Create-only conflict checks remain independent of inspect
permission. No saved view, admission or authorization cache is introduced.
Neutral ABI/port, CLI and language SDK metadata mappings remain separate work.

On development source based on `3c11f9c3`, pinned Zig
`0.17.0-dev.2267+48abf1a34` passes root unit/fixture checks, the small real native
schedule and full `just check`. The native schedule takes **42.936 s** with
1391 reads, 36 accepted turn responses, five lost caller replies and three lost
owner replies. It checks five named definitions in the supplied host resource,
seven applied Tables across both resources, point/list agreement and current
catalog/native disclosure denial. Bounds remain four mutations, 132-byte observed
values and eight resident authority pages. This small schedule is not a growth
proof. Its report is `/tmp/transit-sql-catalog-metadata-native-fixed.json` and log
`/tmp/transit-sql-catalog-metadata-native-fixed.log`.

The native contract definition is unchanged. Binary SHA-256 identities:

| Binary | SHA-256 |
| --- | --- |
| node | `6f27157343edbf4311ceaeba4444566c9ce91a761ce2f6b647a2e0667d393e8c` |
| catalog proof | `19da6d30e2d6c792c285bf35bc1f3faf93f4c0ef92f6f78b82d6784ec06d5aa2` |
| catalog host | `9545df46010fede16ed61231e508942b1b744c6285cfb0673656e3d034d6f1c6` |
| native port | `4a31f186752ff355011f6952c59965baffd9c9efc1799347a47b24d7b219b993` |
| native library | `34ae38b64593862311010b9d478324fc3a8103cc52a018677fcc0c46d854d398` |
| CLI | `f66e7b11526f1e14006f6a43721f806af1f61916e360229d096ca7ae63991325` |

Eight component seeds pass **40 package schedules / 1264 events** with identical
replay in **13.719 s**, including the shared inspection code. The log and report
are `/tmp/transit-sql-catalog-metadata-domain.log` and
`/tmp/transit-sql-catalog-metadata-domain.json`. At committed `6464b125`, all **nine
compiling component mutants** are detected by executed assertions, including
removing inspection authorization or the cursor revision guard from `Inspection`.
The log and copied report are `/tmp/transit-sql-catalog-metadata-mutants.log` and
`/tmp/transit-sql-catalog-metadata-mutants.json`; detailed traces remain in
`.cache/verification/domain-simulation-mutations/`.

The 257-additional-Table disk run fails during creation-status polling with
`AuthorityTimeout`; the owner also reports an uncertain turn. It does not reach
the final listing/restart checks and remains failed. The log is
`/tmp/transit-sql-catalog-metadata-growth.log`; it does not retain an exact completed
creation count. The fixture now retains incomplete progress, operation counts and
metadata timings in `native.json`, including on failures. Bounds and timeouts are
unchanged. The larger schedule remains incomplete.

The subsequent `just test::catalog --grow 65` schedule passes in **292.798 s** on
development source based on `869f112e`, with the binary hashes above. It creates
65 additional Tables and lists **70 definitions across nine pages**, checks each
name lookup and exact object/revision against the listing, kills/restarts the
node and disk store, and repeats the complete listing. Actual committed growth
invalidates an old cursor; changed scope/revision and current native/catalog
revocation reject. There are 72 applied Tables across both resources, 6382 total
reads (3209 from the catalog caller), 101 accepted turn responses and the original
five caller/three owner receipt-loss cases. Bounds remain four mutations,
132-byte observed values and eight resident authority pages. This is the finite
default `test::catalog-growth` schedule; it does not complete the failed 257 case.
The report and log are `/tmp/transit-sql-catalog-metadata-growth-65.json` and
`/tmp/transit-sql-catalog-metadata-growth-65.log`.

The report separates caller reads from worker polling. Cold signed listing costs
**19 reads for eight definitions** and 15 for six; successful name lookup costs
five and exact definition lookup three. A missing name costs three. Measurements
cover 19 successful listing calls (including one during growth), 142 name
lookups and 142 definition reads across the two walks. Growth creation takes
211.962 s; cumulative 16/32/48/64-Table times are 27.904/71.741/134.220/206.188 s.
These shared-host measurements expose increasing creation cost and a bounded
point-read batching opportunity; they do not attribute the cost to a specific
subsystem or establish end-to-end latency targets.

The initial native metadata attempts fail converting a Zig JSON byte string as a
Python integer array; the corrected fixture passes the small schedule. A new
create-only unit assertion initially overflows its maximum-ID fixture; selecting
a distinct lower operation ID fixes the test. Failed logs are
`/tmp/transit-sql-catalog-metadata-native-initial.log`,
`/tmp/transit-sql-catalog-metadata-native.log` and
`/tmp/transit-sql-catalog-metadata-full-check.log`. The full rerun passes at
`/tmp/transit-sql-catalog-metadata-full-check-fixed.log` with 4625 documentation
links, 56 invariants, 53 classified bounds and 13 SDK scenarios. Neither fixture
failure establishes a successful production check.

### Batched signed catalog pages

The signed reader fetches the page's definition records and Table descriptors in
two dependent batches. Each requires the exact initial resource revision and
current native grants; the second replaces the first after definitions are copied
into the result. Private-turn callers retain ordinary point reads and sticky
failure behavior. Resident dependency storage holds at most eight keys/entries,
independently of retained catalog size.

On development source based on `55f360e3`, the same 65-additional-Table disk
schedule passes in **218.313 s**: 70 named definitions over nine pages, exact
point/list agreement, node/store restart, current denial, five caller and three
owner receipt-loss cases. It records 5981 total reads, 2958 caller reads and 101
accepted turn responses; bounds remain four mutations, 132-byte values and eight
resident pages. Source/dirty status and binary hashes are in
`/tmp/transit-sql-catalog-metadata-batch-growth.json`; the log is
`/tmp/transit-sql-catalog-metadata-batch-growth.log`.

All **19 successful list calls cost five signed reads**, including the two
six-entry final pages. Compared with the earlier matching growth schedule, a
full eight-definition page falls from **19 to five reads**; listing calls total
353 reads before and 95 after. The 142 name lookups retain their five-read
successful/three-read absent costs, and the 142 exact-definition calls retain
three reads each. Listing wall times total 6.972 s before and 3.258 s after, but
these shared-host runs are unpaired: only the measured request-count reduction
establishes the batching improvement. Total runtime and worker polling are not
used as a latency or throughput guarantee. The failed 257-Table attempt remains
incomplete.

Root unit checks pass, and eight seeded component runs pass **40 package
schedules / 1264 events** with identical replay in **13.732 s** after changing the
read order. Logs are `/tmp/transit-sql-catalog-metadata-batch-unit.log` and
`/tmp/transit-sql-catalog-metadata-batch-domain.log`; the domain report is copied
to `/tmp/transit-sql-catalog-metadata-batch-domain.json`.

A separate real native schedule pauses the first dependent definition batch
after initial policy/name reads, revokes the caller's native resource read grant,
then releases the batch. Listing fails with `AccessDenied`; restoring the grant
permits a fresh listing. This check passes in **43.676 s**, with 1428 total reads,
507 caller reads and 36 turn responses. It preserves the original five
caller/three owner receipt-loss cases, five listed definitions and the same
resident/write bounds. Every successful listing asserts a five-read budget.
The log and report are `/tmp/transit-sql-catalog-metadata-batch-revocation-fixed.log`
and `/tmp/transit-sql-catalog-metadata-batch-revocation.json`. The first attempt
does not compile because the new fixture gives an eight-bit permission field a
32-bit value; `/tmp/transit-sql-catalog-metadata-batch-revocation.log` retains that
failure. It is corrected without changing protocol fields or limits.

Final native binary hashes (the growth run uses the preceding helper hash
`cc3c0b7046c631bca1ed2fb96154b148127aac94b897d0cf2fa44bc188c5f941`):

| Binary | SHA-256 |
| --- | --- |
| node | `6f27157343edbf4311ceaeba4444566c9ce91a761ce2f6b647a2e0667d393e8c` |
| catalog proof | `18a822862a38cc4a52a4edd0c5c42716a7795a2700ed4fc7d04c94ad637ffe6b` |
| catalog host | `dc96313fc0d17aa038e34791c6ea7e2af527ee445172791555995fd27e9bc8eb` |
| native port | `62442c92768565973e7879ad6e83328f3674add9406d560e1156447b80bad63d` |
| native library | `5fb61f939a4aacf5b5355196a5a78534689a7bdb160ce9e01a06746eeeceaad4` |
| CLI | `f373d7886a3d0b696723441a974376834f6e0e86703ac76b6b74b618b98eea42` |

Full `just check` passes at `/tmp/transit-sql-catalog-metadata-batch-full-check.log`,
including unchanged generated contracts and 4625 documentation links. All nine
compiling component mutants are detected again at committed `8e728de3`, including
inspection authorization and cursor revision defects after batching. The log and
copied report are `/tmp/transit-sql-catalog-metadata-batch-mutants.log` and
`/tmp/transit-sql-catalog-metadata-batch-mutants.json`. Committed clean validation
passes separately at `8e728de3`: `just ci-clean --lane core` completes all
**22 tasks in 1146.58 s**, without inherited workspace build outputs. Evidence is
`.cache/ci/clean/8e728de3a8de-transit-ci-ykvwiuy3/core.{json,meta.json}`; the log is
`/tmp/transit-sql-catalog-metadata-batch-ci-clean.log`. This is the core lane,
not the complete clean suite or the subsequent ABI/CLI metadata work.

### Neutral catalog metadata values

Shared definition/cursor/page conversions match independently assembled metadata
and binary definition fixtures. Root unit checks verify full-width decimal
identities, owned text, mandatory current cursor definitions and rejection of
missing/foreign definitions, unsafe revisions, page holes, mixed scopes and
inconsistent continuation. The generated native/ABI/host contracts remain
unchanged: these conversion types alone expose no new executable actions.
The pinned-shell logs are `/tmp/transit-sql-catalog-neutral-metadata-unit.log`
and `/tmp/transit-sql-catalog-neutral-metadata-contracts.log`. Native ABI/port,
CLI and SDK metadata actions and installed-caller evidence remain.

Committed `55f360e3` also passes `just ci-clean --lane core`: **22 tasks in
1171.42 s**, including the seeded simulation checks. Evidence is
`.cache/ci/clean/55f360e39e73-transit-ci-q0dn3km_/core.{json,meta.json}` and
`/tmp/transit-sql-catalog-neutral-metadata-ci-clean.log`. It does not include
the later signed-read batching or metadata action additions.

### Catalog metadata through native ABI, port and CLI

The neutral bridge adds `lookup`, exact `definition` and `list` actions using
the shared signed client. Generated schemas/resources cover the new variants;
earlier action/result fields, handle layouts and saved commands are unchanged.
CLI list continuation consumes the original private saved page and checks its
complete structure before credential loading.

On development source based on `fdaa53f4`, `just test::catalog --grow 17` passes
in **48.402 s**. All three callers agree with Zig for **22 definitions over three
pages**, every point lookup and exact definition, and missing records. The walk
repeats after node/Ursula disk restart. A newly created Table invalidates an
original cursor on all surfaces, including a saved CLI page. Catalog and native
revocation deny all three metadata actions; the paused dependent-read revocation
case also remains. Existing creation/control recovery retains five lost caller
receipts and three lost owner receipts. Counts are 4201 total reads, 2193 caller
reads and 53 turn responses; bounds remain four mutations, 132-byte values and
eight resident pages.

All 21 successful neutral list calls stay within five signed reads: seven each
through ABI/port cost four with previously negotiated batch support, and seven
fresh CLI invocations cost five. The cached capability is not an authorization
cache. Every operation still fetches current configuration/policy and native
grants; these unpaired wall times establish no latency claim.
The report is `/tmp/transit-sql-catalog-metadata-abi-cli-native.json`; the log is
`/tmp/transit-sql-catalog-metadata-abi-cli-native-schema-fixed.log`.
The report retains source/dirty status and all six binary hashes. Node, proof and
catalog host hashes match the preceding batched-reader proof. Updated binaries:

| Binary | SHA-256 |
| --- | --- |
| native port | `f8329121706cfb35e41af77aaf96df35c1389d384849fa8d980f7055401bcb62` |
| native library | `fac060c74e3f679858543451b494c1e1ebf4a3e5d7d5312897759be140539060` |
| CLI | `7f427823c886cbd629b3325aaccbf98de48fbbb3dee92dad2f33563b4d9a993c` |

Protocol/catalog unit tests and **399 real CLI diagnostic cases** pass at
`/tmp/transit-sql-catalog-metadata-ordinal-fix.log`. New cases check required
arguments, canonical IDs/names, saved-page holes, ordering/continuation scope and
revision, missing/foreign definitions and final-page refusal before credential
loading. The first CLI/native attempts expose a shared decoder defect: Zig's
generic enum parser accepts an all-zero string as ordinal zero. The shared
protocol shape validator now requires exact declared names; numeric aliases
reject even when nested in a page or action. Logs
`/tmp/transit-sql-catalog-metadata-abi-cli-expanded.log` and
`/tmp/transit-sql-catalog-metadata-abi-cli-native.log` retain those failures.
The following native attempt reaches metadata comparison but fails because its
fixture retains the native schema's `version` field in the neutral expectation;
`/tmp/transit-sql-catalog-metadata-abi-cli-native-fixed.log` records it. The
fixture now verifies version one and compares the declared neutral schema.
Full `just check` passes at
`/tmp/transit-sql-catalog-metadata-abi-cli-full-check.log`; final documentation
and verification inventory checks pass 4625 links across 486 files, 56
invariants, 53 bounds and 13 SDK scenarios at
`/tmp/transit-sql-catalog-metadata-abi-cli-docs.log`.

All ten rebuilt, installed SDKs pass their existing catalog creation/control and
recovery schedule against these additive schemas/actions: **126.508 s**, including
**47.718 s** installation, 4558 reads, 69 turn responses, sixteen lost caller
receipts and three lost owner receipts. It retains eighteen Tables across the two
resources, sixteen listed definitions, four mutations, 134-byte observed values
and eight resident pages. ABI/port/CLI also compare all sixteen definitions and
two pages in this run; language SDK metadata methods are not exercised by this
checkpoint. Source revision is `7fc92b33`; report/package hashes and log are
`/tmp/transit-sql-catalog-metadata-all-ten-regression.json` and
`/tmp/transit-sql-catalog-metadata-all-ten-regression.log`.

Committed `7fc92b33` passes `just ci-clean --lane core`: **all 22 tasks in
756.17 s**, including the shared protocol enum fix, generated contracts and
seeded simulations. Evidence is
`.cache/ci/clean/7fc92b33d25a-transit-ci-en_9c5gk/core.{json,meta.json}` and
`/tmp/transit-sql-catalog-metadata-abi-cli-ci-clean.log`. This validates the
ABI/CLI checkpoint independently of inherited build outputs; it does not include
the subsequent language metadata methods or establish a full clean-suite pass.

### Python catalog metadata

Python sync/async public methods return immutable definitions, Table sources,
cursors and dense page tuples. Strict decoding checks full-width identities,
requested scope/name/revision, continuation and page structure. Type checking
passes all 18 source files, and focused malformed-response/ownership checks pass
at `/tmp/transit-sql-catalog-python-metadata-values.log`. Missing/foreign cursor
definitions, holes, duplicate order, changed cuts, wrong identity and source
variants reject; copied name/entry collections remain independent and frozen.

Rebuilt installed wheels pass `just test::catalog --sdk python --grow 17` in
**72.256 s**, including **2.022 s** installation. Both public clients agree with
Zig/ABI/port/CLI on **24 definitions, three full pages and an empty final page**,
all exact/name reads and missing records before and after node/store disk
restart. Original cursors reject after creation, and both catalog/native
revocation deny each metadata method. Seven lost caller replies and three lost
owner replies retain the existing exact creation/control recovery checks.
Counts are 5839 reads, 3146 caller reads and 59 turn responses; bounds remain
four mutations, 133-byte observed values and eight resident pages. Each Python
client's seven successful populated list calls cost four signed reads and two
empty final pages cost two, using already negotiated native batch support.

The native report and installed-wheel hashes are
`/tmp/transit-sql-catalog-python-metadata-native.json`; the log is
`/tmp/transit-sql-catalog-python-metadata-native.log`. Source is development based
on `8c375486`; all six native binary hashes match the ABI/CLI metadata checkpoint.
This proves Python metadata mappings, not the remaining nine SDKs.

### TypeScript catalog metadata

TypeScript adds frozen definitions, Table sources, cursors and dense page arrays
over its existing native port. Generated schemas reject malformed wire shapes;
the public adapter checks requested identity, scope, ordering and continuation.
`vp check`, TypeScript compilation and **22 catalog tests** pass at
`/tmp/transit-sql-catalog-node-metadata-values.log`, including altered identities,
missing/foreign definitions, holes, duplicate order, changed cuts, unknown sources,
wide bigint values and owned collections. The earlier type check also passes at
`/tmp/transit-sql-catalog-node-metadata-types.log`.

Rebuilt TypeScript and Python installed packages pass the combined
`just test::catalog --sdk python --sdk node --grow 17` schedule in **89.568 s**,
including **7.015 s** installation. All six callers agree on **25 definitions
over four pages**, every point read and absence before/after node/store restart.
Original stale cursors and current catalog/native revocation reject. Eight lost
caller receipts and three lost owner receipts preserve creation/control recovery.
There are 6956 reads, 3634 caller reads and 62 turn responses, bounded to four
mutations, 133-byte values and eight resident pages. All nine successful TypeScript
list calls cost four signed reads with already negotiated batch support.

Report/package hashes and log are
`/tmp/transit-sql-catalog-python-node-metadata-native.json` and
`/tmp/transit-sql-catalog-python-node-metadata-native.log`. This is development
source based on `2ec18f51`, with unchanged native binary hashes. Other eight
language metadata mappings remain outside this evidence.

### Rust catalog metadata

Rust adds owned definitions, Table sources, dense page vectors and explicit
checked cursors through mutable blocking caller methods. Four catalog tests pass
at `/tmp/transit-sql-catalog-rust-metadata-unit-fixed.log`, including full-width
identity, independent cloned ownership, response matching and ten malformed-page
cases. The first source test at
`/tmp/transit-sql-catalog-rust-metadata-unit.log` fails before execution because
native artifacts are not selected; the rerun supplies the built library directory
explicitly. No package dependency or search fallback changes are made.

Rebuilt installed crates pass `just test::catalog --sdk rust --grow 17` in
**72.367 s**, including **16.278 s** installation. Their packaged unit tests and
compiler rejection of overlapping mutable callers/use after close pass. Rust
agrees with Zig/ABI/port/CLI for **23 definitions over three pages**, all point
reads and absence before/after node/store restart. Changed cursors and current
catalog/native denial reject, retaining six lost caller replies and three lost
owner replies in the existing creation/control recovery schedule. Counts are
4968 reads, 2629 caller reads and 56 turn responses; bounds remain four mutations,
133-byte values and eight resident pages. All seven successful Rust listings
cost four signed reads with already negotiated batch support.

Report/package hashes and log are
`/tmp/transit-sql-catalog-rust-metadata-native.json` and
`/tmp/transit-sql-catalog-rust-metadata-native.log`. Source is development based
on `9c6ca374`; native binary hashes are unchanged. Seven language metadata
mappings remain outside this evidence.

Committed `a65c4285` passes `just ci-clean --lane core`: **all 22 tasks in
891.07 s**, including the seeded resource, scheduler, component and external
fault suites. Completion metadata and every task exit code are retained at
`.cache/ci/clean/a65c4285c45d-transit-ci-_g1s7lbt/core.{json,meta.json}`;
the command log is `/tmp/transit-sql-catalog-three-sdk-metadata-ci-clean.log`.
The cumulative Python/TypeScript/Rust source passes full `just check`, including
the documentation build, at
`/tmp/transit-sql-catalog-three-sdk-metadata-full-check.log`. This is the expanded
clean core lane, not a full clean suite or evidence for the seven remaining
language metadata APIs. The following evidence-only commit records these results.

### Ruby catalog metadata

Ruby adds frozen definitions, Table sources, owned dense page arrays and mandatory
original cursors through the existing synchronous worker. Syntax checks pass at
`/tmp/transit-sql-catalog-ruby-metadata-syntax.log`. Installed value checks cover
full-width identity, copied/frozen strings and collections, nine malformed pages,
request identity, continuation cuts, empty final pages and absence. Existing
owned-port malformed/lost responses and cancelled waiting-thread cleanup remain
in the schedule.

Rebuilt installed gems pass `just test::catalog --sdk ruby --grow 17` in
**62.700 s**, including **4.971 s** installation. Ruby agrees with Zig/ABI/port/CLI
on **23 definitions over three pages**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. The creation/control schedule retains six lost caller replies and three
lost owner replies. Counts are 4987 reads, 2638 caller reads and 56 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. Native
binary hashes remain those of the ABI/CLI metadata checkpoint.

The report/package hashes and log are
`/tmp/transit-sql-catalog-ruby-metadata-native.json` and
`/tmp/transit-sql-catalog-ruby-metadata-native.log`, from development source based
on `a65c4285`. Empty-final-page validation here is a value test, not an observed
final native page. This focused run does not qualify the six remaining metadata
SDKs or establish a latency comparison.

### C/C++ catalog metadata

C adds bounded inline definition, cursor and eight-entry page values through the
existing native worker; C++ exposes owned strings, vectors and optional values.
C output values clear on failure, and lookup/list accept their input name/cursor
from the same output value by copying it before clearing. Installed tests exercise
both alias cases, foreign/missing cursor definitions, retained metadata after
close and independent C++ copies. Existing compiler rejection of copied C++
client/recovery owners remains in the schedule. Known metadata shape, scope,
identity, ordering and continuation checks do not establish rejection of every
unknown JSON field by the C parser.

The first installed attempt fails in the fixture with `KeyError: next_hex`: its
inherited query adapter expects a hex query cursor on catalog pages. The corrected
catalog adapter decodes only saved command bytes and uses typed catalog cursors.
That failed attempt remains at
`/tmp/transit-sql-catalog-c-metadata-native-failed.json` and
`/tmp/transit-sql-catalog-c-metadata-native.log`; no production compatibility
fallback is added.

Rebuilt installed packages pass `just test::catalog --sdk c --sdk cpp --grow 17`
in **122.816 s**, including **6.856 s** installation. They agree with
Zig/ABI/port/CLI on **24 definitions, three full pages and an empty final page**,
point reads and absence before/after disk-backed node/store restart. Changed
cursors and current catalog/native denial reject; creation/control recovery
retains seven lost caller replies and three lost owner replies. Counts are
5976 reads, 3138 caller reads and 59 turn responses; bounds remain four mutations,
133-byte values and eight resident pages. Native binary hashes are unchanged.

Source is development based on `a65c4285`; package hashes/report are
`/tmp/transit-sql-catalog-c-metadata-native.json`, build log is
`/tmp/transit-sql-catalog-c-metadata-build.log`, and completed native log is
`/tmp/transit-sql-catalog-c-metadata-native-fixed.log`. Shared-host elapsed time is
not a paired latency comparison. Java/.NET/Erlang/Elixir metadata remains outside
this evidence.

### Java catalog metadata

Java adds immutable definitions, Table sources, copied dense page lists and
mandatory original cursors through the existing bounded-future worker. Installed
value checks cover full-width identities, retained immutable values, twelve
malformed-page cases, response identity, repeated/changed continuation cuts,
empty final pages and absence. Existing owned-port malformed/lost responses,
result-allocation failure and cancelled-future cleanup remain in the schedule.

The first installed attempt fails at fixture compilation: referencing Gson's
`JsonParser` exposes unavailable `InlineMe` annotation methods under `-Werror`.
Using the existing `Gson.fromJson` entry point fixes the fixture without changing
dependencies or suppressing warnings. That attempt is retained at
`/tmp/transit-sql-catalog-java-metadata-native.log`.

Rebuilt installed JARs pass `just test::catalog --sdk java --grow 17` in
**64.660 s**, including **2.735 s** installation. Java agrees with Zig/ABI/port/CLI
on **23 definitions over three pages**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. The creation/control schedule retains six lost caller replies and three
lost owner replies. Counts are 5126 reads, 2634 caller reads and 56 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. All seven
successful Java listings cost four signed reads with negotiated batch support.

Source is development based on `dc2e2e10`; native binary hashes are unchanged.
Report/package hashes are `/tmp/transit-sql-catalog-java-metadata-native.json`;
logs are `/tmp/transit-sql-catalog-java-metadata-build.log` and
`/tmp/transit-sql-catalog-java-metadata-native-fixed.log`. This focused result does
not qualify .NET/Erlang/Elixir metadata or establish a latency comparison.

### .NET catalog metadata

.NET adds immutable definitions, Table sources, copied read-only page collections
and mandatory original cursors through the existing bounded-task worker. Installed
value checks cover full-width identities, retained immutable values, twelve
malformed-page cases, requested identity, repeated/changed continuation cuts,
empty final pages and absence. Existing actual native HTTP read cancellation,
pre-admission cancellation and disposal/join checks remain in the schedule.

The first installed attempt terminates with an unhandled `IncompatibleNative`
exception in its new value fixture: locally constructed `JsonValue<int>` counters
are not parsed neutral JSON numbers. Round-tripping the fixture through JSON
establishes the intended boundary. No production decoder is relaxed. The initial
failure is retained at `/tmp/transit-sql-catalog-dotnet-metadata-native.log`.

Rebuilt installed packages pass `just test::catalog --sdk dotnet --grow 17` in
**61.955 s**, including **4.816 s** installation. They agree with Zig/ABI/port/CLI
on **23 definitions over three pages**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. The creation/control schedule retains six lost caller replies and three
lost owner replies. Counts are 5003 reads, 2629 caller reads and 56 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. All seven
successful .NET listings cost four signed reads with negotiated batch support.

Source is development based on `5dce22fa`; native binary hashes are unchanged.
Report/package hashes are `/tmp/transit-sql-catalog-dotnet-metadata-native.json`;
logs are `/tmp/transit-sql-catalog-dotnet-metadata-build.log` and
`/tmp/transit-sql-catalog-dotnet-metadata-native-fixed.log`. This focused result
does not qualify Erlang/Elixir metadata or establish a latency comparison.

### Erlang/Elixir catalog metadata

Erlang adds immutable definition, Table source, cursor and bounded dense page
records; Elixir maps them to mandatory-field structs through the same owned
worker. Each installed language exercises full-width values, requested identity,
absence, repeated/changed continuation cuts, twelve malformed-page cases and
empty pages through the actual port boundary. Missing/foreign cursor definitions
reject; external text never becomes a newly allocated atom. Existing uncertain
submission and waiting-process loss/join checks remain in the schedule.

The first installed attempt expects `incompatible_native` for every malformed
page. The existing port instead reports `read_failed` when a neutral reply fails
its generated schema before metadata decoding. The corrected test checks those
exact categories separately from semantic metadata failures. No transport error
mapping changes. The failed attempt remains at
`/tmp/transit-sql-catalog-beam-metadata-native.log`.

Rebuilt installed packages pass
`just test::catalog --sdk erlang --sdk elixir --grow 17` in **81.413 s**, including
**9.413 s** installation. Both agree with Zig/ABI/port/CLI on **24 definitions,
three full pages and an empty final page**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. Creation/control recovery retains seven lost caller replies and three
lost owner replies. Counts are 6002 reads, 3144 caller reads and 59 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. Each
language makes seven populated listings at four signed reads and two empty final
listings at two signed reads with negotiated batch support.

Source is development based on `bbb6e11d`; native binary hashes are unchanged.
Report/package hashes are `/tmp/transit-sql-catalog-beam-metadata-native.json`;
logs are `/tmp/transit-sql-catalog-beam-metadata-build.log` and
`/tmp/transit-sql-catalog-beam-metadata-native-fixed.log`. All ten SDK metadata
APIs now have focused installed evidence. Cumulative full `just check` passes at
`/tmp/transit-sql-catalog-all-metadata-full-check.log`, including the documentation
build. The first combined command stops at argument parsing because splitting the
Ruby/C commits accidentally removed `c`/`cpp` from the runner's allowed options.
Those options are restored; the stopped attempt remains at
`/tmp/transit-sql-catalog-all-ten-metadata-native.log`. This record does not
establish a completed combined run or a clean-suite pass.

### Combined metadata cleanup investigation

The ten-language metadata schedule at committed `8e021cc6` completes its
functional assertions for **33 named definitions over five pages**, before/after
disk restart, with sixteen lost caller receipts and three lost owner receipts.
It remains **failed**: an installed caller closes stdout during final cleanup
without the expected close response, and the original diagnostic observes its
exit status before reaping. Counts are 15846 reads, 8560 caller reads and 86 turn
responses; bounds remain four mutations, 134-byte values and eight resident pages.
Elapsed time is 356.319 s, including 61.592 s installation. The failed report is
`/tmp/transit-sql-catalog-all-ten-metadata-native-failed.json`; the log is
`/tmp/transit-sql-catalog-all-ten-metadata-native-fixed.log`.

The fixture now joins an EOF child before reporting its exit code and annotates
catalog cleanup failures with the caller surface. Those diagnostics do not
change SDK behavior or turn an incomplete cleanup into success.

The same ten-language command with `--grow 17` passes on development source
based on `8e021cc6`, with those diagnostics and test-only growth timing, in
**393.676 s**, including 85.563 s installation. All fourteen metadata surfaces
agree on 33 definitions over five pages before/after disk restart, current
denial, sixteen lost caller replies and three lost owner replies; final cleanup
reports no failures. Counts are 16473 reads, 8565 caller reads and 86 turn
responses, with the same four-mutation, 134-byte-value and eight-resident-page
bounds. All six native binary hashes match the earlier focused runs. Report and
package hashes are `/tmp/transit-sql-catalog-all-ten-metadata-native-diagnostic.json`;
the log is `/tmp/transit-sql-catalog-all-ten-metadata-native-diagnostic.log`.
This successful rerun does not identify the earlier cleanup failure's cause or
erase that failed run. Surface and final-exit diagnostics remain in the fixture
for recurrence; no SDK runtime fix is claimed.

The clean core run at `8e021cc6` passes 21 of 22 tasks, then fails
`test::state`: its current-resource poll races the separate maintenance process
and receives HTTP 409 `Conflict`. The authority's final journal-tail check in
`growing_read.zig` deliberately rejects that changed observation; no mixed cut
is returned. The reclamation poll now discards exactly that conflict and reads
a fresh cut within its existing ten-second deadline. Denial, unexpected errors,
command retries and fixed-cut continuations are unchanged. The focused
`just test::state` rerun passes at `/tmp/transit-sql-pr27-state-maintenance.log`.
The failed clean report remains at
`/var/tmp/transit-ci-n4hi0a30/src/.cache/ci/core.json`; its log is
`/tmp/transit-sql-catalog-all-metadata-ci-clean.log`. It is not a clean-lane pass.

The next committed clean core attempt at `0621d2a1` fails the external Vortex
schedule after two rounds. Its third turn receives HTTP 503 `AuthorityTimeout`;
the proxy drops that response, and the supervisor incorrectly assumes acceptance
before killing the worker/node/store. The recorded history establishes a missing
test premise, not lost accepted work. Evidence remains under
`/var/tmp/transit-ci-l2btxgaw/src/.cache/verification/vortex/1790796726338078073-seed-1/`
and `/tmp/transit-sql-pr27-state-fixed-ci-clean.log`.

Response-loss/delay injection now waits for HTTP 200 acceptance, forwarding other
responses and retaining the armed fault within the existing supervisor deadline.
An independent loopback proxy check forces a 503 followed by acceptance for both
fault kinds and checks that only the accepted response triggers the fault. It
passes at `/tmp/transit-sql-pr27-vortex-proxy.log` and runs in `test::vortex`.
The real disk schedule `just test::vortex --seed 19 --rounds 12` passes in
**33.892 s** with joined cleanup after this correction; its report/history are
`.cache/verification/vortex/1790796842894520667-seed-19/` and its log is
`/tmp/transit-sql-pr27-vortex-acceptance.log`. Production admission, timeouts and
recovery assertions are unchanged. Neither prior failed clean attempt is a pass.

### Catalog growth attribution

`just test::catalog-growth` runs the disk-backed schedule with 65 additional
Tables; `just test::catalog --grow 257` selects the larger investigation. The
report at `.cache/verification/catalog/native.json` retains source revision,
dirty status, runner and native binary hashes, growth progress and failure state.
Copy it before another run overwrites it. No timeout, cache, turn or value limit
changes with this instrumentation.

The report separates `compile`, `prepare`, `admit` and `await_application` wall
time, calls, failures and caller reads. A failed phase retains its zero-based
growth index; a successful application clears it. An admitted send is not an
applied Table, and a failed status read does not establish rejection. A baseline
immediately before growth and cumulative samples every sixteen Tables (plus the
last Table) allow subtraction of setup work and comparison of successive blocks.
Cursor checks during growth remain outside the four timed phases.

The owned proxy groups upstream attempts by fixed caller/owner/administrator/
other roles and native operation. It records transport failures, HTTP errors,
cumulative elapsed nanoseconds and the maximum observed duration. Durations end
after the upstream body is read; they include queue/provider work and proxy
overhead, overlap across requests, and are not independent CPU measurements.
Deliberately blocked requests never reach upstream; lost-reply attempts count
even when the caller cannot observe the result. Counts describe attempts, not
unique durable commits. Metrics contain no request bodies or credential values.
Compare native request counts and phase costs at equivalent workload boundaries;
shared-host durations do not establish percentiles or throughput guarantees.
After stopping the node, the report also retains at most 64 distinct node/storage
error groups, with occurrence counts, first timestamps and maximum observed
durations. Further groups increment a dropped counter. These summaries preserve
errors that can fall outside the printed log tail, without retaining payloads,
credentials or user labels; they do not establish operation outcomes.

The first instrumented disk runs use runner SHA-256
`63fa35689262d5fce12b5a303fcf390f3812931cf9a64a6375e7e76e3eb47fbe`
and the same six native binaries, with eight resident authority pages. The
65-additional-Table run at committed `d681181d` passes in **233.028 s**, lists
70 named definitions in nine pages, and repeats the metadata checks after
node/store restart. Cleanup joins. Growth itself takes **112.669 s**:

| Phase | Calls | Seconds | Caller reads |
| --- | ---: | ---: | ---: |
| Compile | 65 | 0.010 | 0 |
| Prepare | 65 | 1.923 | 130 |
| Admit | 65 | 10.595 | 0 |
| Await application | 65 | 99.922 | 1089 |

Growth-only upstream observations include 65 owner turns (**41.125 s**), 845
owner entry reads (**38.810 s**) and 1170 caller entry reads (**89.375 s**).
These overlapping durations include serialized authority/provider work and
contention; they are not additive phase costs. Validation runs share the host.

The 257-additional-Table attempt at committed `05454efd` fails in **508.687 s**
after **138** additions apply. The next send is admitted, then index 138 remains
in `await_application` at the unchanged twenty-second progress deadline. Owner
turns repeatedly report `AuthorityUnavailable`. Cleanup joins, but the final
listing/restart checks are not reached and the pending operation's outcome is
not established. This attempt supplies failure attribution, not a larger-growth
pass. Both reports retain complete binary hashes and source identities; later
rebases preserve the runner's content.

Committed-head clean experience runs at `1c4d91e1` (source tree `3d38f5a7`,
matching the merged implementation) and `0dc49100` (tree `6216f338`, matching
the rebased attribution increment `c79c4307`) each pass six of seven tasks.
Board query inspection passes in **103.43 s** and **101.79 s** respectively.
Both fail `launchers::local::test-station` waiting for the requester Arrow reply,
after **275.54 s** and **277.76 s**. Private fixture logs and WALs are retained
for diagnosis. Neither is a clean experience pass; these runs do not supersede
the separate full `just check` passes or establish all clean-suite gates.

The corrected clean core run at `4927ba38` passes nineteen tasks, including
Vortex, Station and all disk storage phases. It then fails `test::callers` in
**17.63 s** when the courier-progress observation sees `AuthorityUnavailable`;
the last two core tasks are not reached. Node observations show a two-second
request deadline interrupting page staging and a queued observation. This is
not a clean-core pass or a demonstrated root cause of the earlier catalog failure.

### Balanced batch splits and larger catalog growth

The original binaries repeat the failure after exactly 138 applied additions
in **564.408 s** with the diagnostic runner. Cleanup joins and no storage-error
group is recorded; sixteen native attempts report `AuthorityUnavailable`.
The independent descending-key page regression fails with `PageDepthExceeded`:
batch splits pack one sibling full, so descending inserts repeatedly split the
left spine and reach the 32-level guard before 257 keys. Evenly distributing
entries and children across split pages fixes that insertion pattern without
changing page encodings, mutation budgets, resident limits or deadlines.

At committed `1483b330`, all **60** standalone core tests and full `just check`
pass. The new regression checks 257 descending keys in batches of one, four and
eight, retained roots, ordered scans and at most nine page loads per lookup.
`just test::resource-simulation --seeds 8` passes **798 traces / 15,496 events**
with identical replay in **437.762 s**. All six negative controls are detected.
Its binary SHA-256 is
`82db89402f28ae6b1d28b999392600c912870c2f67bae7f8d220ef659bfacda6`;
the two-page in-memory fault store does not establish physical disk durability.

`just test::catalog --grow 257` then passes in **397.642 s**, including **262
named definitions / 33 pages**, repeated metadata after node/store restart,
current denial, original lost-reply recovery and joined cleanup. It uses eight
resident authority pages, at most four turn mutations and 132-byte values.
Only the node binary differs from the original runs; its SHA-256 is
`214b0646e187cd12676c995d4b2badd0e4962631988df0946440039b32dfcd04`.
The five caller/host binary hashes remain equal. The report retains all hashes
and the diagnostic runner identity.

The 257 growth additions take **254.420 s**: compile **0.041 s**, prepare
**3.488 s**, admission **30.433 s**, application waiting **220.260 s**.
All growth phases succeed. There are 257 owner-turn attempts and 3341 owner-entry
reads (thirteen per Table), with no growth transport/HTTP errors. These shared-host
instrumented samples establish the completed workload, not a throughput ratio.
The existing roots of previously deep catalogs are not rebuilt; continuation
from an already exhausted height guard remains a separate recovery qualification.
Committed-head `just ci-clean --lane core` at `1483b330` passes all **22 tasks**
in **947.49 s**, including the caller-progress test that failed in the earlier
attempt. Its completion/timing records are retained under
`.cache/ci/clean/1483b330d7b9-transit-ci-lwcj_yf3/`. Subsequent changes only record
evidence in this ledger and the roadmap; their documentation links pass. This
is a clean core-lane pass, not an experience/bindings/complete-suite or hosted
CI pass. The earlier experience failures are not reclassified as successes.

### Resuming a depth-exhausted catalog

The optional `test::catalog --grow 257 --initial-node PATH` schedule starts
with an explicitly supplied pre-fix node binary. Its digest is recorded alongside
the target binary. At the known zero-based growth index 138, it requires two
`AuthorityUnavailable` responses to the exact same owner turn, then replaces
only the node binary across disk-store restart. The worker and its frozen turn
stay alive. Success requires that same turn's receipt and the originally admitted
SQL input, followed by continued growth and the normal metadata/restart/denial
checks. The SQL send is not resubmitted. No operation deadline is increased.

Failure joins owned services and retains the private fixture under
`.cache/verification/catalog/recovery-failures/`; it contains credentials and
must not be published. `node_recovery` records the initial digest, original turn
digest, input, observed failures, replacement and receipt state. Retained
configurations still name their original temporary paths; the fixture is
diagnostic evidence, not an automatically restorable launcher installation.

With source based on `ef2cc97d` and the recovery runner under development, the
original node digest `1039c8de…328d6e07e` stalls after 138 additions. Replacing it
with the split-only node `214b0646…2dfcd04` still fails the unchanged progress
deadline in **416.073 s** total. Input **538** remains without an observed turn
receipt. The private fixture is retained; this is not successful recovery.
A separate current-v1 page fixture with a full spine and sparse siblings at
height 32 also fails `PageDepthExceeded` before local sibling merging. After
merging, all **61** core component tests pass, including 64 further inserts,
old-root preservation and refusal/lost-acknowledgement at every staging boundary
of the first repaired mutation. Disk qualification of that repair follows.

At `85009af5`, the repaired node `89e7f544…d65f0a19` resumes the exact original
turn: input **538** produces receipt **540**, with the worker and signed turn
unchanged across replacement. The full run still fails after **145** additions
in **477.296 s**. Ursula reports `ColdBackpressure` at its **64 MiB** hot-store
limit; this fixture has no cold tier. The node records 161 `page.stage`
`ServiceUnavailable` failures. Joined cleanup succeeds and the private fixture
is retained. This establishes receipt recovery, not full growth qualification.

`--cold` selects the existing owned S3 fixture with an **8 MiB** hot-store
limit and **8 MiB** cold cache. It requires actual persisted cold chunks and
records object count and file bytes. Use it with `--initial-node` for continued
growth beyond the hot-only fixture's capacity; operation deadlines, eight
authority cache pages and four application mutations remain unchanged. Failed
upgrade runs retain the stopped cold-store files with their private disk fixture.
The first cold run at `1f6dd4ee` fails on `AuthorityTimeout` before node
replacement. Its proxy-drain cleanup then fails, so the last report contains
only an earlier **112-addition / 263.393 s** sample; final progress and fixture
retention are not established. `b97406fe` makes cleanup continue through
authority/proxy shutdown and final reporting after a drain error, and retains
failed upgrade fixtures even when cleanup itself fails.

The retry at committed `b97406fe` passes in **1438.997 s**. It recovers original
input **538** as receipt **540** after two failures of the same signed turn,
then applies all **257** additions. All **262 definitions / 33 pages** pass
Zig, ABI, port and CLI metadata checks, a further node/store restart, current
denial and joined cleanup. The worker and original SQL input are preserved;
no send is resubmitted. The run retains eight authority cache pages, four
mutations and the unchanged operation deadlines. Its S3 fixture uses an **8 MiB**
hot limit and **8 MiB** cold cache, and holds **1125 persisted cold chunks** and
**142,532,884 filesystem bytes** including object-store metadata.

Growth takes **823.220 s**: compile **0.040 s**, prepare **15.111 s**, admit
**78.784 s**, and await application **729.043 s**. There are **4890** measured
metadata calls across the complete schedule. The only `AuthorityUnavailable`
responses recorded by the node are the two expected pre-replacement failures;
cleanup reports no failures. These shared-host durations are not a throughput
comparison with the fresh balanced-tree schedule. Earlier failed runs remain
failed, and their causes are not inferred from this retry's success.

The target node digest is `89e7f544…d65f0a19`, the initial node is
`1039c8de…328d6e07e`, and the runner is `f9329712…67ac8b82a`.
The full hashes, source identity and measurements are retained in
`/tmp/transit-sql-deep-catalog-recovery-cold-retry.json`; its matching `.log`
contains the executed command and completion output.

The same `85009af5` passes full `just check` and the eight-seed resource
simulation: **798 traces**, **15,496 events**, **1598 executions**, identical
replay and all six negative controls in **431.120 s**. Its committed-head clean
core attempt fails in the first task's CLI terminal cleanup after **81.49 s**;
the remaining 21 tasks do not run. Strict cleanup diagnostics expose exit 130
when cleanup sends Ctrl-C during command output. The fixture now queues editor
draft clearing and ordinary `.quit`, preserving explicit interrupt tests and
rethrowing unexpected exits/timeouts. The focused 399-case CLI diagnostic suite
passes with queued quit. Full `just check` also passes after the terminal cleanup
and diagnostic-path lifetime fixes.

Committed `1f6dd4ee` then passes all **22 clean-core tasks** in **1154.37 s**
and all **seven clean-experience tasks** in **501.07 s**. Core includes the
399-case CLI diagnostic suite, simulations, disk WAL/recovery, callers,
inspection and state. Station's disk readiness write takes **307.79 s** and the
complete storage task **481.35 s**; the experience Station replacement/restart
task takes **283.96 s**. Evidence is retained in
`.cache/ci/clean/1f6dd4eec3fd-transit-ci-58qo5jmn/` and
`.cache/ci/clean/1f6dd4eec3fd-transit-ci-mr8_g_9s/`. These are two lane passes,
not the complete CI inventory. The later catalog cleanup change affects only
the proof runner and remains under focused disk qualification.

The clean experience run at rebased `ef2cc97d` passes all **seven tasks** in
**433.89 s**, including Station's Arrow exchange, replacements and persistent
restart in **220.67 s**. This revision includes main's type/schema-discovery
documentation, with unchanged split-only runtime code. Evidence is retained in
`.cache/ci/clean/ef2cc97dc6b0-transit-ci-dl5e5q05/`. It does not retroactively pass
the earlier failures or qualify the subsequent sibling-merging change.

### Shared immutable paths for bounded point reads

`edb54a12` adds a bounded tree traversal for native `read_entries`. It retains
caller order and current native authority checks while sharing immutable paths
among the existing eight requested keys. Component fixtures cover absent and
repeated keys, invalid input before I/O, every selected page-load failure,
corruption and retained roots. The depth-32 eight-key fixture records **37 page
loads**, compared with **264** separate lookup loads. These counts are component
I/O evidence, not a native throughput result.

All **62 core component tests**, full `just check` and the eight-seed resource
simulation pass. The simulation records **798 traces / 15,496 events / 1598
executions**, identical replay and all six negative controls in **437.816 s**.
Committed-head `just ci-clean --lane core` passes all **22 tasks** in
**1060.07 s**. Evidence is retained under
`.cache/ci/clean/edb54a12a558-transit-ci-4bx7pg1w/`; this is one lane, not the
complete CI suite. Subsequent history changes and parent evidence documentation
do not change these runtime files.

The cold-tier legacy-root recovery schedule at the same clean source fails in
**1248.201 s**, after **213** additions, on `AuthorityTimeout` during the next
application-status read. The original input **538** recovered as receipt **540**
after node replacement, but the remaining growth and larger metadata/restart
phases did not complete. Joined cleanup succeeds and retains the private
fixture. This is not a full recovery-profile pass. Node diagnostics record two
additional ten-second `AuthorityUnavailable` requests and `ReadFailed` events
for page staging and journal tail; these observations do not establish the
timeout's cause. Operation deadlines and resident bounds are unchanged.

The runner is `f9329712…67ac8b82a`, the target node is
`fa29956b…fdf8f`, and the other five binaries match the completed sparse-sibling
baseline above. Source, full hashes, failed phase and retained fixture location
are recorded in `/tmp/transit-sql-shared-point-read-cold-recovery.json`, with its
matching `.log`. The private fixture includes credentials and must not be
published. PRs #40 and #41 are merged; merge status does not qualify this failed
schedule or establish a performance improvement under native cold storage.

### Shared reads for catalog mutation counts

The `perf/sql-catalog-mutation-reads` continuation starts from merged #41 at
`d5541301` in its own `rey-sql-catalog-mutation-reads` worktree. Catalog mutation
counting now uses the existing bounded `Tree.getMany` before staging the new
candidate. It validates all keys, values and duplicate keys before page I/O,
reads the original immutable cut, and updates the root and count together only
after successful staging. The eight-key bound and current v1 formats are unchanged.

The standalone core suite passes **64 tests**. An eight-operation fixture over
64 existing records mixes inserts, replacement, deletes and no-ops in unsorted
caller order. It records **45 page loads** with separate existence reads versus
**23** with shared traversal, including the same subsequent tree mutation in
both counts. Both produce the same immutable candidate root. Independent expected
values check all 130 addresses in the selected range and the retained old cut;
the new count is 65. Every observed read failure and staging failure/lost
acknowledgement preserves the original candidate root and count. Corrupt pages
reject; empty/no-op batches do not stage; malformed and oversized batches reject
before reads or writes. The log is
`/tmp/transit-sql-catalog-mutation-batch-unit-final.log`.

This is component I/O evidence, not a native latency improvement. The earlier
shared-point-read cold recovery failure remains open: a status observation times
out after 213 additions, while the original accepted turn has recovered. Its
retained node log shows the final read spending almost ten seconds waiting
behind an `open_view` write that also reaches its deadline. The batching change
reduces demonstrated repeated work; it does not by itself diagnose that provider
stall or qualify the full native recovery schedule. Full checks, resource-fault
simulation and native/committed-head clean evidence are recorded separately.

At committed `68794bd7`, full `just check` passes, including generated contracts,
CLI, frontend and documentation checks. The eight-seed resource simulation
passes **798 traces / 15,496 events / 1,598 executions**, with identical replay
in **450.845 s**. Its report records dirty source based on `d5541301`; the
production source was committed unchanged as `68794bd7`. Committed-head
`just ci-clean --lane core --work-root /var/tmp` passes all **22 tasks** in
**1254.78 s**, without inherited workspace build outputs. Evidence is retained
under `.cache/ci/clean/68794bd70102-transit-ci-w03ie6wa` and in
`/tmp/transit-sql-catalog-mutation-batch-resource-simulation.json`.

The native cold-recovery schedule at that same committed revision **fails after
149 applied additions / 944.550 s** on an application-status `AuthorityTimeout`.
Original input **538** recovers as receipt **540** without resubmission. Joined
cleanup succeeds. Eight authority pages, four mutations, the 8 MiB hot store
and 8 MiB cold cache remain the bounds. The full 257-addition continuation,
later metadata/restart and disclosure checks are unqualified for this candidate.
The record is `/tmp/transit-sql-catalog-mutation-batch-cold-recovery.json`; the
private failure fixture remains under
`.cache/verification/catalog/recovery-failures/1790809229338501922`.

Its final node events distinguish a turn reaching the ten-second deadline
(52 cache hits / 912 misses) from the following read spending **9.950 s**
waiting and **0.050 s** working before its own deadline. A later turn is logged
successful at position **573**, but the interrupted proof did not observe its
application status. Neither that log nor component page-load savings qualifies
the missing end-to-end assertions or establishes the storage stall's cause.
The complete native run remains failed; no deadline has been increased.

## SQL branch integration of seeded simulations

The SQL branch rebases onto `a53d6262` (merged PR #33), preserving the expanded
resource, shared Session/courier, component and external fault suites. The
consolidated query and protocol owners remain in use. All 75 rebased commits
retain their author dates and use matching committer dates. Conflict resolution
preserves both task/invariant inventories and roadmap scope; Session and courier
production files match main exactly.

On development source based on `9140972c`, pinned Zig
`0.17.0-dev.2267+48abf1a34` and the bindings shell:

- Full `just check` passes, including unit tests, generated contracts, CLI
  diagnostics, frontend checks and the documentation build. Final direct checks
  pass 4581 links across 480 files and 56 invariants/53 bounds/13 SDK scenarios.
- `just test::domain-simulation --seeds 8` passes **40 package schedules with
  identical replay in 13.302 s**. The new catalog domain runs 512 requests over
  eight seeds: 128 fresh Tables and 128 conflicts of each kind. Every round
  injects a point/page failure and compares committed state with an independent
  accepted-request ledger; seeded choices also cover revocation, discarded
  proposals and replacement after lost replies. Each seed ends with 115 keys,
  sixteen created Tables and all 64 original receipts. Sorted bounded pages and
  changed-cut rejection are checked throughout.
- The catalog test binary SHA-256 is
  `8d69a473d37ba62b800965f8f0f372c11b58f20aab3ff522c421062fecc53a05`;
  runner SHA-256 is
  `2b157b687d1c9f12e87efc56f7277e7b0605e802099da974846d694a3c361a06`.
  `.cache/verification/domain-simulation.json` records all five binary hashes,
  source/dirty status and per-seed trace hashes; its adjacent directory retains
  original and replay events/logs.

Logs are `/tmp/transit-sql-pr33-full-check.log` and
`/tmp/transit-sql-pr33-domain.log`. These private-turn stores model atomic
publication; they do not qualify physical journal faults, native catalog growth,
signed transports or installed SDKs. Compiling catalog policy/receipt mutants
are registered for the committed-source checker; registration alone is not a
passed mutation proof. Separate execution results follow their completed runs.

Committed `08fd00a6` also passes `just test::domain-simulation-mutations`.
All seven compiling mutants are detected by executed assertions, including the
new current-create-policy bypass (2.420 s) and overwritten receipt position
(2.375 s). The baseline and original five component defects pass their expected
checks; build failures are not counted. Evidence is
`.cache/verification/domain-simulation-mutations/evidence.json` with per-mutant
traces/logs, and `/tmp/transit-sql-pr33-domain-mutations.log`.

The rebased resource run (`just test::resource-simulation --seeds 4`) passes
**402 traces / 7804 events with identical replay in 216.661 s**. The shared-client
run (`just test::scheduler-simulation --seeds 8 --steps 96`) passes **12 traces /
1410 events in 37.499 s**. Both began on development source based on `9140972c`;
reports retain exact binary/oracle hashes and configuration. Logs are
`/tmp/transit-sql-pr33-simulations.log`. Resource faults use the atomic in-memory
journal premise; the scheduler uses signed in-process transport. Neither result
expands the documented physical-durability or host-cancellation evidence.

Python, TypeScript, Rust and Ruby packages are rebuilt against the rebased
libraries before `just test::catalog --sdk python --sdk node --sdk rust --sdk ruby`.
The combined installed schedule passes in **48.876 s**, including **25.066 s**
installation: **2157 reads, 51 accepted turn responses, ten lost caller receipts
and three lost owner receipts**. Original receipts, current catalog/native denial
and replacement after lost admission pass for all selected callers. Bounds remain
four mutations, 133-byte values and eight resident pages; twelve Tables do not
establish native catalog growth. This report binds `08fd00a6` with dirty status
(the resumed C/C++ source is uncommitted and not selected). Artifact hashes and
execution output are retained in `/tmp/transit-sql-pr33-sdk-native.json` and
`/tmp/transit-sql-pr33-sdk-native.log`.

Rebuilt native SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| `node` | `6f27157343edbf4311ceaeba4444566c9ce91a761ce2f6b647a2e0667d393e8c` |
| `proof` | `03074b53ddcb92a57e63a00f2e2b53093fc61efaf5b8cdca4ae3214f1464340f` |
| `host` | `64fd1efeeb6cee7a182271439cb429fa2fc4c68d31e8a68c2e82b74bb70faa72` |
| `port` | `67db289ec20b1e2dc94ebe918694f17be34d5c33dc1e219e8bc72a723f284643` |
| `library.so` | `85411c09a7e8bc832050fead3fc93c5eb54eeb37966f847ff6f2f7792dc9780c` |
| `cli` | `ec1ee54bcf1e41a345b7a52e4398fbcfa012adc530240af943677aefc2d76351` |

Committed-HEAD `just ci-clean --lane core` passes **all 22 tasks at `08fd00a6`
in 744.86 s**, including the added resource, shared-client, catalog/component and
external fault suites. It installs locked frontend dependencies and runs from a
fresh clone without inherited build outputs. Completion and per-task timing are
in `.cache/ci/clean/08fd00a6d234-transit-ci-9cznago1/`; the log is
`/tmp/transit-sql-pr33-ci-clean.log`. This qualifies the expanded core lane and
separately recorded focused schedules, not a full clean suite or the resumed
uncommitted C/C++ implementation. Existing incomplete proof runs remain recorded.

## Offline state declaration compiler

The additive Fuze `Declaration` API parses, validates and formats owned
`CREATE TABLE/KV/DOCUMENT` definitions. Its explicit `tableSchema` adapter accepts
only the existing two-column Table profile. This is offline compiler evidence;
it does not qualify a catalog, resource creation, grants, publication, language
SDK/CLI administration or wider Table storage. Existing native and ABI definitions
are unchanged. [The contract](../contracts/STATE_DECLARATION_V1.md) owns semantics;
`SQL-DECLARATION-01` and the per-definition bound are in the verification inventory.

Executed in the pinned bindings shell on the development source based on
`aba61401`:

- Full `just check` passes, including generated contracts, native/package tests,
  CLI diagnostics, frontend checks and the production documentation build. Final
  proof-inventory and documentation checks cover 51 invariants, 52 classified
  bounds, 12 SDK scenarios and 4498 local links across 472 files.
- Standalone `transit-fuze` `zig build test` passes, including five declaration
  tests for owned names, canonical padding, sparse/duplicate columns, whole-input
  rejection, formatting buffers and explicit Table capability checks.
- `just test::sql` passes **182 declaration cases**, including the complete
  four-type/three-nullability product for both Table columns. **156 Zig/ANTLR
  ASTs agree**, canonical formatting reparses in both implementations, and five
  compatible definitions match independently calculated existing Table schema
  fingerprints. Other cases reject at syntax, structural or capability boundaries.
  Existing SELECT/Arrow, unified-source and mutation oracles also pass.
- `just test::sql-benchmark --samples 7 --output
.cache/verification/sql/state-declaration-benchmark.json` records seven warmed
  ReleaseSafe processes with 10,000 compilations per case. The pinned compiler
  is `0.17.0-dev.2267+48abf1a34`; the probe SHA-256 is
  `83e09098bd4ac3877a8dec229b22936d70ac8fe0bcad9b2ee464799f77948ad9`.

| Offline declaration | Median ns/compile | Observed min–max |
| ------------------- | ----------------: | ---------------: |
| Two-column Table    |            296.92 |    284.35–317.55 |
| KV                  |            133.13 |    130.98–136.94 |
| Document            |            119.28 |    114.54–120.86 |
| Eight-column Table  |            632.59 |    612.16–636.75 |

The raw report identifies dirty source, platform and binary. This is a local
compiler baseline with no allocation, source I/O, authorization, publication or
transport work. It is not a before/after speedup or end-to-end latency claim.

At committed implementation `0bb8364c`, `just ci-clean --lane core` passes all
18 tasks without inherited workspace build outputs: foundation, properties,
simulation, codecs, tooling, packages, compute, client ABI, Station, disk storage,
service, runtime upgrade, callers, inspection and state. Package builds take
135.06 seconds, Station 150.09 seconds and storage 212.97 seconds, including the
129.00-second readiness write schedule. Completion, exact revision and timings
are retained under `.cache/ci/clean/0bb8364c2384-transit-ci-3clcw1pd/`.
The following evidence-only commit changes no production source. This is a
complete core-lane pass plus the focused SQL proof above, not a full clean-suite
or administrative-execution qualification.

## Rust native lifetime investigation — 2026-09-30

Following PR #33, a fresh installed Rust suite passed on the merged source
`a53d6262`, while a separate repeated malformed-input schedule reproduced the
`decode-block` SIGSEGV on case 108 after 107 successful fresh cases. A retained
core shows the detached native thread returning from `futexWake` through
`Io.Threaded.WaitGroup.finish` and `Io.Threaded.worker` after the client library
was unmapped. The Rust owner was removing the extracted artifact, and the main
thread was joining that owner. Thus a passing ordinary rerun does not resolve
the failure.

The Rust loader now retains bounded shared code mappings until process exit,
while handle and buffer destruction remain explicit. Installed raw/Station
regressions check actual Linux mappings across close and repeated open. The
focused `nix develop .#bindings --command just bindings::rust-lifetime 256`
reuses the existing installed-consumer/real-authority fixture with fresh
malformed inputs. It checks the failure marker, unchanged input progress and
empty resource after each case. The case argument is bounded to 1–1024 and
defaults to 128; this is a selected host schedule, not deterministic OS replay.
The installed consumer is reused across independent fixtures of at most 32 cases,
with each history verified before joined cleanup. An initial 256-case attempt in
one history exhausted the fixture's 64 MiB hot-storage quota during provisioning.
It did not complete and is not lifetime evidence for all 256 cases. Quotas remain
unchanged; the batched profile keeps this host-lifetime proof within its scope.
The corrected batched run passed all 256 cases across eight independently verified
histories using one installed consumer build, followed by joined cleanup.

Qualification of the correction is in progress. An initial corrected run passed
the raw-client regression but could not compile the Station consumer because
the shared `/tmp` filesystem ran out of space. That incomplete run is not a pass;
subsequent work uses an owned disk-backed `TMPDIR`.
The full corrected installed Rust client, Station, HTTP and gRPC suite then passed.

The [follow-up record](verification/results/m37-followup-2026-09-30.json)
retains hashes and separates incomplete, passing and unexecuted profiles.
Installed raw-client checks passed, including sixteen I/O/open/close repetitions
and override reuse/replacement/missing-file rejection. A compiling mutation that
removes library retention fails the mapping assertion immediately. The authority
(14 traces / 749 events), resource (204 / 3,958), shared-client (eight / 542)
and component (eight schedules) simulations passed with identical replay.

The first concurrent clean attempts at `4ae88b99` remain incomplete. Core passed
21 tasks, then its final state test observed `Conflict` while maintenance changed
the authority tail during a resource metadata read. The corrected maintenance
poll retries that fresh read within the existing ten-second deadline; the focused
state proof passed. Snapshot cuts and mutation retries are unchanged. Growth
exceeded its existing 240-second Station write deadline, experience received
`503 Unavailable` observing a Board operation, and bindings reported an unexpected
Python Station event. Runner assertions now preserve the actual unexpected event.
These results do not establish the complete ordinary gate.

An isolated clean bindings run at `2b9faa53` passed generated contracts, native
conformance and the complete Python, Node and Rust SDK tasks. The Rust task took
574.66 s. The lane then stopped in Ruby when a query turn correctly returned
`NeedsRecovery` with `AuthorityTimeout`; the fixture had assumed immediate
commitment. Ten later tasks were unrun.

The shared fixture now repeats explicitly unavailable reads and reconciles
transient dispatch/confirmation failures through the installed host API. It
checks that `next()` remains paused, saved bytes stay unchanged and observed
same-identity command attempts remain byte-identical. Recovery shares the existing
180-second progress deadline and has at most eight recovery/read steps. Other
outcomes still fail. A deterministic unavailable read and unavailable reply after
acceptance challenge those paths; the accepted schema input must be consumed once.
The focused Ruby schedule passed with both faults: one unavailable read repeated
and one accepted outcome reconciled, followed by all Table, IPC, revocation and
lifetime checks. `just check` passed with the corrected fixtures.

Board's focused query proof passed after its fixture learned to repeat only
unavailable observations of the same receipt within the existing 60-second
deadline. It does not prepare or submit replacement work. The isolated complete
growing-service proof also passed without code or deadline changes: Station write
took 71.616 s against 240 s, and query delivery took 149.820 s against 180 s.
Earlier timing failures remain separate evidence.

The subsequent clean growth lane at `dae70a38` passed 14 tasks, including query
delivery in 145.224 s and the complete gRPC streaming/restart proof. Its gRPC fault
fixture then reached its declared 60-second process work cutoff while preparing
the second call for the blocked-peer scenario. `DeadlineUncertain` correctly
prevented further ordinary work; that scenario's intended control challenge had
not begun. The remaining three growth tasks and four later lanes were unrun.
The cutoff scenario now uses a separate disposable disk installation after the
crash/revocation installation is joined. It declares a 120-second work lifetime
before spawning and verifies that the recorded work and settlement cutoffs stay
unchanged through preparation and closure. It starts the RPC in the final
30 seconds of that work window. The 10-second control-progress limit remains
unchanged; cold-spill evidence belongs to the preceding crash/revocation profile.
Expiry waits through the configured
10-second clock-error bound and requires `DeadlineExpired`, rather than accepting
any failed dispatch. This scenario declares the peer's existing 120-second block
window as its RPC timeout before preparing the request, and checks that both the
worker and remote RPC remain active when closure completes.

An initial isolated attempt failed the combined closure-duration/worker-alive
assertion before its operands were logged; the original operand remains
unattributed. Four diagnostic reruns passed, with closure taking 0.186–0.711 s.
Those passes precede the definite-expiry and active-peer assertions and do not
erase the earlier failure.

A full rerun then took 59.078 s just to prepare both calls in the fresh
installation; the worker exited before reaching the peer. This demonstrated
that separating installations alone did not establish the intended pre-cutoff
dispatch premise. The 120-second work window is selected before admission to
accommodate setup; the test still requires definite expiry, an active remote
call, bounded closure and permanent retirement.

The lifetime diagnostic initially used the execution-read selector after work
expiry, which correctly rejected input access even though closure had passed in
0.294 s with an active peer. It now uses public inspection for retained process
metadata. `just test::grpc-control` runs this isolated portion directly;
`just test::grpc-faults` still includes both crash/revocation and cutoff profiles.
The corrected focused proof passed in 133.06 s excluding compilation, with
closure in 0.181 s while the worker and remote RPC remained active. It verified
unchanged recorded cutoffs, exact `DeadlineExpired`, duplicate-closure rejection,
permanent retirement and pending-effect cancellation. `just check` passed with
the corrected fixtures and focused task registration.

The next combined proof passed all crash boundaries and dispatch revocation,
then failed while starting the separate control installation: MinIO returned
HTTP 503 to bucket creation after its health probe returned ready. Bucket creation
now retries only HTTP 503 using the same signed request and the original
30-second startup deadline. An injected 503 followed by real MinIO creation
passed; negative checks retained immediate non-503 failure and deadline exhaustion
under persistent unavailability.

The expanded deterministic profiles passed on committed sources. Authority and
resource reports identify `028e2f7b`; shared-client and component reports identify
`2b9faa53`, whose intervening change corrects the separate state API polling fixture.
All four retain clean-source identity, binary/oracle hashes and identical replay.

| Expanded profile | Executed result | Simulation time |
| --- | --- | ---: |
| Authority: 32 seeds, 128 steps | 38 traces / 5,293 events | 119.304 s |
| Resources: four seeds, every observed I/O boundary | 3,202 traces / 60,704 events | 1,744.224 s |
| Shared client: 32 seeds, 128 steps | 36 traces / 6,490 events | 158.158 s |
| Components: 32 seeds | 128 schedules across Document, Exchange, query/refresh and runtime owners | 38.139 s |

The resource checker rejects corrupted values, input progress, outputs and views,
plus stalled and incomplete histories. The retained reports include the full trace
hash lists and actual fault counts. These in-process results preserve the existing
atomic-journal premise; disk durability and host scheduling use their separate proofs.

At committed `ee4770c9`, the complete clean bindings lane passed all 16 tasks in
7,096.414 s including setup. This includes every installed SDK, the ten-language
interoperability ring, finite models, SQL checks and gRPC publication faults. The
same revision's first clean growth attempt passed Arrow, pages and authority growth,
then exceeded the unchanged 180-second query-delivery limit in `growing-service`.
Station writes had passed in 217.453 s against 240 s. Successful delivery/turn
receipts continued until the query timeout; no correctness assertion failed, but
the cause remains unattributed. Other test workloads were active on the shared
host. This attempt does not establish the complete ordinary gate. A new clean
attempt uses the same source, workload and limits with CPU affinity 6–11 instead
of 16–31. That clean growth repeat passed all 18 tasks in 3,548.751 s including
setup. Station writes took 71.311 s and query delivery took 150.013 s. The full
gRPC fault proof passed with closure in 0.316 s while its worker and remote RPC
remained active. The HTTP proof passed sixteen sends, eight applications and two
cancellation requests. Both real connector examples passed. These two complete
lanes account for 34 tasks at the same implementation revision; experience,
launchers and core remain outside this draft checkpoint. The earlier growth
timeout remains an incomplete attempt with an unattributed cause.

During the bindings run, an external process removed the qualification worktree
and branch. The independent clean checkout and running tests survived. The
worktree and source checkout were restored at the identical commit, and open log
descriptors preserved the complete bindings log through completion. No test was
restarted or skipped. Earlier ignored logs, build outputs and private crash files
were removed with the worktree; their committed result summaries, embedded reports
and hashes remain in the follow-up record. This event is recorded separately from
test outcomes.

The next clean experience attempt at `ee4770c9` passes five tasks, then fails
Board query qualification on HTTP 503 `Unavailable` while reading query status.
The final Station launcher task does not run. This remains an incomplete lane.
Integration with main at `dca324f3` preserves its definition/layout cutover and
catalog/mutation proof registrations; the integrated ordinary inventory has
68 tasks. Earlier results do not qualify this changed source by inheritance.

The integrated Board fixture repeats only the same unavailable status,
description, page or Atlas read. It retains the existing eight-query/twelve-Atlas
attempt limits, the 60-second receipt window and 120-second result window;
individual read timeouts cannot exceed the remaining window. It never prepares
or submits a replacement mutation. A first focused run passes query operations,
then fails on an unavailable final Atlas read. After including that read in its
existing retry loop, the complete real Board proof passes. Expected denial,
expired cuts and malformed-command checks remain in that proof. Full `just check`
and generated binding checks also pass on the integrated development source.

The merged cold-store fixture passes temporary-unavailability recovery,
accepted-but-unavailable then already-owned recovery, foreign/malformed conflict
rejection, immediate denial and exhaustion of the original startup deadline.
Repeated attempts retain identical signed requests. A real owned MinIO bucket
also accepts repeated creation. These focused checks and the Board failure logs
are retained in the follow-up record; clean integrated qualification remains
separate. A fresh hosted check still does not start because GitHub reports the
account payments/spending-limit restriction.

The clean experience lane at `95ed6c72` again passes five tasks, then fails
when a retained stale Atlas position returns temporary HTTP 503 instead of the
required 409. The Station launcher and subsequent lanes remain unrun. A 503
does not establish stale-cut rejection. The observation helper now gives each
read one bounded retry loop, including reads with expected rejection statuses:
eight attempts for query/inspection reads and twelve for Atlas. It retains the
same URL, saved position, operation and request bytes; expected statuses and
`no-store` assertions remain mandatory. The existing receipt/result deadlines
still bound their reads, and mutations are never retried by this helper.

Eleven controlled response schedules pass, including unavailable-then-expired,
unavailable-then-denied, refusal to accept a successful stale-cut read, both retry
bounds, unchanged query identity, deadline exhaustion, receipt observation and
no mutation retry. The final helper also passes the complete real Board proof
in a separate checkout based on `95ed6c72`. The simulation checkout remains at
that unchanged commit while this fixture correction is validated; reports retain
their actual source identities. The follow-up record embeds the failed clean
attempt and controlled-check driver. Complete clean qualification of the final
fixture is still required.

At clean simulation source `95ed6c72`, the expanded campaigns repeat successfully:
38 authority traces / 5,293 events (121.605 s), 3,202 exhaustive resource traces /
60,704 events (1,835.258 s), and 36 shared-client traces / 6,490 events (164.360 s).
The component campaign now includes catalog and passes 160 schedules across five
owners in 55.894 s. Each report retains identical replay, source and tool/binary
identity. These are 72,487 events across 3,276 traces plus the separate component
schedules; they preserve the existing atomic-journal and host-scheduling limits.

Clean experience at `5fe3df66` passes all six Board/frontend tasks, including the
corrected Board query proof, then fails the Station launcher's unchanged
60-second Arrow-reply wait. The retained manager log shows the courier exiting
after repeated failed readiness probes; its inherited `restart: no` policy leaves
it stopped. This matches the manager's documented
[probe lifecycle](https://f1bonacc1.github.io/process-compose/health/).
Current public reads show consumed requester input with no recorded Arrow result.
Restarting the same courier completes that retained reply (16.689 s of subsequent
polling). No query is reissued and no authority or deadline is changed. The
original clean attempt remains failed; subsequent lanes did not run.

The native counter and Station topologies now restart the stateless courier
after failure with a one-second backoff. An owned proxy in the Station proof
refuses only signed delivery reads, preserving command bytes and all authority
checks. The proof observes a new courier PID and increased manager restart count
before releasing the fault, then requires the Arrow result within the original
60-second window. It passes with 292 refused reads and one replacement after
30.261 s, followed by the existing same-PID worker recovery, upgrades, Board and
persistent stop/start assertions. The proxy restores the original configuration
and joins its threads. The full ordinary gate still requires all five lanes at
the final committed source.

The counter launcher proof also passes with the new policy, including an explicit
courier stop that preserves its queued outbox until explicit restart, authority
restart, same-PID replacement and foreground cleanup. Full `just check` passes.
A negative control disables only the Station courier restart policy: the real
injected-outage proof fails at `Courier did not recover after failed readiness
probes`. The driver restores the topology and stops its owned failed installation.
This is detection of the removed lifecycle guard, not an unrelated build or
timeout failure. Final catalog and documentation checks pass separately.

Clean experience at `8b1be77e` passes all seven tasks in 516.624 seconds including
setup. Its Station launcher observes 292 refused delivery reads, one automatic
courier replacement after 30.284 seconds and the Arrow reply within the original
60-second window. The remaining ordinary lanes are separate until their full
completion records are available.

Hosted [run 36796408660](https://github.com/rupurt/rey/actions/runs/36796408660)
executes jobs; the earlier account restriction no longer prevents this run.
Experience fails its first task because its reduced Nix Python environment lacks
`jsonschema`. Bindings fails while restoring the Nix store with `No space left
on device`, before any test executes. These are failed qualifications. The CI
shells now include the validator from the existing lock, and disposable hosted
runners reclaim unused SDK space before cache extraction, including exact hits.
Self-hosted runners retain their software. Both corrected Python environments,
the full Board check in the reduced experience shell, `just doctor` and full
`just check` pass locally; hosted correction evidence remains separate.

Cost accounting also distinguishes the intentionally skipped documentation-only
job from the full matrix that already owns the documentation proof. Its regression
requires all five lane names before excluding that alternative job and rejects a
missing or skipped required lane. This correction does not convert failed jobs
or unknown cache transfers into budget qualification.

Clean core at `8b1be77e` then passes all 22 tasks in 1,160.532 seconds including
setup. Together with experience, this is 29 tasks at one revision. Growth passes
Arrow, pages and authority growth, then the Station caller exits with
`AuthorityTimeout`. This is not its outer 240-second timeout: the node records a
6.72-second successful turn followed by a failed page stage and request timeout.
The underlying provider delay remains unattributed. That attempt has 32 passing
tasks, one failed task and 35 unrun tasks; bindings and launchers do not execute.

The separate clean experience attempt at CI-setup commit `151772ac` passes six
tasks, then misses the Station Arrow reply's original 60-second window after the
injected courier outage. The manager replaces the courier, but node logs record
storage read/write failures, request timeouts and capacity refusals after release.
The original reply is later present without resubmission or manual replacement.
This later observation does not pass the deadline. Logs, process status and the
stopped installation remain retained; the cause of storage unavailability is not
established by these observations.

Hosted run `36796408660` executes synthetic merge `7ee3c04b`, combining PR head
`8b1be77e` with main `5c98499e`. Its core lane passes all 22 tasks in 1,196.95
seconds excluding setup. Growth passes seven tasks, then Docker exits 125 before
the combined Table fixture starts. A separate registry lookup confirms that its
pinned historical MinIO digest has no manifest. The run takes 1,762 seconds from
creation to completion and 4,366 aggregate runner seconds. The bindings log is
unavailable after its runner disk failure, so total restored bytes are unknown;
this failed run does not qualify a cost budget. Cost collection now preserves
available job measurements when another job's log is missing and distinguishes
fallback cache restores from a complete warm sample.

Hosted launchers fails its initial consumed/admitted assertion without recording
the row. Independent controlled scheduling reproduces a race in the original
observer: it samples process progress before the counter value, then returns the
old row when the turn commits between reads. The corrected helper samples the
value first and progress afterward, retaining the 30-second polling limit. Four
controlled cases pass, including stalled and metadata-only observations, and the
full native counter launcher proof passes from a short checkout based on
`151772ac`. The hosted row's original operands remain unavailable. An earlier
focused attempt in the long worktree path fails the explicit Unix-socket path
bound before launching the manager; that attempt is not lifecycle evidence.

At committed `151772ac`, all nine component mutations are detected by executed
assertions: Document conflicts/checkpoint floors, Exchange holds, refresh
generation, provider readiness and four catalog policy/receipt/inspection/cursor
guards. Compilation failures and timeouts do not count as detections.

Cold-store fixtures now start the same native MinIO output already used by the
local bundle. The former bundle definition and extracted shared Nix definition
resolve to the identical store path and binary hash; source/vendor pins and
`flake.lock` are unchanged. Actual startup, repeated owned-bucket creation and
the six controlled readiness/rejection cases pass. The first combined Table
proof with native cold storage proceeds past startup, then fails on
`StaleStateResource` in its progress observation. Main's focused correction
`88d7ab7d` supplies a progress-only query and prepares the mutation before holding
the snapshot read; these fixture changes are brought over without changing the
runtime or broadening the declared snapshot deadline.

The corrected combined Table proof passes in 45.231 seconds with two recovered
initialization receipts, 70 turns and a 0.547-second held snapshot. The native
cold-page proof passes write, recovery, checkpoint and trim recovery with 1,024
keys, 1 MiB of retained values, two resident pages and 20 persisted cold chunks.
The physical capacity proof reaches real ENOSPC after query acceptance and passes
finite control/shutdown and exact recovery in 18.62 seconds. Native-provider
lifecycle checks join the real child and remove its owned data, including failed
startup. Full `just check` and `just doctor` pass on the corrected development
source based on `151772ac`; the experiment record binds the changed source hashes.
Initial stale image imports and ambient-tool assumptions in CLI diagnostics are
retained as failed attempts and corrected before these passes. These focused
results do not replace committed-source clean or hosted qualification.

Discovery retains the exact thirteen commands and exploration arguments formerly
appended to ordinary bindings. The fault workflow now selects that campaign weekly
or on demand, with separate 3,600-second stage and 180-minute job limits. A real
runner-entry regression completes stage one, fails stage two deliberately and
requires incomplete evidence with no later execution. The larger ordinary job
caps permit measuring expanded inventories; they do not change task-local
deadlines or qualify the historical feedback budgets.

Clean experience at `1f76bf3b` passes all seven tasks in 523.220 seconds including
setup, with 292 courier read refusals, replacement after 30.276 seconds and the
Arrow reply within the original deadline. Core passes twelve tasks before its
package build is deliberately interrupted to integrate main at `2704c153` after
new PR conflicts. Its completion record remains false; growth, bindings and
launchers are unrun at that checkpoint. The stopped checkout retains evidence
and has no remaining owned processes. Hosted discovery run
[36801433218](https://github.com/rupurt/rey/actions/runs/36801433218) uses the
unchanged `1f76bf3b` source and is incomplete at this recording.

Integration preserves main's SQL console write/recovery cases and the controlled
missing-MinIO diagnostic environment. Full `just check` passes on the merged
development source. Clean qualification of the merged commit remains separate
from the superseded run.

The first merged combined Table attempt fails its 45-second console wait while
MinIO rejects cold writes with HTTP 507 `XMinioStorageFull`. The pinned provider
reserves 1% of its filesystem's total capacity; the shared 1.97 TB filesystem has
fallen below that reserve. Removing rebuildable outputs and dependencies from
stopped, owned qualification checkouts restores space while retaining source,
logs, proof records and database state. The same proof then passes in 65.916
seconds: 105 turns, two recovered initialization receipts, a 0.504-second held
snapshot and all added SQL-write interruption/recovery/cancellation cases. No
assertion, request deadline or provider capacity guard changes between attempts.

## Expanded fault-verification qualification — 2026-09-30

The [local experiment record](verification/results/m37-local-2026-09-30.json)
binds the source revisions, dirty development runs, compiler/binary/runner hashes,
counts, fault coverage, negative controls and elapsed times. The last implementation
revision is `b0462904`; subsequent ledger changes contain documentation/evidence.
Passing profiles below retain their actual source identity. They do not combine
into a complete ordinary-suite pass.

| Executed profile             | Result and scope                                                                                                                                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Repository checks            | `just check` passed at committed `fb912908`, including units/contracts, ownership inventory, frontend checks and the public Docusaurus build                                                    |
| Expanded resource simulation | At committed `5b267061`, 204 traces / 3,958 events replayed identically in 111.250 s; staging/read/publication/trim faults and independent atomicity/view checks                                |
| Clean ordinary simulations   | At `e92087ff`, 14 authority traces / 749 events, six resource traces / 112 events, eight Session/courier traces / 542 events and eight component package schedules passed with identical replay |
| Compiling mutations          | At committed `5b267061`, all nine new resource, scheduler and component mutants were detected by executed contract checks; build failures/timeouts did not count                                |
| External supervisor          | At `f7d0361f`, seed 19 / twelve rounds passed in a fresh checkout in 19.588 s; the later clean core run also passed four rounds, with requested faults observed and cleanup joined              |
| Installed SDKs               | Python/Node package builds and independent installed consumers passed in 30.343 s total; signed histories, cancellation/disposal and exactly two admissions retained                            |
| Application/provider fixture | Lost provisioning, rotation, migration and activation replies plus runtime upgrade passed in 28.531 s total                                                                                     |
| Query lifetimes              | Durable lifecycle, durable expiry and interactive Table cancellation/current denial passed in 385.887 s total                                                                                   |
| Browser/reactive lifecycle   | The real TLS/browser owner passed refresh replacement, pause, revocation, stream loss/resume, pagehide/expiry and reset/resnapshot in 169.381 s total                                           |

`just ci-clean --lane core` passed all 22 tasks at `e92087ff` in 1,186.95 s.
`just ci-clean --lane experience` passed all seven tasks at `b0462904` in
443.77 s, including the real local Station launcher and clean Node dependency
build. The clean launchers lane passed both tasks at `4df41ba5` (57.56 s for
artifact builds and 283.36 s for local lifecycle, replacement and cleanup).
These are distinct committed revisions; only this final evidence update follows
the last launcher qualification.

Repository-wide qualification remains incomplete:

- At `5b267061`, 27 tasks passed before the publication expiry assertion failed;
  37 tasks were unrun. The clock-bound fixture correction subsequently passed
  the complete publication proof in the `fb912908` clean run.
- At `fb912908`, 37 tasks passed before HTTP cancellation follow-up admission
  failed; 27 tasks were unrun. The corrected fixture chooses its finite
  reconciliation window before initial acceptance and checks that every follow-up
  preserves it; production deadlines are unchanged. The corrected complete HTTP
  proof passed at `b0462904` in 492.21 s excluding compilation: sixteen remote
  sends, eight applications, two cancellations and 1,153 cold objects.
- The parallel `e92087ff` growth lane passed three tasks, then exceeded the
  existing 180-second query delivery deadline. No deadline was relaxed.
- The `e92087ff` bindings lane passed native bindings and the full installed
  Python/Node SDK tasks, then its Rust Station consumer terminated with SIGSEGV
  in `decode-block`. Eleven later tasks were unrun. A focused full Rust
  Station/HTTP rerun and 32 additional fresh malformed-input blocking cases
  passed with the same implementation; the original crash remains unexplained.

The earlier clean Node check failed because it checked Station before emitting
its client's package exports. The corrected dependency ordering passed the
complete clean experience lane above. None of these corrections relabels a
failed or incomplete run as successful.

The installed/service/browser runs are separate selected local profiles, with their
original revision/dirty flags retained in the record. They do not certify other
hosts or Kubernetes placement. Vortex checks quiescent public correspondence,
not arbitrary concurrent-read linearizability; process SIGKILL is not power loss.
Simulation assumes atomic journal append and does not qualify physical page GC.
Component schedules replay seeds with pinned binaries; only the JSON-trace profiles
provide edited-trace replay and bounded minimization.

Hosted run [36678421267](https://github.com/rupurt/rey/actions/runs/36678421267)
produced no test execution: GitHub refused job startup because of account
payments/spending limits. The local observations do not requalify hosted feedback,
aggregate runner time or cache budgets. Hosted ordinary/discovery runs and cost
measurement remain tracked by [issue #26](https://github.com/rupurt/rey/issues/26).

## Publication clock-bound correction

The committed clean run at `5b267061` passed 27 ordinary tasks, then stopped at
`test::publication`: a fixed 3.1-second sleep observed `DeadlineUncertain` instead
of definite expiry. That run is incomplete; its remaining 37 tasks did not run.
The fixture now passes its configured maximum clock error to the public caller.
The caller opens a view beyond that bound and waits until the deadline plus the
same bound before requiring the exact `StateViewExpired` rejection. Unavailable
or uncertain authority is still a failure, not accepted expiry evidence.

## External fault supervisor and installed hosts

The [external harness](verification/README.md#external-fault-testing) runs real
node/counter/courier binaries and disk Ursula, retaining requested/observed faults,
public request/reply histories, independent quiescent state checks and joined
cleanup. At dirty source based on `a59e0d9c`, four rounds passed in 7.219 seconds.
The expanded seed-19 run passed twelve rounds in 18.711 seconds, including output
pagination beyond the native eight-entry page. Both runs recorded cleanup success.
An earlier expanded run exposed a fixture omission of the fixed pagination position;
its incomplete report remains retained and is not passing evidence.

At dirty source based on `157469a4`, the installed SDK profile passed Python and
Node independent consumers. Build stages took 20.952 and 2.018 seconds; the Python
and Node fault schedules took 3.120 and 4.023 seconds. They checked byte-identical
uncertainty, seedless host recovery, cancellation/join/disposal and current denial,
with exactly two accepted inputs. Per-host histories and exact wheel/tarball/native
hashes are retained. This covers those installed Linux hosts, not all SDKs.

The local application fault scenario initially stopped on a transient
`AuthorityUnavailable` during an ordinary public operation. Its driver now uses
the same bounded, byte-preserving recovery-file retry as the owning application
proof; intentionally faulted calls still return immediately for explicit checks.
The rerun passed dropped spawn, worker rotation, migration send/turn and activation
send replies in 21.551 seconds, including current revocation and management bounds.
The separate provider-upgrade stage also passed; the consolidated record below
binds both stages to their executed source revision.

`just check` and the selected application, query and browser/reactive profiles
passed during development. Complete committed-HEAD clean qualification and hosted
cost remain separate gates in the consolidated record. SIGKILL is not host power loss; local durations
do not establish hosted feedback budgets or a runtime performance target.

## Stored-definition recovery correction

The former `LegacyAcceptedGrowthHistory` assertion instantiated the current
`adapter.Store` under a legacy variable name and incorrectly required it to reject
current history. The replacement writes separate foreign-definition and
missing-definition records to disposable disk journals, then requires exact
decoding errors before recovery can write pages or append authority. The checks
repeat after provider restart and checkpoint/trim of the valid journal.
At dirty source based on `a59e0d9c`, `just test::growing` passed write, recovery,
checkpoint and trimmed recovery (54.098, 3.859, 6.668 and 3.776 seconds). This fixes
that focused proof; a complete clean CI run remains separately required.

## Component simulation

At dirty source based on `d3562a07`, `just test::domain-simulation --seeds 8`
passed 32 package schedules, each replayed identically, in 9.586 seconds with
pinned Zig `0.17.0-dev.2267+48abf1a34`. Five domains cover concurrent Document
assignments and dependencies, checkpoint discard/final floors, Exchange closure
and replay holds, query refresh ownership/source cuts, and provider activation.
These are real component operations over private-turn stores. They do not qualify
physical storage, application installation, transport or remote dispatch. See the
[harness guide](verification/README.md#component-simulation) for exact bounds,
artifacts, seed replay and separate mutation qualification.

At committed `a59e0d9c`, all five real-code mutations were detected by executed
contract assertions (1.245–1.508 seconds each). Trace logging is enabled only by
the component runner; ordinary package tests execute the same assertions quietly.
The two-seed replay after that logging change passed in 2.377 seconds.

## Shared-client scheduling simulation

The shared Session/courier driver runs production preparation, frozen retry,
activation checks and courier selection against controlled signed transport.
Its [guide](verification/README.md#shared-client-scheduling-simulation) defines
faults, invariants and limits. At dirty source based on `b6626cae`, the ordinary
run passed four saved and four generated schedules: eight traces / 542 events,
each replayed identically, in 15.876 seconds. The finite case exercised recorded
permits through settlement, expiry maintenance, trim/recovery, clock rollback and
untrusted time. The standalone client package tests and `just test::callers`
also passed, including real counter/byte-log programs, automatic courier delivery,
exact retries, stale activation and disk recovery. The proxy printed a broken-pipe
diagnostic during its interruption scenario; the complete caller task exited zero.
These are shared-host development observations, not hosted cost or OS scheduling
qualification. Compiler/binary/oracle identities are retained in the artifacts.

The shared-client ABI proof passed at `982b85b0`. At `d3562a07`, both compiling
shared-client mutants were detected: discarded courier uncertainty (2.646 seconds)
and omitted Session activation validation (1.739 seconds). The earlier checker
missed uncertainty created and lost within the first courier step; the corrected
oracle explicitly requires that submission's digest to remain pending. Its full
eight-trace / 542-event run passed in 16.730 seconds before mutation qualification.

## Resource publication simulation

The resource profile adds numbered page staging/read faults, a two-page cache,
resource/input/output correspondence, captured view roots and checkpoint/trim
recovery. The [harness guide](verification/README.md#resource-publication-simulation)
owns commands and model limits. On the shared Linux host with pinned Zig
`0.17.0-dev.2267+48abf1a34`, the first development sweep based on `38ac8781`
passed 99 traces / 1,923 events, each replayed identically, in 53.290 seconds.
After adding the saved corpus, `just test::resource-simulation-smoke` passed
six traces / 112 events in 3.409 seconds. Both were dirty development runs;
metadata records binary/oracle identity. At committed `b6626cae`, both actual
core mutants were detected: omitted resource writes in 2.128 seconds and omitted
input progress in 2.079 seconds, including bounded minimization. These in-memory observations do not
establish actual WAL durability, physical page reclamation, full CI completion
or hosted cost. Compiling core mutation qualification is a separate command.

## Authority and delivery simulation

The multi-process simulator executes real signed authority/outbox transitions for
two producer PIDs and one destination, with eight delayed-decision slots and an
atomic in-memory journal. Its independent oracle checks every operation outcome,
ownership/sequence/lifecycle projection, output and destination-input provenance.
Cold recovery must match the live engine without writing pages; the live engine
and cache persist until an explicit restart. The
[harness guide](verification/README.md#authority-and-delivery-simulation) owns
commands, fault assumptions, bounded progress and artifact formats.

The initial development run of `just test::simulation` passed six saved cases and
eight generated 48-step schedules: 14 traces, 749 events, each replayed identically,
in 18.287 seconds on the shared Linux development host. The healthy suffixes add
events beyond the requested random steps. These are test execution timings, not
throughput or deployed latency measurements. The run used the pinned Zig
`0.17.0-dev.2267+48abf1a34`; evidence records the binary hash and dirty source status.

Initial driver bring-up exposed an optional-slot assignment that became populated
before failed preparation completed. The minimized two-event schedule is retained
in `failed-preparation.json`; preparation now finishes before assigning the slot.
This was a harness defect, not a discovered Transit protocol defect.

At committed source `76ad31e3`, `just test::simulation-mutations` passed its
unmodified baseline and detected both compiling real-core mutants. Omitting the
route-order guard minimized to seven events; corrupting delivered output provenance
minimized to five. Mutation executions took 9.626 and 6.235 seconds respectively,
including minimization. Artifacts are in `.cache/verification/simulation-mutations/`.

The expanded development run, `just test::simulation --seeds 64 --steps 128`,
passed 70 traces and 10,535 events with identical replay in 246.809 seconds.
It ran alongside repository checks on the shared host; its metadata identifies
dirty source based on `6f629aaa`, the unchanged driver later committed in
`76ad31e3`, and the oracle hash. `just check` passed formatting, package/unit and
contract checks, verification ownership, frontend checks and the Docusaurus
production build. These runs do not establish clean-checkout qualification or
new hosted CI costs.

After adding runner negative controls, the ordinary simulation passed the same
14 traces / 749 events in 18.884 seconds and rejected both deliberately undrained
work and incomplete output. The unchanged authority/resource property suite also
passed its 40 traces / 1,687 steps in 14.345 seconds. These development runs were
based on `76ad31e3` with the recorded runner/documentation changes.

The profile does not execute application handlers, resource mutations, an
automatic worker/courier scheduler, clocks, HTTP or real disk. Its progress check
restores permissions and explicitly schedules finite eligible work with available
storage. It does not prove scheduler fairness or general liveness. The complete
external real-binary program remains tracked by
[issue #26](https://github.com/rupurt/rey/issues/26).

## Native v1 cutover checkpoint — 2026-09-30

This checkpoint replaces the bounded native authority with the paged v1
implementation and moves native clients, Station, controllers, Board, Flight,
installation and language boundaries onto it. It is an implementation checkpoint;
full cutover qualification remains in progress under
[protocol consolidation](../docs/roadmap/M31.md). Earlier milestone records below
are historical executions and do not qualify the replacement automatically.

Executed against the cutover workspace with the pinned Linux x86_64 Nix/Zig
toolchain:

| Check                                                                            | Observed result                                                                                                                                                                                       |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just check`                                                                     | Passed pinned tooling checks, generated contracts, native units/fixtures, CLI diagnostics, documentation links, frontend lint/types/unit tests and the production documentation build                 |
| Native unit/independent fixture suite                                            | Passed, including current-definition rejection and owner-lifetime read/required-dependency gates                                                                                                      |
| `zig build test-storage`                                                         | Passed all four disk/restart phases of the nine storage, kernel, effects, lifetime, outbox, runtime, deletion, state and readiness executables                                                        |
| `zig build test-service`                                                         | Passed actual signed HTTP counter/state recovery, bootstrap/fencing, background expiry/checkpointing, blocked storage deadlines, real effect uncertainty and payload deletion                         |
| `zig build test-station`                                                         | Passed two-resource application recovery, registry routing, timed waits, supervision, paged child discovery and lifetime cleanup                                                                      |
| Native state HTTP proof                                                          | Passed resource grants, captured views, paging/cuts, exact retry, counter worker and disk recovery                                                                                                    |
| `zig build test-flight -Dflight-faults=true` in the Flight shell                 | Passed independent Arrow clients, bounded concurrent/control behavior, ticket/current-rights checks and worker/gateway/node/store recovery                                                            |
| `just bindings::native` and `just bindings::node-sdk-test` in the bindings shell | Passed native/port ownership and installed Node client/Station/query/HTTP/gRPC scenarios                                                                                                              |
| `zig build test-public-query`                                                    | Passed actual shell/hosts, 41 exact int64/null rows, frozen retry, fencing/recovery, busy admission, schema rejection, cancellation and terminal resource refusal                                     |
| `just bindings::python-test` in the bindings shell                               | Passed clean installed client/Station packages, durable continuation, query pages, HTTP and gRPC scenarios                                                                                            |
| `zig build test-transit-board`                                                   | Passed embedded assets, current inspection/resource grants, framework views, history gaps, outage handling and bounded-load control progress                                                          |
| `zig build test-board-query`                                                     | Passed separate query identity, current typed result schema, exact retry, malformed admission, incomplete-result refusal, cancellation and current grants/cuts                                        |
| `zig build test-observability`                                                   | Passed correlated spans, exact receipt retries, revoked reads, secret exclusion and progress with a blocked diagnostic pipe                                                                           |
| `zig build test-inspection`                                                      | Passed bounded scoped discovery, signed query rejection, old-route refusal, changed cuts, revocation and disk recovery                                                                                |
| `zig build test-server -Dserver-faults=true`                                     | Passed local lifecycle, exact bootstrap recovery, definition mismatch without record mutation, private gateway/Host checks, process/storage recovery, executable drift and authority rollback refusal |
| `just examples::run counter`                                                     | Passed the actual counter binary over independently granted resource state                                                                                                                            |

Limits at this checkpoint: the remaining installed-language matrix stopped at
Rust formatting;
formatting is corrected, but that matrix has not been rerun. Recent owner-lifetime
changes need the relevant final integration reruns. Public query recovery exposed
an unclassified terminal resource rejection; the reader now maps it to
`ResourceUnavailable`, and the full public-query scenario passed after the fix.
The broader unified shell recovery schedule exposed a stale current observation
while restoring a saved bundle; preparation now restarts only conflicted reads,
and this schedule needs rerunning. Local-server fixtures now include the required
matched Board artifact even for headless execution, expect the current application
profile and keep test configuration out of the server environment namespace;
the full lifecycle and extended failure schedules passed. Browser/placement, remaining
source/lifecycle/installation proofs, all-language interoperation, final
documentation/legacy inventory and committed-HEAD `just ci-clean` are not yet
claimed passed. No deployment or history conversion is authorized by this
checkpoint.

## Native v1 consolidation follow-up — 2026-09-30

The current workspace removes the earlier Table compiler, plan, progress codec
and executor. Station capture uses the same `FZP1` plans, `FZS1` progress,
source definitions and nested Arrow cells as KV/Table/Document queries. The
shared native/ABI definition changes with the stored Station records; generated
contracts, installed SDK manifests and independent signing fixtures match it.
Superseded Fuze contracts remain accessible through revision-pinned historical
links, rather than as current specifications.

The following executions use the pinned Linux x86_64 toolchain. Rows describe
finite schedules, not a complete cutover qualification or performance guarantee.

| Check                                                 | Observed result                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `just check`                                          | Passed native units and independent fixtures, generated contracts, verification inventory, 174 CLI diagnostic cases, documentation links, frontend checks and production documentation build                                                                                                                                                                                                                                                     |
| `zig build test-query -Doptimize=ReleaseSafe`         | Passed staging, sealing, publication and partial-consumption recovery over real disk Ursula: 41 rows, six current nested IPC segments, 21,296 bytes, exact retries and receiver credit                                                                                                                                                                                                                                                           |
| `zig build test-arrow`                                | Independent PyArrow validated current scalar/state encoding, 13 malformed schema/state cases, all eight page widths, exact aggregates and 167-byte checkpoints; a 70-row text result occupied 38,296 bytes over 11 segments                                                                                                                                                                                                                      |
| SQL grammar/compiler proofs                           | Three parsers agreed on 103 SELECT cases; 86 current plans matched the independent encoding/result oracle. Unified results covered three source bases and all eight page widths                                                                                                                                                                                                                                                                  |
| Unified Table shell/Board/browser/lifecycle           | Passed frozen upload/restart, same signed retries, current grants, explicit cancellation, released-version refusal, finite draft budgets, complete coverage and retirement: 41 rows, six segments, 251.59 seconds                                                                                                                                                                                                                                |
| Interactive Table/KV/Document queries                 | Passed fresh cuts, bounded frames, zero durable updates, cancellation and current denial: 3.60 / 3.07 / 314.63 seconds                                                                                                                                                                                                                                                                                                                           |
| Serving lifecycle                                     | Passed two-gateway exact retry, ordered cancel/timeout, late replies after restart, process/wait/resource limits and current revocation: 23.59 seconds                                                                                                                                                                                                                                                                                           |
| Reactive browser view lifecycle                       | Passed shared-principal tabs, transport reconnection without replacing logical sessions, pagehide/expiry, explicit watch-generation reset/resnapshot and retirement: 61.61 seconds                                                                                                                                                                                                                                                               |
| Local installation and replacement faults             | Passed exact recovery after five lost replies: spawn, worker rotation, copy admission, worker copy and activation admission; fault schedule 22.252 seconds                                                                                                                                                                                                                                                                                       |
| Native client ABI and `just bindings::native`         | Passed canonical signatures, foreign/missing-definition rejection, saved-operation recovery, disk/host restart, revoked retry, scoped Station callbacks and independent decoding of six current query segments                                                                                                                                                                                                                                   |
| `just bindings::python-test`                          | Passed clean installed client/Station/example artifacts, scope/lifetime ownership, retained query segments and HTTP/gRPC capture/replay/disposal; HTTP 65.05 seconds, gRPC 68.94 seconds                                                                                                                                                                                                                                                         |
| Installed Node and Rust SDKs                          | Passed raw clients, Station callbacks/recovery, current nested Arrow ownership and HTTP/gRPC capture, disposal and follow-up rejection. Node HTTP/gRPC: 76.28 / 76.20 seconds; Rust: 106.17 / 107.77 seconds                                                                                                                                                                                                                                     |
| Installed Ruby, C/C++, Java, .NET and BEAM SDKs       | Passed raw clients, Station scope/fencing/recovery, independent decoding and retained ownership of six current nested IPC segments, and HTTP/gRPC capture/replay/disposal. HTTP/gRPC seconds: Ruby 69.62 / 69.36; C 73.06 / 76.84; C++ 79.49 / 85.10; Java 83.89 / 83.29; .NET 72.01 / 73.90; Erlang 32.27 / 30.48; Elixir 35.72 / 32.15                                                                                                         |
| Unified KV and Document shell/Board/browser           | Passed frozen retries, disk/worker recovery, scoped denial, complete nested results and retirement. KV: 41 rows, six segments, 170.91 seconds; Document: 12 rows, two segments, 509.39 seconds                                                                                                                                                                                                                                                   |
| Transition properties, codecs and bounded models      | Passed 40 saved/generated authority traces (1,687 steps), codec corpus/allocation failures, the authority model with negative controls, and the delivery safety model                                                                                                                                                                                                                                                                            |
| Runtime upgrade and reference workload                | Passed stale controller/Actor rejection and lost-response recovery; the real Kubernetes/Substrate workload passed controller crashes, same-PID worker replacement, node/store restart, expiry, isolation and shutdown                                                                                                                                                                                                                            |
| Local and Compose counter launchers                   | Passed persistent restart, exact retry, artifact replacement, incompatible-definition refusal, courier recovery, Board evidence and foreground signal cleanup                                                                                                                                                                                                                                                                                    |
| `just test::growing-capacity`                         | Real owned ext4 ENOSPC, physical control-reserve release and disk restart passed with 40 retained rows and one 8,544-byte resident page. Recovery created zero pages and issued only GET/HEAD requests                                                                                                                                                                                                                                           |
| Unified KV and Document lifecycle/expiry              | Current-definition lifecycle schedules passed caller/source denial, cancellation, released-version refusal and bounded cleanup (76.70 / 364.63 seconds). Real-clock expiry denied prefix/complete reads, released pins and survived node/store restart (194.16 / 503.58 seconds)                                                                                                                                                                 |
| Current reactive limits/client/refresh/view lifecycle | Passed finite sessions/streams, reserved renewal and health, signed cursors, malformed frames, reconnects, observer absence, expiry and retirement. Two gateways used 51,281,920 bytes RSS under the 256 MiB ceiling; health took 0.005 seconds. Shared client, durable refresh and browser lifecycle passed in 4.44 / 71.16 / 54.47 seconds                                                                                                     |
| Current Flight faults                                 | Passed independent Arrow consumers, concurrent/control reads, one-byte HTTP/2 credit stalls, malformed framing, current ticket rights, worker/gateway/node/store restart and retirement. Sampled gateway RSS was 72,007,680 bytes                                                                                                                                                                                                                |
| Local and Compose Station launchers                   | Passed registry routing, calls, current Arrow exchange, three-worker recovery/upgrades, Board provenance and persistent stop/start                                                                                                                                                                                                                                                                                                               |
| Committed-source mutation controls                    | All four disabled guards—generation, resource revision, permission and view deadline—produced minimized engine counterexamples at `3ea81aaa`. Compilation failures were not counted as detections                                                                                                                                                                                                                                                |
| Current Station                                       | Passed calls, two-resource turns, exact recovery, captured authorized nested Arrow, fencing and blocked-handler control; registry, supervision, late timeout closure and real-clock lifetime/reclamation survived disk restart                                                                                                                                                                                                                   |
| Current public-query startup and Work Items           | Injected first-read 503 responses for both query hosts recovered before readiness; full public-query retry, recovery and denial passed. Native Work Items passed 19 rows, two fresh-key fenced replacements, disk restart and exact operator/worker retries in 15.36 seconds                                                                                                                                                                     |
| Current Work Items browser                            | Passed complete pages, publication/schema changes, gateway replacement, saved upload recovery/cancellation, fresh query generation, current denial and responsive keyboard/axe checks in 93.48 seconds. Largest sampled gateway RSS was 28,954,624 bytes                                                                                                                                                                                         |
| Reference Station and counter launchers               | Passed registry/calls/current Arrow, real pod loss with same-PID fresh activation, worker upgrades, Board provenance, authority restart and persistent stop/start. Counter also passed queued work through image replacement, logical suspension/provider stop and courier recovery                                                                                                                                                              |
| Immutable page proof                                  | Current v1 roots/checkpoints, page writes, read-only recovery and trimming passed with 64 keys, 17,088 cache bytes and zero recovery writes                                                                                                                                                                                                                                                                                                      |
| Current SDK unified matrix                            | All ten installed targets passed KV, Table and Document codecs and complete source schedules: frozen upload retry, worker/node/store recovery, current prefix denial and retired-source refusal. KV: 41 rows / six segments / 13,584 bytes / 231.00 seconds; Table: 41 / six / 13,584 / 248.59 seconds; Document: 12 / two / 9,880 / 1,742.66 seconds. These runs used disk-backed temporary storage and eight/eight/64 resident authority pages |
| Current core service/caller follow-up                 | Passed signed service recovery, background expiry/checkpointing, effect uncertainty without replay dispatch, runtime upgrade fencing, runnable counter/byte-log examples, inspection and state APIs                                                                                                                                                                                                                                              |
| Physical-disk phase measurements                      | Standalone readiness write/recover/checkpoint/trim recovery passed in 348.45 / 6.88 / 5.48 / 4.97 seconds. Kernel write/recover/checkpoint/trim recovery passed in 27.47 / 79.40 / 1.87 / 3.32 seconds. The shared-store schedule exceeded its previous 120-second phase budget; each phase now has a finite 600-second test limit and prints its actual cost                                                                                    |
| Complete current disk schedule                        | All nine executables passed write, SIGKILL/recovery, checkpoint and trim recovery against one shared disk store. Readiness write took 395.33 seconds and kernel recovery took 100.96 seconds; every phase completed within the finite 600-second fixture budget                                                                                                                                                                                  |

The earlier Table, interactive, serving, reactive and installation executions
precede the later Station-format/definition change. The rows explicitly marked
current, the KV/Document schedules and installed-language executions use the new
definition; earlier results are not substituted for those reruns.
Mixed-language interoperation and final committed-HEAD clean CI remain in
progress. Earlier clean CI attempts stopped at transient Station storage errors
and storage phase time limits. Interoperation attempts stopped at recoverable
dispatch/read failures; the driver now uses explicit ready checks, saved-request
reconciliation and bounded read retries, with injected faults for each language.
Earlier all-language builds also exhausted shared temporary storage. Clean CI
now assigns its own disk-backed temporary directory after entering Nix. These
failed or interrupted runs are not passes. No skipped schedule or earlier
historical result is counted as a pass for the replacement.

## M19 qualification

The initial HTTP serving profile is qualified on Linux x86_64 with the pinned
Zig/Nix toolchain. Application service callers use explicit native signing keys;
Board keeps private shared viewer admission and its separate query identity.
The [compatibility matrix](../packages/zig/transit-serving/docs/compatibility.md)
separates consumers, placements and unsupported protocols.

| Proof                                                                        | Executed evidence and measured cost                                                                                                                                                                                                                                                                                                   |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just test::serving-http` and standalone HTTP tests                          | Real socket framing/chunking, duplicate/ambiguous headers, slow uploads, two blocked 8 MiB response writes, 413/503, reserved health, header/request deadlines and joined parent shutdown. Injected scheduling failure joins the already-started timer                                                                                |
| Board unit/service proof                                                     | Existing inspection flooding, revocation, trimming, storage outage and diagnostics pass; four stalled uploads exhaust data capacity while reserved health remains responsive (0.007s maximum control latency in that run)                                                                                                             |
| `just test::unified-ingress table`                                           | Two actual Board instances, shell, generated client and Chromium; competing principal sequences, exact retries, durable active-upload quota, current prefix denial, nested Arrow/JSON pages and worker/node/store recovery. Final run: 290.33s; 331 cold objects / 31,238,036 bytes                                                   |
| `just test::serving-capacity`                                                | Real nginx 1.30.5 TLS, two gateways, per-caller fairness, eight stalled authorized reads, excess caller 429/data 503 and health 0.003s. Lost native admission, worker commits, destination delivery and reply-delivery receipts recover exact bytes. Accepted mutation exceeds the gateway deadline, then recovers. Final run: 15.74s |
| `just test::serving-lifetimes`                                               | Explicit cancel, authenticated timeout, duplicate observation, late replies after restart, finite process/wait bounds and hard resource expiry without observer delivery. Final run: 30.05s including real-clock waits                                                                                                                |
| `just test::serving-growth`                                                  | 128 additional retained operations, old point reads and exact original results with only 8 resident authority pages. Final run with explicit native ceiling/reserve: 501.27s                                                                                                                                                          |
| `just examples::serving-compose`                                             | Two TLS gateways, immutable results, current denial, physical worker/gateway/node/disk recovery and fresh ownership. Final cached-image run: 16.73s; 17 cold objects / 880,092 bytes                                                                                                                                                  |
| `just examples::serving-reference`                                           | Operator-attributed fresh Substrate worker keys and exact generations; private gateway Secrets, real egress-denial probes, two TLS gateways and physical recovery. Final cached-image run: 89.49s; 14 cold objects / 890,245 bytes                                                                                                    |
| `just launchers::compose::test` / `just launchers::reference::test-launcher` | Board and persistent launcher regressions pass in separately owned installations: isolated updates, same-PID replacement, queued outbox/reply evidence, authority/store restart, stop/start and missing-store refusal                                                                                                                 |
| `just test::growing-quota`                                                   | Explicit quota exhaustion retains pending Station work/backlog, uses the control reserve and recovers from disk                                                                                                                                                                                                                       |

Native timings exclude compilation. Placement timings include image preparation,
deployment and the scenario, excluding final cleanup; first-use downloads/builds
can cost more (the first Compose image run took 111.40s). These are finite schedules,
not throughput/latency promises. New integration tasks remain focused or external;
expanded hosted CI costs are deferred under M10. No CI lane expansion is inferred
from these local runs. `just check` and standalone Station/serving checks pass.

The TLS peers verify trust/hostname and reject foreign Host/Origin. The actual
private nginx template bounds framing/body/write/upstream work, disables proxy
retry, buffering/spooling and access logging. Termination is on the operator host;
physical backends use an isolated bridge or authenticated Kubernetes port-forward.
The reference gateway denies storage/cold-store/public-network/Kubernetes/Substrate
egress before startup and carries no service-account token. Owned namespace UID
checks protect cleanup; the default installation is not adopted or modified.

The independent Python/OpenSSL callers pin binary layouts and scoped signatures.
The native schedule rejects forged/cross-principal reads and forwarding headers,
deduplicates operation IDs across new native sequences, and preserves the original
target after publication retirement. Malformed native frames, spoofed replies and
premature timers become ordered dispositions without poisoning the service queue.
Gateway, worker, node and store loss leave the same operation/result recoverable.
Current service-policy and native-grant revocation deny disclosure.

Capacity observations are scoped. The two delayed-read gateways use 47,792,128 bytes
RSS against a declared 256 MiB ceiling and private 2 MiB request allocators. During
two concurrent Board result reads, sampled aggregate RSS reaches 29,532,160 bytes
against the same two-instance ceiling. The 128-operation growth run measures
38,035,456 bytes across node, two workers and gateway against a 512 MiB profile
ceiling. These measurements exclude proxy/kernel memory and are not peak guarantees
for every configurable workload. The physical fixtures use an 8 MiB hot store.

All service fixtures now configure a 50,000-position native admission ceiling and
2,000-position recovery/control reserve. Service active slots and caller quotas
are separate from retained cardinality. Standalone tests exercise 128 retained
records, bounded point reads, conditional publication, target immutability,
quota refusal, poisoned reads and cancellation/reply/timeout races. No retention
opt-in or total-cardinality array is used to permit growth.

Growing native receipts and terminal service records remain retained across newer
sequences. This profile does not advertise finite receipt reclamation. Finite
process/resource expiry is separate: clock uncertainty yields temporary
unavailability until expiry is definite, and socket deadlines do not renew waits.
The observer is explicitly provisioned; no automatic timer daemon or growing
runtime reconciliation controller is qualified. M20 separately qualifies reactive transports and Table watch coverage below;
reactive SDK wrappers and inbound gRPC/Flight retain separate qualification gates.

## M18 qualification

The declared Linux x86_64 growing profile is qualified: signed KV/Table/Document
queries, all ten installed SDKs, the explicit SQL shell and separately authorized
Board workspace. Native lifecycle proofs cover all three sources; physical
Compose and Substrate recovery is qualified for Table. KV/Document physical
placement remains unmeasured. No optimizer rewrite or Flight/ADBC endpoint is
introduced. The detailed evidence below preserves each workload, configuration,
failed attempt and scope; earlier component results do not imply later service
coverage. Expanded hosted CI cost remains deferred under the agreed CI policy.

| Final recovery schedule                             | Seconds | Cold objects / bytes | Resident authority pages |
| --------------------------------------------------- | ------: | -------------------: | -----------------------: |
| KV shell, Board API/Chromium, lifecycle and example |  595.25 |     781 / 83,591,053 |                        8 |
| Table example with injected host read timeout       |  193.33 |     210 / 19,269,554 |                        8 |
| Document shell, Board API/Chromium and lifecycle    |  875.94 |  1,612 / 174,056,281 |                       64 |
| Document example and permanent source retirement    |  670.95 |  1,327 / 122,898,144 |                       64 |
| Table Compose recovery/isolation                    |  100.76 |     136 / 11,572,217 |                        8 |
| Table Substrate recovery/isolation                  |  253.55 |     120 / 11,626,265 |                        8 |

All use 8 MiB hot Ursula storage with cold offload and ReleaseSafe executables.
Native times include provisioning and exclude compilation. Placement times include
image preparation inside the runner and exclude its preceding host build; they
are recorded before successful owned-resource cleanup. Cold bytes are retained
storage, not process RSS. These finite schedules do not establish throughput or
hosted CI budgets. Document's final example spends 473.86 seconds provisioning
accepted state; the browser/lifecycle run spends 477.83 seconds there.

`just examples::query SOURCE` runs the real finite Zig SQL caller. Its 0600
recovery file preserves the original bundle and pending signed command before
dispatch. The proof loses an accepted acknowledgement, rejects changed SQL without
altering recovery material, restarts the caller, verifies identical retry and
reads bounded owned pages to complete coverage. The Table timeout extension also
holds a requester read beyond its deadline: the host logs the timeout and stays
alive. Every prepared mutation remains frozen; no timeout grants authority.

`just examples::query-compose table` and `just examples::query-reference table`
kill actual source/requester hosts during an intermediate capture and restart
node/disk storage before fresh ownership. Reference kills the source's physical
Substrate worker, validates replacement public registrations and scopes fresh
keys before granting exact generations. The source and requester run in gVisor;
the finite caller and separate courier run at the operator. Egress probes deny
storage, external and reference control-plane targets. Final coverage, original
call/source identity, released pins and permanent retirement pass. Cleanup checks
namespace identity and leaves the default installation untouched.

The first reference attempt stopped on an idle read timeout and is excluded.
The host now retries read timeouts without discarding frozen mutations or hiding
authorization/fencing failures. A Compose attempt and the first combined KV
attempt rejected a valid `ResourceUnavailable` retirement error in their test
assertions; those incomplete runs are excluded. The standalone Table example's
first fault run accidentally bypassed the proxy and is also excluded. Passing
runs above include the corrected fault paths and cleanup. The original v1 public
Table shell/host proof and real Board service regression still pass. Board's v2
transport additionally qualifies escaped pages beyond 256 KiB under a separate
1 MiB decoded-response bound; other routes retain 256 KiB. All twelve frontend
unit tests, generated boundaries and repository checks pass.

### Component and incremental evidence

`just test::sql` now also checks the v2 compiler against an independent 70-row
Python evaluator and PyArrow: **13 queries × three source-kind bases × eight
page widths**, including an empty initial page, plus **six rejected or failing
cases**. Star projection spans eight columns/six scalar types/five cell states;
Unicode, binary, negative zero, full-width unsigned values, explicit null versus
missing, ordered projection/filter/limit/count/sum and output ownership retain
their meaning. These source bases exercise the pure engine, not the durable
adapters. Three package tests additionally check owned literals, error/conflict
propagation and ordered overflow under all source kinds. The original **103 AST
cases / 91 v1 plans** still pass unchanged. No optimizer rewrite is enabled.

Fuze's first four unified-model tests and the independent Python fixture check
pass. They bind the same plan to KV/Table/Document source-kind evidence, preserve
missing/null/type-error/value/conflict distinctions and ordered assignment IDs,
reject type/schema/projection mismatches, and round-trip full-width integers,
negative zero, binary, Unicode and a 537-byte plan. Every strict prefix of the
canonical plans rejects, as do trailing bytes. This is pure model/codec evidence,
not source-adapter, durable execution or SDK qualification.

`just test::arrow` also passes the new nested IPC profile through independent
PyArrow: six primitive types, all five cell states, full-width conflict IDs,
Unicode, binary and negative zero. A six-column/five-row stream is **7072 bytes**;
the same empty schema is **6088 bytes**. Independent evaluation checks filter,
limit, count and sum over 70 input rows with every page width from one to eight,
including the exact 167-byte restart checkpoint. Component tests reject changed
source evidence, cancellation, invalid progress and cross-page checked overflow.
Arrow encoding uses a **4 MiB fixed workspace / 64 KiB output limit**; allocation
or output exhaustion fails without a result. This remains pure engine evidence;
it does not establish durable capture or current source authorization.

`Unified.Inspect` additionally passes independent PyArrow-produced streams,
including empty results, all six types and the five states. Thirteen adversarial
streams reject unknown states, wrong kinds, hidden values/alternatives, invalid
conflict cardinality/order/IDs, missing alternatives, NaN, oversized text, nested
nullability violations and a renamed schema. Owned decoded values survive
overwriting the Arrow workspace. The original Table v1 Arrow fixtures still pass.

The `transit-query` adapter component tests also pass canonical `UQS1` source
fixtures and explicit KV decoder checks. A 38-record prefix crosses multiple
pages with a typed malformed-value error; a 19-row Table retains its old cut
across a replacement. Document pages preserve missing/null/type-error/conflict,
read nested full-width values and Unicode text, expand twelve ordered list
items with stable identities, and reject text-budget exhaustion. Retained bytes
cannot bypass current read denial, a newer merge-window floor or retirement.
This in-memory evidence does not qualify durable query capture/result access.

V2 bundle fixtures independently bind all three sources, explicit work budgets
and larger plans to Publication references. Current reference reads reject
before/during/after-copy denial and retirement, including empty completion.
The source capture component schedule passes for KV (37 rows), Table (12 rows)
and accepted Document list expansion (12 rows) through actual `GrowingTurn`
retained-reader APIs backed by a test map. It checks discarded-proposal
recomputation, live-source updates after retention, original replies, complete
manifest/segment coverage, pin release, older continuations, policy denial,
explicit cancellation, budget failure and bounded cleanup after request denial.
Every private turn retains the existing four-mutation limit. `just check` passes
with these tests. This is in-memory state-machine evidence, not a signed service,
disk, worker/node recovery, public SDK or returned-prefix authorization proof.

The subsequent `UnifiedResult` component tests read actual captured manifests and
nested Arrow for all three sources, reject current source/request access denial
after a returned prefix, and verify complete ordered coverage. A KV schedule also
injects denial at the first, middle and final current-read boundary, changes the
policy after completion, and rejects a forged row cursor or original correlation.
Admission rejects a different Publication publisher before retaining a source.
`just check` passes; these use the same in-memory reader fixtures and do not
replace the signed service/deployment schedules recorded separately.

The v2 upload component fixture submits a 4 KiB predicate using at most 145-byte
command payloads, retries each part, rejects conflicting bytes/identities and
premature seal, and preserves one original call on duplicate submission. Partial
abandonment holds admission until bounded cleanup releases quota. Independent
Python fixtures cover every command and full-width namespace/status encoding.
Behavior cases qualify configured-principal ingress, malformed-command disposition,
restart-configuration refusal and original-route source closure after request
access denial. These are component checks; daemon/SDK qualification is recorded separately.

The shared native `QueryCodec` additionally passes **28 independent library/port
cases** in `tests/unified_codec.py`: the three canonical source/bundle fixtures,
schema/version/limit rejection, and PyArrow-produced empty/full nested streams
with all six primitive types and five states. Owned output preserves full-width
integers and conflict IDs, negative-zero bits, Unicode and binary. The standalone
binding unit tests and generated-schema checks pass. This is local codec evidence;
the language SDK and signed lifecycle schedules remain separate obligations.

The signed **KV and Table** daemon schedules now pass over disk Ursula with eight
resident authority pages: each returns **41 rows / six segments / 13,584 Arrow
bytes**, taking **371.42 seconds (KV)** and **416.99 seconds (Table)**, excluding
compilation. The finite KV request is 587 bytes. The actual requester,
source and courier recover a lost upload receipt using identical signed bytes;
the source is killed after committing an unpublished segment candidate. The node
and disk store then restart, stale activation reuse rejects, and freshly fenced
workers publish the complete original result. Independent PyArrow verifies every
row. Revocation after the first returned page denies continuation without moving
the cursor; restoration permits verification of complete coverage. The source pin
is released. `just check` also passes. This is local disk evidence with a
default 64 MiB hot-store fixture without cold offload, not a bounded growing-storage, SDK, Compose, Substrate or
hosted CI qualification. Document evidence follows below.

The extended KV schedule also passes through the standalone query ABI and native
port in **430.97 seconds**, with the same 41 rows/six segments/13,584 bytes. A
native caller persists the prepared command before a lost upload response; a
restarted Zig caller resumes those exact bytes. Native and port readers survive
the service restart, reject access after the actual returned prefix, and alternate
pages over one verified cursor. Standalone ABI tests additionally reject invalid
local envelopes before dispatch and preserve uncertainty on a transport failure.
This qualifies the shared boundary, not the individual language SDK conveniences.

Installed Python and Ruby unified-query APIs now pass the same signed KV schedule
with **eight resident authority pages / 8 MiB hot storage and cold offload**.
Python's sync and async consumers complete in **559.64 seconds** (88 cold objects,
8,792,739 cold bytes); Ruby completes in **488.21 seconds** (82 objects, 8,783,565
bytes), excluding build time. Each returns 41 rows/six segments/13,584 Arrow bytes,
persists exact upload retry material, survives worker/node/store restart, rejects
revocation after a returned prefix and verifies complete page coverage. Python
also checks the optional pinned PyArrow adapter. Their installed codec fixtures
cover all three source declarations, six types, five states, full-width values,
Unicode, negative zero and malformed streams. This early run covered those SDK/source combinations only; the complete installed
matrix follows below.

Installed TypeScript and Rust pass the Table schedule with the same eight-page /
8 MiB hot-store bounds and 41 rows/six segments/13,584 bytes. TypeScript completes
in **547.72 seconds** (91 cold objects / 9,160,106 bytes), Rust in **570.84 seconds**
(86 objects / 9,169,222 bytes). Both check optional pinned Arrow adapters and all
three source codec fixtures. Rust additionally rejects overlapping mutable client
borrows at compile time. All owned consumers close and join before these runs
are counted; an earlier TypeScript run with a shutdown failure is excluded.

The signed accepted-Document schedule also passes in **ReleaseSafe**, including
installed Python sync/async callers, in **581.90 seconds** (478.34 seconds for
source provisioning). Twelve accepted list entries project value, stable element
counter/replica and a missing optional field into **two segments / 9,880 Arrow
bytes**. Source/requester/node/store recovery, exact upload retry, current denial
after a returned prefix, complete independent PyArrow verification and released
source pins pass with **64 resident authority pages / 8 MiB hot storage** and
1,252 cold objects / 141,311,912 bytes. This is a measured larger working-set
profile than KV/Table. The Debug fixture exceeded its 30-minute setup deadline;
that incomplete run is excluded. An earlier three-column optimized fixture
completed capture but missed its intended 8 KiB result-size assertion and is
also excluded. No deadline or deployment quota was increased to count a pass.

Installed C11 and C++17 callers pass the same six-segment schedule: C over KV in
**498.67 seconds** (86 cold objects / 8,786,941 bytes) and C++ over Table in
**545.27 seconds** (82 objects / 9,137,941 bytes), using Debug service binaries.
Both retain their exact prepared bytes on uncertainty, reject current denial,
and decode owned pages after destroying the client. C additionally overwrites
its input IPC before reading owned decoded cells; C++ rejects client copying at
compile time. Java 21's installed immutable models and bounded futures pass
Table recovery in **117.71 seconds** with ReleaseSafe service binaries (113 cold
objects / 9,672,977 bytes). All three use eight resident authority pages / 8 MiB
hot storage, and each passes the three-source/six-type/five-state codec fixtures.
All consumers close successfully before the run is counted. No optional Java
or C++ Arrow dependency is selected; independent PyArrow checks original IPC.

The unified SDK recipes now select ReleaseSafe service binaries, retaining safety
checks while avoiding the measured Debug provisioning cost. `just test::unified-query`
defaults to ReleaseSafe when called without arguments; explicit build arguments
can select a profile. Measured Debug and ReleaseSafe results above are separate.

Installed .NET 8, Erlang and Elixir callers also pass with ReleaseSafe service
binaries: .NET KV in **101.25 seconds** (123 cold objects / 9,547,213 bytes),
Erlang Table in **112.06 seconds** (112 objects / 9,660,453 bytes), and Elixir KV
in **105.90 seconds** (127 objects / 9,606,013 bytes). Each returns 41 rows / six
segments / 13,584 Arrow bytes within eight resident authority pages / 8 MiB hot
storage. Exact signed retry, worker/node/store recovery, current denial after a
returned prefix, complete independent Arrow verification and released source
pins pass. Owned page decoding succeeds after client disposal. .NET also rejects
a cancelled wait before admission; this run does not qualify in-flight Task
cancellation. Installed BEAM and NuGet codec fixtures pass all three source
declarations, six types, five states, full-width values, Unicode, negative zero
and malformed streams. Root `just check` passes. All ten SDKs now have typed v2
APIs; these individual runs precede the complete SDK/source matrix below.

The full installed SDK/source recovery matrix subsequently passes: **all ten
SDKs on KV in 285.65 seconds, Table in 302.53 seconds and accepted Document in
661.95 seconds**, including isolated installed-consumer setup in each measurement.
KV/Table return 41 rows / six segments / 13,584 Arrow bytes with eight authority
pages; Document returns 12 rows / two segments / 9,880 bytes with 64 authority
pages (533.36 seconds of its run provisions accepted state). All use 8 MiB hot
storage. Cold evidence is 124 objects / 9,575,310 bytes (KV), 109 / 9,061,732
(Table), and 1,252 / 112,961,269 (Document). Every SDK independently reads and
verifies every segment, rejects revoked access after an actual returned prefix,
and checks all three codec declarations. One uploader performs the lost-receipt
schedule per source; it is not ten independent upload fault schedules. All
consumers join successfully before the matrix is counted. `just bindings::unified-all`
builds the installed packages and reruns this matrix in the bindings shell.
These local measurements do not qualify hosted CI cost or deployment recovery.

The actual v2 SQL shell passes on KV (**166.16 seconds**, 239 cold objects /
20,230,400 bytes), Table (**169.18 seconds**, 191 / 17,805,776), and Document
(**697.02 seconds**, 1,337 / 125,730,779). These runs include the original signed
recovery schedule, a separate SQL query, current denial after a returned prefix,
complete nested rows, and permanent request retirement/collection. The Document
run spends 495.20 seconds provisioning accepted state. The subsequent Table
`just test::unified-ingress table` passes in **277.60 seconds** (320 objects /
30,600,944 bytes): it additionally exports the frozen bundle and pending token,
exits the shell after a lost upload receipt, and resumes the identical signed
request in a fresh shell. It exercises the separately authorized Board v2 API,
generated TypeScript runtime validation and real Chromium workspace. Browser
checks cover explicit submission, identical retry after an accepted-but-lost
receipt, a failing atlas refresh without losing pending work, view/draft identity,
exact provenance, and protected-state clearing after current denial. Inspection
remains readable while query access is denied. No cookies or browser storage are
created. Later KV/Document browser evidence is recorded above and below.

This proof found and fixed malformed frozen-token errors mapped to HTTP 503
instead of 400, and transient atlas read failure remounting a v2 workspace and
losing its pending request. Those failed attempts are not passing evidence.
Root `just check` passes, including eleven browser-client unit tests and generated
contract checks. `unified-ingress` is an explicit finite task, not a hosted CI
budget measurement or a deployment proof.

The focused signed KV lifecycle task (`just test::unified-lifecycle kv`) passes
in **157.04 seconds**, with 232 cold objects / 20,053,320 bytes and the unchanged
eight authority pages / 8 MiB hot-store budget. It checks caller denial before
upload, independent source-worker request-read denial before admission and after
committed segment staging, explicit requester cancellation, released-version
read rejection, and completed bounded cleanup. Cancellation can reach the source
as its cancel frame or as withdrawal of the request publication; the requester
keeps its explicit cancelled disposition in either ordering. Source, requester
and courier emit bounded JSON readiness/progress evidence without fixture
payloads or signing seeds. The same Table lifecycle schedule passes in **143.25
seconds**, with 185 cold objects / 16,387,913 bytes. The complete Document
shell/API/Chromium/lifecycle run passes in **875.94 seconds**, including 477.83
seconds of accepted Document provisioning, with 1,612 cold objects / 174,056,281
bytes and 64 resident authority pages. It returns 12 rows / 2 segments / 9,880
Arrow bytes. These durations include the fixture schedule, not just query time.

The real-clock opted-in KV request-expiry proof passes in **194.84 seconds**, with
116 cold objects / 9,727,232 bytes. A complete result and prefix are readable
before the deadline; expired status/pages reject, and node/disk-store recovery
cannot revive them. The source pin is released. It uses a three-minute lifetime
and waits through the authority's declared clock uncertainty. This uncovered
and fixed an unlimited requester wait under finite resource lifetime. Component
coverage checks earliest process/resource deadlines, authenticated timer closure
and bounded cleanup. Table expiry passes in **198.24 seconds** (125 cold objects /
9,854,161 bytes); Document expiry passes in **697.82 seconds** (1,261 cold objects /
109,186,815 bytes), including accepted-state seeding. Neither uses a test clock.

The KV ingress run also reaches passing shell, generated-client, Board API and
Chromium checks, including uncertain retry and current denial, before the newly
added lifecycle test fails an incorrect staged/completed-segment assertion. The
Document ingress run reaches passing shell/API checks but its browser fault
injector incorrectly rejects a legitimate pre-admission HTTP 429. The injector
now forwards rate limits and drops only an accepted receipt. Neither incomplete
combined run is counted as a complete passing schedule. The KV lifecycle rerun
above fixes its inspection helper's bounded stale-read handling as well.

## M17 qualification

The standalone Station suite passes **42 tests in 538 ms** with **18 MiB test
process peak RSS**. Immutable-index cases cover 1024-key permutations, retained
roots, ordered continuation, corruption, failed path copying and current read
denial, including on a cache hit. Its fixed eight-node cache stores verified
bytes and reopens publication descriptors under current policy before use.
The Document package passes **18 tests in 1 second** with **17 MiB peak RSS**,
including concurrent merge permutations, Unicode text, private-turn recovery,
finite/unlimited checkpoints and reconstruction from a checkpoint plus accepted
tail. These RSS figures include the tests' in-memory reference stores.

`just test::document` passes over disk Ursula with an **8 MiB hot-store limit**.
The four phases take **609.631 seconds** excluding compilation. It kills the
actual worker three times during candidate/checkpoint publication, restarts the
node and store, rejects stale owners and recovers exact signed retries at change
acceptance, checkpoint publication, cleanup and node checkpoint boundaries.
Final acceptance still fits four mutations including framework state and emits
exactly one acceptance output. The final recovery uses **one resident authority
page**. Current-policy reads through a separate read-only principal preserve
exact old snapshots, enforce revocation after a returned prefix and reject
closed history, stale epochs and permanent retirement. Bounded cleanup retains
permanent ledgers. The run records 361 turns, 8,984 resource reads and 396 cold
objects / 35,169,506 bytes. This is a local measurement, not a hosted CI budget.

`just check` validates the independent Python-generated SDC1/SDR1 change and
reference fixtures, including full-width integers, negative zero, binary and
Unicode. The same fixtures pass through `station_document_codec` in the real native
library and port host, including invalid/truncated/canonical-identity checks.
`just bindings::generate` and `just bindings::build` pass, and `just check` checks
all generated declarations against the public Zig types. Public SDK and application-surface evidence appears below; the disk proof
alone does not establish those surfaces.

`just bindings::document-native` passes in **181.23 seconds** over disk Ursula.
It uses 140 bounded scoped turns through the real native library and port host,
replaces the host mid-upload with fresh ownership, refuses changed job content
without consuming private mutation budget, preserves old accepted values across
new resource cuts, and exposes conflicts/text through a separate read-only
principal. It rejects reads after prefix revocation and Document retirement.
The bridge's eight component tests pass in **15 ms / 8 MiB peak RSS**; `just check`
also passes after generated schema/native additions. Public SDK evidence follows
separately; no remote Document service protocol is claimed by this bridge proof.

`just bindings::document-python` passes the installed public Python API in
**224.26 seconds**, including clean wheel installation. Independent change/Unicode/
full-width/reference fixtures round-trip through public types. Its 139 scoped
turns cover an empty checkpoint, host replacement during upload, exact duplicates,
a disconnected peer edit, old accepted reads through a separate non-executing
principal, prefix revocation, conflict/text visibility, resynchronization and
permanent retirement. Asynchronous cancellation followed by runner close joins
native reads; escaped owner objects reject. Strict mypy passes all 20 public SDK
and example modules. The installed Node schedule also passes in **222.85 seconds**, including clean
tarball installation and the same 139-turn/read-only-consumer schedule. Additional
Node tests reject dropped Document operations after native completion; typed
construction copies inputs before awaiting and prepared byte getters return
copies. Vite+ formatting/lint and strict TypeScript pass.

`just bindings::document-ruby` and the installed Ruby consumer pass the same
schedule in **226.06 seconds** with clean gem installation. Frozen owned values
round-trip full-width integers, negative zero, binary and Unicode; invalid UTF-8
and escaped turn owners reject. Reads use the runner's serialized worker, and
close joins an outstanding read before destruction. `just check` passes after
the Ruby additions.

`just bindings::document-rust` and the installed Rust consumer pass in **253.21
seconds**, including clean crate compilation and the same 139-turn schedule.
Compiler rejection cases prevent a Document owner from escaping its turn and
prevent a reader from overlapping runner mutation. Full-width values, Unicode,
retained references and post-retirement reads use the shared fixtures. Threaded
reads are joined before disposal; arbitrary thread cancellation is not claimed.
Rust formatting and source checks pass.

The installed C11 and C++17 Document consumers pass in **225.84 seconds** and
**235.01 seconds**, respectively. C callbacks compile separately with the C11
compiler; C++ uses variant values and scoped RAII owners/readers. Both execute
139 committed turns, exact change/reference fixtures, host replacement, independent
reads, preserved conflicts/text, prefix revocation and permanent retirement.
Escaped owners reject, readers fail closed after runner destruction, and copied
results remain owned. Threaded reads are joined before disposal. The root
`just check` also passes after rebasing onto `origin/main` at `145c380`.

The installed Java 21 Document consumer passes in **244.38 seconds**, including
clean JAR installation and compilation with `-Xlint:all -Werror`. The 139-turn
schedule preserves full-width values, negative zero, immutable bytes, Unicode
scalar positions, exact older references and current read authority across host
loss. Invalid surrogates and expired owners reject. A cancelled read future is
followed by joined runner close, and later reader use fails closed. The generated
host schema validates native response shapes before typed materialization.

The installed .NET 8 Document consumer passes in **223.35 seconds**, including
clean NuGet restore and compilation with zero warnings. It executes the shared
139-turn authority/recovery schedule, verifies immutable operation/value buffers,
full-width numbers, Unicode scalar text, original references and conflict states.
Cancelling an admitted read followed by asynchronous disposal joins native work;
readers fail closed afterward. Invalid surrogate strings and escaped owners reject.

The installed Erlang and Elixir Document consumers pass in **220.99 seconds**
and **224.03 seconds**, respectively, completing this installed API schedule for
all ten M11 language targets. Both execute the same 139-turn recovery/authority
schedule, independent canonical fixtures, full-width values, Unicode text,
conflicts, retained references, prefix revocation and retirement. Immutable
records/structs use the shared Zig semantics; expired callback owners reject.
Reads use the existing serialized BEAM worker and close rejects later calls.
The test joins a separately spawned read before closing; it does not inject
native cancellation or claim BEAM process death cancels remote work.

The Document package now passes **25 tests in 1 second / 17 MiB peak RSS** after
adding authenticated remote calls. Independent Python fixtures cover SDQ1,
SDT1, SDO1 and SDW1, including full-width IDs and exact frame sizes. Seven new
component cases reject caller/replica impersonation, digest substitution, changed
policy, access loss after a verified chunk, retired publications and replacement
PIDs. They reconstruct every private step, preserve the original reply route,
atomically reject missing dependencies and roll back final acceptance when the
reply budget is exhausted. Caller tests preserve peer/correlation and reject
spoofed or conflicting outcomes. These in-memory component tests alone do not
qualify remote disk recovery or deployment. The root `just check` passed
after completion of all ten installed SDK APIs.

`just examples::document` (also `just test::document-remote`) passes the real
Zig writer and two independent editor binaries in **571.4 seconds** over disk
Ursula with an **8 MiB hot-store limit**. It verifies disconnected/reordered
structured and Unicode text edits, explicit conflicts/resolution, duplicates,
one writer SIGKILL during candidate publication, node/store restart, denied
request access followed by fresh-owner recovery, exact signed acceptance retry,
finite-window resynchronization and permanent retirement. The run records 421
writer turn attempts, a four-mutation maximum, 642 cold objects and 64,766,910
cold bytes. It also refuses reuse of a completed activation marker. Caller and
writer PID-scoped inspection requires optional cross-resource associations plus
separate read grants; the proof does not broaden them to realm execution rights.
The Document tasks are registered as focused verification; their hosted CI
cost has not been measured.

The Document component suite now passes **27 tests in 1 second / 17 MiB peak
RSS**. Bounded metadata pages count accepted registers, assignment IDs and
conflicts without returning application values. Tests cover an eight-record
boundary, exact older snapshots, invalid cursors, revocation between pages and
permanent retirement. A separate regression ensures explicit policy rejection
of an admitted job closes it without disclosing an accepted-state basis. These
metadata readers are the library handoff for Board. `just check` passes with the worker and these library additions.

`just examples::document-compose` passes in **208.78 seconds**, including cached
static builds, with two separately credentialed editors and a fenced writer.
It repeats the original caller after fresh ownership, resumes an unpublished
candidate after node/store loss, merges reversed structured/Unicode changes,
resolves conflicts, recognizes duplicates, resynchronizes after a finite checkpoint
window and refuses changes after retirement. The client network cannot connect
to Ursula, MinIO or external TCP. The run records **542 cold objects /
63,005,309 bytes**, using **8 MiB hot storage and 8 MiB cold cache**. The first
no-cold-tier attempt exhausted the 512 MiB Ursula container; raising that limit
was not the recovery. The chart now supports a separately created configuration
Secret without copying credentials into Helm values or ConfigMaps; its deployment
render/lint tests pass. The root `just check` also passes. These are local
measurements; they do not establish hosted CI cost.

`just transit-board::document-browser` passes the complete local two-editor
schedule in **596.76 seconds**, including its real Chromium test (**12.0 seconds**).
The generated API/model and UI show exact accepted identity/revisions, five
retained registers, one conflict and six assignments without application values.
The proof verifies a stale cut, an actual metadata continuation, denial of that
continuation after revocation, browser clearing, restored access, the finite
history floor and retirement metadata. It records **621 cold objects /
63,935,059 bytes** under the same 8 MiB hot limit, plus writer SIGKILL,
node/store restart and exact acceptance retry. Counts include retained text
character registers, not just application field names. Component API tests,
strict frontend checks and all nine frontend unit tests pass.

`just examples::document-reference` passes in **497.08 seconds**, including cached
builds. Two editors execute as independent Substrate/gVisor activations with
fresh public registrations and exact operator-recorded ownership. The trusted
writer runs in a separate confined Kubernetes pod. The schedule kills an editor
worker, recovers the original call, interrupts an unpublished candidate with
node/store loss, and completes conflict resolution, duplicate handling, finite
window resynchronization and retirement. It records **610 cold objects /
61,575,930 bytes**, with **8 MiB hot storage and 8 MiB cache**. Isolation probes
deny direct storage, provider/control APIs and external TCP while permitting
Transit. The proof owns and removes its namespace and atespace.

Two failed reference attempts exposed a replacement-order race and intermittent
five-second writer read timeouts at different operations. The successful schedule
holds replacements until Ursula is ready and addresses the trusted writer's
already-allowed fixed Service IP. This removes per-request writer DNS resolution;
it does not qualify arbitrary DNS failures or change client timeout budgets.
The manual restart used during diagnosis is excluded from the passing evidence.
This is cold restart against retained disk/object data, not disk-loss recovery,
automatic growing provider reconciliation or hosted CI qualification.

## M16 finite connector qualification

`just test::unit` runs the new RPC request codec against a Python-generated
GRQ1/GRB1 fixture with independent Publication digest computation. It covers
original protobuf bytes, Unicode, duplicate/binary metadata, empty messages,
full-width references and canonical parsing; it is not a durable RPC proof.

The shared `PublicationUpload` helper now stages HTTP's two immutable request
records with the same frozen identity and one bounded operation per turn.
Units cover partial upload, changed content/identity, occupied namespace refusal
and private-decision rollback. The unchanged HTTP worker corpus passed after
this extraction in **483.14 seconds**, with sixteen sends, eight applications,
two cancellation requests and 1,066 cold objects / 116,710,006 bytes under the
8 MiB hot limit. These local timings do not establish hosted CI cost.

HTTP and RPC now share authenticated admission/routing/disposal and the public
Transit worker driver. The unchanged HTTP recovery corpus passed after both
extractions in **491.58 seconds**, with sixteen sends, eight applications, two
cancellation requests and 1,025 cold objects / 114,036,242 bytes under 8 MiB hot
storage. This is the shared-component regression.

The installed C11 and C++17 RPC consumers additionally pass this shared SDK
schedule in **69.24** and **74.66 seconds** respectively, including isolated
installation/compilation. `just bindings::c-sdk-test` runs both protocol schedules.
C explicitly preserves status presence; C++ uses an optional status and move-only
readers. Both authenticate control replies and join a delayed replay read.

Java and .NET installed RPC schedules pass in **75.53** and **71.06 seconds**,
including clean JAR/NuGet consumer compilation. Both additionally execute the
independent status-zero/unknown/rejection/release fixtures and truncated-outcome
checks. Their public cancellation views invalidate the reader while runner close
joins underlying native work. These are local measurements, not hosted budgets.

Erlang and Elixir RPC schedules pass in **68.08** and **70.56 seconds**, including
clean OTP consumer setup. Both use the shared runner's bounded per-protocol token
state: stale copies cannot skip undisclosed parts, failed readers cannot resume,
and runner close joins work after killing its waiting process. Shared fixtures
preserve observed zero versus unknown and reject truncated replies. Every M11
language now qualifies the finite RPC caller/replay/disposal surface. The unchanged
Erlang and Elixir HTTP schedules pass with the shared reader in **68.26** and
**68.48 seconds**. `just check` also passes after all ten SDK extensions.

The Zig HTTP caller now uses the shared `Exchange.Caller` for bounded ticks,
request publication, durable correlation and authenticated reply storage. Its
unchanged local application/restart/replay proof passes in **27.05 seconds** with
exactly one network send. Protocol request/replay validators stay in the adapters.

The Zig RPC caller now passes local (**35.05 seconds**), fresh-key bootstrap
(**36.80 seconds**), Compose (**138.86 seconds**) and reference placement
(**364.86 seconds**) schedules, each with exactly one RPC and 54 response bytes.
The reference task completed owned-resource cleanup after caller worker loss,
fresh registration/ownership, node/store restart and replay with the peer stopped
and credential deleted. Caller/effect network and file isolation use the shared
[operator placement](../examples/exchange/README.md); the default installation is
untouched. HTTP regressions through the shared placement pass locally in **26.97**
and in Compose in **105.58 seconds**. Container timings include changed-image
preparation and concurrent proof load. These are local measurements, not hosted
CI budgets or automatic growing runtime binding/supervision evidence.

`just transit-board::grpc-browser` passes the real RPC capture/API/browser
schedule in **375.54 seconds** excluding compilation (the browser portion takes
**11.7 seconds**). It checks all four shapes, source-bound descriptor/member
metadata, status zero, half-close and directional counts, immutable inspection,
current read revocation and browser clearing. Generated and handwritten runtime
validators reject private fields, narrowed identities and inconsistent evidence.
The unchanged worker recovery tail retains nine sends/eight applications and
691 cold objects / 67,103,930 bytes under the 8 MiB hot limit. Board reports
protocol evidence only; it loads no protobuf bodies or credential/routing values.
`just check` passes with eight frontend boundary tests and generated contracts.

`just test::grpc-faults` passes in **184.48 seconds** excluding compilation.
It kills the actual worker during request preparation, immediately after dispatch
commits but before network I/O, after capture completion, and after observation
commits. Every recovery restarts node and disk store. Preparation resumes; an
authorized attempt with no recorded response closes unknown without sending;
complete/observed capture settles without another send. Current effect permission
is revoked while dispatch waits at ingress. A blocked peer does not prevent work
cutoff, explicit closure, forged-executor rejection, pending-effect cancellation
or permanent retirement. Five RPCs/five applications retain 349 cold objects /
34,224,103 bytes under the same 8 MiB hot bound. The test does not promise remote
cancellation after already authorized work.

`just bindings::grpc-faults` adds actual public caller schedules. The installed
Python consumer passes committed-reply worker loss and node/store restart before
delivery in **71.60 seconds**, then the ordinary read/disposal checks. Caller
retirement after dispatch passes in **58.22 seconds**: one authorized RPC finishes,
its result keeps the original retired destination across restart, a replacement
PID receives nothing, and explicit controller disposal reclaims the capture.
Neither case implicitly repeats the RPC. Other languages run the common SDK
ownership schedule; these two additional failure schedules use the Python caller
and the same shared Zig authority and framework implementation.

`just test::grpc-worker` separately passes in **344.45 seconds** excluding
compilation over disk Ursula and the actual Zig worker. All four shapes complete
and replay, then lose workers during partial durable response capture and recover
as closed unknown without another send after node/store restart. Exact signed
seal/dispatch/observation retries recover dropped receipts. Current endpoint/grant
changes, generation re-entry, replay prefix revocation and retired capture reject.
An explicit idempotent retry succeeds under the original budget; another attempt
is refused. Bounded cleanup preserves lineage until descendants release it. The
peer records nine sends and eight applications; the 8 MiB hot profile retains
697 cold objects / 63,978,080 bytes. This controller-driven proof does not qualify
public caller SDKs, deployment placement or every final-publication crash boundary.

`just bindings::native` also passes the RPC native/port fixture and growing
scoped upload/call/retry/disposal schedules, including host replacement mid-upload,
changed-reference refusal and unchanged mutation budgets after failure. Both
protocol readers use shared local ownership/copy-out logic, with allocation-failure
rollback units. The independent fixtures preserve empty/binary/Unicode messages,
duplicate metadata, full-width identities and observed `OK` versus unknown. This
qualifies the native bridge. Installed Python, Node, Ruby and Rust RPC callers
now pass the shared disk-backed schedule in **64.74**, **70.02**, **65.56** and
**96.56 seconds** respectively (including clean consumer setup). Each binds the
local descriptor, resumes upload after host replacement, sends binary/Unicode/
full-width protobuf plus an empty message, authenticates its reply, rejects replay
after prefix revocation, joins active reader work and disposes its durable hold
before/after cleanup. Typed retry refusal allocates no child or send. Each peer
records exactly one RPC. The unchanged Python and Node HTTP schedules pass through
the shared harness in **65.95** and **68.32 seconds**. The remaining language and placement proofs are recorded above; these local
timings do not establish hosted CI cost.

The final unchanged HTTP/Board browser regression passes in **505.30 seconds**,
with sixteen sends, eight applications, two cancellation requests and 1,028 cold
objects / 116,002,637 bytes under the original 8 MiB hot bound. `just check`
passes after RPC code generation and the expanded failure tasks. No expanded
hosted timing run is claimed; that budget work remains deferred.

`just test::grpc-codegen` regenerates the pinned descriptor's Zig helpers and
compiles/uses all four request shapes, exact descriptor identity and typed secret
references. Independent descriptor mutations reject missing types, truncation,
empty and oversized data without producing partial helper source. It is offline
construction evidence, separate from transport and dispatch qualification.

`just test::grpc-libraries` runs the selected pinned HTTP/2, HPACK, protobuf and
gRPC client suites. Compatibility changes and the intentionally excluded server
surface are recorded with source hashes in the [snapshot](../third_party/zig-libs/README.md).
`just test::grpc-transport` runs all four call shapes against grpcio 1.80.0 over
TLS, resolving all four methods from local protoc-generated descriptors and
preserving original protobuf bytes with binary/Unicode/full-width values,
duplicate/binary metadata and distinct trailers. Eight calls exercise complete,
non-OK, oversized, exhausted-budget and stalled results without retries.
Six independent h2 peer schedules add 64-byte request credit, 16-KiB response
credit, a response larger than its window before request credit is returned,
missing status, truncated/compressed frames and malformed/duplicate terminal
status. The same-frame END_STREAM regression rejects a false terminal head even
when later DATA and END_STREAM arrive in one read. This is transport evidence;
the same live callbacks now pass through the pure RPC capture/replay adapter,
including frozen policy, 4 KiB message parts and 256-byte replay reads. Units
reject changed digests, missing parts, false terminal counts, invalid metadata,
undeclared credentials and unsafe retry changes. Python-generated GRH1/GRM1/GRS1/
GRT1/GRO1/GRC1 fixtures fix the binary layouts independently. These sinks are
in-memory protocol probes; durable recovery, SDKs and deployment are qualified separately above.

`just test::tls-alpn` executes a real Zig client against six independent TLS
connections: TLS 1.2 and 1.3 each accept `h2` and reject absent or incompatible
selection before application bytes. Units reject unsolicited/duplicate selection,
unknown protocols and malformed vectors. The unchanged HTTP transport and
certificate-path corpus passes after this addition. HTTP/2 and gRPC streaming
are not established by this negotiation proof.

## M15 connector work in progress

The terminal-publication fault extension to `just test::http-worker` passes in
**499.61 seconds** excluding compilation. The executor is killed after kernel
observation commits but before the receipt/framework publication; fresh ownership
after node/store restart settles without another send. A second node/store
restart happens after the correlated output commits and before delivery. The
schedule still records sixteen sends, eight applications and two cancellation
requests, retaining 1,009 cold objects / 113,779,019 bytes. Endpoint hostname,
scheme, port and metadata-address changes reject before dispatch. The independent
transport proof now has **22 sends**, explicit SNI/Host assertions, a nonexistent
DNS name with a numeric pin, nonnumeric-address refusal and wrong-CA rejection.
Both uppercase and lowercase proxy variables are ignored. The non-CA intermediate
audit exposed a standard-library TLS weakness, now fixed by the pinned
[TLS adapter](../packages/zig/transit-tls/README.md). The transport task additionally
uses twelve independent TLS 1.2/1.3 handshakes: valid chains succeed, while non-CA
issuers, missing signing usage, excess path length, client-only purpose and
excluded DNS names fail before HTTP bytes. Standalone validator and TLS suites
pass, including malformed DER and the original forged-chain regression. These
are fixture-based qualification, not a general cryptographic audit.
With this transport, Compose passes in **98.79 seconds** and reference placement
in **301.22 seconds** before successful cleanup, under concurrent proof load and
with changed-image preparation. Each makes one remote send, replaces its caller,
restarts node/store and replays without the peer or credential.
The hardened disk schedule passes in **489.90 seconds** excluding compilation,
with sixteen sends, eight applications, two cancellations and 1,067 cold objects /
117,643,105 bytes. No retention or storage-limit increase was needed.

`just examples::http-reference` passes in **192.85 seconds** before successful
owned-resource cleanup. The actual gVisor caller admits a request, loses its
worker pod, registers a fresh in-memory key, receives explicit Transit ownership
and recovers the same saved call. The trusted connector pod makes one TLS request
under explicit egress rules; both roles' network probes reject raw storage and
provider/admin targets. Node/store pod restart, peer shutdown and credential
removal precede replay in another fresh caller. The task checks Actor/template/
worker attribution and keeps the existing default installation untouched.
This is finite operator placement, not automatic growing runtime binding or
supervision. See the [placement guide](../examples/station-http/docs/placement.md).
The accompanying local bootstrap and Compose regressions pass in **29.45** and
**86.48 seconds**, with changed-image preparation and concurrent proof load in
the latter. The reference task is in the external verification inventory.

The expanded `just test::http-worker` schedule passes in **493.33 seconds** excluding
compilation, with **sixteen sends, eight applications and two cancellation
requests**, retaining 1,074 cold objects / 116,719,300 object-store bytes under the
same 8 MiB hot bound. It kills the executor after a response chunk is durably
committed while its acknowledgement is withheld. The capture remains partial;
replay refuses. Fresh ownership after node/store restart closes unknown without
resending, then explicit retirement/cleanup reclaims the unsealed member too.
This extends the earlier schedules below; it does not add a hosted measurement.

`just examples::http` builds and executes the actual Zig caller and connector
against a disposable disk Ursula, growing authority and independent TLS peer.
The **26.81-second** local schedule checks caller replacement after publication
preserves the call, separately authorized outbox delivery, one remote send,
correlated receipt and binary/Unicode replay after node/store restart with the
peer stopped and credential removed. Its operator uses the real growing CLI;
workers receive scoped keys. This local task does not qualify OS egress isolation.
`just examples::http-compose` passes the same schedule in **19.40 seconds** with
cached static images, separate internal networks, read-only role mounts, resource
limits and no published ports. Its caller-network probe reaches Transit while
TCP access to the peer, Ursula and an external address fails. Node/store recovery
and replay run in the real containers. This is local Linux/Docker evidence, not
Substrate qualification.

`just examples::http-bootstrap` passes locally in **28.04 seconds**, replacing
the caller's key in memory for every invocation. The operator validates the public
registration, rotates only that PID's grants and records the exact expected
generation. Reissued resource grants preserve the saved call and replay after
restart. Pure client tests reject successor-generation adoption, wrong ownership,
blocked or retired processes. This prepares finite reference placement; it does
not prove provider attribution by itself.

The worker's bounded diagnostic integration passes the complete disk/S3 schedule
in **445.26 seconds** excluding compilation, with the same fifteen sends, seven
applications and two cancellation requests. Structured stderr excludes credentials,
raw targets, credential paths and authority URLs; stdout stays parseable JSON.
An observed recovery finishes while its debug stderr pipe is intentionally left
full and emits no fresh transport event. `just test::telemetry` also passes all
four off/drained/stalled/closed sink modes with 10,000 completions under one-CPU
affinity; metrics accumulate despite diagnostic loss. These are service-local
observations, not counters of unique durable transitions or remote applications.

`just test::unit` includes exchange segment/coverage, frozen effect intents,
identity conflicts, quota/rollback, terminal cleanup and old-source availability
checks. Ninety-six durable dependency tokens exercise admission, wrong-holder
release, duplicate disposal and permanent token retirement across turns. Capture
cannot retire before kernel settlement and explicit caller/consumer disposal.
The additive EXL2 lineage context is independently byte-fixtured and bounded at
214 bytes. Package and root unit checks prove its four-mutation allocation,
rollback with occupied capacity, immutable duplicate identity and preservation
of the original caller/input/deadline and attempt budget across EXL1/EXL2
descendants. HTTP service units also check authentication before request reads,
atomic child/reply-route allocation, read/mutation/output rollback, conflicting
correlations, unpublished/retired parents and exhausted total budgets.
`just test::http-transport` runs the real Zig transport against independent
Python HTTP/TLS peers: 22 single-send requests cover 16,387-byte binary chunked
bodies, trailers, header omissions, redirects, ambiguous framing, truncation,
capacity refusal, capture failure, lost responses and timeouts. TLS authenticates
the configured hostname while dialing its explicitly pinned IPv4 address.
Ambient proxy settings are ignored. Close-delimited TLS bodies are rejected
because the pinned transport relies on HTTP framing to detect truncation.

`just test::http-worker` runs the actual finite worker over disk Ursula and the
existing owned MinIO fixture; Docker is required. It loses
accepted segment-seal, dispatch and observation replies and checks exact retries;
SIGKILLs a preparing worker after a committed request chunk, restarts node/store,
and resumes under fresh ownership with matching bytes and the original deadline;
restarts node/store; replays a 1,027-byte response without another send; and kills
the worker after remote application. Fresh ownership closes that attempt unknown
without resending. Reusing an entered activation fails. Public body reads recheck
resource permission after an actual prefix. A separately requested idempotent
retry uses a new linked effect with the original key and request bytes. Changed
bodies and exhausted attempt budgets reject. The independent peer records three
remote requests but only two applications across those retry scenarios. Additional
explicit status, cancellation and captured same-authority redirect followups each
have separate effects, giving seven sends, three applications and one cancellation
request across those controller scenarios. Status/cancellation evidence leaves the original effect
closed unknown. Pure policy cases reject metadata/admin address changes,
cross-authority/changed redirects, undeclared action targets and policy changes.
The worker proof uses TLS and a versioned credential file. Changed numeric
destinations, wrong credential versions and header scopes reject before dispatch;
resolved credentials are absent from all durable mutations. Replay works after
removing the credential file.
Changed byte budgets, capture allowlists and CA bundle bytes also reject before
dispatch. Replay now uses the HTTP validator: required record order, complete
heads, original body counts, status and terminal timing/omission evidence must
agree with the verified exchange coverage. Shared binary fixtures independently
fix full-width identities, empty/binary member commitments and Unicode escaping;
strict replay reports a gap when requested data was redacted.
Explicit release retires availability before cleanup. The proof rejects replay
while uncollected bytes remain, restarts node/store during reclamation, and resumes
bounded cleanup to its durable end without another network attempt.
The public-admission extension publishes metadata/body in a separate caller's
resource and sends an authenticated Station call to the worker. The proof revokes
and restores request access, rejects changed method/target scope before dispatch,
and delivers one correlated observed reply. Capture is independently owned;
optional associations preserve PID-scoped read access without required caller
lifetime dependencies. After remote application, caller termination plus worker,
node and store replacement produces closed unknown with the original attempt.
The reply's outbox destination is retired; a replacement PID receives no input.
Public retry now uses a new call from that original application PID. Changed
scope/policy rejects before allocating a child. A revoked request-read grant stops
the activation without blocking the process or advancing the input; restoring
access and fresh ownership resumes the same call. Losing the committed EXL2
allocation receipt proves exact retry of child, route and root-budget consumption.
Fresh preparation resumes the child without another allocation or send, then
execution produces a new effect/attempt and correlated outcome. The independent
peer sees two sends and one application, while the parent remains closed unknown.
Public status/cancellation now publish separate empty-body requests from the
original caller. Public redirect publishes a new target only after observing a
complete 307; no implicit follow occurs. All preserve new correlations/effects
and leave the original effect unchanged. EXB2's unsettled-child count blocks parent
cleanup before and after node/store restart, then permits cleanup after all
children settle. Package tests additionally cover abandoned siblings, nested
descendants, duplicate settlement and mutation rollback without refunding slots.
The expanded proof passes in **458.34 seconds** excluding compilation, with
**fifteen sends, seven applications and two cancellation requests**. A prior run
hit the default hot-only 64 MiB store limit; the proof now uses M10's existing
8 MiB hot/S3 profile. This run persisted 967 cold objects and 103,195,312
object-store bytes without enabling retention or raising memory limits.
The combined 477.68-second worker/Board schedule also uses an independently owned
growing Registry service to bind the caller name, retire that caller and rebind
to its replacement. After node/store restart the new binding persists, but the
original HTTP outcome still has the retired destination and the replacement has
no input. Growing units retain 96 names while each operation uses three point
reads, exercise a principal above 255, tombstones, stale revisions and rollback.
`just test::station` and `just bindings::native` pass their legacy regressions.
Broader deployment qualification remains open.

`just transit-board::http-test` adds the real Board API to that disk/S3 worker
schedule; `just transit-board::http-browser` additionally exercises its embedded
UI. The latter passes bounded record paging, exact source alignment, no raw value
disclosure, unchanged durable authority position across inspection, stale-revision
refusal, and current read revocation including a previously valid continuation.
The actual generated JavaScript validator accepts service pages and rejects
numeric full-width exchange IDs. The real browser clears capture cards on live
revocation, resumes after access is restored, sends only GET requests, and leaves
no cookies or local/session storage. The complete worker/API/browser schedule
took 460.46 seconds excluding compilation, including 11.7 seconds of Chromium
execution, and retained 971 cold objects / 104,734,346 object-store bytes. This is
local evidence, not hosted CI qualification.
Deterministic projection/client units cover malformed versions, wrong writers,
private context omission, exact uint64 limits and source mismatches. HTTP timing,
omission and root endpoint policy inspection are now qualified by the selected
HTTP metadata route. The complete worker/API/browser schedule passes in
**477.68 seconds**, including **11.7 seconds** of Chromium execution, retaining
966 cold objects / 106,209,530 object-store bytes. The read adapter checks selected
record commitments without reading bodies; partial captures expose no invented
terminal data. Generated client fixtures reject unsafe numeric timing/policy IDs,
inconsistent member sources and private fields. Revocation clears the selected
metadata view. Telemetry assertions allow bounded event loss and loss reports.
`just transit-board::query-test` also passes against the changed growing router.

Public HTD1 disposal now releases only the authenticated original caller's hold.
The real worker's `poll` mode passes disposal without its credential file,
accepted-receipt loss with exact retry,
node/store restart, repeated disposal before and after cleanup, and an actual
replay prefix refusing continuation after retirement. Its HTK1 acknowledgement
retains the call's source/correlation. Release alone leaves replay available;
retirement and cleanup are separate controller operations. Package tests also
prove output-budget rollback and preservation of another consumer's dependency.

The same real capture exercises `station_growing_http_read`: one active reader,
owned bounded chunks, actual prefix revocation, sticky failure, explicit close,
stale reader IDs and reopening. Returned body bytes survive native destruction;
replay completes after deleting the request credential, without another send.
Native allocation enumeration proves an undisclosed part cannot advance a cursor
when response allocation fails. Shared HTTP codecs run independently constructed
admission/outcome fixtures through the native library and local-codec port.
Growing native actions reject unpublished or mismatched request references,
preserve duplicate chunks and publish the ordinary durable call through the
existing preparation/dispatch gate. `just bindings::native` includes these
checks alongside the existing Table/query and C/C++/Python interoperability proofs.
The shared native/port disposal codecs also consume the independent HTD1/HTK1
fixtures, preserving full-width exchange IDs and rejecting wrong/truncated frames.
The `http_release` scoped action rejects invalid identities without consuming
turn capacity, then emits the exact durable call without requiring a capture
read grant. The service retains holder authentication and current-policy checks.
Native/port codecs also consume the independently constructed HTU1 fixture. The
scoped `http_followup` capability preserves all 64 parent bits, validates the exact
published request in the current associated resource, and emits the ordinary
durable call under a new correlation. Invalid/unpublished/changed references
consume no turn capacity. The native suite passes these additions alongside
its existing ownership, exact-retry, Table/query and interoperability schedules.
The installed Python and TypeScript HTTP schedules now include all four typed followup reasons,
full-width parent identity, cross-realm/expired-turn refusal and authenticated
HTF1 rejection with the saved correlation. It reports no child allocation or
additional send for unsupported policy, and still passes durable disposal and
replay. Expanded local HTTP schedules took 63.21 and 70.91 seconds respectively;
TypeScript additionally refuses an invalid reason at runtime. Positive public retry
dispatch belongs to the independent Zig worker proof above.
Rust's typed followup method passes the same installed schedule in 95.12 seconds
including clean compilation; borrowed turn/request ownership remains enforced by
its existing compiler rejection checks.
Ruby passes all four followup symbols, runtime invalid-symbol/cross-realm/expired
turn refusal, authenticated rejection and its previous lifecycle checks in
65.47 seconds for the HTTP schedule.
Java's clean JAR consumer passes typed followups, saved correlations, cross-realm
and expired-turn rejection in 76.33 seconds, alongside all prior raw/Station
and asynchronous capture-reader checks.
.NET's clean NuGet consumer passes in 68.23 seconds for HTTP, including all four
followup reasons, invalid enum values, cross-realm/expired-turn refusal and
authenticated correlated rejection, with prior cancellation/join checks retained.
Erlang and Elixir pass in 65.19 and 68.23 seconds respectively, including all four
followup atoms, tagged invalid-reason/cross-realm/expired-turn errors, saved reply
correlations and the previous immutable-reader/owner-death/join schedules.
C and C++ pass in 62.92 and 70.08 seconds, including compiled C11 callbacks,
typed C++ handlers, full-width parent identity, saved correlation and defined
invalid-reason/cross-realm/expired-turn rejection. The initial C run exposed a
C++ invalid-enum load abort; the C input now uses a checked fixed-width integer.
All ten SDKs qualify followup submission and authenticated policy refusal.
The shared `http_stage` helper freezes namespace ownership and advances one
publication step per turn. Its disk/native proof replaces the host and owner
after a committed metadata prefix, rejects a changed endpoint revision without
consuming mutation budget, resumes to a validated call and rejects retired reuse.

`just bindings::python-test` additionally runs the installed Python HTTP API
through [the shared HTTP caller schedule](sdk_http_runner.py): a binary request
with duplicate headers, escaped Unicode target and credential references, fresh
ownership after a staging prefix, one correlated reply, prefix revocation and
reopening, owned replay after deleting credentials, and joined asynchronous
cancellation. Only one request reaches the independent TLS peer. The local
2026-09-26 expanded HTTP schedule took **52.98 seconds**, including clean wheel installation
and excluding compilation. The ordinary raw client, runner recovery and Arrow
consumer regressions also passed. Sticky replay errors report the current local
failure instead of inheriting a previous authority rejection.
The expanded schedule calls `release_http` from a scoped handler, authenticates
the correlated `HttpReleased` acknowledgement and repeats disposal after capture
cleanup. It runs without a transcript read grant or credential file and still
records only one remote request. Cross-realm and expired-turn calls reject;
independent acknowledgement fixtures preserve full-width exchange identities.
`just bindings::node-sdk-test` runs the same HTTP schedule through clean Node
tarballs, including runtime schema validation, owned request/getter bytes, native
HTTP reply dispatch and joining a delayed replay read during local stop/disposal.
The expanded 2026-09-26 local HTTP schedule took **55.73 seconds**, including
authenticated durable disposal before/after cleanup without transcript access
or credentials, with the existing client,
runner and Arrow regressions also passing. TypeScript handlers opt into the async
shared decoder through `handleHttpReply`; application codecs stay synchronous.
`just bindings::rust-sdk-test` qualifies the same binary caller/replay schedule
through installed source crates and embedded native libraries. The HTTP schedule
took **86.92 seconds** locally, including clean Rust/Arrow compilation and durable
disposal before/after cleanup without transcript permission or credentials. A compiler
rejection case proves a live HTTP reader's mutable borrow prevents another runner
operation; a delayed read finishes before the owned blocking task is joined.
The ordinary client/runner/Arrow regressions also passed.
`just bindings::ruby-sdk-test` also passes the shared HTTP schedule through clean
gems, with frozen owned strings, schema-validated port results and an interrupted
controller wait whose native read is joined during runner disposal. Its local
expanded HTTP schedule took **53.75 seconds** including gem installation and
authenticated durable disposal before/after cleanup with transcript reads revoked.
The existing
Ruby client and Station recovery/query schedule remained passing.
`just bindings::c-sdk-test` builds HTTP callbacks as C11 and a typed C++17
consumer against installed archives. The C and C++ HTTP schedules passed locally
in **57.72** and **60.78 seconds**, including clean consumer compilation, golden
request/outcome fixtures, staged upload recovery, prefix revocation, sticky
failure, copied parts and reader use after runner destruction. Both join a
delayed read during stop/disposal. Both also authenticate durable disposal with
transcript access revoked and repeat it after cleanup. C uses a separate HTK1
decoder and inline acknowledgement type, preserving its existing outcome layout;
C++ adds an explicit acknowledgement variant. The ordinary raw client and Station
schedules passed in the same task invocation. Host
allocation poisoning is implemented; fault-injected host allocation coverage
remains distinct from the native allocation proofs.
`just bindings::java-sdk-test` adds clean installed JAR HTTP callers to this
expanded schedule. It passed locally in **62.14 seconds**, including authenticated
durable disposal before/after cleanup without transcript access, immutable bytes, the
explicit application/outcome codec, prefix revocation and future cancellation
followed by joined cleanup. The independent raw client and Station recovery/query
regressions passed through their task commands as well. A cancelled read view
invalidates its local reader; native execution remains owned until disposal.
`just bindings::dotnet-sdk-test` passed the same installed NuGet HTTP schedule
in **60.17 seconds**, including authenticated durable disposal before/after cleanup
without transcript access, immutable copies, explicit typed outcomes,
revocation/reopening and cancelled task waits joined by runner disposal. Existing
raw client and Station recovery/query checks passed in the same invocation.
`just bindings::beam-sdk-test` installs both BEAM archives and exercises Erlang
records and Elixir structs. Both raw client and Station schedules passed; after
fixing a missing import in the new fixture loader, both Station and expanded
HTTP schedules passed through the task's harness in **54.45** and **55.47
seconds** for HTTP. Both authenticate durable disposal under revoked transcript
access and repeat it after cleanup. Immutable reader tokens reject stale cursor reuse; a killed waiting
process cannot silently skip a part, and disposal joins the admitted port job.
All ten SDKs now pass the HTTP fixtures, caller schedule and durable disposal
before/after cleanup without transcript access or credentials. The existing public
counter/query interoperability ring was rerun against these installed artifacts:
all ten edges passed in **255.78 seconds**, including clean consumer installation.

The 2026-09-26 Linux x86_64 worker run took **285.29 seconds**, excluding compilation.
This is local proof time, not a hosted CI or aggregate runner-minute measurement.
Machine output distinguishes sealed capture phase from the kernel outcome.

These checks passed locally on Linux x86_64 with the pinned compiler. They do not
yet qualify general public multi-call/followup APIs, managed secret providers,
every cross-service lifetime combination, all launchers
or hosted CI cost. Those remain explicit
[M15](../docs/roadmap/M15.md) exit obligations. The shared capture
[contract](../contracts/STATION_EXCHANGE_V1.md) distinguishes library coverage
from protocol completeness and effect-result acceptance.

## Test ownership

This directory owns conformance harnesses, fault injection, test-only executors,
and proof results. Application examples live under [examples](../examples/README.md);
tests launch those real binaries rather than a separate implementation of their
logic. The [conformance design](../docs/reference/verification.md) owns the required adversarial
scenarios. Results below describe the recorded bounded milestone profiles, not
a claim that all commands are rerun on every documentation change.

## Running checks

`just check` includes `tests/reference_launcher_state.py`: isolated launcher
regressions cover missing infrastructure, replaced clusters/namespaces, original
identity recovery, interrupted namespace creation and explicit local cleanup
after cluster deletion. Docker failure cannot count as absence. These mocked
boundary checks supplement the real reference launcher proof; they do not claim
Kubernetes recovery or isolation by themselves.
The 2026-09-26 local repair also exercised fresh counter provisioning and a real
reference stop/start cycle: state remained 12, realm/PID/namespace/Actor stayed
fixed, and ownership advanced from generation 4 to 7 with a different worker.
That focused recovery check did not rerun the full reference isolation corpus.

M7 evidence is recorded in [the state proof](#m7-state-resources). The ordinary
suite includes the public state API and real resource-backed Zig caller.

M9 proofs include `just test::arrow` (independent PyArrow validation
of Fuze IPC, including nulls, empty results and wide integers) and
`just test::client-abi` (a generated C header, real authority calls, canonical
signatures, receipt loss, fresh-host retry, revocation and malformed input).
The [Fuze integration notes](../packages/zig/transit-fuze/docs/integration.md) and
[client binding guide](../packages/zig/transit-client/docs/bindings.md) record
their limits. `just test::station` launches the real Zig Station ledger/requester
and courier, proving private state/call commits, lost receipts, fresh ownership,
worker plus store recovery, authenticated replies, scoped registry/supervision,
timers, poison-input blocking and opted-in lifetime expiry/reclamation.
The [M9 evidence](#m9-station-bindings-and-tables) below distinguishes native
language qualification from reference worker qualification.

M11 extends `just test::client-abi` with the explicit growing raw-client boundary.
Its [shared fixtures](verification/sdk-operations-v1.json) pin v3 canonical bytes,
signatures and full-width IDs. The real disk proof checks principal 65,536,
node/provider restart, opaque retry in a fresh process, lost/malformed accepted
replies and revoked reads/receipt recovery. Allocation enumeration covers both
mutation profiles. `just check` and the complete `just bindings::test` matrix
passed after this extension.
The same raw-client task now also runs the independent
[client port](../apps/transit-client-host/README.md), including metadata identity,
profile/command classification, malformed canonical recovery and seedless retry
from a fresh process. Its executable imports no Station implementation. The raw
port and `station_codec_host.py` also verify explicit shutdown acknowledgements
and successful exit while stdin remains open. Station covers local-codec, raw,
legacy and query-enabled growing handles. Native cleanup precedes the response;
this lifecycle acknowledgement does not replace mutation receipts.

`just bindings::test` also runs the [growing Station ABI proof](station_growing_abi.py)
against disk-backed Ursula. It checks every mutation's preparation/dispatch gate,
41 Table rows through bounded pages, retained sources, stale scopes/cursors,
poisoned reads, explicit stop behavior, revocation, native port parity and exact
retry from a fresh process after caller/node/store loss. Native allocation-failure
enumeration preserves accepted receipts until the host can receive them. Both
`just check` and the complete existing language matrix pass with this boundary.
The companion [query ABI proof](station_query_abi.py) uses the native query
profile's bounded 64-page cache. It captures and delivers 41 rows in six IPC
segments, retries lost staging receipts, restarts workers/node/provider after a
seal, checks complete source metadata and decodes owned IPC with PyArrow after
native disposal. Port parity, disabled query access, stale scope and revocation
are covered by the shared `query-abi` scenario. Public language adapters have separate qualification below.

`just bindings::python-test` builds Python wheels, installs only `transit-client`
and `transit-native-client` into an isolated consumer outside the source tree,
and exercises the public raw API against disk Ursula. It covers typed bounds,
copied mutable payloads, canonical classification, a dropped accepted receipt,
seedless retry in another process, host allocation failure after a receipt,
revoked historical retry, one-operation admission and responsive async close
after await cancellation. Strict typing covers the public client and native
artifact resolvers. A second isolated consumer installs Station and the example
package, then exercises the typed runner against a real disk node. It covers
persistence and confirmation failures for permit/open/commit, post-acceptance
host allocation, escaped/wrong-thread turns, strict ingress with stop/block
policies, a poisoned read caught by a handler, responsive cancellation during
an accepted commit, and exact seedless retry after killing the host and restarting
node/provider. Installed counter CLI roles preserve a full u64 reply across a
fresh requester activation. Table/query handlers prove 41 rows/six pages, retained
point reads after mutation, six original IPC segments after disposal, current
access revocation during a result read and process expiry. The optional PyArrow
23 adapter uses the pinned Nix consumer after the independent clean core install.
The shared `public-runner-lifecycle` scenario records comparable observations for
all targets. Qualification is Linux x86_64 with Nix-linked native wheels.

`just bindings::node-sdk-test` builds the independent Node client/native tarballs,
checks the strict public API and installs them outside the checkout using ordinary
package-manager overrides for unpublished local artifacts. No Station package or
manual native loader path is present. Python and Node run the same
[raw-client schedule](sdk_raw_client.py): copied input/export buffers, native
classification, a lost accepted response, seedless host restart, failed host
response parsing/allocation, current revocation, bounded overlap and responsive
close after a local await/abort. A second clean consumer installs Station and the
executable counter/query examples. Python and Node share the
[runner authority schedule](sdk_station_runner.py), including every mutation's
persistence/confirmation hooks, dropped accepted commits, exact seedless recovery
after host/node/store restart, stale/revoked/expired callers, poisoned reads,
41-row retained Tables and six original IPC segments. Node additionally checks
dropped, overlapping, escaped and foreign-context turn calls, callback reentry,
and responsive stop/join during an accepted commit. Its runner unit proof injects
a retained confirmation after host allocation failure; raw port-response failures
and native allocation enumeration retain their separate real boundary proofs.
The optional Apache Arrow JavaScript 21.2 adapter is installed only after the core
proof and preserves int64/null values after disposal and mutation of input copies.
The consumer selects the root manifest's pnpm version through `vp env exec` and
uses normal package-cache fallback; a different filesystem may have its own cache.
Strict checks compile both public examples. Linux x86_64/Nix-linked tarballs are
qualified.

`nix develop .#bindings --command just bindings::rust-sdk-test` builds the
independent raw Rust client and matching native crate. The external consumer
builds with the lockfile and ordinary Cargo patches for unpublished artifacts,
then deletes extracted crates and build outputs before running its installed
executable. The embedded library loads without a Cargo-cache or loader path.
It runs the same raw authority schedule, plus compile-fail checks for overlapping
mutable use, shared handles and use after consuming close. Its initial API is
blocking: `blocking-owner-disposal` abandons an application's receive, keeps
native work owned through explicit close, joins responsively and recovers the
same receipt. It does not claim an async executor adapter.

The Rust Station consumer installs five crates and builds core and optional
Arrow variants using the SDK lock. Registry versions/checksums remain unchanged;
the core dependency tree excludes Arrow. After deleting extracted sources and
builds, it runs `sdk_station_runner.py`, including both installed counter CLI
roles. Compiler rejection covers overlapping turn helpers, `Send`/lifetime escape
and a boolean passed to the u64 codec. The real schedule covers persistence errors
and panics at permit/open/commit gates, handler errors and panics under stop/block
policies, retained confirmation receipts, responsive stop/join during an accepted
commit, caught poisoned reads, exact seedless retry after disk/host restart,
fencing, retirement and revoked result access. Retained Tables span six pages;
six owned IPC streams preserve i64 extremes/nulls and complete source metadata.
The optional Arrow Rust 59 adapter decodes after runner disposal and its batches
survive mutating the SDK bytes; independent PyArrow verifies the same streams.
Rust does not inject an allocator failure into its own FFI wrapper; native retained
confirmation behavior is also covered by the shared ABI/Python proof.

`nix develop .#bindings --command just bindings::ruby-sdk-test` builds and installs
separate Ruby 3.4.9 client/native gems outside the checkout. Its raw schedule
qualifies owned binary strings, full principal bounds, native canonical kind
classification, lost receipts, seedless recovery and revoked historical retries.
Killing the controller thread during an accepted send leaves native work owned;
concurrent work rejects, close joins responsively and retains the known receipt.
Missing/incompatible host overrides and oversized, invalid-UTF-8, malformed-status
and truncated port replies fail with read/uncertainty distinctions. The client
has no Station dependency. Interrupted block acquisition waits for startup and
then joins both the Ruby worker and native child. The bindings CI lane includes
these public proofs.

The Ruby Station consumer installs five gems and invokes both documented counter
CLI roles. It runs the shared `sdk_station_runner.py` schedule with full-width
codec fixtures, all persistence/confirmation gates, reentrant-call rejection,
normal and non-StandardError handler failures under stop/block policy, expired
helpers and cross-thread/fiber access. Killing a waiting caller retains owned
native work through responsive close, including an accepted commit. Exact retry
survives host/node/disk loss without a seed, and fresh owners resume durable calls.
Poisoned reads, retirement, stale ownership and revoked result access retain their
meaning. Retained Tables span six pages, and original IPC buffers survive runner
close and mutation of returned copies. Independent PyArrow decodes all six
segments, including i64 extremes and nulls. Ruby has no selected native Arrow
adapter; the optional-adapter step is explicitly disabled for it, while the full
IPC/metadata/independent-consumer proof runs. Codec reentry is rejected, and a
caught state decoder failure aborts without committing or blocking the head even
under `block_input`.

`just bindings::c-sdk-test` builds versioned C SDK/native archives and C++ headers,
installs them into external prefixes and compiles separate C11 and C++17 callers
with standard pkg-config discovery. Consumers use installed rpaths and adjacent
native discovery without a library-path environment variable or Station library.
Both run the shared raw-client schedule: owned input/export bytes, metadata and
canonical-kind checks, lost accepted receipts, seedless recovery, revoked retry
and responsive joining of an owned blocking task after its controller stops
waiting. C also checks overlap/closed rejection; C++ checks move-only types and
distinct process/resource references. Missing libraries, incompatible native
versions and C SDK version mismatches fail explicitly. The implementation owns
one admitted job and an 8 MiB worker stack. Asynchronous POSIX thread cancellation
is not supported; the controller's local wait is the cancellation boundary.
This qualifies raw clients on pinned Zig/Linux x86_64 with the Nix runtime closure.

The same task installs C/C++ Station SDKs and the actual counter CLI/application
artifacts. A shared C++ conformance controller selects the direct C runner with
compiled C11 callbacks, then the public C++ runner with typed C++ handlers. Both
execute the full `sdk_station_runner.py` schedule: golden codec names/bytes and
u64/i64 extremes, persistence/confirmation failures for each mutation purpose,
callback reentry, exceptions and malformed input under stop/block policy, retained
scope rejection, responsive stop/join through an accepted commit, poisoned reads,
fencing/retirement/current access, and exact seedless recovery after host/node/disk
loss. Six-page Tables exercise retained point/page reads after mutation. Six
original IPC segments survive runner destruction and mutation of copies before
independent PyArrow decoding; no optional C/C++ Arrow adapter is selected. Installed
counter roles run as their actual C11/C++17 binaries. Compile failures reject copied
C++ runners and a boolean passed to a typed u64 state key. Native-version overrides
reject before codec/frame use. Allocation enumeration remains the shared native
proof; this C/C++ consumer does not inject a host allocator failure.

`nix develop .#bindings -c just bindings::java-sdk-test` builds independent Java
client/native JARs with POM dependency manifests and installs only those JARs plus
pinned Gson into an external consumer. Strict Java 21 compilation precedes the
shared raw authority schedule. The proof covers typed bounds, copied buffers,
native metadata, lost accepted responses, exact seedless recovery and revoked
retry. Cancelling both dispatch and a close-future view preserves owned work;
joined cleanup retains the accepted receipt while the controller remains
responsive. Missing/mismatched native JARs, ABI-version overrides, malformed
status, duplicate JSON members, invalid UTF-8, oversized lines and partial output
are rejected. No Station JAR is installed in the raw proof.
The Java artifacts require the Nix runtime closure; Maven resolution/publication,
portable Linux artifacts and JVM allocation-failure injection are not qualified.

The same task installs Java Station/native/example JARs and strictly compiles a
consumer outside the checkout. Its shared runner proof covers all mutation hooks,
exceptions and `Error` callbacks, reentrant/wrong-thread/expired scope rejection,
stop/cancel/join with retained commitment, malformed ingress, caught poisoned
reads, stale ownership, expiry, revoked access and exact recovery after host,
node and disk-provider restart. Both actual counter CLI roles run; full u64 values
survive restart. Typed compile failures reject boolean values for u64 KV keys and
int64 Tables. Six-page retained Tables and six owned IPC segments remain valid
after disposal and are independently decoded with PyArrow; no optional Java Arrow
adapter is selected. ABI/native-artifact and mismatched public-client versions
reject before handler work. Status validation uses each generated ABI's range,
including Station's stale/not-ready/budget statuses. Full-width values are exact
`BigInteger`/`long`, with no floating-point conversion at the public boundary.

`nix develop .#bindings -c just bindings::dotnet-sdk-test` packs independent
`Transit.Client` and `Transit.Native.Client` NuGet artifacts, restores them from
an isolated local feed into an external .NET 8 consumer, and deletes build source
and package caches before execution. No Station package is installed. The shared
raw schedule checks typed bounds, copied payload/export bytes, native metadata,
lost accepted responses, exact seedless recovery and revoked retry. Cancelled
dispatch/close awaits preserve owned native work and the accepted receipt while
the caller stays responsive. Missing artifacts, ABI mismatches and closed handles
reject explicitly; credential-read errors omit private paths. Native calls and
destruction use one owned 8 MiB thread. Portable Linux packages, NuGet.org
publication and CLR allocation-failure injection are not qualified.

The same task independently restores Station/native/example NuGet packages,
compiles typed consumers with warnings as errors, rejects mismatched state/Table
value types, and runs the shared runner schedule. Every mutation persistence and
confirmation hook fails once without rerunning the handler. Both handler failure
policies, expired/wrong-thread/reentrant scopes, poisoned reads, fencing, expiry,
revocation, cancellation/stop/join and exact seedless disk recovery are covered.
`async void` handlers and persistence hooks reject before activation work. The
installed counter executable resumes a durable requester; Table/query handlers
verify bounded pages, retained revisions, nullable signed extremes and complete
provenance. Six owned original IPC segments survive disposal and are decoded by
independent PyArrow; no optional .NET Arrow adapter is selected. Generated-schema
checks reject absent nullable fields, invalid cursors, fractions and oversized
exponents. Native package/ABI checks precede use; SDKs require exact 0.2.0 peers.

`nix develop .#bindings -c just bindings::beam-sdk-test` builds standard OTP
applications with separate Erlang core, Elixir wrapper and native dependencies.
External consumers install only these raw packages through `ERL_LIBS`; the Erlang
consumer compiles with warnings as errors and no Elixir/Station dependency.
Both languages pass the shared typed/raw schedule: native classification, exact
seedless retry, rejected non-send/noncanonical material, caller/task death during
accepted I/O, responsive joined cleanup with retained receipts, and revoked
retry. The admission proof distinguishes a dead unpublished reservation from an
active worker-owned job. Supervisor start/handle/close and parent termination
join native cleanup. Missing artifacts, native/package/SDK version mismatches,
malformed/duplicate/fractional/oversized/partial/invalid-UTF-8 responses and closed
handles reject. Boundaries use generated schemas and binary JSON keys. Native
shutdown acknowledgement precedes successful child exit; no cancellation is
inferred from local task death. Rebar/Mix registry resolution, Hex publication,
portable artifacts and BEAM allocation-failure injection are not qualified.
The public Station schedule also installs independent Station/native/example
applications and runs both language APIs through the shared authority schedule.
A common Erlang test controller drives adapters using the public Erlang records
and Elixir structs/behaviours; both real language counter CLIs run from installed
artifacts. It covers full-width codecs, all three mutation gates, retained
confirmation, callback throw/exit failures, scoped owner/reentry checks, sticky
read failures, caller kill/stop/join, exact seedless disk recovery, stale/revoked/
expired authority, retained Tables and six owned IPC segments after close.
Original segments are independently decoded with PyArrow; no BEAM Arrow adapter
is selected. Sources are removed after consumer compilation. The builder derives
application metadata from each `.app.src` or Mix manifest.

### Public SDK interoperability

`nix develop .#bindings -c just bindings::sdk-interop` builds all public artifacts,
installs clean external consumers and runs ten counter/query pairs. Every target
is both service and requester in this ring:

`Python → Node/TypeScript → Rust → Ruby → C → C++ → Java → .NET → Erlang → Elixir → Python`.

Each counter path uses the installed documented CLI and a direct authority base
URL with a trailing slash. Fault proxies also preserve the original HTTP request
target, so they cannot mask an incorrectly joined route. The requester exits after
recording its call, reacquires ownership and resumes through a recorded reply of
`18446744073709551615`. Table/query paths use the same public proof adapters around
installed example handlers, restart the requester, and expose original complete
IPC after closing both runners. Independent PyArrow checks three rows containing
null, `i64::MIN`, `i64::MAX` and `9007199254740993`, plus source/destination,
resource and byte-count metadata. The ring does not select optional host Arrow
adapters; those remain in the separate six-segment per-SDK schedules. It covers
ten edges, not all 100 ordered pairs, and does not repeat each fault for each pair.
`public-language-ring` in the [SDK catalog](verification/sdk.json) owns the exact
observations. M9's separate low-level matrix remains executable and passed again.

All artifacts below are version 0.2.0 on Linux x86_64 with their pinned Nix native
closure; the [runtime table](../bindings/README.md#build-and-verification) owns exact
compiler/runtime versions.

| Public target      | Installed artifact                                                        | Optional host Arrow adapter |
| ------------------ | ------------------------------------------------------------------------- | --------------------------- |
| Python             | Separate client/Station/native wheels and examples wheel                  | PyArrow 23                  |
| Node.js/TypeScript | Separate public/native npm tarballs and examples package                  | Arrow JavaScript 21.2       |
| Rust               | Versioned crates with separate embedded-native crates and examples        | Arrow Rust 59               |
| Ruby               | Separate client/Station/native gems and examples gem                      | None                        |
| C/C++              | Independent pkg-config prefixes, headers/libraries and C11/C++17 binaries | None                        |
| Java               | Independent client/Station/native/example JARs and POM manifests          | None                        |
| .NET               | Independent client/Station/native/example NuGet packages                  | None                        |
| Erlang/Elixir      | Separate compiled OTP core/wrapper/native/example applications            | None                        |

Public registry publication, Java Maven resolution, BEAM Hex/Rebar/Mix registry
resolution, portable native distributions and foreign Substrate workers are
not qualified. Package guides document current low-level escape hatches and
migration. These tests do not qualify arbitrary callback honesty or I/O isolation.

The [2026-09-26 local record](verification/results/m11-sdk-2026-09-26.json) measured
**3m58.7s** for clean consumer installation and the complete ring,
including 56.8s of installation/consumer compilation.
The authority ran on one CPU; provisioning used the same five-second deadline
as the authority and SDK defaults. The record includes per-pair timing, machine scope,
SDK source revision and proof-source hashes. It excludes artifact builds, other
SDK failure suites, setup and cache transfer, so it is not a full CI measurement.
The `bindings` lane now owns the per-SDK tasks and this public ring. M10's hosted
budgets remain unchanged; their old passing samples do not qualify M11's larger
inventory. New hosted cost measurement and runner optimization remain deferred.

### Local and clean verification

Enter `nix develop` and run `just transit-board::install` at the repository root. `just ci` runs the ordinary local
suite. Capacity and reference proofs have extra prerequisites and are separate.

`just check` includes Board contract/validator drift and frontend formatting,
lint, types and unit tests, even for changes made only to shared Zig types or
frontend Markdown. Regenerate deliberately with `just transit-board::generate`;
use `just fmt` to fix formatting.

Before pushing committed work, run `just ci-clean`. It refuses uncommitted source
changes, clones the exact HEAD into a temporary directory, installs the locked
frontend dependencies, and runs the same core/growth/experience/launchers/bindings
task inventory as hosted CI. It inherits the
Nix store and global compiler caches, but no checkout build outputs, launcher
state, dotenv file or `node_modules`. Successful runs remove the temporary clone;
timing/completion evidence survives under `.cache/ci/clean/`;
failed runs retain it for diagnosis and print its location. The local launcher proof must use its
selected artifacts; a binary left in the developer's `zig-out` cannot mask an
undeclared dependency. Compose explicitly builds a native caller for its
host-side stale-credential check. The browser proof remains a separate
`just transit-board::browser` step, as it is in hosted CI; neither command
qualifies the separate reference or physical-capacity profiles.

`just ci-clean --lane NAME` qualifies one inventory lane in its own fresh clone
with the pinned binding toolchain. Independent invocations may run concurrently
without sharing checkout outputs. A passing lane is partial evidence: the ordinary
clean gate requires completed metadata and every expected task for core, growth,
experience, launchers and bindings at the **same committed revision**. Retain all
five reports; do not combine different revisions or count an interrupted lane.
This changes neither hosted lane allocation nor the M10 feedback/cost budgets.

Use `just ci::complete` or `just ci-clean --complete` to include Chromium in the
same invocation after `just transit-board::browser-install`. `just test::unit`
only runs library/protocol tests; `just test::build` separately compiles the
application and probe entry points formerly hidden in that unit target. Core CI
runs both and retains standalone package checks.

| Evidence                                                                                                      | What it proves                                                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just check`, `just test::packages`                                                                           | Independent package composition; signed requests/current grants; one conditional successor; ordered input, invalid proposals and blocked failures; runtime fencing; bounded clocks, settlement, closure and outboxes; shared valid/invalid JSON traces and bounded view encoding                                           |
| `just test::callers`, `just contract::check`                                                                  | Runnable counter and byte-log examples use the same generic node; opaque bytes, state revisions, atomic outputs, denied effects, lost commit responses, ownership replacement and restart recovery; generated schema matches public types                                                                                  |
| `just test::storage`                                                                                          | Disk WAL SIGKILL/restart; competing authorities, lost receipts and revoked grants; 100 inputs beyond the 16-record window; checkpoint/trim with pending effect/outbox/control evidence; live authority catch-up; immutable payload deletion after a lost receipt; native long-poll/offset continuation                     |
| `just test::state`                                                                                            | Signed KV/association reads, current independent grants, immutable read views, exact retry, two Zig caller activations, disk recovery, and clock-independent opted-in background reclamation                                                                                                                               |
| `just test::service`                                                                                          | Real signed ingress/read revocation/key renewal, request deadlines and paused-worker fencing; Python/Zig wire vectors; actual-clock background expiry/trim; synthetic external I/O with paused dispatch, late results, unknown closure and no replay sends; background payload deletion preserving default-retention bytes |
| `just test::capacity`                                                                                         | Real ENOSPC on an owned ext4 image; release of preallocated control space; closed admissions, preserved/drained backlog, revocation/expiry/closure/checkpoint and restart; completed maintenance issues no further storage mutations                                                                                       |
| `just test::deployments`                                                                                      | Rendered/linted Transit Helm chart; explicit bootstrap, existing credential references, retained/reused PVCs, private services and network policies; unsupported values fail before deployment                                                                                                                             |
| `just launchers::reference::infra-up`, `just launchers::reference::images`, `just launchers::reference::test` | Real provider setup; controller crash after creation; backlog wakeup, killed worker and fresh activation; Ursula/authority pod restart; opted-in expiry; blocked overflow stops replacement; gVisor egress/credential bypass denials                                                                                       |
| `just test::runtime-upgrade`, `just launchers::reference::test-launcher`                                      | Fenced same-PID workload changes, provider response loss, complete persistent reference startup, isolated service updates and state-preserving stop/start                                                                                                                                                                  |

The capacity proof uses a finite allocation and a measured physical reserve;
online expansion and arbitrary write amplification are not promised. Retention
policies are immutable in M1. Checkpoint/trim requires quiescent or explicitly
cancelled mailboxes; pending effect/outbox metadata survives in the checkpoint.
Payload deletion is limited to closed standalone bytes with explicit opt-in and
an unlimited-lifetime owner. Unsupported finite body/dependency contracts fail
before admission. Full compaction, live dependency graphs and backup import
remain later work.

The trusted Linux time source reports synchronization/error bounds; acceptance
uses a validated sample at the compared journal tail, not physical append time.
An authorized external send may occur after closure; its result cannot reopen
Transit. Ursula cursors are cache tokens separate from read positions. The client
model is fixed and continuation verified; the server documentation mismatch is
tracked in [Ursula #317](https://github.com/tonbo-io/ursula/issues/317). This profile
uses verified record positions/offsets and never reuses physical names.
A rolled-back whole-store backup is not an authorized live restore.

Hosted CI runs `just ci::core`, `just ci::experience` and `just ci::bindings`
in parallel, then `just ci::browser` in the experience lane. Locally, `just ci`
loads the pinned bindings tools, runs all three sequentially and records timings
in `.cache/ci/`. The
[toolchain guide](../nix/README.md#ci-lanes) explains cache ownership and the
smaller experience shell. A weekly/on-demand dedicated runner workflow exposes the
reference and physical-capacity proofs. Local runs supply the current runtime
evidence. A passing hosted end-to-end timing and native validation on the other M0
platforms still require their own runners/runs.

Integration tests use Nix-provided Python, temporary directories, and loopback
ports with their own disk Ursula; they never use an existing deployment.
Toolchain smoke checks verify binary execution and first-use Vite+ setup, not
cluster conformance. See the [command reference](../tasks/README.md) for all tasks.

On Linux, `just test::service` limits the harness and its child processes to one
available CPU. This exercises deadline cancellation without spare async workers,
including slow ingress, stalled protocol responses and maintenance storage I/O.
The affinity change is confined to the test process tree; compilation and the
parent shell retain their existing CPU allocation.

The Station ABI portion of `just bindings::native` / `just bindings::test` also
runs on one CPU on Linux, restoring affinity before the remaining language
matrix. It exercises back-to-back exact raw-client retries and Station polling
with bounded native pools. Client unit tests inject unavailable concurrency at
either scheduling slot: transient contention recovers, persistent contention
hits the original deadline, and transport failure is never retried. Those
deterministic tests run in `just test::unit` and therefore `just check`.

The synthetic effect harness sets `NO_COLOR=1` for captured child logs so exact
error checks work under interactive and forced-color builds too. Its rejection
checks also verify the durable effect state, mailbox counts, and remote sends.

## Kubernetes tooling qualification

`just test::dev-environment` proves that the shell selects the checkout-local
reference config before creation and after removal, honors an explicit override
from a subdirectory, and leaves a personal config untouched.
`just test::kubectl-transit` runs the real Zig executable against a fake kubectl
boundary, without credentials or a cluster. It checks selectors, explicit context
and kubeconfig forwarding, native JSON, invalid flags, read failures, empty and
ambiguous resources, output bounds, a hanging child after both pipes close,
and SIGINT/SIGTERM cleanup for log following and Board forwarding.
The fake child publishes its readiness PID by atomic rename after installing
signal handlers, so the parent cannot mistake an empty file for readiness.
Discovery tests cover aligned columns across namespace lengths, exact
namespace/release selection, useful empty-selection diagnostics, and rejection
of control characters or oversized human-table fields without partial output.

The plugin's [runbook](../apps/kubectl-transit/README.md) and
[full plan](../docs/roadmap/M5.md) define its inspection-only scope.
Toolchain smoke checks verify Kind and both kubectl plugins offline.

`just launchers::reference::test-plugin` passed on Linux x86_64 against the
already-running owned Kind reference. It renders the real chart with overridden
names into a uniquely created namespace, uses an inert node Deployment plus a
CoreDNS HTTP health responder in place of Board, and verifies native discovery,
status/workload views, prefixed logs, configured origin, real port-forward traffic
and listener shutdown after interruption. The fixture proves Kubernetes wiring,
not Transit read authorization or execution. Cleanup verifies the namespace
UID before deleting only test resources. Existing reference workloads are not
restarted. Plain `kubectl get nodes` and packaged `kubectl ate get workers` also
succeeded through the environment's default reference kubeconfig.

`just check`, `just doctor`, the offline proofs and chart validation passed;
`nix flake check --all-systems --no-build` evaluated all configured systems. Native
macOS execution and complete reference recovery after these tooling changes
remain separate qualification; a successful inspection is not a recovery proof.

## Launcher qualification

Stable topology lives in root [process-compose.yaml](../process-compose.yaml),
[docker-compose.yaml](../docker-compose.yaml) and
[charts/transit](../charts/transit/README.md). Integration proofs consume these
files directly; generated private files contain only installation-specific
values, service configuration and provisioning material. The reference proof
installs/upgrades the chart, including its WorkerPool and optional Board and
maintenance resources. Provider setup and adversarial fault injection stay in
the harness.

`just launchers::local::test` and `just launchers::compose::test` exercise the
real launchers in uniquely named installations, with disk-backed Ursula and
the actual node, maintenance process, counter and Board. Both passed on Linux
x86_64. The native proof is part of `just ci`; Compose remains an explicit
Docker-dependent check. The proof checks:

- Direct Board access and the inspection-only upstream principal; private
  credential files and secret-free status/log output.
- Seed inputs admitted once, same-ID send retries returning the same receipt,
  conflicting retry rejection, and resumption after a lost operator receipt.
- Pending input surviving caller replacement, same PID with a fresh generation,
  and rejection of the old caller's actual credentials.
- Full stop/start with unchanged state, realm and keys; independent storage,
  node and Board restarts; no fresh bootstrap when established WAL is missing.
- Refusal to reset running resources, adopt an occupied port or running
  installation, or reactivate a permanently retired PID.
- Reconfigure an existing Board listener/public origin without resetting its
  realm or keys; probe through the correct Host header without public DNS.
  Remote HTTP requires explicit development opt-in; wrong Host/Origin still
  fails while direct reads succeed without a Board credential. Ursula/Transit keep loopback publication.
  Native Board must become ready in Process Compose and stay alive beyond the
  original 30-second probe-failure window.
- Local and Compose foreground startup stream service output and manager/container
  exits; a killed Board stays diagnosable across status calls. Other terminals can send and
  restart while `up` is attached. Ctrl-C, termination during startup, and failed
  recovery stop only the owned services and preserve the installation's data.
  Compose also checks detached startup and that a delayed foreground cleanup
  leaves a newer replacement stack running after another terminal's `down`/`up`.

Successful proofs stop/remove only their owned resources and delete their test
state. Failed proofs preserve private evidence for inspection after cleanup.
These tests establish development workflow behavior, not Substrate isolation,
clock accuracy, finite-capacity reserves, remote Docker support, or production
deployment safety. Compose uses ordinary bridges with loopback publication;
native code runs as the developer. See [launcher limits](../launchers/README.md).

Initial checks caught premature local readiness using a previous activation's
config, Docker internal networks suppressing host port publication, private build
output permissions preventing non-root execution, and a Board config mount
colliding with its executable path. Readiness now requires fresh worker config;
images place executable files under `/bin` with explicit executable permissions.

## Incremental development and workload upgrades

The local/Compose launcher proofs also build candidates without touching running
services, verify no-op updates and selected-version restart, interrupt an apply
and resume its saved target, replace Board alone, and update the counter without
replaying committed inputs. Foreground logs remain attached across replacement.
Native candidates use a different optimization build; image candidates add a
unique image label around the real executable. This proves deployment identity
and recovery mechanics, not compatibility of arbitrary edited application code.

Core tests exercise the public `runtime_upgrade` transition: scoped grants,
stale revisions/workloads, incompatible declared code/state revisions, retirement
and the work cutoff. Pending input/turn permits/effects survive the transition;
old owners and reused worker identities cannot activate or commit. Disk tests
checkpoint and trim with an unresolved upgrade, recover it, and reconcile
provider suspension after retirement without reviving execution. The optional
binding marker is omitted when absent to preserve existing checkpoint bytes.

`just test::runtime-upgrade` uses the real node/controller with a fake provider
CLI boundary. It rejects stale controllers and replacement Actor UIDs, then
simulates a completed template switch whose response is lost. A fresh controller
observes the target without switching it again. `--check` leaves protocol and
provider state unchanged. The Nix-packaged CLI extension separately tests
UID/template/suspension validation and version conflicts.

`just launchers::reference::test-launcher` uses a newly owned namespace on the
existing reference cluster. It provisions the complete stack, changes Board
without replacing the node/Ursula/maintenance/controller pods, removes an old
Board viewer-key Secret field while preserving its Transit seed, verifies direct
inspection without a viewer credential, admits input while
the Actor is suspended, and deploys a different counter image through the real
guarded Substrate API. PID and Actor UID remain stable; worker UID and activation
generation change. The queued input commits once. Authority restart and full
application stop/start preserve state, followed by owned-resource cleanup.

Qualification found that private build contexts could give the controller's Nix
store directory mode `0700`. Image assembly now sets directory/file permissions
explicitly, and controller readiness exercises the packaged provider CLI instead
of assuming a running container is functional. Reference cleanup verifies saved
template identities before deletion; Substrate refuses to delete a nonempty
atespace. Application `down` also waits for the prior worker to disappear before
another start may request a fresh activation.

The real reference upgrade and cleanup proof passed on 2026-09-24, alongside the
local suite, Compose launcher proof and focused protocol/provider/chart proofs
on Linux x86_64. These checks do not rerun or replace the separate
M1 capacity and adversarial isolation qualification. The persistent reference
launcher uses the default Kind CNI and does not claim the additional Board
firewall confinement supplied by that isolated proof.

## Service and reference evidence

`just test::service` exercises actual signed HTTP ingress, PID-scoped reads,
key rotation/revocation, slow-body deadlines, and paused/replacement workers
against disk-backed Ursula. Authority and storage restart preserve state and
revocations. This loopback proof does not establish deployment network isolation;
see the [service profile](../contracts/SERVICE_V1.md).

`just launchers::reference::test` runs the fixed counter via the pinned Substrate gVisor
runtime on an owned Kind cluster. A controller crash after Actor creation is
reconciled without a duplicate resource; killing the real worker preserves the
PID/Actor and rotates worker identity and ownership. Ursula and authority pod
restarts preserve state, and separate maintenance expires an opted-in process.
The sandbox probe first reaches Transit, then verifies denied raw Ursula
read/write/admin access, direct IP access, CONNECT tunnelling, and Substrate and
Kubernetes APIs. Host spoofing reaches only Transit's fixed NotFound handler.
Known credential/control mounts are absent or inaccessible. These claims cover
the configured fixed images, private trusted cluster network and pinned runtime;
they do not establish arbitrary native-handler determinism or protection against
privileged administrators. Public ingress TLS and broader runtime support remain
outside this reference slice.

## Failed application turns

Caller-reported counter overflow records a blocked head input and fences its
owner. Unit tests reject failure reports that change state or emit outputs;
signed-service tests preserve pending input across restart and permit explicit
termination. The counter worker also reports malformed application bytes as a
blocked failure. Transit does not verify the caller's arithmetic or failure claim.
Runtime reconciliation uses that durable failure to stop replacement; its cluster test also checks a
stable generation after shutdown. This bounds retries of the fixed reviewed
handler; arbitrary plugin execution and general Station restart policies remain
outside this profile.

## Capacity and deletion evidence

The [bounded capacity profile](../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity) has a
real ext4/ENOSPC proof in `just test::capacity`. Closed admissions survive restart;
accepted input is preserved, and releasing only a preallocated reserve enables
revocation, opted-in expiry, unknown closure, backlog completion and checkpoint/
trim. The recorded bounds and measured amplification apply to the specified
single-node fixture, not arbitrary disk writers, topologies or unlimited faults.

Immutable standalone payload tests add whole-stream deletion through the pinned
client. Owner/PID and current grants fence retirement; publication, explicit
deletion opt-in and permanent owner retirement are prerequisites. Disk restart
after DELETE but before outcome recording recovers from a tombstone in the
separate control checkpoint. Background service maintenance completes deletion
while preserving default-retention bytes. Late publication cannot reopen a
retired payload. This profile rejects finite owners and live dependencies;
unresolved creation cannot be mistaken for safe deletion or retried blindly.

## Authority, effects, and outbox evidence

Implemented evidence: `just test::unit` exercises request signatures, realm/PID grants,
key replacement, retry identity, ownership, stale state revisions, ordered input, and
retirement. `just test::storage` repeats competing transitions, revocation, lost
receipts, and replay across a real Ursula SIGKILL/restart, with a 100-message
backlog and a 16-record read window. Application logic is absent from the
authority and its replay path.
Further SIGKILL boundaries exercise checkpoint publication before trim, retried
trim, and recovery after prefix removal with new pending input in the tail.
Effect tests additionally prove intent validation, revocation racing dispatch,
authenticated observations, and one mailbox admission per result. Disk restart
and prefix removal preserve unknown attempts; late evidence after caller
termination cannot revive application execution. No external I/O is invoked.
The separate service proof now adds actual I/O through a trusted Zig synthetic
executor: successful result admission, pause after authorization, late response,
and executor death after remote acceptance. A fixture records exactly four
requests across these schedules; fresh executors and checkpoint/trim/restart
cause no additional sends. Closed attempts reject late outcomes, including when
the authorized executor starts its request after closure. This demonstrates the
external limit, not remote cancellation or a general HTTP connector.
Closure tests exercise both winners of the result/closure race, lost
acknowledgements, and unauthorized closure. Real disk restart and trim preserve
closed unknown outcomes and reject late observations even while the caller lives.
Outbox tests cover ordered routes, partial fan-out, denied/expired destinations,
revocation racing delivery, and cancellation of undelivered outputs. Disk restart
and prefix removal preserve pending payloads; a lost delivery receipt cannot
admit the same output twice. Replay verifies explicit admission metadata so
denied deliveries cannot masquerade as mailbox messages.
These are local single-node results, not the Kubernetes/Substrate isolation proof.

## Time and maintenance evidence

The time interface and finite-policy transitions now have executable proofs:
missing/uncertain time, rollback, delayed maintenance, permit recovery, deadline
closure, and observation-budget exhaustion. A disk-backed fixture settles a
preauthorized turn after its work cutoff, then expires its PID and trims history;
restart preserves both retirement and the time high-water mark. Time is controlled
in this fixture. `just test::service` additionally exercises Linux's synchronized
clock and a separate maintenance process: opted-in expiry, explicit cancellation
of unfinished input, checkpoint/trim while ingress remains live, and permanent
retirement after authority/storage restart. It requires the host clock to report
an error bound within two seconds; the fixture explicitly permits that bound
because a synchronized host can exceed one second between NTP polls. Controlled
clock tests retain exact rejection boundaries. Other platforms exercise explicit
retirement and cleanup without claiming a supported finite-time source.
The [deadline investigation](../packages/zig/transit-core/docs/authority.md#deadline-enforcement)
defines the tested acceptance-time and closure contract. A physical
storage-write cutoff at the earlier work deadline is no longer the target.

## Extending the proof

The M1 mechanisms above now have concrete implementations and adversarial
results. Extending them to general behaviors, connectors or another storage/
runtime profile requires preserving these contracts and adding its own evidence.
A failed proof requires revising the owning design, not relabeling a weaker
implementation as conformant. The client cursor-model bug and separate upstream
documentation mismatch are recorded in the [backend README](../packages/zig/transit-backend-ursula/docs/upstream.md#client-integration-surface). The corrected
client proof verifies offset-plus-cursor and record-plus-cursor continuation;
Transit's journal reads use record positions.

## Independent caller evidence

`just test::callers` launches the actual `example-counter` and `example-byte-log`
binaries, each importing only `transit-client`. Application-independent Zig
probes perform rejected proposals and state assertions; Python injects faults.
The counter is shared with the service and reference proofs. No test driver
executes a separate copy of application logic.
The same node binary accepts both, records opaque state and atomic outputs,
rejects stale revisions/skipped inputs/unauthorized effects, and recovers through
authority and disk Ursula restart. A proxy drops successful commit responses and
injects malformed unavailable responses on reads and commit retries;
retrying the identical pending request returns the original receipt. Replaced
activations fail locally and at signed ingress. Recovery verification does not
execute either application. `just contract::check` checks that the committed
binding schema exactly matches the public types; shared fixtures check signing.

## Physical capacity profile

The capacity proof requires Linux Docker with privileged-container support and
at least 2 GiB of free disk for its temporary regular image file. It uses pinned
Nix filesystem tools and the official Ursula image; it formats no host block
device. Its mount/loop device belongs to the owned container, which is removed
after the proof. It runs in the opt-in reference CI workflow, not hosted `just ci`.

`just test::capacity` proves the `N=256` profile against the pinned official
Ursula image on an owned 2 GiB ext4 filesystem, with a physically allocated
1 GiB reserve file. It fills only that filesystem, observes real `ENOSPC` and
Ursula's disk-pressure write rejection, and releases only the reserve. The filler
stays in place while Transit revokes a grant, expires an opted-in PID, closes an
unknown attempt, drains the unlimited PID's accepted backlog, and checkpoints
and trims. SIGKILL/restart preserves retirement, closure, and closed admissions.

The fixture uses 251 post-ceiling records. The v2 run grew WAL allocation by
176,128 bytes during control recovery; current measurements are emitted by the
recipe. The conservative bound
was 3,905 records (31,989,760 bytes plus a checkpoint) in M1;
the [M8 proof](#m8-runtime-readiness) records the current expanded bound. The 1 GiB physical reserve is
a tested envelope for this configuration/schedule, not a universal filesystem
or Ursula write-amplification guarantee. The fixture asserts control growth
stays below 128 MiB and free space remains above the 32 MiB resume threshold.
Keep one maintenance writer and bounded authority concurrency; unbounded crash
loops, unrelated disk writers, disk loss, other topologies and larger allocations
need separate qualification. An absent/exhausted reserve fails closed and needs
operator capacity recovery; it does not create expiry permission.

Completed maintenance now verifies the existing checkpoint/floor before writing.
After restart the adapter uses only GET/HEAD for that already completed intent;
it does not repeatedly publish or trim. Ursula can still change its internal WAL
during reads/recovery, so raw WAL equality is not a valid no-mutation assertion.
The fixture records adapter HTTP methods and stores measurements in the ignored
`.cache/capacity-evidence.json`.

The [core capacity contract](../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity)
defines the admission ceiling, permitted drain work, and accepted-record bound.

## Recording new evidence

Record tested pins, topology, failure boundary, authoritative operation point,
input schedule, and durable outcomes. A workflow definition is not evidence of
a remote run. The [reference runbook](../deploy/reference/README.md) records its
runner requirements and owned-resource cleanup. Keep synthetic endpoints, test
keys, transcripts, and private proof files out of Git.

Benchmarks record compiler/tool versions, hardware, dataset, concurrency,
durability settings, and p50/p95/p99 latency together with throughput and memory.
A failed proof requires revising the owning design, not weakening its label.

## Public inspection

`just test::inspection` checks scoped discovery, signed queries, fixed pages, cut
expiry, revocation, and disk recovery through the node and public client. Core
unit tests inject final-tail and trim races, test bounded sparse scans, and verify
that scoped outbox/history projections do not disclose hidden endpoints.

## Board qualification

`just transit-board::check` checks exact Zig/OpenAPI regeneration, generated TypeScript and
standalone validator drift, strict TypeScript, Vite+ formatting/lint and unit tests.
`just transit-board::test` runs Zig ingress tests and `tests/board.py` against disk-backed
Ursula. A copy of the Board binary runs alone in an empty directory with an empty
executable search path, serving embedded assets and the exact OpenAPI artifact.
An independent Python consumer follows process/output/effect evidence; generated
JS validators consume actual Zig responses and reject malformed identities/data.

The API proof checks current grants, scoped lists and edges, unsafe deployment
principals, missing API/asset routes, Host/Origin/forwarded-header rejection,
direct reads without viewer credentials, no cookies or session/mutation/proxy routes,
closed-unknown effects, blocked inputs, history cut/trim gaps and storage restart.
Core tests deterministically inject revocation/tail and physical-trim races.
Board projection tests reject mixed-resource pages before they could overflow
the 32-edge budget. Revoked Transit grants reject reads even with old Board
cookies or arbitrary bearer headers; these headers stay out of diagnostics.
The initial local load run (Linux x86_64, pinned tools) completed five control
writes during 25 refresh requests; the maximum observed latency was 43 ms.
Requests exceeding Board's 10 upstream reads/second admission rate were rejected.
A slow incomplete Board request also left the authority available. This is a
bounded reference measurement, not a throughput/fairness or latency guarantee.

`just transit-board::browser-install` and `just transit-board::browser` run pinned Chromium against
that same real binary/API. Checks cover direct access, typed runtime validation, nested
routes/lazy assets, arrivals/departures and uncertainty, keyboard focus through
polling, escaped opaque payloads and authorized state-resource views, denial clearing and connection retry,
and absence of Board cookies or browser storage. Axe checks the journey against WCAG A/AA;
this does not replace a full assistive-technology audit. Local screenshots/traces
remain ignored under `.cache/`. Remote TLS termination and identity federation
are outside this private/loopback profile.

The Kubernetes/Substrate run on 2026-09-23 passed using the pinned images/tools.
Board observed PID 1 at generation 2, then the same PID at generation 4 with a
new worker incarnation. After disk Ursula and node replacement it still exposed
state `1153`; it also exposed permanently expired PID 48. Retained history began
at position 52 after checkpoint/physical trim; inspection reported
`prefix_reclaimed`, and later PID 1 termination remained visible. This preserved
the existing M1 controller-crash, worker-recovery, expiry and gVisor isolation
proof. Local evidence is in ignored `.cache/reference/proof-d585cab0/evidence.json`;
its enclosing directory contains private disposable keys and must not be published.

Board ran as a non-root, read-only-filesystem pod without a service-account token,
using only a dedicated inspect grant. A second unprivileged container in that
pod's network namespace first reached Transit, then received transport denials
for raw Ursula service/pod/admin endpoints and actual Substrate/Kubernetes API
addresses. The default Kind CNI does not enforce NetworkPolicy: the owned proof
uses an init-container firewall, permitting Transit, DNS and loopback Board
port-forwarding. Production clusters need equivalent enforced egress policy;
the fixture is not a portable NetworkPolicy conformance claim. The cluster and
registry were removed through the ownership-checking teardown command.

Qualification caught and corrected three assumptions: HTTP header views cannot
be accessed after Zig's body reader changes state; Kubernetes port-forwarding
needs a loopback exception inside the confined pod; and Substrate's headless API
service must resolve to a ready EndpointSlice address for a valid denial probe.
The probe rejects DNS errors/timeouts as evidence of egress denial, so an invalid
target cannot produce a passing isolation result.

## Service instrumentation qualification

`just test::telemetry` tests the real bounded stderr writer on one CPU (Linux):
10,000 completions with logging disabled, drained, stalled and closed pipes.
Every completion reaches local metrics despite log drops; stdout remains JSON.
The initial debug build measured 0.12–0.42 seconds total per scenario, including
100 ms of deliberate wait and up to 200 ms flushing; emission was 9–74 ms.
These are measured proof results, not throughput targets or arbitrary I/O guarantees.

`just transit-board::test` also asserts fixed routes, request/timeout outcomes, ignored
public trace headers, quiet successful probes and credential/query redaction in
real service logs. See [telemetry](../packages/zig/telemetry/README.md) for limits.

`just test::observability` follows a real Board request through the public client
and node, checking distinct correlated spans, existing receipt retries, revoked
reads, duplicate/untrusted trace headers and absence of credentials/state.
No raw storage dependency is introduced into Board and no durable schema changes.

Storage/recovery spans are checked as children of the actual authority request.
The existing disk, service, maintenance and caller proofs run with instrumentation
active. Maintenance deadline checks inspect the structured error field. The
bootstrap proof separates stdout and stderr to verify the machine interface,
while the provider reader continues to identify bootstrap records in combined logs.
The stalled-writer proof shrinks its Linux pipe to 4 KiB and asserts the writer
is actually blocked before shutdown; it cannot pass merely by fitting all logs
into the OS buffer.

The observability proof also runs the real node on one CPU with unread stderr:
after filling its 4 KiB pipe, an incomplete HTTP request still hits the 800 ms
deadline, and a signed input plus exact retry still returns one durable receipt.
This qualifies control progress under diagnostic pressure, not just logger exit.
Replay and retries are observed as recovery or receipts; no metric claims they
are fresh commits. No protocol, signature, or durable-history schema changed.
The caller proxy proof drops a response after a real commit, then injects a
malformed 503. Both attempts remain `uncertain`; only the exact successful retry
reports `receipt`. Each attempt has a distinct span linked to the same proposal.
A focused invariant test preserves a known receipt when the response write fails
and checks that a new service instance resets its local counters.

`just launchers::local::test` and `just launchers::compose::test` passed with JSON
request records and saved per-service settings across restart. The native proof
checks visible foreground Board logs, manager-log rotation through three cycles,
two bounded backups and configured child-log rotation. Compose checks each
service's environment and Docker log budget. Native copy/truncate can lose
diagnostics and overshoot between checks; it is not a filesystem quota.

The Kubernetes/Substrate observability run passed the existing controller-crash,
worker replacement, disk Ursula/authority recovery, expiry and isolation proof.
It also checked JSON events from Board, Transit, maintenance and the controller,
and the effective kubelet rotation settings (5 MiB, three files). Evidence is
in ignored `.cache/reference/proof-7f71fb4c/evidence.json`; its enclosing directory
contains private test keys. Provider-owned log/snapshot stores and host proof
files are outside the CRI log budget.

Qualification exposed a packaging assumption: a Zig artifact reused from a
private launcher cache can have mode `0700`. Reference image assembly now sets
published executable modes explicitly to `0755`, so the non-root container user
can execute them. The controller-crash fixture now waits for the structured
`created` progress observation; continuous controller stdout is no longer used
as a diagnostic interface. `--once` retains its single machine-readable result.

## M7 state resources

The bounded [state v1 profile](../contracts/STATE_V1.md) is qualified through
`just ci`, `just transit-board::browser`, `just launchers::compose::test` and
`just launchers::reference::test-launcher` on x86_64 Linux (2026-09-24).
`just test::capacity` also passes with the expanded 3,917-record control reserve: real
ENOSPC, control progress, checkpoint/trim and disk restart. Focused
state, unit and disk proofs were rerun after final authorization/recovery fixes.

Coverage includes:

- Core adversarial tests: atomic mutations/input/outputs/effects; uncertain
  receipts and competing revisions; stale ownership; association CAS; writer
  exclusivity and shared snapshot reads; hidden metadata/value permissions;
  revocation before commits, reads and receipt disclosure; required/optional
  expiry; full read-view capacity and reserved retirement/reclamation progress.
- [state.zig](state.zig), included in `just test::storage`: real disk Ursula,
  competing conditional appends, abandoned private preparations, lost receipts,
  SIGKILL/restart, durable view recovery, checkpoint publication/trim, and 32 live
  keys beyond the eight-entry page and 16-record replay buffer. It preserves
  unchanged values, deletes/recreates a key, permanently retires required
  dependents and reclaims opted-in data. Receipt permissions survive checkpoint
  recovery even after their view-opening records are trimmed.
- [state_api.py](state_api.py), `just test::state`: the real HTTP/CLI boundary and
  counter executable; metadata/value grants, exact view revisions, pagination,
  changed cuts, state retention across two activations and unchanged legacy
  inline bytes. A clockless realm proves zero-age opted-in background cleanup
  and maintainer restart without rediscovering or resurrecting removed data.
- Board service/browser proofs: no application lens/configuration/API field;
  generic resource and association pages, explicit hex entry reads, independent
  disclosure permissions and filtered relationships. Existing effect, journey,
  stale-observation, safe-rendering and accessibility checks continue to pass.
- Local, Compose and reference launcher proofs: new installations provision a
  required KV resource; worker replacement, compatible same-PID upgrades, queued
  inputs, authority/storage recovery and stop/start preserve its data. Existing
  manifests retain inline-state behavior; this is not an automatic migration.

On the pinned x86_64 Linux Debug profile, fixed structure sizes are 158,560 bytes
for the complete catalog (four resources, four captured views and receipt rights),
364,848 bytes for core state, 17,224 bytes for one captured view, 7,800 bytes for
one public state page and 67,688 bytes for the Ursula replay store. These are
layout measurements, not total RSS or throughput claims. Parsing, candidate
copies and serialized I/O need additional bounded memory. Maximum record and
checkpoint tests retain the 8 KiB / 1 MiB limits.

The first larger catalog exhausted Debug stack frames in checkpoint verification.
The selected profile remains four resource identities / 32 live keys each;
large checkpoint fields now parse into allocated storage and the backend returns
an owned parsed checkpoint. The service and storage recovery proofs exercise
that path with default stack sizes. No stack-limit override hides the failure.
Simultaneous launcher builds also exposed shared frontend-output deletion;
embedded Board builds now use separate temporary output directories.

M7 does not prove an unbounded KV index, per-key TTL, writer transfer, multiple
resources in one transaction, online migration, arbitrary native determinism,
or global distributed transactions. History trimming still requires quiescent
or explicitly cancelled mailboxes and every resource's opt-in/minimum age.
Resource identity/tombstone evidence is retained permanently within the bounded
realm profile. Expiry can make data unavailable while unlimited history keeps
its bytes; it never promises erasure of external copies.

## M8 runtime readiness

M8 supplies the generic runtime prerequisites for Station. Qualification passed
on x86_64 Linux on 2026-09-24 with the pinned toolchain, including the full CI,
browser, physical-capacity, three-launcher and Substrate isolation suites. Focused
controller/caller checks and foundation checks were rerun after the recovery fixes.
Its contracts are
[authenticated inputs](../contracts/TRANSIT_V1.md),
[scoped delivery](../contracts/SERVICE_V1.md),
[catalog collection](../contracts/CATALOG_V1.md) and
[lifecycle controls](../contracts/LIFECYCLE_V1.md).

| Proof                                                                           | Evidence and command                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Authenticated origin                                                            | Core checks authority-derived external/process/effect envelopes, replay mutation rejection and retained origin after collection. Shared `inputs-v1.json` and canonical signed command fixtures are validated by `just check`.                                                                                                                                                                                            |
| Actual caller exchange                                                          | `just test::callers` runs the counter and byte-log executables with `transit-delivery`, drops/malforms acknowledgements, checks exact retries and restarts the courier. Scoped delivery reads expose counts/sequence, not application payload. Core tests cover destination scope, revocation and terminal denial. Delayed counter activation stays within the bootstrap log bound even at debug verbosity.              |
| Sustained working catalogs                                                      | Unit and disk proofs allocate 257 outputs/effects and 65 process/resource identities while collecting eligible entries, exceeding the previous lifetime ceilings. Pending outputs, uncertain attempts, live dependencies and default unlimited retention remain protected; old IDs/results/owners cannot revive.                                                                                                         |
| Lifecycle recovery                                                              | Core tests cover lost creation/resource acknowledgements, missing required associations, scoped administration, exact failed-input retry, stale generations, suspension bounds and provider-stop/activation fencing. `tests/readiness.zig` restarts during initialization, completes it after recovery, checkpoints a blocked input, retries that head and expires a suspended process after trim/recovery.              |
| Disk/capacity                                                                   | `just test::storage` runs readiness with disk Ursula, SIGKILL, checkpoint and prefix trim. `just test::capacity` fills an owned ext4 image: at admission ceiling 256, the reserve bound is **4385 records**, with control progress and restart verified. This replaces the pre-M8 reserve estimate for the current binary.                                                                                               |
| Deployment                                                                      | `tests/readiness_client.zig` imports the public client only. Local, Compose and reference launcher tests run it against real services: queue an output while delivery is stopped, restart courier and node, reject an identical externally submitted forged reply, accept the process-origin reply and inspect generic Board evidence. The harness never delivers that output. Reference qualification also queues input |
| during a bounded logical suspension, confirms provider stop, replaces worker    |
| capacity and resumes the same PID/Actor with a fresh activation. Automatic pool |
| recycling is outside the controller's current rights and this proof.            |
| Inspection                                                                      | Core history queries preserve retained events for collected PIDs without inventing mailbox disposition. Board exposes lifecycle actions, initialization/suspension bounds and a collection warning. Generated OpenAPI/validators, API tests and the real browser suite check the shared surface.                                                                                                                         |

Run `just ci`, `just transit-board::browser`, `just test::capacity`,
`just launchers::compose::test` and `just launchers::reference::test-launcher`.
The existing `just launchers::reference::images` / `just launchers::reference::test`
proof additionally checks controller/worker loss, persistent authority/storage
restart, expiry, poison-input shutdown and actual sandbox/Board bypass rejection.
Its diagnostic check covers every remaining signing seed after removal of Board
viewer keys. Pod readiness is distinct from host-forward availability; the Zig
readiness caller retries unavailable reads without treating them as progress.
Launcher qualification uses separately owned installations and retains failure
evidence; it must not upgrade a developer's existing live realm implicitly.

The measured disk-proof structures on x86_64 Linux are: state catalog 158560 bytes,
core state 433472 bytes, captured view 17224 bytes, state page 7800 bytes and backend
store 68968 bytes. These are type sizes, not total process RSS. Catalog capacities
remain 64 concurrent processes, 128 effects, 256 outputs, four resources, four
views and 16 principals. Collection is opt-in; unlimited default history can grow
on disk. Automatic collection conservatively waits for delivered inputs to be
consumed; explicit collection can prove a retained self-contained origin earlier.
Whole-realm checkpoints require quiescence. No production throughput, recovery-time,
HA, distributed retention or principal reclamation claim follows from these proofs.
Station owns durable wait/correlation layouts, child policies, timers,
lifecycle watches, restart budgets and versioned framework descriptors.

## M9 Station, bindings and Tables

The final implementation at `1462041` passed `just ci-clean` with no inherited
checkout build outputs. All target languages passed in that run. Embedded Board
passed its five Chromium checks; the Station local, Compose and Substrate
profiles passed their separate recovery/upgrade proofs. `just doctor` and
Actionlint also passed. This records local qualification, not a hosted CI speed
measurement or validation of other operating systems/architectures.

The Linux x86_64 profile uses the locked Zig 0.17 compiler, the pinned
`rupurt/zarrow` and `rupurt/zarrow-compute` forks, disk Ursula, and the real public
authority/courier. Framework logic remains in Zig; no language-specific server
route or second authoritative task/state store is introduced.

| Proof                                                                                                                     | Evidence                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just test::station`                                                                                                      | Three behavior roles, two-Table atomic turns, exact retry after receipt loss, worker/store restart, source-authenticated calls/replies, captured Arrow publication/consumer restart, service-policy revocation, registry rebind with the original PID retained, timed waits/late-result closure, poison-head supervision and independent lifecycle control |
| `just test::station` lifetime schedule                                                                                    | Required PID-owned Table state survives recovery; suspension beyond a dependency is rejected; opted-in expiry permanently rejects activation and permits background reclamation, including after authority restart                                                                                                                                         |
| `just bindings::native`                                                                                                   | C/C++/Python real callers; shared ABI exact frozen request recovery after every handle is lost; failed-turn rollback, stale/revoked/retired callers, wide correlations, malformed native-port input, asynchronous cancellation and owned cleanup                                                                                                           |
| `just bindings::native` materialization schedule                                                                          | Duplicate source admission/commit, update/delete, physical checkpoint/trim, reinsertion in the tail, disk/node restart and an independent Arrow aggregate over only current rows                                                                                                                                                                           |
| `nix develop .#bindings --command just bindings::test`                                                                    | C, C++, Rust, Python, Node, Java, .NET, Erlang and Elixir each run service and requester roles across language pairs; fresh hosts resume captured results; exact `9007199254740993` values survive Arrow; managed/port tests cover bounded input, busy handles, host/caller loss, responsive schedulers and cancellation/cleanup                           |
| `just test::unit`, `just test::packages`, `just test::arrow`                                                              | Private batch rollback, capacity and schema checks, all admitted Arrow types/null/empty/overflow behavior, C Data/C Stream release ownership, exact source basis and no enabled rewrites, cancelled queries, maximum 672-byte captured reply, malformed/duplicate/missing fragments and no prefix completion                                               |
| `just transit-board::test`, `just transit-board::browser`                                                                 | Versioned framework metadata with source PID/resource/key/revisions; unknown versions fall back safely; no application-state decoder                                                                                                                                                                                                                       |
| `just launchers::local::test-station`, `just launchers::compose::test-station`, `just launchers::reference::test-station` | Same three-process scenario, scoped service roles, registry/call/Arrow exchange, Board provenance, worker recovery, compatible upgrades of all three workers with PIDs/state retained, no-op updates and persistent stop/start                                                                                                                             |

The reference proof additionally kills an actual Substrate worker pod, verifies
a fresh activation/key while retaining the Actor UID, and upgrades versioned
worker templates through the recorded protocol. It uses the shared Helm chart
with three separate PID-scoped runtime controllers and two framework controllers.
Failed launcher runs retain their own installation; successful ones remove only
their own application resources. The shared infrastructure is not destroyed.

The ordinary CI inventory includes the local Station proof and full language
matrix. Docker Compose and reference proofs require Docker/the provider fixture
and run in the opt-in reference workflow or as explicit qualification commands.
No hosted run-time improvement is
claimed from local measurements; the CI lanes report their individual task times.

Qualification is deliberately finite: four realm resources, 32 entries per
resource, four mutations/outputs per turn, one mutated resource and at most
672 captured IPC bytes. Execution pulls one synchronous batch into bounded
buffers; it has no queued pipeline or parallel in-flight operators. Slow remote
consumption is durable mailbox/result state, not a live Arrow task. No optimizer
rewrite is enabled. Unlimited retention is the default and does not evict old
waits/results when capacity fills. See the [Table guide](../packages/zig/transit-station/docs/tables.md).

Only Zig workers are qualified on Substrate. Client support does not establish
foreign-VM isolation, public SDK releases or non-Linux portability. Logical
supervisor retry also cannot guarantee fresh provider placement; the
[example runbook](../examples/station-ledger/docs/running.md#recovery-and-incremental-work)
records the required operator recovery when Substrate reuses an old pod.
Continuous queries, multi-resource transactions, SQL, Documents and remote
Flight/ADBC remain later milestones.

## M10 verification and scale foundations

The [2026-09-25 growth evidence](verification/results/m10-scale-2026-09-25.json)
records **14 passing samples**: two each at 64/256/1,024 rows with one resident
page, 256 rows with 16 pages, eight retained views, and two public-service offered
loads. All use real Ursula WAL plus pinned MinIO on the checkout's ext4 filesystem,
on a shared Linux x86_64 Threadripper 3960X host (48 logical CPUs, about 121 GiB
RAM), Zig `0.17.0-dev.2267+48abf1a34` and Ursula 0.5.1. Each sample records actual
binary hashes, revision/dirty state and timing boundaries. Six cases ran through
`just test::scale`; the added eight-view case ran twice separately before joining
the executable matrix. These are shared-host observations, not production SLOs.

| Rows / cache pages / retained views | Write plus verification, seconds | Turn p99, ms | Full recovery verification, seconds | Maximum authority-driver RSS, KiB |
| ----------------------------------- | -------------------------------: | -----------: | ----------------------------------: | --------------------------------: |
| 64 / 1 / 1                          |                      54.86–57.31 |      952–978 |                           4.21–4.58 |                            12,596 |
| 256 / 1 / 1                         |                    109.01–113.49 |    984–1,013 |                         14.33–15.19 |                            12,596 |
| 1,024 / 1 / 1                       |                    366.91–366.94 |  1,166–1,315 |                         61.64–62.37 |                            12,660 |
| 256 / 16 / 1                        |                      85.31–86.17 |      825–839 |                         11.77–12.05 |                            12,720 |
| 256 / 16 / 8                        |                      91.08–92.72 |    780–1,792 |                         15.66–15.89 |                            12,744 |

The one-page cache remains **8,532 bytes** while retained application values grow
from 16 to 256 KiB, alongside 70 PIDs, 21 principals, six resources and 69
associations. The eight-view driver also checks every retained association after
restart; its timing difference is not solely view-count cost. At 1,024 rows,
engine opening took 1.04–1.06s on first recovery; checkpoint publication took
107–109ms, separately from full verification. Recovery/trim created zero pages.
Ursula peaked around 95 MiB and MinIO around 327 MiB. Write/setup/verification
made 289,558 page requests and attempted 45.09 MB of immutable page payloads,
retaining about 47 MB in cold files. These costs expose substantial index/history
and request amplification despite the fixed authority cache.

Each offered-load run scheduled 48 independent signed requests, then verified
exact retries, control revocation, every drained row and restart digests. With
16-byte uniform updates, one generator worker and 100ms offer intervals, p99 was
3.28–3.42s and control latency 208–238ms. With 256-byte updates, 90% hot-key
selection, four workers and 1ms intervals, p99 was 9.11–9.73s and control latency
805–880ms. All requests were admitted; accepted backlog survived provider/node
loss. Generator queueing is included in latency and was substantial; these
finite bursts do not establish service capacity. Both load cases and all
four authority phases retain process/provider metrics and correctness evidence.
A preceding setup attempt timed out during severe host I/O contention and remains
inconclusive; it is not included in the passing sample count. Two repeats do not
establish stable performance-regression tolerances or cold-run tail guarantees.

`just test::arrow` also qualifies Fuze's incremental engine independently of
Station persistence. Python checks the typed plan fingerprint and 143-byte
progress format; PyArrow decodes variable-sized segments across 70 rows. The
text result totals 16,008 bytes in seven complete IPC segments. Global limits,
count/sum, nulls and exact integers agree across boundaries. Package/root unit
tests additionally reject changed basis/plan/order, signed intermediate overflow,
insufficient workspace/output and cancellation without publishing progress.
This does not qualify durable large-result staging, delivery or recovery; those
remain integration gates in the [incremental contract](https://github.com/rupurt/rey/blob/c5ac253365ba7dfa136cc4dadf99ba0c21570af1/contracts/FUZE_STREAM_V1.md).

`just test::query` (also part of `test::growing-service`) separately
qualifies durable **capture**. Real Zig callers retain a 41-row Table, stage
221-byte fragments, and recover through disk Ursula/node/caller replacement
first during staging, then after the first seal. The first recovery uses one
resident backend page; the remaining capture defaults to 64. Use
`just test::query --finish-pages 1` to retain one page throughout both
recoveries. The proxy loses an accepted staging reply and a seal reply; exact
retry returns the original receipt without rerunning a handler. Each recovered
segment is decoded by independent PyArrow, and Python checks the ordered digest
chain: 41 rows, 9,984 bytes in six segments. The source is released with the final
seal and rejects later reads. The requester's wait is still waiting: capture is
not delivery or acknowledgement. In-memory tests add 70-row private capture,
changed staging, duplicate/future/forged continuation, policy revocation, sticky
read failure, explicit closure and corrupt/missing fragments.

Growing result **delivery** now has both in-memory and real disk/service
qualification. `query_growing_test.zig` drives two independent in-memory
`Store` fixtures as separate producer and receiver peers exchanging real
`QueryDelivery.dispatch` frames through an explicit message queue, matching
the wire protocol rather than calling capture and delivery in the same
process. One run publishes and independently decodes 41 rows across six
segments end to end, closing exactly once before acknowledgement despite a
duplicated fragment redelivery, a forged reply source, and a closed wait
staying closed against a late corrupted resend. A second, focused test rejects
out-of-order/conflicting/premature evidence (`UnorderedResultFragment`,
`ConflictingResultFragment`, `ConflictingResultIdentity`, `IncompleteResult`,
`InvalidArrowResult`) without ever closing the receiver's wait, and checks
cancellation mid-dispatch. `Inspect.segment`
(`packages/zig/transit-fuze/src/Inspect.zig`) independently validates every
received Arrow segment — bounded allocation, schema/row/cell bounds, UTF-8 and
nullability — before its fingerprint enters the chain; it is exercised
separately in `inspect_test.zig`.

`just test::query` now adds `publish` and `deliver` phases to its
existing real disk Ursula/node proof, driving two separate `GenServer.Growing`
instances (sender and receiver) that each explicitly configure
`.query = .{ .workspace, .cancellation }` — the growing GenServer still
rejects these frames by default; nothing wires this in a production host yet.
The proxy loses an accepted publish reply and a receive reply in addition to
the existing stage/seal faults; exact retry recovers all four without
rerunning a handler or reopening released source rows. It also cancels the
sender mid-submit while an authority outcome is uncertain and confirms the
uncertain mutation is retained, not discarded. Independent PyArrow decodes
every segment the receiver durably stored and diffs it byte-for-byte against
the sender's own captured segment, and Python checks the received manifest's
basis/plan/chain/schema against the sender's. One run: 41 rows/9,984 bytes in
six segments; publish took 3.99s and deliver 69.36s on this one-CPU Debug
sample, on top of the existing 8.30s/10.24s/18.14s write/seal/recover. Six
segments against a two-segment credit window means the sender genuinely blocks
and resumes under real cross-process delay here, not just in the in-memory
proof below; these are finite shared-host proof timings, not service SLOs.

Receiver-issued credit (`GQG1`, [`contracts/STATION_QUERY_V1.md`](../contracts/STATION_QUERY_V1.md#flow-control))
is implemented, not just designed: the sender will not start a segment more
than `credit_window` (2) ordinals past the last credit it has observed, the
destination grants credit only for segments it has itself durably sealed, and
a regressing or forged grant is rejected rather than tolerated.
`query_growing_test.zig` qualifies this in-memory — a forged-peer grant is
rejected, a regressing grant errors, a repeated or post-completion grant is
inert, and the two-sided delivery proof asserts exactly one grant per sealed
segment (six, for six segments). [`Delivery.tla`](verification/models/Delivery.tla)
checks the same shape abstractly via `just test::model-delivery`; it is not
yet wired to a Zig trace replay the way `test::model` is for `Authority.tla`.
`just test::query --finish-pages 1` retains one resident page through
the seal/recover phases instead of the 64-page default measured above; the
first recovery (after staging, before any seal) always uses one page and no
faults or assertions are removed either way. These are finite shared-host
proof timings, not service SLOs or hosted Nix/CI budgets.

The [verification guide](verification/README.md) owns the versioned inventory,
bound audit and generated transition harness. `just test::properties` checks the
real Zig authority against an independent mailbox/fencing/retry projection,
including replay after every step and bounded failure minimization. The initial
21-trace corpus/generation run passed 826 boundaries in 8.46 seconds on this host.
That measures the harness, not service throughput or exhaustive exploration.
The captured-view extension passed 39 saved/generated traces with 1,682
boundaries in 18.91 seconds on this host. It additionally compares atomic KV/input
publication, view release/expiry, clock rollback/uncertainty and current resource
rights. These finite in-memory schedules preserve the real disk and host checks.
The larger run passed 263 traces / 33,250 boundaries in 475.97 seconds. At
`ea62354`, all four compiling guard mutants were detected, with minimized
counterexamples retained by the mutation task.

The [shared SDK scenario contract](verification/sdk.json) now has executable
owners for admission/commit/reply distinctions, same-principal multi-handle
contention, host-loss retry, durable continuation, decode failure, local await
cancellation/disposal and response allocation after commitment.
`just test::client-abi` passed its disk-backed contention and boundary checks;
`just bindings::test` passed the shared host cases and continuation observations
through every existing language pair. Malformed framework input becomes durably
blocked without being consumed. Public M11 SDKs must reuse these scenarios
through their own interfaces; the current matrix qualifies low-level bindings.

M10 is qualified within the [recorded limits](verification/README.md).
CI separates library unit tests from
application/probe builds, avoid duplicate feature-push/PR runs, and select
runtime checks conservatively. Standalone package manifests are compile-checked
with `test::packages-build`; root unit tests own their shared runtime suites, and
`test::compute` separately owns the upstream compute tests. Focused
`test::packages` remains a complete standalone run. `tests/ci_runner.py` exercises actual Git rename/
delete selection, missing revisions, failure propagation and all combinations
of aggregate-gate results. Unknown/shared changes remain full; only foundational
prose-only PRs omit runtime lanes. Main, release tags and merge queues run full.

`just ci::complete` includes Chromium, and `just ci-clean --complete` uses that
inventory on committed HEAD. Each lane records required tasks, completion and
revision beside task timings; successful clean runs preserve these outside the
disposable checkout. Hosted CI budgets and growing-state qualification have
separate measured evidence below; local timings do not qualify massive scale.

The initial M10 model also passed 30,140 states with a four-transition journal
bound and replayed all four removed-guard counterexamples against Zig. The first
CI optimization commit (`b9dd595`) passed `just ci-clean --complete`, including
all language bindings and five Chromium checks; timing and completion metadata
survive under `.cache/ci/clean/b9dd595faade-transit-ci-7c3pzmzd/`.

`just test::pages` qualifies the immutable page primitive with disk-backed Ursula,
cold bounded caches, old roots, unpublished staging and root-only checkpoint/trim.
`just test::pages-cold` separately exercises the pinned S3-compatible cold tier
with owned Docker MinIO and measures both provider processes. The ordinary WAL
fixture disables that tier; it cannot establish bounded provider memory.
The [adapter guide](../packages/zig/transit-backend-ursula/docs/pages.md) describes
measurement fields and their limits. The launcher-default v2 authority retains
bounded catalogs; the explicit v3 authority uses these paged roots. Unit checks also compare randomly ordered updates
and deletion against an independent map and preserve old roots after lost staging
acknowledgements.

The initial [growing authority tests](../packages/zig/transit-core/docs/growing.md)
also cross the legacy process/principal catalogs and retain historical receipts
in immutable pages. They qualify the implemented control transitions against an
injected conditional journal, including lost acknowledgements and stale prepared
roots. State checks also publish rows, input progress and outputs together,
reject staged partial proposals and fence expired required dependencies. Signed
read checks cover bounded current/captured pages, current permissions, stale
ownership/cuts, expiry and hidden association filtering. These engine checks
use injected storage; delivery/settlement also have injected-storage checks.
Station integration has separate service evidence below. Launcher defaults
continue to use v2; each explicitly configured growing capability has its own
proof owner.

An explicit control reserve now has injected-storage evidence too
(`GROWTH-11`, [growing capacity](../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity)):
past a configured ceiling, sends/spawns/grants/new resources/views/associations
and turns that would emit a new output or effect are refused before
acknowledgement, while ownership reassignment, revocation, retry, termination,
delivery, effect observation/closure, an opted-in checkpoint and output-free
turns keep draining and closing existing work through an explicit reserve band
— until even that is exhausted and every command is refused. A restarted
engine recovers the identical ceiling and reserve state. The signed
`capabilities` query now returns `admission_ceiling` and `control_reserve`
alongside every response's own `position`, checked at three points in the
same test (before, at the ceiling, and past the exhausted reserve) so a
caller can compute remaining headroom directly rather than discovering it by
provoking `AdmissionClosed`/`ControlCapacity`. This qualifies the admission
mechanism and its observability. The additional
[physical-capacity and service/Station proofs](#growing-physical-capacity)
qualify the finite deployment profile separately.

`just test::growing` runs the growing core against real Ursula and a single-page
Transit cache. It crosses legacy process/principal/resource/row bounds, stages
private candidates, rejects stale publication after revocation, injects failure
before append and response loss after real acceptance, and verifies retained
views/receipts/progress/outboxes across SIGKILL. Opted-in root checkpoint/trim
retains all that state and rejects an uncommitted retention intent. It finally
removes page storage in its disposable fixture to prove recovery fails closed.
The [adapter guide](../packages/zig/transit-backend-ursula/docs/growing.md) owns
measurement details and compatibility limits. This is authority/provider
qualification, not node/client/Station support or a scale SLO.

`just test::growing-service` runs an independent Zig caller using only
`transit-client` against the real v3 node, with disk Ursula on one CPU. It uses a
wide principal, six resources and 64 rows, reading individual captured keys and
bounded current pages. A malformed receipt after acceptance survives caller/node/
provider restart as the exact same signed request and receipt; current revocation
then denies both reads and that historical retry. The response validator also
rejects mixed realm/revision, page holes and invalid continuations while accepting
empty filtered catalog pages. No launcher, Station or foreign ABI changes profile
implicitly. Existing v2 ingress and observability proofs cover the shared loop.
The caller also inspects blocked metadata, uses a PID-scoped administrator to
retry the exact failed input and consumes it only after fresh ownership. Core
tests additionally race retry with revocation, recover a lost retry receipt,
reject stale repeated-failure generations, and preserve dependency expiry,
process deadlines and permanent retirement.

The [retained-version proof](../contracts/READ_VERSIONS_V1.md) adds an atomic
pre-write 60-row snapshot to the lost-reply turn. It reads current and retained
state after caller/node/provider restart, fences the old activation and explicitly
declares/releases the version from a replacement. Core checks cover missing
snapshot pages, filtered discovery, source expiry, release and grant changes
between reading and publication. The separate provider proof retains these roots
across actual checkpoint/trim/recovery; it preserves immutable page storage.

The task also runs two real [growing Station callers](growing_station.zig),
retaining 41 typed Table rows and completed calls without reclamation. A proxy
enforces point reads during handlers, corrupts a captured read and loses an
accepted turn reply. A swallowed read failure cannot publish its private work;
the accepted turn retries byte-for-byte without rerunning the handler. After
caller/node/provider restart, fresh ownership fences a prepared old turn and
recovers the unconsumed call without rerunning committed initialization. The
proof uses a bounded 64-page cache for exchange, one resident backend page
after restart, and explicit public-client delivery. It
does not qualify background courier, registries, supervision, runtime bindings
or foreign APIs. Separate query and quota proofs below own those
implemented capabilities.
After restart, the writer also reads all 41 Table rows in six typed pages before
committing its completion count. Continuations cannot change view, resource,
Table or schema; unit cases cover extreme keys, a neighboring Table, caught scan
failure and exclusion of private writes. This is paged state access, not yet
large-result capture or whole-query execution.

Run just this scenario with `just test::growing-station`. It also retains the
earlier 40-row source, commits one scan page plus a self-continuation, and loses
caller/node/provider again. A replacement continues from durable progress across
new handler views, finishes the same source in six pages total, and releases it
with the final count. Retained reads automatically become proposal dependencies.
This is an application-managed scan; it does not implement the Arrow result gate.

The caller now drives M11's separate `prepare`/`dispatchPending` methods. It
checks that repeated preparation preserves frozen work, discard rejects a pending
mutation, and successful dispatch exposes the same input identity and a positive
receipt. Native units cover permit/view/turn preparation with no usable I/O
client, stop without a failure marker and read poisoning under stop policy.
`just test::unit`, this disk recovery proof and the legacy `just test::station`
service/recovery/lifetime proofs passed after the change. Foreign persistence
callbacks and public SDK runner qualification are still separate work.

The same service task runs growing maintenance on one CPU with owned proxy
faults: kill after an accepted snapshot loses its reply, then restart from the
recorded trim intent; loss of an accepted immutable-page reply before root
publication; timeout after accepted physical trim; current maintenance
revocation and later regrant; node/provider/worker restart. Terminal-source work
is disposed without delivering to the destination, independent state and an
unresolved authorized attempt survive, and retained output bytes stay readable.
Core checks separately cover clock loss/uncertainty, bounded finite scan passes
under continuing admission, current control authorization and revalidation of
stale scan suggestions. These are not sweep-latency or full-store guarantees.

### Growing physical capacity

`just test::growing-capacity` uses the same owned Docker/ext4 fixture as the
legacy capacity proof, with the real v3 authority and disk Ursula. The declared
profile has 96 admission positions and a 96-position control reserve. One decoded
page (8,532 bytes) serves 40 retained 256-byte rows, retained receipts, accepted
backlog, a finite process and an unresolved authorized effect. Applications have
not opted into row/result reclamation; root-history trimming is explicitly enabled.

The 2 GiB filesystem preallocates a 1 GiB reserve. Filling the remainder triggers
real ENOSPC and Ursula's WAL pressure gate. A control publication then fails while
the authority stays at position 96 and all data and permissions remain intact.
Only the reserve file is released; the filler remains throughout control work
and restart. Revocation, opted-in expiry, effect closure, complete backlog drain
and root checkpoint/trim finish at position 154. SIGKILL/restart preserves every
row, exact historical receipt, retirement and closure. Repeated maintenance and
verification issue only GET/HEAD requests and stage no pages.

One local Debug run took 29.43 s for setup, 0.95 s under pressure, 31.55 s for
control/drain/checkpoint and 1.42 s for recovery/verification. Control work added
1,310,720 allocated WAL bytes while using 58 of the 96 reserved positions. These
are one finite workload's measurements, not a worst-case allocation formula,
production reserve recommendation or host-power-loss proof. The node does not
provision physical headroom automatically. Evidence is written to
`.cache/growing-capacity-evidence.json`; the legacy task retains its own artifact.
The dedicated reference workflow runs both proofs and preserves their metadata.

`just test::growing-quota`, also included in `test::growing-service`, uses the real
node and Station on one CPU with one resident page, a 24-position ceiling and four
control positions. A previously captured output-free handler turn commits after
admission closes. Opening a view for the next input is refused, and the host
retains its exact signed proposal. Caller/node/provider replacement preserves
15 admitted inputs, one consumption and zero cancellations. The same request
still receives `AdmissionClosed`; authorized revocations exhaust the reserve,
after which a new control operation receives `ControlCapacity`. Current rights
still govern retry disclosure. Reads confirm the same retained data and backlog.

## M12 declarative interface readiness

`just test::sql` regenerates the ANTLR reference parser and runs the pinned
pglast/libpg_query differential corpus, then invokes the actual Zig public-package
consumer in [sql_driver.zig](sql_driver.zig). All 103 admitted SELECT statements
must have identical normalized ASTs across the three parsers. Fourteen are
unchanged PostgreSQL REL_17_5 regression statements; source provenance, hashes,
license and exact exclusions live in [the grammar contract](../contracts/sql/README.md).
Seventeen syntax exclusions and thirteen grammar-only administrative forms must
be rejected by the production parser. Twelve admitted SELECTs deliberately fail
schema/type/limit compilation; the other 91 compile to independently checked
`FZP1` bytes and execute through `Stream.step` over 70 rows in seven-row pages.
Plan and progress round trips precede continued execution. PyArrow independently
checks original result segments, column order, nulls and exact values against a
Python result oracle. Omitted limits must not truncate at 32 rows.

The SQL unit suite (ordinary `just check`, or standalone `zig build test` in
`packages/zig/transit-fuze`) covers manually constructed plan equivalence,
AST ownership after text destruction, invalid encodings/names, statement/literal/
comment bounds, integer extrema, trailing input, and 2,000 seeded arbitrary or
mutated statements. Actual compiled sum plans retain cross-page overflow,
source-revision fencing and cancellation; a limited input excludes later
row overflow. Tests do not claim unbounded fuzz coverage.

`just test::sql-grammar` is the focused reference-only check. Ordinary bindings CI
owns `test::sql` and `test::sql-rewrites`; generation always reruns, and a cache
hit cannot substitute old trees. The optional tools come from existing Nix pins.
No PostgreSQL server or ANTLR/Lean runtime enters Fuze. These local proof commands
are executable evidence; a hosted timing measurement for the expanded lane is
still deferred, as it was for M11.

This qualifies parsing → typed plan → bounded paged Arrow execution, not a
network query service or SQL DDL/writes. Current authorization, durable Station
publication, recovery and foreign SDK behavior retain their existing owners and
proofs. The parser does not change those boundaries. The Lean model's separate
assumptions and evidence are recorded in the grammar contract.

`just test::sql-rewrites` checks four complete Lean theorems. Filter reordering
and projection pruning print only `propext`; predicate pushdown with first-error
preservation and its downstream-consumer corollary print no axioms. The runner
requires all four names and rejects warnings, incomplete proofs and unexpected
axioms. This is specification evidence with explicit correspondence assumptions,
not implementation refinement or an enabled optimizer. False/generalized limit
and sum rewrites remain excluded, with reasons in the model.

## M13 public query access

`just test::public-query` builds and runs the actual `transit` shell and
`transit-query-host` source/requester/courier binaries against an isolated growing
node and disk Ursula. A separate provisioning caller creates a 41-row Table,
including nulls and integers beyond JavaScript's exact numeric range.

The current proof passes exact decoded typed rows across all six segments;
unsupported SQL without admission; a malformed/lost admission receipt and
byte-identical signed retry; worker SIGKILL after accepted staging followed by
fresh recorded ownership; rejection of reuse of the old activation; explicit
busy admission; schema mismatch rejection; incomplete result refusal; explicit
cancellation; source retirement clearing; and read revocation during incomplete
capture, after an actually received partial segment, and after complete disclosure.
An inspection-only principal cannot use another principal's requester binding.
Re-authorized reads select the original result without rerunning SQL.

The public client restarts an entire changed read at most three times, retaining
resource-cut consistency during final acknowledgement. This never retries query
execution or regenerates an uncertain mutation. Package tests also verify owned
schema-fenced request encoding, full-width cancellation identity and rejection
of a predicate that exceeds the existing frame budget.

`just transit-board::query-test` runs the actual growing Board binary and the
same real hosts against a separate disk-backed realm. It proves default query
disablement, distinct inspection/query principals, unsupported/malformed ingress
refusal before admission, exact frozen start/cancellation retries, incomplete
page refusal, current result authorization, source retirement and stable atlas
cuts. Widening the inspection grant is refused. Restoring it requires explicit
resource reauthorization because coarse grant replacement changes incarnation.
Actual source/plan/page responses pass the generated JavaScript validator; typed
int64 cells retain values beyond JavaScript's exact numeric range.

`just transit-board::query-browser` includes that API proof and drives Chromium
against the actual embedded UI. It selects a resource, changes emphasis/detail,
enters the workspace, switches Canvas/Browse before and after a single explicit
submission, and preserves an edited draft alongside the identified old result.
An externally recorded revocation clears schema, draft and result in the open
workspace; restoring access does not rerun SQL or recover an offline copy.
Source retirement clears it again with a distinct unavailable/expired message.
The proof checks no cookies/local/session storage and captures the atlas and
workspace screenshots. Frontend unit tests reject int64 overflow, wrong cell
types, row gaps, invented continuation and invalid Unicode.

Local Linux x86_64 qualification passed: `just check`, both real query proofs,
Board's legacy API proof and all five legacy browser scenarios, plus independent
`transit-board-api` package tests. CI owns the API and browser tasks in the
experience/browser lanes. These new lanes have not been remeasured on hosted
runners; M10's earlier cost evidence is not a claim about the expanded suite.

This is one Table, one query principal, one requester and one authority. It
qualifies process SIGKILL, not host power loss; the courier's bounded restart scan
has no latency guarantee over arbitrary retained history. It adds no automatic
production provisioning, larger-population atlas proof, per-human delegation or
reference-deployment query capacity guarantee. Complete-results-only row access
is intentional; partial progress is visible without disclosing partial rows.

## M14 immutable publication

`just test::publication` runs [real Zig Station callers](publication.zig) against
an isolated `growing_v3` authority and disk-backed Ursula. The
[Python harness](publication.py) verifies an independent SHA-256 fixture,
intercepts actual signed HTTP responses and SIGKILLs four workers at named
boundaries. It also kills the authority and restarts the owned store at each
boundary. Native memory and the harness manifest are not authoritative content.
The proof belongs to CI's growth lane; the ordinary build compiles its caller.

The schedule stages a 64 KiB binary record and an unpublished 513-byte record,
reserving bytes/slots before append. It rejects quota/oversize work, resumes
four remaining chunks with one resident authority page, and stops again with a
fully staged record and an unsent publication turn. After fresh ownership the
old signed turns are rejected. Publication, application head, acceptance marker
and output commit together; a revoked write attempt publishes none of them.
Lost append/publication/cleanup acknowledgements retry the exact signed bytes
and receive the same receipt. A distinct duplicate application command creates
no second acceptance output.

Forty-one additional 32-byte records remain published without requiring cleanup
or enlarging a snapshot. After another restart with one page, an actual returned
prefix is followed by read revocation; the failed read poisons the whole proposal.
An expired view cannot continue. Explicit retirement removes the current head;
explicit abandonment retains its staging reservation until cleanup completes.
Cleanup commits two chunk deletions at a time and is interrupted after progress.

A retained source protects the original 64 KiB body while current chunks are
removed. Its verification reader records the source identity and cursor progress
in KV, reads eight chunks per handler and resumes after worker/node/store loss.
Only the final verified chain sets the completion marker. Subsequent revocation
and explicit release deny retained reads. Authority history checkpointing is explicitly opted in; publication lifetimes
remain unlimited and no history trim is requested. A checkpoint is recorded
before each of the last two recovery boundaries. Final inspection checks empty staging
reservation, preserved acceptance evidence, retained smaller records and
permanent descriptors rejecting old IDs. This is logical current-KV cleanup;
it does not prove physical provider erasure or history trimming.

The package's `publication_test.zig` separately exercises invalid encodings,
full-width identities, empty bodies, identity/content conflicts, out-of-order
chunks, missing/corrupt content, mixed-source cursors, private-write rejection,
quota accounting, read-error poisoning and rollback when the four-mutation
budget fills partway through a helper. It includes 64 KiB streaming and a
historical-snapshot oracle. `just test::unit` runs these checks; the Station
package also builds/tests them using its own dependency manifest.

Capacity is explicit: chunks are 256 bytes, namespace values 32 bytes, descriptor
values 104 bytes, keys 23 bytes and cleanup at most two chunks. A 64 KiB record
uses 71,551 logical key/value bytes plus 55 bytes for its namespace; provider
indexes, authority history and retained roots add separate overhead. Record and
staging byte/count quotas are durable configuration. The u32 encoding ceiling
is not a qualification of arbitrary multi-gigabyte records. Total retained
record count does not size an array or whole-record buffer in the implementation.

Local Linux x86_64 qualification passed: `just check`, standalone Station
package tests, `just test::publication` and the existing `just test::query`
regression. The [retained report](verification/results/m14-publication-2026-09-26.json)
records source hashes, sizes, workload and phase timings: staging 34.566s,
one-page sealing 4.781s, publication 18.878s, one-page cleanup/recovery 21.203s,
and completion 91.551s (170.979s total phase time, excluding build/provider startup).
The native descriptor/cursor/returned part occupy 104/144/416 bytes; these are
type sizes, not a process-RSS measurement. The one-page recovery phases are separated from ordinary
64-page preparation/completion. A preliminary whole-write one-page stress run
was interrupted for excessive repeated cache work; it is not passing evidence.
These proofs concern one authority on Linux x86_64 and process/store restart,
not host power loss, production throughput, CRDT convergence, language SDKs,
remote uploads, physical reclamation or deployment-launcher support. Hosted CI
feedback/cost for the additional task has not yet been measured.

The M17 Document package now runs eight component tests in `just check` and
`just test::packages`. They include all 24 permutations of four concurrent
changes with duplicate delivery, nested parent deletion/child edits, text anchor
deletion and concurrent insertion, explicit register conflicts/resolution,
missing/null/type errors, full-width values, Unicode and failed candidate writes.
An 80-change text schedule stores 640 scalar elements and more than 2,048 index
entries while traversal advances one bounded transition at a time. The standalone
suite passed in 1 s with 16 MiB process RSS (including the in-memory test store);
this is not a production resident-memory or disk-recovery measurement. Full
repository checks passed. Durable acceptance, checkpoint/compaction, SDK and
placement evidence remain pending.

M17's Document service component now passes 14 standalone tests (1 s, 16 MiB
process RSS including fixtures), and `just check` passes. The private-turn fixture
reconstructs every staged proposal, discards it before commit, and verifies that
only final acceptance changes the head. Three acceptance mutations leave room for
one framework mutation plus the success output. Other schedules cover original
revision recovery for duplicate changes, frozen request identity, rejected-node
cleanup, candidate quota exhaustion, exact older reads, logical retirement and
current read denial. The maximum synthetic head encodes to 252 bytes. Disk/node
failure, checkpoint/compaction and public SDK/placement proofs remain pending.

The Document checkpoint component extends the standalone suite to 16 tests,
passing in 1 s with 16 MiB fixture-process RSS. It reconstructs every checkpoint
staging proposal, preserves unlimited-history duplicates and deletion anchors,
and advances finite epoch/floor only in the final decision. Tests reject stale
epochs and recycled replica counters, verify accepted tail requests, preserve an
older checkpoint after new text edits, and reclaim rejected checkpoints or
accepted intervals after permanent retirement. Live accepted intervals remain
physically retained; no reachability collector is claimed. The root check passed;
disk recovery qualification is running separately.

## M20 qualification

All rows use the declared Linux x86_64 int64 Table profile, pinned Zig/Nix,
actual Station workers and disk-backed Ursula. These are focused integration
proofs, not additions to M10's hosted PR lanes or evidence of a new hosted cost
budget. The [compatibility matrix](../packages/zig/transit-serving/docs/compatibility.md)
separates source, transport, client and placement; unavailable rows stay unavailable.

| Proof                                     | Executed evidence                                                                                                                                                                                                                                                                                                                                                | Observed local cost                                                                                                                  |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `just test::reactive`                     | Independent Python/OpenSSL HTTP/SSE/RFC 6455 peers through real nginx TLS and two gateways; empty snapshot, Table progress/outcome, lost WebSocket reply with exact HTTP retry, signed resume, fences, challenge reuse, fragmented bootstrap/ping, declined compression, idle native/service revocation and full worker/gateway/node/store recovery              | Expanded native trace 18.60 s                                                                                                        |
| `just test::reactive-browser`             | Actual Chromium WebCrypto, same-origin WSS bootstrap without custom auth headers, exact HTTP fallback, incremental fetch SSE/event IDs, authenticated description digests and lossless minimum-i64 keys/maximum-i64 values                                                                                                                                       | Browser plus native trace 28.47 s                                                                                                    |
| `just test::reactive-limits`              | Four durable sessions and four held SSE responses, fifth data request refused, reserved health/renewal, idle grant revocation, validly signed future/foreign/incompatible cursors, malformed frames and close, escaped JSON member names, twelve reconnects, lease expiry without observer, and hard source expiry while the logical session lease remains valid | 106.75 s including native recovery; limits portion 87.54 s; health 0.003 s; two-gateway RSS 34,902,016 bytes against 256 MiB ceiling |
| `just test::reactive-placement compose`   | Two TLS gateways, WS command with lost acknowledgement and exact HTTP recovery, SSE replacement fence/cursor resume, physical workers/gateways/node/store recovery and publication retirement                                                                                                                                                                    | 95.81 s; 21 cold objects / 1,438,542 bytes                                                                                           |
| `just test::reactive-placement reference` | Same owned private placement with fresh worker keys/exact ownership, source/session history recovery and explicit new session after the lease elapsed during downtime                                                                                                                                                                                            | 168.88 s; 22 cold objects / 1,994,383 bytes                                                                                          |
| `just test::reactive-descriptions`        | Generated OpenAPI 3.2.1/schema-base and AsyncAPI 3.0, pinned official offline validators, shared schema parity, independent full-width fixtures and drift                                                                                                                                                                                                        | No network schema resolution                                                                                                         |

The placement rows use eight resident authority pages and an 8 MiB hot store;
their times include their local image/preparation path. They create and remove
owned temporary resources and leave the existing reference installation intact.
The reference proof is explicit operator placement, not a growing runtime controller.
Chromium trusts only the fixture certificate SPKI and grants local-network access
only to its owned loopback origin; it is a protocol harness, not a Board view or SDK.

The peer runner writes fixture-only public wire messages to
`.cache/verification/m20-reactive-trace.json`. Validate them with
`python3 -B tests/reactive_descriptions.py zig-out/bin/transit-serving-api --trace PATH`.
The independent validator checks WebSocket messages, reactive reads and the SSE
media-level `event`/`data`/`id` fields. It explicitly parses and validates the JSON
inside `data`: JSON Schema's `contentSchema` is an annotation, not an automatic
assertion. Negative controls reject unknown fields, unsupported versions and
invalid encoded content. Host JSON tests also reject quoted integers and string
substitutes for byte arrays; escaped UTF-8 and full-width identities round-trip.

Serving component tests compose actual `UnifiedCapture` transitions with Table
watch acquisition. A mutation during retained capture is not covered by the older
query basis and remains visible to a watch; later query/manifest writes leave the
marker unchanged and capture releases its source pin. Separate schedules inject a
commit at each acquisition step, empty pages, schema change and denied reads.
Lifecycle tests cover conditional attachment/subscription generations, competing
renew/expiry observations, authenticated clocks, quota, reconstruction and 128
retained session histories. These are deterministic transaction models, separate
from the native disk and physical recovery rows above.

RFC framing tests bound masks, canonical lengths, UTF-8 fragments, control
interleaving, 32-fragment/8 KiB limits and close codes. The deployed peers exercise
these mechanics through nginx. A rejected oversized frame need not have its body
read: the proof sends only its declared length and observes the close. Four held
streams and non-reading reconnect peers cannot grow an event-history queue;
M19's independent slow-write proof additionally exercises the shared finite-deadline
cancellation mechanism with an actual blocked writer.

`just check`, pinned-tool `just doctor`, component checks and description validation
passed. The M19 lifetime regression also passed in 30.74 s after the host changes:
ordered cancellation, duplicate/late timeout, finite process/wait/resource bounds
and hard expiry remain distinct. No push or `ci-clean` run is claimed here.

## M21 qualification

M21 qualifies the selected int64 Table consumers: Board's metadata-only progress
view, its explicitly submitted finite v2 query and the counter application's
bounded snapshot. These consumers share the private Zig caller, generated
runtime-validated TypeScript transport and `LiveView`; Board's inspection,
watch-control and query identities remain separate. KV/Document watches and
continuous SQL are not qualified.

| Executed proof                                  | Evidence                                                                                                                                                                                                                                                  |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just test::reactive-client`                    | Actual TLS/disk hosts, frozen lost-reply recovery, scoped descriptions/clock, private Origin, reserved close, metadata-only reads, denial and 40 schema-validated envelopes; 7.52 s for the clock-policy extension                                        |
| `just test::reactive-refresh`                   | Two sessions sharing one requester, round-robin progress, lost follow reply, stopped source and replacement activations, exact accepted identity, full-width namespace and entry-read-only revocation; 224.56 s initial run, 153.08 s repeated regression |
| Requester/component and frontend checks         | Four-mutation copy turns, writes during capture, dirty successors, quiescence without self-triggering, start budgets, late-candidate fencing, queued pause, startup uncertainty, independent renewal and terminal control rejection                       |
| `just test::reactive-views`                     | Real Chromium counter/Board over TLS, lost accepted upload, failing atlas plus route remount, exact recovery, complete 20-row verification with one eight-row resident page, distinct finite refresh and read-only revocation; 327.65 s                   |
| `just test::reactive-views-lifecycle`           | Shared-principal tabs, actual broken SSE/resume with unchanged sessions, pagehide/expiry, watch reset, explicit resnapshot and source retirement after displayed state; final run 89.03 s                                                                 |
| `just test::reactive-views-placement compose`   | Full consumer schedule plus worker/gateway/node/disk restart, same-result recovery and denial between complete verification and visible-page reread; 389.04 s browser / 402.90 s including packaging                                                      |
| `just test::reactive-views-placement reference` | Same extended schedule with fresh Substrate worker activations and confined gateways; 518.32 s browser / 663.06 s including packaging                                                                                                                     |

The final placement runs measured the following single observations, including
client scheduling, source observation and full verification. They are not peak
memory, latency percentiles or sustainable-rate guarantees. The visibility
measurement starts at the mutation trigger, so it includes admission before the
source commit; it is an upper bound on commit-to-visible delay in that run.

| Measurement                                     |                     Compose |                    Reference |
| ----------------------------------------------- | --------------------------: | ---------------------------: |
| Counter trigger to visible snapshot             |                    7,563 ms |                     6,223 ms |
| Finite 20-row verified refresh                  |                  126,895 ms |                   155,111 ms |
| Physical restart to authorized same-result read |                    6,289 ms |                    18,338 ms |
| Observed Board / counter JS heap                | 9,433,188 / 4,794,296 bytes | 10,397,376 / 4,637,604 bytes |
| Retained cold objects / bytes                   |            493 / 49,035,893 |             504 / 57,849,285 |

The fixture checks a 128 MiB per-page heap ceiling. The implementation retains one
visible page, one bounded candidate/verification page and one newest dirty
revision; it does not collect the complete result. Server admission remains four
sessions/service, two/caller, one active finite requester query and at most eight
selected refresh intents per explicit Follow generation. Accepted query and
clock/control history remain retained unless separately opted into retention.

Qualification exposed three lifecycle bugs: attachment recovery could consume
renewal headroom, lost HTTP replies escaped the recoverable error vocabulary, and
a known rejected renewal could loop as a disconnect. The fixes preserve exact
pending bytes, prioritize renewal using the committed clock and observe current
scope after a committed rejection. HTTP attachment observation allows ten seconds
inside the thirty-second joined host budget; logical leases remain thirty seconds.
Frontend tests cover denial/expiry/reset after rejection; the final actual
multi-tab run above passes. Failed earlier schedules are not passed evidence.

The shared `resource_read_batch` capability acquires at most eight named keys at
one current cut; serving policy/session reads and immutable publication chunks
reuse it. Root checks cover scope, signatures, stale revisions, deadline,
retirement and final-tail races. Publication still verifies ordered digests and
fresh final authorization. The unchanged `just test::publication` passed in
91.861 s with four worker kills, 64 KiB, 42 retained records, four mutations and
256-byte values. This is shared-boundary regression evidence, separate from
consumer placement qualification. M20's independent SSE/WebSocket proofs remain
protocol evidence; M21 selects SSE without copying its protocol into the UI.

## M22 qualification

`just test::grpc-server` passes independent grpcio/h2 unary and streaming calls,
pooled sequential requests, reserved control progress under full data admission,
joined deadline/cancellation, blocked credit cleanup and malformed framing.
`just test::flight-metadata` passes pinned protobuf drift and PyArrow 23.0.0
catalog/schema/Table/type/SqlInfo metadata, optional filter presence, empty
batches, all six union children and the published int64 Table schema. Package
units cover IPC boundaries and signed ticket tampering/scope/expiry. Fuze's
zero-body primitive IPC regression and compatible compute tests pass (119 tests).

`just test::flight` also passes the real native gateway and disk-backed finite
query hosts through verified nginx TLS. PyArrow checks schema/catalogs, all 41
exact int64/null rows, duplicate retrieval and exact admission retry (71 seconds
for this portion on the measured development host). Apache ADBC release 24's
Flight SQL 1.12.0 Python consumer checks native schema, rows, empty results,
count, checked sum and unprepared fallback. The independent C vtable consumer
checks the same schema/rows through Arrow C Stream and releases every handle.
The unchanged public-query recovery/authorization regression also passes.

`just test::flight-outbound` passes an independent PyArrow TLS Flight service
through the actual recorded RPC worker: request preparation sends nothing,
authorized dispatch records schema/six batches/outcome, then the peer is stopped
and its credential removed. After node/disk-store restart, the Zig Flight replay
adapter checks all 41 exact int64/null rows and complete capture without dispatch.
The adapter keeps M16's finite message/byte budgets and explicit outcome policy.

`just test::flight-faults` passes the real gateway through TLS with two separately
scoped caller mappings. It drops an accepted native reply, replaces the gateway
and verifies byte-identical signed retry and the same receipt. Pooled RPCs check
credentials independently. Malformed/unsupported requests, sequence conflicts,
foreign/tampered/expired tickets, read-only revocation after an actual batch,
interrupted duplicate fetch and released capture pins all pass. Request and
source retirement fail closed after real prefixes; gateway/worker/node/disk
replacement retrieves the same retained result. Board reads capture/manifest
provenance with query execution disabled and returns 410 after source retirement.
Projection units cover canonical keys, mismatched ownership and maximum u64
correlations/counters; Board emits decimal strings for these framework fields
and regenerates its runtime validators from the public types.

The load extension holds two native fetch reads for six seconds with an explicit
15-second native budget, rejects a third caller data RPC, and keeps current-schema
control responsive within five seconds. Gateway RSS sampled 57,794,560 bytes
under the declared 192 MiB fixture ceiling; this is not a measured peak or general
capacity guarantee. A private HTTP/2 peer grants only one byte of response credit:
the adapter sends a real prefix, admits control and closes the stalled write
within twelve seconds (five-second write budget). Subsequent fetch returns the
same complete result. Actual compressed, oversized and truncated request frames
fail before dispatch; outbound replay units reject malformed protobuf/Arrow.
TLS edge buffering is separate from this private adapter credit measurement.

The same workload passes `just test::flight-placement compose` and
`just test::flight-placement reference`, including original-ticket retrieval and
exact admission retry after workers, gateway, authority and disk store stop.
Compose measured 271.18 seconds including packaging, 413 retained cold objects /
42,821,771 bytes. Reference measured 367.00 seconds, 365 cold objects /
37,968,589 bytes, with fresh Substrate source/requester activations and restored
public grants. Both use the explicit operator-host TLS edge; reference's courier
is also operator-hosted. The reference proof checks gateway egress denial to
storage, external endpoints and provider/control APIs. Placement owns only its
isolated namespace/project and leaves the default installation unchanged.

Recovery found transient DNS loss could incorrectly stop an idle query host;
it now uses the shared unavailable classifier while preserving pending signed
bytes. A ready gateway pod also precedes port-forward/TLS reachability. Bounded
schema discovery waits for that read path without admitting another query.
Pinned PyArrow GetSchema exposes UNAVAILABLE through OSError with status detail,
which the readiness loop classifies separately from denial. Failed precursor
runs are not counted as qualification.

The unchanged public query, M16 RPC worker and fault, M19 serving and M20
reactive suites pass after this composition. The final common regression measured
378.36 / 184.30 / 12.09 / 15.45 seconds respectively for RPC worker, RPC faults,
HTTP serving and reactive recovery (excluding build time). `just check` and
`just doctor` pass. The manual Flight CI workflow registers metadata, native
clients, fault/load, outbound and Compose checks with timing artifacts; it has
not been run on a hosted runner in this work. Local costs do not replace the
M10 feedback/runner-minute budgets. Reference remains an explicit external proof.

Qualification stays finite: Table v1, declared int64 columns, read-only SQL,
pinned Linux x86_64 C/Python consumers and the documented RPC limits. Metadata
union/list/map validity does not qualify wider application types. No Flight
writes, prepared parameters, continuous streams, automatic new-query retry,
dedicated ADBC driver or production-scale throughput is claimed.

## M23 application declaration boundary

`just test::application-grammar` builds the actual `transit-app` CLI and uses the
pinned ANTLR toolchain to compare independent parse-tree models, SQL/model/visual
edit round-trips and complete-program rejection. Full-width revisions remain
canonical decimal strings. Package tests (also in `just test::unit`) exercise
allocator failures, source-buffer ownership, incompatible references and budgets.
These prove the offline boundary only; the separate native publication and
editor proofs below cover ingress and restart. The generated work-item proofs
below separately qualify the selected migration and physical placements.

Application publication owner tests add two competing operators, exact accepted
proposal recovery after owner reconstruction, atomic four-mutation activation,
revocation between chunks, process-origin rejection, invalid body/read failures,
explicit cleanup, non-owned-record abandonment rejection and seventeen retained
revisions beyond the two-body staging budget. `tests/application_contract.py`
checks independently encoded AP1 layouts in the ordinary root unit task.
These deterministic tests do not substitute for physical restart/ingress proofs.

`just test::application` now exercises the real signed native boundary with a
separately granted operator and Station worker over owned disk Ursula. It kills
three workers at chunk/activation boundaries, restarts node and disk store,
rejects saved stale-generation proposals, retries lost append/activation replies
byte-for-byte, and verifies persistent operator denial plus current resource-read
denial. Recovery uses one resident authority page. The 1002-byte interface took
20 turns, 197 point reads, at most four mutations and 256-byte values; measured
phase times were 0.907/1.660/0.405/0.917 seconds (stage/seal/publish/finish, excluding
compilation). This proves native publication recovery; the separate browser proof below
covers native HTTP operator ingress. Data migration and Compose/reference
application placements remain open.
The proof and independent grammar are explicit focused tasks, without expanding
ordinary PR lanes or claiming a new hosted budget.

The application browser package has strict type/format/lint checks and executable
Vite+ tests in `just transit-board::check`. Its generated CSP-compatible validators
reject unknown fields, coercion, unsupported component versions and full-width
identity overflow. Pure theme/diagram edits preserve operation definitions;
generation keys distinguish scope, revision, record and exact body commitment.
`just transit-board::contract` checks the Zig schema and both generated browser
artifacts for drift. Structural browser checks never replace native graph/source
validation or current authorization.

The native application proof now sends `Request.Command` uploads to the actual
`Behavior`, including a pending first half across a kill. It checks retained
denial dispositions and explicit administrator restoration. Additional owner tests
reject mixing full-body and half-chunk upload paths and prove that unsupported
program bytes cannot become an active interface. Allocation/read failures do not
become terminal caller rejections. Independent fixtures cover every command tag.

`just test::application-browser` starts owned disk Ursula, an actual application
worker and the embedded Board binary. It checks the disabled operator endpoint,
exact Origin, invalid signatures, disallowed principals and complete-program
rejection. Chromium edits SQL/Form/Canvas, reviews an exact base/digest, loses a
real admitted reply, edits the separate draft, remounts the route and retries
the identical signature. It also restores the reviewed plan after a full reload
and fresh key import without changing its original base or body. The
extended native browser sequence passed in **31.9 seconds** (excluding compilation
and fixture setup). The harness then kills worker/node, restarts disk storage,
checks the same complete published definition and denies disclosure after reader
revocation. Built-in and published definitions are distinct response variants.
This is native editor/publication evidence, not interface-generation fencing,
application data migration or Compose/reference qualification. The task remains
focused, outside the measured hosted PR budget.

The shared native signing helper also agrees with independent Python Station/v3
fixtures. Browser tests preserve one outstanding signature through export/import
and refuse altered scopes before signing. Host compiler replies use the existing
Station publication commitment; they do not invent a second digest format.

M23's declared shell now passes the real native application browser proof with
published custom routes and deep-link reload, old-client navigation replacement,
SQL/Form/Canvas recovery, fixed independent recovery route, keyboard flat/Browse
navigation, Activity/Operations, two monochrome densities, WCAG A/AA axe checks,
320 px layout and 200% content zoom. The executed browser case took 41.5 seconds
(42.2 seconds including the Playwright runner), excluding compilation and fixture
startup. Worker/node/disk restart and current read denial remain part of the same
focused harness. The Table browser case additionally drops a successful native
admission reply, unmounts the route and proves an identical retry after remount;
it passed in 22.5 seconds (23.2 including runner), then checked current revocation
and permanent source retirement without another SQL admission.

Startup failures found during this work are part of the evidence: route-split
module requests exhausted the existing handler pool, custom document navigation
was exposed to the native-read throttle, and synchronized five-second definition
and Atlas timers could starve Atlas. The consolidated static artifact, independent
static navigation and bounded Atlas read retries fixed these observed failures.
Browser proofs use the same Playwright output directory and run sequentially;
concurrent invocations corrupt trace artifacts. Source-contract guard tests reject
foreign/mixed contracts and a different Table with identical columns. The generated
application's migration and physical placements have separate proofs below.

M23 migration ledger package tests now cover independent full-width AP1/key/hash
fixtures, twenty retained step receipts, exact reapply without invoking domain
code again, concurrent proposals, changed step digests, future ordinals, revoked
operators, source conflicts, explicit abandonment and activation limits. Injected
read failure and domain failure preserve the original turn decision, and a third
domain write rejects without partial effects when the two ledger writes would
exceed the four-write budget. `tests/application_migration_contract.py` runs in
the root unit task. Migration network admission, the selected data transform and
physical deployment have separate work-item proofs below; deterministic owner
tests alone do not establish those results.

The shell/source-fencing changes also passed `just test::unified-ingress table`:
actual shell and browser, scoped descriptions, frozen retries, source/requester/
node/disk restart, prefix revocation and released source pins. The complete
focused run took 236.81 seconds excluding compilation. This is a regression proof
of the existing Table v2 path, not a new cross-schema migration qualification.

The M23 Atlas/participation extension passes the native Board query/browser
harness with three PIDs, two visible resources and one hidden resource. A newly
provisioned unowned PID has ten shared aliases plus a hidden association; two
bounded pages recover the ten visible aliases without exposing the hidden name.
Resource revocation rejects the metadata API and removes browser contributions;
restoration requires current reads. Invalid/mixed continuations reject. The
browser covers local filtering before visible summaries, per-PID continuation,
both density variants with WCAG A/AA axe checks, and the existing exact query
retry/remount/retirement schedule. The browser case took 30.8 seconds (31.5 with
runner), excluding compilation and fixture setup. This finite population proves
neither complete realm aggregation nor billion-scale rendering or throughput.

The first fixture attempt correctly failed because it tried to add associations
to an active owner. The corrected fixture declares them on a fresh unowned PID.
A missing observation position on association continuation also failed; cursors
now preserve the native position and changed cuts require rescan. No kernel
permission or fencing rule was weakened to make either proof pass.

The application browser proof also covers staging interruption, explicit
abandonment, a lost collect reply recovered with identical signed bytes, released
staging capacity and refusal to abandon an applied revision. The expanded run
passed in 52.3 seconds (53.0 seconds including the browser runner), excluding
compilation and native setup. Package owner tests cover multiple collection turns,
interrupted half chunks, exact proposal mismatch and the four-mutation bound.

The Table v1 browser additionally exports a terminal query reference, clears its
selection and resumes the original correlation under current reads without any
additional submission. It then revokes access and retires the source as before.
The expanded run passed in 33.0 seconds (33.7 seconds with the runner), excluding
compilation/setup. Shared recovery controls also type-check for v2; this test does
not establish a schema migration, different requester or different origin proof.

The M23 finite draft owner passes independent little-endian command/record and
big-endian key fixtures, full uint64 identities, malformed/trailing data,
conflicting opens, exact replay, exhaustion, closed-generation replay, twenty
retained generations, source/budget mismatch, read poison and preservation of
prior decisions. New query admission uses exactly four mutations; publication
reads correctly reject a turn that already mutated state. Foreign external and
process origins reject; corrupted stored records propagate without recording a
caller rejection.

`just test::unified-ingress table` additionally qualifies the draft host against
the actual requester/source and disk Ursula: a one-row finite query, cross-instance
identical signed retries, no reset on repeated open, exhausted-budget refusal,
closed-generation replay and revoked source access. This slice took 27.21 seconds;
the expanded full Table run took 266.30 seconds excluding compilation. It includes
the existing worker/node/store recovery and browser regression; the subsequent
Table Live browser proof below separately qualifies scheduling and saved recovery.

The neutral query-browser extraction passed generated schema equality with Board,
strict types, semantic validators, bounded response/UTF-8 handling, exact throttle
retries, no retry of uncertain/503 submissions and complete-result coverage tests.
Board's actual Table native/API/browser regression now uses the shared transport,
value validator and result reader. It passed in 265.51 seconds excluding compilation;
the draft-budget host slice took 26.58 seconds and two Board readers peaked at
34,537,472 bytes RSS. Automatic draft scheduling has its separate browser proof below.

M23 Table Live draft browser qualification is part of `just test::unified-ingress
table`: a lost accepted upload reply is saved, the browser reloads, and the exact
signed command and frozen namespace/bundle recover without replacement. Rapid
edits coalesce; two consumed native intents exhaust the explicitly opened
generation, and editing cannot reopen it. Current denial clears protected data.
The combined worker/store recovery, API and browser run measured 327.26 seconds
locally; this does not enlarge hosted PR lanes or establish interactive latency.
The scheduler's separate seven tests cover known rejection, pause and explicit
cancellation; KV/Document Live draft and distributed caller fairness are unqualified.

The M23 Table workspace suite also qualifies native authorized SQL suggestions:
case-insensitive filtering, bounded/invalid search, real compilation, current
source denial and no admission when selecting a draft. The actual browser opens
a same-result visible-page profile/chart. Its combined run measured 329.00 seconds
and two concurrent Board instances measured 35,663,872 bytes RSS. Native catalog
tests cover all eight column positions, type-aware sums and allocation failure.
These measurements cover the Table placement, not a distributed latency target.

`just test::work-items` qualifies the actual `transit-work-items` application
worker against native growing authority and disk Ursula. Nineteen rows cross ten
two-row copy turns and a complete verification pass before activation. Two worker
kills, fresh-key registration/regrants and exact generations span copying and
verification; the node and disk store restart after the first copy. Lost operator
and worker receipts retry identical bytes, and an old-key accepted proposal is
refused after replacement. Current migration revocation preserves progress;
activation keeps writes paused until explicit administrator release. The run
measured 15.75 seconds, 53 observed turns, 20 page reads, at most four mutations
and 142 bytes/value. This does not qualify generated UI, Compose/reference
placement, a distributed controller or authority transfer. Four unit tests and
independent Python command/cursor fixtures cover empty and 33-row migrations,
full-width keys/ordinals, exact reconstruction, target corruption and abandoned
Table identities. Retention remains unlimited.

The v2 Document workspace also passes the M23 SQL candidate/profile browser
checks with current denial and the original worker/store and exact-retry suite.
The full run measured 831.88 seconds (473.65 seconds provisioning), twelve rows
in two result segments, 37,576,704 bytes RSS across two Board instances and
148,158,801 retained cold bytes. Searching `count` can match Document column
names as well as COUNT; the catalog filters before its eight-result bound.
This does not enable Document Live draft or change the hosted M10 budget.

`just test::work-items-browser` now qualifies the standalone generated work-item
frontend with the actual native worker, separate publication/requester workers,
query courier, private gateway and disk-backed Ursula. The current run measured
164.79 seconds, including 15.83 seconds provisioning. Nineteen rows span three
verified result pages. The browser preserves the selected page during current
rereads, reads the canonical declaration, saves a lost accepted upload, crosses
bounded copy/verification/activation and conditional interface publication, then
reloads through gateway replacement. It retries the identical native proposal,
refuses continuation against the new contract, cancels the original upload and
explicitly admits a query over the new schema. Normal writes remain paused until
publication and explicit administrator release; old epoch commands are rejected.

The same browser checks work-item decoding, two densities, 320 px layout,
keyboard focus, axe accessibility, current read denial and empty browser storage.
HTTP origin checks and startup refusal of overlapping operator/query identities
also pass. Arbitrary external query-control frames receive a retained denial
without stopping the data owner. Per-process peak RSS was 23,080,960 bytes for the first gateway,
24,604,672 for its replacement, 10,801,152 for the node, 14,450,688 for data,
8,278,016 for publication, 13,434,880 for the requester and 8,515,584 for delivery.
These are one local run's observed peaks, not configured ceilings or distributed
throughput. `just check` passed with the new workspace. Generated-application
M23 clean committed-HEAD qualification is recorded below; this focused task does not
change the hosted PR matrix or M10 budget.

`just test::work-items-placement compose` and `reference` qualify that same
generated browser through actual isolated physical services. Compose passed in
**164.23 seconds**, including 4.54 seconds of image work, retaining 19,557,165 cold
bytes. Reference passed in **383.26 seconds**, including 77.00 seconds of image
work, retaining 18,045,191 cold bytes. These are single local measurements with
nineteen rows and three independently owned PIDs, not sustained throughput or
hosted CI budgets. Reference used the existing kind v1.37.0 cluster and pinned
Substrate revision `d277088bc1d081ef716d81dd7986d05d0a36ad3a`, in a fresh namespace.

Both fixtures stop and replace all owners, gateway, node and disk Ursula before
migrating and publishing the new interface. Compose replaces worker keys and
records fresh ownership; reference places each owner in a separate gVisor actor,
validates its ephemeral registration and grants its exact generation. Regranting
the data owner's requester-resource read rights is separate from association.
Gateway and workers have their own credentials. The private TLS edge passes
independent trust/hostname checks; storage, cold-store and Internet egress probes
reject. The reference gateway also rejects Kubernetes/Substrate control egress.
The default launcher installation is neither adopted nor updated.

The first reference attempt exposed an expired read during upload preparation.
The neutral transport now retries up to three explicitly identified read conflicts
with the same preparation request. Unit tests prove the finite limit and refusal
to apply that policy to signed submissions, changed contracts or denial. The
second complete reference run passed. No accepted identity, authority lifetime
or generation was changed to recover this read contention.

The fixture's TLS edge retains its existing 8 KiB body cap; application publication
uses the native operator, so it does not qualify 512 KiB browser operator uploads
through that edge. Provisioning and migration are trusted operator processes;
automatic growing supervision, every partial root-bootstrap failure, distributed
authority transfer and provider snapshot recovery remain outside this proof.
`just check` passed with the placement wiring; the post-contention regression and
clean committed-HEAD gate are recorded separately when complete.

The post-M23 `just test::reactive-views` regression passes against the declared
Board shell and shared query transport. It covers actual counter/Board consumers,
abandoned-session cleanup, exact uncertain query retry, complete result refresh,
pause and current read denial. The native proof took **461.24 seconds** excluding
compilation; mutation-to-visible measurements were 5.031 seconds for the counter
and 134.615 seconds for the fully verified query. Observed browser heaps were
11,474,368 bytes (Board) and 4,616,116 bytes (counter). These single-run costs do
not claim an interactive freshness target. `just check` also passed after the
read-conflict correction and parser instrumentation.

## M24 shared cursor assistance

`just test::unified-ingress table` passes the native assistance endpoint and real
Board editor against a disk-backed authorized Table, alongside the existing
finite upload, worker/node/store recovery, full coverage, Live budget and exact
retry proofs. The final combined run took **331.57 seconds** excluding compilation.
It checks source scoping, unsupported column/cursor rejection, Ctrl-Space,
whole-token replacement at an interior cursor, Tab acceptance, completion undo,
dismissal and current denial clearing. Neither editing nor acceptance submits.
The native fixture covers quoted/qualified names, typed predicates, SUM limits,
UTF-8 boundaries, comments, literals, eight-result bounds and allocation failure.
The shared browser owner tests delayed generations, one outstanding request,
contract changes, revocation and safe replacement (15 query-client tests).

The final browser fixture measured completion at **823.74 ms cold / 811.18 ms
warm**, including debounce and current authorization, with two gateway processes
using 33,234,944 bytes RSS. The [console fixtures](#m24-console-qualification)
exercise the same parser, authorization and cursor-assistance contract through
an actual terminal for Table, KV and Document. These single-run measurements
establish evidence for the selected fixtures, not a completion latency target.

The first M23 clean-checkout run at `ac287122ea1d` passed core, growth,
experience, launchers and the earlier binding tasks, then stopped in the Node
SDK source tests. A query bridge parameter property was unsupported by Node's
strip-only TypeScript loader. The SDK now uses explicit fields and enforces
`erasableSyntaxOnly`; all ten source scope/runner tests and TypeScript checking
pass. This correction does not turn the incomplete clean run into a pass;
final clean qualification is recorded below.

The retry at `a3f1733c6423` and a simultaneous console proof encountered a full
61 GiB `/tmp` tmpfs. Compilation and the console's private recovery write failed
with `NoSpaceLeft`; Ursula cold storage also refused writes. No run is counted
as passed. Clean checkouts now default to `/var/tmp` (configurable with
`--work-root`) to separate build outputs from short-lived storage fixtures.
The two owned failed checkouts were removed after preserving their CI evidence.

The subsequent disk-backed clean run at `0d671aa` passed core, growth, experience,
launcher and foreign-binding lanes before failing the Python public-runner
expiry setup. Its two-second work window could expire during the seven native
provisioning operations. The fixture now declares a thirty-second window before
spawn and still waits beyond that exact accepted cutoff plus the admitted clock
uncertainty before asserting retirement. No accepted lifetime is extended.
`just bindings::python-test` passes with this correction. The incomplete clean
run and its evidence remain at `/var/tmp/transit-ci-ftq9vsk2`; it does not satisfy
the final clean gate.

The next clean run at `8fefb1c` passed all four non-binding lanes and the
cross-language, Python, Node, Rust and Ruby SDK tasks before the C/C++ runner
harness raised `UnboundLocalError`. Its Document command branch shadowed the
ordinary codec-fixture path. The paths now have distinct names; this changes
only fixture command construction. The failed run is retained at
`/var/tmp/transit-ci-92t7owi1` and remains incomplete. Final qualification must
execute every ordinary lane at one corrected committed revision.

## M24 console qualification

`just test::console table` passes the actual versioned command against forty-one
rows on disk Ursula, bounded cold storage and separate native query workers.
The combined recovery/console proof took **186.62 seconds** excluding compilation;
the added console checks took 105.30 seconds. The Linux controlling-PTY fixture
measured completion at 970.18 ms cold / 290.37 ms warm and 15,208,448 bytes RSS
high-water (64 MiB fixture ceiling). These single-run costs include current
authorization; they do not establish an interactive latency target.

Coverage includes offline help/version, strict options/configuration and relative
credential paths, multiline/comment-aware SQL, rejection before mutation, one
private locked recovery record, a lost reply followed by SIGKILL and exact signed
retry, verified bounded pages, machine/human formats and current denial. The real
PTY covers whole-token replacement, Tab/Enter acceptance, undo, UTF-8 editing with
safe visible escapes, bracketed paste, queued-input invalidation, metadata expiry,
resize, history clearing and interrupt restoration. A stalled stdout exits through
a joined two-second write deadline without submitting cancellation. Native HTTPS
schema reads pass with an explicit private CA; untrusted roots and a different
hostname reject. Existing `query` keeps its independent contract.

The first terminal attempt delayed every metadata read in the test; the fixture
now delays one read. A later test stopped consuming PTY display bytes while
waiting for JSON output; it now drains both streams, and the editor coalesces
queued redraws. The signal path buffers one command before presentation and
checks interruption before emitting it. The space-exhausted run above is not
counted as passed.

The same actual-command, PTY and explicit TLS proof also passes for KV and
Document with their distinct source adapters:

| Source   | Combined native proof | Added console checks | Cold / warm completion | Terminal RSS high-water |
| -------- | --------------------- | -------------------- | ---------------------- | ----------------------- |
| KV       | 195.32 s              | 123.43 s             | 792.42 / 276.61 ms     | 16,261,120 bytes        |
| Document | 738.32 s              | 141.55 s             | 356.81 / 57.08 ms      | 16,265,216 bytes        |

Document provisioning accounts for 493.70 seconds of its total; the fixture
retains twelve rows across two segments, 64 resident authority pages and
133,852,226 cold bytes. KV retains forty-one rows across six segments, eight
resident pages and 26,816,531 cold bytes. Both cap Ursula hot storage at 8 MiB.
These focused costs do not change M10's hosted CI budget. The separate server
lifecycle and physical-capacity evidence follows below.

## M24 local server qualification

`just test::server` passes the Linux `local_table_v1` core lifecycle proof in
**29.12 seconds** in the final fault run, excluding compilation. The actual supervisor launches native
MinIO and disk Ursula, authority, maintenance, source, requester, courier and a
separate gateway with an empty `PATH`. A separately launched console discovers
the empty declared Table and reads a verified `COUNT(*) = 0` result through that
gateway. No example data, shell, Python launcher or source checkout participates
in the running service neighborhood; Python and Docker extract/setup the owned
test fixture only.

The proof rejects an ordinary start without installation state, concurrent
managers, repeated initialization, missing WAL/cold directories and a conflicting
listener. It preserves the same accepted provisioning identities through normal
shutdown, manager SIGKILL and automatic source/node/store replacement. A fourth
role failure exhausts the invocation's three-restart budget. A Linux test
subreaper verifies joined children after manager loss; the implementation itself
uses kernel parent-death handling, fresh worker keys and exact native ownership.
Assertions check increasing generations, different public keys, retained activation
markers and the original verified query after recovery. A SIGSTOP child exercises
the timed SIGKILL path; pipe readers join before their handles close. A real pipe
unit proof drains 2 MiB while retaining only the configured 64 KiB log prefix.

Early attempts exposed a directory `fsync` descriptor issue and HTTP target use
after request-body parsing invalidated its memory. Both were fixed before the
passing run. The fixture now selects an explicit query namespace, waits for
verified completion and sets socket reuse when testing an occupied listener.
`just test::server-faults` additionally passes interrupted persisted provisioning,
exact receipt recovery, wrong caller-key denial, unchanged native status/body,
forbidden identity headers, oversized bodies, four stalled data requests with
reserved control, executable hash mismatch and provider rollback refusal. The
additional schedule took **12.96 seconds**; health took **3.00 ms** under data
pressure and gateway sampled RSS was **9,035,776 bytes** (64 MiB fixture ceiling).
Rollback is a negative test against the persisted observation floor, not evidence
of a supported snapshot restore or a global latest-history oracle.

`just test::server-capacity` passes in **16.61 seconds** after fixture setup.
It uses one owned 2 GiB ext4 image mounted inside an isolated privileged test
container, with native service processes running as the unprivileged host user.
After accepting a query, a filler leaves 4 MiB metadata headroom and a separate
32 MiB allocation proves actual ENOSPC. A preallocated 512 MiB reserve is released
with the filler before restart. Control attempts and shutdown remain bounded;
ordinary recovery preserves provisioned identities and completes the original
query using its independently persisted console record. This is the selected
capacity fault schedule, not a storage throughput or zero-free-byte guarantee.

`just check` passes with the final server and console implementation. The final
M23/M24 committed-HEAD clean gate also passes, as recorded below. These focused
tasks do not change M10's hosted CI budgets.

### Local gateway host alias checks

[Issue #11](https://github.com/rupurt/rey/issues/11) adds the local host policy
described in the [server guide](../apps/transit-cli/docs/server.md#local-names-and-ssh-tunnels).
`zig build test-cli-lifecycle` includes case-insensitive exact authority matching,
port separation, DNS-label/IPv6 syntax and the eight-entry/200-byte bounds.
These tests reject wildcard, URL, userinfo, control-byte, suffix and malformed-port
inputs without resolving configured names through DNS.

`just test::server` reads the actual ready record's gateway URL/effective hosts
and performs a `localhost` HTTP request. Independent socket requests cover the
numeric/default name, uppercase hostname, wrong name/port, missing or duplicate
Host, malformed Host and unchanged Origin/forwarded-identity rejection.
`just test::server-faults` adds explicit developer names and a different forwarded
port, refusal of invalid policy before installation, recovery of the same
installation with the same policy and configuration-identity refusal after policy
drift. Its existing native denial, pressure, joined shutdown, interrupted
bootstrap and provider rollback checks remain required.
`just test::server-applications` checks the same default gateway authorities and
ready fields while retaining the version 2 application management profile and
its installation/replacement/recovery checks.

The forwarded-port proof sends the exact Host an SSH tunnel preserves; it does
not provision an SSH daemon or change the server's loopback-only listener.
The application-serving Origin policy and console endpoint policy are separate
and unchanged. Existing binary/configuration identity guards remain in force;
these tests do not qualify a runtime upgrade of older installations.

## M23 and M24 final clean qualification

The final implementation and proof harnesses at **`21089bb654f0`** pass all
**59 ordinary CI tasks** through `just ci-clean --lane NAME`, with one fresh
checkout per lane. Every completion report names that same full revision;
expected task lists, task order, unique coverage and zero exit codes were checked
against its committed `suite.json`. All five invocations exited successfully.
The [retained report](verification/results/m23-m24-clean-2026-09-28.json) includes
task timings, machine information and the original local evidence directories.

| Lane       | Tasks | Local lane task time |
| ---------- | ----: | -------------------: |
| Core       |    17 |             385.38 s |
| Growth     |    18 |           1,970.07 s |
| Experience |     6 |             341.32 s |
| Launchers  |     2 |             312.88 s |
| Bindings   |    16 |           3,943.77 s |

Lanes ran concurrently on one local machine, with tasks sequential within each
lane. Times exclude clone/dependency installation; their 6,953.42-second sum is
aggregate local lane time, not PR feedback or a hosted runner-minute measurement.
The bindings lane includes every installed SDK, the ten-language public ring,
model checks, SQL qualification and RPC fault recovery. The ordinary gate does
not include the complete browser tier: M23 application/placement/browser and
M24 Table/KV/Document terminal/TLS/server/capacity proofs are recorded separately
above. No new hosted warm/cold budget, platform or production-scale claim follows.

The first isolated experience attempt at `3717c50` exposed an implicit evidence
directory dependency in `board_query.py`. The proof now creates its own parent
directory before writing the real wire fixture. The other four attempts were
interrupted so all final lanes could run the corrected revision; no processes
remained from those interrupted checkouts. They do not count as passing evidence.
The corrected full C/C++ SDK task also passed separately, and a pinned Ruff
`F823` scan of `tests/` found no further unbound-local fixture errors. Earlier
failed clean runs remain incomplete and are not included in the final report.

## M25 local application qualification

The initial profile is trusted Linux placement and a separately compiled Zig
consumer over the [neutral installation/bootstrap contract](../contracts/APPLICATION_INSTALLATION_V1.md).
The example builds through its own manifest, imports public packages and runs
with an empty `PATH`. Installation and domain operations use public CLI commands
and exported connections; ordinary workflow steps never edit private manager
records or use realm-root credentials.

| Executed proof                      | Result                                                                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `test::server-applications`         | 98.521 s; two applications, 19 migrated rows, three Table pages, 21 paged native provisioning/activation receipts, final worker generation 9 |
| `test::server-application-faults`   | 29.221 s; exact lost spawn/rotation/send/turn/activation replies, current revocation and denied/malformed management; reserved health 1 ms   |
| `test::server-application-capacity` | 16.40 s after fixture setup; accepted input across actual ext4 ENOSPC, same receipt/PID/resource after restart                               |
| Existing `test::server-faults`      | Core lifecycle 30.18 s, bootstrap/gateway/rollback faults 13.04 s; reserved health 5.20 ms                                                   |
| Existing `test::server-capacity`    | 17.28 s; accepted console query recovered after real ENOSPC                                                                                  |

The application lifecycle proof interrupts provisioning, attaches twice without
new identities, refuses conflicting intent/declarations, incompatible replacement,
invalid receipt cursors and active-role quota overflow. Installer, domain operator,
writer and inspector remain separate. A compatible configuration replacement
preserves PID/resource/principal and migration progress while the neighboring
application and pinned neighborhood processes remain running. Worker, manager,
authority and disk-store interruption preserve accepted work. The 19-row transform
is verified against its retained source through bounded pages before explicit
write release. Replaying an old migration step does not copy another page.

The largest sampled manager high-water RSS was **28,180,480 bytes**, below the
fixture's 128 MiB ceiling; the largest current application checkpoint was
**2,847 bytes**. These are measurements for two single-role applications, not a
maximum-quota or throughput qualification. Runtime limits are explicit: at most
eight roles/sixteen resources/eight callers per declaration, configured active
application/role quotas, one 256 KiB checkpoint read, eight receipts per status
page, 64 KiB management values, finite HTTP/registration/activation deadlines,
three worker-exit restarts and joined child shutdown. Retained request/receipt
history grows on disk with unlimited retention; it is not read into a resident
collection.

The fault fixture puts the real disk authority behind an **explicit test-only**
node peer. It records accepted native bytes/receipts, drops replies, kills the
manager, and requires byte-identical retry and equal receipts before fresh root
operations. That test peer uses Python and parent-death handling; the production
manager does not. A separate schedule loses migration send and committed worker
turn replies, then verifies activation and old-key fencing. Root keys are used
only by adversarial fixture steps to revoke native rights, not by the application
workflow. Inspector resource revocation, worker revocation and installer
revocation remain effective. Twenty denied requests, malformed/foreign/oversized
values and forbidden identity headers cannot bypass authentication; health uses
its reserved request capacity.

The capacity fixture reuses M24's owned 2 GiB ext4 image inside an isolated
privileged container. It waits for **domain initialization**, pauses the data
worker, admits an input and saves its receipt outside the provider volume. A
filler leaves 4 MiB metadata headroom; a 32 MiB allocation confirms actual ENOSPC.
After releasing the filler and a preallocated 512 MiB reserve, ordinary startup
and the original command recovery file complete exactly one retained input.
No existing host block device, user installation or reference cluster is changed.

`just check`, `zig build test -Doptimize=ReleaseSafe`, standalone client tests and
independent schema/SHA-256/Ed25519 fixture checks pass. These new focused/external
tasks do not expand the ordinary hosted lanes or claim a new M10 budget sample.
The selected replacement changes configuration with the same compatible binary;
M33 must additionally qualify changed executable artifacts through installed
release packages. Other SDK hosts, maximum active quotas, local multi-role
dependency graphs and distributed placement are not qualified by this consumer.
Interface publication retains its separate M23 proof; worker readiness does not
claim a published interface or verified migration result.

The first runs exposed three corrected defects: borrowed JSON strings outliving
the response buffer, pending application root operations being recovered after
built-in activation, and old worker readiness being displayed with a new fence
generation. A generic JSON tuple needed its original array wire shape preserved.
The capacity fixture initially paused before domain initialization; it now waits
for public domain evidence. Failed schedules are not counted as passes.

## M27 local Board qualification

`just test::server-board` exercises the actual embedded executable against native
MinIO and disk Ursula. Its version-3 fixture covers both command aliases, fresh
default UI, headless initialization followed by first enablement, disabled port
preflight, exact Host/Origin checks, real JavaScript assets and machine readiness.
The generic separately compiled work-item application declares resource inspection
under declaration v2; another application's undeclared resource remains hidden.
Replacement retains IDs, resource revocation survives toggles/restart, and principal
revocation rejects UI startup without restoring grants.

The owned-failure schedules kill Board, node, Ursula and management, verify child
cleanup and retained identities/receipts, and reject missing/changed/incompatible
artifacts and conflicts with every configured listener. Explicit fault peers lose
accepted Board principal-creation and application inspection-grant responses;
recovery must replay identical signed bytes and return the same native receipt.
These peers are test infrastructure, not runtime dependencies.

`just test::server-board-package` builds the Nix local package and consumes only
its exported executable manifest. It starts from an unrelated temporary working
directory with unavailable PATH, fetches the embedded UI and authorized atlas,
forwards `--no-ui`, then resumes the same retained Board identity. The package
closure excludes Node, Python, Vite+ and pnpm. Existing M24/M25 recovery tasks now
request headless operation explicitly. `contract::check` independently verifies
the v2 inspection declaration digest; a unit fixture preserves v1 signed bytes.

Focused qualification passed after rebasing the implementation onto the gateway
host-alias changes. The Board lifecycle/revocation schedule completed in 33.37
seconds; both lost-reply schedules recovered the exact accepted request/receipt.
The Nix packaged consumer passed with a 14-path runtime closure excluding Node,
Python, Vite+ and pnpm. `just check`, `just doctor`, contract drift checks and the
headless server/application regressions passed. The rebased headless core
lifecycle took 37.26 seconds; application replacement/recovery took 122.70 seconds,
and application fault recovery took 28.40 seconds.

`just ci-clean` is running against implementation commit `e077519`. Core, growth,
experience and launcher lanes have passed; the binding lane remains in progress.
This is not yet a completed ordinary clean qualification, and it does not include
the separately selected browser or physical-capacity lanes.

Initial focused attempts exposed a port-conflict fixture needing socket reuse
after shutdown and a reply-loss assertion needing the public tagged-union shape.
One concurrent-build M24 attempt observed `AuthorityTimeout` and failed the console
status assertion. Those attempts are not counted as passes; subsequent focused
and rebased regression runs passed without weakening the assertions.

The scope is trusted local Linux x86_64, loopback shared viewers, explicit resource
grants and unlimited retained history. It does not qualify per-user login,
browser query/operator credentials, history import, an in-place older-runtime
upgrade, power loss or broader platforms. New tasks remain separately selectable;
no expanded hosted CI budget is claimed.

## M26 documentation handbook

`just transit-docs::check` checks the real Docusaurus package: Vite+ formatting
and lint, strict TypeScript, six source/reference tests and production static
rendering with broken links/anchors treated as errors. The initial site included
all 31 foundational Markdown files. The catalog includes every public guide/reference and Internals page, with
selected owning component/wire guides. Its ownership test checks full coverage
and unique routes/sources. Internals has a separate sidebar and participates in
search. A separate snapshot check rejects milestone IDs, milestone wording and
roadmap references in usage/reference page labels, routes and raw content,
including link targets and component guides. The contributor index may name
separate source sections; scientific accounts can cite scoped proof records.
Roadmap, Design and History retain separate repository indexes and stay outside
the primary catalog/search. It also checks every
Markdown wire contract, generated API reference content and exact downloadable
description source.
Those references share current concepts, guarantees and failure semantics with
users, developers and agents. API pages render operations, nested
fields, union alternatives and bounds from the checked Board/serving OpenAPI and
reactive AsyncAPI; downloaded descriptions retain their original bytes.

`just transit-docs::browser` builds and serves the actual output with Chromium.
Four checks cover desktop navigation/search/API anchors, exact downloads,
mobile menu and overflow, light/dark accessibility, and every published Mermaid
diagram, plus workload-to-performance/session navigation, code languages and
search discovery. Internals coverage includes desktop/mobile navbar entry, its
scientific standard and template, labeled search results, linked technical
accounts/diagrams and source links to the separate Roadmap/Design indexes. `TRANSIT_DOCS_BASE_URL=/handbook/ just transit-docs::browser` runs the same
proof below a path prefix. Screenshots and failures stay in
`.cache/verification/docs-browser`; the server belongs to that proof and starts
no Transit processes. Accessibility checks exercise selected pages; they are not
a manual audit of every document or an all-browser compatibility claim.

The local quickstart and first-application commands were also executed from the
published Markdown blocks: the pinned Nix bundle initialized a fresh version-2
installation, a console query returned uint64 count zero after verified completion,
and the independently compiled work-item worker installed and committed one row.
After graceful server stop and ordinary restart without `--initialize`, the same
query was resumed and the application row remained visible. The temporary server
was stopped; no existing launcher installation was modified. These are onboarding
checks, not new runtime/failure qualification or public release evidence.

`just check`, `just doctor` and `just test::reactive-descriptions` pass locally.
The latter validates the existing generated descriptions against pinned official
schemas and checks reflected-type drift. The experience lane owns the site check
on ordinary runs. Documentation-only PRs run that same check in the small `docs`
Nix shell; the aggregate CI gate rejects a skipped/failed selected job. Hosted
feedback/cost for this addition remains unmeasured. No site was published and
this work does not constitute a full ordinary `ci-clean` run.

A documentation-only clean clone of committed `20ccdd3` passed the exact CI
filtered install (`vp install --frozen-lockfile --filter rey --filter @rey/transit-docs`),
`just transit-docs::check` and all three production browser checks at `/`.
The separate `/handbook/` build and browser checks also pass, including regular
file navigation and byte equality for all three specification downloads. The
clean clone had no inherited `node_modules`, generated documentation or site
output; it reused the locked package/tool downloads and installed Chromium.
This is focused site evidence, not the full ordinary `just ci-clean` suite.

The public/internal documentation reorganization passes `just check` after the
locked workspace install, plus all three production browser checks at `/` and
`/handbook/`. The catalog now has 56 pages, including all 36 public guides and
references; internal plans, reviews and historical design are absent from site
navigation/search. The updated ownership test requires every public page and
rejects its links to internal records. Agent instructions, component entry links
and invariant owners now use the public explanations. The complete glossary and
developer workflow have public owners, with internal section pointers preserving
older references. Source validation passes 3,885 local links across 415 Markdown
files; a separate path check resolves all 114 local documentation image references.
This pass changes documentation/navigation and source pointers, not runtime
semantics. It does not rerun runtime deployment proofs, the full ordinary clean
CI suite or hosted timing. The previously executed onboarding proof remains the
basis for the unchanged runnable commands.

The capability-snapshot pass removes delivery-plan references from all 56
published pages and all 35 Markdown wire documents, including source links and
SQL grammar guidance. It replaces stale implementation-status prose with the
existing qualified capability profiles. `just check` passes with the five
source/reference tests; all three production browser checks pass at `/`, and
source validation passes 3,904 local links across 415 Markdown files. The guard
also checks generated reference text and original specification downloads.
This documentation-only pass does not rerun runtime deployment proofs or the
full ordinary clean CI suite.

The interface-language pass replaces maturity labels and broad readiness caveats
with direct operations, platform requirements, compatibility rules and concrete
limits across the handbook and wire contracts. `just check` passes after the
locked workspace install. The final site-only format/type/test/build run and all
three browser checks pass after updating the homepage and shared footer. Source
validation passes 3,900 links across 415 Markdown files. A separate built-output
audit checks every HTML page and all 56 search entries for the removed maturity
wording. No runtime integration or deployment proof was rerun for this prose change.

After rebasing the handbook onto `7f08401`, the quickstart and application guides
use version-3 server configuration with supervised Board, matching the local
bundle's executable manifest. The CLI reference includes `--no-ui`, and public
guides describe Board's separate identity and explicit application inspection
grants. `just check` passes after the locked workspace install; the final focused
site check and all three production browser checks at `/` also pass. Source
validation passes 3,915 links across 416 Markdown files. These checks cover
documentation integration; the revised version-3 onboarding commands, runtime
deployment proofs and full ordinary clean CI suite were not rerun in this pass.

### Workload architecture and examples — 2026-09-29

The public workload/performance references and example gallery pass `just check`
after the locked workspace install, including 174 CLI cases and six documentation
content tests. The added excerpt check matches the Python, TypeScript, Rust and
Zig snippets to contiguous lines of their executable owners, allowing common
indentation only. The final focused site format/lint/type/content checks pass.
All four production browser checks pass at `/` and `/handbook/`, including
language rendering, gallery navigation into measured costs and planned session
semantics, and search discovery. Source validation resolves 4,052 local links
across 424 Markdown files before this ledger entry.

The featured source also passes Python's strict mypy configuration (21 files),
the TypeScript example package's `tsc --noEmit`, Rust's `cargo check --locked
--offline` with the built native libraries, and `zig build examples`, under the
pinned Nix tools. The snippets reuse existing applications: their full SDK,
Document, connector and query integration schedules are linked rather than
rerun for this documentation change. No performance experiment is rerun or new
runtime speedup established. Fresh interactive sessions/cancel-on-exit and bulk
storage improvements remain explicitly planned; no new wire/runtime behavior,
site deployment or full clean CI run is claimed.

### Interface navigation and SQL statement reference — 2026-09-29

The interface navigation and fourteen new SQL reference pages pass `just check`
after the locked frontend install. Existing routes stay stable. The four
production browser checks pass at both `/` and `/handbook/`, covering top-level
interface categories, SELECT/DDL/application navigation, statement search,
mobile navigation, generated descriptions/downloads, diagrams and accessibility.
The workload navigation assertion now follows the implemented interactive-session
reference instead of expecting its earlier unimplemented wording.

`just test::sql-grammar` parses 37 published examples and requires coverage of
every statement rule in `TransitExtensions.g4` plus its historical-read fragment.
The existing 103 PostgreSQL/ANTLR AST cases, 17 syntax exclusions and 13 extension
cases also pass. Administrative examples establish syntax only, not executable
DDL or effects. `just test::application-grammar` passes the complete published
application program through the independent parser and real offline compiler,
then checks its canonical model round-trip alongside the existing rejection
and schema cases. These changes add no runtime SQL capability or new recovery
guarantee; those remain under their owning service proofs.

### Public Internals and separated engineering records

The documentation reorganization based on `b79a8a8` publishes 12 Internals pages:
nine consolidated technical accounts, an overview, the scientific standard and a
writing template. The complete site has 86 pages. Delivery plans live in
`docs/roadmap/`, UI/UX reviews in `docs/design/`, earlier technical records in
`docs/history/` and reserved decision guidance in `docs/decisions/`. These source
records remain linked without becoming individual catalog/search entries.

Executed locally on Linux x86_64 with the pinned Nix development shell and frozen
workspace installation:

- `just check` passed after consolidation: core/contract checks, Zig units,
  177 CLI diagnostic cases, frontend checks and the documentation production build.
- `just transit-docs::check` passed for the final structure as part of `just check`:
  formatting/lint, strict types, six content tests and broken-link/anchor checking.
- `nix develop --command bash -c 'cd apps/transit-docs && vp exec playwright test'`
  passed all four checks against the production root build in 14.4 seconds.
  Coverage includes Internals desktop/mobile navigation, labeled search results,
  standard/template and technical-account links, separate Roadmap/Design source
  links, every published Mermaid diagram and the existing interface checks.
- `python3 -B tests/docs.py` resolved 4,359 local links across 455 Markdown files.
  A source-path audit found retained destinations for all 249 original engineering
  files. All 114 review images resolve and retain their original bytes.
- `TRANSIT_DOCS_BASE_URL=/handbook/ just transit-docs::browser` rebuilt the
  consolidated site and passed the same four browser checks in 13.6 seconds.

The scientific accounts cite existing runtime evidence and add no runtime
qualification. The checks above establish documentation structure and selected
rendering/interaction behavior, not scientific correctness of every claim.
No deployment proof, hosted-cost measurement, live publication or `just ci-clean`
run is claimed for this uncommitted worktree.

## CLI diagnostic qualification

`just test::cli-diagnostics` runs the actual `transit` executable against invalid
invocations and owned temporary files, without a provider. The same check runs
within `just check` as a separately named core check. It verifies concise error
transcripts, command-specific and application-operation help, required/duplicate/
inapplicable options, application subcommands, query-shell arity, explicit console
environment precedence, configuration JSON parser coordinates and semantic fields,
missing executables/credentials, occupied listener coordinates, privacy, escaped
and bounded paths, exit codes, and stdout/stderr separation. It also checks that
invalid input creates no installation. This is CLI failure-presentation evidence;
server lifecycle and durable console recovery retain their separate proofs above.

The earlier labeled-diagnostic qualification at `720ced6` passed **95 real
command cases** with the pinned Zig 0.17 compiler, `just check` and the server
lifecycle proof in **28.60 seconds** excluding compilation. That historical run
checked separate cause and outer-exhaustion identifiers.

The concise-output implementation passes **125 real command cases**, including
exact short option errors, useful file/field/listener coordinates, escaped paths,
untranslated executable failures, and offline application-operation help. Help
still rejects duplicate, unknown and incomplete supplied options before effects.
`just check` passes, including diagnostic rendering checks for unknown cause and
outer failure, exact retry guidance, interruption without cancellation, and
restart exhaustion after child exit or listener conflict. The handbook production
build passes. `just test::server` passes in **29.13 seconds** excluding compilation,
including independent console output, manager/worker recovery and a final
exhaustion message that identifies the underlying child failure and role.

`just test::console table` also passes with the concise formatter: **177.62 seconds**
for the combined proof, including **99.20 seconds** of console checks, excluding
compilation. It covers real PTY interaction, private-CA TLS and trust/hostname
refusal, recovery-lock exclusion, killed-session exact retry, current denial,
interrupted waits and bounded machine output. This run qualifies the shared
presentation change on Table; it does not add a new source or transport profile.

`just test::server-faults` passes with the same formatter: the core lifecycle took
**30.20 seconds** and the additional bootstrap/gateway/rollback schedules took
**17.50 seconds**, excluding compilation. The checks retain native denial and
machine-status distinctions, bounded control under stalled data, exact recovery
of persisted bootstrap intent, and refusal of configuration/artifact drift and
provider history below the recorded authority observation.

`just test::server-board` passes its preflight, incompatible-Board, lifecycle and
interrupted-provisioning schedules. The lifecycle portion took **32.63 seconds**;
it covers defaults/toggles, embedded assets, application replacement, revoked
inspection access and owned failures. Both inspection-principal and application
lost-reply/manager-death schedules recover the exact saved request and receipt.
No committed-HEAD `ci-clean` run is claimed for this working-tree qualification.

## Unified CLI and conventional configuration

The unified console removes slash aliases and manual namespace/upload/result
controls from its primary interface. Real command fixtures exercise `-c`, `-f`,
streamed stdin and final statements without semicolons, first-error stopping,
dot-only commands, lossless pages and table rendering. A lost reply persists the
original signed request before recovery; `.resume` retries that exact request
and prints the same query's result. Cancellation settles the original pending
request and sends cancellation without uploading the remaining bundle. A new
query cannot replace unresolved intent. The PTY and TLS fixtures retain editing,
completion, current denial, private-CA trust, signal handling and output bounds.

The working-tree checks recorded so far are:

| Check                                                                                             | Executed outcome                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just test::cli-diagnostics`                                                                      | 160 real command cases passed: partial defaults, project/home selection, explicit file selection and missing-file refusal, malformed YAML/JSON, nesting bounds, typed environment precedence, rc merge/relative paths, flag precedence, adjacent executable lookup before PATH and explicit executable overrides |
| `just test::console table`                                                                        | Passed in 301.26 s including 222.10 s of console checks; PTY cold/warm completion 1080.16/344.63 ms; 16,756,736-byte terminal RSS high-water                                                                                                                                                                     |
| `just test::console kv`                                                                           | Passed in 415.14 s including 342.07 s of console checks; PTY cold/warm completion 600.78/590.67 ms; 17,444,864-byte terminal RSS high-water                                                                                                                                                                      |
| `just test::console document`                                                                     | Passed in 827.56 s including 253.45 s of console checks; PTY cold/warm completion 322.35/69.79 ms; 17,195,008-byte terminal RSS high-water                                                                                                                                                                       |
| `just test::public-query`                                                                         | Compatibility Table v1 dot commands, exact retry, cancellation, fenced recovery and current read denial passed                                                                                                                                                                                                   |
| `zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source=table -Dunified-shell=true` | Compatibility unified shell and native recovery passed in 148.18 s                                                                                                                                                                                                                                               |
| `just test::server-faults`                                                                        | Core lifecycle 31.05 s; bootstrap/gateway/rollback schedules 18.16 s; independent automatic console query, exact provisioning recovery and identity/rollback refusal passed                                                                                                                                      |
| `just test::server-capacity`                                                                      | Accepted automatic query, real ext4 ENOSPC, finite control/shutdown and recovery of the original query passed in 19.62 s                                                                                                                                                                                         |
| `just check`                                                                                      | Passed core/contracts, 160 CLI cases, frontend checks/tests and the production documentation build                                                                                                                                                                                                               |
| `just doctor`                                                                                     | Passed; the existing absent `~/.cargo/bin` PATH entry was reported by kubectl's plugin listing                                                                                                                                                                                                                   |

The first offline package build exposed a stale frontend dependency-store hash
that omitted dependencies already present in the workspace lockfile. Refreshing
that fixed-output hash allowed the offline Board asset build to pass without
changing package versions or the lockfile. The initial packaged defaults proof
passed first creation, bare restart, Board and automatic SQL with an unavailable
PATH. A subsequent run qualifies adjacent lookup with a copied CLI, neighboring
provider links and no executable manifest.

Earlier in-progress console runs exposed stale diagnostic expectations and an
undersized output-pressure fixture after help became shorter. KV and Document runs also
reached the initial one-minute wait budget. The completion budget is now five
minutes, accommodating the real finite source workers. Completed result streaming
now uses finite page/per-request/output bounds separately from the budget for
waiting on completion. The PTY result wait now follows the longer finite query wait rather than the
old receipt-response deadline. Those failed runs are not counted as passed evidence.
The final package run passes with a copied CLI, adjacent executables, no manifest
and unavailable PATH, including initialization/restart, Board, automatic SQL and
retained identity. The extended defaults proof also restarts using equivalent
partial YAML and whole-object/nested environment overrides, preserving the same
normalized configuration and provisioning identities. The default console now derives its endpoint from server topology and its scoped
identity from retained installation state, without a generated connection file.
The diagnostics cover this path, YAML connections, mode-only rc files, changed
gateway defaults and environment precedence, and incomplete-installation refusal.
The lifecycle and physical-capacity proofs above were repeated after removing the
generated console file. Configuration uses YAML while rc files remain dot-command
scripts. No committed-HEAD `ci-clean` or push is claimed by these checks.

The packaged follow-up passes bare-console automatic SQL without either
`console.json` or `console.yaml`, along with adjacent executable discovery,
Board toggles and retained identity. Its ports are now reserved independently
and supplied through the environment, avoiding interference with a developer's
running default server. Equivalent YAML and nested environment settings preserve
the same normalized configuration. The earlier fixed-port run collided with an
already-running server and is not counted as a pass.

Submitted input now remains in terminal scrollback before results. A shared
controlling PTY running `SELECT * FROM items;` against the actual local server
checks the echoed statement, bordered empty result and zero-row count. The
separate-output PTY checks multiline transcripts and the continuation prompt
without contaminating JSON stdout.

The final `just test::server` run passes in **49.35 s**, including the shared
terminal transcript check. `just test::server-applications` passes in **89.067 s**
with YAML management, declaration and replacement input, equivalent YAML/JSON
caller exports, retained identities and migration recovery. Its manager RSS
high-water is 28,164,096 bytes and its largest checkpoint is 2867 bytes. YAML
initialization frames use the native custom codec through the same token decoder
as JSON. The earlier value-decoder failure and the run interrupted by rebuilding
a pinned executable are not counted as passes; the fixture now copies its CLI
before startup so concurrent builds cannot change retained artifact identity.
The final diagnostics report 160 passing cases, and `just check` passes.

### Console settings presentation

The `.show` presentation follow-up passes `just check` and
`zig build test-cli-lifecycle` with the pinned Zig 0.17 compiler. The renderer
checks exact name/colon alignment, automatic selection, boolean `on`/`off`, enum
values and escaped controls. `just test::cli-diagnostics` passes **163 real
command cases**, including settings in both query result modes, home/project and
explicit rc origins, environment and flag precedence, interactive-command origins
in batch input, automatic topology defaults and escaped connection filenames.

`just test::console table` passes in **328.22 s** excluding compilation, including
**241.03 s** of console checks over 41 rows on disk Ursula. Settings inspection
preserves the exact uncertain recovery record and sends no native mutation or
retry. A following SQL statement still emits verified JSON. The controlling PTY
checks `.show` in both modes, `.mode` and `.connect` origins, unchanged saved work,
and the existing editing, denial, signal and TLS schedules. Terminal RSS high-water
is **17,854,464 bytes** under the fixture's 64 MiB ceiling.

`just test::server` passes its core lifecycle in **48.16 s** excluding compilation,
including automatic `(automatic)` settings in shared terminal scrollback before
an independent SQL result. These runs qualify settings presentation; they do not
add a timing setting or establish query latency targets. Clean-checkout CI is
reported separately against the committed revision.

The rebase of native Arrow rendering and timing onto the aligned settings change
passes `just check` with **177 CLI cases** and `zig build test-cli-lifecycle`.
`.show` retains aligned text in both result modes and adds `timing` as `on`/`off`
plus its origin. The merged batch check verifies settings text followed by a
complete JSON query result, with timing confined to stderr; PTY checks preserve
timing and its origin across `.connect`. `just test::console table` passes in
**295.35 s**, including **215.79 s** of console checks, 41 rows/six segments,
saved-intent recovery, current denial, cancellation, TLS and terminal interruption.
Terminal RSS high-water is **13,688,832 bytes**. These are functional integration
results, not a new query performance comparison.

### Native table rendering and query timing

The console renders verified native Arrow batches directly, avoiding the previous
Arrow-to-hex-to-Arrow conversion before presentation. Table output has box borders,
column names/types, numeric alignment and a final row count. JSON retains its
lossless page envelope. `.timing` is off by default, can be set in rc scripts or
interactively, survives connection changes, and emits attempt/phase wall time
only to stderr.

`just check` passes with 163 CLI cases. The additional cases cover merged timing
preferences, interactive overrides and invalid rc values. Native renderer units
pass for all six scalar types, 64-bit extrema, escaping and all five cell states,
including conflict identities. `just test::console table` passes in **300.73 s**,
including **219.79 s** of console checks: saved-intent recovery, six result segments,
current denial, automatic SQL, separate timing/JSON output, PTY connection changes,
TLS trust failures and bounded output. PTY cold/warm completion measures
1079.45/359.18 ms with 13,574,144-byte RSS high-water. These are executed checks,
not a new latency guarantee. The renderer units were repeated after extending
coverage to boolean, binary and conflict cells and passed.

The latency investigation uses isolated empty local Tables, disk Ursula/MinIO,
eight resident authority pages and frozen executable copies. Initial probes
inadvertently combined an optimized CLI with a Debug node; the node's
SHA-256 exactly matches a rebuilt Debug artifact and the developer's running
node. Those observations must not be reported as ReleaseSafe engine performance:

- Repeated table queries took 62.48 and 82.55 s; JSON took 82.60 s and COUNT took
  78.95 s. An empty result and changing output format did not explain the delay.
- A console-only HTTP counting proxy measured 63.32 s: preparation 144 ms,
  compilation 338 ms, submission/advancement 13,122 ms, wait 47,367 ms,
  fetch/verification 2336 ms, render below 1 ms and persistence 16 ms. It counted
  513 native calls, mostly point reads. The proxy did not count worker/courier
  traffic and its timings include queues and transport, not just engine work.
- Fresh Debug-node installations with 64 versus eight cached pages took
  20.82 versus 62.85 s, consuming 16.86 versus 52.52 node CPU seconds. This proves
  cache sensitivity in that build, not a cache-size fix or optimized performance.
  No cache budget, authorization gate or durability behavior was changed.

`just test::console-latency` builds all three Transit executables in ReleaseSafe,
freezes and hashes them, and measures repeated table/JSON/COUNT queries with node
CPU and client phase times. It uses its own installation and listeners, checks
timing on failed SQL, and imposes no latency threshold. It does not touch an
existing installation or restart a developer's server. Render time cannot explain
the observed long waits; repeated signed reads, polling, page decoding and digest
verification remain the relevant paths for further profiling.

The consistently ReleaseSafe run passes with first/repeated table queries at
**13.64/18.46 s**, JSON at **19.72 s**, and COUNT at **17.65 s**. The first table
attempt spends 23 ms preparing, 48 ms compiling, 2919 ms submitting/advancing,
10,204 ms waiting, 430 ms fetching/verifying, below 1 ms rendering and 11 ms in
separately measured persistence. Authority CPU is 5.98 s for that query and
8.37/8.39/7.78 s for the remaining queries. Thus Debug execution amplifies the
problem, but optimized empty queries remain slow. This comparison does not
attribute the improvement to the renderer. The server transcript/lifecycle check
also passes with the native tables in **47.42 s**. No latency optimization to the
query engine or storage is claimed by this change.

A controlled ReleaseSafe cache probe with the same executables and separate fresh
installations measures **13.95 s / 6.10 node CPU s** with eight resident pages and
**5.73 s / 1.94 node CPU s** with 64. This confirms substantial page-cache sensitivity
after removing the Debug-build confounder. Even the larger diagnostic cache leaves
seconds of native work for an empty result; the shipped eight-page budget remains
unchanged. No other qualification or build ran concurrently with these final
measurements; the developer's existing server remained running throughout.

The final ReleaseSafe console-only proxy probe takes **13.79 s** and counts
**382 native requests**: 110 resource reads, 218 entry reads (one non-success
response), eight capability reads, four sends, 38 process reads and four batched
entry reads. Resource/entry calls alone account for 7.95 s of proxy-observed
wall time. Rendering again measures below 1 ms. These counts exclude all worker
and courier requests, so they are a lower bound on system request amplification.
The next performance work should distinguish redundant status polling, repeated
authority/data page reads and page verification cost before selecting batching,
cache-policy or scheduling changes. Existing current-authority and complete-result
checks must remain covered by denial and recovery proofs.

The timing command requires `on` or `off`. CLI diagnostics pass **174 real command
cases**, including missing/blank, invalid and extra timing arguments in both
output modes, tab-separated settings, batch stopping and no stdout contamination.
Offline controlling-PTY checks exercise the real console in table and JSON modes:
`Usage: .timing on|off` leaves an enabled setting intact, the prompt accepts `.show`
and `.timing off` afterward, and terminal attributes are restored on exit.
`just check` passes with these cases, and the focused CLI diagnostics pass again
after keeping timing-argument errors out of query-recovery diagnostics.

### Native query latency: whole-node attribution

Leased snapshot foundation: `nix develop --command zig build test` and
`zig build transit-node` pass with independent signing vectors, malformed response
coverage, stable old reads across writes, fresh cuts, zero journal advancement,
repeated close, restart invalidation, current resource revocation, principal
replacement, retirement, per-principal admission, lease renewal and hard expiry.
These deterministic tests do not establish the console integration or physical
page reclamation safety; append-only pages remain required.

The console latency runner also supports `--repeat`, `--age-queries` and
`--instrument`. On 2026-09-29, the owned instrumented empty-Table run completed
in 71.303 s, first output 71.295 s, sampled console RSS 14,241,792 bytes.
It observed 1,800 native attempts (including background workers), 51 command
attempts and 50,366 provider attempts. A separate three-second idle window had
101 native attempts. The Python proxies materially increase cost and polling;
these numbers are attribution/control evidence, not a speed comparison with
the earlier uninstrumented baseline. Failed proxy experiments and a concurrent
build race are excluded. The script retains failed fixtures and cleans up only
its own processes. Populated-source and restart/cache matrix coverage remains
to be added with interactive-session qualification.

A subsequent isolated disk-backed profile counts all native callers, including
source/requester workers and the courier. ReleaseSafe builds of the same node and
query host are held fixed; the profiling node adds per-request page counter deltas
and monotonic timers around provider page requests, page decoding and backend
page verification. Diagnostics contain operation names, numeric actor identities,
status, durations and counters, without credentials, keys or values. Temporary
LRU and bounded-range experiments use a detached checkout and are not part of the
shipped engine. Raw traces, source patches, the driver and binary hashes are
retained locally under `.cache/transit-latency/` with
`deep-profile-manifest.json`. These are diagnostic samples, not latency targets.

The local server sets **100 ms** worker/courier idle intervals, overriding the
query host executable's standalone 20 ms default. For a first empty Table SELECT
with the shipped eight-page cache and 100 ms intervals, the profile measures
**12.96 s**: prepare 21 ms, compile 50 ms, submit 2,951 ms, wait 9,547 ms, fetch
373 ms, render below 1 ms and persist 10 ms. It observes:

- **1,120 native requests**, of which 384 are console requests, 367 source-worker,
  153 requester-worker, 203 courier and 13 manager requests.
- **31,466 page-cache misses** and 22,815 hits; every miss reads a separate
  immutable page record through the Ursula HTTP client.
- **51 durable native updates**, including four upload sends, 17 view opens,
  17 turns and 13 deliveries. The source takes 12 turns and the requester five.
- **1,471 staged pages**, about 1.84 MB of attempted page JSON payload for an empty
  result. These exclude root-journal payloads, HTTP framing and provider WAL/
  replication amplification. All cache/polling experiments stage the same number
  of pages.
- **12.58 s inside the serialized node handlers**, including 9.16 s of page
  provider I/O, 0.58 s decoding fetched pages and 0.39 s of backend fetch digest
  checks. The remaining handler time includes signature checks, tree work, the
  core's additional digest checks and root-journal I/O; it is not attributed to
  any one of those operations by this probe.

Within the query window, source-worker step spans total 8.756 s while their native
client request spans total 8.701 s. The approximately 55 ms remainder includes
local bookkeeping and query computation; this empty-query observation does not
establish execution costs for populated tables or more complex SQL. The timings
and whole-node counts locate the delay in native orchestration and storage.

Grouping the same recorded request counters by mutation gives **1,069 read
requests / 8.63 handler seconds** and **51 update requests / 3.94 handler seconds**.
These times include each operation's checks and I/O and partition the 12.58-second
handler total; they must not be added to the overlapping 9.16-second page-I/O
measurement. The page cache misses 58% of its 54,281 loads, and the 51 updates
average 28.8 staged pages each. These are derived attributions of the existing
trace, not a new benchmark or a predicted speedup from removing an operation.

Controlled first-query experiments, each on a fresh installation:

| Page cache | Worker/courier idle interval | Diagnostic change                        | Elapsed | Page misses |
| ---------: | ---------------------------: | ---------------------------------------- | ------: | ----------: |
|          8 |                       100 ms | Baseline                                 | 12.96 s |      31,466 |
|          8 |                        20 ms | Faster polling                           | 15.52 s |      36,604 |
|         64 |                        20 ms | Larger cache                             |  5.50 s |         624 |
|          8 |                       200 ms | Slower polling                           | 15.67 s |      31,642 |
|          8 |                       100 ms | LRU replacement                          | 12.50 s |      27,397 |
|          8 |                       100 ms | Stop scans at the catalog range boundary | 11.99 s |      24,548 |

LRU and range-bounded scans reduce reads but do not resolve multi-second empty
queries. These single elapsed samples are subject to host variance and do not
qualify either experimental engine change. Slower polling primarily helps idle
work: at 100 ms, three idle seconds use 0.24 node CPU seconds and cause 114 native
requests/924 page misses; at 20 ms these rise to 0.97 CPU seconds and 467 requests/
3,832 misses. At 200 ms they fall to 0.12 CPU seconds and 61 requests/481 misses,
but query completion takes longer. Polling must be evaluated alongside wake-up
latency and durable work, not reduced blindly.

The running developer node's executable hash still matches the earlier Debug
control. Its 86.9-second reported query is consistent with the already measured
Debug amplification; an optimized CLI does not replace an already running Debug
node. The developer installation was neither queried nor restarted by the probes.

The benchmark now supports reproducible fixture-only controls and idle CPU
measurement, building to its own output prefix:

```sh
just test::console-latency --single
just test::console-latency --single --resident-pages 64
just test::console-latency --single --worker-interval-ms 200
```

It hashes and freezes the selected binaries, applies controls only to its own
child configurations, verifies the result and joins all owned processes. The
next changes should reduce repeated native metadata/point reads and intermediate
page staging within bounded operations, and reduce result-publication turns
where the existing atomic mutation budget permits. Current-authority checks,
retained versions, exact receipts and final result verification remain required.

The extended benchmark passes against the uninstrumented ReleaseSafe binaries
both without overrides (**14.01 s**, 6.12 node CPU seconds) and with the fixture-only
64-page/100-ms controls (**5.69 s**, 1.91 node CPU seconds). Both return the verified
empty typed table; render time is below 1 ms. Idle node CPU is 0.24 and 0.14 seconds
respectively over three seconds. Binary hashes match between runs. No build or
other qualification ran concurrently with these measurements; the developer's
existing server remained running. These controls reproduce the cache sensitivity
without relying on the profiling node.

`just check` passes after adding the benchmark controls and attribution notes,
including the 174 CLI cases, Zig unit checks, generated contracts, frontend checks,
public documentation validation and site build. The diagnostic range experiment
also passed the standalone core's existing unit suite in its isolated checkout;
no engine change is promoted on that evidence alone.

### Fresh interactive console execution

On 2026-09-29, `just test::interactive-query` passes for a 41-row Table,
41-row KV prefix and 12-row Document list on owned disk Ursula/MinIO. Every
statement has a distinct session ID, retains its source basis, streams bounded
frames and marks only terminal coverage complete. SELECT, COUNT, LIMIT, empty
output and table/JSON rendering make zero durable update requests. SIGINT during
a gated source read releases the lease without output; resource revocation after
a prefix prevents completion and a restored grant permits a new statement.
The Document fixture takes about 501 seconds including provisioning; its two
measured SELECTs take 0.469 and 0.439 seconds with 82 native requests. Provisioning
is excluded from query timing and remains costly.

`just test::interactive-query --source table --rows 257 --age 128` also passes:
retained state exceeds the source batch, with unrelated durable history before
the read. An empty Table with `--resident-pages 0` passes, including the added
closed-output-consumer case: failed output closes its snapshot. These are finite
scenarios, not load percentiles. The populated fixture counts requests through a
proxy without query workers; its timings are not default-server timings.

The separate default-server runner, without proxies or concurrent qualification,
returns eight empty SELECT/COUNT samples in 121–146 ms, first SELECT 131 ms and
first stdout 128 ms. It uses the default cache and background workers. The
executable hashes and per-phase data are emitted by `tests/console_latency.py`.
`--execution durable` selects the old lifecycle explicitly; `--age-queries`
always uses that lifecycle to create actual durable history.

`just check` passes after the console switch, including unit tests, CLI
configuration/diagnostics, generated-contract checks and the public site build.
`zig build test-cli-lifecycle` passes. Later bounded-workspace/LIMIT-zero changes
are exercised by the ReleaseSafe fixture and empty-cache control above.
Physical reclamation remains unsupported. Deterministic snapshot tests cover
lease expiry/restart/epoch and concurrent source changes; these console proofs
do not establish a multi-node session service or host power-loss behavior.

### Bounded tree mutations and immutable page batches

On 2026-09-29, the unit suite passes bounded range termination, an independent
257-key map across 160 mixed mutation batches, retained cuts,
no-op/duplicate/budget handling and failure or acknowledgement loss at every
staging step. Packed-cache tests cover LRU eviction, disabled cache and recency
counter wrap. Per-frame receipt tests reject failed, missing, duplicate, malformed
and incomplete coordinates before modifying returned references.

The real-disk commands pass in ReleaseSafe:

```sh
zig build test-pages -Doptimize=ReleaseSafe -- --keys 256 --cache 2 --mutation-batch 1
zig build test-pages -Doptimize=ReleaseSafe -- --keys 256 --cache 2 --mutation-batch 8
zig build test-pages -Doptimize=ReleaseSafe -- --cold-s3 --keys 1024 --cache 2
just test::storage
just test::service
just test::growing-service-release
```

The primitive checks every retained value after SIGKILL/restart and root-only
checkpoint/trim. The HTTP fault peer forwards actual accepted immutable batches,
then drops the whole reply, corrupts a coordinate or substitutes a failed frame.
No references are returned, no staging retry occurs, authority remains unchanged
and both retained roots still read. The first trial incorrectly expected batch
coordinates in top-level headers; it failed closed with `InvalidAppendReceipt`.
That trial is excluded. The corrected per-frame JSON decoder and all three fault
modes pass. Page locators remain format 2, with mixed single and batch records.

With one binary and two cache slots, the 256-key write/verification phase stages
1,960 pages for single updates versus 330 for batches, makes 5,820 versus 2,617
page HTTP attempts and encodes 4,099,816 versus 1,252,826 attempted payload bytes.
Elapsed samples overlapped other qualification and are not used as performance
comparisons. The artifacts include binary hash, revision, dirty status and
per-phase counters under `.cache/verification/pages-*-batch*.json`.

The growing service suite preserves exact receipts after lost replies and disk
restart, current read denial, retirement, maintenance snapshot/page reply loss,
trim timeout, growing Station recovery, multi-turn query publication and explicit
quota/control reserve behavior. The generic storage and legacy service suites
also pass. These checks do not authorize page GC or establish host power-loss
or horizontal-throughput guarantees.

The earlier interactive change also passes `just test::console table`, including
durable recovery, controlling-PTY input/editing/interrupt behavior, command/file/
stdin stopping rules and private-CA/hostname checks. The complete run took about
290 seconds including provisioning and query worker/node/store restart.

### Interactive Table access paths

The unit suite compares every primary-key and value-column comparison against
independent full predicate evaluation over 43 keys, including int64 minimum,
maximum, absent keys and a nullable value. Equality and tail-range access use one
source batch; unsupported access predicates retain full scanning and denial is
preserved. `just test::interactive-query --source table --rows 257 --age 128`
passes with the storage batches and Table seeks, including equality, both range
directions, COUNT with equality, maximum-key exhaustion, empty LIMIT, distinct
sessions, interrupted reads, closed output and denial after a prefix.
Full scans make 174 native attempts; each selected key/range query makes 14 and
no durable updates. The elapsed samples overlap qualification and are not SLOs.

### Final interactive performance qualification

`just check` passes with the final production changes, including source checks,
unit tests, CLI diagnostics, generated contracts, Board tests and the Docusaurus
build. Additional snapshot tests then pass in `zig build test`: all 64 slots
across eight principals, refusal without eviction, owner-only close, admission
after release, clock rollback, uncertain deadlines and expiry during read
materialization without renewal or authority writes.

The final `just test::interactive-query` passes all three sources with the
bounded adapter workspace and cancellation diagnostic. SIGINT returns 130 and
"query cancelled", with no durable resume advice. Output failure releases its
snapshot. Document SELECT takes 0.318–0.344 seconds with 82 reads; LIMIT zero
avoids traversal and takes 0.082 seconds with 26 reads. The whole Document proof
includes provisioning and takes 373.63 seconds. These are diagnostic observations.

`just test::server` passes in 16.57 seconds, including transcript rendering,
default discovery, a fresh query after supervisor/node/provider replacement,
identity preservation and child cleanup. Its first attempt still expected
`.resume` in the default console and failed; that obsolete expectation was
replaced with a fresh SELECT. Explicit durable resume remains qualified by the
separate `just test::console table` proof. The closed-page provider's 64-key batch
fixture also passes all restart/checkpoint/trim phases.

A final default-server measurement with `--repeat 2 --age-queries 2` uses the
ReleaseSafe executables, default cache and background workers, no proxies and no
concurrent qualification. Eight SELECT/COUNT table/JSON samples take 159–196 ms.
A separate `--single --instrument` run has 14 console native reads, 10 background
reads, zero command attempts and 188 provider attempts during the query. Its
three-second idle interval has 108 native and 553 provider attempts. These are
transport counts, not distinct commits, and proxy elapsed time is kept separate.

The final public documentation link check and diff whitespace check pass.
No existing developer installation was restarted or reinitialized by these tests.

### Console query interruption and prompt reuse

The issue #19 regression fixtures add controlling-PTY checks for Ctrl-C before
submission, during uncertain upload, during source work and during paged result
display or `.resume`. They exercise repeated signals, discarded trailing SQL,
completed-query races, exact retry after an unconfirmed cancellation and a fresh
statement at the same prompt. Batch interruption checks exit 130. The default
interactive fixture separately checks snapshot release and a fresh statement
without durable requests or recovery state.

Before rebasing onto interactive execution, the durable interruption cases and
terminal/TLS checks passed in two local `just test::console table` attempts. The
enclosing proof failed in its final retained-version cleanup: the expanded
history required paging, then an explicit fixed read position with the cursor.
The corrected cleanup and rebased behavior are pending qualification; those
partial runs are not full-suite passes. Earlier clean-checkout runs were stopped
when their tested revisions were superseded. Hosted CI did not start because of
the GitHub account billing/spending limit. Current PR validation reports the
revision and result of subsequent runs.

### Combined reads, control caching and bounded transport

The next read-path revision adds canonical `snapshot_read` fixtures and generated
native schema coverage. `just contract::check` and `just test::unit` pass. Core
tests distinguish the captured source from final current metadata, allow an
injected unrelated publication during materialization, reject current revocation,
retain a slot after failed finish validation, and enforce byte-limited continuation
and expiry. Immutable control-cache tests cover scan eviction pressure, changed
roots, unpublished candidates and retained roots; cached bytes cannot grant access.

`just test::serving-http` passes with three exchanges on one socket, advertised
closure at the configured cap and health progress between exchanges. The existing
deadline, cancellation/join, partial header/body and capacity cases still pass.
`just test::server-faults` passes the real growing node/gateway, including socket
reuse, fresh sessions after an idle connection expires, stalled body isolation,
false control-hint rejection, full data admission with control parsing and signed
denial still available, interrupted provisioning and rollback refusal. Its final
lifecycle/fault runs take 17.05/16.85 seconds. Health under data pressure takes
2.91 ms in that run; this is a sample, not a latency bound.

The transport change also passes `just test::service` for legacy close-after-reply
authorities and `just test::growing-service-release` for exact retry, malformed
replies, revocation, resource reads, current/retained versions, node/provider
restart, maintenance uncertainty, quota reserve and durable Station/query recovery.
The latter includes a 41-row, 9,984-byte durable result through staging, sealing,
publication, partial consumption and retained acknowledgement. No transport retry
is introduced. Growing authority work remains serialized; these finite proofs
do not establish per-principal fairness or offered-load throughput.

### Document chunk prefetch and request ceilings

The Station unit suite now publishes a nine-chunk index node through ordinary
bounded turns, reads it in two prefetch batches and checks the decoded value.
Corrupt prefetched bytes fail the Publication digest; unavailable batches and
current denial also fail, including denial on a verified node-cache hit.
`just check` passes with these tests and the transport changes.

The Document-only interactive fixture passes with 30 native requests for a full
12-row scan, 29 for `LIMIT 3`, and three for `LIMIT 0`, with zero durable updates.
Its full-scan completion samples are 106–171 ms including the counting proxy;
provisioning and failure cases take 260.74 seconds overall. Other qualification
ran concurrently, so these are not isolated latency measurements. Fresh sessions,
bounded complete/incomplete framing, cancellation, output failure and
revocation after a prefix pass. The runner enforces native request ceilings for
all source fixtures, independently of elapsed time, to catch amplification
regressions without selecting a host-dependent latency threshold.

### Read-path performance qualification

The final `just test::interactive-query` passes Table, KV and Document with the
request ceilings enabled. The 41-row Table/KV scans each use eight native reads;
small/LIMIT-zero reads use three. The Document rerun uses 30 full-scan reads and
takes 261.50 seconds including provisioning and fault cases. A separate
`--source table --rows 257 --age 128` run passes with 39 full-scan reads and three
for equality/range reads, compared with the earlier 174 and 14. All SELECTs issue
zero durable updates; fixture setup is counted separately.

`just test::console-latency --repeat 2` runs without concurrent qualification or
proxies. Its eight empty SELECT/COUNT table/JSON samples complete in 14.98–18.18 ms
including CLI startup. The first SELECT completes in 16.75 ms, with first output
at 15.17 ms; console phases total 11–14 ms. Sampled console RSS is 13–16 MB, node
RSS 23–24 MB. The same fixture's first query before this round took 91.10 ms;
one baseline and eight new samples do not establish tail latency or attribute
the speedup to individual changes. The historical user installation is not a
controlled comparison.

A separate `--single --instrument` run uses the same executable hashes and no
concurrent qualification. Three console reads plus one background read cause
11 provider attempts (10 HEAD, one GET), with zero updates. Three idle seconds
contain 16 native and 60 provider attempts; uninstrumented idle node CPU is
0.03 seconds. The historical profile recorded 108 native/553 provider idle
attempts. Proxy timing is not mixed into the uninstrumented measurements.

The final CLI SHA-256 is
`e6609d87b8d52e4c2e46bec806889428ed849bdd9149279a0e0ce7bc35057e63`,
node `09acf58ff4093a1709f0c4c353837da9ceba4a039e66a5b90a837b6b4f17a9af`,
and query host `c6de4c3320a5179add330cc81689fbc1edc226ae89d8f7458c7cc8815728c699`.
All use pinned ReleaseSafe builds, disk Ursula and MinIO. The runner freezes its
executables and uses owned temporary state. No running developer installation
is restarted or reinitialized.

`just test::console-latency --single --execution durable` also passes with the
new local idle backoff. It runs alongside Document provisioning, so its elapsed
time is not used as a controlled durable-performance result. `just check` passes
the final implementation: unit tests, diagnostics, generated contracts, frontend
checks and the production documentation build. Later edits only explain measured
behavior, compatibility and remaining scope; `just transit-docs::check` passes
again for those edits. No push is performed, so the pre-push `just ci-clean` gate
is not run.

## SQL reference operation coverage

The SQL reference now indexes unsupported INSERT/UPDATE/DELETE operations and
separates types, functions/operators and streaming/effect boundaries. The
[M36 gap inventory](../docs/roadmap/M36.md) records proposed contracts and proof
gates; it does not establish executable mutation or continuous SQL support.

Working-tree validation with the pinned Nix development shell:

- `just check` passes, including native/contract/unit checks, 174 CLI diagnostic
  cases, frontend checks and the production documentation build. The site runs
  six ownership/content checks and validates its published links and anchors.
- `just test::sql-grammar` passes: 37 public SQL examples parse, all statement
  rules and the historical fragment are covered, 103 SELECT ASTs agree with
  libpg_query, 17 syntax exclusions and 13 administrative examples pass, and
  ANTLR reports zero diagnostics. This establishes syntax coverage only.

No grammar, compiler or runtime behavior changes in this revision. These checks
do not qualify any proposed mutation, maintained-query or effect-binding profile.

## Query performance reproduction

From the repository's pinned development environment:

```sh
nix develop
just test::console-latency --single
just test::console-latency --single --resident-pages 64
just test::console-latency --single --worker-interval-ms 200
just test::console-latency --single --repeat 3 --age-queries 5
just test::console-latency --single --instrument
just test::console-latency --single --execution durable
just test::interactive-query
just test::interactive-query --source table --rows 257 --age 128
just test::interactive-query --source table --resident-pages 0
just test::pages --keys 256 --cache 2 --mutation-batch 1
just test::pages --keys 256 --cache 2 --mutation-batch 8
just test::pages-cold --keys 1024 --cache 2
```

Interpret the measurements using the [performance reference](../docs/reference/performance.md#reproduce-and-compare).
These are reproduction commands, not a record of a new execution.

## Public command documentation

The published handbook assumes the complete local bundle is installed and invokes
`transit` through `PATH`. Source setup and proof commands remain with repository
tooling owners. The launcher overview retains `/guides/launchers`; its full
runbook remains outside the site catalog and search. This follows the public
documentation scope in [M26](../docs/roadmap/M26.md).

Executed for this documentation change:

- `just check` passed the native/contract/unit checks, 174 CLI diagnostic cases,
  frontend checks/tests and production documentation build.
- `just transit-docs::check` passed: formatting/lint, strict TypeScript, seven
  content/reference tests and the production build. The content guard rejects
  Nix/Just commands and path-qualified Transit invocations in published code.
- `python3 -B tests/docs.py` passed 4,334 local links across 453 Markdown files.
- `nix develop --command bash -c 'cd apps/transit-docs && vp exec playwright test'`
  passed all four production browser checks at `/`, covering desktop/mobile
  navigation, search, generated downloads, diagrams and accessibility.
- The built search index was checked for repository command invocations and
  local Transit executable paths; none remain across its 92 entries.

These checks validate documentation and rendering. They do not rerun bundle
builds, application installation, provider recovery or deployment qualification.

### Explicit source aliases

The `feat/sql-source-aliases` continuation implements explicit `FROM source AS
alias` through the shared Zig parser, compiler and scoped completion owner.
Fuze and query package tests pass. Equivalent aliased/unaliased queries produce
identical canonical plans for row, state-test, count, sum and restricted-derived
forms. Checks reject hidden original qualifiers, escaped inner aliases, unknown
actual sources and duplicate columns. Completion fixtures keep the declared
source authority separate from alias spelling, including quoted case and typed
literal hints.

Eight additional independent completion fixtures expose and correct a missing
dot continuation after a source qualifier, including an alias that also names a
column, quoted case, hidden/foreign sources and an already qualified column.
The first run fails the original-source continuation case (63/64 package tests
pass); after the correction all 64 query package tests pass. Logs are
`/tmp/transit-sql-source-aliases-completion-before.log` and
`/tmp/transit-sql-source-aliases-completion-after.log`. This changes suggestions,
not source authority, parsing or the saved-plan format.

`just test::sql` passes **113** Zig/ANTLR/PostgreSQL SELECT AST comparisons,
**92** real plans and independent paged Arrow checks, and **19** grammar
exclusions. The unified fixture checks **28** independent results at three source
kind bases and eight page widths, plus nine explicit failure cases. Mutation and
declaration fixtures also pass unchanged. The log is
`/tmp/transit-sql-source-aliases-sql.log`. These are compiler/engine proofs;
installed native/port/ten-SDK inspection and SQL-shell recovery checks are
separate.

Full `just check` passes on the initial source tree and again at rebased
`512ebcb4`, including the completion correction. The latter log is
`/tmp/transit-sql-source-aliases-rebased-check.log`. The first installed attempt
stops before provisioning because this fresh worktree has no built Python wheel;
no caller case ran. The failed log is
`/tmp/transit-sql-source-aliases-installed.log`. All standalone Zig and ten SDK
package builds subsequently pass. The installed run passes KV and Table in
**386.41 s / 374.20 s**, including inspection agreement across thirteen
native/port/SDK callers and SQL-shell admission, exact retry, source/requester/
node/store recovery, current denial, retained rows and joined cleanup. Document
qualification also passes in **1726.68 s**, including **1465.98 s** provisioning:
twelve rows/two segments/9,880 bytes, with its existing 64 authority pages and
8 MiB hot store. The entire three-source command exits successfully. The log is
`/tmp/transit-sql-source-aliases-installed-built.log`; its frozen binaries precede
the rebase and completion-only correction. KV/Table retain eight authority pages;
these different fixture profiles do not establish comparable native latency.

Committed-head `just ci-clean --lane core --work-root /var/tmp` passes all
**22 tasks in 1309.02 s** at `34b0b96f`. The report is
`.cache/ci/clean/34b0b96f175e-transit-ci-ocwpgt5q/core.meta.json`; the log is
`/tmp/transit-sql-source-aliases-ci-clean-core.log`. Rebase onto merged #44 at
`b8b224ce` preserves all three original commits unchanged. Clean growth at
rebased `512ebcb4` includes #44's catalog read reduction and the corrected
snapshot fixture, but fails in query delivery at the unchanged 180-second
deadline (**592.17 s** task / **752.95 s** lane). Three tasks pass and seventeen
are unrun, including the corrected fixture. The earlier failed attempts remain
failed; this result does not establish their cause. The log is
`/tmp/transit-sql-source-aliases-ci-clean-growth.log`, with its failure checkout
retained at `/var/tmp/transit-ci-0sct7l0m`.

Clean experience at final alias head `93c3832b` passes five tasks, then fails
Board's cancellation-result observation with HTTP **503 Unavailable**
(**93.33 s** task / **261.17 s** lane). The final Station task is unrun. The log
is `/tmp/transit-sql-source-aliases-ci-clean-experience.log`, with its failure
checkout retained at `/var/tmp/transit-ci-knqo9ipr`. Neither lane is passed;
the implementation is published as tracking draft PR #47.

The declarative benchmark adds an aliased selected-count component beside its
unaliased equivalent; all **29 components** and nine rejection probes pass with
257 rows, three rows per page and five samples. Compile medians are **0.582 /
0.707 microseconds** for unaliased/aliased SQL; execution medians are **76.816 /
75.703 microseconds**. The canonical plans and independently checked outputs
agree. These samples overlap other qualification and do not establish an
execution speedup or native latency. Full workloads remain blocked. The report
is `/tmp/transit-sql-source-aliases-benchmark.json`, with dirty source based on
`d5541301` and exact manifest/harness/binary provenance. The benchmark runner's
negative controls, documentation links and verification inventory checks pass.

### Typed output-name plan checkpoint

The `feat/sql-output-aliases` continuation introduces owned names by output
position and a mandatory definition in `FZP1`. Five independent Python byte
fixtures cover renamed rows, repeated inputs with distinct names, named count
and sum, and default names. Fuze tests compare exact bytes and output schemas,
retain input basis/schema identity, and reject old/foreign definitions,
colliding names, hidden slots and malformed owned names. Decoded names remain
owned when the encoded input is changed. Fuze package tests pass after migrating
two limit-field corruption probes to the replacement wire offsets.
The full unit task passes after two inline signing digests are recomputed with
independent canonical JSON/SHA-256. The first broader run passes 493/494 tests
and exposes that stale expected digest; it remains distinct from the corrected
pass in `/tmp/transit-sql-output-aliases-unit-fixed.log`.

A source-behavior regression publishes an integrity-valid bundle with a foreign
plan definition, then verifies one terminal rejection reply to the original peer
and correlation without retaining a source version. The first run fails because
the new decoder error escapes the disposition mapping (64/65 tests pass).
Classifying incompatible-plan and invalid-output-name errors as failed requests
makes all 65 query-package tests pass. The before/after logs are
`/tmp/transit-sql-output-aliases-rejection-before.log` and
`/tmp/transit-sql-output-aliases-rejection-after.log`. This is an in-memory
behavior proof; it does not replace installed or disk-backed recovery evidence.

The shared native definition, generated protocol/installation/ABI/host/browser
resources, neutral bundles and signing fixtures are replaced together. Native
fixtures use independent SHA-256 and OpenSSL signatures; rejection of the actual
retired definition remains explicit. `just test::sql` passes its existing 113
parser comparisons, 92 plan/Arrow checks, 28 three-source/eight-page-width cases,
and mutation/declaration checks under the new plan encoding. This checkpoint
does not yet enable output-alias SQL syntax or qualify installed caller recovery
and performance under the replacement definition. Its logs are
`/tmp/transit-sql-output-aliases-model-test-fixed.log`,
`/tmp/transit-sql-output-aliases-wire-sql.log` and
`/tmp/transit-sql-output-aliases-fixtures.log`.

### SQL output-alias lowering checkpoint

The shared parser, reference grammar and compiler accept explicit `AS` names on
row positions and count/sum results. Restricted derived aggregates resolve
renamed inner columns back to original source indices. Predicates continue to
resolve original source names. Owned-name, scope, duplicate-output, identifier
bound, completion and EXPLAIN fixtures exercise this behavior without granting
source access or widening query execution budgets.

`just test::sql` passes **134** Zig/ANTLR/PostgreSQL AST comparisons, **105**
independently encoded plans and Arrow results, and **44** six-type/five-state
result cases across three source bases and eight page widths. The latter includes
renamed negative zero, full-width uint64, binary, null/missing/error/conflict
cells, repeated inputs, empty results and named aggregates; **17** cases check
explicit compile/execution failures. All **56** public SQL examples parse.
The Fuze/query package tests, existing mutation and declaration checks also pass
in `/tmp/transit-sql-output-aliases-syntax-final-focused.log`.

The initial checks expose two test assumptions: result types were inferred from
output names, and a repeated identical projection expected `DuplicateColumn`
instead of the existing `DuplicateProjection`. The independent checker now
derives types from input positions and aggregate semantics; the precise error
expectation is corrected. Initial failures remain in
`/tmp/transit-sql-output-aliases-parser-expanded-unit.log` and
`/tmp/transit-sql-output-aliases-parser-sql.log`; the corrected SQL pass is in
`/tmp/transit-sql-output-aliases-parser-sql-fixed.log`.

The first full `just check` exposes stale browser inspection rules that required
unique input projections and fixed output names. The browser now validates
matching widths, distinct valid output names and aggregate types independently
of aliases. Shared native fixtures include repeated renamed inputs, named count
and renamed derived sum; malformed duplicate outputs, widths and count types
still reject. The failed full run is
`/tmp/transit-sql-output-aliases-syntax-check.log` and the focused browser check is
`/tmp/transit-sql-output-aliases-browser-inspection.log`.
The corrected full `just check` passes, including generated-contract checks,
Zig tests, browser validation and the documentation build, in
`/tmp/transit-sql-output-aliases-syntax-check-fixed.log`.

This compiler checkpoint does not establish neutral-plan/SDK output-name round
trips, installed recovery, performance or committed-head clean qualification.
Those remain required before publishing the output-alias increment.

### Neutral and installed SDK output-name checkpoint

The neutral plan now preserves optional names by output position through
decode/prepare and workspace compiled metadata. A regression compiles named
SQL, decodes its bundle through the neutral API, then prepares it through the
actual ABI codec and compares exact bytes and publication identity. Before the
fix, 12/13 binding tests pass and this regression exposes lost names and a
changed digest; afterward all pass. Ownership checks mutate the original name
buffers, and malformed names or vectors with the wrong width reject. Logs are
`/tmp/transit-sql-output-aliases-neutral-before.log` and
`/tmp/transit-sql-output-aliases-neutral-after.log`.

All ten public SDK plan APIs expose these names. The neutral/ABI cutover replaces
the shared native definition with
`00177e103bcb1a8208abd6958d79c9f3f471caf62d4a0c87957072356fd28214`;
generated contracts, host/browser resources and independent signed fixtures move
together. Both the preceding native definition and the retired main
definition remain explicit rejection cases. The plan-definition identifier and
`FZP1` layout from the preceding checkpoint are unchanged.

The shared native/port codec suite passes **52 cases**. All eight SDK package
build tasks pass, then `python3 -B tests/sdk_unified.py` installs and executes
all **ten language consumers** in a fresh temporary directory. Each consumer
compares default and named bundles against independent bytes for KV, Table and
Document, retaining six-type/five-state Arrow and malformed-input checks. The
new `just bindings::unified-codecs` task composes those build tasks and this
standalone proof. These are pure codec checks: no signed authority caller or
disk recovery is exercised. Logs are
`/tmp/transit-sql-output-aliases-neutral-unit.log`,
`/tmp/transit-sql-output-aliases-sdk-build.log` and
`/tmp/transit-sql-output-aliases-installed-codecs.log`.

Full `just check` passes, including generated-contract drift, runtime units,
**21** query-browser tests and the documentation build. Python mypy passes;
`just test::sql` retains the preceding **134/105/44/17/56** checks, and
`just bindings::node-check` passes **39 tests**. Logs are
`/tmp/transit-sql-output-aliases-neutral-check.log`,
`/tmp/transit-sql-output-aliases-neutral-mypy.log` and
`/tmp/transit-sql-output-aliases-neutral-sql-node.log`.
Initial generation attempts fail on fixture ordering and a formatting-wrapper
invocation; their logs remain in
`/tmp/transit-sql-output-aliases-neutral-generate.log` and
`/tmp/transit-sql-output-aliases-neutral-generate-fixed.log`. Fixtures are regenerated before dependent
schemas, formatting uses `vp fmt`, and the subsequent full check passes.

Installed authority/CLI named-schema checks, exact retry, current denial,
disk-backed recovery, performance measurements and committed-HEAD clean lanes
remain required. Earlier source-alias failures remain separate evidence.

### Installed named-output recovery checkpoint

The disk-backed unified-query schedule now uses an explicit `Result` output
name in the Zig bundle and all ten SDK constructors. Document's other output
positions retain their default names. Independently decoded Arrow must carry
the exact renamed schema and original values. The SQL shell uses a quoted
output alias, saves its original bundle/request across shell exit, and checks
names on each returned page. Inspection includes named count and repeated
inputs with distinct names, both under current access and subsequent denial.

The first installed attempt fails before upload because its new inspection
fixture expects mixed case from an unquoted SQL identifier. Quoting `Result`
corrects the fixture without changing compiler case rules. That failure remains
in `/tmp/transit-sql-output-aliases-installed-recovery.log`.

The corrected schedule passes KV named-plan preparation and SQL inspection
across **13 native/port/installed caller variants**, then exact signed upload
retry and worker/node/disk-store restart after staging a segment. After restart,
the cold store refuses writes with **507 `XMinioStorageFull`**: its shared 1.8 TB
backing filesystem has only 17 GB available. Ursula reaches its existing 8 MiB
hot-store boundary and returns `ColdBackpressure`; native staging reports 503.
No storage quota or operation deadline is increased. This is incomplete recovery
evidence: completed results, post-restart disclosure denial, CLI execution and
the Table/Document schedules are not qualified by this run.
The run exits unsuccessfully at the unchanged **900-second** post-restart
deadline, with namespace 1 / correlation 86 still `admitted` and no manifest.
Table and Document are unrun. The fixture's normal cleanup completes; the
separately retained log snapshot is diagnostic evidence, not a recoverable
copy of the store.

The corrected log is
`/tmp/transit-sql-output-aliases-installed-recovery-fixed.log`. A private log
snapshot is retained at `/var/tmp/transit-sql-output-aliases-capacity-evidence`.
The six frozen runtime artifact hashes are in
`/tmp/transit-sql-output-aliases-installed-artifacts.json`; their runtime source
is `4e9a8bca`, before the later compiler optimization. The unchanged limits and
remaining gates still apply after capacity is restored.

Full `just check` passes on the subsequent optimized source tree, including
generated-contract drift, runtime units, browser validation and the documentation
build, in `/tmp/transit-sql-output-aliases-optimized-check.log`. This does not
complete the storage-dependent installed schedule or committed-HEAD clean lanes.

### Output-alias integration with located diagnostics and console writes

The continuation rebases without conflicts onto `2704c153`, including #49's
wire-access investigation and #50's located diagnostics, authorized console
write routes and canonical saved-write validation. Parser locations, diagnostic
redaction and the existing mutation/catalog execution owners remain in use.
The PostgreSQL/MySQL milestone is a proposal, not an implemented listener.

Real CLI regression cases expose stale duplicate-projection advice that forbids
repeated inputs. Shared local/remote diagnostics now describe distinct output
names and explicit `AS`; invalid output-name shapes also receive binding advice.
Malformed alias syntax retains its exact location. The bounded remote rendering
tests pass, including output-name failures; runtime errors still keep their
owning authority/recovery disposition.

The initial CLI regression fails in
`/tmp/transit-sql-output-aliases-rebased-diagnostics-before.log`. The next run
exposes a new fixture using `id` against its configured `key` column; that fixture
is corrected without changing binding rules, and its failure remains in
`/tmp/transit-sql-output-aliases-rebased-focused.log`. The corrected **422 real
CLI cases** pass, including the socket trap that rejects any authority contact
for invalid SQL. Fuze package tests and the full independent SQL proof pass:
134 ASTs, 105 plan/Arrow cases, 44 results, 17 failures and 56 public examples.
Logs are `/tmp/transit-sql-output-aliases-rebased-fuze.log` and
`/tmp/transit-sql-output-aliases-rebased-focused-fixed.log`.
Full `just check` also passes on the rebased integration tree in
`/tmp/transit-sql-output-aliases-rebased-check.log`; final local documentation
links pass in `/tmp/transit-sql-output-aliases-rebased-docs.log`.

The expression reference and grammar inventory now consistently describe output
names and repeated inputs. Earlier measurements and installed artifacts retain
their original pre-rebase source identities; the rebase does not qualify new
installed write routes or resolve the recorded cold-store capacity failure.

### Output aliases with the combined local Table writer

The output-alias continuation rebases onto `65c9c669`, retaining the combined
local Table query/writer and automatic console write route from `a0a9375e`.
The rebase preserves author dates and resolves definition/generated-resource
conflicts by generating a combined current native definition:
`1b790ef9b226fa9d5ee27622dd7fbfd51cb56eb764574594c0a792d4170bf0a2`,
the SHA-256 of
`transit.native.v1.local-writer.sql-output-name-callers.2026-09-30`.
The output-name `FZP1` definition stays unchanged. Schemas, ABI resources, browser
validators and independent SHA-256/OpenSSL signing fixtures are regenerated.
Explicit regressions reject alias-only, local-writer-only and intermediate
definitions. No installation history is converted or reset.

The first full check fails one protocol fixture because the independently
recomputed entries-query digest omitted the existing `resource` and `revision`
null fields. Correcting the expected canonical bytes preserves production
signing. The failed log is
`/tmp/transit-sql-output-aliases-local-writer-check.log`; full `just check` and
`just test::sql` then pass in
`/tmp/transit-sql-output-aliases-local-writer-check-fixed.log`.

That combined command's subsequent `just test::server` fails before its local
console transcript: the bindings shell's `TRANSIT_SQL_TOOLS` build setting leaks
into automatic server configuration and correctly rejects as unknown. Evidence
remains at `/var/tmp/transit-server-proof-i9no6k0w`. A focused run removes only
the shell's `TRANSIT_SQL_TOOLS` and `TRANSIT_GSON_JAR` variables, retaining the
same pinned tools and unchanged fixture. It passes the real console write,
readiness, current-denial and restart schedule in **36.51 s**; its log is
`/tmp/transit-sql-output-aliases-local-writer-server.log`. This local-server proof
does not complete the separate installed all-source recovery or clean gates.

## SQL performance iteration

### Output-name component coverage

The declarative benchmark includes four additional output-name components:
named count, named sum over a renamed derived input, renamed row projection,
and repeated inputs with distinct names. Its independent manifest declares
result types by position; the oracle no longer infers signedness from names.
SQLite supplies expected names/values and PyArrow checks complete output.

All **33 components and nine rejection probes** pass for both 257 rows in
three-row pages and zero rows, including quoted mixed-case output names.
Reports are `/tmp/transit-sql-output-aliases-benchmark-oracle-fixed.json` and
`/tmp/transit-sql-output-aliases-benchmark-empty.json`. These correctness runs
use one sample, one execution and ten compilations; they are not performance
comparisons. The eight benchmark-runner negative checks and local documentation
links also pass. Full TPC workloads remain blocked.
Reports identify dirty source based on `4e9a8bca`, with exact binary,
manifest, harness and fixture hashes; runtime code is unchanged from that commit.

The first run fails on a fixture's unquoted mixed-case alias: Transit correctly
folds it to lowercase while SQLite preserves case. The fixture now uses quoted
identifiers when expecting mixed case. That failed report remains at
`/tmp/transit-sql-output-aliases-benchmark-oracle.json`; the corrected passes do
not overwrite it. Logs are
`/tmp/transit-sql-output-aliases-benchmark-build.log` and
`/tmp/transit-sql-output-aliases-benchmark-oracles-fixed.log`.

### Direct-query compilation measurement

Direct queries now use the already validated source schema instead of building
and validating an identity input projection. Derived inputs still build and
validate their projected scope; all plans retain final validation. Fuze's
standalone tests and `just test::sql` pass, including 105 independently encoded
plans and 44 paged result cases. Logs are
`/tmp/transit-sql-output-aliases-compile-optimization-unit.log` and
`/tmp/transit-sql-output-aliases-compile-optimization-check.log`.

The [paired raw report](benchmarks/results/2026-10-01-output-aliases.json)
records control/candidate order **A B B A A B**, five samples per run, one warm-up,
8192 rows in eight-row pages, ten executions and 2000 compilations per sample.
Both frozen binaries pass all 33 components and nine rejection probes in each
run, with identical verified output cells and Arrow segment hashes. The report
retains raw durations, fixture/harness/compiler/binary identities, source plus
the exact candidate patch, host load and result evidence. The control is runtime
source `7e6e2905` (unchanged from `4e9a8bca`); the candidate adds only the recorded
compiler change.

Medians across the three per-build run medians, in microseconds:

| Compilation component | Control | Candidate |
| --- | ---: | ---: |
| Selected count | 1.073 | 0.725 |
| Selected count with output name | 1.172 | 0.828 |
| Row projection | 1.527 | 1.188 |
| Renamed row projection | 1.747 | 1.412 |
| Named sum over derived input | 1.841 | 1.723 |

The direct named cases show about 19–29% less compilation time in these samples.
Execution timings overlap; no execution speedup is established. The derived
path retains its validation work, so its small observed difference is not
attributed to a removed operation. This shared host also runs installed recovery;
the measurements do not establish isolated-host, native, transport or storage
latency. The installed recovery run uses frozen pre-optimization binaries and
does not independently qualify the later compiler change. The subsequent full
check passes as recorded above; committed-HEAD clean lanes remain outstanding.

### Finite SQL probe

`just test::sql-benchmark` builds a ReleaseSafe public-package consumer and records
five independent process samples after one warm-up. Four compile cases each run
10,000 times; count and sum each consume 8,192 rows in eight-row pages, 100 times.
The aggregate probe validates completion and row coverage, and sum's exact value.
Independent Arrow correctness remains in `just test::sql`.

The JSON report at `.cache/verification/sql/benchmark.json` records raw durations,
per-case median/range, source revision, dirty state, compiler, host and executable
SHA-256. `--samples N` and `--output PATH` select repetitions and report location.
The compiler uses a reset 16 KiB arena; execution uses the existing 4 MiB Arrow
workspace and 64 KiB output buffer. These are supplied budgets, not measured RSS.
There is no timing assertion. Run controls without competing builds; compare the
same cases and optimization mode. These measurements exclude source adapters,
authorization, network, storage, result publication and rendering.

The wider projection iteration passes `just test::sql`: 104 Zig/ANTLR/PostgreSQL
AST comparisons, 91 Table plans, 16 unified results across three source bases
and eight page widths, plus nine unified rejection/failure cases. The added
cases cover eight-column reversed output, a wider derived input, duplicates,
unknown names and a ninth column. Canonical plans and result layouts are unchanged.
`just check` also passes for this iteration, including generated contract parity,
shared native/port codecs, CLI diagnostics, frontend checks and the documentation
build. Five local performance samples put compilation at 0.393–0.897 µs per
statement across the four cases and 8,192-row count/sum at 0.772/0.788 ms.
A documentation build overlapped this sample, so it is not a controlled speedup
claim; the raw report is `.cache/verification/sql/projection.json`.

The typed-filter iteration passes `just test::sql` (24 unified results across
three source bases and eight page widths) and `just test::unit`. New unit cases
check exact state tags, canonical plan agreement, full uint64 range, signed zero
through the plan codec, malformed/non-finite literals and type mismatches. Cursor
fixtures cover numeric operators, typed literals and all five state suggestions.
`just check` and `just test::interactive-query --source table` pass. The real
console selects 41 values and zero missing/type-error/conflict keys with eight
native read attempts per full scan and no durable updates; the same fixture
checks cancellation, fresh cuts, complete framing and current denial. Individual
new-predicate samples took 32–39 ms with sampled console RSS of 16.2–16.4 MiB;
these are local observations, not latency percentiles. An initial optimized build
failed on duplicate Arrow C objects; reusing the root Fuze dependency in the
benchmark build fixed it before the successful fixture run.

The aggregate-copy iteration skips row projection materialization for count/sum;
row validation, source-order matching, overflow, cancellation and checkpoint
validation remain on the same path. `just test::sql` and `just test::unit` pass.
Nine alternating ReleaseSafe control/candidate samples over 8,192 rows measured
count at 0.776/0.753 ms and sum at 0.788/0.765 ms (about 2.9% lower medians).
A second nine-pair run measured 1.037/0.903 ms and 0.970/0.894 ms with overlapping
ranges and substantial variation in unchanged compiler cases. These local runs
establish reduced copying and intact results, not a reliable deployment speedup.
Both controls use source `c8583767`; frozen binary hashes, candidate diff and raw
samples are in `.cache/verification/sql/aggregate-comparison.json` and
`.cache/verification/sql/aggregate-paired.json`.

For an alternating comparison, preserve the baseline executable, then run:

```sh
just test::sql-benchmark --samples 9 --control /path/to/frozen-probe \
  --control-revision BASE_COMMIT --output .cache/verification/sql/comparison.json
```

The runner rejects mismatched case/workload shapes, alternates process order and
retains both sets of samples and executable hashes. Use the actual baseline
revision and a frozen probe built with the same optimization and toolchain.

### Scoped SQL inspection iteration

The inspection change adds shared Fuze parsing, validated output schemas and the
query owner's `DESCRIBE`, `SHOW TABLES` and `EXPLAIN SELECT` operations. Before
rebasing onto the protocol-consolidation revision, `just check` (including the
full docs build), `just test::unit` and `just test::sql` pass: 104 SELECT ASTs, 16 syntax exclusions, 14 extensions,
44 documentation examples, 91 executable Table fixtures and 24 unified results
across three source bases and eight page widths. Neutral inspection fixtures
cover operator order, output types, literal redaction, exact names, full-width
limits/policy revisions, empty KV listings, initial/final denial and reduced
final budgets. Browser fixtures consume the same JSON and reject impossible
operator order, duplicate projections, overflow and foreign Table names.

`just test::interactive-query` completes Table and KV cases against disk Ursula
with 41 rows. Each of the three inspection statements uses five native reads,
zero snapshots and zero durable writes. Table wall times are 15.1–21.0 ms and
KV times 16.6–17.7 ms, including process startup; sampled console peak RSS is
8.4–9.4 MiB. Revocation returns no metadata. Existing finite-query fresh-cut,
cancellation and current-denial checks pass for both kinds. The Document run is
stopped during provisioning to apply the user's requested protocol rebase; it
is incomplete and establishes no Document execution evidence for inspection.

Five pure benchmark samples record compile medians 0.45–0.97 microseconds and
8192-row count/sum medians 0.789/0.808 ms. The raw report records dirty source
state and the executable digest; these are local observations, not a paired
performance improvement claim. All of this evidence predates the protocol
rebase and must be rechecked on the consolidated implementation.

### SQL integration after protocol consolidation

The SQL branch is rebased onto `3ea81aaa`, retaining the consolidated native
contract definition and the removal of the older Fuze compiler/executor.
`Unified.Sql`, `Unified.Plan`, `Unified.Codec` and `Unified.Stream` remain the
single lowering/execution path; generated ABI/browser resources are regenerated
from the merged Zig types. The duplicate-projection fixture now expects the
current compiler's `DuplicateProjection`, instead of the removed Table
compiler's width error.

`just check`, the independent SQL proof and a further `just test::unit` pass.
The SQL proof covers 104 AST cases, 86 executable current plans, 16 syntax
exclusions, 14 extensions, 44 documentation examples and 24 independent unified
results across three source bases and eight page widths. Rebuilt Table/KV
runtime inspection again uses five reads, no snapshots and no durable writes;
revocation and the existing interactive controls pass. Individual inspection
wall times are 16.9–19.5 ms in this run. The Document fixture also completes:
12 rows, 14 native reads per inspection, no snapshots or durable writes and
current denial without output. DESCRIBE, SHOW and EXPLAIN take 50.25, 34.98 and
35.12 ms respectively, including console startup; sampled peak RSS is 10.3 MiB.
The Document fixture including provisioning and existing interactive checks
takes 299.69 s. These are single-run observations, not comparative speedup claims.

`just bindings::node-check` initially fails in this fresh worktree because
Station imports the client package's `dist` exports, which the task only
checked with `--noEmit`. The task now builds that direct dependency first.
The standalone check then passes strict types, formatting/lint and all ten
Node handler/ownership tests. This is a task-dependency correction, not a
substitute for installed-SDK runtime qualification.

### Installed SQL inspection callers

Python sync/async `inspect_sql` and TypeScript `inspectSql` expose owned typed
description, Table-list and explanation results through the shared native owner.
Python type checking and `just bindings::node-check` pass. After rebuilding the
installed wheels/tarballs, `zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node -Dunified-source=table` passes the disk-backed recovery
schedule in 62.05 s: 41 rows, six segments, eight resident authority pages and
an 8 MiB hot store. All five native/port/installed callers agree on inspection
details, full-width limits, output types and redacted literals without query
admission; current revocation and permanent source retirement reject disclosure.
The existing frozen retry, worker/node/store restart and released-pin checks pass.

The first run reaches retirement but fails an incomplete assertion: typed SDKs
preserve the authority's `StateResourceExpired` code, while native results also
carry the mapped `ResourceUnavailable` error. The assertion now accepts that
specific retirement rejection; no production error translation is changed.
Other language SDKs and installed KV/Document inspection are not covered by
this run.

### Current Document metadata batching

`UnifiedClient` shares the current metadata key selection between inspection and
interactive snapshots. Document description batches policy, lifecycle head and
accepted revision records at one current resource revision, then uses the same
`UnifiedSource.checkCurrent` checks as before. The reader caches protocol support,
never permissions or source state.

`just test::unit` passes, including current batch checks for exact Document
identity, missing requested keys, access denial, reclaimed history and permanent
retirement. `just test::interactive-query` passes all three source kinds. Each
inspection now requires exactly five native requests, enforced by the fixture:
one capability read plus source/requester reads before and after resolution.
The earlier Document baseline used 14 requests. No snapshots or writes occur;
current denial, bounded results, fresh cuts and cancellation remain verified.

Document DESCRIBE/SHOW/EXPLAIN wall times are 27.75/16.03/17.35 ms, with sampled
peak RSS 9.5–10.2 MiB; the full Document fixture takes 304.08 s. The corresponding
earlier statement times were 50.25/34.98/35.12 ms. These separate local runs
establish the nine-request reduction, not a paired latency or memory claim.

### Ruby and Rust SQL inspection

The Ruby and Rust packages add typed inspection over the same native operation.
Ruby syntax checks and Rust formatting/type checks pass. Rebuilt installed
gems/crates participate with Python sync/async, TypeScript, native and port
callers in `zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node,ruby,rust`. KV and Table complete the full disk-backed
schedule in 113.60 and 226.46 s respectively. Seven callers agree on description,
listing, count schema, comparison redaction, all/state predicate variants and
zero/full-width limits. Revocation and permanent retirement reject inspection
and results; frozen upload retry and worker/node/store recovery pass.

Two pre-existing negative codec fixtures incorrectly select decoder version 1;
they now select unsupported version 2. An earlier clean Rust build exhausts
shared `/tmp`, so the successful KV/Table run uses a dedicated disk temporary
directory outside the workspace. Document setup then receives HTTP 503 from the
cold-store bucket creation before provisioning. Document is not passed by this
run and requires its own continuation. These fixture timings include concurrent
host load and are not performance comparisons.

### Java and .NET SQL inspection

Rebuilt JAR and NuGet packages expose immutable inspection details through their
existing bounded future/task workers. Installed consumers compile with warnings
as errors. `zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=java,dotnet` completes KV and Table in 76.10 and 81.29 s: four
native/port/SDK callers agree on the same metadata and predicate cases, reject
revoked and retired disclosure, and preserve the full signed recovery schedule.
The Java test adapter now treats an omitted cursor as no cursor, allowing the
existing final retirement probe to reach the public SDK. The Document continuation
also passes: 12 rows, two segments, 64 resident authority pages, an 8 MiB hot
store and the same four-caller inspection/denial/recovery checks. Provisioning
takes 1409.61 s and the complete Document fixture takes 1562.99 s under concurrent
host load. These are fixture costs, not query latency or improvement claims.

### C and C++ SQL inspection

`just bindings::c-build` compiles the independent archives, C11/C++17 examples
and C++ ownership checks. The public C result contains bounded inline metadata
with no borrowed pointers; C++ returns owned strings, vectors and variants.
`zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=c,cpp
-Dunified-source=table` passes in 159.85 s, including four-caller metadata
agreement, predicate variants, redaction, zero/full-width limits, zeroed C error
output, current denial, permanent retirement and the existing disk recovery
schedule. The test adapters normalize public typed results through a shared
fixture printer; they do not invoke the raw inspection action. KV and Document
installed coverage remain outstanding for this increment.

### Erlang and Elixir SQL inspection

`just bindings::beam-build` compiles the OTP applications and Elixir structs.
`zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=erlang,elixir
-Dunified-source=table` passes in 157.89 s. The installed adapters use public
records/structs and normalize their results for comparison with native and port
callers. The same description/list/plan, redaction, state/limit, current denial,
retirement and signed disk recovery checks pass. Atom conversion uses fixed
allowlists. The controller now handles omitted page cursors for the final
retirement probe. KV/Document installed coverage remains outstanding.

### Bounded application-owned Table mutations

The shared lexer/parser and typed Fuze compiler accept literal INSERT and
primary-key UPDATE/DELETE. Station applies the validated plan within an explicitly
supplied private writer turn. This increment does not add public admission or a
query-client mutation route. Typed validation and SQL use the same three-row,
exact-type and duplicate-key rules; no native/storage definition changes.

`just test::unit` passes, including atomic proposal rollback after a later duplicate
or exhausted budget, missing/same-value affected counts, full-width keys, all four
Table value types, cross-resource/schema rejection and sticky read failure after
an earlier row change. `just test::sql` passes its existing 104 SELECT ASTs,
86 current plans and 24 unified results across three bases/eight page widths.
The new corpus adds 24 ANTLR/Postgres mutation AST comparisons and 31 independent
storage-byte/outcome or rejection cases. All 49 public SQL examples parse. These
private-turn fixtures do not establish native mutation admission, disk recovery,
current revocation or language-SDK mutation coverage; those remain required.

The ReleaseSafe performance probe now includes 10,000 compilations each of a
three-row insert, key update and key delete, with five independent process samples.
Their median costs are 1.081, 0.627 and 0.447 microseconds respectively. The
independent outcome probe observes at most nine private point reads for three-row
insertion and five for an existing-row update. This is a baseline for compiler
and helper work, excluding authority, network and disk. Raw samples, executable
hash, dirty-source flag and compiler identity remain in the generated report;
no end-to-end performance improvement is inferred.

`just check` passes, including the production documentation build; a further
`just test::unit` passes after the 220-byte literal boundary cases are added.
The first broad check exposes a catalog omission in the rebased CI consolidation:
`bindings::test` remains an invariant owner but was removed from lane membership.
It is now listed as an external aggregate, preserving the once-per-lane SDK run.

### Avoid repeated mutation selection

After the initial mutation baseline, the Station helper uses `Table.upsert` only
after finding the existing row in the same private view. It retains descriptor,
type and write validation without repeating the existence lookup. The independent
oracle now asserts exactly three private point reads for each existing-row update,
down from five, with identical proposed bytes and affected counts. This is a
40% reduction in those callback reads, not a network or commit-latency claim.
`just test::unit test::sql` passes again, including rollback, sticky read failure,
all 31 mutation cases and the unchanged query corpus. Inserts remain at most
nine private point reads for three rows.

### Cold-store setup readiness

Repeated SQL ingress attempts observe an owned MinIO health response followed by
HTTP 503 from bucket creation, before any authority/source setup. The fixture now
includes the signed empty PutBucket in its existing 30-second readiness deadline.
It retries that 503 and accepts only an explicit `BucketAlreadyOwnedByYou`
conflict when recovering a completed creation. Other conflicts and authorization
failures still reject. Three fresh pinned MinIO fixtures pass readiness, a second
creation of the same owned bucket and cleanup. This qualifies setup only; the
interrupted query/browser runs are not passing evidence.

### Worksheet SQL inspection

The worksheet adds explicit Inspect SQL submission and a separate metadata/plan
region, bound to the inspected draft and observed source/policy revisions. The
real Board API rejects unsupported catalogs and malformed explicit numeric
literals with 400 `UnsupportedQuery`; these errors formerly fell through to 503.
The fixture now preserves and retries the exact frozen submission body after a
503, still requiring the original receipt and its current disclosure checks.

`just transit-board::check` and the broader `just check` pass. The real Table
API/Chromium run (`zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-source=table -Dunified-board=true -Dunified-browser=true`) passes in
524.40 s. It verifies DESCRIBE, SHOW TABLES and EXPLAIN without query admission,
operator/output-column presentation, stale-draft labeling, failed-inspection
clearing and current revocation clearing. Existing uncertain submission, cross-
instance retry, finite Live draft recovery and worker/node/store recovery pass.
Two Board result readers peak at 41,209,856 combined RSS bytes in the API probe;
that measurement excludes Chromium. The run uses 41 rows, six segments, eight
resident authority pages and an 8 MiB hot store. These are whole-fixture costs,
not comparative inspection latency. KV/Document browser coverage remains open.

### Canonical Table mutation requests

`TableMutationRequest` binds the current native definition, realm, writer,
resource, Table descriptor and typed operation in at most 799 owned bytes.
It reuses Station's Table value codecs and immutable publication commitments;
it does not admit work or add a query-client write route.

`just test::unit` passes with five independently encoded fixtures across four
Table value types, full-width signed keys and nullable/Unicode/binary values.
The Zig checks compare canonical bytes, overwrite the input buffer before using
the decoded value, reject every truncated fixture and reject missing/foreign
definitions, query-bundle magic, trailing input, invalid identities/operation
counts and foreign publication records. The maximum-size fixture occupies
exactly 799 bytes and a one-byte-short output rejects. The ownership/bound
catalog and `just transit-docs::check` also pass. Public mutation admission,
revocation and durable outcome recovery remain subsequent proof boundaries.

### Remaining KV callers and browser

`zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source=kv
-Dunified-sdk=c,cpp,erlang,elixir -Dunified-board=true -Dunified-browser=true`
passes in 191.17 s. Six native/port/installed callers agree on SQL inspection;
revocation, permanent retirement, frozen retry and worker/node/store recovery
pass. The real browser additionally verifies the empty SHOW TABLES listing,
read-only plan/description display, stale draft, error clearing and current
revocation clearing alongside the existing finite-query recovery flow. The two
Board reader processes peak at 41,189,376 combined RSS bytes; Chromium is excluded.
This completes the installed KV inspection set across all ten SDKs when combined
with the earlier language runs. The remaining eight SDK Document callers and
Document browser are still being verified.

### Application-composed Table mutation admission

`TableMutationAdmission` passes `just test::unit` and the independent package
`zig build test`. It uses the existing publication/half-chunk components and
an explicit per-principal/Table policy. Begin uses four private mutations;
application of three rows uses three row mutations plus one result. A terminal
active pointer is replaced on the next begin without discarding the old result.

Reference-store schedules cover interrupted/repeated halves and owner
reconstruction, identical recomputed pre-commit proposals, repeated terminal
apply/cancel with the original input identity, conflicting/foreign namespaces,
forged process origin, another principal, busy uploads, conditional policy
updates, zero-mask revocation, same-mask revision fencing and per-operation
permissions. INSERT conflict leaves every row unchanged; same-value UPDATE
counts one and missing UPDATE/DELETE count zero. Declaration drift rejects.
A read failure on the second insert restores the first proposed row and leaves
sticky read poison; no terminal record is fabricated. Foreign definition bytes
with a valid publication commitment produce an invalid-request result, while
post-publication chunk corruption propagates as an integrity error.

The independent Python contract oracle additionally encodes the source
fingerprint, publication commitment, one policy, five status phases and six
commands. Zig matches their bytes and rejects truncated fixed records/commands,
inconsistent terminal fields, permission bits, part flags and exceeded part
bounds. These are private-turn/model checks, not native durability, transport
uncertainty or public mutation-client proofs. The supplied query hosts still
reject mutation messages; the native integration is the next proof boundary.
`just check`, including generated-contract, frontend and documentation checks,
passes for this increment. The verification catalog also passes.

### SQL worktree main rebase

The SQL worktree is rebased from `3ea81aaa` onto `2c1a9d2d`. One retired-source
fixture conflict was resolved by keeping the explicit null cursor and concrete
authority errors together with SQL inspection denial checks. Main's bounded
startup/browser retries, installed SDK ready/reconcile schedules and current
Arrow fixtures are retained. Its ten-language source evidence above qualifies
the base query path; it is not substituted for the new inspection assertions.

The remaining-eight-SDK Document/browser run was interrupted during provisioning
to avoid mixing source revisions during the rebase. It had completed installed
codec checks, but no source/browser success was reported. It is not a pass and
will be rerun from the rebased worktree. The unfinished native mutation proof was
saved and restored intact. Post-rebase `just check` and `just test::sql` pass.
The transport package's formatting/lint, TypeScript check and eight focused
transport tests pass. The added inspection schedule checks upstream's exact
500/1000/2000 ms availability backoff, identical request bodies and immediate
termination at current denial. Its first draft used an invalid request field
and failed before dispatch; the corrected request passes without unhandled
promises. Public-query and Document integration reruns remain in progress.

### Native Table mutation visibility and recovery

`just test::table-mutation` passes in **7.890 s** against owned disk-backed Ursula
and the real native node, with eight resident authority pages. The test
application calls the public mutation admission owner through ordinary Station
casts. It does not add a supplied host, CLI or SDK write route.

The schedule stages a multi-chunk UTF-8/null request and confirms no rows exist
before the final native commit. All three rows and the terminal result then have
the same resource revision, the original terminal input identity is retained,
and native input progress is consumed. The proxy removes the accepted commit's
receipt; after process exit and node/store SIGKILL/restart, the unchanged frozen
signed proposal returns the original receipt and unchanged rows/result. A changed
signed retry rejects. A new apply of the same namespace returns the original
result without row writes.

A two-row INSERT conflict after the first absent key leaves that key absent and
the existing rows unchanged. An earlier resource revision cannot open a captured
view after intervening staging commits. A prepared update from an older writer
generation rejects without changing rows/result, then the fresh fenced writer
resumes the original admitted input. Revoking native write rights rejects an
already frozen delete; restoring rights permits that exact saved request.
Separate application-policy revocation records a denied result with no row
change, and revoked read rights prevent inspection of an earlier result.

The proxy observed **555 read requests** and **26 successful turn responses**,
including exact receipt retries; these are transport counts, not 26 unique
accepted mutations. The largest proposal has four mutations and the largest
stored value has 256 bytes. Runtime includes the fixture's provisioning,
inspection, fault injection and recovery, but excludes compilation. This is one
local schedule, not a statement-latency target or a paired performance comparison.
The fixture freezes and hashes both executables before running. Unit/catalog
checks and the independent SQL oracle retain their own evidence above.

The initial schedule also passed before adding the stale-resource-view case;
the final schedule above is the qualifying result. The ordinary growth lane now
owns `test::table-mutation`, and invariant `SQL-MUTATION-01` maps its contracts,
implementation, SQL oracle and native proof. Native integration does not complete
the remaining supplied-host and public caller work.

### Installed mutation operation profiles

`just test::table-mutation` runs seven profiles for the native ABI, port and
real CLI. Each selected `--sdk` adds the same profiles through independently
installed public language APIs; Python adds both synchronous and asynchronous
callers. Build the selected packages with their `bindings::*-build` tasks first;
`bindings::c-build` covers C/C++ and `bindings::beam-build` covers Erlang/Elixir.
The complete selection is:

```sh
just test::table-mutation --cold --sdk python --sdk node --sdk rust --sdk ruby \
  --sdk c --sdk cpp --sdk java --sdk dotnet --sdk erlang --sdk elixir
```

The profiles cover UPDATE, DELETE of an existing row, DELETE and UPDATE of an
absent row, INSERT with reversed column order, conflicting two-row INSERT and
cancellation after a committed upload part. Each caller compares current rows
with independent expectations, including NULL versus absence and rollback
of an earlier private insert when a later key conflicts. The conflicting batch
must leave that earlier key absent. Missing-row operations and rejected or
cancelled operations preserve all row revisions. A successful insert shares its
revision with the durable result.

The proxy loses the begin receipt for UPDATE and the final apply/cancel receipt
for each added profile. The caller closes and is recreated, then resubmits the
exact saved command before selecting a successor. Repeated explicit apply and
cancel controls preserve the original terminal outcome, input and result
revision. All retained outcomes are checked again across physical node/store
restart and denied after current read revocation. Per-profile intervals include
recovery and assertions; they are functional schedule timings, not statement
latencies or language performance rankings. The success record is emitted only
after fixture cleanup and retains the source, dirty state, runner and binary hashes.

`--cold` selects the existing owned S3 fixture with an 8 MiB hot-store limit and
8 MiB cold cache, requires actual persisted cold chunks and records their count
and filesystem bytes. Eight resident authority pages, four mutations and all
operation deadlines stay unchanged. The installed profiles use one UTF-8 Table;
wider literals and three-row bounds retain their private-turn/native proofs.
Upload cancellation does not implement SQL transactions or undo applied rows.

The initial native/port/CLI expansion passes **21 profiles** in **197.977 s**,
with **6120 reads**, **150 turn responses** and **23 lost receipts**. That run
cancels immediately after begin, before the subsequent partial-upload extension;
it does not qualify that extension or the optional cold/installed-SDK schedule.
Its log is `/tmp/transit-sql-installed-mutation-profiles-native.log`.

The complete cold-storage selection above passes at clean source `207003bf`:
**98 profiles across fourteen caller variants in 988.246 s**, including
**42.403 s** of installed-consumer setup. It records **25,692 reads**, **582 turn
responses**, **677 mutation-send responses** and **100 lost receipts** (99 caller
receipts and one writer receipt). All retained outcomes survive physical
node/store restart and current read revocation denies every selected status.
Row/revision assertions run before that restart; the native application cases
separately check atomic row/result recovery. Cleanup completes before the final
success marker. The store records **604 cold objects / 71,935,123 filesystem
bytes**, including provider metadata. Four mutations, 256-byte values and eight
resident authority pages remain the observed maxima. The log and full report are
`/tmp/transit-sql-installed-mutation-profiles-all.log` and
`/tmp/transit-sql-installed-mutation-profiles-all.json`. The runner SHA-256 is
`a18888ead65bd90e49300be94231afd82cb83e531e30954369f2cc27da719a02`;
the report records every frozen binary digest. All ten SDK package builds and
full `just check` also pass at this source.

The separate committed-head clean growth run at `207003bf` remains **failed**:
Arrow, pages and growing authority pass, then `test::growing-service` exceeds the
query delivery subprocess's **180-second** deadline. That task takes **598.71 s**;
the lane takes **792.65 s**, with its remaining **17 tasks unrun**, including the
changed mutation schedule. The isolated checkout and lane records remain at
`/var/tmp/transit-ci-i4cuegoj/src`; the log is
`/tmp/transit-sql-installed-mutation-profiles-ci-clean-growth.log`.

That run uses Debug binaries. The unchanged focused schedule
`zig build test-query -Doptimize=ReleaseSafe` passes at the same source: write
**9.986 s**, seal **7.731 s**, recover **13.546 s**, publish **1.768 s** and deliver
**79.959 s**. It verifies **41 rows / 21,296 bytes**, exact retries, bounded Arrow
validation, cancellation and retained acknowledgement. Its log is
`/tmp/transit-sql-growth-query-release-safe.log`. These are separate build-profile
observations, not a diagnosis of the Debug timeout or an engine speedup claim.
The growing service and focused query recipes now explicitly select ReleaseSafe,
as other installed integration proofs do. Safety checks, workload, fault
injections, timeouts and resident limits remain unchanged; Debug remains
available through the direct Zig commands. A new committed-head clean run is
required to qualify the recipe change.

The clean growth retry at `7f2ef35f` passes its first **seven tasks**, including
the ReleaseSafe growing service (**300.67 s**) and the expanded mutation task
(**333.20 s**, including compilation). The mutation schedule itself completes
**21 profiles in 210.849 s**, with **6231 reads**, **153 turn responses**,
**23 lost receipts** and successful cleanup. It covers native ABI, port and CLI;
the separate 98-profile installed proof above covers all ten SDKs.
The lane then fails in `test::table-query-writer` after **115.47 s** when the
console reports `AuthorityTimeout`. The **1340.14 s** lane is failed, with its
last **13 tasks unrun**. Evidence remains at `/var/tmp/transit-ci-w350glyv/src`
and `/tmp/transit-sql-mutation-coverage-clean-growth-release-safe.log`;
the completed mutation record is copied to
`/tmp/transit-sql-mutation-coverage-clean-native.json`.

### Full-reference mutation command cutover

Mutation parts, seal, apply and cancel now carry the complete 68-byte immutable
publication reference. Unit schedules reject a different resource with the same
writer/principal/Table/namespace/policy revision, changed request length/digest,
and changed references to terminal results. Namespace-only payloads reject.
The largest part is 205 bytes; native frame, request, row and turn bounds remain.

The shared native/ABI definition is replaced with `b17eab6aefacb9013afbbcfebf9eededea9f57dcd8be304bab4a18e5d41cd016`.
Generated native/install schemas, ABI/binding resources, browser schemas and
independent request/query/serving/signing fixtures are regenerated together.
Existing missing/foreign-definition and canonical saved-request checks remain.
`just check`, the package-local query tests, the independent mutation fixture
check and application signing check pass. The first root check caught two
hard-coded native signing digests; independently recomputing their current
canonical bytes corrected the fixtures. An initial package invocation using
`--build-file` failed configuration; running from the package directory passes.

`just test::table-mutation` passes on this definition in **7.682 s**, with the
same 555 read requests, 26 successful turn responses (including exact retries),
four-mutation maximum, 256-byte maximum stored value and eight resident authority
pages. The fixture persists the original reference alongside its required
definition before staging, then loads that reference for later apply/cancel.
It never resolves a replacement reference from the current namespace.
The frozen node digest is `a511cb9f1f8996f93a94cdb795fece1d8cbdbb46bf2663e2fa2b034947362835`;
the proof digest is `6d1b6ce699f80e0f09d28ec5c6e54f66b3a8f99c10106e121698a3259fa404ee`.
These independent runs are not a paired performance comparison.

The earlier rebased Document schedule completed on the preceding definition:
Python, Node, Ruby, Rust, C, C++, Erlang and Elixir plus native/port/CLI inspection
agree, and real Board API/browser checks pass. Combined with the previously
recorded Java/.NET schedule, all ten SDK source sets are covered on that
revision. The final Document run takes **1805.83 s**, including **1436.92 s**
provisioning; it produces 12 rows in two segments (9880 bytes), uses 64 resident
authority pages, and retains 1255 cold objects (139076558 bytes). Two concurrent
Board readers sample 45101056 bytes RSS, excluding Chromium. Worker/node/store
restart, prefix revocation, released source pins, current denial and exact
uncertain retries pass. This completed earlier-build evidence is not substituted
for post-cutover caller qualification.

The first committed-HEAD `just ci-clean` run, at `d3fab512`, passed the core lane
and growth Arrow/page proofs, then failed in `test::growing` with
`LegacyAcceptedGrowthHistory`. The old assertion expected the now-consolidated
current adapter to reject its own history. Later clean-CI lanes did not run.
The isolated checkout and failure evidence remain at
`/var/tmp/transit-ci-rb8z_6yk`. A replacement current-owner definition-rejection
proof and new committed-HEAD validation are tracked separately; the failed run
is not a clean pass.

### Consolidated storage definition rejection

`just test::growing` passes after replacing the obsolete legacy-adapter assertion.
A fresh current adapter reads valid genesis history. Separate disk-backed fixture
journals with a missing or foreign head definition reject through both `Store.read`
and `Engine.open`, before and after provider restart. Their tails and stored bytes
remain unchanged. The first replacement compared append-input ordering to Ursula's
canonical JSON and failed; the corrected proof captures the stored bytes before
rejection and compares them after, preserving the intended no-rewrite assertion.

The final write/recover/checkpoint/trim-recover phases take **115.883 / 3.918 /
6.575 / 3.734 s** with one resident page, 64 rows and 1011 catalog records before
the checkpoint. All existing root, mailbox, captured-view, grant, exact-receipt,
trim and missing-page checks remain. This focused pass does not turn the earlier
incomplete clean-CI run into a pass.

On the replacement definition, `just test::client-abi` and `just bindings::native`
also pass canonical signing, missing/foreign-definition refusal, seedless exact
recovery after host/store restart, current revocation, poisoned-read controls,
shared local codecs and six independently decoded query segments. Installed
language/browser cutover schedules and complete committed-HEAD CI remain separate.

### Shared signed Table mutation client

`TableMutationClient` now owns current metadata/SQL compilation, one-command
preparation, canonical save/restore, explicit submit, processed-input observation,
reference-bound status and bounded upload resumption. Package tests prove owned
saved bytes, required outer/nested definitions, canonical framing, and target or
signature rejection before touching the transport. The first test compile caught
a slice binding that should be `const`; correcting the binding preserves the
intentional mutation of its allocated bytes in the ownership test.

The expanded `just test::table-mutation` passes in **9.711 s**. It exercises the
shared client through real native commands, recreates each writer between stage
commands, and checks pending/processed input progress. The proxy removes the
accepted caller-send receipt, then the process exits and node/store restart.
The restored signed command returns the same admission position; only after that
receipt is reconciled and its original input processed does upload continue.
The separate accepted writer-commit receipt loss/restart proof remains intact.
Conflicting namespace preparation cannot overwrite the fixture's saved reference,
a busy active upload cannot admit a second begin, and policy denial prevents new
compilation. Cancelling a terminal denied request retains its original result.

The proxy counts **674 reads**, **25 successful mutation-send responses** and
**27 successful turn responses**, including exact retries. Bounds remain four
mutations, 256-byte values and eight resident authority pages. The frozen node
digest is `a511cb9f1f8996f93a94cdb795fece1d8cbdbb46bf2663e2fa2b034947362835`;
the proof digest is `5e45e18b7f74d9fc117093f41c78476d8cad741c4b386882f620c3066dd02c2e`.
This expanded schedule adds a second node/store restart, explicit stage progress
reads, failed preparations and duplicate cancellation, so its totals are not an
equivalent-workload comparison with the earlier admission-only proof.

Metadata acquisition requests at most six keys in one native batch. Replacing
a terminal active pointer needs one additional prior-status batch; immutable
feature support is cached, while current credentials, grants, source metadata
and policy are not. Saved retry submission performs no metadata read or new
signing. Supplied host/CLI/language SDK write integration remains outstanding.

### Consolidated service capability follow-up

The second committed-HEAD `just ci-clean`, at `775b4bc9`, passed core and the
corrected growing-storage proof, then failed in `test::growing-service`: its old
assertion expected Station and runtime bindings to be unavailable. The current
service advertises both. The focused `just test::growing-service` passes after
requiring those capabilities together with batched reads, retained versions and
worker rotation. It preserves signed reads/turns, current denial, exact retry,
maintenance faults, disk restart and quota/backlog checks. Station write/recover
takes **55.584 / 16.132 s**; the retained query publishes 41 rows / 21296 bytes
through write/seal/recover/publish/deliver phases. This is a focused pass; later
clean-CI lanes did not run. The failed checkout remains at
`/var/tmp/transit-ci-zzrnm6qv`.

### Supplied Table mutation writer

The explicit `table_writer` host role composes the same mutation admission owner
and requires an authorized initializer, an immutable stored configuration and
separate per-principal policy. Independent bytes cover configuration, initializer
commitment, policy changes and all twelve input rejection reasons. Package tests
cover the four-slot initialization boundary, changed configuration/resource,
unauthorized/stale policy changes, namespace conflicts, rollback, poisoned reads
and corrupt status. Rejected inputs have a retained disposition and do not
replace a request's terminal result.

`just test::table-mutation` passes in **12.481 s** using the actual supplied host,
including termination during upload, fresh fenced ownership, premature-apply
rejection, continued upload/application and activation-marker reuse refusal.
The caller reads a processed input's reference-bound rejection separately from
its mutation result. The first run exposed a missing fixture activation directory;
creating that owned directory fixes startup without changing host recovery gates.
All earlier caller-send and writer-commit receipt-loss/restart, atomicity,
conflicting retry, current grant/policy and duplicate-result schedules remain.

The expanded schedule records **1010 reads**, **30 successful mutation-send
responses** and **33 successful turn responses**, including retries. Bounds stay
at four mutations, 256-byte values and eight resident authority pages. The node
SHA256 is `a511cb9f1f8996f93a94cdb795fece1d8cbdbb46bf2663e2fa2b034947362835`,
the proof SHA256 is `af0313622dc0bd760d7684b42899e3fca22ae27ac109216358edfcc29e1294b7`,
and the host SHA256 is `2e620499a4df9b472cc8f52b90e8a9e0855cff8b062430e14515a1f1a0a9b0fe`.
These totals add host polling and rejection/recovery work; they are not a paired
performance comparison. CLI/language SDK mutation entry points and a combined
query-source/writer host remain outstanding.

### Main relational and verification integration

The SQL branch is rebased onto `5e0efd19`, retaining the new delivery simulation,
SDK administrative exact retries, disk-backed language-ring storage and actual
CPU-affinity reporting. Storage conflicts retain main's no-page-request/no-page-
creation gates and add direct current Store-read rejection. The service proof
requires Station/runtime support plus batching, retained versions and rotation.
The pre-rebase supplied-writer tree passes full `just check`, independent mutation
bytes, documentation and the verification catalog. Rebased committed-HEAD clean
qualification is a separate run; no unexecuted lane is reported as passed.

### Neutral Table mutation caller

The post-rebase supplied-host schedule passes at `8314f17b` in **12.407 s** with
1008 reads, the same node/proof/host digests as the preceding host run and unchanged
native bounds. Full clean CI at that committed revision is tracked separately.

`TableMutationBridge` adds owned neutral actions and results above the shared Zig
caller. Package tests match all six independently encoded commands, five request
variants and five stored phases. They preserve full-width namespaces, safe-counter
policy revision bounds, owned cells/strings and rejection before transport of
changed references, malformed saved commands and truncated references. An initial
test incorrectly gave policy revision the full u64 namespace range; the corrected
case uses its existing native safe-counter bound rather than widening the contract.

The real native proof now drives the supplied host through serialized neutral
compile/prepare/next/submit/observe/rejection/status actions. Compiled bytes and
opaque prepared text survive caller recreation and host replacement; premature
apply preserves upload status, terminal cancellation preserves the original result,
and current read revocation stops neutral status lookup. All earlier atomicity,
caller-send/writer-commit receipt loss, disk restart and fencing schedules remain.
The pass takes **12.347 s**, with **1063 reads**, **31 mutation-send responses**,
**34 turn responses**, two lost receipts, four mutations maximum and eight resident
authority pages. Its proof SHA256 is
`5c4d0ce1f6edea1c8faba49a8688012f75afea3e6eac10504e162cfcf7ef6e58`;
node and host digests remain those in the supplied-writer record. Extra metadata,
status and terminal-cancellation observations make this a different workload,
not a paired performance improvement. Package tests, independent wire fixtures
and documentation checks pass. Native ABI/port and installed SDK/CLI exposure
remain separate integration work.

### Mutation ABI and port callers

The explicit `station_table_mutation_create/call/destroy` API and
`mutation_client` port profile delegate to the neutral Zig bridge. Schemas and
all generated language resources are regenerated from public types. A structural
comparison confirms that existing exported signatures and all existing standalone
schemas remain unchanged; only HostConfig/HostRequest gain the new optional
profile/action, with three new mutation schemas. No existing wire or stored
meaning changes in this additive export.

Binding package tests pass current-target/signature validation before dispatch,
malformed recovery rejection, bounded handle overlap, unconfirmed transport
classification and buffers that outlive their client. The native schedule also
checks conflicting local/query/mutation profiles and read-query refusal of
mutation actions. The header generator initially needed the new opaque handle
name registered; generated declarations now include it in C and foreign resources.

`just test::table-mutation` passes in **16.044 s**. In addition to the earlier
native/host schedule, real C ABI and port callers each compile, stage and apply
an UPDATE, lose its accepted admission receipt, replace their handle/child, and
recover the identical saved command. Both read their original durable result,
and both stop after current native read revocation. Three caller receipts and one
writer-commit receipt are lost independently. The schedule records **1406 reads**,
**41 mutation-send responses** and **42 turn responses**, retaining four mutations,
256-byte values and eight resident authority pages. These additional callers and
faults expand the workload; the elapsed time is not a paired speedup comparison.

The port SHA256 is `85ca4859050fc68e0859c4a446464c488ee747b11e29c787b7e0fb15a6e2c436`
and library SHA256 is `b1bf78601f65df27a1038ee993fc8596ce0c770bb010a50905054a66e5dd603b`.
The node, proof and writer digests match the preceding neutral-caller record.
Actual idiomatic SDK callers, CLI integration and combined read/write source
composition remain separate boundaries; generated declarations alone do not
qualify them.

The final mutation tree also passes full `just check`, `just bindings::check`,
`just bindings::native`, documentation and the verification catalog. The broader
binding regression preserves local-codec/native-port parity, scoped controls,
poisoned reads, exact disk/host recovery, six independently decoded query segments,
current denial and materialization update/delete/reinsert behavior.

The separate committed-HEAD clean run at `8314f17b` passed core, growing authority,
service/maintenance and Station recovery, then exceeded the existing **180 s**
query-delivery deadline inside `test::growing-service`. The last recorded native
history position was 560 and commands were still succeeding; no assertion proved
incorrect results. This is an incomplete proof, not a pass or evidence that the
deadline is sufficient under shared-host contention. The failure checkout remains
`/var/tmp/transit-ci-n_3e42w_`. A focused `just test::query` rerun on that frozen
revision, after the binding regression finished, passed with the same binaries
and original deadline: write **7.550 s**, seal **11.852 s**, recovery **31.933 s**,
publication **3.586 s**, delivery **146.497 s**. It independently decoded 41 rows,
21,296 bytes and six IPC segments through exact retry and disk restarts during
staging, sealing, publication and partial consumption. The initial rerun stopped
before testing because Nix could not recreate a cached shell derivation; disabling
Nix's evaluation cache allowed the pinned bindings shell to start. This focused
pass does not convert the preceding incomplete clean run into a pass.

### Installed Python Table mutation callers

`just test::table-mutation --sdk python` passes with independently installed
0.2.0 wheels in a clean environment outside the checkout. Both public synchronous
and asynchronous callers compile an UPDATE, preserve opaque prepared bytes, lose
the admitted send receipt, close and recreate their caller, recover that exact
receipt, finish staging, and read the durable one-row result. Both stop status
disclosure after current native read revocation. Their exception adapters check
that uncertainty retains the exact original recovery bytes. The earlier native,
ABI, port and supplied-writer schedules remain in the same run.

The expanded schedule takes **22.645 s**, including **1.628 s** for installation.
The synchronous and asynchronous caller intervals take **2.455 s** and **2.444 s**;
they include caller creation, replacement, upload and result checks. The proxy
records **1791 reads**, **51 mutation-send responses**, **50 turn responses** and
six lost receipts (five caller sends plus one writer commit). The bounds remain
four mutations, 256-byte stored values and eight resident authority pages. Native
binary digests match the preceding ABI/port record. These are unpaired workload
measurements, not comparative SDK throughput claims.

An initial wrapper omitted Just's positional-arguments attribute, so its green
run exercised only native/port callers; it is excluded from Python evidence.
The corrected schedule prints its selected SDKs and per-caller completion.
Its first actual Python run exposed a test-adapter result-key mismatch; the
adapter now preserves the bridge's `observation` field. Both modes pass after
that correction. Shared native cases cover INSERT/UPDATE/DELETE; this installed
Python extension exercises UPDATE recovery, not an independent full SQL corpus.
The public Python API passes strict type checking across 21 source files, and
the complete repository `just check` passes. `bindings::python-test` owns
the installed mutation schedule, and `bindings::mutation-python` provides its
focused entry point. Other language mutation clients and the CLI remain separate
integration work.

The final `just bindings::mutation-python` rebuild/install/type-check rerun also
passes: **23.170 s**, **1777 reads**, unchanged send/turn/lost-receipt counts and
native digests, with **1.731 s** installation and **2.322/2.421 s** Python caller
intervals. Poll-dependent read counts and shared-host timings vary between runs.

### Installed TypeScript Table mutation caller

`just bindings::mutation-node` builds and installs the public/native packages
outside the checkout, passes strict TypeScript and formatting/lint checks, then
runs the same disk-backed mutation schedule through typed promise methods.
Its UPDATE uses namespace **18446744073709551615**, preserving the full uint64
through `bigint`, owned request/reference buffers, caller replacement and exact
admission retry. Current read revocation denies the original result afterward.
The caller's uncertainty object retains the original prepared text.

Seven boundary tests pass mutable-input/getter ownership, malformed saved text,
cross-realm targets, three unconfirmed receipt responses, a foreign status phase,
and missing/foreign contract definitions with otherwise matching v1 labels. The
shared Node Station port now checks its generated definition before caller work,
using the existing native capability owner. A version label alone never qualifies
a different native build. Generated schemas validate response variants at runtime;
semantic receipt validation also rejects position zero while retaining uncertainty.

The final focused schedule takes **22.768 s**, including **2.753 s** installation
and **3.796 s** for the installed Node caller interval. It records **1686 reads**,
**46 mutation-send responses**, **46 turn responses**, four lost caller receipts
and one lost writer-commit receipt. The four-mutation, 256-byte-value and
eight-resident-page bounds and native binary digests match the preceding ABI
record. The earlier installed trial took 23.433 s with 1680 reads; these unpaired
runs do not establish a performance improvement. The first focused task stopped
on Markdown formatting before its proof; the formatted guide and complete rerun
pass. The verification catalog and local documentation links pass.

`bindings::node-sdk-test` owns the installed mutation schedule, and the ordinary
Node checks include its runtime boundary tests. The installed mutation extension
exercises UPDATE; the shared native fixture remains the independent
INSERT/UPDATE/DELETE and rollback oracle. Remaining language adapters, CLI
integration and read-query/writer composition remain separate work.

The broader `just bindings::node-sdk-test` also passes with the shared definition
check: raw-client owned I/O and revoked exact retry; runner scope/gates, poisoned
reads, fencing/expiry, exact disk/host recovery, retained Tables and six owned IPC
segments; ordinary installed HTTP (**76.74 s**) and RPC (**77.52 s**) with staged
recovery, binary TLS, current denial and authenticated disposal/followup. Its
final mutation rerun takes **22.589 s** with 1685 reads and unchanged send/turn/
fault counts and native digests. No skipped case is counted as passed.

The next committed-HEAD `just ci-clean`, at
`d5f909864d11025849c76da28b1c9c48d2745b16`, also exceeded the unchanged **180 s**
query-delivery deadline in `test::growing-service`. Core, growing authority,
signed service/maintenance and Station recovery completed first. The failed
service task took 452.48 s; later lanes did not run. The retained clean checkout
is `/var/tmp/transit-ci-ljgt0r26`. This is incomplete clean evidence for the
Python/TypeScript checkpoint, not qualification of subsequent Ruby/Rust commits.
No timeout or authority bound was relaxed.

### Installed Ruby Table mutation caller

`just bindings::mutation-ruby` rebuilds and installs the public/native gems in
an external consumer, checks Ruby syntax, and passes the shared native schedule.
Typed value constructors copy and freeze request/reference bytes; the consumer
mutates the original strings and verifies that the saved request is unchanged.
The UPDATE uses namespace **9223372036854775825**, survives a lost admission
receipt and caller replacement, recovers the exact original send, observes the
durable one-row result, and stops disclosure after current read revocation.
The native ABI, port and Ruby callers also reject a changed complete request
commitment before preparing a valid stage. No adapter reconstructs that identity.

The final focused run takes **19.970 s**, including **1.810 s** installation and
**2.325 s** for the Ruby caller interval. It records **1592 reads**, **46 send
responses**, **46 turn responses**, four lost caller receipts and one lost writer
receipt. Four mutations, 256-byte stored values, eight resident authority pages
and all five native artifact digests match the ABI/port record. The initial
installed trial before the altered-commitment case took 20.861 s with 1617 reads.
These are unpaired shared-host measurements with poll-dependent counts; no
comparative throughput improvement is claimed. The installed extension exercises
UPDATE recovery; shared native cases cover INSERT/UPDATE/DELETE and rollback.

Block-based acquisition reuses the existing all-interrupt mask so its ensure
clause owns worker/child cleanup before caller interruption can arrive. The port
uses the existing generated definition and action/result validation. The ordinary
Ruby SDK task now includes the mutation schedule; this focused evidence does not
claim that the entire Ruby runner/connector regression was rerun for this additive
adapter. CLI and seven other typed language mutation clients remain outstanding.

### Installed Rust Table mutation caller

`just bindings::mutation-rust` builds the public/native crates and an external
consumer without source-checkout artifact overrides. The installed blocking
client uses namespace **9223372036854775826**, rejects an altered full request
commitment, preserves the borrowed prepared command across receipt loss, replaces
its native caller and recovers the identical admitted send. It observes the
one-row UPDATE result, then stops disclosure after current native read revocation.
A separate compiler check rejects overlapping mutable borrows of the client.
The executable runs after its consumer source, vendor directory and build outputs
are removed, so its embedded native dependency owns execution.

The focused schedule passes in **30.939 s**, including **12.434 s** for external
compilation/installation and **2.311 s** for the Rust caller interval. It records
**1587 reads**, **46 send responses**, **46 turn responses**, four lost caller
receipts and one lost writer receipt. Four mutations, 256-byte stored values,
eight resident authority pages and all five native artifact digests match the
ABI/port record. These unpaired measurements include compilation and polling;
they do not establish comparative SDK throughput. This installed extension
exercises UPDATE recovery; shared native cases cover INSERT/UPDATE/DELETE and
rollback.

The first installed attempt stopped at a test-only lockfile equality assertion
before mutation execution: Cargo pruned the unused optional Arrow dependency
graph. No registry package version or checksum changed or was added. The consumer
now requires every retained registry identity to match the packaged lock, rejects
an unexpected Arrow dependency and builds with `--locked --offline` after that
check. A source development check initially lacked embedded native artifacts;
selecting the documented local native-directory override allowed it to pass.
Neither initial failure is counted as mutation evidence.

The ordinary Rust SDK task now includes this schedule. This focused result does
not claim a rerun of the entire Rust runner/connector regression. CLI and six
other typed language mutation clients remain outstanding.

### Installed C and C++ Table mutation callers

`just bindings::mutation-c` rebuilds the public/native archives and compiles C11
and C++17 consumers outside the checkout using installed pkg-config discovery.
Their UPDATE namespaces are **9223372036854775827** and **9223372036854775828**.
Each rejects a changed complete request commitment, replaces its caller after an
accepted-but-lost receipt, retries the original saved bytes, observes application
and stops disclosure after current read revocation. Imports copy caller buffers;
the consumers overwrite those buffers and verify unchanged compiled/prepared
values. Saved prepared commands remain readable after native client close. C
failure outputs clear, and C++ client copying rejects during compilation.

The focused schedule passes in **24.933 s**, including **4.196 s** for installed
consumer compilation and **2.214/2.245 s** for the C/C++ caller intervals. It
records **1768 reads**, **51 send responses**, **50 turn responses**, five lost
caller receipts and one lost writer receipt. Four mutations, 256-byte stored
values, eight resident authority pages and all five native artifact digests match
the ABI/port record. The command ran with CPU affinity 2–47, separate from the
concurrent clean run's first allowed CPU. Timings and polling counts are unpaired
observations, not comparative throughput claims. The installed extension exercises
UPDATE; shared native cases remain the INSERT/UPDATE/DELETE and rollback oracle.

The ordinary C/C++ SDK task includes the mutation schedule. Java, .NET, Erlang,
Elixir and CLI mutation clients remain separate implementation boundaries.

The C/C++ tree passes full `just check`, including native contract drift, unit
checks, the verification catalog, frontend checks and documentation build. The
broader installed runner/connector regression is recorded separately when complete.

The broader `just bindings::c-sdk-test` also passes after loading the added native
mutation entry points through the shared C bridge. Both installed raw clients
preserve owned I/O, exact seedless recovery and current denial. Both Station
runners preserve scope/gates, callback errors, poisoned reads, fencing/expiry,
exact disk/host recovery, retained Tables and six owned IPC segments. Installed
C/C++ HTTP schedules pass in **75.51/78.73 s**, and gRPC in **79.47/86.94 s**,
including staged recovery, binary TLS, current denial and authenticated disposal
and followup. The final mutation rerun passes in **24.968 s** with 1776 reads,
unchanged send/turn/fault counts and native artifact digests. No skipped case is
counted as passed. This working-tree regression is separate from committed-HEAD
clean qualification.

### Installed Java Table mutation caller

`just bindings::mutation-java` builds the public/native JARs with the pinned Java
21 compiler, then compiles an external consumer using `-Xlint:all -Werror`.
Immutable values retain full-width namespace **9223372036854775829**. The caller
rejects a changed full request commitment, preserves owned input/getter copies,
replaces its port/worker after receipt loss, recovers the exact admitted send,
observes the one-row result and stops status disclosure after current native
read revocation. Saved prepared bytes remain unchanged on success or uncertainty.
Generated request/result schemas and the existing bounded worker remain shared.

The focused schedule passes in **19.824 s**, including **0.936 s** for installed
consumer compilation and **2.964 s** for the Java caller interval. It records
**1628 reads**, **46 send responses**, **46 turn responses**, four lost caller
receipts and one lost writer receipt. Four mutations, 256-byte stored values,
eight resident authority pages and all five native artifact digests match the
ABI/port record. The command ran on allowed CPUs 3–47. These unpaired shared-host
measurements do not establish comparative throughput; this installed extension
exercises UPDATE, while native cases cover INSERT/UPDATE/DELETE and rollback.

The first consumer compilation stopped on missing optional Error Prone annotations
referenced by Gson's `JsonParser` class. Using the same `Gson.fromJson` test-frame
reader as the existing installed consumers resolves that warning without adding
dependencies or relaxing lint. This compile-only failure is not mutation evidence.
The ordinary Java SDK task now includes the schedule; no full Java runner/connector
regression rerun is claimed for this additive adapter. .NET, Erlang, Elixir and
CLI mutation callers remain outstanding.

The Java increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build. Its installed consumer passes strict Java 21 compilation.

### Installed .NET Table mutation caller

`just bindings::mutation-dotnet` builds the public/native NuGet packages and
restores an external .NET 8 consumer from only those exact local artifacts.
Compilation treats warnings as errors. The executable runs after its source and
restore cache are removed, without a checkout native-library override. Immutable
values retain namespace **9223372036854775830**, copy input/output arrays and
expose read-only column names. The caller rejects a changed request commitment,
replaces its worker after receipt loss, recovers the exact admitted send, observes
the one-row result and rejects current status disclosure after read revocation.
Prepared bytes survive both successful and uncertain submission unchanged.

The focused schedule passes in **21.404 s**, including **2.577 s** for installed
consumer restore/compilation and **2.560 s** for the .NET caller interval. It
records **1598 reads**, **46 send responses**, **46 turn responses**, four lost
caller receipts and one lost writer receipt. Four mutations, 256-byte stored
values, eight resident authority pages and all five native digests match the
ABI/port record. The command ran on allowed CPUs 2–47. These unpaired shared-host
measurements do not establish comparative throughput. The installed extension
exercises UPDATE; native cases cover INSERT/UPDATE/DELETE and rollback.

The adapter uses the existing bounded worker's cancellation and joined disposal
semantics. This schedule observes asynchronous disposal and caller replacement;
it does not independently inject cancellation into every mutation method. The
ordinary .NET SDK task now includes the schedule. No full .NET runner/connector
regression rerun is claimed for this additive adapter. Erlang, Elixir and CLI
mutation callers remain outstanding.

The .NET increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build.

### Installed Erlang and Elixir Table mutation callers

`just bindings::mutation-beam` builds separate public/native OTP applications,
checks Elixir formatting and compiles external consumers with warnings as errors.
The callers run after their source is removed, without a checkout native-host
override. Erlang records and Elixir structs preserve immutable binaries and
full-width namespaces **9223372036854775831** and **9223372036854775832**.
Both reject changed request commitments, retain the original prepared value in
uncertain results, replace their caller after receipt loss, recover the exact
admitted send and observe the one-row result. Saved values remain readable after
close; current read revocation denies status disclosure. Generated validation
and the existing bounded worker/port own every crossing.

The focused schedule passes in **23.190 s**, including **2.151 s** for installed
consumer compilation and **2.462 / 2.610 s** for the Erlang/Elixir caller intervals.
It records **1790 reads**, **51 send responses**, **50 turn responses**, five lost
caller receipts and one lost writer receipt. Four mutations, 256-byte stored
values, eight resident authority pages and all five native digests match the
ABI/port record. The command ran on allowed CPUs 2–47. These unpaired shared-host
measurements do not establish comparative throughput. Installed extensions
exercise UPDATE; native cases cover INSERT/UPDATE/DELETE and rollback.

The ordinary BEAM SDK task includes both schedules. No full BEAM runner/connector
regression rerun or new process-death injection is claimed for these adapters;
they reuse the existing worker's ownership and joined cleanup. Ten language SDKs
now expose the bounded mutation profile. CLI composition, broader SQL operations
and post-cutover inspection qualification remain outstanding.

The BEAM increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build. The installed consumers pass Erlang and Elixir compilation
with warnings as errors.

### Standards-main rebase and clean CI boundary

The SQL branch rebases through main `f481f2b9`, including `c50ee96a`'s standards,
multi-model and historical-schema analysis. Runtime, fixtures, generated contracts
and SDK source remain byte-for-byte unchanged by this rebase. The conflicts were
the roadmap index and the independently added M38: main's standards/branching M38
is preserved, and the SQL continuation becomes M39 at that checkpoint (now
[M40](../docs/roadmap/M40.md) after inserting the type-system prerequisite). Original author and committer
dates are preserved by `git rebase --committer-date-is-author-date`.

The committed clean run at pre-rebase Rust checkpoint `0b680b71` did not finish.
It passed core and the growing-service schedule in **428.16 s**, including query
delivery in **148.517 s** under its unchanged 180-second bound. Public query,
publication, native mutation, HTTP/gRPC libraries/transport/server and Flight
metadata also passed. The ordinary gRPC worker proof passed in **736.96 s**
(**726.53 s** excluding compilation), with nine sends and eight applications.

`test::grpc-faults` then failed after **402.84 s**, after its preparation,
dispatch, completion and observation recovery cases. During preparation of the
second finite-lifetime exchange, an accepted send was followed by a native read
returning HTTP 503 `DeadlineUncertain`, surfaced as `AuthorityUnavailable`.
This is in the scenario that provisions a 60-second work cutoff before staging
two exchanges; it did not reach the blocked-peer/control assertions. The log
does not establish a generic transport outage. Deadlines and authority gates
remain unchanged. The retained checkout is `/var/tmp/transit-ci-zlmded5l`, with
the command log at `/tmp/transit-sql-rust-ci-clean.log`. Later suite tasks did
not run. This failure is not a pass and the frozen checkpoint does not qualify
the later C/C++, Java, .NET or BEAM mutation adapters.

A separate `just test::grpc-faults` rerun in that same frozen checkout passes in
**191.38 s** excluding compilation, on allowed CPUs 2–47. It covers all four
recovery boundaries, current dispatch revocation, the work cutoff, forged
observation, blocked-peer closure and retirement. It records five sends and five
applications, an 8 MiB hot budget, and 402 cold objects totaling 40,130,309 bytes.
The log is `/tmp/transit-sql-rust-frozen-grpc-faults.log`. This focused pass does
not complete the failed full clean run or qualify later code.

### Explicit CLI Table mutation caller

`just test::table-mutation` now includes the real `transit mutate` executable in
the native/port fault schedule. Every command runs in a fresh process. The CLI
compiles UPDATE with namespace **9223372036854775833**, saves new private 0600
artifacts and refuses an existing output path without replacing its bytes.
Altered commitments reject. After an accepted-but-lost receipt, another process
locates the original prepared file and recovers the same receipt. Observation,
separate input rejection and durable status remain distinct. Explicit apply
before sealing rejects; cancellation after application preserves the terminal
result. Current read revocation denies status disclosure. Input artifact bytes
remain unchanged on success and uncertainty.

The schedule passes in **19.383 s**, with **1657 reads**, **48 send responses**,
**48 turn responses**, four lost caller receipts and one lost writer receipt.
Native, port and CLI intervals are **1.625 / 1.848 / 2.999 s**. Four mutations,
256-byte stored values, eight resident authority pages and the five native
artifact digests match the ABI/port record. The CLI ReleaseSafe digest is
`9c82e91ef5180c1ce6fde4e578262b03ed65a1150f91fb3a09f536a55629a0bb`.
Commands ran on allowed CPUs 2–47. These unpaired shared-host measurements are
not comparative throughput evidence. The CLI extension exercises UPDATE;
native cases cover INSERT/DELETE/rollback. This does not establish combined
read/write sessions or a power-loss proof for local artifact persistence.

`just test::cli-diagnostics` passes **237 real-command cases**, including offline
mutation help/capabilities, strict options and numeric bounds, version and URL
validation, and malformed local artifacts rejecting before credential loading.
The log is `/tmp/transit-sql-cli-mutation-diagnostics.log`; the mutation schedule
is `/tmp/transit-sql-cli-mutation-proof.log`.

After tightening the test adapter to require a CLI-created prepared artifact
instead of permitting a reconstructed fallback file, the schedule passes again
in **18.423 s**, with **1653 reads**, the same 48 send/turn responses, lost-receipt
counts, bounds and artifact digests. Caller intervals are **1.575 / 1.800 /
2.742 s**. The log is `/tmp/transit-sql-cli-mutation-final.log`.

The CLI increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build. The log is `/tmp/transit-sql-cli-mutation-check.log`.

### CLI checkpoint clean validation

Committed `42325495` ran `just ci-clean --lane core`. Foundation checks,
properties, simulation, independent package builds, ABI, Station and disk
storage recovery passed. The service proof failed at its first worker Table
turn after an accepted view: HTTP 503 `AuthorityUnavailable` replaced the
expected success (`tests/service.py:146`). Later core tasks did not run. No
deadline or authority bound was relaxed. The checkout remains at
`/var/tmp/transit-ci-66hrmfd0/src`; the log is
`/tmp/transit-sql-cli-ci-clean.log`. A separate `just test::service` in that
unchanged frozen checkout passes, including scoped revocation, worker fencing,
disk recovery, retirement/trim and uncertain dispatch closure/replay. Its log is
`/tmp/transit-sql-cli-frozen-service.log`. This focused pass does not complete
the failed clean lane.

### Publication domains and coordinated caller cutover

The current native definition is
`2577b1247a78a2f8a3eae59b3b36a286fedf9836759d19325edd9b3318b5bad5`.
Publication keys include a required domain; SPF1 references are 72 bytes.
This separates query results from mutation requests with the same full-width
namespace and record ID. Native SDK publication actions and caller-staged
HTTP/RPC/Document bodies use the application domain. Generated definitions,
neutral resources, signing fixtures and all ten SDK reference validators change
together. Earlier proof entries retain their original definition and evidence.

Full `just check` passes, including contract drift, independent wire fixtures,
237 CLI diagnostics, frontend checks and the documentation build. After adding
the index-cache isolation regression, `just test::unit` passes again. Unit
schedules cover independent budgets/content/cleanup/cursors at equal full-width
IDs, missing/old-length references, upload-marker retargeting, typed domain
rejection before resource reads and a cached node that cannot conceal a missing
chunk in another domain. Logs are
`/tmp/transit-sql-publication-domains-check.log` and
`/tmp/transit-sql-publication-domains-unit-final.log`.

`just test::publication` passes with a 64 KiB record and 41 additional retained
records, four killed workers, exact append/publication/cleanup retries and
one-page recovery. Stage/seal/publish/cleanup/finish intervals are
**33.816 / 2.926 / 20.478 / 14.006 / 87.795 s**. It records **2447 reads** and
**309 turns**, at most four mutations and 256-byte values. The record's logical
key/value size is **72579 bytes**, with **59 bytes** per domain/namespace
budget. The first attempt exposed an outdated fault-injector key offset, now
corrected. The next attempt failed on an expired-view read with HTTP 503
`DeadlineUncertain` surfaced as `AuthorityUnavailable`, instead of the expected
`StateViewExpired` rejection. An unchanged rerun passed all phases; this is
not a deadline reliability guarantee. Logs are
`/tmp/transit-sql-publication-domains-native.log` and
`/tmp/transit-sql-publication-domains-native-rerun.log`.

All SDK package builds pass. `just test::table-mutation --sdk python --sdk node
--sdk rust --sdk ruby --sdk c --sdk cpp --sdk java --sdk dotnet --sdk erlang
--sdk elixir` passes native/port/CLI and every installed language caller,
including both Python schedules. The native case still covers INSERT/UPDATE/
DELETE and rollback; installed extensions cover UPDATE recovery. It completes
in **78.473 s**, with **3859 reads**, **103 send responses**, **92 turn responses**,
15 lost caller receipts and one lost writer receipt. Four mutations, 256-byte
values and eight resident pages remain the bounds. SDK installation takes
**29.975 s**. Caller intervals range from **1.654 s** (native) to **3.841 s**
(Node); these expanded, unpaired intervals do not establish comparative
throughput. The log is `/tmp/transit-sql-publication-domains-mutations.log`.
The proof freezes and hashes its ReleaseSafe artifacts before the schedule:

| Artifact       | SHA-256                                                            |
| -------------- | ------------------------------------------------------------------ |
| Node           | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Mutation proof | `0c78c1dbf03eec1f793f6dfb89ed9bd53b719e1cca3efcc4a93ce505c1a4f264` |
| Supplied host  | `dcc9d8410d9e42d896c54561b589353079a177c7fdf37f2976a4827481e9ebef` |
| Native port    | `e27d4229e22812c09e74bfcec9224231cee323d7d596f04ea1d44e7752551196` |
| Shared library | `946c36f43c9736e6905309bf21ed1374bdb858f740360c866f87b1e012753992` |
| CLI            | `34f72173cd1b2338e2756f7c1040852a055999c6e272f0540c72e044da9c5e28` |

The domain prerequisite does not enable a combined query/writer host. Separate
read/write policies, bounded initialization and interleaved snapshot/mutation
proofs remain M36 work. Query and other owner recovery qualifications are
recorded separately from the mutation schedule; it does not prove them.

`just test::build` compiles all application and integration entry points with the
required domains, including HTTP request readers and the application proof.
`just test::application` passes signed publication, exact append/final receipt
recovery, three worker kills, disk restart with one resident page and current
policy/resource denial. Its stage/seal/publish/finish intervals are **0.956 /
1.058 / 0.507 / 0.817 s**, with **195 reads** and **20 turns**, at most four
mutations and 256-byte values. The independent fault selector now checks the
application-definition domain and the new record offset. Logs are
`/tmp/transit-sql-publication-domains-build.log` and
`/tmp/transit-sql-publication-domains-owners-final.log`.

`just test::reactive-refresh` passes in **70.95 s**, including two shared-principal
views, one active admission, exact lost follow receipt, worker replacement,
full-width identities and entry-read denial while metadata remains readable.
An initial run timed out because the independent UQU1 decoder still selected
the old phase offset; the corrected decoder selects the phase after the 72-byte
reference. The successful log is
`/tmp/transit-sql-publication-domains-refresh-document.log`.

The separate clean bindings run at pre-cutover `f6698e0c` has passed Python,
Node, Rust, Ruby and C/C++ complete SDK regression tasks in **594.61 / 714.73 /
795.18 / 467.73 / 1018.21 s**, respectively. It continues with Java and later
tasks in `/var/tmp/transit-ci-aupu5a9d/src`. These completed tasks qualify that
frozen definition only; neither the unfinished lane nor these earlier runtime
artifacts qualify the publication-domain cutover. The log is
`/tmp/transit-sql-ten-sdk-ci-clean.log`.

`just test::unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node,ruby,rust,c,cpp,java,dotnet,erlang,elixir` passes all
three source schedules on the new definition. Each agrees on SQL inspection
across thirteen enabled native/port/SDK caller variants, retries the frozen
upload, restarts both workers, node and disk store after segment staging, reads
verified results, enforces prefix revocation and checks released source pins.
Each installed SDK also runs independent Arrow/schema/cell-state codec cases.

| Source   | Rows / segments / IPC bytes | Resident pages | Schedule seconds |
| -------- | --------------------------- | -------------- | ---------------- |
| KV       | 41 / 6 / 13584              | 8              | 139.07           |
| Table    | 41 / 6 / 13584              | 8              | 147.78           |
| Document | 12 / 2 / 9880               | 64             | 431.70           |

The source intervals include isolated SDK installation and provisioning; they
are not query-latency or cross-source performance comparisons. Every schedule
uses an 8 MiB hot-store budget with persisted cold objects. The log is
`/tmp/transit-sql-publication-domains-query.log`. Shell/Board/browser options
were not selected by this run.

`just test::http-worker` passes disk recovery, exact native retry, credential-free
replay, cleanup, explicit/public followups and disposal, caller termination,
name rebinding and partial-capture loss: **16 sends**, **8 remote applications**,
**2 cancellation requests**, **526.93 s** excluding compilation. Its 8 MiB hot
store leaves **1087 cold objects / 129751880 object-store bytes**. The log is
`/tmp/transit-sql-publication-domains-http.log`. Final `just check-core` also
passes after the owner and test-adapter corrections; its log is
`/tmp/transit-sql-publication-domains-core-final.log`.

`just test::document` passes staged index, acceptance, checkpoint and terminal
cleanup recovery, with exact lost receipts at all four boundaries. Its independent
fault selector uses the Document publication domain and new key offsets.
Stage/accept/checkpoint/finish take **6.394 / 56.199 / 89.802 / 209.724 s**;
the final phase recovers with one resident authority page. It records **8984
reads**, **361 turns**, three killed workers, at most four mutations and 256-byte
values. The 8 MiB hot store leaves **460 cold objects / 43721160 bytes**. The
log is `/tmp/transit-sql-publication-domains-refresh-document.log`.

The committed-HEAD clean core run at `fd929ddc` passed foundation checks,
properties, simulation, codecs, deployment/telemetry, independent package builds
and compute. It then failed in the raw client ABI's signing vectors: the SDK
operation fixture's canonical definition had changed but its expected digest
and signature were stale. This is a fixture defect, not a passing ABI proof.
Later core tasks did not run. The source/log evidence is retained at
`/var/tmp/transit-ci-uwms4hww/src` and
`/tmp/transit-sql-publication-domains-ci-clean.log`.

The two SDK operation digests and Ed25519 signatures are regenerated from the
fixture's public test seed using independent SHA-256 and OpenSSL signing.
The foundation verification check now checks their definition, canonical JSON
and digest before native builds. `just test::client-abi` then passes standalone
port checks, canonical signatures, full-width growing identities, disk/host
restart, exact uncertain recovery, current revocation and malformed replies.
The log is `/tmp/transit-sql-publication-domains-client-abi.log`. This focused
pass does not complete the earlier failed clean lane.

After the fixture correction, **`just ci-clean --lane core` passes at committed
`79b648b2`** without inherited workspace build outputs. All core tasks complete,
including foundation/CLI checks (**74.24 s**), properties/simulation, independent
package builds (**136.52 s**), raw client ABI (**6.32 s**), Station (**149.86 s**),
disk storage (**390.85 s**), signed service (**64.94 s**), runtime upgrade,
runnable callers (**22.81 s**), inspection (**7.50 s**) and state (**17.61 s**).
The readiness write takes **241.79 s** within the existing fixture bound. The
log is `/tmp/transit-sql-publication-domains-ci-clean-fixed.log`; completion
evidence is `.cache/ci/clean/79b648b2c3ed-transit-ci-vz30niqm`. This is a complete
core-lane pass, not a full-suite pass.

`just test::unified-ingress table` and `just test::unified-ingress kv` pass the
actual SQL shell, generated Board client, concurrent Board instances and browser
worksheet on this definition. They preserve frozen signed retries, separate
inspection/query grants, current prefix denial, complete results, retirement and
draft/view separation. Table also proves finite Live draft budgets and exact
saved recovery. The full source schedules take **212.76 / 177.37 s**, each with
41 rows, six IPC segments and eight resident authority pages. Two Board instances
use **42582016 / 40566784 bytes RSS** in the respective samples. The Table draft
budget schedule takes **17.25 s**. The log is
`/tmp/transit-sql-publication-domains-ingress-rerun.log`. Document ingress also
passes: **12 rows / 2 segments / 9880 bytes**, 64 resident pages, **501.78 s**
including provisioning, and **45400064 bytes** for the two-Board RSS sample.
Its independent browser checks cover SQL inspection, exact uncertain retry,
current denial and provenance. The first invocation failed before execution
on a missing cached Nix shell derivation. Disabling the Nix evaluation cache
recreates the pinned shell; no toolchain or lockfile changes are involved.

The older clean bindings lane at `f6698e0c` finishes the individual Java,
.NET and BEAM suites in **506.37 / 480.87 / 1173.37 s**. All selected language
suites pass at that earlier definition. Cross-language `bindings::sdk-interop`
then fails after **298.97 s**: MinIO returns HTTP 507 `XMinioStorageFull`, Ursula
cannot stage pages and the exact delivery retry reaches its existing deadline
with `AuthorityUnavailable`. This is a failed lane; later tasks did not run.
The checkout and evidence remain at `/var/tmp/transit-ci-aupu5a9d` and
`/tmp/transit-sql-ten-sdk-ci-clean.log`. Only ignored compiler caches in other
inactive proof clones are removed to recover disk capacity; retained source and
failure logs remain. These older language passes do not qualify the current
publication-domain definition.

After restoring disk capacity, the unchanged frozen-checkout
`just bindings::sdk-interop` rerun passes all **ten different-language pairs**
in **462.5 s**, including isolated consumer installation, lost receipts, worker
restart, typed Table/query results and owned IPC. Its log is
`/tmp/transit-sql-ten-sdk-interop-rerun.log`. This focused pass does not complete
the failed bindings lane or qualify the current definition.

### Combined Table owner component checks

`TableQueryWriter`'s independent configuration/state/control vectors and five
component schedules pass with the pinned compiler. They model four-mutation
initialization phases, replacement of the in-memory owner, duplicate and forged
continuations, early ingress, independent policy revisions, whole-proposal
rollback and poisoned reads. These in-memory tests are not native durability
evidence. `just check-core` passes with the supplied `table_query_writer` role.

The existing `just test::table-mutation` native/port/CLI schedule also passes
after extracting the shared two-write declaration helper: **19.287 s**, **1661
reads**, **48 turns**, four lost caller receipts plus one lost writer receipt,
eight resident authority pages, four mutations and 256-byte values. This proves
the existing standalone host still recovers; it does not yet prove the new
combined host's two-turn or interleaved query/mutation schedule. Logs are
`/tmp/transit-sql-combined-table-unit.log` and
`/tmp/transit-sql-combined-table-check.log`.

`just test::table-query-writer` now passes against the actual supplied host,
disk-backed Ursula and public ABI/CLI callers. It loses each initialization
commit's receipt, kills the worker, restarts node/storage, recovers the original
signed commit, and requires fresh ownership while refusing activation reuse.
The staged phase has neither initial policy; the ready phase has both. Repeated
initialization leaves their revisions unchanged.

The schedule admits a durable query, pauses its self continuation, opens an
interactive console snapshot, then commits a CLI UPDATE using the durable
query's **same numeric publication namespace**. Both earlier snapshots contain
the old row; subsequent durable and interactive queries contain the new row.
Query-policy revocation prevents old-result disclosure while separately
authorized mutations still succeed. Mutation-policy revocation rejects new
mutations while new queries succeed. Native read revocation finally prevents
disclosure. Independent PyArrow decoding verifies the complete typed cell
envelopes and values.

The clean attempt at `7f2ef35f` exposed a synchronization problem in that fixture:
it held an interactive snapshot read while performing the entire CLI mutation
upload, seal and apply. The console keeps its ordinary five-second request
timeout; the extra setup exceeded it. The fixture now stages and seals before
opening the console snapshot, freezes the final apply command, and holds the
snapshot read only until that apply input is processed. It checks the applied
outcome, affected row and original input separately, then compares both retained
cuts and both later queries. `snapshot_pause_seconds` records the harness's final
apply interval. Workload rows, numeric namespace collision, request deadlines,
resident bounds and recovery/policy assertions remain unchanged. The focused
rerun reaches all retained/latest query assertions, then fails in later policy
progress polling on `StaleStateResource`: that poll opened a Table-policy view
while the turn being observed could change its resource revision. The progress
probe now reads only the current process input. Separate phase, policy and row
assertions still check their owning state; no rejection is swallowed or retried.
The first focused log is `/tmp/transit-sql-combined-snapshot-final-apply.log`.

With both fixture corrections, `just test::table-query-writer` passes in
**106.683 s**, with **5001 reads**, **70 turn responses**, both recovered
initialization receipts and a **1.085 s** final-apply pause. Four mutations,
256-byte values, eight authority pages, and the five-second console deadline
remain unchanged. The log is `/tmp/transit-sql-combined-snapshot-progress.log`.
This run covers native/CLI callers; it does not expand installed SDK coverage.
A new committed-head clean growth run is still required; neither earlier failed
run is reclassified as a pass.

The schedule takes **54.355 s**, including provisioning/recovery, with **5303
reads**, **70 accepted turn responses**, two recovered initialization receipts,
at most four mutations, 256-byte values and eight resident authority pages.
It uses an 8 MiB hot store with disk-backed cold storage. Read counts include
10 ms worker polling and the fixture's explicit one-output delivery scans;
this is not a query latency or operator throughput benchmark. The log is
`/tmp/transit-sql-combined-table-cli-leases.log`. ReleaseSafe binary SHA-256 values:

| Binary                 | SHA-256                                                            |
| ---------------------- | ------------------------------------------------------------------ |
| Node                   | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Query host             | `12abd330c24290badb25df477fe5133613a726c46394e702b6525ce7d872c1a6` |
| Proof                  | `f59d9965cc31aa9aeddeaf14ce3052a600a5b1fa99c3ab8bcf286075c5524380` |
| Shared Station library | `946c36f43c9736e6905309bf21ed1374bdb858f740360c866f87b1e012753992` |
| CLI                    | `34f72173cd1b2338e2756f7c1040852a055999c6e272f0540c72e044da9c5e28` |

Earlier attempts exposed fixture defects: its delivery scan failed to reacquire
an expired read, its first result assertion expected flat values instead of the
shared Arrow cell envelopes, and its command runner expected JSON from a void
revocation command. These attempts remain failures in
`/tmp/transit-sql-combined-table-native{,-rerun,-final}.log`; correcting them did
not change the combined owner's implementation or relax its bounds. Full
`just check` also passes, including frontend validation/tests and the documentation
site build (`/tmp/transit-sql-combined-table-full-check.log`). The new native
schedule is registered in the growth lane; it is separate from a committed-HEAD
clean run and from the installed SDK matrix.

The optional combined-host mutation SDK matrix also passes:
`just test::table-query-writer --sdk python --sdk node --sdk rust --sdk ruby
--sdk c --sdk cpp --sdk java --sdk dotnet --sdk erlang --sdk elixir`.
All ten installed SDKs (eleven caller variants with Python sync/async) resume
the exact saved command after losing an admitted send receipt and replacing the
caller, then observe one applied full-width-namespace UPDATE. Current native
read revocation prevents each caller from disclosing its earlier status. The
same run includes the initialization and durable/interactive CLI snapshot cases
above. Query result reads here use the public native ABI and console; installed
query SDK source coverage is recorded in the preceding query matrix.

This larger schedule takes **132.498 s**, including **29.646 s** isolated SDK
installation, **8736 reads**, **114 accepted turn responses** and eleven lost
SDK admission receipts in addition to the two initialization receipts. Caller
intervals span **2.894–4.279 s** and include upload, deliberate failure, caller
replacement and status checks; they are not statement execution timings. The
four-mutation, 256-byte and eight-page bounds hold. Frozen native binary hashes
match the table above. The log is `/tmp/transit-sql-combined-table-sdks.log`.

**`just ci-clean --lane core` passes at committed `a3c40a0d`** in a fresh
checkout without inherited build outputs. It completes foundation checks
(**68.31 s**), properties/simulation, independent package builds (**137.49 s**),
client ABI (**6.20 s**), Station (**147.94 s**), disk storage (**212.77 s**),
signed service (**44.19 s**), runtime upgrade (**4.94 s**), callers (**16.99 s**),
inspection (**4.23 s**) and state (**11.08 s**). Readiness write takes **129.48 s**;
these unpaired runs do not establish a performance improvement. The log is
`/tmp/transit-sql-combined-table-ci-clean.log`; copied timing/completion evidence
is `.cache/ci/clean/a3c40a0d6006-transit-ci-ux_5ezz5`. Later commits add the optional
SDK test schedule and documentation, with the production source unchanged.
This is a complete core-lane pass plus the separately executed combined-host
proofs, not a complete clean-suite pass.

### Console SQL routes, diagnostics and exact write recovery

The console dispatches bounded mutations and compatible Table declarations to the
shared signed clients through explicit `writes.table` / `writes.catalog` routes.
Located parser failures and the shared diagnostic presenter distinguish syntax,
unsupported constructs, reference-only families, unavailable interfaces and
binding errors. This does not extend the accepted mutation grammar, install
writers/catalogs, grant rights or enable Flight writes.

Local focused runs for issue #46 completed with the pinned development shell:

```sh
just check
just test::sql
just test::table-query-writer
just test::catalog
just test::flight
```

`just check` includes **419 real CLI cases**, including both reported INSERT
forms, missing catalog routes, incompatible Table definitions, statement/batch
bounds, locations, escaped/redacted context, and a listening trap proving invalid
SQL makes no authority call. The SQL corpus retains **113 SELECT ASTs, 92 plans,
28 unified results, 31 mutation cases and 182 declaration cases**. These compiler
checks alone make no admission or durability claim.

The real console in `tests/table_query_writer.py` runs against the combined host
and disk Ursula. It inserts, updates and deletes, observes zero-row results and
atomic duplicate-key rejection, and reads the resulting rows. It loses a native
receipt, verifies the original saved signature, reopens without submission, rejects
changed key/connection or missing-definition recovery, and explicitly resumes
exactly once. SIGINT preserves admitted work and prevents the following batch
statement from running; `.cancel` reconciles the input and observes cancellation.
A proxy holds a prepared part while a distinct administrator revokes policy.
The rejected input leaves its upload recoverable, blocks replacement work and
can still be cancelled. The policy-race focused run completed in **51.73 seconds**,
with at most four mutations per turn, 256-byte values and eight authority pages.

The real catalog proof runs CREATE TABLE through the console, loses its receipt,
verifies no replay on open, resumes the original signed command, checks the
explicit creation-cancellation limitation, and resolves the created definition
through DESCRIBE and paged SHOW TABLES. Duplicate names report the recorded
conflict; revoked inspection prevents `.status` disclosure. The final catalog
report has `completed: true` and no cleanup failures. The first attempt's new
Python variable shadowed its report function during finalization; that attempt
failed and is not counted as a complete proof.

Flight schema and execution tests cover error categories, coordinates, guidance,
redaction, authentication/current authorization before diagnostics, and no
admission for rejected SQL. Full finite-result recovery and independent PyArrow,
ADBC Python and ADBC C checks pass. Remote public messages retain their 128-byte
ASCII bound; a longer draft message failed its unit check and was shortened.

Console batch and controlling-PTY regressions keep result stdout separate from
errors and preserve recovery files on rejected SQL. Valid INSERT without a writer
has configuration guidance, while malformed SELECT has a caret. The idle-interrupt
fixture acknowledges a queued `.show` after the final result, so an earlier input
redraw cannot be mistaken for completed recovery persistence. Deadlines and
recovery assertions are unchanged. These fixtures do not establish arbitrary
SQL, automatic query registration after CREATE TABLE, multi-resource transactions,
or cancellation of an already applied write. Clean-checkout lane execution is
reported separately with the PR's committed revision.

The console recovery reader also requires exact canonical JSON, preventing native
type defaults from filling in omitted nested request definitions or schema
versions. The writer proof removes each field from otherwise canonical saved
bytes and checks rejection before resubmission. The initial clean growth run at
`7d97b4fd` was interrupted after Arrow, page and growing-authority checks passed
to include this additional check; it is not a complete clean-lane result.

The subsequent full `just test::console table` run completed: console batch, PTY,
interruption and TLS checks took **237.72 seconds** inside the **275.64-second**
disk-backed unified proof. The earlier terminal attempt expected a parse caret
for valid INSERT without a writer and failed; the corrected assertion requires
the caret only for malformed SELECT and keeps the no-send/stdout checks.

### Default local Table writes — 2026-09-30

The automatic local console now uses the server's combined Table query/writer
owner for `items`, with an explicitly initialized INSERT/UPDATE/DELETE policy,
allocated route identities and private write recovery. Gateway readiness checks
the exact durable ready configuration plus authorized query metadata. The
superseded local `TableSource` initializer and host role are removed.

This is a hard cutover to shared definition
`ccd596113a3719c6d38afdffe907f04e90f4703472c91aaaffa7875364b5b31e`.
Schemas, ABI/binding resources and independent signing, mutation and catalog
fixtures are regenerated. Missing, foreign and previous query-only installation
definitions reject in both server and automatic console before use, preserving
the original installation record. Existing histories are not converted or reset.

Executed on Linux x86_64 in `nix develop` with pinned Zig
`0.17.0-dev.2267+48abf1a34`, native MinIO and disk-backed Ursula:

- `just transit-board::install` installed the locked dependencies; `just check`
  passed formatting, generated contracts, units, CLI diagnostics, frontend and
  documentation checks, including the site build. The first check stopped on
  Zig formatting; the corrected rerun passed.
- `just test::server` passed the expanded local lifecycle in **41.19 s**.
  The bare console inserts two rows, updates and deletes by key, and verifies
  fresh reads. An explicit connection without a writer rejects mutations.
  The fixture stops the Table owner, admits a console write, kills the console,
  restarts the server and resumes the same saved operation. Rows survive worker,
  node, store and manager replacement. Mutation revocation persists across
  restart while query reads continue. Recovery files retain mode 0600.
  After removing the old initializer, `just test::unit` and `just test::server`
  passed again; the final local lifecycle took **37.94 s** and additionally
  compares the entire saved operation before resuming its original identity.
- `just test::server-faults` passed that lifecycle again in **37.68 s** and its
  bootstrap/gateway/rollback schedules in **20.64 s**, retaining exact initial
  provisioning receipts and refusing changed artifacts or rolled-back storage.
- `just test::table-query-writer` passed in **51.424 s**, with **7,009 reads**,
  **105 turn responses** and both initialization receipts recovered. It checks
  independent query/mutation policies, lost write receipts, cancellation,
  retained query snapshots across writes and current native disclosure gates.
  The run retains four mutations per turn, 256-byte values and eight resident
  authority pages; no installed SDK matrix was selected.

- `just test::server-board` passed default/headless behavior, embedded assets,
  application replacement, inspection revocation, owned process failures and
  both lost-reply/manager-death provisioning schedules. The final lifecycle took
  **34.12 s**. The initial fixture incorrectly requested configuration version 3;
  it now requests the implemented version 1. A later run correctly rejected
  shared build outputs replaced during recovery, so the proof now freezes all
  its binaries. One frozen-artifact run stopped on `AuthorityUnavailable` during
  application status polling; the unchanged rerun passed all scenarios. No
  runtime identity, authorization or availability assertion was relaxed.
  Final evidence: `/tmp/transit-local-writes-board-verified.log`.

Logs: `/tmp/transit-local-writes-check.log`,
`/tmp/transit-local-writes-server.log`, `/tmp/transit-local-writes-faults.log`
and `/tmp/transit-local-writes-combined.log`; final unit/lifecycle evidence is in
`/tmp/transit-local-writes-final.log`. These are working-tree executions, not
clean committed-HEAD or hosted CI evidence. `just ci-clean`, physical ENOSPC and
installed SDK matrices were not run for this cutover.
## Fuze logical type foundation

The local `Types` profile has nine passing focused Zig tests, including 46
independently generated Python stdlib scalar cases for exact integer widths,
decimal coefficients, IEEE floats, Gregorian dates, timestamps and UUIDs.
`just test::fuze-types` checks fixture drift and executes descriptor/value
truncation, incompatible definitions, recursive budgets, escaped duplicate JSON
keys and exhaustive allocator-failure cleanup schedules. This is local
codec/conversion evidence, not CSV/JSONL execution, installed SDK/Arrow extension,
durable file recovery or comparative performance evidence. The original
six-scalar Fuze package suite passed before recursive codec additions; final-tree
package and repository checks are recorded separately when executed.

The type-foundation tree passes full `just check` on Linux x86_64 with the pinned
Zig 0.17 shell and locked frontend dependencies: generated native/application/ABI
contracts, unit/CLI checks, independent fixtures, frontend validation/tests and
Docusaurus build. The initial contract commit `cb86170a` separately passes
`just ci-clean --lane core` in a fresh checkout, including disk Ursula,
service/client/caller/inspection/state proofs. This clean result applies to that
contract-only commit, not subsequent type or reader implementation. One focused
shell entry failed due to a missing cached Nix derivation; retrying with
`--option eval-cache false` resolved the environment failure without changing pins.

## Fuze bounded file sources

`just test::fuze-sources` passes 23 focused Zig tests, including the nine type
checks. Six independent Python csv/json/Decimal cases compare exact schema and
neutral value bytes at chunk widths 1, 2, 3, 7 and 8192. Separate framing schedules
split a quoted/BOM/newline corpus at every width. The tests cover partial and raw
schemas, multi-file names, sparse/nested values, integer precision, late outliers,
unknown fields, malformed/ragged input, work limits, option ownership, changed
content, current denial, cancellation, failed-prefix completion, binding
truncation/definition rejection and exhaustive allocator-failure cleanup.

These callbacks use in-memory fixture sources. They establish neither physical
file/capture durability nor installed caller, compression, Arrow or DuckDB
performance qualification. Full checks and clean CI for the source checkpoint
are recorded when executed; the earlier contract-only clean run does not qualify
this implementation.

The source checkpoint passes full `just check`, including generated contract
checks, Zig units, CLI diagnostics, frontend tests and the documentation build.
A subsequent focused rerun of all 23 source/type tests passes after centralizing
saved-binding metadata validation. Logs are `/tmp/rey-fuze-sources-check.log`
and `/tmp/rey-fuze-source-final-test.log`; these local paths are not portable
artifacts or independent durability evidence.
