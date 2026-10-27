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

### Captured turn reads

GenServer reuses up to 64 validated committed point reads within the same
captured turn, including absent keys. Private writes take precedence; committed
sources exclude them. A new turn/view has a new cache. Optional bounded prefetch
requests at most eight keys through native `read_entries` against that exact
view with current authority and lifetime checks. Read failures poison the proposal, including cached reads after
failure. Native commit still rechecks current ownership, grants, fencing and
revision; the cache is not an authorization cache or a retained version.
