# Hosted Consumer Contract

This document defines the canonical hosted-consumer boundary for `transit`.

It answers two narrow questions:

- how a downstream consumer identifies the authoritative hosted Transit
  endpoint
- how hosted auth posture is declared without turning Transit into a
  consumer-specific identity system

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
  The hosted authority is expected to require a token-style credential at the
  server boundary.
- `mtls`
  The hosted authority is expected to require mutually-authenticated transport
  credentials at the server boundary.

### Current Non-Claims

The current runtime must stay honest about what is and is not implemented.

- `auth_mode` is part of the authored server contract today.
- The shipped runtime does not yet enforce `token` or `mtls` on the wire.
- Consumers must not infer bearer-header, HTTP, or certificate-exchange
  mechanics beyond what the runtime and proofs explicitly implement.
- Operators may still use network containment, mesh policy, or front-door
  controls around the server, but those are deployment choices rather than
  proof that Transit has already implemented protocol auth.

Until wire-level enforcement lands, `auth_mode` should be read as declared
posture plus rollout target, not as an overclaimed security guarantee.

## Consumer Guidance

Hosted consumers should rely on Transit for:

- endpoint ownership
- request correlation via `request_id`
- acknowledgement envelopes and durability labels
- explicit remote error codes
- stream and lineage operations exposed by the hosted server surface

Hosted consumers should keep these concerns outside Transit:

- schema meaning
- entitlement policy
- account or identity business rules
- application-specific reducer decisions

## Example Hosted Contract

```toml
[server]
listen_addr = "0.0.0.0:7171"
advertise_addr = "transit.prod.example:7171"
auth_mode = "token"
```

In that shape:

- operators bind locally on `0.0.0.0:7171`
- consumers target `transit.prod.example:7171`
- auth posture declares that the hosted boundary is intended to require token
  credentials
- the implementation must still stay explicit about whether that posture is
  fully enforced or only declared

## Verification Questions

When a downstream repo integrates with hosted Transit, it should be able to
answer all of these from Transit-owned docs and proofs alone:

- What exact network endpoint form should the consumer target?
- Which server address is authoritative for consumers: `listen_addr` or
  `advertise_addr`?
- Which auth posture is declared for the hosted boundary?
- Which auth guarantees are implemented today, and which are still explicit
  non-claims?
- Where do `request_id`, acknowledgement, and error semantics come from?

If those answers require downstream repos to invent new protocol meaning,
Transit has not finished publishing the contract.
