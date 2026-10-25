# Direct Table lifecycle

`Transit.Station.Sdk.Catalog` exposes the shared Erlang direct Table caller with
Elixir structs and ordinary `{:ok, value}`, `{:error, error}` and
`{:uncertain, original, error}` results. The shared Zig implementation owns
compilation, publication, current authorization and durable recovery.

```elixir
alias Transit.Station.Sdk.Catalog, as: C

connection = %C.Connection{scope: scope, audience: audience}
{:ok, client} = C.open(config, credential, connection, service_url)
{:ok, work} = C.compile_sql(client,
  "CREATE TABLE people (id BIGINT PRIMARY KEY, name VARCHAR(80))",
  %C.Identity{operation: operation_id}, object_id)
{:ok, bytes} = C.save(work.saved)
:ok = persist_intent(bytes) # Application-owned durable persistence.
{:ok, original} = C.stage(client, work.intent)
{:ok, bytes} = C.save(original)
:ok = persist_reference(bytes)
{:ok, observation} = C.admit(client, original)
```

The connection names a catalog scope, audience, branch (default 1) and optional
role. It grants no access or catalog ownership. Namespace selection belongs to
each identity or lookup. Provision catalog and authorization identities through
the owning public operations. Opening checks matching package/native definitions
and capabilities without initializing the service. The optional service URL
selects the direct endpoint; otherwise requests use the configured node URL.

`compile_sql` accepts optional create-object, dialect (`:transit | :mysql`) and
ingestion (`:point | :bulk`) arguments. `prepare` accepts typed schemas, lifecycle
changes and logical mutations; typed mutations use
`{:mutate, basis, mutation, :point | :bulk}`. Preparation and `preview` do not
admit work. `stage` stores intent content; persist its reference before `admit`.
`execute(client, original, steps)` advances accepted work; `inspect` observes the
original operation and `cancel` requests cancellation. Only a committed
observation carries accepted position, resulting definition and exact mutation
counts. Neither preview nor admission implies completion.

`lookup(client, name, namespace \\ 1)` returns metadata with a complete basis,
schema, authorization ID, row count and accepted position. The basis preserves
connection, namespace, name, object, branch, immutable definition and schema
commitment. Old work cannot retarget a same-name replacement. Logical types,
physical encoding and collation remain separate. Schemas allow at most 128
columns, INSERT at most 1,024 rows and predicates at most 64 instructions. SQL is
bounded to 4,096 UTF-8 bytes and names to 255 bytes. Logical values preserve exact
decimals and recursive shapes within the shared conversion bounds. Native
counter bounds remain distinct from full-width catalog and operation identities.

`save` and `restore(kind, bytes)` preserve a `:basis`, `:intent`, `:reference`,
`:cursor`, `:snapshot_owner`, `:snapshot_acquisition` or `:snapshot`. `load`
restores original saved work without recompiling; `forget` releases local loaded
work. Saved values require the current definition and reject ambiguous or
incomplete JSON. An uncertain mutation returns its original recovery value and
error. Inspect that identity after loss; do not replace it with newly compiled
work. No implicit retry occurs.

`prepare_snapshot(client, metadata, operation)` creates an explicit acquisition.
Persist it before `acquire_snapshot`; resolve uncertainty using `snapshot_status`
on its owner. Persist the returned snapshot before `snapshot_metadata` or
`release_snapshot`. Retained metadata survives ALTER, DROP and name reuse but
rechecks current rights. Owner status resolves uncertain release, and repeated
original release is idempotent. Closing a client does not release snapshots or
authorize physical deletion. The catalog API exposes retained metadata, without
an interactive relational SQL cursor.

`describe`, `namespace`, `namespaces` and `tables` expose current authorized
inspection. Pages have at most eight entries and a complete continuation cursor.
Changed directory cuts fail; start a fresh listing. Table entries use independent
accepted positions. Namespace administration, dependency controls and named
KV/Document declarations use their owning public operations; this typed adapter
does not expose them.

The immutable Elixir structs project to shared Erlang values with bounded depth
and total nodes. They do not create another protocol or permission authority.
Decoded schemas preserve public `Logical.Field` and `Logical.Element` structs
inside nested structure, list, array and map descriptors.
One active native operation is allowed per client. Task loss does not abandon
that operation; the worker remains busy until completion. `close` joins active
work and port cleanup. Returned values outlive the caller. Importing packages
does not start workers or read credentials.
