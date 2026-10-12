# Recorded manual worker replacement

`WorkerHandoff` implements the [manual handoff contract](../../../../contracts/WORKER_HANDOFF_V1.md)
for an unbound PID with one writer-owned application resource. It produces pure
record transitions and native commands; the host owns persistence, transport,
current dependency checks, key delivery and physical instance attribution.

Create a `Plan` with exact native identities, key/permissions, generation,
replacement key, application binding, instance identities and finite suspension
deadline. Persist `Record.start(plan)`. At `planned`, `checkpointed` and
`restored`, `command()` returns the required native operation. Save its exact
signed request before dispatch and retain it until receipt reconciliation and
the next manager record are durable.

After quiescence, call `snapshot` through a current `ResourceReader` with an
explicit page budget, then `capture` with the digest and observed process. After
the conditional resume fence, rescan state and revalidate the application's
current dependencies before `restored`. Observe activation with the replacement
credential. Record old-instance retirement after attributed shutdown/absence
evidence. Provider-bound PIDs use the runtime controller's separate contract.

Recover with `Record.restore`; missing records are errors. Reconcile exact
pending native requests before fresh ones. Old-key requests cease to authenticate
after rotation, including duplicate receipts. Recover accepted application work
from current history without resetting inputs, output destinations or cursors.

The 8 KiB manager record and explicit scan-page budget do not impose a total
durable collection bound. No retention policy, automatic placement, distributed
authority or new SDK/ABI operation is introduced by this typed Zig interface.
