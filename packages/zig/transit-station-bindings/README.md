# transit-station-bindings

The shared native SDK bridge composes [Station](../transit-station/README.md),
the [client ABI](../transit-client/docs/bindings.md) and
[HTTP](../transit-station-http/README.md). It owns detached handler
operations, native handle/buffer lifetime, generated C declarations and the schemas
used by every language adapter and the [native port](../../../apps/transit-station-host/README.md).

This package sits above the framework so connector and later Document/query
adapters can compose shared Zig implementations without reversing Station's
dependency direction. The existing `station_abi` module, `libtransit_station`
artifact, function signatures and wire schemas are preserved by this extraction.
Additive M15 exports prepare HTTP request commitments, decode outcomes and expose
one bounded replay reader. Scoped publication actions and validated HTTP calls
reuse the same native turn and dispatch gate. These are native composition APIs;
all [ten public SDKs](../../../docs/CLIENT.md#http-connector-callers) provide typed
request/call/replay conveniences with local qualification. Explicit durable
release is also available through shared codecs and scoped `http_release` calls;
all ten SDKs expose it. Scoped `http_followup` calls validate published request
commitments and submit HTU1 through the same durable call machinery. All ten SDKs
expose typed followup helpers and qualify correlated policy refusal; broader
connector lifecycle and deployment work remain in M15.

See the [binding guide](docs/bindings.md) for ownership, scoped turns, explicit
dispatch, exact pending retry and query buffers. Native foreign pointers never
grant durable authority; host runtimes still own scheduling and joined destruction.

Run `zig build test` here for standalone checks. From the root, use `just check`
and `just bindings::native` for generated-contract drift and real C/C++/Python
ownership/recovery proofs. `just bindings::generate` regenerates declarations
from the public Zig exports; generated resources remain separate from idiomatic
host APIs.
