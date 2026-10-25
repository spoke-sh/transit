# Direct catalog lifecycle

`Transit::Station::Catalog::Client` exposes direct Table definitions, row changes,
current inspection and explicit snapshot retention through the shared Zig caller.
SQL compilation and typed preparation freeze work without reserving names or
accepting changes. Provision the catalog service and native grants first.

```ruby
c = Transit::Station::Catalog
scope = c::Scope.new(resource: resource, catalog: catalog_id)
connection = c::Connection.new(scope: scope, audience: audience, branch: 1)
c::Client.open(config, credential, connection, service_url: service_url) do |client|
  work = client.compile_sql(
    'CREATE TABLE people (id BIGINT PRIMARY KEY, name UTF8)',
    c::Identity.new(operation: operation_id, namespace: 1), object_id)
  save_durably('intent', work.saved.save)
  inspect_preview(client.preview(work.intent))
  original = client.stage(work.intent)
  save_durably('reference', original.save)
  observed = client.admit(original)
  while observed.state == :admitted
    observed = client.execute(original, steps: 32)
  end
  inspect_outcome(observed)
end
```

`save_durably`, `inspect_preview` and `inspect_outcome` are application functions.
The application supplies distinct operation IDs and continuation budgets. Staging,
admission and completion are separate. A committed Table operation reports its
resulting definition, accepted position, `matched`, `affected` and `live_rows`.
Conditional name assertions report a catalog position and `:unchanged`,
`:rejected` or `:cancelled`, without inventing a Table commit.

Connections contain the scope, service audience, branch and optional selected
role. Credentials supply the principal; no actor PID participates in these
operations. Catalog, branch, object, operation, definition, data-position and
row-count values use exact uint64 Ruby `Integer` values. Realm, resource,
principal and namespace counters retain their native safe-integer bounds.
`ClientConfig` selects `profile: :native_v1`, the authority URL, timeout and
optional trusted `native_host`. `service_url` defaults to the authority URL.
Both URLs exclude user information, query strings and fragments. The native
caller accepts timeouts from 1 through 60000 milliseconds.

Opening owns a worker and native child, loads the supplied key and checks the
exact current definition and capabilities. It initializes no catalog and grants
no rights. Importing the module starts no worker and reads no credential.

## Schemas and exact work

`Schema.new(object:, revision:, next_column:, columns:, primary_key: [])` owns
one to 128 columns with stable IDs, names, [logical types](LOGICAL.md), nullability,
optional defaults and character bounds. Encoding and collation are independent
physical descriptors. New columns default to `:plain` encoding and `:none`
collation; returned schemas require both fields explicitly. Shared Zig validation
owns supported combinations and conversion semantics. Empty primary keys allow
unkeyed duplicate rows. Names are at most 255 UTF-8 bytes; SQL is at most 4096.

`prepare(name, identity, operation)` accepts these typed operations:

- `Create(schema:, if_not_exists: false)`.
- `Mutate(basis:, mutation:, ingestion: :point)` with `Insert(rows:)`,
  `Update(assignments:, predicate: nil)` or `Delete(predicate: nil)`.
- `Alter(basis:, change:)` with `AddColumn`, `DropColumn`, `RenameColumn`,
  `SetDefault`, `SetNullable`, `SetType` or `SetPhysical`.
- `Rename(basis:, name:)` and `Drop(basis: nil, if_exists: false)`.

Use the complete `lookup(name, namespace: 1).basis` for existing-object actions.
`Basis.save` and `Basis.restore(text)` preserve the connection, namespace, name
and exact stored interpretation. Stale definitions reject without redirecting
work to a newer definition or a same-named replacement.

Assignments address stable column IDs with a logical cell or `:default`.
INSERT owns one to 1024 rows with at most 128 assignments each. UPDATE and DELETE
accept at most 64 postfix predicate instructions: `Comparison`, `StatePredicate`,
`:all`, `:negate`, `:conjunction` and `:disjunction`. A nil predicate selects all
rows. `ingestion: :bulk` stages immutable data through the direct service.
`compile_sql` accepts `dialect: :transit` or `:mysql` and `ingestion: :point` or
`:bulk`. Supply its third `create_object` argument for CREATE.

Schema and mutation conversion charge each fragment before building more values.
Schemas are bounded to 2 MiB; complete saved work and action frames obey the
generated `catalog_intent_bytes` and `catalog_action_bytes` limits. Catalog port
framing accommodates direct batches larger than actor frames. The
[Table reference](../../../../docs/handbook/reference/tables.md) describes the
executable storage and codec profiles.

## Saved work and outcomes

Save `SavedIntent.save` before staging. `SavedIntent.restore(text)` and
`load(saved)` restore local work without recompilation. Save `Reference.save`
before admission; `Reference.restore(text)` supplies the original binding for
`inspect`, `execute` and `cancel`, including after DROP/name reuse. Missing or
foreign definitions reject. One local intent can be loaded at a time.
`forget(intent)` releases that local ownership without cancelling accepted work.

`:not_observed` is distinct from admission, rejection, cancellation and commitment.
An observation's original binding must match the reference. `Uncertain` retains
`.original`, which is the saved intent for staging, operation reference for
admission/execution/cancellation, acquisition for pinning or snapshot for release.
Persist that value and recover the same identity. Malformed successful replies,
transport loss after mutation dispatch and reply allocation failure preserve
uncertainty; they do not imply that accepted work failed.

## Inspection and explicit retention

`capabilities`, `describe`, `namespace(id)`, `namespaces(cursor)` and
`tables(namespace: 1, cursor: nil)` expose current catalog observations.
Descriptions contain native policy revision and authenticated subject separately.
Pages contain at most eight entries. Cursors bind the original connection,
selection and directory position; a changed directory requires a fresh scan.
Table observations have `:independent` consistency, not a shared transactional cut.

A retained snapshot requires an explicit saved acquisition:

```ruby
metadata = client.lookup('people')
acquisition = client.prepare_snapshot(metadata.basis, metadata.position, pin_id)
save_durably('acquisition', acquisition.save)
snapshot = client.acquire_snapshot(acquisition)
save_durably('snapshot', snapshot.save)
retained = client.snapshot_metadata(snapshot)
# Persist cleanup responsibility before releasing the original handle.
client.release_snapshot(snapshot)
```

After a lost acquisition reply, restore the acquisition and call
`snapshot_status(acquisition.owner)` to recover its original snapshot.
`Snapshot.restore(text)` restores a saved handle. Status reports current Table
interpretation and position separately from the snapshot's retained metadata.
`snapshot_metadata` returns the accepted interpretation, schema and row count,
including after ALTER, DROP and name reuse. Its authorization object IDs do not
grant access; each remote read checks current rights. Ruby exposes retained
metadata through this API; it has no interactive relational cursor API.

Release is explicit and idempotent for the original snapshot. After a lost
release reply, inspect the same owner's status and retry the original release.
Closing the client does not release durable snapshots. Retention does not acquire
an automatic expiry, and applications retain cleanup responsibility.

The worker admits one operation at a time. Cancelling a waiting Ruby thread does
not cancel or disown admitted work. `close` joins the active operation and child
cleanup before returning. `Client.open` ensures that cleanup around a block.
