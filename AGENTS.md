# Working on Transit

## Before changing code

Transit is programmable, versioned data infrastructure for applications. Data,
computation and policies are the primary user-facing model; durable execution,
write-ahead change logs (`TransitLog`), and tiered segment storage
(`TransitObjectStore`) explain how Transit activates those declarations and
preserves their accepted changes, progress and outcomes. Start with the
[data model](docs/handbook/reference/data-model.md) and ask: can someone describe
what they need, then inspect whether Transit is fulfilling that declaration?

Read [README.md](README.md), the [public documentation index](docs/README.md),
[architecture and scope](docs/handbook/reference/architecture.md), and the
[system internals](docs/handbook/internals/README.md) first. Users,
developers and agents share these same guides and references. Use the
[glossary](docs/handbook/reference/glossary.md) for names and the
[component directory](docs/handbook/reference/components.md) to find the affected
package/app README, configuration and limits. Treat proposals as intent, not
implemented behavior.

Follow the public explanations and exact contracts for the area you change:

| Area | Required references |
| --- | --- |
| Protocol, processes, ownership | [Processes](docs/handbook/reference/processes.md), [execution model](docs/handbook/internals/execution-model.md), [native v1 contract](contracts/TRANSIT_V1.md) |
| Authentication, grants, credentials, trust | [Security](docs/handbook/reference/security.md), [service contract](contracts/SERVICE_V1.md) |
| Storage, delivery, producer/consumer behavior | [Streams](docs/handbook/reference/streams.md), [storage boundary](docs/handbook/reference/storage.md), [storage runtime](docs/handbook/internals/storage-runtime.md) |
| State resources, associations, KV/Table/Document APIs | [State](docs/handbook/reference/state.md), [Tables](docs/handbook/reference/tables.md), [Documents](docs/handbook/reference/documents.md), [state model](docs/handbook/internals/state-model.md), [state contract](contracts/STATE_V1.md) |
| Declarative interfaces and query execution | [SQL](docs/handbook/reference/sql.md), [queries](docs/handbook/reference/queries.md), [query engine](docs/handbook/internals/query-engine.md), [applications](docs/handbook/reference/applications.md), [grammar](contracts/sql/README.md) |
| Arrow IPC/C interfaces, Flight SQL, ADBC | [Arrow](docs/handbook/reference/arrow.md), [Flight](docs/handbook/reference/flight.md) |
| Inbound HTTP APIs and service publication | [Serving](docs/handbook/reference/serving.md), [OpenAPI](docs/handbook/reference/openapi.md), [serving contract](contracts/SERVING_V1.md) |
| SSE/WebSocket, sessions, watches and live views | [Reactive](docs/handbook/reference/reactive.md), [AsyncAPI](docs/handbook/reference/asyncapi.md), [reactive contract](contracts/REACTIVE_V1.md) |
| Lifetimes, expiry, compaction, deletion, capacity | [Retention](docs/handbook/reference/retention.md) |
| Caller APIs and language bindings | [Caller semantics](docs/handbook/reference/callers.md), [SDKs](docs/handbook/reference/sdks.md), [public protocol package](packages/zig/transit-protocol/README.md) |
| Operator/agent inspection and Board UI/API | [Board guide](docs/handbook/guides/inspect-board.md), [Board API](docs/handbook/reference/board-api.md), [SQL](docs/handbook/reference/sql.md) |
| Logs, metrics, traces, probes | [Observability](docs/handbook/reference/observability.md) |
| Behaviors, supervision, names | [Station](docs/handbook/reference/station.md) |
| Effects, capture, secret interpolation | [Connectors](docs/handbook/reference/connectors.md), [HTTP](contracts/STATION_HTTP_V1.md), [gRPC](contracts/STATION_GRPC_V1.md) |
| Kubernetes, provider bindings, recovery | [Deployment](docs/handbook/reference/deployment.md), [runtime contract](contracts/RUNTIME_SUBSTRATE_V1.md) |
| Installation, bootstrap and replacement | [Applications](docs/handbook/reference/applications.md), [installation contract](contracts/APPLICATION_INSTALLATION_V1.md) |
| Local/Compose lifecycle and developer environments | [Launchers](launchers/README.md), [contributing](docs/handbook/guides/contributing.md) |

Read [guarantees and verification limits](docs/handbook/reference/verification.md) and
[executed proof evidence](docs/history/qualification/README.md). Preserve the proved authority,
readiness and recovery gates before extending a profile. Distinguish planned
checks from executable evidence; never treat a skipped or incomplete proof as passed.
Tie work to the [roadmap](docs/roadmap/README.md), consulting only the
relevant milestone or historical review for scope and rationale. Planning and
historical records must not be required to discover current user-facing semantics. Promote newly
established behavior, limits and reasoning into the public owner with the change.

## Implementation rules

