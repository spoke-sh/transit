# Transaction directories and decision journal

`TransactionDirectory` stages immutable participant directories and
`TransactionDecisionLog` freezes one attempt and records its commit or abort
decision. `TablePartition` accepts durable preparation barriers and resolves
successors against that actual journal. The catalog component coordinates those
owners under an embedding host's exclusive database publication fence. The
[signed Catalog controls](../../transit-catalog/docs/direct-catalog.md) and
[SQL service](../../../../docs/handbook/reference/sql/transactions.md) compose these
operations into the public transaction lifecycle.

## Private directories

Construct a directory with an explicit transaction identity, kind, entry quota,
resident page count and index-work byte budget. `put` stages one participant or
preparation through `TreeStore`; the key is the stable object ID and nullable
logical partition ordinal. State objects have no ordinal; Stream and Queue
targets require one. Exact repeats are idempotent; conflicting content for that
key and mixed kinds for one object reject. A log participant groups its append
and settlement actions under one guard and preparation.
`seal` stages its root descriptor and returns the neutral directory commitment.
Neither operation accepts a transaction or retains a snapshot. Save the sealed
reference before the corresponding owner publishes it.

`restore` verifies the root object, identity, kind, count and top-level page.
`page` reads at most eight entries in object/ordinal order; each entry verifies its
content, complete key and transaction scope. Continuations retain both object
and ordinal. A null continuation ends that fixed
directory traversal. `requireComplete` verifies all expected writes against the
prepared directory, including each original attempt and predecessor. It scans
both directories and checks their actual cardinalities. It performs no writes.
It does not verify participant WAL acceptance or successor object availability.
The directory supports neutral state and log evidence, while the current
decision journal accepts Table, KV, Stream and Queue participants. The public
catalog currently selects Table and direct KV only. Document participation and
public log transaction admission remain unavailable.

Directory objects are at most 16 KiB. Index caches and index staging use the
existing `TreeStore` bounds. Entry quota is independent of resident page count;
earlier roots survive later private inserts. Failed insertion leaves the current
private root unchanged. Staged orphan objects require an owning retained-graph
and cleanup policy; this component deletes nothing.

## Private log actions

`LogTransactionActions` stores one partition owner's ordered append, offset,
ACK and terminal-transfer intents under an exact transaction identity and
`LogGuard`. An entry retains its statement sequence, ordinal, intent and original
operation. A second paged index rejects reuse of an operation under another
entry. Appends to the private directory must advance the statement/ordinal
order; exact retries can address any existing entry. Entries from the same
statement bind the same intent. The statement coordinator separately verifies
complete work across owners; this storage interface does not infer completeness
from contiguous ordinals.

`putOffset` requires the original Stream cursor, including its read handle and
authentication bytes. Its coverage and principal must match the offset action.
Other action kinds require no cursor. Shape checks here do not verify its MAC
or retained read; those checks belong to the partition owner before preparation.
An exact retry cannot substitute another cursor or authentication value.

`put` verifies payload bytes against the append's content identity and stores
them separately from the fixed-size action metadata. Non-append actions carry
no payload. Entry and cumulative payload quotas are explicit, independent of
the resident page count. Metadata objects are at most 16 KiB; each payload is
bounded by the ordinary log batch format. Object publication failure may leave
staged objects, but it leaves the private directory root unchanged. Both index
updates must be persisted before that root advances.

`seal` returns an immutable directory commitment. `restore` checks its identity,
exact guard, count, quotas and root pages. `page` returns at most eight owned
fixed-size entries. `verify` traverses the complete directory and operation
index, checking their counts, ordering, final entry and cumulative payload bytes.
`readPayload` uses caller-owned bounded storage and verifies exact bytes. Provider
allocations are separate from this owner's fixed buffers and page cache.

These objects are private proposals. Their availability does not establish
schema-valid payloads, live input leases, valid consumer progress, retention or
accepted work. Restoring a saved directory cannot release globally consumed
operation/statement identities. The transaction coordinator must retain the
root and payload graph, apply current rights and participant guards, prepare
offset reservations, and record a common decision before exposing output or
settlement. The serialized log owner supplies preparation and resolution below;
the catalog does not yet admit these actions as public transaction work.

## Retained log transaction cuts

`StreamPartition` and `QueuePartition` expose `pinTransactionSource`,
`transactionPinState`, `inspectTransactionSource` and `releaseTransactionSource`
to the serialized transaction host. Acquisition binds the original begin identity,
current declaration and exact accepted position. Its WAL record publishes a
paged live pin to an immutable `LogTransaction.Source`. An exact retry returns
that source even after later data changes; substituting a newer cut rejects.
A new pin against an old physical position rejects before publication.

