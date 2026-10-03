# Bounded CSV and JSONL sources

`transit_fuze.FileSource` discovers and decodes CSV and JSONL over immutable byte
sources supplied by a host. It performs no filesystem or network access. The host
acquires a permitted version, supplies its SHA-256 and length, implements bounded
reads at an explicit offset, and checks current access and cancellation through
`Source.check`. A pathname or modification time is insufficient identity.

These are local Zig APIs. Native query transports, stored Tables, SQL consoles,
Board and Flight do not acquire file sources through this API. It supplies no
durable job admission, connector dispatch or automatic source capture. Compressed
or non-seekable inputs require a host that explicitly captures/decompresses them
under encoded/expanded/disk quotas into immutable seekable content. No such host
adapter is implicit in Fuze.
The explicit [CLI file-query host](../../../../apps/transit-cli/docs/file-query.md)
provides local acquisition, checked gzip and ephemeral unlinked disk captures.

## Discovery and execution

Call `FileSource.discover(allocator, sources, options, overrides)` to obtain an
owned `Binding`. Its schema is one `Types.Type.structure`. It records content,
options and schema commitments, discovery coverage and each root field's origin:
`inferred`, `specified` or lossless `raw`. Call `binding.deinit()` to release its
schema and copied options. The binding owns override/type/name/null-token bytes.
Source handles and their contexts remain owned by the host.

| Mode       | Behavior                                                                                            |
| ---------- | --------------------------------------------------------------------------------------------------- |
| `explicit` | Requires a complete field list; binds it without inferring types                                    |
| `sampled`  | Uses a prefix bounded separately by record count and bytes; optional overrides replace named fields |
| `full`     | Explicitly scans every source to discover a schema without retaining rows; work budgets still apply |
| `raw`      | CSV fields remain UTF-8; JSONL returns one `record` JSON column; overrides reject                   |

Inferred root/nested field names sort by decoded UTF-8 bytes. Multi-file CSV
headers align by exact names; input file order still determines row order.
Complete explicit schemas retain their declared field order. Empty/all-null
observations do not invent numeric types: known CSV fields fall back to UTF-8,
known JSON fields to JSON, and unresolved fieldless input requires explicit
fields or JSON raw mode. Header-only CSV can bind its named raw columns.

CSV inference recognizes canonical integer text through 128 bits and lowercase
`true`/`false`. Leading zeros, plus signs, negative zero, decimal/exponent text
and whitespace remain UTF-8. Explicit type overrides can deliberately convert
those fields. JSON strings remain strings; JSON numeric lexemes infer exact
integers/decimal128 where representable. Signed zero, out-of-range exact numbers
and heterogeneous values use JSON. Sparse object fields are optional; explicit
null is nullable. Lists infer their element type; mixed elements use JSON.

Create `FileSource.Scan.init(allocator, &binding, sources)` and call `next()` for
owned rows. Keep the scan at its final address once scanning begins, because its
CSV header slices borrow its own bounded storage. Each `Row` owns cells in an
arena and must be deinitialized. Release rows as they are consumed; retaining all
returned rows is a caller allocation decision, not a bounded streaming scan.
Call `scan.deinit()` on success, error or cancellation.

Every source read and buffered row disclosure rechecks the host callback. The
scan verifies actual source length and digest before setting `complete` at EOF.
Rows returned earlier are a provisional prefix. An error is terminal: later
`next()` calls fail, and `complete` stays false. A caller must not publish a
successful result before this terminal verification. Hosts that violate their
immutable-source promise can expose a failed prefix; hashing cannot retract bytes
already returned. Current policy remains a separate check from content identity.

`SourceCodec.encode` serializes a frozen binding. `decode` requires already
acquired matching source handles, validates the current mandatory definition and
all commitments, and rechecks current access. It never opens/refetches a source.
Saving a binding is not durable query acceptance or an authorization grant.

## Finite file plans

