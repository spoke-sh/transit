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
row fails. `init(allocator, capacity)` reserves fixed aligned representation
storage once; `fromBuffer` borrows caller-owned storage. This resident capacity is
separate from canonical byte count. Reset ends existing row borrows and retains
the charged capacity; failed nested copies rewind without consuming progress or
stranding capacity. Exhaustion reports `ResultMemoryBudgetExceeded`. Keep the
builder at a stable address after its first reset. Its backing allocator is not
consulted again before destruction.

`ResultSet` consumes a semantic source through `nextRow` or `nextBatch`. It owns
progress validation and closes the source on exhaustion, failure or explicit
closure. Borrowed rows last until the next advance or closure; schema and
observation last until `deinit`. `Window.readInto` copies rows into a leased
`transit-memory.Workspace`; `Window.read` reserves its own bounded storage.
Both return one window owner by value, released with `deinit`. Keep a supplied
workspace at a stable address until release. Retained windows prevent reuse;
separate workspaces retain independent windows while the source advances or
closes. The entire reserve, including unused capacity and row directories,
remains charged. A failed partial row copy rolls back without delivering that
row. A row or byte limit leaves the next row unread and does not establish
completion. A previously received terminal survives truncation, but its count
does not imply that the window contains every row. The caller can continue
streaming or close the result.

Historical data observations carry the selected catalog snapshot and complete
source vector. Historical metadata observations carry the catalog identity
without inventing a row-data snapshot. Validation checks scope, definitions,
source count and consistency; independent selections cannot claim an atomic
transaction cut. These descriptors attribute results but do not acquire or
extend retention. Explicit schema projections retain original source identity
and schema while reporting accepted target identity, schema and mapping policy
separately. Current disclosure rights remain the source owner's duty.

Interactive sources may implement `Source.validate_disclosure`. Calling
`ResultSet.holdDisclosure` retains the last source scope after exhaustion until
explicit close/deinit or source lease expiry. `validateDisclosure` checks current
access without advancing; unsupported or closed sources refuse it. Validation
covers the current chunk, not earlier metadata with different authorization
subjects. Ordinary readers keep automatic closure on exhaustion. Holding a
disclosure scope does not pin source history or grant continuing access.

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
