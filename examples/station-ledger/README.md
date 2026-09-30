# Station ledger

`example-station-ledger` is a Zig Station application: a ledger, requester and
coordinator exchange durable calls, use associated Tables, and capture finite
Arrow replies. The coordinator supplies a scoped registry and bounded supervisor.
Each role is a separate Transit process and worker. This is the runnable
[M9](../../docs/roadmap/M9.md) example.

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
It also updates an audit Table atomically with the total, independently reads
the query's Arrow IPC, replaces both query hosts mid-delivery, and orders query
policy revocation ahead of publication. Root-origin `allow-query`/`deny-query`
casts configure the demo's explicit sharing policy for `destination`.

The executable accepts a JSON configuration path, or `--once <path>` to stop
after one committed turn. Configuration fields are `url`, `realm`, `principal`,
`pid`, `generation`, `seed_file`, `association` (default `data`), `role`
(`ledger`, `requester` or `coordinator`), optional `destination`, `registry`
and trusted `observer` principal.
Provisioning must establish a required association, resource permissions,
execute/inspect/publish grants, and fresh ownership before starting a worker.
Never put root credentials in this configuration.

The provider form, `--bootstrap-json '<configuration>'`, omits `seed_file` and
`generation`. It creates a fresh in-memory key, emits one public registration,
and waits for a provider-verified activation through the public client. The
runtime adapter must select the reviewed `station` container and validate its
current worker incarnation. No signing key or authority is saved in Substrate's
durable directory. The host pins one generation; replacement uses a new worker
and key. Merely cold-booting within the old pod cannot establish that activation.

The host proposes a short state-view deadline and drives the framework; the
handler receives neither a clock nor a network client. A lost submission retains
the exact proposal before any subsequent handler. The [Station package](../../packages/zig/transit-station/README.md)
owns the behavior and recovery contract. This executable is an application,
not a service required to operate Transit.
