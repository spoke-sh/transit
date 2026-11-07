# Retention, lifetimes and capacity

Retention is unlimited unless the application explicitly opts into a finite
policy. Storage or memory pressure can refuse new work; it cannot silently expire
accepted work. Logical expiry, settlement closure and physical reclamation are
different events with different evidence.

## Separate lifetimes

| Lifetime | What it controls |
| --- | --- |
| Process/required input | Whether the PID can still recover and execute |
| Resource | Whether state and required dependencies remain available |
| History | How far back replay or inspection can read |
| Settlement | Which already authorized work may finish after ordinary admission closes |
| Session/view/ticket | Temporary attachment or access mechanism, not the underlying data |
| Captured payload | Availability of bytes; compact attempt/closure identity can survive longer |

A live process can recover from a checkpoint plus retained tail after older
completed history is removed. But required unprocessed input or a required
resource cannot disappear while recovery is promised. A worker snapshot alone
does not establish that recovery basis.

## Cutoff, settlement and retirement

At the ordinary-work cutoff, new admissions, ordinary turns and new effect
authorizations stop. A pre-recorded finite settlement contract may allow only its
existing authorized work to finish. It cannot extend its own scope or deadline.
Explicit termination retires a PID; expiry ultimately ends its settlement rights
and retires it permanently. A retired PID cannot activate again.

Trusted authorization time and serialized closure enforce the selected deadline
contract. This is not a physical guarantee that no remote byte is sent after the
wall-clock cutoff. An authorized external attempt is potentially in flight;
local closure can preserve **outcome unknown**. See [connector recovery](connectors.md).

Suspension never promises recovery beyond required input/resource lifetimes.
A storage outage is not expiry. Missing required history is a recovery failure,
not permission to skip to the tail. Restored old bytes cannot revive a retired
identity. Replaying history uses its recorded time/decisions, not today's clock.

## Checkpoints, trimming and cleanup

Publish and validate a checkpoint with its required payloads before trimming
history it replaces. Preserve committed state, progress, pending outputs,
ownership, dependencies and supported retry evidence. After trim, that checkpoint
is essential durable data. A latest-value projection alone cannot replace an
execution journal.

Reads before the retained boundary report a gap/expiry explicitly. Current state,
replay, duplicate rejection and post-retirement inspection can have different
horizons. After detailed retry evidence is reclaimed, old identities must still
be rejected through retained floors/retirement facts; they cannot become new work.

