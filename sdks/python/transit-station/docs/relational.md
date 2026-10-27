# Interactive relational queries

`transit_station.relational.Client` and `AsyncClient` evaluate finite Table joins
and grouped aggregates through the shared Zig query owner. Configure one or two
identical direct `catalog.Connection` values. A statement selects a namespace
and a configured route for each FROM/JOIN target. The
[shared relational contract](../../../../packages/zig/transit-query/docs/relational-callers.md)
owns SQL support, ordering, budgets and current authorization.

`explain` returns typed columns, a plan digest and each source's complete prepared
basis and observed position. It acquires no retention and executes no rows.
`open_query` requires an explicit saved binding and durable snapshot per source;
it never silently acquires or releases one.

```python
from transit_station import catalog, relational

options = relational.Options(
    consistency="independent_table_snapshots",
    resident_bytes=16777216, spill_bytes=16777216,
    result_bytes=8388608, output_rows=1000,
    work_steps=100000, requests=100000, spill_work=100000,
    source_pins=2, spill_directory=private_spill_directory,
)
statement = relational.Statement("SELECT id FROM people", routes=(0,), namespace=1)
with catalog.Client(url, principal, seed_file, connection) as tables:
    with relational.Client(url, principal, seed_file, (connection,), options) as query:
        source = query.explain(statement).sources[0]
        acquisition = tables.prepare_snapshot(source.basis, source.position, pin_operation)
        save_durably("acquisition", acquisition.save())
        snapshot = tables.acquire_snapshot(acquisition)
        save_durably("snapshot", snapshot.save())
        identity = relational.fresh_id()
        save_query_request(identity, statement, source.basis.save(), snapshot.save())
        opened = query.open_query(
            identity, statement, (relational.RetainedSource(source.basis, snapshot),),
        )
        try:
            ordinal = 0
            while True:
                page = query.page(opened.reference, ordinal)
                if page.complete_coverage:
                    break
                consume(page.row)
                ordinal += 1
        finally:
            query.close_query(opened.reference)
        save_cleanup_decision(snapshot.save())
        tables.release_snapshot(snapshot)
```

The application owns saved acquisition and cleanup decisions, including failures
before the query opens. Resolve uncertain acquisition through
`tables.snapshot_status(acquisition.owner)` and retain the original snapshot
until release is confirmed. An exact acquisition can reject if the live position
changed before acceptance; it does not substitute a newer position. Repeated
aliases of one Table use the same snapshot. Distinct Table cuts are independent,
not a global transaction snapshot.

Retry an uncertain open with the original ID, statement, bindings and snapshots.
A live client owns one active query. Ordinals begin at zero; repeat the current
page or advance exactly one after a row. Skipped and older pages reject. A
terminal page has no row and sets `complete_coverage`; a failed prefix remains
incomplete. Current authorization is checked again for repeated, buffered and
terminal output. The reference contains its mandatory shared definition, query
ID, plan and basis. Saving it does not make an interactive cursor durable.
Replacing the host invalidates that cursor instead of resuming it silently.

Rows own tuples of `int | str | None`. Signed values and integer grouping keys
are int64; counts preserve uint64. Text cells and keys preserve Unicode strings,
including empty strings and embedded NULs. Pair identities own their 20-byte values. Response
validation checks original source bindings, object identities, schema and cut
positions. Local query closure releases local execution and spill resources,
including after denial. It leaves explicit durable snapshots for their owner to
release. Client destruction has the same retention boundary.

`AsyncClient` provides the same remote operations as awaitables. Each caller has
one owned worker; cancelling an await does not release native operation ownership.
Overlapping calls raise `Busy`, and `close()` joins outstanding work. An optional
`service_url` selects the direct service separately from the authority URL.
