# Roadmap

This roadmap tracks milestone scope, sequencing, acceptance criteria and
completion status for Transit, ordered by dependencies and explicit delivery
priorities, not delivery dates.
The supporting [development workflow implementation plan](development-workflow.md)
records the completed test directory migration, build reuse and feedback
qualification alongside this product sequence.
The supporting [on-demand specialization research workflow](on-demand-specialization-research.md)
investigates verified CPU specialization, Datalog/RTL analysis and optional
hardware execution through Nix-packaged experiments and explicit Platform
handoffs. It adds no milestone or release gate and records no executed result.
The supporting [downstream application language plan](downstream-application-language.md)
maps Platform's identity, GitHub sign-in and publication migrations to current
owners, missing contracts and an ordered implementation/qualification sequence.
It is a proposal for review and changes no milestone status.
The [application Table test runner plan](application-test-implementation.md)
records the delivered bounded M12 slice after the recursive compiler: isolated
Table tests using the production SQL emitter and real local database owners.
The remaining P5 controls and broader milestone remain In Progress.
The [lowered DATAFLOW SQL implementation plan](dataflow-sql-implementation.md)
connects M12's emitted SQL to M13's publication, activation, execution and recovery
owners, starting with the delivered typed Queue-program foundation. It preserves
the finite Table profile and the remaining WAL-history/incremental gates.
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
[qualification plan](45-qualification-and-benchmarks.md#observation-and-consequence-evidence)
defines the proposed measures and comparison method; individual milestones
qualify their contribution as they land. These are evaluation goals, not current
measurements, and they do not assume that modeling or reasoning is solved.

The [planned source/build model](../handbook/reference/applications.md#planned-source-language-and-build-model)
provides the authoring path: recursively compose typed `.transit` modules,
describe builds in that same language, and emit executable `.sql` for statements
or explicit migrations. [M12](12-application-modules-compilation-and-testing.md)
owns source ANTLR grammar, the typed core, effect/ownership/transition contracts
and selected TLA+/Lean correspondence gates alongside that toolchain. Later
compilation and language adapters reuse its semantics rather than introducing
another build or execution authority.
The [source grammar and typed-core slice](application-source-grammar-implementation.md)
adds independent ANTLR/Zig comparisons, embedded SQL and stage checks,
source round-trips and the contract for subsequent language features. The
[typed-target slice](application-typed-target-implementation.md) implements nominal
source values, closed variants, exhaustive compile-time matching and typed
public Table exports, with selected Lean laws and independent SQL execution.
The earlier typed-target record retains its incomplete qualification at that
source. The public Queue build/test foundation subsequently merged in
[PR #450](https://github.com/spoke-sh/transit/pull/450); its final CI results are
reconciled in the [next-slice plan](application-typed-queue-implementation.md#source-basis-and-existing-owners).
That slice implements actionable diagnostics and nominal types through public
Queue programs, with [scoped qualification](../history/qualification/query.md#actionable-source-diagnostics-and-nominal-queue-programs--2026-11-13)
and retained failure evidence. The
[remaining M12 implementation plan](application-remaining-implementation.md)
retains richer typed composition, runtime encapsulation, protected workflows,
migrations and replay qualification.
Dynamic typed commands and reference-only exports remain subsequent work.

## Performance ambition

Our ambition is to make Transit the fastest database and durable runtime for its
supported workloads. Pursue that through measured access paths, efficient data
structures, query planning and runtime execution, with explicit latency,
throughput, memory and recovery targets. Every claim must name its workload,
comparison versions, hardware, resource budgets, durability and isolation.
Measure complete outcomes and sustained mixed load, including background work;
component throughput alone does not establish application performance.

The [indexing milestone](11-indexing-and-access-paths.md) establishes safe shared
access paths. The [data structures and performance milestone](14-data-structures-and-performance.md)
delivers the local workload scorecard, selected optimizations and regression
budgets. Earlier owners establish baselines and meet their existing gates; later
providers, distributed execution and language surfaces extend the same measures.
[Final qualification](45-qualification-and-benchmarks.md) combines the evidence
at one revision. Publish wins, regressions and unresolved competitive gaps with
reproducible results; correctness, current authorization and accepted-work
recovery remain part of every performance profile.

The next implementation sequence for startup and the existing 10–100× SQL
objectives is the [M8 plan after recent milestones](08-gateway-architecture-and-protocol-ingress.md#next-performance-implementation-after-milestones--2026-11-02).
Run the [M9 SDK measurement and optimization sequence](09-client-foundation-and-language-apis.md#sdk-performance-implementation-sequence--2026-11-01)
alongside it using shipped APIs. These plans preserve the milestones' existing
scope and status; SDK gains require their own measured baselines.

## Delivery phases

The [nightly container performance tracker #378](https://github.com/spoke-sh/transit/issues/378)
connects build/deployment boundaries with the
[local-to-distributed performance scorecard](14-data-structures-and-performance.md#nightly-container-scorecard-and-distributed-handoffs).
The first campaign uses the last promoted nightly image, twelve hours after the
release schedule, for single-authority and explicitly independent three-node
controls. M8/M14 own local bottlenecks, M24–M27 add qualified distributed profiles,
and M45/M46 own combined evidence and artifact composition. This cross-milestone
work does not change statuses or qualify replication by running more containers.

Seven phases group the linear milestone sequence by the capability an application
or operator gains. The phase outcomes summarize their milestones' acceptance
criteria; each numbered milestone remains the owner of scope, status and proof.
Read the [delivery checkpoints](#delivery-checkpoints) for the execution plan.

| Phase | Milestones | Exit outcome |
| --- | --- | --- |
| [I: Local data and application foundations](#phase-i-local-data-and-application-foundations) | 1–12 | Applications declare and query local Tables, KV, Documents (backed by `.tseg` succinct trees and shredded subcolumns in `DocumentPartition` with `Station` decoupled), Streams (`PRODUCE INTO` / `CONSUME ... FROM`) and Queues (`ENQUEUE INTO` / `CLAIM ... FROM`), consume complete statement outcomes, compose supported transactions, run `Station` behaviors over database primitives with the database decoupled from actor turns, connect through a formalized event-driven, sans-I/O gateway boundary co-hosted with the Direct Data Plane without `/table/v1` polling cascades, use shared clients with exact historical interpretation and maintained indexes, and compose recursive `.transit` modules through `build.transit`, compile executable `.sql` with `transit build`, synthesize migrations against an explicit prior basis and run deterministic `transit test` suites across workspace and pinned repository dependencies |
| [II: Data composition, performance and interface coverage](#phase-ii-data-composition-performance-and-interface-coverage) | 13–23 | Applications maintain derived data, meet measured local database/runtime, string/search and data-centric compilation performance targets, use the multi-format Document Type Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`, `AMQP`, `MQTT`, `NTP`, `PDF`, `DOCX`, `XLSX`, `ODF`) and unified gateway/connector exchange lifecycle, store and query 2D/3D geospatial, volumetric 3D model, discrete-exterior-calculus cochain field (`COCHAIN_FIELD` / `.float_zfp`), raster and spatio-temporal data (`GEOMETRY`, `GEOGRAPHY`, `MESH3D`, `SOLID3D`, `SCENE3D`, `POINTCLOUD`, `RASTER2D`/`GRID3D`, `S2_CELL`, `H3_CELL`, `OCT_CELL`, `TRAJECTORY`) with topological/Edgebreaker/octree compression and incremental DBSP evaluation, compose native and foreign models, cook and stream interactive 3D game assets and continuum/fluid simulations (`.mesh_cluster_dag`, `.tex_mip_morton`, `.vdb_hierarchy`, `.splat_hilbert`, `SKELETON3D`, `ANIMATION_CLIP`, incremental `NavMesh`/`HLOD` DDC dataflows, CFD differential/isosurface/conservation operators and ECS AoI streaming), work across branches and use the qualified service/SDK matrix with selected formal models and implementation correspondence |
| [III: Distributed durability and operations](#phase-iii-distributed-durability-and-operations) | 24–27 | Operators use qualified providers, replicate and recover complete history, perform verified backup/restore/upgrades and move execution safely |
| [IV: Governed collaboration and Board](#phase-iv-governed-collaboration-and-board) | 28–31 | People and applications inspect published resources, propose and review changes under shared policy and use the installed Board workbench |
| [V: Agents and mixed application composition](#phase-v-agents-and-mixed-application-composition) | 32–35 | Agents and applications use governed MCP access, reactive activation and recorded effects through complete direct, Station and mixed language experiences |
| [VI: Scientific, media and evidence workloads](#phase-vi-scientific-media-and-evidence-workloads) | 36–43 | Applications compose calibrated scientific arrays, synchronized video, attributable ML/AI experiments, robotics replay, software/build/deployment evidence, constrained planning, stratified Datalog/equivalence-graph reasoning and Verilog/RTL/EDA hardware verification over shared versioned data, numerical, policy and publication contracts |
| [VII: Qualification and release](#phase-vii-qualification-and-release) | 44–47 | One committed revision has a harmonized SQL and deductive rule grammar audited against formal standards and industry dialects, combined workload/fault evidence, verified distribution artifacts and runnable installed onboarding, followed by speculative research into declarative language, structural context and corpus-native synthesis |

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
| 3 | [Executable data lifecycles and live storage/SQL cutover](03-live-storage-and-sql-cutover.md) | In Progress ([#110](https://github.com/spoke-sh/transit/issues/110); [allocation slice and remaining qualification, 2026-11-08](03-live-storage-and-sql-cutover.md#next-slice-implementation-plan--2026-11-08)) | Build on installed lifecycles, automatic maintenance and single-executable recovery. Aggregate request/retained-owner admission and independent control, maintenance and collection reserves are delivered with scoped pressure/recovery evidence. Next: combined workload/fault qualification. Broader retention/resource, measured SQL/storage cost, uniform inspection and common-revision gates remain open |
| 4 | [SQL statement results and client consumption](04-statement-results-and-consumption.md#implementation-plan) | Completed | Formal transport-independent result model, shared client consumption, bounded batches/readers and verified completion |
| 5 | [Transactions, consistent snapshots and atomic composition](05-transactions-and-atomic-composition.md) | Completed | Local serializable multi-Table transactions, retained common cuts, savepoints, original decision recovery and Table checkpoint/outbox composition; native KV/Document and Stream/Queue participant extension handed to M6/M7 |
| 6 | [Declarative streams, queues and durable runtime architecture](06-streams-queues-and-durable-runtime.md) | In Progress ([completion plan, 2026-11-12](streams-queues-runtime-completion.md)) | Native logs, Stream/Queue SQL, waits/groups/offsets, predicate-aware claims, automatic DLQ, native `.tseg` log columns, finite `STREAM_SLICE`, Queue checkpoints and mixed SQL transactions are implemented. Batch 5 adds a private transactional Station handler with native execution fencing and installed replacement proofs. PR #451 extracts the shared transaction lifecycle with Station as a consumer. [Owned Table/KV transaction reads](transaction-read-ownership.md) are implemented with scoped installed evidence. Next deliver shared batching/cost qualification and durable service/effect and consumer migration (Batches 6–7), finish Table commit/latency work (Batch 8), and qualify one revision (Batch 9). Preserve M3 resource admission, deadlines and retained capture roots; M7's Document participant gates the full consumer cutover. Broader resource/collection proofs, complete baselines and inherited latency objectives remain open |
| 7 | [Logical document storage, `.tseg` trees and Station decoupling](07-document-storage-and-station-decoupling.md) | In Progress ([remaining implementation plan, 2026-11-05](07-document-storage-and-station-decoupling.md#implementation-plan-for-remaining-work); [next slice: protected source staging and discovery](07-document-storage-and-station-decoupling.md#protected-source-staging-and-operation-discovery-plan--2026-11-05)) | Build on causal maps, conditional ordered trees, retained partition membership/BP inspection and verified JSON/XML/MIME parts. Build on logical deletion and partition guards; implement bounded source staging, verification, recovery and closure, then streaming candidates and direct lifecycle. Follow with Document mixed decisions and SQL using current Stream progress, typed relational results and shared file publication; complete merges, spans, checkpoints, adaptive subcolumns and one coordinated Station/consumer cutover |
| 8 | [Gateway architecture, sans-I/O wire protocols and direct-plane ingress](08-gateway-architecture-and-protocol-ingress.md) | In Progress ([next deadline slice](08-gateway-architecture-and-protocol-ingress.md#next-slice--inherited-command-deadlines-and-cancellation); [remaining implementation plan, 2026-11-05](08-gateway-architecture-and-protocol-ingress.md#implementation-plan--2026-11-05)) | Build on merged HTTP/TLS deadlines and Queue WAIT: carry one command deadline through service/client/local dispatch, preserve original outcomes and joined cancellation, then prove resumable hosting before CPU-based sizing. Configuration, coarse remote SQL, Flight/Serving, M6/M7 handoffs and measured [#211 latency closure](https://github.com/spoke-sh/transit/issues/211) remain open |
| 9 | [Shared client foundation and language-native APIs](09-client-foundation-and-language-apis.md) | In Progress ([remaining implementation plan](09-client-foundation-and-language-apis.md#remaining-implementation-plan--2026-11-01)) | Build on delivered Catalog/SQL context and local recovery storage; complete coordination, ordinary settlement, managed handles, independent bindings and installed language APIs; compose available direct KV/Stream/Queue and native mixed transactions, with Documents gated by M7 |
| 10 | [Standards, collations and historical catalogs](10-standards-and-catalogs.md) | In Progress ([remaining implementation plan, 2026-11-02](10-standards-and-catalogs.md#remaining-implementation-plan--2026-11-02)) | Delivered collations/companion semantics, CHECK/staged-FK definitions, retained catalogs/common cuts, historical SQL/views and shared inspection; close semantic/consumer regressions, recovery/collection and independent-reader evidence, bounded-work checks and common-revision qualification |
| 11 | [Indexing model, access paths and online maintenance](11-indexing-and-access-paths.md) | Planned | Shared index definitions, bounded ordered/covering/partial access, fine-grained key-range SSI conflict tracking, index-backed `FOREIGN KEY` enforcement and recoverable online index/table builds |
| 12 | [Recursive `.transit` modules, SQL compilation, builds and testing](12-application-modules-compilation-and-testing.md) | In Progress | Public Table/Stream/Queue builds, Queue program tests, source grammar and nominal/variant/typed resource exports are implemented; qualification remains source-specific. The [next slice](application-typed-queue-implementation.md) delivers actionable build/test diagnostics, source discovery and nominal types through public Queue programs, with [scoped qualification](../history/qualification/query.md#actionable-source-diagnostics-and-nominal-queue-programs--2026-11-13) and retained failures. The [remaining implementation plan](application-remaining-implementation.md) retains helpers, runtime boundaries, protected workflows, explicit-basis migrations, replacement and replay proofs |

### Phase II: Data composition, performance and interface coverage

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 13 | [Managed computations and WAL-activated dataflows](13-sql-and-dataflows.md) | In Progress ([lowered DATAFLOW SQL plan, 2026-11-10](dataflow-sql-implementation.md); [SOURCE ingestion plan](13-sql-and-dataflows.md#create-source-implementation-plan--2026-11-05); [capture storage and readers](13-sql-and-dataflows.md#next-source-slice-owned-capture-storage-and-readers--2026-11-07)) | Connect lowered Queue DATAFLOW SQL to the delivered typed application runtime through shared publication, migration, activation, recovery and inspection. Preserve finite managed Tables and retained revisions; complete combined finite qualification, transaction-consistent history consumption and incremental execution. Reuse SOURCE capture ownership for fenced HTTP scheduling; deliver analytical/temporal SQL and governed effects through explicit adjacent-owner gates |
| 14 | [Data structures, query optimization and runtime performance](14-data-structures-and-performance.md) | In Progress | Zero-steady-state-allocation hot paths, per-morsel CPU/memory/IOPS metering, LeanStore/Umbra swizzled zero-copy buffer slabs, CedarDB directory-tagged join hash tables & WCOJ, statistics/costing, partitioning/clustering, LSM/`.tseg` compaction bounds and workload scorecards |
| 15 | [First-class strings, perfect hashing and vectorized search execution](15-vectorized-strings-and-search.md) | In Progress ([remaining implementation plan, 2026-11-02](15-vectorized-strings-and-search.md#implementation-plan--2026-11-02); [first implementation slice](15-vectorized-strings-and-search.md#first-implementation-slice-owned-predicate-preparation)) | Build on delivered compact Batch strings, safe lookup and shared encoded traversal: prepare owned predicates, integrate retained operator keys and constant membership; deliver shared index lifecycle and owned searchable generations, vectorized lexical/proximity execution and snapshot-bound hybrid search, with independent inspection and installed recovery/resource/performance qualification; retain biological, chemical and audio search profiles as gated scope |
| 16 | [Data-centric pipeline fusion, AOT query compilation and adaptive specialization](16-data-centric-compilation-and-specialization.md) | Planned | HyPer/CedarDB data-centric push fusion inside vectorized morsels, per-row-group dense non-null specialization, Flying-Start Adaptive Morsel Tier-Up, `transit build` AOT Zig query/view compilation and HyPer/Umbra/CedarDB benchmark baselines |
| 17 | [Document type library, protocol grammars and gateway exchange lifecycle](17-document-profiles-and-gateway-exchange-lifecycle.md) | In Progress ([2026-11-02 plan](17-document-profiles-and-gateway-exchange-lifecycle.md#implementation-plan--2026-11-02); [next increment](17-document-profiles-and-gateway-exchange-lifecycle.md#next-increment-profile-candidates-and-publication-handoff)) | Extend delivered offline JSON/XML/MIME readers/writers, compound commitments and bounded candidates through publication contracts. Qualify M7's ordered/raw-part storage and public lifecycle before SQL exposure; use the common Document/effect decision for exchange cutover. Reuse delivered transaction-owned staging and independent-reader inspection without assuming Document participation. Full protocol/office, search/branch, SIMD/AOT and future evidence-consumer handoffs remain tracked. |
| 18 | [Geospatial types, topological compression, spatial indexing and incremental spatio-temporal queries](18-geospatial-and-spatio-temporal-computing.md) | In Progress ([implementation plan](18-geospatial-and-spatio-temporal-computing.md#implementation-plan--2026-11-01)) | Orthogonal $\tau \perp \kappa_{\text{spatial}} \perp \epsilon$ 2D/3D types (`GEOMETRY`, `GEOGRAPHY`, `MESH3D`, `SOLID3D`, `SCENE3D`, `TRANSFORM3D`, `POINTCLOUD`, `RASTER2D`/`GRID3D`, `SPARSE_MATRIX`, `COCHAIN_FIELD`, `BBOX2D`/`3D`, `S2_CELL`, `H3_CELL`, `OCT_CELL`, `TRAJECTORY`), Shewchuk exact `orient2d`/`3d` predicates & snap-rounding grids, 16B inline 2D/3D MBR vector headers, `.geoarrow`/`.twkb_delta`/`.mesh_edgebreaker`/`.raster_morton`/`.float_zfp`/`.sparse_bcsr` codecs, logical topological shared-arc/face (`.topo_arc`, `.topo_face` + $C^0..C^3$ cochain fields), `INTERIOR`/`BOUNDARY` `S2`/`H3`/`OCT` Roaring coverings (`.s2_roaring`, `.octree_roaring`), instanced `.scene_dag`, 2.5D VLSI `.layout_manhattan`, `.pcloud_hilbert` (including 3D protein/atomic structures & spatial transcriptomics) and 4D/6-DoF trajectory compression, 2D/3D zone maps, `RTREE`/`S2`/`OCTREE` indexes, 2D/3D spatial SSI and DBSP Z-set incremental `ST_Union`, `ST_3DUnion`, `DRC`/`LVS`, Discrete Divergence Theorem volume/flux aggregates and spatial/3D clash joins |
| 19 | [Multi-model and multi-format foreign relations](19-multi-model-and-foreign-relations.md) | Planned | Document/graph/2D-spatial/3D-coboundary projections (with WCOJ cyclic pattern matching), multi-model lexical/structural/vector/2D-3D-spatial hybrid search composition, foreign formats (`Parquet`/`GeoParquet`, `FlatGeobuf`, `COG`, `glTF`/`GLB`, `OpenUSD`, `KTX2`, `OpenVDB`, `IFC`/`STEP`, `3D Tiles`, `LAS`/`LAZ`/`COPC`, `CGNS`/`VTU`/`OpenFOAM`/`Zarr`/`NetCDF`/`GRIB2`, `FASTQ`/`BAM`/`CRAM`/`VCF`/`PDB`/`mmCIF`/`SMILES`/`.h5ad`, `DICOM`/`NIfTI`/`OME-Zarr`, `OASIS`/`GDSII`/`LEF`/`DEF`/`SPICE`, `FLAC`/`WAV`/`MiniSEED`/`EDF+`/`ITCH`, `CSV`/`JSONL`, mainframe `FB`/`VB`), streaming CDC ingress and typed COPY/import/export |
| 20 | [Interactive 3D worlds, game asset pipelines and simulation streaming](20-game-asset-pipelines-and-simulation-streaming.md) | Planned | Orthogonal $\tau \perp \kappa_{\text{asset}} \perp \epsilon$ game/simulation/signal assets (`TEXTURE2D`/`3D`/`CUBEMAP`, `VOLUME_GRID`, `SPLAT3D`, `SKELETON3D`, `ANIMATION_CLIP`, `MATERIAL`, `SHADER_VARIANT`, `WAVEFORM`, `AUDIO_CUE`, `NAVMESH`), virtualized `.mesh_cluster_dag` micropolygon DAGs, `.tex_mip_morton` `BCn`/`ASTC`/`KTX2` virtual texture pyramids, `.vdb_hierarchy` (staggered MAC/AMR/LBM grids) & `.splat_hilbert` codecs, `.skin_weights` & `.anim_acl` pose evaluation, `.wave_lpc_pyramid` audio/waveform envelopes + SIMD spectral/convolution DSP (`DSP_STFT`/`DSP_ConvolveIR`) & qualified gated `LUFS` loudness, WAL-activated Derived Data Cache (DDC) cooking, incremental DBSP `NavMesh` & `HLOD` maintenance, Eulerian/Lagrangian fluid & molecular dynamics (`ST_Gradient`/`ST_Divergence`/`ST_Curl`/`ST_QCriterion`/`ST_IsoSurface`/`ST_Streamlines`, $2h$ Hilbert SPH/MD sweeps, DBSP control-volume conservation & Lift/Drag integrals), and ECS archetype / frustum / progressive `.float_zfp` AoI streaming under fog-of-war Spatial RLS |
| 21 | [Branches, merges and restore](21-branches-merges-and-restore.md) | In Progress ([remaining implementation plan, 2026-11-02](21-branches-merges-and-restore.md#implementation-plan--2026-11-02); [immutable Table increment](21-branches-merges-and-restore.md#local-table-branch-increment)) | Extend delivered immutable Table branches and retained historical cuts through coherent catalog/data publication, writable histories, bounded `DIFF`/`DIFF_SCHEMA`, constraint-checked merge and fenced forward restore; complete multi-model integration, branch-aware compaction/GC and verified remote fetch/mirror/candidate transfer |
| 22 | [Service and SDK coverage](22-service-and-sdk-coverage.md) | In Progress ([SQL type parity plan](22-service-and-sdk-coverage.md#sql-type-parity-and-installed-interface-smoke-loop)) | Preserve Go raw/console slices; qualify shared SQL types through console/psql/mysql with required installed smoke and driver checks, then extend service, language and platform coverage |
| 23 | [Formal semantics and implementation correspondence](23-formal-semantics-and-correspondence.md) | In Progress | Selected temporal models (including `T8` DDL evolution and 5-state dataflow lifecycle) and algebraic proofs over delivered local contracts, connected to production behavior before distributed extensions |

### Phase III: Distributed durability and operations

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 24 | [Storage providers and concurrent-writer qualification](24-storage-providers-and-concurrency.md) | Planned | Real provider/cache profiles, KMS/BYOK envelope encryption at rest, enforceable partitioned authority and distributed fine-grained concurrent-writer qualification |
| 25 | [Replication and durable failover](25-replication-and-failover.md) | Planned | Complete replicated history, transaction decisions and objects, bounded catch-up and fenced failover |
| 26 | [Operations, backup, restore and upgrades](26-operations-and-recovery.md) | Planned | Verified transaction-consistent backups/PITR, authority-safe disaster recovery, upgrades and operational workflows |
| 27 | [Clustered execution and storage-disaggregated placement](27-clustered-execution.md) | Planned | Fenced placement changes and distributed queries preserving qualified transaction, replication and operational contracts |

### Phase IV: Governed collaboration and Board

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 28 | [Enterprise identity and the Control & Policy Plane](28-control-and-policy-plane.md) | In Progress ([implementation plan](28-control-and-policy-plane.md#implementation-plan--2026-10-30); [delivered evidence](28-control-and-policy-plane.md#delivered-implementation-evidence--2026-10-30)) | Trusted enterprise identity, declarative `SECRET` catalog (`CREATE SECRET` / `USAGE ON SECRET`) & OAuth2/PKCE challenge-response dataflows, security-barrier RLS (including spatial RLS), dynamic column masking, GDPR crypto-shredding/purge, Hierarchical Workload Management (WLM) and shared branch/publication policy |
| 29 | [Published business resources and consistent investigations](29-published-resources-and-investigations.md) | In Progress ([implementation plan](29-published-resources-and-investigations.md#implementation-plan--2026-10-30); [delivered evidence](29-published-resources-and-investigations.md#delivered-implementation-evidence--2026-10-30)) | Deliberate resource exposure, disclosure policy and retained multi-call investigation bases |
| 30 | [Versioned proposals and reviewed publication](30-reviewed-data-collaboration.md) | Planned | Comparable branch proposals, branching-only policy and exact reviewed publication |
| 31 | [Board reimplementation and data-first workbench](31-board-reimplementation.md#r3--explain-completed-and-pending-computation) | In Progress | Reactive ownership, automatic local access and R2 readable storage/deferred modules are merged with recorded qualification gaps. R3's plan for review adds independent-reader computation evidence, then linked source/computation/output inspection. R4 retains reliability, resource and accessibility qualification. The [Document persistence plan](31-board-reimplementation.md#local-connections-and-document-persistence-plan--2026-11-02), richer workload inspection and governed changes remain full-milestone obligations |

### Phase V: Agents and mixed application composition

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 32 | [MCP service and interactive Apps](32-mcp-service-and-apps.md) | Planned | Authenticated agent access and optional Apps over shared published capabilities |
| 33 | [Reactive context, subscriptions and agent activation](33-reactive-context-and-agent-activation.md) | Planned | Meaningful change conditions, durable interests and governed version-bound hybrid context through subscriptions/tasks |
| 34 | [Recorded outbound MCP and application guidance](34-recorded-mcp-integrations.md) | Planned | Governed outbound MCP, captured observations, network-free replay and reviewed application guidance |
| 35 | [Language-native programming model and mixed application composition](35-programming-model.md) | Planned | Complete language-native direct, Station and mixed composition over the earlier client/transaction foundation |

### Phase VI: Scientific, media and evidence workloads

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 36 | [Scientific arrays, measurements and reproducible numerical computation](36-scientific-arrays-and-measurements.md) | Planned | Named-axis dense/sparse arrays, units/clocks/calibration, quality and numerical fidelity, dependency-aware kernels and attributable earth-observation/climate/scientific results |
| 37 | [Video and synchronized multimodal timelines](37-video-and-multimodal-timelines.md) | Planned | Versioned media tracks and alignment, bounded indexed decoding, source-bound annotations and authorized temporal inspection/export |
| 38 | [ML/AI features, model artifacts and reproducible experiments](38-ml-ai-and-experiment-provenance.md) | Planned | Knowledge-time-correct features, model/transform/run identities, attributable embeddings and predictions, bounded recovery and exact-basis evaluation/publication |
| 39 | [Robotics, industrial sensing and calibrated replay](39-robotics-and-sensor-replay.md) | Planned | Clock/frame/calibration-aware sensor capture, MCAP/ROS profiles, bounded synchronized replay and candidate evaluation with physical actuation separately authorized |
| 40 | [Software, build and deployment evidence](40-software-build-and-deployment-evidence.md) | Planned | Exact source/dependency/build/test/artifact/deployment evidence, bounded impact queries and candidate checks, with a scoped Spoke Platform integration handoff |
| 41 | [Constrained planning and attributable optimization](41-constrained-planning-and-optimization.md) | Planned | Frozen problems, feasible/optimal/infeasible/unknown outcomes, verified candidates and bounds, bounded solver recovery and reviewed plan publication |
| 42 | [Deductive rules, Datalog fixpoints and equivalence graphs](42-deductive-rules-datalog-and-equivalence-graphs.md) | Planned | Mutually recursive Tarjan-SCC stratified fixpoints, semi-naive DBSP & WCOJ evaluation, monotonic lattice/semiring aggregations, Union-Find (`e-class`) / bounded `egglog` rewrites and inspectable derivation witnesses |
| 43 | [Hardware design, RTL/netlist verification and EDA evidence](43-hardware-design-rtl-and-eda-verification.md) | Planned | Elaborated Verilog/SystemVerilog RTL, netlist, `VCD`/`FST` waveform and `.layout_manhattan` (`GDSII`/`OASIS`/`LEF`/`DEF`) verification, Datalog information-flow/taint & CDC/RDC analysis, incremental DBSP `DRC`/`LVS`, IP spatial-RLS compartmentalization and RTL-to-silicon tape-out provenance |

### Phase VII: Qualification and release

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 44 | [SQL grammar, standards comparison and dialect ergonomics](44-sql-grammar-and-dialect-ergonomics.md) | Planned | Cross-dialect SQL and deductive rule grammar comparison against ISO SQL:2023, ISO SQL/MM Spatial, Datalog (`Soufflé`/`Logica`/`egglog`) and industry dialects (PostgreSQL/PostGIS, DuckDB, Snowflake/Delta, Dolt, ClickHouse, GoogleSQL, Materialize/Flink), compile-time ergonomic desugarings (`FROM`-first queries, `SELECT * EXCLUDE/REPLACE`, `GROUP BY ALL`, `ORDER BY ALL`, multi-head deductive rules, trailing commas), 2-way/3-way `DIFF` & `DIFF_SCHEMA`, standardized 5-state dataflow lifecycle DDL (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`) and actionable dialect diagnostics |
| 45 | [Qualification and complete benchmarks](45-qualification-and-benchmarks.md) | Planned | Combined common-revision workload/fault evidence, full benchmarks and measured CI costs |
| 46 | [Release distribution](46-releases.md) | In Progress | Versioned verified artifacts, matching documentation and runnable installed onboarding |
| 47 | [Declarative language, structural context and corpus-native synthesis research](47-declarative-language-context-and-synthesis.md) | Planned | Speculative research defining declarative span segmentation, multi-scale structural/graph proximity (`NEAR`), context-conditioned continuation and branch-verified agency over swappable physical index and predictor implementations |

Performance measurement and amplification work remains tracked in
[issue #76](https://github.com/spoke-sh/transit/issues/76), alongside the reopened
milestone trackers above.
The [allocation-guidance implementation plan](14-data-structures-and-performance.md#implementation-plan-for-issue-194)
tracks [issue #194](https://github.com/spoke-sh/transit/issues/194), starting with
reusable result delivery and extending zero allocations after warmup through
storage, query execution, strings/search and compilation in milestones 14–16.
Standards, multi-model and branching work is tracked in
[issue #31](https://github.com/spoke-sh/transit/issues/31).

## Terrestrial and orbital logistics — issue 358

[Inbound request #358](https://github.com/spoke-sh/transit/issues/358) requires
FLIGHTPLAN's terrestrial/intermodal transport and D.A.L.E's cislunar/interplanetary
logistics to share versioned frame, trajectory, temporal and routing semantics,
also consumed by SAGA. The request identifies FLIGHTPLAN FP4/FP8/FP9 and SAGA S7
as consumer handoffs. The following additions are **planned acceptance work**;
existing numeric types and offline spatial helpers do not establish application
support. Preserve the numbered sequence and current milestone statuses.

| Requirement | Delivery owner and gate |
| --- | --- |
| Celestial/planetary and parent-relative frames; canonical mm-to-AU unit scaling and explicit epoch transforms | [M18 S0/S1](18-geospatial-and-spatio-temporal-computing.md#reference-contract-and-transform-gates): frame/time/model identities, independent fixtures and current-v1 cutover before persistence/adapters |
| Linear, cubic Hermite and Keplerian trajectories; velocity, radial bounds and conservative conjunction screening | [M18 S9](18-geospatial-and-spatio-temporal-computing.md#s9--implement-finite-trajectories-and-kinematics): bounded evaluation, explicit numerical error and independent orbital/conjunction oracles |
| Propagation delay and bitemporal observation visibility | [M13 R6/P4](13-sql-and-dataflows.md#propagation-delay-and-knowledge-time-joins), composed with M18 S9: emission/reception versus knowledge time, pinned clocks/ephemerides and no future-knowledge leakage |
| Time-dependent resource-constrained shortest paths | [M19 graph delivery](19-multi-model-and-foreign-relations.md#time-dependent-resource-constrained-routing): time windows, waiting/resource resets, sound FIFO/non-FIFO search and complete/incomplete outcomes |
| Fuel/propellant, boil-off and cold-chain numerical rules; coupled logistics optimization | [M41](41-constrained-planning-and-optimization.md#transport-and-orbital-planning): conservative feasibility, exact ledger balance, recoverable candidates/bounds and separately reviewed publication |
| Installed terrestrial and orbital workload parity, recovery and resource evidence | [M45](45-qualification-and-benchmarks.md#terrestrial-and-orbital-logistics-qualification): both journeys at one revision after each owner's focused gates |

Start with the shared frame/unit/time and transition contracts and independent
fixtures. Then deliver finite M18 motion and M13 temporal composition, M19 route
search, and M41 numerical/solver integration. M19 can qualify generic finite
transitions before M41; the complete logistics workload requires their combined
evidence. Keep application vehicle/mission policy and dispatch outside the
database kernel. Do not infer nanometer coordinate accuracy, constant-time orbital
solves or operational flight safety from these planned capabilities.

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
| I | Compose recursive source modules, emit SQL and test applications | 12 | Qualify `build.transit` in the source dialect, typed module interfaces, monorepo/remote locks, bounded evaluation, independent generated-SQL execution, explicit-basis migration synthesis and deterministic `transit test` replay schedules |
| II | Maintain declared computations | 13 | Qualify complete analytical SQL (windows, CTEs, universal `D-Join` subquery unnesting, multi-way joins, sandboxed UDFs), bitemporal `AS OF JOIN`, `CHANGES(...)` CDC egress, service-owned activation, complete-commit change consumption, bounded operator state and recovered completed revisions |
| II | Optimize database and runtime work | 14 | Establish workload/competitor baselines and numeric budgets, deliver zero-steady-state-allocation hot-path arenas, per-morsel CPU/memory/IOPS metering, LeanStore/Umbra swizzled zero-copy buffer slabs, CedarDB ~10-instruction directory-tagged join hash tables & WCOJ, statistics/planning, partitioning/clustering keys, LSM/`.tseg` compaction bounds and scan-resistant caching, and pass installed correctness/resource/performance gates |
| II | Deliver first-class strings, perfect hashing and vectorized search | 15 | Qualify 16B collation-prefixed Umbra/German strings, compressed-domain `.dictionary`/`.fsst` predicates, `comptime`/immutable perfect hashing with 16B SIMD string comparisons, and declarative text/proximity search contracts over swappable `.tseg` index profiles (starting with vectorized 256-doc Block-Max BM25 and hybrid search) |
| II | Deliver data-centric compilation, AOT queries and specialization | 16 | Qualify HyPer/CedarDB data-centric push fusion inside vectorized morsels, per-row-group dense non-null specialization, Flying-Start Adaptive Morsel Tier-Up and `transit build` AOT Zig query/view compilation against HyPer/Umbra/CedarDB (VLDB 2018, JOB and CH-benCHmark) baselines |
| II | Deliver the Document Type Library and gateway exchange lifecycle | 17 | Qualify declarative Document Profiles (`JSON`, `XML`, `HTTP`/`MIME`, `FTP`, `EDI_X12`/`EDIFACT`/`HL7`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`, `AMQP`, `MQTT`, `NTP`) and compound formats (`PDF`, `DOCX`, `XLSX`, `ODF`) over shared SIMD structural scanners, perfect hash vocabularies, container part graphs and `.tseg` subcolumns, and cut `STATION_EXCHANGE_V1` connector/gateway capture over to `DocumentPartition` with causal lineage and transport decoupling |
| II | Deliver geospatial types, topological compression and incremental spatio-temporal queries | 18 | Qualify $\tau \perp \kappa_{\text{spatial}} \perp \epsilon$ (`GEOMETRY`, `GEOGRAPHY`, `MESH3D`, `SOLID3D`, `SCENE3D`, `TRANSFORM3D`, `POINTCLOUD`, `RASTER2D`/`GRID3D`, `COCHAIN_FIELD`, `BBOX2D`/`3D`, `S2_CELL`, `H3_CELL`, `OCT_CELL`, `TRAJECTORY`), Shewchuk exact 2D/3D predicates and snap-rounding grids, 16B inline MBR vector headers, `.geoarrow`/`.twkb_delta`/`.mesh_edgebreaker`/`.raster_morton`/`.float_zfp` codecs, logical topological shared-arc/face (`.topo_arc`, `.topo_face` + $C^0..C^3$ cochains), `INTERIOR`/`BOUNDARY` `S2`/`H3`/`OCT` Roaring cell/octree coverings, `.scene_dag`, `.pcloud_hilbert` and 4D/6-DoF trajectory compression, 2D/3D zone maps, `RTREE`/`S2`/`OCTREE` indexes, 2D/3D spatial SSI and DBSP Z-set incremental `ST_Union`, `ST_3DUnion`, linear volume/flux aggregates and 2D/3D clash joins |
| II | Compose multi-model relations, game asset pipelines, simulation streaming and history | 19–21 | Qualify foreign COPY/projections (`GeoParquet`, `FlatGeobuf`, `COG`, `glTF`/`OpenUSD`/`KTX2`/`OpenVDB`/`IFC`/`STEP`/`3D Tiles`/`COPC`/`CGNS`/`VTU`/`OpenFOAM`/`Zarr`/`NetCDF`), streaming CDC ingress, multi-model lexical/structural/vector/2D-3D-spatial search composition, virtualized `.mesh_cluster_dag` meshlets, `.tex_mip_morton` virtual texture pyramids, `.skin_weights`/`.anim_acl` skeletal animation, WAL-activated DDC cooking, incremental DBSP `NavMesh`/`HLOD` maintenance, CFD differential/isosurface/streamline operators & DBSP conservation/Lift-Drag audits, ECS archetype & frustum AoI streaming, multi-commit branches, branch-aware compaction/GC and conditional forward publication with `FOREIGN KEY`/uniqueness/constraint evidence and measured costs |
| II | Expand qualified interfaces | 22 | Extend the language/service/platform matrix over the existing foundation; preserve delivered Go raw and console evidence and reject unsupported transaction/feed profiles |
| II | Establish formal semantics and correspondence | 23 | Select settled local contracts, execute temporal/algebraic checks with implementation replay or independent fixtures, challenge them with negative controls and assign later extensions |
| III | Qualify distributed infrastructure | 24–27 | Real providers, KMS/BYOK envelope encryption at rest and writer fencing/fine-grained distributed SSI, then replication, backup/PITR/upgrade procedures and automatic placement/distributed queries; repeat transaction and native-owner recovery across each failure profile |
| IV | Establish governed collaboration contracts | 28–30 | Enterprise identity, security-barrier RLS (including spatial RLS), dynamic column masking, GDPR crypto-shredding/purge, Hierarchical Workload Management (WLM), published resources/investigations and exact reviewed publication through independently usable public owners |
| IV | Reimplement the Board workbench | 31 | Deliver the installed data-first interface, bounded profiles/workbooks/spatial-map/lineage views and separately authorized change review; preserve operational inspection and prove real browser/recovery journeys |
| V | Extend agent-host interfaces and activation | 32–34 | MCP/Apps, reactive context and recorded outbound MCP over shared owners; no dependency on Board's frontend or configured credential |
| V | Prove complete application composition | 35 | Installed direct, Station and all mixed capabilities in every claimed language; transaction/turn/checkpoint/effect boundaries and recovery remain explicit |
| VI | Establish scientific measurement and computation contracts | 36 | Qualify named axes, units, clocks, calibration, quality, numerical error and sparse/dense tiled execution; prove conservative pruning and incremental/finite agreement on earth-observation and calibrated-sensor journeys |
| VI | Deliver media, ML/AI and robotics lifecycles | 37–39 | Qualify indexed video/timeline disclosure, exact model/input/evaluation attribution and synchronized sensor replay; exercise gaps, corrections, bounded work, restart and revocation without replaying physical effects |
| VI | Connect evidence, deductive rules and hardware verification to reviewed plans | 40–43 | Qualify source-to-deployment evidence and Platform exchange boundaries, constrained candidate outcomes/bounds, stratified Datalog fixpoints/equivalence graphs with derivation witnesses, and elaborated Verilog/RTL/netlist/layout security (`IFT`/taint, `CDC`, `DRC`/`LVS`) and tape-out provenance separately from external execution |
| VII | Harmonize SQL grammar, standards and dialect ergonomics | 44 | Audit the complete SQL and deductive rule grammar against ISO SQL:2023, ISO SQL/MM Spatial, Datalog and industry dialects (PostgreSQL/PostGIS, DuckDB, Snowflake, ClickHouse, GoogleSQL, Materialize/Flink), qualify compile-time ergonomic desugarings (`FROM`-first queries, `SELECT * EXCLUDE/REPLACE`, `GROUP BY ALL`, `ORDER BY ALL`, multi-head deductive rules, trailing commas, numeric underscores) to canonical `FQP1`/`FDM1` plan bytes, standardize 5-state dataflow lifecycle DDL (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`) and verify actionable foreign-dialect diagnostics before freezing 1.0 qualification |
| VII | Qualify and distribute one revision | 45–46 | Compose workload/fault/performance evidence at one committed revision, then immutable artifacts, matching docs and installed onboarding. Focused correctness gates remain mandatory earlier |
| VII | Explore declarative language, structural context and synthesis | 47 | Speculative post-release research: define declarative span segmentation, multi-scale `NEAR` proximity maps, context-conditioned continuation and branch-verified agency against scalar reference oracles before selecting physical structures |

Track first-three-milestone acceptance and explicitly transferred scope through
#108/#109/#110 and the component issues. Update tracker ownership and links with
this sequence; retain original diagnoses, delivered evidence and incomplete
checks. #123 corrects current documentation as implementation changes, and #124
owns traceable installed acceptance. No planning edit changes their runtime status.

## Declarative application modules, compilation, migration synthesis and testing review — 2026-11-09

A review of the 3,513-line declarative SQL application in Spoke Platform
(`platform/transit/migrations/0001-auth.sql` through `0007-https-endpoints.sql`)
demonstrates that applications built on Transit's declarative SQL surface behave
like multi-module software programs—combining persistent state, HTTP/webhook
ingress, background queue consumers, outbound HTTP/command effects, and JSON
response projections—while lacking the modularity, encapsulation, reusable
abstractions, whole-program static verification, desired-state migration
synthesis, and deterministic unit-testing toolchain expected of a programming
language. [Milestone 12](12-application-modules-compilation-and-testing.md) is
added at the end of **Phase I** (shifting former Milestones 12–46 to 13–47) to
establish that software-engineering foundation before Phase II–VII workload and
interface expansion:

The source/build design uses a higher-order SQL dialect rather than a separate
application command family. All items below are planned:

1. **Use `.transit` for source and `build.transit` for builds in that same language ([D1](12-application-modules-compilation-and-testing.md#d1--one-source-dialect-and-build-graph-executable-sql-outputs)).**
   `transit build` resolves, checks and specializes a program into executable
   Transit `.sql`. The output runs through ordinary statement owners or the
   existing migration lifecycle without source repositories or a build interpreter.
2. **Compose typed modules recursively across workspaces and repositories ([D2](12-application-modules-compilation-and-testing.md#d2--recursive-typed-modules-repository-dependencies-and-explicit-stateful-instances)).**
   Child builds, module-valued parameters and exported constructors use the same
   interfaces as remote dependencies. Separate packages/modules from SQL schemas;
   explicitly bind durable instances. Lock exact revisions/content and transitive
   inputs, record local overrides, and support frozen offline rebuilds. Reject
   dependency cycles and conflicting versions of one stateful instance.
3. **Lower higher-order abstractions to SQL with shared semantics ([D3](12-application-modules-compilation-and-testing.md#d3--composable-compile-time-abstractions-profile-function-guard-procedure)).**
   Typed profiles, functions, guards and procedures expand hygienically with
   source maps. Compile-time work and output are bounded; runtime authorization,
   logical types, definition bindings and transaction boundaries survive emission.
4. **Share whole-program checking and independent SQL execution ([D4](12-application-modules-compilation-and-testing.md#d4--shared-compiler-bounded-evaluation-and-canonical-sql-emission-transit-build)).**
   Block-aware scanning separates file, statement and graph budgets. Capability
   and secret analysis precede emission; reparse generated SQL through ordinary
   compilers and compare definitions/outcomes with hand-expanded equivalents.
5. **Generate immutable migrations against an explicit prior state ([P4](12-application-modules-compilation-and-testing.md#p4--desired-state-to-migration-synthesizer-schemadefinition-diffing-and-create-or-replace-lifecycle)).**
   Build targets compare desired definitions with a declared basis and explicit
   transforms. Existing migration owners apply the frozen SQL and recover original
   work; builds neither apply changes nor recompile accepted migrations.
6. **Run tests through the same graph and SQL emitter ([D6](12-application-modules-compilation-and-testing.md#d6--deterministic-offline-unit-testing-effectclock-simulation-and-yield-point-fault-injection-transit-test)).**
   `transit test` reads `build.transit`, compiles `.test.transit` bodies and executes
   their SQL through isolated real database components. Runner-only clocks, mocks
   and fault schedules preserve uncertainty; simulation is separate from provider
   qualification. Performance objectives remain targets pending measurement.

## Unified LSM, `.tseg` format, branching and provider-cost review — 2026-11-08

A cross-workload review of Transit's six declarative data and computation
primitives (**`TABLE`**, **`KV`**, **`DOCUMENT`**, **`STREAM`**, **`QUEUE`**,
and **`DATAFLOW`**) alongside **zero-copy branching/merging**
([Milestone 21](21-branches-merges-and-restore.md)) and **storage provider unit
economics** across local NVMe, shared POSIX filesystems (AWS EFS / NFSv4), and
disaggregated cloud object stores (S3, S3 Express One Zone, GCS, Cloudflare R2,
Azure Blob in [Milestone 24](24-storage-providers-and-concurrency.md)) confirms
that **no new milestone number is required**. Instead, the unified LSM +
`.tseg` storage evolution is diffused across the existing numbered owners while
preserving [Milestone 3 Decision D1](03-live-storage-and-sql-cutover.md) so the
local cutover closes cleanly:

| Owner | Diffused storage, format, branching and provider-cost scope |
| --- | --- |
| [Milestone 3](03-live-storage-and-sql-cutover.md) | Keep Decision D1 intact to close M3; bound **P4** maintenance/GC and foreground contention across all active direct owners in `DirectStorageGraph` (`TablePartition`, `KVPartition`, `StreamPartition`, `QueuePartition`, `DocumentPartition`, and `DATAFLOW` `TXR1`/`CPR1`/`SOR1`/`DFR1`); isolate high-frequency runtime progress/token updates from cold `DirectCatalog` Partition 0 definition contention in **P5**; and project a unified physical storage inspection schema (`SHOW STORAGE` / Board) across all six workloads in **P6**. |
| [Milestone 6](06-streams-queues-and-durable-runtime.md) | Fold `STREAM` delivery/compaction metadata (`_offset`, `_timestamp` / `visibility_time`, `_tombstone`) into native `.tseg` system columns with monotonic zone maps and `.tdel` Roaring key-compaction vectors (retiring separate `LBMETA01` and `LOGVIEW1` sidecars under the coordinated `.tseg` v1 cutover); coalesce `QUEUE` `.tack` (`TACK0001`) and `QueueIndex` `TDIX` checkpoints behind append-only `TWAL1` delta frames and in-memory timing wheels/lease heaps so individual `CLAIM`/`ACK`/`NACK` turns never trigger small-object `PUT` storms. |
| [Milestone 7](07-document-storage-and-station-decoupling.md) | Flush `DocumentPartition` revisions into native `.tseg` structural column groups—persisted $2N$-bit `BP` topology with two-level $O(1)$ `rank`/`select`/`excess` directory blocks, `DocumentShredder` promoted 5-state subcolumns with zone maps, residual `VARIANT`, and piece-table text spans—paired with WiscKey-style $> 4\text{ KiB}$ immutable raw-part/blob separation. |
| [Milestone 11](11-indexing-and-access-paths.md) | Replace the eager flat full-key `Footer.pk_index` array and 64-bit `bloom_mask: u64` in [`TSeg.zig`](../../packages/zig/transit-fuze/src/TSeg.zig) with a **$\le 64\text{ KiB}$ suffix-range-readable footer** containing per-row-group **Sparse Fence Pointers (`min_key`, `max_key`, `page_offset`)**, **Split-Block Bloom Filters** (~10 bits/key), and optional minimal-perfect-hash equality directories so cold segments open in 1 suffix range read (`Range: bytes=-65536`) and point lookups require at most 1 page read. |
| [Milestone 13](13-sql-and-dataflows.md) | Replace custom `DFP1` (64-row / 128 KiB) dataflow result page blobs with standard `.tseg` segments carrying a native `@weight: i64` multiplicity system column, unifying `ManagedTable` materialized revisions (`DFR1`) and `FuzeDelta` DBSP operator arrangements under the same LSM `.tseg` writer, zone maps and net-zero (`@weight == 0`) compaction engine. |
| [Milestone 14](14-data-structures-and-performance.md) | Cut `KVPartition` and `TablePartition` over from per-turn global Copy-on-Write `TreeStore` (`TDIX`) B-tree page rewrites (`rows`, `scan_rows`, `identities`, `ordered_rows`) to a **true LSM-tree (`TWAL1` + bounded Memtable + leveled `.tseg` manifest + `.tdel` deletion vectors)**; eliminate mandatory read-before-write on blind `KV` `put`/`remove` via first-class LSM tombstone tags in `.tseg`; and add **WiscKey-style out-of-line value blob segments** for values $> 4\text{ KiB}$ so compaction merges only compact `(key, lsn, 57B_locator)` entries. |
| [Milestone 21](21-branches-merges-and-restore.md) | Execute $O(1)$ branch creation and sublinear 3-way `DIFF`/`MERGE` directly over LSM `.tseg` manifests, branch-scoped `.tdel` overlays, shared WiscKey value blobs and pinned unflushed `TWAL1` tails; splice disjoint `.tseg` segments/row-groups via sparse fence pointers and Split-Block Bloom filters; record **authenticated compaction lineage** ($\{S_1, S_2\} \xrightarrow{\text{compact}} S_{12}$) and **branch-aware compaction watermarks** ($\tau_{\text{del}}$ vs. pinned branch retention cost); and incrementally activate/merge branch `DATAFLOW`s by feeding branch delta `.tseg` Z-set runs (`@weight = +1/-1`) into shared base arrangements. |
| [Milestone 24](24-storage-providers-and-concurrency.md) | Enforce the six provider latency and cloud-cost invariants across **Local NVMe/EBS**, **Shared POSIX (AWS EFS / NFSv4)**, and **Disaggregated Cloud Object Storage (S3, S3 Express, GCS, R2, Azure Blob)**: `fallocate` pre-allocated `64 MiB` `TWAL1` segments (1 `fdatasync`, 0 directory syncs per turn), zero foreground object `PUT`s, coalesced `.tdel`/`.tack` flushes, 1-RTT `64 KiB` suffix-range footer `GET`s, `64 KiB` SHA-256-verified `NvmeCache` page alignment (shielding EFS `$0.03/GiB` and S3 `GET` fees), and WiscKey compaction bandwidth bounds. |

## Deductive Datalog rules, equivalence graphs and Verilog/EDA hardware verification review — 2026-11-01

A review of how Datalog deductive reasoning and Verilog/EDA hardware design
intersect with Transit's [DBSP dataflows](13-sql-and-dataflows.md),
[Worst-Case Optimal Joins (`WCOJ` / `FreeJoin`)](14-data-structures-and-performance.md),
[AOT query compilation](16-data-centric-compilation-and-specialization.md),
[2.5D `.layout_manhattan` and `COCHAIN_FIELD` spatial/continuum storage](18-geospatial-and-spatio-temporal-computing.md),
[multi-model foreign projections](19-multi-model-and-foreign-relations.md),
[zero-copy branches and `DIFF`](21-branches-merges-and-restore.md),
[security-barrier and spatial RLS](28-control-and-policy-plane.md),
[software/artifact provenance](40-software-build-and-deployment-evidence.md),
[constrained optimization](41-constrained-planning-and-optimization.md) and
[branch-verified agency](47-declarative-language-context-and-synthesis.md)
identifies two independently reviewable Phase VI workload owners—[Milestone 42](42-deductive-rules-datalog-and-equivalence-graphs.md)
and [Milestone 43](43-hardware-design-rtl-and-eda-verification.md)—shifting
Phase VII to `43–46`:

1. **Elevate `Fuze`'s recursive evaluator to stratified Datalog fixpoints, monotonic lattice aggregations, Union-Find equivalence classes (`e-graphs`) and derivation witnesses ([Milestone 13](13-sql-and-dataflows.md), [Milestone 14](14-data-structures-and-performance.md), [Milestone 42](42-deductive-rules-datalog-and-equivalence-graphs.md), [Milestone 44](44-sql-grammar-and-dialect-ergonomics.md)):**
   Standard single-table SQL `WITH RECURSIVE` cannot directly express mutually
   recursive rule systems, monotonic lattice accumulation inside recursion, or
   compact equivalence-class unification without $O(N^2)$ transitive closure
   materialization. [Milestone 42](42-deductive-rules-datalog-and-equivalence-graphs.md)
   extends `Fuze` and DBSP with Tarjan-SCC stratification (rejecting
   unstratifiable negative/non-monotonic cycles before admission), semi-naive
   differential evaluation over WCOJ (`FreeJoin`) cyclic bodies, monotonic
   join-semilattice accumulators ($\langle L, \sqcup, \bot \rangle$ for taint
   labels, reachability and tropical $(\min, +)$/$(\max, +)$ path bounds), paged
   Union-Find (`e-class`) congruence tables and bounded `egglog` equality
   saturation, and RLS-checked derivation witness DAGs (`WITH PROVENANCE`).
2. **Unify Verilog/SystemVerilog RTL, gate/SPICE netlists, `VCD`/`FST` waveforms and 2.5D `.layout_manhattan` physical layouts under incremental Datalog verification and tape-out provenance ([Milestone 18](18-geospatial-and-spatio-temporal-computing.md), [Milestone 19](19-multi-model-and-foreign-relations.md), [Milestone 40](40-software-build-and-deployment-evidence.md), [Milestone 41](41-constrained-planning-and-optimization.md), [Milestone 43](43-hardware-design-rtl-and-eda-verification.md), [Milestone 47](47-declarative-language-context-and-synthesis.md)):**
   [Milestone 43](43-hardware-design-rtl-and-eda-verification.md) projects
   elaborated RTL hierarchy, sequential/combinational cones and netlists into
   versioned tables and SQL/PGQ graphs alongside `VCD`/`FST` digital waveforms
   and `.layout_manhattan` (`GDSII`/`OASIS`/`LEF`/`DEF`) geometry. It expresses
   Hardware Information Flow Tracking (`IFT` / taint analysis), Clock- and
   Reset-Domain Crossing (`CDC`/`RDC`), combinational loop detection, static
   timing depth bounds, incremental `DRC` and graph-based `LVS` as WAL-activated
   DBSP / Datalog computations—enabling branch-isolated ECOs, spatial-RLS IP
   macro compartmentalization, RTL-to-GDSII Trojan/provenance audits and
   deterministic `VERIFY` gates for agent-assisted hardware synthesis.

## Scientific, media and evidence workload expansion — 2026-11-01

Add eight independently reviewable milestones after the common application
foundation and before combined qualification. Each is Planned and defines its
own contract, caller journey, resource bounds and recovery/disclosure evidence.
Earlier delivered scope and unfinished gates are preserved. The existing audio,
biology, EDA, medical-imaging and simulation plans remain with M15/M18–M20;
new shared contracts generalize their interpretation and computation boundaries.

| Shared concern | Owning extension | Consumer obligations |
| --- | --- | --- |
| Measurement interpretation and numerical fidelity | [M36](36-scientific-arrays-and-measurements.md) | Preserve units, named axes, clock/frame/calibration revisions, quality separate from five-state interpretation, and conservative error bounds |
| Computation dependencies and derivation | [M13](13-sql-and-dataflows.md) lifecycle; [M36](36-scientific-arrays-and-measurements.md) numerical/window/halo/frontier profiles | Bind exact source basis, executable/model/parameters, retained artifacts and complete output; qualify incremental updates or bounded recomputation |
| Synchronized media | [M37](37-video-and-multimodal-timelines.md) | Preserve frame/sample/byte coordinates, decode dependencies, uncertainty and current authorization across metadata, previews and exports |
| Model and experiment attribution | [M38](38-ml-ai-and-experiment-provenance.md) | Prevent future-knowledge leakage, distinguish predicted from observed evidence, bind model/transform/evaluation versions and keep application policy above Transit |
| Sensor episodes and replay | [M39](39-robotics-and-sensor-replay.md) | Preserve gaps, clock/calibration changes and replay progress; require separate authority and qualification for physical actions |
| Software evidence and Platform exchange | [M40](40-software-build-and-deployment-evidence.md) | Bind exact source/build/test/artifact/deployment identities, preserve incomplete evidence and leave hosting/product policy with Platform |
| Constrained planning | [M41](41-constrained-planning-and-optimization.md) | Distinguish feasible, optimal, infeasible and unknown search, retain bounds/tolerances and review exact candidates separately from effects |
| Deductive rules, Datalog and equivalence graphs | [M42](42-deductive-rules-datalog-and-equivalence-graphs.md) | Stratify mutually recursive rules, reject negative cycles, distinguish complete fixpoints from budget prefixes, bound Union-Find/`e-graph` state and check RLS on derivation witnesses |
| Hardware design, RTL and EDA verification | [M43](43-hardware-design-rtl-and-eda-verification.md) | Bind elaborated RTL, netlists, waveforms and `.layout_manhattan` masks to exact snapshots; verify taint/CDC/DRC/LVS incrementally, compartmentalize IP via RLS and preserve RTL-to-silicon provenance |

The first cross-domain demonstrator is calibrated sensor replay: capture raw
samples and a camera interval, bind calibration, derive features, inspect an
event, revise calibration on a branch and identify changed results. Reopen the
original basis after restart, revoke access during disclosure and prove replay
sends no device command. M36 supplies the numerical slice; M37 and M39 qualify
the complete synchronized journey. Software evidence, deductive Datalog rules and
hardware RTL/EDA verification can progress independently of video/robotics
kernels once their explicit prerequisites are qualified.

Phase VI does not require every earlier numbered milestone as an implicit
technical dependency. Owners can settle contracts and deliver independent slices
as their actual prerequisites become executable. Existing minimum authorization,
bounded work and recovery requirements remain gates in every phase.

This insertion (together with M42–M43) moves the former M36 grammar, M37
qualification, M38 release and M39 synthesis-research owners to M44, M45, M46
and M47 respectively. Phase VII retains their statuses and obligations. The
post-release synthesis research is separate from M38's concrete
model/feature/experiment lifecycle. No planning edit establishes implemented
support, new benchmark results or Platform readiness.

## Interactive 3D worlds, game asset pipelines and simulation streaming review — 2026-11-01

A review of game-engine asset storage and real-time simulation streaming against
[Milestone 18](18-geospatial-and-spatio-temporal-computing.md),
[Milestone 19](19-multi-model-and-foreign-relations.md),
[Milestone 13](13-sql-and-dataflows.md),
[Milestone 14](14-data-structures-and-performance.md) and
[Milestone 21](21-branches-merges-and-restore.md) identifies that while
[Milestone 18](18-geospatial-and-spatio-temporal-computing.md) establishes the
computational-geometry, topological-compression (`.topo_arc`, `.topo_face`,
`.mesh_edgebreaker`, `.octree_roaring`), rigid-body `.scene_dag`, 2D/3D tiled
raster (`.raster_morton`) and DBSP spatial foundation, 75–85% of a modern game
or simulation engine's asset pipeline and runtime activation involves
non-geometric or deformable assets, target-profile cooking caches and
frame-budgeted Area-of-Interest (AoI) streaming. Inserting
[Milestone 20](20-game-asset-pipelines-and-simulation-streaming.md) in Phase II
(after [Milestone 19](19-multi-model-and-foreign-relations.md) and before
[Milestone 21](21-branches-merges-and-restore.md)) shifts the sequence to
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
2. **Transactional Derived Data Cache (DDC) and target-profile asset cooking over WAL-activated DBSP dataflows ([Milestone 13](13-sql-and-dataflows.md), [Milestone 20](20-game-asset-pipelines-and-simulation-streaming.md), [Milestone 21](21-branches-merges-and-restore.md)):**
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
   [Milestone 18's](18-geospatial-and-spatio-temporal-computing.md) `.topo_face`
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
   Arrow Flight and [Milestone 33](33-reactive-context-and-agent-activation.md)
   reactive subscriptions directly from swizzled `NvmeCache` slabs, and enforce
   fog-of-war / anti-cheat visibility at the storage/query security barrier via
   [Milestone 28's](28-control-and-policy-plane.md) 3D Spatial RLS.
5. **Topology-decoupled Discrete Exterior Calculus (DEC) / Finite-Volume cochain fields (`COCHAIN_FIELD`), error-bounded bitplane float compression (`.float_zfp`) and continuum / fluid simulation streaming ([Milestone 18](18-geospatial-and-spatio-temporal-computing.md), [Milestone 19](19-multi-model-and-foreign-relations.md), [Milestone 20](20-game-asset-pipelines-and-simulation-streaming.md)):**
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
   [Milestone 19](19-multi-model-and-foreign-relations.md), and deliver staggered
   MAC / 2:1 AMR / `D3Q19`–`D3Q27` LBM grids, $2h$ Hilbert SPH particle neighbor
   sweeps, fused face-sweep `ST_Gradient` / `ST_Divergence` / `ST_Curl` /
   `ST_QCriterion` / `ST_IsoSurface` / `ST_Streamlines` kernels, incremental DBSP
   control-volume conservation residuals ($(+\Phi_f) + (-\Phi_f) = 0$) and wall
   Lift/Drag force integrals, and 5-state `IS TYPE_ERROR` CFL/divergence blowup
   diagnostics in [Milestone 20](20-game-asset-pipelines-and-simulation-streaming.md).
6. **Computational biology, genomics, structural proteomics, cheminformatics, audio/acoustic wave DSP, medical imaging and 2.5D EDA/VLSI chip layouts ([Milestone 13](13-sql-and-dataflows.md), [Milestone 15](15-vectorized-strings-and-search.md), [Milestone 18](18-geospatial-and-spatio-temporal-computing.md), [Milestone 19](19-multi-model-and-foreign-relations.md), [Milestone 20](20-game-asset-pipelines-and-simulation-streaming.md)):**
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
     volume projections under [Milestone 28](28-control-and-policy-plane.md)
     HIPAA/GDPR security-barrier RLS and dynamic PHI masking, and linear DBSP
     Z-set Limit-Order-Book (`LOB`) depth maintenance in
     [Milestone 13](13-sql-and-dataflows.md).

## Geospatial computing, 3D volumetric models, logical topological compression and companion data-type formalization review — 2026-10-29

An architectural review of 2D/3D geospatial, volumetric 3D model and
spatio-temporal computing across
[`types.md`](../handbook/reference/sql/types.md),
[`query-engine.md`](../handbook/internals/query-engine.md),
[Milestone 10](10-standards-and-catalogs.md),
[Milestone 11](11-indexing-and-access-paths.md),
[Milestone 13](13-sql-and-dataflows.md),
[Milestone 14](14-data-structures-and-performance.md),
[Milestone 15](15-vectorized-strings-and-search.md) and
[Milestone 17](17-document-profiles-and-gateway-exchange-lifecycle.md)
identifies why 2D/3D spatial data behaves like a graded **Cellular Chain Complex
($C_0, C_1, C_2, C_3$)** with boundary operators $\partial_k: C_k \to C_{k-1}$
satisfying $\partial_{k-1} \circ \partial_k = 0$ (planar subdivisions as DCELs
over $(C_0, C_1, C_2)$, 3D manifold meshes and B-Rep solids over
$(C_0, C_1, C_2, C_3)$ with coboundary $\delta_2 = \partial_3^\top$ room/part
adjacency graphs, discrete grids/octrees `S2`/`H3`/`OCT_CELL` as hierarchical
trees and $k$-regular neighbor graphs, and spatial/3D clash joins as bipartite
intersection graphs) while requiring explicit manifold, metric and
topological-robustness guarantees. Inserting
[Milestone 18](18-geospatial-and-spatio-temporal-computing.md) in Phase II
(after [Milestone 17](17-document-profiles-and-gateway-exchange-lifecycle.md)
and before [Milestone 19](19-multi-model-and-foreign-relations.md)) shifts the
sequence to `1–37` and establishes four architectural commitments:

1. **Formalize 2D & 3D Spatial Types ($\tau \perp \kappa_{\text{spatial}} \perp \epsilon$) alongside companion Range, Dense Vector, Decimal Arithmetic and Pinned-TZ Timestamp types ([Milestone 10](10-standards-and-catalogs.md), [Milestone 18](18-geospatial-and-spatio-temporal-computing.md)):**
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
   cell coverings, unified with [Milestone 13's](13-sql-and-dataflows.md)
   `PERIOD FOR valid_time`), unboxed **`VECTOR(dim, elem_type)`** with
   $\kappa_{\text{metric}}$ (`L2_SQUARED`, `COSINE`, `DOT_PRODUCT`, `HAMMING`),
   deterministic **`DECIMAL(p, s)` arithmetic scale/rounding rules**
   ($\kappa_{\text{numeric}}$), and **`TIMESTAMPTZ` bound to a manifest-pinned
   IANA `tzdb` version digest** ($\kappa_{\text{tz}}$).
2. **Logical 2D & 3D compression in concert with the DBSP / Z-set incremental engine ([Milestone 13](13-sql-and-dataflows.md), [Milestone 18](18-geospatial-and-spatio-temporal-computing.md), [Milestone 23 A3](23-formal-semantics-and-correspondence.md#a3-incremental-dataflow-equivalence)):**
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
3. **16-byte inline spatial headers in `Batch.zig`, 2D/3D zone maps and 2D/3D spatial SSI ([Milestone 11](11-indexing-and-access-paths.md), [Milestone 14](14-data-structures-and-performance.md), [Milestone 18](18-geospatial-and-spatio-temporal-computing.md)):**
   Equip `Fuze` vectors with a **16-byte Inline Spatial Header**
   (`[subtype_and_flags: u16][srid_id: u16][hilbert_s2_or_oct_prefix: u32][quantized_mbr_or_inline_xy: 8B]`)
   so 2D points stay inline and 2D/3D polylines, polygons, meshes and solids
   reject $>95\%$ of non-intersecting candidates in SIMD registers before
   touching `.geoarrow` or `.mesh_edgebreaker` buffers; add 2D/3D `.tseg`
   bounding-box zone maps (`BBOX2D`/`BBOX3D`), static 2D/3D Hilbert R-trees
   (`USING RTREE`), inverted `S2`/`H3`/`OCT_CELL` Roaring indexes (`USING S2` /
   `USING H3` / `USING OCTREE`), and **2D/3D bounding-box / Hilbert-interval
   Serializable Snapshot Isolation (SSI)** conflict tracking.
4. **Diffuse 2D/3D spatial and type guarantees across multi-model foreign formats, branches, security-barrier RLS, Board and formal proofs ([Milestones 17–34](17-document-profiles-and-gateway-exchange-lifecycle.md)):**
   Unify [Milestone 17's](17-document-profiles-and-gateway-exchange-lifecycle.md)
   `PDF` `(page_no, bbox, span)` layout boxes, `GeoJSON` and `GML`/`KML` with
   `BBOX2D` / `GEOMETRY`; add 2D (`GeoParquet` v1.1, `FlatGeobuf`, `GeoArrow`,
   `PMTiles`/`MVT`) and 3D (`glTF`/`GLB`, `OpenUSD`, `IFC`, `STEP`, `CityJSON`,
   `OGC 3D Tiles 1.1`, `LAS`/`LAZ`/`COPC`) foreign adapters, 3D coboundary dual
   graphs and Geo-/3D-Filtered Hybrid Search in
   [Milestone 19](19-multi-model-and-foreign-relations.md); add 2D/3D segment
   skipping and topological/clash `IS CONFLICT` cells in
   [Milestone 21](21-branches-merges-and-restore.md); extend Lean 4 pruning,
   codec and DBSP delta proofs (`A2`/`A3`/`A5`) in
   [Milestone 23](23-formal-semantics-and-correspondence.md); enforce 2D/3D
   Spatial RLS in [Milestone 28](28-control-and-policy-plane.md); render
   read-only 2D map, progressive-LOD 3D scene/mesh/point-cloud and `DIFF`/clash
   layers in [Milestone 31](31-board-reimplementation.md); and audit ISO SQL/MM
   Spatial (`ST_*` / `ST_3D*`) in
   [Milestone 44](44-sql-grammar-and-dialect-ergonomics.md).

## SQL grammar, standards comparison, dialect ergonomics and dataflow lifecycle review — 2026-10-29

A pre-release review of Transit's SQL grammar surface
([`grammar-surface.md`](../handbook/reference/sql/grammar-surface.md),
[`contracts/sql/README.md`](../../contracts/sql/README.md)), managed
computation lifecycle ([Milestone 13](13-sql-and-dataflows.md)), branching/diff
semantics ([Milestone 21](21-branches-merges-and-restore.md)) and formal
verification scope ([Milestone 23](23-formal-semantics-and-correspondence.md))
establishes four architectural refinements:

1. **Explicit five-state dataflow lifecycle (`Published`, `Authorized`, `Active`, `Suspended`, `Retired`), DDL and `T8` TLA+ formalization:**
   While ISO SQL:2023 defines no standard lifecycle grammar for continuous
   queries or materialized views—and vendor engines split between boolean trigger
   toggles (`ENABLE` / `DISABLE` in PostgreSQL/Oracle) and stateful compute
   controls (`SUSPEND` / `RESUME` / `REFRESH` in Snowflake Dynamic Tables and
   Tasks)—collapsing a stateful dataflow into a boolean `ENABLE` / `DISABLE` flag
   leaves authorization, checkpointed `TransitLog` (`TWAL1`) watermarks,
   snapshot-to-live handoffs and read behavior while paused ambiguous.
   [Milestone 13](13-sql-and-dataflows.md) now explicitly specifies the
   five-state computation lifecycle (`Published`, `Authorized`, `Active`,
   `Suspended`, `Retired`) and its DDL verbs (`ACTIVATE`, `SUSPEND`,
   `RESUME WITH (on_resume = 'replay_history' | 'recompute_snapshot')`,
   `REFRESH`, `RETIRE`), preserving checkpointed watermarks and serving the last
   completed revision with its frozen source basis while `Suspended`.
   [Milestone 23](23-formal-semantics-and-correspondence.md#t8-catalog-ddl-evolution-and-dataflow-lifecycle-state-machines)
   adds **`T8. Catalog DDL evolution and dataflow lifecycle state machines`
   (`DdlAndDataflowLifecycle.tla`)** to model and replay the interleaving of lazy
   and phased online DDL (`DefinitionId` transitions) with `Suspended`/`Active`
   dataflows, `_lease_epoch` worker fencing, `TWAL1` compaction and
   `policy_epoch` revocations.
2. **First-class relational and schema `DIFF` (`DIFF(...)` and `DIFF_SCHEMA(...)`) over `.tseg` segment skipping and 5-state `IS CONFLICT` cells:**
   Unlike ISO SQL `EXCEPT [ALL]` (one-way, primary-key blind and schema-rigid) or
   table-doubling diff functions (`from_<col>` / `to_<col>`),
   [Milestone 21](21-branches-merges-and-restore.md) and
   [Milestone 44](44-sql-grammar-and-dialect-ergonomics.md) define key-aligned
   two-way and three-way `DIFF(object, ...)` and `DIFF_SCHEMA(...)` table-valued
   functions that skip shared `.tseg` segments and `.tdel` bitmaps in $O(1)$
   ([`A4: BranchMergeAlgebra.lean`](23-formal-semantics-and-correspondence.md#a4-logical-merge-and-safe-segment-skipping)),
   project across column renames via stable `ColumnId` lineage, and surface
   three-way cell-level merge conflicts natively through Transit's five-state
   `conflict` tag (`WHERE col IS CONFLICT`).
3. **Git-like remote $\leftrightarrow$ local incremental mirroring, lazy `.tseg` hydration and branch proposal push ("Git remotes for data"):**
   Because committed state forms a content-addressed Merkle DAG (`manifest/v{N}`
   commits $\to$ `DefinitionId` catalog trees $\to$ immutable SHA-256 `.tseg`
   blobs and `.tdel`/`.tack` bitmaps plus `TWAL1` delta tails),
   [Milestone 21](21-branches-merges-and-restore.md),
   [Milestone 25](25-replication-and-failover.md) and
   [Milestone 30](30-reviewed-data-collaboration.md) support attaching a local or
   staging Transit instance to an upstream remote (`CREATE REMOTE`, `FETCH`,
   continuous `MIRROR`) under current `policy_epoch` RLS/masking filters,
   transferring only missing `.tseg`/`.tdel` deltas, testing schema migrations
   and fenced dataflows on a local branch, and pushing the delta segments and
   candidate manifest back to the remote as a reviewed proposal.
4. **Pre-release cross-dialect grammar comparison and DuckDB-style ergonomic desugaring ([Milestone 44](44-sql-grammar-and-dialect-ergonomics.md)):**
   The grammar owner is now [Milestone 44](44-sql-grammar-and-dialect-ergonomics.md)
   at the start of Phase VII, after the scientific/media/evidence workload
   phase and before [qualification](45-qualification-and-benchmarks.md) and
   [release](46-releases.md). It audits the
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
   [Milestone 17's](17-document-profiles-and-gateway-exchange-lifecycle.md)
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
[Milestone 17](17-document-profiles-and-gateway-exchange-lifecycle.md) in Phase II
(after [Milestone 15](15-vectorized-strings-and-search.md) and
[Milestone 16](16-data-centric-compilation-and-specialization.md)) shifts the
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
2. **Deliver a declarative Document Type Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`, `AMQP`, `MQTT`, `NTP`, `PDF`, `DOCX`, `XLSX`, `ODF`) over a shared suite of `.tseg` and `Fuze` data structures ([Milestone 17](17-document-profiles-and-gateway-exchange-lifecycle.md)):**
   Define structured documents (`JSON`, `XML`, `EDI_X12`/`EDIFACT`/`HL7`),
   application protocols (`HTTP`/`MIME`, `FTP`, `SMTP`/`IMAP`/`POP3`,
   `LDAP`/`LDIF`, `SIP`/`SDP`, `AMQP`, `MQTT`, `NTP` fixed-point clock
   exchanges) and compound office/publishing containers (`PDF` `xref`/`COS` +
   spatial page spans, `DOCX`/`ODF` `OPC`/`ZIP` XML part graphs, and `XLSX`/`ODS`
   workbooks mapping `sharedStrings.xml` to `.tseg` `.dictionary` tables and
   worksheets to five-state relational `Table` views) as parameterized
   **Document Profiles** sharing zero-allocation SIMD structural/TLV scanners,
   [Milestone 15's](15-vectorized-strings-and-search.md) 16-byte Umbra/German
   collation-prefixed strings (`utf8_binary`, `ascii_ci`, `ebcdic_cp037`,
   `icu:<locale>`) and `comptime`/segment-sealed perfect hash vocabularies,
   [Milestone 16's](16-data-centric-compilation-and-specialization.md) AOT Zig
   grammar/shredder specialization, and non-aborting five-state validation (where
   malformed fields, EDI segments or `#REF!`/`#DIV/0!` spreadsheet cells become
   `type_error` cells with exact `(part_id, byte_start, byte_end, rule_id)`
   provenance into the preserved raw frame).
3. **Unify Gateway and Connector exchange capture with `Document` lifecycle and history while keeping transport and storage decoupled ([Milestone 17](17-document-profiles-and-gateway-exchange-lifecycle.md)):**
   Gateways and Connectors own **Transport, TLS, Authentication, Flow Control
   and Effect-Attempt Fencing** (*Process & Effect Plane*), while
   `DocumentPartition` owns **Representation, Staging, Lineage & Queryability**
   (*Direct Data Plane*). Cut [`STATION_EXCHANGE_V1.md`](../../contracts/STATION_EXCHANGE_V1.md)
   outbound connector capture and inbound gateway admissions over to linked
   `DOCUMENT` revisions (and `STREAM`s/`QUEUE`s of `DOCUMENT`s) in
   `DocumentPartition`, preserving SHA-256 coverage commitments, `SecretRef`
   credential redaction, unknown-outcome fencing and network-free replay while
   making every HTTP, FTP, EDI, XML and JSON exchange directly queryable in
   `Fuze` SQL and [Board](31-board-reimplementation.md).

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
     [Milestone 13](13-sql-and-dataflows.md) read bounded historical `.tseg`
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
execution and buffer management refines [Milestone 13](13-sql-and-dataflows.md) and
[Milestone 14](14-data-structures-and-performance.md) and inserts two dedicated
Phase II milestones—[Milestone 15](15-vectorized-strings-and-search.md) and
[Milestone 16](16-data-centric-compilation-and-specialization.md)—shifting the
subsequent milestones to `13–30`:

1. **Zero steady-state heap allocation on hot paths, LeanStore/Umbra zero-copy buffer management and fine-grained per-morsel resource metering ([Milestone 3](03-live-storage-and-sql-cutover.md), [Milestone 14](14-data-structures-and-performance.md), [Milestone 28](28-control-and-policy-plane.md)):**
   Rather than fixed total-cardinality static arrays that would violate Transit's
   paged durable-state model, hot paths target zero steady-state OS/heap allocations
   after warmup by pairing pre-allocated subsystem slabs with explicit `scratch`
   (reset per step/page with `.retain_capacity`) and `output` arenas.
   [Milestone 3](03-live-storage-and-sql-cutover.md) (P5) and
   [Milestone 4](04-statement-results-and-consumption.md) replace per-row
   `OwnedRow` arena churn on storage/SQL read paths with batch-reused arenas and
   borrowed verified slices; [Milestone 14](14-data-structures-and-performance.md)
   enforces counting-allocator regression gates, 64-byte cache-line alignment and
   L1d/L2 working-set budgets across `Fuze` vectors and `.tseg` pages, and upgrades
   [`NvmeCache`](../../packages/zig/transit-storage/src/NvmeCache.zig) using
   **LeanStore/Umbra pointer swizzling, optimistic version-latched zero-copy
   slices over variable size-class slabs ($64\text{ KiB}\text{–}1\text{ MiB}$)
   and admission-only SHA-256 verification** (eliminating per-hit SHA-256
   recomputation and `@memcpy` overhead). Taking inspiration from
   [Egres](https://manishrjain.com/egres/),
   [Milestone 14](14-data-structures-and-performance.md) and
   [Milestone 28](28-control-and-policy-plane.md) chain a hierarchical
   `MeteredAllocator` vtable with per-`Batch` morsel CPU cycle/tick and storage
   IOPS/byte accounting so runaway queries deterministically spill to Tier 2 NVMe
   or return a typed budget refusal at batch boundaries without noisy-neighbor
   starvation or process-wide OOMs.
2. **First-class Umbra/German strings, perfect hashing and fully-vectorized Block-Max BM25 search ([Milestone 15](15-vectorized-strings-and-search.md)):**
   Instead of overloading general data structures or foreign-format adapters,
   [Milestone 15](15-vectorized-strings-and-search.md) gives text, static/immutable
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
     [Milestone 15](15-vectorized-strings-and-search.md) separates declarative
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
     [Milestone 47](47-declarative-language-context-and-synthesis.md).
3. **Data-centric pipeline fusion, CedarDB join structures, Flying-Start Adaptive Morsel Tier-Up and AOT query compilation ([Milestone 13](13-sql-and-dataflows.md), [Milestone 14](14-data-structures-and-performance.md), [Milestone 16](16-data-centric-compilation-and-specialization.md)):**
   Taking inspiration from [HyPer](https://hyper-db.de/) (Neumann, VLDB 2011),
   [Umbra](https://umbra-db.com/) (Neumann & Freitag, CIDR 2020),
   [CedarDB](https://cedardb.com/) and the compiled-versus-vectorized synthesis
   (Kersten et al., VLDB 2018), [Milestone 13](13-sql-and-dataflows.md) and
   [Milestone 14](14-data-structures-and-performance.md) adopt universal `D-Join`
   correlated subquery unnesting, **CedarDB-style ~10-instruction directory-tagged
   join hash tables** (embedding 16-bit Bloom/tag signatures in directory slots)
   and **Diamond-Hardened / Worst-Case Optimal Joins (WCOJ / FreeJoin)**.
   [Milestone 16](16-data-centric-compilation-and-specialization.md) combines
   vectorized `Batch` morsels (for SIMD scans and software-prefetched `@prefetch`
   hash-join probes) with **data-centric push pipeline fusion** inside each morsel
   so multi-step expressions, projections and aggregations stay in CPU registers
   without writing temporary `scratch` arrays per AST node. It pairs
   **per-`.tseg`-row-group dense non-null kernel dispatch** (`null_count == 0` and
   empty `.tdel`) with **Flying-Start Adaptive Morsel Tier-Up** ($0\,\mu\text{s}$
   startup via fused superinstructions, tiering up at a morsel boundary to
   Copy-and-Patch stencils only for long-running queries) and **true Ahead-of-Time
   (AOT) Zig compilation through `transit build` targets**, setting HyPer, Umbra and CedarDB on
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
   [Milestone 24](24-storage-providers-and-concurrency.md) explicitly own the
   progression to index-range and predicate-level conflict detection so concurrent
   read-write transactions touching disjoint keys on shared Tables commit without
   false whole-Table aborts.
2. **LSM/`.tseg` compaction invariants, branch-aware GC and multi-dimensional clustering:**
   [Milestone 14](14-data-structures-and-performance.md) owns leveled/size-tiered
   `.tseg` overlap bounds ($K_{\max}$), `.tdel` tombstone compaction thresholds
   and declarative `PARTITION BY` / `CLUSTER BY` (including Z-order/Hilbert sort
   keys decoupled from primary keys); [Milestone 21](21-branches-merges-and-restore.md)
   owns branch-aware compaction and shared-segment garbage collection watermarks.
3. **Security-barrier Row-Level Security (RLS), Column-Level Security (CLS) / dynamic masking and GDPR crypto-shredding:**
   [Milestone 24](24-storage-providers-and-concurrency.md) owns authenticated
   encryption at rest and KMS/BYOK per-tenant/per-subject envelope encryption over
   `TransitLog` and `.tseg`/`.tdel` objects;
   [Milestone 28](28-control-and-policy-plane.md) owns security-barrier RLS
   (preventing side-channel leakage via 5-state `type_error`, division-by-zero or
   zone-map/index statistics), dynamic column masking and auditable cross-branch
   crypto-shredding/purge workflows.
4. **Declarative `FOREIGN KEY` and `CHECK` relational integrity:**
   [Milestone 10](10-standards-and-catalogs.md) owns catalog bindings and dependency
   graphs for `CHECK` and `FOREIGN KEY` constraints;
   [Milestone 11](11-indexing-and-access-paths.md) owns index-backed transaction
   enforcement; and [Milestone 21](21-branches-merges-and-restore.md) validates
   referential integrity across 3-way branch merges.
5. **First-class bitemporal SQL (`AS OF JOIN` and application-time periods):**
   [Milestone 13](13-sql-and-dataflows.md) and
   [Milestone 14](14-data-structures-and-performance.md) pair `FOR SYSTEM_TIME AS OF`
   with declarative valid-time periods (`PERIOD FOR valid_time`) and streaming
   $O(N + M)$ `AS OF JOIN` merge execution so point-in-time backtesting and
   decision audits never leak later corrections into earlier simulated decisions.
6. **Complete analytical SQL and deterministic in-engine UDFs:**
   [Milestone 13](13-sql-and-dataflows.md) and
   [Milestone 14](14-data-structures-and-performance.md) explicitly enumerate
   multi-way/non-equi/`SEMI`/`ANTI`/`LATERAL` joins, correlated subquery
   decorrelation, window functions (`OVER (...)` / `QUALIFY`), CTEs (`WITH` /
   bounded `WITH RECURSIVE`), set operations, rich aggregates, external NVMe
   spill and sandboxed scalar/table UDFs (SQL macros and deterministic Wasm
   kernels running over `Fuze` vectors without actor-mailbox round-trips).
7. **Native segment-backed Full-Text Search (BM25) and Vector / Hybrid Retrieval:**
   [Milestone 19](19-multi-model-and-foreign-relations.md) and
   [Milestone 33](33-reactive-context-and-agent-activation.md) own immutable
   inverted full-text segments (BM25) and `.tseg` vector/ANN similarity indexes
   so lexical, semantic and relational queries execute under a single `SnapshotId`,
   branch and `policy_epoch` without exporting data to external search/vector stores.
8. **Hierarchical Workload Management (WLM) and scan-resistant caching:**
   [Milestone 14](14-data-structures-and-performance.md) owns scan-resistant
   buffer-pool/NVMe eviction (2Q/ARC/W-TinyLFU) and background I/O token buckets;
   [Milestone 28](28-control-and-policy-plane.md) owns multi-tenant WLM resource
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
    [Milestone 13](13-sql-and-dataflows.md) exposes committed deltas via a
    `CHANGES(table, ...)` table-valued function, and
    [Milestone 19](19-multi-model-and-foreign-relations.md) delivers governed
    streaming CDC ingress adapters (PostgreSQL logical replication, MySQL binlog,
    Debezium/Kafka CDC envelopes) with watermark and checkpoint recovery.

All 28 milestone numbers, phase boundaries and existing statuses remain unchanged.
This planning update establishes delivery ownership and acceptance criteria, not
implemented runtime support.

## Formal semantics and correspondence review — 2026-10-25

Add [formal semantics and implementation correspondence](23-formal-semantics-and-correspondence.md)
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
[data structures, query optimization and runtime performance](14-data-structures-and-performance.md)
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
[Board reimplementation](31-board-reimplementation.md) as milestone 19, after
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
[complete mixed composition](35-programming-model.md), and gives
[provider/concurrent-writer qualification](24-storage-providers-and-concurrency.md)
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

[Language-native programming and mixed composition](35-programming-model.md)
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

This is distinct from [service/SDK coverage](22-service-and-sdk-coverage.md),
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

[Replication](25-replication-and-failover.md) and
[operations](26-operations-and-recovery.md) precede
[clustered execution](27-clustered-execution.md). Replication qualifies complete
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
   **Multi-Writer OCC** in [provider/writer qualification](24-storage-providers-and-concurrency.md),
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
5. **Optimize the database, string/search engine, data-centric compiler, Document Type Library, geospatial engine and durable runtime ([Milestones 14](14-data-structures-and-performance.md)–[17](18-geospatial-and-spatio-temporal-computing.md)).**
   Use workload contracts and comparative baselines to select trees, filters,
   bitmaps, hash tables, zero-steady-state-allocation slabs, per-morsel resource
   meters ([Milestone 14](14-data-structures-and-performance.md)), 16-byte
   collation-prefixed strings, `comptime`/immutable perfect hashing and vectorized
   Block-Max BM25 search ([Milestone 15](15-vectorized-strings-and-search.md)),
   HyPer-style data-centric push pipeline fusion, per-row-group kernel
   specialization and `transit build` AOT Zig query compilation
   ([Milestone 16](16-data-centric-compilation-and-specialization.md)),
   declarative Document Profiles (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`) with
   transport-decoupled gateway/connector exchange capture
   ([Milestone 17](17-document-profiles-and-gateway-exchange-lifecycle.md)), and
   orthogonal $\tau \perp \kappa_{\text{spatial}} \perp \epsilon$ geospatial
   types, 16-byte inline MBR headers, topological/cell-covering compression and
   DBSP Z-set incremental spatial operators
   ([Milestone 18](18-geospatial-and-spatio-temporal-computing.md)).
   Deliver statistics and cost-based plans, measure complete durable operations
   under mixed load, and enforce latency, throughput, memory and recovery budgets
   throughout later work.
6. **Cut over live executables and activate derived views, multi-format foreign sources, branches and clustered compute ([Milestones 3](03-live-storage-and-sql-cutover.md)–[26](27-clustered-execution.md)).**
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
qualification belongs to [qualification](45-qualification-and-benchmarks.md#documentation-publication),
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

Keep one numbered, descriptively named file per milestone (`01-` through `47-`).
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
