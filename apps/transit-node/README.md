# transit-node

The Transit authority executable. It composes
[transit-core](../../packages/zig/transit-core/README.md), the
[Ursula backend](../../packages/zig/transit-backend-ursula/README.md), signed HTTP
ingress, and a trusted clock. It validates and commits protocol operations;
application handlers run in client programs.

## Build and run

From the repository root in `nix develop`:

```sh
just build
zig-out/bin/transit-node CONFIG.json
```

Use the [example launcher](../../examples/README.md) for a complete local setup
or the [reference runbook](../../deploy/reference/README.md) for Kubernetes.
`CONFIG.json` below is an operator-supplied file, not a checked-in fixture.
[main.zig](main.zig) owns startup/HTTP configuration;
[Maintenance.zig](Maintenance.zig) owns background reconciliation.

## Configuration and bootstrap

`transit-node CONFIG.json [--bootstrap|--initialize|--maintain]` accepts:

| Field | Meaning |
| --- | --- |
| `genesis` | Exact expected [v2 genesis](../../contracts/TRANSIT_V2.md), including root public key |
| `ursula_url`, `bucket`, `journal` | Private authoritative storage endpoint/location |
| `listen`, `port` | IPv4 address (default `127.0.0.1`) and port (default 8080) |
| `request_timeout_ms` | Whole-request deadline, default 2000, maximum 60000 |
| `maintenance` | Optional settings for the separate `--maintain` process below |

Only explicit `--bootstrap` or `--initialize` creates storage; the latter exits
after validating initialization. Ordinary startup requires validated
existing history/checkpoint; an outage is not an empty installation. The node
needs no root signing seed. Bootstrap configuration is an operator trust input.

`--maintain` runs a separate trusted process without an HTTP listener. Its config
requires `principal` and `seed_file`, with realm-wide `admin` and `effect` grants.
It scans at most 64 PIDs, 128 effects and 16 payloads, commits at most one due
transition per iteration, and reconciles recorded checkpoint/deletion intents.
Payload deletion requires verified publication, owner retirement and explicit
opt-in; its tombstone stays in control history. Default interval is
1000 ms and whole-operation timeout is 5000 ms; both are configurable up to
60000 ms. Incoming HTTP load cannot occupy this process's execution loop.
Lost acknowledgements are reconciled from history before the next operation.

History remains unlimited by default. Optional `checkpoint_every_records` (at
least 2) asks maintenance to checkpoint quiescent opted-in processes after that
many records since the retained floor. Realm retry policy must permit removal,
and every PID must have `allow_trim`; pending input still blocks trimming.
Publication is read back before retention advances. Clock failure blocks timed
expiry/closure but permits authorized checkpoint/deletion recovery. Maintenance
credentials and raw storage access stay outside worker sandboxes. The separate
[capacity proof](../../tests/README.md#physical-capacity-profile) exercises a
physically reserved finite realm; enabling the node alone does not provision that
reserve or promise full-store recovery for an arbitrary storage deployment.

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

## Time and deadlines

Deadline races require `Io.Select.concurrent` for both the operation and timer.
Zig's `async` may execute inline when its worker budget is exhausted, preventing
the caller from observing the timer. Failure to allocate concurrency fails the
operation instead of running it without a working deadline. On Linux, the
service proof restricts itself and its children to one CPU and exercises stalled
request headers/bodies, an authority that never replies, and paused storage
across successive maintenance deadlines.

Finite lifetimes opt into `genesis.max_clock_error_ms`. On Linux, the node reads
`adjtimex` in read-only mode, rejects unsynchronized/error status, and records the
kernel-reported maximum error rounded conservatively to milliseconds. Platform
C headers supply ABI offsets; clock policy is Zig. Transit checks the configured
error bound and durable time floor. Other platforms fail finite clock use closed.
A trusted synchronization service and honest reported UTC error bound remain
deployment assumptions; reading a clock does not prove them. Controlled-clock
tests prove the deadline rules. The `--maintain` mode hosts background expiry,
closure, checkpoint/trim and eligible payload deletion in a separate process.

## API, trust, and validation

The [service contract](../../contracts/SERVICE_V2.md) defines routes, signed reads,
error responses, buffers, and transport limits. The current listener is private
HTTP: command signatures neither encrypt reads nor authenticate response
transport. A public deployment needs an authenticated TLS boundary. Keep raw
Ursula and provider APIs inaccessible to workloads.

Run `just test::service` for signed ingress, deadlines, revocation, paused callers,
maintenance, and restart; `just reference::test` separately checks deployment
isolation. See [proof coverage and limits](../../tests/README.md).
