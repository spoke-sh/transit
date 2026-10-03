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

| Source   | Declared decoding / projection                                                                                                                                     | Ordering                                           |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| KV       | Explicit prefix and independently versioned key/value decoders: binary, UTF-8, little-endian signed/unsigned 64-bit, finite IEEE float64 or canonical boolean byte | Unsigned byte order of keys                        |
| Table    | Exact Table ID and schema fingerprint; key and nullable value columns                                                                                              | Signed primary-key order                           |
| Document | Exact document/epoch/type/change-format/accepted revision; named paths, scalar or materialized-text projections, optional list expansion                           | One root row, or accepted sequence traversal order |

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

Typed plans support ordered scan, typed comparison and explicit state predicates,
bounded Boolean composition, ordered projection, whole-query limit, row count, value count and
checked int64 sum. Value comparisons preserve unknown for missing/null and reject
type errors/conflicts. Only true selects a row. State predicates select the
named state as true or false. A Boolean program contains one to 64 postfix
instructions: an atom, NOT (`negate`), AND (`conjunction`) or OR (`disjunction`).
Atoms are all-true, exact state tests or existing typed comparisons. NOT preserves
unknown. AND is false if either value is false, true if both are true, otherwise
unknown. OR is true if either value is true, false if both are false, otherwise
unknown. Operands evaluate eagerly in instruction order; the first error aborts
evaluation even when another operand determines the Boolean result. Validation
checks every atom before source processing. Programs cannot contain jumps,
references, recursion or nested programs; stack underflow and multiple final
values reject. Evaluation uses a fixed 64-byte truth stack. Instruction storage
is owned inline in the plan; text/binary literals keep their existing borrowed
lifetime. Copying a plan does not borrow its original instruction storage.
Sum ignores missing/null, rejects error/conflict and checks overflow in source
order across page boundaries. Count includes selected rows, regardless of cell
state. The `count_values` aggregate counts top-level value cells in its one
projected column, ignores missing/null, rejects type errors/conflicts in source
order and checks u64 overflow. Both counts return zero for empty input.
Limit is applied after filtering and before aggregation. No rewrite,
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
output buffer. `FZP1` plans have an 8192-byte encoding budget. The 175-byte `FZS1`
checkpoint binds source evidence and plan digest to global progress, value count, checked sum
and explicit end/limit disposition. Adapter continuation is a separate owned
record. These are resident/batch limits, not total source or result cardinality.

`FZS1` encodes magic, source kind (u8), resource/revision (u64 each), source
contract/schema digests (32 bytes each), plan digest (32 bytes), then six u64
counters in order: pages, scanned, selected, value_count, segments, rows. A
one-byte sum-present flag and i64 sum follow; absent sum requires zero bits.
The final byte is 0 (unfinished), 1 (source end) or 2 (input limit). All integers
are little-endian. `value_count` must not exceed selected rows and must be zero
for other aggregate kinds; `count_values` cannot carry a sum. Missing/null rows
consume the selected-row limit even though they do not increment value_count.
The prior 167-byte encoding rejects; no accumulator is inferred or reset.
The neutral result manifest exposes value_count as an unsigned decimal string.

## Canonical plans and output names

A typed plan owns up to eight optional output names. A name applies to its
output position, not its source column: a repeated source column is permitted
when the resulting output names are distinct. An omitted name preserves the
source name for rows or `count`/`sum` for an aggregate. Names use the schema's
one-to-thirty-two-byte ASCII identifier rules and canonical zero padding. Slots
beyond the output width must be empty. Duplicate output names reject; aliases
never rename the source schema or confer access to another source.

The current `FZP1` encoding starts with its four-byte magic and the mandatory
32-byte SHA-256 of `transit.fuze.plan.v1.boolean-programs.count-values.2026-10-01`. Missing or
foreign plan definitions reject before the plan can bind or execute. Next come
the aggregate byte (`rows` 0, `count` 1, `sum` 2, `count_values` 3),
projection-count byte, and that many source-column bytes.
Each output position then has a one-byte name length and exactly that many name
bytes; zero means no explicit output name. The existing limit-present byte,
little-endian u64 limit and predicate encoding follow. Absent limits retain a
zero value. Canonical decoding rejects trailing bytes and malformed names.