- Design from the data lifecycle. Identify the data kind, stable object and
  definition identities, dependencies, computation lifetime, policies and
  observable outcomes before choosing workers, messages or transports. Separate
  the **Control & Policy Plane** (catalog, schemas, grants, retention, branch
  manifests), the **Direct Data Plane** (partitioned write-ahead logs, in-memory
  memtables/buffer pools, local NVMe caches, and immutable `.tseg` segments),
  and the **Process & Effect Plane** (`Station` actors and connectors). Direct
  data-plane ingestion and analytical scans must not be bottlenecked by actor
  mailbox frame limits when no custom actor logic is invoked. Reuse the owning
  public operations across SQL, SDKs and UI; do not create another configuration
  or permission authority. Separate validation, publication, activation, progress
  and completion. A common catalog and service-managed reconciliation are planned
  extensions, not assumptions about current behavior.
- Keep logical types ($\tau$: scalars, `RANGE<T>`/`MULTIRANGE<T>`, unboxed
  `VECTOR(dim, T)`, `GEOMETRY`/`GEOGRAPHY`/`MESH3D`/`SOLID3D`/`SCENE3D`/`POINTCLOUD`/`RASTER2D`/`COCHAIN_FIELD`/`BBOX`/`S2_CELL`/`H3_CELL`/`OCT_CELL`/`TRAJECTORY`,
  and game/simulation assets `TEXTURE2D`/`VOLUME_GRID`/`SPLAT3D`/`SKELETON3D`/`ANIMATION_CLIP`/`NAVMESH`),
  physical codecs ($\epsilon$: bitpacking, RLE, dictionary, FSST, mainframe
  `COMP-3`, `ZONED`, `COMP`/`COMP-4`, `IBM_HFP`, `EBCDIC`, spatial/3D/continuum `.geoarrow`,
  `.twkb_delta`, `.mesh_edgebreaker`, `.topo_arc`, `.topo_face`, `.s2_roaring`,
  `.octree_roaring`, `.raster_morton`, `.float_zfp`, and interactive asset `.mesh_cluster_dag`,
  `.tex_mip_morton`, `.vdb_hierarchy`, `.splat_hilbert`, `.skin_weights`, `.anim_acl`),
  and semantic/ordering rules ($\kappa$: text collations `UTF8_BINARY`, `ASCII_CI`,
  `EBCDIC_CP037`, `ICU:<locale>`; spatial reference/manifold/precision descriptors
  $\kappa_{\text{spatial}}$ with SRID, `PLANAR`/`GEODESIC`, snap-rounding grid
  $\delta_{\text{grid}}$, Shewchuk exact predicates and `S2_HILBERT`/`H3`/`HILBERT_3D`/`RCM`
  order; asset/navigation target profiles $\kappa_{\text{asset}}$ / $\kappa_{\text{nav}}$;
  vector metrics $\kappa_{\text{metric}}$; deterministic decimal rounding and
  error-bounded float tolerances $\kappa_{\text{numeric}}$; and manifest-pinned IANA `tzdb` versions
  $\kappa_{\text{tz}}$) orthogonal in query and storage design. Zone maps
  (including 2D/3D bounding-box and `S2`/`H3`/`OCT_CELL` cell summaries) and
  B-tree/R-tree sort keys must respect the declared $\kappa$ descriptor so pruning is sound.