The local Table owner can archive complete accepted records and trim their covered
WAL files while preserving unlimited logical history. Original receipts, retained
unflushed snapshots and offline history cursors resolve through the accepted
archive directory. Missing required archive data is a replay/read failure. A
published recovery checkpoint bounds Table restart to its accepted root and later
transitions while preserving those original read/retry obligations. It grants no
additional trimming or expiry authority. This
[physical history maintenance](../../../packages/zig/transit-storage/docs/table-partitions.md#archive-complete-history-and-trim-wal-files)
does not expire history or collect immutable Table objects.

The Table storage component also accepts explicit `expireHistory` calls with
maintenance authority. A call advances a durable logical history floor only
within published archive/checkpoint coverage and never past a live history
lease's original frontier. Reads starting below that floor report expiry.
Ordinary pinned snapshots, original receipts, current data and admitted work
remain retained. An offline history consumer keeps its lease until explicit
release. The paged lease directory bounds the oldest-lease check independently
of pin count. This operation does not reclaim physical objects; the installed
service has no automatic Table history-expiry policy.

Published [immutable Table branches](tables.md#immutable-table-branches) retain
their source pin without expiry, including schema-only branches. Explicit
retirement first closes branch reads, including existing continuations, then
resumably releases the original pin. Current source access is required for both
steps; no background sweeper completes interrupted retirement. The successful
creation receipt, head and immutable directory metadata remain inspectable after
release. Physical collection separately checks all remaining data dependencies;
retirement neither erases that evidence nor releases another branch's pin.
An immutable fork owns an independent copy of its parent's exact retained cut.
Parent retirement preserves that accepted child pin and the original ancestry
metadata. Admission without an accepted pin copy does not hold the parent's data;
such a pending child refuses if its parent retires before acquisition.

The Stream storage component can expire one sealed prefix batch per call under
an explicitly declared age. Trusted append time establishes eligibility; payload
timestamps do not. A paged consumer watermark index prevents expiry beyond the
slowest checkpoint. Existing finite read pins preserve their original data;
new reads below the retained boundary report a gap. Original receipts and
producer fences remain retained. Physical collection separately requires pins
and recovery dependencies to close. The signed Stream API exposes original
reads and releases; local native maintenance schedules opted-in age expiry.

Queues add a terminal-state requirement to that age policy. Native maintenance
expires at most one whole sealed batch from the retained prefix when every item
is ACKed or durably archived. Nonterminal work, including delayed and exhausted
items, blocks its batch; later batches wait behind that prefix. This check uses
accepted `.tack` cardinalities and does not scan every item. Lease expiry and
payload expiry are separate bounded tasks. DROP preserves the frozen policy;
quota pressure grants no expiry right.

An open original claim keeps its frozen payload placement even after the Queue's
current retained boundary advances. Explicit `QueueRead.Release` closes only that
claim's payload reads and preserves its original receipt and lease identities.
It does not settle a lease. Older replay checkpoints and other open claims retain
their own dependencies. Physical collection can remove the expired payload only
when those dependencies have also closed. See the [Queue lifecycle](streams.md).

Logical deletion precedes physical reclamation. Cleanup is fenced, resumable and
dependency-aware; a delayed delete cannot target a replacement identity. An
adapter's delete acknowledgement does not prove removal from every backup or
external copy. Broad physical-erasure guarantees need a contract for those copies.

Published SOURCE bodies follow their destination Stream's retention. The Stream
envelope, existing read pins and uncertain publication work retain the complete
manifest/chunk graph. Explicit age expiry prevents new pins below the retained
boundary; existing readers keep their original bytes. After the last pin and
recovery root release them, collection may remove the body while preserving its
original publication receipt. Dropping SOURCE or CONNECTION metadata does not
release destination-owned captures. A descriptor alone is not a retention pin.
This capture-specific lifetime does not change unrelated committed transaction
record retention. See [owned captures](streams.md#owned-source-captures).

The [local native maintenance API](../../../packages/zig/transit-backend-local/docs/maintenance.md)
marks retained roots and live captured versions before deleting immutable pages
and blocks. It requires an accepted epoch fence and a persisted time fence after
snapshot/request grace. Allocation and deletion progress survive reopen. Native
compaction preserves values and resource revisions. The separate
[direct-data collector](../../../packages/zig/transit-backend-local/docs/maintenance.md#direct-table-and-catalog-collection)
retains complete catalog control history, Table recovery, unexpired history, live
snapshots, original receipts and admitted work. It reclaims expired graph objects
only after proving that none of those owners need them. Saved direct-intent
references and permanent identity reservations remain retained. Transaction-owned
managed result candidates become eligible only after authoritative abort and
complete cleanup. Uncertain attempts and committed revisions remain protected;
retirement alone does not release them. Replaceable managed progress uses
Catalog-owned `CPR1` records: collection retains the current and staged references
at its accepted cut and may reclaim superseded payloads after reader grace.
Terminal progress and published declarations remain retained. Initial managed
work uses operation-owned `SOR1` records: explicit closure can release private
staging, and completed work closes its original bytes after recovery obligations
settle. Closure serializes with exact head attachment and permanently fences late
retries. Original receipts and commitments survive physical cleanup. Generic
unowned admission records retain their existing lifetime.
The local
maintenance executor schedules native and direct collection using separate
source-allocation activity and durable pass progress. It resumes an incomplete
pass before starting another and still requires current maintenance authority
and reader grace before deleting anything. See the
[storage configuration](configuration.md#immutable-storage) for eligibility and
work limits; scheduling grants no logical expiry.

Documents add an explicit merge epoch/history floor. Old replicas may need
resynchronization after opted-in compaction; they cannot replay stale edits into
a new epoch. Ordinary resource references do not pin all historical revisions.

## Capacity and control progress

Bound resident pages, operation batches, active work, stored bytes and maintenance
work separately. Cache eviction discards derived memory, not accepted data.
Admission must leave space for control operations such as revocation, closure,
delivery disposition and maintenance.

The implemented optional `admission_ceiling` and `control_reserve` close admission
before the reserved control budget is consumed. Growing capabilities expose
those configured bounds. They do not allocate physical disk or guarantee that
all queued application work can drain: a new data read may remain blocked while
control operations still progress. Provision and measure actual storage headroom.

See the [authority capacity guide](../../../packages/zig/transit-core/docs/authority.md),
[storage maintenance](../../../packages/zig/transit-backend-ursula/docs/storage.md),
[catalog contract](../../../contracts/CATALOG_V1.md) and [Document service](../../../packages/zig/transit-station-document/docs/service.md).
Per-key TTL, generic dependency deletion and distributed compaction are unsupported.


## Table transaction resources

A [Table transaction](sql/transactions.md) retains its common-cut pins and private
roots independently of SQL connection/session leases. There is no automatic
transaction lifetime timeout. Session expiry releases temporary results and
preparations; an authorized caller explicitly recovers and commits or rolls back
the original transaction. Aggregate reservations refuse excess pending work
without expiring accepted transactions.

Decision cleanup releases pins and active reservations in bounded steps. It
preserves original statement/control outcomes and decision evidence. Savepoint
rollback can release private roots after publishing its restored head; physical
collection separately follows retained graph dependencies. Neither a lost commit
reply nor abandoned caller grants authority to discard preparation or decision
records needed for recovery.
