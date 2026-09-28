# Serving example

M19 work in progress: an actual signed HTTP gateway, Station ingress and separate
non-trading Table counter application. The [serving contract](../../contracts/SERVING_V1.md)
owns admission, provenance and recovery. The gateway exposes command admission,
current bounded discovery/status/result reads and a health route through the
shared HTTP listener. SSE/WebSocket are not enabled yet.

The executable takes a bounded JSON configuration with authority `url`, `realm`,
non-root `principal`, a private `seed_file` and a `role`. Ingress/application
workers additionally require exact `pid`, `generation` and a preserved
`activation_directory`. Restart requires fresh fenced ownership. The ingress
role contains service/administrator/observer identities; the application role
contains its trusted ingress PID and initializer principal. The gateway role
contains service/ingress/resource identities, port, exact public host/HTTPS origin,
and up to 32 explicitly provisioned caller public keys. Private seeds are files,
never command arguments. Public registration bootstrap is available only for
workers and does not acquire ownership automatically.

The HTTPS origin names the independently provisioned TLS terminator; the clear
listener must remain on its private loopback/network boundary. No forwarding
header can establish identity. The configuration is not proof of deployed TLS:
that qualification remains open. Each admitted HTTP data request uses at most
2 MiB for parsing/upstream work, plus the listener's bounded buffers. Default
four data handlers and two reserved health handlers are separate from the durable
service quota. The owning resource retains terminal operations with no implicit
expiry. Read diagnostics contain finite error categories, not request data.

The application stores one typed Table of `(id, count)` and records data progress
in the same turn as each update. It accepts only the configured ingress's process
origin. Payload codec 1 is an i64 row ID followed by an i64 delta, little-endian;
the exact result is the resulting i64. Socket retries never invoke the application
directly. Query/read bookkeeping cannot alter its data progress marker.

Build with `nix develop --command zig build serving-example -Doptimize=ReleaseSafe`.
Run `nix develop --command just test::serving` for the independent Python/OpenSSL
caller proof with owned disk Ursula, real workers and two gateway instances. It
provisions its own keys/rights and leaves existing launcher deployments alone.
No complete M19 or M20 qualification is claimed by this local example.
