# Engineering history

This archive preserves earlier topic accounts, language API sketches, workload
assumptions and qualification reviews. These records mix past implementations
and proposals. Their dates, outcomes and stated limits remain attributable;
they do not define current interfaces or add passing evidence.

Read [Internals](../handbook/internals/README.md) for consolidated explanations of how the
system works, and the [guides and reference](../README.md) for how to use and
operate it. Delivery planning belongs in [Roadmap](../roadmap/README.md);
UI/UX proposals and review outcomes belong in [Design](../design/README.md).

## Reading the archive

The records remain in Git and are linked as source material rather than published
as separate handbook pages. Technical accounts link relevant records for detailed
provenance; readers do not need to reconstruct current behavior from this archive.

- [Pre-Station review](reviews/PRE_STATION.md) and [pre-scale review](reviews/PRE_M10.md)
  preserve their qualification findings and open requirements.
- [Python](sdk/PYTHON.md), [TypeScript](sdk/TYPESCRIPT.md) and [Rust](sdk/RUST.md)
  preserve the original SDK design decisions; packages own current APIs.
- [Trading workload model](workloads/TRADING.md) records demand scenarios, not measured SLOs.

## Topic records and current interface owners

| Engineering record | Current public owner |
| --- | --- |
| [ARCHITECTURE](ARCHITECTURE.md) | [Architecture and scope](../handbook/reference/architecture.md) |
| [SCOPE](SCOPE.md) | [Architecture and scope](../handbook/reference/architecture.md) |
| [TRANSIT](TRANSIT.md) | [Processes, turns and recovery](../handbook/reference/processes.md) |
| [STREAMS](STREAMS.md) | [Streams and delivery](../handbook/reference/streams.md) |
| [STATE](STATE.md) | [State resources and associations](../handbook/reference/state.md) |
| [SECURITY](SECURITY.md) | [Identity, permissions and trust](../handbook/reference/security.md) |
| [RETENTION](RETENTION.md) | [Retention, lifetimes and capacity](../handbook/reference/retention.md) |
| [FLOW_CONTROL](FLOW_CONTROL.md) | [Streams and delivery](../handbook/reference/streams.md) |
| [GLOSSARY](GLOSSARY.md) | [Glossary](../handbook/reference/glossary.md) |
| [CLIENT](CLIENT.md) | [Caller and SDK semantics](../handbook/reference/callers.md) |
| [SDK](SDK.md) | [Caller and SDK semantics](../handbook/reference/callers.md) |
| [STATION](STATION.md) | [Station behaviors, names and supervision](../handbook/reference/station.md) |
| [TABLES](TABLES.md) | [Tables and materialization](../handbook/reference/tables.md) |
| [DOCUMENTS](DOCUMENTS.md) | [Documents and collaborative text](../handbook/reference/documents.md) |
| [CONNECTORS](CONNECTORS.md) | [Effects, HTTP and gRPC connectors](../handbook/reference/connectors.md) |
| [GRPC](GRPC.md) | [Effects, HTTP and gRPC connectors](../handbook/reference/connectors.md) |
| [SERVING](SERVING.md) | [Serving application APIs](../handbook/reference/serving.md) |
| [REACTIVE_API](REACTIVE_API.md) | [Sessions, watches and live views](../handbook/reference/reactive.md) |
| [REACTIVE](REACTIVE.md) | [Sessions, watches and live views](../handbook/reference/reactive.md) |
| [REACTIVE_APPLICATIONS](REACTIVE_APPLICATIONS.md) | [Application installation, definitions and migration](../handbook/reference/applications.md) |
| [FUZE](FUZE.md) | [Query execution and result recovery](../handbook/reference/queries.md) |
| [QUERY_LANGUAGE](QUERY_LANGUAGE.md) | [SQL reference](../handbook/reference/sql.md) |
| [ARROW](ARROW.md) | [Arrow interchange](../handbook/reference/arrow.md) |
| [DEPLOYMENT](DEPLOYMENT.md) | [Deployment and recovery](../handbook/reference/deployment.md) |
| [BOARD](BOARD.md) | [Inspect with Board](../handbook/guides/inspect-board.md) |
| [OBSERVABILITY](OBSERVABILITY.md) | [Logs, metrics, traces and probes](../handbook/reference/observability.md) |
| [URSULA](URSULA.md) | [Storage and recovery boundary](../handbook/reference/storage.md) |
| [DEVELOPMENT](DEVELOPMENT.md) | [Development](../handbook/guides/contributing.md) |
| [TESTING](TESTING.md) | [Guarantees and verification limits](../handbook/reference/verification.md) |
| [CONFORMANCE](CONFORMANCE.md) | [Guarantees and verification limits](../handbook/reference/verification.md) |
