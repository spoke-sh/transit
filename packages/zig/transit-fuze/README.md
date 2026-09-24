# transit-fuze

Fuze's Zig-native query library, exported as `transit_fuze`. It runs in callers;
it has no Transit authority, storage, network or deployment dependency.

M9 implementation has started with Arrow integration. The current package
provides bounded IPC encoding and qualified dependency wiring. Query planning,
Table sources and durable result publication remain in progress; this package
does not yet implement the full [Fuze design](../../../docs/FUZE.md).

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
