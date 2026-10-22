# Processes, turns and recovery

A Transit process is a durable PID, ordered mailbox, committed progress and
lifecycle. It is not an OS process. A worker can disappear while its logical
process and accepted work remain. Replacement workers require fresh ownership;
knowing the PID never grants permission to execute it.

## One turn

1. Authenticate and acquire eligible ownership under current policy.
2. Recover committed state and the next required mailbox input.
3. Read bounded associated-state views under current resource permission.
4. Compute a private proposal in application code.
5. Submit state changes, input progress and outputs in one commit decision.
6. Observe the durable result before releasing recovery material.

The authority validates ownership generation, current permissions, prior
revision, input ordering, resource dependencies and lifecycle. It does not run
the handler or prove that the computation is correct. Invalid proposals cannot
publish part of a turn. Host fields, temporary buffers and side effects performed
outside the connector boundary are not rolled back by a rejected proposal.

The implemented state-resource boundary permits one mutated resource per turn.
Other associated resources can be read through their declared views; this does
not create an atomic multi-resource snapshot or transaction. See [state](state.md).

## Identities you must keep separate

| Identity | Meaning |
| --- | --- |
| PID | Permanent logical process identity; never reused after retirement |
| Principal and realm | Authenticated caller and administrative scope |
| Ownership generation | Fences an activation; a newer owner excludes an older worker |
| Turn/input/output identity | Orders execution and fixes delivery provenance |
| Application revision | Selected executable/compatibility declaration, not permission |
| Provider worker or pod | Physical placement, not durable execution identity |

Names and registries resolve to PIDs at the defined acceptance boundary. Rebinding
a name cannot redirect an already accepted call or its recorded reply destination.
Restoring a worker snapshot cannot renew ownership or bypass retirement.

[Manual worker handoff](../../../contracts/WORKER_HANDOFF_V1.md) records a complete
application-state check between quiescence and credential-changing activation.
It preserves current native mailbox/outbox history while fencing the old key.
The host persists its manager record and exact pending commands; missing or
corrupt recovery evidence cannot authorize a new activation.

## Admission, completion and uncertainty

A send receipt means the input was admitted. It does not mean the receiver ran
or that its domain operation succeeded. A commit receipt establishes the turn's
accepted transition; delivery and remote effects have their own outcomes.

If a response is lost, the mutation may have committed. Preserve the original
identity, canonical bytes and frozen request. Reconcile or retry that exact
operation using the [client recovery API](callers.md). Preparing a new sequence
or changing the payload describes new work. Current read permission still
governs receipt disclosure; denial cannot be interpreted as proof of rejection.

Cancelling an await, closing a console or losing a connection does not cancel
accepted work. A durable cancellation or terminal disposition needs the owning
operation's explicit contract. An external attempt can remain unknown even
after its local execution path has closed.

## Failure and retirement

A storage outage is an availability failure. Unexpected missing history is a
recovery failure. Known expiry or retirement is terminal. None allows skipping
required inputs, recreating the same PID or treating an unreachable installation
as empty. A new logical process requires explicit initialization with a new
identity.

Lifetime cutoffs stop ordinary work. Where a finite settlement contract was
recorded, only that already authorized settlement may continue. Retirement
permanently ends activation; physical cleanup may happen later. The
[retention reference](retention.md) explains checkpoints, dependencies and time.

Exact envelopes and transitions are in [native protocol v1](../../../contracts/TRANSIT_V1.md). Use [native protocol](native.md)
to select the right profile, and [Station](station.md) for behavior APIs above it.
