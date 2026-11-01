# Query execution and computation: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

Captured and maintained results, relational execution, source attribution and bounded computation.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Managed finite Table lifecycle — 2026-11-01

The selected installed slice declares one ordinary Table input and an existing,
schema-matched Table output. The [public profile](../../handbook/reference/queries.md#managed-table-computations)
and [contract](../../../contracts/DATAFLOW_V1.md) distinguish publication,
authorization, activation, pending work and complete finite revisions. This is
finite recomputation after publication notifications, not ordered change capture
or incremental algebra.

With the runtime implementation through `549798c32` and the pinned `ReleaseSafe`
binaries, the [typed proof](../../../tests/catalog/tables/managed_table.zig)
passes original-transaction recovery, atomic output/checkpoint publication,
suspend/resume fencing, resume before old-worker cleanup, output-row budget
refusal without a partial revision, invalid maximum-budget rejection before
admission, managed dependency exclusions and retirement. The
[driver](../../../tests/storage/tables/direct_table_service.py) kills and replaces
the node after a prepared participant blocks ordinary head reads with `Conflict`.
Independently paged pending work then recovers the original decision. The raw
typed output is in `/tmp/transit-m12-final-overflow.log`; that combined command
later failed in the installed watcher, so it is not a whole-command pass.

The [installed SQL fixture](../../../tests/interfaces/installation/server_managed_tables.py)
at `ab588a2f4`, run against those same binaries, passes publication without
execution, explicit authorization/activation, five complete revisions including
empty successors and refresh, suspend/SIGKILL/restart/resume, idle parking without
storage polling, and retirement. Duplicate output keys settle as an execution
failure without publishing a partial revision. Checked `SUM` overflow also
settles and preserves the existing output value `7`. Its complete passing output
is `/tmp/transit-m12-final-reconnect.log`. The fixture explicitly uses the
existing direct-Table correctness profile: 120-second server commands and
30-second authority requests. Fresh metadata observations, result closure and
replacement observation sessions retain the original 180-second watch deadline.
An uncertain retirement is inspected by its original identity and token; SQL is
never resubmitted. `just test::managed-tables` is the reproduction entry point
for both fixtures. This is not a latency qualification.

Earlier installed attempts failed on canceled metadata observations, result-close
timeouts, uncertain controls, missing local SQL sockets and permission denials
after replacement. Reopening one retained installation established that original
retirement operation `207` was terminal and applied without resubmission. A
diagnostic run then exposed an actual overflow recovery defect: a fresh reader
returns `Overflow`, while `FailedRelationalQuery` only describes reuse of an
already failed reader. The former had remained pending until `549798c32` added
its failure disposition. The watcher now reconnects only independent metadata
observations after transport/session loss; permission denial still fails the
fixture. These failures remain in `/tmp/transit-m12-final-installed-retry.log`,
`/tmp/transit-m12-final-installed-isolated.log`,
`/tmp/transit-m12-debug-refusal.log`, `/tmp/transit-m12-node-debug.log` and
`/tmp/transit-m12-final-overflow.log`.

The shared current-v1 definition is
`082c5ef4fcfe2d1daa385774f5843ecf933af68d68a91df4b7d1281faf55dca1`.
All 58 fast checks pass at `a826d6754`, and all 19 contract checks pass there
without inherited outputs. Schemas, signing fixtures and binding resources use
that definition. Complete clean `interfaces-relational` and `interfaces-sql`
lanes pass at `c2316c8ce385` and `35cc77b97534`, respectively; logs are retained
as `/tmp/transit-m12-qualified-clean-interfaces-{relational,sql}.log`.
These selections do not establish full qualification: SDK interop encountered
MinIO `XMinioStorageFull`/HTTP 507, and the broader core/storage runs were
interrupted to reduce shared-host I/O contention. Successful preceding checks
do not qualify unfinished suffixes.

This evidence does not close the full crash matrix, cardinality growth gates,
dedicated installed revocation schedule, or T5/T8 implementation correspondence.
It establishes no historical output snapshots, abandoned immutable-record
collector, multi-source execution, Stream/KV/Document inputs, sink delivery or
zero-allocation/performance guarantee. The broader milestone remains in progress.

## Collated TEXT relational execution and owned results — 2026-10-26

The current-v1 cutover adds nullable `int64` and `utf8` relational values to
filtering, projection, equijoins and grouping. `SUM` remains integer-only.
`UTF8_BINARY`, `ASCII_CI` and `EBCDIC_CP037` define comparisons, group identity,
index ordering and exchange routing; joins reject unequal declared collations.
The first contributing row supplies a group's displayed spelling. An equal
collated identity can therefore have a paired delta with different text values.
The shared definition becomes
`e374e6f34d0a317e1fedcde79a548b45e124f1751a3bc62494aadcb7e69988d5`;
stored records, generated contracts, caller fixtures and signing inputs migrate
together. Earlier definitions reject rather than being decoded as this format.

Rows, outputs, index keys, checkpoints and exchange records now have explicit
owned text lifetimes. A value vector admits at most 1 MiB of cumulative TEXT;
larger record envelopes reserve their complete bounded constituents. Captured
and maintained readers have stable heap addresses so their budget allocators
outlive returned rows. Callers release rows before the owning reader. Spill
charges actual text bytes, and a segment larger than total exchange credit
fails explicitly instead of waiting forever for impossible credit.

Executed with the pinned Zig development shell (Debug component checks and
`ReleaseSafe` service binaries):

- Fuze relational selection passes **66/66** tests, including retained join
  rows, collated group representatives, checkpoint restore after source release,
  encoded output/delta/exchange ownership and immutable group indexes. The
  additional exhaustive output/delta/exchange allocation-failure selection
  passes **23/23**, including imported dependencies.
- Query relational selection passes **43/43** tests. Its disk-spill growth case
  consumes **36,448 inputs**, retains **18,224 groups**, uses a **145,789-byte
  resident bound**, writes **2,770,048 spill bytes** and returns **473,873 result
  bytes** in **54,674 steps**. TEXT spill and 16 KiB TEXT exchange rows retain
  owned values across producer and receiver transitions.
- The independent relational oracle compares **312 SQLite cases**; the
  exchange oracle checks **81 independently calculated text routes**. The
  Python caller's **7 tests**, TypeScript caller checks and Board's **101 tests
  in 12 files** pass with typed integer/text group identities.
- `just check fast` and the contract checks pass **36** and **18** checks
  respectively. Generated schemas, ABI declarations and neutral fixtures agree
  on the new definition. These are working-tree checks, not clean-source CI.
- The complete direct captured-query service schedule passes: captured TEXT
  joins/groups, retained row ownership, existing integer captures, named
  declarations, maintained backfill and resume, node replacement, permanent
  failures, overflow/work/spill/history limits, exchange continuation and unified
  Arrow boundaries. The subsequent TEXT-maintenance fixture is qualified
  separately below; it was not in the binary for this broad run.

The focused relational service rerun passes captured and maintained collated
joins/groups, worker replacement after a persisted compute checkpoint, retained
rows across subsequent reads, current disclosure denial/restoration, and two
complete maintained revisions. Deleting the earliest `Alpha` contributor produces
exactly one paired delta to `aLPHA`, with equal collated group identity and the
new aggregate count. Both revisions return four groups and a verified terminal
position. The passing rerun reports no allocator leaks. Earlier attempts exposed
fixture assumptions about rotated credentials, unrelated pin-fault injection,
the initial absent compute checkpoint and ownership of allocated retention
grants; the corrected fixture completes all assertions without relaxing them.
Its raw output is `/var/tmp/transit-m2-relational-text-maintained6.log`.

Raw runs are retained locally as `transit-m2-relational-text-*.log` under
`/var/tmp`. The reproduction entry points are the Fuze `test` and query
`test-unit` targets with relational filters, the neutral contract drivers, and root
`zig build test-direct-captured-query -Doptimize=ReleaseSafe`. The focused
`-- --relational-only` service option runs captured and maintained relational
cases without the unrelated finite-capture uncertain-pin schedule. This record
does not establish arbitrary SQL types, maintained incremental algorithms,
distributed exchange or the final clean-source milestone gates.

## Captured direct Table request batching — 2026-10-24

`nix develop --command zig build test-direct-captured-query -Doptimize=ReleaseSafe
-- --captured-only` passes with 23 authorized publication read batches observed
from the actual source worker. The direct Table wrapper had omitted native
`readBatch`, causing published requests to use separate reads for each 256-byte
chunk on every continuation. It now forwards the existing bounded operation.
The HTTP fixture requires combined descriptor/chunk reads of at most eight keys.

The same run preserves original-cut recovery after lost pin/release replies and
node replacement, retained Table evidence after pin closure, current disclosure
denial and cleanup after credential rotation. This result does not qualify the
separate Compose browser timing schedule.

## Direct Follow browser lifecycle — 2026-10-24

`nix develop .#serving --command just test::reactive-views-lifecycle` passes the
embedded Board/Chromium multi-tab schedule against direct Table storage. It
checks independent sessions for one principal, actual stream loss with the
original snapshot basis retained, reconnect without session replacement,
pagehide and abandoned-session expiry, watch-generation reset, explicit
resnapshot, and protected-state removal after the catalog lifetime resource is
retired. The native/browser portion completes in 71.29 seconds; dependency
installation and build time are additional.

The schedule exposed a recorded renewal rejection being treated as a temporary
disconnect. LiveView now stops in `reset_required`, retaining the original
diagnostic and snapshot until explicit resnapshot; current denial or expiry
still takes precedence and clears protected state. All 18 focused LiveView unit
tests pass, including a single-renewal regression and denial precedence for both
lease conflicts and watch resets. Board and reactive-client formatting/lint and
Board strict TypeScript checks pass. This does not qualify the remaining
Compose/reference Follow placement or credential-rotation schedules.

## Direct Flight and captured-query consumers — 2026-10-24

The public-query, Board captured-query and Flight fixtures now provision Tables
through `DirectTablePreparedDdl`/`DirectTablePreparedDml` and the signed direct
service. Catalog storage, source worker progress and requester progress have
different resource identities. The local authority and Table owner share one
durable directory; the fixture's Ursula/MinIO services do not establish tiered
Table persistence.

Executed with the pinned development environments:

- `nix develop .#serving --command just test::public-query` passes actual query
  hosts and the operation-fixture shell: 41 exact int64/null rows, lost accepted
  replies, original signed retry, fresh fenced ownership, incomplete-prefix
  refusal, busy admission, cancellation and current read denial. A forged logical
  column type with an unchanged definition identity rejects before admission.
- `nix develop .#serving --command zig build test-board-query -Doptimize=ReleaseSafe`
  passes explicit capture, identical preparation/submission recovery, typed pages,
  bounded capacity retries, exhaustion and current denial. This command does not
  include the browser schedule.
- Adding `-Dquery-browser=true` also passes the embedded Board/Chromium schedule
  in 52.7 seconds of browser execution: Canvas/Browse navigation, exact lost-send
  retry, typed results, current revocation, restored access and explicit reopening
  of the retained result. The fixture separates data and progress resource IDs.
  It exposed and corrected their conflation in workspace validation and recovery
  links, empty Follow recovery storage, and replay of a prior draft denial during
  access refresh. Failed attempts are superseded by this complete rerun.
- `nix develop .#flight --command just test::flight` passes native TLS PyArrow,
  ADBC Python/C and saved diagnostic recovery on the updated schema check. Flight
  repeats an original query after a direct row change and retains the old result;
  a distinct first sequence captures the changed row. The finite-statement
  portion completes in 64.22 seconds; that is not the full command's elapsed time.
- `nix develop .#flight --command just test::flight-faults` passes on the updated
  schema-validation implementation with two scoped mappings: lost acceptance,
  gateway replacement, unchanged retry bytes/receipt, current SELECT denial after
  a returned batch, released pins, bounded concurrent fetch/control work,
  malformed/slow peers, requester retirement and original result recovery through
  worker/node/gateway replacement. Sampled gateway RSS is 81,383,424 bytes, below
  the fixture's unchanged 192 MiB ceiling; this is not a measured peak.
- `nix develop .#flight --command just test::flight-placement compose` passes
  TLS PyArrow/ADBC Python/C and physical gateway, query worker, node and store
  replacement in 507.16 seconds. The original ticket and admission retry retain
  their accepted results. Native history and direct Table files persist in the
  authority directory; the fixture reports no cold Table objects.
- The focused query-package `test-unit -Dtest-filter='general Table'` passes.
  Query-client browser-library tests pass all 57 cases and Board unit tests pass
  all 95 cases. Board formatting, lint and strict TypeScript checks pass.

The schema regression exposed that checking the stored definition identifier
alone did not authenticate its separately supplied logical descriptor. New-work
metadata now compares that descriptor with the authorized stored schema;
retained execution still uses its original pin and interpretation.

`nix develop .#flight --command just test::flight-placement reference` also
passes the complete TLS PyArrow/ADBC Python/C schedule after the courier change,
including physical gateway, query worker, node and store recovery and the exact
original ticket/admission retry. The placement portion completes in 991.94
seconds and reports zero cold Table objects. This complete rerun supersedes the
earlier ADBC C deadline failure; it does not establish a latency target.
These scoped runs do not close the remaining actor-Table consumer
removal, coordinated artifact cutover or final repository/clean-build gates.

## Retained relational caller conformance — 2026-10-24

`nix develop .#bindings -c zig build test-relational-callers
-Doptimize=ReleaseSafe -Drelational-sdk=python` passes **1,390 public requests**
through the native C ABI, native port and independently installed synchronous
and asynchronous Python clients. The corresponding `-Drelational-sdk=node` run
passes **1,087 public requests** through the native callers and installed
TypeScript API. Matching Python wheels and Node tarballs were rebuilt with
`just bindings::python-build bindings::node-build`.

The fixture provisions three Tables through the direct owner and produces
`.tseg` files. Two configured routes identify one catalog. Both route layouts
join independent Table cuts; a self-join explicitly shares one retained pin.
Nullable keys, unmatched rows, duplicate matches and COUNT/SUM groups have
independent expected results. Every open carries the original complete bindings
and explicit snapshots. Repeated open/page/close is stable; malformed bindings,
changed work and invalid/skipped/earlier cursors reject.

Two abrupt node replacements and one killed native port preserve original
retention. A pooled connection can report unavailable after node loss; the test
retries only the identical cached read permitted by its diagnostic. Destroying a
query client invalidates its old cursor. Explicit reopening from the original
bindings and snapshots starts execution from the beginning, without acquiring a
new source basis. Each installed Python and TypeScript API exercises the same reconstruction.
Current denial blocks a cached row. Output exhaustion preserves an incomplete
prefix and its original failure; overflow retains the exact output column and
ordered source-row witness. Local query closure leaves the pins owned; the
fixture explicitly releases each original pin and verifies its released state.

The former actor-catalog fixture is replaced by this direct service schedule.
The first attempt stopped on an obsolete malformed-binding error expectation;
the second stopped on a stale pooled connection after replacement. Neither was
passed evidence. This run does not establish automatic recovery of execution,
mixed-catalog joins, physical reclamation or the final repository gates.

## Explicit relational queries over retained definitions — 2026-10-24

The ReleaseSafe `just test::direct-table-service` rerun passes **1,253 typed
calls** and the original three-restart CRUD/DDL, retained-read, delegation and
change-reader schedule. The added query explicitly supplies the original saved
Table binding and pin after DROP/name reuse; COUNT reads the original two rows,
then verifies terminal completion. A changed source name or a different retained
interpretation is rejected. Source metadata and output disclosure use current
snapshot rights rather than requiring the old interpretation to remain live.
This run includes the ongoing SDK cutover's matching native binaries and fixtures;
it qualifies the shared retained relational implementation, not completed
interactive language bindings or a resumable cursor after host loss.

## Named query dependency publication and retirement — 2026-10-24

Under shared current-v1 definition
`fb5dbd8980b7260fecf93af4f0d47684cc6d386d8bd86c92009b98530a64edd0`,
the Station application naming tests pass pure saved publication preparation,
owned JSON restoration, exact source/dependent bindings, logical references
independent of retained physical locators, conditional publication, retirement,
name reuse and preserved original attribution. Independent Python fixtures verify
the `NRL1` logical digest, mandatory proposal digest, `NRT1` retirement record and
exact keys. The complete Station application package suite passes; reproduce it
with `zig build test` from `packages/zig/transit-station-app` in the pinned Nix
shell. The complete catalog package suite and its additional `dependency
membership` filter pass current graph observation, metadata denial, inert reads,
removed membership despite an old successful receipt, exact response binding and
rejection of a missing membership field or substituted operation result.

An initial saved-plan test exposed borrowed JSON strings that outlived their
temporary preparation buffer. The loader now owns its decoded bytes and the
regression passes. The first two public captured-query runs reached their
600-second supervisor deadline while progressing through the added node-restart
schedule. Neither is passing evidence. The dedicated captured schedule now allows
1200 seconds for twelve accepted-reply faults and both query/retirement shapes;
per-operation and bounded-work assertions remain in force.

The public captured schedule passes `zig build test-direct-captured-query --
--named-only`: six exact source registrations and six native naming acceptances
withhold their replies, each followed by abrupt node replacement. Publication,
authorization and retirement recover their original native receipts after worker
generation/key rotation. Four saved publication plans remain byte-identical.
Self-joins share an edge; independent Tables retain distinct cuts and edges.
Both shapes verify inert publication, explicit activation, original result
attribution, current disclosure denial/restoration, stale/error freshness,
DROP RESTRICT before cleanup, exact retirement/removal and complete retained
results after source DROP. Replaying the old registration cannot restore a
removed edge or make its publication plan ready.

The maintained schedule passes `zig build test-direct-captured-query
-Doptimize=ReleaseSafe -- --maintained-only` under the same source definition.
It recovers six registrations and six native publication/policy/retirement
acceptances across abrupt node replacement and worker credential rotation;
all four saved publication plans remain byte-identical. Both self-join and
independent-Table shapes complete backfill and original physical history progress,
verify no-op revisions and paired deltas, close their original history leases,
enforce current disclosure denial/restoration, reject DROP before cleanup and
retire both named definitions before explicit edge removal. The original retained
revision remains readable after source DROP; explicit result retirement then
requires reset. These are separate logical retirement and cleanup operations.

The first Debug run completed preparation/key recovery but
hit the 600-second deadline while the second query shape was still advancing in
backfill. The dedicated two-shape backfill phase now has a 1200-second supervisor
budget; the incomplete run is not counted as passing evidence. The second Debug
run passed preparation and backfill, then exceeded the 900-second resume deadline
after recovering the first retirement acceptance. It is also incomplete. The
passing ReleaseSafe run retains the same budgets and assertions.

Generated schema/ABI/signing fixtures and `just contract::check` pass.
Diagnostic mappings and inventory pass with 594 production owners, 4864
owner/error pairs and 5071 error-return boundaries. The complete handbook check
passes formatting, types, nine content tests and production build. The complete
`just check` also passes at source `849901e64` in the pinned Nix shell, after
installing locked frontend dependencies. This includes the native/package tests,
generated contracts, CLI, Board and handbook checks. Clean-checkout qualification
and a full check of the final integrated source remain required before delivery.
These checks do not establish atomic catalog/native publication, automatic
reconciliation, SQL view publication or service-managed query scheduling.

## Saved Follow control and preparation recovery — 2026-10-23

The direct Follow schedule under definition
`554fe1fda3e411cf8699db84285f655ae459494c04192fb6dfa66b29b00c12fa`
passes original receipt recovery before/after native acceptance, namespace
mismatch rejection and unchanged principal sequences during read-only recovery.
The private reactive owner decodes actual signed controls, rejects a valid
signature from another key before acceptance, and returns original receipt
positions afterward. The Workspace wrapper exercises the corresponding prepared
upload receipt operation. Existing prepared-capture selection, node restart,
worker replacement, fresh verified output and bounded pause still pass.

```sh
nix develop -c zig build test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --follow-only
```

In `nix develop`, the query and serving package suites pass 143 and 52 tests.
The query-client
TypeScript suite passes 57 tests; the full Board suite passes 93 tests, and a
subsequent focused run passes 29 session/Follow/live-view tests after adding exact
attachment metadata recovery. Strict types, Board formatting/lint and the Board
production build pass. The reactive package reports one existing catch-parameter
lint warning and no errors. Generated query/Board/reactive contract checks,
diagnostic inventory/mapping checks and the nine documentation tests/build pass.

```sh
cd packages/zig/transit-query && zig build test -Doptimize=ReleaseSafe --summary all
cd packages/zig/transit-serving && zig build test -Doptimize=ReleaseSafe --summary all
cd packages/ts/transit-query-client && vp check && vp exec tsc --noEmit && vp test run
cd apps/transit-board-web && vp check && vp exec tsc --noEmit && vp test run && vp build
cd apps/transit-board-web && vp test run src/session-recovery.test.ts src/follow-recovery.test.ts src/live-view.test.ts
```

Run each command from the repository root. Browser-owner tests use injected
transport observations: inert import, no saved rows, failure to persist before
dispatch, original accepted token recovery, changed saved input/scope rejection,
template/pool/budget binding, consumed-pool reuse without re-preparation,
exhaustion without replacement, and interrupted closure without reopening. The
composed Board artifact validates all three owners before making them operational.
These tests do not establish an installed browser reload against the private
HTTP host, credential rotation at lost replies, or Compose/reference deployment
qualification. Those schedules and full repository/committed-HEAD checks remain
required; the milestone and its broader tracking issues remain open.

## Named maintained revision inspection and recovery — 2026-10-23

Under definition
`554fe1fda3e411cf8699db84285f655ae459494c04192fb6dfa66b29b00c12fa`,
this native local-persistence schedule passes:

```sh
nix develop -c zig build test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --maintained-only
```

Self-join and independent-Table maintenance now publish an immutable named
definition and explicitly authorize/activate it. Repeated publication and metadata
reads leave policy, execution and history leases absent until their separate
operations. A node restart recovers the original acquisition, followed by another
restart inside bounded physical history traversal. Initial output, complete
successors/deltas, no-op revisions, lease cleanup, current revocation/restoration
and retirement pass through those named activations.

`NamedRelational.maintainedDefinition` resolves actual result and delta readers
through their original retained native snapshot. It preserves attribution after
a later named definition and after node restart, rejects a foreign computation
scope, consumes no output and cannot establish a consumer checkpoint. Exhausted
readers reject inspection. Source freshness remains bound to the inspected
revision; inspecting definitions/freshness leaves the maintenance head unchanged.
The existing result reader performs complete coverage and current-rights checks.

Diagnostic inventory/mapping checks and `just transit-docs::check` pass, including
nine documentation tests and the production documentation build. This schedule
does not inject lost native naming replies or credential rotation at those replies;
the older naming fixture still needs migration. Direct dependency registration,
full repository checks and the committed-HEAD clean gate remain outstanding.

## Query-owned computation evidence — 2026-10-23

Under definition
`554fe1fda3e411cf8699db84285f655ae459494c04192fb6dfa66b29b00c12fa`,
the catalog and application package suites pass 127 and 45 tests respectively:

```sh
cd packages/zig/transit-catalog && zig build test -Doptimize=ReleaseSafe --summary all
cd packages/zig/transit-station-app && zig build test -Doptimize=ReleaseSafe --summary all
```

Run each command from the repository root in `nix develop`. The generic catalog
computation record, caller-supplied completion operation and schema-only freshness
inspection are removed. Canonical record tests reject their retired kind/action
tags even under a current header, and the JSON caller rejects the removed
inspection action. Captured and maintained query owners retain their actual
execution/result evidence; named KV/Document metadata does not acquire stronger
provisioning semantics from this removal.

The shared current-v1 definition changes for the removed stored and caller
contracts. Reflected contracts, language bindings, independent signing fixtures
and diagnostic inventory/mapping checks pass. The prior definition remains an
explicit rejection case. These checks do not complete direct dependencies, named
resource provisioning, full repository qualification or the committed-HEAD clean
gate.

## Result source freshness and named attribution — 2026-10-23

Under definition
`312fcb8d609365bc55ffa7ddbe0242493e843256539f96889a51a2fba0f2b9c0`,
these native local-persistence schedules pass:

```sh
nix develop -c zig build test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --named-only
nix develop -c zig build test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --maintained-only
nix develop -c zig build test-direct-table-service -Doptimize=ReleaseSafe --summary all
```

Captured self-join and two-Table results compare their actual retained cuts with
current logical-change positions. Pin progress and accepted no-ops remain fresh;
DELETE without a schema change reports stale. Same-Table aliases agree, while an
unchanged independent Table stays fresh. The HTTP fault peer injects a generic
conflict and unavailable response; neither becomes definition-change evidence.
Current revocation denies inspection. RENAME reports `definition_changed` through
the specific wire rejection, and the original result still verifies COUNT=1 and
complete coverage. Exhausted readers reject further freshness inspection.

`NamedRelational.capturedDefinition` resolves original attribution through the
result reader's retained snapshot, even after a later name revision. A foreign
computation scope rejects; inspection consumes no output and uses the reader's
request budget. Maintained revisions report the original backfill stale after a
row change and the latest completed revision fresh after restart and catch-up.
Inspection leaves the maintenance head unchanged and cannot produce a consumer
checkpoint before output verification. The direct Table suite passes 549 typed
exchanges, including explicit `TableDefinitionChanged` after DROP/name reuse.

Package suites pass 143 query, 45 application, 50 protocol and 51 serving tests.
Reflected contracts, generated bindings, independent signing fixtures and
diagnostic inventory/mapping checks pass. The shared current-v1 identifier is
replaced for the distinct wire rejection; the prior definition rejects. These
checks do not complete generic catalog computation replacement, direct dependency
registration, named-maintenance inspection, full repository qualification or the
committed-HEAD clean gate.

## Named captured definitions over the direct service — 2026-10-23

Under definition
`18d5e193251f177dbf700e9601a6dede6e98e48d9c2c744049ffacc1b0601ca8`,
the following native local-persistence schedule passes:

```sh
nix develop -c zig build test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --named-only
```

The equivalent task is `just test::direct-named-query`. Both a self-join and two
independent Tables use separate computation resources. Upload and named
publication leave query policy, activation and direct pins absent. Explicit
authorization still starts no work; the publishing peer's separate activation
executes the frozen bundle. Worker replacement during acquisition preserves its
original grants and named attribution. Later named publication advances the
definition without changing the completed query's original policy or attribution.
Result readback verifies COUNT=1 and complete coverage after pin cleanup; current
source revocation denies disclosure and restoration permits it. The executor
still cannot independently look up the Table.

This schedule does not inject node restart or lost native replies into the naming
layer, and does not replace the older named-maintenance native fixture. Result
freshness and the generic catalog computation-completion path remain separate
open work. Full repository and committed-HEAD clean qualification are outstanding.

## Explicit Workspace capture and separate caller recovery — 2026-10-23

Under definition
`18d5e193251f177dbf700e9601a6dede6e98e48d9c2c744049ffacc1b0601ca8`,
the native Follow schedule passes through `Workspace.compile`, `capture` and
`refresh`. Compilation leaves the bundle unsigned; explicit capture requires a
configured executor and rejects an already authorized bundle. Preparation neither
acquires a Table pin nor advances the Table acceptance position.

```sh
nix develop -c zig build test-direct-captured-query -Doptimize=ReleaseSafe -Ddirect-query-example=true --summary all -- --follow-only
```

This run also starts the actual `example-state-query` executable as a separate
caller. It compiles and saves its capture before upload, recovers the same saved
bundle in a new OS process without changing its recovery file, and reads verified
complete coverage with SUM=20. The native worker runs under its own credential
and independent progress resource. The Follow selection/restart/replacement
schedule also passes. This additional example schedule does not inject a lost
upload reply or qualify Compose/reference placement.

The query package passes 142 tests; the TypeScript query client passes 55 tests,
`vp check` and `vp exec tsc --noEmit`. Draft caller cases cover saved-grant reuse
after a lost upload reply, independent grants for selected edits, capture denial
before dispatch and changed-metadata rejection. Board's focused workspace/live
state suites pass 23 tests; its type checks and actual binary/embedded frontend
build pass. Generated Workspace/Board contracts and diagnostic mappings/inventory
checks pass. Installed browser reload, remaining legacy callers, the full
repository check and clean committed-HEAD gate remain outstanding.

## Current-capture cleanup after definition changes — 2026-10-23

Under definition
`18d5e193251f177dbf700e9601a6dede6e98e48d9c2c744049ffacc1b0601ca8`,
`nix develop -c just test::direct-table-service` passes 549 typed HTTP exchanges.
Two current-frontier grants are saved before restart; one acquires a pin and the
other remains absent. After ALTER, authorized cleanup proves the absent grant
can never acquire under its original definition, without appending a pin record.
The previously acquired grant instead recovers and releases its original cut.
Delayed acquisitions reject in both cases, including after another restart and
DROP/name reuse. Current revocation denies cleanup of both grants. The existing
uncertain acquisition/release and retained-history schedules still pass.

The catalog suite passes 127 tests. The focused storage `-Dtest-filter=pin` suite
passes seven tests, and catalog `-Dtest-filter='pin status'` passes four. Mandatory
interpretation evidence and foreign-object response rejection are covered.
`just contract::check`, diagnostic mapping/inventory checks and `git diff --check`
pass. These checks do not rerun the broader captured/Follow or browser schedules;
the full repository check and clean committed-HEAD gate remain outstanding.

## Prepared finite refresh and direct watch transitions — 2026-10-23

In the pinned Nix shell, `zig build test -Doptimize=ReleaseSafe` in
`packages/zig/transit-serving` passes all 51 tests. Direct catalog fixtures cover
authorized read-only observations, logical change watermarks, exact retained-cut
coverage and current interpretation rejection. Scheduler tests use real native
upload/preparation records and direct observations, with execution/results and
authority injected at the reader boundary. They cover fair selection, restart of
requester state, independent manual admission, pause/closure, cancellation,
retained failures and explicit admission of an already selected prepared request.
These fixtures do not verify complete query execution or native authentication.

`vp test run` in `packages/ts/transit-query-client` passes all 52 tests; `vp check`
and `vp exec tsc --noEmit` pass. Sixteen refresh-caller cases cover bounded distinct
identities, exact-token retry after a lost submission reply, pending acceptance,
caller-scope changes, rejection and refusal to relabel an activated request as
prepared. Export/restore cases recover lost and accepted-pending inputs without
new grants, recheck saved readiness, reject a changed connection and bound malformed
recovery input before any dispatch. `vp test run src/live-view.test.ts` in `apps/transit-board-web` passes
all 16 tests. These browser state fixtures do not replace the native Follow or
installed browser proof. Full repository and clean committed-HEAD checks remain
outstanding for this change.

Under current definition
`02553baa7d791340e9ea3339002537bf15495c26bd2f2bd2e2fde5950589e53f`,
`just contract::check` passes; the query and catalog package suites pass 142 and
126 tests. `just test::diagnostic-outcomes` passes 3,410 projections after adding
prepared status and direct-source failure mappings. `just check` reaches the unit
suite but cannot pass while the named relational and work-item example fixtures
still construct the removed actor Table query source. These require migration;
the successful focused suites do not certify those callers.

The direct Follow composition passes:

```sh
nix develop -c zig build test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --follow-only
```

The equivalent task is `just test::direct-follow-query`. This real disk-backed
native node uses separate Table, query-worker and requester resources, with a
separate read-only inspection credential. It executes and verifies a completed
template, prepares two independently signed current captures without remote pins,
accepts Follow and a row update, then restarts the node after committed selection
and before activation. Worker replacement resumes the same selected namespace;
the verified sum changes from 10 to 20, the accepted Table position advances and
acknowledgment covers the observed change. Pause leaves the second request prepared.
Every control's exact signed duplicate returns its original receipt. This schedule
does not yet inject lost pin/release replies into Follow, revoke the original
caller during selection, rotate credentials, or exercise installed browser reload.

## Retained Table evidence and current disclosure rights — 2026-10-23

The combined public run passes under definition
`38fb0433e2dbce32b39167abb988460d09b813d8f2de519e78fbb8ca732b40e8`:

```sh
nix develop --command zig build test-direct-table-service test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --captured-only
```

The Table schedule passes 530 typed exchanges. `read_authority` returns the same
native source requirements as an authorized observation, denies a revoked caller,
and remains available for the original object after DROP/name reuse. It agrees
with that object's retained snapshot authority, without acquiring another pin.

The focused single-source capture schedule retains node restart, uncertain
acquisition/release and credential-changing cleanup. `UnifiedResult.open` returns
the exact recorded Table basis after its source pin is closed; its commitment
matches the verified result page. Current revocation denies both metadata open
and page disclosure. The schedule does not run relational, maintained, exchange
or installed SDK consumers unless separately selected. The default full schedule
retains those cases.

The query package passes all 143 tests, including native KV/Document results
whose `table_basis` is null. The focused catalog selection passes 33/33 tests;
retained and borrowed grants cannot use the new authority-discovery action.
Direct contract regeneration and validation pass. Reactive consumer migration
and full repository qualification remain unfinished.

## Direct maintained successors and query fixture migration — 2026-10-23

The direct runner's `--exchanges-only` and `--relational-failures-only` schedules
pass under definition
`38fb0433e2dbce32b39167abb988460d09b813d8f2de519e78fbb8ca732b40e8`:

```sh
nix develop --command zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --exchanges-only
nix develop --command zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --relational-failures-only
```

The exchange schedule now publishes two maintained revisions using one producer,
first with one partition and then seven. A live delete before the first scan
leaves its original two-row result intact; the next revision uses a fresh vector,
assignment and borrowed-read proofs and returns one row. Incomplete attachment
and attachment of the old exchange reject without changing the native decision.
An old borrowed proof cannot read the newer cut. Reconstructed hosts preserve
progress and drain producer acknowledgements before changing assignments.
Retiring the live request publication before either scan leaves the accepted
computation's retained request available. Cancellation closes its history lease
while both results remain readable; explicit query retirement releases the
request and rejects later result reads.

The five failure cases retain work/spill and ordered-overflow assertions. After
the service-reported history gap, a new executor and accepted query identity
acquire a current cut and publish count four, sum six. That query closes its own
lease. The failed original identity, original failure and prior result remain
unchanged after both the restored-service wake and the explicit rebuild.
These runs reconstruct hosts but do not inject lost native receipts or restart
the node. Multiple exchange workers and credential-changing cleanup remain
separate qualification work.

`nix develop --command zig build test --summary all` in
`packages/zig/transit-query` passes all 143 tests: 140 component tests and three
native-contract fixtures. The obsolete actor-store maintained tests are replaced
by the direct backfill/delta, failure and exchange schedules. Table lifecycle and
retained interpretation checks use the public direct capture/source-page
schedules; native KV/Document fixtures remain. The contract fixture uses injected
authorization to reject unsigned, changed, misrouted, stale-epoch and wrong-role
proofs, including changed retention purpose/executor, without publication. It
does not claim a new real-service authority proof. Full repository and installed
caller qualification remain pending.

The migration initially found stale record lengths and the SQL inspection
fixture's removed Table metadata fields. Current native checkpoints occupy 222
bytes and the tested manifest 366 bytes. The fixture now uses direct
interpretation descriptors; parsing remains strict. The direct scalar fixture
also checks the Table catalog resource independently of the query progress
resource. Earlier failed fixture runs are not counted as passing.

## Finite direct capture memory and retirement — 2026-10-23

`nix develop --command zig build test-direct-captured-query
-Doptimize=ReleaseSafe -- --unified-boundaries-only` passes five public cases
under definition `38fb0433e2dbce32b39167abb988460d09b813d8f2de519e78fbb8ca732b40e8`.
An empty Table is captured, renamed and dropped before traversal completes; the
verified empty result preserves its original schema. Explicit result retirement
collects its publication while keeping the completed source pin closed. A stored
600 KiB text value exceeds the normal 1 MiB decoding adapter, records a durable
budget failure and remains readable through a separately acquired current pin.
Explicit adapter and Arrow workspace exhaustion also retain the failure identity,
close the original pin and preserve the stored row. Hosts are reconstructed
during bounded progress. Separate client failures cover both the allocating
writer's `WriteFailed` and the Table HTTP response allocator's `OutOfMemory`.
Both leave the native proposal unchanged, produce no terminal query diagnostic,
and permit the same query to complete with healthy memory.

The schedule exposed a local allocating JSON writer returning `WriteFailed`
instead of `OutOfMemory` while validating a saved grant. Capture now classifies
either error as an adapter budget only when its own fixed allocator records
exhaustion. Failed resize/remap probes do not establish that evidence. Twenty-nine
selected query tests pass across capture, KV/Document sources and allocator
classification. They preserve external publication and poisoned retained-read
errors, exact budget/runtime witnesses, replay, cleanup and later healthy work.
The current native retention encoding stores the input once as the job ID;
failed native job records occupy 248 bytes. These checks replace the superseded
actor-store Table capture/memory fixtures and retain native KV/Document coverage.
The two direct native contract tests also pass, preserving exact checkpoint
encoding and prepared scalar ownership.

This focused schedule does not restart the node or inject lost native receipts.
The full query unit build still fails at the unmigrated maintained actor-store
fixture's call to `TableSource.from`; it is not reported as passing. The broader
current-definition and installed caller checks remain pending. Documentation and
diagnostic inventory/mapping checks pass separately.

## Direct relational failure boundaries — 2026-10-23

`nix develop --command zig build test-direct-captured-query
-Doptimize=ReleaseSafe -- --relational-failures-only` passes five public cases
under definition `fa0ce9cb4eb38397a9ad22078cbf6ca4fc0f8426a0428853fc136553dd13eb52`.
Captured work/spill limits and captured/maintained SUM overflow produce durable
failure records. The overflow input includes a later cancelling value; evaluation
still records the first overflowing row identity and output column. Recreating
the host during bounded steps preserves the result and witness. Captured cleanup
collects abandoned pages while retaining the failed checkpoint. Failed maintained
successors preserve the preceding complete manifest and verified result. Every
case closes its original direct lease.

The gap case replaces one successful history response at the HTTP test proxy
with `HistoryReclaimed`. The coordinator records `TableHistoryGap`, preserves the
last complete revision, and rejects implicit resumption after the proxy restores
ordinary responses. The test waits for the subsequent explicit wake to commit
before checking the unchanged failed identity. This is a service-boundary fault
injection, not evidence of end-to-end disk corruption recovery.

The storage `Table history retention` ReleaseSafe filter passes three tests.
Its new disk-backed case deliberately trims required WAL coverage through the
lower storage test interface, bypassing the Table retention owner. Historical
reads reject without changing the accepted Table root or releasing the lease.
The HTTP owner maps explicit missing/trimmed Table/WAL history to
`HistoryReclaimed`; transport/storage availability failures remain attempts.
No physical history collector is enabled by these checks.

Eighteen selected query tests pass for direct captured bundles/vectors,
historical vectors/scan cursors, finite-exchange vector encoding and source
declaration encoding. They include
truncation, allocation failure, signed grant preservation, independent Table cuts,
alias identity, schema/retirement rejection and fixed scan bounds. These replace
the corresponding actor-store relational fixtures; their runtime behavior is
covered by the public direct schedules. Explicit exchange placement/attachment,
fresh maintained cleanup after credential rotation, older native caller fixtures
and full query/repository qualification remain pending.

## Maintained direct Table queries — 2026-10-23

`nix develop --command zig build test-direct-captured-query
-Doptimize=ReleaseSafe -- --maintained-only` passes under current definition
`fa0ce9cb4eb38397a9ad22078cbf6ca4fc0f8426a0428853fc136553dd13eb52`.
The private disk-backed node runs both a self-join and a join of independent
Tables in one catalog. Each unprivileged executor stores native query progress
outside the catalog resource. The schedule loses the native handle commit after
remote history acquisition, restarts, and recovers the exact original lease.
Accepted changes during backfill do not replace the initial two-row result.
Twelve cancelled row operations form a physical history prefix longer than one
page; a second restart preserves the committed scan cursor inside that prefix.

Explicit wakeups publish the next two logical acceptances, including a no-op,
as separate complete revisions. The verified result reader and exact-successor
delta reader agree on their checkpoints; a changed count has a paired before/
after delta and the no-op has no delta. An empty interval creates no revision.
Cancellation closes every original lease, preserves disclosure of complete
results, and does not preserve source permission after revocation. Restoration
permits a fresh read; retirement requires a consumer reset. An earlier run found
that removing the scan record used the application-key deletion API; switching
to the internal framework write API preserves the reserved-key guard. The
passing schedule includes both logical selection and empty-interval removal.

The query filters `direct history records`, `maintained control`, and `exchange
authorization` pass 13 tests. They cover full-width Table positions, exact source
record/vector encoding, scan alias consistency, control cursor bounds and
exchange authorization binding. These codec inputs do not assert storage
admission. The catalog ReleaseSafe suite passes 123 tests, and the storage
history-retention filter passes two tests. All current generators and independent
contract/signing fixtures regenerate successfully after the definition change.

The prior default captured-query schedule passed its captured phases under this
definition before reaching the scan-removal defect. The successful focused run
does not execute installed SDK consumers or qualify their current artifacts.
The separate failure schedule above covers ordered overflow and an explicit
history-coverage rejection. Exchange and credential-rotation cleanup schedules,
older relational consumers, the full query package and repository checks remain
pending. The two-row cases do not establish throughput or catch-up performance.

## Direct captured Table queries and separate cleanup authority — 2026-10-23

`nix develop --command just test::direct-captured-query` passes against a private
disk-backed local node and signed public native/Table clients. A query worker
with no ordinary Table rights stores progress in a resource independent of the
catalog. The test captures 19 unflushed rows, restarts before pin acquisition,
corrupts successful acquisition and release replies, restarts the node between
attempts, and renames the Table before the native handle is published. Recovery
preserves the original interpretation/frontier and traverses three pages. The
verified COUNT result remains readable after pin release; revoking current Table
rights denies disclosure, and a fresh credential can disclose after restoration.

A second query cancels with a live pin, then rotates the original caller's
credential. The old grant leaves cleanup pending. A separate fresh closure
authorization commits before release, survives a corrupted release response and
worker replacement, and reaches both remotely released and natively closed
state. Immutable source evidence and the original bundle reference remain equal.
The extended direct schedule also passes a malformed fresh cleanup signature:
the control is rejected durably, the pin remains live, and the next valid proof
at the same credential epoch completes cleanup. A third query loses Table access
after admission but before acquisition eligibility. It becomes denied without a
pin, and fresh cleanup after restoring access preserves that absence and failure.
The [fixture](../../../tests/query/execution/direct_captured_query.zig) uses the public clients and real native
hosts; its proxy injects response uncertainty after acceptance, not a fabricated
storage outcome. `CapturedTablePin.observe` supplies read-only closure status.

The Station bindings ReleaseSafe tests pass in `nix develop .#bindings`, including
owned direct endpoint configuration and rejection of caller/role/realm mismatch.
The catalog ReleaseSafe suite passes, including exact closure-signature binding,
rejection of its use as a read grant, and maximum-width source fingerprints.
Documentation checks pass 5,500 local links across 559 files. The direct Table
schema and independent request-signing fixture have been regenerated.

`nix develop .#bindings --command just bindings::direct-captured-python` and
`just bindings::direct-captured-ruby` also pass through their public SDK APIs with
fresh native libraries/ports. They resolve the direct definition and frontier,
compile an unsigned COUNT, and produce exactly the Zig caller's saved authorized
bundle. Missing names remain missing; after recovery, the old name does not
rebind, the renamed definition retains the unchanged schema, and verified results
remain readable under the rotated credential. Python exercises both synchronous
and asynchronous clients. Both callers prepare separate fresh terminal cleanup
controls. These runs use source packages and private nodes; they do not establish
installed wheel/gem qualification or the other languages' runtime behavior.

Python strict checking passes 27 source files. TypeScript type checking and six
query boundary tests pass, covering full-width capture coordinates, independent
resources, distinct cut/retention variants and mismatched lookup-schema rejection.
Those TypeScript boundary tests use a fake port and establish neither authority
nor execution. Rust's library checks and 16 unit tests pass with the freshly built
native libraries. The shared
binding schemas have been regenerated for lookup/capture/cleanup. Documentation
checking passes 5,503 links across 559 files before this evidence addition.

The installed direct capture schedule now passes for all ten languages: Python
(sync and async), TypeScript, Ruby, Rust, C, C++, Java, .NET, Erlang and Elixir.
The command is `nix develop .#bindings --command just bindings::direct-captured-all`;
the recorded run built the packages first, then passed all eight package-directory
options to `zig build test-direct-captured-query -Doptimize=ReleaseSafe`.
Each independently installed consumer resolves the direct definition/frontier,
compiles COUNT, compares the entire authorized bundle with the Zig fixture and
reads the same verified result after rename, restart, pin closure and credential
rotation. Each also prepares a separate cleanup control. C and C++ retain their
owned definition after closing the client; Rust's consumer preserves the SDK's
locked registry dependencies. This proves those public caller operations over
the shared fault schedule; the Zig host still drives execution and injected
uncertainty.

`nix develop .#bindings --command python3 -B tests/sdk_unified.py` also passes
all ten independently installed codec consumers. It checks three source kinds,
nine Boolean bundles, six scalar types, five cell states, 128 columns, uint128,
nested values and malformed-input rejection. These codec checks do not establish
execution authority or recovery; those claims come from the direct schedule above.

The storage `Table ` filtered ReleaseSafe tests pass, including bounded logical
history across restart, accepted no-ops, CREATE/RENAME/ALTER/DROP and current
revocation before disclosure. That component inspection is not yet a public
logical-change feed or maintained-query source adapter.

The direct relational filter passes 12 tests, including exact physical
schema matching, shared alias grants, native-route binding, maximum-width Table
coordinates, every truncated bundle prefix and incompatible-definition rejection.
Two Tables in one catalog require separate pin budgets and distinct pin owners;
their partition/frontier commitments remain independent.
The catalog ReleaseSafe suite also passes after adding retained identity-suffix
reads; malformed coordinates, ordering and an empty initial page reject without
changing sequential coverage. The documentation suite passes its nine ownership
checks, strict types and production site build; local link checking passes 5,505
links across 559 files. The public two-row captured self-join schedule passes:
it uses independent native progress, shares one pin between aliases, replaces
the worker after committed acquisition eligibility, closes the pin and reads a
verified COUNT result. The expanded schedule also passes with two distinct
Tables in one catalog: replacement occurs after the first pin is committed and
before the second acquisition, the vector retains distinct partitions, and both
pins close. Revoking one source's current authority denies result disclosure;
restoring it permits the same verified result. The self-join also passes that
revocation/restoration check. Both cases use two rows per Table and a COUNT with
a post-join filter. The first 19-row combined run exceeded the 240-second deadline.
A separate run showed advancing checkpoints and was stopped before completion;
neither run passed. The lifecycle fixture now uses a two-row self-join in a
separately timed phase, while single-source capture retains its 19-row three-page
case. The one-row checkpoint model's cost on larger captured joins remains a
performance limitation; this fixture does not establish throughput.

The direct point-read extension passes the full catalog ReleaseSafe tests and
the two local native catalog tests. The dispatcher checks both present and absent
keys against a real native authorization fence and suppresses either response
when Table ownership changes after buffering. An executor with no ordinary
Table rights can read only through the original exact-pin grant. The retirement
race asserts native guard denial, separately verifies the resource is expired,
and confirms no new Table authorization registration was published. The reflected
direct envelope and independent signing fixtures are regenerated.

The query package's `general Table` filter passes 16 tests after migrating
descriptor/policy fixtures to direct declarations. These include allocation
failure cleanup, independent recursive bytes, truncation/foreign-definition
rejection, an embedded query arena, multiple Table policy targets in independent
progress storage, and caller/role mismatch rejection before I/O. They use
unpublished definitions and a reference store; they establish no admission or
storage durability. The two `direct native contracts` tests also pass, covering
the maximum native checkpoint key, rejected cut changes and 21 scalar descriptor
families through prepared/neutral query bundles with independently owned values.

The complete public direct schedule now passes with its wide-row phase. A
19-row, 13-column Table has a composite integer/UTF-8 key, nested lists and INT128
values. Its original pin survives column rename, DROP and reuse of the Table
name by another object. Matching and absent composite-key predicates finish in
one source page, while ordinary traversal reads all 19 rows in three pages and
preserves the projected values through Fuze and Arrow decoding. Current
revocation denies both point selections; explicit release makes the original
source unavailable. The same run passes the single-source fault schedule and
both captured relational cases. Catalog tests also pass allocation-failure
cleanup for retained point decoding. Documentation checks pass nine ownership
tests, strict types, the production build and 5,505 links across 559 files.

This is scoped feature-branch evidence. The shared-definition replacement,
remaining generated artifacts, broader caller schedules and older relational
Table paths are still in progress. The full query package currently fails to
compile at those unported consumers; neither `just check` nor `just ci-clean`
has qualified this combined working tree. No milestone or tracking issue is
closed by these checks. Broader multi-source schedules, maintained logical-change
history, remaining caller migration and GC/compaction race coverage remain
separate obligations.

## Station node build profile — 2026-10-26

The [retained control](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/station-node-profile-2026-10-26/report.json)
uses source `9ab5fb64a`. The clean core invocation with a Debug node fails the
unchanged 60-second captured-query completion phase after replacing both host
generations. The first 18 core tasks have passed; later tasks do not run.

With only the node rebuilt as ReleaseSafe, the same Debug administration,
ledger worker, courier and controller binaries pass the complete ledger,
services and lifetime schedules in 115.13 seconds total. The query workload,
60-second phase deadline, five-second native request timeout and all assertions
are unchanged. This sequential correctness control is not a matched latency
benchmark. The owning `just test::station` task now selects that mixed profile,
as the installed Station SDK tasks do. The raw `zig build test-station` target
still honors the selected optimization mode for every artifact.
The changed owning task also passes the full ledger, services and lifetime
schedules at `31b48b73e` plus the recorded task change. This qualifies that
Station task; the complete corrected core lane remains separate.

## Retained-source publication authority — 2026-10-23

The current shared definition is
`f1849ba2a3c5da53b60914a76a25e141790d1d4c4c74adbf3b18be70c24b0677`.
Direct snapshot replies require exact native database/schema/Table authority IDs;
captured pin records retain those IDs for later native publication guards.
Authorization domains now persist an explicit, immutable optional resource
lifetime prerequisite. The previous definition rejects; contracts, binding
resources and independent signing/record fixtures have been regenerated.

The core ReleaseSafe suite passes 122 tests. Its native authority fixture gives
a caller domain access without raw source-resource access, prepares an independent
worker's guarded turn, advances the source deadline, verifies definite guard
denial without maintenance, then materializes expiry and rejects the old prepared
commit. Reopening the engine preserves the binding and denial. This uses the
in-memory page/journal fixture; it does not claim a wall-clock resample after a
transition is prepared. The policy store also rejects lifetime-binding changes.

The query ReleaseSafe suite passes 142 tests, including retained policy IDs,
current Table revocation and rejection of a replacement execution credential
epoch. The local native catalog proof passes. The public direct HTTP proof passes
475 typed calls, checks returned authority IDs through the native guard API, and
preserves exact delegated source/closure behavior across three restarts.
`just contract::check`, diagnostic mappings, inferred-error boundaries and 3,387
outcome projections pass. Documentation checks pass 5,491 links across 559 files.

`just test::server-direct-tables` also passes with a fresh installed local
server: default publication, CRUD/DDL with the old query worker stopped, abrupt
restart, preserved bootstrap intent, deliberate deletion and name reuse. Its
manually signed gateway request now supplies the required `delegation: null`;
omitting the field is explicitly rejected. The first run exposed that stale
fixture and failed before SQL execution; the corrected full run passes.

These proofs establish source authority and retention components. Captured-query
admission, traversal, result publication and physical Table collection still
require integration and qualification.

## Durable-computation pin ownership component — 2026-10-23

`zig build test -Doptimize=ReleaseSafe --summary all` in
`packages/zig/transit-query` passes 142 tests. The new `CapturedTablePin` reference
model checks committed eligibility before direct acquisition, duplicate pin-owner
rejection, original grants across worker replacement, lost acquisition replies,
lost native handle commits, committed closure before release, cleanup denial,
lost release replies and lost native closed-state commits. Both known-handle and
unknown-handle closure paths pass. Partial records and another executor reject.
The fixture uses the native `Turn` proposal API with an in-memory reference store
and modeled remote outcomes; it is not a disk-recovery or end-to-end capture proof.

The catalog's focused ReleaseSafe suites for `direct Table` and `direct read
delegation` pass. `just contract::direct-table-check` independently checks the
309-byte retained grant with Python/OpenSSL bytes and original caller signatures.
Diagnostic mapping/error checks and 5,490 local links across 559 files pass.
The current shared definition remains
`64510390ce1d02e9e93fc04bf00554ca4625ae8b895134fc8cb04e3f5143a96c`;
these additive retention records do not replace an existing stored format.
Captured-query admission, traversal and verified-result integration remain open.

## Exact direct pin closure — 2026-10-23

`just test::direct-table-service` passes 474 typed HTTP calls under definition
`64510390ce1d02e9e93fc04bf00554ca4625ae8b895134fc8cb04e3f5143a96c`.
SQL recovery uses the common direct client's explicit closure operation. The
fixture exercises uncertain acquisition and release, restart, current denial,
and retained pins after rewrite, retirement and name reuse. Recovery without a
known handle rejects a different acquisition frontier for both the original
caller and its delegated executor; the original retained reader remains usable.
Diagnostic mapping and inferred-error checks pass. This qualifies exact remote
closure, not captured-job admission or the decision that a durable job has ended.

## Retained typed Table reader — 2026-10-23

The catalog suite passes **107/107 tests** with `DirectTableReader`. Its new
case rejects changed accepted/logical-change positions, premature completion,
and invalid final-row bytes without advancing the cursor. It checks exact source
row consumption and decodes binary values under the retained schema. Allocation
checking covers partial-page decode failure.

`just test::direct-table-service` passes with **24 typed HTTP calls** after the
reader is wired into the independent caller. The retained source is consumed
after restart, including its original unflushed 64 KiB row. Current revocation
denies both cached-result checks and a completed reader's next call. Explicit
release is repeatable, reopening a released handle returns `QueryExpired`, and
a changed connection is rejected locally. Diagnostic error/outcome checks and
documentation links pass. SQL does not use this reader yet.

## Retained Table page reads — 2026-10-22

The later storage suite passes **55/55 tests** after correcting conditional data
bases at admission. A disk-backed source survives pin acquisition, physical
flush and a canonical no-op before admission, then recovers admitted execution
after reopen. An intervening logical write, foreign partition or future frontier
still rejects. Conditional RENAME likewise survives control progress; replay
preserves the original row receipt. The native dispatcher proof passes a no-op
UPDATE selected from its pinned source, with one matched and zero changed rows.
The catalog suite passes **106/106** and `just contract::check` passes after the
coordinated definition/fixture regeneration.

This changes persisted conflict semantics and selects the shared definition
derived from `transit.native.v1.direct-table-service.2026-10-22`. The prior
definition is an explicit incompatibility case. These checks do not qualify the
in-progress listener, installed SQL migration or automatic point-row flushing.

The subsequent catalog package suite passes **105/105 tests** with the signed
direct request codec. Shared Python/OpenSSL and Zig vectors agree on the complete
request context, signature, Unicode and full-width catalog IDs. New cases reject
missing definitions, modified actions/roles, noncanonical base64, changed row
payload digests, incompatible row interpretations and mismatched mutation shapes.
Binary values, unsigned extremes and negative floating zero survive conversion.
`just contract::direct-table-check` passes its independent schema/signing checks.

`just test::local-catalog` passes with the internal `LocalTableService` dispatcher.
Real signed requests pass through JSON parsing, current native authorization and
disk storage for CREATE admission, hidden pending names, explicit execution,
repeat admission returning the original commit, bulk INSERT, durable pin,
snapshot/schema inspection, row scan and release. Inspection leaves the native
head unchanged. Transferring Table ownership after response buffering denies
the complete page; regrant permits release. This test exercises the dispatcher
in process, not a network listener, installed launcher or SQL adapter.

The following catalog run passes **106/106 tests** with `DirectTableClient`
response validation. Its negative cases reject unrelated contexts, changed
operation IDs, impossible changed counts, wrong accepted partitions, inconsistent
terminal phases and wrong result kinds. The native dispatcher test also passes
every returned envelope through this validator and rejects altered page byte
counts and pin attribution. The client's HTTP method compiles; a network call
through it has not yet been qualified here.

The pinned storage suite passes **54/54 tests** with `inspectSnapshot` and
`scanSnapshot`. New disk-backed cases traverse thirteen mixed unflushed WAL and
segment rows across flush, schema rewrite, DROP and actual owner reopen. They
retain the original two-column interpretation and exact accepted position,
enforce independent row/byte page limits, and reject foreign or fabricated
cursors and released handles. Variable-length returned values remain valid
after the Table owner and its caches are destroyed. A final injected policy
denial discards buffered values and also denies empty end-of-source metadata.
Repeated inspection leaves the Table root unchanged.

`just test::local-catalog` passes with the new catalog read operations under real
native authority. A domain owner without raw-resource access can acquire and
read its pin. Another pin principal rejects. Ownership revocation denies page
delivery and release; regrant permits release even when ordinary data capacity
is exhausted. Returned pages and schema use caller-owned allocations after the
temporary catalog view closes.

This qualifies bounded retained source pages, not public HTTP/SQL result
streaming, service scheduling, a shared catalog cut or physical collection.

## Integrated vector execution

[Issue #71](https://github.com/spoke-sh/transit/issues/71)'s integrated query runtime is
**`5b3d1ba6`**, based on merged `243df508`. File/general Table execution uses
bounded typed columns; logical, Unified and relational callers share kernels.
Portable computation and one worker remain defaults after measured AVX2 and
worker comparisons. Public progress formats, source/page validation boundaries,
current-right checks and publication limits are unchanged. Relational execution
retains its one-source-read/one-group-update quantum and canonical order.

The complete qualification record (archived)
covers **all 79 ordinary tasks**: core 22, growth 30, experience 7, launchers 2
and bindings 18. Every task runs in a pristine committed-source clone with locked
dependencies. Core, experience and launchers are complete clean lanes. Growth
combines its completed fifteen-task prefix with fifteen tasks in a new clone;
bindings combines its completed five-task prefix with thirteen tasks in separate
clones. The unchanged inventory is checked for exact coverage, without omissions
or duplicate credit. These are composed results, not five complete single runs.
The record identifies each source revision, command, result and log hash, and
archives the orchestration scripts for audit. Full reproduction uses
`nix develop --command just ci-clean`; individual lanes use its `--lane` option.

Full `just check` passes at **`83bc1e2e`**. Standalone Fuze ReleaseSafe tests cover
copied rich values, allocation failure, oversized outputs surviving executor
release, first-error frontiers and ordered source rejection. Seeded tests add
32 rebatching inputs for projection, COUNT and ordered SUM and 32 worker
partitions over all five states, portable/AVX2 and 1/2/4 workers. Shared admission,
contention, cancellation and held-output tests preserve memory and control gates.
Benchmark evidence tests reject incomplete/incorrect matrices, regressions and
stale successful reports.

The real Unified KV/Table/Document proof passes frozen upload retry,
worker/node/disk-store restart after staging, complete manifests, prefix
revocation and source-pin release. Flight passes its enabled TLS/ADBC, exact-value,
replacement and current-denial schedules. The independent 315-case relational
oracle, actual Board relational browser, installed TypeScript/Python relational
callers, all ten existing language SDKs and their cross-language ring pass within
their documented profiles. The ordinary suite includes all 190 file CLI cases.
Cold maintenance completes 26 exact revisions, drains three arriving updates to
zero backlog and preserves prior complete results through schema/DROP failures.
Both native exchange layouts preserve exact retries, checkpoint validation,
fenced handoff, source-expiry refusal and original publication bounds.

Qualification exposes two fixture corrections: an idle retained snapshot must
be renewed during long mutations, and transient catalog observations can retry
within their original call/operation deadlines. Renewals preserve the same
snapshot, resource and hard deadline; explicit expiry/revocation schedules receive
no renewal. Read retries do not reconstruct or repeat uncertain submissions.
The corrected cold proof records four renewals. Two earlier Board provisioning
timeouts remain failed attempts; the final clean experience lane is separate.
No timeout, lease, storage quota or publication ceiling is raised.

An installed .NET requester also crashed at an unmapped instruction address.
No original core stack is available. Inspection found per-owner library unloading,
the same unsafe lifetime documented in the [Rust investigation](sdk.md#rust-native-lifetime-investigation--2026-09-30).
A new real-I/O mapping assertion fails deterministically against the old loader.
Correction **`48f6adff`** retains bounded shared code images through detached worker
exit while still closing native handles/buffers. Repeated opens, extraction cleanup,
changed/missing overrides and the sixteen-image bound pass. The complete corrected
.NET task runs at **`83bc1e2e`**, including the catalog-read fixture correction;
the installed cross-language ring also passes with the corrected loader.
Reproduce with `nix develop .#bindings --command just bindings::dotnet-sdk-test`.
Failed and interrupted earlier attempts remain in the record.

The [measurement account](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-10-13-pipelines/README.md)
retains 960 wider pipeline, 120 kernel/pipeline, 324 real file and 180 file-worker
samples, plus 20 paired native-control processes. All independent results,
24 wider/default checks and 115 original int64/file checks pass. Failed SUM
trials and a mismatched compiler-target comparison remain recorded. Hardware
counters are denied on this host; no unavailable metric is counted as evidence.
The measured source remains `5b3d1ba6`; later SDK/fixture and evidence changes do
not silently replace it.

The baseline-target Fuze package passes on the host and under emulated Nehalem:
312 passed, one AVX2-hardware test skipped, zero failed. Independent checkpoint
bytes and restored execution run under both. A separate forced-dispatch probe
executes AVX2 natively and checks `UnsupportedVectorCpu` under Nehalem, with no
result stdout or illegal instruction. The emulated skip is not an AVX2 pass.
Native recovery and emulated CPU checks are separate experiments. These local
Linux x86_64 results do not establish another hardware profile, a latency SLO,
a universal SIMD/parallel speedup or new join/maintenance algorithms. Hosted
execution status is reported separately in the PR.

## Integrated relational qualification

[Issue #70](https://github.com/spoke-sh/transit/issues/70)'s selected implementation is
qualified at **`85861c88`**, integrated on the Table foundation `07918d7a`.
The complete record (archived)
contains all **79 ordinary tasks**, with five complete clean lanes at that same
committed revision: core 22, growth 30, experience 7, launchers 2 and bindings 18.
Each lane runs `just ci-clean --lane <lane>` from an isolated disk-backed clone,
with locked dependencies and no inherited workspace build outputs. Full
`just check` also passes at that revision. Later evidence/documentation commits
are identified separately; they do not silently become the tested source.

| Selected package                       | Executed evidence                                                                                                                                                                                                       |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Neutral semantics and finite execution | [315-case independent oracle, captured jobs and recovery](#captured-relational-owner-and-results), [resident spill growth](#relational-resident-growth)                                                                 |
| SQL and public callers                 | [Neutral ABI/port](#neutral-relational-caller-pages), [installed TypeScript/Python](sdk.md#installed-interactive-relational-sdks), [explicit Board sessions](interfaces.md#explicit-relational-board-sessions), console and grammar checks |
| Complete changes and maintenance       | [Snapshot/tail](catalog.md#complete-table-history-and-snapshot-tail), [ongoing input and failed successors](runtime.md#ongoing-maintenance-and-failed-successors), [mutation costs](performance.md#complete-history-mutation-cost)                        |
| Bounded exchanges                      | [Native fault schedules](#relational-exchange-faults-and-checkpoint-growth), [real disk exhaustion](#relational-physical-capacity), independent routing and rebatching fixtures                                         |
| Worker reassignment                    | [Recorded single-authority handoff](#recorded-manual-worker-handoff), paged checkpoints, stale credentials, source expiry and fenced restore refusal                                                                    |
| Named activation                       | [Immutable definitions, authorization and explicit activation](#named-relational-definitions), complete revisions/deltas and native overflow recovery                                                                   |

The record retains both earlier clean attempts. One fails on the legacy growing
Table test's assumption that every non-point read is the creation-prefix page;
the corrected assertion validates the exact bounded Table-history head prefix,
returned head key, revision and STH1 value. Board's 41-row provisioning reaches
its original 60-second deadline during three concurrent attempts, including two
with four physical cores and disjoint CPU sets. The focused rerun with eight
physical cores passes without changing that deadline;
the final clean experience lane is recorded separately. Interrupted lanes are
not passed checks. No timeout, snapshot lease, resident-page or native mutation
bound increases substitute for qualification.

These are local functional checks on a shared host with ext4-backed runtime
scratch. They do not establish a latency SLO, sustainable input rate, global
snapshot, automatic placement or distributed write authority. Physical capacity
and the focused relational browser proof are separate from the 79 ordinary
checks. GitHub-hosted execution and any external billing failure are reported
separately from these executed results.

## Relational physical capacity

`nix develop --command just test::relational-capacity` passes against the direct
Table owner and native local storage on a private **2 GiB ext4 image**. A grouped
LEFT JOIN retains a partial captured checkpoint; a separate exchange retains
accepted producer/receiver state. Filling the filesystem to block exhaustion
causes real `ENOSPC`, and both attempts return `AuthorityUnavailable` without
changing the canonical digest of any retained computation entry. Health remains
observable. Only a **512 MiB recovery reserve** is released before restarting the
same authority; the filler remains allocated through complete result validation.

The captured result verifies grouped COUNT/SUM and NULL for an unmatched row.
Its replacement records fresh ownership. The exchange executor is killed after
its atomic checkpoint, then restores the same bundle, source vector and borrowed
proofs. Recorded worker handoff, one/seven-partition successors and original
lease cleanup complete without replacing that checkpoint. Storage refusals take
0.141/0.238 seconds; health reads take 0.001 seconds each. Restart through complete
result and cleanup takes 113.849/501.622 seconds for capture/exchange. These are
shared-host observations, not latency guarantees or power-loss qualification.

Two earlier attempts failed in the fixture's disk-filling setup before exercising
Transit under pressure. The corrected driver reserves extent-metadata space for
the initial allocation, consumes the tail in bounded steps and uses read/write
file descriptors. Private executable copies use the pinned interpreter inside
the owned container. This schedule does not qualify a remote storage provider.

The historical **2026-10-12** schedule used the previous Table owner, native disk
Ursula and owned MinIO on a **2 GiB ext4 image**. Real 32 MiB allocations failed with
`ENOSPC` after leaving 4 MiB available. Both an active captured checkpoint and
accepted exchange work refused advancement without changing their recorded heads.
Releasing only a **512 MiB preallocated reserve**, retaining the filler, and
restarting the same node/store permitted exact recovery and bounded advancement.
Both complete results agreed with the independent oracle afterward.

That schedule took **487.562 seconds**, including both partition layouts,
handoff faults and source lifetime expiry. Captured/exchange refusal takes
24/49 ms; health reads take 14/8 ms; reserve-release/restart/first-advance takes
0.634/1.175 seconds. Those are finite shared-host observations during other
qualification, not latency or sustained-throughput claims. The [record and
retained failed fixture attempt](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-capacity-2026-10-12.json)
include binary and raw-log hashes. The physical task remains an explicit Linux/
Docker reference task, separate from ordinary clean tasks. The historical result
does not qualify the current direct owner or expand its provider support.

## Relational exchange faults and checkpoint growth

The expanded `just test::relational-exchanges` schedule passes in **305.707
seconds** on one native authority, disk Ursula and owned cold storage. One- and
seven-partition layouts retain exact oracle results through the recorded worker
handoff and accepted-command receipt losses. Both checkpoints contain **270
entries**, including 257 explicit application records scanned through bounded
pages. The schedule observes **669 turn responses**, at most four mutations and
256-byte values.

A persistent authority outage, missing/corrupt checkpoint and denied source keep
restoration fenced. Truncated reads and corrupted published exchange segments do
not acknowledge corrupted data; receiver source denial preserves its head.
Terminating the foreign source owner expires its native resource and blocks a
separate fenced restoration; own-resource query retirement still succeeds. This
is lifetime expiry, not a TTL or physical deletion claim. The [exact record,
logs and failed attempts](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-exchange-faults-2026-10-12.json)
retain the narrower earlier schedules separately. Physical ENOSPC, provider-bound
workers and distributed write authority are separate qualifications.

## Relational resident growth

The query package's generated-source/disk-spill component test completes **14,060
input rows**, **7,030 groups** and **7,030 output rows** with an explicit combined
operator/spill resident bound of **94,905 bytes**. Its **759,240-byte** private
spill and **182,829 charged result bytes** both exceed that bound; even the
input's int64 value bytes exceed it. All canonical group keys and counts agree
with an independent arithmetic expectation without collecting input or output
rows in memory. Execution uses **21,092 logical steps**.

The complete query package unit task passes, including this case. Exact source,
raw log hashes and the initial wrong measurement-field compile attempt are in
the [growth record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-resident-growth-2026-10-12.json).
This proves component resident accounting and disk-spill growth. Generated input
is not native Table ingestion; the bound excludes transport/process runtime, so
it is not a measured RSS or provider-amplification claim.

## Named relational definitions

[Exact implementation revision, binary/log hashes and retained attempts](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/named-relational-2026-10-12.json)
record the naming slice separately from broader query qualification.

`just test::named-relational` runs the application-owned naming layer above the
real captured/maintained owners on a native node and disk Ursula. The independent
`tests/named_relational_records.py` fixture pins every control/record layout,
full-width object/revision/namespace, exact name keys and definition digest. It
also runs in the ordinary unit task. The native task belongs to the growth lane;
the ordinary suite now has **79 tasks**.

The application package units pass missing/truncated/foreign record rejection,
canonical identifier bounds, administrator denial, allocation/quota rollback,
explicit policy admission and both activation lifetimes. A 67-revision history
retains exact earlier definitions and original query attribution using three
mutations per publication, with no total-history resident list. Retrying an
earlier revision or permission after later publication recovers its original
record without changing the current name or reinstalling an older grant.

The completed native schedule passes in **146.815 seconds**, observing **408
turn responses**, at most four mutations and 256-byte values. It checks
publication without activation, lost definition/authorization/admission receipts,
node/disk-store restart and fresh workers, captured output, current source denial,
immutable attribution after a name replacement, same-resource maintained history
and exact complete delta retries. Three initial revisions reach the changed
right-join result. After deletion and explicit no-op successors, inserting
`[MAX_I64, 1, -1]` fails revision **9**, preserving complete revision **8** and its
manifest. The retained witness identifies output 2, right operation 7, ordinal 1.
A lost failure receipt also recovers exactly after worker/node/store replacement.

Application units, independent fixtures, verification ownership and diagnostic
mappings pass. Full `just check` passes the source, contracts, frontends and
documentation build; the additional old-policy retry assertion passes its focused
unit rerun afterward. The first native compile used an enum tag instead of the
control union value; the second run's assertion expected plain integers instead
of the actual typed envelopes. Both failures and successful reruns remain in
`.cache/relational-intake/named-*`. SQL declaration and foreign naming transports
remain outside this typed/Station message profile. No external effect is
dispatched by the definition, result or delta operations.

## Neutral relational caller pages

[Exact revision, budgets, logs and retained attempts](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-callers-2026-10-12.json)
record the caller boundary separately from durable owners and SDK consumers.

`just test::relational-callers` runs the real Station query port and C ABI over
signed catalog routes, a native node with eight resident pages and disk-backed
Ursula. One-resource aliases and two-resource joins produce three exact grouped
rows each. The neutral EXPLAIN/open and typed executor agree on their prepared
plan hashes. Active open, current-page and last-close retries preserve identities;
changed references, skipped/old ordinals and references from a replaced host
reject. Current right-source denial blocks re-reading a cached left-join prefix.
Output quota failure preserves the original cause and incomplete status. Ordered
`[MAX_I64, 1, -1]` SUM fails with the second contributor's identity and original
output expression, under current source disclosure checks.

The initial completed schedule passes in **7.432 seconds**, 63 port calls and a
maximum 1,603-byte response (`neutral-native-cut-fixed.log`). The expanded
plan-agreement and ordered-overflow schedule passes in **10.258 seconds**, 68
calls and the same maximum response (`neutral-native-final.log`). These are
small local fixtures, not throughput or large-output/RSS qualification. Both
use 16 MiB executor-resident and spill budgets, an 8 MiB result budget, 1,000 rows,
100,000 operator/request/spill-work limits and two source pins. The ordinary task
inventory now includes this focused caller proof.

The focused query package and Station ABI suites pass; the TypeScript binding
check passes 57 tests. `just test::query` also passes the existing disk query
staging/sealing/recovery/publication/delivery schedule with 41 rows and 22,880
bytes. Full-width neutral codec tests preserve signed minimum, unsigned maximum,
20-byte stable row identity and null. Generated schemas and resources for all
binding languages agree with the same Zig types; this is not installed idiomatic
SDK relational qualification.

Failed attempts remain in `.cache/relational-intake/`. The first native fixture
incorrectly compares complete alias cuts, including their intentionally distinct
Table schemas; it is corrected to compare resource/revision/commitment. A later
fixture expects the generic ambiguity name instead of the owner's specific
`AmbiguousRelationalColumn`; the actual located diagnostic is preserved. Earlier
compile logs retain a shadowed name, nullable location-pointer mismatch and two
Zig error/statement corrections. Initial full checks stop at the new unconfigured
interface's missing semantic mapping and then its missing independently reviewed
outcome cases. The mappings and all **3,239** executed outcome projections now
pass. Installed SDK wrappers, Board, foreign durable lifetimes and committed-HEAD
clean qualification remain separate gates.

`check-neutral-callers-outcomes.log` passes the full repository check, including
root units/examples, contracts, diagnostic projections, CLI, frontends and the
production documentation build. Final review then tightens malformed cursor
classification, validates the typed session's configured route count and preserves
the original protocol rejection when a diagnostic performs a current-rights
check. The focused Station ABI suite passes those changes
(`neutral-abi-reviewed.log`); the final native schedule passes in **10.573 seconds**,
**72** port calls and a 1,603-byte maximum response
(`neutral-native-reviewed.log`). It also asserts the overflow contributor's exact
ordinal. These are working-tree executions; final committed-HEAD clean validation
remains required before pushing.

## Maintained relational revisions

The typed owner records complete Table-history bases, recomputes each through the
finite executor, merges complete results into paired deltas, and publishes one
manifest/root atomically. Idle work requires an explicit host wake. This is not
a throughput claim or automatic SQL activation. The source/resource, operator,
workspace and cumulative-state limits are in the
[relational contract](../../../contracts/RELATIONAL_V1.md#maintained-table-owner-operations).

Executed local checks use the pinned development environment. The Fuze package's
`zig build test` passes delta identity/basis checks, duplicate projected values,
first/last outer-match identity ordering, null-first group order, paired updates,
truncated/foreign encodings and shifted output ordinals. The query package's
`zig build test` passes history-vector capture/roundtrip, consecutive transaction
selection, same-resource two-Table atomicity, frozen backfill, gaps and current
denial. Independent `python3 tests/relational_records.py` checks exact control,
work, continuation, delta-descriptor and key bytes rather than deriving them from
the Zig codecs.

The reference-store maintained-owner test rebuilds its workspace every turn and
repeats uncommitted proposals to compare complete decisions. It preserves the old
visible manifest through private staging, includes each no-op source transaction,
checks paired aggregate deltas, rejects stale continuations, and stops at ordered
SUM overflow while preserving the last complete result. This fixture is an
in-memory transition check, not a native authority or durability proof. Initial
attempts fail on a shadowed Zig name and an explicitly undersized fixture resident
budget; the fixture now budgets the exported owner base plus its workspace.
Passing logs are `.cache/relational-intake/fuze-maintained-delta.log` and
`.cache/relational-intake/query-maintained-owner-budget.log`. The full enclosing
native Table/captured regression also passes in 229.689 seconds, 720 turns and
225 sends; that earlier invocation does not execute the new maintenance schedule.

The real maintained schedule is `just test::relational-maintenance` through
`tests/relational_maintenance_native.py`. It checks every recorded basis against
the independent finite Python interpreter and applies each complete delta to a
separate consumer relation. Its delayed-backfill, lost-receipt, disk-restart,
both-side-change, outer-match, cursor and current-denial gates pass in the
disk-backed run below. Raw native attempts are retained under
`.cache/relational-intake/native-maintained-*.log`.
The first native attempt fails during fixture provisioning because it tries to
recreate the captured proof's existing source association (`StaleAssociation`).
The fixture now reads and reuses that exact association, rejecting a different
resource/required flag. Initial full-check attempts stop at the newly added
caller-outcome projections and then the reviewed delta-validation inventory;
neither is counted as a complete passing check. The reviewed outcome task passes
3203 projections across 29 declared surfaces. The hot-only native rerun reaches revision 5, then fails when Ursula's
64 MiB total hot-storage limit returns `ColdBackpressure`, surfaced as
`AuthorityUnavailable`. This is retained as a failed run, not recovered completion.
The dedicated ordinary growth-lane task now selects the existing disk-backed
cold-store fixture (`--maintained --cold`), retaining its 8 MiB hot/cache limits;
it does not raise the hot-only bound or expire history. The general Table and SDK
schedules remain separate from this longer growing-history proof.

The [cold-store record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-maintained-2026-10-12.json)
passes with the implementation committed as `79a8246d`:
15 complete revisions (five changing successors, nine no-op successors and the
initial result), 929 maintenance turns, 524.093 seconds and 104,216 retained
logical query-state bytes. Every basis agrees with the independent interpreter;
retrying each delta produces identical identities, pairs and manifest evidence.
Delayed backfill, a lost accepted receipt, node/disk-store restart, fresh owner,
current denial after a visible prefix, exact old-position resume and own-resource
retirement all pass. The enclosing Table/captured/logical-type fixture takes
776.149 seconds and 1,649 turns, retaining the four-mutation/256-byte limits.

At fixture completion the cold store contains 531 objects and 139,446,494 bytes.
This includes the entire Table/captured/maintenance fixture and native storage
history; it is not solely query-state amplification. These are observed costs,
not sustainable throughput, latency guarantees or an ongoing-input catch-up
measurement. At that earlier slice, clean integration and the additional failure/
ongoing-input schedules were still open. The [integrated qualification](#integrated-relational-qualification)
and [expanded maintenance schedule](runtime.md#ongoing-maintenance-and-failed-successors)
record their subsequent results without broadening this earlier experiment.
Reference-store failure checks above are not native failure qualification.

## Relational exchange transitions

The typed exchange records explicit logical partitions and immutable source
segments, distinguishes acceptance from consumption, enforces credits and
cumulative retention, and requires empty-partition terminal coverage. The
[contract](../../../contracts/RELATIONAL_EXCHANGE_V1.md) names the one-authority/manual
placement profile and excludes automatic placement or distributed write authority.

Pinned Fuze `zig build test` passes all 315 independent finite cases after
repartitioning/rebatching through `FXS1`, for one partition/one-row batches and
seven partitions/four-row batches. Partition arrivals are reversed and every
operator step is checkpointed/restarted. Original bag identities, NULL behavior,
group order and first checked-overflow witness agree with the independent Python
interpreter. Thirty routing cases and exact wire/control bytes come from
`python3 -B tests/relational_exchange.py`; no production codec generates expected
bytes. The earlier memory and immutable-index runs remain enabled.

Pinned query `zig build test` passes the reference-store exchange schedule at
1/7/31 partitions and 1/2/4 rows per segment. It restarts private staging,
repeats uncommitted decisions, retries accepted notices before/after consumption,
retires producer bytes after acceptance, denies producer rereads and still reads
the receiver copy. Every required empty partition completes explicitly; the
native paged index restores source order and the actual finite executor agrees
with separately enumerated join pairs. Reordered notices and credit pressure
remain unaccepted; cumulative quota failure preserves accepted records and
own-resource closure. Producer quota is reserved before staging, conflicting
pending bytes reject, and exhaustion retains every offered segment. Receiver
reservations cannot be spent by later channel registration. Current source denial
prevents disclosure after a prefix.
These use a reference KV store and synthetic authority, not a native durability
or fencing proof.

The producer-cursor continuation passes reference-store schedules with one or
three logical workers, seven partitions and one- or four-row batches. Each
attempt reads at most eight source rows; interrupted proposals reconstruct the
same pending segment, and every row/empty partition appears exactly once across
the assigned workers. Eligible notices retry after publisher retirement without
redirecting their destination. Source denial blocks retry while own-resource
acknowledgement remains possible. These are worker-layout transition tests,
not native physical movement proofs. Frozen Table-history vectors admit captured
inputs separately from maintained successors; a captured vector cannot be
reinterpreted or advanced as maintained work. Native retained pins still require
the capturing PID. Passing logs are `query-exchange-producer-fixed.log` and
`query-exchange-history-basis.log` under the same intake directory. The final
`query-exchange-producer-final.log` also passes the independent 162-byte cursor
fixture and the combined producer/history continuation. An initial producer
fixture used the wrong output-field name and failed compilation; it is not
counted as an executed pass.

Maintained attachment passes the pinned query suite at one and seven partitions
(`query-exchange-maintained-attachment.log`, then the complete
`query-exchange-maintained-wire.log`). It selects exchange execution before
activation, waits without operator mutations for complete coverage, computes the
original frozen result after a live Table update, and waits for a new attachment
at the next successor. Reusing the previous exchange for that successor rejects.
Every operator checkpoint still reconstructs on each turn and repeated proposals
produce identical decisions. `tests/relational_records.py` independently supplies
the exact `RMX1`/`RMI1` bytes, including truncated/foreign-definition rejection.
This reference-store result does not establish the native exchange host gates.

Initial attempts expose fixture name/API errors, a row key exceeding the native
32-byte limit, and a quota fixture that had not actually filled its admitted
capacity. The implementation uses 32-byte row keys; the quota schedule now fills
the remaining space before requiring rejection. Passing logs include
`.cache/relational-intake/fuze-exchange-oracle.log`,
`query-exchange-execution.log` and `query-exchange-wire-fixed.log` in that same
directory. The full `just check` run in `check-exchange.log` passes before the
final producer/reservation quota additions; the later query package run in
`query-exchange-quota.log` passes those additions. Diagnostic outcomes pass
3,233 projections across 29 surfaces. An earlier new exchange-conflict fixture
incorrectly inherited native rejection evidence; the reviewed projection
preserves uncertain-send semantics.

`just test::relational-exchanges` passes the native disk/cold-store host schedule
in `exchange-native-view-lifecycle.log`.
[Exact source, binaries, measurements and failed attempts](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-exchanges-2026-10-12.json)
are retained separately. One partition/one producer/one-row
batches completes in **71.453 s / 192 turn responses**, retaining **11,436**
logical receiver bytes. Seven partitions/three producers/four-row batches
completes in **111.750 s / 242 turn responses**, retaining **17,252** bytes. Both
publish the independent grouped left-join answer through the actual maintained
owner, with **10,422** logical operator/result bytes each. Four rows per source
include duplicate hot keys, NULL and unmatched keys. All 2/14 channels consume
explicit terminal coverage; receiver credit is one segment and selected producer
read fan-in is one resource. Every host invocation reconstructs its state.

Both layouts lose a receipt after producer staging and at receiver acceptance
before consumption. They restart the node and disk Ursula, replay the exact
saved proposal, replace producer/receiver native generations and reject stale
sessions. Reversed worker scheduling retries outstanding notices until accepted;
acknowledgements clear only their matching pending notice. This exercises crash
replacement with existing credentials, not the recorded credential-changing
handoff protocol. The enclosing fixture takes **188.327 s**, observes at most
four mutations/256-byte values, and retains **198 cold objects / 52,007,898
bytes** across setup and both layouts. Logical charges do not measure physical
provider amplification. Turn-response counts include accepted exact retries.

The first native attempt fails `PendingOperation`: the fixture tried to change
resource selection during a prepared delivery. The corrected host changes views
only between turns. A preceding compile command used a nonexistent task name;
the actual native probe compilation and run are separate passing evidence.
The recorded handoff schedule below extends this evidence. Native exchange
payload corruption/ENOSPC/current-denial schedules, ongoing-input measurements
and committed-HEAD clean verification remain open.

### Recorded manual worker handoff

Pinned client `zig build test` passes phase recovery, stale execution progress,
changed credentials, malformed/truncated records, missing checkpoints and
complete ordered state scans. `python3 -B tests/worker_handoff.py` independently
encodes the canonical manager record and SHA-256 digest of **10,003 entries**;
the client scans them in **1,251 eight-entry pages** with constant resident
buffers. `worker-handoff-independent.log` records that passing package run.
The native record is a trusted manager's private fsynced file; native history
remains execution authority. No distributed manager or provider binding is used.

`just test::relational-exchanges` passes the extended schedule in
`exchange-native-handoff-final.log`.
[Source, binaries, raw measurements and earlier runs](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/worker-handoff-2026-10-12.json)
record **197.044 s** overall, **74.608 s / 195 turn
responses** for one producer and **117.366 s / 250 turn responses** for three.
Each layout transfers one producer after an acknowledged segment and an eligible
unacknowledged segment. Its **12-entry** checkpoint includes publication bytes,
scan progress, eligibility, acknowledgement and original pending notice. The
replacement keeps the old segment's physical epoch and both maintained results
still agree with the independent oracle.

The manager process is reconstructed at each phase; the node and disk store are
restarted at every recorded boundary. Lost receipts after native suspension,
conditional resume and key rotation retain and replay the original root-signed
request before recording the successor phase. Missing/corrupt checkpoints and a
revoked source grant block restoration without activation. A known pending
worker request blocks handoff admission until reconciled. After activation the
old key fails authenticated identity reads, and the new key resumes the original
cursor with existing resource grants. Physical test workers are finite process
invocations whose exits are observed by the fixture.

The run retains **204 cold objects / 53,583,110 bytes** across setup and both
layouts; logical receiver/operator charges match the earlier exchange run.
It observes at most four mutations and 256-byte values. Earlier passing handoff
runs (`exchange-native-handoff-first.log` and
`exchange-native-handoff-receipts.log`) cover narrower checkpoint/receipt gates
and are not substituted for the final schedule. Source-expiry injection,
unavailable revocation authority, physical checkpoint cardinality growth and
power-loss behavior remain separate gates. The full clean suite still needs a
committed source revision.

`just check` passes in `check-worker-handoff-docs-fixed.log`, including generated
contracts, the independent fixtures, Zig units, CLI/semantic diagnostics,
frontend checks and documentation build. Its predecessor
`check-worker-handoff.log` fails the documentation ownership rule because an
Internals explanation embedded a repository task command. Reproduction commands
now live in this proof ledger; the public explanation links here. The failure is
retained and is not counted as a passed full check.

## Relational contract and oracle intake

The finite continuation implements `RelationalExecution` and `RelationalSql`.
The executor agrees with the 15 independent named cases, including first failing
contributor/output across groups. It rejects source/store failures and exhausted
resident/work/result budgets without completion. The focused task passes 54 Zig
tests including dependencies; the standalone Fuze and query Debug suites pass.
The query suite includes 901 disk groups inserted in ascending, descending and
interleaved order, replacement and ordered enumeration, plus quota, cancellation,
short-record and digest failures. A 600-row/300-group execution uses that actual
disk map. These storage tests use temporary OS files, not durable job recovery.

The first native attempt fails because its fixture declared SQL INTEGER (int32)
for an int64-only operator. Correcting the fixture to BIGINT preserves the
operator restriction. The subsequent `just test::typed-tables` passes in 129.492 s,
including six duplicate inner-join pairs, three grouped left-join rows, empty
grouped/ungrouped results, same-resource cut equality, self-join multiplicity,
frozen results across UPDATE and current policy denial. Existing exact caller and
owner lost-receipt recovery and the 28-descriptor Table matrix also pass. No SDK
language was selected in this run.

The subsequent cross-resource attempt exposes a proof setup error: granting the
same caller again advances its incarnation and invalidates the first resource's
grant. The fixture now reuses the established caller when provisioning the second
resource. The retry passes in 146.271 s: independently frozen resource cuts,
reused numeric catalog/object IDs without aliasing, retained rows across UPDATE,
and denial when only the second catalog revokes reads. It also executes opt-in
console JSON results, complete coverage, EXPLAIN and precise ambiguous-column
diagnostics. Immediate private spill unlinking is included. The full native run
records 481 turns, 201 sends, at most four mutations and 256-byte values per turn.
The reported representative relational query uses 50 source requests, 474 spill
bytes and 3153 bytes of accounted heap; these are observations, not latency or
memory-wide guarantees. An earlier console run was interrupted after fixture
edits during its build and supplies no passing evidence. Committed-head clean
qualification remains pending.

The complete `just check` for finite implementation `bc68b688` passes: root
unit tests, reviewed diagnostic mappings/outcomes, real CLI diagnostic cases,
console history, Board checks and the documentation build. Earlier attempts
failed on missing new diagnostic expectations and missing relational SQL
presentation routes; the mappings and executable projections now agree.
This check precedes the additional Station view work and does not qualify it.

### Captured resource vectors and publication guards

The native definition is replaced by
`e18e8959687c62017860bd73be9c8f062aaaa5fa68aa37c2542bcec9e86375d5` for explicit
`current_views` publication conditions. Public schemas, bindings, current
fixtures and independent signing hashes/signatures are regenerated together.
Historical records retain their original identifiers. Missing/foreign definition
rejection is preserved; this does not migrate or reset accepted histories.

Station's unit proof checks registered views, exact shared retention slots,
bounded caches, one writable resource, invalid/duplicate selections, sticky read
failure and frozen pending work. The core proof distinguishes ordinary frozen
observations from guarded revisions: missing/duplicate guards reject; an advanced
guarded resource leaves input progress and view closure unchanged; native current
rights still gate publication. Unguarded snapshot behavior is preserved.

`just test::growing-station` passes the additional two-resource schedule, lost
additional-view and retention replies, exact receipt recovery, foreign revision
guard rejection, native revocation, two retained roots and release after a new
activation and disk node/store restart. The existing 40/41-row Table schedule,
poisoned read, lost turn reply and six retained-page continuations also pass.
The run records 143.894 s for the existing write segment and 50.02 s for its
recovery segment, with 64 write-cache pages, one recovery-cache page and 94 cold
objects. These timings are observations of this proof, not service objectives.

An initial test incorrectly expected an ordinary read-only view to conflict when
its resource advanced. The state contract intentionally preserves that snapshot;
explicit guards now provide the required separate condition. The next attempt
reaches revocation but expects generic `Rejected` instead of the client's
specific `AccessDenied`; the corrected retry above passes. Earlier root checks
also identify stale signing expectations during cutover; independently recomputed
Python/OpenSSL fixtures correct those expectations. None of these failed runs is
counted as passing evidence. The subsequent complete `just check` passes,
including root units, diagnostic projections, generated contract drift, CLI,
Board and the documentation build. Committed-head clean qualification is pending.

`RelationalCodec` owns complete immutable schemas and the prepared identity in
its definition-bound artifact. Root tests cover independent identity agreement,
input-buffer ownership, allocation failures, every truncated prefix, foreign
definitions, schema substitutions and trailing bytes. Resource vectors, guards
and plan artifacts alone do not qualify durable relational result execution,
maintained revisions, exchanges or reassignment.

### Immutable group checkpoints and bounded publication staging

The standalone Fuze Debug suite and `just test::relational` pass after adding
immutable group roots and operator checkpoints. The focused executor now runs
59 tests including dependencies. All 15 named independent semantic fixtures run
both with the original small reference map and with immutable group records,
encoding/decoding/restoring the executor after every step, including complete
and failed states. Results, row identities and canonical overflow witnesses agree.
The Python oracle still independently checks its 300 generated cases; those
additional generated cases are not yet production-executor comparisons.

The index proof inserts 901 groups in ascending, descending and interleaved
order, enumerates canonical null-first keys, replaces values and reads retained
old roots. Every candidate-write failure in the selected insertion leaves its
accepted root readable. Missing/corrupt records, changed bindings, invalid root
counts/lengths and malformed aggregate state reject. Checkpoint tests reject
every truncated prefix, foreign definitions, changed cuts, invalid counters and
current denial before restoration.

The query Debug and ReleaseSafe suites pass the new Station Publication staging schedule.
Twenty updates repeatedly discard their candidate/operator memory between
bounded turns, reconstruct exact reserved records, reopen the accepted root and
publish the checkpoint reference last. Staging never advances that root. A
five-group old root remains readable after all twenty updates. Separate tests
exercise retained-byte/work limits, conflicting reuse of an allocated record and
current read denial. These tests use the explicit in-memory reference turn store;
they do not establish native durable query admission, source-pin/result cleanup,
worker/node loss or distributed reassignment. Earlier compile attempts caught a
changed Zig reflection API and a shadowing parameter; corrected runs pass.
The full `just check` also passes, including generated contracts, diagnostic
routes, CLI, Board and the documentation build. Committed-head clean qualification
remains pending.

### Captured relational owner and results

The exported semantic fixture now includes all 300 seed-70 generated cases as
well as the 15 named cases. `just test::relational` passes all 315 through the
production executor with both reference groups and immutable group roots,
including checkpoint restoration before every step and output-record validation.
The same independent Python corpus supplies expected bags/identities; SQLite
still checks the 312 non-overflow cases. This closes the earlier gap where only
the named cases were compared with the Zig executor. It does not expand the
small-input oracle into a runtime or storage proof.

The query Debug suite passes frozen `RQB1` request admission, same-resource alias
pin sharing, full schema identity rejection, retained reads after Table changes
and request retirement,
checkpoint reconstruction, complete manifests and output chains. Requests are
decoded with allocation-failure coverage and every truncated prefix rejects.
The actual Fuze executor produces COUNT/SUM results after its host state is
discarded between bounded turns. Work and retained-byte exhaustion close without
a manifest; ordered overflow keeps its original contributor/output witness.
Retirement releases the request/data pins once. Bounded collection reaches every
record, preserves failed checkpoints and is a no-op after completion. Complete
manifests reject vectors from a different owner. Fuze output records reject every
truncated prefix, a foreign definition, a changed binding and an out-of-budget
ordinal. These
schedules use the in-memory reference turn store, with the native four-mutation
and 256-byte value bounds; they are not disk or authority evidence.

`just test::typed-tables` passes captured multi-resource execution, source mutation
after checkpointing, exact lost-turn receipt retry across node and disk-store
restart, a fresh ownership generation, authorized complete result iteration,
current source policy denial, pin release and explicit collection after foreign
native-grant denial. The final run takes 213.161 seconds and observes 631 turns,
207 external sends, at most four mutations and 256-byte values. The captured
three-group result remains `[NULL,1,0,NULL], [7,2,2,16], [9,1,0,NULL]` after the
right Table changes from 8 to 90. Old-generation observation rejects before
resumption. The enclosing proof also passes the 28-descriptor Table matrix,
console, supplied-host lost receipts and general Table restart checks; this
command does not install the language SDKs or run the optional cold/growth modes.

Initial native runs found missing scoped-worker association setup and incorrect
fixture reactivation; neither is recorded as a passing schedule. `test-build`
also caught proof-helper type/exhaustiveness errors, corrected before native
execution. The standalone query suite passes after adding bounded collection;
the first invocation with an incorrect build root failed configuration and did
not execute tests. Full `just check`, focused relational/diagnostic checks and
the documentation build pass. Committed-head clean qualification remains pending.

### Relational editor agreement

Fuze and query Debug suites pass shared relational parser expectations and token
roles, alias-qualified int64 completion, unknown/ambiguous predicate suppression,
and allocation-failure checks. The native console exercises these suggestions
through its authorized catalog route. Its complete `typed-tables` run passes in
209.063 seconds, including the captured restart/denial schedule above, with 631
turns, 207 sends and unchanged four-mutation/256-byte bounds. The logs are
`relational-editor-fuze-final.log`, `relational-editor-query-final.log` and
`native-relational-editor.log` under `.cache/relational-intake/`. No installed SDK
or distributed query profile is covered by this run.

### Relational grammar and metadata-only EXPLAIN

`test::relational-sql` compares 33 positive ASTs across production Zig,
independent ANTLR and PostgreSQL, including aliases, unaliased clauses, mixed
aggregates and Boolean instruction order. All 22 excluded forms reject. The
ordinary grammar proof still passes its 174 SELECT comparisons, 32 exclusions
and 14 extensions; all 79 SQL documentation examples parse. Diagnostic grammar
qualification covers 337 compiler cases and 467 rule/alternative/boundary
obligations, including binding failures and the existing contextual identifiers.

The query Debug suite passes metadata-only preparation. The native Table schedule
passes in 207.549 seconds, with 631 turns and 207 sends: relational EXPLAIN has a
null execution basis and emits no snapshot/mutation command, while the complete
captured restart, fencing and denial schedule remains intact. These observations
do not qualify a foreign SDK or maintained query. A later Fuze regression checks
that columns, aliases and Tables named `join` or `group` do not select the wrong
query profile.

The first full check identifies missing diagnostic-grammar branch coverage;
the expanded cases pass. Two subsequent attempts encounter a missing stale-cache
test executable after cache cleanup; successful test prefixes are not whole-run
passes. Full `just check` passes twice using an explicit fresh local Zig cache,
including the final routing correction, native units, contract drift, CLI,
frontend and documentation build. Logs are `relational-three-parser-first.log`,
`grammar-relational-docs.log`, `native-metadata-explain.log`,
`fuze-relational-routing.log` and `check-relational-sql-routing.log` under
`.cache/relational-intake/`. Committed-head `ci-clean` remains pending.

### Initial contract checkpoint

The intake starts at merged `07918d7a` on the pinned Zig
`0.17.0-dev.2267+48abf1a34` compiler. `just test::relational` executes the new
pure Fuze plan/basis validation and independent fixtures. The Python oracle
checks 15 named finite cases, 300 seed-70 generated cases and physical input
permutations. Its 312 successful-result cases agree with Python's SQLite engine;
three ordered-overflow cases use explicit independent prefix arithmetic instead.
Thirty-six NULL/key-order combinations, checked aggregate boundaries and
independently encoded prepared/bound SHA-256 identities also agree with Zig.

The Zig cases reject ambiguous aliases/columns, unsupported referenced types,
invalid grouping/predicate scope, insufficient budgets, partial vectors, changed
schemas and inconsistent cuts for aliases of one resource. Output descriptors
preserve left null extension. These are local semantic/admission checks, not
proofs of SQL lowering, native source capture, bounded row execution, spill,
authorization, maintained revisions or distributed recovery. The specification
oracle deliberately materializes at most 32 input rows per side and 1024 pairs;
those are test bounds, not runtime cardinality limits.

The pre-change standalone Fuze ReleaseSafe run reports 252/253 package tests
passing. `compact DML preserves exact typed intent predicates defaults and
ownership` fails with `NondeterministicMemoryUsage`; running the same cached
pre-change binary reproduces it. The allocation schedule now uses the same
no-resize backing allocator as the logical-plan codec proof. Each arena growth
therefore gets a deterministic allocation/failure index without weakening
ownership, exact-byte or failure-cleanup assertions. The standalone Fuze
ReleaseSafe suite then passes. Earlier failed runs remain failures.

The locked frontend installation and full `just check` pass, including root
units, contract/diagnostic drift, 596 real CLI diagnostic cases, console history,
Board checks and the documentation site build. After adding the wide-plan
byte-budget adversary, the final focused `just test::relational` passes all
42 Zig tests and the independent Python/SQLite checks; the final root unit rerun
also passes. The new primitive types
change no native/ABI/stored definition and enable no SQL operator.

The recorded general Table 75-task coverage still spans several source revisions.
Same-revision native integration and committed-HEAD `just ci-clean` have not run
for this working-tree slice; no complete native or clean intake is claimed.

Fixtures live in [the relational corpus](../../../packages/zig/transit-fuze/src/fixtures/relational.json),
generated independently by [the oracle](../../../tests/query/execution/relational.py). The
[local contract](../../../contracts/RELATIONAL_V1.md) and
[plan tests](../../../packages/zig/transit-fuze/src/relational_test.zig) define the
implemented boundary.

## Mutation completion follow-up

The follow-up to merged `96943293` starts with a fresh ReleaseSafe physical-disk
140-case control: INSERT/UPDATE/DELETE p50 142/153/138 ms. Bounded caller waits
at `799a7a69` complete the same seven-case control with p50 131/149/129 ms.
Shared-host measurements do not establish an SLO or isolate host variance.
The real local-server proof passes forced pending observations with a paused
Table owner, exhausted wait admission, denied observation and exact saved
recovery. Ordinary read fallback completes with all wait requests refused;
denial issues no fallback or repeated mutation. Existing lost-receipt and
acknowledged-checkpoint recovery schedules also pass. Root unit checks pass.
An initial development proof used an unsupported INSERT spelling and failed
before wait admission; the corrected explicit-column schedule passes.

The mutation fixture's instrumented `completion_timeline` correlates one native
send receipt with view/turn commands at the same PID/input, then the caller's
processed-input observation. It retains separate request/response coordinates,
overlapping receipt delivery, caller completion and bounded work counters.
No row payload, signature or credential enters this trace. Missing or multiple
stages are incomplete, not zero. Parser/correlation tests cover lost stages,
ambiguous admission, unrelated inputs and observation before receipt delivery.
Use `just test::mutation-latency --repeat 3 --instrument --output /var/tmp/completion-counts.json`
inside the pinned environment. Proxies change timing; use uninstrumented controls
for ordinary latency.

Leaf-frontier batching passes root unit checks, including a depth-32 tree,
complete-command staging faults and a separate opaque-locator store. Eight
independent leaf replacements use one bounded batch plus one parent stage;
losing any staged acknowledgement preserves every value at the old root.
The physical packed-page proof (`--keys 256 --cache 2`) passes write, provider
SIGKILL/recovery, checkpoint and trim recovery, including accepted batch replies
that are lost, incomplete or partially failed. A development compile failure
from an extra semicolon was corrected before the passing unit run.
The bounded-batch unit case also passes 24 leaf replacements across three
eight-page buffers with every acknowledgement fault. The concurrent-reader
control completes 140 writes and 1,280 reads without uncertainty or restart.

The original finite offered-load harness assumed all 48 requests were admitted;
the first four-worker/1 ms run fails on explicit `HttpCapacity` refusals. The
corrected ReleaseSafe harness records those refusals separately and supplies the
accepted sender set to its independent Zig drain oracle. The repeated burst
admits four, refuses 44 and preserves all four receipts and resulting rows through
node/provider loss. Its control command is refused during the burst and succeeds
afterward; this is not a control-latency guarantee. Only accepted sends are
replayed. Other 503s and uncertain exchanges still fail qualification.
The paced 50 ms control admits all 48, refuses none, preserves revocation and
passes the same drain/restart checks. Its admitted p50/p95 is 16.4/26.6 ms;
the later drain takes 2.54 s. Both load controls overlap qualification and are
native admission experiments, not sustainable end-to-end SQL throughput.
The cold packed-page proof also passes 1,024 keys with two cache pages, owned
MinIO, all acknowledgement faults, provider replacement and checkpoint/trim.
Retained roots stay exact and recovery stages no pages.

The first full check stops at the expected diagnostic-inventory drift from the
new wait boundary and explicit invalid-response check. Existing semantic mappings
cover the added cause; the reviewed inventory is regenerated and independent
mapping checks pass. The second check reaches documentation validation before
the linked measurement artifact is committed and stops there; the artifact and
all documentation links subsequently pass. A third check rejects a repository
test command in the public performance reference; replacing it with the fixture
link restores the documentation boundary. Full pinned `just check` then passes,
including 77 Board tests and the documentation site build.

All **75 ordinary CI tasks** pass in one uninterrupted `just ci-clean --work-root
/var/tmp` run at `be0e03d1547bfa5aadc38c199068f49594e2906c`: core 22, growth 26,
experience 7, launchers 2 and bindings 18. The isolated checkout installs locked
frontend dependencies and inherits no workspace build outputs. The
[qualification record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m45-completion-2026-10-05.json)
embeds every result and completion record, exact revision, toolchain identity,
commands and log hashes. Its audit matches all ordered ordinary inventory entries
without gaps or failures. An earlier clean preflight rejects the user's untracked
DuckDB files; qualification moves to an owned clone without altering those files.
The first clone run is interrupted to include the documentation correction and
remains incomplete; the complete run above replaces no failure with a skipped pass.

The final real console recovery proof also passes. The selected exhaustive
resource campaign runs four seeds, 1,170 traces, 22,652 events and 2,342 executions,
replaying every trace identically across the observed page/journal/trim fault
boundaries. Its [raw report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-05/resource-exhaustive.json.gz)
retains the finite selection; it does not prove arbitrary-fault correctness.
The [measurement archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-05/README.md) retains
before/after controls and failed experiments. Browser and external-placement tiers
and sustained multi-writer SQL throughput are outside this qualification. Runtime
qualification remains tied to the revision above; later closeout commits change
only documentation and evidence. This completes the scoped implementation gates
for [issue #73](https://github.com/spoke-sh/transit/issues/73), pending merge.

Evidence is scoped to each recorded revision or definition. “Current” in an
earlier entry refers to that entry's source, not automatically to HEAD. The latest
[publication-domain cutover](performance.md#publication-domains-and-coordinated-caller-cutover)
records its reruns and remaining qualification separately; earlier consolidation
results do not qualify the changed stored layout by inheritance.

## Connector capture failure evidence — 2026-10-03

The `exchange-failure-witness` current-v1 cutover retains a 197-byte first-closure
record and an immutable authenticated worker input. `just test::unit` passes
independent Python/Zig encoding, full-width exchange identities, exact replay,
first-cause preservation, wrong-target refusal, mutation-budget rollback,
missing/corrupt evidence refusal and current-read failure propagation. The real
HTTP and gRPC workers compile. Full `just check` passes, including **517 CLI
cases**, **75 Board unit cases**, generated contracts, native/frontends and the
handbook build. A final focused strict-TypeScript/8-case Board boundary run
passes after correcting the display of unrecorded callback context.

`just test::http-worker` passes in **538.03 s** excluding compilation. Its new
schedule loses the admitted failure input's receipt, kills the worker and
restarts node/disk storage. Replacement retains the exact original transport
cause and admission input, separately reports native abandonment, sends no
second remote request and preserves the same failure through retirement/cleanup.
The complete schedule observes **17 sends**, **9 remote applications** and
**2 cancellation requests**, with an 8 MiB hot limit and **965 cold objects**.
Existing lost-before-failure-admission recovery explicitly records an unrecorded
cause. The first transport failure still uses its owner's `ReadFailed` wrapper;
unwrapping available transport causes remains separate work.

Logs: `/var/tmp/transit-exchange-native.log`,
`/var/tmp/transit-exchange-check.log`,
`/var/tmp/transit-exchange-board-unit.log` and
`/var/tmp/transit-exchange-board-final.log`. At commit `27d33757`, the gRPC disk schedule also passes in **358.30 s**:
all four shapes preserve recovered-incomplete versus native abandonment,
explicitly leave the lost cause unrecorded, emit only inspection guidance and
retain the same capture diagnostic after retirement. It records **9 sends**,
**8 remote applications** and **658 cold objects**. Neither Board connector browser proofs, installed
connector SDK adoption, complete semantic inventory nor committed-HEAD clean
qualification is established by this increment.

## File diagnostic boundary evidence — 2026-10-03

Pinned `just test::unit`, `just test::cli-diagnostics` and `just test::file-query`
pass. The final real CLI matrix has **517 cases**, including empty JSONL records,
CR framing, invalid/duplicate header names and original positions, separate
header-byte and field-count bounds, JSON depth/token/object-field limits,
inference bounds, malformed/incompatible schemas, unsupported CSV types,
exact option attribution, output expansion, temporary capture directory failure,
invalid DEFLATE, second-file attribution and Arrow segment capacity. Required
amounts come from the original check; prefix measurements explicitly establish
only a minimum. The existing **190 file-query cases** also pass, including
cancellation/cleanup, immutable capture, gzip, quotas and 192 MiB input under a
96 MiB address-space limit. JSON/Arrow completion rules and successful stdout
remain unchanged.

Logs: `/var/tmp/transit-file-witness-third.log` (unit and initial CLI matrix),
`/var/tmp/transit-file-witness-fourth.log` (final focused CLI/file proof).
The first focused attempt stopped at an old assertion that required amounts were
unrecorded; the replacement assertion verifies the actual stopping count.
Full `just check` passes in `/var/tmp/transit-file-witness-check.log`, including
514 CLI cases, generated contracts, native/frontend checks and the handbook build.
A subsequent focused CLI rerun adds three human quote/UTF-8 explanation checks
and passes all 517 cases (`/var/tmp/transit-file-witness-final-cli.log`).
These checks do not establish complete recursive descriptor attribution, the
semantic inventory gate or committed-HEAD clean qualification.

## Query result selection after access recovery — 2026-10-01

Hosted run `36809340716` passes the five atlas browser tests, then exposes a
workspace defect: revocation clears rows, but refreshing restored access reads
the retained completed namespace and displays those rows again under a reset
draft. The [selection record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m37-query-selection-2026-10-01.json)
retains the hosted failure and source hashes.

The workspace now retains accepted upload/signature recovery independently of
result selection. Access refresh checks access and status without selecting
cleared rows; explicit namespace resume verifies the original result and labels
its unavailable saved SQL separately from the current draft. The real disk-backed
API/browser proof passes in **167.816 seconds** on development base `e1253fc6`.
It checks zero result-page reads during access refresh, the unchanged namespace,
explicit resume with no new submission, exact retry after a lost acknowledgement,
and clearing on source retirement. The original browser deadlines are unchanged.
Three earlier attempts receive unavailable API responses before browser launch;
they do not detect the UI defect or qualify completion. Full combined-source
clean and hosted qualification remain open.

The [unavailable-reply controls](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m37-query-recovery-2026-10-01.json)
subsequently reach the original UI failure locally: one result remains where zero
is required after access refresh. The corrected UI passes the same real proof.
The API fixture now recovers unavailable preparation and frozen-submission replies
using the identical request body. A proxy replaces one successful preparation
reply and one actual accepted receipt with `Unavailable`; recovery must preserve
both original requests and return the original receipt. Disabling that recovery
fails on the injected preparation reply. Eight attempts remain bounded by the
existing ten-second preparation, sixty-second settlement and 120-second upload
windows; receipt retries now consume the settlement window instead of preceding
it. These controls retain unavailable observations as uncertainty, not rejection.

## Delivery staging and bounded query progress — 2026-10-01

Committed `d6ce30ea` passes full repository checks in 218.371 seconds and clean
core's 22 tasks in 1,123.770 seconds including setup. Clean growth passes eight
tasks, then the query delivery phase exceeds its unchanged 180-second deadline
inside `test::growing-service`; seventeen later growth tasks are unrun. Clean
launchers passes both tasks in 345.792 seconds. The
progress record (archived)
retains the exact binaries, completed task outcomes and diagnostics.

The failed delivery window contains 350 completed commands through position 545,
with negligible authority-lock wait. Sequential controls on CPUs 0, 12 and 0,
using identical binaries, fixture and the clean runner's 46 MiB stack limit, all
repeat the delivery timeout. Earlier direct invocations with an 8 MiB stack fail
before the workload and do not qualify those controls. A separate instrumented
run observes 13,447 completed Ursula `fdatasync` calls during delivery, with a
6.8 ms median. Tracing perturbs execution and syscall durations overlap; these
observations neither decompose wall time nor establish a shared-host cause.

Clean bindings passes its check and native tasks, then its Python SDK task exits
successfully after client, Station, HTTP/gRPC, mutation and catalog checks. The
CI controller is paused while that active task continues under its unchanged
deadlines, then terminated only after the task exits. Its original checkpoint
and the independently observed zero child exit status are retained separately.
The lane is deliberately incomplete so the changed implementation can be tested;
the wrapper's termination is not a failed SDK proof. This source ends with
**35 ordinary passes, one failure and 38 unrun tasks of 74**, plus seven unrun
browser tasks. Hosted run `36823397287` is refused before execution by GitHub's
account billing restriction and contains no test results.

The batching control (archived)
compares `9b19d569` with the original delivery path. It groups the disposition,
three pending-index removals and optional mailbox/process pair into one existing
bounded catalog mutation. The same small-catalog unit fixture stages **eight
pages instead of sixteen**. Both paths pass all 65 core tests. Every numbered
staging refusal and lost staging acknowledgement leaves the published admission,
mailbox and pending indexes unchanged; recovery and exact retry preserve one
admission with original source/turn/output provenance. Expanded simulation passes
**70 traces / 10,535 events with identical replay** in 238.024 seconds. Both
compiling route-order and delivery-origin mutants are detected, and full
repository checks pass on the matching development source.

The sequential original/batched/original disk comparison uses the same caller,
fixture, CPU, stack limit and phase deadlines. **All three delivery phases time
out**, after 321, 410 and 382 completed commands respectively; the common prefix
has identical command coordinates. Total fixture times are 247.660, 256.580 and
246.524 seconds. The batched sample makes more progress, but does not clear the
deadline. These shared-host, incomplete workload observations do not qualify an
end-to-end speedup or resolve the historical timing change. Committed-source
clean qualification remains separate.

The subsequent clean checkpoint (archived)
passes all **22 core tasks at committed `42d45983` in 1,082.326 seconds** including
setup. Its disk storage task passes in 430.21 seconds with kill, checkpoint and
trim recovery. The driver stops between lanes; growth, experience, launchers,
bindings and browser remain unrun at this source. This core pass does not resolve
the focused query timeout. Hosted run `36832812554` is refused before any test
starts with the same GitHub account billing annotation. The source-specific
record retains both outcomes; neither is a complete ordinary or cost pass.

The receipt-batching follow-up (archived)
at `8e49e0bc` prepares delivery's records together with the caller sequence and
receipt in the existing eight-key mutation limit. Other commands still read
their resulting caller record after applying their own changes. The same unit
fixture now stages **six pages**, with twelve staging/acknowledgement fault
cases; all 65 tests pass. Expanded replay passes **70 traces / 10,535 events** in
227.346 seconds, full repository checks pass on matching development source,
and both compiling delivery mutants are detected at the committed revision.

A six-key/eight-key/six-key disk comparison again times out in all three delivery
phases, after **415/430/394 commands**, with matching coordinates over their common
394-command prefix. Total fixture times are 237.729/244.619/259.620 seconds.
The additional staging reduction does not resolve the deadline, and these
incomplete shared-host samples do not establish a complete-workload speedup.
All phase limits, provider durability and workload assertions are unchanged.

## Query boundary and fixture controls — 2026-10-01

The continuation record (archived)
retains `c61896d2`'s 55 ordinary passes, two failures and 17 unrun tasks of 74,
plus one browser pass, one failure and five unrun tasks. Core, experience and
launchers complete at that source; an independent growth suffix does not
retroactively complete its original failed lane. The original delivery attempt
exceeds the 180-second limit after 416 commands. The complete suffix separately passes the
HTTP/RPC recovery and closure proofs. Hosted run `36836820226` is refused before
test execution by the account billing restriction. These results do not qualify
the full suite or its cost budget.

The boundary controls (archived)
preserve the failed browser resume after restored access. The native client
classifies a validated `HttpCapacity` rejection as `AuthorityUnavailable`; Board
previously flattened that into generic `Unavailable`. Board now retries only
that paired classification for read/preparation operations, at most three times
with 500 ms, 1 s and 2 s delays under the original request deadline. Signed
submission is unchanged. The original binary fails the intended negative
control in 52.597 seconds; the corrected full API/browser proof passes in
140.693 seconds. Controls require exact native attempt counts for recovery,
exhaustion, denial and unrelated failure, plus identical signed recovery and
explicit resume without resubmission.

The Table proof originally assumes a small preparation must remain staged,
although the supported inline profile can already apply it. Its snapshot
interleave now explicitly admits the existing staged begin before resuming the
same compiled reference. A subsequent run passes the snapshot check, then
exposes the same invalid assumption in interrupted cancellation. The corrected
proof distinguishes an admitted inline write reporting `applied` from a staged
begin reporting `cancelled`, verifies the frozen command tags and row outcomes,
and retains the rejection-gated upload-part case. The full proof passes in
100.597 seconds with original `c61896d2` binaries and the `28f98560` fixture,
including two initialization receipt recoveries and a 0.658-second snapshot
pause. Neither original failure is discarded; these source-specific timings
are not a performance comparison.

Full checks at `28f98560` pass in 226.534 seconds. Its clean experience attempt
passes five tasks, then fails when the test proxy records a closed downstream
reply socket as an upstream error; Station is unrun. The binding check and raw
native proof pass before orchestration deliberately stops at a task boundary.
The child's observed zero exit is recorded separately from the incomplete CI
checkpoint. Neither lane is complete. The deterministic disconnect control
reproduces `ConnectionResetError` in the original proxy and passes with the
`7e263488` fixture, which counts closed downstream replies while retaining
upstream errors and all exact retry/page assertions.

Full checks at `7e263488` pass in 215.963 seconds. Its first clean experience
attempt passes four tasks, then Board inspection exhausts its ten-second retry
window after native page staging reports `ReadFailed` under the existing
800 ms request deadline. Query and Station tasks are unrun. The attempt overlaps
preparing stopped-build cleanup on the shared host; its storage errors
do not establish a cause. The failure output retains only child-log tails;
these later attempts additionally retain up to 32 numbered child logs per
fixture, with
at most 8 MiB per file and explicit offsets when truncated. The five
implementation and fixture commits are pushed. Hosted run `36850587443` is again
refused before any test starts. Eleven binding tasks pass at this source:
contracts, the native proof (332.19 seconds), complete Python SDK (1,102.76 seconds), complete Node SDK
(810.80 seconds), logical-value/Arrow ownership (32.37 seconds), and complete Rust
SDK (781.59 seconds), Ruby SDK (700.93 seconds), C/C++ SDK (1,559.10 seconds),
Java SDK (838.91 seconds), .NET SDK (706.71 seconds) and Erlang/Elixir SDK
(1,420.35 seconds). Each installed SDK task includes Station, HTTP/RPC, mutation and catalog
schedules. Interoperability passes the Python-to-Node pair, then fails in
402.25 seconds after MinIO returns HTTP 507 `XMinioStorageFull` and a later
request reaches `DeadlineUncertain`. The clean binding attempt ends with eleven
passes, one failure and five unrun tasks in 8,715.956 seconds including setup.
The five unreached tasks then pass in an independent continuation: finite
safety model (11.894 seconds), delivery model (6.681), SQL rewrite theorems
(7.045), SQL checks (19.994) and RPC faults (163.893), each including its shell
setup. The safety model explores 7,867 states and detects four removed guards
replayed against Zig; four named Lean theorems have no `sorry` axioms or
warnings. The original failed lane remains incomplete.

All seven browser tasks pass at this source: inspection (50.01 seconds), query
(177.53), HTTP (1,000.54), gRPC (691.46), reactive browser (139.79), reactive views
(294.81) and reactive-view lifecycle (61.37). The complete clean browser lane
takes 2,439.751 seconds including setup. HTTP and gRPC include disk recovery
and 755 and 527 persisted cold objects respectively. A fresh clean experience
retry passes all seven tasks in 475.415 seconds including setup. Station takes 239.73 seconds; its original Arrow reply arrives
in 38.854 seconds, before cleanup intervention and within the unchanged
60-second deadline. The courier replacement takes 30.267 seconds after 292
refused reads. The earlier failures and unresolved timing cause remain recorded.

A separate diagnostic with the exact original `c61896d2` binaries and existing
request metrics enabled passes in 67.624 seconds, including delivery in
50.456 seconds under the unchanged 180-second cap. All 4,464 completed responses
have metrics; no records are dropped. Delivery accounts for 3,013 responses,
34,465 provider requests and 17,736 attempted page stages. Its 42.546 seconds of
provider time are included in 46.283 seconds of observed request work, not added
to it; lock wait totals 0.000263 seconds. This later instrumented success does
not explain the earlier timing change, qualify an uninstrumented source or
establish an implementation speedup. The original timeouts remain recorded.

An uninstrumented repeat then uses the same original binaries, unchanged
fixture/support sources, CPU affinity and stack limit. It passes all assertions
in 69.689 seconds including shell setup, with delivery in 47.385 seconds.
The earlier timing variation remains unexplained, and complete clean growth
qualification remains open. Retained system-wide
[PSI](https://docs.kernel.org/accounting/psi.html) samples describe different
observation windows and cannot attribute a causal share to this fixture.
The interop retry remains unrun with only about 1.5 GiB above the provider
reserve; the exact original binaries and SDK packages remain available.

## Installed Node optional Arrow dependency — 2026-10-01

Hosted [bindings job 110181434108](https://github.com/spoke-sh/transit/actions/runs/36803044000/job/110181434108)
passes the raw client and durable-continuation checks, then exits when the
Station fixture installs its optional Arrow dependency. The original fixture
reports only installation exit 1, so that hosted log does not identify the
package-manager error.

With `CI=true GITHUB_ACTIONS=true` and pinned `pnpm@10.32.1`, changing an existing
consumer manifest to add `apache-arrow@21.2.0` reproduces
`ERR_PNPM_OUTDATED_LOCKFILE`. A separate control invokes the actual fixture from
`5c76d03e` with its built Transit tarballs: Arrow is absent initially and the
second install fails. The corrected fixture explicitly updates only this
disposable consumer lock. It preserves the absence check, then installs Arrow
and passes an independent IPC round trip for `9007199254740993n`.

The [installation record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m37-node-arrow-install-2026-10-01.json)
retains source hashes and both outcomes. Full repository checks pass on the
corrected development source. These installation controls do not by themselves
qualify the real Station, query, connector or remaining language schedules.
No repository lock, native behavior or progress deadline changes.

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

`just test::publication` runs [real Zig Station callers](../../../tests/runtime/application/publication.zig) against
an isolated `growing_v3` authority and disk-backed Ursula. The
[Python harness](../../../tests/runtime/application/publication.py) verifies an independent SHA-256 fixture,
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
regression. The [retained report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m14-publication-2026-09-26.json)
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
saved-binding metadata validation. Logs are `/tmp/transit-fuze-sources-check.log`
and `/tmp/transit-fuze-source-final-test.log`; these local paths are not portable
artifacts or independent durability evidence.

Committed source checkpoint `2b729f7a` passes `just ci-clean --lane core` without
inherited outputs. Foundation/package checks, properties, client ABI, Station,
disk storage, service, runtime upgrade, callers, inspection and state all finish
successfully. Evidence is `.cache/ci/clean/2b729f7afdcc-transit-ci-9iwhecgd` and
`/tmp/transit-fuze-source-ci-clean.log`. This is the core lane, not every integration
or installed SDK profile.

The shared file/native SQL checkpoint passes all 65 Fuze package tests and
`just test::sql`: 104 independent parser ASTs, 86 Table plans/results and 24
unified results over three source bases/eight page widths, plus declaration and
mutation oracles. File tests exercise shared finite filtering/projection/LIMIT,
COUNT/ordered SUM, late failures behind LIMIT, exact typed uint128 predicates,
and exhaustive allocation failures. Logical JSON tests preserve recursive
descriptors, full-width integers and signed floating zero through owned codecs;
missing/foreign definitions and noncanonical numeric strings reject. Logs are
`/tmp/transit-fuze-logical-json-test.log` and `/tmp/transit-fuze-sql-regression.log`.
Physical acquisition, installed SDK extensions and comparative performance
remain separate qualification gates.

## Captured local file queries

`just test::file-query` passes 83 cases against the real `transit` executable on
Linux x86_64. Six independent Python source fixtures and all 46 scalar oracle
cases cross acquisition, discovery/explicit decoding, SQL and neutral JSON;
the Python checker reconstructs canonical descriptor/value bytes independently.
Other cases verify gzip optional fields/header CRC/payload CRC/size, truncation,
trailing/concatenated members, encoded/expanded quotas, exact aggregate results,
late failures behind LIMIT, explicit type-error cells, duplicate names/keys,
UTF-8 failures and invocation validation.

SIGINT during idle/partial stdin and blocked stdout exits 130; a broken output
pipe exits 1. SIGKILL during acquisition leaves no named capture. Each case
checks its private temporary directory. Rewriting the original file after the
schema is published leaves all 10000 captured values unchanged. A 192 MiB CSV
scan returns the expected count under a **96 MiB RLIMIT_AS** process ceiling;
captures use `/var/tmp` disk storage. This is larger than the process's permitted
address space, not a claim that input exceeds host RAM or that host caches were
cold. No durable job is admitted, so these are ephemeral cleanup/immutability
proofs rather than accepted-work crash recovery.

The CLI checkpoint passes full `just check` (generated contracts, Zig/CLI units,
independent fixtures, frontend checks/tests and documentation build). Logs are
`/tmp/transit-fuze-cli-proof.log` and `/tmp/transit-fuze-cli-check.log`. Arrow, installed
SDK extensions and the DuckDB performance matrix are not qualified by this run.

## Logical Arrow export

`just test::logical-arrow` passes **100 PyArrow 23.0.0 cases** on Linux x86_64.
All 46 independent scalar fixtures and six source fixtures cross the real CLI
into IPC, with Python reconstructing exact canonical values from Arrow buffers.
Temporal validation reads integer units without Python datetime truncation;
decimal uses widened Python Decimal precision. The separate neutral-JSON bridge
checks binary, interval, civil timestamp, fixed arrays, maps, tagged unions,
structs, lists and JSON across value/null/missing/type-error/conflict. Canonical
type metadata, full-width conflict IDs, inactive variants and ownership after
the producer exits remain intact.

Independent checks include physical schema/nullability, full Arrow validation,
batch splitting at widths 1/8 under 64 KiB segments and missing end markers on
late failure. The Fuze package passes 66 tests, including logical IPC round trip,
tiny workspace/output failures and the previous allocation schedules. Logs are
`/tmp/transit-fuze-arrow-proof.log` and `/tmp/transit-fuze-logical-arrow-cli.log`. These
prove local IPC export, not installed SDK, logical IPC import/C ownership,
Flight expansion or comparative performance.

The logical Arrow checkpoint also passes full `just check` and a rerun of all
83 real file-query host cases; see `/tmp/transit-fuze-arrow-check.log`. Rich Arrow
export remains inside the original output/workspace bounds.

Structural operations pass **11 focused type tests / 68 Fuze package tests**.
The 46 independent scalar fixtures now also compare Python-computed semantic
SHA-256 hashes, including float32 widening and signed-zero normalization.
Recursive tests distinguish null/missing, check exact uint128 ordering, typed map
equality and rejection of error/conflict/unsupported traits before comparison
short-circuiting. Hashing does not change the bit-preserving neutral codecs.
The log is `/tmp/transit-fuze-operations-test.log`.

## Local logical codec and installed owners

`just test::logical-codec` passes 91 independent scalar/recursive/state fixtures
through both the C ABI and local native port on Linux x86_64. It compares exact
binary values and type fingerprints, the independent scalar structural-hash
oracle, generated recursive JSON Schema validation and PyArrow interpretation.
It rejects missing/foreign definitions, truncation, trailing bytes and noncanonical
hex, and checks explicit decimal rounding. Native input bytes are overwritten
before returned buffers are read; copied results remain valid after native
buffer release. Fuze's allocation-failure test covers every allocation in a
complete uint128 binding/result operation.

`just bindings::logical-test` installs current wheels and Node tarballs outside
the checkout and passes the same 91 fixtures through public Python/TypeScript
logical owners. Byte arrays are independently owned, results survive later calls
and codec closure, and closed codecs reject work. Native artifacts come from the
local pinned build. This qualifies local document/codecs and logical IPC export;
it does not widen the stored/native query or Flight profiles, qualify other
language logical APIs, or establish comparative performance. The 100-case
`just test::logical-arrow` schedule also passes after sharing its recursive
fixtures with these boundary checks.

## File comparison baselines and metadata execution

The [2026-09-30 evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-09-30/README.md) freezes
numeric budgets in commit `5052c59e`, before the metadata optimizations. The
optional benchmark shell pins DuckDB 1.5.2/build `8a5851971f` and PyArrow 23.0.0
from the unchanged lockfile. `just doctor` and the optional-shell version/build
checks pass. The harness uses the real CLI capture boundary and Fuze source,
query and Arrow owners; DuckDB remains a development dependency.

The accepted baseline contains 792 samples over nine shapes, five schema modes,
two input-cache conditions and two engines, including separate projection,
batch-size, filter, COUNT and SUM experiments. Every case has three raw
repetitions and verified source hashes/results. The same eight-query six-scalar
driver runs against `d5541301` and candidate with one discarded warmup and nine
measured processes per binary. Median candidate/control ratios are 0.9960–1.0480.
A 600058901-byte input completes in four modes under a fresh 256 MiB RAM/cache
cgroup with swap disabled, actual peak 268435456 bytes and no OOM events.
Exact commands, scope differences, original failures, hashes and compressed raw
JSON reports accompany the baseline. Executable VmHWM and process-lifetime
wait4 RSS are separate counters; the latter includes the pre-exec launcher.

The harness rejects wrong counts/checksums, missing phases/completion and changed
captures. Its six Python evidence tests also reject incomplete/dirty reports,
changed workloads/drivers/CPU, missing repetitions and numeric regressions; a
failed check replaces any prior successful report. The numeric checker recomputes
metrics from raw observations and requires identical declared conditions. It does
not infer parity from a successful process exit or compare incompatible allocator
counter scopes.

The descriptor-validation optimization at `19d3ba7d` passes all 25 focused
source/type tests. The bounded CSV column-map implementation at `f509cdfb` passes
27, including reordered/absent optional headers and rejection of a replacement
valid binding during an active scan. Its map is rebuilt per file; current checks,
full-row conversion, source verification and failed-prefix behavior remain.
At `00f83fc0`, full `just check`, all 83 executable file-query cases and all 100
independent PyArrow cases pass. The benchmark binaries are rebuilt from that
source; generated local Zig caches were then removed before candidate measurement.

The first complete optimized matrix passes its result, allocation, I/O-count,
memory, scan/query and specialized-path checks but fails the numeric timing gate:
12 cold-acquisition/phase wall limits and one discovery CPU limit. The retained
report distinguishes this failure from successful correctness checks. Investigation
shows large wall/CPU separation in cold acquisition with unchanged bytes and
similar acquisition CPU; the unchanged repeat below tests reproducibility. These observations
are not a passed performance gate or final committed-HEAD clean qualification.

A complete unchanged repeat also fails seven capture/discovery timing limits in
different cases. Both optional metadata changes are withdrawn at `cffa7b56`;
none of these failures is waived and no budget is raised. The
[experiment archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-09-30/README.md#withdrawn-metadata-experiments)
retains every raw run and both failed gate reports. A source comparison verifies
that all implementation/generated-contract/build/toolchain paths again match
accepted baseline `5052c59e`. The delivered feature uses that measured baseline;
it makes no qualified optimization or DuckDB-parity claim. Final clean checks
remain a separate requirement.

### File-query integration with current main

The schema-on-demand branch integrates `main` at `9fdf1d02`, including current
native definitions, SQL diagnostics and explicit `AS` source aliases. Alias
resolution lives in the shared `SqlLowering` path for file and native queries;
it preserves source identity, binds inner/outer qualifiers separately and rejects
bare aliases or references to the hidden original qualifier. SDK resources are
regenerated from the merged Zig owners.

The merged tree passes `just doctor`, full `just check` (including documentation
production build), and `just test::sql`: 113 independent SELECT ASTs, 92 real
plans and 28 unified results, plus mutation/declaration fixtures. The first
expanded file-query proof incorrectly expected bare aliases to succeed; the
shared parser rejects them. Correcting that expectation and the new guide text
leaves the implemented grammar unchanged. The complete rerun of
`just test::file-query` passes 89 real CLI cases, including explicit/nested aliases,
invalid qualifiers and all existing capture/gzip/cancellation/192 MiB memory cases.

The frozen benchmark artifacts retain their exact pre-integration revisions.
Integration does not reinstate either withdrawn metadata experiment and does not
turn those historical timings into measurements of a new revision. Committed-HEAD
clean qualification remains outstanding at this integration checkpoint.

The subsequent rebase uses `origin/main` at `ac9ad43d`, which adds native SQL
output aliases and replaces its current protocol definition. Native compilation
and generated SDK resources retain that implementation. File plans keep their
previous output-name profile and explicitly reject output aliases; source `AS`
aliases remain supported. Earlier merged-tree checks do not qualify this rebased
revision; final checks must run again.

### Post-merge Fuze qualification

Follow-up revision `a24f5cd3` passes locked frontend installation, full
`just check`, `just test::sql` (134 independent SELECT ASTs, 105 compiled plans
and 44 unified results), `just test::fuze-types` (11 tests / 46 scalar fixtures),
`just test::fuze-sources` (25 tests), `just test::file-query` (92 real cases),
`just test::logical-arrow` (100 PyArrow cases) and `just test::logical-codec`
(91 C ABI/native-port cases). The three added file-query cases reject output
aliases in this narrower profile; native SQL retains its output-name support.

Its specialized six-type control still fails the frozen 1.15 ratio budget in
seven predicate/aggregate cases. The
[post-merge evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-09-30/README.md#post-merge-specialized-path-regression)
retains the complete raw repetitions and scoped failed gate. This is a detected
regression, not final performance qualification. Final clean lanes and the
installed-owner rerun remain outstanding under issue #53.

Native plan validation at `a99a9c59` avoids rebuilding an output schema when
validated unique source names and projections already determine it. Aliased
outputs retain their combined collision check. Binding also uses the same
private canonical encoder after complete plan/basis validation, avoiding a
second shape traversal; public encoding independently validates its inputs.
Wire bytes, definitions, fingerprints, page/source checks and cancellation are
unchanged. Fuze package tests and the complete independent SQL proof pass after
both changes. The final paired six-type control passes every unchanged 1.15
budget with ratios 1.0003–1.1219. Raw measurements, exact hashes and both prior
failed trials remain in the linked evidence. Final clean lanes are still pending.

At `331abe3a`, full `just check` and the 52 native C ABI/port codec cases pass.
The clean core lane completes all 22 tasks, including signed service and disk
recovery. Clean growth completes its first eight tasks: Arrow, logical types,
sources, all 92 file-query cases, 100 logical Arrow cases, 91 logical codec cases,
immutable pages and growing authority recovery. Main then advances through
PR #57 to `8bd85869`; integrating it supersedes this source. The owned clean run
is interrupted during `test::growing-service`, with exit 130 and no surviving
owned processes. Growth is incomplete; experience, launchers and bindings did
not start. The retained checkpoint (archived)
records task timings, completion and log hashes. These results do not qualify
the new integration implicitly.

The rebase preserves both evidence-ledger additions and every original commit
author/committer date. Fuze, Arrow, the six-type driver and `flake.lock` match
the measured native implementation; its raw benchmark reports retain their
original revision identities. Main's new native definitions, generated caller
resources, Table admission and transport changes require fresh integration
checks and ordinary clean lanes.

### Qualification continuation after PR #54

PR #54 merges as `5f46096b`; issue #53 retains the final qualification gates.
The focused signed query run at `bf39a197` passes KV and Table recovery in
31.79 s and 33.42 s respectively. Each returns 41 rows, six segments and 13584
IPC bytes after frozen upload retry and worker/node/disk restart, then checks
prefix revocation and released source pins. Document provisioning fails with
`AuthorityUnavailable` before its query schedule begins. Ursula reports
`ColdBackpressure` at the existing 8388608-byte hot-store limit. This is a failed
three-source run; no provider limit or failure is waived. The
retained failure (archived)
records the command, source and log identity. Diagnosis and final ordinary clean
lanes remain outstanding.

The unchanged Document-only reproduction fails the same way. The proof's seed
driver propagates transient errors immediately, although GenServer preserves
its pending signed request and the real query host retries it. The corrected
driver retains the 20-step progress bound and adds a ten-second availability
retry budget, preserving frozen mutations and discarding only unsent private
read candidates. The proxy first refuses a seed turn, then withholds its accepted
receipt; both retries must use identical signed bytes and recover the original
receipt. The old native helper fails this injected schedule as expected.

The corrected diagnostic passes KV/Table/Document in 32.04/33.85/296.13 s,
including all existing upload, restart, result, revocation and pin checks. Its
WAL backend is file-based but its Nix scratch directory is on tmpfs; the final
committed-HEAD recovery run must use the owned ext4 scratch directory. Storage
and resident-page limits are unchanged. The linked report retains both failed
runs, the negative control, exact source/log hashes and diagnostic scope.

Clean experience at `efc7e001` passes Board and documentation checks/build, then
fails on formatting of the TypeScript logical-value guide. The formatting fix
passes `just bindings::node-check`. The prior `bf39a197` clean core passes its
first 18 tasks, including Station, disk storage and signed service, then fails
runtime upgrade with a backend `ReadFailed` and `AuthorityUnavailable`. An
unchanged focused reproduction passes; the initial cause is not established,
and final clean qualification still must pass. Neither failed lane is complete.

Hosted growth on the tracking PR's merge revision `2b53c1fc` passes twelve
tasks, then the combined Table/query proof fails at its seal-only snapshot
barrier. The fixture assumes small mutations upload before applying, but current
`prepareNext` selects direct execution for requests of at most 223 bytes. Its
later staged cancellation and part-rejection cases make the same assumption.
The corrected CLI fixtures use 200-byte values within the existing 220-byte
Table bound to select publication staging; no runtime path or limit changes.
The short lost-reply operation still verifies direct execution, exact recovery
and preservation of its applied result and row when cancellation follows.
The retained Table proof record (archived)
includes hosted completion metadata, the failed explicit-begin adapter trial,
source identities and the focused physical-disk rerun.

The corrected focused `just test::table-query-writer` run completes on ext4 in
40.117 s, recovering both initialization receipts and preserving the four-mutation,
256-byte-value and eight-resident-page bounds. The interactive snapshot is held
for 0.302 s during the final apply. These are proof timings, not a latency budget.

### Integrated launcher recovery qualification

Clean experience at `c64e5b96` passes its first six tasks, then misses the
Station Arrow reply's shared 60-second replacement/completion window. The
retained launcher record (archived)
contains completion metadata, task timings and stopped-fixture log hashes.
Main advances to `a4ba1124`, including the closing-response transport fix and
console write-observation changes. Rebase preserves all commit author dates.
The unchanged launcher proof still fails after integration; its original query
later completes without resubmission, 61.853 s after admission. This later result
does not pass that deadline. Proxy connection reuse and slower observer polling
also fail and are removed. The underlying provider-delay cause is not established.

The fixture now bounds two phases separately: automatic courier replacement must
finish within 60 s, and the resumed complete Arrow exchange has its own fixed
60-second window. This increases the total test allowance; it is not a passing
result for the former combined window or a runtime latency guarantee. Neither
phase extends its deadline after transient reads. Runtime request deadlines,
resource quotas, signed commands, current authorization and all result/recovery
assertions remain unchanged.

The focused ext4 run passes with 292 refused reads, one courier replacement in
30.257 s and subsequent complete Arrow exchange in 32.326 s, then passes worker
recovery, upgrades, Board provenance and persistent stop/start. A negative control
removes only automatic courier restart and fails at the unchanged replacement
gate. Its original topology is restored and the owned failed installation stopped.
Fresh ordinary clean lanes remain required at the final integrated source.

The earlier physical-disk query result (archived)
at `e870713e` passes KV/Table/Document recovery, but does not qualify the newly
integrated transport implicitly. Hosted run `36815884722` starts no jobs because
GitHub reports an account payment/spending restriction; it supplies no test result.

### Physical-disk captured query delivery

The clean growth run at `be27b037` passed its first eight tasks, then exceeded
`growing_query.py`'s 180-second complete-delivery limit. An unchanged focused
run on CPU 12 also exceeded that limit. The same binaries and one-CPU profile
completed on tmpfs with delivery taking 34.516 seconds; that diagnostic does not
qualify disk durability. These observations are consistent with physical WAL
cost, without isolating every source of shared-host I/O contention.

The fixture now allows 600 seconds for complete delivery, matching the existing
physical-disk proof allowance. **This increases that phase's test allowance from
180 to 600 seconds.** Other query phases retain 180 seconds. Workload, one-CPU
execution, resident pages, lost-reply schedules, exact results, cancellation and
retained acknowledgements are unchanged. Runtime limits and the frozen native
and file performance budgets are unchanged. A fixture time limit does not define
a runtime latency guarantee.

The focused ext4 run passes with the revised fixture and unchanged implementation:
write 10.691, seal 7.633, recover 41.916, publish 4.675 and deliver 242.177 seconds.
It verifies all 41 rows and 21,296 IPC bytes. The delivery report (archived)
retains both original deadline failures, the memory-backed diagnostic, source and
log hashes, and the passing dirty-tree fixture identity. It also retains the
superseded full check and complete core/experience lanes at `be27b037`; these do
not qualify later revisions implicitly. Final committed-HEAD qualification
remains outstanding.

### Finite HTTP and gRPC saved-call marker checks

At `0633d355`, the clean growth lane passes its first 24 tasks, including complete
HTTP/gRPC worker recovery and the corrected combined Table/query writer schedule.
The HTTP example then fails after its initial publication commits a call:
`ChangedCallConfiguration` comes from comparing the stored 48-byte `SPU1` upload
marker with the raw `HTQ1` request reference. An unchanged focused gRPC example
reproduces the same mismatch with `GRQ1`. The lane remains incomplete; the
example publication report (archived)
retains its task results, independent reproduction, prior core/experience passes
and log hashes.

Both examples now construct the expected marker through Station's shared
`PublicationUpload.marker` helper. The stored format and peer/correlation checks
remain unchanged. Package tests verify an independent marker byte fixture, invalid
identity rejection and equality with the stored upload marker. Each real example
also rejects a changed endpoint revision before resuming the original call.

The focused local disk runs pass for HTTP (53.59 seconds), gRPC (69.90 seconds),
HTTP with fresh-key bootstrap (56.40 seconds) and gRPC with fresh-key bootstrap
(72.30 seconds). Each reuses the original call across caller replacement, sends
exactly once and replays after node/store restart with the peer stopped and
credential removed. These timings exclude compilation. The initial development
check omitted an explicit endpoint revision and failed with a fixture `KeyError`;
the report retains that failure and the corrected fixture source hashes.
Compose and Substrate variants were not run for this correction. Final integrated
qualification is recorded separately.

## Boolean integration with native admission and Fuze validation

At `014e4f6d`, the Boolean branch is rebased onto main `e82c8430`, retaining
#54's validated canonical encoder and unnamed-output schema validation,
#57's inline Table admission and captured read selectors, and #58/#59's transport
and qualification changes. The current native definition is
`23c4c85312d089e41826bb76da6ffa2b6a009fc49bd8655bcb813524f2f401e7`.
Generated contracts and independent Python/OpenSSL signing fixtures cover the
combined definition. Both prior component-only definitions explicitly reject.
The existing Boolean FZP1 layout and its separate identifier remain unchanged.

Full `just check`, `just test::sql`, `just test::unified-codec`,
`just test::file-query` and `just bindings::node-check` pass at that committed
source, exit 0. This includes 151 ASTs, 122 plans/Arrow cases, 56 results across
three sources/eight page widths, 57 documentation examples, 88 native/port codec
cases, 95 real file-query cases and all 39 Node tests. Log:
`/tmp/transit-sql-boolean-main-e82-check.log`. The generated native-schema diff
against main changes only the definition; captured-read fields remain present.

The integration measurements (archived)
retain clean source/binary/driver/lock identities, alternating raw samples and
the exact frozen-budget comparison. Nine paired six-type samples against main
`e82c8430` return the same results with candidate medians 0.8–8.3% higher.
A separate nine-pair run uses the original control binary with its verified
`5ba8f349` SHA-256 prefix and unchanged 15% budget. Its int64, uint64, UTF-8 and
binary predicate cases exceed that budget at 17.8%, 16.5%, 20.2% and 18.6%; the
**specialized performance gate fails**. A report's successful execution status
means samples/results completed, not that its numeric budget passed.
Seven paired compiler samples against current main show four SELECT medians
76–98% higher and existing paged aggregates 4.2–5.5% higher. These replace neither
the earlier source-qualified measurements nor any frozen limit. Shared-host
load, compound throughput, installed callers and native I/O remain separate.

The pre-rebase clean core at `1bd979b5` was intentionally interrupted after new
main changes landed. It is incomplete, with `completed: false`, 269.85 seconds
and checkout `/var/tmp/transit-ci-3_i52gm9`; log:
`/tmp/transit-sql-boolean-sql-clean-core.log`. It does not qualify the integration.
The second instrumented service run at `051c766a` passes and retains its owned
fixtures under `/var/tmp/transit-sql-service-diagnostic-8jwnky5h/tmp`; it does not
reproduce or explain the original clean-service failure. Private stores and keys
remain outside Git. The earlier failed clean result remains failed.

Committed-HEAD clean core at `014e4f6d` passes all 22 tasks in 1280.49 seconds;
terminal metadata is retained at
`.cache/ci/clean/014e4f6d35d3-transit-ci-o6sevl3q`, log
`/tmp/transit-sql-boolean-main-e82-clean-core.log`. Clean experience at
`0b8f3750` fails after six passing tasks: the final Station launcher Arrow reply
misses its unchanged deadline (309.20 seconds task / 593.61 seconds lane).
Checkout `/var/tmp/transit-ci-zpxsqzvc` and log
`/tmp/transit-sql-boolean-main-e82-clean-experience.log` retain evidence. Its
owned services are stopped; data, keys and logs remain outside Git. Client
telemetry includes `HttpCapacity` refusals, but the timeout cause is unestablished.
Other lanes and installed all-source recovery remain unqualified.

### Validation reuse and current-main integration

At `c5cce70a`, the branch includes main `a4ba1124`, retaining unavailable-read
observation retries without implicit mutation resubmission and persistent
console history. The only rebase conflict joins both verification-ledger
additions. Author/committer dates are preserved; the native and FZP1 definitions
are unchanged by these main commits and the following optimizations.

Atom representation and schema correspondence are checked once per full plan
validation. The private encoder consumes that validated shape; each binding
call reuses its own schema validation before hashing. Public encoding still
rejects invalid UTF-8, oversized bytes, nonfinite floats and unknown columns;
binding still rejects type mismatches. No validation flag survives the call,
and continuation/source checks remain. SQL lowering fills owned output storage
to reduce intermediate plan copies without changing literal ownership or cleanup.

Full `just check`, `just test::unit`, `just test::sql`,
`just test::unified-codec` and `just test::console-history` pass at this executable
source, exit 0; log `/tmp/transit-sql-boolean-main-a4-check.log`. The independent
SQL and native/port counts remain 151 ASTs, 122 plans/Arrow cases, 56 results
across three sources/eight page widths, 57 documentation examples and 88 codecs.
The console proof exercises real PTY search/accept/cancel, Unicode/multiline,
restart, concurrent append, malformed records, permissions and file failure.

The retained validation measurements (archived)
contain raw alternating samples, binary/source/driver/lock identities, reproduction
commands, dirty exploratory patches and the committed-source six-type gate.
Nine measured pairs plus a discarded warmup return identical results. The eight
ratios against the original frozen control are 1.0042, 1.0322, 1.0233, 1.0627,
1.0217, 1.0115, 1.0186 and 1.0010: **the specialized subset passes** its unchanged
1.15 limit. `budgets.six_ratios` verifies complete clean evidence; the control,
driver, lock and CPU match the original budget. Other file matrices and the
large-input gate are not requalified. The earlier failing measurements remain.

Seven compiler pairs against `e82c8430` still show 64–92% overhead in the four
SELECT probes; the two paged aggregates are 1.4–1.5% faster in this sample.
Main's intervening CLI commits do not change that control's query/driver/lock
inputs. These shared-host component results do not establish native latency,
compound throughput or a complete performance pass. Compiler work remains open.

Committed-HEAD clean core at `c5cce70a` passes all 22 tasks in 883.95 seconds,
exit 0. Terminal metadata is retained at
`.cache/ci/clean/c5cce70a7722-transit-ci-yb7tf4xi`, log
`/tmp/transit-sql-boolean-main-a4-clean-core.log`. PR #52 and issue #37 track
the failed experience proof, remaining lanes, typed SDK APIs and installed
recovery. This pass qualifies that executable source, not later SDK edits.

### Typed predicate programs in Python, Node, Ruby and Rust

These four SDKs add typed postfix atoms/operators, bounded plan construction
and owned inspected program values. Their ordinary single-atom constructors
remain available. Shared Zig retains validation, canonical encoding and
execution; host code only constructs neutral values and checks response shape.
C, C++, Java, .NET, Erlang and Elixir program constructors/inspection are still
unimplemented; native/port support does not qualify those public adapters.

`boolean_bundle_fixtures()` in [unified_codec.py](../../../tests/query/unified/unified_codec.py) shares nine
independent canonical bundles with the native/port and installed SDK consumers.
Seven literal programs cover six scalar types, full-width values, negative zero,
Unicode/binary and multi-chunk literals. The additional fixtures independently
encode an all/state/NOT/AND program and the 64-instruction boundary. The two real
transports pass all 96 shared codec cases. Installed consumers verify exact
bundle bytes, invalid stacks/types/limits and input ownership. Python, Node,
Ruby and Rust pass in `/tmp/transit-sql-boolean-four-sdk-codecs-2.log`; no source
authorization or recovery claim follows from that local run. The first run
stopped because the test omitted Python's existing `ValueError` for an invalid
column; the corrected test accepts that rejection without changing SDK behavior.

The four package builds, Node strict checks and all 39 Node tests pass in
`/tmp/transit-sql-boolean-sdk-build.log`. Python's strict check passes all 23
source files in `/tmp/transit-sql-boolean-python-types.log`. The public query
guides describe exact instruction ownership and the remaining language profiles.
Reproduce installed codec checks after those package builds by invoking
`sdk_unified.install` for `('python', 'node', 'ruby', 'rust')` in a fresh private
directory; `just bindings::unified-codecs` runs the complete default language
inventory. The other six consumers still cover their documented atom profile.

The signed query schedule now checks Boolean EXPLAIN structure, redacted
literals and the 64-instruction result through each enabled program adapter,
then repeats current-denial and retired-source checks. Unsupported SDK adapters
are explicitly excluded from those program cases; the printed caller count
identifies coverage. The KV run with Python sync/async, Node, Ruby and Rust
passes, exit 0, in `/tmp/transit-sql-boolean-four-sdk-kv.log`: seven enabled
inspection callers agree, then current denial and source retirement reject.
The unchanged single-atom delivery workload recovers after source/requester/
node/disk restart, including a transient requester read timeout. It verifies
41 rows, six segments and 13,584 bytes with eight resident authority pages,
an 8 MiB hot store and 78 cold objects (8,021,154 bytes), completing in
175.65 seconds. This is an integration sample, not a latency SLO. It does not
establish compound-plan delivery/recovery or Table/Document coverage.

Full `just check` passes, exit 0, in `/tmp/transit-sql-boolean-sdk-check.log`.
Final documentation and Node formatting/lint checks pass in
`/tmp/transit-sql-boolean-sdk-docs.log`. All-language and compound durable
recovery qualification remains open. Reproduce the signed profile with
`zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node,ruby,rust -Dunified-source=kv` in the pinned shell.

### Typed predicate programs in Java, .NET, Erlang and Elixir

The continuation from `30982a1e` adds owned typed program constructors and
redacted inspection values to these four SDKs. Java and .NET copy their
instruction collections; BEAM retains immutable lists, tuples and binaries.
Erlang and Elixir share the existing adapter, with explicit Elixir struct/record
conversion. Programs carry one to 64 non-nesting postfix instructions. Shared
Zig still owns source binding, complete program validation, canonical encoding
and evaluation. These host API additions do not change the native or FZP1
definitions. C/C++ constructors and compound file plans remain unfinished.

The Java/.NET/BEAM package builds pass in
`/tmp/transit-sql-boolean-managed-build-2.log`. Installed consumers for all four
languages pass in `/tmp/transit-sql-boolean-managed-codecs.log`, including the
nine independent Boolean bundle fixtures, all six scalar types, all operators,
negative zero, Unicode/binary, long literals and the 64-instruction boundary.
Malformed stacks, excess instructions, unavailable columns and scalar/source
type mismatches reject. Managed inputs are copied before their caller-owned
lists are cleared; BEAM checks reject nested programs. The Elixir consumer
requires the public program struct and exact conversion back to its record.
These are local codec checks, not durable execution evidence.

Full `just check` passes, exit 0, in
`/tmp/transit-sql-boolean-managed-check.log`, including all 96 native/port codec
cases, generated-contract drift and the documentation build. Reproduce the
installed codec checks after `just bindings::java-build bindings::dotnet-build
bindings::beam-build` by invoking `sdk_unified.install` for
`('java', 'dotnet', 'erlang', 'elixir')` in a fresh private directory inside the
pinned bindings shell. The signed query schedule now enables these four program
inspectors; its source-specific outcomes are recorded separately below.

The default Debug signed KV schedule passes, exit 0, in
`/tmp/transit-sql-boolean-managed-kv.log`. Six native/port/managed SDK inspectors
agree on Boolean EXPLAIN, literal redaction and 64 instructions, then reject
after current revocation and source retirement. The existing single-atom
workload recovers through source/requester/node/disk restart and verifies 41
rows, six segments and 13,584 bytes. It retains eight resident authority pages
and an 8 MiB hot store, with 73 cold objects / 8,020,314 bytes, completing in
239.56 seconds. This is not a throughput claim or compound-delivery proof.
Reproduce with `just test::unified-query -Dunified-sdk=java,dotnet,erlang,elixir
-Dunified-source=kv`. Explicit ReleaseSafe, Table/Document, compound delivery
and current-source clean-lane qualification remain separate gates.

The explicit ReleaseSafe KV run also passes, exit 0, in
`/tmp/transit-sql-boolean-managed-kv-safe.log`, completing in 86.72 seconds with
101 cold objects / 8,036,601 bytes. It has the same six inspection callers,
41 rows, six segments, 13,584 result bytes and unchanged resident/store bounds.
Reproduce with `just test::unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=java,dotnet,erlang,elixir -Dunified-source=kv`. No comparison with
the concurrent Debug sample establishes a speedup or latency target. This run
qualifies typed Boolean inspection and the existing single-atom recovery
schedule only; Table/Document and compound-plan recovery remain open.

Committed-source clean core at `f6ed5fd2` passes all 22 tasks, exit 0, in
1076.22 seconds. The log is `/tmp/transit-sql-boolean-managed-clean-core.log`;
terminal timing/completion metadata is retained under
`.cache/ci/clean/f6ed5fd282cb-transit-ci-uun7d1gb`. This result precedes the
C/C++ ABI cutover below and does not qualify that replacement definition.

### Typed predicate programs in C and C++

The continuation from `f6ed5fd2` adds bounded C instructions, caller-owned
redacted inspection arrays and C++ program/inspection values. Preparation
borrows input instructions only for its synchronous call; the resulting bundle
owns its bytes. C++ binds literals from the original plan through a stationary
view, preserving their lifetime. Unknown instruction codes reject before
indexing; integer opcode storage permits validation without an invalid C++ enum
load. Shared Zig remains the validation, canonical encoding and execution owner.

The public C plan and inspection layouts change under the coordinated native
definition `b2a625681e95d8a208ebe65f4b7b86931b6582bdfcc9f85d66b043447b9473b9`.
The prior `23c4c853...` definition rejects. Generated schemas, all language
resources, independent canonical/signing fixtures and serving/reactive
descriptions move together. FZP1 program bytes and their separate definition
remain unchanged. Matching headers, SDK libraries and native artifacts are
required; this cutover supplies no conversion or reset of accepted work.

`just bindings::unified-codecs` passes all ten installed SDK consumers, exit 0,
in `/tmp/transit-sql-boolean-all-sdk-codecs.log`. Each checks the same nine
independent Boolean bundles, six scalar types, all operators, variable-width
input ownership and 64 instructions. The C/C++ tests also reject empty,
underflowing, extra-stack, oversized, unknown-opcode and invalid-source programs.
This is codec evidence, not source authorization or durable recovery evidence.
The separate C/C++ build/codec run also passes, exit 0, in
`/tmp/transit-sql-boolean-c-codecs-3.log`.

The first installed C run failed because its fixture installer did not write the
Boolean bundle files; the next exposed the invalid-enum load for opcode 99.
Both are corrected with the rejecting case retained. Their logs remain
`/tmp/transit-sql-boolean-c-codecs.log` and
`/tmp/transit-sql-boolean-c-codecs-2.log`. The first full check stopped on Zig
formatting; after formatting, full `just check` passes, exit 0, in
`/tmp/transit-sql-boolean-c-check-2.log`, including generated drift, all 96
native/port codec cases, Board checks and the documentation build.

Signed Boolean inspection is enabled for all ten SDKs in the existing source
schedule. Current-definition signed inspection/recovery, committed-source clean
lanes, Table/Document and compound delivery remain separate qualification gates.
PR #52 and issue #37 retain their terminal results and continuation handoff.

At `95d4abd0`, the all-ten-SDK ReleaseSafe KV schedule passes, exit 0, in
231.67 seconds. All 13 native/port/SDK callers agree on Boolean inspection,
redaction and 64 instructions. The existing single-atom delivery workload
recovers through source/requester/node/disk restart with exact upload retry,
current prefix denial and source-pin release: 41 rows, six segments, 13,584
bytes, eight resident authority pages, an 8 MiB hot store and 76 cold objects
(8,019,053 bytes). The log is `/tmp/transit-sql-boolean-all-sdk-kv.log`.

Committed-source `just ci-clean --lane core` at `95d4abd0` passes all 22 tasks,
exit 0, in 1111.20 seconds. The log is
`/tmp/transit-sql-boolean-c-clean-core.log`; terminal metadata is retained under
`.cache/ci/clean/95d4abd0d49c-transit-ci-kl2d3hfc`. This qualifies the core lane
for the native-definition cutover, not the following recovery fixture extension
or other clean lanes. Hosted run `36820952024` did not start its jobs because
GitHub reports failed account payments or a spending limit; skipped jobs are
not executed evidence.

### Compound programs in installed recovery

The continuation from `95d4abd0` adds an explicit compound profile to the real
source/requester recovery schedule. All ten installed SDKs construct the same
six-instruction program as the native fixture: a long UTF-8 comparison combined
with NOT of a comparison/state disjunction. Every typed bundle must match the
native canonical bytes, and all 13 caller variants prepare the identical signed
begin operation without dispatch. The independent result oracle excludes the
last two source rows: 39 KV/Table rows or 10 Document rows, preserving Document
element identities. Ignoring or changing the Boolean operators changes those
expected results. The original single-atom profile remains available.

The SQL shell additionally compiles a Boolean filter with a tighter threshold,
returning 31 KV/Table rows or eight Document rows before its LIMIT 33. This
prevents an ignored filter from passing merely because LIMIT selects the same
prefix. Its bundle and original signed request survive shell exit, lost reply
and exact retry; existing denial, ownership, complete-coverage and permanent
retirement checks remain. Resident pages, hot-store limits, operation budgets
and deadlines do not increase. Document retains its separate 64-page authority
profile; KV/Table use eight pages.

Build all packages and run all three sources with
`just bindings::unified-compound` in the pinned bindings shell. After building
matching packages, the equivalent explicit command is
`just test::unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node,ruby,rust,c,cpp,java,dotnet,erlang,elixir
-Dunified-compound=true -Dunified-shell=true`; add `-Dunified-source=kv`,
`table` or `document` for one source. Board/browser, console, example and expiry
profiles retain their separate schedules and cannot select this flag implicitly.

The updated proof executable builds and all ten installed codec consumers pass,
exit 0, in `/tmp/transit-sql-boolean-compound-build-2.log` and
`/tmp/transit-sql-boolean-compound-consumers.log`. The first build stopped on an
obsolete array-repetition spelling, corrected for pinned Zig 0.17; it did not
execute a schedule. Full `just check` also passes, exit 0, in
`/tmp/transit-sql-boolean-compound-check.log`. These checks do not establish
durable compound recovery; the signed source outcomes are recorded separately.

The combined installed run's **KV phase passes** in 327.75 seconds, including
joined caller/service cleanup before the next source begins. All 13 callers
agree on the compound bundle/prepared identity and verify complete results after
source/requester/node/disk restart. Current prefix denial and source retirement
reject. The typed program returns 39 rows / six segments / 13,288 bytes; the SQL
shell independently returns 31 rows, survives lost-reply exit and retries the
same bundle/command before retirement and collection. Bounds remain eight
authority pages and an 8 MiB hot store; the complete source phase records 138
cold objects / 16,738,044 bytes, including the separate shell query. The log is
`/tmp/transit-sql-boolean-compound-all-sources.log`. Table and Document phases
are still running or unrun at this checkpoint; this is not an all-source pass.

The same combined run subsequently **passes Table and Document**, and exits 0.
Table completes in 305.80 seconds with 39 rows / five segments / 12,048 bytes,
eight authority pages, 8 MiB hot store and 118 cold objects / 14,291,811 bytes.
Document provisioning takes 1107.88 seconds and the complete phase takes 1311.16
seconds: ten rows / two segments / 9,648 bytes, 64 authority pages, 8 MiB hot
store and 988 cold objects / 113,112,747 bytes. Every source includes all 13
caller variants, compound canonical/prepared-identity agreement, exact upload
retry, source/requester/node/disk restart, current prefix denial and retirement.
The SQL shell independently verifies 31 Table / eight Document rows, saved
bundle/exact retry across exit and permanent retirement/collection. Cleanup joins
before moving between sources and before terminal success. This qualifies the
compound schedule at frozen `0bdaaf15`, not a later runtime refactor or every
transport/bounds/error profile.

Committed-HEAD **`just ci-clean --lane core` at `0bdaaf15` passes all 22 tasks**
in 1128.22 seconds, exit 0. Completion metadata and all expected zero-exit task
records are verified under
`.cache/ci/clean/0bdaaf158d20-transit-ci-8npolt5b`; the command log is
`/tmp/transit-sql-boolean-compound-clean-core.log`. Remaining clean lanes and
hosted checks retain their separate gates.

### Shared Boolean execution for file queries

The continuation from `0bdaaf15` extracts the bounded postfix machine shared by
native and file predicates. Logical file atoms retain their own type admission;
SQL keeps the six-scalar literal profile. The compiler borrows its owned AST
only during lowering, then owns the program, literal bytes and descriptor.
File fingerprints bind instruction order/opcodes/typed literals within the
existing 8192-byte bound; existing single-atom identities and native definitions
are unchanged. Full source conversion and digest verification remain mandatory
after filtering and LIMIT.

Pinned `zig build test` in `packages/zig/transit-fuze` passes, including native
Boolean regressions and logical file truth tables, eager first-error order,
64-instruction/invalid-stack/type/column rejection, full-width uint128 comparison,
changed-program poisoning, late conversion/digest failures and exhaustive
allocation-failure cleanup. Log: `/tmp/transit-sql-boolean-file-unit-3.log`.
The first build fails on a declaration placed between Zig fields; moving the
unchanged declaration resolves it before tests execute. That log remains
`/tmp/transit-sql-boolean-file-unit-initial.log`.

`just test::file-query` passes **110 real CLI cases**, including independent
CSV/JSONL results, precedence/grouping, unknown under NOT, exact atom fingerprint,
source/derived-input aliases, aggregates, eager error branches, statement bounds,
checked gzip and disk/pipe/cancellation proofs. The retained memory proof reads
192 MiB under a 96 MiB address-space limit. Its initial new assertion compares a
lossless decimal-string counter with a Python integer; converting the asserted
counter to an integer corrects the test without changing runtime behavior.
The failed and passing logs are `/tmp/transit-sql-boolean-file-cli.log` and
`/tmp/transit-sql-boolean-file-cli-2.log`. Full `just check` and `just test::sql`
pass, exit 0, in `/tmp/transit-sql-boolean-file-check.log`. These working-tree
results do not substitute for committed-HEAD clean validation.

The [paired file report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-file-comparison.json.gz)
retains 162 successful samples: three alternating baseline/candidate pairs over
nine shapes and explicit/sampled/full discovery, 4096 rows each, one CPU, warm
input pages and unchanged budgets. The frozen baseline is `0bdaaf15`, SHA-256
`70f06335012ad4f94f044f25f305b904eb3a16c48a0281a5192cafa062f05452`;
the candidate hash is
`e499d60b442070907cdfdfb47d985fb41cd03a229027bb31f8b5e95c16055a5d`.
Reports retain source/driver/lock hashes, raw wall/CPU/allocation/RSS records,
fixture identities and independent result checks. All 27 pipeline median ratios
are within 1.15 (0.7607–1.0764, median 0.9746). Compiler ratios range
0.7649–1.4507, median 0.9993; **wide/sampled (1.4507) and gzip/sampled (1.1561)
exceed 1.15 and remain unresolved**. Allocation counts/bytes match for those
cases; one wide sample shows wall preemption, but neither cause nor a general
speedup is established. These per-source single-compilation phases and three
pairs do not resolve the earlier native SELECT compiler regressions.

The [compound-work report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-file-compound-cost.json.gz)
adds another 162 successful samples, comparing the same selected rows with a
six-instruction candidate and single-atom baseline. Across configurations,
median compile and pipeline ratios are 1.1533 and 1.0644 respectively;
pipeline ratios range 0.8524–1.2293. Extra operators are different work, so this
is a cost measurement, not an unchanged-workload regression pass. Both reports
are reproducible through `tests/fuze_benchmarks/compare.py`; the ordinary matrix
also accepts `--query compound`. Independent DuckDB compound measurements,
cold-input/remaining query matrices and installed native latency remain unrun.

### Predicate compiler cost reduction

Runtime commit `4b1dc42e` avoids initializing compound storage for absent or
single-atom predicates, keeps the compound parser outside the common stack
frame, and constructs derived-plan storage only for derived inputs. Projection
validation occurs on the completed plan; derived output schemas still validate
before name resolution. No predicate bound, public rejection, canonical bytes or
native definition changes. New rejection fixtures exercise owned string literals
when duplicate projections/output names reject after lowering.

Pinned Fuze tests, full `just check`, `just test::sql` and all **110 real file CLI
cases pass** for that runtime. SQL evidence includes 151 independent SELECT ASTs,
122 real plans/codec/Arrow cases and 56 result cases across three source bases
and eight page widths. Logs: `/tmp/transit-sql-boolean-compiler-unit-3.log` and
`/tmp/transit-sql-boolean-compiler-check.log`. The initial single-atom shortcut
fails one completion test by consuming the cursor before offering a parenthesis;
keeping cursors on the existing completion path fixes it. The failed log remains
`/tmp/transit-sql-boolean-compiler-initial-unit.log`.

The [native compiler archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-compiler-paths.json.gz)
retains six exploratory comparisons and four final nine-pair comparisons, including
slower AST initialization/return experiments that were reverted. Final source
hashes match `4b1dc42e`; original dirty-source metadata is unchanged. The final
probe SHA-256 is
`c687fb98866cfa4998e72abd05c97f5bd5811427a44360a5da30c05cfa85fcb2`.
On CPU 1, SELECT medians fall **20.8–30.3% against `2330d6ed`**, but remain
**28.0–49.9% above the frozen main control**. The control is `e82c8430`, with no
Fuze/probe/lockfile differences through `a4ba1124`. CPU-0 reports retain larger
variation and 9.3–129.7% overhead against main; they are not discarded or replaced.
The intervening utilization sample overlapped our file benchmark on CPU 0, so it
does not establish the cause of previous noise or exclusive CPU availability.
No native compiler or end-to-end latency gate is declared passed.

The [final file comparison](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-file-compiler-paths.json.gz)
retains **486 correct-result samples**: nine alternating pairs, nine shapes,
three discovery modes, 4096 rows, CPU 0 and warm input, with unchanged budgets.
All 27 compiler median ratios are below one (0.6652–0.9812, median 0.8630);
the earlier wide/sampled and gzip/sampled outliers are now 0.9450 and 0.9096.
Pipeline median ratios range 0.8678–1.2400 (median 1.0057), with **narrow/full
exceeding the unchanged 1.15 wall-time limit**. Its recorded phase CPU median
ratio is 0.9868, while wall medians are 51.96/64.43 ms; this discrepancy does not
turn the wall-time result into a pass or establish the contention cause.
The report's `status: passed` denotes result correctness, not every timing gate.
Compound-to-compound costs, cold inputs and remaining matrices stay open.

Committed-HEAD clean core at the preceding file checkpoint `2330d6ed` completes
all **22 tasks in 1168.10 seconds**, exit 0. Verified completion metadata and task
records are retained in the native archive and under
`.cache/ci/clean/2330d6ede62c-transit-ci-8__7bafx`; log
`/tmp/transit-sql-boolean-file-clean-core.log`. This predates the compiler change.
Current-source clean lanes and installed requalification remain separate gates.

### Compiled-plan return and equivalent compound measurements

Commit `06700b69` removes a private value-returning compiler wrapper. Each public
entry point lowers into its own result storage and retains the same allocation,
cleanup and validation path. The pinned ReleaseSafe assembly loses one 3,400-byte
plan copy; the public `plan` stack frame shrinks from 22,664 to 19,272 bytes.
One full-plan return copy remains. The [native return archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-compiler-return.json.gz)
retains source patches, assembly, binary/source hashes and three nine-pair CPU-1
comparisons. An earlier active-payload reconstruction experiment gives mixed
results (−1.7% to +6.7%) and is reverted. The accepted change gives 0.5–11.9%
lower SELECT medians against `4b1dc42e`, with overlapping ranges; it does not
establish a general speedup. Against the unchanged main control, SELECT medians
remain **22.5–41.6% higher**, so the native compiler gate stays open.

Pinned Fuze unit tests, full `just check` and `just test::sql` pass for the final
runtime. The independent SQL proof retains 151 SELECT ASTs, 122 canonical
plan/Arrow cases and 56 result cases across three source bases/eight page widths.
Log: `/tmp/transit-sql-compiler-direct-check.log`. The file comparison runner
adds explicit baseline-query and CPU controls: identical query programs are
labeled separately from filter/compound comparisons with equal results but
different operator work. Its seven negative/oracle tests pass; different query
pairs with different results reject before execution.

The [equivalent compound report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-file-compound-equivalent.json.gz)
passes **486 result-checked samples**: nine alternating pairs across all nine
shapes and three discovery modes, 4096 rows, CPU 1 and warm input. Both binaries
execute the same six-instruction program. The frozen baseline is `2330d6ed`;
candidate source hashes match `06700b69`. All **27 compiler ratios** satisfy
1.15 (0.7388–1.1221, median 0.9956), as do all **27 pipeline ratios**
(0.9955–1.0215, median 1.0118). This qualifies that equivalent compound matrix;
it does not replace the earlier CPU-0 single-atom pipeline outlier or qualify
cold inputs, independent DuckDB comparisons, native transport latency or clean
integration lanes. The shared host is not isolated. Log:
`/tmp/transit-sql-compiler-direct-qualification.log`.

Committed-HEAD **clean core at `dafca8c9` passes all 22 tasks in 1161.50 seconds**,
exit 0. Expected task order, zero exits and completed metadata are verified in
`.cache/ci/clean/dafca8c97bdb-transit-ci-ainxmlaz` and retained in the native
return archive. Log: `/tmp/transit-sql-boolean-compiler-clean-core.log`. This
qualifies the preceding compiler checkpoint, not the later return-wrapper
change or the other required lanes. Final documentation validation for this
continuation passes 4,908 local links across 503 files.

Further read-only inspection of the retained Station experience failure at
`0b8f3750` identifies six `/v1/query` deadline events with **1.90–1.95 seconds
spent acquiring the authority lock** and no serialized work recorded. The two
clusters accompany command work reaching the two-second request limit, provider
`ReadFailed` events and capacity refusals. The owning `Native.Server.acquire`
and observability reference define `wait_ns` as lock acquisition, distinct from
provider/engine work. These sampled logs narrow the next investigation to lock
holders and provider progress; they do not prove why the holder stalled or why
the complete Arrow reply missed its deadline. No rerun or changed limit is
claimed. Logs/stores remain at
`/var/tmp/transit-ci-zpxsqzvc/src/.cache/launchers/local/station-c5bbc0`.

### Owned parser projections and independent compound matrix

Commit `862ab427` fills selections directly in the owned AST and projections
through caller-owned arrays. It removes intermediate array returns without
changing the AST layout, accepted syntax, ownership, bounds or canonical plans.
Pinned Fuze units, full `just check`, `just test::sql` and all **110 real file CLI
cases pass**, exit 0. The SQL proof retains 151 SELECT ASTs, 122 canonical
plan/Arrow cases and 56 result cases across three sources/eight page widths.
Log: `/tmp/transit-sql-parser-owned-check.log`.

The [parser storage archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-boolean-parser-storage.json.gz)
retains three nine-pair CPU-1 comparisons, both source variants and assembly.
The projection-only intermediate has mixed SELECT deltas (−2.4% to +8.5%); it is
not accepted alone. Filling the AST selection in place gives 1.3–3.4% lower
SELECT medians against `06700b69`, with overlapping ranges. The main comparison
still shows **17.4–38.9% overhead**. The 19,272-byte compiler stack frame and
large AST initialization remain; no native compiler timing pass is claimed.
Final source hashes match `862ab427`, with original dirty metadata preserved.

The independent compound report (archived)
passes **324 samples**: nine shapes × explicit/sampled/full discovery × cold/warm
input × Transit/DuckDB × three repetitions, 4096 rows per fixture. Every expected
sample identity is present exactly once, result counts/checksums pass, and
`mincore` confirms zero original-input residency for cold samples and full
residency for warm samples. The pinned tools are Zig
`0.17.0-dev.2267+48abf1a34`, DuckDB `1.5.2`/`8a5851971f` and PyArrow `23.0.0`.
Both engines use one CPU, the existing 4 GiB process address-space ceiling and
300-second timeout; DuckDB retains one thread and its 64 MB memory limit.

The report retains all six phase timings, CPU/RSS/allocation evidence, exact
fixtures and source/tool/binary provenance. It compares a compound id filter
over shared fixture values, not complete SQL value/error/five-state equivalence.
Discovery, conversion, vectorization and Arrow/allocation scopes differ as
documented by the [benchmark owner](../../../tests/performance/query/README.md). This is descriptive
comparative evidence, not an unchanged-workload/frozen-budget regression pass.
Cold input means original page-cache eviction, not a cold machine or device;
private captures are new and warm. Partial/raw modes, other queries and native
transport/large-input compound profiles remain unmeasured. Reproduce with
`nix develop .#benchmarks --command just test::file-benchmark --query compound
--modes explicit sampled full --caches cold_input warm_input --repetitions 3
--output REPORT`. Log: `/tmp/transit-sql-parser-compound-matrix.log`.

Earlier committed-source lanes also complete, with metadata/task records in
the parser storage archive: **clean core at `05a386ab` passes 22/22 in 1107.60
seconds**, and **clean bindings at `30982a1e` passes 17/17 in 10450.29 seconds**.
Both exit 0; completed metadata and every expected zero-exit task are verified.
Their logs are `/tmp/transit-sql-compiler-direct-clean-core.log` and
`/tmp/transit-sql-boolean-sdk-clean-bindings.log`. Core predates the parser change;
bindings predates the later native definition/SDK cutover. Neither qualifies
those later changes or substitutes for all required lanes at one revision.

## File-query output aliases — 2026-10-01

The separate `feat/sql-file-output-aliases` worktree starts at main `a4ba1124`.
Runtime commits `620f2c16` and `e5d08951` add owned SQL output names to file
plans and isolate renamed-output descriptor validation. Native saved plans,
SDK layouts, source bindings and existing unnamed file fingerprints are unchanged.
This source does not include the separate Boolean continuation in PR #52.

Pinned Fuze units, full `just check`, `just test::sql`, `just test::file-query`
and `just test::logical-arrow` pass on final runtime `e5d08951`, exit 0.
The SQL proof checks 134 SELECT ASTs, 105 canonical plan/codec/Arrow cases and
44 independent results across three source bases/eight page widths. All **108
real file CLI cases** and **103 PyArrow 23.0.0 cases** pass. The CLI proof retains
192 MiB input under a 96 MiB address-space limit. Logs:
`/tmp/transit-sql-file-alias-final-check.log` and
`/tmp/transit-sql-file-alias-scoped.log`. Initial-runtime full/focused passes are
separately retained in `/tmp/transit-sql-file-alias-check.log` and
`/tmp/transit-sql-file-alias-integration.log`.

Fixtures cover row/aggregate aliases, repeated recursive input columns, exact
Arrow names/descriptors and missing/null/value states, quoted names, derived-input
scope and hidden original names. Native/file comparisons share expected scope
and projection semantics. Independent Python reconstructs unnamed and named
fingerprints. Ownership checks overwrite SQL text and mutate borrowed names
during execution; mutation fails before another row and cannot complete.
Malformed names, collisions, mismatched name-vector widths and repeated recursive
outputs exceeding the descriptor budget reject. Allocation-failure injection
retains cleanup across owned alias/literal/schema/result allocation. Late source
conversion failure after an aliased LIMIT still omits successful JSON/Arrow
completion. Existing cell and Arrow fixture families retain their own wider
value/state coverage; the alias cases alone do not prove every logical type.

The [file-alias measurement archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-file-output-aliases.json.gz)
contains four paired reports, all raw samples/configurations, production source
hashes verified against the two runtime commits, frozen binary/tool/lock hashes,
source patches, assembly and the exact measurement drivers. All **1080 measured
results pass**. Both engines in these pairs are frozen Transit binaries; this is
not a DuckDB comparison. Workloads use 4096 rows, nine alternating pairs on CPU 1,
warm input, the existing 4 GiB address-space ceiling and 300-second timeout.
Other host work is not isolated. Compilation is one cold invocation per process;
its microsecond timings retain all samples and do not establish steady-state
compiler throughput.

- Initial main comparison: 486 samples across nine shapes and explicit/sampled/full
  discovery. All 27 pipeline ratios meet 1.15 (0.9957–1.0700), but **12/27 compiler
  cases exceed 1.15** (complete range 0.9758–1.3832).
- Workspace isolation: 54 narrow-shape samples against the initial implementation.
  The generated validator frame falls from **7848 to 384 bytes**; the main control
  uses 232 bytes. All validation remains. Compiler ratios are mixed (0.8724–1.1252);
  this structural stack improvement is not claimed as a compiler speedup.
- Final main comparison: 486 samples. All 27 pipeline ratios meet 1.15
  (0.9466–1.0306), but **16/27 compiler cases exceed 1.15** (range 1.0541–1.4094).
  The compiler gate remains open; no failed sample or budget is removed.
- New named-plan cost: 54 narrow-shape samples compare default `id` with explicit
  `AS id` on the same final binary. Values/results agree while the plan work
  differs. Compiler ratios are 1.0368–1.0746; pipeline ratios 0.9719–1.0086.
  This descriptive feature-cost measurement is not an unchanged-workload gate.

The ignored comparison driver is reused from PR #52 with this worktree's file
harness, production source and frozen binaries; its exact source is in the archive.
Build controls/candidates with `zig build file-benchmark -Doptimize=ReleaseSafe`.
The initial invocation of nonexistent `transit-fuze-benchmark` exited 1 before
any measurement; the corrected build passed. Remaining cold-input/query/mode and
larger-input timing matrices, current committed-head clean lanes and installed
qualification are not implied by these focused passes. Adjacent Station/growing
fixture qualification stays with #53/#60; unmerged proof-allowance changes are not
applied here.

### File-alias lowering follow-up

Commits `818758a0` and `2cbd1a00` borrow output-name metadata from the owned
syntax tree during lowering and resolve aggregate inputs directly through the
projection. The compiled file plan still owns its names. An ownership regression
compiles and destroys another named query before inspecting the first plan.
Generated `SqlLowering.project` code removes a 432-byte projection copy and
reduces its stack frame from 792 to 184 bytes; the temporary 128-entry name
array used for aggregate resolution is also removed.

The [lowering measurement archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-file-alias-lowering.json.gz)
retains six reports and all **1836 correct results**, exact drivers, binary
hashes, source patches and assembly. Production hashes are checked against
`818758a0` or `2cbd1a00`; the earlier intermediate borrowing experiment retains
its exact patch against `c3e39c3a`. Reports distinguish successful result checks
from the existing 1.15 timing limit. The workload, nine alternating pairs, CPU 1,
4096 rows, 4 GiB address-space ceiling and 300-second timeout are unchanged.

- Initial borrowing experiment: 54 narrow-shape samples against the previous
  implementation; compiler ratios 0.8581–0.9141 and pipeline 1.0088–1.0130.
- Final borrowing against main: 486 samples; **6/27 compiler cases exceed 1.15**
  (range 0.9542–1.1751). All pipeline cases meet it (0.9805–1.0318).
- Direct projection resolution against the borrowing revision: 162 unchanged
  filter samples across narrow/sparse/gzip shapes. Compiler ratios are mixed,
  0.8829–1.0903; pipeline ratios 0.9843–1.0145.
- Final warm-input filter against main: 486 samples; all 27 compiler ratios
  (0.9266–1.1452) and 27 pipeline ratios (0.9495–1.0176) meet 1.15.
- Final cold-input filter against main: 486 samples; all pipeline ratios meet
  1.15 (0.9836–1.0107). **Three compiler cases exceed it**: sparse/explicit
  1.1542, decimal/sampled 1.2279 and gzip/full 1.1549. Cold-input conditioning
  is the harness's file-cache request, not proof of cold physical storage.
- Derived aliased SUM against the borrowing revision: 162 samples across
  narrow/sparse/gzip; compiler ratios 0.8680–1.0273 and pipeline 0.9895–1.0110.
  Both binaries execute the same renamed inner projection and outer aggregate.

The earlier failed timing cases remain in their original archive. The completed
warm filter matrix does not establish the remaining cold/query/size matrices or
an overall performance pass. Microsecond compilation timings remain one call per
process on a shared host, rather than steady-state throughput measurements.

At `818758a0`, full `just check`, independent SQL, 108 file CLI cases and 103
PyArrow cases pass, exit 0; log `/tmp/transit-sql-file-alias-borrowed-check.log`.
At `2cbd1a00`, Fuze units pass, but full `just check` fails in console history:
after Ctrl-C clears a history search, `console_history.py:174` receives no new
prompt within the existing deadline. The cause is not established. The original
chained SQL/file/Arrow tasks were unrun; log
`/tmp/transit-sql-file-alias-direct-check.log`. This failure is not a passed
qualification or attributed to the lowering changes.

A separate focused run at the same `2cbd1a00` source passes `just test::sql`,
all 108 real file CLI cases and all 103 PyArrow cases, exit 0. It retains the
134 AST / 105 plan / 44 independent result counts and the 192 MiB input under
96 MiB address-space check. Log:
`/var/tmp/transit-sql-file-alias-submit-focused.log`. These focused passes do
not resolve or replace the failed full check.

The prior committed-HEAD clean core at `c3e39c3a` completes **22/22 tasks in
1185.49 seconds**, exit 0. Its metadata and exact task inventory are verified
and retained in the lowering archive. Log:
`/tmp/transit-sql-file-alias-clean-core.log`. This precedes the two lowering
optimizations and does not qualify their final source. Current clean lanes,
the console failure and remaining performance limits stay open.

## COUNT(column) shared transition — 2026-10-01

The `feat/sql-count-column` continuation starts from `a3e15a9f`. Its shared
pure cell transition counts each top-level value, ignores missing/null, rejects
type errors/conflicts and checks the full u64 range. Focused Fuze package tests
pass under the pinned bindings shell (`cd packages/zig/transit-fuze && zig build
test`), exit 0; log `/var/tmp/transit-sql-count-value-units.log`. Fixtures cover
all six native scalar types, false/empty/negative-zero values, overflow and a
logical empty list as one top-level value.

At prerequisite commit `d35d04e4`, this helper was not exposed through typed
plans, SQL, resumable execution or caller APIs. The coordinated continuation
below supersedes that implementation boundary without enlarging this unit proof.

## COUNT(column) coordinated surface — 2026-10-01

The continuation on `d35d04e4` adds aggregate `count_values` (tag 3), shared
native/file SQL lowering, resumable progress and neutral manifest value counts,
all ten typed SDKs, generated contracts and independent signing fixtures.
Progress grows from 167 to 175 bytes; the largest KV checkpoint is 254 bytes
within the unchanged 256-byte value bound. Both native and FZP1 definition
identifiers change. Former definitions/layouts reject rather than defaulting,
resetting progress or invoking a fallback decoder.

The working-tree full `just check` passes under the pinned bindings shell,
followed by **162 real file CLI cases**, **106 PyArrow cases** and **64 shared
native/port codec cases**, exit 0. Log:
`/var/tmp/transit-count-column-check-manifest-fixed.log`. The file proof retains
192 MiB input under 96 MiB address space and checks late conversion failures
after LIMIT 0 and LIMIT 1. Recursive file counts count a top-level list as one
value. Full checks include generated drift, units, 422 CLI diagnostic cases,
the four terminal signal schedules, history and frontend checks/builds.

`just test::sql` and the independent Arrow proof pass, exit 0, in
`/var/tmp/transit-count-column-generated-sql-fixed.log`: **157 SELECT ASTs,
125 canonical-plan/codec/Arrow cases, 57 independently evaluated results across
three source kinds and eight page widths**, and 21 excluded/error cases.
Fuze units separately exercise six scalar types, all three basis kinds, widths
1–8, seven LIMIT choices, encode/decode after every step, full u64 counters,
null/missing LIMIT consumption, errors/conflicts and forged checkpoint rejection;
log `/var/tmp/transit-count-column-fuze-expanded.log`.

All ten installed query SDK codec consumers pass against independent count
bundles for KV, Table and Document sources, alongside existing byte/Arrow
fixtures. All SDK packages build, and Node checks pass after formatting a
pre-existing logical-types example. Log:
`/var/tmp/transit-count-column-installed-codecs-fixed.log`, exit 0. This is codec
and packaging evidence, not service authorization or recovery qualification.

Failed development attempts remain distinct: an old fixed-offset malformed
progress test failed after the layout change; generated Board contracts rejected
stale reactive signing fixtures; full checks caught the stale progress limit,
remaining signing fixtures and missing required `value_count` fields in frontend
test manifests. The first SDK command stopped at Node documentation formatting,
before running installed consumers. Their logs are respectively
`/var/tmp/transit-count-column-fuze.log`,
`/var/tmp/transit-count-column-generated-sql.log`,
`/var/tmp/transit-count-column-check.log`,
`/var/tmp/transit-count-column-check-fixed.log`,
`/var/tmp/transit-count-column-check-signing-fixed.log` and
`/var/tmp/transit-count-column-sdk-codecs.log`. Subsequent focused successes do
not turn those incomplete commands into passes.

A later review corrected Flight's independently reconstructed output schema
to use the shared plan, including value-count uint64 conversion and row/aggregate
aliases. The refreshed full `just check` and `just test::sql` pass, exit 0, in
`/var/tmp/transit-count-column-flight-layout-check.log`, including 57 parsed
documentation examples and the same independent result counts above.

`just test::flight` completes successfully, exit 0; log
`/var/tmp/transit-count-column-flight.log`. PyArrow verifies the ordinary native
Table result and exact retry (72.96 seconds for that phase). ADBC Python then
verifies named COUNT(value) = 32 across 41 nullable rows, derived LIMIT 3 count =
2, empty count zero, repeated renamed null outputs and unchanged COUNT(*)/SUM.
The independent C ADBC consumer checks all 41 int64/null rows and the native
Table schema. These added count cases establish normal gateway execution, not
COUNT-specific recovery after a fault.

The installed KV command at `029b21a0` also completes, exit 0, in **233.47 s**;
log `/var/tmp/transit-count-column-installed-kv.log`. All 13 native/port/SDK caller
variants agree on named value-count inspection and renamed limited input. The
existing row schedule preserves exact saved upload retry, worker/node/store
replacement, current denial, retirement and released pins: 41 rows, six segments,
13,584 bytes, eight resident authority pages, 8 MiB hot store, 41 cold objects and
8,005,412 cold bytes. Its runtime query is a row projection, so this pass does
not establish COUNT accumulator recovery.

`just test::unified-counts` extends that same rig with a receipt held after a
nonzero unfinished count checkpoint, exact original upload recovery, and a
comparison of accepted progress before and after all workers, node and disk
store restart. Separate partial-count cases deny source access and cancel work;
completed results test current read denial. Every installed SDK exposes its
selected/value counters to the independent Arrow/result oracle. Empty LIMIT and
Document missing-value cases keep selected rows distinct from contributing
values. The **KV schedule passes with all 13 callers in 390.55 s**, exit 0, in
`/var/tmp/transit-count-column-kv-partial-recovery.log`. Its held committed
accumulator is 2/10; the identical checkpoint survives replacement and completes
at 10. Current denial, cancellation, unchanged closed checkpoints, zero LIMIT,
and source retirement pass. The full rig retains eight resident authority pages,
8 MiB hot store, 185 cold objects and 20,536,884 cold bytes. This proof extends
`029b21a0` with the accompanying test changes; runtime code is unchanged.

The **Table schedule passes with all 13 callers in 228.12 s**, with its held
accumulator at 8/10. It checks the same recovery, denial, cancellation, empty
LIMIT and retirement cases, retaining eight resident authority pages, 8 MiB hot
store, 112 cold objects and 11,582,298 cold bytes. The sequential Document
schedule fails during provisioning, before query inspection or COUNT assertions,
and the combined command exits 1. MinIO returns HTTP 507 `XMinioStorageFull`;
Ursula then reports `ColdBackpressure` when a write would exceed the unchanged
8 MiB hot limit. The log is
`/var/tmp/transit-count-column-table-document-partial-recovery.log`;
bounded failure evidence (archived)
preserves the completed Table phase and unrun Document checks. Fixture cleanup
joins its children and removes the private state; the log retains provider tails.

Removing regenerable build caches from three inactive owned checkouts increases
available disk space from about 18 to 27 GiB while preserving source, recorded
evidence and frozen comparison binaries. The unchanged Document-only rerun at
`40ad89aa` **passes with all 13 callers in 1443.13 s**, exit 0; log
`/var/tmp/transit-count-column-document-partial-recovery-retry.log`.
Its held 8/10 accumulator survives replacement and completes at 10. The separate
missing-column query selects ten rows and counts zero. The same current-denial,
cancellation, empty LIMIT, retirement and pin-release checks pass, with the
existing 64 resident authority pages, 8 MiB hot store, 1037 cold objects and
120,666,637 cold bytes. Source-qualified evidence (archived)
retains the completed scope and prior failure. No storage threshold, deadline,
resident bound or assertion changes.

Committed-head core at `029b21a0` **fails after 19 passing tasks**, with two later
tasks unrun, in 1106.60 seconds. `test::callers` expects `AccessDenied` for an
unauthorized effect but receives `AuthorityUnavailable`; the node records a
`page.stage ReadFailed` and HTTP 503 after about two seconds of request work.
That observation does not establish the cause of the provider failure.
[Exact metadata, task results and unrun inventory](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-clean-core-2026-10-01.json)
retain the failed outcome. Checkout: `/var/tmp/transit-ci-skzrxzcq/src`; log:
`/var/tmp/transit-count-column-clean-core.log`. An unchanged focused
`just test::callers` rerun in that same checkout passes, exit 0, log
`/var/tmp/transit-count-clean-callers-focused.log`. No deadlines, assertions or
runtime code change. This focused pass does not complete the failed lane or
explain its failure. Refreshed full `just check` for the new proof/benchmark
changes also passes, exit 0, in `/var/tmp/transit-count-proof-check.log`.

Fresh core at `40ad89aa` **passes all 22 tasks in 1155.90 s**, exit 0. Completed
metadata, exact task order and all zero exits are verified at
`.cache/ci/clean/40ad89aa1b7c-transit-ci-jty9suii`; the
[file-control archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-file-controls.json.gz)
retains the metadata/results. Log:
`/var/tmp/transit-count-column-recovery-clean-core.log`. This later pass does
not establish the cause of the earlier failure. Production code is unchanged
at `5d897f0d`; its clean bindings lane remains in progress. Full `just check`
for the file-profile/evidence changes passes in
`/var/tmp/transit-count-file-profile-check.log`.

`just test::unified-counts -Dunified-shell=true` also selects COUNT for the
actual signed SQL shell's existing frozen-bundle/original-command recovery
schedule. It checks the renamed derived input, named uint64 result and manifest
counters, including Document missing values, through shell exit/restart and
permanent retirement/collection. The all-source native/port/shell command
**fails**, exit 1, in `/var/tmp/transit-count-column-shell-recovery.log`.
KV completes the shell assertions in **287.10 s**. Table completes ordinary
row recovery and native/port partial-count recovery, denial, cancellation and
zero LIMIT, then fails in shell completion polling with `KeyError: status`.
That expression discards the actual response body; worker tails include
`AuthorityTimeout`, but they do not establish the shell error or its cause.
Document is unrun. [Bounded failure evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-shell-recovery-2026-10-01.json)
retains the completed scope and exact proof hashes. A diagnostic assertion now
preserves the status response without accepting errors, repeating failed reads
or increasing the existing 300-second deadline.

The diagnostic-only Table rerun **passes in 223.92 s**, exit 0; log
`/var/tmp/transit-count-column-shell-table-diagnostic.log`. It covers native/port
partial-count recovery and the actual shell's exact restart/retry, named uint64
result, manifest counters, current denial and retirement/collection. The existing
eight resident pages and 8 MiB hot store retain 166 cold objects / 18,368,277 bytes.
[Source-qualified Table evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-shell-table-recovery-2026-10-01.json)
does not explain the earlier status failure. Document shell recovery separately
**passes at `cdb1bc49` in 1328.60 s**, exit 0, including provisioning in 1023.26 s.
The native/port/actual-shell schedule preserves partial 8/10 through replacement,
checks denial/cancellation and missing values (ten selected/count zero), and
completes original-bundle/request recovery, named output and retirement/collection.
Its existing 64 resident pages and 8 MiB hot store retain 1094 cold objects /
124,201,701 bytes. [Document shell evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-shell-document-recovery-2026-10-01.json)
and `/var/tmp/transit-count-column-shell-document-recovery.log` retain this
separate pass; installed SDK consumers were not enabled in that run.

The default console's separate snapshot path also **passes** explicit COUNT
cases in the real local-server proof: empty zero, one value among two nullable
rows, unchanged row count two, null-only zero, renamed derived input and LIMIT
zero. Each result has a named uint64 column and independent completed snapshot.
The full server lifecycle completes in **50.56 s**, exit 0; log
`/var/tmp/transit-count-column-interactive-server-runtime-env.log`. The command
uses the pinned bindings shell with only `TRANSIT_SQL_TOOLS` and
`TRANSIT_GSON_JAR` removed from the runtime environment. Its first attempt failed
before these assertions because automatic server configuration rejected the
tool-only setting `TRANSIT_SQL_TOOLS`; log
`/var/tmp/transit-count-column-interactive-server.log`, retained fixture
`/var/tmp/transit-server-proof-c70z6cd8`. No product setting or deadline changes.

Clean experience at committed `2130f367` **fails after five passing tasks in
208.01 s**. `transit-board::query-test` receives HTTP 503 `Unavailable` when
retrying the exact prepared upload after its original receipt; the final Station
task is unrun. The response does not establish a rejected or duplicated mutation,
and the retained process tails do not identify its upstream cause.
[Exact metadata and task inventory](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-clean-experience-2026-10-01.json)
are verified against the committed suite. Checkout:
`/var/tmp/transit-ci-en_y0mfh/src`; log:
`/var/tmp/transit-count-column-clean-experience.log`.
An unchanged focused `just transit-board::query-test` rerun in that checkout
passes, exit 0; log `/var/tmp/transit-count-clean-board-query-focused.log`.
The focused pass does not complete the failed lane or explain its HTTP 503.
Full `just check` passes for the diagnostic and failure-evidence changes, exit 0;
log `/var/tmp/transit-count-failure-diagnostics-check.log`.

The fresh clean experience lane at `cdb1bc49` **fails after six passing tasks
in 514.46 s**, including a passing Board query task. The final Station launcher
task fails its unchanged 60-second Arrow-reply deadline after courier readiness
replacement. Its later lifecycle checks are unrun. Worker logs record HTTP 503
`HttpCapacity` and `AuthorityUnavailable`; the cause is not established.
[Completed task inventory and bounded observations](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-experience-station-2026-10-01.json)
retain this failure separately from the earlier Board failure. Checkout:
`/var/tmp/transit-ci-mc2kg8kf/src`; fixture:
`.cache/launchers/local/station-886ef1`; log:
`/var/tmp/transit-count-diagnostics-clean-experience-retry.log`.

Clean launchers at `cdb1bc49` **passes both tasks in 322.54 s**.
[Completed metadata and task results](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-clean-launchers-2026-10-01.json)
match the committed suite. The proof includes local persistence, exact retries,
same-PID replacement, fencing, missing-store refusal and foreground shutdown.
Log: `/var/tmp/transit-count-diagnostics-clean-launchers.log`; retained results:
`.cache/ci/clean/cdb1bc49777e-transit-ci-x77143dn`. The successful runner removes
its temporary checkout. This lane does not complete experience or bindings.
Full `just check` passes for the interactive-console proof and qualification
evidence changes, exit 0; log `/var/tmp/transit-count-console-qualification-check.log`.

Remaining CLI qualification, compiler timing failures and clean lanes stay in the
[SQL and dataflows](../../roadmap/12-sql-and-dataflows.md).

### Native COUNT costs

The [native count archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-native.json.gz)
retains nine alternating candidate/control pairs for the unchanged thirteen-case
pure benchmark. Frozen runtime `029b21a0` is compared with its parent
`a3e15a9f`; the original Zig benchmark source is identical at both revisions.
The binaries, Python driver, new-profile Zig driver, lockfile, source-diff hashes,
commands and all raw samples are recorded. Both probes use pinned Zig
0.17.0-dev.2267+48abf1a34, ReleaseSafe and CPU 1, on a shared host with external
disk proofs active. No isolated-host or end-to-end latency claim follows.

All thirteen median ratios meet the unchanged 1.15 comparison budget in this
run. SELECT compilation ratios are **1.0106 / 1.0193 / 1.0065 / 1.0086**;
COUNT(*) and SUM execution ratios are **0.9989 / 1.0039**. Mutation/declaration
controls range from **0.9706 to 1.0342**. This is a bounded regression observation,
not evidence of a general speedup or completion of the file/acquisition matrices.

The separate new-capability profile records nine samples for each of 24 compiler
and 24 execution cases: six native scalar types, all-value/mixed pages and both
COUNT forms. Compilation medians span **452.95–525.03 ns**; 8192-row execution
with encode/decode after every eight-row page spans **0.893–0.928 ms**. Every
iteration checks selected/contributing progress, and the final Arrow result is
decoded outside the timing interval. Mixed pages contain half values and half
null/missing, returning 4096 for COUNT(column) and 8192 for COUNT(*). That result
difference precludes an equivalent-result speedup claim. The baseline execution
probe does not serialize progress, so its absolute timings cannot isolate the
new counter's serialization cost. Logs: `/var/tmp/transit-count-performance.log`;
both commands exit 0. File costs, native acquisition/publication, recovery and
remaining clean lanes retain their separate gates.

### File COUNT costs and rejected compiler experiments

The [file-control archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-file-controls.json.gz)
retains **3888 correct results** across projection, filter, COUNT(*) and SUM;
nine file shapes; explicit/sampled/full discovery; both input-cache conditions;
and nine alternating pairs. Both frozen probes use the same benchmark source,
with runtime `029b21a0` compared against parent `a3e15a9f`. All **216 pipeline
ratios pass** the existing 1.15 limit (0.9832–1.0849). Three of 216 compiler ratios
fail: cold projection narrow/explicit **1.2579**, cold projection wide/explicit
**1.2833**, and warm SUM sparse/sampled **1.2231**. Other compiler ratios pass.
These failures keep overall performance qualification open. Exact drivers,
source/binary hashes, raw samples, input-residency checks and gates are retained.

The separate COUNT(column) capability archive (archived)
passes **1296 Transit/DuckDB results**: nine shapes, four typed discovery modes,
both input-cache conditions and nine samples per engine. Each source has 4096
rows; sparse values contribute 2184 and the other selected columns contribute
4096, including top-level lists. Native compilation medians span **5.56–24.98
microseconds**; full scan/conversion/count medians span **33.97–407.53 ms**.
DuckDB's corresponding binding and scan/Arrow phases have different boundaries;
matching scalar results do not establish equal conversion work, type inference
or a general speedup. Both matrices run on CPU 1 on a shared host, with unchanged
resource and timeout limits. Log `/var/tmp/transit-count-file-performance.log`,
combined exit 0 for correctness; the three timing failures remain failures.

An isolated parser experiment reuses #52's owned selection/projection storage,
adapted for COUNT(column). Independent SQL, Fuze units and all 162 file CLI cases
pass. The projection function shrinks from 744 to 532 machine-code bytes, but
native SELECT median ratios are only 0.9903–0.9984 and targeted cold wide/explicit
compilation regresses to **1.3533**. Same-binary file controls span 0.8703–1.0613,
with that cold wide/explicit case at 0.9724. The experiment is **rejected** and
its runtime patch restored; code size alone is not a timing improvement.
The experiment archive (archived)
retains 1098 native case measurements, 486 file process results, the exact patch,
drivers, assembly and control provenance. These diagnostics use CPU 2 while the
original matrices use CPU 1; shared-host variation and the original failures
remain explicit. No published production implementation changes.

A separate experiment moves the unchanged file compiler into a private function
that cannot be inlined. Fuze units and all **540 paired process results** pass,
but ten of thirty compiler gates fail: maxima **3.7779** against pre-COUNT and
**3.8324** against unmodified COUNT. All thirty pipeline gates pass. The smaller
caller body does not justify the compiler costs; this patch is **rejected and
restored**. The [boundary experiment archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-rejected-count-compile-boundary.json.gz)
retains the exact patch, source/binary identities, driver bytes, assembly and
six completed comparisons. They use CPU 1, nine alternating pairs, verified
input-cache conditioning and unchanged limits on the shared host. Changing a
call boundary changes where work is incurred; these timings do not prove why
the explicit-schema cases regress.

The subsequent `db5a29bc` implementation replaces the file compiler's schema
encode/decode copy with `Type.clone`. It retains descriptor validation and uses
the canonical writer to check the independent encoded-byte budget, then owns all
names and recursive children directly. Source identity/metadata checks remain.
Canonical bytes, fingerprints, native/FZP1 definitions and ABI layouts do not
change. Fuze tests check use after releasing the original, every allocation
failure, recursive containers, independent scalar fixtures and exact node/name
budget boundaries. An added test initially used an inferred tuple where the
pinned compiler requires an array; the corrected full unit suite passes in
`/var/tmp/transit-count-descriptor-copy-bounds-array.log`. All **162 file CLI
cases** also pass, including the 192 MiB/96 MiB memory proof, in
`/var/tmp/transit-count-descriptor-copy-file-query.log`.

The [owned-descriptor archive](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-descriptor-copy.json.gz)
retains **540 correct paired results** against pre-COUNT and unmodified COUNT,
with all **30 compiler and 30 pipeline gates passing**. Compiler ratios span
**0.7880–1.0321** for the targeted narrow/wide projections and sparse SUM cases.
The three originally failing combinations pass these targeted runs, but the
complete frozen-control matrix remains open. Nine alternating pairs use CPU 1,
verified input-cache conditions and unchanged budgets on the shared host.
The final committed prototype rebuild is byte-identical to the measured binary;
the archive distinguishes subsequent test-only boundary checks from runtime code.
Log `/var/tmp/transit-count-descriptor-copy-comparison.log`. The broader run is
`/var/tmp/transit-count-descriptor-copy-full-comparison.log`.
Full integrated `just check` passes, exit 0, in
`/var/tmp/transit-count-descriptor-copy-integrated-check.log`.

The completed [full owned-descriptor comparison](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-descriptor-copy-full.json.gz)
retains **3888 correct process results**: four unchanged queries, nine shapes,
three discovery modes, two input-cache conditions and nine alternating pairs.
All **216 pipeline gates pass**; **214 of 216 compiler gates pass**. Warm
projection with decimal/explicit discovery reaches **1.1960**, and cold SUM
with wide/explicit discovery reaches **1.2297**, above the unchanged 1.15 limit.
The final cold SUM report adds the second failure after the earlier seven-report
checkpoint. Correctness completion is not a full timing pass. Every sample
inventory and median was audited; binary hashes and all recorded Fuze source
hashes match the frozen `d14887f2` prototype, whose runtime is published in
`db5a29bc`. The untracked archived comparison driver explains the dirty flag.

Committed-HEAD `just ci-clean --lane growth --work-root /var/tmp` at `40718b3f`
**fails** after eight passing tasks. `test::growing-service` finishes the query
write, seal, recover and publish phases, then its deliver subprocess exceeds the
unchanged **180-second** deadline. The task takes **487.29 s** and the incomplete
lane takes **685.38 s**; **17 of 26 tasks are unrun**. The
[failure record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-growth-delivery-2026-10-01.json)
retains exact metadata, task order and the log digest. The node-log tail shows
successful deliver/open-view/turn receipts; a proxy disconnect during cleanup
does not establish a cause. The clean checkout remains at
`/var/tmp/transit-ci-9vlbv3xj/src`; the fixture's temporary storage was removed by
its cleanup. Log `/var/tmp/transit-count-descriptor-copy-clean-growth.log`.
No deadline, residency or operation limit changes were made.

A [discovery-copy experiment](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-rejected-discovery-descriptor-copy.json.gz)
extends `Type.clone` to explicit/raw discovery and neutral JSON descriptor
decoding. Full `just check`, allocation-failure/ownership checks, 162 real file
CLI cases and 91 independent native/port logical-codec cases pass. The initial
and final probe builds are byte-identical after adding ownership tests. All
**594 paired results** and **33 pipeline gates** pass, but cold wide/explicit
SUM compilation reaches **1.3147** against the published descriptor-copy build:
**32 of 33 compiler gates pass**. Passing that case against the older pre-COUNT
control does not erase this failure. This variant is **not adopted**; its patch
is restored from the integration worktree. The archive retains both patches,
driver bytes and all six reports with independently audited sample inventories
and medians. A separate variant retaining the JSON parser arena is evaluated
independently. Logs `/var/tmp/transit-count-discovery-copy-comparison.log`,
`/var/tmp/transit-count-discovery-copy-sum-comparison.log`,
`/var/tmp/transit-count-discovery-copy-ownership-checks.log` and
`/var/tmp/transit-count-discovery-copy-integrated-check.log`.

The [direct-parser-arena variant](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-rejected-discovery-parser-arena.json.gz)
keeps the parsed JSON descriptor arena after definition, descriptor and encoded-byte
checks, alongside direct copies in explicit/raw discovery. Fuze package units,
including ownership after overwriting the JSON input and every allocation failure,
pass. All **594 paired results** and **33 pipeline gates** pass, but three compiler
gates fail: wide/explicit warm projection **1.2101** against the current copy,
wide/explicit cold projection **1.2371** against pre-COUNT, and wide/explicit cold
SUM **1.6610** against the current copy. This variant is also **rejected and
restored**. It does not establish an improvement by removing an allocation alone.
The archive keeps the exact patch, all six reports, drivers and audited medians.
Logs `/var/tmp/transit-count-discovery-arena-check-build.log`,
`/var/tmp/transit-count-discovery-arena-units.log` and
`/var/tmp/transit-count-discovery-arena-comparison.log`.

The `53945c67` implementation reuses descriptor validation while lowering a
compiler-owned immutable schema. `Type.clone` and binding metadata checks remain;
the private plan-shape check validates projection, names, aggregates and predicates.
Public typed-plan admission still validates both schema and shape. Boundary tests
reject duplicate fields, invalid decimal descriptors and changed binding identity;
an already compiled plan retains its owned descriptor after the source binding is
changed. Fuze package tests and all **162 real file CLI cases** pass. The frozen
probe rebuilt after adding these tests is byte-identical. Full integrated
`just check` passes in `/var/tmp/transit-count-plan-validation-integrated-check.log`.

The [compiler-validation comparison](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-plan-validation.json.gz)
retains **594 correct paired results**, all **33 compiler gates** and all
**33 pipeline gates** passing against pre-COUNT and the current descriptor-copy
control. Compiler ratios span **0.5834–1.1146** and pipeline ratios
**0.9971–1.0270**. The two failing combinations in the earlier complete matrix
pass these targeted comparisons. Every sample inventory and median is audited;
all recorded Fuze source hashes match prototype `605e46ed` and implementation
`53945c67`. The exact patch and comparison driver are retained. Native/FZP1
definitions, canonical plan bytes, fingerprints and bounds do not change.

The [completed full matrix](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-plan-validation-full.json.gz)
retains **3888 correct results** and all **216 pipeline gates passing**.
**213 of 216 compiler gates pass**. Remaining failures are warm narrow/explicit
projection **1.1592**, cold nested/explicit COUNT(_) **1.3123**, and cold
pipe/explicit COUNT(_) **1.1763**. Each sample inventory and median is audited;
all recorded source hashes match committed prototype `605e46ed`. Targeted
success does not establish a complete timing pass. The shared-host run overlaps
other qualification and the retained Station fixture shutdown below; it does not
establish a causal explanation for the timing differences. Log
`/var/tmp/transit-count-plan-validation-full-comparison.log`.

Clean core at `8b9d1d5b` passes **22/22 tasks in 1123.21 s**. The
[record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-core-descriptor-copy-2026-10-01.json)
retains the completed metadata, exact task inventory, source revision and log
digest. It includes the owned descriptor copy but precedes `53945c67` and cannot
qualify the later compiler optimization by inheritance. Current-source clean
growth and installed bindings remain separate. Log
`/var/tmp/transit-count-completed-matrix-clean-core.log`.

The retained Station launcher installation was still running after its earlier
Arrow-reply failure. A signed read at **13:01:20 UTC** observes `last-query` at
authority position 169. This establishes later completion, not its arrival time
or satisfaction of the original 60-second deadline. The owning launcher's
`down` operation stops it at **13:02:15 UTC**, with its WAL and logs preserved
and no reset. The [original failure record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-experience-station-2026-10-01.json)
retains this follow-up separately; the experience lane remains failed.

Current-runtime clean growth at `3f5cfdd8` also **fails** after eight passing
tasks, including the new file compiler and logical-source checks. Query write,
seal, recover and publish finish, then deliver exceeds the unchanged 180-second
subprocess deadline. The failed task takes **501.54 s**, the lane **730.01 s**,
and **17 of 26 tasks remain unrun**. The [separate record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/count-values-growth-validation-2026-10-01.json)
retains exact metadata and task order. This repeats the earlier failure stage;
its cause remains unestablished. Checkout `/var/tmp/transit-ci-r6_tbid3/src` and
log `/var/tmp/transit-count-plan-validation-clean-growth.log` are retained.

The [frozen compiler diagnostics](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-count-values-compiler-diagnostics.json.gz)
retain **108 correct process results** for the three failing full-matrix cases.
Each case first compares the current binary with itself, then with the frozen
pre-COUNT binary, using nine alternating pairs, CPU 1, explicit discovery and
the original input-cache conditions and 1.15 limit. Same-binary compiler ratios
are **0.9835/0.9875/0.9476** for warm narrow projection, cold nested COUNT(_) and
cold pipe COUNT(_), respectively. The corresponding pre-COUNT ratios are
**0.9628/1.0066/0.9666**; all six pipeline comparisons also pass. Sample identities,
medians, frozen binary hashes and prototype source hashes are independently
audited. No source or benchmark change separates these observations from the
earlier full matrix. The shared-host diagnostics do not reproduce its three
failures, establish their cause, erase them or provide a full timing pass. They
do not justify another runtime optimization without further evidence. Logs
`/var/tmp/transit-count-compiler-self-control.log` and
`/var/tmp/transit-count-compiler-diagnostic-comparison.log`.

The fixed-revision installed-bindings clean lane at `5d897f0d` completes with
**17/17 tasks passing in 9909.64 s**. The completed record (archived)
retains the exact source revision, completed metadata, ordered task inventory,
zero exit codes and log digest. It covers the installed SDK checks, the public
language interoperability ring, bounded models, SQL rewrite checks, independent
SQL fixtures and Python gRPC fault schedules. This source includes COUNT's
coordinated definition/SDK cutover but precedes the later file-compiler changes;
it is not a complete current-source suite pass. The isolated checkout is removed
by the successful clean runner after copying evidence to
`.cache/ci/clean/5d897f0dc733-transit-ci-s1517yp_`. Log
`/var/tmp/transit-count-column-clean-bindings.log`.

The `4b0c9dbc` integration reuses PR #62's existing `38e5a328` fragment-read
batching commit, preserving its author date. Native captured turns prefetch at
most eight fragment keys through the existing captured-view cache; read-only
adapters keep their point-read interface. Station package tests cover identical
bytes/manifests, fewer reader callbacks, missing/corrupt fragments and poisoned
proposals after unavailable/denied reads. The matching prototype `64024bdc`
passes those tests and `just test::query`; integrated `just check` also passes.

The frozen fragment-read comparison (archived)
uses the same instrumented proof, CPU 0, ext4 fixture storage and unchanged
180-second phase deadlines in candidate/baseline/baseline/candidate order. Each
run independently verifies all 41 rows, six segments and 21,296 Arrow bytes,
including exact retry across restart, cancellation and retained acknowledgement.
Candidate delivery takes **56.302/53.041 s** and baseline delivery takes
**57.067/53.360 s**. Both candidate samples use **1849 native read queries**
versus **2546** in both baseline samples, with **467 commands** unchanged;
146 batched reads are included in the candidate query total. This establishes
27.38% fewer native read queries for this fixture, not a latency improvement,
distribution or explanation of the earlier timeouts.

The initial candidate's **166.654 s** delivery and a separate standard-task
baseline's **56.858 s** delivery remain in the archive. A direct Python launch
of the frozen baseline fails before provisioning in `zig_probe_stack`: the
shell has an 8 MiB stack, while the standard Zig task is observed with
48,234,496 bytes. The comparison uses the standard build-runner path for both
variants without manually changing limits. An initial package invocation with
`--build-file` fails configuration before tests; the package-local invocation
passes. Earlier clean-growth and Station failures remain separate; these focused
passes do not complete either clean lane. Logs, executable hashes, runner bytes,
source identities and the comparison wrapper are retained in the archive.

## Direct Follow reload and credential recovery — 2026-10-24

`just test::reactive-views-lifecycle` passes its native-local browser schedule in
159.38 seconds. In addition to stream loss, independent shared-principal tabs,
lease closure, watch-generation reset and retirement, Chromium now reloads a
page and verifies that it starts paused with no private rows or snapshot basis.
Explicit Follow reacquires an authorized result; the other tab keeps its own
session. Rotating the viewer credential clears rows and basis, while Board's
separate viewer remains current. Replacing the gateway with the current key and
explicitly recovering/reopening controls restores the authorized result.

Attempt 8 expired a session during the earlier stream-loss step and supplies no
evidence for the new cases. Attempt 9 reached credential denial, then failed
because the replacement gateway's readiness probe omitted its required Host
header. Attempt 10 supplies that header and passes the complete schedule with
unchanged deadlines and assertions. These are real native-local TLS/browser
checks; reference-placement and final repository gates remain separate.

## Follow reads during control recovery — 2026-10-25

Reference attempt 14 again verified the original query and physical recovery,
then exceeded the 180-second refresh deadline. The new diagnostic read, issued
after that failed assertion, observed the selected finite query as complete while
the last refresh observation was admitted. This does not establish that execution
had completed before the deadline, or identify the only cause of the failed run.

Independent client regression cases do establish a read-progress defect:
`LiveView` blocked all result observation while a control was active or uncertain.
Both cases fail on the previous implementation with the earlier result still
displayed. Current status/result reads now progress with their own authority
checks. New invalidation and acknowledgment controls wait for the original frozen
control to settle. A verified immutable result is read once while acknowledgment
is deferred, and the visible status preserves control uncertainty.

Four new cases cover pending versus actively running controls, deferred exact
acknowledgment, and current denial while the original request remains frozen.
All 28 live-view/follow-recovery tests pass. The complete
`just transit-board::check` also passes contracts, types, formatting/lint and
consumer tests, including 101 Board tests. A subsequent status-wording assertion
checks both pending and uncertain messages; all 28 focused tests still pass.

`just test::reactive-views` passes the native browser schedule with the read-progress
change in 255.84 seconds. It retains ingress/clock contention injections, exact
query submission recovery, complete-result verification, finite refresh, pause
and current revocation between verification and disclosure. Single observations
are 16,956 ms for counter visibility and 41,416 ms for verified refresh; observed
Board/counter heaps are 9,747,044/3,745,728 bytes. These values establish no matched
performance comparison. The new client path still requires the separate reference
deployment run and final combined repository/clean-checkout qualification.

Reference attempt 15 includes the client fix and still exceeds the three-minute
refresh deadline. Its post-failure query read observes `admitted`, with continued
application input progress and capacity refusals. The failed run's counter and
physical-recovery observations are 20,915 ms and 58,156 ms. The client regression
fix therefore does not establish that the reference latency problem is resolved.

The next reference correctness schedule permits six minutes for each finite
query/result-denial observation and 25 minutes for the enclosing browser run.
Its fixture service publication lasts 30 minutes so it contains that schedule.
Eight-capture preparation retains its three-minute deadline; native and Compose
query waits retain theirs. Per-request deadlines, 30-second session leases,
native/direct cache sizes, current authorization, exact retry, full coverage,
result identity, physical recovery and denial assertions are unchanged.
Initial query/recovery and Follow preparation times are now observed separately.
This longer aggregate observation tests eventual completion under the same bounded
deployment, not compliance with the failed three-minute latency window. No pass
is established by changing the fixture budget.

## Direct Follow reference recovery and disclosure — 2026-10-25

`nix develop .#serving --command just test::reactive-views-placement reference`
passes with the browser/client and fixture source at `c305cf405`. The retained
log is `/var/tmp/transit-direct-follow-reference-16.log`. Browser qualification
takes 823.88 seconds; deployment, qualification and recovery report 949.60 seconds
in total. The enclosing command exits successfully after joined cleanup.

The real browser verifies the initial 20-row query after a lost submission reply,
navigation and explicit exact retry. Physical worker, gateway, node and store
replacement preserves the same query namespace, displayed values and result
identity over the retained local native and Table logs. Follow prepares all
eight finite captures, then a committed mutation produces a distinct verified
result with the same Table/schema binding and a later accepted data position.
A further mutation checks current denial between full-result verification and
the visible reread; protected rows are cleared. Pause, cookie/local-storage
absence, bounded session recovery and both browser heap bounds also pass.

Single-run observations are 25,652 ms for counter mutation visibility, 67,916 ms
for the initial query including exact submission recovery, 54,029 ms for physical
recovery, 160,025 ms for Follow preparation, and 205,614 ms for a verified refreshed
result. Observed Board/counter heaps are 11,436,668/4,259,492 bytes. These are raw
observations, not a distribution or matched performance comparison.

This run uses the documented six-minute aggregate query/result-denial wait,
25-minute browser budget and 30-minute fixture publication. The three-minute
preparation budget, per-request deadlines, 30-second session leases, native/direct
cache bounds and all recovery/authorization assertions remain unchanged. The
205,614 ms refresh exceeds the earlier three-minute window: this correctness pass
does not qualify that latency window or close broader performance obligations.
The earlier failed schedules remain recorded above. Latest combined repository
and committed-HEAD clean-checkout qualification remain open.

## Paged Table owner and standalone-profile retirement — 2026-10-26

The standalone `TableMemtable`, catalog `TableStorageEngine` and query
`TableSegmentScan` are removed with their public exports and profile-only tests.
They retained complete active row sets and manifests and had no installed
consumers. `TablePartition` remains the installed acceptance and retained-read
owner. The earlier helper results above remain historical evidence; they do not
qualify the current owner or imply installed pruning.

The shared current-v1 definition changes from `cd12a1e2…` to `797a232f…`
because the stored `TRDL` interpretation is removed. Native, ABI, browser and
fixture resources follow the owning generators. Earlier artifacts, including
those from the earlier paged owner, require their matching build; this cutover
supplies no converter or automatic reset. The generic WAL frame kinds and the
separately owned segment, deletion-vector, manifest, cache and OCC components
remain.

Executed through the pinned `nix develop` shell:

- In `packages/zig/transit-storage`, `zig build test
  -Dtest-filter="retired Table definition" --summary all` passes **2/2 tests**.
  Three disk schedules independently substitute the previous definition in the
  directory marker, partition metadata with a recomputed digest, or a copied
  frame whose payload checksums remain valid. Each refuses two reopen attempts;
  complete marker, metadata and frame bytes compare unchanged afterward.
- The focused owner command with filters `keyless Table identities`, `Table rows
  and exact receipts`, `Table acceptance has no fallible`, `Table recovery`,
  `uncertain storage append` and `durable Table pins` passes **9/9 tests**.
  The keyless case is carried from the removed helper onto real disk with a
  one-page index cache and one-frame WAL batches. Three equal-valued rows retain
  distinct identities. A pinned unflushed cut survives flush, deletion and disk
  reopen; the current view has two rows, the pin still has all three, and exact
  retry returns the original receipt without resurrecting the deletion. Releasing
  the pin prevents subsequent reads. The strengthened full-identity assertion
  separately passes **2/2 tests** with `-Dtest-filter="keyless Table identities"`.
- The broader `-Dtest-filter=Table` storage run passes **41/41 tests**, including
  acceptance/receipts, pinned reads, schema changes, segmented reads, ordered
  ranges, declaration recovery and the new keyless case. Its range/scan byte
  counts agree with the preceding controls. The subsequently added
  `-Dtest-filter="Table recovery cannot expose"` regression passes **2/2 tests**:
  a memory log with two valid acceptance records before an interior missing frame
  fails repeated recovery; reads, receipt observation, flush and mutation stay
  blocked, and the acknowledged frontier does not advance. This exercises the
  Table gate independently of disk-WAL validation.
- Documentation links, the verification catalog, diagnostic inventory and
  semantic mappings pass. The inventory records **579** production owners,
  **4,614** owner/error pairs, **693** qualified outcome surfaces and **4,795**
  error-return boundaries. This source inventory is separate from runtime proof.

`just test::local-catalog` and `just test::direct-table-service prepared` pass
with the new definition. The prepared service schedule covers metadata-only
binding, typed values, fresh snapshots, current denial and definition replacement.
Full repository checks and committed-HEAD clean qualification are pending.
These component results do not establish encoded
SQL execution, safe collection, provider support or an installed latency gain.

## Relational setup outcome recovery — 2026-10-26

`nix develop .#bindings --command just bindings::relational-node` passes the
[installed control](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-setup-recovery-2026-10-26/report.json).
It builds matching packages and checks Node sources before exercising native,
port and installed Node relational callers. The direct proxy corrupts the
accepted DDL reply for setup operation 1002; the fixture must inspect that same
saved reference and establish its committed outcome. It never recompiles the SQL
or allocates a new operation after uncertainty. Current denial and other semantic
failures still escape; unavailable inspection has a bounded observation window.

All three callers pass retained joins, current denial, node/host replacement,
ordered overflow and original retention checks, across 1,088 typed requests.
The earlier clean bindings-1 failure at `dd3687e01` is retained: Python completed
its task, and Node passed its client/Station/HTTP/gRPC schedules before relational
setup stopped on an unknown outcome. The first direct invocation of the focused
Zig target was stopped because it lacked installed package prerequisites; only
the owning just task is a pass. This does not complete the full SDK matrix.

## Explicit recovery of each query upload step — 2026-10-26

The clean browser run at `adad2b189` passes both Board tasks, then fails HTTP
when MinIO refuses cold puts with `XMinioStorageFull`. Ursula reaches its unchanged
8 MiB hot-data bound, and the worker retains `AuthorityOutcomeUnknown`. Five
inactive compiler caches are archived losslessly and verified before their
unpacked copies are removed. Source, proof records and original uncertain SQL
installations remain intact; no MinIO guard or runtime recovery rule changes.

The next clean run begins with 44,964,306,944 free bytes. Embedded Board passes
in 422.06 seconds; query-browser fails in 415.61 seconds. Its trace shows the
first synthetic dropped response was pre-dispatch HTTP 429. Explicit retry then
accepts that step, but a later upload step returns HTTP 503 with
`query.send_unknown` and `AuthorityTimeout`. Board retains that exact signed
request, requires another explicit recovery action and reports incomplete upload.
The test instead waits for automatic completion and exceeds its result deadline.

The corrected schedule drops two distinct successful upload replies, checks
identical saved request bytes and receipts on recovery, and uses the visible
explicit recovery action for each classified unknown step. It preserves real
throttling responses and fails on other submission errors. Both recoveries share
the existing 120-second window; the whole browser test remains bounded to
180 seconds. The complete focused task passes in 300.31 seconds, including
compilation, stale participation refresh, query verification, navigation, current
revocation and source retirement. Production runtime code is unchanged.

The [failure trace, HTTP timeline, source patch and focused result](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-browser-closeout-2026-10-26/report.json)
retain exact attribution to `adad2b189` plus patch SHA-256
`1efaf42711164d55369c187dfb48b555d48ddc23b40d963d2f9a6d489b2b23c1`.
Frontend checks and all 6,354 documentation links pass. Hosted growth is now
complete, but another full committed clean browser lane and the final acceptance
review still gate lifecycle closure.

## Declared finite query collations — 2026-10-26

`just test::direct-table-service collations` passes in ReleaseSafe through the
signed local disk-backed Table service. SQL CREATE TABLE declares ASCII_CI and
CP037 columns; independently expected counts distinguish their order/equality.
The proof compares same-pin range and identity scans, bound parameters, captured
source/plan and neutral-value round trips, current UPDATE/DELETE outcomes and
old retained snapshots. A substituted plan collation rejects. It exercises the
local owner; installed lifecycle/performance qualification is separate.

Focused Fuze checks pass 37 tests covering independent text masks across scalar,
vector and page evaluation, saved plan ownership/identity, unknown values, eager
error provenance and the counters used by oversized rows. Unsupported/mismatched
profiles, unmappable CP037 literals/values, truncated/foreign plans and duplicate
DDL clauses reject. The complete Fuze suite passes 374 tests and the complete query suite passes 142.
The browser query client passes 57 tests, strict types, formatting and lint;
native/host and browser contract checks pass. The diagnostic outcome proof passes
3,407 projections, including the collation error across caller/Board/Flight boundaries.
`just test::table-ddl-sql`
passes 280 independent grammar/compiler cases with 244 exact schema comparisons,
including all three COLLATE spellings, ADD COLUMN and invalid declaration controls.
The new collation tests are in
[`query_collation_test.zig`](../../../packages/zig/transit-fuze/src/query_collation_test.zig)
and [`direct_table_collations.zig`](../../../tests/query/tables/direct_table_collations.zig).

These checks do not establish text relational join/group/order support, general
SQL encoded pushdown, benchmark percentiles or complete milestone qualification.
The clean core lane at commit `09d24daa8ad037abe1359e31f68e6e5f9d700ef4`
passed `check-core`, properties, simulations, package builds and Zig SDK checks,
then failed `test::station` with `Station domain work did not complete` during
replacement recovery. That run is failed, not a clean qualification of later
payload or collation changes.


## Borrowed finite Table compute pages — 2026-10-26

Finite direct Table execution retains one decoded reader page while compute
columns borrow its variable, recursive and conflict payloads. It consumes the
page before replacing that owner. The focused Fuze run passes **47/47** tests,
including an 8 KiB value in a 4 KiB compute buffer with no payload-arena growth,
pointer identity, all five states and nested/conflict details. Independent output
rows survive source replacement and executor destruction. Exhaustive allocation
failures release pages and detached outputs. Deferred read errors preserve prior
SUM overflow, selected-prefix LIMIT and full-source verification; current
disclosure denial prevents further source acquisition.

The complete query unit suite passes **141/141**, including its existing
16,840-row relational growth case. The signed `projection` service proof passes
encoded filtering, sparse coverage, segment/WAL reads, owned results, prepared
`ASCII_CI` comparisons, ordered failures and post-compute/terminal revocation.
Diagnostic inventory, verification catalog and documentation links pass.

The [batch guide](../../../packages/zig/transit-fuze/docs/batches.md) specifies page
invalidation and separate source/compute/output budgets. This change removes one
compute payload copy; it does not change stored formats, export Arrow buffers or
establish a whole-query latency improvement. The earlier clean core lane and
ingestion matrix remain in progress at their recorded revisions.
