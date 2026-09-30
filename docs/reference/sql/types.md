# Data types and cell states

SQL reads the types in an explicitly declared query source. It does not infer a
schema from application bytes or create a resource. Query types, SQL literal
syntax, offline declaration types and published Table schemas have different coverage.
The [planned type system and schema discovery](#planned-type-system-and-schema-discovery)
below describe work that is not implemented; the scalar and cell-state sections
describe current behavior.

## Logical descriptor API

Fuze's Zig `Types` API supplies bounded descriptors for signed/unsigned integers
through 128 bits, finite float32/64, decimal128, boolean, UTF-8/binary, date, time,
civil/UTC timestamp, interval, UUID and recursive struct/list/array/map/union/JSON.
It supplies descriptor fingerprints, checked scalar literal binding, selected
explicit numeric casts, lossless domain promotion and an owned neutral value
codec. JSON parsing preserves numeric lexemes and rejects duplicate decoded keys.
Map entries use strictly increasing typed keys, rejecting duplicates including
positive/negative floating zero.

These are local type/codec APIs. SQL, native query plans, catalogs, stored Tables,
Arrow query transports and SDK queries accept the narrower profiles below.
Recursive comparison/hash operations and general SQL casts are not enabled by a
descriptor. Fuze's local Zig [file-source API](../../../packages/zig/transit-fuze/docs/file-sources.md)
supplies explicit, sampled, full and raw CSV/JSONL discovery/decoding. Native
query transports and SQL do not acquire those sources. See the [type contract](../../../contracts/FUZE_TYPES_V1.md)
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
syntax. SQL file readers and schema inference are unsupported; local Zig callers use
the separately scoped file-source API above.
Accepted Document fields can be exposed through an explicit scalar
projection; this does not add JSON path expressions to SQL. The interface does
not choose a fixed-point representation for application monetary values.

## Cell states

Nested query cells retain a state as well as a scalar type:

| State | Meaning | SQL behavior |
| --- | --- | --- |
| Value | A value of the declared scalar type | `IS VALUE` selects it; comparisons require exactly typed operands |
| Null | Explicit absence of a value | `IS NULL` selects it |
| Missing | No value at the declared Document projection | `IS MISSING` selects it; distinct from null |
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

## Planned type system and schema discovery

**Status: public query-surface expansion is planned.** The local logical
descriptor, codec and file-source APIs above implement bounded discovery/decoding. The objective is a comprehensive shared
type system that also makes ad hoc CSV and JSONL queries useful without requiring
an import or a complete handwritten schema first. Schema on demand means
deriving a bounded, explicit interpretation when opening a source. It does not
mean changing the meaning of a running query as more rows arrive. The following
requirements introduce no executable SQL syntax, reader options or wire fields.

### Planned type coverage

Logical types describe values and operations; physical layouts describe buffers,
offsets and encodings. The planned shared Zig model separates them so an integer
column can retain a specialized execution path even when another column contains
nested values. Each family needs explicit declaration, expression, source,
storage, Arrow and SDK capability entries; adding a type to Fuze alone cannot
enable every consumer.

| Planned family | Semantics required before support |
| --- | --- |
| Signed and unsigned integers | Widths from 8 through 64 bits, with 128-bit support evaluated explicitly; range checks, signed/unsigned promotion and accumulator widths |
| Floating point | Float32/float64 conversion and rounding; a deliberate decision on non-finite values; preserve the current finite float64 and negative-zero behavior until a coordinated change |
| Exact decimal | Precision/scale bounds, physical width, arithmetic result types, rounding, overflow and canonical encoding; never route exact values through binary floating point |
| Boolean, UTF-8 and binary | Validation, byte versus character length, equality/order/hash, explicit collation policy and conversion errors |
| Date, time, timestamp and interval | Units/ranges, calendar rules, civil time versus instants, offsets/zones and timezone-data identity, daylight-saving ambiguity and interval arithmetic |
| UUID | Validated syntax, canonical bytes, equality and ordering |
| Struct, list, fixed array and map | Field identity/order, optionality, element types, map key equality/duplicates, bounded nesting and variable-size children |
| Tagged union and JSON | Explicit alternatives or raw JSON representation, numeric fidelity, duplicate-key policy and typed extraction; no universal implicit string conversion |
| Enum, domain and extension types | Explicit scope decisions, identity/constraints and serialization rules before admission; not automatically included by claiming comprehensive types |

Decimal capability does not choose an application's currency, scale or monetary
rounding policy. Temporal values do not establish event-time windows, watermarks,
lateness or continuous queries. Nested query values are distinct from mutable
Document object identities and CRDT merge semantics.

The planned semantic contract distinguishes four operations: binding a literal,
explicit casting, promotion within an expression, and unifying observations
during inference. Each needs a deterministic compatibility/error table. A wider
physical type does not necessarily give a lossless conversion: float64 cannot
represent every uint64. Failed conversions must have a defined error or typed
cell outcome, not silently become null. Value, null, missing, type error and
conflict remain distinct, including inside nested values. Comparisons, hashing,
grouping and aggregates must agree on the chosen equality and error rules.

### Planned discovery and binding

The proposed source modes are a complete explicit schema, partial type overrides
with discovery of remaining fields, bounded sampling, deliberate full-input
discovery, and a lossless raw mode. Raw CSV fields remain text; raw JSON retains
its JSON representation rather than flattening every value to a string. These
are requirements, not available reader options.

1. Acquire an authorized source identity and immutable content/version basis.
   A pathname, modification time or unverified remote tag alone is insufficient
   to promise repeatable bytes. A non-seekable input needs bounded buffering or
   an explicitly authorized durable spool with quotas, or a stated unsupported
   replay mode. Discovery and execution must read the same basis.
2. Detect framing and collect evidence within separate byte, record, field,
   depth, file-count and work budgets. Record dialect, encoding, null tokens,
   numeric/date formats, sampling locations and algorithm definition. Sampling
   does not prove the remaining input conforms. Empty/all-null inputs and
   ambiguous text require an explicit unresolved/raw outcome or an override.
3. Resolve one schema using deterministic inference rules and user overrides.
   Review metadata identifies inferred versus specified fields and the evidence
   coverage. Freeze that schema and its fingerprint before emitting typed output;
   discovery alone creates no resource, grants or external effects.
4. Decode bounded batches under the frozen interpretation. A late incompatible
   value or unseen field follows the selected fail/error/raw-preservation policy.
   It cannot silently widen an emitted column, disappear, or restart a query
   under the same accepted identity with different meaning. Any later re-inference
   is a new explicit binding. Failed prefixes never become complete results.

The future schema fingerprint must cover recursive type parameters, field
identity/order and relevant semantic definitions. The source contract separately
binds content identity, decoder/inference definition, resolved schema, reader
options and sampling evidence. Cached inference is reusable only for a matching
basis and options under current permission. Historical binding and retained
requests must keep their original interpretation.

CSV needs explicit rules for delimiters, quoting/escaping, multiline records,
headers and duplicate names, encoding/BOM, empty fields versus null tokens,
ragged rows and numeric/date ambiguity. For example, `00123` can be an identifier;
a numeric guess cannot establish the application's intent. JSONL needs rules for
record framing, duplicate keys, absent versus null fields, numeric precision,
heterogeneous arrays, empty containers, nested shape changes and unusually large
records. Multi-file discovery needs deterministic file/field ordering, bounded
metadata and explicit name alignment and missing-field behavior. Compression
and non-seekable sources must expose their different sampling and replay costs.

### DuckDB comparison

DuckDB is a comparison system for usability, semantics and measurements, not a
Transit runtime dependency or an assertion of SQL compatibility. The linked
upstream documentation describes its current 1.5 profile when consulted on
2026-09-30; a benchmark must pin the actual release/build and options.

| DuckDB behavior | Planned Transit evaluation |
| --- | --- |
| CSV dialect/header/type detection, configurable samples, type overrides, raw text mode and inspectable `sniff_csv` output | Compare discovery cost and reviewable resolved schemas, including ambiguous headers and late outliers |
| CSV sampling can seek through ordinary files; compressed/non-seekable inputs sample the prefix | Compare coverage and time to first batch separately by input capability |
| JSON/NDJSON discovery supports explicit columns, sampling/depth controls, multi-file name unification and struct/map inference controls | Evaluate nested fidelity, sparse fields, heterogeneous values and bounded inference metadata |
| JSON reader missing fields become SQL null | Preserve Transit's separate missing state; classify this as a semantic difference in comparisons |
| Broad scalar/nested types and distinct ordinary versus combination casts | Define Transit's own type and promotion tables; parser or type-name overlap does not establish equivalence |

Sources: [CSV detection](https://duckdb.org/docs/current/data/csv/auto_detection),
[JSON loading](https://duckdb.org/docs/current/data/json/loading_json),
[type families](https://duckdb.org/docs/current/sql/data_types/overview) and
[casting](https://duckdb.org/docs/current/sql/data_types/typecasting).
The [performance plan](../performance.md#planned-schema-on-demand-comparisons)
defines the proposed comparison method. No Transit CSV/JSONL benchmark or DuckDB
performance parity is established by these references.

### Ownership and compatibility

Fuze owns pure type checking, conversion and execution. Source adapters own
authorized acquisition and interpretation; Station/catalog owners govern durable
definitions and publication. SQL, CLI, Board and SDKs share these contracts rather
than implementing separate inference or coercion rules. File/network reads belong
outside the deterministic engine and native authority. Durable external capture
requires recorded intent/outcome rules; replay cannot refetch changed input.

Arrow encodings and neutral binding resources need exact per-type mappings,
ownership rules and independent round trips before support is advertised. Flight
retains its narrower profile until separately extended. Incompatible stored,
wire or ABI semantics require the existing [v1 hard cutover](../versioning.md):
replace the shared definition, migrate consumers and fixtures together, and reject
missing/foreign definitions before execution. Never reinterpret old accepted work
or default a persisted compatibility field to the new definition.
