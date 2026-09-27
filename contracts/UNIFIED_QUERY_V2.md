# Unified state query profile v2

Status: selected M18 contract; implementation and qualification are in progress.
The existing [public Table v1](PUBLIC_QUERY_V1.md), `FZP1` plans and retained
`GQM2` results keep their original interpretation. This document does not mark
unimplemented surfaces as available. See [M18](../docs/roadmap/M18.md).

## Ownership and source identity

Fuze v2 is a pure, bounded engine over typed rows. It imports neither Station nor
Document. The `transit-query` package composes Station's current/retained readers
and M17's accepted Document reader; Document never imports query execution.
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
predicate pushdown, sorting or implicit coercion is enabled. M12's theorems do
not establish new v2 operator correctness.

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
output buffer. `FZP2` plans have an 8192-byte encoding budget. The 167-byte `FZS2`
checkpoint binds source evidence and plan digest to global progress, checked sum
and explicit end/limit disposition. Adapter continuation is a separate owned
record. These are resident/batch limits, not total source or result cardinality.

## Larger requests and durable publication

V2 advertises separate plan, source, result and upload capabilities. It never
widens Transit values, mailbox frames or the four-mutation turn budget. Source
metadata and canonical plan bytes form a bounded immutable request bundle;
requests larger than M13's 207-byte allowance use Station Publication.

An authenticated requester behavior accepts a bounded begin/chunk/seal sequence
from its configured query principal. Chunk parts fit ordinary Station frames;
only the complete verified publication may become a query call. Signed transport
requests remain frozen across uncertainty. Resuming an upload checks the same
identity, length, digest and committed progress. A conflicting chunk cannot alter
an existing upload. One active upload/query bounds admission independently of
retained history. Abandon/cancel is explicit; a timeout or frontend disconnect is
not remote cancellation.

The canonical `UQB2` bundle has a 32-byte header: magic, u16 source length,
u16 plan length, then u64 maximum input pages, segments and result bytes. Integers
are little-endian. Canonical `UQS2` source and `FZP2` plan bytes follow. Its total
budget is 16 KiB; each component retains its own smaller bound. All three work
budgets are positive and must fit the current durable source policy. The bundle
is record 1, format `0x32425155`, referenced by Station's 68-byte `SPF1` encoding.
Neither truncation nor trailing bytes is canonical.

The source's revisioned `UQA2` policy binds the authenticated requester PID,
request resource, allowed declaration and maximum budgets. Its declaration digest
covers all decoder/projection details. Only an accepted Document revision may
vary within that declaration; Document epoch, type, identity and change format
remain fenced. Every accepted job also records the complete exact source digest.

The command envelope uses these distinct magic bytes: `UQI2` initialize,
`UQB2` begin plus `SPF1`, `UQP2` part (u64 namespace, u32 chunk ordinal, one
canonical boolean second-half byte, then 1–128 bytes), and `UQS2` seal / `UQX2`
submit / `UQK2` cancel / `UQG2` collect / `UQR2` retire, each followed by a u64
namespace. All integers are little-endian. The part payload is at most 145 bytes;
begin is 72 and namespace operations are 12, below the unchanged 243-byte limit.
`UQU2` upload state contains its `SPF1`, phase byte, u64 original correlation,
optional-manifest flag/reference and collected flag (83 or 151 bytes). Phases
1–8 mean uploading, sealed, admitted, complete, cancelled, denied, rejected and
retired. Boolean flags are exactly zero or one. Full u64 namespaces never pass
through a floating-point number.

The source validates current peer policy, request-resource access, bundle digest,
source contract and supported plan before capture. It retains an exact source
cut and commits bounded resumable progress. M14 Publication stores independently
verified Arrow segments and a final immutable manifest. Staged segments are not
a complete result. The manifest binds the query, original reply route, all source
and schema evidence, plan digest, ordered segment digests and complete row/byte
coverage. A final reference is delivered through the original durable call.
The request publisher must equal the authenticated requester; result and manifest
publishers must equal the recorded source PID. Merely reading the referenced
resource cannot substitute a different publisher or original reply route.

V2 reads verified result publications through current signed resource reads;
references are not bearer grants. It does not duplicate Arrow bytes into a second
requester store or reinterpret v1's segment-transfer protocol. Reads check current
source/result policy and lifecycle before and after a page. Revocation stops
later disclosure, including a continuation after an already returned prefix;
it cannot retract previously disclosed bytes. Retained source pins are released
on capture completion or explicit closure. Cancelled/failed staging is reclaimed
in bounded steps; publication ledgers preserve permanent identity facts.

The source job's result namespace is `2^63 | source_input_position`, reserved by
the host in that resource; an occupied namespace rejects admission. Segment
ordinal `n` uses record `n + 1`, format `0x32415155`; the final manifest uses
record `2^64 - 1`, format `0x324d5155`. `UQJ2` binds the original route, request
reference, policy revision and retained version. The `UQC2` checkpoint contains
the `FZS2` engine progress, source-specific cursor, total bytes and ordered segment
chain in at most 246 bytes. It fits the unchanged 256-byte KV value.

`UQS2` segment metadata (in the separate result-record context) is 121 bytes:
magic, u64 ordinal, u64 first row, u8 row count, `SPF1` reference and raw Arrow
SHA-256. The chain starts at SHA-256 of `transit.query.result.v2` followed by a
zero byte; each step hashes the preceding digest followed by canonical metadata.
This binds ordered coverage and the independently chunked publication digest.
The finite `UQM2` manifest contains two u16 lengths followed by complete `UQJ2`
and `UQC2` records, within 512 bytes. It is published separately from segments;
only its original-call reply establishes a completed query for the requester.

## Public surfaces and qualification

The signed shell, explicit-submit Board query workspace and all ten M11 SDKs use
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
actual evidence and measured costs. M19 receives a source/type/protocol matrix;
no Flight, Flight SQL or ADBC support follows from this contract alone.
