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
| [M9](M9.md) | Station behaviors, language bindings, and Arrow Tables | Bounded profile implemented and qualified on Linux x86_64 across all target languages; Zig reference workers |
| [M10](M10.md) | Verification and scale foundations | In progress; testing strategy, CI cost, growing state and scale qualification |
| [M11](M11.md) | Idiomatic language SDKs | Planned |
| [M12](M12.md) | Documents, collaborative text and unified querying | Planned |
| [M13](M13.md) | HTTP connector and exchange transcripts | Planned |
| [M14](M14.md) | gRPC connector and streaming calls | Planned |
| [M15](M15.md) | Arrow Flight, Flight SQL and ADBC interoperability | Planned |
| [M16](M16.md) | Clustered execution and portability | Planned |

The historical [pre-Station review](../reviews/PRE_STATION.md) led to the completed
[M8 readiness requirements](M8.md#exit-criteria). Station now builds on the resource
commit primitive and these runtime contracts; a production behavior runtime is
not implied by either bounded profile.

Station establishes Table and language-binding contracts with the first bounded
[Fuze](../FUZE.md) query profile. The [post-M9 review](../reviews/PRE_M10.md)
leads to [M10](M10.md): implement the [testing strategy](../TESTING.md), improve
CI feedback/cost and decouple durable collection growth from fixed resident
catalogs before SDKs stabilize. The current hard limits are qualification
constraints to replace, not the intended programming model.
[M11](M11.md) then builds language-native public SDKs
over those bindings, including typed handlers/state, recoverable operations,
runtime integration and installable artifacts. Fuze's shared source model targets
KV, Table and Document; [M12](M12.md) adds Document/CRDT storage, structured and
collaborative text editing, and the KV/Document query adapters with their own
acceptance criteria.
HTTP proves shared effect capture; gRPC extends it to bidirectional calls; Arrow
interoperability then adds a remote query surface over the same Tables. Clustering
qualifies those boundaries across broader topologies. Fuze
remains Zig throughout; SQL or RPC transport never replaces durable authority.

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