`FileQuery.compile(allocator, sql, source_name, &binding)` lowers the shared SQL
AST against a frozen binding and returns an owned `Compiled`. It shares column
resolution, projection, predicate and ordered aggregate semantics with the
native query profile. It supports finite SELECT, Boolean predicates, projection,
LIMIT, COUNT(*)/COUNT(column) and int64 SUM, including the existing restricted aggregate subquery.
SQL literals retain the native six-type admission rules: comparisons require
exactly matching types, without implicit source-dependent casts. Other logical
types can be projected; typed Zig plans can compare ordered scalar atoms with
an explicitly supplied matching type. General casts, nested access, joins and
additional SQL literal families are unsupported in this file-plan profile.
Explicit source aliases (`FROM input AS src`) also apply inside the restricted
aggregate input. The alias hides the original source qualifier. File plans reject
bare aliases. Rows, COUNT and SUM accept explicit output aliases, such as
`SELECT value AS amount FROM input` and `SELECT SUM(value) AS total FROM input`.
The SQL identifier rules match the [native SQL guide](unified-sql.md): names are
at most 16 bytes, unquoted names fold to lowercase and quoted names preserve case.
Distinct output names permit repeated input columns. Duplicate resulting names
reject, including collisions with an unrenamed column. An inner projection's
renamed columns are available to its outer aggregate; WHERE still resolves the
original source columns. Renaming preserves values, types and cell states.

Typed `FileQuery.Plan.output_names` is empty for default names, or contains one
optional name per projected output. A null entry retains the source name (or
`count`/`sum`). Typed names use the logical descriptor's UTF-8 rules and limits;
SQL names retain the narrower identifier rules above. The resulting descriptor,
including repeated recursive columns, must fit its existing 256-node and
4096-name-byte budgets. Typed plans borrow immutable name/vector storage;
`Compiled` owns copies independently of SQL text.

A plan binds the source commitment, complete schema, projection, predicate,
aggregate, limit and explicit output names into a fingerprint. Plans without
names retain their existing fingerprints; renaming changes identity. Names count
toward the existing 8192-byte fingerprint budget. Mutating borrowed names during
execution rejects before the next row. `Execution.init` checks that binding;
`next()` returns an owned projected row. Release each row, then deinitialize the
execution before releasing its borrowed plan/binding/source owners. The execution
must remain at its final address after scanning begins. The schema supports up
to 128 fields; explicit SQL column lists retain the shared parser's eight-column
bound. `SELECT *` and typed plans can project every field within the source bound.

All source rows are framed, converted and verified even after a projection,
predicate or limit discards them. A late malformed/unconvertible value therefore
prevents successful completion. Operator predicates/aggregates run only on rows selected
by the plan's limit; missing/null comparisons remain unknown through Boolean composition and skip SUM, while evaluated
type-error/conflict cells fail. SUM checks each int64 addition in source order;
empty SUM is null. Both COUNT forms return uint64 zero for empty input.
COUNT(*) counts selected rows; COUNT(column) counts top-level values of any
admitted logical type, skips missing/null and rejects error/conflict. A structured
value contributes one without counting its children. Skipped cells consume the
input LIMIT. Count addition checks u64 overflow. Aggregates are emitted only after source
verification; ordinary row results remain provisional until `complete` is true.
There is no retained result cache or automatic restart with a changed binding.

## Framing, values and failures

CSV uses an explicit ASCII delimiter/quote, doubled-quote escaping, header flag
and optional unquoted null tokens. No delimiter or header guessing occurs. LF
and CRLF terminate records outside quoted fields; quoted fields can contain
newlines. One UTF-8 BOM is recognized at source start. Quoted empty text is not
an unquoted null token. Bare CR, malformed quotes, ragged rows, duplicate/empty
names and invalid UTF-8 fail. With `header = false`, columns are named `column1`,
`column2`, and so on. Every field is decoded, including unprojected columns.

