# transit-http

Bounded HTTP/1.1 request construction and single-attempt transport, shared by
browser/provider hosting and the Station HTTP connector. Its only direct package
dependency is [transit-tls](../transit-tls/README.md). It imports no Station,
Exchange, catalog, query or SDK implementation and grants no execution rights.

`Request` owns typed literal, variable and versioned secret-reference pieces.
Rendering preserves ordered duplicate application headers, percent-encodes target
variables, rejects header injection and reserves transport routing/framing fields.
Each head is limited to 8 KiB, 64 headers and 128 pieces per field. A supplied
resolver produces private wire bytes; rendering without one preserves secret
references. Dispatch rejects unresolved secrets. `Request.Diagnostic` supplies
synchronous borrowed evidence; a consumer must copy values it retains.

`Transport.execute` performs one bounded exchange against a provisioned IPv4
address, authenticating the configured TLS hostname. It does not select DNS,
proxies, redirects or retries. The caller supplies authorization, endpoint/body
budgets and an optional final `WriteGate`. The gate runs after connection/TLS and
before HTTP writes, within the same joined deadline. Denial sends no HTTP bytes.
An error after sending may leave an unknown remote outcome.

The `Capture.segment` callback receives borrowed response head/body/trailer bytes
in segments of at most 4 KiB. Response headers use an explicit allowlist and omit
credential fields. `Capture.complete`, when supplied, receives typed timing,
omission and coverage records after verified framing. Callback failure prevents a
successful result. Completion describes the response, not remote business success,
native acceptance or client consumption. Consumers must finish using each borrowed
buffer before returning. The transport joins cancellation/deadline work and erases
its private request, response, TLS and chunk buffers on every exit.

[transit-station-http](../transit-station-http/README.md) adapts those callbacks to
durably sealed capture segments and encodes the existing HTTP terminal records.
It also converts validation evidence into owned admission diagnostics. This package
does not serialize Station records or own retained history. The
[HTTP capture contract](../../../contracts/STATION_HTTP_V1.md) remains the owner
of those stored layouts and recovery guarantees.

The [HTTP listener](../transit-http-server/README.md) separately owns inbound
sockets and WebSocket framing. Removing these HTTP dependencies does not yet make
the complete serving/subscription implementation independent of Station.

Run `zig build test` in this directory inside the pinned development shell.
`just test http-transport` executes the independent HTTP/TLS peer suite against
both this package and the durable Station adapter. The
[dependency guard](../../../tests/runner/serving_dependencies.py) checks the local
transitive graph and rejects cross-package source imports; standalone compilation
and real peers supply separate evidence.
