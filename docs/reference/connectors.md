# Effects, HTTP and gRPC connectors

Use a connector when application work must perform external I/O. The application
records intent; a trusted worker obtains authorization for one attempt, performs
the I/O and captures its observations. Recovery reads those records. Replay must
not dial, send, resolve secrets or repeat the effect.

## Intent, attempt and outcome

An intent binds destination, operation, request content, credential references,
capture policy and finite budgets. An attempt adds dispatch identity and its
authorization. A remote outcome is established only by the evidence the connector
can record; admission of intent is not completion of the external operation.

```mermaid
flowchart LR
  Intent[Recorded intent] --> Permit[Authorized attempt]
  Permit --> IO[External I/O]
  IO --> Capture[Durable capture]
  Capture --> Outcome[Accepted outcome]
  Permit --> Unknown[Unknown if evidence is incomplete]
```

After authorization, an attempt is potentially in flight even if its worker is
paused before sending. Losing a worker, timing out, revoking its grant or closing
the local attempt cannot prove remote rollback. A retry that could execute new
external work needs explicit connector policy and new authorization. Native exact
retry of an already prepared protocol operation is a different mechanism.

## Capture and publication

HTTP and gRPC reuse the [Exchange contract](../../contracts/STATION_EXCHANGE_V1.md)
and bounded immutable publication. Requests, captured bodies/messages, observations
and terminal manifests retain stable identity and coverage. Final publication
names bytes already durably staged; an unverified prefix is not a complete body
or result. Control records survive payload disposition as required for recovery.

Record credentials as typed references, not resolved values. Captures preserve
original permitted bytes and mark secret omissions. Decoding and re-encoding a
message is not byte-exact capture. Current read rights govern transcripts and
referenced payloads; knowing their identifiers never grants access.

## Supported transports

| Connector | Implemented profile | Important limits |
| --- | --- | --- |
| HTTP | Finite request/response construction, TLS, strict framing and durable capture | Explicit destination/redirect/retry policy and byte/time budgets; no unbounded live capture promise |
| gRPC | Unary, server-streaming, client-streaming and bidirectional shapes over one frozen finite outgoing batch | Batch and half-close fixed before dispatch; responses cannot authorize later sends; identity compression only |
| Outbound Flight | Recorded selected Flight operations and typed captured Arrow interpretation over the RPC connector | Separate from an inbound Flight SQL gateway; selected types/methods only |

The finite gRPC batch may receive responses concurrently with sending, but it is
not an interactive conversation API. Recovery does not resend a sent prefix or
silently reconnect. Reflection, arbitrary dynamic schemas, compressed messages,
automatic remote-stream resumption and generic inbound application gRPC hosting
are outside that profile.

Transport libraries own HTTP/TLS/HTTP2 framing. Connector policy owns effect
authority, capture, retries and reconciliation. A higher-level service integration
may add domain idempotency/status semantics, but cannot weaken that boundary.
Socket credit and successful writes are not durable remote acknowledgements.

## Unknown outcomes and closure

Declare reconciliation duration, attempt/concurrency and retained-work budgets
before dispatch. Recovery can use captured terminal evidence or an explicitly
authorized remote status/idempotency protocol. A status lookup or remote
cancellation is itself external work; it cannot be hidden in replay.

When evidence remains incomplete, preserve unknown rather than calling it a
safe failure. Once reconciliation closes, late outcomes cannot reopen or overwrite
the closed result. Independent investigation needs new authority. Payload cleanup
cannot recycle an attempt identity or make an old response newly eligible.

Unlimited history retention does not authorize unlimited live calls or retries.
Capacity refusal is explicit. Bound buffers, capture work and each streaming
direction separately while preserving control progress.

## Build an integration

Start with the [HTTP example](../../examples/station-http/README.md) or
[gRPC example](../../examples/station-grpc/README.md). Use their owning
[HTTP package](../../packages/zig/transit-station-http/README.md),
[RPC package](../../packages/zig/transit-station-grpc/README.md) and
[outbound Flight package](../../packages/zig/transit-station-flight/README.md)
for configuration and peer compatibility. Wire formats and budgets stay in
[HTTP v1](../../contracts/STATION_HTTP_V1.md) and
[gRPC v1](../../contracts/STATION_GRPC_V1.md).

Board can show attempt, timing, coverage and terminal metadata. It does not decode
arbitrary application messages. Logs and traces are diagnostic observations,
not substitute outcome receipts. See [security](security.md) and
[observability](observability.md).
