# Direct Document partition ownership

`DocumentPartition` owns serialized acceptance and recovery of direct Document
records over `TransitLog` and `TransitObjectStore`. It maintains paged directories
for logical document heads, revisions, replica state, operation outcomes and
retained reads. The exact persisted records are specified in the
[storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#direct-document-partition-records-evidence-retained-reads-and-recovery);
identities and read coverage belong to the
[direct Document contract](../../../../contracts/DOCUMENT_V1.md).

This component accepts supplied state bytes and conflict counts. It does not yet
derive them through the logical evaluator or persist `DocumentShredder` output.
The installed [Document service](../../transit-station-document/README.md) retains
its existing lifecycle. These component APIs do not enable direct Document SQL,
mixed transactions or Station turns over this owner.

## Activation and recovery

The host serializes calls, supplies current scoped authority through
`PublicationGuard`, and provides a private nonzero 32-byte `Options.read_secret`.
There is no default signing key. Preserve it across reopen for retained cursor
authentication; possession of a signed cursor does not replace current rights
or a live pin.

After initialization, `open` performs one bounded recovery step. Its default
`recovery_records` is 64; the permitted range is 1–256. If `ready` is false,
resume with `recoverStep(guard, budget)` and inspect `RecoveryProgress.complete`
before accepting operations. Incomplete or failed recovery fences reads,
mutations and maintenance with `DocumentRecoveryRequired`. A step reports its
replayed record count and recovered WAL position, separately from completion.

Each step selects an accepted recovery checkpoint if available, then replays at
most its record budget. Checkpoint selection has fixed additional work: up to
two frame reads and one checkpoint object. Scratch is reset with retained
capacity after each decoded record. Resident index pages remain controlled by
`resident_pages` (default 16); the record budget is independent of WAL length.
Readiness checks the five directory root pages, current authority and a fresh
WAL tail. Child pages and state objects are checked when accessed, so readiness
is not an exhaustive scrub of retained storage.

An authorization failure before installing a record preserves the last recovered
position. Any recovery error clears readiness, including on an already active
owner. Resume the original owner/request under current authority; replay never
appends another mutation. Existing accepted archival and recovery-checkpoint
coverage remain prerequisites for WAL trim.

## Retained reads

`beginRead` accepts a revision range and cumulative `max_steps`/`max_bytes` within
the declaration's limits. `readCursor` requires its exact recorded receipt.
`readNextRevision(output, cursor, guard)` verifies the signed range and live pin,
then refuses with `DocumentReadLimitExceeded` before allocating state when the
next revision would exceed either remaining budget. A refused prefix is not a
completed range. Repeating a cursor does not advance hidden mutable progress.

A successful `RevisionStep` owns its state in the caller's `output` allocator;
call `deinit(output)` when finished. Later fetches and scratch resets preserve
earlier returned state. The component loads one whole revision within the
admitted byte budget; it does not yet stream pages within a large revision.
`complete` is established only when the exact pinned range is exhausted.
Repeated fetches and empty terminal observations recheck current authorization
before disclosure. Failure after buffering frees that output.

`releaseRead` must bind the original source's logical target and owning principal,
using its own operation identity. An unrelated document cannot release the pin.
Exact release retries recover their original receipt.

## Verification

From this package in the pinned development shell, run
`zig build test -Dtest-filter=document`. The
[owner tests](../src/document_partition_test.zig) include actual local disk
reopen, bounded recovery/resumption, authenticated read continuation, archival,
checkpoint publication and trim. They check cumulative read budgets, refusal
before output allocation, caller-owned output lifetime, receipt/target binding,
and revocation before disclosure, including terminal reads.

A separate memory fixture replays 40 accepted mutations to compare scratch
capacity for single-record and 24-record steps, checks authorization interruption
without advancing the current record, recovers the original mutation receipt,
and rejects an invalid hash chain during open without leaking or double-freeing
the page store. This isolates replay memory behavior; it is not additional disk
durability, zero-allocation, process-death or power-loss evidence.

## Evaluated causal map trees

`applyCausal(mutation, canonical_bytes, guard)` evaluates a `LogicalChange` frame
and publishes its derived immutable root through one WAL append. It never accepts
supplied logical state or a supplied conflict count. Full document/replica IDs,
nested map assignments, observed removals, explicit nulls and chunked strings or
binary values are supported. Field-name and value size follow request/candidate
budgets instead of the installed Station scalar ceiling. The
[exact format and bounds](../../../../contracts/DOCUMENT_V1.md#integrated-causal-map-tree-storage-slice)
identify the narrower component profile and remaining operations.

An exact causal duplicate arriving under a new operation obtains a durable receipt
for the first revision; it does not apply the change twice. Original-operation
replay retains its own accepted WAL position. Reopen reads the same immutable
`.tseg` roots, and the retained graph marks their directory and segment dependencies.
The existing opaque `applyMutation` seam cannot overwrite these logical roots.
Logical checkpoints currently refuse rather than accepting caller-computed state.

For bounded path reads, first call `beginRead` with one exact revision, then
`causalCursor(receipt, path, guard)` and `readCausalPage(cursor, path, guard)`.
Each page owns up to 240 bytes inline, includes the value's total length and byte
offset, and returns a signed continuation. Preserve the original path and cursor;
a page can split a UTF-8 scalar. The page's completion flag, followed by a verified
terminal call, distinguishes complete coverage from a budget refusal. Missing,
null, type-error and conflict results stay distinct. Releasing the pin invalidates
all continuations. Current authority is checked again after buffering.

This is a library/storage integration. Installed Document lifecycle, native client
and Station behavior still use their existing contract. It does not establish
versioned merge, list/text editing, succinct BP layout, adaptive shredding,
collection scans or mixed Document transactions.
