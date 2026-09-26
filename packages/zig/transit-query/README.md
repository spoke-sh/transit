# transit-query

Shared Zig public Table query client and application-side Station behaviors for
[M13](../../../docs/roadmap/M13.md). Board and `transit` use the same compiler,
frozen request and result readers. The [v1 contract](../../../contracts/PUBLIC_QUERY_V1.md)
owns authorization, wire encodings, admission, cancellation and limits.

- `Model` owns connection, source, prepared submission, status and typed page.
- `Client.describe/prepare/submit/status/page` use current signed Transit reads
  and commands. Retain `Prepared` on uncertain submission; its receipt identifies
  the requester correlation. A page's strings borrow the supplied request arena.
- `Client.prepareCancel/submitCancel` preserve explicit cancellation identity.
- `Behavior.Requester` binds one query principal/source and admits one active
  query. Initialize it with a separate `PQI1` cast from that principal.
- `Behavior.Source` serves one declared Table to one configured peer under
  Station's current revisioned policy. The Table and policy must already exist.
  Both behaviors need a host-owned growing query context.

This package imports Station's public module and has no kernel, storage or
provider dependency. SQL compiles in Fuze, execution runs in the separately
hosted source behavior, and result verification reuses Station. Current reads
may return a conflict if a resource changes during a bounded observation; callers
may retry the read, but must never regenerate uncertain mutations automatically.

`zig build test` checks the package independently. The real host and shell proof
is `just test::public-query`; [tests](../../../tests/README.md) record evidence.
