# Direct Document Contract v1

This contract defines the shared wire, storage, and catalog vocabulary for
direct `DOCUMENT` resources in [`transit-protocol`](../packages/zig/transit-protocol/README.md)
(`DocumentDeclaration`, `DocumentOperation`, and `DocumentRead`) and
[`transit-storage`](../packages/zig/transit-storage/README.md). Every structure
requires the current `Growth.current_definition` value and rejects missing or
foreign definition markers before execution.

The reflected [data lifecycle schema](data-lifecycle-v1.schema.json) owns exact
field shapes; the [shared fixture](../packages/zig/transit-protocol/src/fixtures/document-v1.json)
exercises full-width 64-bit and 128-bit identities, causal CRDT and versioned
lineage, finite merge-window checkpoints, and pinned read cursors. The installed
[Station Document v1 service contract](STATION_DOCUMENT_V1.md) remains active
until the common transaction decision owner composes Station turn outputs with
direct partition commits.

## Declarations, profiles, and routing

`DocumentDeclaration.Declaration` binds the current definition, an immutable
`DataLifecycle.Definition` (`interpretation`) on branch one, an exact `schema`
content attribution (`DataLifecycle.Content`), `Configuration`, and `Limits`.

`Configuration` binds `Partitioning` (`count`, optional `key_column`,
`hash == .sha256_64`), a merge `Profile` (`causal_crdt` or `versioned`),
`Shredding`, and `Retention`:

- `causal_crdt`: conflict-free causal document trees and collaborative text
  using observed-remove multivalue registers, RGA sequences, and `SpanText`
  spans anchored by replica lineage.
- `versioned`: deterministic three-way structural tree merges (`VersionedMerge`)
  that preserve conflicting leaf or node-kind assignments as explicit `conflict`
  cells until resolved by a successor revision.

`Shredding` configures automatic subcolumn shredding in `.tseg` storage segments:

- `frequent_path_threshold` (`1..=4096`): minimum occurrences within a segment
  before an undeclared path is promoted to a typed subcolumn.
- `max_shredded_columns` (`1..=256`): maximum shredded path subcolumns per
  `.tseg` segment before remaining paths stay in the succinct balanced-parentheses
  (`SuccinctTree`) residual stream.
- `default_collation` (`utf8_binary`, `ascii_ci`, `ebcdic_cp037`): default text
  collation ($\kappa$) governing shredded string zone maps and key comparisons.

`Retention` has nullable positive `max_age_ms` and `merge_window_revisions`
bounds; `null` retains unlimited history. Zero values reject with
`InvalidDocumentRetention`. `Limits` requires non-zero budgets for
`change_bytes`, `operations_per_change`, `path_depth`, `read_steps`,
`read_bytes`, and `unresolved_conflicts`.

`Declaration.requireSuccessor` verifies that a definition successor retains the
same `Object`, advances `revision` by one, and preserves `partitioning`,
`configuration.profile`, and `configuration.shredding.default_collation`.
`Partitioning.select` hashes canonical collation-aware key bytes with SHA-256,
interprets the first eight digest bytes as a big-endian `u64`, and takes modulo
`count`.

## Target identity, lineage, and mutation receipts

`DocumentOperation.Partition` binds the current definition, an `interpretation`
on branch one, and a zero-based `partition` ordinal. `Target` combines
`Partition` with a non-zero 16-byte logical `document` identity.

`Lineage` records the causal or versioned ancestry of a document mutation:

- `profile` (`causal_crdt` or `versioned`) and non-zero `merge_epoch`.
- `base_revision` (`0` only for initial document creation; positive for updates)
  and optional `parent_revision` (permitted only for `versioned` three-way
  merges when `base_revision > 0`, `parent_revision > 0`, and
  `parent_revision != base_revision`).
- `replica` (`Replica`): required for `causal_crdt` and optional for
  `versioned`; binds non-zero 16-byte `id`, `epoch == merge_epoch`, `sequence`,
  and `preceding_sequence` (`preceding_sequence + 1 == sequence`).
