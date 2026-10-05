# General Table candidate data v1

This format composes pure general Table candidates over the
[Station immutable index](STATION_INDEX_V1.md). It does not define or admit a
native Table head, catalog lifecycle or transaction. The owner supplies current
authorization, frozen source identity, staging and atomic publication.

Each Table uses one index with unsigned lexicographic keys. Row keys are ASCII
`R` followed by the 20-byte big-endian row identity from
[Table schema v1](TABLE_SCHEMA_V1.md). Their values are immutable row-blob
references: u64 record ID, u32 format, u32 length and 32-byte Publication digest,
exactly 48 bytes. These reference integers are little-endian. Row format is
`0x54525701`; its complete payload is `FTR1` with the exact logical values and
physical layout fingerprint. The record ID is nonzero; length is bounded by the
Fuze row codec. The owning store supplies the fixed resource/namespace.

Primary-key keys are ASCII `K`, the 32-byte SHA-256 canonical equality-key digest,
then the 20-byte row identity. Their values are empty. Different row identities
retain distinct equal-digest candidates. Readers compare actual typed key values
before concluding equality; collisions never establish a constraint violation.
Unkeyed Tables have no `K` entries and permit duplicate payloads. A row's identity
does not change when its primary key changes.

Index node loads verify reference metadata and Publication commitments. Blob
loads verify their complete commitment, physical descriptor and row identity.
Missing records, malformed references or mismatched layouts reject. Source
errors are never converted into absent rows or successful empty scans.

Insert requires an unused row identity and, when declared, a unique typed key.
Update/delete return matched=0 and changed=0 for an absent row. Existing updates
return matched=1; changed=0 means canonical stored row bytes are identical and
stages no new record. Changed counts preserve representation differences such as
JSON whitespace and IEEE zero sign, independently of query operator support.
Updating a key replaces its index entry; updating another value leaves the key
entry unchanged. Delete removes both row and key entries from the successor.

Every result is a candidate root with counts. An owner must validate a complete
statement and atomically publish rows/indexes, schema/data head, terminal result
and input progress. Intermediate immutable pages are staging artifacts and do
not make a statement prefix visible. Failed builds retain old roots and may
leave unreachable records subject to explicit, reference-safe cleanup.

One index read is at most 4 KiB; one row is bounded by its logical codec. Traversal
holds one decoded collision/scan candidate at a time and releases it before the
next. Small encodings use 4 KiB scratch; larger encodings allocate only within
the row/key envelope bounds. Total Table size is not a resident-memory bound.
Owners enforce operation work/deployment quotas and source lifetime separately.

## Private row-operation overlay

`TableCandidate.Overlay` borrows an authorized source and reserves a nonzero,
exclusive-end record-ID interval. It builds one row operation without writing
KV. At most three index edits create 195 nodes (two per level and one new root
per edit) and one bounded row blob. Its allocation bound is 195 × 4096 bytes
plus the maximum row envelope, independent of Table size. Allocation failure
discards private bytes; previously accepted roots remain unchanged.

Finishing verifies the successor's new node references and marks only reachable
nodes and row blobs. Intermediate copied paths are not published. Their IDs
remain consumed; the owner persists the reservation and never reuses them for
different content. Child and row references precede their containing node in
the same candidate interval. The sealed overlay rejects further writes.
An owner must keep its frozen input/root and reserved interval across staging
turns; this helper supplies neither an admission record nor a transaction.

## Captured KV page storage

`TablePages` stores records under Publication domain 8 and namespace equal to the
stable Table object ID in one resource. It requires a namespace manifest before
every read/write. The `d` key has ID/index zero and stores `STM1`, the exact
32-byte shared native contract definition, and maximum record bytes:u32le.
Missing, foreign or malformed definitions reject. Initialization never adopts a
preexisting budget with a missing manifest. Manifest and Publication budget are
initialized together; changing the configured limits rejects.

Records of 1–246 bytes use the `i` tag, record ID and index zero. Their value is
`STP1`, format:u32le, payload length:u16le and payload. Larger records use the
ordinary Publication descriptor/chunks in the same namespace. Record length
determines the representation; there is no fallback decoder. A record ID cannot
change representation or content. Reads verify the complete spec digest and
namespace definition under the supplied current/retained source. Missing data,
denial, altered bytes and cross-resource access reject. The known formats are
index `0x53495801`, row `0x54525701`, and schema `0x54534301` containing `FTS1`.

`stage` returns `ready` or `progress`. A small record prepares one private KV
write. A larger record performs one Publication begin/append/publish step, using
at most two private writes. `ready` means the record can be composed into the
enclosing turn; it does not mean that turn committed or the Table accepted the
statement. Errors roll back this call's private writes and preserve read-error
poisoning. Replay compares the immutable identity/spec and cannot overwrite it.

The per-record limit applies to both representations. Publication quotas bound
unfinished large records; the Table owner separately reserves complete operation
work and native deployment quotas apply to all retained records. Completed page
storage alone does not grant permission for admission, head publication, cleanup
or ID reuse. Cancellation/retirement and reference-safe collection remain owner
operations. This storage adapter does not publish a native Table head or expose
the general profile through SQL callers.
