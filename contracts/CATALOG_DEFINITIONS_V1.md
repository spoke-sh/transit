# Versioned catalog interpretations v1

`transit-catalog.CatalogDefinition` and `DirectDefinition` own immutable view,
property-graph and foreign-layout definitions. They share the DirectCatalog's
stable object identities, namespace/name directory, current native permissions,
operation binding and dependency graph. This profile creates metadata objects;
it does not allocate Table partitions or start computations.

## Publication and recovery

A request binds the current Transit definition, original operation, stable target,
expected prior definition and complete intent digest. Preview validates the
proposal and current rights without native registration, immutable-object writes,
data acquisition or execution. `accept` first binds the original request and
prepares native object registration, then checks current namespace/object rights
and every exact source definition. Registration is preparation, not publication.
An interrupted registration returns `registration_pending`; retry the same
request. `inspect` never supplies a new identity or repeats an effect.

One catalog log record atomically publishes the immutable definition, qualified
name, exact dependency edges and terminal operation outcome. Replacement, rename
and drop create another immutable definition; prior accepted definitions remain
inspectable. Lost publication replies recover that original outcome. Dependencies
owned by these definitions cannot be modified through the generic edge API.
Dropping a definition removes its live dependency edges in the same commit.
Historical retention neither blocks later DDL nor grants access to retired data.

`TCDESC01` artifacts bind the shared definition, object/revision, namespace and
native authorization object, output FTS1 schema, exact source declarations and
schemas, and typed body. Canonical encoding, length and SHA-256 are verified on
load. An incompatible shared definition rejects; no legacy decoder is supplied.
Artifacts are at most 384 KiB. A declaration has at most four exact Table sources;
this bounds one operation, not the durable catalog's cardinality. Catalog objects
and accepted revisions use paged directories. Retention defaults to unlimited.

## View interpretation

The qualified view has one exact Table source and an accepted canonical FQP1
projection/filter plan. Output columns have independent stable ColumnIds.
Publication verifies their logical types, nullability, semantics and collations
against the plan. Stored SQL is provenance and is never reparsed during query,
inspection or recovery. Source changes require explicit replacement. Nested
views, cycles, definition-time aggregates, scalar computations and limits refuse.

Database SQL SELECT, DESCRIBE and EXPLAIN can resolve these views. Historical
resolution selects the view and its Table dependency from the retained catalog
before outer SQL compilation. Replacing or dropping the current view, renaming
its source, or reusing its name cannot alter that historical interpretation.
The outer finite single-Table compiler supports projection, typed parameters,
filters, aggregates, scalar expressions and limits over the accepted output.
The source filter runs before the outer predicate; combining their Boolean
programs would incorrectly expose errors from excluded rows.

The executor borrows the original historical pin, verifies current SELECT on both
view and source, and repeats checks for schema, buffered rows, empty and repeated
terminal results. Result observations identify the accepted view in addition to
source definition, pin and catalog. EXPLAIN reports both stages and acquires no
pins, reads no segments, and dispatches no effects. View filtering currently ends
a borrowed compute morsel at each returned row to preserve page lifetimes; it
makes no vector throughput claim. Work and source requests remain bounded.

Relational joins over views, captured view execution, transaction composition and
explicit schema projection of a view refuse in this profile. Captured historical
Table execution retains its separate qualified contract.

## Graph and foreign interpretations

Property-graph definitions bind stable vertex/edge mapping IDs, labels, keys,
endpoint references and logical property ColumnIds to exact Table definitions.
Keys and endpoint types, nullability, semantics and source mappings must agree.
Replacement preserves identity high-water marks and cannot reuse retired mapping
or output-column IDs. Each graph has at most sixteen vertex and sixteen edge
mappings. Graph traversal and general graph SQL remain outside this profile.

Foreign definitions bind fixed record/field offsets, widths, physical codecs,
malformed-value policy, output logical types and semantic descriptors. Captured
input has an exact byte length, SHA-256 and explicit `retained`/`unavailable`
availability. Its provenance URI is descriptive; recovery never refetches it.
A retained input is verified before accepting its definition and historical cut.
Captured inputs use the existing 4 MiB work limit. Field codecs include bounded
COMP, COMP-3, ZONED, IBM_HFP and EBCDIC layouts. Logical types, physical decoding
and comparison semantics remain separate.

Pure decoding of an already verified record either rejects a malformed value or
returns the declared `type_error` cell. Missing artifacts, checksum failures and
incompatible formats are storage/definition failures, never ordinary cells.
General foreign scans and connector dispatch remain outside this profile.

## Historical selection and inspection

A historical selection separately counts Table sources and metadata definitions.
Selecting a view or graph includes its exact Table dependency closure. Existing
selected Table cuts are preserved when their definition agrees; selection never
silently refreshes a previously selected data frontier. Publication verifies all
Table pins and descriptor artifacts under one current policy epoch. Epoch changes
restart verification against the same selection. The retained-source directory
contains only Table pins; the catalog directory binds interpretation metadata.
A foreign-only catalog has zero Table sources and independent consistency.
Its selector is valid metadata evidence and implies no data snapshot or new pin.

`DirectDefinition` supplies native lookup, exact inspection, historical lookup and
bounded listing. `Catalog.call(.definitions)` and `DirectCatalogRead` expose the
same reads as owned neutral values, including full-width decimal identities,
logical schemas, exact dependencies and typed mappings. Pages contain at most
four disclosed definitions. Continuations bind connection, namespace and selected
snapshot; current pages remain independent observations. Empty pages do not prove
exhaustion when a continuation exists. Inspection requires current metadata rights
on original objects; row access is separately checked. Released selectors refuse.
Board consumes this read subset and clears failed observations. None of these
reads activate a computation, fetch a URI, or acquire retention.

See [historical catalogs](HISTORICAL_CATALOG_V1.md),
[direct requests](DIRECT_TABLE_V1.md), and
[Table interpretation](TABLE_SCHEMA_V1.md).
