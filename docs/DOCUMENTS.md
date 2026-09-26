# Documents and collaborative text

Status: proposed Station abstraction, selected for [M15](roadmap/M15.md).
[M14](roadmap/M14.md) first qualifies bounded immutable publication over growing
KV. No Document change format or CRDT API is implemented by that prerequisite.

## Authority and identity

A Document belongs to one durable state resource. Its identity, replica identity
and change identity must remain distinct from PID, worker and ownership
generation. Station selects merge semantics; Transit continues to enforce
current access, writer fencing, the resource boundary, input progress and
outputs. A mergeable tentative edit is not an accepted change or permission to
mutate. Associations and retained references confer no new authority.

## Storage prerequisite and acceptance

The 256-byte KV value and four-mutation turn budget cannot atomically replace
a useful document plus metadata directly. M13's result-specific chunking showed
how to separate incremental preparation from one visibility decision. M14
generalizes that mechanism: immutable chunks and a descriptor live in the same
resource, with explicit staging quotas and permanent identity tombstones.

A final publication turn can atomically publish a record, update an application
head and emit a reply. Earlier staging turns consume their own inputs and may
acknowledge staging only. They do not accept the proposed Document change.
Unpublished work is recoverable or explicitly abandoned; no timeout or quota
pressure silently discards it. Byte publication verifies content completeness,
not CRDT validity or honest computation.

M15 must define how change records, causal metadata, materialized indexes and
checkpoint roots share that decision. An index update spanning many turns must
remain invisible until its validated root commits. Checkpoints must preserve
deletion and causal evidence; publication by itself grants no trim permission.
Readers use an exact source and bounded chunks. An interrupted or unverified
prefix is never a complete change or checkpoint.

## Model and merge decisions still required in M15

The model includes nested maps, lists, scalar values and collaborative plain
text. Replacing a string and inserting/deleting sequence elements are distinct
operations. Specify Unicode scalar positions and stable element identities;
grapheme-aware editor behavior is a separate layer. Explicitly define concurrent
field assignment, deletion versus editing, nested object identity, conflict
visibility and conflict resolution before selecting an operation encoding.

Qualify the chosen Zig-native CRDT with shared fixtures, causal reorderings,
duplicates, missing and rejected dependencies, identity/content conflicts and
bounded work. Choose and measure the complete example's metadata and content
layout, including a useful text size. Do not bound the entire durable collection
by an in-memory array or implement independent merge rules in each SDK.

Retention defaults to unlimited. A finite offline-merge window needs an explicit
policy, durable rejection floor, authorized resynchronization and proofs that
stale replicas cannot revive retired identities. Physical deletion follows
dependency-safe logical retirement; replica/checkpoint references cannot extend
resource or process lifetime implicitly.

## Query and language handoff from M13

M13's public request contains at most 207 encoded plan bytes. Its Fuze schema
contains an int64 key and one nullable scalar value. A larger immutable record
does not silently change either contract. M15 must define a versioned source,
schema and request extension for KV decoders and Document projections, retaining
missing/null/type-error/conflict distinctions and bounded list/text operations.
Reuse exact source revisions, current read authorization and verified result
delivery; sharing plans does not create cross-resource snapshots or transactions.

All M11 SDK targets must eventually expose the shared Zig operations with exact
change identities, scoped ownership and explicit accepted/tentative outcomes.
The M14 Zig primitive is a storage prerequisite, not public Document support in
those SDKs. The complete collaborative example, Board metadata and deployment
proofs remain explicit [M15 exit criteria](roadmap/M15.md#exit-criteria).
