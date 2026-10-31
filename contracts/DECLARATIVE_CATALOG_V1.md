# Declarative catalog v1

The catalog names data objects and schema namespaces, binds them to stable
identities and current native authority, and records declaration progress.
`DirectCatalog` is the executable owner. Its signed requests are defined in
[Direct Table v1](DIRECT_TABLE_V1.md), with the generated
[direct message schema](direct-table-v1.schema.json). SQL, the catalog ABI/port
and language SDKs lower to these same operations.

## Identity and ownership

A catalog connection contains `scope` (realm, lifetime resource and catalog ID),
branch, audience, principal and optional selected role. Data object IDs and
operation IDs are independent full-width identities. An interpretation commits
to a stable object, revision and digest. Names are lookup keys, never authority.
A name reused after retirement cannot retarget an earlier binding.

The [data lifecycle contract](DATA_LIFECYCLE_V1.md) owns exact identity,
transaction-domain and acceptance definitions. Catalog records, Table logs and
native process progress retain distinct positions; they do not imply an atomic
cross-owner transaction or a common cross-Table snapshot.

The separate [index lifecycle contract](INDEX_LIFECYCLE_V1.md) defines offline
index identities, immutable key/constraint bindings, build generations and exact
coverage publication. Its validators reuse these catalog/source identities;
they do not add an executable catalog operation or prove query eligibility.

## Initialization and authorization

A configured local node opens and recovers catalog and Table storage. Explicit
initialization establishes the configured database and initial schema under
native authorization. Opening a caller handle and reading a definition perform
no initialization, provisioning or activation.

Native domains bind database, schema and Table metadata to the catalog's lifetime
resource. CONNECT and USAGE precede Table action checks; CREATE requires schema
CREATE and selectable ownership. ALTER and DROP require ownership. Current
visibility filters metadata. Current rights, credential epoch, selected role
and source lifetime are checked during work and again before disclosure.
The registrar publishes native metadata bindings under the original caller's
fence; it is not another grant authority.

## Conditional Table creation

A complete saved DDL intent fixes the caller, operation, stable target,
expectations and proposed schema. Admission preserves the intent and reserves
the name. Native registration and the Table acceptance record establish the
published interpretation. Settlement records catalog completion. A name is not
visible merely because its intent or registration exists.

A conditional statement requiring no Table mutation uses `NameAssertion` with an
exact existing interpretation or absence expectation. It records unchanged,
rejected or cancelled at a catalog position. It never substitutes a fresh target
when repeated. See [conditional names](DIRECT_TABLE_V1.md) for exact actions.

## Schema namespaces and administration

Typed namespace operations support CREATE, RENAME and bounded DROP RESTRICT.
They retain explicit expected definitions, original identity and progress.
A live or pending Table, direct KV, Stream, Queue or named Document blocks namespace retirement.
Policy SQL prepares native authorization actions with an expected policy revision;
preparation publishes nothing. Native authorization owns publication and recovery.
SET ROLE changes connection selection, not the grant store.

Named KV uses `DirectKV` declarations and a database-owned partition in this
catalog. Its INSPECT, READ, WRITE and ownership checks use the existing policy
graph. See [direct KV](DIRECT_TABLE_V1.md#direct-kv) for batches and retained reads.

Named Document declarations use `DirectResource` bindings in the same catalog. Admission, caller-authorized native allocation, writer initialization,
publication and retirement remain distinct. Supplied resource IDs are not
allocation evidence. See [named resources](DIRECT_TABLE_V1.md) and the
[state contract](STATE_V1.md) for their owners and limits.

## Inspection and bounded pages

Lookup returns the complete stored interpretation, schema, authorization object
and current Table position. Directory pages contain at most eight entries and
can be empty after filtering while retaining a continuation. A cursor binds the
contract definition, original connection, selection, directory position and
last examined identity. Changed directories reject continuation. Table positions
are independent observations; the cursor pins no row data.

Retained metadata is read through an explicitly acquired Table snapshot. Its
original accepted position and schema remain separate from current metadata,
including after DROP/name reuse. Current authority gates both. An arbitrary
content-addressed declaration is not evidence of acceptance.

## Signed Zig caller

`DirectTableClient.call` makes one authenticated direct exchange and validates
result kind, binding, counts and bounded page progression. It does not retry
mutations or allocate replacement pins implicitly. `DirectTableIntent` preserves
complete work independently of credentials and host lifetime.

## Neutral caller values

`DirectTableBridge.Session` owns one local intent. SQL `compile` and typed
`prepare` return saved work; persist it before `stage`, then persist the returned
reference before `admit`. `operation.inspect`, `operation.execute` and
`operation.cancel` use that exact reference under current rights. Loading,
forgetting and destruction have no remote side effects.

Data identities, counts and positions use canonical decimal strings; native
counters use safe JSON integers. Bindings and saved artifacts require the current
shared definition. Missing/foreign identifiers and superseded actor envelopes
reject before execution. There is no alternate decoder or actor route.
The [catalog ABI guide](../packages/zig/transit-station-bindings/docs/catalog.md)
and generated Station contract own host actions and allocation lifetimes.

## Outcomes and recovery

Admission, pending work, rejection, cancellation and committed Table evidence
are distinct states. Unknown transport outcome is not rejection. Preserve the
original saved work and inspect its owner after a failed response, including a
denied final disclosure following acceptance. Current grants are required even
for terminal receipts and retained data. Cancellation cannot undo acceptance;
cleanup and pin release cannot erase receipts or promise physical reclamation.

The [direct owner guide](../packages/zig/transit-catalog/docs/direct-catalog.md)
explains implementation bounds. [Executed proofs](../tests/README.md) separately
qualify component transitions, public requests, disk recovery and installed callers.
