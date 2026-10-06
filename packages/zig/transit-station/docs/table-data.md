# General Table candidates

`TableData` builds immutable general Table candidates over `ImmutableIndex` and
caller-owned blob storage. It consumes the Fuze
[schema, row and key contracts](../../../../contracts/TABLE_SCHEMA_V1.md).
The executable [Table API](tables.md), catalog and native transports retain their
separate admission profiles. A candidate is not an accepted mutation.
The [candidate data contract](../../../../contracts/TABLE_DATA_V1.md) defines
index keys, row references and count semantics.

One index contains row identities and primary-key entries. Row entries point to
typed immutable row blobs; key entries combine a canonical key digest and stable
row identity. The reader verifies each blob commitment and exact physical layout.
Lookup scans equal-digest candidates one at a time and compares their actual typed
key values. A digest match alone cannot cause a uniqueness rejection. Unkeyed
Tables preserve duplicate values under separate row identities.

`insert`, `update` and `delete` return a successor plus matched/changed counts.
The old value and every retained index root remain unchanged. A same-value update
matches one row, changes zero and stages nothing. Changed means different
canonical stored bytes, including JSON whitespace and floating zero sign; this
does not add query equality to JSON. Key updates check uniqueness and replace the
associated index entry. Non-key updates leave key entries intact. Missing rows
match/change zero on update or delete.

`get`, `findKey` and `next` use a supplied source. `next` resumes by row identity
under the same immutable root; the caller must retain that root and schema.
Index reads are at most 4 KiB. A row read/encode is bounded by the Fuze row codec,
with a 4 KiB encoding scratch path for small values and bounded allocation for
larger ones. Returned rows own their values and require `deinit`. No collection
is loaded in full; resident work is independent of row count.

Sources provide `load(index_reference, output)` and `loadBlob(blob, output)`.
Candidate stores additionally provide `save(spec, bytes)` and
`saveBlob(spec, bytes)`, returning immutable record IDs. The owner supplies
authorization, exact publication namespace, deployment quotas, staging identity,
commit/recovery and cleanup. Each read must preserve the owner's current access
and retained-source rules. Unreachable records after a failed build are staging
artifacts, not accepted rows or permission to discard recovery evidence.

The Table owner must publish data, indexes, terminal counts and input progress
atomically, after complete statement validation. It must never expose intermediate
candidate roots as successful statement prefixes. `TableData` itself performs no
head publication, catalog mutation or kernel transaction.

`TableCandidate.Overlay` holds one row operation's new records privately and
marks the final root's reachable records before staging. Intermediate index paths
are discarded without a storage round trip. The owner supplies a reserved ID
interval and advances past all consumed IDs, including discarded paths. Memory
is bounded by three index edits and one row, independent of Table size.

`TablePages` adapts these records to captured or retained growing KV. A mandatory
namespace manifest binds the shared native definition and record limit. Small
pages use one inline KV value; larger pages use resumable Publication chunks.
Both verify exact commitments and current source access. A small keyed insert
can compose its row, final index page, head and outcome into four private writes.
Larger candidates require staging turns before a final head decision. The owner
must preserve input identity, source root and reservation across those turns.
These helpers do not perform catalog admission or establish end-to-end latency.

A source with bounded `prefetch` can acquire the namespace manifest and page
header together, then up to eight immutable chunks per native request. Each
header, chunk, ordinal and final digest still passes the same validation.
Retired or unpublished descriptors reject before chunk acquisition; prefetch
failures propagate without turning partial bytes into a readable record.

`TablePages.Reader` retains at most eight verified immutable index-node bodies.
A finite query can share this cache across its bounded pages. Reuse is scoped to
the exact publication resource, namespace and captured read basis. Every access
still checks the Table manifest and published descriptor; a new basis discards
the byte cache. Cached bytes do not authorize disclosure or clear a failed read.
Small inline records and row-value bodies retain their ordinary validation path.

`TableHead` binds the resource/object, head revision, exact schema/root, row count,
record-ID floor, pending work and retirement in one native value. `create`
requires a staged revision-one schema and an absent head; `replace` compares
the complete expected head before preparing a successor. The owner composes its
receipt and input progress in that same turn. Retirement cannot be reset, while
separately authorized retained readers can still decode the original schema and
data. This helper does not implement catalog DROP, name reuse or write admission.

`TableWrite.step` coordinates one typed insertion, complete-row replacement or
row-identity deletion. The owner supplies authenticated principal/operation,
captured schema and current policy. The helper recomputes intent identity, uses a
four-write direct publication when possible, or reserves IDs and a frozen head
before resumable staging. The final head and exact matched/changed counts publish
together. Other writes see `TableBusy` during staging. Repeated terminal intent
returns its original receipt even after the Table changes or retires.
The receipt records the owning coordinator: point DML, finite statement or ALTER.
The matching cancellation path checks that route before changing a reservation;
callers cannot select another path from the same raw operation identity.

`cancel` closes reserved work and releases the busy head without reusing IDs or
erasing receipts. Candidate pages and unfinished storage quota await separate
cleanup. Every returned result still belongs to the private turn until native
commit succeeds. This coordinator requires an admission owner and does not
compile SQL assignments, select predicates or grant access to receipts.

Key-addressed `patch` and `delete_key` inputs let an admitted compiler use complete
primary-key equality without inventing a current-row request body. A patch hashes
the original key and assignments, retains unassigned columns and checks the
resulting row/key constraints under the captured head. Recovery reads its saved
receipt before any new key lookup. The DML compiler qualifies this path only when
every predicate condition is part of that exact key equality.

`TableStatement.step` owns finite multi-row publication over a bound DML plan.
It freezes the original head, processes one row per step and saves a bounded
candidate root/cursor between turns. Readers continue seeing the original root
until all rows pass and a single final commit publishes the successor and counts.
A later duplicate rejects the whole candidate. Predicates read the original rows;
key changes cannot change selection or cause revisits. No-op and unselected rows
advance progress without data writes. Current authorization and native fencing
still belong to the enclosing owner. `cancel` preserves exact terminal evidence,
the old live root and consumed record IDs; physical cleanup remains separate.

`TableCleanup.step` collects only the exclusive interval of a rejected or
cancelled receipt. It rejects active/applied work, checks the head's record floor
and retains the exact receipt. One bounded native page finds the next allocated
inline record or Publication descriptor, skipping unused IDs. Inline records are
removed; unfinished Publications are abandoned and completed ones retired before
bounded chunk collection. Quota is released through Publication's existing owner.
The separate cursor survives interruption and cannot change ranges or intent.
Accepted roots, schema records, Table heads and permanent descriptors are retained.
Current cleanup authority remains the enclosing owner's responsibility.

`TableAlter.step` derives a schema transition from the exact original schema and
one selected change. Metadata changes share the old root; validation-only changes
check every frozen row; physical changes build a complete successor with the same
row identities and rebuilt keys. Schema staging finishes before source row reads.
The final turn swaps schema/root and saves the outcome together. A later-row
constraint or exact-conversion failure preserves the original head and records
its specific rejection. Interrupted work uses the shared progress/cancellation
and closed-candidate cleanup owners. Catalog name changes and dependencies still
belong to catalog admission, not this schema publication helper.
