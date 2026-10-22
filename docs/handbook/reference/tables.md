# Tables and materialization

A Table is typed application state in an explicitly configured catalog over one
durable resource. The catalog owner controls schema changes and row publication.
Current database, schema and Table grants use native authorization; a name,
retained snapshot or cached schema grants neither access nor execution rights.

The [console](../../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs)
routes CREATE, ALTER, DROP, INSERT, UPDATE, DELETE and supported SELECT statements
through that catalog. An authorized new Table is discoverable without editing a
per-Table connection file or starting another writer. Provisioning the resource,
assigning its owner and granting permissions remain explicit operations.

The catalog binds an explicit database and initial `public` schema to stable
native authorization objects. Table metadata records its namespace and logical
role owner independently of the catalog's worker PID. Restricted readers use the
[Table service](../../../apps/transit-table-service/README.md), which keeps storage
credentials private and checks a signed original subject. Direct clients require
explicit raw-resource privileges; those privileges expose the backing resource.

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
budgets. Variable values use bounded immutable storage blocks. Operation and resident
memory bounds do not impose a fixed total Table or catalog cardinality.

## Mutation and visibility

[INSERT](sql/insert.md), [UPDATE](sql/update.md) and [DELETE](sql/delete.md) bind
complete typed intent to the original object and metadata. Every operation needs
database CONNECT and schema USAGE. Creating a Table also needs schema CREATE;
SELECT, INSERT, UPDATE and DELETE use the respective Table privilege. ALTER and
DROP require role ownership. Metadata visibility follows ownership or an
applicable Table grant. The native graph supplies the current decision, including
credential epoch and selected role, during execution and final publication.

Each head replacement preserves its immutable predecessor and native commit
position. Point changes can publish row, index and predecessor blocks alongside
the head and terminal outcome in one native turn. The turn admits sixteen blocks
and 128 KiB of encoded block data separately from four small metadata mutations.
Larger changes use bounded staging and freeze the source basis.
Readers see the old head until the complete successor and original
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

## Snapshot and change capture

`transit-query.TableChangeReader` captures a frozen Table snapshot and returns a
resume position only after its complete traversal. Later writes remain in the
Table's immutable head history while backfill is paused. `openTail` resumes that
exact object, including after rename, retirement or reuse of its former name.
The signed caller needs current native resource access, database CONNECT,
schema USAGE and Table SELECT throughout snapshot and tail delivery. A resume
position retains the original Table identity; rename, DROP or name reuse cannot
substitute another object's permissions. Every delivered batch and completion
checks current authority, including a tail reopened from a saved position.

The tail covers every committed head revision in order. Inserts have an after
row, deletes have a before row, and updates pair both values under one stable
row identity. Each transaction ends with exact previous/new positions, including
explicit transactions with no row changes. Schema changes carry both schema
references; changed schemas decode each side with its own definition.
Reservation and unchanged-data revisions advance progress without scanning the
whole relation. A caught-up event covers the reader's captured upper bound;
reopen from the last complete position to observe later writes.

Apply a transaction and save its position atomically in the consumer. A delivered
row prefix is incomplete; reconnecting from the previous position repeats that
transaction. Missing history, conflicting roots, corrupt records, expired leases
and current denial fail explicitly. There is no implicit reset or history skip.
History is retained without an opt-in expiry policy, independently of resident
memory. These Table changes do not establish a global resource snapshot or a
maintained query result. Coalesced reactive watches remain a separate interface.

## Query and observe

Finite Table queries bind the full logical row schema and return typed values.
A complete primary-key equality or conjunction can use the collision-safe
index. Partial keys, inequalities and additional predicates use the qualified
finite scan; the complete Fuze predicate still runs. Rows are stored as immutable
row records and indexes, not columnar Arrow row groups. Arrow is an interchange
format and does not itself supply scan pruning.

Finite query pages acquire at most eight row references together. Prefetch admits
at most eight complete blocks and 128 KiB; larger records use successive bounded
block reads. Each decoded row retains its schema, digest and identity checks. Interactive pull scans decode one row
at a time from those references, so a selected LIMIT does not allocate the
remaining values. Explicit result batches contain at most eight rows and 16 MiB
of canonical cells. Current authorization is checked after computation before
each batch is disclosed, including empty output and completion. The single-row
pull API uses the same check for its one row. Storage pages, execution vectors
and result disclosure have independent bounds.

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

See the [schema](../../../contracts/TABLE_SCHEMA_V1.md),
[data/publication](../../../contracts/TABLE_DATA_V1.md),
[DDL](../../../contracts/TABLE_DDL_V1.md), [DML](../../../contracts/TABLE_DML_V1.md)
and [catalog query owner](../../../contracts/CATALOG_QUERY_OWNER_V1.md) contracts,
and the [catalog component guide](../../../packages/zig/transit-catalog/docs/table-metadata.md).
