# Tables and materialization

A Table is typed application state in an explicitly configured catalog over one
durable resource. The catalog owner controls schema changes and row publication.
Current database, schema and Table grants use native authorization; a name,
retained snapshot or cached schema grants neither access nor execution rights.

Typed direct callers can bind a staged Table mutation to a durable client token
and recover its original intent after a lost reply. The catalog checks the
request fingerprint and current permissions. A token receipt establishes the
binding; the Table operation supplies admission and completion evidence. See the
[client-token contract](../../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings).
SQL sessions retain their separate account operation lifecycle.

The [console](../../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs)
routes CREATE, ALTER, DROP, INSERT, UPDATE, DELETE and supported SELECT statements
through that catalog. An authorized new Table is discoverable without editing a
per-Table connection file or starting another writer. Provisioning the resource,
assigning its owner and granting permissions remain explicit operations.

The catalog binds an explicit database and initial `public` schema to stable
native authorization objects. Table metadata records its namespace and logical
role owner independently of a worker PID. The node's
[direct Table interface](../../../contracts/DIRECT_TABLE_V1.md) keeps storage
credentials private and checks the signed original subject on every request.
It requires current catalog/schema/Table rights, without raw-resource read grants.
Each Table has its own acceptance partition within the catalog's logical scope.

