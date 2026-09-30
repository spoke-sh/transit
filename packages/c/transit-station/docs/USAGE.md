# Installation and handler ownership

Build with `just bindings::c-build`. Extract the version-matched native client,
native Station, C client and C Station archives into one installation prefix.
Set `PKG_CONFIG_PATH` to its `lib/pkgconfig`, then compile:

```sh
zig cc -std=c11 app.c $(pkg-config --cflags --libs transit-station-c) -o app
```

The installed rpath finds the SDK; it finds native libraries beside the C client
SDK. `config.client.native_directory` overrides both native libraries explicitly.
ABI versions, required growing capabilities and missing symbols fail before
handler dispatch. Importing the library does not start threads, discover a seed
or contact authority. The qualified build target is pinned Zig on Linux x86_64,
with the build's Nix runtime closure. The raw client remains independent of Station.

Provide `transit_station_config`, handler callbacks, a codec and explicit runner
options to `transit_station_runner_open`. Configuration selects native_v1 and
an existing process activation. The association names a resource; it does not
grant access. Credentials and generation remain separate from process identity.
The examples use association `data`; raw configuration has no implicit name.
Enable `query_results` explicitly for Table query services/requesters.

The runner owns one worker with an 8 MiB stack, one admitted operation, sequential
callbacks and native destruction. Calls block the controller, so use one owned
application task on an event-loop runtime. Concurrent work and callback reentry
return BUSY. `runner_stop` is a local cooperative signal: it prevents further
dispatch and discards private work after the current callback. It cannot
interrupt arbitrary application code or retract an accepted mutation.
`runner_close` signals stop and joins; a response already in flight still produces
its committed/uncertain evidence. Deferred POSIX cancellation is masked across
controller calls. Asynchronous thread cancellation is unsupported. Abandon an
application controller's receive while its task remains owned, then join it.

Callbacks borrow a `transit_station_turn`. Initialization and message/control/result
dispatch share one private handler turn. Retain before keeping a handle and
release each retained reference. After that turn completes, retained handles
return TURN_EXPIRED even after runner destruction; another thread returns BUSY
while the turn is active. A freed C pointer cannot be checked safely. Never use
a borrowed handle after its borrowing scope or destroy a runner concurrently
with another caller's handle access. Close may join an already admitted call;
destruction requires exclusive ownership.

Codec metadata specifies the application type/version and maximum encoded size.
Encoding writes into an SDK-bounded buffer; decoding constructs one application
object in max_align_t-aligned storage. On failure, decoding must leave no live
object or allocation. Destroy callbacks must not throw. Callbacks and their
contexts remain alive through runner close; a returned decoded value also needs
its codec context until `transit_station_value_destroy`. Input values have the
application type promised by the codec. C's void pointers do not provide static
type safety; ingress bytes are always validated before initialization/handling.

## Private turns and durable observations

The message callback receives cast/call/reply metadata and the decoded payload.
Control and verified query-completion callbacks are separate. Origin identifies
the authenticated external principal, process output or effect result. A payload
tag is not proof of a reply: use `turn_require_reply` with the saved correlation
and expected peer. Untimed calls require both deadline and observer to be absent;
timed calls require both. Correlations use full u64; protocol positions, revisions
and identifiers follow the shared safe-counter bound.

An application records call identity in associated state with its output. Return
from the turn and resume on a recorded reply/result in a later activation.
Callbacks, C stacks and worker fields are not durable state. `turn_cancel` records
explicit advisory cancellation; local stop/close does not perform it.

`runner_next` owns native preparation and bounded framework progress, invokes
handlers, then observes dispatched mutations. A COMMITTED event carries a known
receipt. PROGRESS, handler return and raw admission are different observations.
With `TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH`, the store must persist exported
exact bytes before returning from `before_dispatch`. Every permit/open/commit,
including framework query work, passes through it. `confirmed` runs after a known
receipt. A failed confirmation callback retains the receipt and pauses; calling
`runner_reconcile` retries observation/confirmation without rerunning the handler.
Repeated `runner_next` returns the same recovery pause until reconciliation.

NEEDS_RECOVERY owns the pending operation and phase/error. Export it before
destroying its owning event/mutation handle. A fresh raw client can recover and
dispatch an opaque mutation without its seed. If exact recovery bytes are lost,
the explicitly selected fresh-ownership policy requires the deployment to obtain
new authority and inspect/reconcile progress. The SDK does not invent new retry
identities, acquire ownership automatically or claim that restored worker fields
are authoritative.

Stop policy leaves failed input pending. Block-input policy discards private
changes and prepares the native failure marker, itself gated before dispatch.
A failed read poisons the turn even if application code catches the error; it
cannot commit success or a failure marker based on an incomplete view. Rejection,
uncertainty, revoked access, stale ownership, retirement and unavailable history
keep separate error categories/native codes. Allocation failure while exposing
a runner event leaves native/state evidence available for reconciliation or
close; no callback is rerun just to reconstruct a confirmed receipt.

## State, Tables and results

Typed keys carry a codec. `state_find` distinguishes missing values from decoded
application values. Mutations, mailbox progress and outputs commit in one proposal,
with one mutated associated KV resource per turn. Query/read version helpers do
not turn associations into grants or lifetime ownership. Ask `turn_budgets` for
remaining operations; durable collection size is independent of a page bound.

Pages, cursors, decoded values, rows and segments have explicit destroy functions.
Page entry/row views borrow their owning page; copy bytes before releasing it.
Table handles retain their turn scope and reject use after completion. Tables
have an i64 key and one nullable i64, boolean, UTF-8 or binary value column. Native
schema capture verifies the typed declaration. Nullable cells differ from a
missing row. Retained versions support bounded point/page reads with current
authorization, and are read-only. Releasing their durable identity is an explicit
turn operation, separate from freeing a local handle.

Query plans expose projection, comparison/null predicates, aggregation and limit.
Fuze executes in Zig. Verified result completion leads to a complete manifest
with source/destination, correlation, captured resource/revision/schema, plan and
segment/row/byte counts. Every segment read rechecks current access. Each owned
segment retains its manifest, digest, ordinal, row count and original IPC bytes;
`segment_ipc` returns a copy that survives segment and runner destruction. Reading
one segment does not claim the caller fetched the entire result. Stream bounded
segments into an application-owned consumer instead of collecting an unbounded
result in the SDK. No Arrow C/C++ dependency is selected; the shared proof uses
an independent PyArrow reader for the original IPC.

The [C examples](../../../../examples/station-sdk/c/README.md) implement both roles.
Their persistence files contain signed requests, not private seeds. Effects in
query-consumer callbacks occur before commitment and need application idempotency.
The old generated ABI remains available as an explicit lower-level interface;
moving to this SDK replaces manual prepare/apply/finish loops with handlers,
typed helpers and observed recovery events.
