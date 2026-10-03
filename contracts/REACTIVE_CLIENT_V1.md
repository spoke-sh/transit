# Reactive private host client v1

The private host client connects browser viewers to bounded int64 Table sessions. The owning types are
[`ReactiveClient`](../packages/zig/transit-serving/src/ReactiveClient.zig); generated
[host schemas](../packages/zig/transit-serving/api/client.json) accompany the
existing [reactive API](REACTIVE_V1.md). This adapter adds no session or cursor
protocol and does not authenticate individual Board viewers.

A deployment may explicitly select one provisioned caller for its private viewer
boundary. Its signing seed stays in the Zig host. The optional
`/reactive/v1/client` POST route requires the exact configured Origin and JSON.
No principal, URL or native operation supplied by a browser selects another
credential. The host limits preparation to open, attach, subscribe, renew,
unsubscribe and close. Publication, observer, policy and application commands
remain outside this adapter. A separate upstream reader still checks current
service and source authority; neither private reachability nor a signature
supplies those permissions.

Explicit `refresh` configuration enables preparation of follow, invalidate,
acknowledge and pause for the composed finite-query owner. The generation and
budget contract lives in the [refresh guide](../packages/zig/transit-serving/docs/refresh.md).
Follow requires `resource_read_access` and signs the caller's identity and two
resource read-access queries; the durable owner checks their current grants.
Metadata-only resource inspection is insufficient. Status checks current resource
read authority and returns view/query identities and progress, never rows.
The read-only inspection credential does not acquire send authority.

Prepare returns an owned native signed send. Submit forwards precisely those
bytes. Retain them through unknown replies, including component remounts; retry
never calls prepare again. Native acceptance returns an input position. Observe
checks the current ingress head and the service's committed disposition before
reporting pending, committed or rejected. Only the committed control advances
the client lifecycle. Session opening and subscription generations come from
those actual committed input positions.

Sign-read binds the configured realm/principal/service/ingress. The resulting
signed read uses the reactive API's HTTP read, challenge and SSE bootstrap unchanged. Challenge
and streaming attachment must reach the same gateway. An attached message means
the host observed that exact attachment commit; interruption before it preserves
the frozen attach operation. Reconnect first recovers that operation and observes
the current attachment, then obtains a new challenge. It never opens a replacement
session implicitly after lease expiry.

The default private profile cannot sign application snapshots or subscribe to an
application operation. Its inspection projection calls the existing Table watch
adapter and returns schema, exact source basis and data progress without row
values. The paired cursor can precede the metadata observation: this may repeat
an invalidation and cannot skip one. Both observations retain their own basis.
An explicitly configured application viewer may enable `snapshot_values` and
read the reactive API's bounded int64 Table snapshot. This does not add a decoder to Board.

`covered` delegates to `TableWatch.covered` for the same resource, contract and
schema; it is a deterministic relation, not an authorization decision. Complete
query verification and a current authorized visible-page reread remain required.

The `/reactive/v1/client/control` route reserves listener/caller capacity for
renew, unsubscribe, close, refresh pause and committed-input observation. It rejects opening,
attachment, discovery, snapshot and inspection work. Finite operations use the
same bounded upstream allocator as the signed host. Per-caller data limits include
both streams and reads: deployments serving two tabs must leave read capacity
in addition to their two streams and qualify that configuration explicitly.

The browser package derives types and CSP-compatible validators from the owning
Zig schemas. It validates SSE fields and separately validates their JSON data;
`contentSchema` annotations alone are insufficient. The parser retains one
9216-byte framing buffer and no history queue. Finite JSON responses are capped
at 16 KiB and 35 seconds. Application int64 values remain exact decimal strings.
The host's lease and final current-authority checks remain authoritative.

Descriptions include `observed_ms`, the ingress owner's committed observer clock.
The private host rejects samples absent or more than ten seconds behind its
conservative upper clock bound. Callers choose open/renew deadlines from that
sample and the advertised maximum lease. Reading a description does not emit an
observer command. Only the separately authorized observer records clock progress.

The read-only `clock` operation returns the same validated observer sample through
reserved control capacity, with current native/service authorization. Renewal
uses it without repeating discovery/schema reads. It grants no extra lease;
the owner still validates the subsequently recorded conditional renew command.

Committed control rejection carries the serving owner's original input record
and optional diagnostic. The browser releases that completed control's sequence
lock and preserves its finite reason. It separately inspects current scope when
an attachment exists. A later scope failure does not relabel the original
rejection or make the control uncertain. Current denial/closure/expiry clears
protected view state and suppresses the retained diagnostic from display.
Malformed optional detail cannot replace the primary rejection or authorize
retry. The shared TypeScript diagnostic package validates owned details.

An explicitly closed session reports `ReactiveSessionClosed` and a stream
terminal `closed`. An expired lease reports `ReactiveSessionExpired`/`expired`.
An observed deadline with recorded phase `open` does not prove the owner has
reclaimed its active slot. Neither condition cancels accepted application work.


Follow status has a `view`, requester `resource`/`revision`, `policy_revision`,
optional `diagnostic` for the original scheduler stop, and optional
`query_diagnostic` for the selected query. Head, view and query status are copied
at one native cut after discovering the namespace. A changing selection retries
at most three reads. Current native identity, source/requester read access and
service policy are rechecked before disclosure, including after session closure.

The stored view includes a finite stop reason, original committed input and
check-time witness. No stop is represented explicitly by the `none` variant.
Scheduler diagnostics use `not_applicable` outcome; the independent query
projection uses its retained rejection, cancellation or retirement outcome. Its
absence does not assert successful completion. Namespaces use exact decimal
strings throughout. The combined response remains within the 16 KiB client bound.

The browser validates scheduler input, view generation and session identity, and
binds query diagnostics to the selected namespace. Malformed optional details
are flagged independently without losing primary progress or scheduling work.
A failed query pauses presentation with the last exact result; authority denial
clears protected state. No diagnostic implicitly submits SQL or grants a budget.
