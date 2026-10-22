# Logical values

`Transit::Station::Logical` supplies owned Ruby values for Table schemas and
cells. Zig owns logical domain validation, conversions and durable encoding;
Ruby performs structural, ownership and budget checks before dispatch.

Type descriptors are `Scalar(kind:)`, `Decimal(precision:, scale:)`,
`Timestamp(zone:)`, `Structure(fields:)`, `Union(fields:)`, `List(element:)`,
`ArrayType(element:, length:)` and `Map(key:, value:)`. `Field` owns a name, type,
`nullable: false` and `optional: false`; `Element` owns a type and nullability.
Scalar kinds cover signed/unsigned integers from 8 through 128 bits, float32/64,
boolean, UTF-8, binary, date, time, interval, UUID and JSON. Timestamp zones are
`:civil` and `:utc`. Decimal precision is one to 38, with scale zero to precision.

Cells distinguish `Missing`, `Null`, `SourceTypeError(actual:)`, `Present(value:)`
and `Conflict(alternatives:)`. Present values are `Atom(kind:, value:, width: nil)`,
`Sequence(kind:, cells:)`, `MapValue(entries:)`, `Tagged(index:, value:)` or
`Json(json:)`. Sequence kinds are `:structure`, `:list` and `:array`; map entries
own a typed atom key and cell value. A tagged union owns its alternative index
and cell. JSON text remains explicit logical JSON rather than an arbitrary Ruby
object. Binary strings and nested collections are copied and frozen.

Atom kinds are `:signed`, `:unsigned`, `:decimal`, `:float`, `:boolean`, `:utf8`,
`:binary`, `:uuid`, `:date_days`, `:time_nanos`, `:timestamp_micros` and `:interval`.
Integers and decimal coefficients use exact `Integer` values; no float conversion
intervenes. Intervals use `Interval(months:, days:, nanos:)`. Floating atoms require
a finite `Float` with explicit width 32 or 64, preserve signed zero, and reject
float32 overflow. UUIDs contain exactly 16 binary bytes.

Conflicts contain two to eight `Alternative(counter:, replica:, value:)` values
in strictly increasing positive uint64 dot order. Alternatives contain null,
source type error or present values and share the owning cell's nesting depth.
Missing and conflict remain distinct from SQL null.

`type_wire`/`type_from_wire` and `cell_wire`/`cell_from_wire` convert these typed
values to/from neutral JSON objects. Exact integers use canonical decimal strings;
binary and little-endian float bits use lowercase hex. Each type is bounded to
16 nesting levels, 256 nodes and 4096 aggregate field-name bytes. Each cell is
bounded to 16 levels, 65,536 children and 1 MiB aggregate data. MAP keys count as
children, and floating bytes count against payload budgets. These codec bounds
do not override the enclosing schema, operation, storage or query budgets.

See the [catalog caller](CATALOG.md) for typed assignments and schema operations,
and [logical type reference](../../../../docs/handbook/reference/sql/types.md) for shared
semantics.
