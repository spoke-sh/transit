# Selected work-item evolution

Epoch 1 stores `id, status` with states 0 (open) and 1 (done) in Table 1.
Epoch 2 stores `id, state` with states 10 (open) and 20 (done) in a fresh Table.
The migration plan ID also selects its target Table, so this application's plan
IDs must fit a nonzero u32 and exceed 1. This is an application command limit; the general Table identity is u64. It is
not a resident limit on work items or historical migration receipts.

Bootstrap initializes the native migration ledger and records an explicit direct
catalog binding. The data service and namespace already exist. The binding names
the realm/resource/catalog, branch, service audience, namespace, first global
Table object and owning role. Local Table N maps to `first_object + N - 1` and
`work_items_N`. An administrator explicitly prepares the source and empty target
through direct catalog DDL. Publication neither activates a target nor pauses the
source. Tables use an INT64 primary key and an INT64 NOT NULL state column.

Begin validates the application source/target commitments, requires queued puts
to finish, checks the empty target and records both Table definitions, logical
positions and row counts alongside three ledger values. It pauses Work items
commands. Application commitments bind realm, native resource, worker, layout
and state encoding; query declarations bind the actual direct Table definition.

Each copy step freezes its original native input, ordinal and arguments. A later
turn stages a complete immutable direct Table intent and commits its reference
and dispatch eligibility in one bounded native block. Only a subsequent turn
reading that committed reference may admit or execute it. Table acceptance and
native progress are separate commits. After observing the original Table
outcome, the worker advances the target basis, migration cursor and exact receipt
in three native writes. Lost replies or discarded native progress recover that
same Table operation before checking the target's now-advanced basis. They never
create another insert identity or replan a rejected operation.

The second pass verifies every target value against the original source basis
and checks complete copied/verified counts. A separately requested activation
records the selected Table and new epoch with three ledger writes in one native
four-mutation commit. Old command epochs fail closed. Activation leaves Work
items writes paused until the administrator releases the reviewed epoch and
complete target contract; interface publication remains a separate operation.

The cursor carries phase, an optional row identity and copied/verified counts.
Identity contains origin u64, operation u64 and ordinal u32, independently of the
signed integer primary key. Reads fetch one row under the exact definition and
original logical position. Accepted no-ops and physical storage changes may
advance the current frontier; a logical edit, including a change later restored,
invalidates the traversal. Exhaustion and counts both establish complete coverage.
Empty Tables, full-width keys and multiple resident pages use the same path.

The application pause does not remove direct Table privileges. Independently
authorized writers can still change either Table; subsequent conditional reads
reject that changed basis. Activation records the bases that were verified; it
does not atomically freeze both Tables with the native ledger or assert that
those bases remain current at native publication. `inspect` exposes the recorded
verification basis separately from its current Table observation. These basis
records are metadata, not retention pins. Each direct row read is bounded to one
row and 4 KiB; each dispatch record is bounded to 16 KiB. Durable rows, pending
writes and operation receipts have no fixed total-cardinality array.

Abandonment resumes epoch-1 writes but preserves the partial target, plan and
receipts. A new attempt requires a fresh Table/plan ID. Activation cannot be
abandoned or rolled back. Publication of a compatible interface is a separate
conditional owner operation; deployments must keep writes paused across any
additional configuration/publication transition. Old historical Tables are
retained; they are not implicitly deleted or made unreadable.

Commands use ordinary signed Station casts with an application-specific `WI1i`
payload. Field encoding follows the shared fixed application codec: little-endian
integers, explicitly numbered union tags, one-byte booleans and bounded Values.
Tags are initialize=0, policy=1, put=2, begin=3, step=4, abandon=5,
release_writes=6, catalog_initialize=7 and prepare_table=8.
`catalog_initialize` carries a mandatory 32-byte current definition identifier
and eight u64 binding fields: realm, resource, catalog, branch, audience,
namespace, first object and owner role. An existing binding cannot be replaced.
`prepare_table` carries a u32 local Table ID. Native roles and object privileges govern
Table access. The application migration policy independently controls which
caller may advance a migration; it does not grant Table access.

Accepted puts retain their original input, principal and selected Table in
paged native state. A later turn records the complete insert/update reference;
Table acceptance precedes removal of the pending native write. Only authenticated
owner self-messages continue DDL, puts or migration steps. The service checks the
worker's current rights independently of the original accepted input's frozen
SEND and Table requirements, including both source SELECT and target INSERT for
copying. Revocation leaves pending work intact. Inspection of already accepted
outcomes can recover native progress without rerunning the write.

The application migration policy independently gates every continuation. A
revoked policy stops progress; restoring it permits an exact step to resume.
Abandonment preserves staged references and accepted outcomes; it does not undo
or cancel already admitted data work. Native input consumption alone does not
establish Table or migration completion. The operator waits for the domain
outcome and retains its recovery file when completion cannot be observed.

The declared writer is separate from the administrator and current per-operator migration
policies. Files, reviewed plans and interface declarations confer no rights.

Each rejected input has paired records under `00 57`, application:u64be, tag `e`
or `f`, principal:u64be and native input:u64be. Their `AP1e`/`AP1f` values use the
shared migration failure record and this application's witness. Witness tags are
ledger=0 (the shared migration witness), epoch=1 (expected/actual epoch, active
plan, observed/expected contracts and expected-contract presence), cursor=2
(expected/actual commitments and byte lengths), verification=3 (copy/verify/ready
phase and copied/verified counts), state=4 (epoch, row key, supplied int64 state),
target=5 (u32 Table). The largest witness occupies 126 bytes. Cursor commitments
hash `transit.work_items.cursor.v1\0` and the exact cursor bytes.

The operator reports a semantic explanation on stderr and a structured diagnostic
with `accepted`, `committed: false` and the original cause on stdout. The native
input can be admitted while its domain command is rejected. After uncertainty,
retain the recovery file and reconcile its original signed request. A rejected
input does not cancel the migration or undo activation. Later policy changes and
successful steps do not rewrite its original evidence; current resource read
permission still applies. Stored source values outside the supported encoding
leave the input unresolved as `WorkItemSourceInvalid`, preserving tentative rows,
progress and receipts for operator recovery.
