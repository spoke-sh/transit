# Serving OpenAPI reference

The serving HTTP adapter exposes application commands, scoped reads and the
reactive Table API. Its [OpenAPI 3.2.1 specification](../../../packages/zig/transit-serving/api/openapi.json)
is generated from the owning Zig types. The site renders operations, response
shapes, field constraints and budgets from that exact file below.

## Connect and authenticate

Provision a service, publish a binding and grant the caller's actual operations
before connecting. Send native Ed25519 proofs in JSON bodies using the shared
client. A schema-valid JSON object is not a valid signature or a grant. Do not
replace canonical signing with a generic OpenAPI generator's JSON serialization.

Production hosts require their configured HTTPS Host/Origin. Keys, tickets and
query literals do not belong in URLs. The explicitly enabled local HTTP mode
retains exact Host/Origin checks. See [host configuration](../../../packages/zig/transit-serving-http/README.md)
and the [serving wire contract](../../../contracts/SERVING_V1.md).

## Response and stream semantics

An ingress receipt is admission, not a committed application outcome. Recover
uncertainty with the exact original signed command, then observe its disposition.
The selected reactive source is an int64 Table. SSE is a signed **POST fetch
stream**, not an unauthenticated `EventSource` GET. A session, subscription,
attachment generation and current source authority are required before data is
disclosed. The SSE `data` field contains encoded `ServerMessage` JSON.

[AsyncAPI](asyncapi.md) describes the WebSocket binding of those same durable
sessions. [Board's API](board-api.md) is a separate private inspection boundary;
this specification is not a REST facade for every native Transit operation.