The source retains the complete partition root, including payload placement,
group progress or Queue scheduling and lease state. It omits the transaction-pin
directory and cannot contain a preparation barrier, avoiding recursive chains
of earlier transaction pins. A snapshot descriptor or staged source alone does
not confer retention. The catalog storage graph follows each accepted live pin,
using current archive coverage to preserve older WAL payloads after trimming.
Released pins retain their identity and closure marker but stop retaining the
source through that edge. Independently live replay or checkpoint roots can
still retain their earlier pin.

`changed_lsn` tracks append, assignment, offset, claim, settlement, lease expiry,
payload expiry and logical compaction. Pin/release, flush, archive, checkpoint and
physical timer merging preserve it. A `LogGuard` can therefore tolerate physical
maintenance while refusing changed data or interpretation. Every inspection,
retry and release checks current authorization. Release uses the control reserve;
publication failures retain the original identity and ordinary WAL uncertainty.

Source metadata is bounded to 64 KiB and decoded with fixed scratch buffers.
Pin cardinality is independent of the page cache. The public native catalog
selects and retains these sources alongside state participants. A pin alone neither
reserves append offsets nor settles a lease or consumer offset.

## Log evaluation, preparation and resolution

`StreamPartition.evaluateTransaction` constructs one private successor from a
live source pin and a sealed `LogTransactionActions` directory. `QueuePartition`
uses the same owner internally. Evaluation applies the existing append,
authenticated offset-commit and fenced ACK validators in statement/ordinal order.
It rejects already accepted operation identities, changed source data, forged
coverage and expired leases. Terminal transfers privately archive a live leased
or exactly identified exhausted source, after verifying its original logical row
under the recorded destination definition. The destination owner's mirrored
action evaluates the append. Public roots remain unchanged during either check.

Each proposed batch is sealed to immutable segments; several batches share the
prospective preparation position and retain distinct original offsets and content
identities. Existing WAL payloads can precede those sealed batches. Segment
placement therefore permits sealed ranges beyond the contiguous `sealed_through`
prefix. Tail-cache identity includes the batch's first offset as well as its
position and content; a shared preparation position cannot alias different batches.
Evaluation reserves no offsets, publishes no receipts, advances no group and
settles no input. It restores the public root and clears derived index/scheduling
caches on success and failure.

`EvaluationLimits` independently bounds action count, cumulative append payloads,
last statement and temporary heap bytes. Evaluation and prepared-owner checks
meter newly allocated memory, while borrowing the owner's initialized slabs,
page cache and serialized lifetime. Their scratch arenas live for the operation
and reset with retained capacity between records. Caller outputs, fixed stack
buffers, provider buffers and retained staged bytes remain separate reservations.
A caller cannot retain a tail borrow across evaluation. `resident_peak` reports
the evaluator's temporary heap peak; it is not total partition residency.

`prepareTransaction` requires the exact frozen journal, selected guard/action
directory and live source. It stages a bounded `LogTransaction.Preparation`, then
accepts its reference in the partition WAL. This barrier preserves the predecessor
and blocks ordinary reads, writes and maintenance. Exact retries return the same
preparation. The stored successor binds all appends and settlements for that
partition; its operation receipts identify the preparation frontier and become
visible only after commit resolution. The host must retain private action roots
before preparation and reserve the original operation identities globally.

The journal's host holds all participant and current policy guards while checking
preparations. `verifyPrepared` verifies the actual barrier, live source, action
directory and current ACK leases, and returns a transient `DecisionTime` check.
The host must separately traverse the complete successor graph and verify current
names, rights and all participants. The catalog's `DirectStorageGraph` follows
preparation predecessors/successors, action metadata, payloads and decision
indexes in bounded steps. Missing dependencies leave that traversal incomplete.

Log writes require the journal's `before_decision` callback. After every potentially
slow participant/availability check, this callback calls `verifyDecisionTime` for
every collected owner under the same publication guard. It allocates nothing and
rechecks the collected ACK/live-transfer and append-retention deadlines, plus
exhausted-transfer time bounds, immediately before the
conditional decision append. Missing callbacks, expired deadlines or intervals
spanning lease expiry leave the transaction preparing. A descriptor or callback
that skips these checks does not establish a qualified transaction host.

`resolveTransaction` consults the actual coordination journal and exact committed
preparation membership. Commit publishes the immutable successor; abort preserves
the predecessor's data and original leases. Both clear the barrier through one
partition WAL record. Unknown decisions keep it in place. Recovery and resolution
of an accepted decision do not recheck current time, reauthenticate old cursor
keys, dispatch effects or reconstruct a different successor. Lease expiry after
a committed decision cannot undo its ACK. The transaction host retains the
publication fence across common-cut acquisition and resolution; independent reads
are not a new atomic snapshot API.

