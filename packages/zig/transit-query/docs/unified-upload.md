# Unified requester uploads

`UnifiedUpload` and `UnifiedBehavior.Requester/Source` implement the finite v1
request lifecycle. The [contract](../../../../contracts/UNIFIED_QUERY_V1.md)
owns wire versions. Component, signed all-source lifecycle/SDK and Table physical
placement qualification is recorded in the [proof guide](../../../../docs/history/qualification/runtime.md#m18-qualification).

Initialize a requester separately with `UnifiedRequest.Command.initialize` from
its configured query principal. The behavior durably binds that principal and
source PID. Restart configuration must match that binding. Source initialization
similarly binds its accepted peer and initializer principal; source policy and
application data must already be provisioned through their owning operations.

The requester accepts these authenticated casts:

| Command | Effect |
| --- | --- |
| `begin` | Reserve one finite bundle and the sole active slot; never adopt an occupied namespace |
| `part` | Stage one 128-byte half of a canonical Publication chunk; verify repeated parts exactly |
| `seal` | Verify the complete Publication commitment and mark the bundle ready |
| `submit` | Create one durable call carrying the immutable reference; duplicates keep its original correlation |
| `cancel` | Explicitly close an active local wait/upload and schedule bounded collection |
| `retire` | Explicitly withdraw a terminal request publication, ending later result availability |
| `collect` | Advance closed-publication cleanup; no implicit expiry |

The largest part payload is 145 bytes, before the existing 13-byte Station header.
Begin is 72 bytes; namespace-only operations are 12 bytes. Neither the 243-byte
payload nor the four-mutation budget changes. An upload may contain a 4 KiB
predicate while each handler sees one small command. Partial pairs are durable
requester state, not native worker fields. A changed part, identity or digest
cannot overwrite earlier accepted staging.

One active upload/query bounds admission independently of retained history.
Abandonment keeps the active slot until Publication cleanup releases its staging
reservation. Accepted/complete request records remain immutable evidence until
explicit cancellation or retirement. A namespace cannot be reused after cleanup.
A transport receipt acknowledges input admission, not successful upload or query
acceptance. Invalid authenticated commands receive a durable error-name record at
`UnifiedRecords.key('e', input_position, 0)`; infrastructure/read failures do not
become successful acknowledgments. Never log bundle bodies or decoded values.

The source receives the reference through an authenticated call, checks its
publisher, policy and full bundle, and enters the
[capture state machine](unified-capture.md). Domain rejection/denial uses the
original reply route. Current request-resource denial closes an accepted query
without reading its body; own-source read failure cannot fabricate a closure.
Cancellation is an ordered request: source completion may already have won, and
previously returned bytes cannot be retracted.

Station still freezes exact pending signed commits, and a new OS worker still
requires fresh fenced ownership. The shared client must keep each prepared
signed upload command across uncertainty. It may choose its successor only after
the preceding input has been observed as committed. No local timeout grants
permission to invent a replacement call.

Finite process/resource lifetimes bound the requester wait to their earliest
recorded deadline. The configured query principal is also the authenticated
Station timer observer; it already has explicit cancellation authority. An
accepted timer observation closes the local wait, records cancellation and
schedules bounded publication cleanup. Hard resource/process expiry is enforced
by Transit even when no observer runs; neither timer delivery nor cleanup can
extend it. The daemon does not supply a timer service. Unlimited lifetimes retain
an unlimited wait. `UnifiedUpload.submitWithObserver` exposes this composition;
low-level `submit` without an observer rejects finite waits before any mutation.

## Reusing a submitted plan for a new finite query

M21 adds owner-side `UnifiedUpload.copyNext(turn, template, namespace)`. The
explicitly selected template must be a completed query with a still-published
request bundle in this same requester resource. Each step either reserves the
new namespace, copies one 256-byte Publication chunk, or seals it. Sealing verifies
the complete original commitment. The operation never admits a source call;
only the existing explicit `submit` transition can do that.

This is a new finite evaluation of identical source/plan/budgets, not recovery of
an uncertain query. Exact retry still retains the original signed request/call.
A composing durable owner chooses a new permanent namespace and freezes each
Station commit, then reconstructs copy progress from the retained upload record.
The helper uses at most four mutations and one chunk of resident payload, rejects
mixed public half-uploads and preserves the requester's one-active-query quota.
Retired/unavailable templates reject. Failure leaves accepted staging observable
and subject to ordinary explicit cancellation/collection; it never evicts work.

Component tests reconstruct the owner after every step of a bundle larger than
4 KiB and test quota/identity conflicts, four-mutation rollback, template retirement,
partial-upload mixing and corrupted bytes. This foundation does not itself qualify
the M21 scheduler or browser views.
