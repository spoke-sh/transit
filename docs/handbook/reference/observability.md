# Logs, metrics, traces and probes

Telemetry explains observed behavior; it does not decide ownership, permission,
retention or whether a turn committed. Use durable receipts and authorized state
reads for those facts. Telemetry loss or a blocked sink must not stall control
progress or alter accepted work.

## Interpret signals

| Signal | Meaning and limit |
| --- | --- |
| Request log/span | One transport attempt and observed local handling; response write does not prove peer receipt |
| Protocol result | Newly accepted, deduplicated, recovered, rejected or uncertain only when the owner can establish that distinction |
| Metric | Bounded service-instance observation with reset/freshness semantics, not an exact global durable count |
| Liveness | Ability to make the service's required local progress |
| Readiness | Ability to serve its declared role now |
| Workload progress | Accepted application work is advancing |

An idle worker can be healthy. A responding HTTP process can be blocked on
storage. A ready server does not imply a complete query. Missing or stale metrics
are not zero, and provider journal-position differences are not message counts.

Count admission, commit, delivery, dispatch and settlement separately. Retrying a
request adds a transport attempt without necessarily adding accepted work.
Recovery must not invent a fresh application completion or external dispatch.

Growing-authority request events separate `wait_ns` (authority-lock acquisition)
from `work_ns` (serialized engine work, including provider I/O). Their
`cache_hits` and `cache_misses` count decoded page-cache access during that work.
These fields exclude network body/response time and are absent when the request
does not acquire the authority. Cache misses are not total provider requests:
journal fences and other provider operations have their own observations.
Use native operation names and provider attempt spans to attribute amplification;
do not add overlapping span durations as though they were separate elapsed phases.

## Correlation and privacy

Correlate with authenticated realm, PID, generation and operation identity where
available. Keep service/OS instance and trace/span IDs separate from durable
identities. Remote trace context is not authentication, and sampling flags cannot
force unbounded collection. Suspended work should not hold a span open for its
entire durable lifetime.

Do not record private keys, bearer tokens, resolved secrets, raw payloads or
unbounded user-controlled labels. Debug logging is not permission to dump them.
Use stable event names, bounded fields/cardinality and explicit drop counters.
Lossy telemetry remains useful without becoming an authority database.

## Configure and investigate

Executables configure diagnostic format/verbosity and write diagnostics to stderr,
preserving machine stdout for receipts and bootstrap JSON. Launchers display and
route logs; they do not reinterpret them as execution authority. Metric accumulation
is independent of whether a log was sampled or suppressed.

`transit server` uses `logging.format: text` and `logging.level: info` by default.
Set these in `transit.yaml` or override with `TRANSIT_LOGGING__FORMAT` and
`TRANSIT_LOGGING__LEVEL`. Levels are `debug`, `info`, `warn`, `error` and `off`;
formats are `text` and `json`. `SHOW logging.format` and `SHOW logging.level`
report active values. Reload validates changes and marks them pending restart.

Startup phase entry/completion events identify the active work and its monotonic
`duration_ns` at info level. The attempt total includes the wait for local SQL
when enabled; failed/retried attempts remain separate. Use these timings to
distinguish installation validation, recovery, provisioning, worker activation
and SQL setup before profiling inside an owner. See
[startup timing semantics](../../../apps/transit-cli/docs/server.md#logging-and-readiness).

At debug level, co-hosted SQL attaches client spans to typed local owner calls.
`transit.local.request` reports bounded route/operation tags, owner admission wait
and elapsed owner work. Its parent client span includes dispatch and joined
cleanup. These nested durations describe attempts, including failed attempts;
they do not establish durable completion. Default info logging omits this local
attribution. The existing bounded telemetry sink can drop or suppress records.

Text records contain a UTC timestamp, severity, service, stable event name,
optional message and named fields. JSON emits one schema-v1 envelope per line,
including the service instance and trace context when present. Text includes
trace/span/parent IDs for traced operations; the full service-instance envelope
is available in JSON. Control characters are escaped in both formats.

Standalone services use `LOG_FORMAT` and `LOG_LEVEL`. The server translates its
own effective policy into each isolated Transit child's environment; it does
not inherit arbitrary environment variables. The supervisor retains bounded
child-output prefixes rather than forwarding raw provider or application output.
See the [server logging guide](../../../apps/transit-cli/docs/server.md#logging-and-readiness)
for lifecycle, terminal and machine output behavior. Expected service failures
submit one terminal error event and exit unsuccessfully after a bounded flush.
The terminal event has a separate 2 KiB slot so ordinary queue contention and
rate suppression cannot discard it. Level and record-size limits still apply;
`off` suppresses it. The flush attempt lasts at most 200 ms. A blocked or failed
sink, or abrupt termination, can still prevent delivery. See the
[telemetry bounds](../../../packages/zig/telemetry/README.md#measurements-and-bounds).
CLI argument, configuration and SQL errors retain their command-specific
diagnostics. Panics and crashes are outside the normal service event path.

Start with [launcher diagnostics](../../../launchers/README.md#service-diagnostics)
and [node operations](../../../apps/transit-node/docs/operations.md) for exact options.
Use [Board](../guides/inspect-board.md) to follow authorized durable evidence,
including gaps, revision and freshness. Configure collectors and export paths
separately; Transit does not deploy an OpenTelemetry collector automatically.
