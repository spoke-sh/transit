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

Primary-key keys are ASCII `K`, the first 16 bytes of the SHA-256 canonical equality-key digest,
then the 20-byte row identity. Their values are empty. Different row identities
retain distinct equal-digest candidates. Readers compare actual typed key values
before concluding equality; collisions never establish a constraint violation.
The 128-bit prefix selects a lookup bucket only. It is neither an integrity
commitment nor authorization evidence: immutable nodes and row blobs retain
their complete 256-bit SHA-256 commitments. Prefix collisions can add bounded
per-candidate reads but cannot substitute a row or weaken uniqueness checking.
The shorter entries reduce every keyed leaf's encoded size. Two small keyed
rows need a 234-byte leaf, within the 246-byte inline page payload, allowing a
changed point write to compose its row, index, head and receipt in four writes.
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

## Private candidate overlay

`TableCandidate.Overlay` borrows an authorized source and reserves a nonzero,
exclusive-end record-ID interval. It builds a point operation or bounded INSERT
batch without writing KV. A point operation needs at most three index edits,
creating 195 nodes (two per level and one new root per edit) and one bounded row
blob. The shared ceiling remains 196 records and 195 × 4096 bytes plus the maximum
row envelope, independent of Table size. A batch that reaches either ceiling
discards only its unfinished next row's private records and stages the preceding
complete rows. The unfinished IDs have never escaped or been staged. Allocation failure
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
key bytes and entry count:u64. The minimum is a 21-byte row or 37-byte key entry.
The maximum complete head is 229 bytes. Trailing/truncated values, invalid flags,
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
Large schema Publication cursors require a committed source: finish their
immutable publication before the head-validation turn. An inline schema can be
read through private point writes. These rules preserve the existing prohibition
on opening a Publication cursor after private mutations.

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

Key-addressed patches and deletes accept complete typed primary-key values.
Patches carry stable column IDs and typed constant/default assignments; omitted
columns retain their existing values. Request identity includes these inputs,
without reading a current row. On first execution the owner resolves the key and
applies assignments under the frozen head; terminal repetition returns its
original result without resolving the key again. A later change to an unassigned
column cannot change the original request digest, and a deleted/recreated key
cannot make an old deletion remove the replacement row.

Request identity hashes the domain `transit.table.write.v1` followed by NUL,
the raw 32-byte shared definition, resource/principal/operation:u64le, a 32-byte
enclosing-owner binding (zero for standalone unbound helpers), complete
schema fingerprint, action:u8 (insert=1, update=2, delete=3), and exact `FTR1` row
or 20-byte row identity. It recomputes the digest from typed input. Receipt keys
are `00 57`, object:u64be, principal:u64be, operation:u64be, exactly 26 bytes.
Different input at the same key rejects rather than overwriting the operation.
Additional actions are patch=4 and key deletion=5. Both encode their complete
canonical `FTK1` key preceded by length:u32le. Patch appends assignment count:u16le
and each column ID:u64le, a default/value tag:u8 (0/1), and for explicit values a
length:u32le plus complete typed `FVL1` envelope. Assignment order is part of
intent; DEFAULT remains distinct from a coincidentally equal explicit value.

The `STW1` receipt is exactly 254 bytes: magic, raw shared definition, resource,
object, principal and operation (u64 each), request digest (32 bytes), admitted
input, completed input, source head revision, first record, exclusive-end record,
matched count and changed count (u64 each), state:u8, rejection:u8, route:u8 and
the mandatory 95-byte execution witness below. All value
integers are little-endian. States are building=1, applied=2, rejected=3 and
cancelled=4. Rejections are none=0, row exists=1, row identity exists=2,
NULL not allowed=3, missing required field=4, character limit exceeded=5,
numeric overflow=6 and inexact conversion=7.
Routes are point=1, finite statement=2 and ALTER=3. The route byte is mandatory;
missing/unknown routes reject. The point coordinator admits at most one match,
while ALTER reports zero DML counts. Cancellation dispatch uses this recorded
route; a caller-selected DML path cannot close an ALTER behind its catalog owner.
Building has zero completion input; terminal input is nonzero and no earlier
than admission. Counts are full-width, with changed no greater than matched;
single-row publication returns at most one. Rejection/cancellation have zero
counts. Building requires a nonempty reserved range. The point coordinator records
its one-row candidate counts; finite statements keep provisional counts in their
private progress record and expose terminal counts only at publication. Unknown flags,
inconsistent counts/identity, truncation and foreign definitions reject.

