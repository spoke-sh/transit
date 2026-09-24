# transit-node

The Transit authority executable. It composes
[transit-core](../../packages/zig/transit-core/README.md), the
[Ursula backend](../../packages/zig/transit-backend-ursula/README.md), signed HTTP
ingress, and a trusted clock. It validates and commits protocol operations;
application handlers run in client programs.

## Operations guide

[Configuration and operations](docs/operations.md) covers bootstrap, the separate
maintenance process, trusted clock requirements, deadlines, and diagnostics.
The HTTP node and maintenance use the same binary with different roles; neither
executes application handlers.

## Build and run

From the repository root in `nix develop`:

```sh
just build::debug apps
zig-out/bin/transit-node CONFIG.json
```

Use the [persistent launchers](../../launchers/README.md) or
[disposable examples](../../examples/README.md) for a complete local setup
or the [reference runbook](../../deploy/reference/README.md) for Kubernetes.
`CONFIG.json` below is an operator-supplied file, not a checked-in fixture.
[main.zig](main.zig) owns startup/HTTP configuration;
[Maintenance.zig](Maintenance.zig) owns background reconciliation.

## Topology and scaling

The current profile has one realm journal and a sequential HTTP server, with one
request per connection and bounded buffers. Conditional append fences competing
authorities; it does not turn replicas into independent write shards. No throughput
or high-availability target is claimed. Run maintenance separately so ingress
cannot occupy its loop; the finite-capacity proof assumes one maintenance writer
and bounded authority concurrency.

Application workers are replaceable callers and need no Ursula credentials.
The [runtime controller](../transit-runtime-controller/README.md) manages their
provider resources when deploying through Substrate. Neither it nor an example
worker is required for standalone client-driven use.

## Public surfaces and service roles

| Surface | Meaning |
| --- | --- |
| `POST /v2/command` | Signed mutation or reconciliation of an existing receipt |
| `POST /v2/view` | Signed current process and next-input view for callers |
| `POST /v2/inspect` | Signed bounded discovery, relationships and retained history |
| `POST /v2/state` | Signed state capabilities, resources, associations and value reads |
| `GET /health` | Refresh storage and report role readiness; no workload progress guarantee |

[main.zig](main.zig) owns configuration, ingress and response projections;
[Clock.zig](Clock.zig) supplies host time and [Maintenance.zig](Maintenance.zig)
owns background lifetime/checkpoint/reclamation work. Neither mode automatically
pumps committed outboxes or emits framework timers/lifecycle messages. Those
runtime roles are [M9 prerequisites](../../docs/roadmap/M9.md#entry-gates).

## API, trust, and validation

The [service contract](../../contracts/SERVICE_V2.md) defines routes, signed reads,
error responses, buffers, and transport limits. The current listener is private
HTTP: command signatures neither encrypt reads nor authenticate response
transport. A public deployment needs an authenticated TLS boundary. Keep raw
Ursula and provider APIs inaccessible to workloads.

Run `just test::service` for signed ingress, deadlines, revocation, paused callers,
maintenance, and restart; `just launchers::reference::test` separately checks deployment
isolation. See [proof coverage and limits](../../tests/README.md).

## Inspection

The additive `/v2/inspect` read boundary supplies discovery and filtered retained
history with fixed page/scan bounds. [Inspection v1](../../contracts/INSPECTION_V1.md)
defines authentication, two-endpoint link filtering, cuts and reclamation errors.
It exposes neither raw storage nor administrative journal records.

## State-resource reads

`POST /v2/state` implements the domain-separated signed [state v1](../../contracts/STATE_V1.md)
query contract. Current principal, PID and resource grants are checked before
returning bounded metadata, associations, entries or an activation's captured
read view. Reads fence against a changed journal tail; stale pagination cuts
fail explicitly. Resource mutations use `/v2/command` and the existing receipt
and retry rules. Legacy inline-only callers retain their original wire format.
