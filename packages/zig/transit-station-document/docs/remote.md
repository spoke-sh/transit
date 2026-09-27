# Authenticated Document calls

`Request`, `Caller` and `Remote` compose Document jobs with Station's authenticated
call/reply boundary. Component tests qualify their bounded private decisions;
the runnable worker and deployment proofs are still in progress. Wire sizes and
fields live in the [submission contract](../../../../contracts/STATION_DOCUMENT_V1.md#authenticated-submission-profile).

A caller prepares a change with `Request.prepare(resource, namespace,
policy_revision, change)`. Choose a dedicated publication namespace for each call;
keep the canonical source bytes recoverable until upload finishes. In its handler,
`Caller.stage(turn, target, reference, change)` advances one bounded upload step
or sends the call. `target` fixes the writer PID and Document resource. The result
distinguishes `progress`, `sent`, `waiting` and a recorded `complete` outcome.
Neither upload nor sending implies acceptance. The recorded call, Station wait
and original target commit together; host loss cannot redirect an admitted call.

The writer's configured `Remote.Policy` binds an authenticated caller PID to a
request resource, replica and policy revision. Select that policy for the specific
Document before calling `Remote.admit(service, turn, policy, reader, node_limit)`.
`reader` is a public `transit-client.ResourceReader` with the writer's explicit
read grants. The process origin supplies the caller; a payload identity cannot
substitute for it. Authentication, service policy and resource grants remain
separate checks. The caller's publication must remain currently readable through
acceptance. Removing the caller's own ability to send new messages does not
retroactively erase previously authenticated inputs; revoke the explicit service
policy to stop that caller's pending candidate.

Admission records one active candidate and a frozen reply route. Busy, malformed,
wrong-epoch or disallowed calls receive explicit rejections. Denied and malformed
requests receive no accepted-state basis. Remote job IDs reserve bit 63 and use
the admitted input position in the low bits; use the lower range for direct
maintenance jobs. The Document must already exist; missing provisioning fails
closed instead of implicitly creating authority.

On an authorized continuation input, inspect `service.head(turn).active_job` and
`Remote.route` to select the current policy, then call `Remote.advance`. The
helper reopens caller publication access at each step. A lost read or removed
policy leaves the job pending and the private turn uncommitted. Restore access
or explicitly use `Remote.reject` under administrative authority. Semantic
dependency/type/conflict/capacity errors close the candidate and record a
correlated rejection. They never trim history or reclaim bytes implicitly.

The last successful step commits the new Document head, snapshot, job outcome,
input progress and original reply together. Three Document mutations leave one
slot for Station framework state. If the reply cannot fit, the whole private
acceptance proposal rolls back. Later ticks see no active job and emit no repeated
success. Exact signed retries remain Station's responsibility. Worker recovery
requires fresh ownership of the same PID; another PID cannot adopt its route.

In the caller's Station reply handler, `Caller.accept(turn, namespace)` validates
origin, correlation and the resource/Document basis before recording the owned
reply. Station has already settled its wait before invoking this handler.
`Caller.outcome` reads that recorded result through the current resource source.
A rejection is not an accepted edit; explicit resubmission uses a new call
namespace. Resynchronization requires application reconciliation and new causal
identities where needed. Cleanup of closed jobs and caller publications remains
an explicit lifetime decision.

No external effect transport or Exchange dependency is involved. This profile
does not promise a transaction over the caller's and writer's resources, or
prevent changes in authorization after the last checked read. Transit still
checks the writer's current authority at its own commit boundary.
