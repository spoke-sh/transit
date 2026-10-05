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
