# 3. Executable data lifecycles and live storage/SQL cutover

[Roadmap](README.md) · [Tracker #110](https://github.com/spoke-sh/transit/issues/110) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

Complete the installed local system over the delivered `TransitLog`,
`TransitObjectStore`, paged `TablePartition` and bounded `.tseg` reader. Direct
Table acceptance and SQL reads already use that foundation. Remaining delivery
integrates automatic physical maintenance, compatible lazy schema projection,
native payload routes, recovery, observable storage state and local packaging,
then qualifies the complete public caller path and its costs.

Extend the [declarative data lifecycle](01-declarative-data-lifecycle.md) and
[four-tier storage hierarchy](02-storage-and-query-performance.md). The
[performance reference](../handbook/reference/performance.md) and
[storage internals](../handbook/internals/storage-runtime.md) document the
live execution profile and measured latency bounds.

The next [statement-result milestone](04-statement-results-and-consumption.md)
owns the shared command/result lifecycle, client readers and bounded console
presentation. Coordinate its batch ownership and disclosure contracts with this
cutover; existing safe bounded-read and performance gates remain here. Replication
and operational recovery precede later automatic placement and do not replace
this milestone's installed restart and accepted-operation recovery evidence.

## Implementation plan — 2026-10-27

**Plan status: approved for implementation on 2026-10-27.** The user approved
the reviewed plan, including decisions D1–D4, and authorized logical commits and
a completion PR. The milestone retains its In Progress status and historical
delivery; unchecked implementation and qualification gates remain required. Source review uses main at
`c2d665e5ec7e4095f70f5b0c0d92a17e8497d8f6`, after
[PR #187](https://github.com/spoke-sh/transit/pull/187) completes milestone 2 and
[PR #186](https://github.com/spoke-sh/transit/pull/186) completes the supporting
[development workflow](development-workflow.md). GitHub states below were read
on 2026-10-27. This review inspected source and recorded qualification; it did
not execute a new runtime qualification.

The checklist below is the implementation order. Dated assessments later
in this file preserve earlier diagnoses and acceptance requirements; they are
not a second current backlog. A checkbox is complete only with linked delivery
and the corresponding executed gate. Planning agreement alone completes none
of the implementation checks.

### Starting point: retain the foundation

| Area | What is delivered at the review source | What milestone 3 must add or establish |
| --- | --- | --- |
| Local ownership | [Local node](../../apps/transit-node/Local.zig) opens one exclusive native backend; [server](../../apps/transit-cli/server/Server.zig) selects `data/native` without Ursula/MinIO children | Complete automatic maintenance, payload publication/reclamation and owner replacement; preserve shutdown/join and directory exclusivity |
| Table acceptance | [LocalTableHost](../../apps/transit-node/LocalTableHost.zig), [service](../../apps/transit-node/LocalTableService.zig) and [direct catalog](../../packages/zig/transit-catalog/src/DirectCatalog.zig) compose direct CRUD/DDL, current policy and exact operation recovery | Preserve these operations while adding maintenance and mixed-definition reads; no second writer or actor Table staging |
| SQL reads | [DirectTableScan](../../packages/zig/transit-query/src/DirectTableScan.zig) and [DirectTableReader](../../packages/zig/transit-catalog/src/DirectTableReader.zig) already reach bounded WAL/segment reads, projection/filtering and retained key access | Qualify the installed mixed WAL/segment path during maintenance; measure repeated owner recovery, cache reuse and transport work |
| Physical maintenance | [TablePartition](../../packages/zig/transit-storage/src/TablePartition.zig) implements bounded flush, archive, checkpoint, expiry and compaction; [local collectors](../../packages/zig/transit-backend-local/docs/maintenance.md) cover native and direct graphs | Schedule these operations safely in the exclusive live owner and expose attributable progress. `Local.collect` currently returns false, and local runtime configuration rejects compaction |
| Schema changes | [Table evolution](../../packages/zig/transit-storage/docs/table-partitions.md#acceptance-and-observation) validates and rewrites existing rows into private replacement segments before one acceptance | Implement a precisely qualified lazy path for compatible edits; retain exact old interpretation and current authorization |
| Native payloads | [PayloadStore](../../packages/zig/transit-backend-local/docs/payloads.md) implements declaration-bound creation, verification and opted-in deletion | Connect authenticated installed publication/read/recovery and maintenance; `Local.reclaimPayload` currently reports unavailable |
| Named resources/computations | Milestone 1 delivers typed named KV/Document lifecycle, exact dependencies, explicit computation activation, result attribution and freshness | Requalify installed behavior through restart and new maintenance. This does not introduce SQL publication for every data kind or automatic computation scheduling |
| Packaging | The local bundle contains `transit`, node, query host, SQL gateway and Board; [configuration](../../apps/transit-cli/server/Config.zig) retains their paths/hashes | Resolve the single-binary target explicitly; absence of external storage services already holds and is a different criterion |
| Recovery and readiness | Durable refusal and original-request recovery exist; query-host activity still resets `idle_wait_ms` to zero | Resolve [#173](https://github.com/spoke-sh/transit/issues/173), keep-armed waiting and startup/shutdown recovery with measured installed evidence |

Use the [milestone 1 acceptance](01-declarative-data-lifecycle.md#final-lifecycle-acceptance-review--2026-10-26)
and [milestone 2 acceptance](02-storage-and-query-performance.md#final-local-foundation-acceptance--2026-10-27)
as prerequisite evidence with their original revisions. In particular, the
foundation's fixed-memory growth, disk/process-fault, codec, history and retained
graph checks should be extended at integration boundaries, not recreated in
parallel harnesses. An open component issue with an old checkbox is not evidence
that its implementation is absent.

### Accepted decisions and scope boundaries

**D1 — Accept the paged manifest as the local publication representation
(accepted scope clarification).** The live Table uses a WAL-accepted
`TablePartitionRecord.Root` and immutable paged indexes as its manifest. Deletes
change that accepted live-row mapping; retained roots preserve previous rows.
The [current storage contract](../../contracts/TRANSIT_STORAGE_V1.md#table-acceptance-records-and-indexes)
explicitly rejects an independently published latest-manifest authority.
Standalone `TableManifest`/`.tman` and `TDel` components exist, but the live owner
does not use them. Requiring those filenames would add another format integration
project to this milestone.

The accepted local gate qualifies actual `.tseg` content, accepted paged
manifest roots, deletion visibility and retained-history recovery. It replaces
the earlier requirement for standalone `.tdel`/manifest files, preserving those
semantic and recovery obligations. Do not create decorative files or claim
`.tdel` integration. Future standalone segment membership/deletion coverage must
reference the same WAL acceptance and qualify exact snapshot retention, pruning,
compaction, GC and crashes through its owning milestone and current-v1 cutover.
No independent CAS may become a second visibility decision.

**D2 — Deliver one local executable without merging execution authorities.**
Keep the existing single-binary target in scope. The implementation is
one `transit` executable with internal node, SQL gateway, query-host and Board
roles, reusing their implementation modules and embedded assets. It may spawn
itself in separate processes. One executable does not mean one thread, one
process, one acceptance log or an actor-based data plane. Standalone role
executables may remain supported deployment entry points over the same modules;
the default local profile must no longer need them beside `transit`. Application
workers and external connectors remain separately installed applications.
Release signing, platform expansion and distribution channels remain in
[milestone 28](28-releases.md).

**D3 — Limit lazy evolution to edits with a proved projection.** Include
non-key column rename, nullable/constant-default ADD COLUMN and supported
non-key DROP COLUMN where dependencies and validation permit. Bind projections
to stable column identity and exact original definitions, including unflushed
WAL rows. Freeze the ADD-time default for old rows; later default changes must
not reinterpret them. Preserve `missing`, SQL NULL, errors and conflicts rather
than converting every absent historical value to NULL. Key, type, codec,
collation and constraint changes that require validation/reindexing retain an
explicit bounded existing path or explicit refusal. General online rewrites,
new constraints and arbitrary historical SQL remain in milestones
[7](07-standards-and-catalogs.md) and [8](08-indexing-and-access-paths.md).

**D4 — Compose maintenance; do not widen logical retention.** Automatic flush,
archive/checkpoint, bounded compaction and safe collection operate within
existing acceptance, quota, pin and epoch rules. History remains unlimited by
default. Physical WAL trimming needs recoverable archive/checkpoint coverage;
logical expiry needs explicit policy; deletion additionally needs a complete
retained graph and read-lifetime fences. These are separate transitions.
Automatic computation activation stays in
[milestone 9](09-sql-and-dataflows.md), distributed providers/writers in
[15](15-storage-providers-and-concurrency.md), and general cache/index/group-commit
optimization in [10](10-data-structures-and-performance.md).

The existing [SQL session contract](../../contracts/SQL_SESSION_V1.md) remains
the result boundary. Fix storage/read ownership, current-policy disclosure and
bounded consumption needed for this cutover, but leave the new shared
`StatementResult`/result reader and console presentation to milestone 4.
Multi-object transactions, global snapshot atomicity, new SDK families and a
Board redesign are outside this plan.

### Delivery sequence and reviewable changes

Each row is a logical PR-sized outcome, with smaller scoped commits inside it.
Split a row further if its contract/implementation review becomes too large;
keep its exit gate intact. No elapsed-time estimate is asserted before P0's
baseline. Lazy interpretation, maintenance scheduling
and packaging are substantive work, not final documentation chores.

| Slice | Reviewable outcome | Dependencies | Tracking owner |
| --- | --- | --- | --- |
| P0 | Frozen baseline, contract/ownership decisions and acceptance inventory | Review decisions D1–D4 | #110, #122, #123, #124, #76 |
| P1 | Installed owner recovery and native payload lifecycle | P0 | #173, #126, #122 |
| P2 | Automatic point flushing with bounded scheduling and basic inspection | P0; P1 recovery integration | #122, #116 |
| P3 | Compatible lazy schema projection over WAL and segments | P0/D1; P2 supplies mixed-state fixture | #122, #118, #128 |
| P4 | Automatic archive/checkpoint, compaction and safe collection | P1–P3 | #122, #116, #126, #127 |
| P5 | Measured live reader reuse, bounded access and event-driven waiting | P0 baseline; P2–P4 final regression inputs | #122, #128, #76 |
| P6 | Shared public storage inspection, configuration and Board projection | P2–P5 contracts | #122, #123 |
| P7 | Single executable local composition | P1 ownership; P6 configuration | #122 |
| P8 | Installed common-revision qualification, documentation and closure | P1–P7 | #110, #122, #123, #124, #76 |

Review progress at three concrete checkpoints: after P2, demonstrate installed
WAL-only acceptance, automatic flush and exact restart; after P4, repeat that
journey with mixed schemas and safe maintenance; after P7, run it from the single
executable. P8 establishes the complete final evidence rather than introducing
the first end-to-end test at the end of the milestone.

### Early integration PR and statement-result handoff

On 2026-10-27 the user prioritized merging the live Table integration so the
statement-result work can proceed concurrently. Deliver the already implemented
owner recovery/payload routes, automatic flushing, lazy schema projection and
single-executable packaging in an early PR. The user clarified that the ordinary
`transit server` and `transit console` workflow must make the new implementation
available for human testing, without special flags, executable configuration or
test commands. Move P7 ahead of P4–P6 for this integration gate. This does not
close milestone 3 or move its remaining obligations
to milestone 4. Direct SQL already reaches the real WAL/Table owner; the PR
qualifies that installed path with mixed physical schemas and automatic flushing.
Single-executable packaging is required before this early PR and the
statement-result handoff.

The handoff gate is:

- [ ] One copied `transit` executable starts with `transit server`, including
  default Board assets and internal runtime roles, without sibling Transit
  binaries or external storage services. `transit console` discovers it and
  executes Table DDL/DML and reads through the new default storage owner.
- [ ] The same ordinary commands preserve accepted rows through restart;
  `--no-ui`, opt-in database listeners and owned-role shutdown/recovery retain
  their existing behavior. Qualify the copied executable with unavailable PATH.
- [x] Installed direct SQL accepts and reads WAL-only rows while the application
  query worker is stopped; exact values survive abrupt owner restart.
- [x] Default flushing publishes verified segment coverage under the existing
  two-second maintenance deadline without changing logical mutation positions.
- [x] Compatible lazy ALTER preserves frozen defaults and stable column identity
  across mixed WAL/segment reads, restart and subsequent normalization.
- [x] Current definition, generated contracts and independent signed fixtures
  agree; missing or incompatible retained formats remain refusals.
- [x] Native collector composition retains the new schema dependencies and
  preserves current-policy, quota and paused-I/O/control-progress checks.
- [ ] Complete the early PR's committed-source checks and report remaining
  qualification explicitly in its description.

Milestone 4 owns `transit-sql` statement outcomes and batches,
`transit-sql-client` consumption/settlement, console presentation and affected SQL
adapters. It consumes exact Table definitions, retained source cuts and bounded
owned rows through the current direct APIs. Storage page size is not the result
batch size; collecting several pulls must preserve value ownership and current
authorization before disclosure. Keep the existing source/basis, acknowledgement,
incomplete-prefix and original-operation recovery rules while evolving that
contract. Coordinate any shared-definition replacement and regenerated resources
across the two branches; neither branch may retain a parallel legacy definition.

Remaining work here includes P0's baseline diagnosis, P1.4's broader resource
matrix, P4's automatic archive/checkpoint/compaction/collection, P5's measured
reader/recovery reuse and waiting, P6's storage views and P8's
full common-revision qualification. Unfinished bounded WAL cleanup is a follow-up
to the early PR. Coordinate P5 reader lifetime and P6 SQL inspection changes with
the statement-result owner instead of editing its result lifecycle independently.

#### P0 — Freeze the contracts and baseline

- [ ] P0.1 Record exact baseline binaries, definition, build profile and task
  inventory. Reproduce a small installed physical-disk lifecycle and performance
  control before changing runtime behavior. Keep uncertainty under its original
  saved identity; a failed baseline is diagnostic evidence, not a timing sample.
- [x] P0.2 Resolve D1–D4 in this owner and #110/#122. Reconcile milestone 2's
  acceptance with component issues and obsolete milestone-number references.
  Preserve historical evidence; distinguish remaining local obligations from
  explicitly transferred provider/transaction/index work.
- [x] P0.3 Specify the maintenance contract before wiring it: eligible work,
  Table discovery, fairness, trigger accounting, per-step and aggregate budgets,
  backpressure, retry/recovery, shutdown and public progress. Define current
  privileges for configuration, requested maintenance and read-only observation.
  Use existing storage/catalog policy owners, not an independent admin service.
- [x] P0.4 Define accurate observations: accepted physical position, logical
  change position, oldest live WAL dependency/flush coverage, pending rows/bytes,
  archive/recovery coverage, logical history floor, retained pins, collection
  phase and bounded failure information. Do not invent one contiguous
  "flushed LSN" if the layout contains gaps or non-row records. Directory-wide
  summaries must state whether observations are independent.
- [ ] P0.5 Map changed fields and formats to
  [current-v1 cutover](../handbook/reference/versioning.md), generated contracts,
  binding resources, signing fixtures and installed configurations. Every
  incompatible merged slice must rotate the shared definition and migrate its
  consumers together. Never default missing persisted fields or run mismatched
  binaries against retained installations. Use separate candidate installations;
  preserve older data with its matching build. This plan promises no automatic
  conversion of an incompatible installation.

**Gate:** one owner/proof matrix, a reproducible baseline and resolved format,
projection, packaging and maintenance contracts. Required paths have concrete
acceptance assertions before implementation; unavailable evidence is labelled.

The issue reconciliation closes foundation trackers #113–#115 against merged
PR #187 and its final local acceptance/evidence. #116 remains open with explicit
P2/P4/P5/P6/P8 installed-runtime work. Group commit, broader indexes and remote
providers retain the already assigned later milestones; this changes no scope.

**Frozen baseline (27 October 2026):** runtime source
`c2d665e5ec7e4095f70f5b0c0d92a17e8497d8f6`, `ReleaseSafe`, pinned Zig
`0.17.0-dev.2267+48abf1a34`, Linux x86_64, physical disk under `/var/tmp`.
The private `.cache/milestone3/baseline-identity.json` records executable,
driver and inventory hashes; `.cache/milestone3/baseline-mutation.json` records
the three-repeat, eight-row control and original failure. It completed sixteen
samples before an `update_same` submission returned `SqlOutcomeUnknown` after
30 seconds. The original installation is retained with its matching binaries.
This is an incomplete control, not a successful latency qualification, and
three repeats cannot support p95/p99 claims. P5 must diagnose and resolve the
original outcome before comparing the final candidate.

**Accepted maintenance contract to implement:**

- One local owner has one maintenance executor, sharing its physical WAL/object
  owner with request lanes. Lifecycle scans and physical work alternate; no
  worker or in-memory queue is allocated per durable Table. Discovery uses
  resumable pages over accepted catalog/partition directories. Each selected
  Table gets one bounded unit before enumeration advances, including when a
  hot writer keeps that Table eligible.
- Catalog publication takes the directory's exclusive lock. Table work takes
  its shared side and the same bounded Table lock stripe as public requests.
  Private staging releases native authority; acceptance reacquires current
  authorization, resource lifetime and storage-epoch fences. Owner replacement
  joins every task before closing storage. Scheduler cursors are hints; accepted
  roots, fixed targets and durable collection progress establish completion.
- Automatic flush moves only accepted WAL rows. Byte/row thresholds and maximum
  pending age select work; defaults are measured in P2. Work has one configured
  deadline and aggregate resident budget, including read caches, index staging
  and encoder buffers. Timeout or quota refusal leaves the accepted state and
  pending target intact. A failed class backs off and does not disable the
  lifecycle/control scan. A poisoned WAL requires owner replacement.
- Automatic work uses the configured maintenance principal's current authority.
  Explicit requests use the caller's existing object control privileges;
  observation uses current object inspection privileges. Configuration remains
  deployment policy. Neither a request nor configuration can grant retention,
  bypass a revoked grant or recreate a dropped object. Board only observes.
- A requested flush fixes its original accepted cut. Completion means no current
  row still depends on WAL row bytes strictly below that exclusive cut; overwritten/deleted
  rows cease to be current obligations. Historical readers retain independent
  dependencies. Later writes do not extend this target. Inspection publishes no
  maintenance record and never initiates work.
- Observations identify object/definition, observed physical acceptance frontier,
  logical change frontier, pending WAL row count/bytes and earliest current-row
  WAL dependency separately. Archive coverage, recovery checkpoint, logical
  history floor, retained pin summary and collection phase have distinct fields.
  Counts computed by a bounded page walk disclose partial coverage; they cannot
  masquerade as exact totals. Directory summaries are independent observations,
  not a cross-Table snapshot. Failures use bounded categories without payloads.
- New persisted interpretation/counter fields have no compatibility defaults.
  P2/P3/P6's changed records and wire/ABI surfaces require a shared-definition
  cutover, regenerated contracts/bindings/signatures, foreign/missing-definition
  rejection and fresh candidate installations. P1 owner reopen itself changes
  no persisted or wire interpretation. Keep the frozen baseline installation
  isolated from later incompatible candidate binaries.

#### P1 — Complete live ownership, reopen and payload recovery

Owners: [Local](../../apps/transit-node/Local.zig),
[native server](../../apps/transit-node/NativeServer.zig),
[local backend](../../packages/zig/transit-backend-local/README.md),
[server lifecycle](../../apps/transit-cli/server/Server.zig),
[launcher recovery](../../launchers/common.py).

- [x] P1.1 Document and enforce startup, exclusive directory ownership,
  readiness, cancellation/join and shutdown for native, catalog, Table and
  maintenance owners. Borrowed handles and request memory must not outlive their
  owners; no detached worker may use a closed WAL/object store.
- [x] P1.2 Implement bounded replacement after recovery-required refusal,
  covering temporary bootstrap and supervised runtime ownership. Stop admission,
  drain/join the old owner, reopen and validate its original directory, then
  resolve the exact saved request. Preserve principal/sequence/content, current
  authorization and fencing. Corruption/incompatibility must remain errors;
  exhausted recovery must report an unresolved outcome, not reinitialize.
- [x] P1.3 Compose accepted standalone payload declaration, authenticated byte
  publication/read, original verification after uncertainty, readiness and
  opted-in reclamation. Reuse the component's one-attempt marker and reserved
  namespace; do not repeat a PUT merely because its reply or bytes are missing.
  Define any missing service boundary before implementing its adapters.
- [ ] P1.4 Exercise named KV/Document provisioning, native input/state/output,
  captured blocks and effect records in the installed local profile after owner
  replacement. Replay dispatches no external effect. Keep the existing native
  one-KV-resource turn boundary and direct Table acceptance separate.

**Gate:** deterministic recovery-required injection completes the original
bootstrap request exactly once, the complete launcher schedule passes, payload
recovery/reclamation passes on disk, and stop/restart preserves each durable
owner without an external storage daemon. Close #173 only against those proofs.

The owner/reopen slice passes `test-local-owner-recovery`, `test-local-native`
and `test-local-native-service` in `ReleaseSafe`. The first injects lost sync
outcomes in the real node on physical disk, checks exact original receipts and
the three-reopen budget, then resolves the saved request after process restart.
The existing service schedule also passes signed reads/turns, malformed reply,
abrupt restart, local maintenance and current revocation on one CPU. P1's full
installed durable-owner gate remains open.

The payload slice adds authenticated local publication/verification/reads and
current-authorized opted-in deletion through native maintenance. The installed
node route passes the independent signed HTTP schedule and shared Zig client
read, including a discarded creation reply, restart, permanent attempt fence,
current revocation and an unlimited-retention neighbor. The seven backend
payload failure/integrity tests pass in `ReleaseSafe`; the protocol package
passes 60 tests in `Debug`, and all 18 reflected contract checks pass. The full
Station local launcher passes bootstrap, registry/call/Arrow exchange, worker
replacement, upgrades and persistent restart without changing deadlines. The
Document local recovery schedule passes with a one-page recovery cache.
Committed-source fast qualification passes all 39 selected checks at
`9cc0c99c6403`. One concurrent installed SQL run failed during authorization
bootstrap, before SQL submission; its original installation subsequently resumed
to readiness with identical binaries. Preserve that failure while diagnosing
contention and qualifying the installed lifecycle. These results do not close
P1.4 or establish the final common-revision acceptance gate.

A serial rerun of the installed direct SQL schedule passes direct CRUD, schema
and namespace lifecycle, stopped application workers, stale preparations,
dependency protection, abrupt owner restart and original outcomes after name
reuse. The earlier bootstrap failure remains recorded; a later successful run
does not establish its cause.

#### P2 — Make point flushing automatic and inspectable

Owners: local Table host/service, `TablePartition`, shared storage settings and
the installed server configuration.

- [x] P2.1 Discover eligible partitions through bounded persisted directories,
  including after restart and for Tables absent from a resident cache. Use a
  bounded worker set and fair resumable enumeration; do not allocate a queue or
  owner for every durable Table. Define lock order with catalog/policy changes.
- [x] P2.2 Implement configurable pending-byte/row and maximum-age triggers
  with explicit work/time/memory limits. Select numeric defaults from P0/P2
  measurements and publish them before enabling the default. WAL acceptance
  remains the durability boundary; ordinary INSERT does not wait for a flush.
- [x] P2.3 Reuse one bounded `TablePartition.flush` unit per selected turn of
  the maintenance scheduler. Publish its exact replacement through the Table
  WAL, preserve the logical change frontier and return capacity to foreground
  work between units. This scheduler is direct runtime work, not Station actors.
- [x] P2.4 Preserve pending work through crash or uncertain publication. Reopen
  when required and inspect accepted coverage before retrying; never infer
  completion from staged objects. Reserve control capacity and surface disk,
  quota or persistent failure without silently dropping accepted rows.
- [x] P2.5 Expose the minimal shared observations from P0 and a deterministic
  qualified flush trigger/configuration for tests. An inspection starts no
  maintenance. A requested flush has a target cut and inspectable completion;
  continuing writes cannot make its completion criterion move forever.

**Gate:** public SQL point writes are visible and survive restart before flush;
crossing the documented trigger produces verified segment-backed rows, which
also survive restart. A pre-flush pin reads its original rows throughout.
Exercise competing Tables, a hot writer, paused I/O and quotas without losing
control progress. Do not count private orphan segments as accepted data.

The bounded discovery/fixed-cut foundations are committed at `f354ade44`.
Focused tests pass fixed high-water enumeration, current-policy cursor fences,
late writes, old pins and lost flush replies. The live maintenance integration
is being qualified: a selected small Table flushed in 128 ms with 29,396,604
private peak bytes, but a real-node 256-row unit exceeded the five-second
maintenance deadline on physical disk. Keep that failure; thresholds alone do
not bound a turn's work. The candidate now separates eligibility thresholds
from a 32-row work limit. That candidate passes the real signed node proof on
physical disk: 258 WAL rows across three competing Tables become 10 independently
verified segments in 12.701 seconds including owner restart, with the installed
two-second per-turn deadline. This fixture uses a 50 ms scheduler interval; it
does not measure the installed server's one-second interval. Original WAL pins
and later segment-backed pins both survive another abrupt restart. The original
failed preparation separately recovers with identical binaries and exact saved
operation identities. The cause of that earlier preparation failure is unproved.
The installed SQL schedule also passes WAL-only point readback, abrupt restart
with flushing disabled, and automatic relocation after removing that explicit
override. The remaining WAL row has accepted segment coverage 0.822 seconds
after readiness; that observation is not a latency distribution. All existing
CRUD/DDL, namespace, stale-preparation, stopped-worker, RESTRICT, restart and
name-reuse checks pass in the same run. `transit server` now enables flushing;
bare nodes still require explicit configuration. The paused-private-I/O check
passes: a native storage-fence publication progresses while a Table's private
object sync is paused, the stale flush fails before acceptance, and a later fair
turn preserves and flushes the pending row. Original receipts and pins survive
restart. The competing-Table schedule also observes both small Tables completing
while the large Table still has pending rows; all 258 rows then have verified
segment coverage and survive restart (10.285 seconds including owner restart).
Shared storage observations and explicit fixed-cut units have passing focused
denial, partial-count, later-write, original-receipt and lost-reply checks.
An explicit flush executes one bounded unit and returns accepted coverage; it
does not acknowledge an asynchronous work request or create a second durable
queue. Callers retain the original target while automatic work may also fulfill it.

#### P3 — Project compatible schema changes lazily

Owners: [TableDeclaration](../../packages/zig/transit-storage/src/TableDeclaration.zig),
[TablePartitionRecord](../../packages/zig/transit-storage/src/TablePartitionRecord.zig),
[TablePartition](../../packages/zig/transit-storage/src/TablePartition.zig),
Fuze schema/evolution/readers, catalog and query adapters.

- [x] P3.1 Bind each physical row/segment interpretation to retained immutable
  definition and stable column identities. Specify bounded mapping lookup and
  retention across repeated edits; do not make read cost or resident state grow
  with an unbounded schema ancestry chain. Update the collector's dependencies.
- [x] P3.2 Qualify D3's exact edit matrix. Publish compatible definition changes
  without traversing/re-encoding all rows; preserve old cuts, old operation
  receipts, default-at-add semantics and rename/drop/recreate identity.
- [x] P3.3 Apply the same projection to WAL rows, segments, point/key-range reads,
  filtered scans and predicate writes. Evaluate filters and pruning under the
  requested logical definition and declared collation; historical physical
  metadata may prune only where the mapping proves it sound.
- [x] P3.4 Normalize selected groups during later bounded flush/compaction,
  preserving identities, logical change positions, history and old readers.
  New writes use the new definition. Missing/corrupt interpretation fails;
  guessing the current schema is forbidden.
- [x] P3.5 Check repeated ADD/default changes/rename/DROP, NULL versus missing,
  denied or revoked reads, old receipts after ALTER, and restart between DDL
  acceptance and physical maintenance. Compare results against an independent
  eager projection oracle.

**Gate:** supported compatible ALTER does no row-count-proportional rewrite on
the interactive path, measured through storage counters. Mixed old/new physical
data returns exact values under both retained and current interpretations.
Unsupported edits have explicit unchanged bounds or refusal, not partial DDL.

The pure `TableSchemaProjection` foundation maps exact physical/logical schemas
by stable column ID and requires explicit frozen initial values. Focused checks
cover original and intermediate physical rows, repeated default changes, dropped
column name reuse, NULL, incompatible layouts and validation of dropped values.
`TableEvolution.canProject` classifies the approved narrow edit matrix. The live
Table owner now uses a paged physical-schema directory with live-locator counts
and a separate active column-origin directory. The final locator removal drops
the current physical mapping; old roots keep their exact dependencies. This
avoids permanently accumulating unused schema mappings after normalization.
Focused storage checks pass metadata-only ALTER over 1,028 segment rows (three
object range reads, two staged index pages, no segment reads or row-index changes), mixed
WAL/segment reads, repeated defaults/rename/drop/name reuse, original receipts,
retained point/range/filtered reads, predicate writes with lost replies, disk
restart and bounded normalization. The collector follows both new directories.
An isolated collector walk preserves both interpretation dependencies without
receipt/history roots masking missing edges. Allocation-failure enumeration
preserves the original head before acceptance and performs no fallible visibility
allocation afterward. The mandatory root directories and revision-bearing row
locators use shared definition
`654ca199c506604af21873605129e34e18c1c349a42643ece06ed0da9dca7a93`;
native/binding/browser contracts and independent binary/signing fixtures are
regenerated together. All 39 fast and 18 contract checks pass. The installed SQL
schedule passes mixed WAL/segment schema edits, frozen defaults, name reuse,
restart before flushing, and exact projected values after default automatic
flushing (0.987 seconds after readiness, not a latency distribution). The same
run passes namespace lifecycle, stale preparation, RESTRICT and original
outcomes. The native collector composition also passes with 1,165 graph steps
and one confirmed unreachable allocation reclaimed; current-policy, quota,
paused-private-I/O/control progress and retained receipt/pin checks pass in the
same schedule. The selected physical flush uses 29,396,584 peak private bytes
and 127 ms. These are scoped observations, not the final common-revision
performance gate.

#### P4 — Schedule archival, checkpoints, compaction and collection

Owners: [GrowingMaintenance](../../apps/transit-node/GrowingMaintenance.zig),
local node composition, `TablePartition`,
[DirectStorageGraph](../../packages/zig/transit-catalog/src/DirectStorageGraph.zig)
and the backend's native/direct/payload maintenance owners.

- [ ] P4.1 Extend the live scheduler with independently bounded work classes
  for Table archive/recovery checkpoints/compaction and native/direct collection.
  Resume accepted progress after restart, including an unfinished collection;
  do not start a replacement pass over an incomplete durable one.
- [ ] P4.2 Separate archive coverage, recovery checkpoint, physical WAL trim,
  explicit logical expiry and object deletion. Bind each to its current
  authority and exact roots. Unlimited history must still be queryable after
  archival; snapshots may retain unflushed history after current rows move.
- [ ] P4.3 Integrate native epoch/time fences, current creator/reuse checks,
  complete graph marking and read-lifetime grace before deletion. Retain schema
  projection dependencies, catalog history, pending operations, original
  receipts, snapshots, captures and standalone payload ownership.
- [ ] P4.4 Bound CPU, bytes, allocations, outstanding I/O and total concurrent
  maintenance memory. Test aggregate budgets across many Tables and foreground
  readers, not just each component's allocator. Back off failures without a busy
  retry loop or permission bypass; retain enough control reserve to recover.
- [ ] P4.5 Exercise process death at accepted archive/checkpoint/flush/compaction
  and delete-progress boundaries, racing policy changes, pin release, new
  allocation/reuse, corrupt metadata, clock failure and injected I/O/quota errors.
  Compaction must emit no logical mutation or invalidate computation freshness.

**Gate:** the installed owner converges on eligible maintenance under a finite
workload, resumes it after process death and preserves every retained obligation.
Reclaim only objects proved unreachable; storage pressure never authorizes expiry.

Implementation sequencing: first separate bounded WAL cleanup from publishing a
trim floor, then schedule archive/checkpoint/trim and native/direct collection
with independent resumable work classes. Each Table class needs its own catalog
cursor; rotating a class on a single cursor can permanently skip work when Table
count aligns with the rotation. Keep fixed archive and compaction cuts and avoid
maintenance records endlessly triggering further maintenance. Collection resumes
incomplete durable progress before starting another pass, preserves the existing
six-minute reader grace, and publishes the required native time fence before
deletion. Cold owner replay/directory costs remain explicit P5 work; bounded
cleanup alone cannot establish the complete P4 resource gate.

#### P5 — Qualify and reduce the remaining live read and wait costs

Owners: local Table service/catalog, direct query readers, shared SQL service,
[query host](../../apps/transit-query-host/main.zig) and readiness supervisor.

- [ ] P5.1 Attribute end-to-end work before optimizing. The current service
  constructs request-owned catalogs; `DirectCatalog.open` initializes and
  recovers a Table for each open. Measure replay, immutable directory/footer
  reads, cache lifetime, credential exchanges, serialization and result delivery
  separately from WAL sync and application coordination.
- [ ] P5.2 Reuse verified immutable data and validated owner/recovery state where
  measurements justify it, under a bounded resident owner/cache pool. Bind every
  entry to its exact root/definition/epoch and invalidate on uncertainty or
  replacement. Eviction closes only volatile state; it cannot release a durable
  pin or lose pending work. Current permission checks remain per disclosure.
- [ ] P5.3 Qualify live point/range/projected/filter/relational reads across WAL,
  flushed and compacted data with small caches and spill limits. Preserve
  skipped-row coverage, original error positions, empty pages, LIMIT, owned
  buffers, cancellation, incomplete prefixes and post-buffer revocation.
  Measure the existing eight-row direct page bound before proposing a change;
  widening a constant alone is not an access-path improvement.
- [ ] P5.4 Complete or explicitly resolve keep-armed query-host waiting. Keep
  immediate work responsive while avoiding the unconditional empty poll after
  progress. Measure idle requests/CPU and first-work latency; prove disconnect,
  cancellation, wakeup races and shutdown. Preserve gateway wakeups and the
  applicable native cache visibility improvements already delivered.
- [ ] P5.5 Establish matched live correctness/performance controls for point and
  bulk mutations, key/range/full scans, metadata, compatible ALTER and recovery
  with maintenance active. Attribute remaining Station coordination separately;
  do not optimize retired actor Table staging or start a general query-engine
  rewrite here.

**Gate:** independently verified installed results, bounded memory at retained
sizes above caches, and measured reduction in the selected live amplification
and latency costs. Report regressions and uncertain samples. A component cache
benchmark or shorter polling interval alone cannot pass this gate.

#### P6 — Publish one authorized storage view and configuration surface

Owners: shared protocol/catalog/client operations, server settings, CLI/SQL
inspection adapters, Board API and its existing inspection UI.

- [ ] P6.1 Complete the shared inspection from P2: selected backend, resolved
  data root for authorized operators, exact Table/definition/cut, flush backlog,
  archive/checkpoint/retention coverage, maintenance state/failure and measured
  quota use. Distinguish live observations, durable facts and unavailable data;
  use paginated inspection instead of traversing the whole installation.
- [ ] P6.2 Define privilege-filtered disclosure of paths, aggregate statistics
  and object details. Current read/inspection authority applies to repeated,
  empty and terminal responses. Exclude credentials, payloads and unbounded
  object-key/error dumps from telemetry.
- [ ] P6.3 Route CLI/SQL and Board views through those same operations. Any new
  SQL inspection syntax must be specified/generated with its grammar and
  capability owner before exposure. Board inspection remains read-only and
  receives no raw storage handles or hidden flush/GC mutation endpoint.
- [ ] P6.4 Register settings with the existing configuration owner, validation,
  retained generation and restart/dynamic-setting rules. Publish defaults,
  units, limits and failure behavior in the public storage/configuration guides.
  Demonstrate why an accepted point write may have no newly flushed segment.

**Gate:** a user can answer where data is stored, what is accepted versus flushed,
why maintenance is pending and what retains history, using public authorized
interfaces. Inspection itself changes none of those states.

#### P7 — Deliver the single executable local profile

Owners: [runtime build](../../build/runtime.zig), app entry modules, CLI
process supervision/configuration and source-bundle fixtures.

- [ ] P7.1 Factor reusable role entry points into explicit build modules with
  direct dependencies. Compose them in `transit`; do not copy implementations,
  embed/extract child executable blobs or introduce another storage owner.
- [ ] P7.2 Self-spawn the selected internal roles with existing process
  isolation, signals, readiness and bounded shutdown. Retain the one exclusive
  WAL owner. SQL and query workers use public direct operations, even when the
  executable bytes are shared.
- [ ] P7.3 Bind installation/configuration identity to role plus executable
  definition/hash. Migrate incompatible bootstrap/configuration artifacts using
  the current-v1 policy; never silently reuse an incompatible installation.
  Keep explicit standalone deployment roles as the same implementation, not a
  fallback decoder or legacy data path.
- [ ] P7.4 Run the default profile and `--no-ui` with only `transit` installed
  in an isolated directory and without ambient Transit/Ursula/MinIO executables.
  Prove console, Board, opt-in PostgreSQL/MySQL, role death/restart and orderly
  shutdown. Downstream application binaries remain explicit external inputs.

**Gate:** one copied executable starts and restarts the qualified local system,
including embedded Board assets when enabled, without sibling runtime artifacts
or external storage daemons. Its accepted history and authorization behavior
match the qualified standalone-role composition.

#### P8 — Qualify, document and close the milestone

- [ ] P8.1 Complete the acceptance matrix below against a frozen candidate and
  matching definition. Establish real artifact provenance, not filename counts:
  `.tseg` is an object-key suffix, and the local object store retains that suffix
  on hashed physical content filenames. The fixture resolves accepted references and verifies
  format, digest and independent row values without granting applications raw
  provider access.
- [ ] P8.2 Run affected formal/negative controls, component faults, installed
  callers, SDK/ABI compatibility and browser regressions. Run `just check all`
  and committed-source clean qualification; retain exact task/source identities
  and failed, skipped or incomplete outcomes. Finish the ordinary full inventory
  on the final runtime source, with the browser inventory separately accounted.
- [ ] P8.3 Publish matched performance and resource measurements under #76/#124,
  including latency distributions, throughput, phase work, restart time and
  maintenance interference. Measure both elapsed CI time and aggregate runner
  cost with the existing runner; update cost budgets only with matching inventory
  and evidence, never merely to accept a slow regression.
- [ ] P8.4 Update public storage/query/schema/retention/configuration/launcher
  and component owners with every supported behavior and concrete limit. Keep
  scientific mechanisms in Internals and source-attributed results in
  qualification history. Keep `tests/README.md` an index; raw logs/reports remain
  generated artifacts unless selected immutable evidence is needed.
- [ ] P8.5 Reconcile issues and PR descriptions, close only satisfied local
  scopes, and record later obligations with their actual owners. Update this
  milestone and the roadmap index to Completed together only after acceptance.
  Clean only task-owned stale worktrees/branches; preserve user notes and
  unrelated work. Submit the final mergeable close-out PR with exact validation.

### Acceptance and measurement matrix

| Required outcome | Public/installed scenario | Evidence and principal failure schedules |
| --- | --- | --- |
| WAL-only durability | `transit console`, typed direct caller and installed PostgreSQL/MySQL write/read before any flush | Same accepted identity and independently known rows after lost reply and process restart; no required segment per INSERT |
| Accepted physical storage | Cross documented flush threshold, inspect progress, then query point/range/full scans | Verified referenced segment and paged manifest at the accepted cut; delete/update and old pin survive flush/restart. D1 records the accepted paged-manifest/deletion gate |
| Lazy compatible ALTER | Mix WAL-only and segment rows, acquire old pin, ADD/rename/DROP, write new rows, compact and restart | Independent old/current schema oracles, stable identities/defaults, no row-proportional compatible DDL rewrite, revoked metadata/row disclosure denied |
| Maintenance safety | Active readers/writers, unlimited history and explicitly opted-in expiry | Archive/checkpoint/trim crash boundaries, A→B→A history, snapshot-to-tail continuity, no logical mutation from compaction, complete retained graph before deletion |
| Native owners and payloads | Named KV/Document, process input/state/output, captured results, effect outcomes and standalone payload lifecycle | Disk restart, conflicts/tombstones, trim/pin retention, no redispatched effect, one-attempt payload verification and opted-in deletion |
| Original operation recovery | Bootstrap, DML/DDL, large saved intents and interrupted publication | Exact original request across owner replacement; no new SQL/identity, duplicate allocation or timeout-as-rejection; bounded recovery exhaustion stays explicit |
| Authorization and fencing | Revoke before publication and after buffering; retire/drop/recreate | Final current-policy fence, original object/definition bindings, old creators rejected, no reads from stale authorization cache |
| Bounded data plane | Many Tables/objects and datasets exceeding cache/resident limits, oversized direct requests through supported staged operations | Fixed operation/cache/spill/scheduler budgets, independent complete readback, disk/allocation/RSS accounting, control progress under pressure; no native actor frame dependence |
| Result safety | SQL, Flight and affected SDK consumers, including empty and multi-page results | Same retained basis, owned buffer lifetimes, current access after buffering, cancellation/early close, no successful completion from EOF or incomplete prefix |
| Installed packaging and observation | Single executable, default Board and headless profiles, public inspection | Resolved root/backend and pending/error state are accurate; denied inspection stays denied; no sibling runtime or external storage daemon required |
| Performance and waiting | Matched old/new ReleaseSafe installed SQL/typed/Flight paths, cold/warm and maintenance-active arms | Independent values/counts; WAL syncs, bytes, page/range reads, requests, CPU/RSS/spill, idle polling and bootstrap/restart latency; report regressions |

Use the current [test owners](../../tests/README.md),
[task inventory](../../tests/runner/suite.json) and
[performance runners](../../tests/performance/README.md). Extend the existing
installed Table/SQL/fault fixtures under `tests/interfaces/installation/`, direct
storage schedules under `tests/storage/`, semantic oracles under `tests/query/`
and formal/simulation owners under `tests/verification/`. Register every new
scenario and dependency; package units stay beside the implementation. Do not
copy complete launchers or rerun an expensive scenario under several wrappers.

During iteration use `just check fast`, focused owner tests and affected clean
lanes (`just ci clean --lane NAME`). Existing relevant tasks include
`just test::local-storage-faults`, `just test::storage-io-faults`,
`just test::local-data-collection`, `just test::table-compaction`,
`just test::table-projection`, `just test::table-filtering`,
`just test::server-direct-tables`, `just test::server-direct-faults`,
`just test::server-sql-lifetimes`, `just test::server-sql-local` and
`just test::sql-gateway`. These are starting owners, not claims that their
current assertions cover all proposed behavior. Formal checking uses the
existing authority/WAL models and relevant negative controls; add correspondence
schedules for new transitions rather than asserting a model proves all Zig I/O.

P0 freezes baseline budgets; P5/P8 must show improvement on selected bottlenecks
without worsening correctness or hiding aggregate work. Use equal dataset,
operation/retention policy, durability, cache budget, hardware, client versions
and build profile. Use enough recorded observations for stated percentiles;
retain raw distributions and failures. Separate cold startup, warm execution,
accepted work, result delivery and asynchronous maintenance. A 20–30 minute full
CI run remains a development-workflow target, not a new prerequisite or achieved
claim. Conversely, the existing cutover's matched improvement and bounded-read
gates may not be deferred to milestone 10. Disk process-kill checks do not prove
device power-loss survival; unavailable distributed deployment tests remain
outside the local claim and with milestone 15.

### Tracking issues and closure policy

Use P1–P7's outcome titles for focused child issues under #122 where its
existing checklist is too broad. Reconcile tracker scope against delivered
evidence as P0 proceeds; keep this file as the execution checklist rather than
creating another parallel milestone plan.

| Issue(s), current state | Planned disposition |
| --- | --- |
| [#110](https://github.com/spoke-sh/transit/issues/110), [#122](https://github.com/spoke-sh/transit/issues/122) — open | Primary closure targets after P8. Reconcile delivered direct CRUD/read wiring now; retain every installed maintenance, packaging, recovery and performance gate. Correct transferred provider references to milestone 15 |
| [#173](https://github.com/spoke-sh/transit/issues/173) — open | Close in P1 after deterministic reopen/original-request and full launcher evidence |
| [#126](https://github.com/spoke-sh/transit/issues/126) — open | Complete installed native/payload obligations in P1/P4/P8. Reconcile milestone 2's delivered foundation. Close only after explicitly accounting for its still-broader provider obligation under milestone 15; otherwise keep that scope open |
| [#113](https://github.com/spoke-sh/transit/issues/113), [#114](https://github.com/spoke-sh/transit/issues/114), [#115](https://github.com/spoke-sh/transit/issues/115), [#116](https://github.com/spoke-sh/transit/issues/116) — open | Reconcile each with milestone 2's completed local evidence in P0. Do not reimplement it because the issue is stale. Close satisfied scopes; retain any actual installed or provider remainder with an explicit owner |
| [#118](https://github.com/spoke-sh/transit/issues/118), [#125](https://github.com/spoke-sh/transit/issues/125), [#127](https://github.com/spoke-sh/transit/issues/127), [#128](https://github.com/spoke-sh/transit/issues/128) — open | Consume the delivered local contracts, qualify changed projection/history/reader integration here, and retain broader historical/transaction/managed-computation/provider requirements with their numbered owners |
| [#123](https://github.com/spoke-sh/transit/issues/123), [#124](https://github.com/spoke-sh/transit/issues/124), [#76](https://github.com/spoke-sh/transit/issues/76) — open | Complete and link the milestone 3 documentation, installed evidence and selected matched controls. These cross-milestone trackers do not automatically close with #110 |
| [#117](https://github.com/spoke-sh/transit/issues/117), [#121](https://github.com/spoke-sh/transit/issues/121) — open | Retain distributed provider/concurrent-writer qualification with milestone 15; local success does not check off these profiles |
| [#108](https://github.com/spoke-sh/transit/issues/108), [#109](https://github.com/spoke-sh/transit/issues/109), [#111](https://github.com/spoke-sh/transit/issues/111), [#112](https://github.com/spoke-sh/transit/issues/112), [#119](https://github.com/spoke-sh/transit/issues/119), [#120](https://github.com/spoke-sh/transit/issues/120), [#171](https://github.com/spoke-sh/transit/issues/171) — closed | Preserve delivered lifecycle/foundation/cutover/logging evidence. Exercise affected regressions; reopen only for an identified unmet original criterion, not to reuse their numbers for new scope |

Milestone completion means an independently checked installed local lifecycle,
including automatic maintenance and exact recovery, with understandable public
observations and measured costs. It does not mean every future provider,
application actor workload or database optimization has been completed.

### Principal risks and containment

| Risk | Required containment |
| --- | --- |
| Projection changes stored interpretation and reachability | Resolve exact definition/default binding before changing readers; migrate the definition and retention graph together; keep independent eager/retained-cut controls |
| Maintenance contends with foreground authority or exposes a stale root | Specify lock order and bounded work; preserve final policy/epoch fences; measure control latency with paused I/O and active collection |
| Reuse hides stale recovery or permissions | Cache immutable content and exact validated roots, never permission; invalidate on uncertain I/O/reopen and qualify changed roots/revocation after buffering |
| Single executable changes installation/process identity | Reuse role implementations, retain process isolation, bind role/definition/hash and test isolated startup plus role replacement |
| Broad qualification becomes another open-ended project | Add one owning scenario per invariant, reuse matching artifacts, run focused checks while iterating and freeze a final matrix; separate later provider and general performance scope explicitly |

## Reopened assessment — 2026-10-22

Source review of local snapshot `a0a8a3ed`
found that [PR #107](https://github.com/spoke-sh/transit/pull/107) and subsequent
work delivered page/block caching, cross-lane sharing, gateway wakeups, batched
reads, shorter DDL/DML turn paths and reduced polling/bootstrap delays. Preserve
those improvements and their scoped regression evidence. They improve the
existing Ursula/actor path; a gateway speedup does not prove storage cutover.

`transit server` still launches MinIO/Ursula. Runtime construction does not attach
`TableBehavior.storage_engine` or `TableScan.segment_scan`, so live Table writes
and reads do not produce/use the new native segment store. The optional write
hook is unsafe to enable as-is: it mirrors selected inline operations before
native acceptance, uses hardcoded lease/time values, ignores storage errors and
borrows schema memory beyond its command lifetime. Complete UPDATE/DELETE/schema
evolution and large-batch integration are missing. The planned keep-armed query
host long poll is also unfinished.

| Remaining work | Tracking issue |
| --- | --- |
| Shared direct operation and durable acceptance protocol | [#111](https://github.com/spoke-sh/transit/issues/111) |
| Safe current-v1 cutover and incompatible-artifact rejection | [#112](https://github.com/spoke-sh/transit/issues/112) |
| Native control/process/KV/Document and payload persistence | [#126](https://github.com/spoke-sh/transit/issues/126) |
| Named KV/Document provisioning and computation lifecycle integration | [#119](https://github.com/spoke-sh/transit/issues/119), [#120](https://github.com/spoke-sh/transit/issues/120) |
| Actual executable ownership, write/read wiring, local default and long polling | [#122](https://github.com/spoke-sh/transit/issues/122) |
| Accurate runtime documentation and proof attribution | [#123](https://github.com/spoke-sh/transit/issues/123) |
| Installed SQL, real artifacts, restart/fault and matched performance qualification | [#124](https://github.com/spoke-sh/transit/issues/124), [#76](https://github.com/spoke-sh/transit/issues/76) |

Consume the safety/correctness prerequisites in
[storage tracker #109](https://github.com/spoke-sh/transit/issues/109) before
attaching the engine. Prove the native local path before extending deployment
qualification. The authorized transcript review replaces the initial
selected-operation mirroring plan with the single-authority path in #111/#122
and complete native persistence in #126. The earlier cache/wakeup outcomes and
recorded bottleneck diagnosis remain evidence to preserve; they are not an
instruction to keep bulk data in the superseded actor/page path.

## Installed lifecycle integration

This section records the 2026-10-26 lifecycle checkpoint. The implementation plan
above incorporates the subsequent milestone 2 foundation acceptance.

The merged lifecycle work supplies direct Table, named KV/Document and explicit
computation owners, migrated callers and a coordinated current-v1 cutover. The
[final lifecycle acceptance review](01-declarative-data-lifecycle.md#final-lifecycle-acceptance-review--2026-10-26)
links delivered caller/recovery outcomes, exact sources and the separate open
logging, launcher and browser checks. Preserve those lifecycle guarantees through
subsequent integration. This milestone remains In Progress: the remaining
storage/maintenance integration, packaging and matched performance/installed gates
below are not completed by that lifecycle review. [#173](https://github.com/spoke-sh/transit/issues/173)
owns temporary launcher bootstrap recovery when the native WAL owner requires
reopening; exact saved-request recovery must preserve accepted identity and
exclusive ownership. The lifecycle review establishes no new qualification of
the storage changes and current-v1 definition subsequently merged in PR #172.

The sequencing review transfers executable lifecycle delivery from milestone 1
to this installed integration owner. Preserve #108's original acceptance gates:

- Complete the direct Table slice from #111: validate/preview, CREATE/ALTER/DROP,
  point and bounded batch mutations, inspect and exact recovery. Retire redundant
  actor staging without introducing a second writable authority.
- Complete #119's named KV/Document provisioning and initialization through
  existing service owners. Expose interpretation, partial/failed initialization,
  bounded recovery, cleanup, rename, retirement and same-name replacement. A
  catalog record alone cannot establish usability or cross-owner atomicity.
- Complete #120's named computation dependencies and inspection: exact input
  identities, requested lifetime, actual result evidence and data-source
  freshness. SQL/SDK and Board projections reuse qualified operations; reading
  or explaining a declaration activates no work. Automatic scheduling stays
  with [managed computations](09-sql-and-dataflows.md).

Original lifecycle acceptance, retained from milestone 1:

- An application can create a Table, inspect its definition, write/query rows,
  alter the schema and recover the original accepted change after losing a reply
  without routing bulk row data through multi-turn actor mailbox loops.
- Named KV and Document objects expose explicit interpretation, initialization
  state, current rights and lifecycle outcomes through the qualified typed path.
- Repeating an inspection or loading a definition starts no work. Applying a
  competing change rejects the stale expectation; recreating a name never
  retargets an earlier operation or dependent definition.
- Independent caller fixtures agree on definitions, outcomes and permission
  failures. Test revocation, interrupted provisioning/publication, missing
  dependencies and object/dependency counts beyond resident caches.
- Snapshot/transaction fixtures distinguish consistent from independent cuts,
  include accepted unflushed data, and establish the selected isolation profile
  under concurrent data/schema changes without promising unsupported atomicity.
- The handbook states each object's executable lifecycle and demonstrates how
  to distinguish defined, published, pending, complete and unavailable evidence.
  These are review questions; the implementation must define exact status types.

Distributed-provider and concurrent-writer integration transfers explicitly to
[milestone 15](15-storage-providers-and-concurrency.md), retaining #117/#121 and
their #124 proof gates. This milestone remains In Progress. #108's delivered
lifecycle acceptance is recorded separately; #110 retains the remaining installed
storage, maintenance and performance obligations. Neither the split nor the
lifecycle acceptance completes those broader gates.

## Recorded diagnosis of live runtime latency

Following the initial standalone `transit-storage` and `transit-fuze` `.tseg`
libraries, profiling the live server and SQL executables revealed four runtime
bottlenecks keeping interactive SQL and server workflows slow:

1. **Write-blind page cache, missing block cache and per-lane isolation in `transit-node`:**
   `PackedPageStore.stage` and `PackedPageStore.finish` wrote B-tree pages and
   immutable blocks (`TBK1`) to Ursula without populating the local verified
   cache (`remember`), causing every newly written root, index node, intent
   upload, saved step and table block to miss on the very next turn or read.
   In addition, `transit server` configured `resident_pages = 8` across 10
   isolated `Lane` instances in `Native.zig`, leaving sibling lanes with cold
   caches and stale journal heads after every mutation.
2. **Unconditional sleep loops and 1,000 ms idle backoff in `transit-sql-gateway`:**
   `runAccount` backed off its polling interval up to `1,000 ms` with no wakeup
   signal when a SQL session submitted work, and slept `5 ms` after every single
   `AccountRuntime.tick()` even when `progressed == true`. Because each
   `GenServer.step` turn takes 4 sub-steps (`prepareView` -> `open_view` ->
   `prepareCommit` -> `commit_turn`) and a SQL write executes ~9 turns across
   admission and coordination, every SQL statement incurred `200 ms`–`1,250 ms`
   of pure sleep.
3. **Forced multi-turn continuation for small DML statements and unwired `.tseg` table storage:**
   Unlike `TableWrite.stepWithReserve` (which completes single-row `INSERT`s in
   one turn via `fitsSingleTurn`), `TableStatement.step` unconditionally returned
   `.state = .building` on the first turn, forcing every multi-row `INSERT`,
   `UPDATE` and `DELETE` through a multi-turn `building` -> `courier` ->
   continuation cycle. Meanwhile, `TablePages`, `TableData`, `TableScan` and
   `transit-catalog` were not yet wired to `.tseg` segment blocks, declared
   column `Collation` comparisons or `transit-storage` (`TableMemtable`,
   `LocalSegmentStore`, `LocalWal`, `TableManifest`).
4. **Worker, courier and SQL supervisor polling delays in `transit server`:**
   `source`, `requester` and `courier` used `interval_ms = 100`, `transit-query-host`
   reset `idle_wait_ms = 0` after every committed step (burning an extra HTTP
   round-trip before arming `x-transit-wait`), and `Sql.tick()` throttled
   readiness checks to `1,000 ms` even during initial bootstrap (`.initializing`
   and `.starting`).

## Delivery sequence

This is the original delivery sequence retained for acceptance traceability.
Use P0–P8 above for the current implementation order; D1 records the approved
paged-manifest clarification of the original artifact gate.

1. **Resolve ownership and compose the native local profile.** Consume the
   catalog/snapshot, commit, native-owner and changefeed contracts in
   [#125](https://github.com/spoke-sh/transit/issues/125), #111, #126 and
   [#127](https://github.com/spoke-sh/transit/issues/127). Assign startup,
   recovery, shutdown and storage-handle ownership across node, SQL/query services
   and CLI. Deliver no Ursula/MinIO dependency for control or application state;
   explicitly resolve how the single-binary packaging target hosts those owners.
2. **Cut public data operations and reads over to one authority.** Route complete
   CREATE/ALTER/DROP, INSERT/UPDATE/DELETE and bounded large-batch operations
   through the accepted direct path. Integrate WAL/memtable writes and bulk
   segment publication, exact schema/source bindings, current access and the
   bounded reader from [#128](https://github.com/spoke-sh/transit/issues/128).
   Evaluate compatible `ALTER TABLE` schema evolutions (`ADD COLUMN`,
   `DROP COLUMN`, nullable/default projection) lazily on read by projecting each
   immutable `.tseg` segment's recorded `DefinitionId` and 5-state `missing` cells
   into the requested table definition, avoiding synchronous full-table segment
   rewrites on the interactive DDL path while deferring physical rewrites to
   background compaction or the phased online rewrite contract in
   [historical catalogs](07-standards-and-catalogs.md) and
   [online maintenance](08-indexing-and-access-paths.md).
   Remove pre-commit mirrors, dummy leases/time, swallowed errors and borrowed
   command memory. Retire superseded Table staging/storage consumers through
   #112 rather than shipping dual writable authorities or silent fallbacks.
3. **Run maintenance and expose observed state.** Compose flush thresholds/timers,
   checkpointing, compaction, archival and GC from
   [#116](https://github.com/spoke-sh/transit/issues/116), with bounded work,
   reserved control capacity, backpressure and restart recovery. Public read
   operations report backend/root, committed/flushed positions, pending bytes,
   maintenance failures and retention floors. Board consumes those authorized
   observations, never raw provider state or hidden administrative mutations.
4. **Prove the first installed local checkpoint.** Through real SQL and typed
   callers, establish Table CRUD/schema evolution, named KV/Document persistence
   and native input/state/output/effect evidence. Acknowledge and read writes
   before flushing; restart and recover them from WAL. Then trigger a documented
   flush condition, observe segments/manifests and verify the same accepted
   outcomes after restart. No external storage daemon may remain necessary for
   a less-visible native owner. Later provider/concurrent-writer promises remain
   explicit milestone 15 obligations; this checkpoint does not complete them.
5. **Complete named resources and computation lifecycles.** Qualify #119/#120
   through the installed paths above, including interrupted provisioning, exact
   accepted-result binding, data-source freshness, dependencies and current
   rights. Deliver the complete local lifecycle before later managed scheduling,
   transaction sessions or provider expansion relies on it.
6. **Preserve latency improvements and qualify the final cutover.** Retain
   validated cache visibility/sharing, batched reads, gateway wakeups and
   shorter readiness paths where their owners remain applicable. Complete or
   explicitly resolve keep-armed long polling; measure idle CPU, provider
   attempts and bootstrap latency. Run the affected safety/recovery proofs,
   `just test::sql-gateway`, `just test::server-sql-local`, `just check all` and the
   committed-source clean check, recording matched controls through #76/#124.

## Completion evidence

Record installed local baselines for durable data operations and native runtime
work, separating admission, WAL sync, execution/turn commit, recovery and result
delivery. Include candidate segments, range-read bytes and peak resident memory.
The later [performance scorecard](10-data-structures-and-performance.md) extends
these measurements; it cannot replace this cutover's existing matched controls
with library-only timings or defer a missing bounded access path.

Require passing end-to-end proofs across `transit-node`, `transit-sql-gateway`,
`transit-query-host`, `transit server` and `psql`/`mysql`/`transit console` callers,
preserving exact recovery, fencing, permission revocation and bounded resumable
direct ingestion for oversized statements while demonstrating measured
wall-clock improvement under matched controls.

The reopening adds an explicit review gate: show the installed public SQL path
creating native `.tseg` artifacts and accepted paged-manifest roots under the resolved storage root
after a documented flush condition, querying independently verified rows, and
recovering the exact accepted results after process restart and lost replies.
Qualify complete CRUD and schema changes,
bounded datasets beyond RAM/cache and the native local deployment profile. Large
statements must retain bounded recoverable progress through the resolved direct
operation contract; the earlier actor fallback cannot remain the bulk data path
and still satisfy the transferred lifecycle acceptance. Return this milestone to
`Completed` only after those executable acceptance paths, accurate public
documentation and the linked proof review are complete.

A successful INSERT need not create a `.tseg` immediately: WAL durability and
memtable visibility precede asynchronous flushing in the point-write profile.
Do not flush every INSERT just to satisfy the artifact test. Qualification must
distinguish accepted WAL-only state from flushed state and exercise both recovery
paths, with observable progress explaining the difference.


## Native local persistence implementation contract

The contract below records the earlier local-adapter delivery. The current
baseline above and milestone 2 acceptance distinguish subsequently delivered
payload/collection components from their remaining installed integration.

The local adapter keeps the existing deterministic native authority engine and
its paged copy-on-write catalogs. This delivery changes persistence, not the
meaning of a native turn or its one-KV-resource boundary. The adapter owns one
exclusive local directory and serializes access to its local WAL handle. Native
control/process transitions initially retain their current shared sequencing;
direct Table data partitions have a separate acceptance owner. A Table-only
mirror cannot satisfy this contract.

| Durable owner | Local representation | Visibility / recovery authority |
| --- | --- | --- |
| Native catalog, policy, sequences and operation receipts | Immutable verified native pages | Roots in the accepted native WAL entry |
| Process input progress, outputs, effects and retirement | Existing core records in the same paged catalog | The same native entry atomically publishes the complete transition |
| KV and Document state | Existing resource roots and immutable blocks | Native resource mutations and input/output progress retain their existing commit boundary |
| Captured versions and views | Existing durable records and referenced roots | No object collection without accounting for these retained roots |
| Staged pages/blocks | Private immutable objects | Staging never publishes a resource; failed/conflicting candidates remain unreachable |

Each accepted native entry uses partition zero of `TransitLog`; the latest
complete entry supplies the published catalog/policy roots. Epochs and expected
LSNs bind append. Log trim requires the already accepted native history floor,
retains the latest entry, and does not collect referenced objects. Restart opens
the existing authority; missing, corrupt or incompatible history is an error.
Replay reads state and never dispatches effects.

Pages and blocks use bounded verified object reads and a configured page cache.
Operation candidate bounds and an explicit physical allocation quota apply
before staging. A control reserve remains available after ordinary data
admission stops. Uncertain writes retain their reservation until restart can
recount actual files; quota pressure never permits expiry or cleanup. Staged and
superseded objects remain until a separately qualified retained-root collector
can reclaim them. The adapter and `transit-node` `local_directory` composition
pass native turn/restart and signed public-caller fault proofs. The local CLI
now selects that backend with maintenance inside the node; its bundle no longer
includes Ursula or MinIO. The bundle still composes multiple Transit executables;
the single-binary target remains part of #122. Direct Table SQL integration now
uses this backend through the separate catalog and Table acceptance owners,
as recorded in the installed lifecycle integration above. Row data does not
pass through Station actor turns. Application workers can separately coordinate
direct operations and persist their own dispatch/result evidence; those turns
are application execution, not the Table's storage or acceptance authority.
Installed standalone payload publication/reclamation, automatic point flushing,
observable segment maintenance and the remaining installed cutover obligations
are incomplete.
See the scoped
[executed evidence](../history/qualification/storage.md#native-authority-over-local-storage--2026-10-22).
