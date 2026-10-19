# Storage, placement and observation

This account explains why durable authority, physical execution and telemetry
remain separate, while accounting for the resource costs of that separation.
The [storage](../reference/storage.md), [deployment](../reference/deployment.md)
and [observability](../reference/observability.md) references own configuration
and operational behavior.

## Persistence model

The backend supplies conditional durability through Ursula. Transit owns logical
identities, accepted transitions, retained boundaries and retirement. Recovery
uses validated history/checkpoints; indexes and resident caches accelerate access
without becoming an independent source of permission or execution rights.

Immutable catalog/resource roots permit bounded page reads at a stable basis.
The current realm journal remains a serialization point. Separating durable
cardinality from cache size therefore does not establish horizontal authority
throughput. It answers a memory-growth question, not every scaling question.

## Resource costs and failure

| Mechanism | Benefit | Cost or obligation |
| --- | --- | --- |
| Immutable pages and roots | Attributable read bases and conditional publication | Page lookup, copying/staging and dependency-aware cleanup |
| Bounded caches | Resident work independent of total retained data | Misses and explicit admission/read budgets |
| Checkpoint before trim | Recovery after old history is reclaimed | Checkpoint validation and retention of all required evidence |
| Admission/control reserve | Capacity for specified control work under pressure | Explicit quotas; no guarantee that all application backlog can drain |

Cache eviction must not delete accepted work. Failed staging may leave orphaned
bytes, but only final authority acceptance may publish a new logical root.
Storage unavailability does not establish empty state, expiry or rejection of
an uncertain mutation. Reinitializing on a failed read would silently replace
the authority being recovered.

Actual latency and memory conclusions need measurements. The
[performance reference](../reference/performance.md) records workloads and
read/write amplification; a configured cache budget is not an observed RSS
bound, and retained storage bytes are not resident memory.

## Concurrent immutable work and conditional publication

The question is whether one slow storage operation must block unrelated reads
and controls. The model retains one conditional realm journal, immutable pages,
bounded admitted requests and a trusted clock for expiring read pins. It assumes
the provider implements atomic conditional append and does not roll back
acknowledged history. Parallel preparation does not create another authority.

The [native host](../../apps/transit-node/Native.zig) assigns each admitted
request an exclusively owned execution lane: engine head, verified caches,
transport client, working buffers and observation counters. Provider I/O runs
without the host's shared registry mutex. Preparation validates at a published
basis and stages a private successor. Core's conditional append requires that
same position. Therefore any intervening grant, owner, resource or sequence
change prevents acceptance of that candidate. Rejected candidates can leave
unpublished bytes; parallelism does not itself reclaim them. Unknown append
outcomes retain the original signed request identity.

[Snapshot reservations](../../packages/zig/transit-core/src/SnapshotLeases.zig)
solve a separate problem: independent engines cannot independently allocate all
64 global pins. Under a short host mutex, an authenticated request reserves one
slot and a unique ticket. Pending opens count toward both global and per-principal
quotas. The engine borrows that slot while it materializes data and rechecks
current authority. Only success installs a renewal/open/close; cancellation or
failure releases the reservation while preserving the preceding pin. Conflicting
operations on one pin fail explicitly. Stale releases cannot overwrite a newer
reservation, and a fresh startup epoch prevents reuse after node restart.

The [disk barrier proof](../../tests/node_concurrency.py) holds a provider
response while requiring an independent signed read and commit to complete
before release. A second schedule holds old evidence across revocation; a third
races identical signed writes and checks exact receipt reconciliation. Run
`just test::node-concurrency` in the pinned development shell. Core schedules
exercise global/per-principal pending quotas, failed renewals, stale release and
shared pins across independently owned engines. The proof ledger records runs.
These finite schedules establish overlap and the checked authority outcomes,
not throughput, fairness or a latency guarantee.

