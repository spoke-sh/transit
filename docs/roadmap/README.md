# Roadmap

Status: Transit-first plan. Milestones are ordered by dependency, not calendar
commitments. The bounded M1 reference profile is implemented and verified;
completed outcomes link to their proof commands and limits. Board is implemented and qualified,
before Station, so higher-level abstractions grow on an inspectable kernel.

| Milestone | Focus | Status |
| --- | --- | --- |
| [M0](M0.md) | Foundations and pinned development tools | Established; remaining platform validation open |
| [M1](M1.md) | Transit sequence enforcement and Kubernetes recovery | Bounded reference profile implemented and verified |
| [M2](M2.md) | Board: inspection UI and OpenAPI surface for operators/agents | Bounded inspection profile implemented and verified |
| [M3](M3.md) | Local and Compose development launchers | Persistent development profiles implemented and verified |
| [M4](M4.md) | Board and Transit observability | Bounded service instrumentation implemented and verified |
| [M5](M5.md) | Kubernetes tooling and the Transit operator CLI | Inspection-only profile implemented and verified; broader CLI direction remains future scope |
| [M6](M6.md) | Persistent reference and incremental development | Shared build/update loop and same-PID workload upgrades implemented and verified |
| [M7](M7.md) | Durable state resources and process associations | Bounded KV profile, generic Board inspection and three-launcher recovery/upgrades implemented and verified |
| [M8](M8.md) | Transit runtime readiness | Bounded origins, automatic delivery, catalog reclamation and lifecycle controls implemented and verified |
| [M9](M9.md) | Station behaviors, language bindings, and Arrow Tables | Bounded profile implemented and qualified on Linux x86_64 across its target languages; Zig reference workers |
| [M10](M10.md) | Verification and scale foundations | Explicit growing profile, verification harness and measured CI budgets qualified; v2 remains the default |
| [M11](M11.md) | Idiomatic language SDKs | Qualified raw/Station SDKs, installed examples and ten public language pairs on Linux x86_64 |
| [M12](M12.md) | Declarative interface readiness | Qualified Table SQL compiler, three-parser corpus, pinned tools and four complete Lean theorems |
| [M13](M13.md) | Board relief atlas and public query access | Complete: qualified Table query client/hosts, SQL shell and growing Board workspace |
| [M14](M14.md) | Bounded publication for larger Station records | Complete: growing immutable publication, bounded staging/cleanup and disk recovery |
| [M15](M15.md) | HTTP connector and shared exchange lifecycle | Local qualification and M16 handoff passed; expanded hosted CI cost deferred |
| [M16](M16.md) | gRPC connector and bounded streaming calls | Finite profile locally qualified: four shapes, ten SDKs, Board, three placements and recovery; hosted cost deferred |
| [M17](M17.md) | Documents and collaborative text | Qualified growing profile: structured/text CRDTs, ten SDKs, Board and three placements; hosted cost deferred |
| [M18](M18.md) | Unified state querying and versioned source contracts | Qualified growing profile: three state sources, ten SDKs, SQL/Board, native lifecycle and Table Compose/Substrate recovery; hosted cost deferred |
| [M19](M19.md) | Serving foundation and HTTP APIs | Qualified HTTP profile: durable application admission, concurrent Board, TLS and three placements; hosted cost deferred |
| [M20](M20.md) | Reactive APIs: SSE, WebSocket and API contracts | Qualified initial int64 Table profile; TLS SSE/WebSocket, Chromium, physical recovery, bounded lifetimes and generated contracts |
| [M21](M21.md) | Reactive interfaces over reactive APIs | Complete for selected Table views; bounded snapshot refresh, shared-principal fairness and three-placement browser recovery |
| [M22](M22.md) | Arrow Flight, Flight SQL and ADBC interoperability | Complete for finite Table v1/int64; TLS Flight/ADBC, scoped recovery, bounded load, outbound replay and three placements |
| [M23](M23.md) | Board grammar and declarative reactive applications | Complete: selected UI, publication, migration and three-placement application proofs; clean qualification passed |
| [M24](M24.md) | Transit CLI | Complete: Linux local server recovery/capacity, Table/KV/Document console and shared assistance; clean qualification passed |
| [M25](M25.md) | Local application installation and replacement | Complete: separate Zig consumer, neutral installation/bootstrap, scoped replacement, exact recovery and physical-capacity qualification |
| [M26](M26.md) | User documentation and interface reference | Complete: shared public guides/reference for users, developers and agents; internal plans/history separated; generated API references and local onboarding proof |
| [M27](M27.md) | Board in the local neighborhood | Implemented: separate supervised Board, explicit headless operation and packaged assets; focused proofs pass, clean qualification running |
| [M28](M28.md) | Concise CLI output | Complete for the selected presentation profile; concise errors, offline command help and preserved recovery/machine output qualified locally |
| [M29](M29.md) | Unified CLI and conventional configuration | Interface qualified: automatic SQL, dot commands, YAML/defaults and rc preferences; timing and latency triage in progress |
| [M30](M30.md) | Interactive queries and storage amplification | In progress; fresh leased snapshots, bounded Arrow execution, repeatable measurements and shared storage costs |
| [M31](M31.md) | Protocol consolidation and v1 hard cutover | In progress; one current definition per owned protocol, legacy removal and coordinated consumer/proof updates |
| [M32](M32.md) | Public Internals and scientific documentation | Complete: nine scientific accounts, separate roadmap/design/history owners, source checks and root/prefixed browser proofs |
| [M33](M33.md) | Publication | Planned; tagged GitHub releases across Nix, installer, Homebrew, Docker/OCI, Helm and inventoried library/SDK artifacts |
| [M34](M34.md) | Relational guarantees, joins and aggregation | Proposed; explicit source vectors, finite Table joins/grouping, maintained revisions and semantic gates for reshuffling |
| [M35](M35.md) | Clustered execution and portability | Planned; growing runtime prerequisites and explicit authority/placement qualification |
| [M36](M36.md) | SQL language completeness and declarative dataflows | In progress: finite queries/inspection, combined Table reads/writes, ten mutation SDKs, saved-file CLI mutations and conditional Zig Table catalog; administrative callers, remaining declarations and maintained dataflows remain |
| [M37](M37.md) | Simulation and external fault verification | Implemented deterministic and Vortex-style profiles; repository-wide clean and hosted qualification remain open |
| [M38](M38.md) | Standards, multi-model dataflows and schema branching | Handbook grammar inventory published; implementation sequence starts with the standards ledger and historical contracts; graph/foreign relations, branches and merges remain planned |
| [M39](M39.md) | Comprehensive types and bounded schema on demand | Final qualification; shared logical types, frozen CSV/JSONL discovery, Arrow/SDK owners and measured regression gates |
| [M40](M40.md) | Extended SQL operations and relational composition | Selected: remaining reference operations beyond M34/M36, historical reads, bulk data, transactions and parameters |
| [M41](M41.md) | Declarative benchmark coverage and measurement | 28 components measured and full TPC coverage inventoried; clean qualification in progress; complete suites blocked |
| [M42](M42.md) | PostgreSQL and MySQL wire access | Proposed read/write profile; Zig adapters over interactive queries and explicit mutation/catalog owners, durable write recovery, TLS/authentication, typed parameters and independent client qualification |
| [M43](M43.md) | Durable Table mutation latency | In progress: end-to-end measurement, bounded mutation admission, shared read/write amplification and recovery qualification |