Predicate tags are 0 (all), 1 (state), 2 (compare) and 3 (program). A state atom
contains a column byte and state byte. A comparison contains a column byte,
comparison byte and scalar-type byte followed by the scalar payload: little-endian
8-byte signed/unsigned integer or float bits, one canonical Boolean byte, or a
little-endian u32 length followed by UTF-8/binary bytes. A program contains a
one-byte instruction count and exactly that many instructions. Instruction tags
0, 1 and 2 use the atom encodings above; tags 3, 4 and 5 are payload-free negate,
conjunction and disjunction. An instruction cannot contain a program. Encodings
preserve instruction order without simplification; a one-atom program remains
distinct from a direct atom. Decoding is allocator-free: instructions and output
names are owned, while projections and variable-width literals borrow the input.
Truncation, invalid tags, noncanonical scalars and programs exceeding either the
instruction or total plan-byte budget reject before binding.

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
optional-manifest flag/reference, collected flag and failure-presence flag. A
present failure adds the 112-byte `UQF1` record below. Valid records are 88 bytes
without a manifest/failure, 200 with a failure or 160 with a manifest. A manifest
and a failure are mutually exclusive. Denied/rejected status requires a failure;
retirement preserves that failure. Old records without the presence byte reject. Phases
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
reference, policy revision and retained version. Its final failure-presence byte
and optional `UQF1` make it 143 or 255 bytes. Failed/denied jobs require a
matching failure; all other source phases forbid one. The `UQC1` checkpoint contains
the `FZS1` engine progress, source-specific cursor, total bytes and ordered segment
chain in at most 254 bytes. It fits the unchanged 256-byte KV value.

`UQS1` segment metadata (in the separate result-record context) is 125 bytes:
magic, u64 ordinal, u64 first row, u8 row count, `SPF1` reference and raw Arrow
SHA-256. The chain starts at SHA-256 of `transit.query.result.v1` followed by a
zero byte; each step hashes the preceding digest followed by canonical metadata.
This binds ordered coverage and the independently chunked publication digest.
The finite `UQM1` manifest contains two u16 lengths followed by complete `UQJ1`
and `UQC1` records, within 512 bytes. It is published separately from segments;
only its original-call reply establishes a completed query for the requester.

## Retained query failures

`UQF1` is exactly 112 bytes: magic, u16 stable code, u8 stage, u8 evidence
tag and a 104-byte payload. All integers are little-endian. Stage 1 is admission
and stage 2 is execution. Tag 0 has an all-zero payload. Tags 1, 2 and 3 mean
pages, result segments and result bytes; their payload starts with u64 limit and
u64 required work and ends in 88 zero bytes. A measured witness requires code 9,
execution stage, a positive limit and required work greater than that limit.
Page work is the next page required beyond the completed-page count; result
counters include the rejected candidate segment, not committed progress.

Tag 4 carries the original runtime witness. Its 104 bytes hold resource u56,
revision u56, frozen binding SHA-256, one-based scanned row u64, source kind u8,
operation u8 (validate/predicate/count/sum = 1/2/3/4), column u8, instruction u8
(255 means absent), flags u8, expected scalar type u8, column-length u8, complete
key-length u16, decoder actual-byte-count u16 and 39 detail bytes. The high bit
of column-length marks truncation; the remaining bits give at most 23 ASCII
column bytes. Detail contains that column prefix followed by the key prefix,
then zero padding. Flags bits 0–1 name no key/KV/Table/Document element; bits 2–4
name no decoder failure/invalid UTF-8/invalid length/invalid boolean/nonfinite
float. All other flag bits are zero. Table keys use exact i64 bytes; Document
element keys use two u64 values (counter, replica). Long KV keys use available
remaining bytes and retain their complete length, so presentation marks truncation.
An unexpanded Document has no element key. No stored cell value is included.

