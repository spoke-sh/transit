# Engineering history

This archive preserves earlier topic accounts, language API sketches, workload
assumptions and qualification reviews. These records mix past implementations
and proposals. Their dates, outcomes and stated limits remain attributable;
they do not define current interfaces or add passing evidence.

Read [Internals](../internals/README.md) for consolidated explanations of how the
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
- [Rey workload model](workloads/REY.md) records demand scenarios, not measured SLOs.

## Topic records and current interface owners

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
