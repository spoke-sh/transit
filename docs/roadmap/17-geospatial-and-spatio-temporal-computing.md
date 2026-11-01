# 17. Geospatial types, topological compression, spatial indexing and incremental spatio-temporal queries

[Roadmap](README.md) · [Standards & Multi-Model #31](https://github.com/spoke-sh/transit/issues/31) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** Planned ([implementation plan](#implementation-plan--2026-11-01))

An application declares spatial columns and their coordinate, precision and
temporal rules, writes features through ordinary database operations, and queries
them through finite or maintained Fuze plans. It can inspect the exact definition,
source basis, index coverage, result completion and stopped progress. Geometry
storage, an index build and a maintained computation have separate lifecycles.

Deliver the full 2D/3D scope: geometry and geography, meshes and solids, instanced
scenes, point clouds, discrete cells and trajectories; columnar and topological
compression; spatial access paths and serializable predicates; finite and
incremental spatial computation. Keep logical types (τ), spatial semantics
(κ_spatial) and physical codecs (ε) orthogonal. These are planned capabilities,
not additional types or SQL accepted by the current build.

## Implementation plan — 2026-11-01

**Source basis:** fetched `origin/main` at
`c8d060cb2dfcf3bc531ef2e41fcdf7d4f172c2d5`. This plan includes merged progress
through the Stream/Queue integration and transaction-replay correction. It does
not assume changes on feature branches have landed. Milestone 17 stays
**Planned** until implementation begins; component foundations in other
milestones do not change its status.

Start with [data identities](01-declarative-data-lifecycle.md),
[local storage](02-storage-and-query-performance.md),
[Tables](../handbook/reference/tables.md),
[types](../handbook/reference/sql/types.md),
[queries](../handbook/reference/queries.md),
[storage mechanisms](../handbook/internals/storage-runtime.md) and
[query mechanisms](../handbook/internals/query-engine.md).
The [verification reference](../handbook/reference/verification.md) and
[qualification ledger](../history/qualification/README.md) govern evidence.
Historical passing runs qualify their own revisions; their union is not a
passing integrated spatial profile.

### Delivered foundations and actual gaps

| Boundary at the source basis | Reuse | Remaining work relevant to M17 |
| --- | --- | --- |
| M1–M5 data, storage and results | Direct Table identities, immutable definitions, retained cuts, WAL/segment publication, original-token recovery, local serializable Table transactions and shared command/result-set lifecycles | Add spatial interpretation to every affected persisted and caller boundary. M5's conservative whole-Table read conflicts do not provide spatial predicate SSI. M3 remains In Progress for its own installed-lifecycle obligations. |
| [M6 Stream/Queue progress](06-streams-queues-and-durable-runtime.md#r5-extend-the-transaction-owner-and-deliver-direct-kv) | Named direct KV; signed Stream/Queue operations; shared bitmap storage; native Table/KV plus append/ACK/offset composition, including an installed mixed-decision proof; installed Stream/Queue declaration SQL | Workload SQL verbs, retained Fuze `STREAM_SLICE`, transactional Station migration, automatic DLQ scheduling and final integrated fault qualification remain open. Trajectories must consume the real retained Stream owner. |
| [M7 Document progress](07-document-storage-and-station-decoupling.md#delivered-basis-and-remaining-obligations) | `SuccinctTree`, `SpanText`, shredding and `DocumentPartition` components, authority and retained-graph foundations | Persisted tree/subcolumn integration, database-derived state, direct public operations, transactions and consumer cutover remain unfinished. A BP helper is not a ready paged mesh store or an installed spatial Document source. |
| [M8 gateway](08-gateway-architecture-and-protocol-ingress.md#current-implementation-and-evidence) and [M9 clients](09-client-foundation-and-language-apis.md#current-implementation-and-gaps) | Co-hosted database SQL, event-driven recovery, resumable wire foundations; extracted data callers, result ownership and frozen SQL submissions | Compose new types with existing owners. Broader managed handles, wire/Flight coverage and coarse remote execution retain their own gates. No spatial polling service or independent retry/result protocol. |
| [M10 types and history](10-standards-and-catalogs.md#delivered-implementation-evidence--2026-10-30) | Standards ledger, comparison helpers and caller-owned historical descriptors | `Types.Tag` and the type contract admit no spatial family. `DecimalArithmetic.SpatialDescriptor` is a standalone helper, rejects SRID 0, and is not persisted in Table schemas. Complete the descriptor/value/schema cutover; do not treat the helper's defaults as a selected CRS policy. |
| [M11 indexes](11-indexing-and-access-paths.md) | `IndexLifecycle` neutral identities, bindings and coverage descriptors | Milestone remains Planned. No installed secondary-index declaration/build/publication or executable `CREATE INDEX`; spatial access methods require an explicit extension and M11's durable lifecycle. |
| [M12 dataflows](12-sql-and-dataflows.md#delivered-implementation-evidence--2026-10-30) | Finite analytical and Z-set component oracles, managed-lifecycle helpers and source-frontier contracts | `FuzeDelta.ZSet` has 256 resident entries; `Arrangement` updates resident state and counters. Spatial invocation returns `SpatialZSetExecutionDeferredToM17`. These are not durable spatial arrangements, actual NVMe spill or installed WAL-driven spatial views. |
| [M13 resources](13-data-structures-and-performance.md#result-path-implementation-checkpoint), [M14 strings/search](14-vectorized-strings-and-search.md#delivered-implementation-evidence--2026-10-30) | `transit-memory` reserves/leases/`AllocationProbe`, `GermanString`, compressed predicates, search oracles and bitmap intersections | Result-path and helper evidence does not establish zero-allocation spatial scans, a swizzled buffer pool or integrated search/index maintenance. Reuse ownership and measurement mechanisms, not string layouts verbatim. |
| [M19 immutable Table branches](19-branches-merges-and-restore.md#local-table-branch-increment) | Named read-only single-Table branches retain exact definitions, unflushed rows and original outcomes through collection/restart | Preserve spatial descriptors and referenced codec objects in those cuts. Writable branches, three-way spatial merge, catalog-wide snapshots and forward restore remain M19 work. |

Concrete starting points are
[`Types`](../../packages/zig/transit-fuze/src/Types.zig),
[`Values`](../../packages/zig/transit-fuze/src/Values.zig),
[`TableSchema`](../../packages/zig/transit-fuze/src/TableSchema.zig),
[`Batch`](../../packages/zig/transit-fuze/src/Batch.zig),
[`TSeg`](../../packages/zig/transit-fuze/src/TSeg.zig),
[`TSegReader`](../../packages/zig/transit-fuze/src/TSegReader.zig),
[`DecimalArithmetic`](../../packages/zig/transit-fuze/src/DecimalArithmetic.zig)
and [`FuzeDelta`](../../packages/zig/transit-fuze/src/FuzeDelta.zig).
Comments naming a future codec or durable arrangement are not evidence that its
storage and caller path exists.

### Dependency gates and scope boundaries

| Owner | Gate consumed by M17 | Work that can proceed before the whole owner milestone completes |
| --- | --- | --- |
| M6 | Retained Stream schema/offset cuts, current authorization, complete change coverage and applicable mixed commit decisions | Table spatial types, finite queries and codecs; Stream adapters wait for their exact source gate, not all Station migration. |
| M7 | Integrated paged Document projections, raw-span evidence and accepted revision/change bindings | Independent spatial kernels and Table storage. Share BP algorithms through package interfaces only after checking their bounds; Document adapters wait for C2–C6. |
| M10 | Immutable descriptor identity, historical interpretation and capability classification | Agree spatial descriptors alongside companion types. Basic exact Table cuts do not require general historical SQL; historical spatial selectors wait for M10's durable catalog work. |
| M11 | Durable index declaration/build/catch-up/publication, row-version identity and predicate conflict tracking | Full-scan spatial execution, segment zone maps and private access-method prototypes. No installed spatial index or fine-grained SSI claim until the common lifecycle is ready. |
| M12 | Paged arrangements, actual spill/checkpoint/recovery, complete WAL activation, common transaction barriers and event-time contracts | Finite spatial oracle and component delta algebra. Public maintained spatial execution waits for P5/P6 integration; `AS OF JOIN` waits for P4. |
| M13/M14 | Shared allocation/resource meters, bounded source buffers and reusable bitmap/vector machinery | Scalar and bounded vector kernels with measured allocations. Full-query spill and zero-allocation claims need evidence from actual owners. |
| [M15 compilation](15-data-centric-compilation-and-specialization.md) | Operator traits and stable batch ABI for fused/AOT/adaptive kernels | Interpreted/vector spatial execution is the initial implementation. Compiled specialization is an optimization after equivalent semantics; M17 does not build a second compiler. |
| [M16 profiles](16-document-profiles-and-gateway-exchange-lifecycle.md) | Exact part/tree/span provenance and layout coordinate descriptors | Spatial types and WKT/WKB/GeoJSON value codecs. PDF page spans and compound CAD/BIM/document ingestion wait for their owning profiles. |

The critical path for the first usable increment is **S0 → S1 → S2 → S3**.
Spatial indexing follows **S3 → S4 → S5**, gated by M11. Topological and 3D work
extends the same types and finite oracle through **S6 → S7 → S8**. Trajectory
execution S9 needs the relevant M6/M10/M12 seams. Maintained execution S10 needs
qualified finite operators and M12's durable runtime. S11 closes the integrated
milestone. Independent kernels and fixtures can develop alongside prerequisites;
a missing prerequisite keeps only its dependent public profile closed.

### Implementation ownership

| Owner | M17 responsibility |
| --- | --- |
| Proposed `packages/zig/transit-spatial` | Pure Zig predicates, coordinate rules, topology, grid algorithms and scalar reference execution; no storage, policy, clock or transport dependency |
| `transit-fuze` | Logical descriptors/values, SQL lowering, `Batch`/vector kernels, shared `.tseg` encoding/reading, spatial plans and delta operators |
| `transit-storage` | Table/Stream/Document integration, paged topology/prototype/index objects, retained graph, maintenance and transaction participation |
| `transit-catalog` and `transit-protocol` | Exact definition and dependency bindings, neutral lifecycle/transaction messages, current authorization and recoverable publication |
| `transit-sql` and existing gateway adapters | Statement execution and individually admitted wire mappings over shared typed operations |
| `transit-data-client`, `transit-sql-results`, `transit-sql-client`, ABI and SDK owners | Typed parameters/values, bounded result ownership, original-operation recovery and complete affected-consumer cutover |
| `transit-memory`, shared bitmap owners and M12/M13 runtime owners | Accounted reusable buffers, conservative bitmap candidates and real paged/spill/checkpoint machinery |

### Contract decisions before runtime exposure

**Identity and lifetime.** A spatial value belongs to its ordinary Table, Stream
or Document object. Bind source/column identities, exact definition, CRS registry
content, precision and algorithm rules into schemas, plans, retained cuts,
segments and index generations. Scene prototypes, topological dictionaries,
transform grids, arrangement checkpoints and LOD pages need explicit retained
references. A segment-local arc/face number is not a stable cross-segment identity.
Compaction must remap physical references without changing logical equality,
accepted rows, pins or delta multiplicities. Neither a CRS cache nor a prototype
reference grants permission.

**Coordinate semantics.** Specify dimension, axis order, units, horizontal and
vertical reference, planar versus spherical versus ellipsoidal edge rules,
rounding and overflow. SRID 0 is an explicit local engineering/layout frame with
units and axes, not an invalid default. EPSG:4979 ellipsoidal height must not be
silently interpreted as EGM2008 orthometric height. Registry/grid artifacts are
pinned inputs loaded by the host; deterministic kernels perform no network I/O.
Start with a documented registry subset and refuse unsupported transformations.
Cross-descriptor operands require an explicit conversion; known mismatches reject
during binding, dynamic mismatches at the checked evaluation boundary. A curve
prefix accelerates access and never defines geometric equality or distance.

**Exact predicates and construction.** Port the
[Shewchuk predicate algorithms](https://www.cs.cmu.edu/~quake/robust.html) to Zig
with explicit finite exponent ranges, expansion workspace, rounding/FMA rules and
overflow refusal. Exact determinant signs do not provide exact constructed
intersection coordinates. Select canonical noding/corefinement and snap-rounding
rules separately; prove their result topology and reproducibility. Closed
boundaries and Euler checks alone do not prove a valid solid: test orientation,
self-intersection, shell nesting, cavities and manifold incidence. Repair is an
explicit operation with changed-value provenance, never an ingestion side effect.

**Value states and errors.** NULL and empty geometry are distinct. Define
structural equality/hash separately from topological `ST_Equals`; do not invent
a natural geometric total order. Preserve null/missing/type-error/conflict and
failure order through projected/foreign data and query results. Ordinary Table
writes currently reject type-error/conflict cells under
[`TABLE_SCHEMA_V1`](../../contracts/TABLE_SCHEMA_V1.md).
Malformed spatial writes must therefore reject atomically; a future explicit
ingestion policy may preserve raw data and diagnostic projections. Do not claim
that every invalid bulk write succeeds because queries support five states.
Corrupt stored pages or incompatible definitions are storage/compatibility
failures, not ordinary bad-geometry cells.

**Physical layout.** The 16-byte spatial header is a measured design target.
Eight payload bytes cannot hold two arbitrary float64 coordinates. Inline only a
declared compact representation; otherwise use a bounded, generation-checked
payload handle or column offset directory. Specify where exact coordinates,
conservative MBRs and payload references live together. A u16 registry index is
not the full SRID. Quantized bounds round outward, including transformed and
geodesic bounds. BBOX2D/3D float64 payloads require 32/48 bytes; int32 versions
require 16/24 bytes. A translation/quaternion/scale tuple has eight components;
48-byte `TRANSFORM3D` needs a selected mixed/compact encoding, while eight
float64 components require 64 bytes. Measure layouts before freezing them.

**Coverage and spatial predicates.** A cell overlap is a candidate unless the
particular predicate has a proved sufficient condition. An exact point in a
certified interior cell can discharge point containment; an interior/interior
intersection can discharge intersection. One hit cannot prove whole-feature
containment, clearance or distance. H3's logical hierarchy does not imply exact
geometric parent containment, and its ordinary polygon fill selects cell
centroids; neither supplies a conservative outer covering. Use
[H3's hierarchy semantics](https://h3geo.org/docs/) and
[region semantics](https://h3geo.org/docs/api/regions/) to qualify separate
covering algorithms. Bound refinement and use exact narrow-phase evaluation
when proof is insufficient. Bitmap work scales with visited containers and
candidates; do not promise constant-time whole joins.

**Topological incremental algebra.** Oriented boundary addition implements the
fast union path only on a verified common, noded cell complex with compatible
orientation and interior-disjoint occupied cells. General overlapping polygons
or solids require arrangement/corefinement and occupancy multiplicities before
boundary extraction. Repeated rows and deletions must not toggle occupancy
incorrectly. Maintain volume and first/second moments under selected numeric
rules; derive centroid by division at finalization. Union surface area comes
from exposed faces, not a signed sum of every input face area.
`SUM(ST_Volume(solid))` and `ST_Volume(ST_3DUnion(solid))` differ on overlaps.
The [CGAL mesh/boolean model](https://doc.cgal.org/latest/Polygon_mesh_processing/index.html)
is an independent qualification reference, not a Transit runtime dependency.

**Loss, approximation and time.** Lossless encoding, logical grid normalization,
error-bounded trajectories, quantized normals, SDF approximations and display LOD
are distinct policies. An approximate LOD/SDF cannot silently answer an exact
predicate. State trajectory interpolation, timestamp equality, late corrections,
angular tolerance, event time, watermark and expiry separately. Staying in one
cell or within a motion tube does not imply unchanged distance, nearest neighbor
or containment: suppress reevaluation only with a predicate-specific bound, and
never omit required row/projection changes. Unlimited retention remains default;
watermarks and memory pressure do not authorize deletion.

## Work packages and reviewable outcomes

Each package includes its neutral fixtures, owning implementation, caller
integration where applicable, and public documentation for the delivered subset.
The identifiers below are delivery units, not proposed public API names.
Partial delivery keeps the remaining capability rows explicit.

| Package | Outcome | Prerequisites | Exit gate |
| --- | --- | --- | --- |
| S0 | Spatial contract, capability and workload inventory | Source audit; agreements with M10/M11/M12 | Exact semantics, cutover/removal map and independent fixtures before adapters |
| S1 | Deterministic 2D/3D primitives and registry | S0 | Exact-sign and construction oracles, bounded refusal, cross-target replay |
| S2 | Stored spatial values and complete caller cutover | S0/S1; existing M4/M5 paths | Declare/write/read/recover through real SQL and typed callers |
| S3 | Finite vectorized spatial SQL and result delivery | S2 | Full-scan oracle, five-state/failure-order and buffered-revocation equivalence |
| S4 | Conservative zone maps and spatial access methods | S3; M11 source/coverage contracts | Scan/index equivalence at one exact cut including tails and deletes |
| S5 | Online spatial index lifecycle and predicate SSI | S4; M11 lifecycle/transaction integration | Crash/resume, no-gap publication, phantom/write-skew and disjoint-region schedules |
| S6 | Shared-arc/face topology and cell-covering codecs | S1–S4 | Lossless logical reconstruction and qualified covering/union fast paths |
| S7 | Mesh/solid storage and exact finite 3D kernels | S1–S3/S6 | Mesh/solid oracle, validity, CSG and bounded large-value execution |
| S8 | Scenes, point clouds and progressive output | S4/S7 | Retained prototypes, pose changes, streaming LOD/tile and resource proofs |
| S9 | Temporal/kinematic types and finite queries | S2/S3/S8 for poses; M6/M10/M12 source/time gates | Retained Stream/Table equivalence, late corrections and temporal joins |
| S10 | Durable incremental spatial computation | Relevant S3/S6–S9 operators; M12 P5/P6 | Finite equivalence at every completed basis through faults and spill |
| S11 | Common-revision qualification and promotion | All declared scope and prerequisite gates | Installed caller, recovery, resource and benchmark evidence; full scope disposition |

### S0 — Define contracts, fixtures and the cutover

Extend the owning contracts:
[`FUZE_TYPES_V1`](../../contracts/FUZE_TYPES_V1.md),
[`TABLE_SCHEMA_V1`](../../contracts/TABLE_SCHEMA_V1.md),
[`TRANSIT_STORAGE_V1`](../../contracts/TRANSIT_STORAGE_V1.md),
[`INDEX_LIFECYCLE_V1`](../../contracts/INDEX_LIFECYCLE_V1.md),
[`FUZE_ARROW_V1`](../../contracts/FUZE_ARROW_V1.md) and the
[SQL grammar](../../contracts/sql/README.md).
Reuse [direct lifecycle operations](../../contracts/DIRECT_TABLE_V1.md),
[statement results](../../contracts/SQL_RESULTS_V1.md) and
[sessions](../../contracts/SQL_SESSION_V1.md).
Add a dedicated spatial contract only if it has a distinct shared owner; avoid
copies of the same descriptor in storage, SQL and SDKs.

Specify canonical value/descriptor bytes, empty geometry, malformed input,
dimensions, exact versus approximate traits, five-state diagnostics with bounded
ring/shell/face/edge/part/byte witnesses, and per-operation resource limits.
Record every type/function by grammar, binding, finite execution, maintained
execution and transport coverage. Freeze canonical fixtures independently of the
Zig encoder, including unknown tags and missing/foreign definitions.

Inventory every affected native message, schema, stored format, saved plan,
Arrow/result encoding, ABI, SDK, generated resource and signing fixture. Apply
the [current-v1 hard-cutover policy](../handbook/reference/versioning.md) at each
incompatible integration: replace the shared definition and migrate affected
consumers together. Never reinterpret old artifacts, silently reset data, add a
legacy decoder or default missing persisted interpretation. Remove the reserved
spatial helper/hook when its owning implementation replaces it.

### S1 — Implement pure spatial kernels

Create `transit-spatial` for deterministic geometry/registry code shared by Fuze
and storage consumers; give it a manifest, declared imports and package checks.
Keep policy, storage, sockets, clocks and external engines outside that library.
Separate transient scratch from retained output, with explicit vertex, edge,
face, intersection, expansion and refinement budgets.

Define registry coverage for local SRID 0, WGS84 4326/4979, Web Mercator 3857,
selected UTM/national grids and explicitly pinned vertical transforms. Admit
each transformation only with its coordinate-domain and grid-artifact evidence.
Implement orientation/incircle/insphere, coordinate and ring validation,
canonical precision conversion, envelope construction, scalar planar predicates
and distance, then geodesic kernels and explicit transforms. Define axis/unit
fixtures before adapters. Compare degenerate and near-degenerate inputs with
independent exact arithmetic and pinned GEOS/PostGIS, GeographicLib and grid
fixtures. Run x86_64/aarch64 fixtures with controlled arithmetic; a cross-compile
alone does not prove equal execution.

### S2 — Carry spatial values through the database

Extend `Types`, `Values`, logical codecs, `TableSchema`, native schema/value
carriers and `DirectCatalog` binding before enabling SQL declarations.
Implement `.geoarrow` coordinate/offset pages and `.twkb_delta` under the shared
`TSeg`/`TSegReader` envelope. Follow the selected
[GeoArrow layout](https://geoarrow.org/format.html) for interoperability while
retaining Transit definition and five-state evidence separately. An internal
codec name alone does not establish upstream format compatibility.

Prove Table insert/update/delete, defaults, ALTER compatibility, WAL tail/flush,
retained reads, compaction, checkpoint/reopen and branch retention. Make geometry
size independent of resident working memory with paged payload access and
explicit per-value admission bounds; do not raise scalar/actor caps as a storage
design. Reject unsupported type/codec pairs before acceptance.

Migrate `transit-data-client`, `transit-sql-results`, `transit-sql-client`,
neutral ABI and affected existing SDK decoders together. Preserve exact widths,
descriptor ownership, cancellation and original write identity. Admit protocol
types individually; PostgreSQL/MySQL, Arrow C/IPC and Flight each need their own
mapping and tests. Unsupported adapters return an explicit refusal rather than
mislabeling geometry as generic text.

### S3 — Deliver the first finite query journey

The first installed increment supports a declared planar POINT/LINESTRING/POLYGON
and BBOX2D profile, explicit precision, WKT/WKB conversion, validation, envelope,
intersection/containment and distance/area/length. Add GEOGRAPHY and additional
subtypes through the same capability rows. This is an initial slice, not the
completion boundary for M17.

Bind SQL and typed expressions to the same scalar/vector operators. Add spatial
lanes to `Batch`/`VectorKernel` with accounted coordinate/payload directories,
64-byte alignment and verified padding for any unconditional SIMD read. Preserve
original source positions, eager failure order, state-only operations and
borrowed lifetimes across batch reset. Keep storage pages, compute morsels, wire
batches and display windows independent.

Deliver one complete public journey: declare, inspect, insert, prepare/query,
update, read a retained cut and recover the original uncertain mutation after
restart. SELECT returns one schema and a verified terminal count through the
existing result reader. Test empty and multi-batch results, a single large
geometry, early close, cancellation and current authorization after buffering
rows, schema, diagnostics and terminal counts.

### S4 — Add sound pruning and spatial access methods

Implement conservative row-group/segment BBOX2D/BBOX3D, geodesic cap/wrap bounds
and cell summaries, bound to the exact descriptor and source interpretation.
Zone maps may prune only when their bound proves non-matching rows; preserve
observable error/state semantics. Unknown summaries require a qualified scan.

Prototype immutable Hilbert-packed R-trees plus bounded mutable overlays, and
inverted S2/H3/OCT cell postings using
[`transit-bitmap`](../../packages/zig/transit-bitmap/README.md) and
[`BitmapDirectory`](../../packages/zig/transit-storage/src/BitmapDirectory.zig).
A 16-bit Roaring container does not directly encode a global 64-bit cell ID:
specify the paged prefix directory, resolution, stable row/version mapping and
duplicate suppression. Combine index candidates with MVCC visibility and
`.tdel`; cover accepted unflushed rows and updates moving between cells.

Implement bounded candidate discovery and k-NN queues with admissible distance
lower bounds and deterministic row-identity tie-breaking. Include
`<->`/`<<->>` in the checked grammar only after their exact metric is defined.
Measure clustering by Hilbert/S2/Morton separately from logical row order.
EXPLAIN reports actual eligible coverage, broad/narrow-phase work and scan
fallback without initiating an index build.

### S5 — Integrate index publication and transactions

Extend M11's shared declaration and access-method contract for `RTREE`, `S2`,
`H3` and `OCTREE`; do not introduce a spatial-only catalog or worker authority.
Build from an exact retained cut, including WAL tails, consume complete
intervening changes, validate, then conditionally publish coverage. Persist
original build identity, owner fence, progress, staged roots and cancellation.
DROP/rebuild and schema/CRS changes retain old reader generations until release.
A stale index cannot claim current coverage.

Extend the existing transaction owner with conservative spatial read/write
predicates and common-cut evidence. Include insert/delete, old and new bounds
on movement, empty-region reads, transformed/geodesic ranges and k-NN predicates.
Keep whole-Table conflict protection for cases not yet proved by finer guards.
Qualify disjoint-region concurrency and overlapping phantom/write-skew schedules;
a range decomposition or index alone is not an SSI implementation. Resolve lost
commit replies using the original decision; index and base visibility must agree
through preparation, decision, restart and cleanup.

### S6 — Implement topology and certified coverings

Store canonical shared arcs and oriented faces once per qualified dictionary,
with signed references, vertices, incidence/coboundary and enough residual data
to reconstruct every feature. Pin dictionary interpretation and preserve
references across segment boundaries, compaction and branch retention.
Canonical noding/corefinement and occupancy handle overlap; the interior-disjoint
coverage fast path requires explicit validation.

Implement bounded S2/H3/OCT outer and certified-interior coverings plus exact
boundary patches. If refinement exhausts its budget, return a conservative
coarser covering or typed refusal, never an incomplete covering labeled complete.
SDF/narrow-band representations carry error bounds and retain exact geometry
when an exact predicate needs it. Qualify antimeridian/polar, pentagon,
multi-resolution, thin-sliver and cell-boundary cases.

Test `.topo_arc`, `.topo_face`, `.s2_roaring` and `.octree_roaring` round trips
against the canonical logical model, independent of byte layout. Measure
dictionary construction and changed-region work as well as compressed size.
Expose adjacency data for M18 without implementing its property-graph engine.

### S7 — Deliver meshes, solids and finite 3D computation

Implement MESH3D/SOLID3D values with shell/face/edge provenance, exact validity,
bounded BVHs and triangle narrow phases. Add finite 3D intersection, containment,
distance/clearance, ray, mass properties and constructive/corefined boolean
operations. Preserve cavities, disconnected components, coplanarity and thin
features. Define explicit behavior for non-manifold output rather than repairing
it silently. Qualify approximate SDF operations separately from exact CSG.

Build `.mesh_edgebreaker` with CLERS connectivity, parallelogram coordinate
prediction, selected octahedral normal encoding and wavelet/vertex-split LOD
prefixes with explicit error and reconstruction metadata. Reuse BP navigation
only where its actual package contract fits. The original
[Edgebreaker work](https://faculty.cc.gatech.edu/~jarek/papers/EdgeBreaker.pdf)
motivates the codec; a sub-two-bits/triangle target is not a universal bound on
arbitrary meshes, coordinates or full stored objects. Record connectivity,
coordinates, normals, exceptions, directories and LOD overhead separately.

Stream large meshes through bounded page/work units. Prove malformed/truncated
connectivity refusal, exact base reconstruction and retained-page ownership.
A coarse LOD result identifies its selected level and error; it cannot establish
full-resolution exact-query completion.

### S8 — Compose scenes, point clouds and output formats

Implement `.scene_dag` prototypes and instance identities with cycle/depth
validation, explicit instance paths for shared children, immutable prototype
references and qualified SE(3)/Sim(3) transforms. A single-parent row is a tree;
a multi-parent DAG needs distinct instance paths/world transforms. Pose updates
reuse prototype geometry but still update affected world bounds, index coverage
and join candidates under bounded progress.

Implement `.pcloud_hilbert` blocks, FOR coordinate residuals and typed attribute
subcolumns. Treat 4,096 points as an initial block target, not a total-cardinality
limit or a promised compression ratio. Qualify lossless selected-grid round trips,
outliers, coordinate overflow and selective attribute decoding.

Add bounded MVT/glTF/3D Tiles value/output builders and progressive LOD delivery
through shared results. Prototype identity, source basis, coordinate frame,
completion and current disclosure remain visible. Container discovery,
`FOREIGN TABLE`/`COPY` orchestration and external format ecosystems remain
M18; interactive rendering remains M29.

### S9 — Implement finite trajectories and kinematics

Bind TRAJECTORY to spatial/time descriptors, interpolation, spatial/angular
tolerances and an explicit temporal interval. Coordinate RANGE/TIMESTAMPTZ
integration with M10 instead of treating standalone helpers as stored types.
Support piecewise linear position and selected quaternion interpolation with
defined duplicate-timestamp, discontinuity and antipodal/quaternion-sign rules.

Read finite Table/Stream cuts through actual authorized paged sources. Implement
value-at-time, locate-along, closest approach and the qualified spatiotemporal
AS OF join. Connect Document layout spans only after M7/M16 supply exact part,
page, revision and coordinate evidence. Compression retains the declared
reconstruction/error contract; event-time ordering is separate from acceptance
order and source progress.

Test late/out-of-order corrections and gaps, time-zone interpretation, stationary
and near-boundary motion, rotation/scale and source expiry. Retained results keep
their original basis; missing history stops advancement explicitly. Queue/Station
effects are not implied by a geofence result.

### S10 — Maintain spatial results over durable changes

Replace the reserved spatial hook with finite-equivalent delta operators after
M12 supplies paged arrangements, actual spill and durable activation. Do not grow
the existing 256-entry array into a production spatial store. Use durable
arrangement keys for feature/version, canonical edge/face, cell/instance and
group identities with checked signed multiplicities.

Deliver coverage union and general overlap-aware union, exposed-boundary/moment
aggregates, spatial/clash joins, scene pose changes and trajectory geofencing.
For simultaneous input changes, include all bilinear join terms and deduplicate
cell candidates without losing relation multiplicity. Distinguish delta size,
arrangement lookup, corefinement, output reconstruction and publication costs.

Publish operator state, output revision/delta and consumed source frontiers under
the owning common-decision/checkpoint contract. Handle backfill-to-tail handoff,
duplicate delivery, crash before/after checkpoint, source/schema changes,
revocation, cancellation and unavailable history. A multi-source vector is only
atomic when its actual transaction-cut evidence establishes that property.
Retain the last complete result while a successor is blocked or incomplete.

Apply event-time/window and correction rules from M12. Motion suppression needs
a predicate-specific stability certificate; movement within one cell that changes
distance or a projected coordinate is a required negative control. Compare every
completed basis against finite recomputation, including retractions, duplicate
polygons/solids and overlapping inputs.

### S11 — Qualify and publish the integrated profile

Run the acceptance journeys below at one committed revision using real public
operations, disk-backed recovery and installed consumers. Preserve earlier failed
and incomplete runs in their owning qualification accounts. Component algorithms,
parser acceptance and neutral-fixture checks do not substitute for these journeys.

Promote supported semantics and limits into the existing type, Table, Stream,
Document, query, Arrow and SQL references; put consolidated spatial mechanisms,
assumptions and oracle correspondence in Internals and package usage beside its
owner. Public explanations must not require this roadmap. Keep capability and
standards records aligned with actual operator and transport coverage.

Run affected clean lanes from [the task inventory](../../tests/runner/suite.json),
including dependent contract/core/storage/query/session/SDK/formal gates selected
by the change. Register new spatial checks with real tasks before citing them.
Closure requires the full scoped function/type matrix, or an explicit roadmap
scope revision preserving unfinished work; the initial planar slice cannot close
M17.

## Type and function coverage retained by this plan

| Family | Planned scope | Delivery owner |
| --- | --- | --- |
| Types and interpretation | GEOMETRY with POINT/LINESTRING/POLYGON/MULTI*/collections, POLYHEDRALSURFACE/TIN and XY/XYZ/XYM/XYZM; GEOGRAPHY; BBOX2D/3D; S2_CELL/H3_CELL/OCT_CELL; explicit CRS/axes/units/precision; MESH3D/SOLID3D/SCENE3D/TRANSFORM3D/POINTCLOUD/TRAJECTORY | S0–S3, S7–S9; every subtype has its own admitted dimension/operation profile |
| Constructors, conversions and validation | `ST_Point`, `ST_MakeLine`, `ST_MakePolygon`, `ST_MakeEnvelope`, `ST_3DMakeBox`, `ST_Extrude`, `ST_Transform`, `ST_RotateX/Y/Z`, `ST_Affine`, `SE3_Transform`; WKT/WKB/EWKB/GeoJSON and selected glTF value conversion; `ST_IsValid[Reason]`, `ST_IsSolid`, `ST_MakeValid`, `ST_3DMakeValid` | S1–S3, S7/S8; repair and conversion never implicit |
| 2D topology | DE-9IM and `ST_Intersects`, `Contains`, `Within`, `Covers`, `CoveredBy`, `Touches`, `Crosses`, `Overlaps`, `Disjoint`, `Equals`, `Relate` | S3/S6; names after the first retain the `ST_` prefix |
| Measurement | Planar and selected geodesic distance/area/length/perimeter/azimuth/centroid/point-on-surface/envelope/extent and `ST_DWithin`; 3D distance/max-distance/shortest-line/area/volume/centroid/inertia/extent | S3/S7; pin metric, dimensional meaning and numeric rules |
| Constructive operations | Intersection/union/difference/symmetric difference, buffer, convex hull, simplify, snap-to-grid, Delaunay triangles and Voronoi polygons; 3D union/intersection/difference/convex hull, tetrahedralization, cross-section and quadric-error mesh simplification | S6/S7; general overlays and approximate simplification have separate profiles |
| 3D predicates and grids | `ST_3DIntersects`, `ST_3DContains`, `ST_3DWithin`, `ST_3DDWithin`, `ST_3DClearance`, `ST_RayIntersects`; S2 point/cell/covering, H3 lat-lng/cell/polygon/grid-disk and OCT point/box/covering/parent/children | S4/S6/S7; grid-specific hierarchy and boundary rules |
| Access paths | 2D/3D box operators `&&`/`&&&`/`@>`/`<@`, metric `<->`/`<<->>`, zone maps, RTREE/S2/H3/OCTREE, Hilbert/Morton clustering and spatial SSI | S4/S5; syntax remains proposed until checked and executable |
| Output and motion | `ST_AsText/Binary/GeoJSON`, `ST_AsMVTGeom`/`ST_AsMVT`, `ST_AsGlTF`/`ST_As3DTiles`, `ST_LOD`; `ST_ValueAtTimestamp`, `ST_LocateAlong`, 2D/3D closest approach and temporal joins | S8/S9; bounded complete output, explicit LOD/tolerance |
| Maintained computation | Union, moment and boundary aggregates, 2D spatial/3D clash joins, pose updates and trajectory geofencing | S10; same finite semantics and source evidence at every completed basis |

ISO SQL/MM Spatial and OGC Simple Features guide the standard 2D subset.
PostGIS/SFCGAL-inspired 3D operations, grid functions and Transit extensions need
explicit capability entries; their names do not establish standards conformance.

## Acceptance and verification matrix

All rows below are **planned checks**, not executed spatial evidence.

| Journey | Required evidence |
| --- | --- |
| Declare and retain interpretation | SQL and typed callers agree on type/CRS/units/grid/definition; rename, ALTER, DROP/recreate and retained branch reads cannot retarget accepted work; unsupported combinations reject before admission |
| Validate geometry and states | Empty versus NULL, malformed rings/shells, NaN/Inf, overflow, self-intersection and unknown CRS; exact diagnostic witnesses; invalid Table writes publish nothing; projected five-state errors/conflicts survive |
| Prove physical representation | Independent bytes and logical round trips for all codecs; corrupt lengths/offsets/connectivity, dictionary references and foreign definitions reject; exact and lossy profiles are distinguishable |
| Preserve large-value ownership | One geometry/mesh larger than a compute or wire batch; page/reset/early-close/cancellation schedules; retained results outlive scratch; memory bounded independently of vertices and total rows |
| Query at one source basis | Full scan agrees with vector/pruned/indexed plans on values, multiplicity, states and failure order; antimeridian, poles, H3 pentagons, mixed resolutions, degenerate and transformed bounds; stable k-NN ties |
| Maintain indexes online | Build from a pinned cut including unflushed rows; concurrent insert/move/delete, duplicate catch-up, missing history, cancellation and process death; publish only complete coverage; old readers survive rebuild/compaction |
| Preserve serializability | Disjoint regions/octants can commit under qualified fine guards; overlapping phantom/write-skew, empty-range, k-NN and movement schedules abort when required; lost decisions recover exactly |
| Exercise topology and 3D | Adjacent and overlapping polygons/solids, duplicates, opposite orientation, cavities and non-manifold inputs; union differs correctly from bag sums; exact finite result matches independent oracle |
| Exercise scenes and trajectories | Shared prototypes, cyclic DAG refusal, deep assemblies, pose-bound changes, point-cloud outliers, late events and within-cell predicate changes; approximate LOD/tubes never masquerade as exact results |
| Preserve incremental results | Insert/delete/retract/both-input updates, topology edits and pose changes match finite recomputation at each completed basis; restart/checkpoint/spill preserve multiplicities and exact source frontiers |
| Enforce current permission | Denied declaration/build/read/inspect, revocation after buffering, metadata/empty/terminal results, spill reads and worker replacement; no coordinate or diagnostic disclosure under stale `policy_epoch` |
| Recover accepted writes and work | Lost admission/commit/publication replies and process death retain original operation/decision; cancellation races do not invent rejection or rollback; incomplete results never become complete replacements |
| Bound resource use and lifetime | Sparse/dense/all-overlap workloads exceed RAM under fixed reserves; admitted spill profiles complete using actual spill, while exhausted quotas refuse without changing prior accepted state; pins/prototypes/checkpoints survive GC; no quota-triggered expiry |
| Verify real callers | Installed console and typed Zig path, affected SDK/ABI and wire mappings, independent Arrow consumers where admitted; incompatible builds and saved artifacts reject before execution |

Use independent GEOS/PostGIS fixtures for 2D, GeographicLib for geodesics,
CGAL/SFCGAL for selected 3D profiles and upstream S2/H3 plus an independent
octree oracle for grids. Pin oracle versions, input hashes, licenses, coordinate
rules and tolerance; compare semantic results where serialization order differs.
Reference engines run in qualification tooling only. Expected results must not
be regenerated from the same Transit algorithm under test.

Coordinate with [M21](21-formal-semantics-and-correspondence.md): A2 covers
conservative spatial bounds/coverings and transform inflation, A3 covers
qualified boundary/occupancy and join delta equivalence, and A5 covers selected
codec/bitmap round trips. Extend models with explicit assumptions and connect
them to executable Zig negative controls. No unexecuted theorem or bounded model
substitutes for disk recovery, arithmetic or deployment evidence.

## Resource and performance qualification

Freeze workload sizes, hardware, compiler/build, oracle versions, precision,
durability, isolation, concurrency and resource limits in S0. Report scalar
baseline, full scan, vector scan, each access method, topology codec and
incremental path separately, then run the installed composed journey.

Include points, road lines, polygon coverages and overlaps, global coastlines,
watertight/cavity solids, repeated assemblies, dense LiDAR and moving entities.
Use uniform, clustered, skewed and adversarial all-overlap distributions;
warm/cold cache, beyond-RAM input and concurrent maintenance/revocation are
separate cases. Compare PostGIS/SFCGAL and DuckDB Spatial only on equivalent
supported semantics; preserve unsupported cells and regressions in the scorecard.

Measure first-row and verified-completion p50/p95/p99, sustained rows/features
per second, candidate and narrow-phase counts, bytes read/written, write
amplification, checkpoint/recovery time, maximum resident/scratch/spill bytes,
allocation attempts and denied/incomplete outcomes. Compression reports all
metadata, residuals, topology and refinement bytes.

The hot-path gate is zero steady-state heap/OS allocation attempts after the
declared warmup for admitted scan/filter/join kernels, checked with
`AllocationProbe` and relevant backing-owner observations. Report setup,
decoding, refinement, exact arithmetic and spill separately; do not generalize a
kernel result to the whole service. Select numeric latency/throughput and
regression budgets from reproduced baselines before optimization.

The earlier 3–6× delta compression, sub-two-bits/triangle connectivity,
sub-byte point-cloud and >95%/>98% pruning figures are hypotheses to measure,
not admission guarantees or completed evidence. Spill must be actual bounded
I/O through M13/M12 owners; increasing resident arrays or a run counter is not
spill. Preserve control/recovery reserves and typed refusal when a profile
cannot execute within its allowed resources.

Spatial joins, boolean overlays, point-cloud scans and MVT/3D Tiles aggregation
must each demonstrate their admitted beyond-RAM path using real Tier 2 spill
within the configured disk/work quota. A safe refusal tests resource enforcement
but does not satisfy that successful-execution gate.

## First implementation changes

1. Land S0's descriptors, canonical fixtures, semantics/capability matrix and
   complete consumer/cutover inventory. Resolve precision/layout and union/
   covering assumptions before assigning binary tags.
2. Land S1's bounded exact predicates and scalar planar reference implementation,
   including degeneracy, overflow and allocation controls.
3. Deliver S2/S3's installed planar Table journey through stored values, finite
   SQL, shared results and original-operation recovery; keep other profiles
   explicitly unavailable.
4. Add S4/S5 only against M11's qualified lifecycle, while extending topology
   and 3D kernels with independent finite oracles. Do not expose a private
   experimental index as an installed catalog capability.
5. Integrate S9/S10 when retained Stream/Document sources and durable M12
   arrangements meet their gates, then run S11 at one common revision.

## Later owners

- [M18 multi-model and foreign relations](18-multi-model-and-foreign-relations.md)
  composes spatial/3D coboundary adjacency with property graphs, routing, WCOJ
  and lexical/vector/spatial hybrid search. It owns foreign/COPY adapters for
  GeoParquet 1.1, FlatGeobuf, GeoArrow, Shapefile/GeoPackage, PMTiles/MVT,
  glTF/GLB, OpenUSD, IFC, STEP, CityGML/CityJSON, 3D Tiles and LAS/LAZ/COPC.
  M17 supplies typed values, codecs and spatial operators; it does not imply
  those complete external source lifecycles.
- [M19 branches](19-branches-merges-and-restore.md) consumes conservative spatial
  summaries and stable topology/prototype identities for DIFF and three-way
  merge. Conflicting edits and clashes need explicit merge policy and
  `IS CONFLICT` evidence; compression alone establishes neither.
- [M20 service and SDK coverage](20-service-and-sdk-coverage.md) owns additional
  language/platform exposure. M17 still migrates every existing consumer affected
  by its type/ABI cutover and proves representative installed spatial callers.
- [M21 formal correspondence](21-formal-semantics-and-correspondence.md) owns the
  broader A2/A3/A5 proof program while M17 supplies concrete spatial invariants,
  counterexamples and implementation hooks.
- [M26 policy](26-control-and-policy-plane.md) adds spatial RLS and security
  barriers. M17 preserves current source rights and prevents pruning/errors
  from bypassing those checks; it does not enable policy helpers as an RLS service.
- [M29 Board](29-board-reimplementation.md) renders maps, progressive mesh/scene/
  point-cloud views, cross-sections, trajectories and conflict overlays through
  public results. No raw segment access or separate map permission authority.
- [M34 standards](34-sql-grammar-and-dialect-ergonomics.md) audits the complete
  selected spatial grammar and dialect coverage. M17 still owns correct checked
  grammar and explicit unsupported forms as each implementation lands.
- [M35 qualification](35-qualification-and-benchmarks.md) combines spatial evidence
  with the broader workload matrix; local M17 correctness, recovery and resource
  gates cannot be postponed to that milestone.
