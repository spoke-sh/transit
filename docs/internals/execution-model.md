# Execution, authorization and recovery

The central question is what evidence permits a worker to advance a logical
process after concurrency, revocation or failure. This account combines the
kernel, delivery and authorization arguments. Exact operations remain in the
[process reference](../reference/processes.md),
[native protocol](../reference/native.md) and [security reference](../reference/security.md).

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

## Progress and tradeoffs

Safety does not promise eventual handling. Progress depends on available storage,
eligible ownership, sufficient permission and capacity, retained dependencies,
and execution/delivery scheduling. A poisoned input or permanently denied output
needs an explicit disposition; skipping it would change accepted work.

Replacing durable retry identity with local task identity would simplify a
single live caller but lose the relation after caller failure. Transit instead
requires recovery material and explicit unknown outcomes. See
[client and framework ownership](client-framework.md) for the language boundary.

## Evidence and limits

The [invariant inventory](../../tests/verification/invariants.json) and
[authority, effects and outbox ledger](../../tests/README.md#authority-effects-and-outbox-evidence)
identify schedules for conflicting authority, acknowledgement loss, stale owners
and delivery. The [independent caller evidence](../../tests/README.md#independent-caller-evidence)
tests the public boundary rather than only internal helpers. Use their recorded
commands, revision and topology when reproducing a claim.

An accepted proposal still does not prove honest computation, deadline scheduling
or successful external cancellation. Earlier rationale is retained in the
[kernel](../history/TRANSIT.md), [streams](../history/STREAMS.md) and
[security](../history/SECURITY.md) records; their proposed extensions are not
additional guarantees of this model.
