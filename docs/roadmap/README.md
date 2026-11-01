# Roadmap

This roadmap tracks milestone scope, sequencing, acceptance criteria and
completion status for Transit, ordered by dependencies and explicit delivery
priorities, not delivery dates.
The supporting [development workflow implementation plan](development-workflow.md)
records the completed test directory migration, build reuse and feedback
qualification alongside this product sequence.
Current behavior belongs in the [public reference](../README.md), mechanisms in
[Internals](../handbook/internals/README.md), and executed checks in the
[proof ledger](../history/qualification/README.md). A planned milestone does not establish
support; completed milestones promote their current semantics into the public
handbook while remaining in this index with their completion status.

The product goal is programmable, versioned data infrastructure: declare schemas,
datasets, computations and policies, then inspect whether Transit is fulfilling
that declaration. Data and derived computation are the primary model; durable
processes (`Station`), write-ahead streams (`TransitLog`) and connectors are the
mechanisms that **activate** data, materialize changes and coordinate external
effects. The [current data model](../handbook/reference/data-model.md) describes
the supported pieces and the gaps between them.

The [observation and feedback loop](../handbook/reference/collaborative-decisions.md#the-observation-and-feedback-loop)
gives this work a product target: improve what humans and agents can observe
before acting and what they can learn from the consequences afterward. Track
observation coverage, latency and cost while preserving meaning, source versions,
current authorization and uncertainty. The
[qualification plan](42-qualification-and-benchmarks.md#observation-and-consequence-evidence)
defines the proposed measures and comparison method; individual milestones
qualify their contribution as they land. These are evaluation goals, not current
measurements, and they do not assume that modeling or reasoning is solved.

## Performance ambition

Our ambition is to make Transit the fastest database and durable runtime for its
supported workloads. Pursue that through measured access paths, efficient data
structures, query planning and runtime execution, with explicit latency,
throughput, memory and recovery targets. Every claim must name its workload,
comparison versions, hardware, resource budgets, durability and isolation.
Measure complete outcomes and sustained mixed load, including background work;
component throughput alone does not establish application performance.

The [indexing milestone](11-indexing-and-access-paths.md) establishes safe shared
access paths. The [data structures and performance milestone](13-data-structures-and-performance.md)
delivers the local workload scorecard, selected optimizations and regression
budgets. Earlier owners establish baselines and meet their existing gates; later
providers, distributed execution and language surfaces extend the same measures.
[Final qualification](42-qualification-and-benchmarks.md) combines the evidence
at one revision. Publish wins, regressions and unresolved competitive gaps with
reproducible results; correctness, current authorization and accepted-work
recovery remain part of every performance profile.

The next implementation sequence for startup and the existing 10–100× SQL
objectives is the [M8 follow-up performance plan](08-gateway-architecture-and-protocol-ingress.md#follow-up-performance-delivery--2026-11-01).
Run the [M9 SDK measurement and optimization sequence](09-client-foundation-and-language-apis.md#sdk-performance-implementation-sequence--2026-11-01)
alongside it using shipped APIs. These plans preserve the milestones' existing
scope and status; SDK gains require their own measured baselines.

## Delivery phases

Seven phases group the linear milestone sequence by the capability an application
or operator gains. The phase outcomes summarize their milestones' acceptance
criteria; each numbered milestone remains the owner of scope, status and proof.
Read the [delivery checkpoints](#delivery-checkpoints) for the execution plan.

| Phase | Milestones | Exit outcome |
| --- | --- | --- |
| [I: Local data and application foundations](#phase-i-local-data-and-application-foundations) | 1–11 | Applications declare and query local Tables, KV, Documents (backed by `.tseg` succinct trees and shredded subcolumns in `DocumentPartition` with `Station` decoupled), Streams (`PRODUCE INTO` / `CONSUME ... FROM`) and Queues (`ENQUEUE INTO` / `CLAIM ... FROM`), consume complete statement outcomes, compose supported transactions, run `Station` behaviors over database primitives with the database decoupled from actor turns, connect through a formalized event-driven, sans-I/O gateway boundary co-hosted with the Direct Data Plane without `/table/v1` polling cascades, and use shared clients with exact historical interpretation and maintained indexes |
| [II: Data composition, performance and interface coverage](#phase-ii-data-composition-performance-and-interface-coverage) | 12–22 | Applications maintain derived data, meet measured local database/runtime, string/search and data-centric compilation performance targets, use the multi-format Document Type Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`, `AMQP`, `MQTT`, `NTP`, `PDF`, `DOCX`, `XLSX`, `ODF`) and unified gateway/connector exchange lifecycle, store and query 2D/3D geospatial, volumetric 3D model, discrete-exterior-calculus cochain field (`COCHAIN_FIELD` / `.float_zfp`), raster and spatio-temporal data (`GEOMETRY`, `GEOGRAPHY`, `MESH3D`, `SOLID3D`, `SCENE3D`, `POINTCLOUD`, `RASTER2D`/`GRID3D`, `S2_CELL`, `H3_CELL`, `OCT_CELL`, `TRAJECTORY`) with topological/Edgebreaker/octree compression and incremental DBSP evaluation, compose native and foreign models, cook and stream interactive 3D game assets and continuum/fluid simulations (`.mesh_cluster_dag`, `.tex_mip_morton`, `.vdb_hierarchy`, `.splat_hilbert`, `SKELETON3D`, `ANIMATION_CLIP`, incremental `NavMesh`/`HLOD` DDC dataflows, CFD differential/isosurface/conservation operators and ECS AoI streaming), work across branches and use the qualified service/SDK matrix with selected formal models and implementation correspondence |
| [III: Distributed durability and operations](#phase-iii-distributed-durability-and-operations) | 23–26 | Operators use qualified providers, replicate and recover complete history, perform verified backup/restore/upgrades and move execution safely |
| [IV: Governed collaboration and Board](#phase-iv-governed-collaboration-and-board) | 27–30 | People and applications inspect published resources, propose and review changes under shared policy and use the installed Board workbench |
| [V: Agents and mixed application composition](#phase-v-agents-and-mixed-application-composition) | 31–34 | Agents and applications use governed MCP access, reactive activation and recorded effects through complete direct, Station and mixed language experiences |
| [VI: Scientific, media and evidence workloads](#phase-vi-scientific-media-and-evidence-workloads) | 35–40 | Applications compose calibrated scientific arrays, synchronized video, attributable ML/AI experiments, robotics replay, software/build/deployment evidence and constrained planning over shared versioned data, numerical, policy and publication contracts |
| [VII: Qualification and release](#phase-vii-qualification-and-release) | 41–44 | One committed revision has a harmonized SQL grammar audited against formal standards and industry dialects, combined workload/fault evidence, verified distribution artifacts and runnable installed onboarding, followed by speculative research into declarative language, structural context and corpus-native synthesis |

Phases are delivery groupings, not additional runtime dependencies or release
dates. Contract work and implementation may overlap when the owning prerequisites
are satisfied; an adapter exposes only qualified capabilities. A phase is complete
only when every milestone it contains is complete. Focused correctness, recovery
and performance checks remain acceptance gates throughout the sequence; phase VII
combines that evidence at one revision.

## Milestone sequence

### Phase I: Local data and application foundations

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 1 | [Data identities, declarations and commit contracts](01-declarative-data-lifecycle.md) | Completed ([#108](https://github.com/spoke-sh/transit/issues/108)) | Neutral data/definition identities, lifecycle operations, atomic-domain/isolation decisions and snapshot contracts before dependent formats |
| 2 | [Local durable storage, `.tseg` segments and bounded queries](02-storage-and-query-performance.md) | Completed ([#109](https://github.com/spoke-sh/transit/issues/109)) | Durable native local WAL/object storage across all owners, bounded segments/readers, logical history, codecs/collations and safe local publication |
| 3 | [Executable data lifecycles and live storage/SQL cutover](03-live-storage-and-sql-cutover.md) | In Progress ([#110](https://github.com/spoke-sh/transit/issues/110); [implementation plan](03-live-storage-and-sql-cutover.md#implementation-plan--2026-10-27)) | Installed direct Table and named KV/Document/computation lifecycles, lazy `.tseg` schema projection, local storage/SQL wiring and exact restart recovery |
| 4 | [SQL statement results and client consumption](04-statement-results-and-consumption.md#implementation-plan) | Completed | Formal transport-independent result model, shared client consumption, bounded batches/readers and verified completion |
| 5 | [Transactions, consistent snapshots and atomic composition](05-transactions-and-atomic-composition.md) | Completed | Local serializable multi-Table transactions, retained common cuts, savepoints, original decision recovery and Table checkpoint/outbox composition; native KV/Document and Stream/Queue participant extension handed to M6/M7 |
| 6 | [Declarative streams, queues and durable runtime architecture](06-streams-queues-and-durable-runtime.md) | In Progress ([current assessment](06-streams-queues-and-durable-runtime.md#source-baseline-and-remaining-gaps); [next implementation changes](06-streams-queues-and-durable-runtime.md#first-implementation-changes)) | Delivered database/SQL separation, typed Stream/Queue lifecycles, payloads, leases and bounded local maintenance; complete named direct KV, mixed state/append/settlement transactions, Queue waits/DLQ, dedicated SQL and finite `STREAM_SLICE`, transactional Station/consumer cutover and common-revision performance/recovery qualification |
| 7 | [Logical document storage, `.tseg` trees and Station decoupling](07-document-storage-and-station-decoupling.md) | In Progress ([remaining implementation plan](07-document-storage-and-station-decoupling.md#implementation-plan-for-remaining-work)) | `Document` decoupled from `Station` actor turns (`STATION_DOCUMENT_V1`/`SIX1`), logical $\tau \perp \kappa \perp \epsilon$ Document algebra in `DocumentPartition` over `TWAL1` + `.tseg` succinct trees ($2N$-bit `BP`), adaptive columnar path shredding, 5-state cells and pluggable versioned/CRDT merge profiles |
| 8 | [Gateway architecture, sans-I/O wire protocols and direct-plane ingress](08-gateway-architecture-and-protocol-ingress.md) | In Progress ([wire foundation and plan](08-gateway-architecture-and-protocol-ingress.md#wire-foundation-implementation--2026-10-31)) | Preserve delivered recovery/co-hosting and browser ingress; close measured console/publication costs toward [#211's 10–100× target](https://github.com/spoke-sh/transit/issues/211), then qualify resumable pure codecs, core-bounded scheduling, coarse remote SQL and Flight/Serving integration with explicit M6/M7 owner/caller gates |
| 9 | [Shared client foundation and language-native APIs](09-client-foundation-and-language-apis.md) | In Progress ([remaining implementation plan](09-client-foundation-and-language-apis.md#remaining-implementation-plan--2026-11-01)) | Build on delivered Catalog/SQL context and local recovery storage; complete coordination, ordinary settlement, managed handles, independent bindings and installed language APIs; compose available direct KV/Stream/Queue and native mixed transactions, with Documents gated by M7 |
| 10 | [Standards, collations and historical catalogs](10-standards-and-catalogs.md) | In Progress ([implementation plan](10-standards-and-catalogs.md#implementation-plan--2026-10-30)) | Capability evidence, declarative `CHECK`/`FOREIGN KEY` catalog bindings, collation-preserving history and exact retained catalog/data interpretation |
| 11 | [Indexing model, access paths and online maintenance](11-indexing-and-access-paths.md) | Planned | Shared index definitions, bounded ordered/covering/partial access, fine-grained key-range SSI conflict tracking, index-backed `FOREIGN KEY` enforcement and recoverable online index/table builds |

### Phase II: Data composition, performance and interface coverage

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 12 | [Managed computations and WAL-activated dataflows](12-sql-and-dataflows.md) | In Progress ([implementation plan](12-sql-and-dataflows.md#implementation-plan--2026-10-30)) | Complete analytical SQL (window functions, CTEs, universal `D-Join` subquery unnesting, multi-way joins, sandboxed UDFs), bitemporal `AS OF JOIN`, DBSP interval-depth and identity-aware order-book (`LOB`) state maintenance, `CHANGES(...)` CDC egress and WAL-driven managed computations |
| 13 | [Data structures, query optimization and runtime performance](13-data-structures-and-performance.md) | In Progress | Zero-steady-state-allocation hot paths, per-morsel CPU/memory/IOPS metering, LeanStore/Umbra swizzled zero-copy buffer slabs, CedarDB directory-tagged join hash tables & WCOJ, statistics/costing, partitioning/clustering, LSM/`.tseg` compaction bounds and workload scorecards |
| 14 | [First-class strings, perfect hashing and vectorized search execution](14-vectorized-strings-and-search.md) | In Progress ([implementation plan](14-vectorized-strings-and-search.md#implementation-plan--2026-10-30)) | 16-byte collation-prefixed Umbra/German strings, compressed-domain `.dictionary`/`.fsst` predicates, `comptime`/immutable perfect hashing with 16B SIMD comparisons, and declarative search/proximity/sequence contracts over swappable `.tseg` index profiles (256-doc Block-Max BM25, hybrid search, biological sequences `BIO_SEQ` `.seq_2bit`/`.cram_ref_delta`/`.fm_bwt`/`.geno_pbwt`, chemical `MOLECULE` `.mol_graph` Morgan bitvectors, and `.audio_fingerprint` constellation hashes) |
| 15 | [Data-centric pipeline fusion, AOT query compilation and adaptive specialization](15-data-centric-compilation-and-specialization.md) | Planned | HyPer/CedarDB data-centric push fusion inside vectorized morsels, per-row-group dense non-null specialization, Flying-Start Adaptive Morsel Tier-Up, `transit-app` AOT Zig query/view compilation and HyPer/Umbra/CedarDB benchmark baselines |
| 16 | [Document type library, protocol grammars and gateway exchange lifecycle](16-document-profiles-and-gateway-exchange-lifecycle.md) | Planned ([implementation plan](16-document-profiles-and-gateway-exchange-lifecycle.md#implementation-plan--2026-11-01)) | Declarative Document Profiles (`JSON`, `XML`, `HTTP`/`MIME`, `FTP`, `EDI_X12`/`EDIFACT`/`HL7`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`/`SDP`, `AMQP`, `MQTT`, `NTP`) and compound container/layout formats (`PDF`, `DOCX`, `XLSX`, `ODF`) over shared SIMD structural scanners, perfect hash vocabularies, container part graphs and `.tseg` subcolumns, plus transport-decoupled gateway/connector exchange capture (`STATION_EXCHANGE_V1` $\to$ `DocumentPartition`) and causal lineage |
| 17 | [Geospatial types, topological compression, spatial indexing and incremental spatio-temporal queries](17-geospatial-and-spatio-temporal-computing.md) | In Progress ([implementation plan](17-geospatial-and-spatio-temporal-computing.md#implementation-plan--2026-11-01)) | Orthogonal $\tau \perp \kappa_{\text{spatial}} \perp \epsilon$ 2D/3D types (`GEOMETRY`, `GEOGRAPHY`, `MESH3D`, `SOLID3D`, `SCENE3D`, `TRANSFORM3D`, `POINTCLOUD`, `RASTER2D`/`GRID3D`, `SPARSE_MATRIX`, `COCHAIN_FIELD`, `BBOX2D`/`3D`, `S2_CELL`, `H3_CELL`, `OCT_CELL`, `TRAJECTORY`), Shewchuk exact `orient2d`/`3d` predicates & snap-rounding grids, 16B inline 2D/3D MBR vector headers, `.geoarrow`/`.twkb_delta`/`.mesh_edgebreaker`/`.raster_morton`/`.float_zfp`/`.sparse_bcsr` codecs, logical topological shared-arc/face (`.topo_arc`, `.topo_face` + $C^0..C^3$ cochain fields), `INTERIOR`/`BOUNDARY` `S2`/`H3`/`OCT` Roaring coverings (`.s2_roaring`, `.octree_roaring`), instanced `.scene_dag`, 2.5D VLSI `.layout_manhattan`, `.pcloud_hilbert` (including 3D protein/atomic structures & spatial transcriptomics) and 4D/6-DoF trajectory compression, 2D/3D zone maps, `RTREE`/`S2`/`OCTREE` indexes, 2D/3D spatial SSI and DBSP Z-set incremental `ST_Union`, `ST_3DUnion`, `DRC`/`LVS`, Discrete Divergence Theorem volume/flux aggregates and spatial/3D clash joins |
| 18 | [Multi-model and multi-format foreign relations](18-multi-model-and-foreign-relations.md) | Planned | Document/graph/2D-spatial/3D-coboundary projections (with WCOJ cyclic pattern matching), multi-model lexical/structural/vector/2D-3D-spatial hybrid search composition, foreign formats (`Parquet`/`GeoParquet`, `FlatGeobuf`, `COG`, `glTF`/`GLB`, `OpenUSD`, `KTX2`, `OpenVDB`, `IFC`/`STEP`, `3D Tiles`, `LAS`/`LAZ`/`COPC`, `CGNS`/`VTU`/`OpenFOAM`/`Zarr`/`NetCDF`/`GRIB2`, `FASTQ`/`BAM`/`CRAM`/`VCF`/`PDB`/`mmCIF`/`SMILES`/`.h5ad`, `DICOM`/`NIfTI`/`OME-Zarr`, `OASIS`/`GDSII`/`LEF`/`DEF`/`SPICE`, `FLAC`/`WAV`/`MiniSEED`/`EDF+`/`ITCH`, `CSV`/`JSONL`, mainframe `FB`/`VB`), streaming CDC ingress and typed COPY/import/export |
| 19 | [Interactive 3D worlds, game asset pipelines and simulation streaming](19-game-asset-pipelines-and-simulation-streaming.md) | Planned | Orthogonal $\tau \perp \kappa_{\text{asset}} \perp \epsilon$ game/simulation/signal assets (`TEXTURE2D`/`3D`/`CUBEMAP`, `VOLUME_GRID`, `SPLAT3D`, `SKELETON3D`, `ANIMATION_CLIP`, `MATERIAL`, `SHADER_VARIANT`, `WAVEFORM`, `AUDIO_CUE`, `NAVMESH`), virtualized `.mesh_cluster_dag` micropolygon DAGs, `.tex_mip_morton` `BCn`/`ASTC`/`KTX2` virtual texture pyramids, `.vdb_hierarchy` (staggered MAC/AMR/LBM grids) & `.splat_hilbert` codecs, `.skin_weights` & `.anim_acl` pose evaluation, `.wave_lpc_pyramid` audio/waveform envelopes + SIMD spectral/convolution DSP (`DSP_STFT`/`DSP_ConvolveIR`) & qualified gated `LUFS` loudness, WAL-activated Derived Data Cache (DDC) cooking, incremental DBSP `NavMesh` & `HLOD` maintenance, Eulerian/Lagrangian fluid & molecular dynamics (`ST_Gradient`/`ST_Divergence`/`ST_Curl`/`ST_QCriterion`/`ST_IsoSurface`/`ST_Streamlines`, $2h$ Hilbert SPH/MD sweeps, DBSP control-volume conservation & Lift/Drag integrals), and ECS archetype / frustum / progressive `.float_zfp` AoI streaming under fog-of-war Spatial RLS |
| 20 | [Branches, merges and restore](20-branches-merges-and-restore.md) | In Progress ([immutable Table increment](20-branches-merges-and-restore.md#local-table-branch-increment); broader plan remains open) | Durable multi-commit branches, 2-way/3-way `DIFF` & `DIFF_SCHEMA` over `.tseg` segment/spatial skipping and 5-state `IS CONFLICT` cells, Git-like remote $\leftrightarrow$ local incremental mirroring (`REMOTE`/`FETCH`/`MIRROR`), logical three-way merge with `FOREIGN KEY`/`CHECK` verification, branch-aware compaction/GC and forward restore under current authority |
| 21 | [Service and SDK coverage](21-service-and-sdk-coverage.md) | In Progress | Preserved Go raw/console slices and broader service, language, type and platform coverage over the shared API foundation |
| 22 | [Formal semantics and implementation correspondence](22-formal-semantics-and-correspondence.md) | In Progress | Selected temporal models (including `T8` DDL evolution and 5-state dataflow lifecycle) and algebraic proofs over delivered local contracts, connected to production behavior before distributed extensions |

### Phase III: Distributed durability and operations

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 23 | [Storage providers and concurrent-writer qualification](23-storage-providers-and-concurrency.md) | Planned | Real provider/cache profiles, KMS/BYOK envelope encryption at rest, enforceable partitioned authority and distributed fine-grained concurrent-writer qualification |
| 24 | [Replication and durable failover](24-replication-and-failover.md) | Planned | Complete replicated history, transaction decisions and objects, bounded catch-up and fenced failover |
| 25 | [Operations, backup, restore and upgrades](25-operations-and-recovery.md) | Planned | Verified transaction-consistent backups/PITR, authority-safe disaster recovery, upgrades and operational workflows |
| 26 | [Clustered execution and storage-disaggregated placement](26-clustered-execution.md) | Planned | Fenced placement changes and distributed queries preserving qualified transaction, replication and operational contracts |

### Phase IV: Governed collaboration and Board

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 27 | [Enterprise identity and the Control & Policy Plane](27-control-and-policy-plane.md) | In Progress ([implementation plan](27-control-and-policy-plane.md#implementation-plan--2026-10-30); [delivered evidence](27-control-and-policy-plane.md#delivered-implementation-evidence--2026-10-30)) | Trusted enterprise identity, declarative `SECRET` catalog (`CREATE SECRET` / `USAGE ON SECRET`) & OAuth2/PKCE challenge-response dataflows, security-barrier RLS (including spatial RLS), dynamic column masking, GDPR crypto-shredding/purge, Hierarchical Workload Management (WLM) and shared branch/publication policy |
| 28 | [Published business resources and consistent investigations](28-published-resources-and-investigations.md) | In Progress ([implementation plan](28-published-resources-and-investigations.md#implementation-plan--2026-10-30); [delivered evidence](28-published-resources-and-investigations.md#delivered-implementation-evidence--2026-10-30)) | Deliberate resource exposure, disclosure policy and retained multi-call investigation bases |
| 29 | [Versioned proposals and reviewed publication](29-reviewed-data-collaboration.md) | Planned | Comparable branch proposals, branching-only policy and exact reviewed publication |
| 30 | [Board reimplementation and data-first workbench](30-board-reimplementation.md#initial-pass-implementation-plan) | In Progress | Initial implementation: catalog, bounded previews and session workbooks over public Transit/result APIs; full scope adds durable workbooks, spatial/map and layout layer inspection, lineage and governed changes with preserved operational inspection |

### Phase V: Agents and mixed application composition

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 31 | [MCP service and interactive Apps](31-mcp-service-and-apps.md) | Planned | Authenticated agent access and optional Apps over shared published capabilities |
| 32 | [Reactive context, subscriptions and agent activation](32-reactive-context-and-agent-activation.md) | Planned | Meaningful change conditions, durable interests and governed version-bound hybrid context through subscriptions/tasks |
| 33 | [Recorded outbound MCP and application guidance](33-recorded-mcp-integrations.md) | Planned | Governed outbound MCP, captured observations, network-free replay and reviewed application guidance |
| 34 | [Language-native programming model and mixed application composition](34-programming-model.md) | Planned | Complete language-native direct, Station and mixed composition over the earlier client/transaction foundation |

### Phase VI: Scientific, media and evidence workloads

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 35 | [Scientific arrays, measurements and reproducible numerical computation](35-scientific-arrays-and-measurements.md) | Planned | Named-axis dense/sparse arrays, units/clocks/calibration, quality and numerical fidelity, dependency-aware kernels and attributable earth-observation/climate/scientific results |
| 36 | [Video and synchronized multimodal timelines](36-video-and-multimodal-timelines.md) | Planned | Versioned media tracks and alignment, bounded indexed decoding, source-bound annotations and authorized temporal inspection/export |
| 37 | [ML/AI features, model artifacts and reproducible experiments](37-ml-ai-and-experiment-provenance.md) | Planned | Knowledge-time-correct features, model/transform/run identities, attributable embeddings and predictions, bounded recovery and exact-basis evaluation/publication |
| 38 | [Robotics, industrial sensing and calibrated replay](38-robotics-and-sensor-replay.md) | Planned | Clock/frame/calibration-aware sensor capture, MCAP/ROS profiles, bounded synchronized replay and candidate evaluation with physical actuation separately authorized |
| 39 | [Software, build and deployment evidence](39-software-build-and-deployment-evidence.md) | Planned | Exact source/dependency/build/test/artifact/deployment evidence, bounded impact queries and candidate checks, with a scoped Spoke Platform integration handoff |
| 40 | [Constrained planning and attributable optimization](40-constrained-planning-and-optimization.md) | Planned | Frozen problems, feasible/optimal/infeasible/unknown outcomes, verified candidates and bounds, bounded solver recovery and reviewed plan publication |

### Phase VII: Qualification and release

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 41 | [SQL grammar, standards comparison and dialect ergonomics](41-sql-grammar-and-dialect-ergonomics.md) | Planned | Cross-dialect SQL grammar comparison against ISO SQL:2023, ISO SQL/MM Spatial and industry dialects (PostgreSQL/PostGIS, DuckDB, Snowflake/Delta, Dolt, ClickHouse, GoogleSQL, Materialize/Flink), compile-time ergonomic desugarings (`FROM`-first queries, `SELECT * EXCLUDE/REPLACE`, `GROUP BY ALL`, `ORDER BY ALL`, trailing commas), 2-way/3-way `DIFF` & `DIFF_SCHEMA`, standardized 5-state dataflow lifecycle DDL (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`) and actionable dialect diagnostics |
| 42 | [Qualification and complete benchmarks](42-qualification-and-benchmarks.md) | Planned | Combined common-revision workload/fault evidence, full benchmarks and measured CI costs |
| 43 | [Release distribution](43-releases.md) | In Progress | Versioned verified artifacts, matching documentation and runnable installed onboarding |
| 44 | [Declarative language, structural context and corpus-native synthesis research](44-declarative-language-context-and-synthesis.md) | Planned | Speculative research defining declarative span segmentation, multi-scale structural/graph proximity (`NEAR`), context-conditioned continuation and branch-verified agency over swappable physical index and predictor implementations |

Performance measurement and amplification work remains tracked in
[issue #76](https://github.com/spoke-sh/transit/issues/76), alongside the reopened
milestone trackers above.
The [allocation-guidance implementation plan](13-data-structures-and-performance.md#implementation-plan-for-issue-194)
tracks [issue #194](https://github.com/spoke-sh/transit/issues/194), starting with
reusable result delivery and extending zero allocations after warmup through
storage, query execution, strings/search and compilation in milestones 13–15.
Standards, multi-model and branching work is tracked in
[issue #31](https://github.com/spoke-sh/transit/issues/31).

## Delivery checkpoints

This is the execution plan within the [delivery phases](#delivery-phases). Work
within a checkpoint may overlap when shared contracts are settled; implementation
and acceptance retain the numbered owners.
Resolve contract dependencies before code, and close delivery against executable
evidence rather than assuming every preceding number is a technical dependency.

| Phase | Checkpoint | Owners | Concrete execution and exit gate |
| --- | --- | --- | --- |
| I | Define identities and commit truth | 1; #125/#111/#112 | Resolve atomic domains/isolation, snapshot/WAL roots, publication decisions, native owners (#126), feeds/pins (#127), layouts/codecs (#128/#118), provider trust (#117/#121) and current-v1 migration before dependent formats |
| I | Establish the local system | 2–3; #113–#116/#119/#120/#122/#124 | Qualify local disk storage, complete native persistence, direct Table and named resource/computation lifecycles; prove installed WAL-only commits, controlled flush, bounded reads and exact restart recovery without Ursula/MinIO |
| I | Deliver statement and transaction experiences | 4–5 | Shared result lifecycle first; then supported multi-object transactions, consistent reads, savepoints, isolation/decision evidence and outbox recovery. Design provisional results and commit attribution together |
| I | Decouple the database, deliver declarative streams/queues and re-architect the durable runtime | 6 | Remove `Station` actor turns (`AccountRuntime`/`Ledger`) from `transit-sql`, deliver first-class `STREAM` (`PRODUCE INTO` / `CONSUME ... FROM`) and `QUEUE` (`ENQUEUE INTO` / `CLAIM ... FROM` / `ACK` / `NACK`) catalog primitives over `TransitLog`/`.tseg` with Roaring-bitmap ack vectors and hierarchical timer wheels, and re-architect `Station` behaviors and connector queues over those database primitives and Milestone 5 transactions |
| I | Decouple `Document` from `Station` into `.tseg` logical storage | 7 | Replace `STATION_DOCUMENT_V1`/`SIX1` actor-turn storage with `DocumentPartition` over `TransitLog` (`TWAL1`) and `.tseg` succinct trees ($2N$-bit `BP`), adaptive columnar path shredding, 5-state cell provenance, transaction participation and pluggable versioned/CRDT merge profiles |
| I | Formalize gateway architecture, sans-I/O wire protocols and direct-plane ingress | 8 | Co-host `DatabaseRuntime` and SQL/Flight/Serving ingress with the Direct Data Plane in `transit server`/`transit-node` (or 1-hop server-side execution in standalone gateway mode), replace `2–100 ms` `runAccount` and `100 ms` `recoverSessions` polling with event-driven recovery, enforce pure sans-I/O wire-protocol state machines (`transit-postgres`, `transit-mysql`, `TSR1`), replace per-command `std.Io.Select` timer tasks with socket `operateTimeout` deadlines and core-bounded thread pools, and split `gateway.py` into sans-I/O unit checks and focused driver suites |
| I | Establish the application API foundation | 9 | Extract shared data packages, compose bounded client/host infrastructure and qualify representative installed language APIs with original-operation recovery before SDK expansion |
| I | Retain exact data interpretation | 10 | Qualify historical catalog/data bindings, declarative `CHECK`/`FOREIGN KEY` constraints, lazy `.tseg` schema projection, collation and encoding fidelity, current permissions and explicit capability evidence over the earlier snapshot contracts |
| I | Declare and maintain indexes | 11 | Qualify ordered, covering and partial access, fine-grained key-range SSI conflict tracking, index-backed `FOREIGN KEY` enforcement, online index/table build recovery and snapshot-specific coverage through shared callers |
| II | Maintain declared computations | 12 | Qualify complete analytical SQL (windows, CTEs, universal `D-Join` subquery unnesting, multi-way joins, sandboxed UDFs), bitemporal `AS OF JOIN`, `CHANGES(...)` CDC egress, service-owned activation, complete-commit change consumption, bounded operator state and recovered completed revisions |
| II | Optimize database and runtime work | 13 | Establish workload/competitor baselines and numeric budgets, deliver zero-steady-state-allocation hot-path arenas, per-morsel CPU/memory/IOPS metering, LeanStore/Umbra swizzled zero-copy buffer slabs, CedarDB ~10-instruction directory-tagged join hash tables & WCOJ, statistics/planning, partitioning/clustering keys, LSM/`.tseg` compaction bounds and scan-resistant caching, and pass installed correctness/resource/performance gates |
| II | Deliver first-class strings, perfect hashing and vectorized search | 14 | Qualify 16B collation-prefixed Umbra/German strings, compressed-domain `.dictionary`/`.fsst` predicates, `comptime`/immutable perfect hashing with 16B SIMD string comparisons, and declarative text/proximity search contracts over swappable `.tseg` index profiles (starting with vectorized 256-doc Block-Max BM25 and hybrid search) |
| II | Deliver data-centric compilation, AOT queries and specialization | 15 | Qualify HyPer/CedarDB data-centric push fusion inside vectorized morsels, per-row-group dense non-null specialization, Flying-Start Adaptive Morsel Tier-Up and `transit-app` AOT Zig query/view compilation against HyPer/Umbra/CedarDB (VLDB 2018, JOB and CH-benCHmark) baselines |
| II | Deliver the Document Type Library and gateway exchange lifecycle | 16 | Qualify declarative Document Profiles (`JSON`, `XML`, `HTTP`/`MIME`, `FTP`, `EDI_X12`/`EDIFACT`/`HL7`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`, `AMQP`, `MQTT`, `NTP`) and compound formats (`PDF`, `DOCX`, `XLSX`, `ODF`) over shared SIMD structural scanners, perfect hash vocabularies, container part graphs and `.tseg` subcolumns, and cut `STATION_EXCHANGE_V1` connector/gateway capture over to `DocumentPartition` with causal lineage and transport decoupling |
| II | Deliver geospatial types, topological compression and incremental spatio-temporal queries | 17 | Qualify $\tau \perp \kappa_{\text{spatial}} \perp \epsilon$ (`GEOMETRY`, `GEOGRAPHY`, `MESH3D`, `SOLID3D`, `SCENE3D`, `TRANSFORM3D`, `POINTCLOUD`, `RASTER2D`/`GRID3D`, `COCHAIN_FIELD`, `BBOX2D`/`3D`, `S2_CELL`, `H3_CELL`, `OCT_CELL`, `TRAJECTORY`), Shewchuk exact 2D/3D predicates and snap-rounding grids, 16B inline MBR vector headers, `.geoarrow`/`.twkb_delta`/`.mesh_edgebreaker`/`.raster_morton`/`.float_zfp` codecs, logical topological shared-arc/face (`.topo_arc`, `.topo_face` + $C^0..C^3$ cochains), `INTERIOR`/`BOUNDARY` `S2`/`H3`/`OCT` Roaring cell/octree coverings, `.scene_dag`, `.pcloud_hilbert` and 4D/6-DoF trajectory compression, 2D/3D zone maps, `RTREE`/`S2`/`OCTREE` indexes, 2D/3D spatial SSI and DBSP Z-set incremental `ST_Union`, `ST_3DUnion`, linear volume/flux aggregates and 2D/3D clash joins |
| II | Compose multi-model relations, game asset pipelines, simulation streaming and history | 18–20 | Qualify foreign COPY/projections (`GeoParquet`, `FlatGeobuf`, `COG`, `glTF`/`OpenUSD`/`KTX2`/`OpenVDB`/`IFC`/`STEP`/`3D Tiles`/`COPC`/`CGNS`/`VTU`/`OpenFOAM`/`Zarr`/`NetCDF`), streaming CDC ingress, multi-model lexical/structural/vector/2D-3D-spatial search composition, virtualized `.mesh_cluster_dag` meshlets, `.tex_mip_morton` virtual texture pyramids, `.skin_weights`/`.anim_acl` skeletal animation, WAL-activated DDC cooking, incremental DBSP `NavMesh`/`HLOD` maintenance, CFD differential/isosurface/streamline operators & DBSP conservation/Lift-Drag audits, ECS archetype & frustum AoI streaming, multi-commit branches, branch-aware compaction/GC and conditional forward publication with `FOREIGN KEY`/uniqueness/constraint evidence and measured costs |
| II | Expand qualified interfaces | 21 | Extend the language/service/platform matrix over the existing foundation; preserve delivered Go raw and console evidence and reject unsupported transaction/feed profiles |
| II | Establish formal semantics and correspondence | 22 | Select settled local contracts, execute temporal/algebraic checks with implementation replay or independent fixtures, challenge them with negative controls and assign later extensions |
| III | Qualify distributed infrastructure | 23–26 | Real providers, KMS/BYOK envelope encryption at rest and writer fencing/fine-grained distributed SSI, then replication, backup/PITR/upgrade procedures and automatic placement/distributed queries; repeat transaction and native-owner recovery across each failure profile |
| IV | Establish governed collaboration contracts | 27–29 | Enterprise identity, security-barrier RLS (including spatial RLS), dynamic column masking, GDPR crypto-shredding/purge, Hierarchical Workload Management (WLM), published resources/investigations and exact reviewed publication through independently usable public owners |
| IV | Reimplement the Board workbench | 30 | Deliver the installed data-first interface, bounded profiles/workbooks/spatial-map/lineage views and separately authorized change review; preserve operational inspection and prove real browser/recovery journeys |
| V | Extend agent-host interfaces and activation | 31–33 | MCP/Apps, reactive context and recorded outbound MCP over shared owners; no dependency on Board's frontend or configured credential |
| V | Prove complete application composition | 34 | Installed direct, Station and all mixed capabilities in every claimed language; transaction/turn/checkpoint/effect boundaries and recovery remain explicit |
| VI | Establish scientific measurement and computation contracts | 35 | Qualify named axes, units, clocks, calibration, quality, numerical error and sparse/dense tiled execution; prove conservative pruning and incremental/finite agreement on earth-observation and calibrated-sensor journeys |
| VI | Deliver media, ML/AI and robotics lifecycles | 36–38 | Qualify indexed video/timeline disclosure, exact model/input/evaluation attribution and synchronized sensor replay; exercise gaps, corrections, bounded work, restart and revocation without replaying physical effects |
| VI | Connect evidence to reviewed plans | 39–40 | Qualify source-to-deployment evidence and Platform exchange boundaries, then constrained candidate outcomes/bounds, original-operation recovery and exact reviewed publication separately from external execution |
| VII | Harmonize SQL grammar, standards and dialect ergonomics | 41 | Audit the complete SQL grammar against ISO SQL:2023, ISO SQL/MM Spatial and industry dialects (PostgreSQL/PostGIS, DuckDB, Snowflake, ClickHouse, GoogleSQL, Materialize/Flink), qualify compile-time ergonomic desugarings (`FROM`-first queries, `SELECT * EXCLUDE/REPLACE`, `GROUP BY ALL`, `ORDER BY ALL`, trailing commas, numeric underscores) to canonical `FQP1`/`FDM1` plan bytes, standardize 5-state dataflow lifecycle DDL (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`) and verify actionable foreign-dialect diagnostics before freezing 1.0 qualification |
| VII | Qualify and distribute one revision | 42–43 | Compose workload/fault/performance evidence at one committed revision, then immutable artifacts, matching docs and installed onboarding. Focused correctness gates remain mandatory earlier |
| VII | Explore declarative language, structural context and synthesis | 44 | Speculative post-release research: define declarative span segmentation, multi-scale `NEAR` proximity maps, context-conditioned continuation and branch-verified agency against scalar reference oracles before selecting physical structures |

Track first-three-milestone acceptance and explicitly transferred scope through
#108/#109/#110 and the component issues. Update tracker ownership and links with
this sequence; retain original diagnoses, delivered evidence and incomplete
checks. #123 corrects current documentation as implementation changes, and #124
owns traceable installed acceptance. No planning edit changes their runtime status.

## Scientific, media and evidence workload expansion — 2026-11-01

Add six independently reviewable milestones after the common application
foundation and before combined qualification. Each is Planned and defines its
own contract, caller journey, resource bounds and recovery/disclosure evidence.
Earlier delivered scope and unfinished gates are preserved. The existing audio,
biology, EDA, medical-imaging and simulation plans remain with M14/M17–M19;
new shared contracts generalize their interpretation and computation boundaries.

| Shared concern | Owning extension | Consumer obligations |
| --- | --- | --- |
| Measurement interpretation and numerical fidelity | [M35](35-scientific-arrays-and-measurements.md) | Preserve units, named axes, clock/frame/calibration revisions, quality separate from five-state interpretation, and conservative error bounds |
| Computation dependencies and derivation | [M12](12-sql-and-dataflows.md) lifecycle; [M35](35-scientific-arrays-and-measurements.md) numerical/window/halo/frontier profiles | Bind exact source basis, executable/model/parameters, retained artifacts and complete output; qualify incremental updates or bounded recomputation |
| Synchronized media | [M36](36-video-and-multimodal-timelines.md) | Preserve frame/sample/byte coordinates, decode dependencies, uncertainty and current authorization across metadata, previews and exports |
| Model and experiment attribution | [M37](37-ml-ai-and-experiment-provenance.md) | Prevent future-knowledge leakage, distinguish predicted from observed evidence, bind model/transform/evaluation versions and keep application policy above Transit |
| Sensor episodes and replay | [M38](38-robotics-and-sensor-replay.md) | Preserve gaps, clock/calibration changes and replay progress; require separate authority and qualification for physical actions |
| Software evidence and Platform exchange | [M39](39-software-build-and-deployment-evidence.md) | Bind exact source/build/test/artifact/deployment identities, preserve incomplete evidence and leave hosting/product policy with Platform |
| Constrained planning | [M40](40-constrained-planning-and-optimization.md) | Distinguish feasible, optimal, infeasible and unknown search, retain bounds/tolerances and review exact candidates separately from effects |

The first cross-domain demonstrator is calibrated sensor replay: capture raw
samples and a camera interval, bind calibration, derive features, inspect an
event, revise calibration on a branch and identify changed results. Reopen the
original basis after restart, revoke access during disclosure and prove replay
sends no device command. M35 supplies the numerical slice; M36 and M38 qualify
the complete synchronized journey. Software evidence can progress independently
of video/robotics kernels once its explicit prerequisites are qualified.

Phase VI does not require every earlier numbered milestone as an implicit
technical dependency. Owners can settle contracts and deliver independent slices
as their actual prerequisites become executable. Existing minimum authorization,
bounded work and recovery requirements remain gates in every phase.

This insertion moves the former M35 grammar, M36 qualification, M37 release and
M38 synthesis-research owners to M41, M42, M43 and M44 respectively. Phase VII
retains their statuses and obligations. The post-release synthesis research is
separate from M37's concrete model/feature/experiment lifecycle. No planning edit
establishes implemented support, new benchmark results or Platform readiness.

## Interactive 3D worlds, game asset pipelines and simulation streaming review — 2026-11-01

A review of game-engine asset storage and real-time simulation streaming against
[Milestone 17](17-geospatial-and-spatio-temporal-computing.md),
[Milestone 18](18-multi-model-and-foreign-relations.md),
[Milestone 12](12-sql-and-dataflows.md),
[Milestone 13](13-data-structures-and-performance.md) and
[Milestone 20](20-branches-merges-and-restore.md) identifies that while
[Milestone 17](17-geospatial-and-spatio-temporal-computing.md) establishes the
computational-geometry, topological-compression (`.topo_arc`, `.topo_face`,
`.mesh_edgebreaker`, `.octree_roaring`), rigid-body `.scene_dag`, 2D/3D tiled
raster (`.raster_morton`) and DBSP spatial foundation, 75–85% of a modern game
or simulation engine's asset pipeline and runtime activation involves
non-geometric or deformable assets, target-profile cooking caches and
frame-budgeted Area-of-Interest (AoI) streaming. Inserting
[Milestone 19](19-game-asset-pipelines-and-simulation-streaming.md) in Phase II
(after [Milestone 18](18-multi-model-and-foreign-relations.md) and before
[Milestone 20](20-branches-merges-and-restore.md)) shifts the sequence to
`1–38` and establishes six architectural commitments:

1. **Orthogonal $\tau \perp \kappa_{\text{asset}} \perp \epsilon$ game and simulation asset codecs (`.mesh_cluster_dag`, `.tex_mip_morton`, `.vdb_hierarchy`, `.splat_hilbert`, `.skin_weights`, `.anim_acl`):**
   Separate logical asset types (`MESH3D`, `TEXTURE2D`/`3D`/`CUBEMAP`,
   `VOLUME_GRID`, `SPLAT3D`, `SKELETON3D`, `ANIMATION_CLIP`, `MATERIAL`,
   `SHADER_VARIANT`, `AUDIO_CUE`, `NAVMESH`) and target profile rules
   ($\kappa_{\text{asset}}$: color space, sampler rules, hardware block-compression
   target `BC1`–`BC7`/`ASTC`/`KTX2`, screen-space error $\varepsilon_{\text{px}}$
   and agent locomotion clearance $\kappa_{\text{nav}}$) from `.tseg` physical
   layouts: Nanite-style 64–128-triangle **meshlet cluster DAGs**
   (`.mesh_cluster_dag`) with locked group boundaries and normal cones;
   **block-compressed texture mip chains** (`.tex_mip_morton`) with inline
   resident mip tails and 64 KiB 2D/3D Morton-ordered Virtual Texture tiles;
   **sparse 3D voxel grids** (`.vdb_hierarchy`) and **3D Gaussian Splats**
   (`.splat_hilbert`); and **deformable skeletal skinning weights**
   (`.skin_weights`) paired with **ACL-style block-compressed animation clips**
   (`.anim_acl`) and vectorized pose evaluation (`ST_EvaluatePose`,
   `ST_SkinnedBBox3D`).
2. **Transactional Derived Data Cache (DDC) and target-profile asset cooking over WAL-activated DBSP dataflows ([Milestone 12](12-sql-and-dataflows.md), [Milestone 19](19-game-asset-pipelines-and-simulation-streaming.md), [Milestone 20](20-branches-merges-and-restore.md)):**
   Replace external asset build servers and bespoke content-addressed stores
   (such as Unreal Zen Storage Server / `.utoc`+`.ucas`) with deterministic
   `TransitLog`-activated managed computations keyed by
   `(DefinitionId, SnapshotId, TargetPlatformProfile)` that cook source meshes,
   textures, `DocumentPartition` material/shader graphs and level edits into
   `.mesh_cluster_dag` pages, `.tex_mip_morton` tiles, compiled shader bytecode
   (`SPIR-V`, `DXIL`, `MSL`, `WGSL`) and per-`OCT_CELL` `HLOD` proxy meshes in
   `.tseg`, shared in $O(1)$ across branches and hydrated lazily on demand via
   `REMOTE`/`FETCH`.
3. **Incremental DBSP Navigation Mesh (`NavMesh`) and volumetric clearance maintenance:**
   Express walkable `NavMesh` surfaces (`.nav_topo`) and their dual portal
   graphs as algebraic DBSP Z-set views over
   [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md) `.topo_face`
   2-chains and `.octree_roaring` obstacle coverings so inserting, moving or
   retracting static geometry or dynamic obstacles updates only the touched
   `OCT_CELL` tiles in $O(|\Delta \text{octants}|)$.
4. **Columnar ECS archetype tables, Prefab prototype inheritance and Fog-of-War Spatial AoI streaming:**
   Map Entity-Component-System (ECS) archetype tables directly onto
   64-byte-aligned `TablePartition` (`.tseg`) vectors with `LIVRPS`-style
   sparse prefab overrides (`ECS_RESOLVE`), stream crack-free `.mesh_cluster_dag`
   cuts, `.tex_mip_morton` virtual texture tiles, progressive `.float_zfp`
   bitplanes and dead-reckoned `TRAJECTORY`
   entity deltas over [Milestone 8](08-gateway-architecture-and-protocol-ingress.md)
   Arrow Flight and [Milestone 32](32-reactive-context-and-agent-activation.md)
   reactive subscriptions directly from swizzled `NvmeCache` slabs, and enforce
   fog-of-war / anti-cheat visibility at the storage/query security barrier via
   [Milestone 27's](27-control-and-policy-plane.md) 3D Spatial RLS.
5. **Topology-decoupled Discrete Exterior Calculus (DEC) / Finite-Volume cochain fields (`COCHAIN_FIELD`), error-bounded bitplane float compression (`.float_zfp`) and continuum / fluid simulation streaming ([Milestone 17](17-geospatial-and-spatio-temporal-computing.md), [Milestone 18](18-multi-model-and-foreign-relations.md), [Milestone 19](19-game-asset-pipelines-and-simulation-streaming.md)):**
   Bind time-series continuum fields (`COCHAIN_FIELD` over $C^0$ nodal potentials,
   $C^1$ edge circulations, $C^2$ oriented face fluxes $\Phi_f$ and $C^3$
   conserved cell averages $\rho, \rho\vec{u}, E, p$) to a cataloged `.topo_face`
   or `OCT_CELL` mesh `DefinitionId` (permuted by `HILBERT_3D` or Reverse
   Cuthill–McKee `RCM` so $>90\%$ of interior faces share an L1d/L2 cache morsel
   between `owner[f]` and `neighbour[f]`) without duplicating mesh geometry across
   timesteps, and compress continuous fields with **`.float_zfp`** ($4^d$
   decorrelating lifting transform + progressive bitplanes under
   $\kappa_{\text{numeric}}$ with conservation-preserving block headers). Support
   foreign `CGNS`, `VTK`/`VTU`/`VTI`/`PVD`, OpenFOAM `polyMesh`, `Zarr v3`,
   `NetCDF-4`/`HDF5` and `GRIB2` datasets in
   [Milestone 18](18-multi-model-and-foreign-relations.md), and deliver staggered
   MAC / 2:1 AMR / `D3Q19`–`D3Q27` LBM grids, $2h$ Hilbert SPH particle neighbor
   sweeps, fused face-sweep `ST_Gradient` / `ST_Divergence` / `ST_Curl` /
   `ST_QCriterion` / `ST_IsoSurface` / `ST_Streamlines` kernels, incremental DBSP
   control-volume conservation residuals ($(+\Phi_f) + (-\Phi_f) = 0$) and wall
   Lift/Drag force integrals, and 5-state `IS TYPE_ERROR` CFL/divergence blowup
   diagnostics in [Milestone 19](19-game-asset-pipelines-and-simulation-streaming.md).
6. **Computational biology, genomics, structural proteomics, cheminformatics, audio/acoustic wave DSP, medical imaging and 2.5D EDA/VLSI chip layouts ([Milestone 12](12-sql-and-dataflows.md), [Milestone 14](14-vectorized-strings-and-search.md), [Milestone 17](17-geospatial-and-spatio-temporal-computing.md), [Milestone 18](18-multi-model-and-foreign-relations.md), [Milestone 19](19-game-asset-pipelines-and-simulation-streaming.md)):**
   Extend the same orthogonal $\tau \perp \kappa \perp \epsilon$ and DBSP Z-set
   foundations across scientific and signal workloads:
   - *Genomics, Proteomics, Cheminformatics & Single-Cell Atlases:* add `BIO_SEQ`
     (`.seq_2bit` and reference-compressed `.cram_ref_delta` bound to
     $\kappa_{\text{genome}}$), succinct FM-Index / Run-Length BWT (`.fm_bwt`) and
     $(w, k)$-minimizer Roaring indexes with SIMD Wavefront Alignment (`WFA`),
     biobank cohort Positional BWT (`.geno_pbwt` mapping `./.` to 5-state
     `IS MISSING`), `MOLECULE` (`.mol_graph` + 2048-bit Morgan/ECFP substructure
     bitvectors), 3D atomic/MD conformations (`.pcloud_hilbert` at $10^{-3}\,\text{Å}$ +
     `.octree_roaring` Solvent-Accessible Surface Area `SASA`), and `.sparse_bcsr`
     single-cell matrices (`FASTQ`, `BAM`/`CRAM`, `VCF`/`BCF`, `BED`/`GFF3`,
     `PDB`/`mmCIF`, `SMILES`/`SDF`, `.h5ad`).
   - *Audio, 3D Room/Wave Acoustics & High-Rate Signal DSP:* add `WAVEFORM` with
     `.wave_lpc_pyramid` (lossless `LPC` + Rice residuals or `.float_zfp` blocks
     with inline multi-resolution `(min_peak, max_peak, rms_energy, zero_crossing_rate, clipping_bitmap)`
     zone maps for $O(1)$ zero-decode timeline rendering and silence skipping),
     `.audio_fingerprint` spectral constellation hashes, SIMD `DSP_FFT` /
     `DSP_STFT` / `DSP_MelSpectrogram` / `DSP_ConvolveIR`, 3D `.topo_face` +
     `MAC_GRID` room acoustics, and incremental DBSP `ITU-R BS.1770` `LUFS`
     loudness metering.
   - *2.5D VLSI/EDA Chip Layouts, Medical Imaging & Order-Book Z-Sets:* add
     `.layout_manhattan` ($D_4$ dihedral symmetries and `(nx, ny, dx, dy)` cell
     arrays over `.scene_dag` + `.topo_arc` for incremental DBSP `DRC`/`LVS` on
     `OASIS`/`GDSII`/`LEF`/`DEF`/`SPICE`), `DICOM`/`NIfTI`/`OME-Zarr` medical
     volume projections under [Milestone 27](27-control-and-policy-plane.md)
     HIPAA/GDPR security-barrier RLS and dynamic PHI masking, and linear DBSP
     Z-set Limit-Order-Book (`LOB`) depth maintenance in
     [Milestone 12](12-sql-and-dataflows.md).

## Geospatial computing, 3D volumetric models, logical topological compression and companion data-type formalization review — 2026-10-29

An architectural review of 2D/3D geospatial, volumetric 3D model and
spatio-temporal computing across
[`types.md`](../handbook/reference/sql/types.md),
[`query-engine.md`](../handbook/internals/query-engine.md),
[Milestone 10](10-standards-and-catalogs.md),
[Milestone 11](11-indexing-and-access-paths.md),
[Milestone 12](12-sql-and-dataflows.md),
[Milestone 13](13-data-structures-and-performance.md),
[Milestone 14](14-vectorized-strings-and-search.md) and
[Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)
identifies why 2D/3D spatial data behaves like a graded **Cellular Chain Complex
($C_0, C_1, C_2, C_3$)** with boundary operators $\partial_k: C_k \to C_{k-1}$
satisfying $\partial_{k-1} \circ \partial_k = 0$ (planar subdivisions as DCELs
over $(C_0, C_1, C_2)$, 3D manifold meshes and B-Rep solids over
$(C_0, C_1, C_2, C_3)$ with coboundary $\delta_2 = \partial_3^\top$ room/part
adjacency graphs, discrete grids/octrees `S2`/`H3`/`OCT_CELL` as hierarchical
trees and $k$-regular neighbor graphs, and spatial/3D clash joins as bipartite
intersection graphs) while requiring explicit manifold, metric and
topological-robustness guarantees. Inserting
[Milestone 17](17-geospatial-and-spatio-temporal-computing.md) in Phase II
(after [Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)
and before [Milestone 18](18-multi-model-and-foreign-relations.md)) shifts the
sequence to `1–37` and establishes four architectural commitments:

1. **Formalize 2D & 3D Spatial Types ($\tau \perp \kappa_{\text{spatial}} \perp \epsilon$) alongside companion Range, Dense Vector, Decimal Arithmetic and Pinned-TZ Timestamp types ([Milestone 10](10-standards-and-catalogs.md), [Milestone 17](17-geospatial-and-spatio-temporal-computing.md)):**
   Separate logical 2D/3D spatial types ($\tau$: `GEOMETRY(subtype, srid, dim)`,
   `GEOGRAPHY(subtype, srid, dim)`, `MESH3D`, `SOLID3D`, `SCENE3D`,
   `TRANSFORM3D`, `POINTCLOUD`, `BBOX2D`/`BBOX3D`, `S2_CELL`, `H3_CELL`,
   `OCT_CELL`, `TRAJECTORY`) from the **Spatial Reference, Manifold & Precision
   Descriptor $\kappa_{\text{spatial}}$** (catalog-bound `SRID`, vertical
   datum / unit scale / axis convention `RightHanded_ZUp` vs. `YUp`, `PLANAR`
   vs. WGS84 `GEODESIC` edge interpolation, deterministic 2D/3D Snap-Rounding
   Grid $\delta_{\text{grid}}$ backed by Shewchuk adaptive-precision
   `orient2d` / `orient3d` / `incircle` / `insphere` predicates, and
   `S2_HILBERT` / `H3` / `HILBERT_3D` space-filling curve ordering) and `.tseg`
   physical codecs ($\epsilon$: `.geoarrow` Struct-of-Arrays, `.twkb_delta`
   quantized varints, `.mesh_edgebreaker` $<2\text{ bpt}$ `BP`/`CLERS` + wavelet
   LOD pages, `.topo_arc` shared 1-chains, `.topo_face` shared 2-faces,
   `.s2_roaring` / `.octree_roaring` coverings, `.scene_dag` prototype
   dictionaries + `SE(3)` instances and `.pcloud_hilbert` blocks). Formalize
   companion type families in the same
   [`FUZE_TYPES_V1.md`](../../contracts/FUZE_TYPES_V1.md) /
   [`TABLE_SCHEMA_V1.md`](../../contracts/TABLE_SCHEMA_V1.md) cutover:
   canonical **`RANGE<T>` and `MULTIRANGE<T>`** (the 1D base case of `BBOX` and
   cell coverings, unified with [Milestone 12's](12-sql-and-dataflows.md)
   `PERIOD FOR valid_time`), unboxed **`VECTOR(dim, elem_type)`** with
   $\kappa_{\text{metric}}$ (`L2_SQUARED`, `COSINE`, `DOT_PRODUCT`, `HAMMING`),
   deterministic **`DECIMAL(p, s)` arithmetic scale/rounding rules**
   ($\kappa_{\text{numeric}}$), and **`TIMESTAMPTZ` bound to a manifest-pinned
   IANA `tzdb` version digest** ($\kappa_{\text{tz}}$).
2. **Logical 2D & 3D compression in concert with the DBSP / Z-set incremental engine ([Milestone 12](12-sql-and-dataflows.md), [Milestone 17](17-geospatial-and-spatio-temporal-computing.md), [Milestone 22 A3](22-formal-semantics-and-correspondence.md#a3-incremental-dataflow-equivalence)):**
   Instead of storing isolated WKB or STL/OBJ triangle blobs that duplicate
   shared borders/faces and force $O(V \log V)$ or $O(F^2)$ full-recomputation
   on polygon/solid dissolve or streaming joins, combine five logical
   compression structures with DBSP Z-sets:
   - **Topological Shared-Arc (`.topo_arc`) & Shared-Face (`.topo_face`) Decomposition + Discrete Divergence Theorem $\implies$ Linear Z-Set `ST_Union`, `ST_3DUnion` & 3D Volume Aggregates:**
     store shared 1-chains (`[+e_1, -e_7]`) and shared oriented 2-faces
     (`[+f_1, -f_9]`) once per segment. Because adjacent 2D faces and 3D solids
     traverse shared internal boundaries in opposite orientations
     ($(+\vec{e}) + (-\vec{e}) = 0$, $(+\vec{f}) + (-\vec{f}) = 0$), incremental
     `ST_Union(geom)`, `ST_3DUnion(solid)` and `-row` retractions evaluate as
     linear Z-set sums over oriented boundaries, while `ST_Volume`,
     `ST_3DCentroid` and `ST_InertiaTensor` reduce to linear Abelian Z-set sums
     over boundary triangles via the Discrete Divergence Theorem
     ($\text{Volume}(V) = \frac{1}{6}\sum \text{orient3d}(0, p_1, p_2, p_3)$).
   - **Succinct Edgebreaker Mesh Connectivity & Wavelet LOD (`.mesh_edgebreaker`) $\implies$ $<2\text{ Bits/Triangle}$ + Progressive Streaming:**
     encode manifold 3D meshes via Rossignac Edgebreaker (`CLERS`) +
     [Milestone 7's](07-document-storage-and-station-decoupling.md) $2N$-bit
     `BP` succinct trees, parallelogram vertex prediction, octahedral normals
     and progressive `LOD_0..LOD_k` page prefixes.
   - **Hierarchical `INTERIOR` / `BOUNDARY` 2D Cell (`.s2_roaring`) & 3D Octree (`.octree_roaring`) Coverings $\implies$ $O(1)$ Short-Circuit Spatial Joins & 3D Clash Detection:**
     partition multi-resolution `S2`/`H3` and 64-bit `OCT_CELL` coverings into
     **`INTERIOR` cells/octants** (100% inside the polygon/solid, compressed
     into `.tseg` Roaring bitmaps with zero vertex/triangle storage) and
     **`BOUNDARY` cells/octants** (storing only the clipped local edge/triangle
     patch or quantized Dual-Contouring `SDF`). In finite and incremental
     bilinear spatial and 3D clash joins ($dA \bowtie B + A \bowtie dB + dA \bowtie dB$),
     any match on an `INTERIOR` cell/octant immediately returns `TRUE` in $O(1)$
     with zero narrow-phase floating-point math.
   - **Instanced Scene-Graph DAGs (`.scene_dag`) & Lie Group $SE(3)/\text{Sim}(3)$ Action $\implies$ Zero-Copy Kinematic Updates:**
     store canonical `MESH3D`/`SOLID3D` part prototypes once in a `.tseg`
     dictionary and represent assemblies as `(node_id, parent_id, prototype_id, transform_se3, world_bbox3d)`
     rows so articulating a part updates only its 48-byte `TRANSFORM3D` in
     `TWAL1` without copying mesh triangles.
   - **3D Hilbert Point Clouds (`.pcloud_hilbert`) & Dead-Reckoning Trajectory Tubes $\implies$ Sub-Byte Point Clouds & Semantic Delta Suppression:**
     cluster `POINTCLOUD` blocks by `HILBERT3D` with `BBOX3D` Frame-of-Reference
     (`FOR`) delta bitpacking, and compress colinear constant-velocity runs in
     `StreamPartition` within $\varepsilon$ into 4D/6-DoF `TRAJECTORY` segments,
     waking downstream continuous geofence and 3D zone dataflows only on
     cell/octant-boundary crossings or kinematic deflections.
3. **16-byte inline spatial headers in `Batch.zig`, 2D/3D zone maps and 2D/3D spatial SSI ([Milestone 11](11-indexing-and-access-paths.md), [Milestone 13](13-data-structures-and-performance.md), [Milestone 17](17-geospatial-and-spatio-temporal-computing.md)):**
   Equip `Fuze` vectors with a **16-byte Inline Spatial Header**
   (`[subtype_and_flags: u16][srid_id: u16][hilbert_s2_or_oct_prefix: u32][quantized_mbr_or_inline_xy: 8B]`)
   so 2D points stay inline and 2D/3D polylines, polygons, meshes and solids
   reject $>95\%$ of non-intersecting candidates in SIMD registers before
   touching `.geoarrow` or `.mesh_edgebreaker` buffers; add 2D/3D `.tseg`
   bounding-box zone maps (`BBOX2D`/`BBOX3D`), static 2D/3D Hilbert R-trees
   (`USING RTREE`), inverted `S2`/`H3`/`OCT_CELL` Roaring indexes (`USING S2` /
   `USING H3` / `USING OCTREE`), and **2D/3D bounding-box / Hilbert-interval
   Serializable Snapshot Isolation (SSI)** conflict tracking.
4. **Diffuse 2D/3D spatial and type guarantees across multi-model foreign formats, branches, security-barrier RLS, Board and formal proofs ([Milestones 16–34](16-document-profiles-and-gateway-exchange-lifecycle.md)):**
   Unify [Milestone 16's](16-document-profiles-and-gateway-exchange-lifecycle.md)
   `PDF` `(page_no, bbox, span)` layout boxes, `GeoJSON` and `GML`/`KML` with
   `BBOX2D` / `GEOMETRY`; add 2D (`GeoParquet` v1.1, `FlatGeobuf`, `GeoArrow`,
   `PMTiles`/`MVT`) and 3D (`glTF`/`GLB`, `OpenUSD`, `IFC`, `STEP`, `CityJSON`,
   `OGC 3D Tiles 1.1`, `LAS`/`LAZ`/`COPC`) foreign adapters, 3D coboundary dual
   graphs and Geo-/3D-Filtered Hybrid Search in
   [Milestone 18](18-multi-model-and-foreign-relations.md); add 2D/3D segment
   skipping and topological/clash `IS CONFLICT` cells in
   [Milestone 20](20-branches-merges-and-restore.md); extend Lean 4 pruning,
   codec and DBSP delta proofs (`A2`/`A3`/`A5`) in
   [Milestone 22](22-formal-semantics-and-correspondence.md); enforce 2D/3D
   Spatial RLS in [Milestone 27](27-control-and-policy-plane.md); render
   read-only 2D map, progressive-LOD 3D scene/mesh/point-cloud and `DIFF`/clash
   layers in [Milestone 30](30-board-reimplementation.md); and audit ISO SQL/MM
   Spatial (`ST_*` / `ST_3D*`) in
   [Milestone 41](41-sql-grammar-and-dialect-ergonomics.md).

## SQL grammar, standards comparison, dialect ergonomics and dataflow lifecycle review — 2026-10-29

A pre-release review of Transit's SQL grammar surface
([`grammar-surface.md`](../handbook/reference/sql/grammar-surface.md),
[`contracts/sql/README.md`](../../contracts/sql/README.md)), managed
computation lifecycle ([Milestone 12](12-sql-and-dataflows.md)), branching/diff
semantics ([Milestone 20](20-branches-merges-and-restore.md)) and formal
verification scope ([Milestone 22](22-formal-semantics-and-correspondence.md))
establishes four architectural refinements:

1. **Explicit five-state dataflow lifecycle (`Published`, `Authorized`, `Active`, `Suspended`, `Retired`), DDL and `T8` TLA+ formalization:**
   While ISO SQL:2023 defines no standard lifecycle grammar for continuous
   queries or materialized views—and vendor engines split between boolean trigger
   toggles (`ENABLE` / `DISABLE` in PostgreSQL/Oracle) and stateful compute
   controls (`SUSPEND` / `RESUME` / `REFRESH` in Snowflake Dynamic Tables and
   Tasks)—collapsing a stateful dataflow into a boolean `ENABLE` / `DISABLE` flag
   leaves authorization, checkpointed `TransitLog` (`TWAL1`) watermarks,
   snapshot-to-live handoffs and read behavior while paused ambiguous.
   [Milestone 12](12-sql-and-dataflows.md) now explicitly specifies the
   five-state computation lifecycle (`Published`, `Authorized`, `Active`,
   `Suspended`, `Retired`) and its DDL verbs (`ACTIVATE`, `SUSPEND`,
   `RESUME WITH (on_resume = 'replay_history' | 'recompute_snapshot')`,
   `REFRESH`, `RETIRE`), preserving checkpointed watermarks and serving the last
   completed revision with its frozen source basis while `Suspended`.
   [Milestone 22](22-formal-semantics-and-correspondence.md#t8-catalog-ddl-evolution-and-dataflow-lifecycle-state-machines)
   adds **`T8. Catalog DDL evolution and dataflow lifecycle state machines`
   (`DdlAndDataflowLifecycle.tla`)** to model and replay the interleaving of lazy
   and phased online DDL (`DefinitionId` transitions) with `Suspended`/`Active`
   dataflows, `_lease_epoch` worker fencing, `TWAL1` compaction and
   `policy_epoch` revocations.
2. **First-class relational and schema `DIFF` (`DIFF(...)` and `DIFF_SCHEMA(...)`) over `.tseg` segment skipping and 5-state `IS CONFLICT` cells:**
   Unlike ISO SQL `EXCEPT [ALL]` (one-way, primary-key blind and schema-rigid) or
   table-doubling diff functions (`from_<col>` / `to_<col>`),
   [Milestone 20](20-branches-merges-and-restore.md) and
   [Milestone 41](41-sql-grammar-and-dialect-ergonomics.md) define key-aligned
   two-way and three-way `DIFF(object, ...)` and `DIFF_SCHEMA(...)` table-valued
   functions that skip shared `.tseg` segments and `.tdel` bitmaps in $O(1)$
   ([`A4: BranchMergeAlgebra.lean`](22-formal-semantics-and-correspondence.md#a4-logical-merge-and-safe-segment-skipping)),
   project across column renames via stable `ColumnId` lineage, and surface
   three-way cell-level merge conflicts natively through Transit's five-state
   `conflict` tag (`WHERE col IS CONFLICT`).
3. **Git-like remote $\leftrightarrow$ local incremental mirroring, lazy `.tseg` hydration and branch proposal push ("Git remotes for data"):**
   Because committed state forms a content-addressed Merkle DAG (`manifest/v{N}`
   commits $\to$ `DefinitionId` catalog trees $\to$ immutable SHA-256 `.tseg`
   blobs and `.tdel`/`.tack` bitmaps plus `TWAL1` delta tails),
   [Milestone 20](20-branches-merges-and-restore.md),
   [Milestone 24](24-replication-and-failover.md) and
   [Milestone 29](29-reviewed-data-collaboration.md) support attaching a local or
   staging Transit instance to an upstream remote (`CREATE REMOTE`, `FETCH`,
   continuous `MIRROR`) under current `policy_epoch` RLS/masking filters,
   transferring only missing `.tseg`/`.tdel` deltas, testing schema migrations
   and fenced dataflows on a local branch, and pushing the delta segments and
   candidate manifest back to the remote as a reviewed proposal.
4. **Pre-release cross-dialect grammar comparison and DuckDB-style ergonomic desugaring ([Milestone 41](41-sql-grammar-and-dialect-ergonomics.md)):**
   The grammar owner is now [Milestone 41](41-sql-grammar-and-dialect-ergonomics.md)
   at the start of Phase VII, after the scientific/media/evidence workload
   phase and before [qualification](42-qualification-and-benchmarks.md) and
   [release](43-releases.md). It audits the
   complete SQL grammar across Tables, KV, Documents, Streams, Queues, Dataflows,
   Property Graphs, Foreign Tables and Branches against **ISO/IEC 9075
   SQL:2023**, **PostgreSQL 17**, **DuckDB**, **Snowflake / Delta Lake**,
   **Dolt**, **ClickHouse**, **GoogleSQL** and **Materialize / Flink SQL**;
   qualifies DuckDB-style `FROM`-first query syntax (`FROM people SELECT id, name;`
   and bare `FROM people;`), `SELECT * EXCLUDE (...) REPLACE (...)`, `GROUP BY ALL`,
   `ORDER BY ALL`, trailing commas and numeric underscores as deterministic
   compile-time desugarings to byte-identical `FQP1` plans; and requires
   actionable compiler diagnostics when callers submit foreign dialect spellings.

## Gateway architecture, sans-I/O wire protocols and direct-plane ingress review — 2026-10-28

An architectural and performance review of [`transit-sql-gateway`](../../apps/transit-sql-gateway/README.md),
[`Gateway.zig`](../../apps/transit-cli/server/Gateway.zig),
[`NativeServer.zig`](../../apps/transit-node/NativeServer.zig),
[`DatabaseRuntime.zig`](../../packages/zig/transit-sql/src/DatabaseRuntime.zig),
[`Registry.zig`](../../packages/zig/transit-sql-service/src/Registry.zig),
[`transit-http-server`](../../packages/zig/transit-http-server/src/root.zig),
[`transit-tls-server`](../../packages/zig/transit-tls-server/src/root.zig) and
[`transit-io`](../../packages/zig/transit-io/src/root.zig) at `42067b5a1`
identified why gateway tests take minutes and flake under load. Even after
decoupling SQL from `Station` actors in [Milestone 6 Step 1](06-streams-queues-and-durable-runtime.md#sql-database-runtime-cutover--2026-10-28),
`transit-sql-gateway` still operates as an out-of-process HTTP/1.1 JSON client
orchestrating 7–10 sequential `/table/v1` round-trips per SQL write (`58` total
upstream POSTs and `1,573 ms` for a 1-row `INSERT` in the instrumented TLS
console trace; `183–191` internal HTTP requests and `1,550–1,640 ms` for a
1-row native `SELECT`; `532–655 ms` p50 for a 1-row wire read and
`1,019–1,679 ms` p50 for a 1-row wire write on a 4-row table; and `1,488–1,505`
`/table/v1` requests taking `31–32 s`—or timing out at `626.06 s` / `> 300 s`
when seeding 67 rows—in [`sql_gateway_native.py`](../../tests/interfaces/sql/sql_gateway_native.py)).
Simultaneously, `runAccount` (`2–100 ms` per account) and `recoverSessions`
(`100 ms`, allocating a fresh `wire.Client` every tick) continuously poll
`transit-node`'s **4 data slots and 2 control slots** (`NativeServer.zig:51`),
triggering `HTTP 503 HttpCapacity` / `ControlCapacity` retry storms, while
`transit-io` pre-spawns **184 to > 600 barrier-synchronized OS threads** per
gateway start and `transit-http-server` / `main.zig` spawn **two concurrent
`std.Io.Select` tasks** (a timer task and a worker task) on every HTTP header,
request, handshake and SQL command. Inserting
[Milestone 8](08-gateway-architecture-and-protocol-ingress.md) in Phase I (after
[Milestone 7](07-document-storage-and-station-decoupling.md) and before
[Milestone 9](09-client-foundation-and-language-apis.md)) shifts the sequence to
`1–35`:

1. **Co-host `DatabaseRuntime` with the Direct Data Plane in `transit-node` / `transit server` and collapse `/table/v1` RPC cascades ([Milestone 8](08-gateway-architecture-and-protocol-ingress.md)):**
   Bind SQL, Flight and HTTP serving listeners directly to in-process
   `DirectCatalog`, `TablePartition`, `StreamPartition`, `QueuePartition` and
   `DocumentPartition` owners in `transit server` / `transit-node` (`0` loopback
   HTTP requests per statement), and expose a single coarse-grained server-side
   statement/transaction execution RPC for standalone remote gateways (`1`
   round-trip instead of 7–10 `/table/v1` HTTP POSTs).
2. **Replace `2–100 ms` background polling (`runAccount`, `recoverSessions`) with event-driven recovery:**
   Sweep pending tokens once on startup/activation and wake recovery workers
   **only** when a foreground statement actually fails or times out after
   binding a `DirectClientToken`, dropping idle gateway-to-node traffic to `0`
   requests/sec and eliminating `HttpCapacity` / `ControlCapacity` self-starvation.
3. **Separate pure sans-I/O wire-protocol state machines from socket/TLS/timer plumbing and bound thread/task budgets:**
   Keep `transit-postgres`, `transit-mysql`, `transit-sql-protocol` (`TSR1`),
   `transit-flight`, `transit-serving-http` and
   [Milestone 16's](16-document-profiles-and-gateway-exchange-lifecycle.md)
   protocol profiles (`HTTP`/`MIME`, `FTP`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`,
   `AMQP`, `MQTT`, `NTP`) strictly as sans-I/O byte/frame state machines with
   pre-allocated connection slabs (zero heap allocations after warmup), replace
   per-step `std.Io.Select` timer tasks with socket `io.operateTimeout`
   deadlines, size `transit-io` worker pools to `O(CPU cores)`, and split
   [`gateway.py`](../../tests/interfaces/sql_wire/gateway.py) into millisecond
   in-memory protocol tests and focused driver suites.

## Logical document storage, multi-format document profiles and gateway exchange decoupling review — 2026-10-28

An architectural review of the `Document` resource type
([`STATION_DOCUMENT_V1.md`](../../contracts/STATION_DOCUMENT_V1.md) /
[`transit-station-document`](../../packages/zig/transit-station-document/README.md))
and protocol exchange capture
([`STATION_EXCHANGE_V1.md`](../../contracts/STATION_EXCHANGE_V1.md) /
[`SERVING_V1.md`](../../contracts/SERVING_V1.md)) identified that `Document`
was still implemented as a `Station` CRDT service over 256-byte [`STATE_V1`](../../contracts/STATE_V1.md)
KV turns and 4 KiB `SIX1` B-tree pages (with a 96-byte scalar string ceiling and
one `u32` Unicode scalar per CRDT text element), while HTTP/gRPC connector and
gateway exchanges built a separate 256-byte KV storage island (`EXF1`, `EXP1`,
`EXB2`, `EXL2`) that could not be queried by `Fuze` or stored in `.tseg`.
Inserting [Milestone 7](07-document-storage-and-station-decoupling.md) in Phase I
(after [Milestone 6](06-streams-queues-and-durable-runtime.md)) and
[Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md) in Phase II
(after [Milestone 14](14-vectorized-strings-and-search.md) and
[Milestone 15](15-data-centric-compilation-and-specialization.md)) shifts the
sequence to `1–34`:

1. **Decouple `Document` from `Station` into `DocumentPartition` over `TWAL1` and `.tseg` ([Milestone 7](07-document-storage-and-station-decoupling.md)):**
   Move `DOCUMENT` into the Direct Data Plane (`transit-storage` and
   `DirectCatalog`) alongside `TABLE`, `KV`, `STREAM` and `QUEUE` before
   [Milestone 9](09-client-foundation-and-language-apis.md) extracts the
   Station-free client foundation. Replace 96-byte `SDC1` scalars, `SIX1` 4 KiB
   B-tree nodes and three-turn `NamedResource` actor initialization with a
   logical $\tau \perp \kappa \perp \epsilon$ Document algebra stored in `.tseg`
   segments using **$2N$-bit Balanced Parentheses (`BP`) succinct tree
   bitvectors**, **Dremel/ClickHouse-style adaptive columnar path shredding**,
   five-state cell provenance (`value`, `null`, `missing`, `type_error`,
   `conflict`), single-round-trip `TransitLog` (`TWAL1`) commits,
   [Milestone 5](05-transactions-and-atomic-composition.md) transaction
   participation and pluggable revision/merge profiles (`versioned` and
   `causal_crdt`).
2. **Deliver a declarative Document Type Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`, `AMQP`, `MQTT`, `NTP`, `PDF`, `DOCX`, `XLSX`, `ODF`) over a shared suite of `.tseg` and `Fuze` data structures ([Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)):**
   Define structured documents (`JSON`, `XML`, `EDI_X12`/`EDIFACT`/`HL7`),
   application protocols (`HTTP`/`MIME`, `FTP`, `SMTP`/`IMAP`/`POP3`,
   `LDAP`/`LDIF`, `SIP`/`SDP`, `AMQP`, `MQTT`, `NTP` fixed-point clock
   exchanges) and compound office/publishing containers (`PDF` `xref`/`COS` +
   spatial page spans, `DOCX`/`ODF` `OPC`/`ZIP` XML part graphs, and `XLSX`/`ODS`
   workbooks mapping `sharedStrings.xml` to `.tseg` `.dictionary` tables and
   worksheets to five-state relational `Table` views) as parameterized
   **Document Profiles** sharing zero-allocation SIMD structural/TLV scanners,
   [Milestone 14's](14-vectorized-strings-and-search.md) 16-byte Umbra/German
   collation-prefixed strings (`utf8_binary`, `ascii_ci`, `ebcdic_cp037`,
   `icu:<locale>`) and `comptime`/segment-sealed perfect hash vocabularies,
   [Milestone 15's](15-data-centric-compilation-and-specialization.md) AOT Zig
   grammar/shredder specialization, and non-aborting five-state validation (where
   malformed fields, EDI segments or `#REF!`/`#DIV/0!` spreadsheet cells become
   `type_error` cells with exact `(part_id, byte_start, byte_end, rule_id)`
   provenance into the preserved raw frame).
3. **Unify Gateway and Connector exchange capture with `Document` lifecycle and history while keeping transport and storage decoupled ([Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)):**
   Gateways and Connectors own **Transport, TLS, Authentication, Flow Control
   and Effect-Attempt Fencing** (*Process & Effect Plane*), while
   `DocumentPartition` owns **Representation, Staging, Lineage & Queryability**
   (*Direct Data Plane*). Cut [`STATION_EXCHANGE_V1.md`](../../contracts/STATION_EXCHANGE_V1.md)
   outbound connector capture and inbound gateway admissions over to linked
   `DOCUMENT` revisions (and `STREAM`s/`QUEUE`s of `DOCUMENT`s) in
   `DocumentPartition`, preserving SHA-256 coverage commitments, `SecretRef`
   credential redaction, unknown-outcome fencing and network-free replay while
   making every HTTP, FTP, EDI, XML and JSON exchange directly queryable in
   `Fuze` SQL and [Board](30-board-reimplementation.md).

## Database decoupling, declarative streams/queues and durable runtime architecture review — 2026-10-27

A latency and systems-architecture review of the post-[Milestone 4](04-statement-results-and-consumption.md)
SQL path (`~609 ms` for a 1-row `SELECT` and `~7,250 ms` across 16 native turns
and 1,307 internal requests for a 1-row `INSERT`) identified that durable actor
runtime concerns (`Station` / [`STATE_V1`](../../contracts/STATE_V1.md)) were
leaking into the database while the durable runtime itself was constrained by
lacking first-class `STREAM` and `QUEUE` database primitives. Inserting
[Milestone 6](06-streams-queues-and-durable-runtime.md) right after
[Milestone 5](05-transactions-and-atomic-composition.md) shifts subsequent
milestones to `7–31` and establishes three architectural foundations:

1. **Decouple the database from the durable runtime (`transit-sql` $\perp$ `Station` — pulled forward to close [Milestone 3 P5](03-live-storage-and-sql-cutover.md#implementation-plan--2026-10-27) before [Milestone 5](05-transactions-and-atomic-composition.md) coordinator implementation):**
   Remove `Station` `GenServer`, `AccountRuntime`, `Ledger` and `Coordinator`
   from `transit-sql`, `transit-sql-gateway` and `transit-query-host` before
   building [Milestone 5's](05-transactions-and-atomic-composition.md)
   `BEGIN`/`COMMIT`/`ROLLBACK` coordinator so interactive transactions are never
   layered on top of 16-turn actor ledgers. Move client token idempotency
   (`(AccountId, ClientToken) -> OperationId, CommitLSN`), snapshot cut
   acquisition and lease fencing directly into `DirectCatalog`, `TablePartition`
   and [Milestone 5 transaction logs](05-transactions-and-atomic-composition.md)
   so single-partition SQL writes commit in one round-trip to `TransitLog`
   (`TWAL1`) and `SELECT` reads hot lease-cached partition state without writing
   per-query `ReadPins` to disk.
2. **Elevate `STREAM` and `QUEUE` to first-class declarative catalog primitives with dedicated grammar and shared `TablePartition` / `StreamPartition` / `QueuePartition` storage:**
   Add `STREAM` and `QUEUE` alongside `TABLE`, `KV` and `DOCUMENT`, using
   explicit workload-specific verbs decoupled from relational table syntax and
   sharing the `TWAL1` + `.tseg` + Roaring-bitmap engine in `transit-storage`:
   - **Streams (`CREATE STREAM`, `PRODUCE INTO`, `CONSUME ... FROM`, `COMMIT OFFSET` and read-only `STREAM_SLICE(...)`):**
     `StreamPartition` stores partitioned append-only event logs over `TransitLog`
     (`TWAL1`) automatically tiered to immutable `.tseg` segments in
     `TransitObjectStore` ([Kafka](https://kafka.apache.org/) /
     [Pulsar](https://pulsar.apache.org/) / [WarpStream](https://www.warpstream.com/)
     model), with zero-copy buffer-pool tail reading and consumer-group watermark
     tracking. Operational consumption uses `CONSUME ... FROM`, while side-effect-
     free relational `SELECT` joins and bitemporal `AS OF JOIN` backtests in
     [Milestone 12](12-sql-and-dataflows.md) read bounded historical `.tseg`
     ranges through an explicit `STREAM_SLICE(stream, ...)` table-valued function.
   - **Queues (`CREATE QUEUE`, `ENQUEUE INTO`, `CLAIM ... FROM ... WITH LEASE`, `ACK`, `NACK`, `EXTEND LEASE`):**
     `QueuePartition` composes `StreamPartition`'s append-only `TWAL1`/`.tseg`
     payload storage with a **`.tack` Roaring-bitmap state vector** (reusing the
     exact `.tdel` bitmap machinery in `transit-storage` to track per-offset
     `Available`, `Acquired`, `Acked` and `Archived/DLQ` states as compact `TWAL1`
     delta frames and sealed sidecars, following
     [Kafka KIP-932 Share Groups](https://cwiki.apache.org/confluence/display/KAFKA/KIP-932%3A+Queues+for+Kafka),
     [RocketMQ](https://rocketmq.apache.org/) and Pulsar `Key_Shared`), an
     in-memory fenced lease heap (`_lease_epoch`), a lock-free `key_fifo`
     entity-key affinity table, and a **Hashed Hierarchical Timing Wheel**
     (Varghese & Lauck, SOSP 1987) for `visible_at` delays and retry backoff
     without B-tree page rewrite amplification.
3. **Unify the [Milestone 5](05-transactions-and-atomic-composition.md) transaction commit envelope so a `Station` turn is simply a database transaction:**
   Following the virtual-actor and durable-execution literature
   ([Restate](https://restate.dev/), [Temporal](https://temporal.io/),
   [DBOS](https://www.dbos.dev/) and [Orleans](https://www.microsoft.com/en-us/research/project/orleans-virtual-actors/)),
   [Milestone 5's](05-transactions-and-atomic-composition.md) commit envelope
   natively supports three participant primitives from the outset:
   `(1) TABLE/KV/DOCUMENT state mutations and conflict guards`,
   `(2) STREAM PRODUCE / QUEUE ENQUEUE log appends`, and
   `(3) _lease_epoch-guarded QUEUE ACK / STREAM COMMIT OFFSET settlements`.
   A `Station` behavior's inbox is a declared `key_fifo` `QUEUE`, its state lives
   in declared `TABLE`/`KV`/`DOCUMENT` objects (retiring the 256-byte value and
   4-mutation per-turn limits of `STATE_V1`), its replay journal and effect
   outbox are declared `STREAM`s/`QUEUE`s, and each handler turn commits atomically
   as a standard [Milestone 5 transaction](05-transactions-and-atomic-composition.md)
   with zero bespoke actor turn-commit protocol or external `courier` polling.

## Fine-grained resource control, vectorized text, perfect hashing and data-centric compilation review — 2026-10-27

A performance-architecture review of Zig resource control, first-class text/search
execution, compile-time/immutable perfect hashing and [HyPer](https://hyper-db.de/) /
[Umbra](https://umbra-db.com/) / [CedarDB](https://cedardb.com/) data-centric
execution and buffer management refines [Milestone 12](12-sql-and-dataflows.md) and
[Milestone 13](13-data-structures-and-performance.md) and inserts two dedicated
Phase II milestones—[Milestone 14](14-vectorized-strings-and-search.md) and
[Milestone 15](15-data-centric-compilation-and-specialization.md)—shifting the
subsequent milestones to `13–30`:

1. **Zero steady-state heap allocation on hot paths, LeanStore/Umbra zero-copy buffer management and fine-grained per-morsel resource metering ([Milestone 3](03-live-storage-and-sql-cutover.md), [Milestone 13](13-data-structures-and-performance.md), [Milestone 27](27-control-and-policy-plane.md)):**
   Rather than fixed total-cardinality static arrays that would violate Transit's
   paged durable-state model, hot paths target zero steady-state OS/heap allocations
   after warmup by pairing pre-allocated subsystem slabs with explicit `scratch`
   (reset per step/page with `.retain_capacity`) and `output` arenas.
   [Milestone 3](03-live-storage-and-sql-cutover.md) (P5) and
   [Milestone 4](04-statement-results-and-consumption.md) replace per-row
   `OwnedRow` arena churn on storage/SQL read paths with batch-reused arenas and
   borrowed verified slices; [Milestone 13](13-data-structures-and-performance.md)
   enforces counting-allocator regression gates, 64-byte cache-line alignment and
   L1d/L2 working-set budgets across `Fuze` vectors and `.tseg` pages, and upgrades
   [`NvmeCache`](../../packages/zig/transit-storage/src/NvmeCache.zig) using
   **LeanStore/Umbra pointer swizzling, optimistic version-latched zero-copy
   slices over variable size-class slabs ($64\text{ KiB}\text{–}1\text{ MiB}$)
   and admission-only SHA-256 verification** (eliminating per-hit SHA-256
   recomputation and `@memcpy` overhead). Taking inspiration from
   [Egres](https://manishrjain.com/egres/),
   [Milestone 13](13-data-structures-and-performance.md) and
   [Milestone 27](27-control-and-policy-plane.md) chain a hierarchical
   `MeteredAllocator` vtable with per-`Batch` morsel CPU cycle/tick and storage
   IOPS/byte accounting so runaway queries deterministically spill to Tier 2 NVMe
   or return a typed budget refusal at batch boundaries without noisy-neighbor
   starvation or process-wide OOMs.
2. **First-class Umbra/German strings, perfect hashing and fully-vectorized Block-Max BM25 search ([Milestone 14](14-vectorized-strings-and-search.md)):**
   Instead of overloading general data structures or foreign-format adapters,
   [Milestone 14](14-vectorized-strings-and-search.md) gives text, static/immutable
   key lookup and search their own dedicated owner:
   - **16-byte collation-prefixed inline strings ("Umbra / German Strings"):**
     Adapting [Umbra's](https://umbra-db.com/) 16-byte string layout
     (`[len: u32][collation_sort_prefix: 4B][inline_or_offset: 8B]`), `Fuze`
     stores a 4-byte collation-normalized sort prefix (`utf8_binary`, `ascii_ci`,
     `ebcdic_cp037`, `icu:<locale>`) so register-level comparisons short-circuit
     across non-binary collations as well, alongside compressed-domain string
     kernels pushing `=`, `IN (...)` and prefix/substring predicates directly
     into `.dictionary` codes and `.fsst` symbol tables.
   - **Compile-time (`comptime`) and segment-sealed perfect hashing:** Applying
     greedy association-table construction (`slot = (len + asso[key[i]] + asso[key[j]]) & mask`)
     and branchless 16-byte `@Vector(16, u8)` SIMD shuffle-mask comparisons from
     [ConstexprCore/perfect_hash](https://github.com/ConstexprCore/perfect_hash),
     Transit eliminates collision chains for SQL/protocol keywords at `comptime`
     and seals frozen perfect-hash directories for `WHERE col IN (...)` sets,
     `TableSchema` column lookups and immutable `.tseg` dictionary/key pages
     (backed by 16–64 byte trailing buffer padding).
   - **Declarative text/proximity search and swappable `.tseg` index profiles (starting with vectorized 256-doc Block-Max BM25 and hybrid search):**
     Taking inspiration from
     [turbopuffer's fully-vectorized search engine](https://turbopuffer.com/blog/fully-vectorized-search-engine),
     [Milestone 14](14-vectorized-strings-and-search.md) separates declarative
     analyzer/segmenter, proximity (`NEAR` / `WITHIN`) and ranking contracts from
     swappable physical `.tseg` index layouts so text and code search are never
     locked into a bag-of-words model. Its initial lexical profile partitions
     posting lists into 256-document bitpacked blocks aligned with `.tseg` row
     groups and equipped with block-max BM25 impact weights (`max_tf`,
     `min_doc_len`), evaluated via vectorized `MAXSCORE` / Block-Max WAND
     operators in `Fuze` that prune non-competitive blocks, intersect relational
     and `.tdel` bitmasks in SIMD registers, and defer payload decoding through
     late materialization, while handing off speculative research into
     declarative spans, multi-scale `NEAR` maps, context-conditioned continuation
     and branch-verified agency to
     [Milestone 44](44-declarative-language-context-and-synthesis.md).
3. **Data-centric pipeline fusion, CedarDB join structures, Flying-Start Adaptive Morsel Tier-Up and AOT query compilation ([Milestone 12](12-sql-and-dataflows.md), [Milestone 13](13-data-structures-and-performance.md), [Milestone 15](15-data-centric-compilation-and-specialization.md)):**
   Taking inspiration from [HyPer](https://hyper-db.de/) (Neumann, VLDB 2011),
   [Umbra](https://umbra-db.com/) (Neumann & Freitag, CIDR 2020),
   [CedarDB](https://cedardb.com/) and the compiled-versus-vectorized synthesis
   (Kersten et al., VLDB 2018), [Milestone 12](12-sql-and-dataflows.md) and
   [Milestone 13](13-data-structures-and-performance.md) adopt universal `D-Join`
   correlated subquery unnesting, **CedarDB-style ~10-instruction directory-tagged
   join hash tables** (embedding 16-bit Bloom/tag signatures in directory slots)
   and **Diamond-Hardened / Worst-Case Optimal Joins (WCOJ / FreeJoin)**.
   [Milestone 15](15-data-centric-compilation-and-specialization.md) combines
   vectorized `Batch` morsels (for SIMD scans and software-prefetched `@prefetch`
   hash-join probes) with **data-centric push pipeline fusion** inside each morsel
   so multi-step expressions, projections and aggregations stay in CPU registers
   without writing temporary `scratch` arrays per AST node. It pairs
   **per-`.tseg`-row-group dense non-null kernel dispatch** (`null_count == 0` and
   empty `.tdel`) with **Flying-Start Adaptive Morsel Tier-Up** ($0\,\mu\text{s}$
   startup via fused superinstructions, tiering up at a morsel boundary to
   Copy-and-Patch stencils only for long-running queries) and **true Ahead-of-Time
   (AOT) Zig compilation via `transit-app`**, setting HyPer, Umbra and CedarDB on
   the VLDB 2018 microbenchmarks, the Join Order Benchmark (JOB), ClickBench and
   the HTAP CH-benCHmark as comparative baselines.

## Enterprise database and governance review — 2026-10-25

An architectural review of the 28-milestone plan against enterprise HTAP,
zero-copy branching and governed multi-agent database requirements identified
ten capabilities that needed explicit ownership within the existing sequence:

1. **Fine-grained Serializable Snapshot Isolation (SSI / key-range conflict tracking):**
   [Milestone 5](05-transactions-and-atomic-composition.md) retains conservative
   whole-Table read conflict validation for its initial local slice, while
   [Milestone 11](11-indexing-and-access-paths.md) and
   [Milestone 23](23-storage-providers-and-concurrency.md) explicitly own the
   progression to index-range and predicate-level conflict detection so concurrent
   read-write transactions touching disjoint keys on shared Tables commit without
   false whole-Table aborts.
2. **LSM/`.tseg` compaction invariants, branch-aware GC and multi-dimensional clustering:**
   [Milestone 13](13-data-structures-and-performance.md) owns leveled/size-tiered
   `.tseg` overlap bounds ($K_{\max}$), `.tdel` tombstone compaction thresholds
   and declarative `PARTITION BY` / `CLUSTER BY` (including Z-order/Hilbert sort
   keys decoupled from primary keys); [Milestone 20](20-branches-merges-and-restore.md)
   owns branch-aware compaction and shared-segment garbage collection watermarks.
3. **Security-barrier Row-Level Security (RLS), Column-Level Security (CLS) / dynamic masking and GDPR crypto-shredding:**
   [Milestone 23](23-storage-providers-and-concurrency.md) owns authenticated
   encryption at rest and KMS/BYOK per-tenant/per-subject envelope encryption over
   `TransitLog` and `.tseg`/`.tdel` objects;
   [Milestone 27](27-control-and-policy-plane.md) owns security-barrier RLS
   (preventing side-channel leakage via 5-state `type_error`, division-by-zero or
   zone-map/index statistics), dynamic column masking and auditable cross-branch
   crypto-shredding/purge workflows.
4. **Declarative `FOREIGN KEY` and `CHECK` relational integrity:**
   [Milestone 10](10-standards-and-catalogs.md) owns catalog bindings and dependency
   graphs for `CHECK` and `FOREIGN KEY` constraints;
   [Milestone 11](11-indexing-and-access-paths.md) owns index-backed transaction
   enforcement; and [Milestone 20](20-branches-merges-and-restore.md) validates
   referential integrity across 3-way branch merges.
5. **First-class bitemporal SQL (`AS OF JOIN` and application-time periods):**
   [Milestone 12](12-sql-and-dataflows.md) and
   [Milestone 13](13-data-structures-and-performance.md) pair `FOR SYSTEM_TIME AS OF`
   with declarative valid-time periods (`PERIOD FOR valid_time`) and streaming
   $O(N + M)$ `AS OF JOIN` merge execution so point-in-time backtesting and
   decision audits never leak later corrections into earlier simulated decisions.
6. **Complete analytical SQL and deterministic in-engine UDFs:**
   [Milestone 12](12-sql-and-dataflows.md) and
   [Milestone 13](13-data-structures-and-performance.md) explicitly enumerate
   multi-way/non-equi/`SEMI`/`ANTI`/`LATERAL` joins, correlated subquery
   decorrelation, window functions (`OVER (...)` / `QUALIFY`), CTEs (`WITH` /
   bounded `WITH RECURSIVE`), set operations, rich aggregates, external NVMe
   spill and sandboxed scalar/table UDFs (SQL macros and deterministic Wasm
   kernels running over `Fuze` vectors without actor-mailbox round-trips).
7. **Native segment-backed Full-Text Search (BM25) and Vector / Hybrid Retrieval:**
   [Milestone 18](18-multi-model-and-foreign-relations.md) and
   [Milestone 32](32-reactive-context-and-agent-activation.md) own immutable
   inverted full-text segments (BM25) and `.tseg` vector/ANN similarity indexes
   so lexical, semantic and relational queries execute under a single `SnapshotId`,
   branch and `policy_epoch` without exporting data to external search/vector stores.
8. **Hierarchical Workload Management (WLM) and scan-resistant caching:**
   [Milestone 13](13-data-structures-and-performance.md) owns scan-resistant
   buffer-pool/NVMe eviction (2Q/ARC/W-TinyLFU) and background I/O token buckets;
   [Milestone 27](27-control-and-policy-plane.md) owns multi-tenant WLM resource
   groups isolating OLTP writes, interactive Board/SQL queries, continuous
   dataflows, background compaction and autonomous MCP agent bursts.
9. **Lazy `.tseg` schema projection and online phased table rewrites:**
   [Milestone 3](03-live-storage-and-sql-cutover.md) and
   [Milestone 10](10-standards-and-catalogs.md) project historical `.tseg`
   `DefinitionId` layouts and 5-state `missing`/default cells lazily on read for
   compatible `ALTER TABLE` operations, while
   [Milestone 11](11-indexing-and-access-paths.md) executes physical type/collation
   rewrites through the recoverable online snapshot-to-tail lifecycle.
10. **Continuous Change Data Capture (CDC) ingress and `CHANGES(...)` SQL egress:**
    [Milestone 12](12-sql-and-dataflows.md) exposes committed deltas via a
    `CHANGES(table, ...)` table-valued function, and
    [Milestone 18](18-multi-model-and-foreign-relations.md) delivers governed
    streaming CDC ingress adapters (PostgreSQL logical replication, MySQL binlog,
    Debezium/Kafka CDC envelopes) with watermark and checkpoint recovery.

All 28 milestone numbers, phase boundaries and existing statuses remain unchanged.
This planning update establishes delivery ownership and acceptance criteria, not
implemented runtime support.

## Formal semantics and correspondence review — 2026-10-25

Add [formal semantics and implementation correspondence](22-formal-semantics-and-correspondence.md)
as milestone 14, closing phase II after service/SDK coverage and before provider
qualification. The local system's storage, statement/transaction, index, dataflow,
selected-structure and branch contracts must settle before this work selects its
models. Earlier correctness and recovery gates remain with their owners; in
particular, this insertion adds no formal-model prerequisite to the upcoming
statement-result work.

The milestone preserves seven temporal and six algebraic candidate families from
the reviewed Argon discussion, including motivating schedules, proposed laws,
implementation connections and corrections to premature algorithm/guarantee
assumptions. Its provenance and self-contained candidate descriptions live in the
milestone. Scope selection requires actual executable models/proofs and production
correspondence; neither an inventory alone nor thirteen predetermined filenames
is the completion criterion. Distributed fencing/replication and enterprise
policy/approval extensions retain later owners once their contracts settle.

The sequence now has 28 milestones in six contiguous phases. Former milestones
14–27 move to 15–28 with statuses, delivered scope and evidence preserved.
Phase II expands to 9–14; subsequent phase ranges, checkpoints and inbound links
move together. Final qualification combines the selected formal suites with
installed workload and physical-fault evidence at one revision. This planning
change implements no model, selects no runtime algorithm and establishes no new
proof result.

## Indexing, performance and phase review — 2026-10-25

The review at `8309a0dc` combines the indexing/lifecycle assessment with the
hardware-conscious data-structure discussion. Add
[indexing](11-indexing-and-access-paths.md) at the end of phase I, after transaction
and historical/collation semantics, and
[data structures, query optimization and runtime performance](13-data-structures-and-performance.md)
in phase II after managed computations. Neutral index/constraint contracts begin
with the foundations; basic storage and transaction guarantees remain earlier
acceptance obligations. Online index maintenance uses qualified storage feeds
without requiring the later general dataflow scheduler.

The first new owner delivers definitions, query eligibility and recoverable
maintenance, including ordered, covering and deterministic partial-index slices.
The second evaluates trees, filters, bitmaps, hashing, vector execution and
runtime scheduling against explicit workload targets. Algorithms, node sizes,
fixed I/O counts, Bloom-filter rates and concurrency guarantees require scoped
proof and measurement. Immutable sharing does not make branch preparation,
constraint validation or historical correctness free. The runtime scope includes
native messages, Station turns, state, wakeups and recovery as well as SQL.

At that review, the sequence had 27 milestones in six contiguous phases. Former
milestone 8 moves to 9 and former 9–25 move to 11–27. Every previous status, delivered slice
and acceptance obligation is preserved. Provider qualification, replication,
operations and clustered execution remain before enterprise/agent adapters;
Board remains after reviewed publication, and complete mixed composition remains
after recorded outbound MCP. This planning change establishes no new executable
index syntax, transaction profile or measured performance result.

The earlier dated reviews below retain their then-current milestone numbers;
links resolve to the current owning files. The [milestone sequence](#milestone-sequence)
and [delivery checkpoints](#delivery-checkpoints) give the current delivery order.

## Board reimplementation review — 2026-10-24

The review at `f699e6ad` adds
[Board reimplementation](30-board-reimplementation.md) as milestone 19, after
reviewed publication and before MCP/Apps. [Board data D2](../design/board-data/D2.md)
defines a focused data-first direction, but its prototype and screenshots do not
deliver the installed interface. The new milestone owns that cutover, including
public API projections, the frontend, accessibility, preserved operational
inspection and real browser/recovery evidence.

The full experience consumes published investigations and exact proposal/review
contracts from milestones 17–18. Building the human workbench before agent-host
adapters is a delivery priority, not a dependency of MCP on Board. Basic catalog,
preview and shell work can land against earlier qualified owners. Existing Board
migrations, service parity and inspection obligations stay with those owners;
the new milestone must not become a reason to postpone them.

Milestone 19 retains bounded comparison, approval and publication operations
usable without a browser; milestone 19 owns their complete Board presentation.
Later reactive context and mixed-language composition are not prerequisites for
the Board cutover. The sequence at that review had 25 milestones: the former 19–24 move to
20–25, with every existing status and acceptance obligation preserved. This adds
delivery ownership without declaring the D2 workflows implemented or all design
details accepted.

## Transaction model and linear execution review — 2026-10-24

The review at `7f9343cc` adds [transactions](05-transactions-and-atomic-composition.md)
immediately after statement results, separates the
[client foundation](09-client-foundation-and-language-apis.md) from later
[complete mixed composition](34-programming-model.md), and gives
[provider/concurrent-writer qualification](23-storage-providers-and-concurrency.md)
an explicit delivery owner. That review produced 24 milestones; the Board review
above adds the 25th. All four existing In Progress statuses and all delivered
evidence are preserved; moving
unfinished work establishes no completion or new supported behavior.

Transaction design covers all experiences together: autocommit/batches, SQL and
typed multi-object transactions, consistent reads, DDL/constraints, Station and
consumer composition, outbox intents, branch publication and uncertain commit
recovery. Serializability within a selected atomic domain is the design target;
the algorithm, real-time ordering and any weaker opt-in profile require explicit
decisions and proof. Multi-partition commit needs participant durability,
visibility and decision recovery, not just a root CAS. No universal nonblocking
execution, zero-I/O savepoint or remote exactly-once promise is implied.

| Previous owner | Current delivery owner and preserved obligation |
| --- | --- |
| 1: combined lifecycle contracts and runtime | 1 retains neutral contracts/metadata; 3 receives the complete direct Table, named KV/Document and computation integration, including #111/#119/#120 and original #108 caller evidence |
| 2–3: local foundation interleaved with provider/writer expansion | 2 retains local correctness, codecs and bounded storage; 3 qualifies installed local lifecycles; 12 receives #117/#121 and corresponding runtime/#124 provider and concurrent-writer proofs |
| 6: transaction sessions inside managed dataflows | 5 owns transactions; 8 retains general SQL composition, MERGE/upsert, prepared plans and managed dataflows, consuming the transaction contract |
| 6–7: typed import/export separate from actual formats | 9 owns typed COPY/import/export and foreign adapters together, using the direct-ingestion and transaction owners |
| 16: all programming-model work after MCP | 6 delivers package/runtime/API foundations before SDK expansion at 11; 23 retains every mixed capability and full per-language Station/composition qualification after outbound MCP at 22 |
| 17–19: replication, operations and clustered execution after MCP | 13–15 preserve their order and scope after provider qualification and branches, before enterprise/collaboration adapters |

Placing infrastructure before enterprise/MCP work is a delivery priority, not a
claim that an authenticated finite adapter technically requires clustered
execution. Likewise, source formats may qualify locally before all cloud
providers; provider-dependent combinations close with milestone 12. Native
authorization and local safety apply from the start; enterprise IAM is an
extension, not the first permission gate. Later capabilities must not become
hidden prerequisites of an earlier milestone's completion.

The first three trackers remain open. #108 retains oversight of its original
installed lifecycle promises through milestone 3; #109 retains oversight of the
provider/writer scope now owned by milestone 12. A later milestone does not
absorb a missing promise without the explicit transfers above. The earlier dated
reviews below preserve the rationale and then-current sequencing. This table
records ownership at that review; the milestone sequence and execution plan
above give the current delivery order.

## Programming model review — 2026-10-24

[Language-native programming and mixed composition](34-programming-model.md)
follows recorded outbound MCP and application guidance. Direct data applications,
Station behaviors and applications combining both need a coherent public model:
shared types, operation identities, results and recovery with explicit execution
scopes. Current raw clients and Station runners are independently usable, but
several ordinary data/query APIs are packaged with Station and expose protocol
orchestration to applications. That review assigned those concerns to one
milestone; the transaction review above now separates its early foundation from
complete mixed qualification.

The Gemini Argon transcript review makes mixed composition concrete: standalone
recorded effects, durable change consumers and typed calls into Station are all
required. That review also required reusable data-package ownership, shared
bounded client infrastructure, recovery/staging helpers and side-by-side language
examples, now divided between the early foundation and later mixed qualification.
Checkpoint progress, turn commits and remote outcomes retain their
separate contracts; an operation key does not establish remote idempotency.

This is distinct from [service/SDK coverage](21-service-and-sdk-coverage.md),
which retains its existing operation and platform obligations. Shared result
semantics remain with [statement results](04-statement-results-and-consumption.md).
The current split requires the early client foundation before expanded SDK
coverage; the later mixed qualification cannot defer those obligations or
introduce another execution protocol. No transparent durability of host tasks or new
cross-resource transaction is implied.

At that review the new milestone was Planned at 16, moving replication through
release from 16–20 to 17–21. Those are historical positions; the transaction
and Board reviews above supersede them while retaining their scope and statuses.

## Result sets, replication and operations — 2026-10-24

[Statement results and client consumption](04-statement-results-and-consumption.md)
follows the live cutover as an independently reviewable SQL service/client
outcome. It covers statement completion, result identity/schema/basis, safe
batching, shared readers and bounded presentation. Storage/query performance
retains encoded execution ownership; the live cutover retains safe bounded
reads and runtime wiring. Their existing promises are not deferred by this split.
Contract work can proceed together. Published resources now consume the earlier
result contract and own disclosure plus retained investigations across calls.

[Replication](24-replication-and-failover.md) and
[operations](25-operations-and-recovery.md) precede
[clustered execution](26-clustered-execution.md). Replication qualifies complete
durable history, object coverage and safe failover for explicit failure profiles.
Operations owns backup/restore, upgrades and maintenance, including the
backup/restore/migration work previously grouped under clustered execution.
Clustered execution adds scheduling and distributed queries, and proves those
operational contracts across placement changes. Branch restore remains logical
data publication under current authority, separate from installation recovery.

This revision inserted three Planned milestones: former milestones 4–14 moved
to 5–15, and clustered execution, qualification and releases moved from 15–17 to
18–20 before the programming-model insertion above. Existing statuses, delivered
slices and proof obligations are preserved. Replication and operational
contract work depends on storage and live runtime foundations, not on every
intervening MCP or collaboration adapter completing first. No backup, replication
topology, result API or upgrade profile is qualified by this planning change.

## Enterprise collaboration and MCP direction — 2026-10-23

The outcome is governed collaboration over versioned, enriched business resources:
people and agents inspect the same evidence, explore alternatives on branches,
and publish changes only under the installation's policy. The
[business stories](../handbook/reference/collaborative-decisions.md) explain that
proposed experience and its current building blocks without requiring this plan.

The 2026-10-23 revision preserved the then-numbered milestones 1–8 and inserted
six collaboration milestones before clustered placement, qualification and
release. The 2026-10-24 revision above inserts result sets and separates
replication/operations; the current table includes the subsequent transaction
and Board reviews as well.
Delivered work and evidence retain their status. These revisions record direction
and acceptance gates, not executed runtime evidence.

The sequence is linear, with explicit prerequisites per milestone. Contract work
and a read-only MCP spike can start before all earlier implementations finish;
an adapter may expose only the capabilities whose owning contracts and evidence
are complete. Native branch operations use current realm authority; milestone 19
adds enterprise identity/delegation integration and milestone 21 adds the shared
proposal/approval experience. A protocol spike does not qualify those additions.

The ownership table below uses the current sequence. Dated insertion records
retain their historical numbers.

| Shared contract | Delivery owner | Required boundary |
| --- | --- | --- |
| Statement outcomes and result consumption | 4 | One typed result lifecycle, bounded readers and verified completion; statement completion is distinct from transaction commit |
| Transactions, snapshots and outbox | 1 contract gates; 5 implementation | Qualified atomic domains/isolation, original decision recovery and atomic local intent publication; external outcomes remain separate |
| Client packages and language APIs | 6, then coverage at 13 | Reusable shared implementation, bounded runtime ownership and idiomatic direct/recovery APIs before adapter expansion |
| Complete application composition | 26 | Direct, Station and all mixed capabilities preserve transaction, turn, checkpoint and effect boundaries across languages |
| Formal semantics and implementation correspondence | 14 | Selected settled local obligations, executable models/theorems, negative controls and production correspondence; later owners extend the qualified assumptions |
| Provider, replication and operational contracts | 15–18 | Enforceable durability/fencing, complete decisions/objects, recoverable backups/upgrades and qualified moving placements |
| Identity, membership, delegation and access decisions | 19 | Trusted actor/subject bindings, current authority and explicit approval powers through every adapter |
| Published resources and retained investigations | 20 | Deliberate exposure, approved disclosure and retained source bases independent of connections/open transactions |
| Branch histories and reviewed proposals | 12, 21 | Frozen base/source/target and candidate; no copied grants/effect rights or protected-destination bypass |
| Board presentation and workflow integration | 22 | Installed catalog/workbook/lineage/change interfaces over public owners; bounded disclosure, read-only inspection and exact recovery |
| MCP and presentation bindings | 23 | Generated descriptors/views over shared owners; exact host/revision matrix and useful fallback |
| Meaningful activation and durable interests | 9, 24 | Complete source commits, completed results and business conditions remain distinct |
| External capabilities and application guidance | 25 | Authorized recorded attempts, capture, uncertainty and network-free replay; instructions confer no authority |

The Control & Policy Plane owns identity bindings, catalog definitions, access and
publication policy. Data owners enforce reads and conditional writes; process
and effect owners enforce activation and dispatch. Reasoning remains an
application responsibility. A model's confidence, an App button or an MCP tool
annotation supplies no authority.

Branching is the versioning primitive within a realm. A branch has an identity,
head and ancestry under the realm's current policy; it is not inherently an
independent export or ownership boundary. A GitHub-like project/application fork
relationship is a possible later collaboration feature, not a prerequisite or a
synonym. Copy-on-write and manifest sharing are storage techniques. Historical
data selection never restores historical permissions or executable effects.

The first collaboration acceptance story uses one native dataset, one captured
external source, a human and two delegated agents. Related queries retain one
basis; agents publish different branch proposals; a report and App show the same
evidence. Source changes mark old evidence without relabeling it. A branching-only
installation rejects every merge and equivalent direct write. A separate approval
profile publishes one exact reviewed candidate and recovers its outcome after a
lost reply. Each owning milestone qualifies its part before the complete journey
is claimed. No new top-level `transit` command or automatic catalog-wide MCP
exposure is part of this direction.

## Reopened assessment — 2026-10-22

Milestones 1–3 are reopened following review of local source snapshot
`a0a8a3ed`.
The initial implementations in [PR #105](https://github.com/spoke-sh/transit/pull/105),
[PR #106](https://github.com/spoke-sh/transit/pull/106) and
[PR #107](https://github.com/spoke-sh/transit/pull/107), plus subsequent latency
work, delivered useful metadata, component libraries and improvements to the
existing Ursula/actor path. They did not satisfy the milestones' full lifecycle,
storage correctness or live cutover acceptance criteria. Component test passes
do not establish disk durability, independent-writer safety or runtime wiring.

The audit snapshot includes four unpublished implementation commits on
`feat/single-turn-sql-and-tseg-cutover` after the published
[PR #107 base](https://github.com/spoke-sh/transit/commit/733bc50406bf7a9100697478960fc18bb6ab8a8b).
Those implementation commits are outside this documentation change. Statements
about subsequent latency work refer to that local audit snapshot; they do not
claim that work is already on `main`.

The milestone pages separate that delivered work from the remaining gaps and
link actionable issues with source evidence, dependencies and completion gates.
The original design discussion transcript was reviewed, and the user authorized
this planning revision on 2026-10-22. The source transcript has SHA-256
`455cff4e0843d7d4602d2273041aa14055fd3272a88192bb5b4ec9ebec679f7e`;
it remains local source material, not a capability contract or a prerequisite
for understanding this plan. The scope and gates below supersede the initial
tracking pass's pending-review notes. They establish intended delivery, not
implementation or qualification.

## Firm scope and contract gates

Transit uses shared `TransitLog` and `TransitObjectStore` boundaries for the
durable system: catalog/control state, native process progress, KV, Documents,
Tables and supported captured/stream payloads. Data kinds retain their own
semantics and may use different physical layouts. Table-only storage does not
complete this cutover. Direct point mutations and bulk segment ingestion share
one accepted-operation protocol; process/effect owners preserve their existing
atomicity and recovery guarantees.

| Required contract | Owner | Gate before dependent implementation |
| --- | --- | --- |
| Catalog/branch roots and transactions | [#125](https://github.com/spoke-sh/transit/issues/125), [#111](https://github.com/spoke-sh/transit/issues/111) | Define atomic domains, isolation, head publication and consistent snapshots including accepted unflushed WAL state. Start with the complete single-owner Table slice; milestone 5 implements the selected transaction-session extension. |
| Native durable-state ownership | [#126](https://github.com/spoke-sh/transit/issues/126) | Map each control/process/KV/Document/payload owner to log transitions, checkpoint evidence and immutable objects; preserve input/state/output atomicity, retirement and effect outcomes. |
| Logical history and retention | [#127](https://github.com/spoke-sh/transit/issues/127) | Separate state recovery, net-result deltas and every-change capture; define subscriptions, snapshot-to-tail handoff, pins and safe physical trimming. |
| Encoded query access | [#128](https://github.com/spoke-sh/transit/issues/128), [#118](https://github.com/spoke-sh/transit/issues/118) | Define layouts, buffer ownership, encoded operators, collation identity and five-state/export semantics before changing segment/query interpretation. |
| Direct writer trust and durability profiles | [#117](https://github.com/spoke-sh/transit/issues/117), [#121](https://github.com/spoke-sh/transit/issues/121) | Select enforceable permission/fencing mechanisms and acknowledgement/failure guarantees for each provider profile; a lease tuple or object CAS is insufficient alone. |
| Index definitions, constraints and coverage | [Identities](01-declarative-data-lifecycle.md), [transactions](05-transactions-and-atomic-composition.md), [indexing](11-indexing-and-access-paths.md) | Define index/source identities, comparison and constraint dependencies, snapshot coverage and build/publication lifetimes before dependent formats; later structure selection preserves these contracts. |
| Maintenance and installed operation | [#116](https://github.com/spoke-sh/transit/issues/116), [#122](https://github.com/spoke-sh/transit/issues/122) | Assign flush/checkpoint/compaction/GC ownership, backpressure, shutdown and authorized progress inspection. Resolve runtime composition and the single-binary packaging target explicitly. |

Resolve these interacting contracts in their owning milestone and public topic
as appropriate before dependent code or persistent formats. This is required
engineering work, not an open-ended request for another product-direction review.
Unsupported combinations must be rejected explicitly. Any later scope change
must update the owner, linked issues and acceptance criteria together.

The native local profile is the first delivery checkpoint, with no Ursula or
MinIO dependency for either application or control state. The distributed
reference remains disk-backed Ursula plus S3 on Compose and Kubernetes/Substrate.
Kafka/Pulsar and GCS/R2/Azure remain explicit target coverage in milestone 18;
each needs its own provider contract and evidence, or an explicit recorded move
in scope. They are not assumed interchangeable implementations. Provider and
concurrent-writer implementation is explicitly transferred to milestone 18.
Native codec correctness and local publication safety remain milestone 2
requirements; no original tracker closes merely because its work was split.

## Architectural direction across the sequence

1. **Define declarative operations independently of the actor turn ceremony ([Milestone 1](01-declarative-data-lifecycle.md) — Completed).**
   Unify catalog identities (`CatalogId`, `DefinitionId`), dependency tracking and
   policy bindings across Tables, KV, Documents and named computations. Route
   data-plane DDL/DML and batch ingestion directly through the catalog and
   storage boundary instead of cycling every row through the `4 × 256B` metadata /
   `128 KiB` block actor-turn loop (`open_view -> commit_turn`), reserving
   `Station` actor turns for stateful process behavior and effect orchestration.
2. **Replace B-tree-over-JSON-streams with a four-tier storage hierarchy and `.tseg` segments ([Milestone 2](02-storage-and-query-performance.md) — Completed).**
   Split storage into two swappable primitives: **`TransitLog`** (the sequenced
   `TWAL1` write-ahead log and live data-activation delta bus, backed by a native
   Zig local WAL by default in `transit server`, or by Ursula, Kafka or Pulsar in
   distributed deployments) and **`TransitObjectStore`** (the immutable segment
   and manifest store, backed by a local POSIX directory in `transit server` or
   S3/GCS/R2 with a local NVMe read-through cache in cloud deployments). Store
   relational data in 64-byte-aligned **`.tseg` hybrid OLTP/OLAP segments** with
   Arrow-compatible physical column buffers, 5-state cell validity tags, embedded
   primary-key prefix B-tree indexes, zone maps, `.tdel` deletion vectors,
   composable Zig codecs (bitpacking, RLE, dictionary, FSST, plus mainframe
   `COMP-3`, `ZONED`, `COMP`, `IBM_HFP` and `EBCDIC`) and first-class Collation
   (`COLLATE`) support. Progress concurrency from a single global realm sequencer
   to **Partitioned Policy/Data Logs**, **Fenced Partition Leases**, and
   **Multi-Writer OCC** in [provider/writer qualification](23-storage-providers-and-concurrency.md),
   over authorized conditional publication. The native local foundation remains
   milestone 2; distributed-provider and writer integration belongs to milestone
   18. Formal progress and metadata-complexity claims require scoped evidence.
3. **Decouple the database and `Document` storage from `Station`, introduce declarative `STREAM` and `QUEUE` primitives, formalize the direct-plane gateway architecture, and re-architect the durable runtime ([Milestones 6](06-streams-queues-and-durable-runtime.md)–[8](08-gateway-architecture-and-protocol-ingress.md)).**
   Sever `transit-sql` and `DOCUMENT` storage from `Station` actor turns
   (`AccountRuntime`/`Ledger` and `STATION_DOCUMENT_V1`/`SIX1`), add first-class
   `STREAM` (`CREATE STREAM`, `PRODUCE INTO`, `CONSUME ... FROM`,
   `COMMIT OFFSET`) and `QUEUE` (`CREATE QUEUE`, `ENQUEUE INTO`,
   `CLAIM ... FROM ... WITH LEASE`, `ACK`, `NACK`, `EXTEND LEASE`) catalog objects
   backed by `TransitLog`/`.tseg` segments, Roaring-bitmap ack vectors, `key_fifo`
   key-affinity leasing and Hashed Hierarchical Timing Wheels, implement
   `DocumentPartition` over `.tseg` succinct trees and shredded subcolumns,
   co-host `DatabaseRuntime` and event-driven sans-I/O wire-protocol gateways
   (`transit-postgres`, `transit-mysql`, `TSR1`, `transit-flight`) directly over
   the Direct Data Plane without `/table/v1` HTTP polling cascades, and
   rebuild `Station` behaviors and connector queues as transactional
   consumers/producers over those database primitives.
4. **Declare safe access paths ([Milestone 11](11-indexing-and-access-paths.md)).**
   Bind index definitions, key/collation semantics, transaction maintenance and
   historical coverage to public owners. Deliver recoverable online builds,
   bounded primary/secondary reads and inspectable planner eligibility without
   introducing a second catalog or permission authority.
5. **Optimize the database, string/search engine, data-centric compiler, Document Type Library, geospatial engine and durable runtime ([Milestones 13](13-data-structures-and-performance.md)–[17](17-geospatial-and-spatio-temporal-computing.md)).**
   Use workload contracts and comparative baselines to select trees, filters,
   bitmaps, hash tables, zero-steady-state-allocation slabs, per-morsel resource
   meters ([Milestone 13](13-data-structures-and-performance.md)), 16-byte
   collation-prefixed strings, `comptime`/immutable perfect hashing and vectorized
   Block-Max BM25 search ([Milestone 14](14-vectorized-strings-and-search.md)),
   HyPer-style data-centric push pipeline fusion, per-row-group kernel
   specialization and `transit-app` AOT Zig query compilation
   ([Milestone 15](15-data-centric-compilation-and-specialization.md)),
   declarative Document Profiles (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`) with
   transport-decoupled gateway/connector exchange capture
   ([Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)), and
   orthogonal $\tau \perp \kappa_{\text{spatial}} \perp \epsilon$ geospatial
   types, 16-byte inline MBR headers, topological/cell-covering compression and
   DBSP Z-set incremental spatial operators
   ([Milestone 17](17-geospatial-and-spatio-temporal-computing.md)).
   Deliver statistics and cost-based plans, measure complete durable operations
   under mixed load, and enforce latency, throughput, memory and recovery budgets
   throughout later work.
6. **Cut over live executables and activate derived views, multi-format foreign sources, branches and clustered compute ([Milestones 3](03-live-storage-and-sql-cutover.md)–[26](26-clustered-execution.md)).**
   Wire the storage hierarchy, `.tseg` segments, write-through caches and immediate
   wakeups into the live node, SQL gateway and server executables; formalize shared
   statement outcomes, bounded result consumption, transactions, declarative
   streams/queues, logical `.tseg` documents, direct-plane gateway ingress and early client
   APIs; bind historical catalog snapshots to immutable manifest versions and collations;
   drive maintained SQL views, reactive watches and Station processes directly
   from `TransitLog` (`+row`/`-row`) delta streams; read Parquet, Arrow IPC,
   CSV/JSONL and mainframe fixed/variable (`FB`/`VB`) copybook datasets through
   the shared `Fuze` segment boundary; implement branch creation over complete
   durable snapshots and logical three-way merges over immutable state; qualify
   replication, backup/restore and upgrades; and schedule distributed Station and
   `Fuze` workers over shared object storage with fenced lease handoff.

Handbook publication is implemented. Remaining live-site navigation and recovery
qualification belongs to [qualification](42-qualification-and-benchmarks.md#documentation-publication),
with completed observations in the proof ledger.

## Shared implementation gates

- Name the user-visible declaration, its owner, dependencies, permitted work and
  lifecycle evidence. A healthy process or parsed statement does not fulfill a
  data declaration. State how the user can distinguish publication, unresolved
  work, a complete result and stale or blocked progress.
- Define neutral contracts, ownership, authorization, lifetimes and bounds before
  exposing syntax. Grammar acceptance is separate from executable behavior.
- Preserve exact accepted-operation recovery, current permissions, permanent
  retirement and the distinction between cancellation and uncertainty.
- Keep retained collection size independent of resident memory. Measure provider,
  compute, transport and publication costs separately. Set workload performance
  budgets before optimization, retain correctness oracles and publish comparable
  latency/throughput, memory, amplification and recovery evidence for each slice.
- Apply the [v1 hard-cutover policy](../handbook/reference/versioning.md) to incompatible
  definitions. Never reinterpret accepted work or reset data automatically.
- Run focused proofs and committed-source clean checks. Publish supported
  behavior and measured limits with their public owners as work lands.

Each delivered slice needs an end-to-end acceptance path: describe, validate,
apply, inspect, change and recover through actual public callers. Include denied
access, lost responses, dependency changes, bounded work and incomplete results.
Retain different completion semantics for interactive, captured and maintained
computation; one universal readiness flag is insufficient.

## Maintaining the sequence

Keep one numbered, descriptively named file per milestone (`01-` through `44-`).
Insert or reorder work by updating this index, filenames and links together.
Split work only when it has independently reviewable outcomes and prerequisites.
Keep phase membership contiguous and exhaustive: each milestone appears exactly
once in the ordered sequence. Update the phase overview, milestone groups and
delivery checkpoints together when inserting or moving work. Phase labels and
boundaries describe delivery outcomes; they do not replace numbered milestone
identities, change completion evidence or introduce implicit prerequisites.

When a milestone is complete, keep its file in `docs/roadmap/` and update its
status to `Completed` in both the milestone header and the sequence above, while
promoting all current user-facing behavior and reasoning into its public
handbook owner and recording executed verification in `tests/README.md`.
If review finds an unmet completion criterion, reopen the milestone as
`In Progress`, preserve delivered work and prior evidence, and link the remaining
acceptance work. Merged code, parser support and component tests do not substitute
for the milestone's executable caller and recovery evidence.
