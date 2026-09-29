# Node configuration and operations

[transit-node](../README.md)

## Configuration and bootstrap

`transit-node CONFIG.json [--bootstrap|--initialize|--maintain]` accepts:

| Field | Meaning |
| --- | --- |
| `genesis` | Exact expected [v2 genesis](../../../contracts/TRANSIT_V2.md), including root public key |
| `ursula_url`, `bucket`, `journal` | Private authoritative storage endpoint/location |
| `listen`, `port` | IPv4 address (default `127.0.0.1`) and port (default 8080) |
| `request_timeout_ms` | Whole-request deadline, default 2000, maximum 60000 |
| `maintenance` | Optional settings for the separate `--maintain` process below |
| `accept_trace_parent` | Accept internal diagnostic trace parents, default false; never authentication |

Only explicit `--bootstrap` or `--initialize` creates storage; the latter exits
after validating initialization. Ordinary startup requires validated
existing history/checkpoint; an outage is not an empty installation. The node
needs no root signing seed. Bootstrap configuration is an operator trust input.

`--maintain` runs a separate trusted process without an HTTP listener. Its config
requires `principal` and `seed_file`, with realm-wide `admin` and `effect` grants.
It scans the bounded process/effect/payload and state-resource catalogs,
including expired read views, suspended-process deadlines and opted-in catalog
collection, and commits at most one due
transition per iteration, and reconciles recorded checkpoint/deletion intents.
Payload deletion requires verified publication, owner retirement and explicit
opt-in; its tombstone stays in control history. Default interval is
1000 ms and whole-operation timeout is 5000 ms; both are configurable up to
60000 ms. After a successful transition the next scan waits only 1 ms; idle and
failed scans use the configured interval. Incoming HTTP load cannot occupy this process's execution loop.
Lost acknowledgements are reconciled from history before the next operation.

History remains unlimited by default. Optional `checkpoint_every_records` (at
least 2) asks maintenance to checkpoint quiescent opted-in processes after that
many records since the retained floor. Realm retry policy must permit removal,
every PID must have `allow_trim`, and every resource must permit history
removal under its minimum age; pending input still blocks trimming.
Publication is read back before retention advances. Clock failure blocks timed
expiry/closure but permits authorized checkpoint/deletion recovery. Maintenance
credentials and raw storage access stay outside worker sandboxes. The separate
[capacity proof](../../../tests/README.md#physical-capacity-profile) exercises a
physically reserved finite realm; enabling the node alone does not provision that
reserve or promise full-store recovery for an arbitrary storage deployment.

## Time and deadlines

Deadline races require `Io.Select.concurrent` for both the operation and timer.
Zig's `async` may execute inline when its worker budget is exhausted, preventing
the caller from observing the timer. Failure to allocate concurrency fails the
operation instead of running it without a working deadline. On Linux, the
service proof restricts itself and its children to one CPU and exercises stalled
request headers/bodies, an authority that never replies, and paused storage
across successive maintenance deadlines.

Finite lifetimes and resource read-view/turn operations require
`genesis.max_clock_error_ms`. Even unlimited-lifetime resources use finite read
views, so their caller turns require this clock profile. On Linux, the node reads
`adjtimex` in read-only mode, rejects unsynchronized/error status, and records the
kernel-reported maximum error rounded conservatively to milliseconds. Platform
C headers supply ABI offsets; clock policy is Zig. Transit checks the configured
error bound and durable time floor. Other platforms fail finite clock use closed.
A trusted synchronization service and honest reported UTC error bound remain
deployment assumptions; reading a clock does not prove them. Controlled-clock
tests prove the deadline rules. The `--maintain` mode hosts background expiry,
closure, checkpoint/trim and eligible payload deletion in a separate process.

## Service diagnostics

`LOG_LEVEL` / `LOG_FORMAT` select bounded stderr diagnostics; see
[telemetry](../../../packages/zig/telemetry/README.md) for schema, defaults and limits.
`transit.http.request` separates HTTP status/local write completion from protocol
`read`, `receipt`, `rejected` or `uncertain` outcomes. Command names and authorized
realm/PID/sequence/position explain the affected boundary. A receipt may recover
an earlier acceptance; these records do not count exact fresh commits. Successful
view/inspection/health polling is debug-only; commands and failures are visible
at normal verbosity. Credentials, raw requests and application state are omitted.

The optional JSON setting `accept_trace_parent` defaults to false. Enable it only
at an explicitly trusted internal diagnostic boundary to correlate caller spans.
Even then headers are untrusted hints, never authentication or proof of causality;
malformed/duplicate context is ignored, and no baggage is forwarded. Board always
starts a fresh context for public requests. `/health` refreshes authority storage
before success; it is a role-readiness observation, not proof of workload progress.

Maintenance emits `transit.maintenance.step` for the actual command or
checkpoint/trim action, with idle scans at debug and clock/storage/deadline errors
at warning. Storage calls and authority open/bootstrap have their own correlated
observations. Recovery reports the recovered position; it does not re-emit turns.
The separate maintenance process uses service name `transit-maintenance`.
