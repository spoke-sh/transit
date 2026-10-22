# General Table callers

Serialization charges each converted column, assignment and predicate before
building the next owned value. Neutral schemas share 2 MiB and actions share
16 MiB; complete frame admission also counts enclosing fields. Oversized input
rejects before constructing the complete JSON batch or dispatching native work.

`transit_catalog` exposes authorized schema discovery, typed Table creation,
mutations, schema evolution and retirement through the shared Zig caller.
Include `transit_station_sdk/include/transit_catalog.hrl` for immutable public
records. Provision the catalog host, resource, ownership and grants explicitly;
a query connection does not enable catalog administration.

```erlang
{ok, Client} = transit_catalog:open(Config, Credential, Connection),
Identity = #transit_catalog_identity{operation = Operation, namespace = Namespace},
{ok, Compiled} = transit_catalog:compile_sql(Client,
    <<"CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(120), active BOOL)">>,
    Identity, Object),
SaveIntent(Compiled#transit_catalog_compiled.saved),
Reference = (Compiled#transit_catalog_compiled.intent)#transit_catalog_intent.reference,
{ok, Step} = transit_catalog:next(Client, Reference),
#transit_catalog_next{kind = send, prepared = Prepared} = Step,
SavePrepared(Prepared#transit_catalog_prepared.bytes),
{ok, #transit_admission{position = Position}} = transit_catalog:submit(Client, Prepared),
SaveReceipt(Position),
{ok, Progress} = transit_catalog:progress(Client, Reference, Prepared, Position, true).
```

The persistence functions are application-owned durable writes. This example
sends one step; continue to a terminal outcome before claiming publication.
Opening owns a bounded worker and native port, checks matching definitions and
capabilities, and returns `{ok, Client}` or `{error, #transit_error{}}`.
`#transit_catalog_connection{owner, scope}` combines a `#transit_process{}` with
`#transit_catalog_scope{resource, catalog}` in one realm; the credential must match.
The client selects installed native artifacts unless given an explicit trusted
host executable. Immutable generated package metadata is retained with the
client; authorization and source cuts are read through the native caller.

## Schemas and typed operations

`#transit_catalog_schema{object, revision, next_column, columns, primary_key}`
contains one to 128 ordered `#transit_catalog_column{}` values. Columns carry a
stable positive ID, UTF-8 name, [logical descriptor](logical.md), nullability,
optional default cell and optional character limit. Nullability defaults to true;
`default` and `max_characters` default to `undefined`. Primary keys default to an
empty list; unkeyed Tables preserve duplicate rows with internal row identities.
Explicit single/composite keys reference column IDs. Shared Zig validates schema,
key, default and nullability semantics.

Catalog, object, column, operation, staging namespace and revision identities are
exact positive uint64 integers. Native process/resource/principal/input IDs keep
their separate safe-integer bounds. Names permit at most 255 UTF-8 bytes and SQL
at most 4096 bytes. There is no physical key/value Table ID argument.

`compile_sql(Client, Sql, Identity, CreateObject)` binds SQL through the authorized
catalog and returns `#transit_catalog_compiled{intent, saved}`. Supply an object ID
for CREATE; the three-argument form omits it. Compilation admits no work.
`prepare(Client, Name, Identity, Operation)` exposes the same semantics through
language-native operation tuples:

- `{create, Schema, IfNotExists}`.
- `{mutate, Basis, {insert, Rows}}`.
- `{mutate, Basis, {update, Assignments, Predicate}}` or
  `{mutate, Basis, {delete, Predicate}}`.
- `{alter, Basis, Change}`.
- `{rename, Basis, NewName}` or `{drop, BasisOrUndefined, IfExists}`.

Obtain the immutable object/revision/fingerprint `#transit_catalog_basis{}` using
`basis(Metadata)` from a looked-up definition. A stale basis rejects without
retargeting work. Rows contain `#transit_catalog_assignment{column, value}`;
values are logical cells or the atom `default`. INSERT accepts one to 1024 rows
of at most 128 assignments each. UPDATE/DELETE predicates are `undefined` for all
rows or a postfix list of at most 64 instructions: `all`, `negate`, `conjunction`,
`disjunction`, `{state, ColumnId, CellState}` or
`{compare, ColumnId, eq | ne | lt | le | gt | ge, LogicalAtom}`.

ALTER changes are `{add, Name, Type, Nullable, DefaultOrUndefined,
MaxCharactersOrUndefined}`, `{drop, ColumnId}`, `{rename, ColumnId, Name}`,
`{default, ColumnId, CellOrUndefined}`, `{nullable, ColumnId, Boolean}` or
`{type, ColumnId, Descriptor, MaxCharactersOrUndefined}`. Shared Zig owns predicate
validation, frozen selection, exact conversion and atomic publication.

## Progression and recovery

