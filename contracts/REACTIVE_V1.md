# Reactive API v1

Status: implemented M20 opt-in int64 Table profile. No SSE/WebSocket capability
is advertised by default. Independent TLS peers, Chromium, Compose and reference
recovery are recorded in the [proof ledger](../tests/README.md#m20-qualification). [Public types](../packages/zig/transit-serving/src/ReactiveModel.zig) and
[generated descriptions](../packages/zig/transit-serving/api/) own the encodings. This extends
[serving v1](SERVING_V1.md), not native authority or Board's OpenAPI 3.1 contract.

## Authority and identities

The service identity is `(realm, ingress PID, service number)`. Native caller
signatures, current native grants and current service read/command policies apply
across HTTP, SSE and WebSocket. Commands carry the same prepared native signed
bytes on every transport. Transport fallback never prepares a replacement command.
A native receipt means ingress acceptance; service admission, application outcome
and client processing remain distinct.

One Station ingress owns durable session/subscription metadata in its existing
resource. Socket queues, challenge caches and attached tasks are disposable.
Session IDs are scoped to a caller and service. Each accepted session has a durable
generation; each subscription has its own ID and generation. Attachment revisions
increase conditionally within a session. A connection ID is a random, short-lived
challenge, not a session, operation or event ID.

The first profile admits at most four live sessions per service and two per caller,
with one subscription per session. These are active-work bounds. Closed session
history grows through public point reads without a resident total-cardinality
array. Reconnecting or switching transports does not multiply the durable quota.

A published watch binding declares the exact target PID, resource, Table,
application progress key and schema. Publication is conditional and revisions
are immutable. It grants no read rights. The gateway's inspect scope covers both ingress and source, with separate explicit
resource grants. Its
current source metadata, caller policy and accepted watch declaration must all
permit a read. Draft configuration and observed listener capability are separate
from accepted publication.

## Durable controls and leases

Open, attach, subscribe, renew, unsubscribe and close are ordered native commands.
The caller retains each prepared native command until its input commit/disposition
is known. Invalid controls produce a durable rejection; storage/read failure
aborts the private turn. Native acceptance alone does not prove a control applied.

Session leases are finite and independent of Station call deadlines, process work
bounds, resource expiry and result retention. A trusted, configured observer
records monotonic time observations. Open/renew bounds the requested lease by that
recorded observation plus the published maximum lease interval and by applicable
process/resource bounds. Renewal changes no scope or operation deadline.
Authenticated expiry observations close a live session and free its active slot;
duplicates do not reopen it. When the observer is unavailable, gateways stop
lease-bound disclosure and new admission remains bounded by the existing quota.
Hard native resource/process expiry needs no observer delivery.

Close, unsubscribe, lost transport and lease expiry never cancel an accepted
application command. Explicit serving cancellation retains its existing ordered
wait semantics. Outcomes remain readable through authorized ordinary HTTP recovery
while their owning resource is available.

## Attachment bootstrap and fencing

The browser/service client proves its provisioned signing identity in message
bodies. No private credential appears in a URL, subprotocol name, log or durable
record. Exact HTTPS Host and browser Origin checks accompany signature/grant
checks; Origin alone is not authentication.

Each new attachment uses a random server challenge with a short local validity
window and bounded pending capacity. For SSE, an authenticated HTTP challenge
exchange precedes the streaming POST on the same gateway; a proxy must preserve
that short exchange's affinity. Committed session/cursor recovery is shared across
gateways using the configured reader signing identity. WebSocket sends a challenge after its
strict upgrade, before accepting application messages. The client signs the same
native attachment control used by HTTP, binding the challenge and expected prior
attachment revision. The gateway consumes its local challenge once and observes
the durable attachment commit before disclosure. A lost challenge or uncertain
attachment is recovered by checking durable session state and opening a new
attachment; it never authorizes a new application command.

Every bounded message/read checks the current session, subscription, attachment,
lease and native/service/source authority. Replacement fences the old attachment
at its next admission/disclosure check. Bytes already authorized and released may
finish; atomic socket transfer is not promised. Idle attachments revalidate on a
finite interval. Denial, expiry, reset and transport interruption differ.

## First source: Table data progress

The non-trading Table owner writes `data-progress` in the same Station commit as
every relevant Table mutation. Its **entry revision** is the data watermark;
the stored integer, mailbox input position and another resource's revision are
not substitutes. Query capture, status reads and other bookkeeping do not change
that entry. This is a trusted application-owner contract, not proof of honest
arbitrary computation.

The public snapshot operation reads the Table schema, progress entry and bounded
Table page at one resource revision. A conflicting acquisition retries the whole
bounded observation or returns interruption/reset; it never mixes cuts. It returns
the exact page basis and a compatible watch cursor. Later polls read current
progress. A commit during or after acquisition is either included in that basis
or appears as a newer data watermark, so coalescing cannot lose relevant changes.

A finite query's captured basis can cover a watermark only for the same source
resource and schema, with `captured revision >= data watermark`. A query result
cursor/source pin is not a watch cursor. Finite query capture releases its pin
under M18; watching requires its own current reads. Empty pages and bookkeeping-only
commits do not invent a data invalidation. Schema, policy, binding and lifetime
changes still produce their own control/availability outcomes.

The first transport snapshot profile is an int64 Table. Row keys and values
encode as lossless decimal strings, with at most eight rows and a `more` flag;
use the existing finite query reader for larger snapshots. Protocol identities
remain safe JSON integers.

The first delivery classes are coalesced source invalidations and notifications
of recoverable operation outcomes. An invalidation covers every relevant mutation
through its named watermark; it does not enumerate mutations or promise a
continuous query answer. An outcome notification references the retained serving
operation, without materializing a query result into a socket queue. This is not
a lossless domain-event broker or durable client-processing acknowledgement.

## Cursors and recovery

A cursor binds realm, principal, service/ingress, session generation, subscription
ID/generation, watch revision, exact source/schema and covered-through watermark.
It is integrity-protected with a domain-separated gateway signature and is never
a read grant. Attachments may change while the same authorized subscription
continues. Forged, foreign, future and incompatible cursors reject; lost coverage
or changed schema/publication produces explicit reset-required.

The progress key remains durable for the source lifetime. The first invalidation
profile coalesces directly from an authenticated older watermark to current
progress; it does not scan an unbounded log or claim intermediate event retention.
A restored gateway reconstructs session and source meaning through public reads.
New admission after a closed session uses a new session identity; old command
receipts/results remain independently recoverable.

## SSE and WebSocket bindings

SSE uses UTF-8 `text/event-stream`, bounded single-line JSON data, explicit event
types and integrity-protected event IDs. Resume accepts the last cursor from the
client. Heartbeats contain no protected application data. After response headers,
a typed terminal disposition or interrupted transport replaces HTTP status changes.
The browser binding uses fetch streaming, so credentials/resume stay in bodies
and headers rather than URLs. Independent peers must handle partial UTF-8 and
partial lines without buffering an entire stream.

WebSocket uses RFC 6455 over HTTP/1.1 and a versioned subprotocol. Validate key,
version, Upgrade/Connection tokens, duplicate security headers and exact Origin.
Require masked client frames; bound encoded frame size, fragment count, reassembled
UTF-8 message size and decoded envelopes separately. Control frames may interleave
with fragments. Ping/pong and close frames have their RFC bounds and close races
join owned work. Decline compression offers and reject RSV bits, unmasked input,
invalid UTF-8, reserved opcodes and unsupported binary messages. HTTP/2 extended
CONNECT is unavailable.

Both bindings use the shared session, control, command, result-reference and event
types. Slow output has a finite deadline and a bounded queue; it cannot accumulate
historical result pages or prevent control/revocation progress. The listener keeps
its separate health reserve. A response write, TCP acknowledgement or pong is not
durable application acceptance or client processing.

## Descriptions and qualification

Generate OpenAPI 3.2.1 HTTP/SSE and AsyncAPI 3.0 WebSocket descriptions from public
runtime types and operation metadata. Runtime decoding rejects unknown versions,
fields, enum values, malformed identities and exceeded byte bounds. Pinned
independent validators check descriptions, examples and actual peer traces.
OpenAPI's `itemSchema` describes the SSE media-level `event`, `data` and optional
`id` fields. The `data` string has `contentMediaType: application/json` and a
`contentSchema` referencing the same `ServerMessage` as WebSocket. Because JSON
Schema treats content keywords as annotations, the independent validator explicitly
decodes and validates that content and checks its tag against the event name.
Authenticated discovery identifies the accepted binding and description digests.
Existing Board OpenAPI stays versioned separately.

The proof matrix records Table/SSE and Table/WebSocket, non-UI peers, a minimal
browser transport harness and each actual placement independently. Board
inspection, KV/Document watches, live-view UX, reactive SDK wrappers, compression,
lossless event histories and other inbound protocols remain unavailable until
qualified in their own rows. M21 consumes the demonstrated snapshot/watch and
reset contracts; it owns refresh scheduling and presentation.