- `raw_span` (`RawSpan`): optional `(part_id, byte_start, byte_end)` provenance
  anchor into an immutable raw envelope attachment.

`Mutation` binds `target`, `operation` (`DataLifecycle.Operation`), `lineage`, a
non-zero `operations` count, and a `payload` (`DataLifecycle.Content`).
`MutationReceipt` binds the accepted `mutation`, a strictly advancing
`accepted_revision`, resulting `state` (`DataLifecycle.Content`),
`unresolved_conflicts` count, and the durable `accepted` (`DataLifecycle.Position`).
`requireMutation` rejects conflicting retries with `DocumentMutationConflict`.

`ReplicaState` tracks per-replica deduplication and epoch fencing for a specific
`(target, principal, replica.id)`:

- `check` returns `.retry` when a candidate's sequence is within
  `(discarded_through, replica.sequence]`; `.apply` when
  `sequence == replica.sequence + 1` in the same epoch; and `.advance_epoch`
  when `epoch > replica.epoch` starting at `sequence == 1`.
- Older sequences at or below `discarded_through` reject with
  `DocumentReplicaReceiptExpired`; sequence gaps reject with
  `DocumentReplicaSequenceGap`; lower epochs reject with
  `DocumentReplicaFenced`; and mismatched principals or replica IDs reject with
  `DocumentReplicaConflict`.

## Cuts, finite merge-window checkpoints, and retained reads

`Cut` fixes `target`, `merge_epoch`, `retained_from`, `accepted_revision`
(`1 <= retained_from <= accepted_revision`), `state` (`DataLifecycle.Content`),
and `accepted` (`DataLifecycle.Position`). `Cut.requireRevision` rejects
revisions below `retained_from` with `DocumentHistoryUnavailable` and revisions
above `accepted_revision` with `DocumentRevisionBeyondCut`.

`Checkpoint` advances a document's merge epoch (`next_epoch == previous_epoch + 1`)
and establishes a validated `retained_from <= checkpoint_revision` with
a `checkpoint` content digest. `CheckpointReceipt` binds `checkpoint` and the
resulting `cut`.

`DocumentRead.Request` opens a bounded revision-range pin (`from_revision`,
optional `through_revision`, `max_steps`, `max_bytes`) under a
`DataLifecycle.Operation`. `Receipt` binds the original `request`, the pinned
`cut`, resolved `through_revision`, `source` (`DataLifecycle.Content`), and
`accepted` (`DataLifecycle.Position`). `Cursor` binds `read` (`Handle`),
cumulative `Coverage` (`cut`, `from_revision`, `through_revision`,
`next_revision`, `steps`, `bytes`, `complete`), and a non-zero 32-byte
`authentication` tag (`HMAC-SHA256` in storage). `Release` and `ReleaseReceipt`
record explicit pin release by the owning principal using a distinct operation.

The direct storage owner enforces `max_steps` and `max_bytes` cumulatively across
the pinned range. It refuses the next revision with `DocumentReadLimitExceeded`
before allocating its state if either budget would be exceeded; a delivered
prefix is not complete coverage. State bytes returned by a successful fetch
belong to the caller and survive subsequent fetches. The current implementation
loads one whole revision within these budgets; it does not page within a revision.

Cursor creation requires the exact recorded read receipt. Release must name the
same logical target as the retained source, as well as its owning principal.
Every fetch checks current authorization before reading and before disclosure,
including repeated cursors and empty terminal observations.

## Retained partition membership

`DocumentRead.Collection` defines a storage-component read of one exact logical
head directory. Its `Cut` binds the declaration/partition target, observed WAL
position, `changed_next_lsn`, and nullable head-directory digest. The data frontier
is the next LSN after the last head change, initially 1; read pins, receipt aliases
and archival/recovery maintenance do not advance it. A null directory denotes an
accepted empty partition. Missing directory storage is an error. Independent
partition cuts form a vector; they do not establish an atomic collection snapshot
or a serializable transaction guard.

