# Logical SQL results

`transit_sql_results` defines statement outcomes and finite typed result progress
independently of communications. It depends on Fuze logical types and native
domain identities, and has no SQL wire, transport, service or renderer dependency.

`CommandCompletion` separates owner-defined counts from row-returning results.
`Observation` distinguishes data cuts from catalog, settings and plan observations.
`Progress` checks immutable attribution, received/delivered counters and terminal
counts. Closing or failing a reader preserves an incomplete prefix; releasing an
already completed result preserves its evidence. `copyRow` copies validated nested
values into a caller-owned bounded arena before iterator scratch can change.

`BatchBuilder` owns up to 32 rows and 1 MiB of canonical cells, with independent
row/byte limits. A row that does not fit remains with its source; an oversized
row fails. Its allocator remains subject to the caller's resident budget.

`ResultSet` consumes a semantic source through `nextRow` or `nextBatch`. It owns
progress validation and closes the source on exhaustion, failure or explicit
closure. Borrowed rows last until the next advance or closure; schema and
observation last until `deinit`. `Window.read` copies rows into an independently
bounded owned view. A row or byte limit leaves the next row unread and does not
establish completion. The caller can continue streaming or close the result.

`Batch` separates value layout from result progress. `fromRows` borrows existing
rows; `fromColumns` borrows cell columns, Fuze vector views or verified plain
column buffers. `nextBatch` returns the remaining bounded view without transposing
its values. `columnAt(i)` provides column access for either layout; `slice` adjusts
only offset/count. `nextRow` uses reusable cell-descriptor scratch for columnar
input while variable payloads continue to borrow their source buffers.

For a verified plain column, `columnAt(i).arrowValues(&buffers)` borrows its Arrow
nullable value child and honors the slice offset. The column view retains the
full missing/null/type-error/conflict distinction; Arrow validity alone cannot.
Keep both the source owner and the caller's buffer directory alive until all
borrowed views are finished. This interface does not extend retention, import
arbitrary Arrow buffers or promise compatible Arrow layouts for every logical
type. Unsupported direct Arrow views return `UnsupportedResultColumnLayout`.

The [semantic contract](../../../contracts/SQL_RESULTS_V1.md) defines the model.
These primitives do not themselves execute SQL, verify source authority or manage
a transport. Concrete session/client adapters own those obligations.

Run `nix develop --command sh -c 'cd packages/zig/transit-sql-results && zig build test'`.
Units enumerate bounded chunk partitions and terminal framing, reject invalid
transitions and verify nested scratch ownership. They do not establish network,
service-recovery or allocator bounds for an integrated client.
