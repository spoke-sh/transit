# Private TLS termination

The first M19 termination profile uses pinned nginx from `nix develop .#serving`,
with the Zig gateway on private loopback or the declared private deployment network. Run `just test::serving-tls` from the
project environment to exercise the actual [template](../nginx.conf.in), signed
clients, two gateway instances and disk recovery. The fixture generates a short
lived certificate/key in its owned temporary directory, verifies its trust and
hostname independently, and removes the processes/files on exit. This qualifies
the local termination configuration. The [physical examples](running.md) separately
exercise the same terminator with private Compose or reference backends.

An operator supplies the real certificate chain, a restricted private-key file,
public Host/HTTPS Origin, private backend address, and explicit caller keys. The
template's `@...@` values are trusted deployment configuration; it is not an
editable route or authorization database. Keep the backend unreachable outside
the trusted proxy/gateway boundary. Application callers authenticate through
native signatures and current grants/policies. The proxy is trusted with plaintext
requests/results, while forwarded identity headers grant no authority.

The template enables TLS 1.2/1.3, finite header/body/write/upstream deadlines,
bounded body/header buffers, no response/request buffering, no disk response
spooling, no upstream retry and no access log. The client verifies certificate
trust and hostname; the gateway separately enforces exact Host and any Origin.
Refer to nginx's [HTTPS configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
and [proxy module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) for the
underlying directives. WebSocket upgrade is not enabled by this template yet.

Default gateway limits are 16 sockets, four data handlers and two reserved health
handlers, with a 1 second header deadline and 5 second total request deadline.
After signature verification, each provisioned caller can occupy at most two
handlers per gateway (`per_caller_requests`, bounded by its data-handler limit).
Excess caller work receives 429, leaving the remaining slots for other callers.
This local transport bound is separate from the Station owner's aggregate durable
operation quotas across all gateways. Unauthenticated body/header work still has
the listener's finite socket and time limits; this is not a DDoS protection claim.
Each data handler has a separate 2 MiB fixed allocator; upstream calls have a
3 second deadline inside that total. The durable service independently limits
active operations and per-caller work. A disconnected or timed-out transport does
not cancel a Station wait or remove its retained result.

`just test::serving-capacity` adds a Linux `/proc` RSS measurement while eight
authorized reads from two callers across two gateways are held in upstream I/O.
It proves one caller's limit leaves capacity for the other. It requires the
ninth data request to receive 503 and health to finish within one second. The
declared aggregate gateway ceiling for this finite configuration is 256 MiB;
the [proof ledger](../../../tests/README.md#m19-qualification) records the
observed value. This is not an Internet flood/throughput qualification. Proxy,
authority, worker and kernel memory are outside that gateway RSS measurement.
