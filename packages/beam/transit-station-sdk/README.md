# Transit Erlang Station SDK

This M11 public runner is qualified through the shared authority schedule.
`transit_station_sdk` owns bounded runner scheduling and ordinary Erlang behaviours
for codecs, handlers and recovery hooks. Shared Zig owns signing, protocol,
framework transitions and query execution. The independent client and native
Station applications are explicit dependencies. Public records live in
`include/transit_station_sdk.hrl`; generated wire contracts stay in `priv/`.

Typed turns expose associated KV state, bounded Table pages, retained versions,
messages/calls and original query IPC. Each helper belongs to one active callback
process and expires at callback completion. Failed reads poison private work even
if the handler catches their tagged errors. Every mutation is gated before native
dispatch; recovery preserves exact bytes and retained confirmations. BEAM fields,
processes and suspended calls are not durable state or Transit ownership.

Build artifacts target Linux x86_64/OTP 28 with the pinned bindings shell. They
require the Nix native closure; registry publication and foreign Substrate images
are outside qualification. The M9 `transit_station` adapter remains separate.

See [installation, APIs, recovery and migration](docs/usage.md).
M15 adds [HTTP publication, correlated calls and immutable replay tokens](docs/http.md)
through the shared native host.

M16 adds [finite RPC calls and captured replay](docs/grpc.md), including local
descriptor binding and explicit status-zero/unknown outcomes.

M17 adds [Document changes, scoped jobs and owned accepted reads](docs/documents.md).

M18 adds [typed unified state queries](docs/unified-query.md), with owned nested
Arrow values, current source checks and explicit signed retry tokens.
