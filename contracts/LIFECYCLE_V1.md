# Process lifecycle controls v1

Implemented M8 extension under `Command.lifecycle`. [Transit](TRANSIT_V2.md)
remains the execution authority; [Station](../docs/reference/station.md) owns behavior policy.

## Initialization

`create` takes the existing spawn fields plus `required` (four optional distinct
association names, each 1–32 bytes) and `collect_catalog=false`. It allocates a PID
in the running lifecycle with `control.phase=initializing`. Collection opt-in is
validated at creation against `allow_trim` and the realm receipt policy.
Legacy `spawn` remains immediately ready; it does not acquire a new barrier.

Messages can queue during initialization, but ownership, activation, turns and
new application effects cannot execute. A trusted provisioner creates empty state
resources, assigns grants, and installs required associations. `initialize:
{pid, expected_generation}` checks each declared name is a required association to
a currently usable resource, records readiness and advances the generation. A
missing association cannot be interpreted as an empty/default initialized state.
Declared requirements remain checked at execution boundaries after initialization.

Every allocation/completion is a separately signed sequenced operation. The
provisioner must save/retry the exact pending request before allocating the next
object; the ordinary receipt contract recovers a lost spawn/resource response.
Transit does not infer an uncertain allocation from names or enumerate a new PID
as a substitute. Termination can abandon an incomplete initialization explicitly;
resource retention and optional catalog collection then follow their contracts.
Initialization here is an execution barrier, not an application initializer or
atomic multi-resource setup. Station still owns schema content, child intent
records and failure policy.

## Scoped administration and retry

`create` requires spawn permission. Other lifecycle controls require current
admin permission for the PID, independently of execution ownership. PID-scoped
administrators can initialize/retry/suspend their process; they cannot change
realm grants or administer other PIDs. Root-only grant/resource-grant provisioning
remains a trusted role. Ordinary behavior workers need no administrative key.

`retry: {pid, expected_generation, failure}` names the exact recorded failure
position. It clears that block and fences the old generation without consuming,
skipping or rewriting the failed head input. New ownership is a separate step.
Wrong failure IDs, stale generations, missing dependencies and expired processes
are rejected. Retry limits, poison-message policies and deciding to replace a
child instead are Station/application policy. Logical termination still requires
a new PID; retry does not resurrect retired processes.

## Suspension and recovery

`suspend: {pid, expected_generation, resume_before_ms}` records a finite recovery
window, requires trusted authority time, and fences ownership/read views. It
cannot interrupt an outstanding finite turn permit. The bound must be future
and no later than the process work cutoff or any required resource's effective
lifetime. A new required association during suspension must also fit the bound.
A suspended process can receive messages within its contract but cannot execute
handlers or authorize new effects.

`resume: {pid, expected_generation}` succeeds only before the recorded bound and
with usable required state. It preserves the PID, advances the generation and
requires fresh ownership. The deadline is a latest resumption time, not a timer
or a request to resume automatically. Once resumed, normal process/resource
lifetimes continue; an expired suspension can never be extended or resumed.

Time-sensitive boundaries reject expiry even if maintenance is delayed.
`expire_suspension: pid` records permanent expiry after the bound, including unread
input disposition and dependent resource retirement. Owned state also observes
its owner's suspension bound on reads/turns before this background transition.
Already authorized connector attempts retain their independent reconciliation
contract; closure is not remote cancellation. After the mailbox window closes,
late connector outcomes can remain attempt evidence without becoming new input.

A provider-bound process must be confirmed stopped before retry/resume requests a
new running intent on the **same** binding/resource. The controller reconciles
that recorded intent and obtains a fresh activation; the lifecycle command itself
does not prove physical stop/start. Initializing/suspended/blocked/retired processes
make the runtime controller stop instead of reactivating them.

The pinned Substrate profile requires a fresh worker pod UID as well as a new
signing key. Cold boot alone can reuse the same pod and is insufficient. Placement
must replace the old worker capacity before resumption; the reference launcher
and qualification do this explicitly. The controller reports `StaleWorkerIncarnation`
if it observes reuse. Automatic pool replacement is not part of logical resume.

The finite-admission profile reserves terminal/control progress, not arbitrary
continued operation: after its ceiling, create/initialize/retry/suspend/resume are
rejected. Due suspension expiry and termination remain eligible. Collection does
not reopen this one-shot admission budget; callers must surface capacity closure.

## Compatibility and evidence

`ProcessView.control` is null for legacy processes. New control state and catalog
opt-in survive checkpoints; absent defaults preserve old checkpoint encoding.
New reads require matching clients/Board; new operations preclude authority
downgrade. Upgrade the bundled services and callers together. No automatic schema
migration, lifecycle subscriptions, timers or supervisor policy is introduced.

Core proofs cover lost initialization receipts, missing requirements, scoped
administration, stale proposals, blocked-input retry and expired resumption.
`just test::storage` interrupts resource provisioning and blocked execution, then
recovers, retries the same input, checkpoints/trims a suspension and proves its
permanent expiry after restart. Board shows generic phase, resumption bound and
collection policy; it does not interpret application state.
