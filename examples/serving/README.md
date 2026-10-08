# Serving example

An actual signed HTTP gateway, Station ingress and separate
non-trading Table counter application. The [serving contract](../../contracts/SERVING_V1.md)
owns admission, provenance and recovery. The gateway exposes command admission,
current bounded discovery/status/result reads and a health route through the
shared HTTP listener. The optional reactive profile adds SSE/WebSocket;
[reactive usage](docs/reactive.md) records its current qualification.

The executable takes a bounded JSON configuration with authority `url`, `realm`,
non-root `principal`, a private `seed_file` and a `role`. Ingress/application
workers additionally require exact `pid`, `generation` and a preserved
`activation_directory`. Restart requires fresh fenced ownership. The ingress
role contains service/administrator/observer identities; the application role
contains its trusted ingress PID, initializer principal and explicit `table_limits`
(`record_bytes`, `staging_bytes`, `staging_records`). The gateway role
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

The application owns a catalog Table named `counter` with an `INT64` primary
key `id` and nullable `INT64 count`. The initializer first sends an empty cast,
then `create-counter`; the owner completes schema publication through authenticated
self continuations. Authorized catalog lookup returning the definition is the
readiness gate before publishing the service binding. The supplied runners admit
4 KiB records and at most eight staged records totaling 32 KiB. These staging
quotas do not cap durable row or operation cardinality.

Each accepted call is saved in paged state with its original ingress and reply
correlation. The owner commits the selected row identity and computed increment
before a later turn reads immutable Table pages and stages the typed row without exposing a partial update. The final turn
publishes the Table head, exact mutation receipt, application progress and reply
together within the native four-write budget. Lost turns reuse the frozen delta.
Only the configured ingress's process origin can enqueue a counter call; only
the owner's process origin can drive its pending queue.

Payload codec 1 is an i64 row ID followed by an i64 delta, little-endian; the exact
result is the resulting i64. Overflow replies `CounterOverflow` without changing
the row or progress. Socket retries never invoke the application directly.
Query/read bookkeeping cannot alter data progress. Reactive watches observe the
Table head; a head reservation can notify possible change before row publication.

The optional `live_ingress` role adds `query_principal` and `source` alongside
the nested `service` configuration. It composes sessions and the v1 requester
in one resource. Application `queries: true` enables existing v1 capture and
initializer-only `UQA1` query policy publication. Initializer-only catalog policy
controls grant explicit inspect/read rights to each query or watch caller; the
gateway identity does not substitute for those rights. The application retains
ownership of its schema and counter writes. Cross-resource read grants must be
provisioned for both workers and the query caller. PID-scoped workers also need
optional foreign-resource associations established
before first activation; associations never replace those grants. The
[refresh guide](../../packages/zig/transit-serving/docs/refresh.md) owns the bounds;
`just test::reactive-refresh` exercises the actual composition. Query execution
remains disabled by default.

Build with `nix develop --command zig build serving-example -Doptimize=ReleaseSafe`.
Run `nix develop --command just test::serving-counter` for queue, overflow and
lost-turn checks. Run `nix develop --command just test::serving` for the independent Python/OpenSSL
caller proof with owned disk Ursula, real workers and two gateway instances. It
provisions its own keys/rights and leaves existing launcher deployments alone.
`just test::serving-lifetimes` adds real cancel/timeout ordering and finite
process/resource expiry. Clock uncertainty returns temporary unavailability until
the authority can establish expiry; it is not a fabricated terminal outcome.
`just test::serving-growth` retains 128 additional operations beyond the resident
page budget. The [compatibility matrix](../../packages/zig/transit-serving/docs/compatibility.md)
records qualification per consumer and placement, including independent
TLS/Chromium and physical reactive recovery rows.

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
Run `just test::reactive-views` for the native embedded consumers and
`just test::reactive-views-lifecycle` for actual shared-principal tabs, connection
loss, reset/resnapshot and retirement. `just test::reactive-views-placement compose`
and `just test::reactive-views-placement reference` run those consumers against
owned physical services and recover an already displayed finite result.
The [consumer placement guide](docs/views.md) describes identities and limits;
the [proof ledger](../../tests/README.md#m21-qualification)
distinguishes executed gates from work still being qualified.

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
