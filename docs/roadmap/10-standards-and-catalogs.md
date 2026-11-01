# 10. Standards, collations and historical catalogs

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** In Progress ([remaining implementation plan](#remaining-implementation-plan--2026-11-01); [delivered evidence](#delivered-implementation-evidence--2026-10-30))

Establish historical query, collation/encoding fidelity, multi-model and branch
semantics using the [grammar inventory](../handbook/reference/sql/grammar-surface.md),
[query model](../handbook/internals/query-engine.md) and
[state model](../handbook/internals/state-model.md).

Extend the [shared data lifecycle](01-declarative-data-lifecycle.md) and
[manifest-backed storage hierarchy](02-storage-and-query-performance.md), using
the [transaction/snapshot contract](05-transactions-and-atomic-composition.md).
Historical retention extends a qualified basis; it neither keeps a transaction
session open nor makes unrelated source versions globally atomic.
Historical inspection must answer which definition, physical encoding and
collation interpreted the data, which immutable Manifest (`manifest/v{N}`) and
`.tseg` segments formed the snapshot, what a derived result depended on and
which current policy (`policy_epoch`) permits disclosure. Do not introduce a
second catalog identity or confuse a historical definition with current rights.

## Delivery sequence

The catalog/snapshot contract in
[#125](https://github.com/spoke-sh/transit/issues/125), retention/pins in
[#127](https://github.com/spoke-sh/transit/issues/127), and exact codec/collation
and layout identities in [#118](https://github.com/spoke-sh/transit/issues/118)
and [#128](https://github.com/spoke-sh/transit/issues/128) are foundations from
milestones 1–2. This milestone implements historical binding and conformance
over those contracts, rather than introducing a second snapshot representation.

1. **Publish a machine-readable standards and collation ledger:** edition/correction,
   feature, owner, dependencies, deviations and separate
   `parse`/`lower`/`execute`/`recover`/`transport` states. Include explicit
   collation descriptors (`UCS_BASIC`, `EBCDIC_037_PAD`, `EBCDIC_1047_NOPAD`,
   `ASCII_CI`, versioned `UCA`) and physical encoding rules (`COMP-3`, `ZONED`,
   `COMP`/`COMP-4`, `IBM_HFP`, `EBCDIC`). Generate capabilities and licensed
   positive/negative fixtures.
2. **Define shared operators and read/mutate/capture/dispatch effects:** propagate
   determinism, fallibility, 5-state cell tags (`value`, `null`, `missing`,
   `type_error`, `conflict`), collation rules, change mode and work bounds.
   Explanation (`EXPLAIN`) does no work.
3. **Define manifest-backed historical catalogs:** bind stable catalog/column
   identities (`CatalogId`, `DefinitionId`, `ColumnId`), ancestry, column
   encodings and collations, immutable `.tseg`/`.tdel` inclusion lists,
   consistency basis (durable manifests and retained `TransitLog` frontiers,
   including accepted unflushed data), typed
   selectors, current access (`policy_epoch`) and conditional head publication.
4. **Bind historical schemas, collations, views, graph mappings and decoders before resolving names or compiling:**
   ensure `FOR SYSTEM_TIME AS OF` queries evaluate comparisons, zone-map pruning,
   sort orders and foreign/mainframe decodings against the exact definition and
   collation recorded at the snapshot manifest, while checking authorization
   against the current `policy_epoch`. Moving a branch cannot change an accepted
   request's basis.
5. **Define declarative relational integrity (`CHECK` and `FOREIGN KEY` constraints) and lazy vs. phased schema evolution:**
   bind deterministic row-level `CHECK` expressions (preserving 5-state `type_error`
   and `null` rules) and cross-table `FOREIGN KEY ... REFERENCES ...` declarations
   (`RESTRICT`, `NO ACTION`, `CASCADE`, `SET NULL` on update/delete) to stable
   `CatalogId`, `DefinitionId` and `ColumnId` identities in the catalog dependency
   graph. Separate metadata- and projection-only `ALTER TABLE` evolutions—evaluated
   lazily on read by projecting each historical `.tseg` segment's recorded
   `DefinitionId` and 5-state `missing`/default cells into the active schema—from
   physical type or collation rewrites, which must execute through the recoverable
   online phased rewrite lifecycle in [Milestone 11](11-indexing-and-access-paths.md)
   rather than blocking large tables with synchronous full-table rewrites.
6. **Formalize companion orthogonal type families ($\tau \perp \kappa \perp \epsilon$) across Ranges, Dense Vectors, Decimal Arithmetic, Pinned-TZ Timestamps and Spatial Descriptors:**
   extend [`FUZE_TYPES_V1.md`](../../contracts/FUZE_TYPES_V1.md) and
   [`TABLE_SCHEMA_V1.md`](../../contracts/TABLE_SCHEMA_V1.md) in a single
   current-v1 cutover so downstream indexing, incremental dataflow, search and
   geospatial milestones share one rigorous type foundation:
   - **Canonical Ranges & Multi-Ranges (`RANGE<T>`, `MULTIRANGE<T>`):** support
     discrete and continuous intervals over `INT64`, `DECIMAL`, `DATE`,
     `TIMESTAMP` and `TIMESTAMPTZ` inheriting the element type's $\kappa_T$ order
     with `[lower, upper)` canonicalization for discrete domains and preserved
     inclusivity for continuous domains, Allen's interval predicates (`&&`
     overlaps, `@>` contains, `-|-` adjacent), and sorted non-overlapping
     `MULTIRANGE` interval runs (serving as the 1D base case of
     [Milestone 12's](12-sql-and-dataflows.md) `PERIOD FOR valid_time` and
     [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md) `BBOX` /
     `S2` cell coverings).
   - **Unboxed Dense Numeric Vectors (`VECTOR(dim, elem_type)`):** distinguish
     fixed-dimension `FLOAT32`, `FLOAT16`, `BFLOAT16`, `INT8` and `BINARY`
     embedding/coordinate vectors (stored as 64B-aligned unboxed SIMD slabs with
     zero per-element 5-state tag overhead and bound to a distance metric
     descriptor $\kappa_{\text{metric}} \in \{\text{L2\_SQUARED}, \text{COSINE},
     \text{DOT\_PRODUCT}, \text{HAMMING}\}$) from recursive 5-state `ARRAY` cells.
   - **Deterministic Decimal Arithmetic & Pinned-Timezone Timestamps (`DECIMAL`, `TIMESTAMPTZ`):**
     specify exact scale-promotion and rounding rules ($\kappa_{\text{numeric}}
     \in \{\text{REJECT}, \text{HALF\_EVEN}, \text{TOWARD\_ZERO}\}$) for
     `DECIMAL(p, s)` arithmetic and aggregates, and bind `TIMESTAMPTZ` operations
     (`AT TIME ZONE`, calendar bucketing) to an immutable IANA `tzdb` version
     digest ($\kappa_{\text{tz}}$, e.g. `tzdb_2026a`) recorded in `manifest/v{N}`
     so `FOR SYSTEM_TIME AS OF` queries remain bit-for-bit reproducible across
     future timezone database updates.
   - **Spatial & 3D Volumetric Reference & Precision Descriptors ($\kappa_{\text{spatial}}$):**
     reserve the catalog descriptor bindings (`SRID`, vertical datum / unit
     scale / axis orientation `RightHanded_ZUp` vs. `YUp`, `PLANAR` vs.
     `GEODESIC` manifold, 2D/3D snap-rounding grid scale $\delta_{\text{grid}}$,
     Shewchuk exact `orient2d`/`orient3d`/`incircle`/`insphere` predicates, and
     `S2_HILBERT` / `H3` / `HILBERT_3D` space-filling curve order) consumed by
     [Milestone 17](17-geospatial-and-spatio-temporal-computing.md).
7. **Expose historical inspection and explicit projections through shared operations:**
   distinguish metadata permission from row/segment access and report exact
   manifest provenance, constraint dependencies and per-segment schema projection
   coverage.

## Boundaries and evidence

Bind [index definitions and coverage](11-indexing-and-access-paths.md) to these
same retained source/column identities, declared `FOREIGN KEY`/`CHECK` constraints
and exact comparison/collation versions.
Specify rejection or rebuild when an index cannot interpret a requested cut;
current physical indexes are not automatically valid for historical queries.
Register indexing DDL/access-method options as explicit Transit extensions with
separate parse, execution and recovery evidence. A normalized key codec must be
proved against every admitted comparison profile; its existence does not imply
universal UCA, type, direction or five-state support.

Target selected SQL:2023, SQL/JSON, SQL/PGQ and SQL/MED features explicitly.
GQL, Cypher and PGQL need separate frontend/compatibility evidence; the later
[SQL grammar, standards comparison and dialect ergonomics milestone](34-sql-grammar-and-dialect-ergonomics.md)
audits the complete pre-release SQL grammar against industry dialects (PostgreSQL,
DuckDB, Snowflake, ClickHouse, GoogleSQL and Materialize/Flink) and qualifies
compile-time ergonomic desugarings (`FROM`-first queries, `GROUP BY ALL`,
`ORDER BY ALL`, `SELECT * EXCLUDE/REPLACE`). Reserve
system-time syntax for temporal semantics; resource revisions, application
revisions, `TransitLog` LSNs and snapshot manifest versions remain distinct types.

Qualify rename/drop/recreate, changed historical views, collation-sensitive
historical comparisons (`EBCDIC` versus `UCS_BASIC`), unavailable/expired
`.tseg` history, lazy multi-version `.tseg` schema projection, declarative `CHECK`
and `FOREIGN KEY` catalog bindings, old-column success/new-column rejection,
explicit projections, metadata-only rights, revocation after a prefix and branch
movement after admission. Publish independent transition/canonical fixtures before
implementing branch storage.

## Remaining implementation plan — 2026-11-01

### Outcome and source basis

**Source basis:** fetched `origin/main` at
`c8d060cb2dfcf3bc531ef2e41fcdf7d4f172c2d5`. This plan replaces the earlier
P0–P8 sequence with completion work against that source. The
[October 30 record](#implementation-plan--2026-10-30) preserves the initial
plan and delivered helper evidence. Milestone 10 remains **In Progress**;
the source audit itself establishes no new runtime qualification.

An application must be able to retain a declared data basis, evolve names and
schemas, then query or inspect that original basis with its original meaning.
The result identifies its catalog, definitions, data cuts, interpretation rules
and projection coverage. Current policy still governs every disclosure. A second
journey declares row-local integrity and inspects constraint dependencies without
mistaking a staged foreign key for enforced integrity.

Deliver these journeys first over the installed local direct Table owner, native
SQL sessions and public Zig client. Preserve all affected existing consumers in
the coordinated cutover. Full closure also requires the companion type families,
versioned view/graph/foreign bindings, and shared inspection described below;
a Table-only demonstration does not waive those gates. Direct KV/Stream/Queue
and Document historical execution is admitted per qualified owner, not inferred
from a shared descriptor. New broad language coverage, writable branches,
index-backed foreign keys and general graph/foreign execution retain their
existing milestone owners.

### First integrated increment — 2026-11-01

The capability ledger now generates the public support matrix, records explicit
unverified standards references and MIT fixture provenance, rejects dependency
cycles, and checks positive/negative cases against the production DDL, relational
and inspection entry points. Analytical, search, dataflow and policy helpers no
longer imply public SQL support.

CP037 PAD SPACE and CP1047 NO PAD are integrated through Table schemas, SQL
CREATE/ADD COLUMN, defaults and row validation, saved query plans, comparison
keys, relational hashes, compressed predicates and affected language bindings.
Existing CP037 NO PAD is preserved. Dictionary comparisons retain every distinct
stored value when multiple codes compare equal. The coordinated current-v1
cutover updates reflected resources and independent signing/encoding fixtures;
old schemas and shared definitions reject before execution.

The owning tests cover index/scan agreement, prepared and captured plans,
UPDATE/DELETE with retained reads, disk reopen, padded-key conflicts, code-page
punctuation, zone-map pruning, and six-profile consumer wire fixtures. Executing
these checks is required for qualification; their presence alone is not evidence.

This completes the collation integration slice, not Milestone 10. P0's remaining
historical/effect contracts, the other P1 type families, P2–P6, broader historical
client work and final P8 closure remain open. The following source-basis table
records the original audit, before this increment.

### Current implementation and remaining gaps

The next implementation increment persists bounded CHECK and explicitly staged
foreign-key descriptors in Table schemas. SQL and typed writes enforce CHECK,
including transaction candidates; NOT VALID defers only old-row validation.
Foreign-key publication registers exact parent/column protection before child
visibility and records bounded original-operation cleanup. `finalizing` separates
an accepted Table commit from completed dependency settlement. Physical rewrites
on populated Tables reject pending M11; bounded validation preserves physical
row roots and retained old definitions.

Independent Python CHECK/FK byte fixtures, Fuze compiler/codec tests, disk Table
validation tests, disk foreign-key interruption/cancellation tests and the
transaction/savepoint constraint test have executed during development. The
diagnostic grammar and representative Python/TypeScript value checks also pass.
The installed native/PostgreSQL/MySQL integrity scenario passes CHECK INSERT and
UPDATE refusal, NULL handling, NOT VALID new-write enforcement, atomic validation,
stable-column renames, transaction/savepoint rejection, original DDL recovery
after gateway restart, and staged-FK dependency cleanup. This development evidence
does not close P2/P3/P8; final committed-revision qualification remains required.

The projection increment adds real retained-directory inspection to the Table
owner and signed dispatcher: one physical schema generation or eight row
locations per call, exact ADD-time origins, distinct definition/schema revisions,
full-width host projections and snapshot-bound continuations. Disk mixed-layout
tests and in-memory signed dispatch/permission tests execute these operations.
They establish directory interpretation and bounded pagination, not payload
verification, historical SQL, installed language/UI composition or complete P3.

The historical catalog increment adds paged selected-name/definition directories,
original-token acquisition and abandonment, verified publication and explicit
bounded release. Source pins preserve the original Table interpretation and WAL
frontier. SQL snapshot suffixes bind this catalog before compilation and carry
its identity through result and metadata observations. The ambiguous integer
system-time grammar fragment is removed. Eight focused owner tests pass during
development, including independent signatures/selectors, lost replies, collection,
current disclosure and metadata reads with segment access/writes blocked. The
reference grammar also passes. The installed native/PostgreSQL/MySQL history
scenario now passes rename/name reuse, prepared reuse, gateway restart,
independent multi-source reads, paged metadata, buffered revocation and explicit
release. These development binaries do not establish final committed-revision
qualification. Common-cut transfer, explicit target projection, P1's
other type families, P6 and P7 still require implementation and qualification.

The shared Catalog host now exposes explicit historical acquisition, progress,
release and metadata operations with full-width neutral values and selector-bound
list cursors. Current-object authorization precedes released-snapshot disclosure;
result validation rejects mismatched source cuts and scope. Installed host/SDK
and Board composition remain part of P7/P8, beyond the SQL transport run above.

The companion-value increment integrates RANGE/MULTIRANGE and aligned dense
VECTOR values through descriptors, canonical/neutral codecs, Table schemas and
rows, SQL declarations/literals, Arrow export/import and TypeScript/Python value
APIs. Persisted column semantics bind rounding, metrics, actual TZif artifacts
and reserved spatial metadata; incompatible layouts require a rewrite. The
current-v1 cutover regenerates contracts and language resources and retains
explicit old-definition rejection. Narrower SDK profiles reject unsupported
descriptors instead of discarding them.

Development checks pass 497 Fuze tests, 305 independent DDL cases and 251 PyArrow
cases. The focused disk test recovers admitted DDL after a lost reply and two
reopenings, retaining companion defaults and semantic descriptors. These checks
do not close P1 or P8: production interval/distance/decimal/timezone expression
integration, decimal aggregates and final installed-consumer qualification remain
required, alongside the historical catalog work listed above.

The expression increment binds bounded scalar programs into production Table
SELECT and prepared/captured logical plans: explicit DECIMAL arithmetic and
ordered DECIMAL(38,s) SUM, range predicates/order, vector distance and frozen
TZif timezone conversion/bucketing. Captured Table declarations retain exact
column semantics. Scalar programs and 128-bit aggregate progress participate in
the coordinated current-v1 cutover; former plans/checkpoints reject.

Development evidence includes 505 full Fuze tests, 69 focused scalar/prepared
tests, 132 query tests, 37 independent decimal/instruction-byte fixtures,
21 TypeScript catalog/query adapter tests and strict Python type checking.
The reference grammar and 60 fast checks pass. Installed scalar/history scenarios
and final committed-revision qualification remain required; this increment does
not close P1/P8 or the remaining projection, common-cut, view and inspection work.

The common transaction-cut transfer now preserves catalog namespaces/names with
its acquired source closure, reserves original pins during bounded transfer and
publishes independently retained copies. Common-cut selectors and shared host
values preserve the complete original attribution. Development checks cover disk
restart, lost copy/control/release replies, committed prepared writes, abandonment,
namespace rename, forged cuts, current-policy denial and collection after original
pin release. The shared v1 cutover replaces saved selectors and persisted pin/catalog
metadata; it supplies no fallback decoder. Development checks pass all 234
catalog tests, four focused storage tests, 19 contract checks, 60 fast checks and
569 diagnostic grammar cases. These checks do not replace P8's final
committed-source qualification or close the remaining projection/view/caller work.

The following table preserves the original source audit. It is not a description
of the newer increments above.

The source owners below distinguish integrated behavior from reusable helpers.
The dated proof records qualify their own revisions; their union is not a pass
at this source.

| Boundary | Available at the source basis | Remaining M10 integration |
| --- | --- | --- |
| Standards and effects | [`standards-ledger.json`](../../contracts/sql/standards-ledger.json), generated `StandardsLedgerData`, [`OperatorTraits`](../../packages/zig/transit-fuze/src/OperatorTraits.zig), compiler rejection checks and metadata-only direct Table EXPLAIN | Feature-specific evidence and generated public capability views; trait propagation through every admitted operator and frontend. Ledger generation checks consistency, not conformance. |
| Types and semantic rules | [`Range`](../../packages/zig/transit-fuze/src/Range.zig), [`VectorMetric`](../../packages/zig/transit-fuze/src/VectorMetric.zig), [`DecimalArithmetic`](../../packages/zig/transit-fuze/src/DecimalArithmetic.zig), [`Timezone`](../../packages/zig/transit-fuze/src/Timezone.zig) and expanded `Collation.Profile` helpers | Wire/value/schema/storage/query integration and generated consumers. A metric helper is not an unboxed stored vector. TZif helpers do not enable SQL timezone expressions. |
| Current schemas and collations | [`TableSchema`](../../packages/zig/transit-fuze/src/TableSchema.zig) persists logical types and independent physical attributes. Admitted text collations are `utf8_binary`, `ascii_ci`, `ebcdic_cp037`, all NO PAD; `icu_root` rejects | Persist complete interpretation descriptors. CP037 PAD SPACE and CP1047 helpers are not admitted Table/SQL collations. Do not reinterpret existing CP037 as PAD SPACE. |
| Integrity and evolution | [`TableConstraints`](../../packages/zig/transit-fuze/src/TableConstraints.zig) evaluates supplied descriptors; `TableEvolution`, `TableSchemaProjection` and `TableInterpretations` implement existing lazy evolution | `TableDdl` still rejects CHECK/FOREIGN KEY. Persist constraints, compile DDL, enforce all write paths, register column dependencies and expose actual evolution/projection evidence. |
| Catalog history | [`DirectCatalogRoots`](../../packages/zig/transit-catalog/src/DirectCatalogRoots.zig) verifies retained control-WAL roots one frame per step. [`HistoricalCatalog`](../../packages/zig/transit-catalog/src/HistoricalCatalog.zig) validates borrowed fixture cuts and supplied grants | Durable paged historical name/definition resolution, complete publication evidence, pin lifecycle and current runtime authorization. Neither helper supplies a production historical catalog. |
| Retained data | `TableSnapshot`, retained history, lazy physical-schema interpretation and transaction cuts preserve exact data bases; [`DirectStorageGraph`](../../packages/zig/transit-catalog/src/DirectStorageGraph.zig) walks retained obligations | Bind catalog interpretation to those bases, including committed WAL-only rows, deletion vectors and complete transaction decisions. A control-root position alone is not a data frontier. |
| SQL and results | M4 result lifecycle, M5 Table transactions, shared SQL readers and direct compilation are integrated | [`FOR SYSTEM_TIME AS OF`](../handbook/reference/sql/as-of.md) remains an isolated grammar fragment. No production historical selector/name binding, explicit projection or historical result provenance is provided by the fixture helper. |
| Verification | [`historical_catalog_test.zig`](../../packages/zig/transit-catalog/src/historical_catalog_test.zig) exercises helper semantics; [`historical_catalog.py`](../../tests/catalog/tables/historical_catalog.py) regenerates neutral fixtures | Independent execution correspondence, installed callers, disk recovery, authorization races, bounded growth and one-revision closure. Matching generated fixtures is not an independent semantic oracle. |

The Python and TypeScript Catalog adapters now expose owned historical selections,
acquisitions, exact control recovery, common-cut inputs and bounded metadata
pages through the existing shared host. Development tests cover full-width
independent neutral fixtures, host loss, changed response identities, cursor
scope/progress, and joined Python cancellation. These are boundary tests; the
installed language journey, Board inspection and final clean qualification remain
open with the other P3/P5/P6/P7 work.

### Recent foundations and upcoming handoffs

| Owner and roadmap status | Progress to consume | M10 dependency or handoff |
| --- | --- | --- |
| [M1](01-declarative-data-lifecycle.md), [M2](02-storage-and-query-performance.md), Completed | Scoped object/definition identities, explicit snapshot consistency, WAL/object durability, retained roots and physical codecs | Extend `DataLifecycle` and storage owners. Do not introduce another catalog ID allocator, in-memory manifest authority or mandatory global CAS for ordinary writes. |
| [M3](03-live-storage-and-sql-cutover.md), In Progress | Direct catalog/Table lifecycle, retained readers, lazy column projection and original-operation recovery | Build history over installed operations. Preserve remaining lifecycle/recovery qualification; a historical adapter cannot certify unfinished M3 profiles. |
| [M4](04-statement-results-and-consumption.md), [M5](05-transactions-and-atomic-composition.md), Completed for their recorded profiles | Logical statement results, bounded verified completion, local serializable Table transactions and common cuts | Extend existing observation/result types. Retaining a historical cut is separate from keeping an interactive transaction open. Preserve private/provisional versus committed results. |
| [M6](06-streams-queues-and-durable-runtime.md), In Progress | Database independence, Stream/Queue declarations and typed payloads, bounded Queue waits, named direct KV, native mixed state/append/settlement and explicit DLQ transfer have landed; installed mixed proof is recorded [here](../history/qualification/transactions.md#installed-mixed-state-output-and-input-settlement--2026-10-31) | Account for new object kinds, prepared roots and decision dependencies in retention and cutover tests. Dedicated workload SQL, automatic DLQ scheduling and transactional Station replacement remain open. Do not repeat the older Table-only participant assessment. |
| [M7](07-document-storage-and-station-decoupling.md), In Progress | Document contracts, algebra, shredder, partition and authority/graph foundations; [remaining plan](07-document-storage-and-station-decoupling.md#implementation-plan-for-remaining-work) separates these from installed lifecycle | Bind exact projection/merge/decoder descriptors now; direct Document execution waits for owner-derived state, public dispatch, transaction and consumer gates. Never route new database history through Station turns. |
| [M8](08-gateway-architecture-and-protocol-ingress.md), In Progress | Co-hosted direct execution, event-driven recovery, neutral wire framing and resumable PostgreSQL/MySQL command engines | Carry historical observations through the shared service and host disclosure guards. Socket scheduling, remote SQL and Flight/Serving expansion are separate gates; no new per-row gateway requests. |
| [M9](09-client-foundation-and-language-apis.md), In Progress | Bounded Catalog/SQL context leases, frozen SQL submissions and local recovery storage | Put typed historical calls and owned values in existing shared data/SQL clients; coordinate the data ABI extraction. Managed handles, principal coordination and installed language composition remain unfinished. |
| [M11](11-indexing-and-access-paths.md), Planned | Offline index lifecycle descriptors; maintained indexes and online builds remain future work | Supply exact comparison/constraint bindings, coverage requirements and rewrite classifications. M11 owns index-backed FK enforcement, fine-grained range conflict tracking and recoverable physical rewrites. No circular dependency on those implementations for M10 metadata or CHECK. |
| [M12](12-sql-and-dataflows.md), In Progress | Analytical, temporal, delta and managed-dataflow helpers have component evidence, with runtime integration still open | Supply immutable view/dependency bindings, range order and operator effects. Temporal joins, managed activation and incremental execution do not follow from historical selection. |
| [M13](13-data-structures-and-performance.md), [M14](14-vectorized-strings-and-search.md), In Progress; [M15](15-data-centric-compilation-and-specialization.md), Planned | Memory accounting, collation prefixes, German strings, compressed predicates and search helpers already exist | Reuse exact comparator/key rules; compare optimized paths against scalar meaning. Bind compiled-plan/cache identity to the complete interpretation. Their helpers do not qualify every persisted collation or index profile. |
| [M16](16-document-profiles-and-gateway-exchange-lifecycle.md), [M17](17-geospatial-and-spatio-temporal-computing.md), [M18](18-multi-model-and-foreign-relations.md), Planned | Future Document profiles, spatial execution and foreign/graph relations | Deliver versioned decoder/layout and spatial descriptor bindings with explicit rejection for unavailable execution. File paths/URIs are not immutable foreign inputs. |
| [M19](19-branches-merges-and-restore.md), In Progress | [Immutable single-Table branches](19-branches-merges-and-restore.md#local-table-branch-increment) now retain definitions and WAL-only data through the existing catalog token/pin owner | Reuse that publication and protected-pin lifecycle. A selected Table branch is not a whole-catalog snapshot or writable branch history. M19 owns divergence, merge, restore and broader branch lifetime. |
| [M21](21-formal-semantics-and-correspondence.md), [M26](26-control-and-policy-plane.md), [M27](27-published-resources-and-investigations.md), [M29](29-board-reimplementation.md), In Progress | Scoped formal models, policy/publication/investigation contracts and operator UI work | Supply independent collation/DDL correspondence and retained provenance. Current native rights remain authority; policy/investigation helpers cannot grant historical access. Board consumes public read surfaces. |
| [M20](20-service-and-sdk-coverage.md), In Progress; [M34](34-sql-grammar-and-dialect-ergonomics.md), Planned | Existing SDK/transport profiles and future full dialect audit | M10 migrates every affected consumer and records per-surface support; M20 adds breadth, M34 audits broader syntax/standards. No blanket SQL conformance claim. |

### Contract decisions before runtime exposure

These decisions refine the original plan. New type/API names and SQL forms below
are implementation targets until the owning contract, grammar and executable
entry point land together.

1. **Use one historical basis with distinct identities.** A proposed `CatalogCut`
   identifies immutable catalog interpretation within existing `DataLifecycle.Scope`
   and branch identities; data coverage stays in `SourceCut`, `Snapshot` and the
   transaction owner. Keep catalog publication sequence, partition LSN, schema
   revision, content digest and application revision distinct. The notation
   `manifest/v{N}` describes a publication sequence, not a second protocol version.
   Reuse M19 branch IDs and heads rather than allocating a competing namespace.
2. **Freeze an accepted catalog and its selected source closure.** The control
   WAL contains reservations and pending work as well as completed operations;
   a historical root is insufficient unless the accepted object declaration is
   verified. Specify a bounded acquisition protocol that resolves completed
   name/definition bindings, retains exact source cuts, validates concurrent DDL
   and records recoverable progress before publishing a complete basis. A
   single-source cut is coherent; a selected common transaction cut uses its
   owner; other sources remain an explicitly independent vector. Do not invent
   whole-catalog atomicity or force independent DML through the catalog WAL.
3. **Separate selection, projection and time.** First expose typed immutable
   snapshot/catalog selection, with a branch selector only for its qualified
   M19 scope. Resolve mutable heads once before compilation. `AS OF SNAPSHOT`
   and explicit projection require grammar and typed-operation contracts;
   `PROJECTING TO` is a proposed spelling, not executable syntax. Match stable
   ColumnIds and freeze the target definition, including a requested `CURRENT`.
   `FOR SYSTEM_TIME AS OF` remains reserved for temporal-table meaning. Remove
   the ambiguous integer fragment at its deliberate cutover; never reinterpret
   its integer as a manifest or LSN. Timestamp convenience needs authority-time,
   ordering/tie and retention rules before admission; M12 owns temporal joins
   and valid-time behavior. Unsupported selectors reject rather than choose a
   nearby or current cut.
4. **Keep current authorization separate from historical evidence.** Resolve
   metadata and rows through their owning native policy references, including
   retained objects after DROP. Historical `policy_epoch` is attribution, never
   permission. Recheck current rights after buffering and before rows, schema,
   metadata, repeated/empty batches and terminal counts. A recreated name grants
   no access to its previous object. Metadata-only EXPLAIN/DESCRIBE must not
   acquire data pins, read segments or disclose hidden dependencies.
5. **Preserve comparison meaning through every representation.** Persist exact
   collation repertoire, padding, normalization/case rules and implementation/data
   identity. Existing `EBCDIC_CP037` is NO PAD: adding PAD SPACE is a distinct
   descriptor. Equality, hashes, sort keys, four-byte prefixes, dictionary/FSST
   predicates, joins, keys and zone maps must agree under that descriptor.
   Equal prefixes require full comparison. Versioned UCA/ICU locale descriptors
   remain rejected until tables, options, licensing and independent conformance
   are pinned; recognizing a name does not qualify execution.
6. **Separate constraint validation from enforcement.** CHECK uses a bounded,
   deterministic row expression with no external access or effects. TRUE/NULL
   pass; FALSE/missing/type_error/conflict reject with attributable diagnostics.
   `NOT VALID` can defer old-row validation while enforcing new candidate rows;
   it is not `NOT ENFORCED`. FK descriptors may be explicitly staged/not enforced,
   with dependency protection and visible status; a plain enforced declaration
   cannot silently downgrade. Enforced activation and referential actions require
   M11's supporting indexes and transaction checks. Before then, reject activation
   and any mutation requiring unavailable enforcement.
7. **Keep historical interpretation within the current Transit definition.** Old
   application schemas can coexist in retained data; old incompatible Transit
   formats cannot. Plan one coordinated descriptor/consumer release boundary,
   with no v2, fallback reader or defaulted persisted definition. Any additional
   incompatible change still requires a new shared current-v1 definition and
   complete migration/rejection checks. Reserving a descriptor does not guarantee
   that future spatial or language work will never need another cutover.

### Work packages and delivery gates

Retain P0–P8 for continuity with the earlier evidence. P1 is the coordinated
contract/consumer boundary, not a repeat of helper implementation. P2/P3 and P4
can progress independently after their shared contracts are fixed; P5 requires
both durable acquisition and correct interpretation. Publish each runtime slice's
supported semantics with its evidence rather than waiting for final closure.

| Package | Deliverable | Start gate | Completion gate |
| --- | --- | --- | --- |
| P0 | Evidence ledger, effect propagation and historical/integrity contract decisions | Audited source | Typed contracts, capability matrix, migration inventory and independent fixture specification reviewed together |
| P1 | Canonical types, semantic descriptors and coordinated v1 consumer cutover | P0 | Actual values/schema/storage/query paths and affected consumers pass, including rejection of incompatible artifacts |
| P2 | Durable CHECK and staged FK definitions, dependencies and write enforcement | P1 constraint representation | SQL and typed writes share enforcement; dependency publication/recovery cannot leave an unprotected visible constraint |
| P3 | Lazy/validation/rewrite classification and projection provenance | P1; P2 for constraint-aware changes | Mixed-generation segments and WAL tails preserve historical/live meanings; physical rewrites reject pending M11 |
| P4 | Durable historical catalog acquisition, lookup and retention | P0/P1 identities and format; existing storage/transaction/branch owners | Exact paged catalog/data cuts survive interruption, restart and collection with current policy |
| P5 | Historical compilation and result lifecycle | P0, P3, P4 | Installed historical SELECT/metadata/projection with frozen basis, verified completion and disclosure fencing |
| P6 | Versioned views and graph/foreign/decoder catalog bindings | P2–P5 | Historical definitions and dependencies survive replacement; execution gates remain explicit per data kind |
| P7 | Shared clients, transports and read-only inspection | P5/P6; qualified M8/M9 facets | Same basis/constraints/coverage through public APIs, with ownership, cleanup and original recovery |
| P8 | Independent correspondence, faults, resource evidence and closure | Every claimed P0–P7 profile | Required journeys pass at one committed revision and current public owners describe them |

#### P0 — Complete contracts and evidence ownership

Extend the existing ledger and validator instead of recreating them. Each feature
must identify edition/part/correction where verified, extension versus standard,
owner, dependencies, deviations, fixture provenance/license and independent
`parse`/`lower`/`execute`/`recover`/`transport` evidence. Record transport/type
profiles explicitly: a native type is not automatically supported by Flight,
PostgreSQL, MySQL or every SDK. Generated capability views must preserve rejected
and reference-only states. Do not copy restricted standards text into fixtures.

Carry `OperatorTraits` through lowering and validation for every admitted plan,
including CHECK and historical projection. Derive read/mutate/capture/dispatch,
determinism, fallibility, five-state behavior, collation, change mode and work
bounds from shared typed semantics. Test EXPLAIN against instrumented owners:
metadata access is permitted, but zero data acquisition, segment reads, durable
mutation or external dispatch is required.

Amend [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[direct requests](../../contracts/DIRECT_TABLE_V1.md),
[types](../../contracts/FUZE_TYPES_V1.md),
[schema](../../contracts/TABLE_SCHEMA_V1.md),
[DDL](../../contracts/TABLE_DDL_V1.md),
[results](../../contracts/SQL_RESULTS_V1.md),
[sessions](../../contracts/SQL_SESSION_V1.md) and the
[grammar](../../contracts/sql/README.md) before dependent runtime exposure.
Specify historical selection/acquisition/release/inspection, consistency,
constraint states, effect-free projection, retention failures and observation
immutability. Add an owning exact historical contract if those operations need
one; do not turn the fixture JSON into a second authoritative protocol.

Inventory all affected stored roots, schemas, rows, plans, prepared requests,
transaction preparations, branch pins, Arrow metadata, ABI/host declarations and
SDK resources. Bind each to its generator, consumer and old-definition rejection
check. Use independent canonical vectors as the oracle for P1–P8.

#### P1 — Integrate types and interpretation descriptors

Extend `Types`/`Values`, `TableSchema`/JSON/row codecs, `PhysicalCodecs`/`TSeg`,
query binding and shared neutral/Arrow/ABI consumers together. Explicitly refuse
unsupported combinations at the earliest owning boundary. Keep the following
subchanges reviewable within the coordinated release:

- **Ranges:** integrate `Range` over the declared INT64/DECIMAL/DATE/timestamp
  domains. Specify successor rules for discrete bounds, overflow at extrema,
  empty/unbounded bounds, continuous inclusivity and canonical sorted/coalesced
  multiranges. Continuous intervals cannot all be converted to `[lower, upper)`
  without changing meaning. Persist the element's exact order; qualify the
  admitted containment, overlap, adjacency and ordering operators.
- **Vectors:** use `VectorMetric` with fixed dimension and admitted FLOAT32,
  FLOAT16, BFLOAT16, INT8 and binary layouts, a whole-cell five-state tag and
  unboxed elements. Define binary dimension/padding, finite-value and zero-norm
  handling, metric/type compatibility, accumulation/overflow rules and bounded
  allocation. Runtime slabs are 64-byte aligned; wire bytes need not share a
  host pointer layout. Coordinate with M14's `VectorSlab` to avoid duplicate
  value representations. SIMD results must satisfy the declared scalar oracle.
- **Decimals and time:** integrate deterministic scale promotion, explicit
  rounding and overflow in expressions/aggregates. Do not invent monetary
  defaults. Pin timezone rules by actual immutable TZif content plus declared
  identity, retain the required artifacts and define local-time gaps/folds.
  Existing coverage refusals remain until separately implemented and tested;
  no host tzdb fallback or digest derived only from a release label.
- **Collations and spatial descriptors:** integrate CP037 PAD SPACE and CP1047
  only after comparator/key/hash/pruning correspondence passes. Preserve current
  NO PAD semantics. Reserve validated spatial reference/manifold/precision/order
  bindings for M17, with explicit unsupported execution. UCA/locale profiles
  remain recorded refusals unless their complete evidence gate passes.

Change format definitions and the shared Transit definition wherever required;
regenerate consumers and signing/schema fixtures. An incompatible retained store
or saved request must fail before execution while preserving original bytes and
recovery material. No silent reset or compatibility shim. Run version alignment
checks if manifests change. Do not advertise SQL operators solely because a new
value round-trips through the neutral codec.

#### P2 — Persist integrity and enforce it at acceptance

Store constraint identity/name, canonical expression, referenced ColumnIds,
validation/enforcement state and exact FK target object/definition/columns in
immutable schema/catalog records. Compile the bounded CHECK subset and explicit
staged FK declaration through SQL and typed callers; reject unsupported forms.
FK arity, type/comparison compatibility, nullable SET NULL targets and candidate
key requirements must be validated or visibly pending, never inferred from names.

Enforce CHECK after assignment/default resolution and before point/bulk acceptance
or transaction statement publication. Cover INSERT, UPDATE, UPSERT, private
workspaces, savepoints, direct binary ingress and replay validation; an adapter
cannot bypass the owner. A failed row rejects the atomic operation without a
successful prefix. Constraint diagnostics use shared typed failures and respect
metadata visibility. Recovered accepted work retains its bound definition.

Extend the paged `DirectCatalogDependencies` owner with column-level integrity
edges. Current registration and dependent publication are separate acceptances:
record the original pending operation, acquire protection before visibility,
recover uncertain publication and release abandoned edges only after resolution.
Do not claim atomic graph/schema publication unless the new owner proves it.
Block dependent DROP/incompatible ALTER, including hidden blockers without
leaking their identities. Compatible renames preserve bindings; no automatic
name-based rebinding. M11 receives enforcement state, key requirements and
referential actions, not an unbounded parent/child scan fallback.

#### P3 — Integrate evolution and projection coverage

Connect the existing classifier/helpers to `TableEvolution`, catalog preview,
accepted ALTER and recovery. Report three distinct paths: lazy metadata/projection,
validation scan, and physical rewrite. Adding a NOT VALID CHECK still enforces
new writes; validating old data, changing comparison/key semantics and physical
conversion need bounded validation or M11's phased lifecycle before activation.
An empty live Table does not make its old retained definitions disposable.

Use `TableInterpretations` and stable ColumnIds to interpret each physical segment
and WAL row at the selected logical definition. Preserve frozen ADD-time defaults,
nullable additions, later default changes and dropped/recreated identities.
Default historical reads target the historical schema; explicit projections bind
their own target and missing/default/conversion policy without rewriting data.

Expose bounded per-definition/segment projection evidence with known versus
completed coverage. Keep result observation immutable: detailed coverage may be
paged through a separately identified inspection result or finalized through the
owning completion contract, not silently appended to the cursor's initial basis.
Budget metadata traversal as well as rows. Claim no constant-time DDL or zero
allocations without measurements against the actual retained graph.

The next storage increment publishes accepted definition revisions and their
frozen ADD-origin directories atomically with Table DDL. Exact metadata lookup
and forward projection survive reply loss, checkpoint/restart, later defaults,
column removal and a history larger than the resident cache. A real collection
walk preserves the origin pages while deleting an unaccepted declaration.
Independent 194-byte fixtures cover wide identities and canonical rejection.
The focused disk projection and canonical fixture checks pass. Signed native
preparation/scan and the shared reader now bind exact accepted targets separately
from source cuts; the signed test covers metadata-only rights, denied reads,
later defaults, DROP, continuation fencing and historical release. SQL SELECT,
DESCRIBE and EXPLAIN are wired to these operations with separate observation
evidence. The current cutover passes all 320 storage tests, 13 focused catalog tests,
20 direct-query tests, 13 SQL tests, 26 result tests, reflected contract checks
and 60 fast checks. Expanded installed SQL qualification remains pending.

#### P4 — Build durable catalog cuts and their retention lifecycle

Implement historical acquisition and lookup in `DirectCatalog`,
`DirectCatalogRecords`/`Store`/`Roots`, with paged immutable directories and bounded
caches. Resolve names and definitions from accepted historical bindings, including
namespace changes, DROP and name reuse. Keep the existing complete control-WAL
recovery walk; an optional lookup index is an acceleration structure, not permission
to discard earlier recovery roots. Measure pages/steps with increasing history
before promising logarithmic access.

Record acquisition intent and source selection under the existing client token
and operation owner. Acquire catalog/schema/artifact references and complete
Table source pins, including `.tseg`, `.tdel`, accepted unflushed WAL and relevant
transaction decisions. Verify definition/data agreement and DDL races before
conditional publication. Preserve acquired progress across failure and use the
same original identity to finish or abandon it. Partially acquired cuts remain
unpublished. Once admitted, execution cannot silently retry against another cut.

For selected multi-Table common cuts, reuse the transaction owner and explicitly
coordinate catalog interpretation with that selected closure; do not relabel an
ordinary independent vector. M6's mixed preparations and M19's operation-to-branch
pin transfer must remain reachable during collection. Reuse immutable Table
branch bindings for that scope; whole-catalog branch histories remain M19 work.

Integrate pins, release/abandonment and metadata/artifact roots into
`DirectStorageGraph`, checkpoint/trim and collection. Retention stays unlimited
by default. Explicit expiry, caller release, storage unavailability, corruption,
unsupported definition and denied access have distinct outcomes, subject to
non-disclosure rules. A missing segment is not proof of authorized expiry. No
outage or quota pressure permits skipping history or returning empty success.

#### P5 — Bind historical SQL before name resolution

Wire the contracted selectors through grammar, AST, direct relational compilation,
`DatabaseRuntime`, `ReadCache` and the shared SQL session/result owners. Resolve
the exact catalog cut first, then object/column/view/decoder bindings and all
comparison/codec/timezone rules. A current-name lookup followed by replacing the
data snapshot is invalid. Plan/cache keys include the full frozen interpretation,
source basis and explicit projection target; repeated aliases share qualified pins.

Define historical SELECT, SHOW, DESCRIBE and EXPLAIN through the same typed
operations. Metadata inspection has a catalog observation, not an invented data
snapshot. SELECT carries exact source/consistency evidence in M4's existing
result lifecycle. Test old-column success/new-column rejection, moved branch
heads and prepared statements retained across later DDL. Cross-basis queries
must identify each basis rather than imply an atomic snapshot.

Keep the initial historical SQL profile read-only. Reject historical selection
inside an active write transaction until the transaction owner specifies how
that basis composes with its common cut and private writes. Do not hide a commit,
reopen a transaction or permit DML against a retained historical definition.

Historical reads must survive ordinary physical maintenance or fail explicitly
when required evidence is unavailable. Keep no-index/full-comparison paths when
an acceleration structure lacks exact definition/collation/cut coverage. Apply
current policy at every protected disclosure, including M8's delayed output
slices. Early close/cancellation/failure releases owned transient reads without
destroying a separately retained basis or converting a prefix into completion.

Historical namespace selection now accepts the optional `IN SCHEMA name` suffix
and resolves it only inside the published selection. SELECT and metadata bindings
freeze the stable namespace ID; metadata observations retain it independently of
the session namespace. The SQL and service package suites pass (13 and 11 tests),
and the independent grammar check accepts all four statement forms, including
quoted names. The installed history scenario now covers namespace rename/reuse
and restart; that expanded scenario remains pending final execution. Shared
CHECK/DML validation and resolved schema projections also derive OperatorTraits;
the Fuze suite passes 508 tests and ten focused catalog projection tests pass.
These checks do not close the outstanding explicit projection, captured-query,
versioned-definition or final qualification gates.

#### P6 — Bind views and multi-model interpretation

Publish immutable view definitions, output identities and exact dependencies
through the existing catalog/query owners. Preserve source text as provenance;
execution uses the accepted typed binding. Replacing a view must not affect a
historical expansion, and a dependency closure resolves once at the selected
basis. Cycles, unsupported operators, missing artifacts and incompatible source
changes refuse before publication/execution. Uncertain publication retains its
original protection and outcome.

Add versioned property-graph key/label/property mappings and foreign/mainframe
layout/decoder descriptors with stable ColumnIds and explicit dependencies.
Persist actual content identities and declared availability for captured foreign
inputs; never refetch a mutable URI during replay. Validate physical codec limits
and malformed-value policy separately from storage corruption: a foreign decode
may produce a declared type_error cell, whereas broken durable checksums or
incompatible formats must not be converted into ordinary cells.

M10 supplies durable descriptor/history/inspection semantics and historical view
expansion over qualified sources. Graph traversal and general foreign scans remain
M18; richer Document profiles remain M7/M16. Register each admitted/rejected
profile in the ledger, including changed historical decoders and dependency
failures. Do not activate computations, effects or connectors while inspecting
or restoring definitions.

#### P7 — Expose one shared caller and inspection surface

Extend `transit-data-client.Catalog`, `transit-sql-results` and
`transit-sql-client`, then the existing ABI/host/language projections. Use M9's
context leases, frozen submission and recovery-store boundary where available;
do not create a history-specific host, token allocator or polling workflow.
Define owned versus borrowed buffers, bounded pagination, cancellation, close
and recovery of original cut acquisitions. New conveniences cannot resubmit SQL
or reacquire a moving branch as new work after uncertainty.

Expose catalog/data basis, schema and semantic digests, constraint state,
dependencies and projection coverage through public read operations. Preserve
exact identities through JSON/ABI/Arrow and reject unsupported transport/type
profiles. M8 gateways adapt these operations without owning historical semantics.
Qualify native SQL and public Zig first, representative Python/TypeScript data
facets with M9, and regression coverage for every affected existing binding.
Additional new coverage stays with M20.

Board inspection consumes those same authorized public reads, with bounded pages
and visible incomplete coverage. It acquires no raw storage access or independent
permission/configuration authority. Publish current semantics and limits in
Tables, data types, historical SQL, query results, caller/component/SDK references
and the state/query/storage internals as each capability lands.

#### P8 — Prove integration and close the milestone

Extend the existing domain suites under `tests/catalog/`, `tests/query/`,
`tests/storage/`, `tests/interfaces/` and `tests/sdk/`; register real runners in
the test inventory. Keep fixture consistency checks, component semantics,
installed fault schedules and formal correspondence separate. Feed independent
canonical fixtures to actual Zig owners and compare observations, not source
symbol presence or regenerated copies of the same expected answers.

With M21, connect comparator/key/prefix/pruning and codec cases to A2/A5, and
CHECK/projection/DDL transitions to A1/T8 where their scoped models apply.
Include negative controls and implementation replay where claimed. Abstract
proofs do not establish correctness of every concrete collation, SIMD path or
storage codec. Retain earlier evidence and failure records.

### Acceptance matrix

| Journey or fault | Required evidence | Packages |
| --- | --- | --- |
| Capability and explanation | Every claimed stage/surface has positive and negative cases; metadata-only EXPLAIN has zero data pins/segment reads/mutations/effects | P0, P7 |
| Rename/drop/recreate | Table, namespace and column reuse cannot rebind original identities; old columns succeed and later columns reject at the old cut | P3–P5 |
| Historical schema projection | Mixed physical generations plus WAL-only rows preserve frozen defaults and five-state distinctions; explicit target mapping never matches reused names | P1, P3, P5 |
| Collation and codec fidelity | Independent compare/key/hash/full-scan oracles agree for admitted profiles, PAD SPACE/control characters, multibyte text, prefix collisions, dictionary/FSST and zone maps; malformed foreign values and corrupt durable bytes remain distinct | P1, P5, P6 |
| Companion types | Range extrema/continuous bounds/coalescing, vector layout/metric/zero-norm limits, decimal scale/rounding/overflow and exact TZif digest/gap/fold/coverage cases pass through actual storage/query/neutral boundaries | P1, P5, P7 |
| CHECK and FK | All write variants reject invalid CHECK atomically; NULL differs from missing/error/conflict; staged FK is visible, blocks incompatible metadata changes and cannot be mistaken for enforcement | P2, P3 |
| Online-rewrite handoff | Populated type/collation/key changes cannot trigger unbounded synchronous rewriting or mutate retained interpretation; validation and activation stay distinct | P3 |
| Complete cut acquisition | Concurrent DDL/DML, pending declarations, unflushed rows and mixed decisions cannot publish partial source coverage; independent vectors and common cuts retain their exact meaning | P4 |
| Lost replies and process death | Kill before/after source pin, catalog publication, abandonment and release; recover the original operation with no leaked untracked roots or duplicate accepted cut | P4, P7 |
| Retention and maintenance | Restart, checkpoint, compaction, trim and real collection preserve reachable schema/data/TZif roots; opted-in expiry, missing evidence and corruption fail explicitly | P4, P5 |
| Current policy | Metadata-only versus row rights; revoke after buffering rows/schema, repeated fetch, empty output and terminal counts; old grants and recreated names cannot authorize disclosure | P4, P5, P7 |
| Moving heads and changed views | Accepted basis survives branch movement/view replacement/upstream rename; unsupported branch scope, foreign scope or incompatible artifact rejects before execution | P4–P6 |
| Result truth and cleanup | Empty/multi-batch output, incomplete prefix, cancellation, early close and missing completion preserve M4 semantics; no SELECT restart/splicing or scratch-buffer lifetime leak | P5, P7 |
| Bounded growth | Histories, objects, pins, segments and dependencies exceed resident caches; paged lookup/acquisition/recovery/cleanup stay within byte/work quotas; warm paths have counting-allocation evidence | P1–P8 |
| Consumer cutover | All affected generated contracts, signing fixtures, SDKs and saved-format rejection checks agree on the current definition; unsupported surfaces refuse explicitly | P1, P7, P8 |

### Verification sequence and first changes

Before implementation, reproduce relevant existing checks and record failures
without weakening assertions. Inside the pinned `nix develop` environment use:

- `python3 -B tests/runner/launch.py tests/query/logical/standards_ledger.py`
  and `python3 -B tests/runner/launch.py tests/catalog/tables/historical_catalog.py`
  for existing generation/fixture consistency only.
- Package-local `zig build test` in the affected Fuze, catalog, storage,
  query-direct, SQL result/client/service and data-client owners, selecting
  focused filters during iteration.
- `just test::direct-table-service collations`,
  `just test::direct-table-service projection`, `just test::local-catalog`,
  `just test::direct-state-transaction` and `just test::direct-mixed-transaction`
  for affected owner/service regressions; extend their real scenarios for history.
- `just test::sql-sessions`, `just test::sql-transactions` and affected installed
  SDK schedules for caller behavior, disclosure and original-operation recovery.
- `just check contracts`, documentation checks and the affected committed-HEAD
  `just ci clean --lane NAME` inventories. Shared format/authority changes require
  dependent lanes, including affected language and interface lanes; selected
  passes are not full integration qualification.

Measure warm/cold lookup and acquisition, time to first/complete result, WAL/object
requests and bytes, retained bytes, resident high-water memory, allocation counts
and cleanup/recovery work as history grows. Include current-read and full-scan
controls at identical durability, policy and resource budgets. Set regression
budgets from that baseline; do not invent latency or O(1) guarantees in the plan.
Record source, toolchain, configuration, workload, seed/fault schedule and omissions
in the owning [qualification records](../history/qualification/README.md).

The first implementation changes should be:

1. **P0 contract/evidence change:** settle typed cut acquisition, selector versus
   temporal semantics, constraint state and immutable observation rules; repair
   ledger evidence gaps and inventory all consumers of the coordinated cutover.
2. **P1 integration change set:** persist canonical types/descriptors and
   constraint representations, migrate consumers and reject incompatible
   artifacts. Reuse the delivered helpers and M14 representations with independent
   oracles; do not publish helper-only completion claims.
3. **P2/P3 integrity and evolution change set:** wire real write checks,
   recoverable dependency protection, lazy evolution and projection evidence.
4. **P4 durable acquisition change set:** implement bounded retained catalog/data
   cuts over current owners and prove disk interruption/GC before SQL exposure.
5. **P5–P7 caller change sets, then P8 closure:** historical SQL, views/descriptors
   and shared inspection over those proven owners; execute the full matrix at one
   committed revision and promote current semantics to public owners.

Keep the milestone **In Progress** until every claimed gate is met. Record any
partial delivery against its work package; do not close M10 by reclassifying
unfinished integration as a later milestone without an explicit scope decision.

## Implementation plan — 2026-10-30

The [original plan at the audited main revision](https://github.com/spoke-sh/transit/blob/c8d060cb2dfcf3bc531ef2e41fcdf7d4f172c2d5/docs/roadmap/10-standards-and-catalogs.md#implementation-plan--2026-10-30)
retains its source assessment, P0–P8 sequence and proposed decisions. The current
plan above supersedes its scheduling and integration assumptions, including the
CP037 padding change, temporal-selector conflation and Table-only transaction
baseline. The delivered record below preserves the original helper evidence and
its limits; it does not establish production integration.

### Delivered implementation evidence — 2026-10-30

PR [#262](https://github.com/spoke-sh/transit/pull/262) introduced standalone
helpers and fixture checks. Those are prerequisites, not completion of the
`P0`–`P8` exit gates. The production SQL compiler still rejects CHECK/FOREIGN KEY,
RANGE/VECTOR and historical catalog selectors; native schemas do not persist
those descriptors. Milestone 10 remains **In Progress**.

| Work package | Current implementation and evidence boundary | Remaining exit work |
| --- | --- | --- |
| `P0` | [Neutral ledger](../../contracts/sql/standards-ledger.json) generates the Zig inventory exactly; [compiler tests](../../packages/zig/transit-fuze/src/operator_traits_test.zig) check unsupported declarations. Direct Table EXPLAIN reports typed traits under inspection permission; [installed session checks](../../tests/interfaces/sql_sessions/native.py) deny data actions and exercise metadata-only grants. | Complete feature-specific positive/negative corpus and capability views; extend trait propagation to all operator owners. |
| `P1` | Standalone range/vector/decimal/spatial/collation helpers. [Timezone](../../packages/zig/transit-fuze/src/Timezone.zig) binds actual TZif bytes and explicitly refuses unsupported coverage. Decimal scale extremes and PAD SPACE prefix/control ordering have regression tests. | Coordinated type/value/schema/ABI current-v1 cutover, query and storage wiring, SQL numeric/timezone expressions, generated consumers and independent interoperability fixtures. No unboxed stored vector slab is delivered by the metric helper. |
| `P2`, `P3` | [TableConstraints](../../packages/zig/transit-fuze/src/TableConstraints.zig) evaluates caller-provided descriptors and classifies proposed changes. Existing Table evolution/projection remains the runtime owner. | Durable constraint descriptors, DDL compilation, actual write checks and dependency edges; connect evolution classification and projection provenance to ALTER/storage/recovery. |
| `P4`, `P5`, `P6` | [HistoricalCatalog](../../packages/zig/transit-catalog/src/HistoricalCatalog.zig) validates immutable caller-owned cuts. Digests bind complete contents; conditional publication retains its successor sequence; row batches retain intra-segment progress. Current grants are supplied explicitly by fixture callers. | Durable paged catalog cuts and retention, snapshot/transaction/WAL binding, SQL selector/name resolution, current runtime authorization, persisted view/graph/foreign dependencies. The helper is not a DirectCatalog store or SQL implementation. |
| `P7` | Direct Table EXPLAIN exposes traits through the existing native result lifecycle. | Historical/constraint/projection provenance in shared results, clients, SDKs and read-only Board inspection. |
| `P8` | [Zig historical tests](../../packages/zig/transit-catalog/src/historical_catalog_test.zig) exercise helper transitions; [neutral fixture checks](../../tests/catalog/tables/historical_catalog.py) verify fixture consistency. | Independent Zig-versus-neutral semantic correspondence, disk recovery/fault/authorization schedules for all ten scenarios, and common-revision qualification evidence. Fixture regeneration and source-symbol checks alone are not an independent execution oracle. |

At that revision, the next implementation boundary was `P1`'s coordinated
descriptor cutover, followed by `P2`/`P3` write and schema integration. The
[current sequence](#verification-sequence-and-first-changes) adds the contract
and evidence decisions required by the newer source. Existing WAL traversal,
Table snapshot/transaction identities, current-policy checks and retention owners
must be reused; a separate in-memory manifest namespace cannot replace them.

The installed Python and Node history schedules pass at `95e82586f`: 457 and
230 public requests respectively, including sync/async Python, caller/node
replacement, lost acquisition/release replies, retained original identities,
rename/DROP/name reuse and current revocation. This evidence predates the accepted
interpretation/projection cutover and must be repeated at the final PR revision.
