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

A journal may implement paired `beginSubmission`/`endSubmission` hooks to sequence
complete `submit` calls before refresh, authentication and private preparation.
The local backend uses this to avoid competing native candidates. Explicit
`prepare`/`commit` remains optimistic; every path retains conditional publication
and current authorization. The engine owns no scheduling lock or provider policy.

Each engine keeps at most eight successful domain-proof/public-key pairs to
reuse their mathematical signature verification. Every authentication still
uses current credential and role state, checks the credential epoch and selected
role, and evaluates current permissions and lifetimes. The cache contains no
authorization decision; a changed claim, signature or key requires verification.
Replacement starts with an empty cache.

Four principal projections can also be retained at an exact native head, bound
to its position and complete Catalog and policy snapshots. Any accepted change
invalidates reuse, including sequence advancement, revocation, role changes and
credential rotation. This saves repeated decoding and realm/process permission
walks within one immutable head. It does not retain operation permission checks,
SET-role decisions or resource lifetime observations across requests; those still
run against current authority and time.

Each native and policy Catalog retains at most 16 immutable control records at
its exact root. Recognized role, credential, object, domain, grant, process,
resource and association records also retain their owned decoded values; other
record types still parse normally. Cached records remain inputs to current
validation and permission evaluation. An unpublished candidate's record takes
precedence, and changing roots invalidates the cache, including when returning
to a retained earlier root.

Policy and required-dependency scans have separate eight-page caches, keyed by
the complete root, namespace range and continuation. Empty pages are cached too.
Current lifetime checks still inspect every dependency and sample the clock;
cached bytes cannot turn expired or revoked work into usable state.

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
