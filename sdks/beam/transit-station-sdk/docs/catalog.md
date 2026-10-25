# Direct Table lifecycle

`transit_catalog` exposes typed Table declarations and mutations through the
shared Zig direct catalog owner. A connection names a catalog scope, audience,
branch and optional role. Provision these identities and grants explicitly.
A connection does not allocate a catalog or confer access; namespace selection
belongs to each operation or lookup.

```erlang
Connection = #transit_catalog_connection{scope=Scope, audience=Audience},
{ok, Client} = transit_catalog:open(Config, Credential, Connection, ServiceUrl),
{ok, Work} = transit_catalog:compile_sql(Client,
    <<"CREATE TABLE people (id BIGINT PRIMARY KEY, name VARCHAR(80))">>,
    #transit_catalog_identity{operation=Operation, namespace=1}, Object),
{ok, SavedBytes} = transit_catalog:save(Work#transit_catalog_compiled.saved),
ok = persist_intent(SavedBytes), % Application-owned durable persistence.
{ok, Original} = transit_catalog:stage(Client, Work#transit_catalog_compiled.intent),
{ok, ReferenceBytes} = transit_catalog:save(Original),
ok = persist_reference(ReferenceBytes),
{ok, Observation} = transit_catalog:admit(Client, Original).
```

Opening verifies the matching native definition and catalog capabilities. It
starts one owned port worker and performs no service initialization. The optional
service URL selects the direct endpoint; otherwise requests use the configured
node URL. Credentials must match the scope's realm. Current public policy governs
each request independently of saved identities and previous observations.

`compile_sql/4` uses the Transit dialect and point ingestion. `compile_sql/6`
also selects `transit | mysql` and `point | bulk`. Compilation and typed `prepare/4`
can inspect current metadata but do not admit work. `preview/2` reports the
current basis, reason and schema work. `stage/2` stores the intent content and
returns the exact reference to persist before `admit/2`. `execute/3` advances
admitted work within a positive step budget; `inspect/2` reads its original
outcome and `cancel/2` requests cancellation. A committed observation carries
accepted position, resulting definition, matched/affected counts and live rows.
Admission, preview and preparation do not establish completion.

## Typed values and definitions

Include `transit_catalog.hrl` for public records. `lookup/2` selects namespace 1;
`lookup/3` selects an explicit namespace. Metadata contains a complete basis,
authorization identity, accepted position, changed position, row count and schema.
The basis preserves connection, principal, namespace, name, stable object, branch,
immutable definition, content commitment and schema fingerprint. ALTER, RENAME,
DROP and typed mutations use it without resolving a replacement object under an
old name.

Schemas own stable column IDs, primary-key IDs and logical types. `encoding` and
`collation` remain orthogonal to the logical descriptor. Physical fields are
mandatory on the wire; missing or foreign tags reject. Shared Zig validation
owns supported conversions, collations and execution semantics. INSERT accepts
up to 1,024 rows, schemas up to 128 columns, and predicates up to 64 postfix
instructions. Logical values include exact decimals and recursive structures,
unions, lists, arrays, maps and missing/null/error/conflict cells. Aggregate
conversion bounds apply before later values are encoded. Application-owned
handler Tables reuse these codecs with their separate native turn semantics.

The mutation form is `{mutate, Basis, Mutation, point | bulk}`. Names are bounded
to 255 UTF-8 bytes; SQL to 4,096 bytes. Catalog, object, branch, operation,
definition and accepted-position identities preserve full-width unsigned 64-bit
values. Namespace, audience, role and native resource IDs retain native counter
bounds. `capabilities/1` exposes the current intent/action limits.

## Saved recovery and retention

`save/1` returns `{ok, Bytes}` for a basis, saved intent, reference, cursor,
snapshot owner, acquisition or snapshot. `restore/2` takes its explicit kind:
`basis`, `intent`, `reference`, `cursor`, `snapshot_owner`,
`snapshot_acquisition` or `snapshot`. Restore validates the current definition,
generated contract, complete binding and bounded JSON; duplicate members reject.
`load/2` restores original saved work locally without recompiling SQL. `forget/2`
releases loaded local work.

Mutations can return `{uncertain, Original, Error}`. `Original` preserves the
saved intent for staging, operation reference for admission/execution/cancellation,
acquisition for pinning, or snapshot for release. Preserve it and inspect that
same identity after loss. Malformed success replies retain uncertainty. Definite
failures remain `{error, Error}`. There is no implicit retry or replacement
operation identity, and caller closure does not cancel accepted work.

`prepare_snapshot/3` binds metadata's accepted position to an explicit owner
operation. Persist the acquisition before `acquire_snapshot/2`; resolve an
uncertain acquisition with `snapshot_status/2` on its original owner. Persist the
returned snapshot before use or release. `snapshot_metadata/2` reads the retained
definition after ALTER, DROP or name reuse under current access. Uncertain
`release_snapshot/2` retains its original snapshot; owner status resolves it,
and repeated original release is idempotent. Client closure does not release
pins or authorize expiry or physical deletion. This catalog API exposes retained
metadata, without an interactive relational SQL cursor.

## Inspection and worker ownership

`describe/1` separates configuration, authenticated subject and current policy
revision. `namespace/2`, `namespaces/1,2` and `tables/1,2,3` inspect current
namespace and Table entries. Pages contain at most eight entries. Continue with
the returned complete cursor; a changed directory cut fails and requires a new
listing. Table entries carry independent accepted positions and report
`consistency=independent`. Saved cursors and authorization IDs grant no rights.
Namespace administration, dependency controls and named KV/Document declarations
use their owning public operations; this typed adapter does not expose them.

Requests are immutable and validated before worker admission. One active native
operation is allowed per client. Loss of a waiting Erlang process does not
abandon native work; the worker remains busy until completion. `close/1` joins
active work and native port cleanup. Returned values own their data and outlive
the client. Package import does not read credentials or start a worker.