CSV accepts the scalar literal types implemented by `Types.Semantics.bind`.
Recursive, JSON and interval CSV type overrides reject before scanning. JSONL
accepts one object per nonempty line, including a final line without newline.
It rejects duplicate decoded keys, blank lines and malformed records. Nested
struct/list/array values use corresponding JSON shapes. Maps use JSON objects
whose keys bind to the declared scalar key type; entries sort by typed key and
converted duplicates reject. Tagged unions use exactly `{"tag":"name","value":...}`;
intervals use exactly `{"months":0,"days":0,"nanos":0}` with checked integer
components. Temporal/UUID atoms use JSON strings. Numeric atoms require JSON
numbers; strings do not silently become numbers.

Late unknown fields fail; schemas never widen during execution. By default,
incompatible values fail. `mismatch = type_error` preserves a conversion failure
as a typed error cell. It does not suppress malformed framing, unknown fields,
nullability/required-field violations, allocation/work limits, denial or
cancellation. No row is skipped. The schema's missing/null/value/error/conflict
model stays intact, although file readers do not create conflict assignments.

`Scan.position()` retains an owned `ValueDiagnostic` for the first terminal
conversion failure. It includes a 256-byte JSON Pointer path, a 128-byte input
scalar preview, exact scalar type parameters, known field rules and discovery
origin/evidence. Truncation is explicit. Nested structures follow schema order,
lists follow input order, and map conversion follows input-key order; converted
map keys are then sorted and checked for duplicates. Tolerated conversions clear
their sidecar before scanning continues. Allocation and source errors remain
errors and cannot become successful type-error cells.

`FileQuery.Execution.failure` retains the first operator failure's scan row,
column, operation, cell state and frozen binding/plan fingerprints. Predicate
instructions use the shared eager postfix evaluation order. The sidecar owns its
bytes after the failed row is released, allocates no diagnostic memory and
preserves the original error. It supplies no source value reconstructed from a
later read.

## Independent bounds

A binding has 1–128 source handles, at most 128 root fields, the type model's
256-node/4096-name-byte descriptor budget, and a 32 KiB saved encoding. These
bound one operation's metadata; they do not constrain a durable collection.

Defaults are 1024 sample records, 1 MiB sampled data, 1 GiB total declared source
bytes, 100 million records, and 64 KiB per record. Record/field limits may be
lowered, not raised past their supported maxima. Total work quotas are explicit
host options and may cover data larger than resident memory. Reads use an 8 KiB
chunk plus one record buffer. Discovery retains bounded schema evidence, not
sample rows; each JSON parse/row allocation is released before the next.
JSON separately limits depth to 16, syntax tokens to 4096 and fields per object
to the configured field limit. Values enforce their own child/byte budgets.

The [source contract](../../../../contracts/FUZE_SOURCE_V1.md) owns the binding
format. The [type contract](../../../../contracts/FUZE_TYPES_V1.md) owns descriptor
and cell formats. Independent fixture and allocator-failure commands live in
[the proof ledger](../../../../tests/README.md#fuze-bounded-file-sources).

Predicates combine comparisons and state tests with NOT, AND, OR and parentheses.
NOT binds before AND, then OR. Programs have at most 64 postfix instructions;
each atom/operator counts once. The same bounded evaluator as native plans
preserves unknown under NOT, evaluates atoms eagerly in source order and selects
only true. A false AND or true OR never suppresses an evaluated error or conflict.
All atoms validate before scanning, including branches that cannot select a row.

`FileQuery.Program` borrows immutable instructions and variable-width literals.
`Compiled` owns its program, literal bytes and schema independently of the SQL
input. Keep these owners alive through execution. Changing any program opcode,
atom, order or literal changes the plan fingerprint; changes during execution
fail before the next row. Fingerprints use at most 8192 encoded bytes, including
the whole plan and each literal's typed encoding. Each typed literal is at most
4096 bytes; satisfying that bound alone does not satisfy the complete fingerprint
budget. SQL keeps its 220-byte per-literal and 4096-byte statement bounds.
Existing single-atom fingerprints are unchanged. File programs do not change
native saved-plan encodings, language ABI layouts or file-source bindings.
