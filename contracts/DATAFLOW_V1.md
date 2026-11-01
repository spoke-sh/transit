# Managed computation contract v1

[`Dataflow`](../packages/zig/transit-protocol/src/Dataflow.zig) owns the neutral
declaration, control, lease, coverage and completion types. They are reflected
in [the data lifecycle schema](data-lifecycle-v1.schema.json). Shape validation
does not authorize execution, retain source history, prove a transaction decision
or establish that a worker computed an honest result.

## Identities and publication

A computation has one stable `DataLifecycle.Object` and immutable
`DataLifecycle.Definition` revisions. A catalog name resolves to that identity;
recovery never resolves a name again. A `Definition` freezes the compiled plan's
content commitment, exact dependency directory, consumer contract, resume policy,
owner and budgets. Directory counts are durable cardinalities; owners page them
under bounded resident memory. A digest alone is not a retention pin.

The catalog owner must reject dependency cycles and unsupported source, operator
and consumer combinations before successful publication. Publication registers dependencies
and retains the declaration before making it discoverable. Partially initialized
work remains attached to the original accepted operation for recovery or explicit
closure. Dependencies protect DROP but grant neither access nor execution rights.

The consumer contracts differ:

| Contract | Required observation |
| --- | --- |
| `finite_recomputation` | A complete finite relation at each selected source basis |
| `net_relation_changes` | Complete changes between selected relations, permitting declared consolidation |
| `complete_ordered_changes` | Every accepted logical change in source order, including oscillations and accepted no-ops |

Only the first two may choose `recompute_snapshot` after unavailable history.
Recomputation establishes a new finite basis; it cannot repair missing ordered
changes. A consumer requesting `complete_ordered_changes` must use
`replay_history` and block on an expired interval.

## Control and fencing

`Control.initial()` is Published at epoch one. Valid transitions are:

| Command | Required state | Result |
| --- | --- | --- |
| authorize | Published | Authorized |
| activate | Authorized | Active |
| suspend_computation | Active | Suspended |
| resume_computation | Suspended | Active |
| refresh | Active or Suspended | Same state, refresh generation advances |
| retire | Any state except Retired | Retired |

Every accepted command advances the control epoch. Retired is permanent. Exact
operation retries return the original receipt; they do not apply the transition
again. `ControlAttempt` carries the original operation, exact definition,
expected control and command. Changed-content reuse conflicts. Authorization is
a current owner check; the Authorized state never caches a grant.

`Lease` binds the definition, complete control value, worker operation and lease
epoch. Replacement advances the lease epoch. Final publication must validate
these fences and current source/output rights at the common decision boundary.
If suspension, refresh, retirement or replacement is accepted first, an old
candidate cannot publish. If completion wins first, the command preserves that
last complete result. A resume does not revive an earlier worker's lease.
Trusted lease expiry belongs to the service owner, not a client clock.

Control acceptance and first-result completion are separate observations.
Suspension/retirement preserve the last complete revision according to its
retention policy. Retirement, recovery closure and physical collection are
separate operations. Closing a result reader or a temporary SQL session does not
retire a computation.

## Source coverage and recovery

`Source` binds one exact interpretation, data kind, partition-qualified exclusive
position and retention owner. Positions in different WAL partitions have no
global ordering. An adapter acquires history protection before backfill and saves
that exact basis before reading; it must not silently reacquire a newer snapshot
after a failure. Retention owners preserve unflushed WAL as well as segments.

`Coverage` names an exact interval and verified terminal coverage. Empty intervals
may be complete. An empty fetch, transport EOF, timeout, budget stop or partially
delivered acceptance cannot establish completion. `requireComplete` checks the
saved predecessor, interpretation, retention identity, partition and monotonic
frontier. A new definition requires explicit rebinding, never an implicit cursor
reset. Current authorization applies to data, metadata and terminal observations.

