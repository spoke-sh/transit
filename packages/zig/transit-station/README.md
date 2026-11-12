# transit-station

Station is the caller framework above Transit. It uses
[`transit-client`](../transit-client/README.md); the authority never imports or
executes application handlers. `GenServer` and `Turn` provide paged resource
reads, private KV mutations, durable calls, authenticated replies and typed
[Tables](docs/tables.md) over the current native v1 protocol.

[Publications](docs/publications.md) stage larger immutable records with explicit
quotas, one final visibility decision and resumable cleanup.
[Ordered indexes](docs/indexes.md) use bounded path copying and resumable candidate
nodes. [General Table candidates](docs/table-data.md) compose typed rows and
collision-safe key indexes with bounded private overlays and resumable KV pages,
without publishing a Table head.
[Services](docs/services.md) provide scoped names, timed waits and supervision
with a separately authorized controller. [Query capture](docs/queries.md) retains
sources and publishes verified Arrow results across ordinary durable turns.
The [lifetime guide](docs/lifetimes.md) explains suspension and permanent retirement.

The [behavior and paging guide](docs/growing.md) owns the execution loop, captured
views and retained sources. All callers use this implementation; resident page
and operation bounds do not limit total retained application state.
The [binding package](../transit-station-bindings/README.md) composes the shared C ABI
and port for [language SDKs](../../../docs/handbook/reference/sdks.md). Its
[binding guide](../transit-station-bindings/docs/bindings.md) defines detached handlers,
explicit dispatch and ownership. Document and finite KV/Table/Document queries
compose above Station through their own packages.

The package also exports the `station_frame` module for consumers needing only
the versioned frame codec. It has the same `Frame` implementation and client
protocol types, without a Fuze/Arrow dependency. The bounded codec fuzz target
uses this interface; it does not substitute a test copy of the wire format.

`GenServer.step(handler, proposed_read_deadline_ms)` does bounded client work,
returning `idle`, `progress`, `committed`, or `blocked`. A handler receives a
detached `Turn`, with reads, private writes, sends and replies. It receives no
client or signing key. This API separation is not native-code sandboxing.

The required named association resolves to a resource written by this PID.
Initialization and the first input commit together; initialization is not rerun
after worker recovery. Handler errors discard all private work and commit a
kernel failure, leaving the input visible and blocking further execution.
Administrative lifecycle control remains independent of the handler.

If concurrent journal progress expires an inspection cut while loading
associations or a captured view, the next poll restarts the complete page read.
No handler sees a partial snapshot. This read retry preserves the captured view;
it does not retry or discard a conflicting mutation or renew an expired view.

When the host separately observes that a captured view has expired, it discards
the private proposal and renews the view only after resolving any outstanding
signed operation. Renewal reobserves the same durable input and current command
sequence; an earlier accepted view-open command has already consumed its sequence.
This worker recovery rule does not reopen an interrupted SQL result cursor.

A host can call `GenServer.retryExpiredOpen(failure, now_ms)` after dispatch
fails. It permits another view-open proposal only for an explicit
`DeadlineExpired` rejection after the proposed read deadline. Native receipt
lookup precedes deadline validation, so this rejection establishes that the
original open was not accepted. Transport loss, another rejection, a deadline
still in the future, or a pending turn commit leaves the exact proposal intact.
The next poll reobserves current metadata and the same durable input before
proposing a new read window. Local clock passage alone never permits renewal.

An unresolved operation stays ahead of the next handler as an exact signed
proposal. The same host retries those bytes. After host loss, acquire fresh
ownership before recomputation: the previous activation is fenced and the
public view reveals whether the prior turn committed. Never discard an uncertain
operation and recompute under its old activation.

Calls write correlation state and an outgoing request in one turn. Replies are
new ordered inputs; their authority-derived source must match the recorded
destination. Closed replies do not invoke application code. Waiting records
remain until an application explicitly selects a reclamation policy. A host
disconnection does not cancel a durable call.

