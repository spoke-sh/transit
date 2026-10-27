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

Logical deletion precedes physical reclamation. Cleanup is fenced, resumable and
dependency-aware; a delayed delete cannot target a replacement identity. An
adapter's delete acknowledgement does not prove removal from every backup or
external copy. Broad physical-erasure guarantees need a contract for those copies.

The [local native maintenance API](../../../packages/zig/transit-backend-local/docs/maintenance.md)
marks retained roots and live captured versions before deleting immutable pages
and blocks. It requires an accepted epoch fence and a persisted time fence after
snapshot/request grace. Allocation and deletion progress survive reopen. Native
compaction preserves values and resource revisions. The separate
[direct-data collector](../../../packages/zig/transit-backend-local/docs/maintenance.md#direct-table-and-catalog-collection)
retains complete catalog control history, Table recovery, unexpired history, live
snapshots, original receipts and admitted work. It reclaims expired graph objects
only after proving that none of those owners need them. Saved direct-intent
references and permanent identity reservations remain retained. Automatic local
collection scheduling remains separate from these component operations.

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