`Request` binds the owning operation, cumulative `max_steps`/`max_bytes`, and
per-fetch `page_heads` (1–16) and `page_bytes` (positive, no larger than
`max_bytes`). Cumulative limits must fit the declaration's read limits. `Receipt`
binds the original request, cut, immutable source and pin acceptance position,
exactly one WAL record after the observation. Exact retries recover this receipt;
changed request budgets or targets conflict. Retrying acquisition after release
does not reactivate the pin. These pins have no implicit expiry.

`Cursor` authenticates the retained handle and cumulative coverage: exclusive
`after` document ID, returned `heads`, consumed `steps`/`bytes`, and `complete`.
Each `Page` owns an inline array of at most 16 nullable heads, a count and a
successor cursor. Entries before `count` are present and strictly ordered by the
16-byte document ID; all remaining entries are null. Each head contains its exact
revision cut and unresolved-conflict count. A page does not materialize logical
values. Prior pages survive scratch resets and later fetches.

A scan charges one step plus every visited directory page, including cache hits
and bounded lookahead. Bytes count canonical encoded head values, excluding
fixed cursor/source overhead. These are logical work budgets, not physical I/O
measurements. A page stops at its row/byte budget; cumulative exhaustion or a
single head exceeding the page byte budget yields `DocumentReadLimitExceeded`.
A failed fetch discloses no partial page and establishes no completion. Repeating
the input cursor repeats the same traversal. Only directory exhaustion establishes
`complete`; repeating a terminal cursor returns an empty, complete page.

The host supplies a trusted current principal separately from the cursor. It must
match the pin owner. Every fetch validates authentication and the live collection
pin and checks current scoped read authority before reading and after buffering,
including empty and repeated terminal pages. `Release` uses a distinct operation
of that principal and the exact original target. Lost acquisition/release replies
require recovery of the original operation, never another logical read. A changed
signing key invalidates old cursors; a currently authorized owner can obtain a new
cursor from the original receipt without changing its retained basis.

Collection pins retain their immutable directory and its referenced revision
states, logical indexes and segments through the shared storage graph. Release
removes this dependency, but other accepted history, checkpoints or pins can
still retain the same objects. Missing/corrupt sources or pages fail closed.
There is no logical-document deletion operation in this component profile;
absence means no head at this cut, not an invented deletion revision. Catalog
DROP, staged-candidate ownership, operation discovery and Document transaction
preparation are separate contracts not enabled by enumeration.

## Integrated causal map-tree storage slice

`DocumentPartition.applyCausal` is a storage-component operation, not an installed
Document service or another selectable public engine. It evaluates the canonical
change below, seals `DocumentIndex` records in `.tseg`, and submits the derived
root and conflict count through the partition's single fenced WAL append. The
opaque `applyMutation` receipt-owner seam cannot introduce or replace a logical
root. Opaque checkpoints cannot replace logical roots either. Existing installed
Station operations retain their current contract until their coordinated cutover.

### Canonical input

`LogicalChange` owns the allocation-free encoder and borrowed decoder. A frame
contains the following fields in order; integers are unsigned little endian
unless stated otherwise. Native struct padding is never serialized.

| Field | Width / representation |
| --- | --- |
| Magic | Eight bytes `DCHANGE1` |
| Definition | Mandatory current shared definition, 32 bytes |
| Logical document | 16-byte identity, not all zero; distinct from the catalog object |
| Merge epoch | `u64`, positive |
| Replica | 16-byte identity, not all zero |
| Sequence / predecessor | Two `u64`; sequence positive, predecessor exactly sequence minus one |
| Operation count | Positive `u16`, exactly the number of encoded operations |
| Each operation | Object dot; `u32` field-name length and UTF-8 bytes; `u16` observed count and dots; value tag and optional value body |

