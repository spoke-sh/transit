# Transit documentation

The public handbook is the shared source of current behavior for application
users, contributors and agents. Start with [What is Transit?](guides/introduction.md),
[Run Transit locally](guides/quickstart.md) and
[Build your first application](guides/applications.md).

## Guides and reference

| Topic | Public documentation |
| --- | --- |
| Model and components | [Architecture and scope](reference/architecture.md), [component directory](reference/components.md), [glossary](reference/glossary.md) |
| Workloads and performance | [Workload priorities](reference/workloads.md), [measured performance and improvement plan](reference/performance.md), [examples across languages](guides/workload-examples.md) |
| Durable execution | [Processes and turns](reference/processes.md), [streams and delivery](reference/streams.md), [caller/SDK semantics](reference/callers.md) |
| Authority and lifetime | [Security](reference/security.md), [retention and capacity](reference/retention.md), [storage](reference/storage.md) |
| Application state | [State resources](reference/state.md), [Station](reference/station.md), [Tables](reference/tables.md), [Documents](reference/documents.md) |
| Installation and composition | [Application installation, definitions and migration](reference/applications.md), [language SDKs](reference/sdks.md) |
| Effects and inbound APIs | [Connectors](reference/connectors.md), [serving](reference/serving.md), [reactive sessions and views](reference/reactive.md) |
| Queries and interchange | [SQL](reference/sql.md), [query execution](reference/queries.md), [Arrow](reference/arrow.md), [Flight SQL/ADBC](reference/flight.md) |
| Interface specifications | [CLI](reference/cli.md), [native protocol](reference/native.md), [serving OpenAPI](reference/openapi.md), [Board OpenAPI](reference/board-api.md), [AsyncAPI](reference/asyncapi.md) |
| Operation and contribution | [Deployment](reference/deployment.md), [Board](guides/inspect-board.md), [observability](reference/observability.md), [verification limits](reference/verification.md), [contributing](guides/contributing.md) |

Select a supported profile with the [interface matrix](guides/choose-interface.md).
Unsupported behavior, uncertainty, recovery rules and compatibility limits belong
beside the feature users rely on. Describe the capabilities in the documented
source revision, using interface versions and explicit supported/unsupported
profiles. Public architectural priorities and performance improvement plans live
beside their evidence, explicitly distinguished from implemented interfaces and
without promised dates or speedups. Keep delivery-plan labels and scheduling in
internal records, including when a component guide or wire contract is published
in the handbook. Public documentation does not require an internal specification
to understand the real contract.

Write interfaces in the present tense: what they do, how to use them, supported
types and platforms, version compatibility and failure behavior. Avoid maturity
labels and blanket readiness caveats. Put concrete limits beside the operation
they affect; keep test execution details in the proof ledger. Clear wording must
preserve the actual support boundary.

## Where documentation lives

| Location | Ownership |
| --- | --- |
| `docs/guides/` | Runnable user and contributor workflows |
| `docs/reference/` | Current concepts, architecture, guarantees, interface semantics, limits and compatibility; explicitly labeled workload priorities and performance improvement plans |
| Package/app READMEs and `docs/` | Exact component APIs, configuration and substantial integration/recovery guides; linked directly from the handbook |
| [contracts/](../contracts) | Versioned wire/ABI formats, neutral schemas and shared fixtures; generated descriptions keep their implementation owners |
| [examples/](../examples/README.md) | Complete applications and commands that exercise the public APIs |
| [tests/](../tests/README.md) | Executable proof commands, failure schedules, measurements and qualification results |
| [apps/transit-docs/](../apps/transit-docs/README.md) | Docusaurus navigation, rendering, search, generated API presentation and browser verification |
| [docs/internal/](internal/README.md) | Planning, dated reviews, historical design rationale and unimplemented proposals; optional background for a scoped change |
| [AGENTS.md](../AGENTS.md) | Contributor/agent workflow and implementation rules; starts from the public handbook |

Keep one current explanation of a behavior. Put user-relevant reasoning, trust
assumptions, unsupported cases and failure semantics in public guides/reference,
then link exact component and wire owners. Internal plans may explain how we got
here or what we might build next; they must not be prerequisites to use the system.
When internal work establishes a current rule, promote it into the public owner
with the implementation and proof. Do not maintain a competing internal contract.

Every Markdown page in `docs/guides/` and `docs/reference/` belongs in the site
catalog. Internal pages are excluded from published navigation and search.
Public pages must not link into internal records for required explanations;
use public references and exact contracts instead. Site checks enforce that
boundary. The internal index remains reachable from this repository index for
contributors who need planning history.

Repository Markdown must remain readable without Docusaurus. Render generated
OpenAPI/AsyncAPI descriptions from the owning files; do not hand-maintain endpoint
schemas. Preserve explicit implemented/proposed/unsupported distinctions and
source evidence when moving material. Keep dates and outcomes on historical reviews.

## Update and verify

Read the public topic, its component guide and relevant wire contract before
changing behavior. Update all affected user explanations with the code. Use
[contributing](guides/contributing.md) for commands and
[verification](reference/verification.md) to select evidence. Documentation work
uses `just transit-docs::check`; `just check` includes it.

Preview with `nix develop .#docs`, `just transit-docs::install` and
`just transit-docs::dev`. The [site guide](../apps/transit-docs/README.md) covers
hosting, generated references and root/prefixed browser checks.
