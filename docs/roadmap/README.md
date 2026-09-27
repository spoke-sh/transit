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
| [M18](M18.md) | Unified state querying and versioned source contracts | In progress; v2 adapters, signed recovery and all ten typed SDKs implemented; lifecycle, shell/Board and deployment qualification next |
| [M19](M19.md) | Serving foundation and HTTP APIs | Planned; qualify shared serving through application APIs and Board |
| [M20](M20.md) | Reactive APIs: SSE, WebSocket and API contracts | Planned; shared session/subscription semantics and generated OpenAPI/AsyncAPI descriptions |
| [M21](M21.md) | Reactive interfaces over reactive APIs | Planned; live views and exact snapshot refresh consume M20 |
| [M22](M22.md) | Arrow Flight, Flight SQL and ADBC interoperability | Planned; Arrow protocol adapters reuse the qualified serving foundation |
| [M23](M23.md) | Clustered execution and portability | Planned; extend component proofs across authority/runtime topologies |

The historical [pre-Station review](../reviews/PRE_STATION.md) led to the completed
[M8 readiness requirements](M8.md#exit-criteria). Station now builds on the resource
commit primitive and these runtime contracts; a production behavior runtime is
not implied by either bounded profile.

Station establishes Table and language-binding contracts with the first bounded
[Fuze](../FUZE.md) query profile. The [post-M9 review](../reviews/PRE_M10.md)
led to [M10](M10.md): the [testing strategy](../TESTING.md), measured CI budgets
and an explicit growing profile that separates durable collection growth from
resident caches. Legacy catalog ceilings remain compatibility constraints;
SDKs must preserve the qualified profile and its capability boundaries.
[M11](M11.md) builds qualified language-native public SDKs
over those bindings, including typed handlers/state, recoverable operations,
runtime integration and installable artifacts. [M12](M12.md) makes the
read-only relational declarative interface [QUERY_LANGUAGE.md](../QUERY_LANGUAGE.md)
designed actually usable: a checked grammar through `SELECT`, a real
`parse -> Fuze plan` compiler, a pinned Postgres-compatibility corpus and an
extended Lean rewrite-safety proof program. [M13](M13.md) reuses that completed
compiler and M11's growing hosts for a bounded public query capability distinct
from Board's inspection grant. Board's relief-atlas workspace and the new
`transit` query shell share the Zig query client, request/result contract and
M12's compiled `SELECT`, without duplicating execution semantics.
M13's chunked results expose a prerequisite for useful atomic Document changes:
[M14](M14.md) qualifies bounded immutable publication over growing KV without
raising kernel value/turn limits. [Documents](../DOCUMENTS.md) records the handoff.
[M15](M15.md) now consumes that storage foundation for HTTP and the shared
exchange lifecycle. [M16](M16.md) applies it to gRPC and proves bounded streaming
authority. These are the first two connectors; they do not depend on Documents.

Later work composes the qualified lower-level components in separate steps:
[M17](M17.md) supplies Document/CRDT storage and structured/plain-text editing;
[M18](M18.md) supplies KV/Document query adapters and versioned schema/request
extensions while preserving the M13 Table path. [M19](M19.md) formalizes the
[serving layer](../SERVING.md) through application HTTP APIs and Board, with
shared inbound identity, admission, response and recovery contracts.
[M20](M20.md) adds [reactive APIs](../REACTIVE_API.md): SSE and WebSocket hosting,
shared session/subscription and resume semantics, and generated OpenAPI/AsyncAPI
descriptions. [M21](M21.md) consumes that API in [reactive interfaces](../REACTIVE.md)
with live views and exact snapshot refresh; incremental continuous query execution
remains later work. [M22](M22.md) then adds Flight/Flight SQL and ADBC
interoperability over the qualified serving contracts. [M23](M23.md) qualifies
these boundaries across broader authority/runtime topologies. Fuze remains Zig throughout; SQL or RPC transport
never replaces durable authority.

The serving review inserts M19–M21 and moves the previously planned Arrow
interoperability and clustering work to M22/M23. HTTP first proves serving with
two consumers; reactive API hosting then establishes the contracts that live
interfaces consume. Flight subsequently qualifies its specialized protocol
adapter. Completed milestone scope and proof remain unchanged, and every new milestone still requires its entry gates.

The M15/M16 plans are reviewed from current M14 evidence. M17 onward has a
composition plan now, with a further entry review after the connectors have
actually passed their proofs. A planned transport, capture API or shared contract
is not an implemented dependency. Provider-specific integrations later compose
connectors without a new durability model or application policy in the kernel.

Each milestone owns its scope, acceptance criteria, and completion status.
Preserve the [M1 design gates](M1.md#design-gates-before-expanding-the-slice)
as later milestones expand the supported profiles. Detailed proof results stay
in the [test guide](../../tests/README.md); implementation and operating details
stay with their [owning components](../ARCHITECTURE.md#planned-monorepo-decomposition).

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