A client owns at most one resident intent. Persist both mandatory fields of
`#transit_catalog_saved_intent{definition, bytes}` before any send. Restore with
`load(Client, Saved)`; missing/foreign definitions reject. `forget(Client, Ref)`
releases only local intent ownership and does not cancel accepted work. Complete
saved intents are bounded to 4,327,031 bytes, action JSON to 16 MiB and prepared
commands to 8192 bytes. Catalog frames use their declared size and 96-level JSON
nesting bound; raw clients retain their smaller limits.

`next` returns `#transit_catalog_next{kind, prepared, outcome}` with kind `send`,
`running`, `terminal` or `upload_cancelled`. Save exact prepared bytes before
`submit` and the admitted position after receiving it. `observe(Client, Prepared,
Position, true)` waits for processing. `progress(Client, Ref, Prepared, Position,
true)` returns separate observation, disposition, outcome and upload state; omit
the final boolean for a single observation. Processed input and sealed upload
alone do not establish application. `status(Client, Ref)` reads
`#transit_catalog_state{outcome, upload}` without sending a command.

Terminal phases are `applied`, `unchanged`, `rejected` and `cancelled`. Only applied
INSERT/UPDATE/DELETE carry `#transit_catalog_counts{matched, changed}`. Unchanged
values can produce one matched row and zero changed rows. Original outcomes stay
bound to their saved object/operation through ALTER, DROP and name reuse. Current
rights still gate diagnostic disclosure. Diagnostic maps retain owned evidence.

`prepare_resume(Client, Ref)` and `prepare_control(Client, Ref, Control)` prepare
explicit signed commands. Controls are `cancel_operation`, `cleanup_operation`,
`cancel_upload` and `collect_upload`. Their meaning depends on durable state;
cleanup does not erase retained accepted evidence.

Submission may return `{uncertain, OriginalPrepared, Error}`. Retain and reconcile
those exact original bytes with the original connection and credential. Do not
recompile, re-sign or replace the intent. Malformed successful receipts, response
loss and worker loss preserve uncertainty. Definite native rejections retain their
kind, status, code and diagnostic. The client performs no automatic submission
retry. A waiting process's death does not request durable cancellation.

## Controls and discovery

`prepare_initialize` takes a configuration with scope, owner, administrator,
explicit Table limits, a native authority profile and a database name. The
profile binds three distinct domains, database/schema objects and the initial
schema namespace. It does not grant privileges. Administration uses native roles
and object grants, with CONNECT and USAGE preceding Table privileges.

`prepare_dependency(Client, Dependency, Present)` registers/removes
`#transit_catalog_dependency{scope, object, identity, owner, kind}`. Kinds are
`query_source`, `writer`, `watch`, `maintained_relation` and `history`. Registration
grants no access; DROP RESTRICT retains original blocker evidence.
`input_disposition(Client, Prepared, Position)` reads control/rejection evidence.
`describe` returns current configuration, authenticated subject and authorization revision; `capabilities` exposes native
limits. Undefined evidence proves no outcome.

`lookup(Client, Name)` returns a definition with metadata, current head and schema,
or `undefined`. `definition(Client, Object, Revision)` returns an accepted
historical definition with metadata and schema, including after retirement; it
has no current head. Missing/unaccepted definitions are absent. `list(Client)`
returns a page with a resource revision, at most eight ordered entries and an
optional cursor. Continue through empty pages while `next` exists. Restore all
cursor fields: mandatory definition, scope, resource revision and after-object
ID. A cursor grants neither authority nor a snapshot lease. A changed cut rejects
continuation; discard partial results before restarting the listing.

One client admits one job at a time and rejects overlap as `busy`. Requests are
validated before worker admission. Admitted native work survives the waiting
process's death and remains owned until joined `close`. OTP processes, Tasks and
managed fields are not durable recovery storage. Generated schemas and typed
decoders check fields, identities, canonical integers, budgets and continuations.

The [Table reference](../../../../docs/handbook/reference/tables.md) and
[catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) own authority,
publication and retention. The [proof ledger](../../../../tests/README.md) records
installed-package and recovery evidence and its limits.

Catalog metadata retains the immutable metadata publication commitment: its
byte length and 32-byte digest. Missing or malformed commitments are rejected;
query sources use this evidence with the catalog owner and resolved schema.

Connections select `role` (default `undefined`, the login role) and `namespace`
(default 1). `open/4` accepts an explicit Table-service URL for mediated reads;
`open/3` uses direct infrastructure reads. Mediation preserves caller signing
and keeps private service resource credentials separate.

`#transit_catalog_subject{}` contains principal, login role, selected role,
credential epoch, audience and an owned 32-byte context. Descriptions check that
the subject matches the selected connection. Metadata includes its positive
schema namespace and a commitment bounded to 444 bytes. Lookup/list reject
foreign namespaces; live definitions also carry the native authorization object.
Historical definitions require the original object's current disclosure rights.
