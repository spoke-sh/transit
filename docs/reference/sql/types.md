# Data types and cell states

Native SQL reads the types in an explicitly declared query source. The local
[file-query command](../../../apps/transit-cli/docs/file-query.md) separately
resolves a frozen CSV/JSONL schema before compiling SQL. Neither creates a
resource from application bytes. Query types, SQL literal
syntax, offline declaration types and published Table schemas have different coverage.
The [surface capability matrix](#surface-capability-matrix) distinguishes these
interfaces; local type support does not widen every source or transport.

## Logical descriptor API

Fuze's Zig `Types` API supplies bounded descriptors for signed/unsigned integers
through 128 bits, finite float32/64, decimal128, boolean, UTF-8/binary, date, time,
civil/UTC timestamp, interval, UUID and recursive struct/list/array/map/union/JSON.
It supplies descriptor fingerprints, checked scalar literal binding, selected
explicit numeric casts, lossless domain promotion and an owned neutral value
codec. JSON parsing preserves numeric lexemes and rejects duplicate decoded keys.
Map entries use strictly increasing typed keys, rejecting duplicates including
positive/negative floating zero.

These are local type/codec APIs. Native query plans, catalogs, stored Tables,
native Arrow query transports and SDK queries accept the narrower profiles below.
Local file queries can export the rich values through the separately identified
[logical Arrow profile](../../../contracts/FUZE_ARROW_V1.md).
The native local codec and the
[Python](../../../packages/python/transit-station/docs/logical.md) and
[TypeScript](../../../packages/ts/transit-station-sdk/docs/logical.md) logical
document APIs expose owned values, fingerprints, casts and Arrow export. Other
language public query APIs keep their existing scalar profiles; generated ABI
declarations alone do not establish idiomatic logical value support.
`Types.Operations` supplies validated structural equality/hash and partial
lexicographic ordering. Structural null/missing equality remains distinct from
SQL predicates; errors/conflicts never become ordinary values. JSON has no
equality/hash/order trait; maps and intervals have equality/hash only. General
SQL casts and nested comparison syntax remain unsupported. Fuze's local Zig
[file-source API](../../../packages/zig/transit-fuze/docs/file-sources.md)
supplies explicit, sampled, full and raw CSV/JSONL discovery/decoding. Native
query transports do not acquire those sources. Local `FileQuery` plans and the
file-query command can project their logical values, with exactly typed six-scalar
SQL comparison literals and int64 SUM. See the [type contract](../../../contracts/FUZE_TYPES_V1.md)
for precise admitted conversions, temporal representations and resident bounds.

## Scalar types

| Query v1 type | Read a declared column | SQL comparison literal | Offline declaration token |
| --- | --- | --- | --- |
| int64 | Yes | Signed decimal integer, such as `-42` | `INT64` |
| uint64 | Yes | `'18446744073709551615'::uint64` | None |
| float64 | Yes | `'1.25e2'::float64` | None |
| boolean | Yes | `TRUE`, `FALSE` | `BOOL` |
| UTF-8 | Yes | Single-quoted text, such as `'ready'` | `UTF8` |
| binary | Yes | Hex bytes, such as `'\x00ff'::bytea` | `BINARY` |

The last column applies to the shared offline [CREATE TABLE](create-table.md)
and [CREATE KV](create-kv.md) compiler. Compilation validates a definition; it
does not provision a resource. The separate catalog operation can publish a
compatible empty Table under current permission. KV publication is unavailable.
Its Table adapter requires
exactly two columns: an int64 non-null key and a nullable value of int64, boolean,
UTF-8 or binary, with explicit nullability. Other valid offline definitions do
not establish storage support. See the
[state declaration contract](../../../contracts/STATE_DECLARATION_V1.md).
Types available to a typed query plan do not automatically acquire SQL literal,
DDL, mutation or transport support. There are no implicit conversions; a
comparison must match the column's exact scalar type.

The signed integer range is -9223372036854775808 through 9223372036854775807.
Decoded SQL text/binary literal cells have a 220-byte bound. See
[syntax and literals](syntax.md#query-literals) for escaping and parser bounds.

SQL has no `DECIMAL`, date, time, timestamp, interval, array, map or JSON type
syntax. SQL file-reading functions are unsupported; the file-query command
captures and binds inputs explicitly before SQL compilation.
Accepted Document fields can be exposed through an explicit scalar
projection; this does not add JSON path expressions to SQL. The interface does
not choose a fixed-point representation for application monetary values.

## Cell states

Query cells retain a state as well as a declared type:

| State | Meaning | SQL behavior |
| --- | --- | --- |
| Value | A value of the declared scalar type | `IS VALUE` selects it; comparisons require exactly typed operands |
| Null | Explicit absence of a value | `IS NULL` selects it |
| Missing | No value at a declared projection or optional field | `IS MISSING` selects it; distinct from null |
| Type error | The source cannot supply the declared type | `IS TYPE_ERROR` selects it; preserved in row results |
| Conflict | The source carries an unresolved conflict | `IS CONFLICT` selects it; alternatives remain intact |

`COUNT(*)` counts rows in every cell state and returns uint64, including zero
for empty input. `SUM(column)` accepts int64 values, skips null/missing, fails on
error/conflict and returns null for empty or all-skipped input. Overflow fails.
See [functions and operators](expressions.md) for the available SQL operations.

## Result interfaces

Query v1 returns nested typed cells through Arrow. The selected
[Flight SQL profile](../flight.md) instead exposes primitive int64 columns over
its configured Table subset and checks conversion of counts. A type supported
by native query v1 does not imply support through every SQL transport. See
[Arrow interchange](../arrow.md) and the
[query contract](../../../contracts/UNIFIED_QUERY_V1.md).

## Logical family capabilities

All families below have canonical descriptors/fingerprints, owned neutral binary
and JSON values, logical Arrow IPC export, and the local Python/TypeScript codec
APIs. These capabilities do not imply storage, SQL syntax or native transport
admission. Parameters, traits and exact encodings are specified in the
[type contract](../../../contracts/FUZE_TYPES_V1.md).

| Family | Values and operations | File decoding |
| --- | --- | --- |
| Signed/unsigned integers | 8/16/32/64/128 bits; exact binding, checked integer/decimal casts and lossless domain promotion | CSV text; JSON numeric lexemes |
| Floats | Finite binary32/64; bit-preserving codecs, numeric equality with equal signed zeros; checked selected casts | Explicit CSV/JSON types; inference never silently rounds exact numbers to floats |
| Decimal | Signed 128-bit coefficient, precision 1–38, scale 0–precision; explicit reject/toward-zero/nearest-even rounding | Explicit CSV; exact JSON numbers within precision bounds |
| Boolean, UTF-8, binary, UUID | Exact booleans; validated UTF-8 without normalization; byte order for strings/binary/UUID | Scalar literal decoding; UUID requires canonical textual shape |
| Date, time, timestamp | Gregorian days, nanoseconds since midnight, microsecond civil/UTC timestamps; no implicit timezone conversion | Explicit string literals; inference leaves date-like strings as text |
| Interval | Independent signed months/days/nanoseconds; equality/hash, no total duration ordering | JSON object with explicit components; CSV unsupported |
| Struct, list, fixed array | Recursive five-state cells; validated structural equality/hash and partial lexicographic order | Corresponding JSON shapes; CSV unsupported |
| Map, tagged union | Sorted unique typed map keys; map equality/hash; explicitly tagged union values | Declared JSON object/tag shapes; CSV unsupported |
| JSON | Validated raw JSON with exact numeric lexemes and duplicate-key rejection; no equality/hash/order trait | Whole-record JSONL raw mode or heterogeneous inferred fields; CSV unsupported |

Enum, domain, opaque extension, spatial, arbitrary precision numeric and named
IANA timezone types are unsupported. Float-to-integer, binary-float/decimal and
temporal casts reject. General decimal arithmetic and additional aggregates are
unsupported. Decimal types select no monetary policy; temporal types add no
continuous-query/event-time behavior. Nested query values are separate from
mutable Document identities and merge semantics.

Descriptors have independent limits of 16 levels, 256 nodes, 4096 total name
bytes and 16 KiB encoded bytes. Values have 16 levels, 65536 visited children and
1 MiB variable bytes; transport envelopes impose additional limits. The local
codec boundary accepts 256 KiB requests/results and up to 96 KiB binary values.
Logical Arrow keeps a 4 MiB workspace, 64 KiB segments and at most eight rows per
batch. A value can be valid logically and too large for a selected transport.

## Surface capability matrix

| Surface | Admitted types and behavior |
| --- | --- |
| Zig logical types, neutral codecs and local Python/TypeScript codec owners | All logical families above, with the selected conversion/trait operations; no acquisition or durable admission |
| Zig file sources and local CLI | Frozen CSV/JSONL schemas up to 128 root fields; logical projection, exactly typed scalar predicates, COUNT and int64 SUM; explicit host capture |
| Native finite/session/durable query plans | Existing six-scalar profile, explicit KV/Table/Document sources and one to eight columns; no file-source admission |
| SQL literals and offline declarations | The exact scalar/token table above; a parsed declaration does not create storage |
| Catalog publication and stored Tables | Declared int64 key and one nullable int64/boolean/UTF-8/binary value; historical/richer schemas remain separately scoped |
| Board and native/foreign query SDKs | Views/callers of the admitted native contracts; no file acquisition or separate inference authority. Other language SDKs do not advertise rich logical owners merely because an ABI declaration exists. |
| Logical Arrow IPC export | All logical families plus exact type metadata and five-state wrappers; no logical IPC import or C Data admission |
| Native Arrow and Flight SQL | Native six-scalar query profile with cell states; Flight retains its primitive-int64 Table subset |

Adding a local type or codec action leaves existing accepted native query work,
stored formats and operation meanings unchanged. The new logical type/source/
Arrow documents require their own exact current definitions. Missing or foreign
definitions reject before execution; saved bindings never infer a current
identifier or reinterpret old work. Future incompatible changes follow the
[v1 hard-cutover policy](../versioning.md).

## Schema discovery and binding

Schema on demand resolves one explicit interpretation before publishing rows.
The host first acquires immutable content with a verified length/SHA-256 and
current access checks. Fuze performs no file or network I/O. The local CLI
captures regular files, gzip or stdin into private, unlinked disk files under
separate encoded/expanded quotas. These captures are ephemeral, with no durable
job recovery or implicit refetch on replay.

| Mode | Schema resolution |
| --- | --- |
| Explicit | Complete caller-supplied fields and types, without inference |
| Partial | Named type overrides plus sampled/full discovery for remaining fields |
| Sampled | A prefix bounded independently by bytes and records; coverage remains visible |
| Full | Every selected source contributes before schema publication; work quotas still apply |
| Raw | CSV fields remain decoded text/null; JSONL exposes the original JSON record |

CSV uses explicit dialect/header/null settings. It preserves leading-zero,
plus-prefixed, decimal/exponent and otherwise ambiguous text as UTF-8 during
inference. JSON strings remain strings; numbers infer exact integers/decimals
or retain JSON when outside the bounded exact domain. Missing and null have
separate flags. Heterogeneous values retain JSON; nested field fallback can
normalize whitespace/escaping while preserving JSON values and numeric lexemes.
Empty/all-null observations require an override or the documented raw fallback,
not a guessed numeric type. Duplicate names/decoded keys reject.

A frozen binding commits ordered source identities, options, schema, per-field
origins and sampling evidence. Multi-file headers align by exact name; file order
still determines row order. Defaults are 1024 sampled records, 1 MiB sampled
bytes, 1 GiB total source bytes and 100 million records. A binding admits up to
128 files/fields and 64 KiB per record, with additional recursive budgets.
These are separate work, metadata and resident-buffer bounds.

Every row is framed, converted and validated, including fields/rows discarded by
projection, predicates or LIMIT. A late incompatible value follows the selected
failure/type-error policy. Unknown fields, malformed input, denial, cancellation
and exhausted budgets always fail; no row disappears and no emitted schema
widens. Rows remain provisional until length/digest verification at EOF. A saved
binding requires already captured matching handles and current permission; it
cannot open a pathname or create authorization. See the
[file-source guide](../../../packages/zig/transit-fuze/docs/file-sources.md) for
ownership, exact modes and failures, and the
[source contract](../../../contracts/FUZE_SOURCE_V1.md) for neutral encoding.

The [performance reference](../performance.md#planned-schema-on-demand-comparisons)
separates source measurements from existing native query timings. DuckDB is a
pinned development comparator, without any Transit runtime dependency.
