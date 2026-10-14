# Unified state queries

`Plan.predicate` accepts `{kind: "program", instructions}` with one to 64 postfix
`PredicateInstruction` values. An atom uses `{kind: "atom", atom}` with a state
or comparison `PredicateAtom`; omitting `atom` means all rows. Operators have
`kind: "negate"`, `"conjunction"` or `"disjunction"`. For example,
`[{kind: "atom", atom: {kind: "state", column: 1, state: "null"}},
{kind: "negate"}]` selects non-null cells. `Bundle.prepare` copies the neutral
input before its first asynchronous wait. Shared Zig validates stack shape and
types; programs cannot nest. Evaluation preserves instruction order, unknown
truth and eager errors. EXPLAIN exposes the same bounded structure through
`InspectedPredicate` without literals; preparation grants no source authority.

Import `unified` from `@transit/station` for v1 KV, Table and accepted Document
queries. Tables use immutable catalog metadata and general logical schemas. Public source, plan and
result types are separate from the generated wire schemas; every port request
and response is runtime-validated. Shared Zig owns protocol and query semantics.

```ts
import { unified as q } from "@transit/station";

const source: q.Source = {
  kind: "kv",
  resource,
  prefix: new TextEncoder().encode("events/"),
  key: { type: "binary", version: 1 },
  value: { type: "utf8", version: 1 },
};
const bundle = await q.Bundle.prepare(
  source,
  { projection: [1] },
  {
    pages: 1000n,
    segments: 100n,
    resultBytes: 1_048_576n,
  },
);
```

`q.Client.open(config, credential, connection)` opens one owned native port.
Select `native_v1`; supply the endpoint, explicit credential and a `q.Connection`
binding source/requester processes and resources in one realm. The caller needs
no activation or writer ownership. `nativeHost` overrides installed discovery.
Import starts no process or credential access. Call `close()` in `finally`;
cleanup joins the current operation. Overlapping operations return `Busy`.

`describe(source)` checks current policy and limits. `prepareNext(namespace,
bundle)` returns one `Prepared` command. Persist its opaque `data` string before
`submit`. The returned `AdmissionReceipt.position` is input admission, not query
completion. Wait until `observe(position)` reports committed before preparing
again. A rejected observation reports the durable behavior rejection. When
preparation returns undefined, inspect `status(namespace)` for the terminal or
admitted state.

`client.compileSql(source, name, sql, budgets, parameters?)` returns a
`Promise<Bundle>`. Pass a readonly array of logical `Scalar` atoms to bind placeholders;
omit it for ordinary SQL, or pass `[]` for a template without placeholders.
Inputs are converted to owned wire values before the first await; changing the
original array or binary buffers cannot change the pending compilation.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

`client.inspectSql(source, name, sql, budgets)` accepts `DESCRIBE name`,
`SHOW TABLES` and `EXPLAIN SELECT ...`. It returns an `Inspection` with current
resource/policy revisions, owned declaration/schema digests and typed details
whose `kind` is `description`, `tables` or `explanation`. Full-width quantities
use `bigint`; collections are frozen. An explanation preserves operator order,
the predicate's column/state or comparison/type, output columns and budgets,
without literal values. `undefined` means an absent input limit or unfiltered
plan. Inspection operates on the supplied source alias under current access;
it acquires no snapshot and submits no query. See the
[inspection contract](../../../../contracts/SQL_INSPECTION_V1.md).
`inspectSql` accepts no parameter bindings and does not inspect bound NULL
comparisons. An unsupported native predicate response raises `IncompatibleNative`.

`q.Uncertain` carries the identical `prepared` value after unconfirmed dispatch.
Retain it across process loss and resubmit unchanged on a new client. Do not parse
and re-encode signed material: embedded full-width numbers must remain opaque.
`prepareCancel`, `prepareRetire` and `prepareCollect` use the same explicit
persistence/submission/observation sequence. Abandoning a Promise does not cancel
durable work.

For a complete query, `page(namespace, cursor)` returns an owned IPC segment,
typed manifest source/schema/plan commitments and optional continuation. The
cursor preserves verification progress and never grants permission. Save it only
with its exact connection/namespace. Reads recheck current access and lifecycle;
failure leaves the old cursor unchanged. Undefined next means complete verified
coverage, not merely an empty source page.

`Page.decode()` and `decodeArrow()` use shared Zig and preserve five cell states,
ordered conflict IDs, bigint values, binary, Unicode and negative zero. For the
pinned optional Apache Arrow 21.2.0 integration, `unifiedToArrow(page)` from
`@transit/station/arrow` returns the nested schema without flattening states into
nullable values. Byte getters copy owned data; native temporary buffers cannot
escape. Bundles contain at most 25069 bytes. Table results admit 128 columns and
segments contain at most eight rows and 64 KiB. Comparison literals retain their
4 KiB byte bound; descriptors and recursive cells retain the shared logical
budgets. KV has two columns; Document projections admit eight scalar decoders.

Result columns carry logical descriptors, nullability and optionality. Cells use
the same language-native `logical.Cell` model as Table writes: `value.atom` for
scalar values and typed structures/lists/arrays/maps/unions for nested values.
Signed, unsigned, decimal and temporal atoms preserve exact `bigint` values;
descriptors supply integer width, decimal precision/scale and timestamp zone.

Construct a Table source from an authorized catalog lookup:

```ts
const definition = await catalogClient.lookup("people");
if (definition === undefined) throw new Error("Table not found");
const table: q.Source = {
  kind: "table",
  owner: catalogClient.connection.owner,
  metadata: definition.metadata,
  schema: definition.schema,
};
```

`Metadata.commitment` carries the immutable record commitment returned by the
shared catalog implementation. Local bundle preparation does not establish
access or readiness. Current `describe` checks that metadata; retained-result
reads separately check current rights while preserving the original schema and
`Manifest.sourceHead`. Renaming or replacing a Table cannot rebind saved work.

`just bindings::unified-node table` installs fresh package tarballs and runs the
shared codec and signed recovery schedule. `kv` and `document` select the other
sources. See [proof evidence](../../../../tests/README.md) for completed runs.
