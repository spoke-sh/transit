# Experimental Transit service profile

Status: implemented for the generic bounded M1 protocol. Zig applications use
`transit-client`; the counter is the reference deployment workload. `just test::service`
owns an isolated disk Ursula, authority, and workers. It exercises signed HTTP
ingress, scoped reads, key renewal/revocation, paused-worker fencing, slow
requests, and authority/storage restart. This is not full deployment conformance.

## Implementations and operation

[transit-node](../apps/transit-node/README.md) owns server configuration,
bootstrap, background maintenance, and clock integration.
[transit-client](../packages/zig/transit-client/README.md) owns Zig caller usage
and retry lifetimes; [rey-cli](../apps/rey-cli/README.md) owns operator commands.
The [examples](../examples/README.md) are complete application callers, including
the reference counter. They are not required platform services.

## API and authorization

`POST /v2/command` accepts the typed `SignedRequest` and returns `{"position":N}`
after durable acceptance or an authorized duplicate receipt. CAS conflicts
return 409, permanent protocol rejections 422, and unavailable authority/storage
503. A transport error does not prove rejection or nonacceptance. Error bodies use the
public `ErrorCode` enum; unknown internal errors become `AuthorityUnavailable`.
The client exposes recognized rejections through `last_rejection`. Malformed or
unknown error bodies produce `InvalidAuthorityResponse`, not an invented receipt.
See the [caller guide](../docs/CLIENT.md) for retry and ownership rules.

`POST /v2/view` accepts a signed request with `sequence:0` and
`command:{"inspect":PID}`. Zero is reserved for this nonmutating surface; the
mutation engine rejects it. The response contains the process, next opaque input
and position, that PID's effect evidence, caller's own sequence, and authority
position. It exposes no other PID's data.

The node checks current keys and PID-scoped `inspect`, reads a bounded batch,
and verifies the journal tail has not changed. That last check is the read
authorization point. An intervening revocation forces 409/retry; a later
revocation prevents the next read authorization. Already authorized bytes can
finish within the request deadline. There are no public raw history, snapshot, subscription, or storage administration
routes. The additive inspection surface exposes filtered catalogs and history. Historical signatures
cannot bypass key replacement or grant revocation.

Authentication/permission failures return 403 with `AccessDenied`, without
disclosing existence. Malformed JSON returns 400. Bodies are limited to 256 KiB,
headers to an 8 KiB buffer, and connections to one request. The sequential server
bounds concurrent work and imposes a deadline including slow bodies and storage
I/O. Client calls have a five-second deadline, a 256 KiB response buffer, and no
redirect following. Rate fairness is not promised; the separate maintenance
process has its own bounded loop. Unauthenticated `GET /health` reveals only
readiness after storage refresh.

## Inspection expansion

`POST /v2/inspect` implements signed, scoped discovery, mailbox/outbox/effect and
retained-history queries. [Inspection v1](INSPECTION_V1.md) specifies its separate
signature domain, bounded scans, expired cuts, and filtered disclosure contract.
Existing command and view signatures remain compatible.

## Transport and time limits

Local proofs use loopback HTTP and a trusted host. Signatures authenticate
callers and protect commands; they do not encrypt reads or authenticate response
transport. Exposing this listener beyond a trusted private network requires an
authenticated TLS ingress/service boundary. The separate Kubernetes/Substrate
proof establishes network and credential isolation on its pinned baseline.
Raw Ursula and provider APIs must remain unreachable by workloads.

Finite lifetimes require realm opt-in to a trusted, bounded-error time source.
The node's [time integration](../apps/transit-node/README.md#time-and-deadlines)
describes Linux support and rejection on unsupported/unsynchronized sources.
The [protocol time contract](TRANSIT_V2.md#authority-time-and-bounded-settlement)
defines acceptance, uncertainty, and durable time-floor rules.
