# Transit native HTTP service v1

The service exposes the single current [native protocol](TRANSIT_V1.md).
`transit-client` owns canonical bytes, signatures, response validation and exact
retry. [Versioning](../docs/reference/versioning.md) defines the pre-1.0 hard
cutover policy. Clients, workers and services use matching builds.

## Routes and envelopes

| Route | Request | Success |
| --- | --- | --- |
| `POST /v1/command` | `SignedRequest { request, signature }` | `Receipt { position }` |
| `POST /v1/query` | `SignedQuery { query, signature }` | `Response { version, definition, realm, position, principal_sequence, body }` |
| `GET /health` | No body or credential | `{ ready: true, profile: "native_v1" }` after authority refresh |

The [generated schema](transit-v1.schema.json) owns complete fields, defaults,
union tags and bounds. Request and query versions are 1. Mutations use a positive
principal sequence; queries have no mutation sequence. Other routes return 404.
There are no alternate command, view, inspection, state or courier envelopes.

Signatures use Ed25519 over SHA-256 of the domain followed by canonical typed
JSON. The domains are `transit.request.v1` and `transit.query.v1`, each followed
by one NUL byte. Canonical JSON uses declared field order, compact UTF-8,
decimal integers, explicit defaults/nulls and single-key union objects. Owned
values use lowercase hex. Unknown or duplicate fields, unsupported versions,
invalid values and out-of-range integers reject before execution.

Canonical request and query fields start with `version`, `definition`, `realm`
and `principal`. The shared builders select the current definition; every
signature binds it. Query responses require that exact identifier. The generated
schema's `x-transit.definition` owns its value. The identifier distinguishes
incompatible builds which share the public v1 label; it is not a negotiation
offer. Old signatures cannot authenticate as current requests.

A command receipt records durable native acceptance or an authorized duplicate.
It does not prove that a worker completed domain computation. Preserve the exact
signed operation across uncertain transport outcomes and host replacement.
Never infer nonacceptance from a timeout, disconnect, malformed response or 503.

## Authorization and reads

Current credential bindings, role grants and optional PID scopes apply to commands,
reads and duplicate receipts. Native action masks are derived from the same
authorization graph. Resource inspection/read/write grants are independent
of process ownership and associations. Query results identify the authority
position and caller sequence; a continuation confers no authority. Each response
rechecks the authority tail before disclosure. A concurrent authority change
rejects the read; a subsequent revocation prevents the next authorized read.

`command.authorization` stages and publishes revision-checked policy changes.
`kind.authorization` supplies current identity, decisions, scoped policy pages
and retained administrative outcomes. These use the ordinary signed envelopes;
they add no route or separate policy authority. See [authorization v1](AUTHORIZATION_V1.md).

`kind: { process: PID }` returns process metadata and its next executable input.
The input owns opaque bytes and its authenticated external, process or effect
origin. Retired, suspended, uninitialized or failed processes expose no executable
input. Provider state and restored snapshots cannot grant execution rights.

`kind: { inspection: SELECTOR }` supplies the bounded, scoped
[inspection projection](INSPECTION_V1.md). Resource, association, entry and
retained-view queries use the same native query envelope. Leased snapshot reads
follow [snapshot reads](INTERACTIVE_QUERY_V1.md). There is no raw storage or provider
administration endpoint.

`kind: { delivery: {} }` requires current `delivery` permission (bit 128) and
returns `{ next: OUTPUT_ID_OR_NULL }` for the first pending output in the caller's
destination scope. It reveals no payload or source catalog. Submit the selected
ID as `command: { deliver: OUTPUT_ID }`, retaining the exact signed command while
its outcome is uncertain. Current `send` permission separately determines
successful admission versus recorded denial. Destination inputs own their value
and authenticated origin independently of later output-catalog collection.

## Errors and transport

| Status | Meaning |
| --- | --- |
| 400 | Malformed envelope, unsupported version or invalid body |
| 403 | Authentication or current permission denied; body is `AccessDenied` |
| 404 | Unknown route |
| 409 | Conditional conflict, expired query cut or reclaimed history |
| 422 | Recognized permanent protocol rejection |
| 503 | Authority/storage unavailability, uncertain time or exhausted admission/control capacity |

Bodies use `{ err: ERROR_CODE }` from the public enum. Unknown internal failures
become `AuthorityUnavailable`. The client rejects unknown/malformed error bodies
and invalid success responses instead of inventing a durable result.

HTTP bodies and client response buffers are bounded at 256 KiB. Canonical mutation
records are bounded at 8 KiB. The shared server allows 16 connections, four ordinary requests, four notification waits and two reserved
control requests, with at most 64 requests per connection. Header timeout is the
lesser of one second and the configured request timeout; it supports HTTP/1.1 keep-alive.
Network parsing and response writes may overlap, while authority/backend access
has one cancelable owner. The client does not follow redirects and defaults to
a five-second request timeout. These bounds do not promise rate fairness.

`x-transit-control: snapshot` selects reserved control admission only for
`close_snapshot` or a finishing `snapshot_read`. Other query kinds with this hint,
unknown hint values and duplicate hint headers reject. This unsigned scheduling
hint does not change authorization or prove that release succeeded.

`x-transit-wait: POSITION:MILLISECONDS` is an optional scheduling hint for
`process`, `delivery` and `outputs` queries. Both numbers use canonical unsigned
decimal; POSITION is at most the native maximum counter and MILLISECONDS is
1–1000. Duplicate headers, unsupported query kinds, future positions, command
requests and combinations with the control hint reject. The signed query and
normal response retain their existing definitions. The hint grants no rights.

When the authorized query's position equals POSITION, the node waits for a local
publication hint or the bounded timeout without holding authority/backend access.
It registers against the publication lock, so a commit between observation and
registration cannot be lost. Point sends and turns notify the affected process;
turns with outputs also notify delivery/output waiters. Grant and lifecycle
changes conservatively notify all registered scopes. This reduces unrelated
worker traffic without requiring a durable watch registry. After waking it runs the signed query again,
including current key, grant, scope, lifecycle and authority-tail checks. A
revocation can therefore return denial. Hints may be coalesced or spurious;
remote-node commits are discovered by the timeout's current read. Query selectors
with an explicit stale cut retain their normal conflict behavior.

Wait admission is separate from ordinary reads and reserved controls, bounded
to four active requests within the same 16-connection limit. Cancellation or
transport loss releases admission; a disconnected peer's undetected wait is
bounded by its timeout. No durable subscription, change coverage, replay cursor,
automatic mutation retry or execution permission is created. Callers preserve
pending signed work and use bounded read retries or polling after unavailable
waits. The local gateway forwards the validated hint through a separate bounded
upstream pool.

Signatures authenticate callers; they neither encrypt responses nor authenticate
the response transport. A listener outside a trusted private network requires an
authenticated TLS ingress boundary. Workloads cannot receive raw Ursula/provider
credentials. [Security](../docs/reference/security.md) owns deployment trust.

## Operation and recovery

[transit-node](../apps/transit-node/README.md) owns bootstrap, trusted clock
integration, request limits and separately authorized maintenance. Finite
lifetimes require an opted-in bounded-error clock; clock failure grants no
expiry or fresh execution. [Caller semantics](../docs/reference/callers.md) owns
host cancellation and recovery. [Executed proofs](../tests/README.md) distinguish
actual evidence from planned checks.

Incompatible histories, checkpoints and saved requests reject. The service does
not convert, reset or reinterpret them. Preserve the original installation and
recovery material for its matching build; initialize a new installation only as
an explicit operator action.
