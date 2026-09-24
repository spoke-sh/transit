# Station ledger

`example-station-ledger` is a Zig Station service, currently demonstrating a
ledger and requester exchanging durable calls through two associated Tables.
It captures and delivers finite Arrow queries during
[M9](../../docs/roadmap/M9.md).

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
(`ledger` or `requester`) and optional `destination` for the requester.
Provisioning must establish a required association, resource permissions,
execute/inspect/publish grants, and fresh ownership before starting a worker.
Never put root credentials in this configuration.

The host proposes a short state-view deadline and drives the framework; the
handler receives neither a clock nor a network client. A lost submission retains
the exact proposal before any subsequent handler. The [Station package](../../packages/zig/transit-station/README.md)
owns the behavior and recovery contract. This executable is an application,
not a service required to operate Transit.
