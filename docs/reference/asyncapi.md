# Reactive AsyncAPI reference

The [AsyncAPI 3.0 specification](../../packages/zig/transit-serving/api/asyncapi.json)
describes Transit's reactive WebSocket protocol. Channels, operations, messages
and schemas below come directly from the generated serving description.
Fetch-SSE uses the separate [OpenAPI reference](openapi.md).

## Session and connection lifecycle

1. Provision a caller and publish a service/watch binding for the selected
   int64 Table. Establish the durable session and subscription with signed
   controls under current policy.
2. Connect through the configured TLS host and exact Origin using the
   `transit.reactive.v1` WebSocket subprotocol.
3. Complete the provisioned Ed25519 challenge bootstrap in the first client
   message. No URL credentials or arbitrary browser handshake headers are used.
4. Attach with the current subscription/attachment generation and signed cursor.
   Apply invalidations and refresh an exact finite snapshot through the shared
   client; a notification is not an updated query result.
5. Renew or close through explicit controls. A disconnected socket does not
   close the durable session or cancel accepted work.

The host uses RFC 6455 over HTTP/1.1 with JSON text. Compression, binary messages
and HTTP/2 CONNECT are outside this profile. Cursors prove integrity, not
permission; every bounded disclosure rechecks current native/service/source
rights, lease and generation. A missing retained range produces explicit reset
or interruption, never a claim of continuous coverage.

See the [reactive wire contract](../../contracts/REACTIVE_V1.md),
[runnable reactive example](../../examples/serving/docs/reactive.md) and
[live-view model](../REACTIVE.md) for exact recovery and snapshot freshness.
The directions `receive` and `send` below are from the server's perspective.