The previous single-engine mutex made ownership simple but coupled unrelated
provider delays. Per-request creation would discard useful caches after every
operation. Bounded reusable lanes avoid both costs, at the expense of a cache
budget per lane and potentially conflicting prepared candidates. The
[node configuration](../../apps/transit-node/docs/growing.md) gives those bounds.
Horizontal write partitioning and storage reclamation require separate contracts.

## Reducing durable mutation work

The question is which work a short Table mutation can share or avoid while
preserving admission, a frozen execution basis, and atomic rows/outcome/input
progress. The model here is one serialized realm authority, immutable retained
pages, authorized external workers and conditional durable publication. Provider
errors can leave staged or accepted bytes without a receipt. Notifications and
telemetry are volatile; neither establishes the mutation outcome.

The implementation combines three independent mechanisms:

- The [shared mutation caller](../../packages/zig/transit-catalog/src/TableClient.zig)
  prepares compatible metadata in one authorized batch and observes processed
  input with disposition/status evidence. The console keeps the acknowledged
  input until a next-request or terminal checkpoint atomically replaces it.
  A crash between observation and checkpoint therefore leaves an exact recovery
  basis; it does not require a new SQL operation.
  After a pending observation it can wait for a process notification for at most
  50 ms. The remembered position is bound to the exact signed input. Wait-capacity
  refusal backs off and makes an ordinary authorized read; denial and uncertain
  transport errors do not become permission or a repeated mutation.
- The [catalog candidate](../../packages/zig/transit-core/src/catalog.zig)
  overlays a command-bounded set of changed records, including receipts/control
  state. Repeated keys collapse before one tree rewrite. Reads see pending
  changes; scans reject an unflushed overlay. Immutable staging can leave
  unreachable pages on failure, but only the final conditional append changes
  the published root. The private bound follows command quotas, never retained
  resource cardinality.
- [Worker notifications](../../apps/transit-node/Notifications.zig) register under
  the same short mutex used to publish local commit hints, then release it while waiting.
  Publication scopes reduce unrelated wakeups. Every wake or bounded timeout
  repeats current authorization and authority reads. Cancellation releases the
  slot; a different node's publication is found on timeout. Coalescing is safe
  for this scheduling hint because the subsequent read establishes state. It
  cannot supply complete change coverage for joins or maintained derivations.

The [tree builder](../../packages/zig/transit-core/src/pages.zig) also collects
independent leaf rewrites under one parent into batches of at most eight pages.
Previously each affected leaf was staged before visiting its sibling, even when
their writes had no dependency. Only the parent needs those persisted locators.
The buffer lives at the leaf frontier, so its page count does not multiply with
recursive height or the command's larger private metadata budget. A failed or
partial acknowledgement returns no candidate root; already accepted pages can
remain unreachable. The [fault tests](../../packages/zig/transit-core/src/pages_test.zig)
exercise real opaque locators and lose each leaf/parent acknowledgement while
checking all values at the retained root.

The [compact page codec](../../packages/zig/transit-core/src/PageCodec.zig) uses
8-entry leaves and 32-child branches. The
[backend mapping](../../packages/zig/transit-backend-ursula/docs/pages.md)
wraps those bytes in canonical base64 JSON records for pinned Ursula record
coordinates. Binary encoding removes generic JSON page parsing and shallow
branches reduce path copies. The cost is a larger decoded page/cache slot and
base64 framing. These are separate from compute vector widths, Arrow batches
and application publication segments; the native mutation quota is unchanged.
A current-definition cutover prevents old stored pages from being reinterpreted.

