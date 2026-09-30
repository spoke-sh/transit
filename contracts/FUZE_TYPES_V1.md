# Fuze logical types v1

This contract specifies the shared Zig logical type and conversion model. The
implementation/capability table in the [type reference](../docs/reference/sql/types.md)
distinguishes admitted types from interfaces that still accept a narrower profile.
Logical types describe meaning; Arrow layouts and neutral encodings describe
representation. Neither a descriptor nor a decoded value grants source access.

## Descriptors and identity

A descriptor is an acyclic tree with explicit children and field order. Its
canonical encoding includes the current definition identifier, kind, parameters,
field names, nullability and optionality. Its SHA-256 fingerprint excludes memory
addresses, allocation strategy and physical batch layout. Unknown identifiers,
invalid parameters, duplicate field names and trailing bytes reject.

| Family | Definition |
| --- | --- |
| Integers | Signed and unsigned 8, 16, 32, 64 and 128 bits; checked ranges |
| Floats | IEEE binary32/binary64, finite only; negative zero survives encoding |
| Decimal | Signed 128-bit coefficient, precision 1–38, scale 0–precision; exact base ten |
| Boolean | Exactly false or true |
| UTF-8 / binary | Valid UTF-8 without normalization / arbitrary bytes; lengths in bytes |
| Date | Signed days since 1970-01-01 in the proleptic Gregorian calendar |
| Time | Nanoseconds since midnight, 0 inclusive to 86400e9 exclusive; no leap seconds |
| Timestamp | Signed microseconds since 1970-01-01; descriptor distinguishes UTC instant from timezone-free civil time |
| Interval | Signed months, days and nanoseconds; components remain independent; no implicit duration ordering |
| UUID | Exactly 16 bytes, canonical textual spelling 8-4-4-4-12 hexadecimal |
| Struct | Ordered named fields, each with type, nullable and optional flags |
| List / fixed array | One element type and nullability; arrays have a positive declared length |
| Map | Entries in strictly increasing typed key order; non-null scalar keys |
| Tagged union | Ordered named alternatives; one tag and one typed cell |
| JSON | Valid UTF-8 JSON preserving numeric lexemes; duplicate object keys reject |

Enum, domain, opaque extension, spatial, arbitrary precision numeric and named
IANA timezone types are unsupported. UTC timestamps require no timezone database;
civil-to-instant conversion requires explicit application policy and is not an
implicit cast. Decimal support selects no currency or monetary rounding policy.
Schema depth, nodes, field-name bytes and encoded bytes have independent budgets.
Value depth, children, variable-width bytes and total work have separate budgets.
Exhaustion rejects the operation and publishes no successful prefix.

## Values and cell states

Value, null, missing, type error and conflict remain distinct. Nullability permits
null; optionality permits missing. A conflict preserves ordered nonzero assignment
identities and every value/null/type-error alternative; it cannot choose a winner.
Nested values obey the same state rules. Values borrow explicitly owned input or
allocator storage. Releasing that owner invalidates borrowed children.

Typed equality requires equal logical descriptors. Integers compare exactly;
finite floats compare numerically, so signed zeros are equal and hash identically.
Decimal coefficients compare at their declared scale without binary floating point.
UTF-8/binary/UUID use unsigned byte order. Structs, lists and arrays compare
lexicographically in declaration/element order when every child is comparable.
Maps have structural equality without a general ordering. Raw JSON equality,
hashing and ordering are not admitted; extraction requires a declared type. Intervals use
component equality without converting calendar months into elapsed days. Conflict
and type error never silently participate as ordinary values or nulls.

## Binding, casting, promotion and inference

These are separate operations with separate admission rules:

- Literal binding parses the target type and checks its complete grammar/range.
  It consumes all bytes, rejects surrounding whitespace and never parses an exact
  integer or decimal through floating point.
- Explicit casts check ranges. Lossless is the default; a rounding mode must be
  supplied for scale reduction or inexact binary conversion. Supported rounding
  modes are reject, toward zero and nearest ties to even. Overflow always fails.
- Expression promotion admits only a common type representing both input domains
  without loss. Mixed signed/unsigned integers may require a wider signed type;
  signed128 plus unsigned128 has no integer promotion. Integer/float mixing is
  not an automatic lossless promotion. Existing checked int64 SUM retains its
  source-order checks and result type.
- Inference unifies observations without changing textual identities. Canonical
  integer text may infer an integer; leading zeros, a plus sign and ambiguous
  formatting remain UTF-8. CSV decimals do not infer binary floats. JSON numbers
  retain exact integer/decimal values or raw JSON when outside the bounded exact
  domain. Null/missing alone do not establish a type. Heterogeneous values fall
  back to a lossless representation, never an implicit stringification of JSON.

An emitted schema never widens. Explicit conversions that cannot represent a
value produce a declared failure or type-error cell, never null. A sampled
candidate does not establish full-input conformance.

## Capability boundaries

The existing native query profile admits int64, uint64, finite float64, boolean,
UTF-8 and binary. Stored Tables, SQL literals, Flight and foreign SDK operations
retain their independently documented profiles until their owning codecs and
proofs admit an extension. Unsupported types reject before execution. Adding a
logical descriptor does not enable new SQL grammar or change stored Tables.

## Implemented local API and encoding