The execution witness records the actual rejecting row and column before its
private candidate is discarded. Its encoding is source:u8 (none=0, input=1,
stored=2), row identity (20 bytes in `FTR1` big-endian order), column ID:u64le,
preview length:u8, truncated:u8 (0/1), and 64 zero-padded preview bytes. Column
zero identifies a primary key or row identity; a positive stable column ID
identifies a failing cell. Input row identity preserves the original INSERT
ordinal. Stored row identity identifies the original immutable source row, not
its current position. The escaped value preview uses the shared logical display;
composite key values follow declared key order. Truncation is explicit. Unknown
sources/flags, invalid identities, nonzero unused bytes, control characters and
invalid UTF-8 reject. A `none` witness has zero identity, column and preview;
non-rejected outcomes require `none`. Missing witness bytes reject.

Current catalog inspection permission gates receipt access. Current catalog read
permission additionally gates stored-row identity/value disclosure. A denied
read projects a `withheld` witness with only its stable column ID; this is a
presentation value and cannot be encoded as a durable receipt. Input values come
from the caller's original saved INSERT and remain available under inspection
permission. Structured diagnostics validate that input evidence matches those
exact saved values and derive column/type names from the original bound schema.
They never resolve a later Table of the same name. Stored outcomes and their
witnesses remain unchanged by disclosure, rename, DROP, name reuse or cleanup.

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

## Atomic finite statements

`TableStatement` accepts a bound `TableDml.Plan` and the same authenticated
resource/principal/operation identity. Its request digest hashes the domain
`transit.table.statement.v1\0`, raw shared native definition, three IDs as u64le,
the 32-byte enclosing-owner binding and the complete typed DML fingerprint.
That binding is part of exact intent, never a grant or trusted caller hash.
It shares `STW1` outcome keys with point
writes: changing coordinator or intent at an occupied identity rejects.

Admission reserves a bounded immutable record interval and records the busy
head, receipt and candidate progress atomically. The live schema/data root stays
unchanged. Every later step verifies that exact head revision, pending identity,
range and schema. INSERT assigns row identities `(principal+1, operation, ordinal)`.
UPDATE/DELETE traverse the original immutable root in row-identity order and
evaluate the complete predicate against original rows. Updated keys never change
selection or cause revisits; inserted candidates do not extend the frozen source.

UPDATE/DELETE process at most one source row per step. INSERT builds up to eight
rows in the same bounded overlay, stopping sooner if its existing record or byte
budget is exhausted. This scheduling bound does not define a query vector size.
Only the batch's final reachable records are staged; intermediate index paths
are discarded. Every restarted stage reconstructs the same batch and IDs.
Unselected rows and same-value updates advance only progress. Changed rows stage
their complete reachable pages before advancing the candidate root/cursor/counts
and reserving a new interval. Each interval contains `TableCandidate.max_records`
IDs; unused IDs stay consumed. This is a finite operation budget, not a collection
cardinality bound. The candidate accumulates in durable immutable pages, not RAM.
Native turns retain the four-mutation limit. A page-only turn may precede the
three-write progress advance. The last INSERT batch can complete directly once
all its records are staged. Lost proposals repeat the same batch/row and reserved
IDs; a saved cursor never points beyond unpublished candidate pages.

Completion atomically swaps the live root, updates row count, clears pending work,
saves terminal matched/changed counts and removes progress. A duplicate key or row
identity at any row rejects the entire statement and clears pending work while
keeping the original live root and zero terminal counts. Cancellation has the
same visibility boundary. Both retain candidate pages and ID floors for separate
cleanup. Other failures restore the private proposal and leave admitted work
available for exact reconciliation; no failure implicitly means rollback.