The [layout experiment](../../tests/mutation_latency/results/2026-10-04/page-layout.json)
counts actual operations in the production tree with an in-memory measurement
store, 50 synthetic turns, retained roots, 64/1,024 rows and matching receipt
populations. At 1,024 rows, compact 8/32 monolithic roots used 782 reads and 468
stages versus 1,790 and 1,391 for JSON 4/5 roots. Raw encoded bytes decreased
from 1,403,546 to 613,884; these counts exclude the provider envelope. Decoded
page size increases from 8,480 to 16,952 bytes. The
[proof ledger](../../tests/README.md#durable-table-mutation-latency) separately
records native disk restart, acknowledgement faults, cold-tier persistence,
latency controls and incomplete runs. The experiment alone proves no latency or
provider-memory bound. The [proof ledger](../../tests/README.md#durable-table-mutation-latency)
owns the reproducible command and its pinned development environment.

The native instrumented idle control completes 21 cases. Its first INSERT stages
20 pages and makes 22 provider POSTs, versus 61/59 in the matched frozen idle
control; both include background work. Across the retained successful native
attempts, median send/view-open/turn work is 43.01/36.86/76.79 ms and provider I/O
is 39.43/34.29/70.54 ms. Median lock wait rounds to zero in that idle control.
These are overlapping phase measurements under proxies, not isolated disk-fsync
costs or sums that predict the ordinary console latency. They favor reducing
provider work before introducing concurrent authority execution. The
[raw campaign](../../tests/mutation_latency/results/2026-10-04/README.md)
records the matched controls and failed attempts.

An unproxied 280-case control with 120 retained rows samples slow requests
separately. One request spends 1,891 of 1,900 ms in provider I/O across 86 attempts;
another read waits 1,879 ms before doing 4 ms of work. The
[bounded slow samples](../../tests/mutation_latency/results/2026-10-04/slow-diagnostic-events.json)
retain 64 of 77 events meeting a 500 ms wait/work threshold or reporting failure.
They establish that long provider work can occupy serialized access and delay
other requests. The threshold sample is not an all-request distribution, and
that control does not reproduce the authority-timeout restarts observed in other
loaded runs. Short idle lock waits therefore do not establish negligible
queueing under load. Moving preparation out of serialized access remains subject
to the publication contracts below.

### Cold-flush budget starvation

The unproxied mutation campaign also asks whether reducing foreground latency
exposes provider backpressure. A diagnostic build observes Ursula
`ColdBackpressure`; bounded provider samples show the hot backlog approaching
its 8 MiB admission limit with no cold-write errors. This distinguishes that
failure from a gateway socket close. Proxies slow the workload and can conceal
the pressure, so their completed runs cannot resolve the unproxied failure.

In the pinned provider's flush planner, let the batch target be `B`, the first
stream's eligible bytes `a` with `0 < a < B`, and the next stream's backlog at
least `B`. Planning the next chunk at size `B` then rejecting `a + B > B` leaves
`B - a` unused. If the first stream receives more bytes between every pass, the
second stream can remain unflushed until admission fails. The
[provider patch](../../nix/ursula-cold-flush.patch) caps subsequent candidates at
the remaining batch budget. It preserves immutable chunk publication, the
existing first-candidate policy and the hot-memory limit. A repeated two-stream
regression checks progress, exact offsets, bounded aggregate bytes and the
separation between planning and publication. This corrects avoidable starvation;
it does not promise admission when incoming bytes exceed durable drain capacity.

The local Nix package owns this correction. Official pinned container images
remain a separate provider profile. The [campaign evidence](../../tests/mutation_latency/results/2026-10-04/README.md)
records diagnostic-only build patches and failed runs; a provider category never
authorizes a fresh retry of an uncertain Transit command.

Corrected-provider controls complete 700-case default and fixed-poll workloads
without uncertain writes. A separate combined direct-client/history/reader
repeat completes 700 cases and 5,729 reads without a restart. Other completed
controls still observe authority-timeout restarts, and the first combined
control loses its reader. The correction addresses the diagnosed flush-budget
starvation; it does not establish bounded queueing or uninterrupted availability.

### Alternatives and contract boundaries

Separate data/control roots used 938 reads and 550 stages in the same 8/32
experiment, more than the monolithic candidate. That result rejects root
partitioning as this workload's point-write optimization. Independent schema
and branch lifetimes can still justify resource roots; global permissions,
process ownership and effect histories must keep their own authority. A broader
scan/branch workload could change the storage choice.

Small writes still require send, durable view capture and a turn commit. Removing
view capture would change recovery and source-basis validation, not merely
remove a redundant request. An ephemeral execution lease would need a defined
commit witness, fencing, revocation, resource retention and crash reconstruction
contract. No such bypass is enabled. Derived query maintenance remains outside
this synchronous mutation path.

Moving immutable preparation outside serialized engine access would require a
frozen validated basis and owned storage clients/buffers. Before publication the
operation must recheck grants, ownership, expected versions, receipts and the
conditional predecessor. Conflict handling must preserve the original request
identity and bound both discarded candidates and queued work. These obligations
remain even though the candidate's pages are immutable. The current shared
engine/client ownership therefore remains serialized.

Group commit could amortize provider flushes across independent operations, but
adds queueing to an isolated write and changes per-command acknowledgement and
failure behavior. It is not enabled by page batching. A throughput experiment
must distinguish offered load, admission, queue residence, individual receipts
and uncertain batch outcomes. The current evidence does not establish a safe
single-write improvement from group commit or horizontal authority execution.

The [completion campaign](../../tests/mutation_latency/results/2026-10-05/README.md)
separates these costs empirically. Bounded caller waits and leaf-frontier batches
reduce console INSERT/UPDATE/DELETE medians from 142/153/138 ms to 113/130/112 ms
in fresh 140-case controls. Separate instrumented controls reduce median provider
requests for admission/view/turn from 16/11/29 to 14/8/22. The post-turn-receipt
observation tail is about 5 ms, followed by about 9 ms for outcome acquisition and
caller completion. Proxies affect these times; receipts do not timestamp fsync.
This favors further measured storage work over treating caller polling as the
whole remaining cost. It does not justify dropping the durable view contract.

The finite overload control offers 48 independently scheduled native sends at
1 ms intervals with four generator workers: four are admitted and 44 receive
explicit pre-admission capacity refusal. At 50 ms intervals all 48 are admitted.
Both controls verify exact accepted receipts and resulting rows after restart;
refused sends are not retried. The first control also refuses the control command,
which succeeds after the burst. These observations expose admission contention
and distinguish refusal from lost accepted work. They are short experiments on
one serialized authority, with qualification running concurrently, not a
sustainable SQL throughput or control-latency guarantee. Any concurrent
preparation or group-commit implementation must preserve those distinctions.

## Placement and recovery

A provider binding maps a logical PID to physical execution. Provider readiness,
pod creation and a restored worker snapshot cannot confer current ownership.
A replacement worker must recover against current authority and acquire eligible
ownership. Station supervision records logical intent; runtime reconciliation
performs physical lifecycle operations.

An old backup can omit revocation, retirement or a remotely completed effect.
Treating it as an ordinary current restart would invalidate the authority model.
Automatic live recovery from rolled-back history is outside the supported
deployment boundary. SIGKILL recovery against current disk state supplies no
proof of arbitrary corruption or host power-loss behavior.

### Checking state across manual worker handoff

The question is how a trusted manager can replace an unbound worker while
detecting changed recovery state and excluding the old credential. The
[handoff contract](../../contracts/WORKER_HANDOFF_V1.md) selects one native
authority, one writer-owned application resource, no outstanding finite turn
permit and a durably serialized manager. The manager's private phase record is
recovery evidence; it cannot grant execution. Provider-bound processes and
rollback of authority history are excluded from this model.

Let the original generation be `g`. Native suspension removes ownership at
`g+1`, allowing a complete resource scan while ordinary worker writes are fenced.
The checkpoint binds every ordered key/value and its revision, plus native
execution progress. Conditional resume requires `g+1` and establishes an unowned
ready process at `g+2`. If another manager intervenes, a different generation
rejects this transition. A second complete scan must equal the checkpoint before
credential rotation requires `g+2` and activates at `g+3`. Changed resources or
process progress fail restoration; a competing owner after the scan fails the
activation generation condition. The
[client state machine](../../packages/zig/transit-client/src/WorkerHandoff.zig)
implements these checks outside the kernel.

The native mailbox can admit inputs while the writer is stopped. Requiring exact
equality of its earlier admitted count would unnecessarily block recovery;
rolling it back would lose accepted work. The checkpoint therefore requires
unchanged consumed/cancelled progress and a nondecreasing admitted count. Native
history keeps output destinations and delivery outcomes. The application
resource retains operator roots, exchange deduplication and pending notices.
Restoration reads that current authority state and never writes an earlier copy
over it. Current dependencies remain separate: the manager checks them for
restore, and subsequent turns and reads still enforce current grants. A saved
checkpoint is neither a permission cache nor proof against later revocation.

Changing only a generation excludes a stale session but leaves its credential
valid. This protocol additionally rotates to a distinct key. Authentication
precedes duplicate receipt lookup, so known old-key proposals must be settled
first; the replacement recovers unknown accepted work from authority rather than
re-signing an invented retry. Manager control requests use their original root
signature through lost receipts. The manager retains each exact pending request
until the successor phase record is durable. Missing manager history blocks
recovery instead of authorizing fresh initialization.

Two whole-resource scans cost linear reads in retained entries with constant
resident memory. They favor a simple auditable manual transfer over a faster
native immutable-root attestation, which this public profile does not expose.
Copying a provider snapshot would also require historical permission and
rollback checks and is not an alternative source of authority. Liveness requires
available storage/grants and completion before native lifetime gates; the finite
suspension deadline is not renewed by a failed scan. The pinned client package
tests, independent Python handoff fixtures and native exchange task reproduce
the selected checks. The [proof ledger](../../tests/README.md#relational-exchange-faults-and-checkpoint-growth)
records their exact commands and artifacts, separating executed cases,
resource sizes, lost receipts and remaining fault boundaries.

## Observation without authority

Logs and traces describe attempts and observations. Durable receipts establish
accepted outcomes. A retry may add a transport event without adding accepted
work; missing metrics are not zero. Readiness, liveness and application progress
must be interpreted separately.

Keeping bounded telemetry outside deterministic core prevents a slow or failed
sink from altering protocol decisions. The tradeoff is lossy diagnostic evidence;
operators must consult authorized durable state for exact execution facts.

## Evidence and limits

The [backend mapping](../../packages/zig/transit-backend-ursula/docs/storage.md),
[runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md) and
[controller](../../apps/transit-runtime-controller/README.md) identify implementation
owners. [Capacity/deletion](../../tests/README.md#capacity-and-deletion-evidence),
[service/reference](../../tests/README.md#service-and-reference-evidence) and
[instrumentation evidence](../../tests/README.md#service-instrumentation-qualification)
record reproducible schedules and limits. Local, Compose and Kubernetes/Substrate
results cannot be substituted for one another's isolation guarantees.

Earlier rationale remains in the [Ursula](../history/URSULA.md),
[deployment](../history/DEPLOYMENT.md) and [observability](../history/OBSERVABILITY.md)
records. They supply historical context, not additional provider guarantees.

## Configuration generations and installation identity

This section describes the local configuration-v1 mechanism introduced on
2026-10-16. Its question is how a file-driven server can change operational
settings without treating mutable configuration as either installation identity
or authorization. The [configuration reference](../reference/configuration.md)
and [exact contract](../../contracts/CONFIGURATION_V1.md) own supported usage.
The source basis is the linked implementations in this revision, rather than
an older milestone's whole-configuration identity model.

Let I be immutable installation inputs and executable compatibility identities,
C the last accepted complete candidate, A the active values, g its generation,
and r the ordinal of the last reload outcome. Startup validates the selected
file and environment, checks I against the installation record, then establishes
A=C before services become ready. The local owner stores one bounded checkpoint;
history cardinality grows on disk independently of resident memory.
Installation completion is recorded only after the first checkpoint is durable.
A completed installation checks the retained checkpoint before starting child
processes and requires it again at publication. Missing completion evidence or
checkpoint data therefore fails closed; restart cannot reset g or r and
reinterpret an old operation identity as new. A crash before the completion
record is saved can resume first bootstrap because no gateway has served it.

Reload reads the pinned filename with captured startup overrides. It rejects
invalid candidates and changes to initialization-only fields. For a valid
candidate, live gateway policy and new-session defaults replace their active
values together. Restart-required values remain in C while A retains the prior
values. A normal server restart validates and applies them. The model has one
live application owner: it does not claim atomic rollout across independent
processes. Other components explicitly report pending restart.

The safety argument depends on three separate boundaries:

1. The native authority evaluates the original caller's signed, action-bound
   domain requirement. The configuration service has no administrator signing
   key. It checks current rights before preparation, immediately before accepted
   publication, and before disclosure. The accepted configuration never supplies
   grants. Permission changes remain ordered by the independent native authority;
   a successful check admits the subsequent bounded publication, rather than
   claiming a distributed transaction with revocation.
2. The owner serializes operations, checks the expected generation, prepares the
   complete bounded candidate, and atomically replaces/fsyncs the checkpoint.
   That checkpoint contains both active/configured values and the pending exact
   operation outcome. A lost acknowledgement therefore leaves either the prior
   checkpoint or a recoverable accepted operation, subject to filesystem atomic
   rename and fsync guarantees. It cannot leave a persisted value change without
   an attributable operation.
3. History indexing is idempotent. The owner writes operation-ID and ordinal
   records, then clears the pending slot. Recovery finishes this indexing before
   another acceptance. Repeating the original request reads the retained outcome
   without reopening the source file. Reusing its ID with different request
   content rejects. File edits between acceptance and retry cannot redefine the
   accepted operation.

These claims can be falsified by an accepted checkpoint lacking its outcome,
retry dispatching a changed file, an immutable edit changing A, or a current
unauthorized caller receiving protected metadata. The implementation owners are
[Configuration](../../apps/transit-cli/server/Configuration.zig),
[Config](../../apps/transit-cli/server/Config.zig), the
[signed contract](../../packages/zig/transit-config/src/Contract.zig), and the
[session owner](../../packages/zig/transit-query/src/SettingsSession.zig).
The installed [server proof](../../tests/server_configuration.py) and
[TLS adapter proof](../../tests/sql_wire/settings.py) exercise the public routes;
[executed evidence](../../tests/README.md) distinguishes completed runs from
planned checks. Reproduce with the pinned development shell and the server and database-wire
recipes named in the proof ledger; both use disposable installation state.

A settings page contains at most eight rows and binds its continuation to g;
history uses r. A changed basis stops the read instead of combining generations.
Ordered history keeps at most 256 candidate rows; traversal has a separate work
budget. The checkpoint and each history record are limited to 256 KiB. This
bounds resident work independently of retained operation count, but does not
bound disk growth or establish latency. Checkpoint reads and authority-floor
writes incur filesystem work on management requests; no performance measurement
is inferred from the bounds.

Keeping the former whole-config identity hash would make ordinary port or
operational edits require installation replacement. Treating every setting as
live would instead require owners capable of safely replacing listeners, child
processes and artifact state. The chosen classification preserves explicit
identity checks while admitting only implemented live appliers. Capturing session
defaults makes RESET deterministic during concurrent reload; the cost is that
existing sessions retain the earlier ceiling until reconnecting. A live global
ceiling would need an additional per-statement authority contract.

Filesystem rollback, loss of acknowledged durable storage, malicious replacement
of the trusted local installation, multi-manager shared-directory use and
cluster-wide rollout are outside this model. Storage errors make the manager
unavailable; they do not reset history or restore defaults. Native authority
checks still govern every later disclosure/retry. The mechanism requires one
installation manager and the existing installation lock, and does not make a
restored local checkpoint proof of native permission.
