# Logical values

`transit_logical` exposes immutable logical descriptors, atoms and five-state
cells. `encode(type | atom | cell, Value)` returns `{ok, WireMap}` or
`{error, #transit_error{}}`. `decode(Kind, WireMap)` returns an owned language-native
value or an incompatible-input error. The wire maps contain the generated neutral
contract's binary keys; they are distinct from the public records and tagged
values. These codecs perform no I/O and grant no authority.

Include `transit_station_sdk/include/transit_logical.hrl` for fields, elements and
conflict alternatives. Scalar descriptors are `int8`, `int16`, `int32`, `int64`,
`int128`, their unsigned `uint*` counterparts, `float32`, `float64`, `boolean`,
`utf8`, `binary`, `date`, `time`, `interval`, `uuid` and `json`. Recursive and
parameterized descriptors are:

- `{decimal, Precision, Scale}` with precision 1–38 and scale 0–precision.
- `{timestamp, civil | utc}`.
- `{structure, Fields}` or `{tagged_union, Fields}`, where each field is
  `#transit_logical_field{name, type, nullable = false, optional = false}`.
- `{list, Element}` or `{array, Element, Length}`, with positive uint32 length
  and `#transit_logical_element{type, nullable = false}`.
- `{map, KeyType, ValueElement}`.

Atoms retain exact representation. `{signed, N}` and `{decimal, Coefficient}` use
signed 128-bit ranges; `{unsigned, N}` uses unsigned 128-bit range. Decimal values
are coefficients interpreted using their descriptor's scale. `{float32, F}` and
`{float64, F}` preserve their IEEE widths and signed zero through neutral byte
encoding and reject nonfinite results. Float32 conversion rounds to that width.
Other atoms are `{boolean, B}`, `{utf8, Text}`, `{binary, Bytes}`, `{uuid, Bytes16}`,
`{date_days, Signed32}`, `{time_nanos, Unsigned64}`, `{timestamp_micros, Signed64}`
and `{interval, Signed32Months, Signed32Days, Signed64Nanos}`. Temporal/domain
constraints beyond the carrier widths belong to shared Zig's typed validation.

Cells keep `missing`, `null`, `{type_error, LogicalKind}`, `{value, Value}` and
`{conflict, Alternatives}` distinct. A present value is one of:

- `{atom, Atom}`.
- `{structure, Cells}`, `{list, Cells}` or `{array, Cells}`.
- `{map, [{AtomKey, CellValue}, ...]}`.
- `{tagged_union, Index, Cell}` with index 0–255.
- `{json, Utf8JsonText}` with an explicit JSON tag.

JSON text remains a typed logical value; ordinary UTF-8 values are not implicitly
JSON. A conflict has two to eight `#transit_logical_alternative{counter, replica,
value}` entries ordered strictly by their positive uint64 `(counter, replica)`
dots. An alternative contains null, source type error or a present value; it
cannot itself be missing or another conflict. Nested values may contain distinct
cell states; Table admission separately validates which are storable.

```erlang
Type = {structure, [#transit_logical_field{name = <<"amount">>,
    type = {decimal, 38, 2}, nullable = true}]},
Cell = {value, {structure, [{value, {atom,
    {decimal, 123456789012345678901234567890}}}]}},
{ok, Wire} = transit_logical:encode(cell, Cell),
{ok, Cell} = transit_logical:decode(cell, Wire).
```

Each descriptor permits at most 16 logical levels, 256 nodes and 4,096 aggregate
name bytes. Each cell permits at most 16 levels, 65,536 child nodes and 1 MiB of
aggregate variable data, including float bytes. MAP keys consume child nodes.
Conflict alternatives occupy their owning cell's level and consume node/data
budget. Limits are shared across a complete descriptor or cell in both codec
directions. Binary extraction owns the bounded bytes and does not pin unrelated
caller sub-binary storage. No external name is converted into a BEAM atom.

Storage, key equality, predicates, aggregation and transport admission have
separate contracts. A logical codec round trip does not qualify every operator
for the represented type. See [logical types](../../../../contracts/FUZE_TYPES_V1.md)
and the [proof ledger](../../../../docs/history/qualification/README.md) for contracts and executed
installed-package evidence.
