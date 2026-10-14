# Authority time and control capacity

[transit-core](../README.md)

## Validation and publication

The authority authenticates and checks retry identity once on the normal
`submit` path. A private preparation continuation uses that exact recovered head;
it is not a public authentication bypass or a reusable permission cache. The
publication's conditional append rejects any intervening operation, including a
revocation. Public `prepare` independently authenticates before returning its
candidate. Exact retries still check current permission before returning evidence.

Unit schedules insert a competing revocation at the storage append boundary of
`submit` itself. The proposal loses, its input/progress stays unchanged, and a
subsequent retry sees the current denial.

## Deadline enforcement

The selected contract permits previously authorized work to settle within a
bounded window. There is no requirement that every physical storage
write finish before the earlier cutoff for starting work. Final settlement
closure is irreversible: it rejects late results, even if the request originally
started on time. A historical receipt can still be read under current permission;
returning that receipt is not accepting a new result.

Keep the upstream Ursula API unchanged. Transit must record the authorized work,
its finite settlement rights, and closure in the same authority ordering. A
worker's prepared proposal or claimed timestamp is not a durable settlement
grant. Closure and result acceptance race through conditional append: once
closure wins, an old prepared result cannot append or reopen the attempt.

The [implemented profile](../../../../contracts/TRANSIT_V1.md#integration-obligations)
uses trusted validation time at the expected journal tail as the authorization
boundary. Its recorded uncertainty must fit the realm's configured bound.
Persistence may finish later; an intervening closure or policy operation fences
the candidate and forces fresh validation. A result first validated after its
window is rejected even if a closure controller is delayed. Clock rollback below
the durable high-water mark fails closed. This is an explicit authorization-time
contract, not a guarantee that all physical writes stop at the UTC cutoff.

The executable proof uses controlled time. A deployment still needs a trustworthy
synchronized source and periodic maintenance; ordinary host wall-clock readings
do not establish a UTC error bound. Reject finite contracts without the required
realm opt-in and time source. Replay applies recorded time evidence.

The node's [clock integration](../../../../apps/transit-node/docs/operations.md#time-and-deadlines)
provides the supported Linux time source and states its deployment assumptions.

## Finite admission and control capacity

Genesis accepts `admission_ceiling` (2–65,536 journal positions, unset by default)
and `control_reserve` (0–65,536, default 4,096). After the admission ceiling, new
processes, sends, grants, resources, views, associations and effect dispatches
are refused. Turns cannot add new outputs or effects from the reserve.

The reserve permits operations that resolve existing work: ownership reassignment,
revocation, retry, termination, expiry, retirement, reclamation, bounded collection,
delivery, effect observation/closure, provider stop/reconciliation, opted-in
checkpointing and output-free turns. All still require current permission and
ordinary validation. At the ceiling plus reserve, new commands fail with
`ControlCapacity`. Authorized reads and exact retained receipts remain available.
An input that needs a new view or effect remains pending; capacity cannot cancel it.

This is an explicitly configured allowance. Growing catalogs do not supply a
fixed total-cardinality formula for the work needed to retire every object.
Repeated accepted controls consume the same allowance. Operators must size both
journal and physical storage headroom for their workload; the node does not
reserve disk space automatically. Transport retries and temporary storage files
can consume physical capacity independently of accepted journal positions.

Authorization revocation, credential disablement/rotation, role/object retirement
and candidate abandonment use this control reserve. Creation, new grants and
privilege expansion require ordinary admission capacity. Staged changes retain
their classification through advance and publication. Genesis separately fixes
`authorization_limits` for each graph decision and `authorization_change_quota`
for each staged change; the [authorization contract](../../../../contracts/AUTHORIZATION_V1.md#bounded-evaluation-and-storage)
states their bounds. These limits do not cap durable graph cardinality.

Capabilities report the ceiling, reserve and current position. Checkpoint, trim
and restart preserve their accounting and cannot reopen admission. Online
expansion or rearming is unsupported. The
[proof ledger](../../../../tests/README.md#growing-physical-capacity) records the
executed disk exhaustion and recovery schedule and its measured limits.
