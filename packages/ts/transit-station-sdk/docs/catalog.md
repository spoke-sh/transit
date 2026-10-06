# Catalog callers

`catalog.Client` from `@transit/station` exposes general Table schemas, SQL and
typed DDL/DML, metadata, policy and dependency controls through the shared Zig
catalog client. Provision its owner, state resource and caller grants explicitly.
The handle neither owns a Table worker nor grants rights by compiling SQL.

```typescript
import { ProcessRef, ResourceRef } from "@transit/client";
import { catalog } from "@transit/station";

const scope = new catalog.Scope(new ResourceRef(realm, resource), catalogId);
const connection = new catalog.Connection(new ProcessRef(realm, owner), scope);
const client = await catalog.Client.open(config, credential, connection);
try {
  const compiled = await client.compileSql(
    "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200), active BOOLEAN DEFAULT TRUE)",
    new catalog.Identity(operationId, uploadNamespace),
    objectId,
  );
  await saveIntent(compiled.saved.definition, compiled.saved.bytes);
  const step = await client.next(compiled.intent.reference);
  if (step.kind === "send") {
    await savePrepared(step.prepared.data);
    const receipt = await client.submit(step.prepared);
    await saveReceipt(receipt.position);
    const progress = await client.progress(
      compiled.intent.reference,
      step.prepared,
      receipt.position,
      true,
    );
    // Continue observing this input, then request the next step. Native admission
    // and input processing are separate from the terminal Table outcome.
  }
} finally {
  await client.close();
}
```

`config` selects `native_v1`, URL, optional `timeoutMs` and optional `nativeHost`;
`credential` belongs to the same realm. The installed Station host is selected
by default. Opening checks its exact definition and capabilities. Importing starts
no process or credential access. One call is active per handle; overlap rejects
with `Busy`. `close()` joins active work and the child. Host lifetime is separate
from accepted operation lifetime.

## Typed schemas and mutations

Catalog/object/operation/namespace/column identities, schema revisions and row
counts use `bigint`. Native resource, principal, process and input counters use
bounded integer numbers. `Identity` requires a positive operation and upload
namespace. `compileSql` accepts a new object identity only for CREATE; all other
statements resolve current authorized metadata and freeze its original basis.

`Schema(objectId, revision, nextColumn, columns, primaryKey)` owns up to 128 named
columns with stable IDs. Columns specify `type`, optional `nullable` (default
true), `default` and `maxCharacters`. Primary keys are explicit stable-column
ID lists. Schema column and default getters return independent values; changing
them cannot mutate the schema. Shared Zig admission enforces key types, constraints,
canonical descriptors and the encoded schema bound.

`logical.Descriptor` and `logical.Cell` are language-native recursive types.
Descriptors use `kind`, with fields/elements for STRUCT, LIST, ARRAY, MAP and
UNION. Atoms use `bigint` for exact integers, decimal coefficients and temporal
units, `Uint8Array` for binary/UUID, and finite numbers with an explicit 32/64-bit
width for floats. Cells retain missing, null, value, type-error and conflict as
distinct states. Ordinary Table storage admits only its documented subset;
missing is not an implicit SQL NULL. Use the assignment string `"default"` to
request a column's default. JSON has an explicit typed JSON value variant.

```typescript
const current = await client.lookup("people");
if (!current) throw new Error("Missing Table");
const compiled = await client.prepare("people", identity, {
  kind: "mutate",
  basis: current.metadata.basis,
  mutation: {
    kind: "insert",
    rows: [
      [
        {
          column: 1n,
          value: {
            state: "value",
            value: {
              kind: "atom",
              atom: { kind: "signed", value: 1n },
            },
          },
        },
        {
          column: 2n,
          value: {
            state: "value",
            value: {
              kind: "atom",
              atom: { kind: "utf8", value: "Ada" },
            },
          },
        },
      ],
    ],
  },
});
```

`prepare` also accepts CREATE with a `Schema`, ALTER with a selected column
change, RENAME and DROP. Mutation actions are INSERT rows, UPDATE assignments and
DELETE, with optional postfix predicates for scalar comparisons, state tests,
NOT, AND and OR. Every non-CREATE operation uses a frozen `Basis` containing the
object, metadata revision and schema fingerprint, except absent-name DROP IF
EXISTS. It never substitutes a replacement object found under the same name.
SQL and typed inputs use the same native compiler, intent codec and owner.

## Persistence and outcomes

Persist both `SavedIntent.definition` and its exact `bytes`. Restoring requires
`new SavedIntent(definition, bytes)` and `client.load(saved)`; missing/foreign
definitions reject. Loading is local and never recompiles SQL or sends a command.
The returned `Intent.reference` identifies the complete original bytes. A handle
owns one loaded intent; `forget(reference)` releases local memory without
cancelling durable work.

`next(reference)` returns `send`, `running`, `terminal` or `upload_cancelled`.
Persist each `Prepared.data` unchanged before dispatch. `submit()` returns an
`AdmissionReceipt`; `observe(prepared, position, wait)` reports input progress.
`progress(reference, prepared, position, wait)` combines that input with the
original operation. A processed input may carry a separate `Disposition`.
`status(reference)` reports `outcome` and `upload` separately, with absent values
represented by `undefined`. Terminal applied DML has recorded `matched` and
`changed` counts. Upload closure or processed input alone does not establish
successful SQL execution.

`Uncertain` retains the original `Prepared` object. Reconnect if needed and
reconcile the identical saved text before preparing another send. Missing or
malformed submission replies preserve uncertainty. A rejected attempt or failed
read never overwrites the original operation's outcome. `prepareResume` and
`prepareControl` produce explicit signed recovery, cancellation or cleanup steps;
all still require persistence and separate submission.

## Metadata and administration

`lookup(name)` returns current `metadata`, complete `schema` and `head`, or
`undefined`. Metadata includes a reusable frozen `basis`; schema revision and
catalog metadata revision remain distinct. UTF-8 names are bounded to 255 bytes.
`list(cursor?)` returns up to eight metadata/head entries ordered by object
identity. Its definition-qualified cursor preserves scope and resource revision.
Retired objects may produce an empty page with continuation. Restart the listing
on revision conflict rather than combining different cuts.

`definition(objectId, revision)` returns accepted historical metadata and schema,
or `undefined` for absent revisions and known unaccepted candidates. The owned
`HistoricalDefinition` has no live head. Reads survive DROP and name reuse but
still require current native grants and catalog inspection rights. Missing
original acceptance evidence or incompatible/corrupt retained records fails;
private publication alone does not establish an accepted definition.

`Configuration` requires explicit record/staging byte and staging-record limits.
`Policy` requires every independent boolean right: inspect, create, read, insert,
update, delete, alter and drop. `PolicyChange` requires the exact expected and
successor revisions. `prepareInitialize`, `preparePolicy` and `prepareDependency`
return commands without dispatch; `describe` reads current configuration/policy.
The native owner rechecks authority and conditions when applying inputs.

Generated schemas validate both port directions. The SDK uses the catalog's
larger generated framing bound only for this profile and grows response storage
geometrically with received bytes; idle clients release it. Logical conversion has
bounded depth and children; the native owner enforces complete schema/value/intent
budgets. Kernel frames and turn limits remain unchanged. See the
[shared caller contract](../../../zig/transit-station-bindings/docs/catalog.md)
for exact transport, ownership and recovery limits.
