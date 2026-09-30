# transit-catalog

Named state definitions and conditional creation above Station, exported as
`transit_catalog`. The library depends directly on `transit-station`; it uses
Fuze's shared declaration compiler and the existing Table schema and turn APIs.
The catalog helper performs no I/O. Its signed caller uses the public native
client; neither component discovers credentials or dispatches connector effects.

`Model.CreateTable.compile` checks SQL and produces an owned typed request.
`Catalog.createTable` atomically proposes an empty Table, immutable definition,
name binding and exact operation receipt in four mutations. Separate current
create/inspect policies gate publication and metadata. `lookup`, `definition`,
`receipt` and `list` expose bounded metadata; list cursors bind resource revisions.
Catalog cardinality is independent of resident page size.

`Inspection` shares deterministic definition, binding, live-schema and page
validation between those in-turn helpers and the signed `Client`. It reads one
authorized resource cut and rechecks catalog inspection policy before resolving
names or consuming continuation. Its values confer no native read authority.

`Client` supplies current metadata, `prepareInitialize`, `prepareCreate`,
`preparePolicy`, explicit signed submission,
input observation and original-request status. Its owned `Prepared` values save
and restore exact canonical bytes with mandatory definition checks. Submission
does not re-sign uncertain work. Current create and inspect policies remain
independent; admission, processing and application are separate outcomes.
`Client.lookup`, `definition` and `list` expose current metadata without acquiring
a view or submitting work. Lists contain at most eight ordered definitions and
bind continuation to the exact resource revision. A changed revision requires a
fresh listing; current native or catalog denial rejects old cursors too. These
metadata methods also use the shared neutral native ABI/port and explicit CLI;
Python sync/async methods also expose metadata. Other language SDK metadata
methods remain separate work.
Signed pages fetch definitions and Table descriptors in two bounded batches at
the same revision, rechecking current native grants on each. The dependent batch
is replaced after each layer; it is not retained across calls.
`inputDisposition` separately reads a supplied behavior's control or rejected-input
outcome under current inspection rights, bound to the original send and input
position. Conditional policy control requires the configured administrator,
independently of create/inspect policy. Self-revocation still denies result
inspection; it does not prevent policy restoration under current native grants.

`Bridge.Action` and `Bridge.Result` provide shared neutral caller values. Catalog,
operation/object IDs and policy revisions use canonical decimal strings; native
identities retain their safe-integer bounds. Offline compilation returns both
typed fields and canonical request bytes. Prepared commands stay opaque and all
remote operations delegate to `Client`. Native conversions own their fields;
result strings belong to the supplied allocator.
`Bridge.Definition`, `Cursor` and `Page` provide owned neutral metadata
conversions. Cursors require the current definition, scope, resource revision and
last normalized name. Page conversion checks order, dense entries, shared scope
and continuation consistency. `lookup`, `definition` and `list` actions expose
these values through the native ABI/port and CLI without changing existing
creation/control actions or saved bytes.
The [catalog ABI/port](../transit-station-bindings/docs/catalog.md) composes these
values with explicit native handle ownership and transport uncertainty.

The [catalog CLI](../../../apps/transit-cli/docs/catalog.md) uses this same owner
for offline compilation, private saved preparation, exact submission, outcomes
and bounded metadata. Its saved pages retain the exact continuation and reject
missing/foreign definitions before loading credentials.

An application supplies an already authorized Station turn, explicit catalog
configuration and native commit/recovery handling. Initialize in a separate turn.
Initialization needs a page reader and permits unrelated private framework setup;
private writes in the catalog namespace reject. Creation still needs a page reader
and no preceding private mutations to refuse orphan Table rows at the captured cut.
`Behavior` supplies a GenServer handler/guard, with atomic initialization,
conditional administrator controls and durable input dispositions. The
[`transit-query-host` catalog role](../../../apps/transit-query-host/README.md)
hosts it with explicit configuration and fresh fenced ownership. Explicit catalog methods
are available in the CLI and Python, TypeScript, Rust, Ruby, C, C++, Java, .NET,
Erlang and Elixir SDKs through the
shared caller. The query console continues to reject CREATE.
KV/Document creation, connector declarations,
dependency-bearing objects, replacement and removal are not implemented here.
The [catalog v1 contract](../../../contracts/DECLARATIVE_CATALOG_V1.md) owns exact policies,
identities, records, limits and failure behavior. The
[SQL Table reference](../../../docs/reference/sql/create-table.md) distinguishes
offline review, private-turn integration and public execution surfaces.

Run in the pinned development shell:

```sh
(cd packages/zig/transit-catalog && zig build test)
```

The component tests use an independent dynamic-map store. They exercise bounded
atomic proposals, exact application identity, conflicts, policy changes, read
failure and catalogs larger than one resident page. They do not emulate native
authority, disk recovery or installed caller behavior; consult the
[proof ledger](../../../tests/README.md) for executed evidence.
