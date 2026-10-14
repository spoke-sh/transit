# transit-query-host

Native growing Station query worker, separate from Board and Transit authority.
Build with `zig build transit-query-host`, then run
`zig-out/bin/transit-query-host CONFIG.json`. It uses only public client APIs.
The [public query contract](../../contracts/UNIFIED_QUERY_V1.md) owns limits and
permission boundaries; [transit-query](../../packages/zig/transit-query/README.md)
owns the reusable behaviors.

Configuration requires `url`, `realm`, non-root `principal`, `seed_file` (32-byte
hex Ed25519 seed), and a `role`. Defaults: `interval_ms: 20`,
`request_timeout_ms: 5000` (both 1–60000). Worker roles also require `pid`,
`generation`, `activation_directory`, and a required `association` (default
`state`) to their writer resource.

`idle_max_interval_ms` defaults to 0 (fixed polling) and accepts 0–60000.
When greater than `interval_ms`, each idle step doubles the next delay up to
that ceiling; observed activity resets it to `interval_ms`. The courier uses
the same rule. Error recovery keeps the base retry interval and exact pending
mutations. The local server sets a 100 ms base and one-second ceiling. This
reduces idle traffic but can add up to one polling interval before newly queued
durable work is noticed; interactive reads do not wait for these workers.

| Role | Configuration | Provisioning |
| --- | --- | --- |
| Unified source | `{"unified_source":{"peer":REQUESTER_PID,"initializer":PRINCIPAL}}` | Existing v1 source declaration/policy and data; a non-required association and independent current read/inspect grant to the request resource |
| Catalog | `{"catalog":{"scope":{"realm":REALM,"resource":RESOURCE,"catalog":CATALOG_ID},"owner":PID,"administrator":ADMIN,"table_limits":{"record_bytes":2097152,"staging_bytes":4194304,"staging_records":2},"authority":{"database_domain":DB_DOMAIN,"schema_domain":SCHEMA_DOMAIN,"table_domain":TABLE_DOMAIN,"database":DATABASE_AUTHORITY,"initial_schema":1,"initial_schema_authority":SCHEMA_AUTHORITY}}}` | Existing resource and required association; realm/PID match the activation. Exact administrator initialization publishes framework/configuration/schema/disposition in one turn. Explicit limits must admit the selected row/schema sizes |
| Unified requester | `{"unified_requester":{"principal":QUERY_PRINCIPAL,"source":SOURCE_PID}}` | Dedicated requester PID/resource; separate first `UQI1` cast, authenticating the configured principal |
| Finite service requester | `{"finite_service":{"service":{"service":1,"administrator":ADMIN,"observer":OBSERVER},"query_principal":CALLER,"source":SOURCE_PID,"binding_revision":1}}` | Composition with current service policy/publication and one active finite query |
| Courier | `{"courier":{"destinations":[CATALOG_PID]}}` | One through sixteen distinct nonzero destination PIDs; dedicated unscoped inspect/delivery/send principal, with no execution/storage credentials |
| Realm courier | `{"courier":{"all_destinations":true}}` | All pending recorded outputs in the configured realm; the explicit destination list must be empty; the same native grants remain mandatory |

The `catalog` role composes `CatalogQueryOwner` with general Table lifecycle
operations. After catalog initialization, the administrator installs each
requester's `CatalogQueryOwner.PolicyChange`, mapping it to one explicit catalog
principal and finite result budgets. Query callers can select authorized Tables
in that scope without a worker per Table. Current catalog read permissions and
native grants apply independently of mutation permissions. The local server
records these initialization operations and does not reissue them on restart.
See the [catalog query owner contract](../../contracts/CATALOG_QUERY_OWNER_V1.md).

The `catalog` role uses [transit-catalog](../../packages/zig/transit-catalog/README.md)
and its [declarative catalog contract](../../contracts/DECLARATIVE_CATALOG_V1.md).
Use `TableClient.prepareControl(.{ .initialize = configuration })`, save the
returned exact command and submit it from the configured administrator before
allowing untrusted ingress. `TableBehavior` routes general typed CREATE, ALTER,
DROP and DML through one owner and resource. Each Table has a stable opaque native
authorization object and role owner. Provision database/schema/Table domains with
this worker's principal as registrar; root bootstrap may register the database
and initial schema while preserving that registrar. The worker publishes each
Table binding through staged native authorization before catalog publication,
then retries the exact admitted input. It retains candidate identity across
lost replies and replacement. Creating another Table requires no worker or
private host configuration edit. Native role/grant operations own permissions;
repeating initialization never restores revoked rights.

`TableClient` compiles schema-bound SQL intent, uploads larger commands, observes
original input dispositions and reads retained outcomes. Staged work emits
recorded self continuations; configure a courier for this catalog PID. Each
publication uses at most four native mutations. `TableQuery` performs authorized
SQL reads on leased snapshots independently of this worker. The catalog role also allocates the bounded query workspace and source adapter
for durable finite requests. Fresh activations
preserve the immutable configuration and accepted work. The catalog metadata
guide lists the exact [general Table contracts](../../packages/zig/transit-catalog/docs/table-metadata.md).

Each OS worker owns one activation. Query execution uses a 4 MiB Arrow
workspace; the source adds a 1 MiB adapter arena. The
courier walks eight-output public pages and preserves exact pending delivery
requests. It scans retained output history on restart; startup cost can grow
with history, while resident memory stays bounded. Delivery selects either an
explicit destination list or `all_destinations: true`; an empty scope or both
selectors rejects. Realm selection needs no resident process catalog and does
not grant execution, resource access or permission to invent outputs.

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
remain terminal. Initial ownership reads also retry transient transport failures,
with retry admission bounded by `request_timeout_ms`; an attempt already in flight
can take one further request timeout. The host creates its activation marker and
reports readiness only after current ownership succeeds.
Reference Flight qualification exposed the former timeout-only
retry path when a Substrate worker encountered a temporary DNS failure.

The real provisioning/proof uses a separate public-API caller and these actual
binaries (`just test::public-query`), with disk Ursula, an authority, two workers
and the scoped courier. It is not a production deployment launcher.

The [v1 contract](../../contracts/UNIFIED_QUERY_V1.md) and
[caller guide](../../packages/zig/transit-query/docs/unified-client.md) cover
finite uploads and result publications. Workers preserve frozen pending
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

Idle process loops combine bounded notification waits with their next receive.
Couriers wait before re-observing their current output page. The adaptive idle interval bounds each wait, capped at one
second. Native publication wakes local waiters; timeout refresh covers other
nodes and lost hints. Unavailable reads retain the configured polling fallback.
Pending exact commands are reconciled before entering the idle path. A wake
never runs a handler or bypasses activation, view or commit checks.