A dot is **26 bytes**: replica bytes, big-endian `u64` sequence, big-endian `u16`
zero-based operation ordinal. The all-zero dot denotes the root map only. Other
dots require nonzero replica and sequence. Observed dots must be strictly ordered
by these complete bytes, without duplicates. Operations may reference existing
assignments or earlier operations in the same change; missing dependencies refuse
the whole candidate. Dependency evidence survives removal and map replacement.

Tags are `null_value=0`, `boolean=1`, `signed=2`, `unsigned=3`, `float=4`,
`string=5`, `binary=6`, `map=7`, and remove `255`. Remove has no body; every other
tag has a `u32` byte length followed by that many bytes. Null and map bodies are
empty; boolean is one byte, zero or one; signed/unsigned numbers are eight-byte
little-endian integers; float is a finite IEEE-754 binary64 bit pattern in little
endian. Strings must be UTF-8. Unknown tags, invalid lengths, noncanonical observed
sets, foreign definitions, truncated input and trailing bytes refuse. No decoder
substitutes the current definition for a missing field.

The frame's document, epoch, replica, sequence, predecessor and operation count
must exactly match the outer `Mutation`. The outer current interpretation,
`causal_crdt` profile and payload length/digest are also checked. This slice rejects
raw provenance and merge-parent requests; profile parsers, raw-part bindings,
versioned merges and sequence editing require their own integration.

### Evaluation and identity

Fields use exact UTF-8 names; string payloads retain their declared logical kind
and bytes. This path does not perform collation-dependent comparison or pruning.
Field hashes are addresses: existing complete field-name chunks must compare
equal before the evaluator uses the register. Replacing a map assigns a new dot,
so its old descendants stay detached. Remove clears only observed assignments;
unobserved concurrent assignments survive, ordered by complete dot bytes. An
explicit null differs from a missing register. Path traversal through a scalar
reports `type_error`; an unresolved register reports `conflict`. The stored
conflict count is the number of extra active alternatives across retained
registers, including detached objects; it is not a visible-tree field count.

Client-operation recovery and causal-change identity are separate. The paged
history maps `(replica, sequence)` within one logical document/epoch to the first
operation and canonical payload digest. Reusing that identity with different
payload or lineage refuses. An exact duplicate under another operation appends
only the new operation's receipt: its revision and state remain the first accepted
ones, while its `accepted` position records this new receipt's WAL decision. It
does not advance the document head, replica frontier or revision directory.
Replaying either operation returns its own original receipt.

### Persistent representation and budgets

`DLOG0001` state objects contain the mandatory shared definition, exact target,
epoch, derived conflict count, mandatory `layout` (`causal_map` or `ordered`),
`nodes`, `parts` and a validated `DocumentIndex.Root`. Causal roots require zero
node/part counts; ordered roots require a nonzero node count. Missing fields or
an earlier shared definition refuse; readers do not infer a layout. The binary
prefix includes the shared definition before the canonical JSON descriptor.
State descriptors are at most 4,096 bytes. Format dispatch verifies those bounded
bytes against their accepted digest before deciding whether they own child roots;
a corrupt marker cannot turn a logical root into an opaque collector leaf.
`readNextRevision` returns this descriptor for a logical revision, not a materialized
tree; use pinned path pages to consume values. The root binds immutable ordered-key
and record-location directories. Record locations identify shared `.tseg`
key/value rows, validated against the declared object/definition and epoch.

Assignment records retain parent object dot, field hash, logical kind, value
length and depth. Field metadata stores active count and complete-name length.
Record keys are at most 64 bytes; the ordered index has no key-continuation
directories in this layout. Names and values occupy **240-byte chunks**; active dots occupy separate indexed
records. Active vectors compact on update, so removing a field repeatedly does
not make evaluation scan its entire tombstone history. Logical collection size
and retained revision history do not determine resident array sizes. This is an
explicit causal record tree, **not** the final BP topology, adaptive subcolumn or
span-edit representation.

