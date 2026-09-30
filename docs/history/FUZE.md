# Fuze — query and compute engine

Engineering background and historical design. Use [Query execution and result recovery](../reference/queries.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Use Fuze to query declared state through bounded batches. Start with the
[SQL reference](../reference/sql.md) and [console](../../apps/transit-cli/docs/console.md);
use the [package API](../../packages/zig/transit-fuze/README.md) when embedding the
engine. This page explains execution ownership and future extension boundaries.

Status: the bounded M9 Table profile is implemented. The [package](../../packages/zig/transit-fuze/README.md)
implements the [v1 bounded query profile](../../contracts/FUZE_V1.md), Arrow
dependency integration and finite IPC encoding. Broader capabilities below
remain design direction. [M9](../roadmap/M9.md) introduces Fuze's
bounded Table execution profile alongside Station. The shared query model targets
KV, Table and Document sources; Document storage, collaborative editing and CRDT
qualification belong to [M17](../roadmap/M17.md); KV/Document query adapters and
wider schema/request contracts belong to [M18](../roadmap/M18.md). [M12](../roadmap/M12.md) adds the
implemented [Table SQL compiler](../../packages/zig/transit-fuze/docs/sql.md);
[M22](../roadmap/M22.md) adds remote Flight SQL ingress. Those bounded profiles
do not imply the whole target design.
[QUERY_LANGUAGE.md](QUERY_LANGUAGE.md) elaborates the "structured query API /
Table SQL frontend" line below into relational DDL/DML and a dataframe surface,
both compiling to the plan this document defines.

[M10](../roadmap/M10.md) requires a measured path from growing durable sources to
bounded query/result batches before public SDKs. The existing finite M9 source
and IPC ceilings remain limits of the legacy path; they are not the intended
maximum Table or retained-result size. A larger dataset must not imply collecting
all rows or result bytes in a worker's memory.
The [incremental execution contract](../../contracts/FUZE_STREAM_V1.md) now has a
qualified pure Zig engine with bounded batches and whole-query progress. Station's
durable fragment/result publication and growing recovery are qualified separately
in M10; pure engine evidence alone does not establish service recovery.

The [unified v2 contract](../../contracts/UNIFIED_QUERY_V1.md) now fixes M18's
source/decoder/projection boundary, five-state typed cells and Publication-based
request/result direction. KV/Table/Document adapters, nested Arrow and native
source/lifecycle qualification are implemented. The
[compatibility matrix](../../packages/zig/transit-query/docs/compatibility.md)
limits physical placement recovery evidence to its tested combinations.

## Purpose and ownership

Fuze is Transit's Zig-native query and compute engine, used by Station to query
versioned state through one plan model and produce Arrow results. Station owns
the state abstractions and their mutations; Transit owns durable acceptance,
resource rights, ownership and lifetimes. Fuze owns query expressions, logical
and physical planning, qualified rewrites and bounded batch execution.

Use **Fuze** in prose and `transit-fuze` for the Zig library, exporting
`transit_fuze`. Its source/operator interfaces must not depend on Station,
Ursula or Substrate. Station supplies adapters over authorized public-client
views and owns durable result publication. The kernel does not import Fuze or
execute query plans. A Fuze library call grants no network, storage or execution
capability, and a query operator is not a Transit PID.

The initial artifact is an embeddable library used in callers/workers. A separate
engine daemon, distributed scheduler and new authoritative store are not implied.
[ARROW.md](ARROW.md) owns IPC/C interchange and Flight/Flight SQL/ADBC integration;
[TABLES.md](TABLES.md) owns Table schema, mutation and result-lifetime semantics.

## DataFusion and Acero as design references

| Reference | Ideas to apply in Fuze |
| --- | --- |
| [Apache DataFusion](https://datafusion.apache.org/library-user-guide/index.html) | Composable query APIs, extensible data sources, expressions and operators rather than a monolithic SQL service |
| [DataFusion source/planning boundaries](https://datafusion.apache.org/library-user-guide/custom-table-providers.html) | Separate a source's schema/capabilities, logical query meaning, physical execution plan and batch production |
| [DataFusion optimizer](https://datafusion.apache.org/library-user-guide/query-optimizer.html) | Explicit, inspectable rewrite rules that preserve query meaning; optimize plans built through either a structured API or SQL |
| [Apache Arrow Acero](https://arrow.apache.org/docs/developers/cpp/acero.html) | Source/transform/sink composition, bounded batch flow, backpressure, cancellation and completion that accounts for in-flight work |

These are architectural influences, not API, SQL-dialect or binary compatibility
promises. Fuze's engine, planner and operators remain Zig native; neither the Rust
DataFusion engine nor C++ Acero is embedded. Prefer the qualified `zarrow` and
`zarrow-compute` revisions described in [Tables](TABLES.md#arrow-and-compute-integration).
Their Arrow representation/kernels do not supply our resource or recovery contract.

## One query model across state entities

| Source | Queryable view | Semantics retained by the source owner |
| --- | --- | --- |
| KV | Key/value records; opaque values stay binary unless a versioned decoder supplies typed fields | Key identity, byte equality, conditional mutations and retained revisions |
| Table | Schema-defined rows and columns | Primary keys, row/schema validation and the resource transaction boundary |
| Document | Document identity plus typed path projections, nested values and materialized text | Change/merge rules, causal metadata, conflict visibility and document lifetime |

Each source adapter supplies identity, schema/decoder version, exact read basis,
supported operations, ordering and bounded batch production. Station binds current
permission, revision and availability before reading and revalidates continuing
access at the declared boundary. Fuze cannot turn an expired view into a current
one or obtain a broader grant through an optimizer rewrite.

The shared API targets lookup/scan, expressions, filter, projection, limit and
qualified aggregation. Capabilities remain explicit: a common interface does
not mean every source supports every operator efficiently or at all. Source
adapters are query adapters, distinct from Transit's durable storage backends.
Schema discovery, statistics and plan explanations are permissioned data surfaces.

Document includes both structured state and collaborative text. Its planned value
model distinguishes nested maps/lists/scalars, replaceable strings and editable
text sequences. CRDT merging belongs to Station's Document implementation; Fuze
queries an accepted materialized revision with an explicit conflict interpretation.
It must not merge speculative offline edits during an authoritative query. A
CRDT causal frontier is additional evidence, not a replacement for the committed
resource revision or current permission.

Document projections must distinguish missing paths, nulls, type mismatches and
conflicting values. Preserve those distinctions in the typed result contract;
mapping all of them to Arrow null is insufficient. Nested Arrow layouts, list
expansion and text operators need explicit type and expansion limits. Unified
querying does not imply full-text indexing or rich-text formatting support.

All sources feed the same logical plan and Arrow execution model. This does not
require the same physical storage layout, mutation API or one stream per entity.
Reads across resources do not acquire a shared snapshot or transaction merely
because one plan describes them. Start with one resource revision per query;
cross-source joins and consistency need a separately qualified extension.

## Planning and extension boundaries

```text
structured query API / Table SQL frontend
    -> typed logical plan
    -> qualified logical rewrites
    -> physical plan bound to authorized source views
    -> bounded Arrow operators
    -> result sink and Station publication
```

Validate schema, expression types, null/error behavior and resource budgets before
execution. Keep planning separate from batch production; resolving a source or
explaining a plan cannot silently perform external effects. Planning metadata
must come through authorized views too. Bind exact source identities and schema
versions; a cached plan never caches permission or silently rebinds a retained
result to newer data.

Begin with an explicit unoptimized plan and a small, tested set of rewrites as
needed. Candidate optimizations include projection pruning and predicate pushdown.
A source must declare whether a pushed filter is exact, only reduces candidates,
or is unsupported. Retain the residual predicate when needed; do not push a limit
ahead of required filtering or ordering if it changes the result. Every rewrite
must preserve the specified result schema, null/missing/conflict interpretation,
numeric/error behavior and ordering, as well as access and lifetime boundaries.

Expose a bounded plan explanation with source versions, operators, limits and
applied rules; omit credentials, private literals and hidden catalog facts.
Qualify optimized execution against the same plan without rewrites, including
empty inputs, nulls, overflow, cancellation and stale source metadata.

Version operator/function identities and capability declarations in the shared
query contract so language bindings and future SQL lower to the same semantics.
The first profile uses compiled, allowlisted Zig operators. User-defined functions,
dynamic plugins and remote/file sources require explicit capability, determinism,
budget and effect policies before admission; extensibility is not arbitrary
native-code execution inside the node or permission to bypass connectors.

## Bounded execution and recovery

M9 starts with scan, filter, project, limit and selected aggregates over one
authorized Table snapshot. A single-worker, demand-driven pipeline is sufficient.
Keep source, operator and sink interfaces separate so later scheduling or a
Flight sink does not change state semantics. Physical parallelism and automatic
operator placement remain later work.

Every operator declares allocation/ownership, input/output schema, row/batch/byte
limits and cancellation points. Bound queued batches and in-flight tasks; pause
upstream before exhausting the declared budget and reserve control progress.
Account for variable-width data and decoded/decompressed sizes. Accumulating
operators must prove a whole-input bound; external spill and unbounded sorts/joins
remain outside M9. An announced final batch count is not proof all batches have
arrived; success requires complete expected input and output coverage.

Compute stays inside a valid bounded read/turn and cannot extend an
activation-scoped view across turns. Station captures the bounded result under
[Table publication rules](TABLES.md#arrow-results-and-durable-replies) before remote
publication. Persist accepted result identity, schema/revision, bytes and delivery
progress, not execution pointers. Before acceptance, recovery may recompute under
a newly validated basis; after acceptance it serves that captured result.
Cancellation, retained-source loss and timeout cannot publish partial success or
silently substitute a newer snapshot for an accepted result.

## Durable materialization and future scope

The first profile queries finite snapshots materialized through accepted turns.
Arrow batches and physical plans are not transaction boundaries. State mutations,
source progress and outputs still follow the resource commit contract. Fuze
does not apply historical row versions as new positive contributions to an
aggregate or reinterpret CRDT operations as independent current documents.

Continuous queries need deltas/retractions, committed operator state and source
positions, transaction barriers, snapshot-to-tail handoff, gap handling and
bounded lag. Joins need an explicit cross-source consistency model; event-time
windows need watermark and late-data rules. Document checkpoints also need the
causal/deletion evidence required by their merge and replica-resynchronization
contracts. These capabilities need their own storage, retention and recovery
proofs; a batch engine or RPC stream alone cannot provide them.

[M21 reactive interfaces](../roadmap/M21.md) deliberately starts with notifications
and fresh finite snapshots through the existing query APIs. It supplies none of
the incremental operator semantics above. [Serving](SERVING.md) owns inbound
admission/delivery; [reactive APIs](REACTIVE_API.md) owns source/watch and
transport contracts; [reactive interfaces](REACTIVE.md) owns refresh scheduling
and presentation. None introduces another query engine or executes inside core.

M9 fixes the source/plan/operator contract and proves the bounded Table path.
[M14](../roadmap/M14.md) provides immutable publication and [M17](../roadmap/M17.md)
adds structured/text Documents with CRDT/storage/retention qualification.
[M18](../roadmap/M18.md) adds KV/Document query adapters, nested Arrow types and
versioned schema/request contracts. Publication alone does not supply those
semantics or widen the existing 256-byte KV/four-mutation boundary. [M22](../roadmap/M22.md) remains the first
bounded remote Flight SQL frontend over qualified Table sources; broadening
its source matrix requires explicit source and interoperability qualification.
