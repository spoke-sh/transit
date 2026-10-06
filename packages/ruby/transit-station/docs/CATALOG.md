# General Table callers

`Transit::Station::Catalog::Client` exposes authorized schema discovery, typed
Table creation, mutations, schema evolution and retirement through the shared
native caller. Provision the catalog host, resource, ownership and caller grants
explicitly. Query connections do not enable catalog administration.

```ruby
c = Transit::Station::Catalog
scope = c::Scope.new(resource: resource, catalog: catalog_id)
connection = c::Connection.new(owner: owner, scope: scope)
c::Client.open(config, credential, connection) do |client|
  compiled = client.compile_sql(
    'CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(120), active BOOL)',
    c::Identity.new(operation: operation_id, namespace: staging_namespace), object_id)
  # Application-owned durable persistence, including the required definition.
  save_intent(compiled.saved.definition, compiled.saved.bytes)
  step = client.next(compiled.intent.reference)
  if step.kind == :send
    save_prepared(step.prepared.data)
    position = client.submit(step.prepared)
    save_receipt(position)
    progress = client.progress(compiled.intent.reference, step.prepared, position, wait: true)
  end
end
```

This example sends one step; it does not imply that the Table is published.
Continue the explicit progression described below to a terminal outcome.
`owner` and `resource` are `ProcessRef` and `ResourceRef` in one realm;
`credential` is a `Credential` in that realm. `ClientConfig` selects
`profile: :native_v1`, URL, timeout and optional trusted `native_host`. The
installed native Station gem is selected by default. Opening owns one worker and
child, loads the supplied key and checks the exact definition and capabilities.
Importing the module starts no worker and reads no credential.

## Schemas and typed operations

`Schema.new(object:, revision:, next_column:, columns:, primary_key: [])` owns
one to 128 `Column` values. Each column has a stable positive `id`, UTF-8 `name`,
[logical type](LOGICAL.md), `nullable: true`, optional logical-cell `default`,
and optional `max_characters`. Keys reference column IDs; empty keys allow
unkeyed duplicate rows. Shared Zig validates schema semantics and supports single
and composite primary keys. Object, column, operation, staging namespace and
schema/policy revisions use exact positive uint64 `Integer` values. Native
resource/process/principal/input IDs keep their separate safe-integer bounds.
Names are bounded to 255 UTF-8 bytes; SQL is bounded to 4096 bytes.

`compile_sql(sql, identity, create_object = nil)` binds SQL to the authorized
catalog and returns `Compiled(intent:, saved:)`. Supply `create_object` for
CREATE. Compilation does not admit work. `prepare(name, identity, operation)`
provides the same semantics through owned typed values:

- `Create(schema:, if_not_exists: false)`.
- `Mutate(basis:, mutation:)` with `Insert(rows:)`,
  `Update(assignments:, predicate: nil)` or `Delete(predicate: nil)`.
- `Alter(basis:, change:)` with `AddColumn`, `DropColumn`, `RenameColumn`,
  `SetDefault`, `SetNullable` or `SetType`.
- `Rename(basis:, name:)` and `Drop(basis: nil, if_exists: false)`.

Use `lookup(name).metadata.basis` for the object, metadata revision and exact
schema fingerprint. Stale bases fail without retargeting work. Assignments are
`Assignment.new(column:, value:)`, with a logical cell or `:default`; INSERT owns
one to 1024 rows, each with at most 128 assignments. UPDATE/DELETE accept a postfix
predicate array of at most 64 instructions: `Comparison(column:, op:, value:)`,
`StatePredicate(column:, state:)`, `:all`, `:negate`, `:conjunction` and
`:disjunction`. Comparison values are logical atoms. A nil predicate selects all
rows. Zig owns validation, atomicity, frozen source cuts and exact conversions.

## Saved work and outcomes

A caller owns at most one resident intent. Persist `SavedIntent.definition` and
its immutable binary `bytes` before sending any step. Restore with
`SavedIntent.new(definition:, bytes:)`, then `load(saved)`. Missing or foreign
definitions reject; there is no inferred compatibility. `forget(reference)`
releases only local intent ownership. It neither cancels nor discards accepted
work. Intents are bounded to the generated 4 MiB limit; catalog action JSON is
bounded to 16 MiB. Larger catalog port frames do not enlarge raw-client limits.

