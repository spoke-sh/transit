# Logical values

`Logical` supplies sealed Java descriptor, atom and cell types for general Table
callers. Zig owns logical domain rules, conversions and durable encoding; these
models validate structural bounds and own their input values.

Descriptors are `Scalar`, `Decimal`, `Timestamp`, `Structure`, `Union`, `ListType`,
`ArrayType` and `MapType`. `Field` owns a name, type, nullable flag and optional
flag; `Element` owns a type and nullability. Convenience constructors default those
flags to false. Scalar names cover signed/unsigned 8/16/32/64/128-bit integers,
float32/64, boolean, UTF-8, binary, date, time, interval, UUID and JSON. Timestamp
zones are `CIVIL` and `UTC`; decimal precision is one to 38 and scale zero to
precision.

Cells distinguish `Missing`, `Null`, `SourceTypeError`, `Present` and `Conflict`.
Present values are typed `Atom` variants, `Sequence`, `MapValue`, `Tagged` or
`Json`. Sequences distinguish STRUCTURE, LIST and ARRAY; maps own atom keys and
cell values. Tagged values retain their alternative index. JSON text remains an
explicit logical type. Lists are immutable copies; `BinaryData` copies bytes on
construction and access and compares by byte content.

Atoms use exact `BigInteger` for `Signed`, `Unsigned`, `DecimalValue` and
`TimeNanos`; `DateDays` uses int and `TimestampMicros` uses long. `Interval` owns
int months/days and long nanoseconds. `Float32` and `Float64` require finite
primitive values and preserve signed zero. `BooleanValue`, `Utf8`, `Binary` and
`Uuid` preserve their distinct types; UUID contains exactly 16 bytes.

A conflict owns two to eight `Alternative(counter, replica, value)` records in
strictly increasing positive uint64 dot order. Alternative values are null,
source type error or present, and share the owning cell's nesting depth. Neither
missing nor conflict is silently converted into SQL null.

`typeWire`/`typeFromWire` and `cellWire`/`cellFromWire` convert typed values to/from
neutral JSON objects. Integers use canonical decimal strings; binary and
little-endian IEEE float bits use lowercase hex. A descriptor is bounded to
16 levels, 256 nodes and 4096 aggregate field-name bytes. A cell is bounded to
16 levels, 65,536 children and 1 MiB aggregate data. MAP keys consume children;
floating bytes consume payload budget. These bounds do not override enclosing
schema, operation, storage or query budgets. Large valid hex uses a linear scan,
without a regex stack frame per byte.

See the [catalog caller](CATALOG.md) for schemas and assignments and the
[logical type reference](../../../../docs/handbook/reference/sql/types.md) for shared
semantics.