The default partition workspace reserves 512 pending records, a 256 KiB segment
buffer, 2 MiB segment scratch and eight logical-index cache pages. The existing
`DocumentIndex.Store.Options` supplies explicit deployment overrides and validates
its bounds; exceeding a candidate/segment/scratch/index-work budget refuses before
WAL acceptance. One owner serializes one active candidate. Declaration limits bound
change bytes, operations, depth and extra conflict alternatives. `read_steps` also
bounds logical-index operations during this initial evaluator slice. Values may
span many records, but a single change still fits the admitted request and private
candidate budgets. This does not claim arbitrary-size streaming ingestion or zero
heap allocations for the complete storage path.

`DirectStorageGraph` follows logical state descriptors into both directories and
all referenced `.tseg` segments. Sealed candidates have no acceptance authority;
unreferenced segments remain collectible. Logical checkpoint/epoch advancement
refuses until its evaluator and graph semantics are integrated. Retention does not
expire data to accommodate capacity pressure.

### Pinned path pages

`causalCursor` requires an exact recorded read receipt with one selected revision.
The cursor binds its retained handle, revision, full path digest, alternative,
byte offset, cumulative steps/bytes and completion through a separate HMAC domain
and the owner's nonzero persistent signing key. A path contains nonempty UTF-8
components within declared depth and cumulative change-byte limits.

`readCausalPage` returns an inline-owned page of at most 240 value bytes, the
five-state path status, selected assignment/kind, complete value length and byte
offset. Conflict alternatives are traversed in full-dot order. A byte page may
split a UTF-8 scalar; it does not assert a complete string. Map/null/empty values
still return an explicit terminal page. Only the authenticated completion flag
establishes exhaustion; budget refusal never means completion. Logical-index
steps and disclosed value bytes accumulate across calls. Descriptor and directory
lookup add bounded per-page overhead. Every call checks the live pin and current
authority before reading and again before disclosure, including missing and
terminal results. Successful pages retain no pointer into scratch or caches.

These storage-component cursors do not replace the shared installed caller ABI.
Collection scans, list/text editing, BP navigation, adaptive shredding, versioned
merge, logical checkpoints, Document transaction participants and installed
catalog/client/SQL/Station exposure remain separate gates.


## Integrated ordered versioned storage slice

