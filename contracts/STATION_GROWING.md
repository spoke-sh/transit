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
share the same codec and transaction semantics as Station v1. Bounded Table
iteration returns at most eight typed rows and an explicit continuation. Query
execution and large retained Arrow results require further qualification in M10.

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

Table page continuations name their source (turn-view ID or retained-version ID),
resource, revision, Table, schema fingerprint and exclusive signed row key. Every
page still needs current read authorization. Iteration over a turn view excludes
private mutations and must preserve that view until completion or explicit failure.
A page boundary does not establish a complete Arrow result.

`GrowingTurn.retain` stages retention of its committed source and returns its
future durable ID. `openVersion(id)` supplies a read-only Table/KV source using
the [retained-version contract](READ_VERSIONS_V1.md); `release(id)` stages terminal
release. They publish only with the handler's final proposal. Metadata and data
reads automatically register the version in that proposal's read dependencies,
so access changes between reading and publication are checked by the authority.
Read failures poison the whole proposal. Private writes can record continuation
progress while reading a retained source; they do not enter the source snapshot.

A retained source borrows the current private turn. Never keep that native pointer
across handlers. A later handler reopens the durable ID and may resume a matching
Table cursor. The application must persist its job/cursor/progress and send durable
continuations in the same turn decision. Station does not infer a restartable job
from a native iterator, and no general query scheduler or Arrow result protocol
is implied by these helpers. V2/foreign bindings do not expose them yet.

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
