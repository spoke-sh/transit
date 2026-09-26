# transit-station-http

The first HTTP connector, under implementation in [M15](../../../docs/roadmap/M15.md).
This package owns HTTP-specific request construction, framing and capture kinds;
[transit-exchange](../transit-exchange/README.md) owns durable capture and coverage.
The pure API does not dispatch effects. `Transport.execute` performs one finite
HTTP/1.1 exchange when called by a trusted, freshly authorized executor; it never
retries or follows a redirect. Durable worker/deployment qualification remains open.

`Request` builds HTTP/1.1 heads from typed literal/variable/secret pieces. Target
variables are percent-encoded; header fields reject control-byte injection.
Transport-owned routing/framing headers cannot be overridden. Duplicate ordinary
headers retain order. Capture renders versioned credential references; only an
explicit executor resolver produces secret-bearing wire bytes. Keep its buffers
private and discard them after the authorized attempt.

`validateResponse` rejects ambiguous content lengths/transfer coding and unsupported
compression before capture. `beginSegment` adapts HTTP record kinds to the shared
Publication commitment. A status line, successfully parsed head or sealed body
segment is not a complete response or kernel-accepted outcome.

Head buffers, header counts and template-piece counts are bounded per operation;
exchange history is paged durable state. Capture/replay retains exact non-secret
bytes at the declared application HTTP boundary, with explicit omissions for
secret-bearing fields. It is not a TLS packet capture.

Run `nix develop --command bash -c 'cd packages/zig/transit-station-http && zig build test'`.
Run `just test::http-transport` for independent HTTP/TLS peers. The first transport
profile dials a provisioned IPv4 address and authenticates the configured TLS
hostname. It does not consult ambient DNS or proxies. Response header capture is
allowlisted, always omits credential fields, and reports omissions; unsupported
compression and unframed TLS bodies fail explicitly. Request/response byte and
deadline budgets are explicit endpoint configuration. A callback seals each
bounded capture segment before its buffer is reused. Capture failure or timeout
does not prove the remote operation failed.

The final capture includes timing, omission counts and protocol coverage with
status/body counts. `Replay.open`/`read` composes current-grant reads, shared digest
verification and bounded HTTP record validation. Prefixes remain provisional until
the final `complete` part. `require_unredacted` reports `HttpReplayGap` when required
secret-bearing fields were omitted; neither replay mode can invoke transport or
credentials. See the [HTTP wire contract and fixtures](../../../contracts/STATION_HTTP_V1.md).
The [connector design](../../../docs/CONNECTORS.md) and
[exchange contract](../../../contracts/STATION_EXCHANGE_V1.md) own authority,
lifetime, unknown-outcome and replay requirements.
