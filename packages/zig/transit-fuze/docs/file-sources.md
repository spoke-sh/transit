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

## Discovery and execution

Call `FileSource.discover(allocator, sources, options, overrides)` to obtain an
owned `Binding`. Its schema is one `Types.Type.structure`. It records content,
options and schema commitments, discovery coverage and each root field's origin:
`inferred`, `specified` or lossless `raw`. Call `binding.deinit()` to release its
schema and copied options. The binding owns override/type/name/null-token bytes.
Source handles and their contexts remain owned by the host.

| Mode | Behavior |
| --- | --- |
| `explicit` | Requires a complete field list; binds it without inferring types |
| `sampled` | Uses a prefix bounded separately by record count and bytes; optional overrides replace named fields |
| `full` | Explicitly scans every source to discover a schema without retaining rows; work budgets still apply |
| `raw` | CSV fields remain UTF-8; JSONL returns one `record` JSON column; overrides reject |

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
