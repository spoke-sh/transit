# State query v1

Unified queries read declared KV, Table and Document sources. The
[compatibility matrix](../packages/zig/transit-query/docs/compatibility.md)
defines supported sources, callers and result representations.
This is the sole current public query definition. Incompatible saved requests
and results reject under the [versioning policy](../docs/reference/versioning.md).

## Ownership and source identity

Fuze is a pure, bounded engine over typed rows. It imports neither Station nor
Document. The `transit-query` package composes Station's current/retained readers
and the accepted Document reader; Document never imports query execution.
A source definition declares one resource and exactly one of these adapters:

| Source | Declared decoding / projection | Ordering |
| --- | --- | --- |
| KV | Explicit prefix and independently versioned key/value decoders: binary, UTF-8, little-endian signed/unsigned 64-bit, finite IEEE float64 or canonical boolean byte | Unsigned byte order of keys |
| Table | Exact Table ID and schema fingerprint; key and nullable value columns | Signed primary-key order |
| Document | Exact document/epoch/type/change-format/accepted revision; named paths, scalar or materialized-text projections, optional list expansion | One root row, or accepted sequence traversal order |

There is no KV schema inference or application callback. A decoder mismatch is a
`type_error` cell. A missing Document path, explicit null and unresolved register
conflict are separate states. Paths have at most eight components. List expansion
is incremental, including empty pages caused by deleted anchors; it does not
collect the whole list. Each list page performs at most 32 traversal transitions and returns at most
eight elements. Relative projections read the element itself or map paths under
it; explicit counter/replica projections expose stable element identity. Expanding
a missing, null, conflicting or non-list path is a distinct error, not an empty
list. A text projection has an explicit byte and traversal
budget and fails on overflow rather than returning a truncated string. All text
projections share a 4096-transition page budget.

Every batch binds source kind, resource ID, exact resource revision, source
contract digest and input schema digest. The contract digest covers the complete
adapter definition, including decoder/projection versions and Document identity.
A query has one source cut. There are no cross-resource snapshots or joins.
Current grants and Document floor/retirement remain live even when bytes come
from a retained cut. Retention cannot turn a retired Document into a readable one.

## Typed expressions and results

The new schema admits up to eight named columns of int64, uint64, finite float64,
boolean, UTF-8 or binary. Names and column order participate in its fingerprint.
One model serves all three adapters. Typed rows borrow bounded adapter storage;
plans borrow their explicitly owned immutable buffers. No native pointer is
persisted in durable progress.

A cell has one of five states: `missing`, `null`, `type_error`, `value`, `conflict`.
A typed projection of a conflict preserves up to eight ordered assignment IDs
and each alternative's value/null/type-error state. It never chooses a winner.
Type errors retain the actual source kind. Unsupported object shapes do not
silently become strings or nulls. Integers retain all 64 bits; finite floating
point preserves negative zero; text is UTF-8 and lengths are bytes unless the
operation explicitly declares Unicode scalar traversal.

The initial plan supports ordered scan, one typed comparison or explicit state
predicate, ordered projection, whole-query limit, row count and checked int64
sum. A value comparison treats missing/null as nonmatching and rejects type
errors/conflicts. State predicates allow callers to select those states directly.
Sum ignores missing/null, rejects error/conflict and checks overflow in source
order across page boundaries. Count includes selected rows, regardless of cell
state. Limit is applied after filtering and before aggregation. No rewrite,
predicate pushdown, sorting or implicit coercion is enabled. The bounded SQL rewrite theorems do
not establish new v1 operator correctness.

Arrow represents each projected column as a non-null struct containing a state,
actual kind, nullable typed value, and a non-null list of alternatives. Each
alternative contains counter/replica identity, state, actual kind and nullable
typed value. This gives primitive values and nested struct/list layouts one
schema while preserving all five outcomes. Empty results still carry the exact
schema. Batches and total results have separate limits; durable cardinality is
not a fixed resident array. Independent Arrow readers must qualify these layouts
before they are advertised.