Adapters resolve transaction participants against the common transaction owner.
Prepared/private rows and aborted decisions contribute no committed changes.
Pending participant evidence remains durable and cannot be skipped by a later
ready transaction. Notifications are wake hints; durable discovery and retained
positions recover lost/duplicate notifications and process replacement.

## Atomic successors

`Candidate` is private staged work. It binds the original operation, worker fence,
previous complete revision, complete source directory and result content/row count.
Incomplete staging is not a result, including a zero-row prefix.

The implementation must publish output, checkpoint and completion together through
the common state/output transaction. The checkpoint/control resource participates
with its original conflict guard so a raced control command fences publication.
Immutable staged objects are retained through preparation and original-operation
recovery. Current grants are rechecked at the decision; prior admission is not a
permit to complete after revocation.

`Completion` attributes the candidate to a committed `Transaction.Identity` and
coordination-log decision position. It cannot substitute a participant's LSN or
a caller-supplied committed tag. The owner must verify the complete candidate's
binding to that decision, not merely validate the neutral descriptor. A lost
reply is resolved through the original transaction and candidate identity.

Retained-result access must follow the published profile's current authorization
rules. Failed work leaves the previous complete revision visible. Cleanup may
release source pins or private roots only after their original decision and
recovery obligations are closed; denial remains observable. Quota pressure never
authorizes expiry, silent cancellation or discarding accepted work.

## Installed finite Table profile

`transit-query-direct.ManagedTable` owns `DFD1` declarations, `DFW1` work and
`DFP1` immutable row pages. A named direct binary KV owns the current control,
pending original work reference and paged completed revision keys. The logical
computation definition hashes the declaration; it is distinct from the KV
storage definition. The catalog's `managed` dependency kind validates that
storage identity and protects source/output DROP. Under the same catalog CAS,
registration excludes output chaining and multiple managed writers, including
concurrent declarations in either registration order.

A work record is staged before its reference can enter the guarded head. Only
that accepted head admits the work token. Recovery can recreate a missing token
from the exact retained reference. The pending reference survives output commit
until original transaction cleanup and work bookkeeping complete. A suspension
changes the same KV that the output transaction reads/writes, so the common
serializable decision enforces the control fence. Replacement resumes that exact
accepted work under the service's existing activation fence.

The output Table, source read guard, head and completed revision key share one
common transaction. Completion inspection reads its committed decision; neither
an individual participant LSN nor a work phase establishes completion. Private
row staging and incomplete execution expose no output. A deterministic output
constraint rejection blocks with `execution_failed` and preserves the last
complete output; it does not schedule an unbounded retry loop. A rejected transaction
can be followed by a new finite attempt only after the original decision closes.
No source LSN is compared with another partition's clock.

The native cohosted SQL service accepts `CREATE DATAFLOW name INTO output AS
SELECT ...`, AUTHORIZE/ACTIVATE/SUSPEND/RESUME/REFRESH/RETIRE DATAFLOW, SHOW
DATAFLOW and metadata-only EXPLAIN CREATE DATAFLOW. SQL operation kind `dataflow`
and command kinds `create_dataflow`/`control_dataflow` preserve the original
saved request and typed completion. Closing a session is not retirement.
Cancellation of an accepted control is unsupported; use lifecycle controls and
inspect its original outcome. Standalone and database-wire declarations reject.

The [query reference](../docs/handbook/reference/queries.md#managed-table-computations)
owns supported operators, quotas, inspection, current grants and retention limits.
This profile uses complete finite recomputation over one Table. It does not
implement the neutral contract's ordered/net-change consumers or history handoff,
SQL joins, incremental arrangements or sink effects. Immutable saved records
remain outside the direct object collector's authority and retain indefinitely;
common transaction cleanup releases its source pins and preparation barriers.

Captured and host-driven maintained execution retain their
[named relational contract](NAMED_RELATIONAL_V1.md). Existing helper modules are
not service executors. The [capability ledger](sql/standards-ledger.json) records
these separate boundaries. Stored records and caller contracts use the single
current definition under the [versioning policy](../docs/handbook/reference/versioning.md).