Progress keys are `00 47`, object/principal/operation:u64be. `STG1` contains magic,
raw native definition, request digest (32 bytes), head revision:u64le, optional
index reference in the same representation as `STH1`, optional 20-byte row cursor
(presence:u8 plus big-endian identity), insert ordinal:u32le, matched:u64le and
changed:u64le. The largest keyed-root record is 229 bytes. Counts, flags, reference
shape, source range and intent are checked before continuation. Progress is owner
state, never caller-supplied proof that a prefix committed. The original live head
is the frozen source until final publication. Retained roots keep their schema;
terminal reconciliation does not reopen or rebind a later head.

## Closed candidate cleanup

`TableCleanup.step` admits only an exact rejected/cancelled `STW1` receipt. Its
exclusive `[first_record,end_record)` interval never entered an accepted head;
the reservation fence, terminal closure and nonreused ID floor establish that
fact. Active/applied receipts reject. The current head must remain beyond the
closed range, with no schema, root or pending identifier inside it. Cleanup does
not traverse accepted graphs to guess liveness and cannot collect arbitrary IDs.
Current owner authorization and native captured-turn fencing still apply.

A bounded native page locates the next allocated inline record or Publication
descriptor in the interval, skipping gaps. Cleanup validates representation before
removal. It deletes inline candidate records, abandons staging Publications or
retires published candidate Publications, then uses their existing bounded chunk
collector. A full four-write collection commits before saving the cursor in a
later turn. Permanent descriptors make that repeat exact; quota release occurs
once through the Publication budget. Progress loss never skips incomplete cleanup.

The separate cursor key is `00 58`, object/principal/operation:u64be. Its 93-byte
`STX1` value holds magic, raw native definition, exact request digest, first/end/
next record IDs:u64le and phase:u8 (inline=1, Publications=2, complete=3). Range,
digest, phase and cursor bounds are checked on every continuation. Receipts,
heads and ID floors never change. Completion is repeatable and performs no new
writes. This removes current candidate storage; protected older provider roots
retain their own bytes. It makes no physical-erasure promise and is not a collector
for accepted historical versions or dropped Tables.

## Schema evolution publication

`TableAlter` accepts an exact original schema and one selected
`TableEvolution.Change`. It derives the successor and its work classification
itself; callers cannot assert that an arbitrary successor needs no validation.
The request digest hashes `transit.table.alter.v1\0`, the raw shared definition,
resource/principal/operation:u64le, and the full before/after schema fingerprints.
It uses the same exact outcome identity and current-policy boundary as other
Table work. Catalog rename/dependency decisions remain outside this helper.

Admission freezes the live head and reserves the successor schema ID followed
by one complete row-overlay interval. Schema bytes finish Publication staging
before any later row read; private publication never bypasses committed cursor
rules. Metadata changes retain the original data root. Validation-only changes
read every original row and keep that root only if all pass. Physical changes
build a new row/key index from the empty root, one stable row identity at a time.
Defaults apply only to new columns; renamed/defaulted existing cells retain their
values. Key type changes rebuild the key index with exact converted values.

The shared `STG1` cursor records processed/rewritten rows, candidate root and
expected head revision. Completed staging advances the cursor and nonreuse floor
atomically. Concurrent DML/DDL sees the busy head. A successful final decision
replaces schema and data references together, preserves total row count, clears
pending work, saves the terminal receipt and removes progress. DDL terminal
matched/changed counts are zero; its internal validation counts are not DML
affected-row counts. No intermediate schema or rewritten prefix becomes live.

Late NOT NULL, missing required values, character-length violations, overflow,
inexact conversion or key conflicts save a precise rejection with the old live
schema/data unchanged. Cancellation closes the same reservation. Both can use
closed-candidate cleanup, including the unpublished schema. Allocation, source
read and unexpected failures restore the private proposal without inventing a
terminal result. Exact terminal reconciliation precedes current-head reads and
retains the original failure even after its conflicting data changes. Old heads
continue to decode against their own immutable schema and root under current
read authority. New work bound to a superseded schema rejects instead of rebinding.