The historical [pre-Station review](../history/reviews/PRE_STATION.md) led to the completed
[M8 readiness requirements](M8.md#exit-criteria). Station now builds on the resource
commit primitive and these runtime contracts; a production behavior runtime is
not implied by either bounded profile.

Station establishes Table and language-binding contracts with the first bounded
[Fuze](../history/FUZE.md) query profile. The [post-M9 review](../history/reviews/PRE_M10.md)
led to [M10](M10.md): the [testing strategy](../history/TESTING.md), measured CI budgets
and an explicit growing profile that separates durable collection growth from
resident caches. Legacy catalog ceilings remain compatibility constraints;
SDKs must preserve the qualified profile and its capability boundaries.
[M11](M11.md) builds qualified language-native public SDKs
over those bindings, including typed handlers/state, recoverable operations,
runtime integration and installable artifacts. [M12](M12.md) makes the
read-only relational declarative interface [QUERY_LANGUAGE.md](../history/QUERY_LANGUAGE.md)
designed actually usable: a checked grammar through `SELECT`, a real
`parse -> Fuze plan` compiler, a pinned Postgres-compatibility corpus and an
extended Lean rewrite-safety proof program. [M13](M13.md) reuses that completed
compiler and M11's growing hosts for a bounded public query capability distinct
from Board's inspection grant. Board's relief-atlas workspace and the new
`transit` query shell share the Zig query client, request/result contract and
M12's compiled `SELECT`, without duplicating execution semantics.
M13's chunked results expose a prerequisite for useful atomic Document changes:
[M14](M14.md) qualifies bounded immutable publication over growing KV without
raising kernel value/turn limits. [Documents](../history/DOCUMENTS.md) records the handoff.
[M15](M15.md) now consumes that storage foundation for HTTP and the shared
exchange lifecycle. [M16](M16.md) applies it to gRPC and proves bounded streaming
authority. These are the first two connectors; they do not depend on Documents.

Later work composes the qualified lower-level components in separate steps:
[M17](M17.md) supplies Document/CRDT storage and structured/plain-text editing;
[M18](M18.md) supplies KV/Document query adapters and versioned schema/request
extensions while preserving the M13 Table path. [M19](M19.md) formalizes the
[serving layer](../history/SERVING.md) through application HTTP APIs and Board, with
shared inbound identity, admission, response and recovery contracts.
[M20](M20.md) adds [reactive APIs](../history/REACTIVE_API.md): SSE and WebSocket hosting,
shared session/subscription and resume semantics, and generated OpenAPI/AsyncAPI
descriptions. [M21](M21.md) consumes that API in [reactive interfaces](../history/REACTIVE.md)
with live views and exact snapshot refresh; incremental continuous query execution
remains later work. [M22](M22.md) then adds Flight/Flight SQL and ADBC
interoperability over the qualified serving contracts. [M23](M23.md) implements
[Board grammar](../design/board-grammar/README.md), bringing the Atlas/Console
explorations into a monochrome reactive UI and a shared declarative application
model with explicit publication and migrations. [M24](M24.md) formalizes
`transit server` for a locally placed service neighborhood and `transit console`
for SQL and slash commands with Board's shared grammar/catalog assistance.
[M25](M25.md) makes separately compiled applications installable in the local
neighborhood, with scoped worker replacement and application-owned migration.
[M26](M26.md) presents those implemented interfaces in a user handbook, with
SQL/CLI references and generated OpenAPI/AsyncAPI documentation.
[M28](M28.md) simplifies terminal errors and command help while preserving recovery
and machine output. [M29](M29.md) unifies the console and adds server defaults,
configuration discovery, environment overrides and merged console preferences.
[M31](M31.md) consolidates Transit-owned protocols on v1 through a hard cutover,
removing superseded code and migrating consumers before release publication.
[M32](M32.md) publishes Internals as a public technical section and establishes
the scientific standard for architecture and engineering accounts.
[M33](M33.md) publishes versioned Transit artifacts through tag-triggered GitHub
release workflows and qualified installation channels. [M34](M34.md) defines and
qualifies finite relational semantics and maintained Table revisions before
[M35](M35.md) extends their exchanges and ownership across authority/runtime
topologies. [M36](M36.md) composes those operators through named declarations,
subscriptions and separately activated effects. Fuze remains Zig throughout;
SQL or RPC transport never replaces durable authority.

[M38](M38.md) adds standards qualification and selected multi-model profiles to
that foundation, then historical schemas, isolated branches and reviewed merges.
Its contract and proof slices are tracked in [issue #31](https://github.com/rupurt/rey/issues/31).
It reuses M34–M36's operators and lifecycle contracts without expanding their
recorded implementation claims.

[M39](M39.md) adds comprehensive type semantics and bounded CSV/JSONL schema
discovery, tracked in [issue #36](https://github.com/rupurt/rey/issues/36). It
coordinates M38's schema identity and M40's expression/COPY work, and compares
equivalent workloads with DuckDB without adding a query-engine dependency. The
extended SQL continuation moves from M39 to M40 with its scope intact, keeping
type and reader prerequisites ahead of their consumers.

M19–M21 separately qualify the serving foundation, reactive API contracts and
their interface consumers. Completed milestone scope and proof remain unchanged;
each new milestone requires its own entry gates and qualification evidence.

[M42](M42.md) investigates PostgreSQL and MySQL wire access through shared Fuze,
interactive-query and explicit mutation/catalog owners. Its selected profile
requires autocommit SELECT, bounded INSERT/UPDATE/DELETE and compatible CREATE
TABLE through both protocols, with durable write identity/reconciliation and
explicit TLS, authentication, parameter, metadata and completion gates. Neither
a listener nor general database compatibility is implemented. M39/M40 retain
the prerequisite type and parameter/transaction semantics; explicit transaction
sessions remain outside the selected wire profile.

M15–M18 now have executed qualification within their declared profiles. The
M19–M35 plans carry those findings forward; a planned server, watch or cluster
contract is still not an implemented dependency. Provider-specific integrations
compose the existing components without a new durability model or application
policy in the kernel.

Each milestone owns its scope, acceptance criteria, and completion status.
Preserve the [M1 design gates](M1.md#design-gates-before-expanding-the-slice)
as later milestones expand the supported profiles. Detailed proof results stay
in the [test guide](../../tests/README.md); implementation and operating details
stay with their [owning components](../history/ARCHITECTURE.md#planned-monorepo-decomposition).

## M15–M18 handoff to M19–M35

The [query compatibility matrix](../../packages/zig/transit-query/docs/compatibility.md)
and [proof ledger](../../tests/README.md#m18-qualification) are the baseline for
the next implementation reviews. M18 qualifies native KV/Table/Document recovery,
ten SDKs and SQL/Board ingress; its physical query-host recovery covers Table.
M15/M16 qualify finite outbound effects, not inbound serving. M17's accepted-state
reads do not create a watch, and manual growing-host placement does not create a
cluster controller. M19 and M20 are qualified within their initial HTTP and
int64 Table reactive profiles. M21/M22 are complete for their selected Table
consumer and finite Flight profiles. M23/M24 are complete for their selected
application, local server and terminal profiles, with focused and clean
qualification recorded. M28 implements the accepted CLI presentation review;
M29 implements the accepted unified CLI direction; M33–M35 remain planned.

| Milestone | Reuse first | New qualification boundary |
| --- | --- | --- |
| [M19](M19.md#m15m18-implementation-review) | Public client/Station admission, shared query workspace, Board contracts and owned deployment fixtures | Concurrent signing/admission ownership, encoded/decoded response budgets, inbound identity and recovery |
| [M20](M20.md#m18-handoff-and-first-watch-profile) | M19 operation identity, current-policy reads and M18 finite lifetime/error distinctions | Public snapshot/watch coverage, meaningful invalidations, cross-transport recovery and bounded leases |
| [M21](M21.md#m18-findings-applied-to-refresh) | M20 API and M18 frozen query/result verification | No missed changes or self-triggered refresh loop, bounded complete-result presentation and shared-principal scheduling |
| [M22](M22.md#evidence-carried-from-m15m18) | Finite gRPC pieces, query/Arrow codecs and M19 serving seams | Inbound gRPC, explicit v1/v2 Table schemas, Flight message budgets, metadata and independent ADBC ownership |
| [M23](M23.md#entry-gates) | M19–M22 public operations, reactive consumers and the Atlas/Console/Grammar designs | Shared SQL/visual definitions, monochrome UI, attributable controls, publication and application migration recovery |
| [M24](M24.md#baseline-and-owners) | Existing query shells, launcher recovery, serving and M23 language assistance | Local supervisor/gateway lifecycle, two-command CLI contract and bounded authorized terminal completion |
| [M25](M25.md#owners-and-implementation-sequence) | M24 local lifecycle, public growing bootstrap and M23 migration ledger | Neutral declaration, exact provisioning recovery and permission-preserving application replacement |
| [M26](M26.md#scope-and-owners) | M25 downstream workflow and the existing typed/wire contracts | User journeys, supported interface reference and generated API descriptions from the same owners |
| [M28](M28.md#scope-and-owners) | Existing diagnostic coordinates, privacy and local recovery | Concise errors, operation-specific help and preserved exit/stream contracts |
| [M29](M29.md#scope-and-owners) | Local server lifecycle, exact query recovery and concise CLI output | Automatic SQL, dot commands, defaults, YAML/environment overlays and rc precedence |
| [M31](M31.md#baseline-and-owners) | Growing authority, unified queries, installed SDKs and existing recovery/authorization proofs | One current v1 definition per protocol, rejection of incompatible artifacts and removal of superseded code |
| [M32](M32.md#scope-and-owners) | Existing Markdown owners, site catalog, source checks and browser proofs | Public Internals navigation/search, source migration and scientific documentation standard |
| [M33](M33.md#baseline-and-owners) | Pinned builds, installed SDKs, existing images/chart and M24 commands | Tagged artifact identity, GitHub publication, verified installation and data-preserving upgrades per channel/platform |
| [M34](M34.md#owners-and-implementation-sequence) | Explicit source contracts, ordered arithmetic, paged state and immutable publication | Snapshot vectors, bag/outer-join semantics, grouped errors, complete change capture and atomic maintained revisions |
| [M35](M35.md#baseline-after-m18) | Exact bootstrap generations, retained evidence, cleanup and existing fault schedules | Growing runtime support and authority transfer/revocation under partition, measured per source/topology |
| [M36](M36.md#implementation-sequence) | Qualified relational operators, public mutations, definitions and connector attempts | Named graph publication, subscription coverage and explicit effect activation through shared declarative interfaces |

At each entry, run the relevant existing proof unchanged, then extend it at the
new boundary. Preserve accepted-but-lost receipts, changed-intent rejection,
staged capture loss, current denial after a returned prefix, pin release, real
expiry and permanent retirement as shared regression cases. New protocol peers
must verify durable stages and exact identities, not just eventual rows. Use
owned disposable installations, check cleanup and keep failed or incomplete
runs out of passing evidence.

Keep fast contracts/models, focused service/source checks, installed-client
matrices and physical placement tasks separately selectable under
[M10's policy](M10.md#exit-criteria). Measure provisioning, build/image work,
scenario and cleanup separately: M18's final Document browser run spent 477.83
of 875.94 seconds provisioning accepted state. That is fixture cost, not a query
latency measurement; neither retained cold bytes nor a configured page cache is
peak RSS. Reuse builds and fault harnesses without sharing mutable authority
between tests or dropping source coverage to improve timing.

Expanded hosted costs remain deferred. Adding these milestones must not quietly
expand the ordinary PR matrix under M10's old budget claim. Record local task
costs first, then obtain representative hosted measurements before changing
required lanes or claiming the expanded suite fits the accepted budgets. Under
ten minutes remains the improvement target and five the stretch target; the
existing under-fifteen-minute warm qualification is historical evidence for its
recorded suite, not a new timing guarantee.

## Maintaining the sequence

Milestones form one linear lineage, with one `M<number>.md` file per milestone.
When new work belongs before an upcoming milestone, insert a numbered milestone
and renumber the upcoming milestones. Update filenames, headings, this index,
and references throughout the repository in the same change. Completed milestones
retain their scope and evidence; additional work gets its own milestone rather
than a follow-up file or section attached to an earlier milestone.

Deferred capabilities remain explicitly outside a completed profile. When they
are selected for implementation, give them a new place in this sequence before
starting the work. A milestone's completion never implies that all future design
directions in its document have been implemented.

## Application milestones after the foundation

Use the evidence above to scope trading, LLM/tool connectors, richer agent
frameworks, and application-specific interfaces. These are intended consumers
of the primitives, with their own requirements and acceptance criteria. A paper-trading
loop is not a prerequisite or the current roadmap's destination. Live trading
requires a separately scoped venue, risk, reconciliation, and operational design.
