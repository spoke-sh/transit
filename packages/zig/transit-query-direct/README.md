# transit-query-direct

Finite SQL query execution over authorized direct Tables, exported as
`transit_query_direct`. The package depends on Catalog, Fuze and the public
protocol. Its compiled dependency graph excludes Station.

`DirectTablePrepared` binds a typed SELECT to an immutable Table definition.
`DirectTableQuery` executes it over an explicitly retained snapshot with bounded
rows, bytes and source requests. `DirectRelationalCompilation` and
`DirectRelationalQuery` supply finite joins and grouped aggregation over explicit
source cuts. Independent Table cuts remain an independent source vector.

The historical preparation entry points bind names and schemas through a
published `DirectHistory` catalog before compiling. Prepared bindings retain
the exact catalog identity as well as each source cut. Historical executors
scan those retained sources and validate current access on every disclosure;
they never substitute a live-name lookup or a newer physical index. Their
borrowed catalog pins remain owned by the original acquisition. The
[historical SQL reference](../../../docs/handbook/reference/sql/as-of.md)
defines the admitted selector and read-only scope.

The caller owns snapshot acquisition and release. Closing an executor releases
its local buffers and spill work; it does not release the caller's retained pin.
Current authorization is checked after computation and before disclosure,
including empty results and terminal batches. Cancellation or failure preserves
an incomplete prefix and never recaptures a different snapshot.

`ComputePool` owns bounded reusable workers and vector scratch. `RelationalSpill`
provides bounded disk scratch for the relational executor. Neither supplies
application scheduling, durable operation admission or an execution authority.
The SQL service and captured-query integration both use these same executors.

`RelationalBridge` exposes neutral requests and a retained-Table session over
the relational executor. It borrows clients, I/O and the spill directory from its
host, which serializes calls and joins them before destruction. Only the current
page can be repeated; each disclosure rechecks current source rights.
`TableChangeReader` supplies snapshot backfill and bounded change handoff over
an explicitly retained direct history lease. Its checkpoint names a complete
acceptance, and reopening repeats an incomplete transaction from its beginning.
Local closure never releases that durable lease. `transit_query` re-exports
these exact modules for captured/interactive composition, and the public Zig
SDK exports `transit_query_direct` independently.

Run `zig build check` and `zig build test` from this directory in `nix develop`.
`-Dtest-filter=<substring>` selects focused existing component schedules.
The [query reference](../../../docs/handbook/reference/queries.md) describes
supported SQL and source semantics; the [SQL service](../transit-sql/README.md)
owns sessions, operation recovery and read-pin cleanup.

`DirectView` expands an accepted single-Table projection/filter over the exact
source declaration. Historical preparation resolves the retained view before
compiling the outer SELECT. Source filtering precedes outer expressions, and
view identity participates in the binding fingerprint and disclosure guard.
DESCRIBE and EXPLAIN use the same metadata bindings. General graph/foreign
execution, view joins, captured views, explicit schema projection and transaction
composition over views remain unavailable. See the
[catalog interpretation contract](../../../contracts/CATALOG_DEFINITIONS_V1.md).

`ManagedTable` composes immutable catalog records, named direct KV control and
common Table/KV transactions for finite recomputation. Save the complete
`Declaration` before `publish`, and save `prepareControl` bytes before
`applyControl`; retries use those original bytes. `inspect` returns lifecycle,
source coverage and the committed transaction decision. The service drives
`start`/`step` with bounded workers and an owned spill directory. Hosts serialize
a work token and retain it until completion. On activation, page pending tokens
with `DirectClientToken.list(client, ManagedTable.workAccount(), after, true)`
and resume their exact `step` calls before discovering new work with `start`.
A prepared control participant can refuse `inspect` or `start`; recovery must
not depend on reading that participant to discover its pending transaction.

`ManagedRevision.open(manager, declaration, revision, limits)` reads one completed
revision from its immutable schema and row pages, independently of later output
Table writes. `next(&output)` copies each row into a caller-owned arena; reset
that arena only after consuming its rows. Call `validateDisclosure` after buffering
and before exposing schema, metadata or rows. Reads recheck current source, output
and control access, including empty and terminal results. Defaults bound consumption
to 10,000 rows and 16 MiB of encoded manifest/page bytes. Budget stops and failures
do not establish completion. `deinit` frees local memory without releasing the
retained revision or retiring the computation.

See [managed Table computations](../../../docs/handbook/reference/queries.md#managed-table-computations)
for supported SQL, current-policy checks and retention limits.
