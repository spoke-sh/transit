# transit-query-direct

Finite SQL query execution over authorized direct Tables, exported as
`transit_query_direct`. The package depends on Catalog, Fuze and the public
protocol. Its compiled dependency graph excludes Station.

`DirectTablePrepared` binds a typed SELECT to an immutable Table definition.
`DirectTableQuery` executes it over an explicitly retained snapshot with bounded
rows, bytes and source requests. `DirectRelationalCompilation` and
`DirectRelationalQuery` supply finite joins and grouped aggregation over explicit
source cuts. Independent Table cuts remain an independent source vector.

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
