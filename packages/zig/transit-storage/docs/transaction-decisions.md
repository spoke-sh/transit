# Transaction directories and decision journal

`TransactionDirectory` stages immutable participant directories and
`TransactionDecisionLog` freezes one attempt and records its commit or abort
decision. They are storage components. The installed catalog and SQL service do
not yet expose them, and `TablePartition` does not yet prepare or resolve their
successors. Using these components alone cannot establish atomic Table visibility,
consistent-cut acquisition or serializable execution.

## Private directories

Construct a directory with an explicit transaction identity, kind, entry quota,
resident page count and index-work byte budget. `put` stages one participant or
preparation through `TreeStore`; the directory's key is the stable object ID.
An exact repeat is idempotent and conflicting content for that ID rejects.
`seal` stages its root descriptor and returns the neutral directory commitment.
Neither operation accepts a transaction or retains a snapshot. Save the sealed
reference before the corresponding owner publishes it.

`restore` verifies the root object, identity, kind, count and top-level page.
`page` reads at most eight entries in object order; each entry verifies its
content, object key and transaction scope. A null continuation ends that fixed
directory traversal. `requireComplete` verifies all expected writes against the
prepared directory, including each original attempt and predecessor. It scans
both directories and checks their actual cardinalities. It performs no writes.
It does not verify participant WAL acceptance or successor object availability.

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
monotonic statement counter and whether data differs through accepted private
mutations. Restoring it checks the begin, interpretation, source identity and
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
still enforce aggregate quotas and protect private segment identity allocation
at preparation. A state descriptor alone is not a retained root or preparation
proof. This evaluator supplies no SQL session, common-cut acquisition,
coordinator, participant preparation or public savepoint interface.

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

One conditional log append records the decision. Every ordinary participant read
and subsequent write must resolve that same decision before exposing or bypassing
a prepared successor. This integration is required before the journal can be
used for Table publication. Finalization is recoverable maintenance, not the
common visibility point.

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

All journal history and referenced directories must remain retained. There is
no trim operation, implicit expiry or collector integration in these components.
Before hosting them, extend the catalog recovery directory and retained storage
graph to cover cuts, workspaces, participant preparations and decisions. Existing
Table maintenance cannot be assumed to retain those new roots.

The [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#transaction-directory-and-decision-records)
defines the exact object and journal formats. Focused component checks run with
`zig build test -Dtest-filter=transaction` from this package inside `nix develop`.
They cover paged disk reopen, exact identity, complete preparation membership,
lost replies, pre/post-append failures, fencing and bounded allocation. They do
not exercise installed SQL, actual Table preparation, process death or power loss.

The [finite decision model](../../../../tests/verification/models/README.md#finite-transaction-decision-model)
checks the journal's decision and knowledge obligations with two abstract
participants and two epochs, including six negative controls. It assumes atomic
log append and truthful guarded verification. Its operation-boundary mapping is
not an implementation refinement proof or a Table isolation/visibility proof.
