# Logical values

`Logical` exposes owned .NET descriptor, atom and cell records and their neutral
JSON codecs. Shared Zig owns domain semantics, conversions and durable encoding;
these codecs enforce structural bounds and own nested host values.

Descriptors are `Scalar`, `Decimal`, `Timestamp`, `Structure`, `Union`, `ListType`,
`ArrayType` and `MapType`. `Field` owns a name, type, nullable flag and optional
flag; `Element` owns a type and nullability. Convenience constructors default both
flags to false. Scalar kinds cover signed/unsigned 8/16/32/64/128-bit integers,
float32/64, boolean, UTF-8, binary, date, time, interval, UUID and JSON. Timestamp
zones are `Civil` and `Utc`; decimal precision is one to 38 and scale zero to
precision.

Cells distinguish `Missing`, `Null`, `SourceTypeError`, `Present` and `Conflict`.
Present values are typed `Atom` records, `Sequence`, `MapValue`, `Tagged` or `Json`.
Sequences distinguish Structure, List and Array; maps own atom keys and cell
values. Tagged values retain their alternative index. JSON text remains explicit
logical JSON. BinaryData copies on construction/access and compares byte content.
Nested collections are immutable copies with structural equality and hash codes.

`Signed` and `DecimalValue` use `Int128`; `Unsigned` uses `UInt128`. Decimal
coefficients preserve all 38 supported digits without passing through the .NET
`decimal` or floating types. `DateDays` uses int, `TimeNanos` uses ulong and
`TimestampMicros` uses long. `Interval` owns int months/days and long nanoseconds.
`Float32`/`Float64` require finite values, preserve signed zero and compare exact
bits. `BooleanValue`, `Utf8`, `Binary` and `Uuid` retain their distinct types;
UUIDs contain exactly 16 bytes.

A `Conflict` owns two to eight `Alternative(counter, replica, value)` records in
strictly increasing positive ulong dot order. Alternatives contain null, source
type error or present values and share the owning cell's nesting depth. Missing
and conflict remain distinct from SQL null.

`TypeWire`/`TypeFromWire`, `AtomWire`/`AtomFromWire` and
`CellWire`/`CellFromWire` convert records to/from owned neutral `JsonObject` trees.
Exact integers use canonical decimal strings; binary and little-endian IEEE
float bits use lowercase hex. A descriptor is bounded to 16 levels, 256 nodes
and 4096 aggregate field-name bytes. A cell is bounded to 16 levels, 65,536
children and 1 MiB aggregate data. MAP keys consume children, and floating bytes
consume payload budget. Codec support does not expand Table, literal, operator,
query or transport admission; their owning contracts define those capabilities.

Run `just bindings::logical-dotnet` in the bindings shell to qualify the models
from isolated NuGet packages. The same fixture is part of the complete .NET SDK
schedule. The [proof ledger](../../../../docs/history/qualification/README.md) records executed evidence;
[logical type semantics](../../../../docs/handbook/reference/sql/types.md) describes the
shared domain rules.