Runtime witnesses require execution stage, no budget counters, and a compatible
cell/arithmetic failure. Source kinds, column/type/instruction bounds, decoder
shape, key shape, padding and reserved bits are validated. The engine validates the whole incoming page before evaluating predicates and
aggregates in row order. Predicate evaluation keeps eager instruction order;
SUM reports the first intermediate overflow. The witness identifies the first
failure in that execution order, not every possible error in the input.
The witness comes from the same retained page and bound plan that failed.
Recomputing a rolled-back proposal against the retained cut produces the same
witness even if live source data changes. Earlier 24-byte failures reject; the
shared definition cutover also rejects peers and saved work from that definition.

Tag 5 carries source/policy evidence in the same 104-byte slot: reason u8,
presence flags u8, budget dimension u8, one zero byte, resource u64, expected u64,
actual u64, expected digest (32 bytes), actual digest (32 bytes), and 12 zero
bytes. Presence bits 0–3 select the two numbers and two digests respectively;
absent values have all-zero bytes. Reasons 1–9 are policy missing, policy
disabled, policy revision changed, request resource mismatch, source resource
mismatch, policy declaration mismatch, Table schema mismatch, frozen source
contract mismatch and policy budget exceeded. Policy budget dimension uses
1/2/3 for pages/segments/result bytes; other reasons require zero. Each reason
validates its required number/hash shape; unused flags, bytes and noncanonical
encodings reject. Tag 5 excludes runtime or execution-budget evidence.

Policy admission checks retain the first mismatch in resource, declaration,
then pages/segments/result-byte order. An admitted request checks missing policy,
disabled policy, changed revision, then request resource. It can close after
revocation without reopening an inaccessible request publication. Table schema
checks retain both fingerprints from the failing comparison. Witness creation
allocates no memory and adds no state mutation. Metadata repair and retirement
do not replace the original failure. Disclosure still requires current native
access to the stored outcome; this evidence grants no source or policy access.

Admission rejection replies carry `UQF1`. Execution closure atomically records
that same value in the source job and sends it on the original reply route.
The requester stores it with its denied/rejected status. Cancellation retains
the separate `query.v1.cancelled` reply and can legitimately have no failure.
The earlier `query.v1.denied`, `.failed` and `.rejected` replies are not accepted.
The combined writer returns `writer_not_ready` while initialization is staged.

Only the first terminal source outcome can set the failure. Retrying closure,
replaying a continuation, cleanup and retiring a request cannot replace it.
Page, segment and byte budget checks run in that order. Failure to allocate,
read storage or commit the outcome does not authorize a terminal failure: the
original work remains unresolved. No extra mutation or larger native value is
required. Access to retained failure status uses the current requester-resource
read authorization, including bounded source keys copied into that recorded
outcome. It includes no stored cell values or credentials.

Neutral status includes both the original `failure` (code/stage/budget counters)
and a nullable [diagnostic envelope](DIAGNOSTICS_V1.md). Denied/rejected/retired
failures project the same original facts; retirement changes the outcome and
actions without replacing the cause. Cancelled/retired statuses without failures
receive lifecycle diagnostics. Other phases carry null. All ten SDKs retain the
complete diagnostic JSON with exact decimal counters; C owns at most 32 KiB in
its status value and C++ owns an optional string. SDK exceptions use their
separate failure boundary; status is an observational result, not an exception.

The stable codes below are the closed inventory for the source behavior's
terminal failure mapping. English descriptions and Zig error names are not the
code identity. Unknown/infrastructure errors are not coerced into this table.
This inventory does not claim to cover compiler, transport or other domain errors.

