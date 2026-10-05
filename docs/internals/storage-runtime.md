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

## Reducing durable mutation work

The question is which work a short Table mutation can share or avoid while
preserving admission, a frozen execution basis, and atomic rows/outcome/input
progress. The model here is one serialized realm authority, immutable retained
pages, authorized external workers and conditional durable publication. Provider
errors can leave staged or accepted bytes without a receipt. Notifications and
telemetry are volatile; neither establishes the mutation outcome.

The implementation combines three independent mechanisms:

- The [shared mutation caller](../../packages/zig/transit-query/src/TableMutationClient.zig)
  prepares compatible metadata in one authorized batch and observes processed
  input with disposition/status evidence. The console keeps the acknowledged
  input until a next-request or terminal checkpoint atomically replaces it.
  A crash between observation and checkpoint therefore leaves an exact recovery
  basis; it does not require a new SQL operation.
- The [catalog candidate](../../packages/zig/transit-core/src/catalog.zig)
  overlays a command-bounded set of changed records, including receipts/control
  state. Repeated keys collapse before one tree rewrite. Reads see pending
  changes; scans reject an unflushed overlay. Immutable staging can leave
  unreachable pages on failure, but only the final conditional append changes
  the published root. The private bound follows command quotas, never retained
  resource cardinality.
- [Worker notifications](../../apps/transit-node/Notifications.zig) register under
  the same mutex used by local publication, then release it while waiting.
  Publication scopes reduce unrelated wakeups. Every wake or bounded timeout
  repeats current authorization and authority reads. Cancellation releases the
  slot; a different node's publication is found on timeout. Coalescing is safe
  for this scheduling hint because the subsequent read establishes state. It
  cannot supply complete change coverage for joins or maintained derivations.

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
provider-memory bound. Reproduce it with `just test::page-layout --output FILE`
in the pinned development environment.

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
