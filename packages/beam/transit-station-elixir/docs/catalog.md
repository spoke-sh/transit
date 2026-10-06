# General Table callers

`Transit.Station.Sdk.Catalog` exposes the shared
[general Table lifecycle](../../transit-station-sdk/docs/catalog.md) through
Elixir structs and tagged operation tuples. Shared Erlang owns the bounded native
worker; shared Zig owns signing, authorization, schema validation, execution and
exact recovery. Provision the catalog host, resource, ownership and grants
explicitly. A query connection does not enable catalog administration.

```elixir
alias Transit.Station.Sdk.Catalog, as: C

{:ok, client} = C.open(config, credential, connection)
identity = %C.Identity{operation: operation, namespace: namespace}
{:ok, compiled} = C.compile_sql(client,
  "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(120), active BOOL)",
  identity, object)
save_intent.(compiled.saved.definition, compiled.saved.bytes)
{:ok, step} = C.next(client, compiled.intent.reference)
%C.Next{kind: :send, prepared: prepared} = step
save_prepared.(prepared.bytes)
{:ok, admitted} = C.submit(client, prepared)
save_receipt.(admitted.position)
{:ok, progress} = C.progress(client, compiled.intent.reference, prepared, admitted.position, true)
```

Persistence functions are application-owned durable writes. The example sends one
step; continue to a terminal outcome before claiming publication. Functions
return `{:ok, value}` or `{:error, %Transit.Client.Error{}}`. Submission can return
`{:uncertain, original_prepared, error}`; retain and reconcile the exact original
bytes with the original connection and credential.

Public structs correspond to the shared guide's records: `Scope`, `Connection`,
`TableLimits`, `Configuration`, `Rights`, `Policy`, `PolicyChange`, `Column`,
`Schema`, `Identity`, `Basis`, `Metadata`, `Head`, `Entry`, `Definition`,
`HistoricalDefinition`, `Cursor`, `Page`, `Reference`, `SavedIntent`, `Prepared`,
`Intent`, `Compiled`, `Counts`, `Outcome`, `Upload`, `State`, `Disposition`, `Next`,
`Progress`, `Capabilities`, `Description`, `Assignment` and `Dependency`.
Missing optional values are `nil`. Rights default false; columns default nullable
with no default or length bound, and schema primary keys default to an empty list.
[Logical values](logical.md) retain recursive descriptors and separate cell states.

`prepare(client, name, identity, operation)` takes the same tuples as the shared
guide, using Elixir structs inside them and atoms for tags. Obtain a captured
`Basis` with `C.basis(definition.metadata)`. `compile_sql` accepts an optional
CREATE object ID. `load`, `forget`, `next`, `status`, `prepare_resume`,
`prepare_control`, `prepare_initialize`, `prepare_policy`, `prepare_dependency`,
`submit`, `observe`, `input_disposition` and `progress` preserve explicit staging,
processing, publication and recovery distinctions. The optional final wait flag
on `observe` and `progress` defaults false.

`lookup` returns a definition with metadata, head and schema or nil; `definition`
returns an accepted historical definition with metadata and schema or nil.
`list(client, cursor)` defaults to a new listing. Continue through empty pages
while `page.next` exists. Keep mandatory cursor definition, scope, resource cut
and after-object ID intact. A changed cut rejects continuation; current native
and catalog rights are checked again. DROP/name reuse does not retarget original
saved operations or historical definitions.

One client owns one active native job; overlap returns `:busy`. A Task's death
abandons only its wait. `close` joins active work and native cleanup. Structs and
binaries are immutable, and no external text becomes a BEAM atom. Host projection
is bounded before request validation. Complete saved intents permit 4,327,031
bytes; prepared commands permit 8192 bytes. Catalog frames and nesting use their
own declared limits while raw callers retain their smaller bounds. See the shared
guide for all operation limits and the [proof ledger](../../../../tests/README.md)
for executed qualification.
