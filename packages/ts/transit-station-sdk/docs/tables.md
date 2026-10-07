# Tables in handlers

`TableSchema` uses the same schema, logical descriptors and values as
[`catalog.Schema`](catalog.md). It accepts up to 128 columns, explicit stable
column identities, defaults and optional composite primary keys. Columns default
to nullable. Tables without a primary key preserve duplicate rows and still have
stable internal row identities. The first column is not implicitly a key.

```ts
import { TableSchema } from "@transit/station";

const people = new TableSchema(
  1n,
  1n,
  4n,
  [
    { id: 1n, name: "id", type: { kind: "int64" }, nullable: false },
    { id: 2n, name: "name", type: { kind: "utf8" } },
    { id: 3n, name: "salary", type: { kind: "decimal", precision: 18, scale: 2 } },
  ],
  [1n],
);
```

`turn.createTable(schema, limits)` prepares one initialization step. Limits name
`recordBytes`, `stagingBytes` and `stagingRecords` explicitly. Its result is
`building` or `applied`, with original admission and completion positions.
Commit each private proposal and schedule a subsequent input while building;
reuse the exact schema and quotas. A changed intent rejects. Only a committed
applied result makes the Table visible to later reads. Creation publishes no
catalog name or grant. Use the catalog API for SQL names and DDL lifecycle.

`await turn.table(objectId)` discovers the schema and captures its current
resource revision and head digest. A Table handle expires with its turn.
`turn.openVersion(version).table(objectId)` reads an explicitly retained source;
current rights still apply. Read operations exclude private mutations.

- `get(identity)` reads an opaque, owned `RowIdentity`.
- `getKey(cells)` reads a complete typed primary key in declared key order.
- `page(cursor?, limit?)` reads one to eight rows. Only an absent continuation
  means completion; a full page can have an empty successor.

Rows expose ordered logical `cells` and a separate identity. A nullable cell is
`{ state: "null" }`; decimal values carry an exact `bigint` coefficient. Nested
values use the [logical value model](logical.md). Missing, explicit null and
DEFAULT retain their distinct mutation meanings. Page order follows internal
row identity, not SQL key ordering. Cursors bind their original cut and reject a
new view or schema/head; they are opaque and must not be edited.

`table.prepare(principal, operationId, mutation)` creates a `TableMutation` from
the captured schema. The principal and nonzero `bigint` operation ID belong to
the application's durable operation namespace. Insert rows and update
assignments address stable column IDs; predicates use the catalog's typed
mutation model. `TableMutation.prepare(resource, principal, operationId, schema,
mutation)` also accepts an explicitly owned schema.

Persist `intent.save()` and its operation identity through application-owned
records or immutable publication before relying on a later input to resume it.
`TableMutation.load(saved)` checks the current definition and owns the exact
schema and values. `await intent.step(turn)` prepares one bounded private step;
it never silently loops, generates a replacement identity or adopts a new schema.
A saved intent rejects a different realm/resource. Application policy still
owns admission and disclosure; the identity itself grants no rights.

Outcomes distinguish `building`, `applied`, `rejected` and `cancelled`. Counts
are present only for an applied outcome, and matched/changed are separate.
A terminal result is provisional until its native turn commits. Rejections
include the retained reason and available original witness. References can be
saved, loaded, inspected and cancelled through `TableMutationReference`; exact
terminal retries return their original receipt. Cancellation does not erase
staged evidence. The runner's saved native proposal reconciles uncertain commits
separately from the application's saved Table intent.

Each binding action, including its enclosing JSON object, is limited to 256 KiB.
Schemas, rows and mutations have their own independent native bounds; storage
admission does not imply every value fits one foreign action. Pages remain
bounded independently of total Table size. Admission, native input processing
and domain completion are distinct; applications schedule continuations and
retain accepted commands until their outcomes are terminal.

`turn.allowQuery(peer, objectId, { expectedRevision, allow })` uses a `bigint`
policy revision. `turn.startQuery(objectId, new QueryPlan({ projection: [0, 2] }))`
accepts explicit positional projections, output names and logical predicates.
It requires an authenticated call and a fresh private proposal. The frozen plan
fits at most 512 bytes. Segments fit a 65535-byte buffer and the Arrow workspace
is 4 MiB. A projection that exceeds these operation budgets produces a failed
query outcome; an earlier segment prefix never becomes a complete result.
See [capture and delivery](../../../zig/transit-station/docs/queries.md).
