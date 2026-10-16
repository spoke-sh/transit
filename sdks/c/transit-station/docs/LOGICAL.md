# Logical values

`transit/logical.h` provides recursive logical descriptors and five-state cells
through C11 construction views and immutable owned handles. These local codecs
perform no I/O. Shared Zig owns type/domain validation, Table admission and
execution semantics.

Every exported C symbol is tied to the shared contract definition. Headers and
libraries from different definitions fail at link/load time before reading public
structures. Use matching artifacts for the C client, Station SDK and native ABI.

Construct a `transit_logical_type_view` or `transit_logical_cell_view` and call
`transit_logical_type_create` or `transit_logical_cell_create`. The call validates
the complete tree and copies all pointed-to data. Its result is independent of
the input views and any client. Tags are uint32 values with named constants;
unknown tags return `TRANSIT_SDK_INVALID_ARGUMENT`. The selected tag determines
which union member must be initialized.

```c
transit_logical_type_view amount = {
    .kind = TRANSIT_LOGICAL_DECIMAL, .as.decimal = {38, 2}
};
transit_logical_type *owned_type = NULL;
transit_sdk_error error = transit_logical_type_create(&amount, &owned_type);
if (error.kind != TRANSIT_SDK_OK) return error;
/* Use owned_type, then release it. */
transit_logical_type_destroy(owned_type);
```

Scalar descriptors cover signed/unsigned 8, 16, 32, 64 and 128-bit integers,
float32/64, boolean, UTF-8, binary, date, time, interval, UUID and JSON.
Parameterized descriptors cover decimal (precision 1–38, scale 0–precision),
civil/UTC timestamps, structures, tagged unions, lists, fixed arrays and maps.
Fields carry names, types, nullable and optional flags; elements carry type and
nullable flags. Fixed array length is positive uint32.

An atom carries a signed or unsigned 128-bit number, decimal coefficient,
finite float32/64, boolean, UTF-8, binary, date days, time nanoseconds, timestamp
microseconds, month/day/nanosecond interval or 16-byte UUID. The 128-bit public
types use two 64-bit limbs, with a signed upper limb for signed values. They do
not depend on a compiler extension. Decimal coefficients use the descriptor's
scale. Floats preserve their width and signed zero; nonfinite values fail.
Temporal carrier widths do not substitute for typed domain validation.

Cells distinguish missing, NULL, source type error, present value and conflict.
Present values have an atom, structure/list/array sequence, map, tagged union or
explicit JSON tag. JSON text is UTF-8 under that tag; other text does not become
JSON implicitly. Conflicts hold two to eight alternatives in strictly increasing
positive uint64 `(counter, replica)` order. Each alternative is NULL, source type
error or a present value. The codec does not grant permission to persist every
query cell state in an ordinary Table.

Getters return const views borrowed from their handle. Keep the handle alive
while using those views; destroy it explicitly afterward. Destroy accepts NULL.
Constructors and decoders clear their output on failure. Inputs and pointer/count
pairs must remain valid for the synchronous call; handles must not be destroyed
concurrently with a call or borrowed-view access.

`*_encode` returns the lossless neutral JSON contract in an owned
`transit_sdk_buffer`; release it with `transit_sdk_buffer_release`. `*_decode`
returns an owned tree. Exact integers and decimal coefficients use canonical
decimal strings, and floats use explicit little-endian bit strings. Decoder
input can be overwritten after return. Invalid JSON, duplicate decoded keys,
unknown variants, noncanonical numbers/hex, invalid UTF-8 and exceeded budgets
return `TRANSIT_SDK_INVALID_ARGUMENT`.

Descriptors allow 16 logical levels, 256 nodes and 4,096 aggregate name bytes.
Cells allow 16 levels, 65,536 nodes and 1 MiB of aggregate variable data, including
float bits. MAP keys consume nodes; conflict alternatives consume nodes at their
owning cell's depth. Descriptor JSON is bounded at 64 KiB and cell JSON at 16 MiB,
with 96 physical JSON levels, 1,048,576 nodes and 256 fields per object. These
codec bounds do not enlarge raw-client frames or native storage values.

Storage, primary keys, predicates, aggregation and transport admission have
separate capability axes. See [logical types](../../../../contracts/FUZE_TYPES_V1.md)
and the [proof ledger](../../../../tests/README.md).
