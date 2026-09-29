# Internal engineering records

Current behavior is documented in the [public handbook](../README.md), shared
by application users, developers and agents. Start there. This directory retains
planning, historical design rationale and proposals; it is not a private product
specification or a prerequisite for using Transit.

## When to use this directory

Consult a specific record for the scope of an upcoming change, a dated design
choice or the provenance of a qualification decision. Keep implemented concepts,
constraints, security assumptions and recovery semantics in public guides and
references. Promote new knowledge there as part of the change; do not leave the
only useful explanation in a milestone or agent instruction.

Legacy topic documents below mix implemented profiles with historical proposals.
Their public successors own current explanations. Exact wire/component owners
and executed proof evidence settle compatibility; internal prose cannot widen it.
Preserve historical outcomes, while correcting broken links and marking superseded
proposals explicitly. Internal records stay out of handbook navigation/search.

## Planning and history

- [Roadmap](roadmap/README.md): linear milestones, decisions, exit criteria and status.
- [UI/UX reviews](design/README.md): one numbered review sequence per item; preserve outcomes and distinguish acceptance from implementation.
- [Pre-Station review](reviews/PRE_STATION.md) and [pre-M10 review](reviews/PRE_M10.md): dated comparisons and qualification gaps.
- [SDK design records](sdk/PYTHON.md), [TypeScript](sdk/TYPESCRIPT.md), [Rust](sdk/RUST.md): original language API decisions; current usage lives with the packages.
- [Rey workload model](workloads/REY.md): downstream demand scenarios, not measured service SLOs.
- [Decision guidance](decisions/README.md) and [template](decisions/TEMPLATE.md): reserved for future use; no separate ADR process yet.

## Public successors to legacy topics

| Engineering record | Current public owner |
| --- | --- |
| [ARCHITECTURE](ARCHITECTURE.md) | [Architecture and scope](../reference/architecture.md) |
| [SCOPE](SCOPE.md) | [Architecture and scope](../reference/architecture.md) |
| [TRANSIT](TRANSIT.md) | [Processes, turns and recovery](../reference/processes.md) |
| [STREAMS](STREAMS.md) | [Streams and delivery](../reference/streams.md) |
| [STATE](STATE.md) | [State resources and associations](../reference/state.md) |
| [SECURITY](SECURITY.md) | [Identity, permissions and trust](../reference/security.md) |
| [RETENTION](RETENTION.md) | [Retention, lifetimes and capacity](../reference/retention.md) |
| [FLOW_CONTROL](FLOW_CONTROL.md) | [Streams and delivery](../reference/streams.md) |
| [GLOSSARY](GLOSSARY.md) | [Glossary](../reference/glossary.md) |
| [CLIENT](CLIENT.md) | [Caller and SDK semantics](../reference/callers.md) |
| [SDK](SDK.md) | [Caller and SDK semantics](../reference/callers.md) |
| [STATION](STATION.md) | [Station behaviors, names and supervision](../reference/station.md) |
| [TABLES](TABLES.md) | [Tables and materialization](../reference/tables.md) |
| [DOCUMENTS](DOCUMENTS.md) | [Documents and collaborative text](../reference/documents.md) |
| [CONNECTORS](CONNECTORS.md) | [Effects, HTTP and gRPC connectors](../reference/connectors.md) |
| [GRPC](GRPC.md) | [Effects, HTTP and gRPC connectors](../reference/connectors.md) |
| [SERVING](SERVING.md) | [Serving application APIs](../reference/serving.md) |
| [REACTIVE_API](REACTIVE_API.md) | [Sessions, watches and live views](../reference/reactive.md) |
| [REACTIVE](REACTIVE.md) | [Sessions, watches and live views](../reference/reactive.md) |
| [REACTIVE_APPLICATIONS](REACTIVE_APPLICATIONS.md) | [Application installation, definitions and migration](../reference/applications.md) |
| [FUZE](FUZE.md) | [Query execution and result recovery](../reference/queries.md) |
| [QUERY_LANGUAGE](QUERY_LANGUAGE.md) | [SQL reference](../reference/sql.md) |
| [ARROW](ARROW.md) | [Arrow interchange](../reference/arrow.md) |
| [DEPLOYMENT](DEPLOYMENT.md) | [Deployment and recovery](../reference/deployment.md) |
| [BOARD](BOARD.md) | [Inspect with Board](../guides/inspect-board.md) |
| [OBSERVABILITY](OBSERVABILITY.md) | [Logs, metrics, traces and probes](../reference/observability.md) |
| [URSULA](URSULA.md) | [Storage and recovery boundary](../reference/storage.md) |
| [DEVELOPMENT](DEVELOPMENT.md) | [Development](../guides/contributing.md) |
| [TESTING](TESTING.md) | [Guarantees and verification limits](../reference/verification.md) |
| [CONFORMANCE](CONFORMANCE.md) | [Guarantees and verification limits](../reference/verification.md) |

## Working rules

Use the [documentation ownership guide](../README.md#where-documentation-lives).
System design rationale stays with its topic. UI/UX proposals follow the shared
[review template](design/TEMPLATE.md) and per-item D-number sequence; black-and-white
wireframes precede explicit styling reviews. New work follows the roadmap's
[sequencing rule](roadmap/README.md#maintaining-the-sequence). Tie claims to the
[public verification reference](../reference/verification.md) and actual
[proof ledger](../../tests/README.md), never a skipped or incomplete check.
