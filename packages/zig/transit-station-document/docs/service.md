# Durable Document jobs and reads

`Service` uses one growing resource and a Publication namespace equal to its
Document ID. Reserve that namespace for this service. It stores its own records
under a separate framework key prefix and never depends on a worker-local file.
Current resource grants and fenced Transit ownership remain necessary for every
turn. The application owns authenticated routing and adding acceptance outputs.

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
growing turn. They recheck logical retirement/history availability and rely on
current resource grants for every source read. A sequence page returns at most
eight elements and performs at most 32 traversal transitions; an empty page with
a continuation is not EOF. Keep the same revision across pages. Raw component
roots/readers are lower-level storage interfaces and do not enforce Document
lifecycle by themselves. Service cursors never authorize another resource.

`resynchronize` returns document/type/epoch/revision, history floor, the replica's
accepted predecessor counter and the maximum observed logical clock. Reconcile
pending edits against those accepted values before choosing new operation IDs.
It does not accept or automatically replay tentative edits. Retirement prevents
reads/submissions/resynchronization; authorized job metadata remains inspectable.

Private-turn component proofs discard/reconstruct every staging proposal, preserve
old snapshots, fit final acceptance plus framework state/output, reject changed
requests, reclaim failed candidates, enforce explicit capacity, and recheck denied
reads/retirement. These are not disk/node failure or public SDK/placement proofs;
those remain part of M17 qualification.
