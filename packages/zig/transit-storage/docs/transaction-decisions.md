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
decision journal and catalog execution reject non-Table owners before admission.
Private Table workspaces, pins and common-decision readers remain the executable
participant adapters.

Directory objects are at most 16 KiB. Index caches and index staging use the
existing `TreeStore` bounds. Entry quota is independent of resident page count;
earlier roots survive later private inserts. Failed insertion leaves the current
private root unchanged. Staged orphan objects require an owning retained-graph
and cleanup policy; this component deletes nothing.

## Private Table evaluation

`TableWorkspace` opens an existing retained Table pin with current authorization
and borrows that Table owner's serialized lifetime. It uses `TablePartition`'s
typed row and predicate DML evaluator against private copy-on-write roots.
Reads include the retained WAL-backed rows and private segment-backed writes.
New row data uses bulk immutable segments; private evaluator positions cannot
become accepted WAL row locations. Statement results carry explicit provisional
counts or a rejection reason, with their transaction and statement attribution.
The public Table root and WAL remain unchanged.

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
