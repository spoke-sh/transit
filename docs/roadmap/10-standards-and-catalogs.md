# 10. Standards, collations and historical catalogs

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** In Progress ([remaining implementation plan](#remaining-implementation-plan--2026-11-02); [integrated baseline](#integrated-baseline-and-remaining-obligations))

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

## Progress PR scope — 2026-11-01

The progress implementation supplies the standards/capability ledger, distinct
CP037 PAD SPACE and CP1047 NO PAD collations, companion logical values and
persisted interpretation rules, durable CHECK and staged foreign-key bindings,
lazy schema projection, retained historical catalogs, historical SQL and
versioned view/graph/foreign descriptors. Python, TypeScript and read-only Board
inspection use the shared operations. Current contracts and limits are owned by
the [historical SQL reference](../handbook/reference/sql/as-of.md),
[Table schema contract](../../contracts/TABLE_SCHEMA_V1.md),
[historical catalog contract](../../contracts/HISTORICAL_CATALOG_V1.md) and
[catalog definition contract](../../contracts/CATALOG_DEFINITIONS_V1.md).

Integration with current main preserves managed computations, compact string
execution, gateway startup, logical Document storage and its collection roots,
Document Profiles and the spatial reference owner.
Opaque BINARY column metadata uses `transit-spatial.Reference` and its canonical
`SPR1` envelope; it does not enable spatial SQL. The shared definition and Table
schema definition change together, and the superseded definitions reject.

Milestone 10 remains **In Progress**. The
[executed pre-integration evidence](../history/qualification/catalog.md#standards-and-historical-catalogs-before-main-integration--2026-11-01)
retains exact revisions, successful lanes, failures and incomplete runs. The
progress PR reports its own checks separately. Closing P8 still requires the
common-revision acceptance matrix and remaining installed storage, browser and
consumer schedules, including the unresolved failure outcomes below. Earlier
passes do not qualify the replacement definition, and a progress merge does not
close those gates or the broader umbrella issue.

## Delivery sequence

This is the milestone's full target. The [integrated baseline](#integrated-baseline-and-remaining-obligations)
and current completion plan below distinguish delivered profiles from remaining
work and later-owner handoffs.

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
     [Milestone 13's](13-sql-and-dataflows.md) `PERIOD FOR valid_time` and
     [Milestone 18's](18-geospatial-and-spatio-temporal-computing.md) `BBOX` /
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
     [Milestone 18](18-geospatial-and-spatio-temporal-computing.md).
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
[SQL grammar, standards comparison and dialect ergonomics milestone](44-sql-grammar-and-dialect-ergonomics.md)
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

## Remaining implementation plan — 2026-11-02

### Outcome, source basis and scope

**Source basis:** fetched `origin/main` at
`5e00b53bfed8a552dc7306e1338394ec037ac9bb`, including the M10 progress merge
(`9d7a15fd6`, PR #320), subsequent integration, and Board's independent computation
inspection (PRs #339–340). This is a source and evidence audit, not a new runtime
qualification. Milestone 10 remains **In Progress**.

An application must be able to retain selected data and definitions, evolve the
live catalog, then query the retained basis with its original interpretation and
inspect why that interpretation applies. Another caller with current rights must
be able to inspect that evidence without acquiring the publisher's authority.
Integrity declarations must distinguish enforced CHECK from staged foreign keys.
An interrupted acquisition, query capture or release must preserve its original
identity, retained obligations and observable outcome.

The work is now completion of the integrated owners and their evidence. Do not
restart the October helper-to-runtime implementation sequence. Preserve its P0–P8
acceptance scope through the mapping below. The
[earlier plan](#remaining-implementation-plan--2026-11-01) and
[pre-integration qualification](../history/qualification/catalog.md#standards-and-historical-catalogs-before-main-integration--2026-11-01)
retain the original implementation history and failures.

The required executable profile comprises direct Tables, native SQL sessions,
qualified PostgreSQL/MySQL projections, public Zig and Python/TypeScript callers,
and read-only Board inspection. It includes companion values and expressions,
explicit schema projection, common-cut transfer, captured historical Tables,
finite historical views and versioned graph/foreign metadata. It does not infer
historical KV/Stream/Queue/Document execution from their descriptors. Existing
consumer refusals are part of qualification, not permission to silently discard
unsupported values. Broader language and transport support retains its owner.

### Integrated baseline and remaining obligations

Read the current public owners before changing semantics: [historical SQL](../handbook/reference/sql/as-of.md),
[Tables](../handbook/reference/tables.md), [types](../handbook/reference/sql/types.md),
[expressions](../handbook/reference/sql/expressions.md), [queries](../handbook/reference/queries.md)
and [caller semantics](../handbook/reference/callers.md).

| Original package | Implemented at the source basis | Remaining completion obligation |
| --- | --- | --- |
| P0 — Standards/effects | [Ledger](../../contracts/sql/standards-ledger.json), generated capabilities and production `OperatorTraits`; resolved CHECK/DML/projection traits and metadata-only EXPLAIN | Reconcile feature/stage/surface claims with the integrated entry points and independently executed cases. Preserve explicit unverified standards references; generation consistency alone is not conformance. |
| P1 — Types/interpretation | Stored RANGE/MULTIRANGE, aligned dense VECTOR, exact decimal programs/SUM, pinned TZif operations, CP037 PAD SPACE and CP1047 NO PAD; persisted `transit-spatial.Reference` metadata | Repeat storage/query/Arrow/neutral correspondence across the combined definition and M14 paths. Verify each narrower wire/SDK refusal and every changed-format rejection. UCA/locale execution remains refused. |
| P2 — Integrity | Persisted bounded CHECK and explicitly staged FK descriptors, owner-enforced writes, validation and recoverable dependency finalization | Prove all actual write/admission paths and interruption points at the integrated source. FK dependency protection is not parent/child enforcement; M11 owns enforcement and referential actions. |
| P3 — Evolution/projection | Accepted definition and ADD-origin directories; lazy evolution, validation/rewrite classification, signed/SQL explicit targets and paged physical interpretation | Qualify mixed segment/WAL generations, retained defaults, stable-column identity and current-policy disclosure through installed consumers. Directory coverage must not claim payload verification. |
| P4 — Historical retention | [`DirectHistory`](../../packages/zig/transit-catalog/src/DirectHistory.zig), paged directories, original-token acquisition/release, independent/common cuts and exact pin copies | Complete integrated fault/collection/growth evidence, including current mixed-transaction and Document roots. No partial cut or cleanup prefix may become a completed result. |
| P5 — Historical queries | `AS OF SNAPSHOT`, retained namespace selection, explicit Table projection, prepared reuse and captured Table descriptors/copy grants | Requalify installed history and capture after all shared-definition changes; cover result lifetimes, release races and buffered revocation. Temporal `FOR SYSTEM_TIME AS OF` remains separate. |
| P6 — Versioned interpretations | [`DirectDefinition`](../../packages/zig/transit-catalog/src/DirectDefinition.zig) atomically publishes metadata/dependencies; finite historical view expansion, graph mappings and captured foreign-layout artifacts | Qualify replacement, lost replies, retention/collection and independent metadata inspection. Graph traversal, general foreign scans and captured/joined views remain outside the admitted profile. |
| P7 — Callers/inspection | Shared Catalog history/definitions/projection operations, owned Python/TypeScript values and Board read surfaces | Repeat installed SDK and full Board schedules at the closure source; add real independently granted metadata/row readers where recent fixtures used injected UI denial. Preserve original recovery and explicit cleanup. |
| P8 — Closure | Substantial component, installed and clean-lane evidence at separately identified revisions | Resolve or reproduce recorded failures, complete missing schedules and qualify all required profiles at one committed revision. No sum of earlier passes closes this gate. |

The contracts already exist: [historical catalog](../../contracts/HISTORICAL_CATALOG_V1.md),
[catalog interpretations](../../contracts/CATALOG_DEFINITIONS_V1.md),
[Table schema](../../contracts/TABLE_SCHEMA_V1.md), [DDL](../../contracts/TABLE_DDL_V1.md),
[logical types](../../contracts/FUZE_TYPES_V1.md), [direct operations](../../contracts/DIRECT_TABLE_V1.md),
[results](../../contracts/SQL_RESULTS_V1.md) and [sessions](../../contracts/SQL_SESSION_V1.md).
Amend these owners before dependent runtime changes if an acceptance case exposes
a missing rule; do not introduce a second history/result protocol.

### Recent progress and future milestone dependencies

Milestone numbers express ownership and sequencing, not completion. Consume only
qualified facets of unfinished milestones; the following boundaries permit M10
completion without waiting for their entire delivery.

| Milestone and status at this source | Progress or dependency to use | M10 boundary and handoff |
| --- | --- | --- |
| [M1–M2](02-storage-and-query-performance.md), Completed; [M3](03-live-storage-and-sql-cutover.md), In Progress | Stable identities, direct declarations, native WAL/object storage, retained roots and lazy Table interpretation | Extend these owners; preserve M3's unfinished installed lifecycle gates. No new catalog authority or Station-mediated database history. |
| [M4](04-statement-results-and-consumption.md) and [M5](05-transactions-and-atomic-composition.md), Completed | Logical results, verified terminal counts, local serializable Table transactions and retained common cuts | Historical retention outlives a transaction independently. An independent source vector never becomes a common cut merely because its sources were acquired together. |
| [M6](06-streams-queues-and-durable-runtime.md), In Progress | Direct KV/Stream/Queue, mixed transactions, automatic DLQ recovery, declaration and partial workload SQL have landed | Preserve complete participant decisions and root retention during historical transfer/GC. Remaining workload SQL and Station replacement are not prerequisites for Table history and are not delivered by it. |
| [M7](07-document-storage-and-station-decoupling.md), In Progress | First causal map-tree storage slice, fenced WAL acceptance and authenticated paging are integrated | Regress current Document roots and descriptor compatibility. Historical Document selection waits for its own retained interpretation, transaction and caller contracts; do not treat the first slice as the complete BP/shredded Document lifecycle. |
| [M8](08-gateway-architecture-and-protocol-ingress.md) / [M9](09-client-foundation-and-language-apis.md), In Progress | Co-hosted direct execution, recovery/startup continuations; Station-free Catalog/SQL context, frozen submissions and local recovery storage | Reuse shared operations and disclose through the current guards. Core-bounded scheduling, coarse remote SQL, broad managed handles and language composition retain their own gates. |
| [M11](11-indexing-and-access-paths.md), Planned | Neutral index lifecycle contracts exist; installed secondary indexes and online builds do not | Hand off exact source/column/constraint/comparison identities, historical coverage and rewrite classification. Index-backed FK enforcement and phased physical rewrites stay here; no synchronous scan fallback or circular dependency for M10 CHECK/history. |
| [M13](13-sql-and-dataflows.md), In Progress | Service-owned finite managed Table recomputation, immutable completion revisions and transaction-owned staging have landed | Preserve retained definition/source attribution and independent inspection. WAL-complete incremental execution, temporal joins and valid-time periods remain M12 work; RANGE or snapshot syntax does not implement them. |
| [M14](14-data-structures-and-performance.md) / [M15](15-vectorized-strings-and-search.md), In Progress; [M16](16-data-centric-compilation-and-specialization.md), Planned | Resource accounting, compact Batch strings, shared lookup and encoded predicates are present | Qualify collation equivalence through the actual optimized paths and scalar controls. Retained operator keys, search-index lifecycle, broader metering and compilation remain separate. |
| [M17](17-document-profiles-and-gateway-exchange-lifecycle.md) / [M18](18-geospatial-and-spatio-temporal-computing.md), In Progress; [M19](19-multi-model-and-foreign-relations.md), Planned | Offline JSON/XML construction and compound commitments; canonical `SPR1` reference and exact spatial predicates | Preserve exact decoder/artifact/reference identities. These are no longer merely planned helpers, but do not supply installed profile retention, spatial SQL or general foreign/graph execution. M19 and later scientific workloads consume these same descriptors. |
| [M21](21-branches-merges-and-restore.md), In Progress | Immutable single-Table branches retain definitions and WAL-only data through the catalog pin owner | Preserve branch-owned retention and exact historical meaning. Writable branches, branch/tag SQL convenience, whole-catalog ancestry, diff/merge and restore remain M20 work. |
| [M23](23-formal-semantics-and-correspondence.md), In Progress | Scoped collation/DDL/result/storage models and concrete correspondence checks | Reuse A1/A2/A5 and T1/T2/T4/T8 only with their stated assumptions and implementation mappings; abstract proofs do not qualify every codec or frontend. |
| [M28](28-control-and-policy-plane.md) / [M29](29-published-resources-and-investigations.md) / [M31](31-board-reimplementation.md), In Progress | Policy/investigation foundations; merged readable storage and independent-reader computation inspection | Use current grants and public reads. Board's newer selected passes inform the remaining matrix; they do not grant historical access or close full installation/browser qualification. M29 reviewed publication stays separate. |
| [M22](22-service-and-sdk-coverage.md), In Progress; [M44](44-sql-grammar-and-dialect-ergonomics.md) / [M45](45-qualification-and-benchmarks.md), Planned | Existing consumer profiles, future full grammar comparison and combined workload qualification | M10 owns its changed-consumer regression and common-source gates. Broad new surfaces, dialect ergonomics and release-scale benchmarking retain their owners. |

### Decisions that constrain the remaining implementation

1. **Keep exact identities and lifecycle boundaries.** Selection/staging,
   acceptance, source retention, publication and availability are distinct.
   Reuse `DataLifecycle.Snapshot`, stable object/ColumnIds and the existing
   operation/token owner. Catalog positions, partition LSNs, schema revisions,
   content identities and transaction decisions are distinct typed evidence.
   Snapshot `manifest/v{N}` notation does not create protocol v2/v3.
2. **Bind before compilation and preserve original recovery.** Resolve the
   published selector and retained namespace before names, views, columns and
   comparison rules. Freeze explicit projection targets by accepted definition;
   `CURRENT` resolves once. Prepared/captured work cannot silently refresh a
   source or reparse under today's schema after an uncertain reply.
3. **Separate interpretation from current permission.** Metadata, rows, row
   placement and terminal counts require their current owning grants, including
   after buffering, DROP, empty/repeated pages and independent-reader access.
   Historical grants, a selector and an old policy epoch confer no authority.
   EXPLAIN/inspection acquire no new pins, read no payloads and dispatch nothing.
4. **Preserve the admitted semantic profiles.** Keep logical type, physical
   encoding and comparison/rounding/metric/timezone/spatial rules orthogonal.
   Existing CP037 NO PAD remains distinct from PAD SPACE and CP1047. Hashes,
   normalized keys, prefixes, dictionary/FSST predicates and pruning must agree
   with full comparison. Pin actual TZif bytes; never fall back to host rules.
   Spatial metadata and recorded UCA names do not imply executable spatial/UCA SQL.
5. **Keep integrity and evolution explicit.** CHECK TRUE/NULL passes; FALSE,
   missing, type_error and conflict reject candidate rows. NOT VALID defers old
   data validation only. FK staging is visibly unenforced, with protected exact
   dependencies. Lazy metadata/projection, bounded validation and physical
   rewrite are distinct; populated incompatible rewrites reject pending M11.
6. **Do not manufacture completeness or retention.** Results retain M4's schema,
   bounded batch lifetimes and verified outcome; EOF/early close is not empty
   success. Projection-directory inspection is not payload verification. Missing,
   corrupt, explicitly released and unsupported history have distinct failures.
   Unlimited retention remains the default; pressure cannot authorize expiry.
7. **Change compatibility only when necessary.** This plan does not schedule a
   gratuitous definition replacement. If a fix changes stored/wire/ABI semantics,
   follow the [current-v1 cutover policy](../handbook/reference/versioning.md):
   replace the shared definition, regenerate affected resources/fixtures and
   migrate all consumers together. Missing/foreign definitions reject before
   execution, with original bytes and uncertain work preserved. Old dated hashes
   in proof records are evidence for those runs, not today's compatibility ID.

### Integrated qualification progress — 2026-11-02

The [standards/collation record](../history/qualification/catalog.md#integrated-standards-ledger-and-retained-collation-cuts--2026-11-02)
records the executed R0/R1 increment: the ledger maps 83 implemented stage
claims to executable owners, its negative controls and 65 clean fast checks
pass, and the signed disk schedule recovers both original pre-flush and sealed
collation cuts after restart. The new fixture's compile error was repaired;
this is selected evidence, not execution of every mapped owner or R1 closure.

The [independent-reader record](../history/qualification/interfaces.md#independent-historical-board-readers--2026-11-02)
preserves the installed Board attempts, original acquisition recovery and R3
fixture repairs. Each principal now has a separate signing file. Historical
settlement retains bounded per-step evidence, and uncertain physical flushes
resume their saved object/frontier target, including an injected lost reply.
The complete ordinary workbench driver passes at `6eae861d4`, including all
12 browser cases and the real independent-reader/revocation assertions.
Request deadlines and 32-attempt bounds are unchanged. Earlier failed runs
remain failed; a successful recovery or narrower schedule does not replace them.

The [native historical collection record](../history/qualification/catalog.md#native-historical-obligations-through-disk-collection--2026-11-03)
adds an R2 disk increment at `35b0fe983`: signed JSON and typed local dispatch
both preserve original acquisition/closure identities through seven lost replies,
three physical collections and three cold owner reopens per case. Unpublished
retained state, concurrent abandonment/release, terminal replay and independent private
pin ownership pass with exact original rows and an orphan reclamation witness.
All 66 clean fast checks pass at that source. This is local service coverage for
a single Table; it does not close common-cut transfer, installed process/transport
faults or the full storage/query lane.

M10 remains **In Progress**. R2's complete retention/collection matrix, R4's
integrated work/allocation evidence, remaining consumer schedules and R5's
common-revision clean lanes remain open. Use the records above for exact
sources, completed checks, failures and omissions; the acceptance matrix below
continues to specify the full closure obligation.

### Review units and delivery order

These are planned changes and checks. Start with R0, then R1. R2 and R3 consume
that settled contract/consumer boundary; R4 measures the resulting implementations.
R5 closes only after all required results are available at its chosen source.
Within each unit, first reproduce the existing case, add only missing coverage
and fix the owning defect; avoid replacing mature owners with another abstraction.

#### R0 — Reconcile capability claims and preserve the failure baseline

**Maps to P0/P8. Owners:** `standards-ledger.json`, its generator/checker,
`OperatorTraits`, grammar corpus and the domain qualification records.

Complete the existing ledger/evidence mapping for every admitted M10 entry point with
separate parse/lower/execute/recover/transport claims, exact surface/type limits,
positive/negative cases and fixture provenance/license. Check the actual compilers
and dispatchers, not symbol presence. Keep selected SQL:2023, SQL/JSON, SQL/PGQ
and SQL/MED targets distinct from Transit extensions and unverified standards
citations. GQL/Cypher/PGQL support requires its own evidence.

Record the closure candidate's commit, shared/format definitions, binary hashes,
installed artifacts, toolchain, topology, commands and unchanged budgets. Give
each runner a separate evidence directory. Preserve original failures and private
installations; no concurrent job may remove another job's checkout or overwrite
its report. The ledger and existing tests should reveal missing work rather than
being relabeled to make it disappear.

**Exit:** every original P0–P8 obligation maps to an implemented owner plus an
executable check or a named missing check; known failures below have reproducible
commands and explicit expected outcomes. Unverified standards remain unverified.

#### R1 — Close semantic and consumer integration gaps

**Maps to P0–P3/P6/P7. Owners:** `transit-fuze`, `transit-storage`,
`transit-catalog`, generated protocol/neutral/Arrow bindings and affected SDKs.

Run independent comparator/key/hash/prefix/pruning fixtures through stored Table
keys, scans, dictionary/FSST filters, compact Batch strings, prepared/captured
plans and retained reads. Include distinct stored spellings that compare equal,
PAD SPACE/control characters, CP037/CP1047 punctuation and prefix ties. Exercise
actual optimized paths and a scalar/full-scan oracle at the same cut.

Carry companion descriptors and values through storage reopen, query expressions,
Arrow and neutral values: range extrema/empty/unbounded/continuous bounds and
multirange coalescing; vector alignment/dimension/metric, finite/zero-norm and
binary padding rules; decimal scale, rounding, intermediate overflow and ordered
SUM; TZif digest, gap/fold, coverage refusal and unavailable artifacts. Preserve
explicit unsupported transport/language combinations, including C/C++'s narrower
construction profile and Flight's selected types.

Exercise CHECK at point/bulk/SQL/typed/transaction candidates and savepoints,
including defaults and NOT VALID validation. A rejected atomic write publishes no
successful prefix. Interrupt FK protection/publication/finalization/cancellation;
retain protection until original publication is settled. Check hidden dependency
blockers without disclosing their identities. Rename preserves stable bindings;
DROP/recreate cannot rebind them. Verify schema evolution against mixed physical
generations and WAL tails, ADD-time defaults and exact projection targets.

**Exit:** actual owner and consumer checks pass for each admitted profile and
refusal. Any incompatible repair includes all stored-plan/schema/selector/pin,
transaction, ABI, signing and generated-consumer updates in the same cutover.
Definition changes reopen affected downstream qualification.

#### R2 — Qualify complete historical acquisition, execution and cleanup

**Maps to P3–P6. Owners:** `DirectHistory`, `DirectDefinition`,
`DirectStorageGraph`, Table pin/projection and transaction owners,
`transit-query-direct`, `transit-query` and `transit-sql`.

Extend the installed disk schedules only where their matrix is incomplete:

- Interrupt before/after source-pin acceptance, catalog publication, common-cut
  reservation/copy, abandonment and release. Lose acknowledgements and restart
  the owner; inspect the same original operation. Unpublished prefixes stay
  unavailable; no acquired pin becomes an untracked collection obligation.
- Transfer the exact acquired transaction closure while commit/abort and cleanup
  race. Preserve mixed participant commitments, copying only the selected Table
  sources admitted by history. Published history and the transaction own separate
  pins; cleanup neither releases the other's copy nor bypasses a reservation.
- Compile retained namespace/table/column names before and after rename, DROP,
  recreation and later defaults. Reuse prepared queries; exercise explicit
  projection and old-column success/new-column rejection. Never splice a newer
  snapshot into an incomplete read.
- Capture an exact historical Table while copy acknowledgement is lost and live
  DDL/frontiers advance. Release before copy acceptance fails explicitly;
  release after acceptance leaves the query-owned copy usable. Replacement and
  closure reconcile the original copy without acquiring a newer basis.
- Replace/drop a view, graph mapping and foreign decoder; retain original exact
  dependencies, typed view filters and captured bytes through real collection.
  Verify view filtering before an outer fallible expression, zero-source foreign
  metadata selections, unavailable bytes and corrupt checksums. Replay never
  fetches a mutable URI or activates an effect/computation.
- Checkpoint/trim/flush/compact and reopen with cold caches. Keep schema origins,
  TZif and decoder artifacts, `.tseg`/`.tdel`, WAL-only rows, required decisions,
  branch/history/managed-result obligations and current Document roots reachable.
  Collect a separately staged orphan to show that retention is not blanket
  collection disablement.

**Exit:** exact rows, definitions, source/consistency evidence and operation
outcomes match independent expectations through restart and collection; all
acquisition/release controls finish or retain explicit unresolved obligations.
No test converts missing history or an incomplete prefix into a successful empty
result. Unsupported temporal, branch convenience and view profiles still refuse.

#### R3 — Complete public caller and independent inspection journeys

**Maps to P5/P7. Owners:** `transit-data-client`, `transit-sql-results/client`,
SQL service/host adapters, language SDKs and Board's existing feature owners.

Execute the same retained-basis journey through public Zig, installed sync/async
Python and TypeScript, native SQL and the admitted PostgreSQL/MySQL profiles.
Check full-width identities, output ownership beyond scratch reset/next call,
selector-bound continuations, cancellation/join, early close, host/node/gateway
replacement and recovery from saved original acquisition/release identities.
Closing a local handle must not release separately retained history.

Use independent authority subjects for metadata-visible non-SELECT, SELECT-only
and denied readers. The current Table model has no separate metadata-only grant;
exercise non-SELECT visibility through a native caller with an existing Table
write privilege, while keeping Board's subject read-only. Revoke after buffering rows, schema, metadata, repeated/empty pages and
terminal counts. Exercise live/retired/recreated objects and released selectors;
a wrong-kind/connection/selector continuation must fail. Preserve validated
missing-selection diagnostics versus authority unavailability through the client.
The recent computation reader is a useful precedent, not authority to read a
publisher's private operation records.

Repeat full Board installation and browser profiles, retaining the recent R2/R3
selected successes as prior evidence. Add real non-SELECT metadata versus SELECT-only
placement checks where the latest browser fixture injected denial for presentation.
Check incomplete coverage, failed/revoked observation clearing, retained definition
and location pages, and independent computed-result attribution. Board must issue
only permitted public inspection reads for these features; fixture setup owns
retention/mutation separately. No raw provider reads or hidden pin controls.

**Exit:** all required public journeys preserve one basis, truthful completion,
original recovery and current disclosure across installed boundaries. Unsupported
SDK/wire profiles reject explicitly; local frontend tests or injected 403s alone
do not establish native permission enforcement.

#### R4 — Establish bounded work and implementation correspondence

**Maps to P1–P8. Owners:** existing storage/query/catalog tests,
`transit-memory` measurement seams and M22's scoped proof/replay owners.

Grow objects, definitions, source selections, pins, dependencies and physical
schemas beyond resident caches. Measure cold/warm lookup, acquisition/publication,
read and release/abandon/collection work, including incomplete operations and
reopen without hints. Use counting allocators after warmup and separate scratch
from retained output. Account for bytes/pages/ranges, resident high water,
allocation count, retained bytes and time to first/complete result. Check quota
refusal without losing accepted obligations. Do not raise fixed ceilings or
require expiry to make the schedule pass.

Compare current and retained reads at identical source, durability, policy and
budgets. Preserve the earlier 8/137-object and mixed-layout measurements as
baselines at their recorded sources; set regression budgets from reruns rather
than inventing latency promises. Report increased total work separately from
bounded resident memory.

Run independent semantic fixtures against real owners and the applicable existing
A1/A2/A5 and T1/T2/T4/T8 checks. Where correspondence is claimed, retain the abstract
trace mapping, implementation replay and compiling negative controls. A Lean
preorder assumption does not prove a new concrete collation; an interrupted model
or a mutant that cannot compile is not passing evidence.

**Exit:** each admitted hot path has its stated allocation/resource evidence,
collection/recovery grows without a total-cardinality memory array, and formal
claims name exact assumptions and implementation coverage. Broader M13 performance
and M44 release benchmarking remain separate.

#### R5 — Close at one committed revision

**Maps to P8 and all prior exit gates.** Select a committed closure candidate after
R1–R4 fixes. Build matching runtime/SDK/Board artifacts there and execute the
acceptance matrix below and affected clean lanes from the real inventory. If code,
contract or fixtures change, rerun affected gates and record the new source;
previous-source successes remain historical evidence. Preserve failed and
incomplete outcomes without concatenating continuations into a passed lane.

Promote established behavior/limits to the existing public owners, including any
stale helper-only explanations in component or internals prose. Publish exact
commands, sources, artifacts, faults, budgets, outcomes and omissions in the
owning qualification topics. Update this milestone and the roadmap index together
only when every required gate passes. Do not close the broader standards issue or
move unfinished M10 obligations to a later milestone to obtain completion.

### Failure baseline and what remains to resolve

The [M10 pre-integration record](../history/qualification/catalog.md#standards-and-historical-catalogs-before-main-integration--2026-11-01)
is the failure baseline. Later [Board storage evidence](../history/qualification/interfaces.md#board-readable-storage-and-deferred-features--2026-11-02)
and [computation inspection evidence](../history/qualification/interfaces.md#board-computation-inspection--2026-11-02)
qualify their stated sources and selected profiles.

| Recorded observation | Current interpretation | Required next evidence |
| --- | --- | --- |
| C logical fixture expected unsupported companion construction; corrected profile passed independently | A corrected focused check is not a passed systems SDK lane | R1/R5: run the complete current `sdks-systems` inventory, retaining admitted values and explicit refusals |
| Board acquisition returned 409 although the original operation later published; original-token recovery fixes and focused retries passed | Preserve the original failure; later success does not explain its cause | R2/R3: reproduce lost/pending/capacity outcomes under original identities; R5: complete installation/UI lane |
| Browser admission exceeded the unchanged bound; another stopped-authority attempt returned 503 and lost its saved token | Later workbench browser passes narrow the pending scope but do not resolve the old unknown operation | R3: retain exact pre-dispatch recovery state, prove original settlement and run complete browser profiles; do not increase timeouts or resubmit SQL |
| Storage-query checkout disappeared after twelve successful targets; common-source runners were interrupted | Missing raw records and unexecuted targets remain missing evidence | R0/R5: isolated preserved checkout/report paths, then a complete storage-query run |
| Core continuation and corrected `transit-sql-results` target passed separately | Neither makes the earlier failed/incomplete aggregate pass | R5: use real inventory targets and complete clean core plus required dependent lanes |
| New Board retained-placement/independent-computation focused schedules pass; full connection profiles retain SQL-only 503/timeout failures | Reuse successful fixture coverage, keep full-profile failures open | R3/R5: real metadata/row grant splits, original SQL outcome diagnostics and complete installation/browser evidence without hidden retries |

### Acceptance matrix and runnable checks

This table specifies the full closure requirements. The
[integrated progress](#integrated-qualification-progress--2026-11-02) above
links subsequent selected executions; listing a command here establishes no
passing result. Use the pinned Nix shells and [tasks](../../tasks/README.md);
each narrower check keeps its stated scope.

| Gate | Existing owning check to run/extend | Required result |
| --- | --- | --- |
| Standards/fixtures/contract drift | `python3 -B tests/runner/launch.py tests/query/logical/standards_ledger.py`; `python3 -B tests/runner/launch.py tests/catalog/tables/historical_catalog.py`; `just check contracts` | Generated data matches owners; independent positive/negative runtime checks support claimed stages; no incompatible artifact accepted |
| Semantic integration and projection | Package-local `zig build test` in Fuze/storage/catalog/query-direct; `just test::direct-table-service collations`; `just test::direct-table-service projection`; `just test::logical-codec`; `just test::logical-arrow` | Compare/hash/key/pruning and companion semantics agree; mixed layouts retain exact meanings and bounded lifetimes |
| Integrity | `just test::sql-integrity`; `just test::direct-state-transaction`; `just test::direct-mixed-transaction` | All candidate writes and savepoints preserve CHECK and atomicity; staged FK protection/finalization is recoverable |
| Historical SQL/results | `just test::sql-history`; `just test::sql-sessions`; `just test::sql-transactions`; `just test::sql-result-allocations` | Names/views/projections and common/independent observations remain exact; empty/multi-batch/early-close and revocation preserve result truth |
| Captured historical Tables | `just test::sql-history` runs `captured_history` in the [installed driver](../../tests/interfaces/sql_sessions/history.py); `just test::direct-captured-query --captured-only` covers the shared capture regressions | Lost copy replies, release races, replacement and closure keep the original source and query-owned retention |
| Durable retention/growth | `just test::local-catalog`; `just test::storage-collection`; affected storage/catalog disk and counting-allocation tests | Complete cuts survive physical maintenance; abandoned work and genuine orphans clean up; growth stays within resident/work budgets |
| Installed language callers | `just bindings::python-test`; `just bindings::node-sdk-test`; affected logical/ABI and remaining language profiles | Original history operations survive caller replacement/lost replies; owned wide values and unsupported-type failures remain faithful |
| Read-only Board | `just transit-board::workbench-test`; `just transit-board::workbench-browser`; `just transit-board::computations-test`; `just transit-board::computations-browser` | Full installed profiles pass with current rights, exact retained evidence and bounded pages; independent readers gain no mutation/private-token authority |
| Correspondence | `just test::sql-rewrites` and affected model/replay tasks from the `formal` lane | Completed scoped models, actual implementation correspondence and effective negative controls, with explicit exclusions |

The [suite inventory](../../tests/runner/suite.json) is authoritative for lane
contents. Before pushing implementation/test changes run affected committed-HEAD
`just ci clean --lane NAME` checks. The closure candidate needs `core`,
`storage-query`, `interfaces-sql`, `interfaces-relational`, `installation-ui`,
`browser`, `formal` and `sdks-conformance`, `sdks-scripting`, `sdks-systems`,
`sdks-managed`. Include `interfaces-connectors` and `launchers` for the integrated
M10 definition: their earlier passes predate its replacement. Record the dependency
decision for any future scope adjustment; no required M10 gate may be excluded
solely because an earlier revision passed. Full integration remains a release
gate. Separate lane runs must all identify the same candidate before claiming
common-revision closure.

Public documentation updates use the existing type/Table/history/query/caller
owners and state/query/storage internals, with component/SDK guides for exact
profiles. Check repository links/whitespace and affected handbook builds. This
plan establishes no runtime guarantee by itself; executed scopes belong in the
qualification records above. Milestone status remains In Progress.

## Remaining implementation plan — 2026-11-01

The [complete prior plan and increment record at this plan's source](https://github.com/spoke-sh/transit/blob/5e00b53bfed8a552dc7306e1338394ec037ac9bb/docs/roadmap/10-standards-and-catalogs.md#remaining-implementation-plan--2026-11-01)
preserves the original P0–P8 work packages, intermediate definition identities,
source audits, development checks and acceptance matrix. The November 2 plan
above supersedes its scheduling and stale open-work assessments. Implemented
collations, CHECK/FK metadata, historical catalogs, SQL, views and caller surfaces
must not be treated as unimplemented because an earlier paragraph predates their
increment. Earlier passes retain their original revision and limits; the
[qualification record](../history/qualification/catalog.md#standards-and-historical-catalogs-before-main-integration--2026-11-01)
preserves failures and incomplete runs.

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
`P0`–`P8` exit gates. At that revision, the production SQL compiler rejected
CHECK/FOREIGN KEY, RANGE/VECTOR and historical catalog selectors; native schemas
did not persist those descriptors. The table preserves that revision's assessment;
the [integrated baseline](#integrated-baseline-and-remaining-obligations) describes
the newer implementation. Milestone 10 remains **In Progress**.

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
[current sequence](#review-units-and-delivery-order) completes integration and
qualification against the newer source. Existing WAL traversal,
Table snapshot/transaction identities, current-policy checks and retention owners
must be reused; a separate in-memory manifest namespace cannot replace them.

The installed Python and Node history schedules pass at `95e82586f`: 457 and
230 public requests respectively, including sync/async Python, caller/node
replacement, lost acquisition/release replies, retained original identities,
rename/DROP/name reuse and current revocation. This evidence predates the accepted
interpretation/projection cutover and must be repeated at the final PR revision.
