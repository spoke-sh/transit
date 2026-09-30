# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

Fuze executes finite typed filter, projection, limit, count and checked integer
sum over caller-authorized source batches. It has no storage, credentials or
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
errors. `Sql` owns the shared parser and a specialized two-column Table lowering
used by Station's Table query API. `Plan` executes one bounded Table batch;
`Stream` preserves whole-query limits across batches. These are library execution
interfaces with distinct input bounds, sharing the same native v1 authority.

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

Station owns authorized Table adapters and durable result publication; the
[Query reference](../../../docs/reference/queries.md) describes the broader direction.

`Stream` implements bounded steps with owned progress,
whole-query limits/aggregates and Arrow segments. See the
[incremental execution guide](docs/streaming.md) and
[contract](../../../contracts/FUZE_STREAM_V1.md). Station supplies durable capture and delivery; a pure engine result alone is
not a committed query.

`Plan.bind(source)` validates the source's schema, capability and exact read
basis. `execution.run` consumes that basis with caller-supplied workspace/output
buffers and a cancellation flag. It retains no pointers or background tasks;
the returned bytes borrow the output buffer. A physical plan rejects a changed
source identity/revision. Explanations omit literals and application values.

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
