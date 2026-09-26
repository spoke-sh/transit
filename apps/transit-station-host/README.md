# transit-station-host

A native port executable for language adapters. It hosts the shared Transit
client and Station ABI; application handlers remain in the caller's language.
It is a local child process, not a network service, scheduler or durable queue.

```sh
zig build transit-station-host
zig-out/bin/transit-station-host /path/to/host.json
```

Configuration is the generated `HostConfig` in Station's
[ABI resource](../../packages/zig/transit-station/abi-v1.json):

```json
{
  "url": "http://127.0.0.1:18101",
  "seed_file": "/private/worker.key",
  "server": {"realm": 72, "principal": 1, "pid": 1, "generation": 3, "association": "data"},
  "timeout_ms": 5000
}
```

The key is 64 hexadecimal characters. Provision identity/grants/ownership before
starting a behavior; this executable does not allocate them. Omitting `server`
creates a raw client port without reading a Station credential. Raw request
preparation takes an explicit key path. The host performs no credential discovery.

Send one JSON request per stdin line and await one stdout line before the next
request. Begin with `{"hello":{}}` and verify all three returned versions are 1.
Responses are `{"status":0,"value":...}`; nonzero statuses use the generated ABI
codes. Logs and metrics go to stderr so stdout remains machine-readable. Adapters
must inherit/drain stderr and enforce bounded requests, responses and pending work.

`next`, `apply`, `finish`, `pending`, `frame` and `arrow_cell` use Station's shared
exports; `prepare` and `call` use the raw client. Schemas come from Zig, not a
second handwritten contract. Canonical pending/prepare results are strings:
retain those exact bytes instead of parsing and re-encoding signed requests.
The current input line budget is twice the protocol body limit plus 16 KiB.
Oversized lines terminate the host; malformed complete JSON gets an error response.
`metadata` classifies opaque retry bytes in the native client; `client_capabilities`
reports that implementation's support. Raw operations delegate to the same
owner as the independent [client port](../transit-client-host/README.md).
New raw-only SDKs can use that executable without importing Station.

EOF releases handles after the current operation. A killed port may leave an
accepted request uncertain; inspect/retry its frozen request or fence the old
activation before recomputing. There is no automatic retry under a new identity.
The [shared binding guide](../../packages/zig/transit-station/docs/bindings.md)
defines proposal, allocation and lifetime semantics.

## Explicit growing profile

M11 adds `growing_server` using the generated `GrowingConfig`. Supply
`profile: "growing_v3"` and an explicit `failure_policy` (`stop` or `block_input`)
with the ordinary activation/association fields. Principals retain the full
public range. Supplying both `server` and `growing_server` rejects; no implicit
profile fallback occurs. The original hello response stays unchanged for M9.

`growing_capabilities` reports this local adapter's support. `growing_prepare`,
`growing_pending`, `growing_dispatch`, `growing_apply`, `growing_finish` and
`growing_discard` call the [growing ABI](../../packages/zig/transit-station/docs/bindings.md#explicit-growing-turns).
Export/persist the exact `growing_pending` string before dispatch, including
control mutations. Growing actions require the ready event's scope token.
This slice supplies bounded KV/Table pages and retained-source access. Set
`query_results: true` to enable native capture/delivery and complete manifest/IPC
segment actions with one bounded 1 MiB workspace. Result completion is a framework
event, not an application-codec payload. Public language runners remain separate work.
