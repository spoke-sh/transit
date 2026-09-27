# transit-query

Shared Zig public Table query client and application-side Station behaviors for
[M13](../../../docs/roadmap/M13.md). Board and `transit` use the same compiler,
frozen request and result readers. The [v1 contract](../../../contracts/PUBLIC_QUERY_V1.md)
owns authorization, wire encodings, admission, cancellation and limits.

- `Model` owns connection, source, prepared submission, status, typed page and
  Board's opaque frozen-token transport. Tokens preserve full-width SQL literals.
- `Client.describe/prepare/submit/status/page` use current signed Transit reads
  and commands. Retain `Prepared` on uncertain submission; its receipt identifies
  the requester correlation. A page's strings borrow the supplied request arena.
- `Client.prepareCancel/submitCancel` preserve explicit cancellation identity.
- `Behavior.Requester` binds one query principal/source and admits one active
  query. Initialize it with a separate `PQI1` cast from that principal.
- `Behavior.Source` serves one declared Table to one configured peer under
  Station's current revisioned policy. The Table and policy must already exist.
  Both behaviors need a host-owned growing query context.

This package imports Station's and Document's public modules and has no kernel, storage or
provider dependency. SQL compiles in Fuze, execution runs in the separately
hosted source behavior, and result verification reuses Station. Current reads
may return a conflict if a resource changes during a bounded observation; callers
may retry the read, but must never regenerate uncertain mutations automatically.

`zig build test` checks the package independently. The real host and shell proof
is `just test::public-query`; [tests](../../../tests/README.md) record evidence.

M18 adds `SourceDefinition`, `Decoder` and `UnifiedSource` under the separate
[v2 contract](../../../contracts/UNIFIED_QUERY_V2.md). Canonical `UQS2` definitions
bind resource identity, declared KV decoder versions, exact Table schemas and
accepted Document references/projections. `UnifiedSource.page` fills a caller-owned
batch from supplied captured/retained public readers; cell byte slices borrow the
bounded arena passed to that call. `Batch.engine()` must be called after the batch
has reached its final address, and its rows cannot escape that batch/arena.

Document pages separately check a current reader before and after using retained
bytes. List expansion returns at most eight items over 32 traversal steps; empty
pages may have a continuation. Text projections share a 4096-step page budget
and have explicit per-projection byte/step bounds. Unsupported expansions and
exhausted budgets reject; values are never truncated. Decoding errors are typed
cells while unknown decoder versions reject the definition.

Component tests qualify these adapters and the current Document floor/retirement
checks with in-memory private turns. V2 durable capture, public submission,
result access and SDK surfaces remain in progress; the existing `Client` and
`Behavior` still serve public Table v1 queries.
