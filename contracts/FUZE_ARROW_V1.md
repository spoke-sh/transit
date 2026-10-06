# Fuze logical Arrow v1

This contract defines logical-value IPC export from `transit_fuze.LogicalArrow`
and `transit file-query --output arrow`, and canonical segment decoding through
`transit_fuze.LogicalInspect`. Native durable query results use this encoding
through the [unified query contract](UNIFIED_QUERY_V1.md); Flight retains its own
int64 output profile. Each source and transport owns its admission bounds.

## Schema and physical representations

The mandatory schema metadata `transit.definition` is
`transit.fuze.logical-arrow.v1.2026-09-30`. `transit.logical_schema` contains the
lowercase hex `FTY1` descriptor of the root struct, including the mandatory current
[logical type definition](FUZE_TYPES_V1.md). Logical meaning follows that
descriptor, never inference from an Arrow physical type. Missing/foreign
definitions cannot be interpreted as this profile. Arrow primitives alone do
not preserve every logical distinction.

Each root field is a non-null Arrow struct containing `state:uint8`, `kind:uint8`,
nullable `value:PAYLOAD`, and non-null `alternatives:list<ALTERNATIVE>`. State IDs
are missing 0, null 1, type-error 2, value 3, conflict 4. Kind is the logical tag
for a value or observed type-error kind, and zero otherwise. Type-error kind zero
means unknown; observed null/Document text/character use 28/29/30. These are not
descriptor tags. These kind semantics
belong to this explicitly identified logical profile. A non-value has a null
payload; only conflicts have nonempty alternatives. An alternative is a non-null
struct of `counter:uint64`, `replica:uint64`, `state:uint8`, `kind:uint8` and nullable
`value:PAYLOAD`. It admits only null/type-error/value and retains canonical ordered
nonzero assignment identities. No conflict winner is selected.

| Logical payload | Arrow representation |
| --- | --- |
| Signed/unsigned 8–64 bits | Matching signed/unsigned primitive width |
| Signed/unsigned 128 bits | Fixed-size binary 16, little-endian two's-complement/unsigned bits |
| Float32/64 | Float/double, finite IEEE bits including negative zero |
| Decimal | Decimal128 with exact declared precision/scale |
| Boolean, UTF-8, binary | Bool, string, binary |
| Date | Date32 days |
| Time | Time64 nanoseconds |
| Timestamp | Timestamp microseconds, timezone `UTC` or absent for civil |
| Interval | Month-day-nano interval, independent signed components |
| UUID | Fixed-size binary 16 in UUID byte order |
| JSON | String retaining the validated JSON text/numeric lexemes |
| Struct | Struct of named non-null cell wrappers in declared order |
| List / array | List / fixed-size list of non-null element cell wrappers |
| Map | Arrow map of non-null primitive keys and non-null value cell wrappers |
| Tagged union | Struct with non-null `tag:uint8` and non-null `variants:struct` |

Map entries retain logical typed-key order. Arrow `keys_sorted` is false because
the physical byte order of a 128-bit key need not match logical integer order.
The union's variants are named cell wrappers in declaration order. The selected
index holds its actual cell; inactive variants are canonical missing wrappers.
Inactive children below a null enclosing payload are also missing wrappers;
they do not override the logical field's requiredness. The enclosing state
controls disclosure. Array null payloads still reserve the fixed number of
physical children, as Arrow requires.

The top-level fields and every state/kind/alternatives/alternative member are
physically non-null. Logical nullable/optional rules remain in `FTY1`; physical
payload nullability also represents missing, type error, conflict and inactive
branches. Treating Arrow payload validity alone as the logical state loses data.

## Ownership, bounds and completion

Export validates the complete logical schema/cells before encoding. Each call
uses at most 4 MiB of caller workspace, at most eight rows and a 64 KiB output
segment. The source's 128-field and logical type/value budgets also apply.
These are independent bounds: a logically valid schema/row can exceed the Arrow
metadata, physical-child, workspace or segment budget. Array/list/map child
counts are capped at 65536 within one physical array. Excess rejects; constants
are not raised to fit a value. Nested wrappers and conflict payloads consume
metadata even when the corresponding value array is empty.

`encode` returns a complete schema/batch/end stream borrowed from caller output;
all internal Arrow ownership ends before return. Discard output on error. Exhausting the fixed encoding workspace reports
`ArrowWorkspaceExceeded`, separately from any host allocator failure. The codec
performs no external I/O or allocation through a host allocator.
`messages` can select schema, batch and end messages. A host may concatenate them
only for the same frozen schema, and may emit end only after verified completion.
There are no dictionary batches or hidden cross-call metadata/value caches.

The file-query host writes one schema, bounded record batches and an explicit
IPC end marker only after full source validation. Schema metadata also includes
`transit.binding`, `transit.plan`, decimal-string `transit.discovery_records`,
`transit.discovery_bytes`, and `transit.discovery_complete` as `true`/`false`.
Discovery completion is separate from query completion. Ordinary batches remain
provisional; a successful process exit and explicit end marker are both required.
Some Arrow readers accept EOF without an end marker, so reader acceptance alone
does not establish a completed query. No JSON records are mixed into this stream.

`--batch-rows` selects 1–8 rows, default 8. If a batch exceeds workspace/segment
capacity, the host splits that same ordered batch; a single oversized row fails.
It never changes schema, drops a row or restarts discovery. The caller releases
all owned rows after export or error.

## Canonical segment decoding

`LogicalInspect.decode` accepts exactly one complete plain schema/batch/end segment
from `LogicalArrow.encode`, with a supplied logical schema and expected row count.
It compares the canonical schema bytes, including both mandatory definitions,
before the IPC reader interprets input metadata. Different field names, types,
nullability, metadata or definitions reject. This is not a general third-party
Arrow importer: file-query streams with discovery metadata, multiple record
batches, dictionary batches and concatenated streams are outside this admission.

Decode enforces the same eight-row, 64-KiB segment and 4-MiB workspace limits.
It validates Arrow structure and the logical state/kind/payload relationships,
ordered conflict identities, map keys and complete row budgets. Recursive cells
consume one shared logical value budget per row. Inactive union wrappers must be
canonical missing; they do not consume the selected logical branch's node budget.
Missing end markers, incomplete input, extra batches and trailing bytes reject.

The returned `Batch` owns its descriptor, rows, names and all variable-width
values independently of input and workspace. Call `deinit` on success; failure
releases partial ownership and provides no batch. Workspace must not alias input.
Decoding establishes no authorization, publication or captured-source evidence.
The neutral ABI's logical IPC import, logical C data/stream export, Flight and
SDK Arrow extensions remain separate capabilities.
