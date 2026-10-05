# General Table candidate data v1

This format composes pure general Table candidates over the
[Station immutable index](STATION_INDEX_V1.md), with a captured-KV head codec.
It does not admit catalog lifecycle or a SQL transaction. The owner supplies current
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
When both records are absent, one bounded committed namespace page must prove
there are no orphan records. Private namespace writes cannot hide or substitute
for that check. Read failure rejects initialization.

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

## Table heads

`TableHead` stores one `h` record at ID/index zero in the Table namespace. Its
`STH1` value is the 32-byte shared definition, resource:u64, object:u64,
head revision:u64, schema reference (48 bytes), root-presence:u8, optional root,
row count:u64, next record ID:u64, pending operation:u64 and retired:u8.
All integers are little-endian; the root-presence and retired flags are 0 or 1.
A root is record reference (48 bytes), level:u8, minimum key length:u8, minimum
key bytes and entry count:u64. The minimum is a 21-byte row or 53-byte key entry.
The maximum complete head is 245 bytes. Trailing/truncated values, invalid flags,
foreign definitions, wrong resources and inconsistent identities/counts reject.

The head binds one resource/object and exact immutable schema/data references.
Schema and root IDs precede the next-record floor. Empty Tables have no root;
opening the schema checks that total index entries equal row count times one
(unkeyed) or two (keyed). A schema decode checks its object identity. Schema
revision and head revision are distinct; pending work does not reinterpret rows.

Creation requires an absent head, revision-one schema and empty data, after
schema storage is readable in the enclosing turn. Replacement compares the
complete expected head bytes, requires the next revision and a nondecreasing
record floor, and prepares one private write. The owner validates all successor
records before replacement and publishes outcome/input progress atomically.
These helpers do not manufacture current permissions or operation admission.

A retired head is permanent and cannot have pending work. Neither creation nor
replacement can reset it. Its schema and immutable data remain available to
separately authorized retained readers and recovery owners; loading a head alone
does not admit a new read/write or resolve a live catalog name. Catalog DROP
dependencies, name removal/reuse and physical cleanup remain explicit owner work.

## Single-row publication and recovery

`TableWrite` composes insert/update/delete over this representation. Its caller
authenticates the principal, applies current read/write/cancel policy and routes
the exact resource/object on every step. This helper does not infer permission
from a request, head, receipt or PID. Native commit supplies current grants,
resource revision validation, ownership and fencing. It performs no network I/O.

A request contains resource, principal, operation, complete captured schema and
one typed row insertion/replacement or row-identity deletion. Insert identity is
`(principal + 1, operation, 0)`; root principal zero remains distinguishable and
the row identity survives later key changes. SQL column assignments and
predicate/multi-row selection require their separate statement owner. This
single-row helper does not admit a loop of independently accepted rows as one
atomic multi-row SQL statement.

Request identity hashes the domain `transit.table.write.v1` followed by NUL,
the raw 32-byte shared definition, resource/principal/operation:u64le, complete
schema fingerprint, action:u8 (insert=1, update=2, delete=3), and exact `FTR1` row
or 20-byte row identity. It recomputes the digest from typed input. Receipt keys
are `00 57`, object:u64be, principal:u64be, operation:u64be, exactly 26 bytes.
Different input at the same key rejects rather than overwriting the operation.

The `STW1` receipt is exactly 158 bytes: magic, raw shared definition, resource,
object, principal and operation (u64 each), request digest (32 bytes), admitted
input, completed input, source head revision, first record, exclusive-end record,
matched count and changed count (u64 each), state:u8 and rejection:u8. All value
integers are little-endian. States are building=1, applied=2, rejected=3 and
cancelled=4. Rejections are none=0, row exists=1 and row identity exists=2.
Building has zero completion input; terminal input is nonzero and no earlier
than admission. This profile's matched/changed counts are at most one, with
changed no greater than matched. Rejection/cancellation have zero counts.
Building requires a nonempty reserved range and one changed row. Unknown flags,
inconsistent counts/identity, truncation and foreign definitions reject.

The owner first builds a bounded private candidate against the current head and
exact schema. It attempts to compose all needed pages, successor head and terminal
receipt in one turn. If that cannot fit, it discards that private attempt and
atomically reserves the complete record range in the head with a building receipt.
The head still points at the original rows/schema. Its pending identifier is the
first reserved record ID; this is separate from the caller's operation ID.

Later steps reconstruct the same candidate from frozen input/root and the exact
reservation. They verify head revision, pending identity, record range and counts
before resuming page storage. Competing operations receive `TableBusy`; changed
source/reservation state rejects. Staging does not publish a row prefix. A final
turn swaps the head, clears pending work and saves exact terminal counts together.
No returned private status is durable until native commit accepts the whole turn.
Allocation/validation failures restore this call's private proposal, retaining
read-error poisoning. A bounded staging turn may commit ready pages and continue
later when final head/receipt writes would exceed the shared mutation budget.

Exact terminal repeats return the original receipt before reading the current
head/schema. Deleting a conflicting row does not convert an earlier rejection
into an insertion. Retiring or replacing a catalog name does not rebind the
original operation. Same-value updates match one/change zero; absent updates or
deletes match/change zero. These counts are saved at publication, never reread
from later Table state.

Cancellation atomically clears this reservation's pending head and closes its
receipt while preserving original data and the nondecreasing record floor.
Repeated cancellation returns that terminal result; an applied write remains
applied. Immutable candidate pages and any unfinished Publication quota remain
retained for separate, authorized reference-safe cleanup. Cancellation itself
does not reclaim bytes, reuse IDs, change earlier results or erase recovery
evidence. Native caller/SQL admission and disk-fault qualification are separate
from this captured-turn coordinator.
