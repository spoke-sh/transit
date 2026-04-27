# Hosted Consumer Contract

This document defines the canonical hosted-consumer boundary for `transit`.

It answers three narrow questions:

- how a downstream consumer identifies the authoritative hosted Transit
  endpoint
- how hosted auth posture is declared without turning Transit into a
  consumer-specific identity system
- how acknowledgement, durability, and remote error semantics are preserved
  across the hosted boundary

The contract is intentionally thin. `transit` owns transport, acknowledgement,
durability vocabulary, and generic access posture. Downstream consumers own
their own schema, policy, and application semantics.

## Endpoint Grammar

Hosted consumers target one authoritative `transit-server` network endpoint.

The current canonical endpoint shape is a socket authority:

```text
<host>:<port>
```

Examples:

- `transit.prod.example:7171`
- `10.0.2.15:7171`
- `127.0.0.1:7171` for local development only

This is not an HTTP URL contract. The current hosted protocol is Transit’s own
framed request/response application protocol over a network transport. The
consumer boundary is the server endpoint itself, not a filesystem path, object
storage bucket, or embedded engine root.

### Server Address Roles

`transit` keeps two address roles explicit:

- `listen_addr`
  The local bind address for the running daemon.
- `advertise_addr`
  The canonical consumer-facing endpoint published by operators when the bind
  address is not the correct external target.

Consumers should target the advertised authority endpoint, not infer one from a
node’s local storage layout.

### Authority Rules

- One hosted authority endpoint owns append, replay, branch, merge, lineage,
  and tail semantics for the target workload lane.
- Hosted consumers should not open embedded local Transit storage as a second
  authority for the same hosted workload.
- Object storage is part of the server’s durability model, not a direct client
  endpoint.

## Auth Posture

Hosted auth in `transit` is an access posture for the server boundary. It is
not a consumer identity or business-policy framework.

The configuration contract currently exposes three posture values:

- `none`
  No protocol-level auth requirement is declared. Suitable only for trusted
  local development or tightly-contained environments.
- `token`
  The hosted authority requires a token credential in the Transit framed
  request envelope when the server is configured with a token.
- `mtls`
  The hosted authority is expected to require mutually-authenticated transport
  credentials at the server boundary.

### Current Non-Claims

The current runtime must stay honest about what is and is not implemented.

- `auth_mode` is part of the authored server contract today.
- The shipped runtime enforces `token` in the Transit framed protocol when the
  server has a configured token.
- The shipped runtime does not yet enforce `mtls` on the wire.
- Consumers must not infer bearer-header, HTTP, or certificate-exchange
  mechanics beyond what the runtime and proofs explicitly implement.
- Operators may still use network containment, mesh policy, or front-door
  controls around the server, but those are deployment choices rather than
  proof that Transit has already implemented protocol auth.

Until mTLS enforcement lands, `auth_mode = "mtls"` should be read as declared
posture plus rollout target, not as an overclaimed security guarantee.

### Token Credential Placement

Token auth is a Transit protocol field, not an HTTP bearer-header convention.
Rust clients attach it through the hosted client builder:

```rust
let client = TransitClient::new(server_addr).with_auth_token(token);
```

CLI helpers read `TRANSIT_AUTH_TOKEN` when they construct hosted clients.

## Acknowledgement Contract

Hosted success responses are correlated and acknowledged explicitly.

At the client boundary, the canonical success shape is:

```text
RemoteAcknowledged<T> {
  request_id,
  ack { durability, topology },
  body,
}
```

This shape is owned upstream by Transit’s shared hosted client/server layer.
Downstream wrappers should preserve it literally instead of inventing a second
acknowledgement model.

### Correlation

- every successful hosted response carries a `request_id`
- the same correlation key also appears on remote error responses
- downstream wrappers may add local tracing, but they should not discard or
  rewrite the Transit `request_id`

### Durability Labels

The acknowledgement envelope exposes a literal durability label at the server
boundary:

- `memory`
- `local`
- `replicated`
- `quorum`
- `tiered`

Those labels name the durability posture actually claimed by the hosted
authority for that response. Consumers should treat them as explicit contract
data, not as values to reinterpret into product-local storage tiers or vague
"committed" states.

Current runtime and proof coverage must remain explicit:

- the shared hosted contract can name all durability labels
- a hosted server booted from tiered/object-store config still surfaces
  `local` acknowledgements until that path actually reaches the remote
  authority required for a stronger claim
- downstream repos must not claim stronger hosted guarantees than the upstream
  runtime and proofs actually demonstrate

### Topology

The acknowledgement envelope also carries a topology label.

- the current hosted runtime surfaces `single_node`
- future topology values must be published upstream before downstream repos rely
  on them

## Error Contract

Hosted failures that come back from the server use a distinct remote error
envelope:

```text
RemoteErrorResponse {
  request_id,
  topology,
  code,
  message,
}
```

The current canonical remote error codes are:

- `unauthorized`
- `invalid_request`
- `not_found`
- `internal`

Downstream wrappers should surface the remote error code and message literally.
They may layer consumer-specific handling on top, but they should not erase the
Transit code or replace it with a private acknowledgement/error taxonomy.

### Local vs Remote Failure

Hosted consumers should keep two failure categories explicit:

- remote failures returned by Transit, which include `request_id`, topology, a
  stable remote `code`, and a message
- local client failures such as transport, protocol, or decode errors before a
  valid remote envelope is obtained

That split keeps remote substrate semantics distinct from downstream wrapper or
network issues.

## Consumer Guidance

Hosted consumers should rely on Transit for:

- endpoint ownership
- request correlation via `request_id`
- acknowledgement envelopes and durability labels
- explicit remote error codes
- stream and lineage operations exposed by the hosted server surface
- upstream client surfaces such as the Rust [`transit-client`](crates/transit-client/README.md)
  crate instead of repo-local hosted wrappers

Hosted consumers should keep these concerns outside Transit:

- schema meaning
- entitlement policy
- account or identity business rules
- application-specific reducer decisions

Hosted consumers should also preserve these upstream semantics literally:

- `request_id` stays the canonical hosted correlation field
- `ack.durability` stays the canonical hosted durability claim
- `ack.topology` stays the canonical hosted topology label
- remote error `code` values stay Transit-defined instead of being renamed into
  repo-local categories

The hard-cutover proof path for deleting duplicate local runtime or private
hosted client ownership is documented in
[`DIRECT_CUTOVER.md`](DIRECT_CUTOVER.md).

## Example Hosted Contract

```toml
[server]
listen_addr = "0.0.0.0:7171"
advertise_addr = "transit.prod.example:7171"
auth_mode = "token"
# Prefer TRANSIT_AUTH_TOKEN for production secrets. For local tests only:
# auth_token = "dev-secret"
```

In that shape:

- operators bind locally on `0.0.0.0:7171`
- consumers target `transit.prod.example:7171`
- auth posture declares and enforces token credentials in the Transit framed
  protocol when a token is configured
- mTLS remains a declared posture only until the runtime implements it

## Verification Questions

When a downstream repo integrates with hosted Transit, it should be able to
answer all of these from Transit-owned docs and proofs alone:

- What exact network endpoint form should the consumer target?
- Which server address is authoritative for consumers: `listen_addr` or
  `advertise_addr`?
- Which auth posture is declared for the hosted boundary?
- Which auth guarantees are implemented today, and which are still explicit
  non-claims?
- What exact acknowledgement envelope should a hosted consumer preserve?
- What exact remote error envelope and code set should a hosted consumer
  preserve?

If those answers require downstream repos to invent new protocol meaning,
Transit has not finished publishing the contract.
