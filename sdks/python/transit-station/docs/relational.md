# Interactive relational queries

`transit_station.relational.Client` and `AsyncClient` evaluate the selected Table
join and grouped aggregate profile through the shared Zig query owner. Configure
one or two `catalog.Connection` values in one realm. Each statement supplies a
route index for every `FROM`/`JOIN` target; names never select catalogs implicitly.
The [relational caller contract](../../../../packages/zig/transit-query/docs/relational-callers.md)
defines SQL, ordering, budgets and current authorization.

```python
from transit_station import relational

options = relational.Options(
    consistency="per_resource_snapshot_vector",
    resident_bytes=16777216, spill_bytes=16777216,
    result_bytes=8388608, output_rows=1000,
    work_steps=100000, requests=100000, spill_work=100000,
    source_pins=2, spill_directory=private_spill_directory,
)
statement = relational.Statement(
    "SELECT l.k, COUNT(*) AS rows FROM left_table l LEFT JOIN right_table r ON l.k = r.k GROUP BY l.k",
    routes=(0, 1),
)
with relational.Client(url, principal, seed_file, catalogs, options) as client:
    proposed = client.explain(statement)  # metadata only
    identity = relational.fresh_id()  # retain with statement for open retries
    opened = client.open_query(identity, statement)
    try:
        ordinal = 0
        while True:
            page = client.page(opened.reference, ordinal)
            if page.complete_coverage:
                break
            consume(page.row)  # a prefix until complete coverage is observed
            ordinal += 1
    finally:
        client.close_query(opened.reference)
```

`AsyncClient` provides the same operations as awaitables and supports `async
with`. One owned worker admits one operation at a time. Cancelling an await does
not cancel its native operation or release the handle; overlapping calls raise
`Busy`. `close()` joins outstanding work and releases the native owner, including
when its own awaiting task is cancelled.

`explain` returns the prepared plan digest, typed columns and exact source
identities without opening a snapshot. `open_query` returns that plan, an
immutable reference and resource cuts. Aliases on one resource share a cut;
different resources form an explicit snapshot vector without a global transaction
claim. One client owns one active query.

Retry an uncertain open using its original nonzero ID and statement. Page
ordinals start at zero. Repeat the current page or advance by exactly one after
a row; older or skipped ordinals reject. A terminal page has no row and sets
`complete_coverage`. A failure leaves the preceding rows incomplete and preserves
the original diagnostic, including checked overflow's contributor identity.

Rows own tuples of `int | None`. Signed values and group keys are checked int64;
counts retain the complete uint64 range. Pair identities own their 20-byte Table
identities. Native responses are validated before constructing frozen values.
Source access is checked again for every page, including repeated and terminal
pages. Closing releases the query's pins and spill file even after source access
is denied.

`Reference.save()` and `Reference.restore()` preserve the mandatory contract
definition, query ID, plan and basis. References belong to the live host;
replacement rejects them instead of rerunning the statement. This interface
exposes interactive queries only. The typed Zig owner separately provides
durable captured jobs and maintained result revisions. There is no implicit
query retry, polling loop or effect dispatch.
