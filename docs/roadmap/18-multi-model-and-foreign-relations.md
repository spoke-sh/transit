# 18. Multi-model and multi-format foreign relations

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Compose KV, Table, Document, Graph, 2D/3D Geospatial, Volumetric 3D Model and external dataset formats using the
[`.tseg` codec and collation architecture](02-storage-and-query-performance.md),
[logical Document storage](07-document-storage-and-station-decoupling.md),
[standards/semantic contracts](10-standards-and-catalogs.md),
[declaration/dataflow lifecycle](12-sql-and-dataflows.md),
[Document Type & Protocol Library (`JSON`, `XML`, `HTTP`, `FTP`, `EDI`, `SMTP`/`IMAP`/`POP3`, `LDAP`, `SIP`, `AMQP`, `MQTT`, `NTP`, `PDF`, `DOCX`, `XLSX`, `ODF`)](16-document-profiles-and-gateway-exchange-lifecycle.md) and
[2D/3D geospatial types, volumetric 3D compression and spatial indexing](17-geospatial-and-spatio-temporal-computing.md).

Use the shared object/definition identities, policy references and inspection
model from the [data lifecycle](01-declarative-data-lifecycle.md). Every
projection or foreign table must expose its schema, physical encoding, collation,
captured manifest basis, dependencies and 5-state completeness through the shared
reader/column-array boundary specified in
[#128](https://github.com/spoke-sh/transit/issues/128). Codec/collation correctness
belongs to [#118](https://github.com/spoke-sh/transit/issues/118); native
KV/Document persistence belongs to [#126](https://github.com/spoke-sh/transit/issues/126).
This milestone adds projections and actual foreign adapters, not another native
storage engine. This milestone receives typed `COPY`/import/export operations
from the dataflow owner and qualifies them with the actual adapters. Reuse
[transaction admission and outcomes](05-transactions-and-atomic-composition.md)
and the direct-ingestion protocol. Each format becomes executable only when its
adapter and caller path are qualified; external sources are not automatically
participants in a native atomic commit.

## Delivery sequence

Reuse [index identities, maintenance and coverage](11-indexing-and-access-paths.md)
and [first-class strings and vectorized search](14-vectorized-strings-and-search.md)
for graph adjacency, admitted document projections, **segment-backed lexical,
substring/proximity and structural search** (starting with 256-doc Block-Max
BM25) and **Vector / Hybrid Search** across Tables, Documents and
foreign projections. Qualify each specialized key/predicate, analyzer/segmenter,
proximity relation, scoring/distance function and source-refresh profile; ordered
index support alone does not deliver inverted full-text, positional/span,
document-path or vector search without the dedicated segment layouts and
recall/exactness contracts below. External statistics and indexes must match the
captured manifest and comparison semantics. Extend the
[performance scorecard](13-data-structures-and-performance.md) and
[string/search scorecard](14-vectorized-strings-and-search.md) with actual
foreign decoding, pruning, graph multiplicity, multi-model lexical/structural/vector
retrieval, streaming CDC ingestion and import/export costs.

1. **Define explicit Document-to-SQL (`DOCUMENT_TABLE`) and richer multi-model projections with stable identities:**
   specify `missing`/`null`/`conflict`/`type_error` and arithmetic overflow
   behavior across [Milestone 7's](07-document-storage-and-station-decoupling.md)
   logical Document trees and [Milestone 16's](16-document-profiles-and-gateway-exchange-lifecycle.md)
   structured, protocol and compound document profiles (including `XLSX`/`ODS`
   worksheet projections and `PDF` layout spans) with no implicit conflict
   winner or silent default value.
2. **Map finite property graphs, 2D spatial networks and 3D coboundary / scene-graph topologies over existing resources:** lower fixed-pattern
   SQL/PGQ through graph-aware `Fuze` operators and
   [Milestone 13's](13-data-structures-and-performance.md) Diamond-Hardened /
   Worst-Case Optimal Joins (WCOJ) over `.tseg` adjacency/edge indexes—and compose
   property graphs with [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md)
   2D topological networks (`.topo_arc` road/parcel graphs), **3D cellular
   coboundary dual graphs ($\delta_2 = \partial_3^\top$ mapping shared `.topo_face`
   2-faces to `(left_solid, right_solid)` room-connectivity, thermal/fluid-flux
   and mechanical-mating graphs)**, hierarchical `SCENE3D` assembly DAGs
   (`.scene_dag`) and multi-way 2D/3D spatial intersection and BIM/CAD clash
   graphs (`A*` / 2D & 3D shortest-path routing with Euclidean/geodesic distance
   heuristics)—so triangle and cyclic graph patterns avoid quadratic intermediate
   blowups while preserving parallel edges, self-loops, endpoint validity and
   multiplicity.
3. **Compose segment-backed lexical/structural search, 2D/3D spatial coverings and Vector / Hybrid Retrieval across Tables, Documents, 3D Scenes and Graph projections:**
   build on [Milestone 14's](14-vectorized-strings-and-search.md) declarative
   search boundary, 256-document Block-Max posting blocks, vectorized
   `MAXSCORE` / Block-Max WAND operators,
   [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md) `.s2_roaring`
   / `.h3_roaring` / `.octree_roaring` 2D and 3D spatial coverings and ANN vector
   indexes (over [Milestone 10's](10-standards-and-catalogs.md) unboxed
   `VECTOR(dim, T)` slabs) to keep multi-model search and AI/agent retrieval
   inside Transit's data gravity, `SnapshotId` cuts, branches and `policy_epoch`
   governance without locking queries into a flat bag-of-words model:
   - **Document and Multi-Model Lexical, Positional and Structural Indexes:**
     extend `.tseg` search index segments (Block-Max BM25, positional/proximity
     `NEAR` streams, and substring/trigram or structural span profiles) over
     Document blocks, CAD/BIM part metadata and projected JSON/structured paths,
     respecting declared collations/segmenters, `.tdel` deletion vectors, online
     snapshot-to-tail maintenance, SIMD bitmask intersection with
     relational/graph/2D-3D-spatial predicates and late materialization.
   - **Multi-Model Vector Similarity and Geo- & 3D-Filtered Hybrid Search:** compose fixed-dimension
     `VECTOR(dim, T)` embedding columns (including text, image and 3D shape/part
     embeddings) and disk-backed quantized/graph ANN index segments
     (such as DiskANN/HNSW with explicit exact-oracle recall reporting) across
     Table, Document, 2D/3D Spatial (`ST_Intersects` / `ST_3DIntersects` via
     `S2` and `OCT_CELL` Roaring bitmask intersection)
     and Graph queries with temporal `AS OF` cuts,
     security-barrier RLS and lexical/structural scores in a single hybrid
     query plan, handing off reactive context subscriptions to
     [Milestone 32](32-reactive-context-and-agent-activation.md) and
     declarative sequence/context synthesis research to
     [Milestone 38](38-declarative-language-context-and-synthesis.md).
4. **Implement multi-format `FOREIGN TABLE` and `COPY` readers over POSIX and `TransitObjectStore` (S3/GCS/R2):**
   - Bind external object-store and HTTP credentials through catalog `SECRET`
     declarations (`CREATE SECRET ... TYPE s3 | gcs | r2 | http ... SCOPE ...` in
     [Milestone 27](27-control-and-policy-plane.md)), requiring both an exact
     destination `SCOPE`/`TLS_POLICY` match and `USAGE ON SECRET` under the
     caller's `AccessContext` at `policy_epoch` so URI prefix matching never
     grants ambient authority or stores cleartext keys in table definitions.
   - **Analytical and 2D spatial columnar/raster formats (`PARQUET`, `GEOPARQUET`, `ARROW_IPC`, `GEOARROW`, `FLATGEOBUF`, `COG` (Cloud-Optimized GeoTIFF), `PMTILES` / `MVT`):** use qualified
     borrowed layouts or bounded decoding for column chunks/dictionaries and
     [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md) `.geoarrow`
     coordinate vectors and `.raster_morton` overview tiles, with row-group
     statistics (`min`/`max`/null count and `GeoParquet` v1.1 `bbox` covering
     metadata, `COG` IFD tile pyramids or `FlatGeobuf` packed Hilbert R-tree
     headers) driving sound 1D and 2D pruning. Capture immutable
     file manifests (`ETag`/`SHA-256`, byte length, row count) for repeatable
     snapshot reads, and support `PMTiles` / `MVT` vector tile, `COG` raster and `Shapefile` /
     `GeoPackage` import/export.
   - **3D model, CAD/BIM, scene-graph, volumetric and point-cloud formats (`GLTF` / `GLB`, `OPENUSD` (`USDA`/`USDC`/`USDZ`), `KTX2`, `OPENVDB` / `NANOVDB`, `IFC` (`ISO 16739`), `STEP` (`ISO 10303-21`), `CITYJSON` / `CITYGML`, `3DTILES` (`OGC 1.1`), `LAS` / `LAZ` / `COPC`):**
     project 3D assets, engineering assemblies, urban digital twins and LiDAR
     scans into [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md)
     `MESH3D`, `SOLID3D`, `SCENE3D` (`.scene_dag` prototype dictionaries +
     48-byte `TRANSFORM3D` $SE(3)$ instance rows), `.topo_face` coboundary
     tables, `.octree_roaring` coverings and `.pcloud_hilbert` blocks, handing
     off virtualized meshlet cluster DAGs, block-compressed texture mip
     pyramids, skeletal animations, WAL-activated DDC cooking, incremental
     `NavMesh` maintenance and ECS AoI streaming to
     [Milestone 19](19-game-asset-pipelines-and-simulation-streaming.md):
     - *`glTF 2.0` / `GLB` and `OGC 3D Tiles 1.1`:* zero-copy or bounded-decoded
       binary buffer views, node-hierarchy DAGs, PBR material properties and
       hierarchical tile bounding volumes (`BBOX3D` / bounding sphere) with
       progressive `.mesh_edgebreaker` wavelet LOD generation.
     - *`OpenUSD` (`USDA` / `USDC`Crate / `USDZ`):* map USD `Prim` paths, `Xform`
       $SE(3)$ stacks, `PointInstancer` arrays and composition arcs (`subLayers`,
       `references`, `payloads`, `variants`) onto `DocumentPartition` succinct
       trees ([Milestone 7](07-document-storage-and-station-decoupling.md)) and
       `.scene_dag` relational projections.
     - *`IFC` (`ISO 16739` STEP-Physical-File / `IFC-JSON`) & `STEP` (`ISO 10303-21` `AP214`/`AP242`) and `CityJSON` / `CityGML`:*
       parse `EXPRESS` entity graphs (`#id = IFCSLAB(...)`, `IfcWall`,
       `IfcSpace`, `IfcRelSpaceBoundary`, `ADVANCED_BREP_SHAPE_REPRESENTATION`)
       into relational entity tables, SQL/PGQ property graphs and tessellated /
       exact `.topo_face` `SOLID3D` volumes, surfacing non-manifold edges or
       unclosed B-Rep shells as `IS TYPE_ERROR` cells with `#entity_id`
       provenance.
     - *`LAS` / `LAZ` and `COPC` (Cloud-Optimized Point Clouds):* stream octree
       hierarchy pages via HTTP Range requests over `TransitObjectStore`,
       pruning 3D octants by `BBOX3D` / `OCT_CELL` before decoding point chunks
       into `.pcloud_hilbert` vectors.
   - **Scientific, CFD mesh & multi-dimensional continuum array formats (`CGNS`, `VTK` / `VTU` / `VTI` / `PVD`, OpenFOAM `polyMesh` + field directories, `Zarr v3`, `NetCDF-4` / `HDF5`, `GRIB2`, `EXODUS II`, `Alembic` `.abc`):**
     project standard simulation, weather/ocean and finite-volume/finite-element
     containers onto [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md)
     `.topo_face` cellular complexes, topology-decoupled `COCHAIN_FIELD` columns
     (`.float_zfp`), `RASTER2D`/`GRID3D` (`.raster_morton`) and
     [Milestone 19's](19-game-asset-pipelines-and-simulation-streaming.md)
     continuum simulation streaming operators:
     - *`CGNS` (CFD General Notation System) & `EXODUS II`:* map `CGNSBase_t` /
       `Zone_t` structured and unstructured zones, `Elements_t` connectivity,
       `GridCoordinates_t`, `FlowSolution_t` (`Vertex` $C^0$, `EdgeCenter` $C^1$,
       `FaceCenter` $C^2$, `CellCenter` $C^3$) and `ZoneBC_t` boundary-condition
       patches onto `.topo_face` meshes and `COCHAIN_FIELD` time-series columns.
     - *OpenFOAM native `polyMesh` + time-directory fields:* ingest
       `constant/polyMesh/{points,faces,owner,neighbour,boundary}` directly into
       `.topo_face` coboundary tables ($\delta_2 = \partial_3^\top$, permuted by
       `HILBERT_3D` / `RCM`) and stream timestep field files (`0.001/{U,p,phi,T}`)
       into `.float_zfp`-compressed $C^3$ cell-state and $C^2$ face-flux cochain
       columns without duplicating mesh topology across timesteps.
     - *`VTK` / ParaView XML & binary formats (`VTU` unstructured grids, `VTI` image grids, `VTP` polydata, `PVD` time-series collections) & `Alembic` (`.abc` cached VFX geometry/particles):*
       zero-copy or bounded-decoded projection of appended binary `DataArray`
       blocks into `.topo_face`, `.pcloud_hilbert` and `COCHAIN_FIELD` vectors.
     - *`Zarr v3`, `NetCDF-4` / `HDF5` & `GRIB2` (chunked N-dimensional scientific/climate/turbulence arrays):*
       map cloud-native chunked N-D hypercubes onto `RASTER2D`/`GRID3D`
       (`.raster_morton` + `.float_zfp`) via HTTP Range requests over
       `TransitObjectStore`, pushing spatial/temporal slice predicates (`BBOX2D`/`BBOX3D`,
       vertical pressure levels, time ranges) down to chunk directories before
       decoding.
   - **Text and semi-structured formats (`CSV`, `JSONL`):** bounded streaming
     parsers that record malformed fields as `type_error` or `missing` cells
     rather than aborting scans.
   - **Enterprise & mainframe sequential datasets (`FIXED_RECORD` / `FB`, `VARIABLE_RECORD` / `VB` with 4-byte `RDW`):**
     declarative record and COBOL Copybook layouts supporting `EBCDIC` codepages
     (`CP037`, `CP1047`, `CP500`), `COMP-3` (BCD packed decimal), `ZONED`
     (overpunched zoned decimal), `COMP`/`COMP-4` (big-endian scaled binary),
     `IBM_HFP` (`COMP-1`/`COMP-2` hexadecimal float), fixed `OCCURS` arrays, and
     `REDEFINES` variants with explicit selection and five-state interpretation.
     Allow foreign mainframe datasets to be queried in place or
     compacted into native `.tseg` segments while preserving source collation
     (`COLLATE EBCDIC_037_PAD`).
     Preserve layout/codepage/collation fingerprints and original-byte diagnostic
     provenance through read, materialization and export. A five-state tag alone
     does not establish lossless source preservation. Distinguish field-local
     conversion failures from unreadable/corrupt record framing; incomplete
     capture must not be published as a complete relation.
5. **Deliver typed import/export and continuous Change Data Capture (CDC) ingress:**
   support native `.tseg`, Parquet/`GeoParquet`, Arrow IPC/`GeoArrow`, `glTF`/`3D Tiles`, `LAS`/`LAZ`, `CGNS`/`VTU`/`Zarr`/`NetCDF` and CSV/JSONL transfer with explicit
   schemas, codecs, collations, five-state/error policy and bounded progress.
   Alongside batch `COPY`, provide governed **streaming CDC and logical-replication
   ingress adapters** (consuming external change envelopes such as PostgreSQL
   logical replication, MySQL binlog and Debezium/Kafka CDC streams) that apply
   ordered inserts, updates, deletes, schema-evolution checks and source
   watermarks into native Transit Tables with idempotent checkpoint recovery.
   Define import and CDC transaction scope, whole-operation versus watermark-committed
   publication, cancellation and original-operation recovery. Stage/verify data
   before atomic publication where promised; export bytes are external
   disclosure/effects and cannot be undone by database rollback. Qualify each
   actual format/direction.
6. **Extend maintained composition after independent finite verification:**
   include updates/deletes, graph changes, 2D/3D spatial and scene-graph pose updates, full-text/vector index catch-up,
   streaming CDC watermarks, captured foreign-manifest refresh and backfill.
   Completed source bases must equal finite recomputation.

## Completion evidence

Use independent relational, graph, 2D/3D spatial/CAD/BIM, scientific/CFD (`CGNS`/`VTU`/`OpenFOAM`/`Zarr`) and mainframe-dataset oracles and current
source rights. Qualify changed or missing files/objects, ETag mismatches,
interrupted captures, corrupted `COMP-3` nibbles / `HIGH-VALUES` (`0xFF`) / space
padding (`0x40`), non-manifold/open 3D shells ($\partial_2 \partial_3 V \neq 0$) or `NaN`/mismatched-cardinality `FlowSolution_t` cochain fields surfaced as `IS TYPE_ERROR`, EBCDIC-collated joins against
UTF-8 tables, `IFC`/`glTF`/`OpenUSD`/`COPC`/`CGNS`/`VTU`/`Zarr` foreign projections and 3D clash/adjacency/flux queries, lost acknowledgements, revocation after partial disclosure, invalid
graph endpoints and datasets exceeding resident RAM and NVMe caches.

Qualify a captured mainframe dataset through foreign query, native Table
materialization and export with independent byte/value oracles. Include
PAD/NO PAD behavior, mixed-collation resolution or rejection, malformed bytes,
REDEFINES selection, rounding/overflow and retained diagnostic provenance.
Document which physical layouts can be borrowed, decoded or operated on while
encoded; no format name alone promises universal zero-copy interoperability.

External writes remain separately activated recorded effects. Declarations do not
grant raw filesystem, network or backend access. Publish grammar, types, encodings,
collations, bounds and exclusions through consistent capability views across
shared interfaces.
