# 3. Live storage engine and SQL execution cutover

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
   a less-visible native owner. This checkpoint does not close all milestone 2
   provider, codec or concurrency promises.
5. **Extend concurrency and deployment qualification.** Integrate the selected
   writer/isolation profiles and real distributed providers from #117/#121.
   Qualify current-policy enforcement, point/bulk conflicts, source snapshots,
   failures and complete logical history using the same public contracts.
   Automatic clustered placement remains milestone 9.
6. **Preserve latency improvements and qualify the final cutover.** Retain
   validated cache visibility/sharing, batched reads, gateway wakeups and
   shorter readiness paths where their owners remain applicable. Complete or
   explicitly resolve keep-armed long polling; measure idle CPU, provider
   attempts and bootstrap latency. Run the affected safety/recovery proofs,
   `just test::sql-gateway`, `just test::server-sql-local`, `just check` and the
   committed-source clean check, recording matched controls through #76/#124.

## Completion evidence

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
bounded datasets beyond RAM/cache and the selected deployment profiles. Large
statements must retain bounded recoverable progress through the resolved direct
operation contract; the earlier actor fallback cannot remain the bulk data path
and still satisfy milestone 1. Return this milestone to `Completed` only after
those executable acceptance paths, accurate public documentation and the linked
proof review are complete.

A successful INSERT need not create a `.tseg` immediately: WAL durability and
memtable visibility precede asynchronous flushing in the point-write profile.
Do not flush every INSERT just to satisfy the artifact test. Qualification must
distinguish accepted WAL-only state from flushed state and exercise both recovery
paths, with observable progress explaining the difference.