These checks qualify storage components, including disk reopen and lost replies.
The native catalog composes selection/staging, aggregate transaction quotas and
paired DLQ actions. `TransactionDecisionLog` verifies both transfer directions by
exact operation lookup, statement and complete transfer equality. A destination
mirror cannot be shared by two sources. This check uses paged directories rather
than a resident set growing with transfers. Queue replay refuses a standalone
terminal operation even when its envelope and candidate state are valid; only a
verified common decision can publish that successor. Installed proof coverage and
its remaining limits belong to the [qualification ledger](../../../../docs/history/qualification/transactions.md).

## Private Table and KV evaluation

`TableWorkspace` opens an existing retained Table pin with current authorization
and borrows that Table owner's serialized lifetime. It uses `TablePartition`'s
typed row and predicate DML evaluator against private copy-on-write roots.
Reads include the retained WAL-backed rows and private segment-backed writes.
New row data uses bulk immutable segments; private evaluator positions cannot
become accepted WAL row locations. Statement results carry explicit provisional
counts or a rejection reason, with their transaction and statement attribution.
The public Table root and WAL remain unchanged.

`executeKV` lowers typed put/remove batches through `KVPartition.lower`, preserving
key/value bounds and exact kind. It uses the same private roots, consumed statement
identities, savepoints, budget and preparation/decision path. A disk check covers
six 1 KiB values and a removal, rollback, both terminal outcomes, lost preparation,
decision and resolution replies, replacement and the original retained cut.

`State` contains the exact begin descriptor, retained source, private root,
monotonic statement counter, cumulative matched/affected counts and whether data
differs through accepted private mutations. Restoring it checks the begin, interpretation, source identity and
live pin. `get` and `execute` recheck the pin and current rights. A released pin
cannot be revived by a saved workspace. A private Table cannot export a normal
recovery hint or recover through the public Table log.

Rollback restores private data while retaining consumed operation receipts,
statement sequence and monotonic private storage frontiers. A discarded
statement's operation or sequence cannot be assigned to replacement work.
The transaction host separately owns persistent savepoint names, read/conflict
dependencies, cursor invalidation and original statement-result recovery.
Workspace rollback neither publishes an abort nor cancels external work.

One stable budget meters the evaluator's heap allocations from initialization
through destruction, including its private Table caches, mutation builders and
budget context. `residentPeak` reports that lifetime peak. Configured exhaustion
returns `TransactionMemoryLimit`; parent allocation failure remains `OutOfMemory`.
The Table's smaller independent build budget can also return a provisional
statement rejection with `work_limit`. Borrowed Table owners, caller-owned
output, provider buffers, stack capacity and retained workspace bytes have
separate owners. The host must reserve their capacity and aggregate concurrent
workspaces; one evaluator's allowance is not an installation-wide limit.

Small allowances can reject even a small statement because intent and owner
buffers have independent minimum capacity. Row buffers use canonical encoded
sizes; segment output starts at 64 KiB and grows within the existing segment and
resident bounds. The component checks execute private inserts, predicate DML,
rollback and reopen with a 16 MiB lifetime allowance and one cached index page.
They refuse initialization with 4 KiB and a statement under an independent 4 KiB
build cap without public acceptance.

The catalog [workspace owner](../../transit-catalog/docs/direct-catalog.md)
publishes accepted private states, consumed statement identities and provisional
results and retains their data/receipt pages. Before service use, the host must
still enforce deployment-wide capacity and reserve physical storage. Preparation
preserves current control directories and the largest physical segment frontier;
immutable segment digests distinguish private and public flush objects. A state descriptor alone is not a retained root or preparation
proof. The evaluator supplies no SQL session or public savepoint interface. Common-cut
acquisition and coordination belong to the catalog owner.

## Frozen attempt and decision

The embedding catalog must reserve one distinct coordination partition for the
transaction and durably bind it to the original accepted client token. The
journal constructor takes that partition and exact `Binding` (`Begin` and
`Attempt`). It rejects a catalog/coordination partition collision and verifies
that participants do not use the coordination partition. It provides no
partition allocator or alternate token directory.

Call `recover` before using a new journal. `freeze` conditionally appends the
complete binding before any participant prepares. Each participant then owns
its durable preparation and predecessor barrier. The coordinator can reconstruct
the preparation work list from the frozen participant directory; it does not
need a second append per participant in the coordination log.

