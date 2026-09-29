# Serving application APIs

Serving adapts inbound protocols to public Transit operations. It publishes
service bindings, preserves caller identity, admits durable commands and returns
bounded observations. It runs above Station/client authority and has no raw
storage path. Start with the [serving example](../../examples/serving/README.md).

## Services and requests

A service identity includes realm, ingress PID and service number. A binding
selects its declared contract/revision and capabilities. Reusing a number with
a different ingress does not continue the previous service's authority or history.
Replacing a gateway socket does not replace the durable service.

| Request class | Result meaning |
| --- | --- |
| Durable command | Receipt of admission, followed by the application's recorded outcome |
| Status/current read | Bounded observation under current native and service policy |
| Session or subscription control | A durable control result; socket attachment is a separate step |

An HTTP status or completed local response write is not proof of application
completion. A connection can fail after admission. Preserve the original signed
command and stable operation identity, reconcile the receipt and observe the
outcome. Changing the sequence or content creates new work.

## Authorization and disclosure

Commands preserve caller-signed native bytes. Scoped reads bind the requested
service/operation to a native identity proof and current service policy. The
gateway's configured public keys authenticate; they do not grant operation rights.
Its own read credential cannot substitute for a caller's missing permission.

Reauthorize before each bounded protected disclosure, including status and
retained receipts. Headers supplied by a client cannot create trusted provenance.
TLS and exact Host/Origin rules protect the transport boundary independently of
native authorization. Local HTTP is an explicitly selected development profile.

## Deadlines, bounds and retention

Bound request bytes, response chunks, concurrency, observation work and active
sessions. Preserve control capacity when data requests or peers stall. Joined
cancellation must finish handler ownership before buffers or tasks are released.
Once streaming headers may have started, failure is interruption, not a second
HTTP error appended to the stream.

Response deadlines and socket closure do not cancel a durable operation. Session
leases bound future live work, while accepted commands and receipts retain their
own lifetimes. A quota refusal cannot delete accepted evidence or imply expiry.

## Interfaces and compatibility

[OpenAPI](openapi.md) renders the actual generated HTTP operations and budgets.
[AsyncAPI](asyncapi.md) describes the WebSocket binding of the same reactive
session model; [reactive views](reactive.md) explains snapshots and notifications.
[Flight](flight.md) serves finite analytical queries through its own gateway.
Board has its own [private inspection API](board-api.md).

The HTTP API exposes the listed operations; generic inbound application gRPC
hosting is unsupported. Use the [serving wire contract](../../contracts/SERVING_V1.md),
[HTTP host](../../packages/zig/transit-serving-http/README.md) and
[compatibility matrix](../../packages/zig/transit-serving/docs/compatibility.md)
for exact fields, deployment configuration and tested combinations.
