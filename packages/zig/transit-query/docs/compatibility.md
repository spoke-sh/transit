# Query compatibility and protocol handoff

This matrix defines supported sources, clients and wire formats for each query
interface. Query engine, result representation and transport versions are
separate compatibility requirements.
[HTTP serving](../../../../docs/reference/serving.md),
[reactive APIs and refresh](../../../../docs/reference/reactive.md) and
[Flight](../../../../docs/reference/flight.md) have separate interface contracts.
Flight adapts the current query v1 implementation to its finite int64 Table
endpoint. It validates the verified native result before producing primitive Arrow.

| Surface | Current query v1 |
| --- | --- |
| Source | Declared KV decoders, exact Table schema, or accepted Document reference/projections |
| Plan/result identity | `UQS1` source, `FZP1` plan, `UQB1` bundle, `UQM1` manifest |
| Submission | Finite authenticated Publication upload; 16 KiB canonical bundle, 128-byte parts |
| Values | Six scalar types and five explicit cell states in nested Arrow |
| Reads | Current authorized publication reads with ordered digest/row/byte verification |
| Shell | `transit query CONFIG`; explicit frozen bundle/token recovery |
| Board | Separate `query` credentials; one configured source and budgets |
| Language callers | Public SDKs over the shared Zig native/port implementation |
| Flight / Flight SQL / ADBC | Int64 Table projection/count/sum; explicit checked conversion to primitive Arrow, as defined by the [client/type matrix](../../transit-flight/docs/compatibility.md) |

The [hard-cutover policy](../../../../docs/reference/versioning.md) applies.
Unknown formats and changed declarations reject; retained data is never guessed
into a compatible decoder. Neither publication references nor continuation
cursors confer authority. Host/provider placement does not change a contract.

| Source | Scalar values | Exceptional states and ordering | SQL declaration |
| --- | --- | --- | --- |
| KV | Binary, UTF-8, little-endian int64/uint64, finite float64, canonical boolean byte | Invalid declared decoding yields type error; bytewise key order | Explicit prefix and independently versioned key/value decoders |
| Table | Existing exact key/value schema; adapter validates it | Nullable value, signed primary-key order | Exact Table identity/schema |
| Document | Accepted scalar paths, bounded materialized text, optional list expansion and element IDs | Missing/null/type error/conflict stay distinct; accepted sequence order, including empty continuation pages | Exact document/epoch/type/change-format/revision and declared projections |

All native Arrow columns use a non-null struct with state, actual kind, nullable
value and a non-null alternative list. Integers keep all 64 bits, finite float64
keeps negative zero, binary stays bytes and text stays UTF-8. Conflicts retain
ordered assignment counter/replica IDs and each alternative's state. A plain
nullable Arrow column cannot represent this contract losslessly. A compatible
transport must expose this layout or define and test an explicit conversion;
client support for primitive Arrow alone is insufficient.

The typed plan supports one comparison or a cell-state test, ordered projection,
limit, count and checked int64 sum. SQL uses the existing parser and exposes only
its supported subset: star or one to eight named columns, one exact-type comparison or
`IS NULL`, row output, `COUNT(*)`, and int64 `SUM`. Uint64/float64 comparisons and
all five state tests are available through typed plans; SQL has no corresponding
numeric literals or general state-test syntax yet. `IS NULL` selects only explicit
null, and comparison to a NULL literal rejects. There are no casts, joins, sort,
general pushdown, rewrites, continuous queries or implicit application decoders.

The engine advances eight rows per page with at most eight columns. Scalars are
bounded at 4096 bytes; Arrow segments at 64 KiB with 4 MiB caller-owned workspace.
Document adapters add bounded path/list/text traversal; source hosts allocate a
1 MiB adapter arena. Total accepted work is governed by explicit current-policy
page/segment/byte budgets and durable progress, not a fixed resident row count.
Input commit, completed capture, final manifest, returned prefix and verified
complete coverage are distinct observations.

Ingress must preserve frozen mutation identity after lost responses,
current authority checks before and after disclosure, owned result lifetime,
ordered error/overflow behavior and explicit cancellation. Closing a local
handle or network stream cannot promise cancellation of accepted durable work.
Keep transport attempts separate from newly completed queries in service signals.
