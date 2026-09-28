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
| Unified source | `{"unified_source":{"peer":REQUESTER_PID,"initializer":PRINCIPAL}}` | Existing v2 source declaration/policy and data; a non-required association and independent current read/inspect grant to the request resource |
| Empty Table source | `{"table_source":{"peer":REQUESTER_PID,"initializer":PRINCIPAL,"requests":RESOURCE,"limits":{"pages":1000,"segments":100,"result_bytes":1048576}}}` | M24 local composition initializes an empty int64 Table and its peer policy in the owning activation; defaults `table: 1`, `key_name: "id"`, `value_name: "value"`; existing metadata rejects |
| Unified requester | `{"unified_requester":{"principal":QUERY_PRINCIPAL,"source":SOURCE_PID}}` | Dedicated requester PID/resource; separate first `UQI2` cast, authenticating the configured principal |
| Finite service requester | `{"finite_service":{"service":{"service":1,"administrator":ADMIN,"observer":OBSERVER},"query_principal":CALLER,"source":SOURCE_PID,"binding_revision":1}}` | M22 opt-in composition with current M19 policy/publication, one active v1 query and the same durable result transfer; qualification in progress |
| Courier | `{"courier":{"destinations":[SOURCE_PID,REQUESTER_PID]}}` | Dedicated unscoped inspect/delivery/send principal; no execution/storage credentials |

Each OS worker owns one activation. V1 uses a bounded 1 MiB query workspace;
v2 uses a 4 MiB Arrow workspace and the source adds a 1 MiB adapter arena. The
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

The host and courier preserve their activation through transient authority
transport loss, including DNS failure and closed connections. They use the
shared client availability classification, retain exact pending mutations, and
discard only poisoned unsent proposals. Denial, invalid responses and fencing
remain terminal. Reference Flight qualification exposed the former timeout-only
retry path when a Substrate worker encountered a temporary DNS failure.

The real provisioning/proof uses a separate public-API caller and these actual
binaries (`just test::public-query`), with disk Ursula, an authority, two workers
and the scoped courier. It is not a production deployment launcher.

The separate [v2 contract](../../contracts/UNIFIED_QUERY_V2.md) and
[caller guide](../../packages/zig/transit-query/docs/unified-client.md) cover
finite uploads and result publications. V2 workers preserve frozen pending
commits and retry transient read timeouts and stale reads before preparation. Request-resource access
denial closes through the original call; source-resource failure stops the host.
Initialize associations before activation because association changes advance
the ownership generation. The optional request association permits closure after
request expiry; making it a required lifetime dependency would prevent that work.

`just test::unified-query` runs the signed KV/Table/Document recovery fixtures;
`-Dunified-source=kv`, `table` or `document` selects one case. The
[evidence ledger](../../tests/README.md#m18-qualification) distinguishes passed
profiles from work still in progress. These fixtures use owned temporary services
and leave existing launcher deployments alone.

Service diagnostics use the shared bounded stderr sink (`LOG_LEVEL`,
`LOG_FORMAT`); stdout remains unused except for the public bootstrap registration. `service.ready` reports a validated
activation and allocated workspaces, or a validated courier scope, not query
completion. `query.worker.step` counts observed worker steps: `receipt` may be a
recovered commit; idle/progress stay at debug, and unknown pending mutations are
`uncertain`. Client attempt spans share the step context. No SQL, source values,
credentials, frozen tokens or cursors enter logs. Fixed application/client metric
series reset per process and do not count unique queries. The sink's 2 KiB records,
128-slot queue, rate limits and 200 ms shutdown bound apply; sink failure never
changes retries, ownership or control progress. There is no query-host HTTP probe;
readiness is a startup observation and current progress requires durable status.

`--bootstrap-json CONFIG` is an operator-placed activation mode. It forbids a seed
file and courier role, generates a fresh in-memory key and emits only its public
registration. The external operator must validate provider identity, grant the
key its independent PID/resource rights and record the exact expected generation.
`bootstrap_timeout_ms` defaults to 120000 and is bounded at 300000. No ownership
is acquired automatically and a later generation is never adopted. Activation
markers still prevent reuse; private key bytes are cleared on exit. The
[query example](../../examples/state-query/docs/placement.md) exercises physical
placement; consult its proof ledger before relying on a particular profile.
