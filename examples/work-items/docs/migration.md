# Selected work-item evolution

Epoch 1 stores `id, status` with states 0 (open) and 1 (done) in Table 1.
Epoch 2 stores `id, state` with states 10 (open) and 20 (done) in a fresh Table.
The migration plan ID also selects its target Table, so this application's plan
IDs must fit a nonzero u32 and exceed 1. This is an application command limit; the general Table identity is u64. It is
not a resident limit on work items or historical migration receipts.

Bootstrap initializes the migration ledger, initializes its catalog, then explicitly
prepares Table 1 through the general catalog DDL owner. These are distinct native
inputs. An administrator prepares the empty target before beginning a migration;
publication alone neither activates it nor pauses the source. Tables use an
INT64 primary key and an INT64 NOT NULL state column. The application selects
4 KiB immutable records, eight staging records and a 32 KiB staging quota per
Table; retained rows and operation histories have no total-cardinality cap.

Begin checks the complete application source/target commitments, verifies the
empty prepared target, requires accepted writes to finish, and records its three
ledger values while pausing normal writes. Application commitments bind realm,
resource, owner, Table schema and state encoding. Query declarations separately
bind the actual published catalog metadata. Each copy step freezes its original
ordinal and arguments, then stages one transformed row. Its final turn publishes
the Table head, Table outcome, migration progress and exact step receipt in four
writes. A second pass over
the target verifies every value against the unchanged source and checks the
copied/verified counts. Only a separately requested activation can change the
active Table and epoch. The ledger's three activation writes and one Table
selector share one native four-mutation commit. Old command epochs fail closed. Activation leaves normal writes paused until
the administrator explicitly releases the reviewed epoch and complete target
contract. This lets a deployment publish and verify its compatible interface
before reopening writes. Release is an explicit administrator decision, not an
inferred or atomically verified cross-owner publication.

The durable cursor carries phase, an optional stable row identity and two counts.
The optional identity contains origin u64, operation u64 and ordinal u32; it is
independent of the user's signed integer key. Each turn reads one row after it: the exclusive data owner
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
Tags are initialize=0, policy=1, put=2, begin=3, step=4, abandon=5,
release_writes=6, catalog_initialize=7, prepare_table=8 and read_policy=9.
`prepare_table` carries a u32 object ID. `read_policy` carries principal, expected
revision and next revision as u64, followed by an allow bool, and grants only
catalog inspect/read. Migration, catalog and native permissions remain distinct.

Accepted puts retain their original native input, principal and chosen Table in
paged state. A later turn freezes insert/update identity before staging. The
Table receipt and removal of that queued work commit together. Only authenticated
owner self-messages continue DDL, queued puts or admitted migration steps. A
revoked migration policy stops continuation while preserving the pending step;
restored policy permits an explicit exact step to resume it. Abandonment retains
unpublished staging for separate cleanup. Native input consumption alone is not
Table or migration-step completion. The operator waits for the respective domain
outcome and retains its recovery file if completion cannot be observed.

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
