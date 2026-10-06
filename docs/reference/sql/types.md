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

Recursive descriptor validation can retain an owned first-failure witness with
the exact descriptor-member path, violated rule, supplied values and measured
budget. File queries expose this context in human and structured diagnostics;
see the [schema-file guide](../../../apps/transit-cli/docs/file-query.md#schemas-and-exact-values).

General catalog Tables and native finite/session/durable queries carry these
logical descriptors and values. The enabled language SDKs own typed logical
models and use the shared neutral boundary; generated declarations alone do not
establish a caller capability. Logical Arrow exports preserve descriptors and
cell states. The local logical codec additionally exposes fingerprints and
selected checked casts; see the [SDK reference](../sdks.md).
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

## SQL types, aliases and constants

General Table declarations admit every logical family in the table below.
Canonical width spellings INT8/16/32/64/128 and UINT8/16/32/64/128 state their bit
width. SMALLINT means INT16; INTEGER/INT means INT32; BIGINT means INT64. INT8
always means eight bits. REAL means FLOAT32; DOUBLE PRECISION means FLOAT64;
BOOLEAN/BOOL, TEXT/UTF8 and unbounded VARCHAR/CHARACTER VARYING are aliases.
NUMERIC and DECIMAL declare exact decimal values. The complete alias and
parameter rules live in the [Table type resolver](../../../contracts/TABLE_SCHEMA_V1.md#scalar-sql-type-name-resolver).

DECIMAL defaults to precision 18 and scale 0, with precision 1–38 and scale
0–precision. VARCHAR(n) counts Unicode scalars and rejects excess length;
nested VARCHAR(n), CHAR padding, BINARY(n)/VARBINARY and FLOAT(p) reject because
they have no selected semantics. TIME defaults to nanosecond precision and
TIMESTAMP to microsecond precision. Civil and UTC timestamps are distinct;
TIME WITH TIME ZONE and named IANA zones are unsupported.

[CREATE TABLE](create-table.md) and typed DML bind constants directly to the
column descriptor. Strings use doubled single quotes; binary uses X'hex'.
Date/time/timestamp/UUID accept exact string forms. STRUCT, LIST, ARRAY, MAP,
UNION and INTERVAL constructors and JSON strings have the
[shared typed constant grammar](../../../contracts/TABLE_DDL_V1.md#type-and-literal-profile).
A storable nested value does not acquire a SQL comparison or aggregate operator.

Read SQL has a separately selected comparison-literal profile. Native general
Table comparisons bind constants to the declared scalar type. Explicit uint64
and float64 suffixes remain available; file and configured scalar-source query
profiles keep their documented exact scalar operands. SQL file-reading functions
are unsupported: the file-query command captures and binds inputs explicitly.
Accepted Document fields retain their explicit projection; Table JSON does not
add Document merge semantics or SQL JSON-path expressions.

## Cell states

Query cells retain a state as well as a declared type:

| State | Meaning | SQL behavior |
| --- | --- | --- |
| Value | A value of the declared logical type | `IS VALUE` selects it; comparisons require exactly typed operands |
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
and JSON values, logical Arrow IPC export, and typed values in the enabled SDKs. Storage, SQL operators and individual
transports retain separate admission limits. Parameters, traits and exact encodings are specified in the
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
| Zig logical types, neutral codecs and enabled typed SDK owners | All logical families above; exact owned values and selected conversions/traits |
| Zig file sources and local CLI | Frozen CSV/JSONL schemas up to 128 root fields; logical projection, selected scalar predicates, COUNT and int64 SUM; explicit host capture |
| Native finite/session/durable query plans | Logical schemas up to 128 columns over declared KV/Table/Document sources; no file acquisition |
| Catalog publication and stored Tables | General typed schemas, typed defaults, optional single/composite primary keys, selected CREATE/ALTER/DROP and atomic DML |
| Board and native/foreign query SDKs | Views/callers of the admitted native contracts; no separate inference authority or implicit write grants |
| Logical Arrow IPC export and native results | All logical families, exact type metadata and five-state wrappers; no logical IPC import or C Data admission |
| Flight SQL | Its configured primitive-int64 Table subset; logical native support does not widen Flight admission |
| Reactive Table transport | The explicitly qualified two-int64-column profile; general finite Table reads do not widen watch admission |

Missing or foreign format definitions reject before execution. Saved bindings
never infer a current identifier or reinterpret old work. Incompatible changes
follow the [v1 hard-cutover policy](../versioning.md).

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

The [performance reference](../performance.md#schema-on-demand-measurements)
separates source measurements from existing native query timings. DuckDB is a
pinned development comparator, without any Transit runtime dependency.
