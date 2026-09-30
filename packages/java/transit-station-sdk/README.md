# Transit Java Station SDK

Version 0.2.0 provides typed Java 21 handlers and associated KV/Table/query APIs
over the shared Zig growing Station implementation. Signing, authority checks,
framework transitions and Fuze execution remain Zig-owned. The independent
[raw client](../transit-client/README.md) is a direct dependency; raw applications
do not depend on this package.

Use `nix develop .#bindings` and `just bindings::java-sdk-test` to compile SDKs and
[counter/query examples](../../../examples/station-sdk/java/README.md), install
JARs outside the checkout, and exercise the shared authority/failure schedule.
The [usage guide](docs/USAGE.md) describes scoped handlers, recovery hooks,
asynchronous scheduling, owned data and the migration from M9's low-level adapter.
M15 adds [typed HTTP requests, durable calls and asynchronous capture readers](docs/HTTP.md)
with immutable bytes, explicit outcome states and shared native semantics.

The supported baseline is OpenJDK 21, Gson 2.12.1, Linux x86_64 and the Nix-linked
native host. Original Arrow IPC is exposed without a selected optional Java
Arrow adapter. The conformance consumer decodes it independently with PyArrow.
Public package publication and foreign Substrate worker images remain outside
this qualification. Generated resources come from the public Zig contracts;
`just bindings::check` rejects drift.

M16 adds [finite RPC calls and captured replay](docs/GRPC.md), including local
descriptor binding, binary metadata and observed status zero.

M17 adds [immutable Document changes and asynchronous authorized reads](docs/DOCUMENTS.md)
with scoped publication and explicit Unicode scalar identities.

M18 adds [typed unified queries](docs/UNIFIED_QUERY.md) with immutable nested
Arrow values, bounded futures and explicit signed retry tokens.

The [Table mutation guide](docs/MUTATIONS.md) covers explicit SQL writes,
immutable requests, bounded futures and exact saved-command recovery.

The [catalog guide](docs/CATALOG.md) covers typed initialization, conditional
policy and Table creation with immutable commands and joined native ownership.
