# transit-core

Transit’s native authority implementation, exported as `transit_core` and hosted
by [transit-node](../../../apps/transit-node/README.md). Applications use
[transit-client](../transit-client/README.md). The core depends only on
[transit-protocol](../transit-protocol/README.md); it imports no framework, storage
backend, provider or application handler.

`Engine(Journal, PageStore)` validates current grants, signatures, principal
sequences, ownership generations, lifecycle, ordered input progress and resource
commit constraints. A conditional journal append publishes the resulting immutable
catalog root. Replay restores accepted state without dispatching effects or
executing application logic. Protocol validation does not prove honest computation.

## State and recovery

Durable catalogs grow independently of resident pages. Operations use bounded
pages, mutation batches and dependency walks. The host supplies journal/page I/O,
resident cache bounds, deployment quotas and trusted time. Prepared candidates
stage immutable pages; only conditional publication grants authority. A competing
revocation invalidates a stale candidate. Exact retries recheck current permission
before returning the original receipt.

Retention defaults to unlimited. Resource history policy, finite lifetimes,
working metadata collection and authority-prefix trimming are separate opt-ins.
Pending work, live dependencies, retained read versions and uncertain effects
constrain cleanup. Retired identities remain permanently fenced. Checkpointing
does not grant execution rights or authorize physical page deletion.

## Source map

| Source | Responsibility |
| --- | --- |
| [root.zig](src/root.zig), [growing.zig](src/growing.zig) | Public exports, engine, conditional publication and recovery |
| [pages.zig](src/pages.zig), [catalog.zig](src/catalog.zig) | Immutable pages and ordered indexes |
| [authorization.zig](src/authorization.zig) | Pure bounded role/grant evaluator over an injected immutable policy store |
| [authorization_store.zig](src/authorization_store.zig), [authorization_admin.zig](src/authorization_admin.zig) | Paged private policy candidates, dependency cleanup and default templates; publication belongs to the native journal |
| [growing_authorization.zig](src/growing_authorization.zig) | Native credential binding, current decisions, scoped policy reads and conditional publication |
| [growing_lifecycle.zig](src/growing_lifecycle.zig) | Required-resource readiness, initialization and bounded suspension |
| [growing_state.zig](src/growing_state.zig) | Resource grants, associations, views, mutations and receipt rights |
| [growing_runtime.zig](src/growing_runtime.zig) | Recorded provider lifecycle, activation and fencing |
| [growing_collection.zig](src/growing_collection.zig) | Opted-in reclamation and permanent retirement evidence |
| [growing_inspection.zig](src/growing_inspection.zig) | Scoped bounded inspection with final authority checks |
| [growing_payload.zig](src/growing_payload.zig) | Immutable payload publication and deletion eligibility |
| [Time.zig](src/Time.zig) | Trusted sample and uncertainty semantics |

## Contracts and checks

Read the [native contract](../../../contracts/TRANSIT_V1.md),
[state contract](../../../contracts/STATE_V1.md), [authority guide](docs/authority.md),
[page guide](docs/pages.md) and [engine guide](docs/growing.md).
The executable owns transport, scheduling, clocks and effects.

Run `nix develop`, then `(cd packages/zig/transit-core && zig build test)` or
`just test::packages`. The [proof ledger](../../../docs/history/qualification/README.md) owns integration
schedules, executed evidence and verification limits.
