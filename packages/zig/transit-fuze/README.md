# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

Fuze executes finite typed filter, projection, limit, count and checked integer
sum over caller-authorized source batches. Aggregates update bounded state
without materializing discarded row projections. It has no storage, credentials or
native authority. No optimizer rewrites are enabled.

`Unified` implements the [finite query v1 contract](../../../contracts/UNIFIED_QUERY_V1.md):
up to eight typed columns, full-width signed/unsigned values, finite float64,
UTF-8/binary, five cell states and preserved conflict alternatives. Its canonical
`FZP1` codec borrows decoded input. `Unified.Stream` retains bounded progress
across source pages; `Unified.Arrow` emits nested typed state/conflict columns.
KV, Table and Document adapters, interactive snapshots and durable public
submission compose these types through [transit-query](../transit-query/README.md).
The contract fixes workspace, segment and encoding budgets.

`Unified.Sql` lowers SELECT syntax against declared sources. The
[SQL guide](docs/unified-sql.md) describes capabilities, allocated ownership and
errors. `Sql` owns the shared parser and cursor assistance. All callers execute
through `Unified.Plan` and `Unified.Stream`, including Station Table delivery.

`Sql.parseMutation` and `TableMutation.compile/lower` produce owned, exactly
typed plans for literal INSERT, UPDATE and DELETE against one declared Table.
These plans are separate from read queries. The application invokes Station's
private-turn helper under its own command authorization; public query transports
reject mutation statements. See the [Table mutation contract](../../../contracts/TABLE_MUTATION_V1.md).

`Sql.hints` uses the production parser up to a token-boundary cursor and returns
bounded grammar expectations. `SqlInput` frames semicolon termination and
whole-token replacement while respecting quotes, nested comments and UTF-8.
Neither reads a catalog nor executes a statement. Callers filter expectations
against their authorized schema and executable capability profile.

`Unified.Inspect.decode` validates that exact nested IPC schema and all cell
states, conflict IDs/order, scalar widths, nullability and complete stream framing.
Arrow allocations stay in caller-supplied workspace; decoded text/binary is copied
into the caller's result allocator. Keep the output `Batch` at its final address:
conflict slices borrow its fixed alternative arrays. Any error invalidates the
whole output. PyArrow-produced round trips and thirteen malformed schema/state
cases qualify this reader independently of Fuze's encoder.

Station owns Table storage and an authorized Table capture/delivery helper.
The [query reference](../../../docs/reference/queries.md) describes interactive
and durable queries across all supported sources. All use the same plan, source
basis and nested Arrow result definition. `model` contains Table storage cells
and descriptors, not a second query engine.

Bind a `Unified.Plan` to the exact basis/schema, initialize
`Unified.Stream.Progress.start(bound)`, and call `Unified.Stream.step` for each
bounded page. Workspace, output buffers and cancellation belong to the caller.
A changed source identity, schema, plan or page ordinal rejects continuation.
No native pointers or background tasks survive a step. See the
[incremental execution guide](docs/streaming.md).

`encode(allocator, batch, output)` writes a complete Arrow IPC stream into the
caller-supplied buffer and returns a borrowed slice. Failure returns no result;
the caller must discard the buffer. The batch remains caller-owned. Allocation
and stream/batch limits are separate: a bounded output buffer does not itself
bound every upstream intermediate allocation.

Run through the pinned development shell:

```sh
just test::arrow
(cd packages/zig/transit-fuze && zig build test)
```

The first command checks actual IPC bytes with independently implemented
PyArrow. The package tests exercise shared Arrow/compute types, ownership and
output failure, and the compatible upstream compute suite. PyArrow is a test
dependency; no C++ query engine is linked into Fuze.

[Integration notes](docs/integration.md) record pins, compatibility changes and
measured limits. [Tables](../../../docs/reference/tables.md) owns transaction and result
semantics; [Arrow](../../../docs/reference/arrow.md) owns Arrow interchange.
