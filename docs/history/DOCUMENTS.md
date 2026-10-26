# Documents and collaborative text

Engineering background and historical design. Use [Documents and collaborative text](../handbook/reference/documents.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Use Documents for accepted structured changes and collaborative text. Begin with
the [Document service guide](../../packages/zig/transit-station-document/docs/service.md)
and query accepted projections through [unified SQL](../handbook/reference/sql.md). Speculative
edits and accepted revisions remain different states.

Status: M17's declared growing profile is implemented and qualified: durable
merge/checkpoint recovery, all ten installed SDKs, two independent editors,
Board metadata and local/Compose/reference placement pass. M14 supplies bounded immutable publication over
growing KV. M15/M16 qualify HTTP/gRPC integrations; Document semantics remain
independent of those transports. See [executed evidence](qualification/runtime.md#m17-qualification).

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

M17 must define how change records, causal metadata, materialized indexes and
checkpoint roots share that decision. An index update spanning many turns must
remain invisible until its validated root commits. Checkpoints must preserve
deletion and causal evidence; publication by itself grants no trim permission.
Readers use an exact source and bounded chunks. An interrupted or unverified
prefix is never a complete change or checkpoint.

## Selected M17 model and merge rules

A Document has a stable identity and declared type/change-format revision inside
one resource. Replica IDs and monotonically allocated operation IDs are distinct
from PID/activation. A map field is an observed-remove multivalue register:
assignments remove only named assignments the author actually observed, preserving
unseen concurrent values as an explicit conflict. Resolution is a new assignment
naming the conflicting values it replaces. Null is a value; absence is not null.

Maps, lists and editable text have immutable object identities created with their
parent assignment. Replacement creates a new object; reparenting/move and cycles
are unsupported. Removing a parent detaches that object; concurrent descendant
edits remain accepted history but cannot resurrect the removed parent. An unseen
concurrent assignment to the same field remains a visible conflict/value. This
explicit detach rule must be tested separately from field-register convergence.

Lists and plain text use an RGA-style predecessor relation, stable element IDs
and deterministic descending ID order among concurrent siblings. Deletion marks
the named element permanently; insertions after a deleted anchor remain ordered.
Text elements are Unicode scalar values, without normalization or grapheme
interpretation. A replaceable UTF-8 scalar string is distinct from editable text.
No wall clock or external ordering service selects a winner.

These choices draw on [Kleppmann and Beresford's nested CRDT work](https://www.cl.cam.ac.uk/~arb33/papers/KleppmannBeresford-CRDT-JSON-TPDS2017.pdf)
and [Almeida et al.'s observed-remove causal datatypes](https://members.loria.fr/CIgnat/files/replication/Delta-CRDT.pdf).
Their proofs are background, not a proof of this implementation or its distinct
detachment, acceptance and retention rules. M17 requires independent convergence,
dependency, duplicate and delete/edit schedules for the concrete encoding.

A change names its replica predecessor and explicit observed operation/anchor
identities. Missing dependencies are rejected as not accepted, with their identity
available for explicit resubmission after the prerequisite. A rejected change
cannot satisfy a later dependency. No unbounded hidden pending queue is introduced.
Reusing an identity with different content is a permanent conflict, not a retry.
Current resource/service authorization and a fenced writer still gate acceptance.

## Paged materialization and checkpoints

Materialized object, field, sequence and causal records use an immutable ordered
index over Publication. [The index format](../../contracts/STATION_INDEX_V1.md) fixes
bounded nodes, path copying and exact root references. Accepted history and index
size grow on disk independently of worker memory. An operation reads and changes
only bounded paths, stages copied nodes, then publishes one validated Document
head. Index-node publication alone never accepts part of a change. Kernel values,
turn mutations and resource boundaries stay unchanged.

The final head binds Document/type/change versions, accepted change identity,
index root, epoch and retained-history floor. Checkpoint roots preserve causal
and deletion records as well as visible values. Default retention is unlimited.
An opted-in finite merge window advances an explicit epoch/floor only through a
validated checkpoint and compaction job; old replicas receive a resynchronization
requirement and cannot replay stale edits into the new epoch. Physical reclamation
is separate and must account for still-retained roots. Root references cannot
extend resource or process lifetime or revive a retired Document.

Operation, active candidate, node/page and output budgets remain explicit. A
capacity refusal does not accept a prefix or trigger compaction/expiry. M17 must
qualify the whole structured/text example, including causal records and staged
nodes, before publishing the final public API and compatibility profile.

## Query and language handoff from M13

M13's public request contains at most 207 encoded plan bytes. Its Fuze schema
contains an int64 key and one nullable scalar value. A larger immutable record
does not silently change either contract. M17 supplies bounded accepted-state
reads and M18 defines a versioned query source,
schema and request extension for KV decoders and Document projections, retaining
missing/null/type-error/conflict distinctions and bounded list/text operations.
Reuse exact source revisions, current read authorization and verified result
delivery; sharing plans does not create cross-resource snapshots or transactions.

All ten M11 SDK targets expose the shared Zig operations with exact change
identities, scoped ownership and explicit accepted/tentative outcomes.
The M14 Zig primitive is a storage prerequisite, not public Document support in
those SDKs. The complete collaborative example, Board metadata and deployment
proofs have executed evidence under M17 exit criteria.
Unified query APIs, Arrow ownership/fixtures and all-language query conformance
remain M18 obligations, separate from Document mutation APIs.

The [Station Document package](../../packages/zig/transit-station-document/README.md)
now implements the selected merge model and bounded candidate/reader component.
Its [neutral format](../../contracts/STATION_DOCUMENT_V1.md) owns exact fields and
limits. [Authenticated call helpers](../../packages/zig/transit-station-document/docs/remote.md)
bind the caller's allowed replica, immutable request and original reply route.
Their component tests supplement the existing disk, SDK and two-client local
worker proofs; they do not complete Compose/reference placement qualification.