`next(reference)` returns `:send` with a `Prepared`, `:running`, `:terminal` with
an `Outcome`, or `:upload_cancelled`. Persist each exact prepared UTF-8 string
before `submit`, and the returned admitted input position afterward. Prepared
steps are bounded to 8192 bytes. `observe(prepared, position, wait: true)` observes
input processing; `progress(reference, prepared, position, wait: true)` combines
that observation with separate disposition, operation outcome and upload state.
Neither processed input nor sealed upload proves operation application.
`status(reference)` performs a read and returns `State(outcome:, upload:)`.

Terminal phases are `:applied`, `:unchanged`, `:rejected` and `:cancelled`.
Only an applied INSERT/UPDATE/DELETE has `Counts(matched:, changed:)`; unchanged
row values can produce `matched: 1, changed: 0`. Diagnostics retain the shared
semantic evidence. Original outcomes remain tied to their saved identity after
schema changes, DROP and name reuse, subject to current disclosure rights.

`prepare_resume(reference)` and `prepare_control(reference, control)` produce
explicit signed steps. Controls are `:cancel_operation`, `:cleanup_operation`,
`:cancel_upload` and `:collect_upload`. Their effects depend on durable state;
cleanup is distinct from cancellation and cannot erase retained accepted evidence.

`Catalog::Uncertain` retains the exact original `prepared`. Recreate the caller
if necessary and reconcile the identical saved command with the same connection
and credential. Do not recompile, re-sign or replace the operation while admission
is unresolved. Malformed success receipts, transport loss and result-allocation
failure preserve uncertainty. Definite native rejections retain their category,
status, code and diagnostic. Cancelling a waiting thread does not cancel accepted
work. The SDK performs no automatic submission retry.

## Policy, dependencies and metadata

`prepare_initialize(Configuration.new(scope:, owner:, administrator:,
table_limits:))` prepares the immutable host configuration. `TableLimits` requires
explicit `record_bytes`, `staging_bytes` and `staging_records` deployment quotas.
`prepare_policy(PolicyChange.new(expected_revision:, policy:))` prepares a
conditional administrator control. `Policy` owns `scope`, `principal`, `revision`
and `Rights`, whose eight explicit boolean fields are `can_inspect`, `can_create`,
`can_read`, `can_insert`, `can_update`, `can_delete`, `can_alter` and `can_drop`.
Expected revision zero denotes an absent policy. Shared Zig and the host validate
the successor revision and current authority.

`prepare_dependency(Dependency.new(scope:, object:, identity:, owner:, kind:),
present)` registers or removes a dependency. Kinds are `:query_source`, `:writer`,
`:watch`, `:maintained_relation` and `:history`. Registration does not grant access.
DROP RESTRICT retains the exact blocking dependency in its original outcome.
`input_disposition(prepared, position)` reads an administrator-control or rejected
input result; absence establishes no outcome. `describe` returns current
configuration and policy; `capabilities` returns typed generated limits.

`lookup(name)` returns a `Definition(metadata:, head:, schema:)` or nil.
`definition(object, revision)` reads an accepted immutable `HistoricalDefinition`
with metadata and schema, including after retirement; it has no current head.
Unaccepted/missing definitions are absent. `list` returns a frozen `Page` with
`resource_revision`, at most eight ordered `Entry(metadata:, head:)` values and an
optional `next` cursor. Continue while the cursor exists, including an empty
page with a continuation. Restore `Cursor` with all fields: `definition`, `scope`,
`resource_revision`, `after_object`. The cursor confers no authority or snapshot
lease; a changed cut rejects continuation. Discard that partial listing before
starting a fresh one.

Constructors own strings and nested arrays. Generated recursive schemas and public
decoders reject malformed fields, noncanonical numbers, foreign identities and
invalid page continuations. Results outlive their caller. One client admits one
operation at a time and raises `Busy` on overlap. A cancelled waiting thread
leaves native work owned; `close` joins that work and child cleanup. Block-based
`open` protects acquisition until its ensure clause owns cleanup. The API is
synchronous, with Ruby scheduling during I/O; it supplies no Fiber scheduler,
retry queue, provisioning loop or principal sequence coordinator.

The [Table reference](../../../../docs/reference/tables.md) and
[catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) own authority,
atomic publication and retention. The [proof ledger](../../../../tests/README.md)
records executed installed-gem and recovery evidence.
