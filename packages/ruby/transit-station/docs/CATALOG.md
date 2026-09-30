# Catalog callers

`Transit::Station::Catalog::Client` exposes initialization, conditional policy,
named Table creation and saved-command recovery through the shared native port.
Provision the catalog host, native resource, ownership and caller grants
explicitly. Query connections do not enable catalog administration.

```ruby
c = Transit::Station::Catalog
scope = c::Scope.new(resource: resource, catalog: catalog_id)
connection = c::Connection.new(owner: owner, scope: scope)
c::Client.open(config, credential, connection) do |client|
  compiled = client.compile_sql(
    'CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)',
    operation_id, object_id, table_id)
  prepared = client.prepare_create(compiled.request)
  save_prepared(prepared.data) # Application-owned durable persistence.
  position = client.submit(prepared)
end
```

`owner` and `resource` are `ProcessRef` and `ResourceRef` in one realm;
`credential` is a `Credential` in that realm. Use `ClientConfig` with
`profile: :native_v1`, URL, timeout and optional trusted `native_host`. The
installed native Station gem is selected by default. Opening starts one owned
worker and child, loads the supplied key and checks the exact definition and
catalog capabilities. Loading the module starts no worker and reads no credential.

Catalog, operation/object IDs and policy revisions are full-width positive
uint64 `Integer` values. Native IDs keep their separate safe-integer bounds;
the physical Table ID is a positive uint32. `Schema` copies and freezes two
names and accepts a value type of `:int64`, `:boolean`, `:utf8` or `:binary`.
Compilation requires an explicit non-null int64 key and an explicitly nullable
value. It is offline after caller creation: no identity is reserved and no
authority is granted. `Compiled.canonical` holds owned frozen bytes for review;
preparation takes the complete typed `Compiled.request`.

## Explicit preparation and outcomes

`prepare_initialize(Configuration.new(scope:, owner:, administrator:))` prepares
the exact immutable host configuration. `prepare_policy(PolicyChange.new(
expected_revision:, policy:))` prepares a conditional administrator control.
Construct `Policy` with `scope`, `principal`, `revision`, `can_inspect` and
`can_create`; expected revision zero denotes an absent policy. Shared Zig
validates successor revisions and current metadata. The host rechecks rights
and conditions at application. `describe` reads currently authorized configuration
and policy. `capabilities` returns typed local limits and operation flags;
`initialize_catalog` names the initialization flag.

Every preparation returns `Prepared` with owned frozen canonical UTF-8 text,
bounded to 8192 bytes. Persist `data` unchanged before submission. Recover with
`Prepared.new(data: saved_text)`; shared Zig validates the exact definition,
connection, signed frame and signature before dispatch. Only `submit` dispatches,
returning the admitted input position. It does not rewrite the prepared command.

Use `observe(prepared, position)` for `:pending`/`:processed` input, then inspect
the separate outcome. `input_disposition` returns an initialization, policy or
rejected-input outcome, or `nil`; absence proves no outcome. `status(original)`
returns the original creation receipt or `nil` and checks that the complete
request matches. Only `:applied` establishes publication. Name, object and Table
conflicts are distinct terminal outcomes. Current catalog and native rights
still gate disclosure of old results.

`Catalog::Uncertain` retains the original `prepared`. Recreate the caller if
necessary and resubmit the identical saved text with the same connection and
credential. Do not parse/re-encode, re-sign or replace it while admission remains
unresolved. Missing or malformed success receipts and allocation failure during
submission preserve uncertainty. Definite
native rejections retain their category, status and code. Dropping local recovery
data or cancelling a waiting thread does not cancel accepted work.

Value constructors copy and freeze strings and nested names. Generated schemas
validate requests and responses; public adapters check canonical full-width
values, enums, bounds and original-request matching. Each client admits one
operation at a time and raises `Busy` on overlap. A cancelled waiting thread
does not release active ownership. `close` joins work and child cleanup;
block-based `open` protects acquisition until its ensure clause owns cleanup.
This is a synchronous API with ordinary Ruby scheduling during I/O, not a Fiber
scheduler adapter. There is no retry queue, provisioning loop or principal
sequence coordinator. Keep recovery text independently of host threads.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
atomic publication and authority. The [proof ledger](../../../../tests/README.md)
records installed-gem recovery, malformed-child and cancelled-wait checks.
