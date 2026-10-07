# Tables and finite Arrow results

General Tables use `fuze.TableSchema`, immutable `TableData` rows/indexes and a
`TableHead` at an authorized captured resource cut. Schemas have stable object
and column identities, nullable and typed defaults, declared single/composite
primary keys, and all supported Fuze logical type families. Tables without a
primary key preserve duplicate rows under stable internal identities. See
[Table schemas](../../../../contracts/TABLE_SCHEMA_V1.md),
[Table storage](../../../../contracts/TABLE_DATA_V1.md) and
[Table mutations](../../../../contracts/TABLE_DML_V1.md) for exact contracts.

## Handler initialization

`TableCreation.step(allocator, turn, schema, limits)` initializes an
application-owned object through bounded private turns. The application supplies
the stable object identity, revision-one schema and explicit immutable-publication
quotas. The first committed step freezes these inputs. Subsequent steps must
supply them exactly, including after worker loss or application replacement;
changed schemas or quotas reject before publication. An existing independently
created namespace is never adopted or reset.

A `building` result requires an application-recorded continuation. An `applied`
result identifies the original admitted and completed input positions. The final
proposal publishes the head and creation receipt together; the result becomes
durable only when the enclosing native turn commits. A reply may be composed in
that commit. Repeating creation recovers the original receipt after writes,
schema changes or retirement; it does not restore the original schema or revive
a retired object. Application command admission, continuation scheduling and
failure policy remain explicit. This helper publishes no catalog name or grants.
General SQL lifecycle operations use the catalog owner instead.

## Captured and retained reads

`TableReader.open(allocator, source, object)` owns the exact head schema at a
captured or retained cut. A `*Turn` source is read through `turn.committed()`;
private changes are invisible to point reads and pages. A retained source comes
from `turn.openVersion(id)`. The reader cannot move to a new view, resource,
revision or head, and a cursor from another cut rejects before data traversal.
Current native read rights and retained-version dependencies remain enforced.

`get` looks up a stable row identity; `getKey` accepts complete typed primary-key
cells and verifies real key equality, including digest collisions. `page` accepts
a nullable cursor and a limit of one to eight rows. Every returned row owns its
descriptors and cells; release point rows, pages and readers with `deinit`.
Rows remain valid after the reader is released. Resident work is bounded by eight
rows, each with the shared logical value/descriptor limits, and bounded index
caches. Total Table size is independent of resident memory.

Pages follow internal row identity, not primary-key order or SQL `ORDER BY`.
A continuation from a full page may yield an empty final page. Retained readers
keep the schema and row identities at their original cut through later schema
changes; their cursors cannot be applied to current readers. Opening a retired
head rejects; historical cuts before retirement remain subject to their own
current authorization and lifetime checks.

## Mutations and queries

`TableWrite` provides recoverable point changes; `TableStatement` executes
schema-bound `fuze.TableDml` plans. Both stage bounded immutable candidates and
publish the complete successor head with committed counts and terminal receipt.
The application preserves the exact original request across steps and supplies
current operation authorization. These helpers neither submit nor commit.
Read [mutation recovery](../../../../contracts/TABLE_DML_V1.md) before composing
application outputs and bookkeeping into the final four-write native proposal.

External durable and interactive Table/KV/Document queries use
[transit-query](../../transit-query/README.md). Catalog SQL resolves shared typed
Table metadata and query sources under existing grants. Query output typing,
operator support and transport budgets remain separate from storage admission.
