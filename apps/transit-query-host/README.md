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
| Table mutation writer | `{"table_writer":{"resource":RESOURCE,"initializer":ADMIN,"principal":CALLER,"permissions":7,"value_type":"utf8"}}` | Existing native resource and required association; exact initializer cast creates an empty typed Table and separate mutation policy. Defaults `table: 1`, names `id`/`value`, type `int64`; permissions are explicit |
| Table query/writer | `{"table_query_writer":{"writer":{"resource":RESOURCE,"initializer":ADMIN,"principal":CALLER,"permissions":7},"peer":REQUESTER_PID,"requests":REQUEST_RESOURCE,"allow":true,"limits":{"pages":1000,"segments":100,"result_bytes":1048576}}}` | Empty typed Table; initializer is nonzero. Required writer resource association plus optional request resource association and separate read grant; two durable initialization turns before query/mutation dispatch |
| Catalog | `{"catalog":{"scope":{"realm":REALM,"resource":RESOURCE,"catalog":CATALOG_ID},"owner":PID,"administrator":ADMIN}}` | Existing resource and required association; realm/PID match the activation. Exact administrator initialization publishes framework/configuration/policy/disposition in one turn |
| Unified requester | `{"unified_requester":{"principal":QUERY_PRINCIPAL,"source":SOURCE_PID}}` | Dedicated requester PID/resource; separate first `UQI1` cast, authenticating the configured principal |
| Finite service requester | `{"finite_service":{"service":{"service":1,"administrator":ADMIN,"observer":OBSERVER},"query_principal":CALLER,"source":SOURCE_PID,"binding_revision":1}}` | Composition with current service policy/publication and one active finite query |
| Courier | `{"courier":{"destinations":[SOURCE_PID,REQUESTER_PID]}}` | Dedicated unscoped inspect/delivery/send principal; no execution/storage credentials |

The Table mutation writer uses the [shared mutation contract](../../contracts/TABLE_MUTATION_V1.md#explicit-writer-host)
and [signed Zig client](../../contracts/TABLE_MUTATION_V1.md#signed-zig-caller).
Initialize it through `TableMutationWriter.Configuration.initializeCommand()`
from the configured initializer before admitting untrusted caller input. Resource
and stored configuration must match on every activation; file edits cannot
reconfigure accepted work. Authorized `PolicyChange` casts conditionally grant or
revoke operation masks without changing native grants. Rejected inputs have
separate recorded dispositions; they do not replace terminal mutation results.
This role owns writes and does not initialize a read-query peer.

The `table_query_writer` role supplies both owners with independent policies.
The local server uses it for the default `items` Table, with INSERT, UPDATE and
DELETE explicitly authorized for its scoped caller.
Use `TableQueryWriter.Configuration.initializeCommand()` from its initializer;
deliver its self continuation through the deployment's courier. Query calls and
mutations become admissible only after `TableQueryWriter.phase(reader)` reports
`ready`. The startup log does not establish this durable readiness. The shared
mutation policy command and the combined owner's `QueryPolicyChange` revise
their respective policies independently. See the [combined contract](../../contracts/TABLE_QUERY_WRITER_V1.md)
for exact two-turn recovery and native metadata visibility.

The `catalog` role uses [transit-catalog](../../packages/zig/transit-catalog/README.md)
and its [declarative catalog contract](../../contracts/DECLARATIVE_CATALOG_V1.md).
Use the shared caller's `prepareInitialize(configuration)`, save the returned
command and explicitly submit it from the configured administrator before
allowing untrusted ingress. Initialization and
creation each fit four mutations. The signed catalog client creates compatible
empty two-column Tables and reads original operation receipts; it does not make
them query sources or grant mutation access implicitly. Shared `preparePolicy`
controls change separate create/inspect rights with a conditional revision.
Control outcomes and rejected inputs have input-bound dispositions. Exact
initialization repeats preserve revoked rights; fresh workers preserve the
immutable configuration. This role allocates no query workspace or source adapter.

Each OS worker owns one activation. Query execution uses a 4 MiB Arrow
workspace; the source adds a 1 MiB adapter arena. The
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
