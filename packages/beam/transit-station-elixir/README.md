# Transit Elixir Station SDK

This M11 public runner is qualified through the shared authority schedule.
`Transit.Station.Sdk` provides structs, behaviours and tagged results over the
shared [Erlang Station SDK](../transit-station-sdk/README.md). Applications supply
codecs, handlers and explicit recovery policy. The runner owns native preparation,
sequential dispatch and mutation gates. State fields and suspended tasks are local;
associated KV/Table state and recorded calls carry durable facts.

The SDK uses separate public-client, Station and native OTP artifacts on Linux
x86_64/OTP 28/Elixir 1.18. It preserves M9's `Transit.Station` low-level adapter.
No optional BEAM Arrow adapter is selected; original owned IPC is the result
interface. Registry publication and foreign Substrate workers remain outside scope.

See [installation, APIs, recovery and migration](docs/usage.md).
M15's [HTTP structs and replay API](docs/http.md) preserve current authorization,
owned binaries and joined disposal through the Erlang SDK.

M16 adds [finite RPC calls and captured replay](docs/grpc.md), including local
descriptor binding and explicit status-zero/unknown outcomes.

M17 adds [Document structs, scoped jobs and owned accepted reads](docs/documents.md).

M18 adds [typed unified state queries](docs/unified-query.md), with owned nested
Arrow values, current source checks and explicit signed retry tokens.

[Catalog callers](docs/catalog.md) provide general typed Table schemas, finite
mutations, ALTER/DROP, retained definitions and exact saved-intent recovery through
the Erlang API.

[Logical values](docs/logical.md) provide owned recursive descriptors, exact wide
numbers, distinct cell states and bounded neutral codecs.