The typed direct caller can observe one current definition and data position,
optionally with up to eight rows, without acquiring a snapshot or changing
storage. Metadata and rows describe the same Table root and require current
SELECT rights. A partial observation reports `more`; a later request may see
newer data. Traversal that must survive later writes uses an explicitly retained
snapshot; conditional current reads instead reject logical drift. See [current observations](../../../contracts/DIRECT_TABLE_V1.md#current-observations)
for exact bounds and response semantics.

A caller can explicitly delegate reads of one exact Table definition and data
frontier to an executor through `DirectReadDelegation`. The grant names one pin
owner and immutable application-work commitment. The executor uses its own
credential to acquire, recover, read or release that pin; it gains no general
Table or catalog access. Both credentials and the caller's current source rights
are checked before publication and disclosure. A retained grant cannot silently
refresh a revoked caller proof or select newer data. See the
[delegated-read contract](../../../contracts/DIRECT_TABLE_V1.md#delegated-retained-reads)
for the allowed operations and recovery rules. Captured-query owners retain
the grant through admission, worker replacement and explicit pin cleanup.

## Immutable Table branches

The direct Table service can create a named, read-only branch of one explicitly
selected Table. Supply the exact definition and accepted position from Table
lookup, a branch name, `full_data` or `schema_only`, and an original account/client
token through the `DirectBranch.Request.create` action. The shared Zig caller uses
`DirectBranch.call(client, request)` and the existing signed `/table/v1` endpoint.
SQL branch commands and additional language convenience wrappers are unavailable.

Inspect the original token to observe `admitted`, `published`, `abandoning` or
`cancelled`. A published head identifies immutable schema and data, including
rows accepted before flushing. Parent writes and later physical collection do
not change its rows. Use `source` to inspect schema and `scan` to read bounded
pages; retain each response until its bytes have been consumed. Complete coverage
requires the original cursor sequence and its terminal row count.

After an uncertain reply, inspect or advance the same token. If the parent
advanced before pin acquisition, cancel the pending operation and deliberately
choose a fresh source for new work. Cancellation releases unpublished preparation
before freeing its name; it cannot remove a published branch. Published branches
have unlimited retention. Schema-only branches return zero rows but currently
retain the full source pin as well as its schema.

Creation requires source SELECT and namespace CREATE; later inspection and
reads still require the original principal's current source access. A branch
name or retained head grants no access. See the
[installed branch contract](../../../contracts/BRANCH_V1.md#installed-immutable-table-branches)
for exact recovery and lifetime rules. Writable branches, whole-catalog cuts,
merge, restore and published branch deletion remain unavailable.

## Schemas and identities

Tables contain 1–128 ordered named columns with the shared
[logical types](sql/types.md), plus orthogonal physical encoding descriptors
($\epsilon$: `plain`, `bitpacked`, `rle`, `dictionary`, `fsst`, `comp3`, `zoned`,
`comp`, `ibm_hfp`, `ebcdic`) and collation descriptors ($\kappa$: `none`,
`utf8_binary`, `ascii_ci`, `ebcdic_cp037`, `ebcdic_037_pad`,
`ebcdic_1047_nopad`, `icu_root`). Encodings and collations
are validated against the column's logical type and committed into the schema
layout fingerprint so physical layout or collation evolution is tracked explicitly.
The [representation contract](../../../contracts/TABLE_SCHEMA_V1.md#physical-representation-and-collation)
defines admitted type/codec pairs. CP037 accepts UTF-8 scalars U+0000–U+00FF;
HFP accepts exactly representable values in its normalized range and preserves
signed zero. Unrepresentable values reject before mutation acceptance. Text
collations use NO PAD except `ebcdic_037_pad`, which compares as if the shorter
string were padded with CP037 spaces. Thus `A` and `A ` are the same key under
that profile; original stored text retains its spaces. Both code pages require
U+0000–U+00FF, and CP1047 has its own punctuation weights. `icu_root` rejects
explicitly.

The direct typed interface preserves physical descriptors in its schema bytes.
The neutral JSON schema and language SDKs preserve each column’s explicit
`encoding` and `collation`, including default `plain`/`none` values. Missing or
unknown wire descriptors reject; constructors supply defaults for new schemas.
SQL CREATE TABLE and ADD COLUMN accept `COLLATE UTF8_BINARY`, `COLLATE ASCII_CI`,
`COLLATE EBCDIC_CP037`, `COLLATE EBCDIC_037_PAD` and
`COLLATE EBCDIC_1047_NOPAD` on text columns. Omission keeps binary comparison.
Direct and captured finite SELECT, prepared comparisons and UPDATE/DELETE
predicates use that declared collation, as do primary-key lookups and range
counts. Saved plans bind each input column's collation alongside its logical
type and exact source. `ENCODING` clauses, expression-level overrides and changing
an existing column's collation through SQL are unsupported. Relational text joins,
grouping and canonical group order use the same declared collations.

Omitted nullability means nullable. A declared
single or composite PRIMARY KEY implies NOT NULL; column position creates no
constraint. Without a primary key, stable internal row identities preserve
duplicate rows. These identities are separate from user-visible identity columns,
which SQL does not provide.

Object and column identities survive rename. Dropping and recreating a name
allocates a new identity. Immutable metadata and schema revisions bind prepared
plans, saved operations and retained readers to their original meaning.
Unsupported or incompatible definitions reject before execution; stored data
and accepted work are never silently reset or decoded as another profile.

Accepted active definitions also retain their exact ADD-time column origins in
a paged metadata directory. Later default changes, column removal, compaction
and Table retirement do not erase this interpretation evidence. A staged schema
artifact is not an accepted definition. Retaining definitions does not retain
old rows; an exact data read still needs its own retained cut.

Explicit schema projection maps a retained source forward to an accepted
definition of the same object. It matches stable ColumnIds, uses frozen ADD
values and keeps source evidence separate from the target. It rejects backward
mapping and type/collation conversion. Ordinary historical reads use the original
schema. Append `PROJECTING TO CURRENT` or `PROJECTING TO SNAPSHOT 'target'`
to a historical SELECT, DESCRIBE or EXPLAIN to choose a target explicitly. CURRENT
resolves once during preparation; later defaults, DROP or name reuse do not
replace that prepared target. A target snapshot supplies metadata for the original
object, not its rows. See the [historical contract](../../../contracts/HISTORICAL_CATALOG_V1.md#explicit-schema-projection)
for bounds, provenance and current authorization.

The protocol package also validates offline index declarations and coverage
descriptors. They bind stable index/source/column identities, comparison and
constraint semantics, build generations and exact source cuts. Definition,
maintenance progress and published coverage are distinct; none grants access.
The [index contract](../../../contracts/INDEX_LIFECYCLE_V1.md) owns their bounds
and comparison rules. The installed catalog exposes no secondary-index
declaration or build operation, and SQL has no executable `CREATE INDEX` form.

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

Each Table has its own write-ahead acceptance log. Admission retains complete
frozen work; execution stages private row/index changes and publishes one Table
successor with its terminal outcome. Readers see the prior state until that
acceptance. A bad later row, duplicate key or failed constraint exposes no
successful statement prefix. Conflicting writes and DDL reject stale definition
or data expectations.

Concrete batches contain at most 1024 changes within 4 MiB of framed work.
Typed predicate UPDATE/DELETE plans select rows inside the Table owner under
explicit work budgets. These data operations do not use actor mailbox frames or
native turn-block quotas. Point writes can remain in retained WAL records;
bulk ingestion publishes immutable `.tseg` objects. The local server enables
bounded automatic point flushing by default, based on pending rows, bytes and
age. See the [storage boundary](storage.md#direct-table-data)
for acceptance, retention and physical cleanup limits.

Matched and changed row counts come from the committed outcome. An unchanged
UPDATE can match a row while changing none. Changed means different canonical
stored bytes, including JSON text and floating zero sign; it does not imply
that JSON has a SQL equality operator.

Admission, Table completion and any application's native progress are distinct.
After an uncertain submission, the console observes the original operation internally
and reports when its outcome cannot be confirmed. Native callers reconcile the
original saved identity through the owning operation API. Repeating SQL creates
new work. Cancellation can close pending work;
it cannot undo an applied operation. Revoking execution permission does not
erase outcomes or make uncertain work safe to repeat. Current inspection rights
still control outcome disclosure.

The direct atomic domain is one Table statement or batch. Native application
turns separately retain their one-mutated-KV-resource boundary. Multiple Tables,
independently captured sources and catalog names establish no cross-owner
transaction. Applications retain exact dispatch references before admission and
reconcile the original Table outcome before advancing native progress.

## Schema lifecycle and retained reads

[CREATE TABLE](sql/create-table.md) publishes the name, immutable definition and
empty head. [ALTER TABLE](sql/alter-table.md) supports column and Table renames,
column addition/removal, defaults, nullability and constraints. Metadata changes
and bounded existing-row validation have separate execution paths. Populated
Tables reject changes requiring physical rewrites until the phased rewrite
runtime is available. Existing rows must satisfy tightened constraints before publication.
Compatible additions, non-key renames and drops project older physical rows by
stable column identity. Changing a default does not rewrite earlier values or
change a column's frozen ADD-time value. Flush and bounded compaction normalize
selected rows later; retained readers keep their original schema and values.

Table-level CHECK constraints enforce bounded deterministic comparisons after
defaults on every candidate write, including private transaction writes. TRUE
and NULL pass; FALSE, missing, type_error and conflict reject the whole mutation.
`NOT VALID` defers validation of existing rows while enforcing new writes.
`ALTER TABLE ... VALIDATE CONSTRAINT` publishes validation only after a complete
bounded scan; exceeding its work budget preserves the old definition.

`FOREIGN KEY ... REFERENCES ... NOT ENFORCED` records a staged declaration with
exact parent definition and column identities. It checks compatible types,
collations and the parent primary key without asserting row-level integrity.
The catalog protects parent columns before publishing the child and removes
obsolete protection through recoverable bounded cleanup. Enforced foreign keys
and referential actions await the index-backed enforcement runtime. Staged
constraints never dispatch CASCADE or SET NULL writes.

[DROP TABLE](sql/drop-table.md) removes the live name and retires its object.
Historical references do not make a name live. The direct Table owner rejects
DROP while an explicitly registered definition dependency remains. Namespace
DROP separately rejects live Tables and pending Table declarations in that
namespace. Neither path discovers arbitrary external consumers.

Typed callers use `dependency_operation` to register or remove an exact source
and dependent definition, and `dependencies` to inspect either graph direction.
Registration requires current source privileges and dependent metadata write
access; it does not publish or activate the dependent or retain a read cut.
The dependent owner registers before publication and removes after retirement
or abandoned-publication recovery. These steps are separate operations.
[Named resource owners](state.md#state-and-higher-level-resources) explicitly
register each declared source using the allocated dependent interpretation.
The [named-query publication plan](queries.md) saves one registration per
distinct source and checks current membership before returning its native
publication command. Neither path infers dependencies from values or read pins.
ALTER and RENAME retain the original edge and may make its definition stale.

Graph pages filter metadata the caller cannot inspect. A blocked DROP reports
a generic dependency reason even when its blocker is hidden. Each page scans at
most four edges, and an empty page with a continuation is incomplete. A catalog
change invalidates the continuation. Retired consumers require explicit edge
removal; native realm administrators with source ownership can remove an orphan
without dependent-resource rights. That cleanup does not delete or cancel the
consumer. The [dependency contract](../../../contracts/DIRECT_TABLE_V1.md#explicit-definition-dependencies)
defines exact authorization, receipts and recovery.

The typed `preview` operation checks current rights, exact expectations, name
availability and schema-evolution work without staging or admitting a change.
It does not scan rows to certify tightened constraints. Save the complete
`DirectTableIntent`, explicitly admit it, then inspect, execute or cancel its
original binding. Outcomes distinguish `not_observed`, `admitted`, `committed`,
`finalizing`, `rejected` and `cancelled`; inspection alone starts no work.
`finalizing` carries a committed Table outcome whose required dependency cleanup
is still pending. Continue the original operation to settlement; a retry as new
SQL would be a different operation.

Already captured readers retain their original schema and cut, subject to
current authorization and their own lifetimes. New admissions cannot substitute
a dropped/recreated object. Exact operation receipts remain reconcilable after
rename, ALTER or DROP. An exact historical definition contains its accepted
metadata and schema, without claiming a current live head.

Retained projection inspection explains how those rows are interpreted without
scanning their payloads. `projection_definitions` reports one physical schema
generation per page: its exact definition, schema revision, live locator count,
and each logical column's stable physical ID or frozen ADD-time definition and
initial cell state. Current metadata visibility is required. The separate
`projection_locations` read requires SELECT and reports up to eight original row
identities with their physical definition and WAL or immutable segment reference.
Both require an existing snapshot owned by the caller and recheck current rights.

These pages report retained directory coverage. They do not verify that every
payload is available or decoded, and their completion is separate from query
completion. Traverse every continuation to account for the original total; an
early stop reports partial coverage. Cursors bind the exact pin, so later ALTER,
DROP or name reuse cannot change the inspection basis. The shared catalog caller
exposes both reads through its `projection` action. Inspection never acquires,
renews or releases retention.

DROP does not physically erase retained data. The installed direct service
exposes no Table garbage collector; accepted history, staged intents and operation
receipts remain separate from logical retirement.

## Snapshot and change capture

The direct caller explicitly acquires a history lease with `retain_history`.
Its original definition and frontier identify the initial source. `history`
traverses a fixed interval of physical log positions and returns ordered logical
acceptances, including accepted no-ops. Pages containing only physical progress
can be empty and still advance their cursor. `history_source` and `history_scan`
read an exact retained acceptance under its original schema. All operations need
current CONNECT, USAGE and SELECT and a live lease, including empty output.

The typed `TableChangeReader` uses that same retained lease for snapshot backfill
and subsequent tails. Its saved position binds the original connection, object,
lease and exact history record. Reopening repeats a partially delivered
transaction; save a successor only with the complete transaction's application.
Each tail has an explicit fixed upper position. Closing the local reader does
not release durable retention or authorize acquiring a replacement historical
cut. The caller explicitly retires the original acquisition when finished.

Maintained-query execution uses these leases for bounded initial backfill and
successive logical changes. Inserts have an after row, deletes have a before
row, and updates pair both values under a stable row identity. Native computation
progress records only fully processed source changes; its bounded physical scan
cursor is separate. A row prefix establishes neither complete source coverage
nor a verified result. Independent Table cuts remain independent.

Missing history, conflicting roots, corrupt records and current denial fail
explicitly. There is no implicit reset or history skip. Releasing a lease closes
its historical reads. Retention defaults to unlimited, independently of resident
memory; physical reclamation requires its own coverage and lifetime contract.
See [retained reads](../../../contracts/DIRECT_TABLE_V1.md#retained-reads-and-binary-payloads)
and [computation lifetimes](queries.md). Coalesced reactive watches are separate.

## Query and observe

The direct `key_range` operation reads an explicitly retained Table using optional
inclusive/exclusive bounds on complete storage keys. Keys follow the original
primary-key columns and collations; keyless Tables use stable row identities.
Each page contains at most eight owned rows under a byte budget. Its continuation
binds that snapshot and interval, and current rights apply again after buffering,
including empty results. `DirectTableReader.readRange` validates row order and
bounds without changing its independent sequential scan coverage. It reads
ordinary snapshots; historical-lease range reads are not exposed. Range completion
covers the requested interval, while `total_rows` describes the whole source.


Finite Table queries bind the full logical row schema and return typed values.
A conjunction containing exactly one equality per declared primary-key column
uses the collision-safe index in captured and finite retained SELECTs, including
prepared execution. Finite `COUNT(*)` can additionally use the retained range
index for comparisons joined by AND on a single-column primary key. Other
inequalities, partial keys and additional predicates use the qualified finite
scan; the complete Fuze predicate still runs. The [query reference](queries.md#interactive-sessions)
defines count eligibility, completion and source-order limits. The retained identity/key
indexes resolve rows in WAL-backed records or immutable segments. Arrow is an
interchange format and does not itself establish segment pruning.
Finite SELECTs retain the scan when a valid comparison literal cannot fit the
stored key's character or encoded-byte limit; lookup qualification does not
narrow the query's valid comparison values.

Direct source pages return at most eight owned rows under an explicit byte
budget, preserving their original schema, digest and identity checks. Interactive
pull scans consume one decoded row at a time from the bounded page, so LIMIT
does not allocate the remaining Table. Explicit result batches contain at most eight rows and 16 MiB
of canonical cells. Current authorization is checked after computation before
each batch is disclosed, including empty output and completion. The single-row
pull API uses the same check for its one row. Storage pages, execution vectors
and result disclosure have independent bounds.

Each [interactive query](queries.md) captures an explicit source basis and checks
current authorization before disclosure. Durable query jobs separately retain
their source and publish verified result segments. An initial result page is
an incomplete prefix. Catalog schema caches retain no permission.

Typed direct callers can also read current Table data without retaining a
snapshot. `observe` returns metadata and an optional bounded first page.
`read_current` performs a primary-key lookup or scans an ordered suffix under
an exact definition and the original Table position. It rejects if logical data
changes between pages; physical flushes and accepted no-ops do not invalidate
that position. These reads require current CONNECT, USAGE and SELECT, including
for absence and empty output. They create no retention pin. A complete scan
requires uninterrupted traversal from the beginning and a verified row count;
a failed page cannot be replaced with a newer source position. See the
[direct read contract](../../../contracts/DIRECT_TABLE_V1.md#current-observations)
for budgets, cursor semantics and response checks.

[Reactive watches](reactive.md) have an explicit two-INT64-column snapshot
transport profile. Rich finite Table values do not widen that transport,
continuous SQL, Flight SQL or future joins and grouping implicitly.

## Materialize a stream

Applications materializing streams own domain decoding, validation and progress.
Staged changes need durable operation identities and publication boundaries;
recovery must never turn one accepted input into another mutation identity.
Backlog remains durable and retention defaults to unlimited.

See the [schema](../../../contracts/TABLE_SCHEMA_V1.md),
[direct Table](../../../contracts/DIRECT_TABLE_V1.md) and
[data lifecycle](../../../contracts/DATA_LIFECYCLE_V1.md) contracts, and the
[catalog owner guide](../../../packages/zig/transit-catalog/docs/direct-catalog.md).

## Selected historical catalogs

The public Zig `transit_catalog.DirectHistory` operations select exact Table
bindings, acquire retention with an original account/client token, and publish
a `DataLifecycle.Snapshot` only after every source has a verified pin. Progress
can be inspected and resumed after an uncertain reply. A selected set can retain
old names, columns, defaults and collations through later ALTER, DROP and name
reuse. It includes accepted WAL-only rows and the physical schema directory.

Use the published [SQL snapshot selector](sql/as-of.md) for historical SELECT,
SHOW TABLES, DESCRIBE and EXPLAIN. Current metadata and SELECT privileges remain
separate and are checked on the original objects before disclosure. Independent
selections make no common transaction-cut promise. A transfer from an acquired
transaction instead preserves its common cut, frozen Table names and namespaces
and complete source commitment. History acquires independent pins while a paged
reservation protects the original transaction pins. Completing the transaction
does not release those historical copies. Explicit release changes
availability without erasing the original acquisition outcome; reader close
does not release that separately retained basis. See the
[exact contract](../../../contracts/HISTORICAL_CATALOG_V1.md) for bounded progress,
private-pin ownership, collection roots and failure distinctions.
