# Data lifecycle and snapshot contract v1

## Scope and implementation boundary

[`DataLifecycle`](../packages/zig/transit-protocol/src/DataLifecycle.zig) owns
neutral identities, frozen operation bindings, commit evidence and snapshot
coverage descriptors. The public protocol package implements their validation;
the catalog reuses its `Scope`. The
[JSON Schema](data-lifecycle-v1.schema.json) is generated from those types.
It groups schema roots; it is not a request envelope or a service endpoint.

These types perform no storage I/O, permission checks, signing, provisioning,
execution or pin acquisition. Validating an alleged commit does not prove that
an authority accepted it. Installed Table operations retain their current
[catalog caller](../packages/zig/transit-catalog/README.md) path until their
owning runtime implements this acceptance protocol. No new SQL syntax, branch
operation or transaction session is exposed by this contract.

## Identity and interpretation

| Type | Meaning |
| --- | --- |
| `Scope` | Existing realm/resource/catalog identity; the resource identifies the logical catalog authority, independently of its persistence backend |
| `Object` | Scope, branch and stable object identity; a human name is not an identity |
| `Definition` | Exact object, immutable definition revision and interpretation digest |
| `Operation` | Scope, original principal and operation ID, frozen before submission |
| `Position` | Partition and exclusive accepted-log frontier `next_lsn` |
| `Content` | Immutable byte length and SHA-256 commitment; possession grants no permission |

Database authorization and schema namespaces retain their existing catalog/native
owners. A namespace/name binding points to an object and its definition; rename
does not change object identity. Name replacement allocates a different object.
Catalog scope does not become a new permission store. Resource IDs remain logical
identities across a storage replacement; they are not filesystem or provider IDs.

Realm, resource and principal values retain native bounds. Principal zero is a
valid identity, not an authorization bypass. Catalog, branch, object, definition
revision and operation IDs are nonzero unsigned 64-bit values. JSON consumers
must preserve their exact integer values; a JavaScript `Number` cannot represent
the full range. Host APIs may project these through their owned decimal-string
types without changing the neutral contract's meaning.

Branch identity is explicit in object/definition bindings. Its presence does not
implement branch creation, fork isolation or historical access. A future fork
must allocate its branch identity and retain the complete source basis before
publishing a writable branch head.

## Frozen intent and acceptance

`Binding` carries the mandatory current contract `definition`, operation identity,
target object, action, expected interpretation, optional expected data position
and complete canonical intent digest. CREATE has no expected definition; every
other action binds an existing exact definition. A data expectation also binds
its partition. Names are resolved before this binding is frozen.

`requireSame` compares every field. A retry with the same operation ID but altered
content, definition, target, branch or expected data position conflicts. Loading
saved work must not resolve a current name or replace an expectation implicitly.
Preview validates proposed work without reserving a name, retaining permission
or admitting an operation. The owner revalidates at acceptance.

The catalog's internal `OperationBinding` storage primitive reserves this exact
binding across object partitions. Its immutable key hashes the operation's realm,
resource, catalog, principal and operation ID; its verified bytes retain every
binding field, including target branch and object. Different content at that key
conflicts. This per-operation identity claim needs no catalog-wide root CAS.
The caller must authorize the request before claiming or disclosing it. A claim
is neither durable operation admission nor a committed/rejected/cancelled result;
only the owning operation log establishes those states. The primitive is not an
installed service endpoint.

Claim bytes are `TOPBIND1` at `0..8`, the mandatory shared definition at `8..40`,
then the canonical typed `Binding` JSON, within a total 4 KiB budget. The key is
`data-operations/<digest>.data`, where the digest is SHA-256 over the domain
`transit.catalog.operation.binding.v1` followed by a zero byte and five
little-endian `u64` values: realm, resource, catalog, principal and operation.
Lookup verifies the full object digest, current definition and exact operation
identity. Immutable conflicts compare the full stored binding; they never adopt
the caller's new target. Claim lifetime is independent of a human name or the
target's later retirement, and no cleanup operation is exposed.

### Direct catalog publication contract

The direct catalog component implements DDL admission and name publication;
installed service/SQL integration remains unfinished. Its control partition
owns immutable paged directories of objects, candidate names, operation records
and pending work. This directory is separate from each Table's data partition;
independent row writes do not change its root. The initial local profile uses
one configured catalog, branch one and disjoint control/data partition IDs.

A catalog operation freezes its binding and canonical intent before admission.
The catalog persists the intent and any required name reservation before calling
the Table owner. A candidate name resolves only when the referenced Table's
accepted, non-retired declaration contains that exact namespace/name. Staging a
declaration or accepting a reservation cannot publish a Table. RENAME makes the
new name visible and the old name unavailable at the same Table acceptance;
DROP makes its current name unavailable at that acceptance. Reusing an available
name allocates a different object and partition. Earlier operation bindings,
definitions and retained read roots never follow the replacement.

The Table log remains the authority for the successful result. Catalog cleanup
or a delayed reply must recover the original accepted declaration and outcome,
not infer success from a reserved name or use the latest Table definition.
Pending reservations block competing changes until an exact accepted result or
a recorded rejection/cancellation settles them. An uncertain Table append must
be recovered and checked before recording rejection or cancellation. A late
cancellation returns the committed result; it cannot undo it. Private staging
failure preserves admitted intent and its recovery identity.

