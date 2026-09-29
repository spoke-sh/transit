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

Start with [launcher diagnostics](../../launchers/README.md#service-diagnostics)
and [node operations](../../apps/transit-node/docs/operations.md) for exact options.
Use [Board](../guides/inspect-board.md) to follow authorized durable evidence,
including gaps, revision and freshness. Configure collectors and export paths
separately; Transit does not deploy an OpenTelemetry collector automatically.
