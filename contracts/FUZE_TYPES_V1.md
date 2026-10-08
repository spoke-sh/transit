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

Type-error evidence uses `Types.Kind`, separately from descriptor `Types.Tag`.
Every logical kind retains its descriptor tag ID. Additional observed kinds are
`unknown` (0), `null_value` (28), Document `text` (29) and Document `character`
(30). An unknown decoder failure must not invent an actual scalar type. These
extra names cannot declare a column or payload type. Document `text` evidence is
distinct from the SQL TEXT alias, which declares UTF-8. A type error remains a
type error even when its observed kind is unknown or null.

`Values.fromQuery` validates and converts the six-scalar source profile into
logical cells, retaining all five states, every observed kind, complete ordered
conflict identities and exact scalar bits. Copied bytes and alternatives belong
to the supplied arena, which the caller releases after success or failure.

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
`FTY1` encoding. `Type.clone(allocator)` validates the descriptor and encoded-byte
budgets, then returns an independently owned descriptor with identical canonical
bytes and fingerprint. Its `Decoded` result owns names and recursive children in
an arena released by `deinit`; allocation failure releases partial copies.
`Semantics` implements scalar validation/binding, checked integer
and decimal casts, integer/float casts with reject or nearest-even policy,
float32/64 casts, integer/float/decimal domain promotion and conservative CSV text
classification. Float-to-integer, binary-float/decimal, temporal casts and interval
literal syntax reject. `Operations` supplies structural equality/hash and partial
lexicographic ordering; these traits do not add SQL operators. Date literals use
years 0001–9999; timestamp literals
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
The component's `encodeBound`/`decodeBound` helpers use exactly that final cell
payload when an enclosing versioned record already binds an exact immutable
descriptor and flags. Bound payloads contain no standalone type or definition
claim and are not an alternative FVL1 decoder. The enclosing owner must verify
its schema binding before decoding, with no current-schema or fallback inference.
The same recursive validation and 2 MiB encoded-value bound apply. Decoded cells
and bytes belong to the supplied request arena, including allocations retained
by a failed parse; releasing that arena releases all of them.
`Types.decodeInto`, `Type.cloneInto` and `Types.Codec.decodeBoundInto` expose the
same checks using a caller-supplied arena allocator for an enclosing request.
They return no independent owner: the caller releases that arena after either
success or failure. Their bytes, type/value bounds and definition checks are
identical to the separately owned entry points. Callers must not retain their
returned slices beyond that arena's lifetime.
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

The recursive [type schema](../packages/zig/transit-fuze/api/logical-type.schema.json)
and [value schema](../packages/zig/transit-fuze/api/logical-value.schema.json)
are reflected from the owning Zig declarations with `just contract::logical-generate`.
They validate structural shapes. Zig additionally validates ranges, descriptor
traits, canonical numeric strings, recursive budgets and cell/type agreement.

`station_logical_codec` and the local port's `logical_codec` action expose the
same pure `LogicalCodec` operations: capabilities, type/value JSON and canonical
binary decoding, scalar binding/casting, structural equality/order/hash and
single-value logical Arrow export. The generated Station action/result schemas
describe their envelopes. Embedded logical JSON remains a separately versioned
document string; binary fields use lowercase hex. Root field names normalize to
`value` because FVL1 identifies the root type/flags, not its presentation label.
Nested names remain part of descriptor identity.

The local codec admits requests/results up to 256 KiB and binary values up to
96 KiB; Arrow retains its existing 64 KiB segment, eight-row and 4 MiB workspace
bounds. Oversized values fail without a partial successful response. The C caller
owns the returned `station_buffer` independently of input buffers and frees it
once. A foreign definition returns `incompatible_version`; malformed documents
and unsupported operations fail before execution. `capabilities` explicitly
denies Arrow import/C Data, acquisition and durable file-query admission.
These additive exports/actions leave existing accepted query work and ABI
operations unchanged. A missing export or unknown port action rejects; it does
not select a fallback decoder.

`TYPE` is an object with exactly one logical tag. Parameterless types have an
empty-object payload, for example `{"int64":{}}`. Decimal has `precision`/`scale`;
timestamp has `"civil"` or `"utc"`. Struct/union payloads are field arrays;
list has `type`/`nullable`; array has `length`/`element`; map has `key`/`value`.
Fields have `name`, `type`, `nullable` and `optional`; omitted flags default to
false. Element nullability also defaults to false. Logical validation and
descriptor fingerprints are identical to the binary codec.

`CELL` has exactly one of `missing:{}`, `null:{}`, `type_error:KIND`,
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

## Structural operations

`Operations.supports(type, trait)` reports equality or ordering support after
descriptor validation. Equality/hash exclude JSON anywhere in the descriptor,
including an inactive union alternative. Ordering additionally excludes maps
and intervals. Support is a type property, not a value-dependent guess.

`eql(field, left, right)` compares two cells under the same descriptor/field
flags. Structural null equals null and missing equals missing; null and missing
are distinct. All values/active children validate first. Any type-error/conflict
rejects before short-circuit comparison, even when an earlier field differs.
Struct/array/list equality follows corresponding child cells. Maps compare
canonical typed keys and associated cells; intervals compare all components.
Unions compare their alternative index and selected cell. This structural
equality is separate from SQL comparisons, which skip null/missing operands.

`order` requires every active cell to contain a comparable value. A null/missing
child returns `UnorderedCell`; type-error/conflict fails independently. Structs
compare in field order; lists/arrays compare their common prefix then length;
unions compare alternative index then selected value. All active children are
checked before lexicographic short-circuiting. No implicit null sort order or
calendar-month conversion is introduced.

`hash(field, cell)` validates equality support and hashes structural meaning
without allocating a value copy. Equal cells under the same field have equal
hashes; signed floating zero normalizes to positive zero. Exact codecs preserve
the original sign. Root field names are excluded; descriptor field names/order,
parameters and root nullable/optional flags remain significant.

The SHA-256 input is the bytes `transit.fuze.structural-hash.v1` followed by NUL,
the 32-byte type fingerprint, two canonical root nullable/optional bytes, then
the structural cell. Each cell starts with its state byte; missing/null have no
payload. Signed/unsigned integer atoms use i128/u128 little-endian values;
decimal uses i128 coefficient; float uses its exact f64 representation after
zero normalization (float32 is exactly widened). Boolean uses one byte;
UTF-8/binary uses u64 length then bytes; date/time/timestamp/interval/UUID use
their neutral fixed-width payload. Struct/list/array/map begins with u64 child
or entry count and ordered children; map entries are key atom then value cell.
Union begins with its u8 index and selected cell. All lengths are little-endian.
JSON/error/conflict never enter this hash format. The mandatory type definition
inside the fingerprint separates incompatible logical meanings.