The implemented pure profile uses at most eight rows per input page, 4096 bytes
per variable-width scalar, a 64 KiB Arrow segment and 4 MiB of caller-owned Arrow
workspace. Segment overflow is an error; callers cannot publish its partial
output buffer. `FZP1` plans have an 8192-byte encoding budget. The 167-byte `FZS1`
checkpoint binds source evidence and plan digest to global progress, checked sum
and explicit end/limit disposition. Adapter continuation is a separate owned
record. These are resident/batch limits, not total source or result cardinality.

## Canonical plans and output names

A typed plan owns up to eight optional output names. A name applies to its
output position, not its source column: a repeated source column is permitted
when the resulting output names are distinct. An omitted name preserves the
source name for rows or `count`/`sum` for an aggregate. Names use the schema's
one-to-thirty-two-byte ASCII identifier rules and canonical zero padding. Slots
beyond the output width must be empty. Duplicate output names reject; aliases
never rename the source schema or confer access to another source.

The current `FZP1` encoding starts with its four-byte magic and the mandatory
32-byte SHA-256 of `transit.fuze.plan.v1.output-names.2026-09-30`. Missing or
foreign plan definitions reject before the plan can bind or execute. Next come
the aggregate byte, projection-count byte, and that many source-column bytes.
Each output position then has a one-byte name length and exactly that many name
bytes; zero means no explicit output name. The existing limit-present byte,
little-endian u64 limit and predicate encoding follow. Absent limits retain a
zero value. Canonical decoding rejects trailing bytes and malformed names.

Output names participate in the plan fingerprint and the output-schema
fingerprint. Execution, EXPLAIN and Arrow use the same validated output schema,
including for empty results. Input basis/schema identity, filtering, aggregate
arithmetic, source order, five-state cells and resource bounds are unchanged.
The shared native definition also changes for this stored-framework cutover;
old saved requests and authority heads require their matching build for recovery.
There is no fallback decoder, automatic migration or data reset.

## Larger requests and durable publication

V1 advertises separate plan, source, result and upload capabilities. It never
widens Transit values, mailbox frames or the four-mutation turn budget. Source
metadata and canonical plan bytes form a bounded immutable request bundle;
all durable requests use Station Publication.

An authenticated requester behavior accepts a bounded begin/chunk/seal sequence
from its configured query principal. Chunk parts fit ordinary Station frames;
only the complete verified publication may become a query call. Signed transport
requests remain frozen across uncertainty. Resuming an upload checks the same
identity, length, digest and committed progress. A conflicting chunk cannot alter
an existing upload. One active upload/query bounds admission independently of
retained history. Abandon/cancel is explicit; a timeout or frontend disconnect is
not remote cancellation.

The canonical `UQB1` bundle has a 32-byte header: magic, u16 source length,
u16 plan length, then u64 maximum input pages, segments and result bytes. Integers
are little-endian. Canonical `UQS1` source and `FZP1` plan bytes follow. Its total
budget is 16 KiB; each component retains its own smaller bound. All three work
budgets are positive and must fit the current durable source policy. The bundle
uses the query-request publication domain, record 1, format `0x31425155`, referenced by Station's 72-byte `SPF1` encoding.
Neither truncation nor trailing bytes is canonical.

The source's revisioned `UQA1` policy binds the authenticated requester PID,
request resource, allowed declaration and maximum budgets. Its declaration digest
covers all decoder/projection details. Only an accepted Document revision may
vary within that declaration; Document epoch, type, identity and change format
remain fenced. Every accepted job also records the complete exact source digest.