| Number | Code | Disposition | Meaning |
| --- | --- | --- | --- |
| 1 | `policy_denied` | denied | The current query policy does not permit this request. |
| 2 | `access_denied` | denied | Current access to a required resource was denied. |
| 3 | `resource_unavailable` | denied | A required resource is unavailable. |
| 4 | `request_unpublished` | denied | The request publication is no longer published. |
| 5 | `publisher_mismatch` | denied | The request publication has an unexpected publisher. |
| 6 | `document_history_gap` | denied | Required Document history is no longer available. |
| 7 | `document_retired` | denied | The Document revision is retired. |
| 8 | `document_resync_required` | denied | The Document source requires resynchronization. |
| 9 | `budget_exceeded` | failed | The query exceeded an admitted execution budget. |
| 10 | `projection_budget` | failed | The source projection exceeds its bounded work budget. |
| 11 | `expansion_missing` | failed | A collection required for expansion is missing. |
| 12 | `expansion_null` | failed | A collection required for expansion is NULL. |
| 13 | `expansion_conflict` | failed | A collection required for expansion has an unresolved conflict. |
| 14 | `expansion_type_error` | failed | A collection required for expansion has the wrong type. |
| 15 | `cell_type_error` | failed | The query encountered a type-error cell. |
| 16 | `cell_conflict` | failed | The query encountered an unresolved conflict cell. |
| 17 | `arithmetic_overflow` | failed | Checked arithmetic exceeded its representable range. |
| 18 | `segment_byte_limit` | failed | One Arrow result segment exceeds the segment-byte limit. |
| 19 | `type_mismatch` | failed | A value does not match its required type. |
| 20 | `unsupported_aggregate` | failed | The aggregate or its input type is unsupported. |
| 21 | `unknown_column` | failed | A referenced column is absent from the source schema. |
| 22 | `invalid_projection` | failed | The query projection is invalid for this source. |
| 23 | `duplicate_projection` | failed | The query repeats an output position without distinct names. |
| 24 | `invalid_bundle` | failed | The submitted query bundle is invalid. |
| 25 | `invalid_source` | failed | The query source declaration is invalid. |
| 26 | `invalid_prefix` | failed | The KV source prefix is invalid. |
| 27 | `invalid_path` | failed | The source projection path is invalid. |
| 28 | `invalid_projection_budget` | failed | The source projection budget is invalid. |
| 29 | `invalid_text_projection` | failed | The text source projection is invalid. |
| 30 | `invalid_element_projection` | failed | The element source projection is invalid. |
| 31 | `unsupported_source` | failed | This query source kind is unsupported. |
| 32 | `unsupported_decoder` | failed | This source decoder is unsupported. |
| 33 | `unsupported_document_source` | failed | This Document source projection is unsupported. |
| 34 | `invalid_source_encoding` | failed | The source declaration encoding is invalid. |
| 35 | `invalid_plan_encoding` | failed | The query plan encoding is invalid. |
| 36 | `plan_definition_mismatch` | failed | The query plan belongs to a different contract definition. |
| 37 | `invalid_output_names` | failed | Query output names are invalid or duplicated. |
| 38 | `unsupported_plan` | failed | This query plan uses an unsupported operation. |
| 39 | `plan_too_large` | failed | The query plan exceeds its byte limit. |
| 40 | `bundle_too_large` | failed | The query bundle exceeds its byte limit. |
| 41 | `truncated_input` | failed | A required encoded query value is truncated. |
| 42 | `source_changed` | failed | The source identity changed from the submitted query basis. |
| 43 | `table_schema_changed` | failed | The Table schema changed from the submitted query basis. |
| 44 | `invalid_budget` | failed | The submitted execution budget is invalid. |
| 45 | `namespace_in_use` | failed | The query namespace is already in use. |
| 46 | `query_after_mutation` | failed | Query admission cannot follow a mutation in the same turn. |
| 47 | `nonfinite_value` | failed | A query value is not a finite number. |
| 48 | `invalid_utf8` | failed | A query value is not valid UTF-8. |
| 49 | `cell_too_large` | failed | A query cell exceeds its byte limit. |
| 50 | `invalid_column_name` | failed | A source column name is invalid. |
| 51 | `invalid_column_count` | failed | The source column count exceeds the supported shape. |
| 52 | `duplicate_column` | failed | The source schema repeats a column name. |
| 53 | `unsupported_schema` | failed | The source schema uses an unsupported type or shape. |
| 54 | `peer_mismatch` | denied | The caller is not the configured query peer. |
| 55 | `invalid_request_reference` | failed | The query request publication reference is invalid. |
| 56 | `writer_not_ready` | failed | The combined Table query and writer owner has not completed initialization. |
| 57 | `request_resource_expired` | denied | The query request resource expired. |
| 58 | `request_resource_missing` | denied | The query request resource no longer exists. |

