# Captured relational jobs

`RelationalCapture` is the Zig Station owner for durable int64 Table joins,
grouping, projection, COUNT and ordered checked SUM. Its
[contract](../../../../contracts/RELATIONAL_V1.md) defines the frozen request,
source vector, checkpoints, output records and manifest. The interactive
`RelationalQuery` uses the same Fuze semantics with a different lifetime.

## Provisioning and admission

The coordinator PID and writable resource are the first Table's owner and
resource. Every source belongs to the same realm. Additional Tables and the
request publication are read-only dependencies. Register their current views
with the turn before calling `start`; aliases of one resource share a cut.
At most two data resources and one distinct request resource require retained
pins. Native resource grants and each catalog's current read policy both apply.
PID-scoped workers also require an association to each dependency. Add or change
associations while the process is unowned, then activate it at the new generation;
an association does not replace a resource grant.

The authorized configuration handler calls `setPolicy` with the requester PID,
request resource, catalog principal, monotonically increasing policy revision,
exact bundle fingerprint and allow flag. This function does not authenticate an
administrator for the application. Changing the policy revision invalidates
continued execution and result disclosure under the old revision.

Encode `RelationalBundle` and publish it as an immutable request record. Its
publisher must be the authenticated caller. Submit its exact
`PublicationReference` in a Station call. `start` requires an otherwise empty
mutation proposal and writes the job, source vector, correlation index and
publication budget together. It retains the request and source versions and
guards their current resource revisions at that same publication boundary.
No process-local schema lookup or name resolution replaces the accepted bundle.

## Execution and recovery

Route the recorded self-cast `UnifiedRecords.Continuation` to `advance` with a
fixed workspace. It authenticates the sender and checks the recorded job/input
identity. Each call reconstructs the exact saved bundle, source vector, operator
root and cursors. It stages one bounded candidate using immutable records, then
accepts the checkpoint, output index and input progress together. Partial
staging leaves the previous checkpoint authoritative. Old continuation inputs
are harmless duplicates; future or foreign continuations reject.

Persist the host's exact `Session.Pending` before dispatch. Resolve an uncertain
submission by retrying those same signed bytes before preparing another turn.
Worker replacement requires a fresh native activation. Reconstruct the owner
from its recorded job and retained versions; an unavailable version fails and
never becomes a fresh snapshot. A lost transport reply does not cancel the job.

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

Authenticate cancellation and retirement in the application's public handler,
then call `RelationalCapture.close`. Cancellation closes active work; retirement
closes a complete result. Failed/denied outcomes retain the original diagnostic
classification and operator witness when one was recorded. Closure releases all
retained request/data pins without rereading them. Duplicate closure is harmless.

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
