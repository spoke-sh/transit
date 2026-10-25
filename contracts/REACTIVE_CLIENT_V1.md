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
Follow carries a completed template and one to eight separately prepared query
namespaces. Each prepared bundle has the same declaration, plan, limits and
execution route, with its own caller-signed current-capture grant and durable pin
identity. The owner authenticates the original accepted caller and every bundle,
and checks current Table privileges before activation. Metadata-only resource
inspection is insufficient. Status checks current resource and Table read
authority and returns view/query identities and progress, never rows.
The read-only inspection credential does not acquire send authority.

The query host's `refresh` preparation returns a new signed bundle from a verified
completed template and an explicit operation identity. `next.prepare_only` uploads
that frozen bundle and stops at `prepared`, without admitting a source call or
acquiring a pin. The browser retains the bundle, namespace and exact native token
through uncertain replies before sending Follow. Its `captures` array has eight
entries: the first `limit` are distinct nonzero namespaces, different from the
template, and the remainder are zero. Scheduling activates those identities in
order; it never copies a completed grant or asks an executor to renew signatures.

Prepare returns an owned native signed send. Submit forwards precisely those
bytes. Retain them through unknown replies, including component remounts; retry
never calls prepare again. Native acceptance returns an input position. Observe
checks the current ingress head and the service's committed disposition before
reporting pending, committed or rejected. Only the committed control advances
the client lifecycle. Session opening and subscription generations come from
those actual committed input positions.

The read-only `recover_control` operation takes those original signed bytes,
validates the current definition and configured realm/principal/ingress/role,
and returns the owning decoder's control and actual receipt input, or null input
when absent. It checks current native and service read authority before and after
receipt lookup. An absent request must verify under the current signing key;
an accepted request is identified by its exact native receipt even after key
rotation. It does not sign, submit, open or renew anything. Administrative,
observer and application commands are rejected. Refresh decoding requires the
host's explicit refresh capability. This operation uses reserved control capacity.

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

`covered` delegates to `TableWatch.covered` for the same resource, partition,
contract and schema, comparing the captured accepted position with the observed
logical-change watermark. This deterministic relation is not an authorization
decision. Catalog/object/interpretation IDs and Table positions use canonical
unsigned decimal strings. Native process/resource revisions retain their native
safe-integer representation. Complete query verification and a current authorized
visible-page reread remain required. Query manifests expose a verified
`table_position`; KV/Document results carry null for that field.

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
service policy and caller catalog inspect/read rights are rechecked before
disclosure, including after session closure. A renamed or dropped Table does not
prevent reading retained diagnostics under those current rights; a catalog
revocation does.

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


HTTP error bodies use the shared serving `Error` schema: primary `err`, optional
finite `reason`, and optional owned `diagnostic`. Listener-level capacity or
invalid HTTP requests can lack semantic detail. The HTTP status remains primary
when an optional body is malformed or incomplete. A semantic reason must agree
with the status; absent detail cannot turn a generic conflict into a required
snapshot reset. Resource unavailability is distinct from session closure/expiry.

Submission diagnostics bind to the exact signed request's realm and sequence.
Invalid or mismatched optional detail is flagged without dropping pending work
or retrying a command. Read-only capacity retries remain bounded. Terminal stream
messages similarly retain their finite reason when optional detail is invalid.
