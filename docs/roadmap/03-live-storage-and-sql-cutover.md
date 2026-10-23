# 3. Executable data lifecycles and live storage/SQL cutover

[Roadmap](README.md) · [Tracker #110](https://github.com/spoke-sh/transit/issues/110) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

Wire the four-tier storage hierarchy (`TransitLog`, `TransitObjectStore`,
`TableMemtable`, `TableManifest`) and `.tseg` hybrid columnar segment engine
into the live runtime executables (`transit-node`, `transit-sql-gateway`,
`transit-query-host`, `transit-cli`), eliminating read-after-write cache
blindness, cross-lane cache isolation, unconditional sleep loops and multi-turn
DML staging delays on the interactive SQL and server hot paths.

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
[milestone 14](14-storage-providers-and-concurrency.md), retaining #117/#121 and
their #124 proof gates. This milestone remains In Progress; the split establishes
no newly completed lifecycle or deployment. #108/#110 retain their delivered
evidence and track these installed outcomes together.

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
   explicit milestone 14 obligations; this checkpoint does not complete them.
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
   `just test::sql-gateway`, `just test::server-sql-local`, `just check` and the
   committed-source clean check, recording matched controls through #76/#124.

## Completion evidence

Record installed local baselines for durable data operations and native runtime
work, separating admission, WAL sync, execution/turn commit, recovery and result
delivery. Include candidate segments, range-read bytes and peak resident memory.
The later [performance scorecard](10-data-structures-and-performance.md) extends
these measurements; it cannot replace this cutover's existing matched controls
with library-only timings or defer a missing bounded access path.

Require passing end-to-end proofs across `transit-node`, `transit-sql-gateway`,
`transit-query-host`, `transit server` and `psql`/`mysql`/`transit sql` callers,
preserving exact recovery, fencing, permission revocation and bounded resumable
direct ingestion for oversized statements while demonstrating measured
wall-clock improvement under matched controls.

The reopening adds an explicit review gate: show the installed public SQL path
creating native `.tseg`/`.tdel`/manifest artifacts under the resolved storage root
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
can reclaim them. The adapter and explicit `transit-node` `local_directory`
composition now pass native turn/restart and signed public-caller fault proofs.
The installed launcher default, standalone payload ownership
and direct Table SQL integration remain incomplete. See the scoped
[executed evidence](../../tests/README.md#native-authority-over-local-storage--2026-10-22).