The service serializes catalog DDL and checks current native authorization at
admission, publication and disclosure. Native database/schema/Table domains
remain the policy authority; native registration and catalog publication are
distinct durable steps. Names, object directories and operation claims grant no
rights. Read-only inspection starts no provisioning or execution. Listing across
Table heads is an independent observation vector, not a catalog-consistent data
snapshot. Retained single-Table reads bind that Table's accepted declaration and
data together; cross-owner transactions require their own coordination contract.

The initial execution domain is one Table owner and one statement/batch. The
owner serializes accepted changes and checks definition/data expectations and
the selected statement's conflicts at its commit point. Validation/rewrite work
may stage bounded private objects before publication. Readers observe the whole
committed successor, not a successful prefix of the statement.

Catalog-scoped transaction sessions require an explicit read/write set,
schema/predicate conflict validation and an atomic publication decision for the
selected owner domain. Independently accepted partition writes are not such a
transaction. No distributed cross-owner atomicity follows from this contract.
Native turns keep their existing input/one-resource/output commit boundary.

Both ingestion forms end in `Commit`:

- Point writes record the accepted mutation and exact result in the owning log
  before acknowledgement; the memtable reflects accepted records.
- Bulk writes first stage immutable objects. The acceptance record binds their
  verified references, operation and result. Uploading an object alone publishes
  no rows. The owner rechecks schema, policy and conflicts after staging.

The durable acceptance record is the linearization point for the admitted
single-partition profile. It binds data changes or segment references and the
recoverable operation result atomically. A manifest checkpoint records coverage
of that history; it cannot introduce an independently writable authority.
Multi-writer publication must preserve this same ordering and define conflict
disposition before admitting that profile.

`Commit.validate` checks attribution, a nonempty advancing commit frontier and
definition succession. DML retains its exact definition; ALTER/RENAME/DROP publish
a later definition, and CREATE begins at revision one. The owner still verifies
the content commitments, current authorization, writer fencing, constraints,
logical history and durable result storage. A rejection/cancellation that wins
before commit must itself be recorded under the original operation identity.

`Observation` distinguishes unavailable or denied observation, no observed record,
admitted work, committed data, rejection and cancellation. Neither a timeout nor
a missing observation establishes rejection. Cancellation cannot undo a committed
operation. Staging failure must preserve admitted work and its recovery identity.

## Snapshot coverage and retention

`SourceCut` binds an exact definition, optional immutable manifest, checkpoint
frontier and accepted frontier. Both frontiers use exclusive offsets:

- Checkpoint objects reconstruct accepted log entries `[0, checkpoint_lsn)`.
- WAL/history coverage retains `[checkpoint_lsn, accepted.next_lsn)`.
- A checkpoint cannot exceed the accepted frontier.
- Without a manifest, checkpoint coverage is zero; a WAL-only accepted basis is
  valid and still needs retention.

Flushing is a physical rewrite of the same accepted basis. It may reduce the
tail required for recovery only when the replacement objects and their root are
durable and reachable. A maximum observed LSN is not proof of contiguous coverage.
State checkpoints alone do not preserve every logical change: `A -> B -> A`
still requires both transitions for an every-change consumer.

`Snapshot` binds a catalog root, an immutable paged source directory, source
count, branch and pin-owner operation. Source count is independent of resident
array size. Its consistency is explicit:

- `single_partition`: every source has exactly the same partition and accepted
  frontier. The owner must capture definitions and data at that same cut.
- `independent`: each source is exact, with no promise of a global or causal cut.

Do not relabel an independent vector as catalog-consistent. Cross-partition
consistent acquisition needs its own coordination and evidence; ordinary
independent writes must not acquire a global catalog-root CAS merely to advance.

A descriptor is not a durable pin. Before publishing a snapshot root, its owner
must durably retain every referenced definition/object and required WAL/history
range. Partial acquisition retains recoverable progress under the same owner;
it does not publish a complete snapshot. Restart reconstructs pin ownership.
Release/abandonment and cleanup require recorded state and current permission.
Compaction/GC cannot remove a source reachable by a retained pin. Physical trim
must also preserve accepted receipts, native recovery/effect evidence and
complete-change consumers. Logical expiry remains opt-in.

## Compatibility, bounds and evidence

`Binding` and `Snapshot` require an explicit contract definition; decoding never
defaults a missing field to the current build. `Commit` carries the binding's
definition. A source-directory entry is interpreted only under its enclosing
validated snapshot root. Incompatible stored interpretation requires the shared
[v1 hard cutover](../docs/handbook/reference/versioning.md), preserved originals
and coordinated consumers. No decoder fallback or automatic reset is provided.

All descriptors own their scalar/fixed-array fields. Durable collections use
paged storage; staging, acquisition, queries and maintenance need separately
enforced per-operation and resident budgets. Operation identity, retained pins
and backlog cannot be stored in fixed total-cardinality arrays.

The [independent fixture](../packages/zig/transit-protocol/src/fixtures/data-lifecycle-v1.json)
and [contract tests](../packages/zig/transit-protocol/src/data_lifecycle_test.zig)
exercise identity conflicts, definition succession, full-width IDs, mandatory
compatibility fields, unflushed coverage and inconsistent-cut rejection. They
qualify descriptor validation only. Durable acceptance, interrupted pin
acquisition, policy races, process crashes and installed caller behavior require
the owning runtime's separate evidence in the [proof ledger](../tests/README.md).
