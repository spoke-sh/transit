# Tables and materialization

A Table is typed application state in an explicitly configured catalog over one
durable resource. The catalog owner controls schema changes and row publication.
Native grants and current catalog permissions apply independently; a name,
retained snapshot or cached schema grants neither access nor execution rights.

The [console](../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs)
routes CREATE, ALTER, DROP, INSERT, UPDATE, DELETE and supported SELECT statements
through that catalog. An authorized new Table is discoverable without editing a
per-Table connection file or starting another writer. Provisioning the resource,
assigning its owner and granting permissions remain explicit operations.

## Schemas and identities

Tables contain 1–128 ordered named columns with the shared
[logical types](sql/types.md). Omitted nullability means nullable. A declared
single or composite PRIMARY KEY implies NOT NULL; column position creates no
constraint. Without a primary key, stable internal row identities preserve
duplicate rows. These identities are separate from user-visible identity columns,
which SQL does not provide.

Object and column identities survive rename. Dropping and recreating a name
allocates a new identity. Immutable metadata and schema revisions bind prepared
plans, saved operations and retained readers to their original meaning.
Unsupported or incompatible definitions reject before execution; stored data
and accepted work are never silently reset or decoded as another profile.

Defaults apply to omitted INSERT fields and explicit DEFAULT assignments.
Explicit NULL stays NULL and must satisfy nullability. Ordinary Table cells
store values or SQL NULL. Nested optional members may be missing; stored type
errors and conflicts are rejected at every depth. A Table can store a type
without supporting every comparison, aggregate or transport for it.

Schemas are bounded by 64 KiB of encoded metadata and shared descriptor/default
budgets. Variable values use bounded immutable chunks. Operation and resident
memory bounds do not impose a fixed total Table or catalog cardinality.

## Mutation and visibility

[INSERT](sql/insert.md), [UPDATE](sql/update.md) and [DELETE](sql/delete.md) bind
complete typed intent to the original object and metadata. Inspect, read,
create, insert, update, delete, alter and drop are separate catalog rights.
Successful SELECT or CREATE does not grant a mutation right.

Small point changes can publish their row, index, head and terminal outcome in
four native writes. Larger changes stage bounded work and freeze the source
basis. Readers see the old head until the complete successor and original
operation outcome publish atomically. A bad later row, duplicate key or failed
constraint never exposes a successful statement prefix. Concurrent conflicting
writes and DDL are fenced while that work is pending.

Matched and changed row counts come from the committed outcome. An unchanged
UPDATE can match a row while changing none. Changed means different canonical
stored bytes, including JSON text and floating zero sign; it does not imply
that JSON has a SQL equality operator.

Admission receipts, processed inputs and applied domain outcomes are distinct.
After an uncertain send, reconcile the original saved work with `.status` and
`.resume`. Repeating SQL creates new work. Cancellation can close pending work;
it cannot undo an applied operation. Revoking execution permission does not
erase outcomes or make uncertain work safe to repeat. Current inspection rights
still control outcome disclosure.

The one-mutated-resource boundary remains. Multiple Tables, independently
captured sources and catalog names do not establish cross-resource transactions.

## Schema lifecycle and retained reads

[CREATE TABLE](sql/create-table.md) publishes the name, immutable definition and
empty head. [ALTER TABLE](sql/alter-table.md) supports column and Table renames,
column addition/removal, defaults, nullability and selected exact type changes.
Metadata-only changes and complete row/index rewrites have separate execution
paths. Existing rows must satisfy every tightened constraint before publication.
Changing a default does not rewrite earlier values.

[DROP TABLE](sql/drop-table.md) removes the live name and retires its object/head
under RESTRICT semantics. Registered blocking dependencies prevent DROP;
historical references do not make a name live. Applications install dependency
records explicitly. The registry does not discover arbitrary external users.

Already captured readers retain their original schema and cut, subject to
current authorization and their own lifetimes. New admissions cannot substitute
a dropped/recreated object. Exact operation receipts remain reconcilable after
rename, ALTER or DROP. An exact historical definition contains its accepted
metadata and schema, without claiming a current live head.

DROP does not physically erase retained data. Cleanup reclaims only qualified
rejected/cancelled candidate storage, preserves identity floors and receipts,
and remains separate from accepted-history retention.

## Query and observe

Finite Table queries bind the full logical row schema and return typed values.
A complete primary-key equality or conjunction can use the collision-safe
index. Partial keys, inequalities and additional predicates use the qualified
finite scan; the complete Fuze predicate still runs. Rows are stored as immutable
row records and indexes, not columnar Arrow row groups. Arrow is an interchange
format and does not itself supply scan pruning.

Finite query pages acquire at most eight row references together. Publication
headers are validated before bounded chunk prefetch, and each decoded row retains
its schema, digest and identity checks. Interactive pull scans decode one row
at a time from those references, so a selected LIMIT does not allocate the
remaining values. Current authorization still precedes every output. This storage
page size is separate from execution-vector design.

Each [interactive query](queries.md) captures an explicit source basis and checks
current authorization before disclosure. Durable query jobs separately retain
their source and publish verified result segments. An initial result page is
an incomplete prefix. Catalog schema caches retain no permission.

[Reactive watches](reactive.md) have an explicit two-INT64-column snapshot
transport profile. Rich finite Table values do not widen that transport,
continuous SQL, Flight SQL or future joins and grouping implicitly.

## Materialize a stream

Applications materializing streams own domain decoding, validation and progress.
Staged changes need durable operation identities and publication boundaries;
recovery must never turn one accepted input into another mutation identity.
Backlog remains durable and retention defaults to unlimited.

See the [schema](../../contracts/TABLE_SCHEMA_V1.md),
[data/publication](../../contracts/TABLE_DATA_V1.md),
[DDL](../../contracts/TABLE_DDL_V1.md), [DML](../../contracts/TABLE_DML_V1.md)
and [catalog query owner](../../contracts/CATALOG_QUERY_OWNER_V1.md) contracts,
and the [catalog component guide](../../packages/zig/transit-catalog/docs/table-metadata.md).
