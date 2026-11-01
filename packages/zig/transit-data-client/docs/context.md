# Shared Catalog context

`transit_data_client.Context` composes direct Table, catalog, Stream and Queue
callers with one explicitly supplied allocator and `std.Io`. Construction and
opening a Catalog facet validate local configuration and own endpoints/key state;
they do not contact the authority or start a worker pool. Existing public Catalog
operations still own authorization, accepted identities and result semantics.

## Capacity and scope

`Config.catalogs` bounds simultaneously open Catalog handles. `Config.active`
reserves separate positive `data` and `control` call counts; `catalogs` must be at
least their sum. These are active-work bounds, independent of retained data size.
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

Use `call`, `callLog`, `callStream` and `callQueue` with those handles. Each
delegates to the existing Catalog caller and returns the same arena-owned result
and mutation-attempt evidence. The output arena must outlive every associated
borrow. Outputs survive another call, facet close and context destruction.
Concurrent calls need separate output arenas or an externally synchronized
allocator; the context does not serialize output allocation across facets.

Only one call may borrow each facet. Overlap returns `Busy`; exhausted lanes or
handle capacity return `ClientCapacityExceeded` before dispatch. There is no
implicit pending queue, admission wait or fairness guarantee. Different facets
may run concurrently using the supplied I/O implementation. The host must give
that implementation sufficient bounded worker/task capacity; a context creates
neither threads nor an inline fallback when concurrency is unavailable.

The control lane carries Table/log operation inspection and cancellation, Table
snapshot status and release, log
pending discovery, Stream/Queue original-operation observation, explicit retained
read release, Stream offset settlement and Queue lease settlement/renewal.
Other calls, including waits, use data capacity. Control cannot borrow data
capacity, nor data control capacity. A control call needs an idle facet; a
separate handle to the same authorized scope allows control progress while
another handle waits. Sharing a scope does not grant access or allocate native
principal sequences. Callers still coordinate sequences and persist original
work through the owning protocol.

## Close and ownership

`closeCatalog` destroys an idle facet's local resources; an active facet returns
`ClientWorkOutstanding`. It never cancels accepted operations, releases durable
pins, acknowledges Queue work or advances Stream offsets.

`beginClose` changes the context from open to closing. New data calls and facet
opens are refused; explicit control calls remain available until joined.
`close(timeout)` begins closing and waits for admitted calls to return, using
one absolute deadline. It does not interrupt those calls: their request deadlines
and the host's cancellation govern their I/O. A timeout or cancelled close await
leaves the owner in closing state with live memory intact. Retry close or arrange
another owner to join; never destroy it merely because an await ended.

After all admitted calls return, close marks the context joined and refuses all
new calls. Join every host task using the context before `deinit`; deinit refuses
an unjoined context and destroys remaining idle facets. A local join says
nothing about durable acceptance, completion or cancellation. Preserve uncertain
work independently of the context.

SQL sessions, automatic settlement, durable recovery stores, cross-process
principal coordination and language ABI/port composition are separate owners;
this context currently exposes the explicit Catalog operations only.

## Verification

The package's `zig build test` covers allocation-failure cleanup, handle scope
and slot reuse, bounded independent lanes, 4096 admission/release cycles without
new directory allocations, close timeout/cancellation and actual Catalog local
intent/output ownership. These checks exercise local admission and ownership;
they do not establish service durability, scheduler fairness or installed SDK
coverage. Existing Catalog integration schedules retain those responsibilities.
