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
contains its trusted ingress PID, initializer principal and a `data` binding:
current contract `definition`, catalog `scope`, `branch`, Table `audience`,
`namespace`, stable `object` and selected `role`. The gateway role
contains service/ingress/resource identities, port, exact public host/HTTPS origin,
and up to 32 explicitly provisioned caller public keys. Private seeds are files,
never command arguments. Public registration bootstrap is available only for
workers and does not acquire ownership automatically.

Idle ingress/application workers use native notification waits, bounded at one
second, followed by a current authorized receive. Temporary request failures use
backoff bounded at one second and retain the exact pending native request.
Workers and the clock observer use the shared `Client.contended` classification
for ordinary native publication contention. That retry preserves the signed request; expiry,
fencing, access denial and conflicting retry identities remain separate outcomes.
Neither waiting nor retrying changes execution ownership or acknowledges input.
The Compose/reference courier also uses a one-second idle-wait ceiling.
Their placement runner requires a private IPv4 Docker bridge gateway for its
storage fixture; it selects that gateway explicitly on dual-stack networks.

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

The installer creates a catalog Table named `counter` with an `INT64` primary
key `id` and nullable `INT64 count` through the direct catalog client. Authorized
lookup confirms its exact identity and schema before the initializer sends an
empty cast. Initialization persists the configured binding in private native
state; replacing the name or changing the binding cannot redirect pending work.
The Table service and native application share a deployment but have independent
acceptance logs. The supplied local runner preserves both under its node directory.

Each accepted call is saved in paged state with its original ingress and reply
correlation. The application reads the current row and stages an immutable intent
containing the selected row identity, computed increment and exact definition/data
expectations. Staging does not accept the write. A native turn saves that reference
and dispatch eligibility; only a later committed continuation can admit it.
The Table owner records the mutation and its receipt first. A separate native turn
records application progress and the reply. This is not an atomic transaction
across those owners. A lost reply or native proposal recovers the original receipt
without applying the increment again. A competing data change rejects the frozen
write and replies `CounterMutationRejected`; the application does not recompute it.

Only the configured ingress's process origin can enqueue a counter call; only
the application's process origin can drive its pending queue. Service command
policy authorizes the business operation. The worker separately needs current
Table write rights through its selected role. The node checks those rights, but
does not prove that the worker computed an honest increment. Queue and receipt
cardinality do not become resident work lists.

Payload codec 1 is an i64 row ID followed by an i64 delta, little-endian; the exact
result is the resulting i64. Overflow replies `CounterOverflow` without changing
the row or progress. Socket retries never invoke the application directly.
Query/read bookkeeping cannot alter data progress. Reactive watches observe the
direct Table data watermark; query bookkeeping does not advance that watermark.

The optional `live_ingress` role adds `query_principal` and `source` alongside
the nested `service` configuration. The worker also requires an
`inspection_principal` distinct from its execution principal. The operator binds
that read-only identity to the worker's current public key, with unrestricted
inspection scope, read grants on both resources and Table SELECT. This reader
can authenticate each source/requester audience; the execution credential keeps
its PID scope. Replacement rotates both identities to the fresh worker key
while preserving their existing roles and grants.
It composes sessions and the v1 requester
in one resource. Application `queries: true` enables existing v1 capture and
initializer-only `UQA1` query policy publication. Native database CONNECT,
schema USAGE and Table SELECT grants authorize each query or watch caller; the
gateway identity does not substitute for those rights. The application retains
ownership of its schema and counter writes. Cross-resource read grants must be
provisioned for both workers. A query caller using the direct infrastructure
profile also requires explicit raw-resource rights and inspection of both native
owners. Its send grant names only the requester. Mediated watch/refresh reads
use the private service reader and the caller's independent Table authority.
PID-scoped workers also need
optional foreign-resource associations established
before first activation; associations never replace those grants. The
[refresh guide](../../packages/zig/transit-serving/docs/refresh.md) owns the bounds;
`just test::reactive-refresh` exercises the actual composition. Query execution
remains disabled by default.

Build with `nix develop --command zig build serving-example -Doptimize=ReleaseSafe`.
Run `nix develop --command just test::serving-counter` for queue, overflow and
lost-turn checks. Run `nix develop --command just test::serving` for the independent Python/OpenSSL
caller proof with an owned local node directory, real workers and two gateway instances. It
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
loss, paused reload, credential rotation/recovery, reset/resnapshot and retirement.
`just test::reactive-views-placement compose`
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