`DocumentPartition.applyOrdered` accepts the
[canonical ordered input](TRANSIT_STORAGE_V1.md#canonical-ordered-document-changes)
for a declaration using the existing `versioned` profile. It checks the complete
payload, current definition/interpretation, full Document ID and merge epoch.
The outer mutation has one operation, no replica, parent revision or outer raw
span, and a base revision equal to the header's expected revision. Create requires
revision zero and epoch one. An existing tree requires its exact accepted head;
a stale or future expectation returns `DocumentRevisionConflict`. Exact original
operation retries return their recorded receipt even after a newer revision.
A new operation using an old expected head is a conflict, not a causal alias.

An empty ordinal path supplies a complete replacement tree and raw-part envelope.
A nonempty path replaces that subtree, including its root name; callers include
the intended edge name in the replacement. Ordinals count immediate ordered
children, preserving duplicate names. Patch paths cannot create missing parents
or traverse a scalar. A patch retains the original raw parts and may add parts;
reusing an ID with different bytes/digest returns `DocumentPartIdentityConflict`.
Every referenced span must fit its verified part. Patching a tree does not rewrite
the captured source frame or imply that the modified tree still parses from it.
Constructed nodes can omit provenance. Profile interpretation is separate.

The offline profile adapter can supply verified JSON/XML/MIME single-part inputs.
Its [ordered candidate mapping](../packages/zig/transit-document-profiles/README.md#ordered-storage-candidates)
uses the same generic node kinds and verified raw parts. MIME fields remain
ordered binary nodes under a header list, with one separate binary body node;
parser fetch windows do not alter the tree. The descriptor attestation remains
outside the accepted generic tree. This adds no wire kind, installed route or
transport authority.

The owner derives the whole candidate before one fenced WAL acceptance. The
preorder residual tree stores node metadata (`N`), name (`K`) and value (`V`)
chunks, raw part metadata (`P`) and bytes (`R`), and a `2N`-bit BP stream (`B`) in
shared `.tseg` key/value rows. Keys are a tag followed by big-endian `u64` node or
part ID and chunk ordinal. Chunk payloads are at most 240 bytes. BP uses an open
bit of one, close bit of zero, least-significant bit first, and zero tail padding.
Topology is persisted; rank/select directories and constant-time navigation are
not implemented on this path. Ordinal path resolution scans bounded residual
metadata. A patch rebuilds its resulting tree and envelope; it is not an
incremental-update or write-amplification performance claim.

A depth stack has `path_depth + 1` entries (root depth zero). Canonical input
remains bounded by `change_bytes`; names, values and parts have `u32` input
lengths. Total retained nodes and revision history do not size the pending slab.
The builder seals private segments when that slab fills and resumes from the
sealed root. `read_steps` bounds indexed reads/writes during construction,
`index_work_bytes` bounds cumulative encoded logical-index staging across those
seals, and configured segment/scratch/cache budgets remain independent. A budget,
span, structure, part or policy refusal publishes no prefix. Intermediate segments
may remain unreferenced; they acquire no revision or retention authority.

`orderedCursor` requires a retained read receipt for exactly one revision.
Select the tree, one raw part ID, or topology bytes. `readOrderedPage` emits owned
node metadata followed by any name/value byte sections, or chunks of the selected
raw part/topology. The HMAC domain is `transit.document.ordered.page.v1\x00`;
it binds the current definition and every cursor field, including source handle,
revision, selection, ordinal, section, offset, cumulative budgets and completion.
Metadata encoding lengths and returned chunk bytes count against `max_bytes`;
indexed operations count against `max_steps`. Directory/descriptor lookup adds
bounded per-page overhead. Bytes may split UTF-8 scalars. Every call checks the
live pin and current authorization, including repeated/terminal calls, and
reauthorizes after buffering. Scratch/cache reuse cannot invalidate returned pages.

`inspectOrderedNode(receipt, ordinal, guard)` returns structural metadata for a
zero-based preorder node in that same single-revision retained read: parent,
first child, next sibling, depth and exclusive subtree-end ordinal. Missing
relations are explicit nulls; an out-of-range ordinal returns
`DocumentPathMissing`. The result owns its fields and reports its revision and
consumed work. It neither accepts work nor acquires another pin.

The reader scans persisted BP chunks with a caller-bounded depth stack, retaining
one 240-byte topology chunk at a time. Each examined bit and each indexed chunk
or node lookup consumes one `max_steps` unit. Structural output consumes 23
bytes plus eight for each non-null parent/child/sibling against `max_bytes`;
revision and work attribution are control metadata. Each call starts its own
bounded inspection from the original retained receipt; it is not a continuation
of a previous page. Exhaustion returns `DocumentReadLimitExceeded`, with no
partial navigation result. Receipt identity, live retention and current rights
are checked before work, with authorization repeated after buffering, including
repeated inspections. The traversed topology prefix is validated and its target
depth is checked against residual node metadata. This is linear bounded scanning,
not a rank/select index, constant-time navigation or an exhaustive storage scrub.
It adds no persisted layout, cursor format or installed endpoint.

The existing retained graph follows both layouts into their directories and all
reachable segments, including raw parts and topology. Opaque mutations and caller
checkpoints cannot replace either logical layout. Three-way merges, logical
checkpoints, incremental text edits, adaptive subcolumns and Document transaction
participation remain outside this increment. This component does not replace the
installed Station Document lifecycle, native/SDK routes or SQL capability.
