# Execution, authorization and recovery

The central question is what evidence permits a worker to advance a logical
process after concurrency, revocation or failure. This account combines the
kernel, delivery and authorization arguments supporting the
[data lifecycle](../reference/data-model.md): accepted mutations, recoverable
computation and current permission. Process progress alone is not evidence that
an application declaration has been fulfilled. Exact operations remain in the
[process reference](../reference/processes.md),
[native protocol](../reference/native.md) and [security reference](../reference/security.md).

The declarative-authorization analysis below describes the implementation at
`a3c2d074` on 2026-10-14. Its evidence records retain their own source revisions
and contract definitions; a common v1 name does not establish compatibility.

## State and acceptance

Model a proposal as naming a PID, ownership generation, prior committed basis,
next input and proposed state/output changes. Acceptance requires current scoped
permission, eligible lifetime, a valid recovery/dependency basis and matching
ownership and ordering preconditions. The authority conditionally publishes
one successor of that basis.

This is a conceptual description of the validation relation, not a replacement
wire format. The selected contract determines the exact fields and bounds.
Its durability assumption belongs to the [storage boundary](storage-runtime.md).

## Safety argument

| Boundary | Invariant | Mechanism |
| --- | --- | --- |
| Competing proposals | Conflicting successors cannot both advance the same basis | Conditional acceptance and validation against committed state |
| Worker replacement | Superseded ownership cannot commit new work | Ownership generations checked at the authoritative boundary |
| Turn visibility | State changes, input progress and outputs publish together | One commit decision; a private draft has no durable effect |
| Lost acknowledgement | Uncertainty cannot create a second identity for the same accepted operation | Frozen request identity/content and exact reconciliation |
| Delivery | Retry cannot choose a different destination for an accepted output | Committed destination/provenance and destination deduplication |
| Retirement | Old bytes or a new worker cannot revive a retired PID | Persistent retirement/rejection evidence checked before execution |

For example, if a commit succeeds and its response is lost, the caller cannot
deduce failure from the transport error. Reusing the frozen operation permits
the authority to identify its existing outcome. Issuing a fresh operation would
ask for new work and defeats that argument.

Delivery is a later operation than source commitment. A courier failure leaves
pending outbox work. Destination denial can block its first acceptance without
rolling back the source turn. Consequently, atomic source publication does not
imply a transaction across receivers or exactly-once remote effects.

## Authorization over time

Identity authentication, current permission and activation ownership answer
different questions. A prior allow decision, association or signed receipt does
not authorize a new disclosure. Reads and reconciliation apply current scoped
policy even when the original mutation was permitted.

This creates a necessary distinction: an accepted operation can exist while its
former caller can no longer read its outcome. Denial is not proof of rejection.
Revocation also cannot erase an external attempt already authorized for dispatch;
that case requires the [effect lifecycle](effect-lifecycle.md).

### One current policy graph

Let `P` be a published policy revision, `L` the authenticated login role, `R` the
selected role and `O` a stable object identity. A credential binds its principal
to `L`; its epoch detects replacement or disablement. Selecting `R` requires a
current SET path from `L`. Evaluation then follows eligible INHERIT paths from
`R` and unions supported grants on `O`. ADMIN and grant options govern delegation
separately. This model explains why revoking one path cannot deny another valid
path, and why deleting a grantor's support must also invalidate dependent grants.
Role and object names are lookup keys; renaming or reusing a name cannot transfer
the old identity's authority.

The [native evaluator](../../../packages/zig/transit-core/src/authorization.zig)
and [administration transitions](../../../packages/zig/transit-core/src/authorization_admin.zig)
implement those decisions over the
[paged policy store](../../../packages/zig/transit-core/src/authorization_store.zig).
A change builds a private candidate from `P`, advances in bounded pages and
publishes only against its original revision. Competing policy publication
invalidates that basis. Interrupted or abandoned candidates grant nothing;
reserved identities remain unavailable for reuse. These are deductions from
the publication precondition, assuming the storage boundary preserves its
conditional publication and recovery checks.

