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
| `local_directory` | Local native storage directory; select this instead of the three Ursula fields |
| `ursula_url`, `bucket`, `journal` | Private Ursula provider location when `local_directory` is absent |
| `listen`, `port` | IPv4 address and port; default loopback:8080 |
| `resident_pages` | Decoded page cache slots per execution lane, default 512, configurable 0–4096; ten lanes plus the bootstrap/maintenance context synchronize verified cache entries at lane boundaries; not retained cardinality |
| `request_timeout_ms` | Whole-request deadline, default 2000 ms, range 1–60000 |
| `storage` | Shared storage candidate/allocation limits and maintenance settings; does not select a provider |
| `request_metrics` | Optional bounded `x-transit-work` response diagnostics, default false |
| `accept_trace_parent` | Internal diagnostic context acceptance, default false |
| `maintenance` | Dedicated maintenance identity and scan budgets; runs inside the local node, or in Ursula's separate `--maintain` process |
| `table` | Optional local direct Table owner: fixed catalog/native bindings and registrar credential reference; see below |
| `sql_control` | Optional local SQL lifecycle owner: private Unix `socket` and process-wide TLS `crypto_capacity` in bytes; installed `transit server` supplies both |

`sql_control` is available on the local backend. Its socket uses the private
runtime directory and same-UID peer checks of the local SQL console. The supervisor
supplies the existing account configuration after enrollment; a complete
configuration fingerprint fences replacement. Repeating an identical start
observes the same activation. SQL shutdown joins its tasks before the node releases
shared storage owners. `crypto_capacity` defaults to zero and refuses a TLS
configuration requiring more reserved bytes; the installer sizes it from the
configured SQL limits. This lifecycle channel grants no data access. Signed local
calls still use current policy and the node's shared data/control/wait lanes.

Both providers use the same signed HTTP request handling, current-rights checks,
snapshot registry and bounded request lanes. The local provider holds an
exclusive directory lock and persists native catalog/resource state through its
[log and immutable object adapter](../../../packages/zig/transit-backend-local/README.md).
It rejects a second owner and incompatible history. `--initialize` creates a new
native authority; ordinary startup requires that authority to exist. This
selection is also the installed local launcher's default. Its Table bootstrap
and shared SQL sessions use the direct Table route in the same physical owner.

`table.catalog` is the `DirectCatalog.Configuration`: existing scope and native
database/schema/Table domain bindings, branch one, service audience, database
and initial namespace names, and its exclusive nonzero control partition.
It allocates Table partitions above that control partition; reserve that range
for this one catalog. Native authority uses partition zero. Retained catalog
configuration/history is checked before readiness; startup does not initialize
the catalog or execute its pending operations.

`table.registrar` names `principal`, `seed_file` and an optional native `role`.
The registrar must already have the native domain registration authority. The
key reference grants nothing to the original Table caller; each registration
step checks that caller again before native commitment. The signed `initialize`
operation establishes the initial catalog under current native ownership.
Configuration selects a service owner and storage placement, not application
definitions or a second permission store. Ursula nodes do not provide this
direct Table route.

`table.queue_transfers` is optional and defaults to null. With local native
`maintenance` enabled, it supplies the database identity used to compose
automatic dead-letter transfers: `principal`, `seed_file`, nullable `role`, a
nonzero 32-byte `account`, transaction `limits` and client-token `budget`.
Use a dedicated credential and account. The identity must already have database
CONNECT, source/destination schema USAGE, source Queue ownership/read and
destination Queue read/append privileges. Configuration never grants them;
the registrar and native maintenance signer are independent authorities.

Transfer `limits` must reserve exactly two participants and one statement,
with positive resident/workspace byte and savepoint ceilings within
`table.transaction_limits`. The protected owner prohibits savepoint commands.
The token budget charges at least 8 KiB plus the canonical row payload; its
account limits and normal transaction reservations also apply. A smaller byte
charge refuses a candidate before admission. The executor shares
`storage.maintenance.resident_bytes` and the unchanged maintenance deadline.
Missing clock, denied or changed destinations, storage quota and pending-work
capacity leave the source blocked. Accepted attempts remain inspectable through
their original client-token and transaction status. Only verified transaction
cleanup removes pending work; changing this identity or account cannot create
a replacement attempt for an already bound source.