- Keep Transit-owned package versions and exact internal dependency pins aligned
  with the root `VERSION`; follow the [release workflow](build/README.md#changing-the-release-version).
  Run `python3 -B tasks/version.py` after changing manifests. Keep release SemVer,
  Git provenance and protocol-definition identity separate; never move a published tag.
- Follow the [versioning policy](docs/handbook/reference/versioning.md). Before Transit
  1.0, every Transit-owned protocol, wire format, schema and ABI has one current
  definition named v1. Breaking changes replace that definition through a hard
  cutover; do not add v2/v3, parallel legacy profiles, compatibility shims,
  fallback decoders or deprecated routes. Remove superseded implementations and
  migrate their consumers, generated contracts, fixtures, examples and public
  documentation together. Keep upstream protocol versions and application-owned
  revisions separate. A v1 label alone never establishes compatibility between
  different builds. Reject incompatible peers, saved requests and stored formats
  before execution; never reinterpret old accepted work or silently reset data.
  Preserve existing safety/recovery checks while replacing their protocol inputs.
  Replace the shared contract definition identifier on every incompatible
  cutover, including stored framework semantics and ABI changes. Regenerate
  schemas, binding resources and signing fixtures; preserve rejection checks
  for missing or foreign definitions. Do not default a persisted compatibility
  field to the current definition when reading old artifacts.
- Keep the Transit kernel generic and Station above it. Reasoning loops, goals,
  delegation, and trading policy belong to applications; LLM/tool access belongs
  in connectors.
- Name runtime artifacts and deployments Transit. This repository develops the
  data and execution system. Board, Station and Fuze belong to Transit;
  use `transit-board*`, `transit-station*` and `transit-fuze*` for their artifacts.
  Keep their readable names in prose. Follow the [glossary](docs/handbook/reference/glossary.md)
  for roles.
- Write kernel, framework, connectors, and backends in Zig. Use strict TypeScript
  and Vite+ for frontends. Keep external infrastructure in its upstream language.
  Language bindings, public SDKs, host adapters, examples and
  conformance tests may use their target languages; share the Zig client/framework
  through the [binding boundary](docs/handbook/reference/callers.md#language-neutral-boundary) instead of duplicating
  protocol semantics. Keep query execution Zig native and outside kernel authority;
  follow [Fuze](docs/handbook/reference/queries.md) for DataFusion/Acero inspiration and query boundaries.
  Neither upstream engine is a runtime dependency.
- Keep generated wire/ABI declarations separate from language-native public APIs.
  SDKs own types, codecs, handler dispatch, scheduling and packaging; the shared
  Zig implementation owns protocol and framework semantics. Preserve uncertainty,
  durable call identity and cancellation distinctions through convenience APIs;
  host tasks and handler fields are not durable state.
- Design Board and other operator interfaces as views over Transit's declarative
  model. Map objects, forms, diagrams and actions to the SQL grammar and shared
  typed contracts in [Query language](docs/handbook/reference/applications.md#declarative-application-interfaces).
  SQL, visual editing, CLI and SDK surfaces must share validation and semantics:
  queries lower to Fuze plans; declarations and controls use their owning public
  operations, never a separate UI configuration authority. Show definitions,
  dependencies, proposed changes and observed state distinctly. Distinguish
  executable syntax, reference-grammar-only forms and missing grammar/semantics;
  propose missing contracts explicitly instead of inventing runnable SQL or
  treating parser acceptance as execution support. Edits may schedule qualified
  read queries in a visible, scoped Live worksheet session, as proposed in
  [Board console D4](docs/design/board-console/D4.md#live-execution-snapshot-and-stream).
  Keep exact, speculative and earlier-draft results distinct; bind work to its
  draft, query, source basis and budget. Probability may guide scheduling, never
  authorization or result truth. Editing does not implicitly apply administrative
  changes or dispatch external effects. Live execution and continuous queries
  require their own contracts; preserve the implemented explicit-submit profile.
- Respect the architecture's dependency direction. Core depends on the public
  protocol, never Station or a provider. Applications use the client; the node
  must not import handlers or claim protocol validation proves honest computation.
- Keep deterministic transitions separate from storage, clocks, and effects.
  Make Zig allocation, ownership, lifetimes, errors, and resident bounds explicit.
  Separate transient `scratch` arenas (reset per page, batch, or turn with
  `.retain_capacity` or `FixedBufferAllocator`) from retained `output` allocations;
  never initialize and free a heap-backed `ArenaAllocator` inside per-row or
  per-record hot loops. Durable backlog is not an in-memory queue. Never silently
  discard accepted work.
- Keep durable collection size independent of resident memory. Bound pages,
  caches, operation batches and active work; enforce explicit deployment quotas.
  Target zero steady-state OS/heap allocations after warmup on hot storage,
  protocol, and vectorized query paths through reusable slabs and bounded arenas.
  Do not introduce fixed total-cardinality arrays, raise constants or require
  retention opt-in as a substitute for the paged durable-state foundation.
- Enforce current scoped authorization separately from PID ownership, including
  reads/replay. Preserve fencing, permanent retirement, and recorded destinations;
  provider state, names, and restored snapshots cannot grant execution rights.
- Retention defaults to unlimited and requires application opt-in. Keep expiry,
  reconciliation closure, and physical cleanup distinct. Quota pressure and
  storage outages never authorize expiry; preserve control/recovery evidence.
- Follow the implemented state-resource profile: associations do not grant access
  or imply lifetime ownership. Preserve the commit boundary between mutations,
  input progress, and outputs. A native turn can mutate at most one KV resource;
  inline values do not acquire resource dependencies implicitly. Consult the
  [state contract](contracts/STATE_V1.md) for exact bounds and compatibility.
- Put effects behind recorded intents, authorization, and outcomes. Replay must
  not dispatch. Unknown remote outcomes require connector policy; closure cannot
  promise external cancellation or make retry safe. Keep secrets as references
  in transcripts and keep credentials/private datasets out of Git and logs.
- Use the pinned `ursula`/`ursulactl` overlay tools and upstream `ursula-zig` only
  inside the Ursula backend. Pin external Zig revisions/hashes in the consuming
  package. Use disk-backed Ursula for durability tests.
- Keep Board's inspection capability read-only. Use public `transit-client` read surfaces;
  no raw storage/provider access, hidden mutations, or unqualified cached views.
  Interpret runtime/framework primitives with source evidence; keep application
  value decoding out of Board.
  Board admits viewers through its private deployment boundary without access
  keys or sessions; its upstream Transit identity still requires a read-only grant.
- Keep instrumentation with its domain owner and I/O outside deterministic core.
  Bound telemetry work, cardinality and sinks; exclude credentials and payloads.
  Preserve machine stdout and distinguish transport attempts from durable results.
  Telemetry loss or failure must not change authority or stall control progress.
- Keep Kubernetes/Substrate as the reference runtime and AX excluded. Providers
  handle physical lifecycle; durable Transit history remains execution authority.
- Put consumer language SDKs and native distribution packages in `sdks/<language>/`.
  Keep runtime apps and shared implementation in `apps/` and `packages/`; they
  must not depend on SDKs. Board and its browser libraries stay with the runtime.
  SDKs may depend on shared packages. Use the public Zig SDK for consumer examples.
- Give real libraries their own manifests, direct dependencies, modules, and
  checks; use package interfaces rather than sibling source imports. Entry points
  compose them. Add directories only for real work. Test the real example binaries.
- Define versioned neutral contracts and shared fixtures before wiring languages
  together. Regenerate the schema from public types; do not maintain divergent
  copies. Validate data at runtime across boundaries, including TypeScript.
- Do not choose trading venues, strategies, latency targets, or live requirements
  implicitly. Future monetary state needs explicit fixed-point/decimal rules.

### SQL statements and result sets: future implementation direction

Formalize statement results across the SQL service, shared client and consumers
before expanding their execution or presentation models. This is architectural
direction, not a claim that a `StatementResult` or `ResultSet` API already exists,
and does not require implementing that abstraction during unrelated console work.
Start from the [SQL session contract](contracts/SQL_SESSION_V1.md),
[query semantics](docs/handbook/reference/queries.md) and
[shared SQL client](packages/zig/transit-sql-client/README.md).

- Distinguish command completion (including authoritative matched/changed counts)
  from a row-returning result set. SELECT, SHOW, DESCRIBE and EXPLAIN use the same
  logical result lifecycle. Command kind and outcome come from shared typed
  semantics, not SQL-text heuristics in each renderer. Pending durable work may
  exist internally; an interactive console must not require users to operate a
  job workflow to obtain a statement's outcome.
- A result set owns one logical schema, a stream of typed rows and a verified
  terminal outcome with row count and observation basis. Physical fetch batches,
  including empty terminal batches, are not separate results. Distinguish a
  genuinely empty result from end-of-stream after previously returned rows.
  Failure, cancellation, missing completion or transport EOF cannot establish
  complete coverage. Never silently restart a SELECT and splice a different
  snapshot into its existing result.
- Keep storage pages, Fuze execution vectors, wire fetch batches and display
  windows separate. Give server batches explicit byte/row budgets and owned or
  borrowed lifetimes; collecting rows must not retain pointers into scratch
  memory reset by the next iterator call. Fill bounded batches across read
  variants and mark the final data batch complete when exhaustion is known.
  Do not require unbounded lookahead or tie SQL throughput to an old Arrow page
  or actor frame limit. Recheck current authorization after buffering and before
  disclosure, including repeated batches, metadata, empty results and terminal
  counts; batching must preserve revocation behavior.
- Put reusable statement submission/settlement and result consumption in
  `transit-sql-client`, with accepted-work execution/recovery in the service.
  A shared result reader should own schema decoding, cursor sequencing, batch
  lifetimes, completion evidence and deterministic cleanup on exhaustion, early
  close or failure. Offer bounded streaming and optional bounded materialization
  or display windows. Reaching a display/memory limit is not query completion;
  never accumulate an arbitrarily large result merely to calculate column widths.
- Align result provenance with the lifecycle's exact definitions and snapshot
  cuts as those contracts are integrated. Define appropriate catalog/settings
  observation evidence for metadata results rather than inventing a data
  snapshot. Do not relabel an independent source vector as an atomic snapshot or
  treat a descriptor as a durable retention pin.
- Preserve the original accepted identity when resolving uncertain writes.
  Keep transport success, durable acceptance, statement completion and result
  delivery distinct. A timeout or missing observation is not rejection; stopping
  a wait is not rollback. Shared-client conveniences must not replay SQL as new
  work, manufacture success, or hide unresolved outcomes. Define cancellation
  races and bounded settlement in the owning contract rather than building
  separate recovery state machines in each UI.
- Deliver the eventual contract through the existing current-v1 cutover policy,
  migrating native messages, SQL adapters, client APIs, console/SDK consumers,
  fixtures and documentation together where affected. Prove empty/multi-batch
  results, scratch-buffer lifetime, early close, bounded memory, revocation after
  buffering, incomplete prefixes and cancellation racing with write completion.
  Until then, keep adapters to current APIs small and preserve their guarantees;
  do not introduce a competing console-only result protocol.

### Database decoupling, declarative streams and queues, and durable runtime composition: future implementation direction

Keep the database (**Control & Policy Plane** and **Direct Data Plane**:
`DirectCatalog`, `TablePartition`, `KV`, `Document`, `Stream`, `Queue`,
`transit-query`, and `transit-sql`) completely independent of `Station` actor
turns (`GenServer`, `AccountRuntime`, `Ledger`), and re-architect `Station` on
top of first-class declarative database primitives. This is architectural
direction across the [data model](docs/handbook/reference/data-model.md),
[streams reference](docs/handbook/reference/streams.md),
[Station reference](docs/handbook/reference/station.md) and
[Milestone 6](docs/roadmap/06-streams-queues-and-durable-runtime.md), not a
claim that `CREATE STREAM`, `PRODUCE INTO`, `CONSUME ... FROM`, `CREATE QUEUE`,
`ENQUEUE INTO`, or `CLAIM ... FROM` already exist in current builds.

- **Decouple `transit-sql` and the database from `Station` actor turns before building interactive transactions:**
  Do not route SQL DDL/DML admission, idempotency token deduplication, snapshot
  pins, or [Milestone 5](docs/roadmap/05-transactions-and-atomic-composition.md)
  `BEGIN`/`COMMIT`/`ROLLBACK` coordination through `Station` `GenServer` actors
  (`AccountRuntime`, `Ledger`) or `STATE_V1` 256-byte KV turns. Enforce client
  operation idempotency (`(AccountId, ClientToken) -> OperationId, CommitLSN`),
  snapshot cuts, and `policy_epoch` lease fencing directly in `DirectCatalog`,
  `TablePartition`, and the transaction log so single-partition writes commit in
  one round-trip to `TransitLog` (`TWAL1`) and `SELECT` reads hot lease-cached
  partition state.
- **First-class declarative `STREAM`, `QUEUE` and logical `DOCUMENT` primitives with dedicated grammar and shared `TablePartition` / `StreamPartition` / `QueuePartition` / `DocumentPartition` storage:**
  Elevate `STREAM` and `QUEUE` to catalog-declared data primitives alongside
  `TABLE`, `KV`, and `DOCUMENT`, using explicit workload verbs decoupled from
  relational table `INSERT`/`SELECT` syntax and sharing the `.tseg` + Roaring-
  bitmap engine in `transit-storage`:
  - **Streams (`CREATE STREAM`, `PRODUCE INTO`, `CONSUME ... FROM`, `COMMIT OFFSET` and read-only `STREAM_SLICE(...)`):**
    `StreamPartition` stores append-only, partitioned, schema-bound event logs
    over `TransitLog` (`TWAL1`) automatically tiered to `.tseg` segments in
    `TransitObjectStore` with zero-copy buffer-pool tail reads and consumer-group
    watermark tracking. Keep stateful stream consumption (`CONSUME ... FROM`)
    distinct from side-effect-free relational queries over historical stream
    segments (`SELECT ... FROM STREAM_SLICE(...)`).
  - **Queues (`CREATE QUEUE`, `ENQUEUE INTO`, `CLAIM ... FROM ... WITH LEASE`, `ACK`, `NACK`, `EXTEND LEASE`):**
    `QueuePartition` composes `StreamPartition`'s append-only `TWAL1`/`.tseg`
    payload storage with a `.tack` Roaring-bitmap state vector (sharing `.tdel`'s
    Roaring bitmap implementation to track per-offset `Available`, `Acquired`,
    `Acked`, and `Archived/DLQ` states and reclaim fully acked `.tseg` segments
    in $O(1)$), an in-memory fenced lease heap (`_lease_epoch`), a lock-free
    `key_fifo` entity-key affinity table, and a Hashed Hierarchical Timing Wheel
    for `visible_at` delays and retry backoff without B-tree page rewrite
    amplification.
  - **Logical Documents (`DocumentPartition` in [Milestone 7](docs/roadmap/07-document-storage-and-station-decoupling.md)) and the Document Type Library + Gateway Exchange Lifecycle ([Milestone 16](docs/roadmap/16-document-profiles-and-gateway-exchange-lifecycle.md)):**
    Decouple `DOCUMENT` from `Station` actor turns (`STATION_DOCUMENT_V1`/`SIX1`
    and the 96-byte scalar string ceiling) into `DocumentPartition` over
    `TransitLog` (`TWAL1`) and `.tseg` segments. Represent documents logically
    ($\tau \perp \kappa \perp \epsilon$) as rooted, ordered, attributed trees +
    envelopes (and multi-part container graphs `Container -> Parts -> Trees/Tables/Spans`)
    with $2N$-bit Balanced Parentheses (`BP`) succinct tree bitvectors,
    Dremel/ClickHouse-style adaptive columnar path shredding into 16-byte
    Umbra/German collated subcolumns, five-state cell provenance (`value`,
    `null`, `missing`, `type_error`, `conflict` with exact `(part_id, byte_start, byte_end)`
    raw-frame offsets), and pluggable revision/merge profiles (`versioned` and
    `causal_crdt`). Express `JSON`, `XML`, `EDI` (`EDI_X12`, `EDIFACT`, `HL7`),
    application protocols (`HTTP`/`MIME`, `FTP`, `SMTP`/`IMAP`/`POP3`,
    `LDAP`/`LDIF`, `SIP`/`SDP`, `AMQP`, `MQTT`, `NTP`) and compound
    office/publishing formats (`PDF`, `DOCX`, `XLSX`, `ODF`) as parameterized
    **Document Profiles** sharing zero-allocation SIMD structural/TLV scanners,
    container unpackers and `comptime`/segment-sealed perfect hash vocabularies,
    and cut outbound connector capture (`STATION_EXCHANGE_V1`) and inbound
    gateway admissions over to linked `DOCUMENT` revisions in `DocumentPartition`
    while keeping transport/effect authority (`Gateway / Connector`) and
    document storage strictly decoupled.
- **Formalize the gateway as a sans-I/O protocol boundary co-hosted over the Direct Data Plane ([Milestone 8](docs/roadmap/08-gateway-architecture-and-protocol-ingress.md)):**
  Keep wire-protocol codecs (`transit-postgres`, `transit-mysql`,
  `transit-sql-protocol` `TSR1`, `transit-flight`, `transit-serving-http`, and
  [Milestone 16's](docs/roadmap/16-document-profiles-and-gateway-exchange-lifecycle.md)
  protocol Document Profiles) strictly as pure sans-I/O byte/frame state machines
  (`InputSlice -> ProtocolEvent / OutputSlice`) with zero socket, TLS, timer or
  thread imports. Co-host `DatabaseRuntime` and SQL/Flight/Serving ingress with
  `DirectCatalog` and `TablePartition` inside `transit-node` / `transit server`
  by default (or use a single coarse-grained server-side statement RPC when
  disaggregated) instead of orchestrating 7–10 `/table/v1` HTTP/1.1 JSON
  round-trips per SQL statement from the gateway. Make operation and session
  recovery strictly event-driven (sweeping once on startup/activation and waking
  only when a foreground statement leaves a bound `DirectClientToken`
  uncertain, rather than polling `/table/v1` every `2–100 ms`), use socket
  `io.operateTimeout` deadlines instead of spawning two-task `std.Io.Select`
  timer futures per header/command, and size `transit-io` worker pools to
  `O(CPU cores)`.
- **Unify the transaction commit envelope so a `Station` turn is simply a database transaction:**
  Include three native participant primitives in [Milestone 5's](docs/roadmap/05-transactions-and-atomic-composition.md)
  transaction commit envelope from the start: `(1) TABLE/KV/DOCUMENT state
  mutations and conflict guards`, `(2) STREAM PRODUCE / QUEUE ENQUEUE log
  appends`, and `(3) _lease_epoch-guarded QUEUE ACK / STREAM COMMIT OFFSET
  settlements`. Model a `Station` behavior's inbox as a declared `key_fifo`
  `QUEUE`, its state as declared `TABLE`/`KV`/`DOCUMENT` objects (without
  256-byte value or 4-key mutation ceilings), and its replay journal and effect
  outbox as declared `STREAM`s/`QUEUE`s, committing inbox lease `ACK`s, state
  mutations, and outbound `PRODUCE`/`ENQUEUE` intents atomically in a single
  standard transaction with zero bespoke turn-commit protocol or external
  `courier` polling.

### Resource control, vectorized strings, perfect hashing and data-centric compilation: future implementation direction

Design storage, query and protocol hot paths for predictable CPU cache residency,
zero steady-state heap allocation after warmup, first-class string/text execution
and data-centric pipeline fusion. This is architectural direction across the
[storage runtime](docs/handbook/internals/storage-runtime.md) and
[query engine](docs/handbook/internals/query-engine.md), not a claim that a
hierarchical `MeteredAllocator`, 16-byte string vector layout, vectorized BM25
operator, or AOT query compiler already exists in current builds.

- **Zero steady-state heap allocation, per-morsel resource metering and LeanStore/Umbra buffer management:**
  Pre-allocate subsystem slabs and page/batch buffers at initialization and pass
  explicit `scratch` (reset per page, batch, or turn with `.retain_capacity` or
  `FixedBufferAllocator`) and `output` arenas through hot loops. Gate hot-path
  operators with counting-allocator regression tests verifying zero OS/heap
  allocations after warmup. In `NvmeCache` and RAM buffer pools, verify chunk
  checksums once upon admission/load into variable size-class page slabs
  ($64\text{ KiB}, 128\text{ KiB}, 256\text{ KiB}, \dots$) and expose swizzled or
  optimistically version-latched zero-copy slices with lock-free cooling eviction
  rather than re-hashing or `@memcpy`-ing on every read hit. Bound active memory,
  CPU cycles/ticks and storage IOPS/bytes at `Batch` morsel boundaries so queries
  exceeding their budget deterministically spill to Tier 2 NVMe scratch or fail
  with a typed budget refusal without starving concurrent tenants or triggering
  process-wide OOMs.
- **Cache-line-aligned vectors, 16-byte Umbra/German collation-prefixed strings and vectorized search:**
  Keep `.tseg` page buffers, column vectors (`Batch`) and selection/validity
  bitmasks 64-byte cache-line aligned and sized so active operator state fits in
  L1d/L2 cache. Evolve variable-length string vectors toward 16-byte Umbra/German
  inline headers (`[len: u32][collation_sort_prefix: 4B][inline_or_offset: 8B]`)
  whose 4-byte prefix stores the declared collation's normalized sort key
  (`UTF8_BINARY`, `ASCII_CI`, `EBCDIC_CP037`), allowing equality, range,
  `ORDER BY` and join probes to filter or short-circuit in registers before
  touching out-of-line payloads. Push string equality, `IN (...)` and prefix
  predicates into `.dictionary` codes and `.fsst` symbol tables, and separate
  declarative text segmentation, proximity (`NEAR` / `WITHIN`) and scoring
  contracts from swappable `.tseg` index profiles—qualifying 256-document
  bitpacked posting blocks with block-max BM25 impact weights (`MAXSCORE` /
  Block-Max WAND pruning, SIMD relational/`.tdel` bitmask intersection and late
  materialization) first without locking text or code search into a
  bag-of-words model. Mirror the 16-byte string header for 2D/3D geospatial,
  volumetric and interactive world vectors in
  [Milestone 17](docs/roadmap/17-geospatial-and-spatio-temporal-computing.md) and
  [Milestone 19](docs/roadmap/19-game-asset-pipelines-and-simulation-streaming.md)
  with a 16-byte inline spatial header (`[subtype_and_flags: u16][srid_id: u16][hilbert_s2_or_oct_prefix: u32][quantized_mbr_or_inline_xy: 8B]`),
  and pair `.tseg` topological shared-arc/face (`.topo_arc`, `.topo_face`),
  `<2 bpt` Edgebreaker mesh (`.mesh_edgebreaker`), virtualized meshlet cluster
  DAGs (`.mesh_cluster_dag`), Morton virtual-texture mip pyramids
  (`.tex_mip_morton`), `INTERIOR`/`BOUNDARY` `S2`/`H3`/`OCT_CELL` Roaring
  coverings (`.s2_roaring`, `.octree_roaring`), instanced `.scene_dag`,
  skeletal `.skin_weights`/`.anim_acl`, `.pcloud_hilbert` and 4D/6-DoF kinematic
  trajectory compression with DBSP Z-set incremental `ST_Union` ($\partial_2$
  half-edge cancellation $(+\vec{e}) + (-\vec{e}) = 0$), `ST_3DUnion` ($\partial_3$
  face cancellation $(+\vec{f}) + (-\vec{f}) = 0$), Discrete Divergence Theorem
  linear 3D volume/inertia aggregates, incremental `NavMesh`/`HLOD` Derived Data
  Cache (DDC) cooking and `INTERIOR`-short-circuited 2D/3D spatial and clash joins.
- **Compile-time (`comptime`) and immutable-artifact perfect hashing with wide SIMD comparisons:**
  Use pure-Zig `comptime` perfect hash maps (`slot = (len + asso[key[i]] + asso[key[j]]) & mask`)
  for closed compile-time keyword, header and directive sets instead of linear
  `std.mem.eql` chains or runtime-allocated hash maps, and evaluate frozen
  perfect hash directories for compiled SQL `WHERE col IN (...)` literal sets,
  immutable `TableSchema` column lookups, and sealed `.tseg` dictionary/key
  directories. Guarantee 16–64 bytes of trailing zero-padding on `.tseg` page
  buffers and `Batch` arenas so internal `@Vector(16, u8)` SIMD string
  comparisons execute unconditionally without 4 KiB page-boundary checks.
- **Data-centric pipeline fusion, Flying-Start adaptive tier-up and AOT query compilation:**
  Combine vectorized `Batch` morsels (for SIMD scans and software-prefetched
  `@prefetch` CedarDB-style directory-tagged hash-join probes) with HyPer/Umbra
  data-centric push pipelines inside each morsel so multi-atom predicates,
  checked arithmetic, projections and aggregate accumulators stay in registers
  without materializing intermediate `scratch` arrays per AST node. Dispatch
  between a branchless Dense Non-Null Fast Path (`null_count == 0` and empty
  `.tdel`) and the Five-State Tagged General Path per `.tseg` row group while
  preserving ordered failure frontiers. Start ad-hoc SQL at $0\,\mu\text{s}$
  compile latency via `comptime` fused superinstruction dispatch ("Flying Start")
  and tier up mid-query at a `Batch` morsel boundary to Copy-and-Patch machine
  stencils only when the runtime morsel CPU tick/row counter crosses a threshold
  (no runtime LLVM dependency), while extending `transit-app` to compile declared
  application queries, views and Zig UDFs ahead of time into schema-monomorphized
  Zig modules.

## Documentation and validation

Use scoped Conventional Commit subjects: `type(scope): description`, such as
`feat(transit): add inspection queries`, `test(board): verify access boundaries`,
or `docs(roadmap): update milestone status`. Include a scope for every commit.
When rewriting history, preserve the original author date and use
`git rebase --committer-date-is-author-date`. For individual `git commit --amend`
operations, set `GIT_COMMITTER_DATE` to that commit's author date.

Follow the [documentation ownership guide](docs/README.md#where-documentation-lives).
Lead product and contributor explanations with data, computation and policies.
Connect each supported declaration to its public operation, dependencies,
authorization and inspectable result or progress. Explain execution mechanisms
as the basis for those semantics. Preserve explicit gaps between the product
direction, offline definitions and executable lifecycle operations.
Keep current scope, concepts, guarantees and user-facing semantics in
`docs/handbook/guides/` and `docs/handbook/reference/`. Publish consolidated scientific explanations
of how the system works in `docs/handbook/internals/`: models, mechanisms, invariants,
architecture rationale, tradeoffs and evidence. Internals is public, navigable
and searchable. Merge overlapping explanations around clear technical subjects;
do not publish every source record as a separate Internals page.

Keep delivery plans and milestone status tracking in `docs/roadmap/`; do not delete completed milestones. Keep UI/UX proposals
and reviews in `docs/design/`, and superseded topic accounts and historical
qualification reviews in `docs/history/`. Preserve their outcomes and source
links; these records stay outside the site's primary reading path and search.
Internals and architecture documentation must follow the
[scientific standard](docs/handbook/internals/standard.md): explicit questions, scope,
models and assumptions; precise claims and reasoning; traceable primary evidence;
reproducible methods; alternatives, uncertainty and limits. Apply it to new and
substantively revised accounts. Do not retroactively certify historical records.

Keep exact wire specifications in `contracts/`, component implementation/usage
beside their package/app, and qualification accounts in `docs/history/qualification/`
with linked source-attributed raw evidence. Keep `tests/README.md` a summary index;
test methods belong with their domain, and active handoffs belong in issues/PRs.
Follow the scoped `tests/AGENTS.md` instructions. User guides and
interface references must explain current behavior without requiring an Internals
record; optional links can supply deeper reasoning. They describe a snapshot of
capabilities at their source revision. Keep milestone IDs, headings, roadmap links
and delivery sequencing in planning/history, outside user-facing prose, examples,
link targets and generated descriptions. Use named capabilities, actual interface
versions and supported/unsupported profiles in usage documentation. This also
applies to component guides included by the site and every wire contract.
Scientific accounts may cite scoped proof/history records as evidence; those
citations do not expand supported behavior. The documentation ownership index
may describe and link all repository sections.

Describe interfaces directly in the present tense. State supported operations,
types, platforms, version compatibility, configuration and failure behavior.
Avoid maturity labels and generic qualification or production-readiness caveats.
Keep concrete limits beside the affected interface and test execution details in
the proof ledger; do not imply broader support or guarantees by changing tone.
Keep component READMEs navigable; place substantial configuration, recovery, or
integration guides in that component's `docs/` and link them from its README.
Update the owning document with meaningful changes and distinguish implemented,
proposed, and unverified behavior. Keep rationale with its topic. Do not add ADRs
yet.

Reserve `docs/design/` for UI/UX reviews. Document system architecture in its
owning topic documents and scope, decisions and qualification in roadmap milestones.
Register UI/UX design items in the [design index](docs/design/README.md). Keep one
linear review sequence and summary table per item in `docs/design/<item>/README.md`,
with one `D<number>.md` per review in that directory. Use the shared template,
preserve recorded outcomes, and distinguish accepted design from implemented behavior.
Use black-and-white wireframes for structure and interaction reviews. Introduce
color only when visual styling is explicitly being reviewed; keep meaning in
labels, geometry and line styles.

Keep the roadmap linear and status-tracked: give each milestone a stable numbered
file, update its status (`Planned`, `In Progress`, `Completed`) as work lands,
and promote current behavior to the public handbook, following the
[sequencing rule](docs/roadmap/README.md#maintaining-the-sequence).

Enter `nix develop` and use [just tasks](tasks/README.md). Use the pinned Zig 0.17
compiler and standard library, not examples from older releases. Use the
[test index](tests/README.md) to select the smallest meaningful owning checks
during iteration and the affected caller/fault checks before submitting. Install
locked frontend dependencies with `just transit-board::install` when needed.
Documentation-only changes require link/whitespace checks and affected site checks;
they do not require a new runtime suite. Before pushing implementation or test
infrastructure changes, run the affected `just ci clean --lane NAME` checks against
committed HEAD to expose dependencies hidden by local outputs. Shared contract,
authority and cross-domain changes require their dependent lanes; full clean
qualification remains an integration/release gate. `just check all` remains available
for broad repository validation. Report selections, omissions and incomplete
checks explicitly; do not label selected lanes as a complete pass.
Toolchain changes also require `just doctor`, deliberate
lockfile updates, and the [toolchain workflow](nix/README.md). Use `vp` for future
frontend dependency operations, checks, tests, and builds. Keep onboarding
commands runnable; never add placeholder tasks that report success.
