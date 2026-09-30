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

`Client` supplies current metadata, `prepareCreate`, explicit signed submission,
input observation and original-request status. Its owned `Prepared` values save
and restore exact canonical bytes with mandatory definition checks. Submission
does not re-sign uncertain work. Current create and inspect policies remain
independent; admission, processing and application are separate outcomes.

An application supplies an already authorized Station turn, explicit catalog
configuration and native commit/recovery handling. Initialize in a separate turn.
Initialization and creation need a page reader and no preceding private mutations
so they can refuse orphan catalog records or Table rows at the captured revision.
There is no supplied catalog host or CLI/SDK administrative route. The query
console continues to reject CREATE. KV/Document creation, connector declarations,
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
