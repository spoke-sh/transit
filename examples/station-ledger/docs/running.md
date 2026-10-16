# Running the Station example

Use a separately named installation. The launcher persists the example choice;
it never converts a counter realm or creates extra state in an existing one.
After first startup, every command selects the saved example automatically.

```sh
export REY_LAUNCHER_NAME=station-demo
export REY_LAUNCHER_BASE_PORT=18400
just launchers::local::up --example station
```

Local and Compose `up` run in the foreground; Ctrl-C stops their own services
and preserves data. Use `--detach` for background operation. For the container
waypoint, replace `local` with `compose`; for Kubernetes/Substrate use `reference`.
Give concurrently running profiles different ports. Board's listener/origin and
logging use the shared [launcher settings](../../../launchers/README.md#local-development-configuration).
No workload receives operator, storage, provider or Board credentials.

## Workloads and identities

| Role | Principal | State and responsibility |
| --- | --- | --- |
| ledger | 1 | Typed total Table and immutable application KV audit; grants the requester finite query access |
| requester | 6 | Durable calls, correlations, query uploads and source-owned result references |
| coordinator | 7 | Registry scope 1, `ledger` binding, and one supervised child |
| station-observer | 10 | Reads waiting/child records and sends trusted timer/lifecycle observations |
| station-lifecycle | 11 | Reads supervisor intent and applies separately scoped ledger lifecycle operations |
| runtime-ledger/requester/coordinator | 4/8/9 | Reference only: each reconciles one PID's Substrate Actor and fresh activation |

Root provisions through exact persisted requests. Board is principal 2,
maintenance 3, and the automatic courier 5. Board receives explicit read/inspect
rights on these example resources so it can display versioned Station metadata.
Worker grants are execute/inspect/publish, scoped to their own PID; resource
grants are separate. The observer does not have lifecycle authority, and the
lifecycle controller does not have provider credentials.

The ledger and requester have stable LOGIN roles and explicitly select a shared
NOLOGIN data role. Its database CONNECT, schema USAGE and Table
SELECT/INSERT/UPDATE grants are provisioned once through saved native
authorization changes. The root owns the catalog/schema and admits Table
creation; the ledger principal registers its stable object identity. Local,
Compose and reference activation rotate credentials while retaining these
roles. Starting or replacing a worker does not restore revoked grants.

The printed `processes` mapping identifies actual durable PIDs and resource IDs;
principal numbers are not PIDs. Durable resources, rows, audit entries and retained
query results use paged storage, independently of resident cache size. Each native
turn still admits four writes and four outputs, with 256-byte values. Wide
framework records and Arrow results use bounded immutable publications. The
example's Table pages allow four-KiB records and eight simultaneously staged
records within 32 KiB. Its finite queries allow 32 source pages, eight segments
and 64 KiB of result bytes, with one active upload per requester.

Root explicitly initializes the ledger catalog and admits `prepare-table` before
queuing its initial deltas. Native installation readiness and Table publication
are separate observations; the printed example workflow waits for its initialized
total. Each delta retains its original input and correlation in a durable queue.
Table publication, the audit entry and the reply become visible together. An
advisory cancellation cannot remove accepted application work or retract a reply.

The ledger needs current read access to the requester's upload resource; the
requester needs current read access to the ledger's schema/result resource.
Launchers grant these separately from ownership and configure the corresponding
resource IDs. Root-origin query policy explicitly maps the configured peer to
the requester principal and can revoke subsequent capture and disclosure.
Both workers act as configured application services. A delta records the
ledger's data-role proof; a query records the requester's proof, source binding
and fixed query before upload. Later turns keep that exact proof. Current grant
revocation or credential rotation can deny unfinished work; the host preserves
its durable input and staging for inspection instead of signing it again.
History and results retain unlimited lifetime by default. Storage quotas do not
authorize silent eviction or expiry; a blocked handler remains inspectable.

## Messages and inspection

```sh
just launchers::local::send -2 delta-1
just launchers::local::send query query-1
just launchers::local::send lookup lookup-1
just launchers::local::inspect
just launchers::local::logs ledger
just launchers::local::logs station-observer
```

`send` delivers a Station cast to the requester. Integers become durable calls to
the ledger; `query` asks for a finite Table snapshot; `lookup` resolves the scoped
name and records that PID before sending a zero delta to it. Reuse the same
request ID and content to retry admission. A receipt proves admission, not handler
or query completion. Keep input within the example's supported syntax; malformed
input deliberately exercises the bounded failed-handler path.

In Board, follow the three PIDs, their **State** associations, and the associated
resource entries. Lenses identify the GenServer descriptor, Table schema, registry
scope/binding, child policy, waiting records, and query uploads and source-owned result publications.
Every interpretation links to its observed PID, resource, entry revision and cut.
Application row values remain opaque. Kernel history/ownership views expose
replacement generations independently of those framework declarations.

## Recovery and incremental work

```sh
just launchers::local::restart ledger
just launchers::local::build ledger
just launchers::local::update ledger --no-build
just launchers::local::down
just launchers::local::up
```

Native/Compose replacement rotates the role's worker key and records fresh
ownership. The single example executable contains all three behaviors, so an
artifact update selects and replaces all roles using that executable. Committed
rows, correlations, registry bindings and captured results remain in Transit.

Reference mode runs one Actor and versioned worker pool per role. Helm installs
the services, three runtime controllers and two framework controllers with
separate Secrets. The shared bootstrap emits one public key and pins the
controller-granted generation; private keys are never snapshot data. Worker loss
recovers the same PID/Actor using a fresh worker pod/key. `restart ledger` confirms
provider stop, recycles only that role's pool, then requests a fresh activation.
Compatible `update ledger` records each PID's template change and preserves its
resource associations. Saved update plans and exact commands resume partial work.

Supervision records one retry for a failed ledger head; it never drops that head
or spawns a replacement PID implicitly. Native/Compose placement remains a trusted
launcher action. On Substrate, logical retry can cold-boot in the old pod, which
does not meet the fresh-worker requirement: inspect the unavailable placement and
use a reviewed pool replacement, such as `restart ledger`. This example does not
add pod-deletion rights to framework/runtime controllers or promise arbitrary
provider placement will eventually succeed. See the
[runtime contract](../../../contracts/RUNTIME_SUBSTRATE_V1.md).

Checked-in [Process Compose](../process-compose.yaml) and
[Docker Compose](../docker-compose.yaml) describe this example's topology.
The [Transit chart](../../../charts/transit/README.md) owns the reference topology;
launchers supply instance values, credentials and durable provisioning.
`test-station` in each launcher task group provisions an isolated installation,
exercises registry/call/Arrow exchanges, upgrades all three workers with their
PIDs retained, verifies Board provenance and stop/start recovery, and cleans up
after success. The reference proof kills a real worker
pod. Failed runs retain their named installation and logs for inspection.
