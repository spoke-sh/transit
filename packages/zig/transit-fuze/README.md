# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

M9 implements a bounded source/logical/physical plan boundary, typed filter,
projection, limit, row count and checked integer sum. All four admitted types
produce finite Arrow IPC. The [v1 contract](../../../contracts/FUZE_V1.md) fixes
the schema, operator and allocation limits. No optimizer rewrites are enabled.
M12's `Sql` frontend parses bounded Table `SELECT` statements and compiles them
to the same `Stream.Plan`/`PlanCodec`. It owns its AST, performs no I/O, and
requires an explicit source name/schema. See the [SQL guide](docs/sql.md) for
syntax, aggregate limits, errors and qualification.

M24 adds pure editor foundations: `Sql.hints` runs the same production parser up
to a token-boundary cursor and returns bounded grammar expectations; `SqlInput`
frames explicit semicolon termination and whole-token replacement ranges while
respecting quotes, nested comments and UTF-8 boundaries. Neither reads a catalog
nor executes a statement. A caller must filter grammar expectations against its
authorized schema and executable capability profile; these foundations alone
do not qualify Board or terminal typeahead. Existing parser/compiler differential
fixtures remain unchanged and pass with this instrumentation.

`Unified` starts the separate [M18 v2 contract](../../../contracts/UNIFIED_QUERY_V2.md):
up to eight typed columns, full-width signed/unsigned values, finite float64,
UTF-8/binary, five cell states and preserved conflict alternatives. Its canonical
`FZP2` codec borrows decoded input and supports larger finite plans. The pure
model/codec fixtures pass. `Unified.Stream` adds resumable filter/projection,
whole-query limit/count/checked sum and `Unified.Arrow` produces nested typed
state/conflict columns. PyArrow independently verifies the bytes, full-width
values and all eight page widths. Adapters and durable/public submission remain
in progress. The [v2 contract](../../../contracts/UNIFIED_QUERY_V2.md) states
workspace, segment and encoding budgets. Existing `Plan`/`Stream` v1 APIs keep their contract.

`Unified.Sql` lowers the existing SELECT grammar to v2 plans for explicitly
declared sources. The [unified SQL guide](docs/unified-sql.md) distinguishes its
capabilities, owned allocator storage and error rules from the original compiler.

`Unified.Inspect.decode` validates that exact nested IPC schema and all cell
states, conflict IDs/order, scalar widths, nullability and complete stream framing.
Arrow allocations stay in caller-supplied workspace; decoded text/binary is copied
into the caller's result allocator. Keep the output `Batch` at its final address:
conflict slices borrow its fixed alternative arrays. Any error invalidates the
whole output. PyArrow-produced round trips and thirteen malformed schema/state
cases qualify this reader independently of Fuze's encoder.

Station owns authorized Table adapters and durable result publication; the
[Fuze design](../../../docs/reference/queries.md) describes the broader direction.

M10's separate `Stream` interface implements bounded steps with owned progress,
whole-query limits/aggregates and Arrow segments. See the
[incremental execution guide](docs/streaming.md) and
[contract](../../../contracts/FUZE_STREAM_V1.md). Durable Station capture and
delivery remain integration work; a pure engine result is not a committed query.

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
semantics; [Arrow](../../../docs/reference/arrow.md) owns later remote interoperability.
