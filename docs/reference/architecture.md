# Architecture and scope

Transit gives applications durable process identities, ordered mailboxes and
versioned state. Workers propose changes; the authority validates and commits
them to durable history. A worker's memory, a provider's pod and a UI cache are
never substitutes for that history.

This reference is shared by application authors, Transit contributors and agents.
Start with [the quickstart](../guides/quickstart.md) for an executable local system
and [interface selection](../guides/choose-interface.md) for supported profiles.
Transit is experimental. The qualified local application profile is Linux x86_64;
source builds are available, while public release distribution remains planned.

## Responsibilities

```mermaid
flowchart TD
  App[Application workers and callers] --> Client[Public client and SDKs]
  App --> Station[Station behaviors and state helpers]
  Station --> Client
  Client --> Node[Transit authority]
  Node --> Storage[Ursula storage adapter]
  Query[Fuze query execution] --> Sources[Authorized source adapters]
  Sources --> Client
  Board[Board inspection] --> Client
  Serving[Serving and Flight gateways] --> Client
  Runtime[Runtime reconciliation] --> Client
  Runtime --> Provider[Kubernetes and Substrate]
```

| Layer | Responsibility | Boundary |
| --- | --- | --- |
| Protocol and core | Identity, ordering, current grants, fencing, lifecycle and atomic commit decisions | No application handlers, provider types or query execution |
| Client | Canonical requests, signatures, bounded reads, private proposals and exact retry | Application code still validates its domain rules |
| Station | Behaviors, durable calls, names, supervision, typed Tables and Documents | Builds above the client; no alternate execution authority |
| Fuze | Typed finite plans, source adapters, bounded execution and Arrow output | No raw storage credentials or kernel authority; no DataFusion/Acero runtime |
| Connectors | Authorized external attempts and durable capture | Replay reads outcomes; it does not redispatch |
| Serving and Flight | Protocol adaptation, scoped admission and bounded disclosure | A socket, cursor or ticket is not permission |
| Board | Evidence projections and separately configured query/application workspaces | Inspection does not decode arbitrary application payloads |
| Storage and runtime | Persistence and physical process placement | Provider state cannot revive a retired PID or grant ownership |

Rey is the intended downstream trading application, not the runtime's name.
Trading policy, reasoning loops, goals and delegation belong to applications.
LLM and tool access belong behind connector effect boundaries. Transit does not
select a venue, strategy, latency target or monetary representation for you.

## Source of truth

A successful [turn](processes.md) commits state, input progress and outputs
together. Materialized indexes and caches are derived from accepted history.
Validated checkpoints may become essential recovery evidence after a prefix is
trimmed; they are not disposable caches. [Ursula](storage.md) supplies conditional
durability through the backend; it does not choose Transit identities or grants.

Execution ownership and permissions are separate. Current authorization applies
to writes, reads and replay. A process association names accessible state but
does not grant access or transfer resource lifetime. See [security](security.md),
[state](state.md) and [retention](retention.md).

## Compatibility is explicit

Legacy protocol/state profiles retain their fixed limits. The growing v3 profile
uses bounded pages and immutable state roots, allowing retained collections to
grow beyond resident caches. There is no automatic history conversion between
profiles. Query v1, query v2, service bindings, SDK ABIs, application revisions
and ownership generations are distinct compatibility dimensions.

Implemented combinations include local application installation, Station SDKs,
finite HTTP/gRPC effects, structured Documents, finite KV/Table/Document queries,
Table notifications and snapshot refresh, and finite Table Flight SQL.
Cross-resource transactions, general continuous SQL, interactive outbound RPC
resumption, federated identity and general live disaster recovery remain outside
those profiles. A runnable subset does not establish the broader feature.

Kubernetes with Agent Substrate is the reference runtime. Trusted local and
Compose deployments do not provide the same isolation. Restore from an old
backup is not an ordinary worker restart. See [deployment](deployment.md).

## Find an implementation owner

Use the [component directory](components.md) for package interfaces and the
[contributor guide](../guides/contributing.md) for builds and validation. Wire
specifications stay in [contracts](../../contracts); each package owns its
configuration, APIs and bounds. Public documentation owns the explanation of
current behavior, including limitations and tradeoffs, for every audience.
