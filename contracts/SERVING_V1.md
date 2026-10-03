# Serving profile v1

Serving v1 defines service identity, caller authorization, durable command
admission and bounded reads. [Serving](../docs/reference/serving.md) explains
the architecture and protocol adapters.

## Owner and publication

One growing Station ingress process and its private resource own one service.
Service identity is `(realm, ingress PID, service number)`; the number alone is
not a global name or alias that can retarget accepted work. These identities,
administrator and timer observer are fixed at bootstrap.
An administrator's ordered `publish(expected_revision, binding)` input commits
the accepted revision and a retained immutable revision record together. A
binding names the exact application PID, application codec, route profile and
active operation limit and a finite upper bound for operation wait deadlines.
The HTTP route profile is `/serving/v1` with explicit
command, read and discovery operations. Arbitrary path-to-PID forwarding is not
supported. Retiring publication stops new operations; retained operations keep
their original binding, target, digest and recovery path. Publication grants no
access. Listener observations and draft configuration are not accepted revisions.

The administrator separately publishes conditional per-principal service policies
for command/read permission and active quota. Policy changes take effect in input
order. The growing kernel still checks current scoped publish/read grants; service
policy cannot replace them. Across callers, at most eight operations are active
per service in this initial profile. Only active work has a bounded slot table;
declarations, policies and terminal operation records use paged durable keys and
have no resident total-cardinality array. Deployment storage/backlog quotas remain
mandatory. Exhaustion refuses new work and does not expire evidence.

## Identity and trust

Provisioned service clients sign native growing `send` requests addressed to the
published ingress. The HTTP adapter validates the selected serving envelope and
forwards the exact signed native request without a gateway-owned signing sequence.
The kernel verifies caller identity/current grant and supplies the authoritative
external origin. The behavior never trusts a principal copied into an application
payload or forwarding header. Service admission is the owning Station commit,
after current service policy and revision checks.

Bounded reads use a scope-bound Ed25519 authorization over the versioned read
request, plus a native signed identity query from that same provisioned key.
The adapter verifies both signatures and asks the authority to validate current
identity. It then uses its separately scoped resource reader to apply the current
service read policy and return only that principal's operation. The resource
reader is a trusted service component; callers receive no raw resource grant.
Service policy explicitly permits this result disclosure. Neither the native
identity proof alone nor a bearer operation ID authorizes another read scope.
Every disclosure rechecks current authority and service policy. Browser session
bootstrap follows the separate [reactive contract](REACTIVE_V1.md); it does not
create an alternate native signing mechanism.

The application trusts only the configured ingress PID's authority-derived
process origin. The forwarded invocation includes original caller, service,
operation ID and binding revision. This is a narrowly provisioned service trust
boundary, not general Transit delegation. Host, exact Origin and TLS/termination
policy apply independently. Authentication material and payloads never enter logs.

## Admission and outcomes

An operation key is `(service, principal, operation_id)`. Its canonical command
digest covers codec, requested binding revision, absolute wait deadline and exact
application payload. Duplicate identical commands recover the original operation;
different content under the same key conflicts, even after completion or route
retirement. The key is independent of socket, gateway instance and native signing
sequence. A client must freeze native signed bytes before sending, coordinate its
native sequence across its own writers and reconcile an uncertain receipt before
preparing different bytes at that sequence. The gateway never repairs conflicts
or retries different work automatically. A deliberate new native submission of
the same operation is deduplicated again at the Station owner.

The admission turn commits the operation record, bounded active slot, Station
wait and outgoing application call atomically. Correlation is the ingress input
position. A reply must match the recorded target/correlation; it commits the
terminal record and releases the slot atomically with the Station wait. Malformed
or unauthorized external frames must be consumed as durable dispositions before
framework reply/timeout dispatch, without blocking unrelated admitted work.

Receipts distinguish `ingress_accepted` (native send receipt), `service_admitted`
(owning turn and recorded outbox), and `completed` (application reply recorded at
ingress). Destination admission is separate public outbox evidence; an emitted
outbox alone cannot claim it. HTTP 202 names only the stage actually observed.
Response-write completion never means client consumption. Pending, completed,
cancelled, timed_out and rejected dispositions remain distinct. Recovery reads
are bounded, current and carry the exact resource revision used.

Cancellation closes the Station wait and sends its ordinary cancellation frame.
It cannot retract destination work or imply external effect cancellation. A
socket deadline/disconnect/drain merely ends that transport. Timed waits use an
explicit authenticated observer, are clamped by finite process/resource lifetime,
and preserve duplicate/late timeout semantics. Hard kernel expiry requires no
observer delivery. Retained records have unlimited retention by default; closing
a wait or transport grants no cleanup authority. Explicit expiry can make recovery
unavailable and must be reported as such, never as a successful empty result.