`table.statement_scan_rows` defaults to 1,000,000 decoded row visits and
`table.statement_scan_bytes` to 64 MiB of canonical input bytes per typed
UPDATE/DELETE execution attempt. Both must be positive and count all passes,
including group-boundary re-reads. These deployment work quotas do not constrain
retained Table cardinality. Exceeding either records a `work_limit` rejection
without publishing a row prefix. Index staging and physical storage quotas are
separate. Captured queries and language SDK adapters still require migration.

`table.client_token_quota` defaults to 1,000,000 durable client-token bindings
per catalog and must be positive. It limits new acceptance independently of the
resident page cache. Existing bindings remain readable and retryable under
current rights at capacity; the node never expires them to admit new work.
Changing this deployment quota does not alter accepted identities. The
[token contract](../../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings)
distinguishes binding an intent from executing it.

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
[growing physical-capacity proof](../../../docs/history/qualification/verification.md#growing-physical-capacity)
qualifies a finite 96-position admission / 96-position reserve workload in an
owned ext4 fixture. A deployment must provision headroom for page/WAL amplification
and provider housekeeping; the configured record band alone cannot ensure it.

`--initialize` and `--bootstrap` explicitly create a new authority and its allocation/collection
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

With `table` configured, `POST /table/v1` accepts the
[direct Table contract](../../../contracts/DIRECT_TABLE_V1.md) through the same
listener. Point and bulk row bytes bypass native actor inputs and resource-block
frames. Catalog DDL excludes concurrent row admission; independent Table requests
share directory access and use 64 bounded lock stripes. A stripe collision can
serialize otherwise independent Tables. No per-row catalog root is published.
The service opens a bounded Table/catalog view for each request. Up to 64 Table
history hints reuse previously verified prefixes for object requests, name
lookups and automatic flushing. Every open verifies the accepted boundary and
current roots, and every disclosure checks current rights. Collisions evict only
volatile hints; cold recovery still depends on retained replay/checkpoint coverage.

Direct requests accept at most 8 MiB and buffer at most 16 MiB of response, in
addition to bounded schema/row conversion, index caches and private storage work.
Response serialization counts the encoded bytes before allocating the final
buffer. Small observations therefore do not reserve the 16 MiB maximum. This
requires two encoding passes and still allocates request-owned output; it does
not establish allocation-free reads. The current-authority fence runs after
serialization, and the buffer lives through the joined response write.

The local Table handler bounds parsing, request scratch and successful response
backing allocations: by default 128 MiB per ordinary request and 256 MiB shared
across ordinary Table requests. Parsed input, request-owned temporary arenas and
the serialized response consume that capacity. Reserved Table controls share a
separate 64 MiB ceiling. Capacity
is charged as allocated, with no idle slab reservation; scratch is released
before transmission and response bytes remain charged until the write finishes
or is cancelled. Exhaustion returns HTTP 503 with `StorageQuota` for ordinary
work or `ControlCapacity` for reserved controls. An accepted mutation can precede
that refusal: inspect its original operation instead of submitting new work.
The small error reply is allocated after scratch cleanup, outside the exhausted
budget.

Retained catalog/Table owners and their private work use separate fixed budgets:
256 MiB across ordinary owners and 64 MiB across control owners, with 128 MiB and
64 MiB per-owner limits respectively. These budgets survive request completion
and are released on workspace eviction or joined owner shutdown. They exclude
fixed owner metadata and provider I/O buffers.

Request limits exclude those workspaces, independently owned engine/provider
caches, native requests, connection buffers, worker stacks and the kernel page
cache. Table and Stream maintenance
has its separate `storage.maintenance.resident_bytes` budget and one executor;
it includes Stream workspaces retained between bounded recovery turns and does
not consume the request control reserve. The limits bound this allocation
boundary, not total node RSS or storage I/O latency.

Direct requests use the listener's ordinary request lanes. `X-Transit-Control: table` uses
reserved admission only for exact operation inspection/cancellation and pin
release; the parsed action is checked and native authorization still applies.
It does not grant ordinary execution access to the reserve. Inspection and
startup do not dispatch retained work. Explicit execution resumes it using its
original operation identity.

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
control-record cache is described in [storage](../../../docs/handbook/reference/storage.md).

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

With Ursula, run `transit-node CONFIG.json --maintain` as a separate trusted process. Its
`maintenance` configuration supplies a dedicated full-width `principal` and
`seed_file`, with `interval_ms` (default 1000) and `operation_timeout_ms` (default
5000), both 1–60000. Use a separate principal from application and administrative
request producers. Each step reauthenticates its key and requires current
realm-wide admin, effect and delivery permissions; it does not require send,
execute or mailbox inspection permission. Raw storage remains privileged.

With local storage, setting `maintenance` starts the same bounded lifecycle scan
inside the node's exclusive storage owner. It has a private engine and bounded
page cache, and shares the local owner's serialized publication boundary with
request lanes. Shutdown joins both tasks before closing storage. Local
`--maintain` rejects: a second process cannot acquire the directory while the
node owns it. Authorized accepted-floor trimming survives restart; unlimited
retention and the history-trim opt-in are unchanged. Each local native trim turn
performs at most 32 directory entries or one verified WAL frame, and removes at
most one segment. The scheduler retains its selected checkpoint target until
cleanup completes. Lifecycle scans alternate with physical work; native trim,
collection and Table work rotate through a bounded pass that skips idle classes.
A failed class advances the rotation before its next attempt. Incomplete cleanup
therefore cannot occupy every maintenance turn. Native and direct immutable-object
collection have independent durable progress and alternate bounded units. Source
allocation activity selects a new pass; marking and FIFO bookkeeping do not
retrigger it. An incomplete pass resumes before a replacement can start, and
completed graph work finishes its inventory WAL cleanup before another pass.
Each unit checks current maintenance privilege. Deletion additionally requires
complete marks, accepted storage epochs and the trusted read-lifetime grace.
Direct Table compaction changes placement without expiring old roots. Standalone
payloads have their own opted-in retirement lifecycle: local maintenance confirms
physical removal under the current native authority fence before publishing
deletion evidence. It retains the permanent creation-attempt marker. Payloads
without deletion opt-in remain retained even after process retirement.

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
Payload byte counters exclude HTTP and filesystem framing. Local direct Table
requests include immutable object bodies as well as WAL append bodies.
Counters cover this process's completed attempt, not maintenance in another
process, durable outcomes, caller persistence or response transport time.
Missing headers mean missing measurement, not zero work. Counters do not depend
on sampled logs and retain no payloads, credentials or principal labels. Encoding
failure omits diagnostics without changing the authority response. Metrics
headers are opt-in. With local storage, provider counters measure native log
and immutable page/block operations, including conflicts and storage failures.
The direct Table route also includes its borrowed catalog/Table owners' WAL and
object attempts, merged into the lane's counters on both success and failure.
`request_memory` records backing allocation, growing-resize and remap attempts,
acquired bytes, peak bytes and bytes still live immediately before writing the
response. The probe covers the handler allocator, including direct Table parsing,
request scratch and serialized output. `owner_memory` separately reports backing
allocations and live/peak bytes for the borrowed catalog/Table workspace, whose
retained pages survive the request. Direct Table requests release request scratch
before response transmission, retaining the independently owned response after
the final authority fence. The probes exclude engine caches, provider-owned
buffers, HTTP socket buffers, task stacks and maintenance. Live request bytes remain
owned until the response finishes or its cancelled handler joins; the header
is a pre-write snapshot, not a post-cleanup measurement. These counters are
observations, not admission limits or aggregate node memory accounting.
Cache hits do not count as provider reads. Local payload bytes count serialized
WAL entries and page/block envelopes; they do not count filesystem framing or
individual system calls. Trimming includes its verification reads.

Before joining borrowers for a local owner reopen, the
`storage.owner.recovery_required` event identifies one observed poisoned log as
`main_wal`, `native_inventory` or `data_inventory`. The main WAL contains both
native and direct partitions; this event does not identify an individual failed
append or establish its durable outcome. It reports a fixed category without
paths, keys or payloads. `storage.owner.reopen` separately records the start of
replacement after borrowers have joined.


## Physical storage budgets and maintenance

With local storage and a configured `table` host, the existing maintenance
executor schedules enabled point-row flushing, history archives, recovery
checkpoints, archived WAL cleanup and segment compaction. Each class has its own
catalog cursor, so rotating classes cannot repeatedly skip a Table. It uses the same shared directory lock and
Table lock stripe as public requests. It releases native authority during private
staging and rechecks current maintenance privilege, catalog-resource lifetime
and storage epochs before acceptance. Physical work does not use Station actors
or require a trusted expiry clock. Each selected Table gets one unit; failures
advance discovery and do not disable lifecycle scans.

The shared [configuration reference](../../../docs/handbook/reference/configuration.md#immutable-storage)
owns row/byte/age thresholds and the aggregate private workspace budget. Bare node
configuration defaults Table work to disabled. Its configured maintenance interval
and operation deadline also govern Table work. Enabling it requires both a Table
host and a maintenance identity; startup rejects an incomplete owner configuration.
The Ursula native profile rejects enabled Table flushing and archiving. Its
compaction setting applies to native blocks/pages. Signed `storage` observations are
read-only; explicit `flush` targets use current Table control authority and the
same direct partition. Current rows, logical changes and retained history have
separate frontiers.

The following allocation ledger and physical collection details apply to
Ursula. Local allocation accounting and retained-object limits are described in
the [local backend](../../../packages/zig/transit-backend-local/README.md).

The native configuration accepts `storage.limits.bytes` (default 8 GiB),
`storage.limits.control_bytes` (64 MiB) and `storage.limits.candidate_bytes`
(8 MiB maximum). These reserve encoded immutable segment bytes, including
unpublished candidates. Control/collection allocations have a separate reserve;
they use ordinary capacity first and fall back to that reserve only when an
allocation cannot fit. The ledger retains each allocation's actual charged budget
through collection and restart. Quota pressure does not expire accepted data.
Provider metadata, ledgers, WAL,
snapshots and filesystem headroom require separate budgets.

`storage.maintenance.collection_every_records` defaults to 1,024 allocation
records. The existing maintenance process performs bounded root traversal and
resumable physical collection. `storage.maintenance.compact` defaults to false;
when enabled it relocates current blocks/pages before collection. Unlimited
history still owns old placement. The [backend guide](../../../packages/zig/transit-backend-ursula/docs/pages.md)
defines the epoch, trusted-time grace, late-create fencing and quota contracts.
The local server exposes these same YAML settings and starts its existing
maintenance process; no additional CLI command is required.


Direct Table allocation limits can be lowered with restart settings
`storage.requests.request_bytes` (1–128 MiB, default 128 MiB),
`storage.requests.data_bytes` (1–256 MiB, default 256 MiB) and
`storage.requests.control_bytes` (1–64 MiB, default 64 MiB).
The per-request limit must fit the ordinary aggregate limit. Small budgets can
refuse otherwise valid operations; they never authorize retry under a new
identity. The signed native `storage` read and SQL `SHOW STORAGE` report the
actual request limits and current/peak charged request bytes. Their counters
include responses held by slow clients until the write is joined. They exclude
retained-owner workspaces, whose fixed budgets are independent of these settings;
optional `owner_memory` diagnostics observe that workspace allocation boundary.
These counters do not measure process RSS.

The Table host exposes `table.transaction_limits` for each begin and
`table.transaction_account_limits` for aggregate durable reservations. Per-begin
defaults are 16 MiB resident work, 1 GiB cumulative workspace staging, 100,000
participants, 100,000 statements and 1,024 savepoints. Account defaults are 128
pending transactions, 64 MiB reserved residency, 4 GiB workspace, 400,000
participants, 400,000 statements and 4,096 savepoints across login roles. These
ceilings do not replace the node's request memory budgets or physical storage
quotas. Only completed transaction cleanup releases reservations; capacity
pressure does not expire accepted work. Transaction controls take the database
publication lock, and inspect/settle retain the reserved control request path.