See the [wire/layout contract](../../../contracts/STATION_V1.md) and the
[Station ledger example](../../../examples/station-ledger/README.md).
Run `just test::station` for the real-service recovery proof and
`just check::native` for the private proposal checks.

### Private transactional behavior composition

The package's `station_transaction_internal` module is a qualification target.
It is absent from the public Station root and bindings, and installed Station
applications continue to use `GenServer` above. Its [runner](src/transactional/Runner.zig)
composes ordinary Catalog, Table, KV, Stream and Queue callers. The database and
native authority do not import or invoke this runner.

An immutable declaration binds one native PID/code/workload, a control KV, one
state KV, one Table, an inbox Queue, replay Stream and output Queue. Bootstrap
retains that declaration as an original `SOR1` record and registers explicit
Catalog dependencies. It creates no worker. A control KV row holds discoverable
pending work; the row is progress, while native PID ownership and current grants
remain execution authority. Each host request carries the current signed native
execution prerequisite, so an old generation cannot publish delayed progress or
claim work after takeover.

A turn saves its original token, BEGIN, input claim and commit operation before
dispatch. It acquires one input and then a common transaction cut. The handler
gets private KV reads/writes, typed Table primary-key reads and Table DML, plus
journal/output builders. Table statements stage in the shared private workspace
before subsequent handler reads; KV reads see buffered writes. Original statement
work is retained before execution. Binary input, KV and output data use owned
base64 envelopes in retained progress. No handler receives a signer, settlement
handle or external effect dispatcher; this is not a native-code sandbox.

The input ACK, state mutations, one replay entry and output intents publish in
one ordinary transaction. The frozen native condition and original Queue claim
are independent decision requirements. Journal attribution joins the original
transaction receipt; an application row alone proves no actor origin. `advance`
performs one bounded turn or one recovery page. A failed or interrupted call
leaves discoverable original work. Recovery aborts undecided work or finalizes
its existing decision without invoking the handler, including under a replacement
principal. Missing BEGIN cannot clear discovery under the same activation:
absence does not cancel a delayed request. Acquire a new native generation first.

A caught read/write failure poisons the body. `block_input` records the blocked
disposition only after a proved abort. `stop` leaves unresolved work for recovery.
Queue lease expiry cannot clear a block; `retryBlocked` is an explicit authorized
choice after settlement. Permanent native retirement continues to fence all new
work. Recovery cancellation closes a missing original claim, while accepted claim
payload retention and lease settlement retain their separate owner semantics.

One runner has one active actor, a 64 MiB allocator ceiling, reusable scratch and
output arenas, a 128 KiB progress-record ceiling, and a 64 KiB handler-data ceiling.
A body admits at most 16 reads, 16 combined KV/Table writes and four outputs;
declarations can lower those bounds. Each claim selects one row. Idle actors and
inbox backlog remain in paged durable storage. The control KV is deliberately
outside the turn's five data participants so progress writes cannot invalidate
the turn's source cut. Private control-data writers are trusted host infrastructure;
handlers have no control-KV capability. All payload roots are ordinary KV, SOR1,
transaction workspace and Queue roots, with unlimited retention by default.

Run the package's `zig build test-transactional` for detached builder checks and
`just test station-transaction` from the repository root for the installed signed
caller/fault schedules. These checks do not activate a public transactional
Station API. Calls/replies, timers, registries, supervision, effect dispatch,
SDK migration and removal of the old persistence owners remain the
[Milestone 6 handoff](../../../docs/roadmap/06-streams-queues-and-durable-runtime.md).

### Captured turn reads

GenServer reuses up to 64 validated committed point reads within the same
captured turn, including absent keys. Private writes take precedence; committed
sources exclude them. A new turn/view has a new cache. Optional bounded prefetch
requests at most eight keys through native `read_entries` against that exact
view with current authority and lifetime checks. Read failures poison the proposal, including cached reads after
failure. Native commit still rechecks current ownership, grants, fencing and
revision; the cache is not an authorization cache or a retained version.
