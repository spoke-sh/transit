# Station ledger

`example-station-ledger` is a Zig Station application: a ledger, requester and
coordinator exchange durable calls, use associated Tables, and capture finite
Arrow replies. The coordinator supplies a scoped registry and bounded supervisor.
Each role is a separate Transit process and worker.

For an interactive installation with Board:

```sh
export REY_LAUNCHER_NAME=station-demo
export REY_LAUNCHER_BASE_PORT=18400
just launchers::local::up --example station
# In another terminal with the same launcher name:
just launchers::local::send -2 station-delta
just launchers::local::send query station-query
just launchers::local::restart ledger
```

Open the printed Board URL. The ledger starts at 12; the first command requests
a change through the requester PID, and the second obtains captured Arrow IPC.
Board explains framework metadata and its source records without decoding the
application's Table rows. [Running the example](docs/running.md) covers Compose,
Substrate, configuration, updates, capacity and recovery limits.

Build with `just build::debug`; run the isolated end-to-end example/proof with
`just test::station`. The proof provisions two real PIDs, associated resources,
scoped worker identities and an automatic courier against disk-backed Ursula.
It checks 7 + 5 - 2 = 10, a lost receipt, worker/store restart, stale ownership
and a poisoned input that remains inspectable after its handler is blocked.
The total is a general typed Table with an explicit INT64 primary key and
nullable INT64 amount. Immutable application KV entries record each input's delta
and resulting total. A terminal turn publishes the Table head, exact Table
outcome, audit entry, pending-work removal and original call reply together using
four native writes. Earlier staging is private; accepting a call does not claim
that its Table mutation has completed.

The proof independently reads the query's typed Arrow IPC, replaces both query
hosts after capture, and orders query policy revocation ahead of publication. Root-origin `allow-query`/`deny-query`
casts configure the demo's explicit sharing policy for `destination`.

The executable accepts a JSON configuration path, or `--once <path>` to stop
after one committed turn. Configuration fields are `url`, `realm`, `principal`,
`pid`, `generation`, `seed_file`, `association` (default `data`), `role`
(`ledger`, `requester` or `coordinator`), optional `destination`, `registry`
and trusted `observer` principal. Ledger and requester also require `authorization`:
the explicitly selected native `role` and the catalog's `profile` binding.
A requester sets `source_resource` to the
ledger's resource; a query-serving ledger sets `peer_principal` and `peer_resource` to the requester's
resource. Each PID has an optional `query-peer` association to that foreign
resource, and each worker needs a separate current native read grant. The
association neither grants access nor makes the peer a lifetime dependency.
The ledger's query policy names the configured requester principal. Each worker
signs its own application work under the selected data role; PID ownership does
not grant Table access. These are application service identities, rather than
per-user delegation. Pending deltas and query uploads retain their original
proofs across continuations; recovery cannot refresh a revoked or rotated proof.

Provisioning sends root-origin `init`, then `prepare-table`, before application
commands. Creation advances through authenticated self-messages; queued deltas
wait for its complete publication. A courier must deliver those self-messages as
well as calls and replies. Provisioning must establish a required association, resource permissions,
execute/inspect/publish grants, and fresh ownership before starting a worker.
The launcher creates stable LOGIN identities, SET-only membership in a NOLOGIN
data role, database CONNECT, schema USAGE and default SELECT/INSERT/UPDATE for
the root-created Table. The ledger principal is its explicit domain registrar.
Restart reads this binding and rotates credentials without reapplying data grants.
Never put root credentials in this configuration.

The provider form, `--bootstrap-json '<configuration>'`, omits `seed_file` and
`generation`. It creates a fresh in-memory key, emits one public registration,
and waits for a provider-verified activation through the public client. The
runtime adapter must select the reviewed `station` container and validate its
current worker incarnation. No signing key or authority is saved in Substrate's
durable directory. The host pins one generation; replacement uses a new worker
and key. Merely cold-booting within the old pod cannot establish that activation.

The host proposes a short state-view deadline and drives the framework. It
supplies bounded workspace and an authenticated public resource reader for
cross-resource query uploads/results. Table computation uses the committed turn
reader and performs no raw storage access. A lost submission retains
the exact proposal before any subsequent handler. The [Station package](../../packages/zig/transit-station/README.md)
owns the behavior and recovery contract. This executable is an application,
not a service required to operate Transit.
