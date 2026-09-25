# transit-station

Station is the caller-side framework above Transit. This package uses
[`transit-client`](../transit-client/README.md); the authority never imports a
behavior or runs its handler. The initial implementation provides a host-pumped
GenServer, private KV mutations, durable calls and authenticated replies.
Typed Tables and captured Arrow queries share the same private turn and state
budget; see the [Table implementation guide](docs/tables.md).
The [services guide](docs/services.md) covers scoped names, timed waits and
bounded supervision, including the separate controller trust boundary.
The [binding guide](docs/bindings.md) covers the shared C ABI and detached
poll/finish interface used by foreign-language handlers.
[M9](../../../docs/roadmap/M9.md) records qualification and the bounded profile.
The [lifetime guide](docs/lifetimes.md) explains retention, suspension and
permanent retirement without hiding the kernel's contracts.

`GenServer.step(handler, proposed_read_deadline_ms)` does bounded client work,
returning `idle`, `progress`, `committed`, or `blocked`. A handler receives a
detached `Turn`, with reads, private writes, sends and replies. It receives no
client or signing key. This API separation is not native-code sandboxing.

The required named association resolves to a resource written by this PID.
Initialization and the first input commit together; initialization is not rerun
after worker recovery. Handler errors discard all private work and commit a
kernel failure, leaving the input visible and blocking further execution.
Administrative lifecycle control remains independent of the handler.

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
