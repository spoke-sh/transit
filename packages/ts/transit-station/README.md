# transit-station for Node.js

A strict TypeScript adapter to the shared [native host](../../../apps/transit-station-host/README.md).
It runs handlers in Node and schedules native calls through a bounded child-process
port. No network/signing/framework implementation is duplicated in JavaScript.
The Node 24 baseline executes the TypeScript directly; Vite+ owns checks and
dependency installation. This is a server-side execution client, separate from
Board's browser inspection SDK.

The separate [M11 public Station package](../transit-station-sdk/README.md) now
provides typed handlers, scoped turns, recovery stores and query readers, with an
independent [raw client](../transit-client/README.md). Existing users can retain
this M9 package; the new API requires explicit growing configuration and does
not silently change `NativeHost` behavior.

```sh
just transit-board::install
zig build transit-station-host
just bindings::node-check
export TRANSIT_HOST="$PWD/zig-out/bin/transit-station-host"
node examples/station-bindings/node/main.ts /private/host.json service 2
```

The example requires provisioned grants/association/ownership. `just bindings::test`
in `nix develop .#bindings` supplies a disposable real system and cross-language
peers. Type and runtime schemas are generated from the shared Zig definitions;
Ajv checks requests and Station response types, with no implicit coercion.

`NativeHost.open(executable, config)` negotiates versions. `next`, `apply`,
`finish`, `pendingRequest`, `prepare` and `call` return promises. Exactly one
request may be in flight; overlapping calls reject with status 9. Requests and
responses are bounded to 528 KiB, and each request has a 65-second outer timeout
around the native deadline. Diagnostics drain to stderr. Call `close` in `finally`.

Aborting a request terminates this port; it does **not** cancel a Transit message
or prove that a submission failed. Lost/malformed completion of `next` or `call`
returns uncertainty, and the host cannot be reused. Retry exact pending bytes or
fence/reconcile through fresh ownership. Host errors never silently acknowledge
an input. The [transport tests](src/host.test.ts) exercise event-loop responsiveness,
busy handles, cancellation, port exit, malformed responses and byte limits.

Table int64/correlation values stay decimal strings; convert to `bigint` when
needed. Protocol counters remain limited to safe integers. Queries expose the
original IPC bytes through the typed `arrow` result; `arrowCell` optionally uses
the same native reader. [Shared ABI semantics](../../zig/transit-station-bindings/docs/bindings.md)
and resource budgets apply unchanged.
