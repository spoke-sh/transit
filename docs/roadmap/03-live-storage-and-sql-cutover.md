# 3. Live storage engine and SQL execution cutover

[Roadmap](README.md) · [Issue #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

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

## Root-cause diagnosis of live runtime latency

After delivering the `transit-storage` and `transit-fuze` `.tseg` libraries in
Milestone 2, profiling the live server and SQL executables revealed four runtime
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

1. **Stage-to-cache write-through, verified block caching and cross-lane cache sharing in `transit-node`:**
   populate `PackedPageStore`'s verified page cache and a new bounded verified
   block cache immediately upon confirmed segment seal in `finish`, update
   `Store.append` to cache confirmed journal entries, share a mutex-guarded
   verified Tier 0 page/block/head cache across all `Native.zig` lanes, and
   raise default `resident_pages` from `8`/`16` to `512` (ceiling `4096`).
2. **Immediate condition-variable wakeups and zero-sleep active turn draining in `transit-sql-gateway`:**
   add `wake_cond` and `progress_cond` to `AccountRuntime` so incoming SQL
   admissions/executions wake `runAccount` immediately, drain ready `GenServer`
   sub-steps inside `tick()`, loop immediately without sleeping whenever
   `progressed == true`, and wake waiting callers (`finishControl`, `admit`,
   `execute`) on progress broadcast instead of polling in `5 ms` sleep increments.
3. **Single-turn DML statement fast path and `.tseg` + `Collation` + `transit-storage` integration:**
   add a `fitsSingleTurn` fast path to `TableStatement.step` so bounded
   multi-row `INSERT`, `UPDATE` and `DELETE` statements complete in a single
   turn when their reachable records fit the turn budget; support `.tseg`
   columnar segment blocks (`0x54534701`) and declared column `Collation`
   ordering/equality in `TablePages`, `TableData`, `Types` and `TableScan`; and
   expose `TableStorageBridge` in `transit-catalog` over `TableMemtable`,
   `LocalWal`, `LocalSegmentStore` and `TableManifest`.
4. **Low-latency worker long-polling and SQL supervisor bootstrap in `transit server`:**
   keep `x-transit-wait` armed across consecutive steps in `transit-query-host`,
   reduce worker/courier retry intervals from `100 ms` to `10 ms`, and poll SQL
   bootstrap readiness at `50 ms` while `.initializing` or `.starting`.
5. **Re-baseline live end-to-end SQL and server latency:**
   verify all safety, fencing and recovery proofs (`just test::sql-gateway`,
   `just test::server-sql-local`, `just check`) and record before/after
   wall-clock latency, cache hit rates and provider request counts in the
   handbook and proof ledger.

## Completion evidence

Require passing end-to-end proofs across `transit-node`, `transit-sql-gateway`,
`transit-query-host`, `transit server` and `psql`/`mysql`/`transit sql` callers,
preserving exact recovery, fencing, permission revocation and multi-turn fallback
for oversized statements while demonstrating measured wall-clock speedup.
