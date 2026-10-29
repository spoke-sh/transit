# Station behaviors, names and supervision

Station is the application framework above the Transit client. It offers
GenServer-style behavior, durable calls, scoped names, supervision and typed
state helpers. It does not replace kernel permission checks or run your handlers
inside the node. Start with the [ledger example](../../../examples/station-ledger/README.md)
or the [SDK examples](../../../examples/station-sdk/README.md).

## Behaviors and calls

A behavior handles the next accepted input in a private turn. Persist the data
needed after restart, emit outputs through the turn and observe its commit.
Local callbacks, fields and host tasks are not durable workflow state.

A call records correlation and its original reply destination. Caller recovery
resumes that durable identity; restarting a host task must not issue an unrelated
call. Replies, timeouts and closure use recorded protocol outcomes. Cancelling a
host await does not undo the receiver's accepted work or imply remote cancellation.
Follow [caller ownership and recovery](callers.md) when implementing a runner.

## State helpers

Station Table helpers provide application-private typed state and finite queries
above a native state resource. They publish no catalog name; SQL catalog Tables
use the separate direct Table owner.
Documents add accepted structured/text changes with explicit merge conflicts.
They share growing storage/read/publication primitives; a handler still has the
one-mutated-resource turn boundary. A Table batch can be atomic within that
resource without creating a cross-resource transaction.

Handlers use native v1 bounded pages and retained call/query records independently
of resident worker memory. Configure per-operation and active-work budgets;
retained collections do not become resident queues.

The ledger example uses the direct Table service for its data and a separate
associated resource for application progress. It commits an immutable operation
reference before dispatch, recovers that operation's Table receipt, then commits
its audit entry and reply together. Table acceptance and the native reply are
separate transactions. The example's saved binding identifies the catalog,
branch and Table; replacing a worker cannot redirect accepted work to a different
object. See [Tables](tables.md) for direct operation and retained-read semantics.

## Names and registries

A registry namespace is an application naming scope, not a security realm.
Lookup needs current rights. Registration/rebinding is a durable, conditional
operation; names map to logical PIDs, not whichever OS worker is currently alive.

Resolve an accepted call's destination according to its contract and preserve it
through delivery and recovery. Rebinding a name or replacing a worker cannot
redirect accepted work. Stale cleanup must be conditional so it cannot erase a
newer binding. Name removal does not itself delete the old process or its history.

## Supervision and time

Station supervision expresses logical child/lifecycle intent. Runtime providers
and local supervisors reconcile physical execution. A restart can replace a
worker for an eligible PID; retirement requires a new PID and explicit bootstrap.
Supervisor state cannot grant a child missing permissions or revive expired work.

Timers provide recorded scheduling input. Deadline enforcement cannot rely only
on a timer being delivered to a sleeping mailbox. Suspension must fit the
process's required recovery-resource lifetime. Capacity shortage is a blocked
condition, not permission to expire a child or discard its accepted messages.

The [Station package](../../../packages/zig/transit-station/README.md),
[Station wire contract](../../../contracts/STATION_V1.md) and
[SDK index](sdks.md) describe the APIs and supported interfaces. See
[deployment](deployment.md) for provider placement and [retention](retention.md)
for terminal lifecycle rules.
