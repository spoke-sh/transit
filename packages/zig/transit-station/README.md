# transit-station

Station is the caller-side framework above Transit. This package uses
[`transit-client`](../transit-client/README.md); the authority never imports a
behavior or runs its handler. The initial implementation provides a host-pumped
GenServer, private KV mutations, durable calls and authenticated replies.
Typed Tables and captured Arrow queries share the same private turn and state
budget; see the [Table implementation guide](docs/tables.md).
The growing Zig [publication interface](docs/publications.md) stages larger
immutable records with explicit quotas, one final visibility decision and
resumable cleanup. Document/CRDT APIs remain a separate milestone.
The [services guide](docs/services.md) covers scoped names, timed waits and
bounded supervision, including the separate controller trust boundary.
The separate [binding package](../transit-station-bindings/README.md) owns the
shared C ABI and its generated declarations. Its [binding guide](../transit-station-bindings/docs/bindings.md) covers the detached
poll/finish interface used by foreign-language handlers.
[M9](../../../docs/roadmap/M9.md) records qualification and the bounded profile.
[M10](../../../docs/roadmap/M10.md) addresses its structural collection limits
before public SDKs. The current 32-entry resource and complete turn snapshots
are hard implementation constraints; they are not tunable memory caches or the
intended maximum size of application state.
The explicit [growing interface](docs/growing.md) adds bounded captured reads,
shared private-turn/Table operations and full-width durable wait identities;
it has bounded M10 qualification and does not change the default profile.
Its [incremental query capture](docs/queries.md) stages and seals growing Arrow
results over retained sources. Explicit query-enabled hosts publish and verify
segments with receiver credit and a complete-result manifest; capture alone does
not complete a remote call. Existing launchers and legacy foreign ABIs do not opt in.
The separate growing C ABI and native port now expose scoped turns, bounded
KV/Table pages and retained sources with explicit preparation and dispatch.
The [binding guide](../transit-station-bindings/docs/bindings.md#explicit-growing-turns) describes ownership,
receipt recovery and capabilities, including explicit growing query capture and
verified manifests/IPC segments. Public SDK runners remain M11 work.
The [lifetime guide](docs/lifetimes.md) explains retention, suspension and
permanent retirement without hiding the kernel's contracts.

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

If concurrent journal progress expires a legacy inspection cut while loading
associations or a captured view, the next poll restarts the complete page read.
No handler sees a partial snapshot. This read retry preserves the captured view;
it does not retry or discard a conflicting mutation or renew an expired view.

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
`just test::unit` for the private proposal checks.
