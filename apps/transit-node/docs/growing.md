# Native authority configuration

[transit-node](../README.md) serves one paged native v1 definition. `profile`
defaults to `native_v1`; other values reject. Launchers, Board, Station and
runtime controllers use the same native command/query boundary.

## Configuration

The expected `genesis` is the
[growing genesis](../../../packages/zig/transit-core/docs/growing.md), including
`version: 1`, `realm`, `root_key`, optional `max_clock_error_ms`, required-resource
and dependency-graph operation budgets, and `allow_history_trim` (false by default).
It is a trusted bootstrap input, not a root signing credential. Startup validates
the durable genesis fingerprint. An old history is an error, not an empty realm.

| Field | Meaning |
| --- | --- |
| `profile` | Literal `native_v1`, also the default |
| `genesis` | Exact expected v1 genesis |
| `ursula_url`, `bucket`, `journal` | Private provider location |
| `listen`, `port` | IPv4 address and port; default loopback:8080 |
| `resident_pages` | Decoded page cache slots per execution lane, default 16, configurable 0–1024; ten lanes plus the bootstrap/maintenance context; not retained cardinality |
| `request_timeout_ms` | Whole-request deadline, default 2000 ms, range 1–60000 |
| `request_metrics` | Optional bounded `x-transit-work` response diagnostics, default false |
| `accept_trace_parent` | Internal diagnostic context acceptance, default false |
| `maintenance` | Configuration for the separate `--maintain` process, below |

Genesis may opt into `admission_ceiling` (2–65,536 journal positions) and
`control_reserve` (0–65,536 further positions; default 4,096). The ceiling is
unset by default. These are finite deployment quotas, independent of retained
row counts and the page cache. They cannot be changed by editing the expected
genesis after bootstrap, and neither restart nor checkpoint reopens admission.

At the ceiling, new obligations are refused with `AdmissionClosed`; existing
control/drain operations can use the reserve. At exhaustion all new mutations
return `ControlCapacity`. Signed capabilities expose both values and the current
position. The service returns these refusals as HTTP 503 with the exact error
code; the Zig client preserves it in `last_rejection`. Keep exact pending work
when a transport exchange is uncertain. A quota error does not establish the
outcome of an earlier attempt with a lost reply.

Station can commit a previously captured, output-free turn from the reserve,
but cannot open a new view there. Such accepted inputs stay queued; quota pressure
is not expiry or permission to skip them. `just test::growing-quota` qualifies
this with one resident page, 15 admitted inputs, one consumed input and an exact
pending view request across caller/node/provider replacement, then exhausts the
reserve through authorized control work. It also checks current revocation.

The node does not provision physical space. The separate
[growing physical-capacity proof](../../../tests/README.md#growing-physical-capacity)
qualifies a finite 96-position admission / 96-position reserve workload in an
owned ext4 fixture. A deployment must provision headroom for page/WAL amplification
and provider housekeeping; the configured record band alone cannot ensure it.

`--initialize` and `--bootstrap` explicitly create the authority and packed page
journals. Ordinary startup requires existing history. Both use the same
[clock and diagnostic boundary](operations.md#time-and-deadlines) used by the service. Finite
views require a configured trusted clock bound even for unlimited-lifetime state.
The cache budget omits transport buffers, parsing and provider memory; consult
the [storage measurements](../../../packages/zig/transit-backend-ursula/docs/growing.md).

## Public surface and limits

The listener provides `GET /health`, `POST /v1/command`, `POST /v1/query` and
`POST /v1/blocks`. Bulk reads own at most 128 KiB of decoded bytes per admitted
request, in addition to their normal metadata and transport buffers. Commands
carry the same bounded body separately from signed logical descriptors; the
authority journal does not copy it. See [block v1](../../../contracts/BLOCK_V1.md).
The [contract](../../../contracts/TRANSIT_V1.md) owns signed types and semantics.
Public queries require current inspection rights plus resource/PID scope where
applicable. Values remain opaque application bytes. Computation runs in the
caller; the node validates identity, ordering, state dependencies and publication.
Requests use the common bounded, cancelable HTTP loop and diagnostics.

The listener allows 16 sockets, four active data requests and two reserved
control requests. Health, commands and snapshot release/finish use the reserve.
`X-Transit-Control: snapshot` is an admission hint: on query routes the parsed
operation must actually be `close_snapshot` or a finishing `snapshot_read`, and
ordinary signed authorization still applies. The hint cannot grant access.
Connections permit 64 sequential exchanges, with an idle/header deadline of
the smaller of one second and `request_timeout_ms`. Body reads and response
writes belong to the admitted request. Ten execution lanes independently own
mutable engines, page stores, control-record caches and provider clients. The
shared mutex protects only lane admission, notifications and snapshot-slot
reservations; it never covers provider I/O. Independent preparation can race;
only a conditional journal append accepts a successor. These bounds do not
establish per-principal fairness or a latency guarantee.

Snapshot slots remain globally bounded at 64 and eight per principal, including
pending opens. Independent pins may read concurrently. Simultaneous operations
on one pin return `Conflict`; a cancelled or failed read releases its reservation
without publishing a renewal or successful close. Node restart invalidates all
volatile pins through the fresh startup epoch. Each disclosure still checks
current credentials, resource access and lifetime.

Request diagnostics retain `wait_ns` as zero because there is no authority-work
mutex, `work_ns` for request execution including provider I/O, and `cache_hits` /
`cache_misses` for decoded page-cache access during that work. They count one
attempt, not durable outcomes or total provider requests. The separate immutable
control-record cache is described in [storage](../../../docs/reference/storage.md).

Capabilities advertise the implemented operation budgets, named association
lookup, scoped failed-input retry, retained read versions and support for root
history reclamation. Retained versions use bounded point/page reads under current
ownership and resource grants; they do not enable an authority-side query engine.
Runtime bindings and Station support are advertised. The
selected history policy is independently `unlimited` or `checkpointed`; supporting
maintenance does not opt an application into trimming. Clock-based operations
fence known-expired work immediately; materialized terminal metadata can lag.

The service does not convert histories across incompatible definitions. Large
results use Station query publications and bounded segments. Replicas still
share one conditional publication journal per realm.

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
the native API. Changes to the shared listener or client transport require
the corresponding service and recovery proofs.

## Per-request measurement

With `request_metrics: true`, native JSON responses that acquire authority access
include an unsigned `x-transit-work` JSON header. Its nullable `failure` field
retains a compiler-defined error name for failed authorized work; access denials
omit that cause. It includes no provider message, key, payload or credential,
and never establishes a durable outcome. It contains work nanoseconds, the zero
authority-lock wait field, decoded cache hits/misses, staged pages/bytes, and provider request,
transport failure, elapsed-time, append payload byte and response byte counters.
Provider time is contained in work time; these durations must not be added.
Append payload bytes exclude HTTP/framing and non-append operation bodies.
Counters cover this process's completed attempt, not maintenance in another
process, durable outcomes, caller persistence or response transport time.
Missing headers mean missing measurement, not zero work. Counters do not depend
on sampled logs and retain no payloads, credentials or principal labels. Encoding
failure omits diagnostics without changing the authority response. Metrics are
opt-in to keep the default response and instrumentation work unchanged.
