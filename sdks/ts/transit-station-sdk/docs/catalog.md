# Direct catalog lifecycle

The `catalog` API exposes direct Table definitions, row changes, current inspection
and explicit snapshot retention through the shared Zig caller. SQL compilation
and typed preparation freeze work without reserving a name or accepting a change.

```ts
import { Credential, ResourceRef } from "@transit/client";
import { catalog } from "@transit/station";

const scope = new catalog.Scope(new ResourceRef(realm, resource), catalogId);
const connection = new catalog.Connection(scope, audience, 1n, selectedRole);
const credential = new Credential(realm, principal, seedFile);
const client = await catalog.Client.open(
  { url, profile: "native_v1", serviceUrl },
  credential,
  connection,
);
try {
  const work = await client.compileSql(
    "CREATE TABLE people (id BIGINT PRIMARY KEY, name UTF8)",
    new catalog.Identity(operationId, 1),
    { createObject: objectId },
  );
  await saveDurably("intent", work.saved.save());
  const proposed = await client.preview(work.intent);
  inspectPreview(proposed);
  const reference = await client.stage(work.intent);
  await saveDurably("reference", reference.save());
  let observed = await client.admit(reference);
  while (observed.state === "admitted") {
    observed = await client.execute(reference, 32);
  }
  inspectOutcome(observed);
} finally {
  await client.close();
}
```

Staging, admission and completion are separate. The application supplies distinct
operation IDs, saves original recovery values and chooses continuation budgets.
A committed Table operation reports its resulting definition, accepted position
and exact `matched`, `affected` and `liveRows` counts. Conditional name assertions
report a catalog position with `unchanged`, `rejected` or `cancelled`; they do not
invent a Table commit.

`Connection` contains scope, service audience, branch and optional selected role;
credentials provide the principal. There is no actor PID. Catalog, branch, object,
operation, definition, data-position and row-count values use `bigint`. Native
realm/resource/principal/namespace counters remain validated safe integers. The
optional `serviceUrl` defaults to `url`; both endpoints are at most 2048 UTF-8
bytes and exclude user information, query strings and fragments. `timeoutMs`
defaults to 5000 and accepts 1–60000. Creation checks the matching definition and
capabilities; it grants no rights and initializes no catalog.

## Schemas and exact work

`Schema(objectId, revision, nextColumn, columns, primaryKey)` owns one to 128 typed
columns with stable IDs. Columns carry independent logical descriptors, physical
encoding and collation, nullability, optional defaults and character bounds.
Nested values use the [logical value API](logical.md). Returned schemas require
physical descriptors explicitly; missing fields never acquire defaults.

`Column.semantics` accepts decimal `rounding`, a vector `metric`, pinned
`timezone` rules and reserved `spatial` metadata. Timezone rules own the version
label, digest, zone name and actual TZif bytes. Returned schemas preserve these
fields, and changing them requires the owner's physical rewrite lifecycle.
An absent `physical.semantics` preserves existing rules; `{}` explicitly clears
them. Range/multirange descriptors carry a `subtype`; vector descriptors carry
`dimensions` and `element`. Vector cells hold exact little-endian `Uint8Array`
bytes with no per-element cell tags. Shared Zig validation owns canonical ranges,
finite vector elements and valid type/metric combinations.

`prepare(name, identity, action)` supports `create`, `alter`, `rename`, `drop` and
`mutate`. Existing-object actions require the complete `Metadata.basis` returned
by `lookup(name, namespace)`. `Basis.save()` preserves the connection, namespace,
name and stored interpretation, so old work cannot redirect to a same-named
replacement. `alter` supports adding, dropping and renaming columns, changing
defaults, nullability, logical types and physical descriptors.

`mutate` contains `insert`, `update` or `delete`, plus `ingestion: "point" | "bulk"`.
Assignments address stable column IDs with a typed cell or `"default"`. Inserts
contain one to 1024 rows with at most 128 assignments each; UPDATE/DELETE accept
at most 64 postfix predicate instructions. An absent predicate selects all rows.
SQL compilation accepts optional `dialect: "transit" | "mysql"`, `ingestion` and
`createObject`. Native owners validate supported types, collation semantics,
constraints, current authority and atomic publication.

Schema and mutation encoding charge fragments before constructing further
logical values. Complete saved work and action frames obey generated
`catalog_intent_bytes` and `catalog_action_bytes` bounds. Bulk requests can exceed
an actor frame. See the [Table reference](../../../../docs/handbook/reference/tables.md)
for the executable storage and codec profiles.

## Recovery and retained reads

Save `SavedIntent.save()` before staging. `SavedIntent.restore(text)` and
`load(saved)` restore original local work without recompilation. Save
`Reference.save()` before admission; `Reference.restore(text)` supplies the exact
binding for `inspect`, `execute` and `cancel`, including after DROP/name reuse.
`preview` has no staging or acceptance side effects. `forget` releases only the
local selection, and destroying the caller never cancels accepted work.

`catalog.Uncertain.recovery` retains the typed saved intent, reference, snapshot
acquisition or snapshot. A malformed success response after mutation also
preserves uncertainty. Inspect or retry the original operation; a new compilation
would create different work. The wrapper supplies no implicit retry or polling.

`describe`, `namespace`, `namespaces`, `tables` and `lookup` observe current
authorized metadata. Directory pages contain at most eight entries. Continue with
the returned saved `Cursor`, including an empty page with a continuation. Its
connection, selection and original catalog position remain fixed; a changed cut
rejects. Table pages explicitly have `independent` consistency. Metadata exposes
the prepared basis, schema, position, logical row-change position and row count.

`prepareSnapshot(source, operation)` freezes the source's basis and exact position.
Save the `SnapshotAcquisition` before `acquireSnapshot`. After uncertainty,
`snapshotStatus(acquisition.owner)` resolves its original owner. Current Table
fields in that status are distinct from the retained cut. `snapshotMetadata`
returns the original definition, schema, accepted position and row count under
current rights, including after logical retirement and name reuse.

Save each acquired `Snapshot` and an explicit cleanup decision.
`releaseSnapshot(snapshot)` addresses its original owner and content; uncertainty
requires status inspection or exact retry. Local client/query closure leaves
these durable snapshots intact. Release does not establish physical reclamation
or authorize expiry. [Interactive relational queries](relational.md) consume
explicit saved sources through the same retention boundary.

Each client owns one host, allows one active operation and joins work on close.
Saved values and returned data outlive the host. Runtime generated validation and
exact response-binding checks protect the public typed boundary. The
[shared caller contract](../../../../packages/zig/transit-station-bindings/docs/catalog.md)
owns authority and failure semantics; the [proof ledger](../../../../docs/history/qualification/README.md)
distinguishes installed execution from decoder tests. Namespace administration,
policy preparation, dependency and named-resource host actions remain separate
from the typed Table methods described here.
