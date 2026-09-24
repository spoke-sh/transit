# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

M9 implements a bounded source/logical/physical plan boundary, typed filter,
projection, limit, row count and checked integer sum. All four admitted types
produce finite Arrow IPC. The [v1 contract](../../../contracts/FUZE_V1.md) fixes
the schema, operator and allocation limits. No optimizer rewrites are enabled.
Station owns authorized Table adapters and durable result publication; the
[Fuze design](../../../docs/FUZE.md) describes the broader direction.

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
measured limits. [Tables](../../../docs/TABLES.md) owns transaction and result
semantics; [Arrow](../../../docs/ARROW.md) owns later remote interoperability.
