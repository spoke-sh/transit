# Serving example

An actual signed HTTP gateway, Station ingress and separate
non-trading Table counter application. The [serving contract](../../contracts/SERVING_V1.md)
owns admission, provenance and recovery. The gateway exposes command admission,
current bounded discovery/status/result reads and a health route through the
shared HTTP listener. The opt-in M20 reactive profile adds SSE/WebSocket;
[reactive usage](docs/reactive.md) records its current qualification.

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
header can establish identity. The [termination guide](docs/termination.md) owns
the real nginx template, TLS proofs and concurrency budget. The
[running guide](docs/running.md) covers owned native, Compose and Substrate
placements and exact recovery. Each admitted HTTP data request uses at most
2 MiB for parsing/upstream work, plus the listener's bounded buffers. Default
four data handlers, two per caller and two reserved health handlers are separate from the durable
service quota. The owning resource retains terminal operations with no implicit
expiry. Read diagnostics contain finite error categories, not request data.

The application stores one typed Table of `(id, count)` and records data progress
in the same turn as each update. It accepts only the configured ingress's process
origin. Payload codec 1 is an i64 row ID followed by an i64 delta, little-endian;
the exact result is the resulting i64. Socket retries never invoke the application
directly. Query/read bookkeeping cannot alter its data progress marker.

M21's optional `live_ingress` role adds `query_principal` and `source` alongside
the nested `service` configuration. It composes sessions and the v2 requester
in one resource. Application `queries: true` enables existing v2 capture and
initializer-only `UQA2` policy publication. Cross-resource read grants must be
provisioned for both workers and the query caller. PID-scoped workers also need
optional foreign-resource associations established
before first activation; associations never replace those grants. The
[refresh guide](../../packages/zig/transit-serving/docs/refresh.md) owns the bounds;
`just test::reactive-refresh` exercises the actual composition. Query execution
remains disabled by default.

Build with `nix develop --command zig build serving-example -Doptimize=ReleaseSafe`.
Run `nix develop --command just test::serving` for the independent Python/OpenSSL
caller proof with owned disk Ursula, real workers and two gateway instances. It
provisions its own keys/rights and leaves existing launcher deployments alone.
`just test::serving-lifetimes` adds real cancel/timeout ordering and finite
process/resource expiry. Clock uncertainty returns temporary unavailability until
the authority can establish expiry; it is not a fabricated terminal outcome.
`just test::serving-growth` retains 128 additional operations beyond the resident
page budget. The [compatibility matrix](../../packages/zig/transit-serving/docs/compatibility.md)
records qualification per consumer and placement. M20 adds independent TLS/Chromium and physical reactive recovery rows.

Run `just test::reactive-browser` for the minimal Chromium protocol harness,
`just test::reactive-limits` for bounded controls and expiry, or
`just test::reactive-placement compose` / `just test::reactive-placement reference`
for physical SSE/WebSocket recovery. The placement runner also accepts
`--reactive` directly. Each proof owns its temporary services and preserves the
existing reference installation. See the [reactive guide](docs/reactive.md) for
bootstrap affinity, clock bounds, recovery and unsupported profiles.

The [counter browser application](web/README.md) is embedded in the gateway binary
and enabled by `counter_view: true` with an explicitly permitted snapshot viewer.
It shares the reactive client with Board while owning its application rendering.

The separate `clock_observer` role takes `ingress`, its state `resource`, and `interval_ms` (1000–5000,
default 5000). Provision a dedicated inspect/send principal scoped to that ingress
and configured as its trusted observer, with inspect/read on that resource. It freezes one signed clock input through
unknown I/O, waits for its consumption, and samples again. Restart first drains
a finite accepted prefix captured once at restart, so later live controls cannot
starve clock progress. Pending consumption is checked every 250 ms independently
of the sampling interval. A stopped worker cannot accumulate unbounded observer work.
This example relies on the deployment's qualified host clock bound; wall samples
are recorded before the deterministic owner uses them. At a five-second interval,
an otherwise idle running observer can retain 720 clock inputs per hour plus
owner turns (and refresh wakeups after a query scheduler exists). Visible sessions additionally retain renewals/attachments;
After each consumed sample it checks the four active session slots and submits
one conditional expiry at a time; a concurrent renewal invalidates stale expiry.
This reclaims abandoned live capacity without deleting session history. Lease
bounds do not expire this history. Stop the observer with the deployment,
and select retention only through explicit application policy.
