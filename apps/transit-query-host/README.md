# transit-query-host

Native growing Station query worker, separate from Board and Transit authority.
Build with `zig build transit-query-host`, then run
`zig-out/bin/transit-query-host CONFIG.json`. It uses only public client APIs.
The [public query contract](../../contracts/PUBLIC_QUERY_V1.md) owns limits and
permission boundaries; [transit-query](../../packages/zig/transit-query/README.md)
owns the reusable behaviors.

Configuration requires `url`, `realm`, non-root `principal`, `seed_file` (32-byte
hex Ed25519 seed), and a `role`. Defaults: `interval_ms: 20`,
`request_timeout_ms: 5000` (both 1–60000). Worker roles also require `pid`,
`generation`, `activation_directory`, and a required `association` (default
`state`) to their writer resource.

| Role | Configuration | Provisioning |
| --- | --- | --- |
| Source | `{"source":{"table":1,"peer":REQUESTER_PID}}` | Existing typed Table and revisioned Station peer policy; fenced source writer with inspect/execute/publish and resource access |
| Requester | `{"requester":{"principal":QUERY_PRINCIPAL,"source":SOURCE_PID}}` | Dedicated requester PID/resource and inspect/execute/publish worker; separate first `PQI1` initialization cast from the query principal |
| Courier | `{"courier":{"destinations":[SOURCE_PID,REQUESTER_PID]}}` | Dedicated unscoped inspect/delivery/send principal; no execution/storage credentials |

Each OS worker owns one activation and a bounded 1 MiB query workspace. The
courier walks eight-output public pages and preserves exact pending delivery
requests. It scans retained output history on restart; startup cost can grow
with history, while resident memory stays bounded. The destination pair is an
explicit deployment scope, not a global process catalog.

Restart requires an administrator/provider to record fresh ownership and supply
the resulting generation. The host refuses an existing activation marker, even
after a clean exit. Preserve that directory; deleting it does not grant safe
reuse of an old activation. Markers contain no credentials or result data.
Uncertain mutations remain exact while the worker runs; fresh fencing after a
crash prevents stale recomputation. There is no hidden ownership acquisition,
automatic retry of a failed handler, source-data seeding or grant provisioning.

The real provisioning/proof uses a separate public-API caller and these actual
binaries (`just test::public-query`), with disk Ursula, an authority, two workers
and the scoped courier. It is not a production deployment launcher.
