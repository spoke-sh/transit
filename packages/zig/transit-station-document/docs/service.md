# Durable Document jobs and reads

`Service` uses one growing resource and a Publication namespace equal to its
Document ID. Reserve that namespace for this service. It stores its own records
under a separate framework key prefix and never depends on a worker-local file.
Current resource grants and fenced Transit ownership remain necessary for every
turn. The application may compose routing directly or use the
[remote call helpers](remote.md) to freeze authenticated routing and add acceptance
outputs in the final turn.

Create the Document with a nonzero type revision and explicit Publication limits:
records must allow 4096 bytes, with at least one record's staging capacity. Default
retention is unlimited. An occupied namespace without the Document head cannot
be adopted silently; permanent retirement cannot be recreated.

1. `prepare(turn, job_id, change, node_limit)` validates the bounded change,
   freezes its exact content commitment and reserves a permanent request/node ID
   interval. Only one job may be active. This admits tentative work, not the change.
   Bind caller/reply identity with the two remaining mutations in that same turn.
2. `upload` resumes the same canonical request, one publication operation per
   turn. Keep its owned bytes or durable source available until the recorded
   request is complete. A changed request under the same job ID rejects.
3. `advance` reconstructs the candidate from the accepted root and reserved range.
   Progress commits only one node publication operation. No candidate root lives
   in a handler field. Once all nodes exist, the final turn writes the accepted
   head, immutable revision snapshot and job outcome using three mutations. One
   mutation remains for framework state; add the acceptance output in this turn.
4. Commit through Station. Preserve exact signed retry after uncertainty. Following
   host loss, obtain fresh ownership and inspect/reconstruct recorded progress.
   Repeating an accepted job returns its original revision. Repeating the change
   through another job creates no new accepted Document revision.

`IndexStaging` is handled inside `advance`. Other failures restore its private
mutations and leave the Document head unchanged. Handle semantic/capacity failure
by explicitly calling `reject` in a fresh turn and recording the caller outcome.
Rejection clears the active job, permanently closes its ID interval and preserves
its ledger. `collectRejected` later abandons/retires and collects only records in
that exclusive interval, one bounded operation per turn. Collection of accepted
history is a separate checkpoint/retention obligation; it is never inferred from
quota pressure.

The maximum head encoding is 252 bytes, including the largest index root. Request
and node records remain segmented into 256-byte chunks. The ordinary four-mutation,
one-resource and output limits are unchanged. A node limit bounds one candidate;
it is not a maximum Document/history cardinality. Exhaustion rejects tentative
work and requires a deliberate retry/admission decision, not expiry.

`readPath` and `readSequence` open an exact accepted revision through a **current**
growing turn or a public `ResourceReader`. They recheck logical retirement/history availability and rely on
current resource grants for every source read. A cached turn reacquires its head
through the native reader before each disclosure or resynchronization; a wholly
cached small index cannot bypass later permission revocation. A failed read
poisons the turn, including any attempted commit. A sequence page returns at most
eight elements and performs at most 32 traversal transitions; an empty page with
a continuation is not EOF. Keep the same revision across pages. Raw component
roots/readers are lower-level storage interfaces and do not enforce Document
lifecycle by themselves. Service cursors never authorize another resource.

`readRegisterMetadata` supplies up to eight register records' counts per page:
registers, assignment IDs and conflicts, with an ordered continuation. Keep the
same accepted revision across pages. Counts include detached/deleted history and
are neither visible field counts nor whole-Document totals. The reader verifies
register framing without decoding or returning application values. Current
resource policy, history floor and retirement still gate every page. This is the
bounded metadata handoff for Board; the Board API/UI integration is separate.

`resynchronize` returns document/type/epoch/revision, history floor, the replica's
accepted predecessor counter and the maximum observed logical clock. Reconcile
pending edits against those accepted values before choosing new operation IDs.
It does not accept or automatically replay tentative edits. Retirement prevents
reads/submissions/resynchronization; authorized job metadata remains inspectable.

Private-turn component proofs discard/reconstruct every staging proposal, preserve
old snapshots, fit final acceptance plus framework state/output, reject changed
requests, reclaim failed candidates, enforce explicit capacity, and recheck denied
reads/retirement. The separate `just test::document` disk proof kills workers,
node and store, recovers exact signed retries and reads through a separate
read-only principal. All ten public SDKs pass the installed scoped change/read
schedule; remote placement qualification remains in progress.

## Checkpoint and retention policy

`Checkpoint.begin/step` rebuilds a complete materialized root one index entry at a
time. Each entry reserves at most 65 permanent node IDs, derived from the index's
maximum path/split bound. Progress stores one root and ordered cursor; total
checkpoint size does not need to fit a fixed interval or worker buffer. Changes
wait behind the active checkpoint; existing accepted reads remain available.
The final three-mutation decision replaces the head, stores its revision snapshot
and closes the checkpoint job. Checkpoints advance the Document revision.

Unlimited retention is the default: checkpoints preserve all causal records,
duplicate identities, snapshots and epochs. Explicit `configureMergeWindow(N)`
selects a finite number of newest revisions, including the next checkpoint.
A completed checkpoint computes `floor = max(old_floor, revision - N + 1)` when
that expression applies. If the floor advances, the epoch advances too; old-epoch
submissions require resynchronization. Staged checkpoints cannot change either
value. Setting the window back to zero preserves future history and does not
restore previously closed revisions.

An epoch-changing checkpoint drops duplicate-change entries below the floor and
assignments that are no longer live in their registers. It preserves replica
frontiers/logical clocks, object identities, sequence predecessor edges, deleted
anchors and their causal evidence. Resynchronized replicas must continue their
recorded counters. Deletion cannot be undone by recycling a replica/operation ID.
This is a conservative compaction profile: detached subtrees and deleted sequence
anchors are retained, rather than promising arbitrary tombstone erasure.

Revision snapshots also bind the immutable accepted request. `acceptedChange`
returns a bounded verified tail change or an explicit checkpoint boundary. Old
SDS1 snapshot records remain readable; SDS2 adds that request ID without changing
SDC1 or the kernel frame. Checkpoint plus later accepted changes supplies a
recovery basis, and each later snapshot is directly readable at its exact revision.

`Checkpoint.reject/collectRejected` closes and reclaims only that candidate's
exclusive intervals. While live snapshots may still share older nodes, accepted
intervals are retained physically even below the logical history floor. After
permanent Document retirement, `collectRetired` on service and checkpoint jobs
reclaims their intervals in bounded steps. Durable ledgers/descriptors remain to
reject delayed reuse. This profile does not run live reachability garbage
collection or infer permission to delete from a revision number alone.

### Current metadata batches

`Service.open` also accepts a public `ResourceReader.Batch` containing the live
head and accepted-revision record. These are one owned current observation,
not a retained grant. A host using such a batch must reacquire current metadata
after computation and before disclosure. Interactive Fuze performs that final
validation through the combined native snapshot-read operation.
