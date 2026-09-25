# Station growing development profile

Status: M10 development behavior/point-state slice over the explicit
[Transit v3 profile](TRANSIT_V3.md). Existing launchers, Station v1, Board lenses
and foreign ABIs continue to use [Station v1](STATION_V1.md). There is no implicit
upgrade, mixed-profile resource or claim that all M9 services are available here.

## State and turns

A growing behavior resolves one required named association and captures its
writable resource through the public client. A handler reads individual keys
through that view and retains at most four private mutations and four outputs.
It never receives a complete resource snapshot. Typed Table point operations
share the same codec and transaction semantics as Station v1. Query paging and
large retained Arrow results require separate qualification within M10.

Each state read enforces current authority and checks the exact captured view.
Private writes take precedence over captured values. Read/transport failures
poison the proposal even if the handler catches the error: no partial decision
or application-failure marker may be published from an incomplete read. Retrying
reads may reconstruct the private turn; uncertain mutations must instead retain
and reconcile their exact signed bytes before any handler runs again.

Application failure discards all private writes and outputs and proposes only
the kernel failure marker. Initialization and the first successfully handled
input commit together. The descriptor is `station.genserver.growing.v1` at
`00 station`; an incompatible descriptor is an explicit error.

## Calls and lifetimes

Message framing and authenticated reply rules remain `STN1`. Durable waits use
the same `00 w <correlation:u64le>` keys with a version-2, 34-byte value:
version=2, phase byte, destination:u64le, deadline-ms:u64le, resolution-input:u64le,
observer:u64le. Zero deadline/observer means absent. Phases are unchanged.
The observer accepts the full public principal range; v1's one-byte sentinel is
never reinterpreted. Root is not a timer identity. Timed calls require an explicit
observer and cannot exceed known process work or resource lifetime bounds.

Wait closure and acknowledgement retain evidence by default. More completed
waits or Table rows than fit the legacy snapshot do not require deletion.
Association, current grants, activation, view deadlines and one authoritative
state/input/output decision retain their kernel meanings.

This profile does not yet advertise growing registries, supervision, captured
query results, runtime bindings, foreign bindings or complete Station capability.
Unsupported framework result frames fail explicitly rather than being treated
as verified result completion. These remain M10 integration work.