Native/port and SDK query status include required `failure`, either null or an
object with `code`, `stage`, `dimension`, `limit` and `observed`. The two counters
use full-width decimal strings on the neutral boundary and native integer types
in SDKs. A cause without a recorded expression, column or source position does
not acquire one from a later read. These fields remain unrecorded in this profile.

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

Neutral plans include `output_names`: null retains all default names; otherwise
the array has exactly one entry per projection position. A null entry retains
that position's default, and a string supplies a valid name of at most 32 ASCII
identifier bytes. Empty arrays, width mismatches, invalid names and resulting
output-name collisions reject. Decoding emits null for an all-default vector;
named vectors preserve null slots and own their text. Decode → prepare preserves
canonical bundle bytes and Publication identity. Compiled workspace metadata
uses this same plan representation. SQL names retain their separate 16-byte bound.

Neutral predicates also admit `{"program":[...]}`. Each instruction is
`{"atom":<all/state/compare predicate>}`, `{"negate":{}}`, `{"conjunction":{}}`
or `{"disjunction":{}}`. The shared codec enforces one to 64 instructions,
complete postfix shape, exact scalar types and source column bounds. Decoding
copies instructions and literal values into the caller's result allocator;
preparing that result preserves canonical bytes and Publication identity.
Generated schemas derive the program bound from the Fuze instruction owner,
separately from the eight-column and eight-row bounds. Native SQL lowers Boolean
composition to this program representation through the shared native/port codec.
All ten language SDKs expose typed program constructors and inspected programs.
C/C++ plan and explanation layouts require the current shared ABI definition and
matching headers/libraries; this host-layout cutover does not change FZP1 bytes.

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
star (all declared columns), one to eight ordered named columns, Boolean
composition of typed comparisons and exact cell-state tests, row output, `COUNT(*)`, `COUNT(column)`, and checked int64 `SUM(column)`. The existing
restricted aggregate subquery preserves filter → limit → aggregate order.

`FROM source AS alias` supplies a query-local qualifier. Source resolution still
checks the declared source name. Qualified columns use the alias when present;
the original source name then rejects as a qualifier. Unqualified columns remain
valid. Inner source aliases and the restricted subquery's outer alias have
separate scopes. `AS` is required, and aliases obey the 16-byte identifier rules.
A source alias does not rename output columns or change the source basis. It lowers
away before plan encoding, so equivalent aliased and unaliased queries have
identical canonical plan bytes and execution semantics.

`column AS name`, either COUNT form with `AS name`, and `SUM(column) AS name` supply owned
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
comparisons on missing/null produce unknown and fail on type errors or unresolved
conflicts. NOT preserves unknown; AND/OR use three-valued truth, and only true
selects a row. NOT binds before AND, which binds before OR; grouping overrides
precedence. SQL preserves source-order eager atom evaluation and the first error,
including errors after a determining Boolean operand. A program has at most 64
instructions, counting each atom and each Boolean operator. The parser also
bounds pending operators/group delimiters to 64 entries. Redundant grouping of
one atom preserves that atom's canonical encoding; operators are never simplified.
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
columns, including columns whose names exceed the SQL identifier bound. Both counts
return uint64 with zero for no contributing values; sum returns checked int64
with null for no contributing values.
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