The policy graph can outgrow resident memory. A decision has explicit limits on
visited roles, path depth and work; an administrative candidate has separate
step and changed-record quotas. Exceeding a limit rejects rather than accepting
a partially explored positive path. Preview uses smaller scratch bounds and
can report incomplete exploration. Therefore a preview is useful for review
but is neither a grant nor evidence that eventual publication must succeed.
The exact bounds belong to the
[authorization contract](../../../contracts/AUTHORIZATION_V1.md#bounded-evaluation-and-storage).

### Original subjects through trusted mediation

The Table service has private native access to a catalog resource that can
contain multiple Tables. Giving that access to every SQL caller would bypass
Table-level isolation: the caller could read backing entries directly. Instead,
the service separates its storage credential from an independently authenticated
subject. An accepted native input supplies a retained admission claim; a read or
query supplies a signed proof binding its principal, credential epoch, selected
role, audience and complete domain request digest.

For a query, the digest includes the immutable plan, source declarations and
intended recipient. Exchange assignments additionally bind the worker, producer,
layout, epoch and retained source basis. Continuations keep those original
proofs. Restoring a saved operation cannot select a new role, replace its source
identity, renew its credential epoch or sign a different query and call that
recovery. Current result disclosure can use a separately authorized recovery
operator while retaining the original execution attribution.

For each Table access the domain owner requires database CONNECT, schema USAGE
and the applicable object privilege. Historical definitions, frozen source cuts,
buffered vector rows and retained results remain subject to current checks.
The [Table authority context](../../../packages/zig/transit-catalog/src/TableAuthority.zig)
collects those requirements; the
[Station turn guard](../../../packages/zig/transit-station/src/Turn.zig)
also places them in the native proposal. The native authority checks that guard
again at publication. Thus a revoke ordered before publication prevents an
otherwise valid staged mutation from committing. An earlier committed mutation
is not rolled back, and a transport failure still leaves its outcome uncertain.

This argument assumes a trusted domain implementation supplies a complete
requirement set and binds proofs to the actual operation. The native kernel
does not parse SQL, interpret Table pages or prove that a compromised service
computed honestly. A service holding raw storage credentials belongs to the
trusted boundary. The separate restricted-caller proof is necessary to show
that ordinary callers cannot exercise those credentials themselves.

### Recovery, roles and credential rotation

Saved administrative and Table commands retain their exact signed bytes.
Receipt reconciliation checks that identity before any further submission.
After credential rotation, a current credential can recover an existing receipt
without replacing the accepted request's signature. An absent receipt does not
authorize re-signing an uncertain request. Observing an operation and obtaining
its protected data have separate current authorization requirements.

The Station ledger makes the deployment distinction concrete: bootstrap creates
stable login roles and an explicitly selected data role, while activation rotates
worker credentials without reinstating grants. A saved query or unfinished delta
keeps its earlier proof, so rotation can deny its continuation even though fresh
work under the new credential has the same role grants. The input and staging
remain inspectable. This is a cost of treating credential replacement as a
current authority change rather than an implicit renewal of accepted work.

## Progress and tradeoffs

Safety does not promise eventual handling. Progress depends on available storage,
eligible ownership, sufficient permission and capacity, retained dependencies,
and execution/delivery scheduling. A poisoned input or permanently denied output
needs an explicit disposition; skipping it would change accepted work.

Replacing durable retry identity with local task identity would simplify a
single live caller but lose the relation after caller failure. Transit instead
requires recovery material and explicit unknown outcomes. See
[client and framework ownership](client-framework.md) for the language boundary.

Independent per-adapter permission lists would reduce native administration
traffic but introduce multiple policy authorities and ambiguous revocation.
Caching a positive decision until a ticket or snapshot expires would reduce
read checks but permit disclosure after revocation. The chosen mechanism pays
for current native checks and can fail closed during authority outages. These
are architectural tradeoffs, not a measured performance comparison with those
alternatives. Broad raw-resource grants remain an explicit infrastructure
profile and cannot substantiate restricted Table isolation.

## Evidence and limits

The [invariant inventory](../../../tests/verification/invariants.json) and
[authority, effects and outbox ledger](../../../tests/README.md#authority-effects-and-outbox-evidence)
identify schedules for conflicting authority, acknowledgement loss, stale owners
and delivery. The [independent caller evidence](../../../tests/README.md#independent-caller-evidence)
tests the public boundary rather than only internal helpers. Use their recorded
commands, revision and topology when reproducing a claim.

The [declarative-authorization proof ledger](../../../tests/README.md#declarative-authorization-evaluator)
links independent role-graph fixtures, native staged-change/restart schedules,
the two-Tables/one-resource mediation proof, exact recovery after rotation,
maintained queries and exchange handoff. The
Station report (archived)
also injects native SELECT revocation after capture while leaving raw worker
reads available. These tests would falsify the claims above if a forbidden
caller obtained another Table's values, a revoked saved proof disclosed a
complete result, a partial policy candidate became effective or a retry changed
the accepted identity. They explore selected schedules rather than all possible
interleavings. They do not establish arbitrary-adapter correctness, compromised
service isolation or unbounded policy-evaluation progress.

To reproduce, use the source and pinned Nix/Zig environment named in each report,
then the recorded native authorization, restricted Table or focused integration
command from the proof ledger. The ledger owns the exact runnable commands,
observed costs and unexecuted profiles. A full repository or clean-source check
is a separate observation and does not replace these authority fault schedules.

An accepted proposal still does not prove honest computation, deadline scheduling
or successful external cancellation. Earlier rationale is retained in the
[kernel](../../history/TRANSIT.md), [streams](../../history/STREAMS.md) and
[security](../../history/SECURITY.md) records; their proposed extensions are not
additional guarantees of this model.
