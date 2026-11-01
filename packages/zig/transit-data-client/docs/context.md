# Shared client context

`transit_data_client.Context` composes direct Table, KV, catalog, Stream, Queue and SQL
callers with one explicitly supplied allocator and `std.Io`. Construction and
opening a Catalog facet validate local configuration and own endpoints/key state;
they do not contact the authority or start a worker pool. Existing public Catalog
operations still own authorization, accepted identities and result semantics.

## Capacity and scope

`Config.catalogs` and `Config.sqls` bound simultaneously open Catalog and SQL
handles; `sqls` defaults to zero. `Config.active` reserves separate positive
`data` and `control` call counts; total facet capacity must be at least their sum.
These are active-work bounds, independent of retained data size.
The directory allocates once at initialization. Each open facet separately owns
its Catalog endpoints, signing state, transport and local intent. Transport,
intent and output allocations retain the Catalog caller's existing budgets;
the context does not establish a total process-memory or zero-allocation profile.

`openCatalog` takes the existing `Catalog.Config` and signing seed. Each facet
retains its complete connection scope, branch, audience, principal and role.
Handles identify their owning context, directory slot and non-repeating serial.
Closing and reopening a slot invalidates its earlier handle. Handles grant no
authority and cannot be used after the context's lifetime. Keep the context at
a stable address from its first open until all users have joined.

Use `call`, `callKV`, `callLog`, `callStream` and `callQueue` with those handles. Each
delegates to the existing Catalog caller and returns the same arena-owned result
and mutation-attempt evidence. The output arena must outlive every associated
borrow. Outputs survive another call, facet close and context destruction.
Use a separate output arena for each concurrent call. Shared backing allocators
must support concurrent access; otherwise serialize the calls. The context does
not serialize output allocation across facets.

Only one call may borrow each facet. The default calls refuse immediately:
overlap returns `Busy`; exhausted lanes or handle capacity return
`ClientCapacityExceeded` before dispatch. Different facets
may run concurrently using the supplied allocator and I/O, which must both
support concurrent use in that case. The host must give
that implementation sufficient bounded worker/task capacity; a context creates
neither threads nor an inline fallback when concurrency is unavailable.

### Optional admission waits

`Config.pending` reserves separate data/control queue counts at initialization;
both default to zero. Their sum must be below 65535. The queue owns only fixed
metadata, with at most one waiter per facet. It allocates nothing per admission.
Caller-owned request/output buffers and host task stacks remain live while waiting
and retain their existing owner budgets; queue counts are not a total memory limit.

Use `callWithAdmission`, `callKVWithAdmission`, `callLogWithAdmission`,
`callStreamWithAdmission`, `callQueueWithAdmission` or `borrowSqlWithAdmission`
with `.{ .wait = timeout }` to opt in. The timeout must be finite. One absolute
deadline covers admission, including wakeups; it does not replace the admitted
request's transport deadline. An expired deadline returns `Timeout` before
admission. `.refuse` preserves the default behavior. Saturated queues return
`ClientCapacityExceeded`; a second waiter on the same facet returns `Busy`.

Within each lane, the oldest eligible waiter gets the next available permit.
A facet held by a call or SQL lease is ineligible, so it cannot block unrelated
facets. New calls cannot overtake an eligible waiter. This defines local admission
order, not host scheduler latency or remote execution order. Cancellation and
expiry remove the waiting metadata before returning, with no dispatch or durable
acceptance. Closing refuses queued data; queued control work can still proceed.

The control lane carries Table/log operation inspection and cancellation, Table
snapshot status and release, log
pending discovery, Stream/Queue original-operation observation, explicit retained
read release, Stream offset settlement and Queue lease settlement/renewal.
KV declaration inspection/cancellation, original-operation observation and pin
status/release also use control capacity. KV preview, admission, execution,
mutations, metadata/value reads and new pins use data capacity.
Other calls, including waits, use data capacity. Control cannot borrow data
capacity, nor data control capacity. A control call needs an idle facet; a
separate handle to the same authorized scope allows control progress while
another handle waits. Sharing a scope does not grant access or allocate native
principal sequences. Direct Catalog/KV/log requests use their domain operation
identities and signed authorization proofs, not native principal sequences.
Applications composing native commands still coordinate those sequences
separately and persist original work through the owning protocol.

