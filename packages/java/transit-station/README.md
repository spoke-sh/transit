# transit-station for Java

This is the preserved M9 low-level adapter. For typed handlers, scoped state,
bounded runner futures and installed examples, use the
[M11 public SDK](../transit-station-sdk/README.md); raw applications can use the
independent [Java client](../transit-client/README.md).

An `AutoCloseable` native port adapter over the shared Zig Transit/Station
implementation. It exposes asynchronous `CompletableFuture` operations and
generated status/version constants; the generated ABI resource records action
and result schemas. Applications retain handler code and choose exception policy.

The pinned baseline is OpenJDK 21 with checksummed Gson 2.12.1. Use
`nix develop .#bindings` and `just bindings::test` for compilation and real
cross-language handler/Table proofs. The
[example](../../../examples/station-bindings/java/StationExample.java) accepts
a provisioned host-config path, role and peer PID. Compile against the Nix
`TRANSIT_GSON_JAR` and this package's Java sources. `TRANSIT_HOST` selects the
explicit native executable. Public Maven publication is not qualified.

`NativeHost.open` negotiates versions. Each host admits one operation; a bounded
worker performs pipe I/O; futures complete on the common pool so user
continuations cannot occupy the pipe worker or shared deadline thread.
A 65-second deadline kills
a stuck port, and cancelled futures terminate their port too. The child owns
native stack/I/O requirements; no native calls run on JVM threads. Use
try-with-resources to close explicitly. Dropped or cancelled futures do not
acknowledge/cancel durable messages; a lost mutation completion is uncertain.

The port bounds line bytes, parses strict UTF-8/JSON with bounded nesting, and
checks response envelopes/statuses. The native implementation validates public
protocol reads and typed action semantics. Gson values retain exact numeric
text; Arrow int64/correlations are decimal strings. Query results expose finite
IPC bytes; the optional `arrowCell` accessor uses the shared Arrow reader.
`pending`/`prepare` return canonical frozen strings for exact retry. Follow the
[shared ownership/recovery contract](../../zig/transit-station-bindings/docs/bindings.md).
