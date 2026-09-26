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
