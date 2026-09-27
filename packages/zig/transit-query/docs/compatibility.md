# Query compatibility and protocol handoff

This matrix describes the implemented query contracts. Qualification is tracked
in the [proof guide](../../../../tests/README.md#m18-work-in-progress); a planned
transport does not become available by sharing an engine. Planned
[HTTP serving M19](../../../../docs/roadmap/M19.md),
[reactive APIs M20](../../../../docs/roadmap/M20.md),
[reactive refresh M21](../../../../docs/roadmap/M21.md) and
[Flight M22](../../../../docs/roadmap/M22.md) have separate qualification gates.

| Surface | Public Table v1 (M13) | Unified v2 (M18) |
| --- | --- | --- |
| Source | Exact Table schema: int64 key plus one nullable value | Declared KV decoders, exact Table schema, or accepted Document reference/projections |
| Plan/result identity | `FZP1`, original `GQM2` result | `UQS2` source, `FZP2` plan, `UQB2` bundle, `UQM2` manifest |
| Submission | Original bounded Station request | Finite authenticated Publication upload; 16 KiB canonical bundle, 128-byte parts |
| Values | Original two-column schema and null interpretation | Six scalar types and five explicit cell states in nested Arrow |
| Reads | Original captured-segment delivery | Current authorized publication reads with ordered digest/row/byte verification |
| Shell | `transit query CONFIG` | `transit query-v2 CONFIG`; explicit frozen bundle/token recovery |
| Board | Separate `query` credential/configuration | Separate `query_v2`; one configured source and budgets, explicit submission |
| Language callers | Existing SDK Table/Station APIs | All ten M11 SDKs over the same Zig native/port implementation |
| Flight / Flight SQL / ADBC | No implemented endpoint | No implemented endpoint; these protocols need M22 qualification |

V1 is not upgraded in place. Its compiler, retained result interpretation,
request limits and SQL null behavior remain unchanged. V2's version and digest
checks reject unknown versions and changed declarations rather than guessing a
compatible decoder. Neither publication references nor continuation cursors
confer authority. Host/provider placement does not change a protocol version.

| Source | Scalar values | Exceptional states and ordering | SQL declaration |
| --- | --- | --- | --- |
| KV | Binary, UTF-8, little-endian int64/uint64, finite float64, canonical boolean byte | Invalid declared decoding yields type error; bytewise key order | Explicit prefix and independently versioned key/value decoders |
| Table | Existing exact key/value schema; v2 adapter validates it | Nullable value, signed primary-key order | Exact Table identity/schema |
| Document | Accepted scalar paths, bounded materialized text, optional list expansion and element IDs | Missing/null/type error/conflict stay distinct; accepted sequence order, including empty continuation pages | Exact document/epoch/type/change-format/revision and declared projections |

All v2 Arrow columns use a non-null struct with state, actual kind, nullable
value and a non-null alternative list. Integers keep all 64 bits, finite float64
keeps negative zero, binary stays bytes and text stays UTF-8. Conflicts retain
ordered assignment counter/replica IDs and each alternative's state. A plain
nullable Arrow column cannot represent this contract losslessly. A future
transport must expose this layout or declare and qualify an explicit conversion;
client support for primitive Arrow alone is insufficient.

The typed plan supports one comparison or a cell-state test, ordered projection,
limit, count and checked int64 sum. SQL uses the existing parser and exposes only
its qualified subset: star or two named columns, one exact-type comparison or
`IS NULL`, row output, `COUNT(*)`, and int64 `SUM`. Uint64/float64 comparisons and
all five state tests are available through typed plans; SQL has no corresponding
numeric literals or general state-test syntax yet. `IS NULL` selects only explicit
null, and comparison to a NULL literal rejects. There are no casts, joins, sort,
pushdown, rewrites, continuous queries or implicit application decoders.

The engine advances eight rows per page with at most eight columns. Scalars are
bounded at 4096 bytes; Arrow segments at 64 KiB with 4 MiB caller-owned workspace.
Document adapters add bounded path/list/text traversal; source hosts allocate a
1 MiB adapter arena. Total accepted work is governed by explicit current-policy
page/segment/byte budgets and durable progress, not a fixed resident row count.
Input commit, completed capture, final manifest, returned prefix and verified
complete coverage are distinct observations.

Future ingress must preserve frozen mutation identity after lost responses,
current authority checks before and after disclosure, owned result lifetime,
ordered error/overflow behavior and explicit cancellation. Closing a local
handle or network stream cannot promise cancellation of accepted durable work.
Keep transport attempts separate from newly completed queries in service signals.
