# Selected work-item evolution

Epoch 1 stores `id, status` with states 0 (open) and 1 (done) in Table 1.
Epoch 2 stores `id, state` with states 10 (open) and 20 (done) in a fresh Table.
The migration plan ID also selects its target Table, so this application's plan
IDs must fit a nonzero u32 and exceed 1. This is a Table identity encoding limit,
not a resident limit on work items or historical migration receipts.

Begin checks the complete source/target UQS1 contracts and pauses normal writes.
The target descriptor and three ledger records commit together. Each copy step
writes at most two rows, plus its progress and exact receipt. A second pass over
the target verifies every value against the unchanged source and checks the
copied/verified counts. Only a separately requested activation can change the
active Table and epoch. The ledger's three activation writes and one Table
selector share one native four-mutation commit. Old command epochs fail closed. Activation leaves normal writes paused until
the administrator explicitly releases the reviewed epoch and complete target
contract. This lets a deployment publish and verify its compatible interface
before reopening writes. Release is an explicit administrator decision, not an
inferred or atomically verified cross-owner publication.

The durable cursor carries phase, an optional last row key and two counts. Each
turn opens a fresh bounded Table page after that key: the exclusive data owner
and explicit write pause establish stable contents across these distinct read
positions. This is not reuse of a snapshot cursor across revisions. Empty tables,
negative/full-width row keys and more than one resident page are supported.

Abandonment resumes epoch-1 writes but preserves the partial target, plan and
receipts. A new attempt requires a fresh Table/plan ID. Activation cannot be
abandoned or rolled back. Publication of a compatible interface is a separate
conditional owner operation; deployments must keep writes paused across any
additional configuration/publication transition. Old historical Tables are
retained; they are not implicitly deleted or made unreadable.

Commands use ordinary signed Station casts with an application-specific `WI1i`
payload. Field encoding follows the shared fixed application codec: little-endian
integers, explicitly numbered union tags, one-byte booleans and bounded Values.
Tags are initialize=0, policy=1, put=2, begin=3, step=4, abandon=5, release_writes=6. The declared
writer is separate from the administrator and current per-operator migration
policies. Files, reviewed plans and interface declarations confer no rights.
