# transit-station-host

A native port executable for language adapters. It hosts the shared Transit
client and Station ABI; application handlers remain in the caller's language.
It is a local child process, not a network service, scheduler or durable queue.

```sh
zig build transit-station-host
zig-out/bin/transit-station-host /path/to/host.json
```

Configuration is the generated `HostConfig` in Station's
[ABI resource](../../packages/zig/transit-station-bindings/abi-v1.json):

```json
{
  "url": "http://127.0.0.1:18101",
  "seed_file": "/private/worker.key",
  "growing_server": {"profile": "native_v1", "realm": 72, "principal": 1, "pid": 1, "generation": 3, "association": "data", "failure_policy": "stop"},
  "timeout_ms": 5000
}
```

The key is 64 hexadecimal characters. Provision identity/grants/ownership before
starting a behavior; this executable does not allocate them. Omitting `growing_server` and `query_client` creates a raw client port without reading a Station credential. Raw request
preparation takes an explicit key path. The host performs no credential discovery.

Send one JSON request per stdin line and await one stdout line before the next
request. Begin with `{"hello":{}}` and verify all returned versions are 1 and the full definition identifier matches
the generated local contract. Version numbers alone do not prove compatibility.
Responses are `{"status":0,"value":...}`; nonzero statuses use the generated ABI
codes. Logs and metrics go to stderr so stdout remains machine-readable. Adapters
must inherit/drain stderr and enforce bounded requests, responses and pending work.

`growing_prepare`, `growing_apply`, `growing_finish`, `growing_pending`,
`frame` and `growing_arrow_cell` use Station's shared
exports; `prepare` and `call` use the raw client. Schemas come from Zig, not a
second handwritten contract. Canonical pending/prepare results are strings:
retain those exact bytes instead of parsing and re-encoding signed requests.
The current input line budget is twice the protocol body limit plus 16 KiB.
Configuration and line byte bounds are exported by the raw ABI contract from
the shared host constants.
Oversized lines terminate the host; malformed complete JSON gets an error response.
`metadata` classifies opaque retry bytes in the native client; `client_capabilities`
reports that implementation's support. Raw operations delegate to the same
owner as the independent [client port](../transit-client-host/README.md).
New raw-only SDKs can use that executable without importing Station.

For pure framing and owned IPC decoding, select `{"local_codec":true}`. This
mode creates no authority clients or behavior handles and accepts no endpoint,
seed path or server configuration. `frame`, `growing_arrow_cell`,
hello and local growing capabilities remain available; authority operations
return `not_ready`. A missing endpoint without this explicit mode still rejects.
SDK encoders can therefore use shared native codecs without inventing an endpoint
or opening a signing credential. `tests/station_codec_host.py` qualifies this
mode and conflicting/missing configuration rejection.

EOF releases handles after the current operation. A killed port may leave an
accepted request uncertain; inspect/retry its frozen request or fence the old
activation before recomputing. There is no automatic retry under a new identity.
The [shared binding guide](../../packages/zig/transit-station-bindings/docs/bindings.md)
defines proposal, allocation and lifetime semantics.

## Station behavior profile

`growing_server` uses generated `GrowingConfig` with `profile: "native_v1"`
and an explicit `failure_policy` (`stop` or `block_input`). Principals retain the
full public range. Station behavior and `query_client` are mutually exclusive.
Unknown fields and incompatible profiles reject without a fallback.

`growing_capabilities` reports this local adapter's support. `growing_prepare`,
`growing_pending`, `growing_dispatch`, `growing_apply`, `growing_finish` and
`growing_discard` call the [growing ABI](../../packages/zig/transit-station-bindings/docs/bindings.md#explicit-growing-turns).
Export/persist the exact `growing_pending` string before dispatch, including
control mutations. Growing actions require the ready event's scope token.
This slice supplies bounded KV/Table pages and retained-source access. Set
`query_results: true` to enable native capture/delivery and complete manifest/IPC
segment actions with one bounded 1 MiB workspace. Result completion is a framework
event, not an application-codec payload. Language runners use this same dispatch boundary.

## Joined shutdown

The independent `query_client` profile supplies `connection` (realm, principal,
source/resource and requester/requests identities) and `timeout_ms`. It requires
an explicit endpoint and seed but no activation. It cannot be combined with a
server or local-codec profile. `unified_query` delegates signed preparation,
admission observation and verified result pages to the shared query ABI; see
the [query guide](../../packages/zig/transit-station-bindings/docs/unified-query.md).
Prepared requests and result continuations are opaque strings. Retain the exact
prepared string before dispatch; replacing a child process cannot resolve an
uncertain submission or renew a revoked grant.

The independent `mutation_client` profile uses an explicit realm/principal,
writer/resource and Table connection. Its `table_mutation` actions delegate to
the [mutation caller ABI](../../packages/zig/transit-station-bindings/docs/table-mutations.md).
It cannot be combined with query, server or local-codec profiles. Current grants
and the writer’s separate policy remain required; the profile does not provision
resources or infer a write target.

`shutdown` explicitly destroys all Station, query, mutation and raw-client handles,
then responds with `{"closed":true}` and exits without waiting for stdin EOF.
This works in authority and local-codec modes. Await the acknowledgement and
successful child exit when joining cleanup; loss of either is a cleanup failure.
Shutdown neither commits private handler work nor cancels previously accepted
mutations. Retain pending material and known receipts independently.
