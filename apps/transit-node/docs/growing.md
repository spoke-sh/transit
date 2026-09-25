# Growing profile (M10 development)

[transit-node](../README.md) accepts an explicit `"profile": "growing_v3"`
configuration. Omitting `profile`, or choosing `"v2"`, keeps the existing protocol.
This is a partially qualified development profile. Launchers, Board, Station,
provider controllers and foreign bindings still use v2; they do not silently
negotiate or convert to v3.

## Configuration

Use a fresh bucket/journal location for v3. The expected `genesis` is the
[growing genesis](../../../packages/zig/transit-core/docs/growing.md), including
`version: 3`, `realm`, `root_key`, optional `max_clock_error_ms`, required-resource
and dependency-graph operation budgets, and `allow_history_trim` (false by default).
It is a trusted bootstrap input, not a root signing credential. Startup validates
the durable genesis fingerprint. An old history is an error, not an empty realm.

| Field | Development behavior |
| --- | --- |
| `profile` | Required literal `growing_v3` for this mode |
| `genesis` | Exact expected v3 genesis |
| `ursula_url`, `bucket`, `journal` | Private provider location |
| `listen`, `port` | IPv4 address and port; default loopback:8080 |
| `resident_pages` | Decoded page cache slots, default 16, configurable 0–1024; not retained cardinality |
| `request_timeout_ms` | Whole-request deadline, default 2000 ms, range 1–60000 |
| `accept_trace_parent` | Internal diagnostic context acceptance, default false |
| `maintenance` | Configuration for the separate `--maintain` process, below |

`--initialize` and `--bootstrap` explicitly create the authority and packed page
journals. Ordinary startup requires existing history. Both use the same
[clock and diagnostic boundary](operations.md#time-and-deadlines) as v2. Finite
views require a configured trusted clock bound even for unlimited-lifetime state.
The cache budget omits transport buffers, parsing and provider memory; consult
the [storage measurements](../../../packages/zig/transit-backend-ursula/docs/growing.md).

## Public surface and limits

The listener provides `GET /health`, `POST /v3/command` and `POST /v3/query`.
The [contract](../../../contracts/TRANSIT_V3.md) owns signed types and semantics.
Public queries require current inspection rights plus resource/PID scope where
applicable. Values remain opaque application bytes. Computation runs in the
caller; the node validates identity, ordering, state dependencies and publication.
Requests use the common bounded, cancelable HTTP loop and diagnostics.

Capabilities advertise the implemented operation budgets, named association
lookup, scoped failed-input retry, retained read versions and support for root
history reclamation. Retained versions use bounded point/page reads under current
ownership and resource grants; they do not enable an authority-side query engine.
Runtime bindings and complete Station support remain false. The
selected history policy is independently `unlimited` or `checkpointed`; supporting
maintenance does not opt an application into trimming. Clock-based operations
fence known-expired work immediately; materialized terminal metadata can lag.

No quota/control-reserve, large-result, migration, production throughput or
clustered-provider guarantee is implied. The public profile must retain these
limits until its remaining M10 gates are implemented and qualified. The node
remains sequential within a realm; additional replicas still share its one
conditional publication journal.

## Background maintenance

Run `transit-node CONFIG.json --maintain` as a separate trusted process. Its
`maintenance` configuration supplies a dedicated full-width `principal` and
`seed_file`, with `interval_ms` (default 1000) and `operation_timeout_ms` (default
5000), both 1–60000. Use a separate principal from application and administrative
request producers. Each step reauthenticates its key and requires current
realm-wide admin, effect and delivery permissions; it does not require send,
execute or mailbox inspection permission. Raw storage remains privileged.

The process rotates through processes, resources and indexed pending effects/
outputs, inspecting one record from a bounded page per step. Its disposable
cursors cap each pass at the starting identity frontier, so new admissions cannot
postpone revisiting an earlier item indefinitely. A failed item does not prevent
another family from progressing. Scans only suggest commands: ordinary signature,
grant, deadline and publication checks still decide each transition. Full sweep
latency grows with the catalogs; this is not a constant-time deadline scheduler.

Maintenance materializes known expiry, retires owned resources after dependencies
resolve, cancels never-authorized effects and outputs from terminal callers, and
closes authorized attempts at their recorded reconciliation deadlines. It does
not dispatch effects or deliver ordinary live-source outputs. Independent state,
retained values, mailbox bodies and historical receipts remain retained. An
authorized attempt with no deadline remains unresolved until explicit closure or
its observation budget is exhausted; caller retirement is not cancellation.

A public `checkpoint` requires the genesis `allow_history_trim` opt-in. The
maintenance process verifies the committed floor, publishes/rereads its root
snapshot and trims only the earlier authority journal. Optional
`checkpoint_every_records` (at least 2) requests this periodically and is rejected
at maintenance startup without that opt-in. With it unset, maintenance processes
only already recorded checkpoint intents. It never trims immutable page storage.

Clock failure blocks time-derived expiry but not recorded terminal-source
disposition or committed trim. Storage deadlines run concurrently even on one
CPU and join outstanding work before reusing engine state. An interrupted or
uncertain step is rediscovered from current durable state after restart. A revoked
maintenance principal cannot publish new transitions or start physical trimming;
already authorized cleanup may finish after revocation. Diagnostics use the
`transit-maintenance` service and bounded maintenance/storage events.

`just test::growing-service` uses an independent Zig calling program, disk Ursula
and the real node on one CPU. It writes 64 rows with bounded point/batch access,
rejects malformed replies, preserves a signed uncertain turn across caller/node/
provider restart, and checks current revocation on both reads and old receipts.
The lost-reply turn also retains its 60-row source version while committing four
more rows. After restart the caller reads both versions, replaces its activation,
rejects old-generation reads and declares/releases the retained basis in a later
turn. The separate provider proof verifies retained versions after physical
authority-prefix trim; pages remain stored.
Its maintenance scenario separately kills a worker after snapshot publication
without its reply, times out an accepted trim, revokes/regrants the maintenance
principal and restarts node/provider/worker. It verifies terminal dispositions,
retained outputs, unresolved authorized attempts and independent-state survival.
The [client guide](../../../packages/zig/transit-client/docs/growing.md) explains
the explicit development API. Existing v2 service proofs remain required after
changes to the shared listener or client transport.
