# 6. Shared client foundation and language-native APIs

[Roadmap](README.md) · **Status:** Planned

Let ordinary applications use data, queries and transactions through idiomatic
language clients without adopting Station. Establish reusable package ownership,
bounded client infrastructure and recovery semantics before expanding the SDK
matrix or building collaboration adapters on those APIs.

## Prerequisites and split ownership

Consume the [installed data lifecycle](03-live-storage-and-sql-cutover.md),
[statement results](04-statement-results-and-consumption.md) and
[transactions](05-transactions-and-atomic-composition.md). Contract and language
sketches begin with those owners; core data paths must not wait until this
milestone to acquire sound ownership. The
[caller reference](../handbook/reference/callers.md),
[SDK reference](../handbook/reference/sdks.md) and
[client/framework account](../handbook/internals/client-framework.md) describe
the current boundaries.

This milestone extracts the foundation from
[language-native programming and mixed composition](26-programming-model.md).
That later milestone retains the recorded source assessment, all three mixed
capabilities (recorded effects, durable consumers and typed Station calls),
Station behavior ergonomics and the complete installed cross-language journeys
after outbound MCP. [Service/SDK coverage](13-service-and-sdk-coverage.md)
retains its delivered raw-client/console slices and operation/platform breadth;
it expands over this package and API foundation rather than establishing a
competing interface first. None of the split marks existing work complete.

## Delivery sequence

1. **Review shared application contracts before package moves.** Map identities,
   definitions, typed values/codecs, references, credentials, result readers,
   transactions, accepted-operation handles and execution scopes to their owners.
   Distinguish pure preparation, reads, independent commits, transaction-scoped
   changes, native turn proposals and recorded effects. Review side-by-side
   direct, transaction, recovery and mixed-mode sketches in Python, TypeScript,
   Rust, Go, Zig and BEAM, then every claimed language. Mark future capability
   sketches as proposals; executing a later mixed journey is not this gate.
   Select native error, cancellation, iteration, ownership and cleanup behavior
   without requiring identical class layouts or scheduling models.
2. **Extract reusable data implementation from Station adapters.** Give shared
   Table storage/publication/index and catalog/query clients real Zig package
   owners under `packages/`, with manifests and direct dependencies. Keep behavior
   and turn adapters with Station. Runtime apps cannot depend on `sdks/` facades;
   the kernel remains independent of Station. Migrate current consumers through
   the package interfaces and preserve their existing qualified behavior. The
   ordinary client artifact must not require a Station runner or caller-hosted
   actor merely to use data. Keep pure codecs usable without credentials or I/O.
3. **Unify bounded client and host infrastructure.** Make data/catalog/query
   facets compose in one client context while leaving room for subscriptions,
   effects and service calls from their later owners. Replace mutually exclusive
   client host modes where they prevent composition. Define principal-sequence
   coordination, handle/buffer ownership, fair admission, worker/queue bounds,
   cancellation and joined shutdown. A context need not use one socket or thread;
   slow queries must not starve control progress. Preserve application-owned
   native loops and explicit Zig allocator/I/O control. Separate native-host and
   browser transport, credential and recovery-store profiles.
4. **Provide ordinary operations and explicit recovery control.** Reuse shared
   SQL result readers and owner-managed submission/staging/settlement so ordinary
   calls do not require application upload/poll/continuation queues. Keep
   prepare/save/dispatch and low-level step control for advanced callers. Specify
   recovery-store hooks, failures and the guarantee without a store; persist exact
   prepared work before dispatch when caller-loss recovery is promised. Bind
   operation keys to scope, content, definition and receipt lifetime. Preserve
   uncertainty, incomplete results and original identity; a local await is not
   a durable record, and retry does not authorize new work. Transaction helpers
   must preserve provisional statement results, explicit commit outcomes and
   the callback/outbox boundaries from the transaction owner.
5. **Ship the foundation through representative installed clients.** Qualify
   direct data/query/transaction and recovery paths in Zig, Python and TypeScript
   first, including concurrent facets through the shared host. Existing consumers
   in every affected language migrate coherently; the representative set does
   not excuse a broken existing binding. Broader new operation/platform coverage
   remains milestone 13; full mixed and Station ergonomics remain milestone 26.
   Apply the current-v1 cutover policy to incompatible ABI/stored semantics,
   regenerate fixtures, reject incompatible saved artifacts, and publish current
   behavior in caller/component/SDK owners as each slice lands.

## Completion evidence

Measure the representative installed clients' allocation/copy counts, bounded
streaming, cancellation/settlement cost and durable completion latency against
the same native operations. Carry these baselines into the later
[performance scorecard](10-data-structures-and-performance.md). Shared declaration
and progress conventions must accommodate the
[indexing lifecycle](08-indexing-and-access-paths.md) without another client
scheduler or recovery protocol; index-specific adapters arrive with that owner.

Run real installed direct-client applications with no Station runner artifact.
Compare object/type identity, five-state values, exact integers/decimals and
result evidence across the representative languages. Exercise original-operation
recovery, lost commit replies, revocation, incomplete reads, recovery-store
failure, cancellation, borrowed-buffer lifetimes and joined close.

Verify actual dependency closure, not just renamed exports. Exercise concurrent
catalog/query/transaction work, multiple principals and one cancelled operation
while other work continues. Measure startup cost, threads/processes, memory,
queue bounds and control fairness. Preserve existing native and SDK recovery
proofs across the package cutover. Language sketches alone do not establish API,
platform or worker-deployment support; record executed profiles in the
[proof ledger](../history/qualification/README.md).