`transit_fuze.Types` implements descriptors, validation, fingerprints and canonical
`FTY1` encoding. `Semantics` implements scalar validation/binding, checked integer
and decimal casts, integer/float casts with reject or nearest-even policy,
float32/64 casts, integer/float/decimal domain promotion and conservative CSV text
classification. Float-to-integer, binary-float/decimal, temporal casts and interval
literal syntax reject. Recursive equality/hash/operator execution remains outside
this local codec profile. Date literals use years 0001–9999; timestamp literals
use `YYYY-MM-DDTHH:MM:SS[.fraction]`, with a required `Z` for UTC. Time fractions
have at most nine digits; timestamp conversion rejects nonzero submicroseconds.

`Values.Cell` validates nested states and canonical sorted maps. `Codec` encodes
and owns decoded values. `Json.parse` retains numeric lexemes and rejects malformed
JSON and duplicate decoded object keys. It accepts caller-owned allocation;
`Json.validate` uses a bounded 1 MiB scratch buffer. Neither performs I/O.

`FTY1` is magic, u8 definition-string length, UTF-8 definition, then one recursive
descriptor. The current definition is `transit.fuze.types.v1.2026-09-30`. Tags
1–27 are int64, uint64, float64, boolean, UTF-8, binary, int8, int16, int32,
int128, uint8, uint16, uint32, uint128, float32, decimal, date, time, timestamp,
interval, UUID, struct, list, array, map, tagged union and JSON. Scalars have no
parameters except decimal (u8 precision/scale) and timestamp (0 civil, 1 UTC).
Struct/union is u8 field count followed by each u8-length UTF-8 name, flags
(bit 0 nullable, bit 1 optional) and child descriptor. Lists encode a canonical
boolean nullable byte then child type; arrays prepend u32 length. Maps encode
key type then the value's nullable byte/type. Integers are little-endian.

`FVL1` is magic, u16 `FTY1` length and bytes, root flags, then one typed cell.
Cell states are 0 missing, 1 null, 2 type-error plus actual type tag, 3 value,
4 conflict. Conflict is u8 count and ordered alternatives, each u64 counter,
u64 replica and state 1/2/3 with its corresponding payload. Scalar integers use
their exact width; floats use IEEE bits; decimal uses signed i128 coefficient;
boolean is exactly 0/1; UTF-8/binary/JSON use u32 byte length; date/time/timestamp
use i32/u64/i64; interval uses i32 months, i32 days and i64 nanoseconds; UUID is
16 bytes. Structs encode cells in declaration order; lists/arrays encode u32
count then cells. Maps encode u32 count then key atom/value cell pairs. Unions
encode u8 alternative index and its cell. Trailing bytes always reject.

Default descriptor limits are 16 levels, 256 nodes, 4096 total name bytes,
255 bytes per name/fields per struct, and 16 KiB encoded descriptor. Value limits
are 16 levels, 65536 visited children and 1 MiB variable bytes; envelopes are at
most 2 MiB. Raw JSON separately limits a value to 64 KiB, 16 levels, 4096 syntax
tokens and 256 fields per object. Conflict count remains 2–8. These bound one
value/schema operation, not total source cardinality. Callers may supply stricter
validation budgets. Encoding and decoding enforce the default wire bounds.

## Neutral logical JSON

`LogicalJson` exposes an owned, validated JSON encoding independently of native
query transport admission. A type envelope is `{"definition":IDENTIFIER,"type":TYPE}`;
a value envelope is `{"definition":IDENTIFIER,"field":FIELD,"cell":CELL}`. The
identifier is the same mandatory current type definition as `FTY1`; missing or
foreign definitions reject. Duplicate/unknown fields and trailing input reject.

`TYPE` is an object with exactly one logical tag. Parameterless types have an
empty-object payload, for example `{"int64":{}}`. Decimal has `precision`/`scale`;
timestamp has `"civil"` or `"utc"`. Struct/union payloads are field arrays;
list has `type`/`nullable`; array has `length`/`element`; map has `key`/`value`.
Fields have `name`, `type`, `nullable` and `optional`; omitted flags default to
false. Element nullability also defaults to false. Logical validation and
descriptor fingerprints are identical to the binary codec.

`CELL` has exactly one of `missing:{}`, `null:{}`, `type_error:TAG`,
`value:VALUE`, or `conflict:[ALTERNATIVE...]`. Alternatives carry canonical
decimal-string `counter`/`replica` and a `value` cell restricted to null, type
error or value. `VALUE` selects `atom`, `structure`, `list`, `array`, `map`,
`tagged_union` or `json`. Struct/list/array contain cells in declared order;
maps contain `key` atoms and `value` cells; unions have integer `index` and
`value` cell; JSON contains the exact validated JSON text as a string.

Atoms select `signed`, `unsigned`, `decimal`, `float_bits`, `boolean`, `utf8`,
`binary`, `date_days`, `time_nanos`, `timestamp_micros`, `interval` or `uuid`.
All integers, decimal coefficients and temporal units use canonical decimal
strings without leading zeros, plus signs or negative zero. Boolean and UTF-8
use JSON boolean/string. Floats carry exact little-endian IEEE bytes as lowercase
hex (8/16 characters); binary and UUID use lowercase hex, UUID exactly 32
characters. Interval has decimal-string `months`, `days`, `nanos`. The declared
logical type checks each atom's variant/range. JSON numeric conversion never
rounds an integer or decimal through a host float.

Type JSON input is at most 64 KiB; value JSON is at most 256 KiB, with 96 syntax
levels and 32768 tokens before recursive logical budgets apply. Decoding owns
all descriptor/name/value bytes. Call `deinit()` exactly once. These JSON
bounds are transport bounds; a valid binary envelope can exceed them.
