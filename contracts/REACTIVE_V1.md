# Reactive API v1

The reactive API provides int64 Table snapshots and notifications over SSE and
WebSocket. Enable each transport explicitly in the service configuration.
[Public types](../packages/zig/transit-serving/src/ReactiveModel.zig) and
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

A published watch binding declares the target PID, realm/resource/catalog scope,
stable Table object, and immutable metadata revision/length/digest. Publication is conditional and revisions
are immutable. It grants no read rights. The gateway's inspect scope covers both ingress and source, with separate explicit
resource grants. Its
current source metadata, caller policy and accepted watch declaration must all
permit a read. Database CONNECT, schema USAGE and Table SELECT are checked for the authenticated
original subject on every observation and final bounded release; the gateway identity does not substitute for them.
The session read returns session state and a null source under current service
policy. It does not disclose the watch's Table declaration. Discovery, snapshot
and event reads require the source privileges above.
Draft configuration and observed listener capability are separate
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

Read envelopes carry the complete scope-bound authorization proof described in
[serving v1](SERVING_V1.md#identity-and-trust), including the current credential
epoch and selected role. A credential rotation fences an existing read proof.
The client acquires a fresh read proof while preserving any accepted control’s
original signed bytes.

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

## Table observation and progress

The watermark is the **native entry revision** of the general Table head.
Catalog resolution verifies its immutable metadata/schema commitment at the
same resource cut. A head reservation, cancellation or no-op completion may
advance the watermark without changing rows; it signals possible change.
Query capture, result/status bookkeeping and unrelated Tables do not write
this head. Neither the Table's logical revision nor another resource's native
revision is a substitute for this watermark.

The snapshot operation checks catalog configuration/owner, current caller
database/schema/Table privileges, live object, exact metadata, schema, head and the first
bounded row page at one resource revision. Conflicts retry the entire acquisition
or return interruption/reset. Readers see only the published row/index root,
including while a successor is staged. The later publication advances the head
again; an earlier reservation notification cannot hide that publication.
Dropping or altering the metadata requires explicit source publication and a new
snapshot. Retained declarations never follow renamed or recreated objects.

A finite query's captured basis covers a watermark only for the identical source
resource, declaration contract and schema, with
`basis.cut.revision >= data_revision`. Its cut includes the exact Table head
commitment. A result cursor/source pin is not a watch cursor. Finite query capture
releases its source pin; watching requires current authorized reads. Merely
reading an empty page does not advance the watermark.

The snapshot transport admits exactly two INT64 columns, the first a non-null
single-column primary key and the second nullable or non-null. This is a
transport profile over general Tables, independent of the broader finite query
and storage type profiles. Incompatible shapes reject before row disclosure.
Both column names retain their complete bounded UTF-8 bytes. Row keys/values
encode as lossless decimal strings, with at most eight rows and a `more` flag.
Use finite query result pages for larger snapshots and other logical schemas.
Native identities remain safe JSON integers; catalog/object/metadata revision
identities use unsigned decimal strings.

The Source binary fields are, in order: watch revision, target PID, resource,
realm, catalog, object and metadata revision (seven little-endian u64s), metadata
length (u32), digest (32 bytes), and publication (one byte). Its payload is 93
bytes. The current metadata format is fixed by the shared v1 definition. It has
no alternate legacy decoding path; the coordinated definition cutover rejects
incompatible saved/native work.

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

The Table head remains durable, including its retirement evidence. The first invalidation
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
browser transport harness and each actual placement independently.
[Live views](../docs/handbook/reference/reactive.md) use these snapshot/watch and reset
contracts for bounded refresh in Board and applications, with a shared browser
client. KV/Document watches, compression and lossless event histories are not
supported. Refresh scheduling, presentation and any other protocol adapter retain
their own compatibility and lifecycle requirements.

An explicitly closed session terminates attached transports with `closed`;
`expired` describes a reached lease deadline or recorded expiry. Neither terminal
reason states that an independently accepted application command was cancelled.
Rejected lifecycle controls retain the original serving input diagnostic under
current read authority; see [rejected input evidence](SERVING_V1.md#rejected-input-evidence).


Terminal messages can include an optional shared diagnostic. It describes the
failed read, frame or exact command attempt; the terminal reason still governs
stream lifecycle. Resource unavailability interrupts a stream without asserting
that its session expired. Only a reached or recorded session lease uses the
`expired` terminal. A native submission receipt and its input position remain
separate from committed control/application outcomes. Closing the transport
cannot cancel those independently accepted operations.
