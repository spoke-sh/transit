# Documents and collaborative text

Documents accept structured changes and collaborative plain text into one durable
state resource. An editor's tentative change, a mergeable candidate and an
accepted revision are distinct states. The fenced writer and current resource
policy still decide acceptance; mergeability never grants write permission.

The [Document library](../../../packages/zig/transit-document/README.md) owns the
deterministic change codec and merge evaluator independently of Station. The
installed service supplies its immutable index, publication and acceptance
boundary; extracting the evaluator does not change that service's lifecycle.
The direct-storage [`DocumentIndex` component](../../../packages/zig/transit-storage/docs/document-index.md)
stages private candidates over `.tseg` records and paged indexes. It exposes no
public Document admission, accepted revision lookup or collection lifecycle.

The direct-storage [partition component](../../../packages/zig/transit-storage/docs/document-partitions.md)
also supplies bounded WAL recovery and authenticated retained revision reads with
cumulative byte/work budgets. It currently accepts supplied state bytes; logical
evaluation and the installed service lifecycle remain separate integration work.

The offline [Document profile library](../../../packages/zig/transit-document-profiles/README.md)
interprets JSON and a declared UTF-8 XML subset with bounded caller-owned memory,
ordered events and raw part offsets. Its verified reader checks grammar, byte
count and content hash before reporting complete. Intermediate events remain
provisional; complete interpretation does not publish a revision or authorize an
effect. The [profile contract](../../../contracts/DOCUMENT_PROFILE_V1.md) binds
exact grammar, limits, coverage and provenance independently of merge rules.
Other protocol and compound-format names in that contract are vocabulary, not
implemented parser or gateway capabilities.

Start with the [Document example](../../../examples/station-document/README.md) and
[service guide](../../../packages/zig/transit-station-document/docs/service.md).
The [shared-notebook recipe](../guides/workload-examples.md#share-an-incident-notebook-with-zig)
shows revision-bound field reads. Path/sequence access and separately versioned
search/analytical projections are architectural priorities; arbitrary search is
not part of the current Document interface. See [workloads](workloads.md) and
[performance](performance.md) for the planned structures and measurement limits.

The [named-resource lifecycle](state.md#state-and-higher-level-resources) binds a
catalog identity to an actual initialized Document. Its explicit allocation,
reservation, service creation and publication steps remain separately observable.
The catalog marker does not replace current Document access or merge authority.

## Identities and merge rules

Document identity, replica ID, operation ID, accepted revision and merge epoch are
separate from PID or worker generation. Changes name their replica predecessor
and explicit observed operation/anchor dependencies. Missing dependencies reject
as not accepted; resubmit after obtaining the prerequisite. There is no unbounded
hidden pending queue. Reusing an identity for different content conflicts.

Map fields are observed-remove multivalue registers. An assignment removes only
the assignments it explicitly observed. Concurrent unseen values remain visible
as conflicts; resolution is a new assignment naming the values it replaces.
Missing and null are different. No wall clock picks a winner.

Maps, lists and editable text have immutable object identities. Replacement
creates a new object. Removing a parent detaches its descendants; concurrent
descendant edits remain history but cannot resurrect the removed parent.
Move/reparent and cycles are unsupported.

Lists and text use stable element IDs and a predecessor relation, with
deterministic descending-ID order for concurrent siblings. Deletion marks the
named element; insertion after a deleted anchor remains ordered. Text elements
are Unicode scalar values, not graphemes; there is no normalization. A scalar
UTF-8 string value is different from growing editable text.

## Acceptance and bounds

A change contains up to eight operations. Inline strings/binary are limited to
96 bytes, and a field has an eight-unresolved-assignment quota. Refusal does not
accept a prefix or silently expire old conflicts. Exact encoding and all bounds
are in the [Document contract](../../../contracts/STATION_DOCUMENT_V1.md).

Immutable index nodes and change bytes are staged through bounded publication.
Only the final validated Document head accepts the change and binds its index
root, versions and history floor. Intermediate node publication is not partial
acceptance. Interrupted jobs recover or receive explicit disposition.

Checkpoint roots preserve causal and deletion evidence as well as visible values.
Default history is unlimited. An opted-in finite merge window advances the
epoch/floor only through validated checkpoint publication. Old replicas receive
a resynchronization requirement; stale edits cannot resurrect deleted values.

## Read, query and recover

An accepted reference fixes resource, Document, epoch, type and accepted revision.
Bounded path reads distinguish missing, null, value, object and conflict. Sequence
reads return an item, continuation/progress or end; keep the exact snapshot and
bound traversal work, including steps that do not yield a visible element.

Each disclosure checks current policy and history/lifecycle bounds. Retaining an
old reference does not bypass compaction or retirement. Unified [query v1](queries.md)
reads declared accepted projections with five-state cells; it does not include
tentative edits or convert conflicts into arbitrary winners.

The [remote caller guide](../../../packages/zig/transit-station-document/docs/remote.md)
binds an allowed replica, frozen request and original reply route. All ten non-Zig
SDK targets support Document changes and reads. The service runs locally, in
Compose and in the reference deployment. It uses the Transit Document format;
external CRDT wire formats are unsupported. See [the package](../../../packages/zig/transit-station-document/README.md)
for exact APIs.

The storage library also has an integrated causal map-tree component:
`DocumentPartition.applyCausal` derives accepted state from canonical changes and
persists it in bounded `.tseg` records. It supports full document/replica identities,
nested map assignments, observed removals and paged large string/binary values;
exact causal retries retain their first revision. Pinned path pages distinguish
value, null, missing, type error and conflict and recheck authority before
disclosure. See the [partition guide](../../../packages/zig/transit-storage/docs/document-partitions.md#evaluated-causal-map-trees)
for its format, bounds and exclusions. This component does not change the installed
Document API described above or provide list/text editing, versioned merges,
logical checkpoints, succinct tree/subcolumn integration or Document transactions.