The command envelope uses these distinct magic bytes: `UQI1` initialize,
`UQB1` begin plus `SPF1`, `UQP1` part (u64 namespace, u32 chunk ordinal, one
canonical boolean second-half byte, then 1–128 bytes), and `UQS1` seal / `UQX1`
submit / `UQK1` cancel / `UQG1` collect / `UQR1` retire, each followed by a u64
namespace. All integers are little-endian. The part payload is at most 145 bytes;
begin is 72 and namespace operations are 12, below the unchanged 243-byte limit.
`UQU1` upload state contains its `SPF1`, phase byte, u64 original correlation,
optional-manifest flag/reference and collected flag (87 or 159 bytes). Phases
1–8 mean uploading, sealed, admitted, complete, cancelled, denied, rejected and
retired. Boolean flags are exactly zero or one. Full u64 namespaces never pass
through a floating-point number.

The source validates current peer policy, request-resource access, bundle digest,
source contract and supported plan before capture. It retains an exact source
cut and commits bounded resumable progress. Station Publication stores independently
verified Arrow segments and a final immutable manifest. Staged segments are not
a complete result. The manifest binds the query, original reply route, all source
and schema evidence, plan digest, ordered segment digests and complete row/byte
coverage. A final reference is delivered through the original durable call.
The request publisher must equal the authenticated requester; result and manifest
publishers must equal the recorded source PID. Merely reading the referenced
resource cannot substitute a different publisher or original reply route.

V1 reads verified result publications through current signed resource reads;
references are not bearer grants. It reads immutable source publications through their original call identity. Reads check current
source/result policy and lifecycle before and after a page. Revocation stops
later disclosure, including a continuation after an already returned prefix;
it cannot retract previously disclosed bytes. Retained source pins are released
on capture completion or explicit closure. Cancelled/failed staging is reclaimed
in bounded steps; publication ledgers preserve permanent identity facts.

The source job's result namespace is `2^63 | source_input_position`, reserved by
the host in that resource; an occupied namespace rejects admission.
The query-result publication domain separates its budgets and records from
request uploads and mutations in the same resource. Segment ordinal `n` uses record `n + 1`, format `0x31415155`; the final manifest uses
record `2^64 - 1`, format `0x314d5155`. `UQJ1` binds the original route, request
reference, policy revision and retained version. The `UQC1` checkpoint contains
the `FZS1` engine progress, source-specific cursor, total bytes and ordered segment
chain in at most 246 bytes. It fits the unchanged 256-byte KV value.

`UQS1` segment metadata (in the separate result-record context) is 125 bytes:
magic, u64 ordinal, u64 first row, u8 row count, `SPF1` reference and raw Arrow
SHA-256. The chain starts at SHA-256 of `transit.query.result.v1` followed by a
zero byte; each step hashes the preceding digest followed by canonical metadata.
This binds ordered coverage and the independently chunked publication digest.
The finite `UQM1` manifest contains two u16 lengths followed by complete `UQJ1`
and `UQC1` records, within 512 bytes. It is published separately from segments;
only its original-call reply establishes a completed query for the requester.

## Language-neutral values

The shared native `QueryCodec` accepts typed source declarations and plans,
produces canonical `UQB1` bytes and validates nested Arrow. Its JSON schemas are
generated from Zig alongside the additive `station_unified_query_codec` export
and `unified_query_codec` local-port action. This is a codec boundary, not query
admission or a grant.

Resource/PID/revision counters keep the public protocol's safe-number range.
Other u64/i64 values, work budgets, limits and Document identities use canonical
decimal strings without leading zeros or negative zero. Float64 uses exactly
eight little-endian bytes encoded as hex; non-finite values reject. Binary and
encoded bundles use hex. UTF-8 remains text. Projection indices are JSON integer
arrays. Missing, null, type error, value and ordered conflicts remain distinct
tagged values, including the full-width counter/replica pair of each alternative.

Input JSON is bounded at 256 KiB; source, plan, bundle, scalar, page and Arrow
limits still apply independently. Native outputs are owned buffers that callers
release explicitly; port responses copy them before native release. Pure local
codecs need no endpoint, signing credential or execution handle. The same schema
and semantic validation apply to the library and the port.

## Public surfaces and qualification

### SQL capability profile