## SQL leases

`openSql(config, password)` owns a SQL facet's configuration and optional password;
their combined text is bounded to 64 KiB. It reserves the existing SQL client's
16 MiB data and 4 MiB transport buffers separately for primary and control clients:
40 MiB per facet, plus owner/configuration metadata. It reads an explicitly
configured CA file but performs no server negotiation and starts no worker pool.
Initialization takes a data permit; trust-file I/O does not hold the context mutex.
The separate reserves preserve the SQL response slots' serialized ownership.
They are not a new shared concurrent response pool or a process-memory budget.

`borrowSql(handle)` returns one generation-checked `SqlLease` and holds a data
permit until `release`. `lease.connect()` explicitly negotiates/authenticates the
initial session; it refuses replacement of an opened session. `lease.executor()`
then returns the existing shared SQL executor as a borrow. The lease must outlive
all executor calls, returned outcomes, row readers and batch views. Destroy those
owners before releasing the lease. Keep one borrower per lease; copying a lease
or executor pointer creates no additional owner. A stale lease cannot be released,
connected or retrieved again after its generation ends. A previously retrieved
pointer must not be used after release.

Use that executor directly or pass it to the [SQL recovery adapter](recovery.md).
Results, transaction controls, provisional statement outcomes and original-token
settlement retain their existing SQL owner. The context does not infer SQL kinds,
restart SELECT, attach a transaction implicitly or retry an application callback.
Different SQL/Catalog facets can run concurrently when data capacity permits.
A lease retained for result consumption continues to charge its data permit.

`cancelSql(lease, .cancel)` delivers cancellation intent to that lease's shared
executor through reserved control admission. `.terminate` requests stopping the
wait; it cannot be downgraded by a subsequent `.cancel` before acknowledgement.
The executor determines the actual cancellation/settlement behavior. Delivery
of the local signal proves no remote outcome and does not interrupt initial
`connect` negotiation, which follows its configured request deadline. A stale
lease cannot cancel a later borrower. Control admission remains available while
the context is closing; active SQL response buffers are never accessed by this
signal method.

## Close and ownership

`closeCatalog` destroys an idle facet's local resources; an active facet returns
`ClientWorkOutstanding`; a queued waiter also retains the facet. It never cancels accepted operations, releases durable
pins, acknowledges Queue work or advances Stream offsets.
`closeSql` likewise refuses a leased or queued facet and destroys only its local resources.
It does not roll back a transaction or erase recovery material.

`beginClose` changes the context from open to closing. New data calls and facet
opens are refused; explicit control calls remain available until joined.
`close(timeout)` begins closing and waits for admitted calls, SQL leases and queued waiters to end, using
one absolute deadline. Only one close await may run at a time; another returns
`Busy`. A cancelled or timed-out await releases that local joining slot. It does not interrupt those calls: their request deadlines
and the host's cancellation govern their I/O. A timeout or cancelled close await
leaves the owner in closing state with live memory intact. Retry close or arrange
another owner to join; never destroy it merely because an await ended.

After all admitted calls return, close marks the context joined and refuses all
new calls. Join every host task using the context before `deinit`; deinit refuses
an unjoined context and destroys remaining idle facets. A local join says
nothing about durable acceptance, completion or cancellation. Preserve uncertain
work independently of the context.

Managed language result handles, cross-process principal
coordination and language ABI/port composition remain separate work. The SQL
lease is an explicit Zig ownership boundary; it is not an installed language host.

## Verification

The package's `zig build test` covers allocation-failure cleanup, handle scope
and slot reuse, bounded independent lanes, 4096 admission/release cycles without
new directory allocations, FIFO eligibility, queue saturation, timeout/cancel
cleanup, queued data/control close races and actual Catalog local
intent/output ownership. SQL checks cover constructor allocation failures, lease
generations, shared saturation/control cancellation and close with a retained
lease, including a lease waiting behind Catalog admission. The disk-recovery loopback test negotiates a session through the context
and uses that leased executor for persistence failure and lost-reply schedules.
These checks exercise local admission and ownership;
they do not establish service durability, host scheduling latency or installed SDK
coverage. Existing Catalog integration schedules retain those responsibilities.