## Encoding and extension

All durable values use the `SV1` family of tagged, length-checked binary records;
integers are little-endian u64 unless declared otherwise. Keys use `\0sv1` plus
a record kind and up to two big-endian u64 identities. Command and result payloads
are opaque application bytes, each at most 64 bytes in this first inline profile.
Finite queries/results use the existing public query contracts and bounded result
references, not inflated inline limits. The public Zig definitions and shared
fixtures own exact tags/layout; encodings reject trailing bytes and unknown tags.

`Model.zig` field order is wire order. `Codec` writes a one-byte record tag after
`SV1`, one-byte bool/enum tags, fixed-length arrays and one-byte inline lengths.
Record tags are `g` configuration, `b` binding, `p` policy, `c` command, `s` submit
digest input, `i` invocation, `o` operation, `a` active slots and `r` scoped read. Rejected input records use `e`.
Key kinds are `c` configuration, `b` current binding, `v` immutable binding revision,
`p` principal policy, `o` principal/operation, `a` active slots and `e`
principal/input disposition. Principals and counters use the native safe-integer
range. Codec IDs are u16; active limits are u8. Opaque payloads are lowercase hex
in JSON. Incompatible field changes replace the shared current v1 definition; old records
and signed requests are rejected before execution.

HTTP mechanics are defined in [HTTP_SERVING_V1](HTTP_SERVING_V1.md). The
[reactive profile](REACTIVE_V1.md) qualifies Table SSE/WebSocket and reuses the
same service operation identity and outcome records across transports. The
[Flight profile](FLIGHT_V1.md) separately qualifies finite Table queries. Neither
provides a generic inbound application gRPC server or another retry database.

## Rejected input evidence

A principal/input disposition is one `SV1e` record defined by
[`ServingFailure.Record`](../packages/zig/transit-serving/src/ServingFailure.zig).
Its declaration-order encoding contains the finite reason, native input, command
family, supplied subject/generation, original frame commitment, bounded underlying
cause and tagged witness. The frame commitment is SHA-256 of
`transit.serving.input.v1\0` followed by the complete original Station frame bytes.
The maximum record is 194 bytes, within one state mutation. The owner rolls back
its private proposal before recording a request rejection. Read failures poison
the proposal and remain unresolved; they do not become committed rejections.

Witnesses retain values already read at the failing decision: policy revision and
permissions, conditional binding/watch revisions, original/submitted operation
commitments, active counts and limits, binding codecs, lease bounds, session
phase/clock and attachment/subscription generations. No later metadata read
reconstructs a historical conflict. Unknown or unrecorded facts remain absent.

Serving disposition reads and private host `observation.rejected` return
`{ record, diagnostic }`. The public record includes reason, input, family,
subject/generation as exact decimal strings, commitment and underlying cause.
The optional shared diagnostic projects the original witness with outcome
`input_rejected`, evidence `domain_status` and inspection guidance. It does not
claim the earlier operation failed, permit replacement work or retry a command.
Current caller/native/service read authority is rechecked before release. A
changed policy never rewrites the original witness or grants access to it.
Bare error-string records are not decoded as the current record layout.


## Operation outcome evidence

Every `SV1o` operation retains its original target, binding/codec, policy revision,
command commitment, wait deadline and admission correlation. Terminal resolution
retains its native input and, for an authenticated reply, its exact payload byte
count. The record is at most 170 bytes. A reply of at most 64 bytes is retained;
a larger reply closes the serving operation as `failed`, retaining its count
without retaining the oversized payload. This is a result-delivery failure and
does not establish application rollback or business failure. Missing or invalid
phase/count/result combinations reject as invalid stored evidence.

Current-authorized status and result reads include the shared operation
diagnostic. A result request for a non-completed operation returns HTTP 409 with
reason `result_not_completed` and that same retained outcome after the final
authority check. It never describes cancellation or timeout as pending admission.
Reactive outcome events include the same diagnostic and its serving resource.
The browser validates optional detail against the phase, operation, resource,
realm, caller/service scope and resolution input. Invalid detail leaves the
primary outcome intact and is marked invalid.

Codes are `serving.operation_admitted`, `serving.reply_recorded`,
`serving.wait_cancelled`, `serving.wait_timed_out` and `serving.reply_too_large`.
Their respective shared outcomes are pending, completed, cancelled,
closed_unknown and failed, all backed by domain status. Only admission offers
cancellation of the local wait. Terminal states offer inspection and never fresh
resubmission, generic resume, remote cancellation or rollback. A recorded reply
remains opaque to serving: its declared application codec determines the business
meaning. Exact retries and later binding changes do not replace original detail.