The v1 SQL compiler reuses the complete-input SQL parser and reference grammar.
One configured SQL name resolves to an explicit authorized source definition;
KV decoders and Document paths/list/text projections are declared in that
definition, never inferred from SQL or application values. This profile supports
star (all declared columns), one to eight ordered named columns, one typed comparison
or an exact cell-state test, row output, `COUNT(*)`, and checked int64 `SUM(column)`. The existing
restricted aggregate subquery preserves filter → limit → aggregate order.

`FROM source AS alias` supplies a query-local qualifier. Source resolution still
checks the declared source name. Qualified columns use the alias when present;
the original source name then rejects as a qualifier. Unqualified columns remain
valid. Inner source aliases and the restricted subquery's outer alias have
separate scopes. `AS` is required, and aliases obey the 16-byte identifier rules.
A source alias does not rename output columns or change the source basis. It lowers
away before plan encoding, so equivalent aliased and unaliased queries have
identical canonical plan bytes and execution semantics.

`column AS name`, `COUNT(*) AS name` and `SUM(column) AS name` supply owned
output names. `AS` is required, using the same 16-byte identifier rules. The
resulting names must be distinct; repeated source indices are allowed with
distinct names. Names, types and cell states in the source remain unchanged.
Output aliases do not enter predicate scope. A renamed inner projection supplies
the names available to the restricted outer aggregate; compilation resolves
those names back to source indices. Only final output names enter canonical plan
bytes. Star cannot have an output alias, and implicit aliases reject.

V1 limits use the plan's full u64 range; an absent limit stays unlimited, subject
to explicit execution budgets. An aggregate's outer LIMIT still rejects.
`IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR` and `IS CONFLICT` select
exactly the named state. Missing values do not become null;
comparisons skip missing/null and fail on type errors or unresolved conflicts.
Comparisons require an exact literal type. The grammar has int64, boolean,
UTF-8 and binary literals, plus string literals with `::uint64` or `::float64`.
Uint64 accepts decimal digits through 18446744073709551615; float64 accepts
finite decimal notation with optional sign and exponent, rounded to binary64.
It preserves negative zero. Non-finite values, overflow, whitespace, underscores
and hexadecimal floating point reject. `column = NULL` and other null
comparisons reject as `UnsupportedNullComparison` because the v1 plan has no
null comparison scalar. SQL lowers to the existing typed scalar and state operators.
No implicit integer conversion, collation or rewrite is introduced.
UTF-8/binary comparisons use the plan's lexicographic byte order.

Parser bounds remain 4096 statement bytes, 16-byte identifiers, eight explicit
projection names and 220 decoded literal bytes. Star can project eight declared
columns, including columns whose names exceed the SQL identifier bound. Count
returns uint64, sum returns checked int64 with null for no contributing values.
Compilation owns projection/literal storage in a caller-supplied allocator and
validates the resulting plan; it performs no reads and confers no authority.

The signed shell, explicit-submit Board query workspace and all ten non-Zig SDKs use
the shared Zig contract. SDKs own their typed objects and Arrow buffers; they do
not implement decoders, query semantics, publication or retries independently.
Board's inspection identity remains separate from optional query credentials.
SQL only advertises forms that lower to this plan; reference grammar acceptance
alone is not an execution capability. No Live or continuous query session is
introduced by this profile.

Each source requires independent expression/Arrow fixtures, page-boundary
permutations, exact signed retry, worker/node recovery, current-policy denial
before/during/after capture, returned-prefix denial, expiry, retained-version
release, retirement and cleanup. Local, Compose and Substrate examples record
actual evidence and measured costs. The compatibility matrix defines sources and types;
the [Flight contract](FLIGHT_V1.md) separately defines the int64 Table conversion
and its remote clients.

Finite requester process/resource lifetimes also bound its Station call wait to
their earliest recorded deadline. The configured query principal is the timer
observer and already owns explicit cancellation. An authenticated ordered timer
observation closes the wait and schedules request-publication cleanup; hard
process/resource expiry requires no timer delivery. Neither path renews source
or result availability. A local transport timeout or disconnected frontend has
no such authority and leaves the original durable call unchanged.
