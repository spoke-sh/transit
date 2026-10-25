# Captured relational jobs

`RelationalCapture` is the Zig Station owner for durable int64 Table joins,
grouping, projection, COUNT and ordered checked SUM. Its
[contract](../../../../contracts/RELATIONAL_V1.md) defines the frozen request,
source vector, checkpoints, output records and manifest. The interactive
`RelationalQuery` uses the same Fuze semantics with a different lifetime.

## Provisioning and admission

The coordinator owns an independent native computation resource. Every source
belongs to the same realm; register the request publication as a read dependency
and supply a direct executor route per Table alias. The route carries the worker's
own key and principal. `RelationalBundle.authorizeCapture` binds the caller's
original proof, exact Table frontier, pin owner and execution route. Same-Table
aliases share one pin; different Tables remain independent even in one catalog.
The request keeps a native retained version. Direct Table pin records keep their
own immutable handles and original authority, without raw source-resource grants.

The authorized configuration handler calls `setPolicy` with the requester PID,
request resource, catalog principal, monotonically increasing policy revision,
exact bundle fingerprint and allow flag. This function does not authenticate an
administrator for the application. Changing the policy revision invalidates
continued execution and result disclosure under the old revision.

Encode `RelationalBundle` and publish it as an immutable request record. Its
publisher must be the authenticated caller. Submit its exact
`PublicationReference` in a Station call. `start` requires an otherwise empty
mutation proposal and writes the job, correlation index and publication budget.
It retains the request and checks current authority for every source. Later turns
commit each Table's acquisition eligibility before dispatching its direct pin
request, then record the recovered handle before traversal. The full source vector
commits only after every handle is durable. No process-local schema lookup or name
resolution replaces the accepted bundle.

## Execution and recovery

Route the recorded self-cast `UnifiedRecords.Continuation` to `advance` with a
configured direct executor routes and a fixed workspace. It authenticates the sender and checks the recorded job/input
identity. Each call reconstructs the exact saved bundle, source vector, operator
root and cursors. It stages one bounded candidate using immutable records, then
accepts the checkpoint, output index and input progress together. Partial
staging leaves the previous checkpoint authoritative. Old continuation inputs
are harmless duplicates; future or foreign continuations reject.

Persist the host's exact `Session.Pending` before dispatch. Resolve an uncertain
submission by retrying those same signed bytes before preparing another turn.
Worker replacement requires a fresh native activation. Reconstruct the owner
from its recorded job, native request version and direct pin records. An
unavailable retained source never becomes a fresh snapshot. A lost transport reply does not cancel the job.

Current authorization or revision checks can reject a proposal before commit.
The host must settle any pending signed request and obtain a fresh proposal
before changing its work. Native read failure poisons a private turn. Do not
convert that turn into a successful closure. A closure handler must be able to
open only the coordinator resource: configuring mandatory foreign reads for
every input would prevent closure after a foreign grant is revoked.

`start` and `advance` require `workspace.len + RelationalCapture.resident_base`
to fit the declared resident budget. The workspace is a fixed allocator;
candidate nodes, schema decoding and publication buffers have bounded resident
storage. Spill accounting includes immutable historical and private candidate
records, not just the latest root. A failed semantic step can use one additional
checkpoint of at most 8192 bytes to preserve its witness after quota exhaustion.
Native storage/transport failures remain attempts until an outcome is committed.

## Reading and closure

The completion reply references an immutable manifest. Open `RelationalResult`
with the caller's original frozen bundle, owner/resource/job identities and
native request limit. Keep the bundle alive for the reader's lifetime. `schema`
and `next` check current coordinator policy, job state, native grants and every
source catalog policy. They do not rebind historical schemas through live names.
Rows are owned scalar values; counts retain their uint64 representation.

Only the final null from `next` establishes completeness. It verifies ordinal
coverage, canonical ordering, output digest chain, encoded byte counts and
checkpoint result counts. An earlier row is a provisional prefix. `close`
releases the reader's lease; it does not cancel the durable job.

Before exhaustion, `freshness` compares the manifest's actual retained cuts with
read-only current Table observations under the result reader's caller identity.
Each entry reports its exact interpretation, captured position and observed
logical-change watermark. Later logical row changes report `stale`; pin,
admission, flush and accepted no-op bookkeeping alone do not. ALTER, DROP or
name replacement reports `definition_changed` after current source authorization.
Denied or unavailable observations return their error without a partial vector.
Same-Table aliases share one observation. Different Tables are sampled
independently; `fresh` describes coverage of that observation vector, not an atomic
catalog snapshot or a promise about later writes. This method starts no query,
acquires no Table pin and does not verify output coverage. Continue to terminal
`next` before treating the result as completely delivered.

Authenticate cancellation and retirement in the application's public handler,
then call `RelationalCapture.close`. Cancellation closes active work; retirement
closes a complete result. Failed/denied outcomes retain the original diagnostic
classification and operator witness when one was recorded. Closure releases the
native request version and schedules direct pin settlement. Complete results also
schedule pin settlement without changing their manifests. Current denial keeps
cleanup pending; `retryCleanup` retries its saved grant, while `authorizeCleanup`
accepts a separate fresh closure proof after credential rotation. Neither control
resumes execution. Duplicate closure is harmless.

Call `collect` explicitly after closure, scheduling another input while it returns
false. Each step examines one descriptor or removes at most two publication
chunks; its cursor survives worker loss. It also reaches partially staged records
beyond the last accepted root. Permanent descriptors, job/correlation records,
output references and source-vector evidence remain. Failed/denied jobs retain
their last bounded checkpoint for diagnostic inspection. Request publications
belong to their publisher and have a separate retirement lifecycle. This is
logical current-state collection; storage compaction and protected historical
roots determine when physical bytes can be reclaimed.

The typed Zig owner is separate from the single-source `UnifiedClient`, native
language port, console durable-query route and Flight adapter. Those routes do
not acquire relational execution by accepting a bundle with a new format.