For `commit`, supply the sealed preparation directory, a current authority guard
and `Verification` callbacks. The guard must hold the complete name/definition,
participant and policy fences through the decision append. The callbacks check
each participant's actual conflict basis and each written participant's actual
durable prepare and immutable successor availability. A read-only transaction's
callback preserves its retained cut without demanding the latest data version.
Callback failure leaves the attempt preparing; it does not implicitly abort.
Descriptor shape, matching counts and callbacks that unconditionally succeed
cannot substitute for these owner checks.

One conditional log append records the decision. A Table with an unresolved
preparation refuses ordinary recovery, reads and writes with `TransactionPrepared`.
Only the component coordinator can open that owner for resolution. It verifies
the actual journal and exact prepared-directory membership before publishing the
private data roots, or clearing an aborted barrier. Finalization preserves
current receipt, pin, history, archive and maintenance control state. A committed
aggregate Table receipt carries the common decision and original commit operation;
private statement outcomes retain their separate statement attribution.

A crash can leave one participant finalized and another blocked. While publication
is incomplete, an unresolved participant refuses a current
read instead of supplying its predecessor. Explicit transaction reads acquire
one common cut; independent reads issued at different times outside a transaction
do not acquire atomic multi-Table observation semantics. The host must hold the
database publication fence across consistent-cut acquisition and each coordinator call.
The decision is the logical commit point; materialization can defer availability.
A physical flush between private evaluation and preparation does not conflict
unless its logical interpretation or data frontier changed.

`abort` uses the same expected decision position as commit. It records an empty
preparation directory; the complete frozen participant directory still identifies
every possible predecessor barrier for cleanup. Once either decision exists,
both controls return that original decision under current inspection authority.
Neither disconnect, expiry nor a caller's cancellation invokes abort implicitly.

An append error requires recovery before observation or another control. An error
after durable append can recover a committed decision. Exact retries never choose
a new attempt. Replaced coordinators are fenced by `TransitLog` writer/policy
epochs. `observe` rechecks current authority even for terminal results. Revocation
does not transform an existing commit into rejection or abort.

## Recovery and resource ownership

The journal has at most two hash-linked records: freeze and decision. Recovery
validates their framing, mandatory definition, exact binding, position, epochs
and directory membership. It stages no objects, publishes no records and calls
no participant/application callbacks. Missing/corrupt directory evidence rejects;
it never resets history. Participant data availability must still be checked by
the participant when resolving the recorded decision.

Each public journal operation meters its temporary heap allocations against
`Begin.limits.resident_bytes`, including log-read output, directory caches and
index decoding. `resident_peak` reports the most recent operation's heap peak.
Record decoding uses a 16 KiB fixed scratch allocator per call and returns owned
fixed-size values; traversing entries creates no heap arena for those records.
Scratch exhaustion returns `TransactionDecodeLimit`. Fixed 16 KiB record/object
encoding, read and scratch buffers live on the caller's stack; provider-owned
buffers, staged immutable bytes and caller input are separate. Configured
exhaustion returns `TransactionMemoryLimit`; a parent allocator failure remains
`OutOfMemory`. Both preserve the original accepted identity and recovery state.
The host must reserve transaction stack/provider capacity, workspace storage and
recovery capacity separately. The journal does not implement session admission
or an installation-wide quota.

All journal history and referenced directories remain retained; no journal trim
or implicit expiry operation exists. `DirectStorageGraph` recognizes coordination
partitions and retains their participant/preparation directories and preparation
metadata. The current transaction progress retains live private data. Historical
catalog progress does not retain superseded private candidates indefinitely.
Once abort cleanup finishes, private data can become collectible; original
statement outcomes, operation claims and decision evidence remain. Table replay
can validate an aborted preparation without opening its discarded data graph.

The [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#transaction-directory-and-decision-records)
defines the exact object and journal formats. Focused component checks run with
`zig build test -Dtest-filter=transaction` from this package inside `nix develop`.
They cover paged disk reopen, exact identity, complete preparation membership,
lost replies, pre/post-append failures, fencing and bounded allocation. The catalog's transaction checks also exercise actual Table preparation,
commit/abort settlement, unavailable successor data, current-policy and logical
conflicts, and cleanup reachability. These component runs do not exercise installed
SQL, process death or power loss.

The [finite decision model](../../../../tests/verification/models/README.md#finite-transaction-decision-model)
checks the journal's decision and knowledge obligations with two abstract
participants and two epochs, including six negative controls. It assumes atomic
log append and truthful guarded verification. Its operation-boundary mapping is
not an implementation refinement proof or a Table isolation/visibility proof.
