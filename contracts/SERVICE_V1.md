# Transit native HTTP service v1

The service exposes the single current [native protocol](TRANSIT_V1.md).
`transit-client` owns canonical bytes, signatures, response validation and exact
retry. [Versioning](../docs/handbook/reference/versioning.md) defines the pre-1.0 hard
cutover policy. Clients, workers and services use matching builds.

## Routes and envelopes

| Route | Request | Success |
| --- | --- | --- |
| `POST /v1/command` | `CommandEnvelope { request, signature, blocks? }` | `Receipt { position }` |
| `POST /v1/query` | `SignedQuery { query, signature }` | `Response { version, definition, realm, position, principal_sequence, body }` |
| `POST /v1/blocks` | `SignedQuery` selecting `block_entries` or `snapshot_read` | `{ response: Response, blocks: BASE64 }` |
| `POST /v1/payload` (local owner) | `PayloadRequest { operation, proof, body }` | `PayloadResponse { definition, realm, payload, outcome, body }` |
| `GET /health` | No body or credential | `{ ready: true, profile: "native_v1" }` after authority refresh |

The [generated schema](transit-v1.schema.json) owns complete fields, defaults,
union tags and bounds. Request and query versions are 1. Mutations use a positive
principal sequence; queries have no mutation sequence. Other routes return 404.
The payload route publishes/verifies/reads standalone immutable bytes. Its
declaration, readiness and retirement transitions use `/v1/command`.

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

The optional command body concatenates the complete immutable values bound by
`turn.blocks` descriptors. Canonical padded base64 owns those bytes across parser
disposal. A fresh publication verifies the entire body before staging and binds
the successor block index to the same state/input/output acceptance decision.
Only the signed logical request enters the authority journal. An already accepted
identity can reconcile without a body; current authorization still applies.

`/v1/query` returns block metadata without acquiring bytes. `/v1/blocks` returns
a separately bounded complete body and validates current authority after private
materialization. It does not accept wait or reserved snapshot-control hints.
Missing/corrupt blocks fail without a success body. See [block v1](BLOCK_V1.md).

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

`kind: { storage: {} }` reads node storage observations under current realm-wide
`inspect` permission. PID-scoped inspection rejects. The response identifies the
backend, resolved local root (up to 4096 UTF-8 bytes), physical admission bytes
and limits, direct request allocation use/peaks and separate recovery reserve,
and the maintenance executor's settings and last bounded failure category.
Unavailable observations are null, never inferred zeroes. Paths and aggregate
statistics share this operator permission; Table metadata still requires its
own signed direct Table inspection rights. The ordinary final authority-tail
check covers this read, including repeated observations and disabled maintenance.
Counters are independent live samples, not an atomic data snapshot, a physical
free-space measurement or a whole-process RSS bound. Maintenance observations
are volatile since owner startup; durable Table targets/coverage remain in the
direct Table `storage` response. Inspection advances no work and changes no
retention or maintenance policy. Hosts without a storage observer return the
explicit `unavailable` backend.

`kind: { delivery: {} }` requires current `delivery` permission (bit 128) and
returns `{ next: OUTPUT_ID_OR_NULL }` for the first pending output in the caller's
destination scope. It reveals no payload or source catalog. Submit the selected
ID as `command: { deliver: OUTPUT_ID }`, retaining the exact signed command while
its outcome is uncertain. Current `send` permission separately determines
successful admission versus recorded denial. Destination inputs own their value
and authenticated origin independently of later output-catalog collection.

## Standalone payload bytes

The local owner serves `POST /v1/payload`; Ursula nodes return 404. An operation
has fields, in order, `kind` (`create`, `verify`, `read`), `payload` (`pid`,
`payload`) and `content` (null, or `bytes` then `sha256`). Creation requires the
exact length/digest from an accepted `declare_payload`; verify/read require
null content. `body` is canonical padded base64: the exact creation bytes, or an
empty string for verify/read. Payloads are nonempty and at most 65,536 bytes.
The envelope has the same 256 KiB HTTP body bound as native commands.

`proof` is the current [authorization subject proof](AUTHORIZATION_V1.md).
Its audience is the payload's PID. Its context is SHA-256 of the ASCII domain
`transit.native.payload.v1`, one NUL, the 32 shared-definition bytes, and the
canonical typed JSON operation. The claim binds realm, principal, credential
epoch, selected role, audience and context; its existing subject signature
authenticates that claim. Native process-scoped `publish` rights and the recorded
publisher identity authorize creation and verification. Current `inspect` rights
authorize ready-byte reads. PID restrictions and explicit role selection apply.
The local owner holds its native authority fence through the final permission,
declaration and physical-I/O checks. An accepted declaration grants no read or
write authority by itself.

`create` attempts immutable publication once behind a permanent marker. Success
returns `outcome: created`; an already recorded attempt returns
`verify_required` and performs no PUT. After any uncertain result, the caller
keeps the original declaration and uses `verify`. Verification establishes
physical durability of those original bytes and returns `verified`; missing
bytes remain unavailable. Neither operation publishes `payload_ready`.
The publisher submits that separate native command after confirmed publication
or verification. The readiness record is the publisher's attestation; reads
still validate the physical content. A `read` returns `outcome: read`, the accepted ready declaration
and its exact bytes. Other outcomes have an empty response body. Responses bind
the current definition, realm and original payload identity; clients validate
the read length and digest before disclosure.

The route never creates a native declaration, advances a principal sequence,
retires a payload or dispatches an effect. Native maintenance confirms physical
deletion under an accepted opted-in retirement intent before publishing
`payload_deleted`. Failed or uncertain deletion leaves that intent unresolved;
the permanent creation marker remains. Logical readiness/retirement and physical
I/O retain their separate acceptance boundaries.

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
records are bounded at 16 KiB. Bulk requests and responses remain inside the same
256 KiB HTTP limit; their decoded data budget is 128 KiB. The shared server allows 16 connections, four ordinary requests, four notification waits and two reserved
control requests, with at most 64 requests per connection. Header timeout is the
lesser of one second and the configured request timeout; it supports HTTP/1.1 keep-alive.
Network parsing, immutable reads and candidate preparation may overlap. Each
admitted request owns its mutable engine, caches and provider transport; a
conditional journal append serializes accepted successors. A losing candidate
returns `Conflict`; a lost acknowledgement remains uncertain. The client does not follow redirects and defaults to
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
It registers against the notification mutex and monotonic observed publication
position, so a local commit between observation and registration cannot be lost.
The mutex is not held across provider I/O. Point sends and turns notify the affected process;
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
credentials. [Security](../docs/handbook/reference/security.md) owns deployment trust.

## Operation and recovery

[transit-node](../apps/transit-node/README.md) owns bootstrap, trusted clock
integration, request limits and separately authorized maintenance. Finite
lifetimes require an opted-in bounded-error clock; clock failure grants no
expiry or fresh execution. [Caller semantics](../docs/handbook/reference/callers.md) owns
host cancellation and recovery. [Executed proofs](../tests/README.md) distinguish
actual evidence from planned checks.

Incompatible histories, checkpoints and saved requests reject. The service does
not convert, reset or reinterpret them. Preserve the original installation and
recovery material for its matching build; initialize a new installation only as
an explicit operator action.
