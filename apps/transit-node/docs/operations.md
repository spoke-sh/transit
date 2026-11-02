# Node configuration and operations

[transit-node](../README.md)

## Configuration and bootstrap

`transit-node CONFIG.json [--bootstrap|--initialize|--maintain]` uses the
[configuration fields and maintenance policy](growing.md). Only `--bootstrap`
or `--initialize` creates storage; the latter exits after initialization.
Ordinary startup requires an existing history/checkpoint with the current
contract definition and matching genesis. An outage or incompatible history
cannot initialize an empty realm. The node needs no root signing seed.

Ordinary startup makes at most three attempts to read retained history when
storage returns a temporary transport failure or service-unavailable response,
with 100 ms between attempts. These attempts do not create storage or publish
state. Missing, denied, corrupt or incompatible history fails immediately, and
the listener opens only after recovery validates the retained authority. This
attempt limit does not establish a deadline for an individual provider request.

The local owner also detects uncertain writes in its native/Table WAL and the
native/direct allocation journals. It stops the listener, cancels and joins all
request and maintenance work, releases borrowed page caches, then closes the
exclusive directory owner. Reopening validates that same retained history before
serving again; it never bootstraps a replacement realm. There are at most three
such reopens per node invocation, with 250, 500 and 750 ms backoffs. A fourth
recovery-required event fails the process with `LocalWalReopenBudget`. Corrupt,
missing or incompatible retained history fails immediately during reopening.

This applies to temporary `--bootstrap` nodes as well as supervised nodes.
Callers keep the original signed request and resolve its outcome after recovery;
an unavailable response or disconnected socket does not establish rejection.
The owner emits `storage.owner.reopen` without request contents. Native transient
snapshot handles acquire a fresh epoch; durable Table pins remain in their
accepted owner history. Joining the old work precedes reopening the directory,
so no request can retain a usable handle into the closed owner.

`--maintain` uses a dedicated realm-wide principal with admin, effect and
delivery grants. Its bounded scans suggest ordinary signed transitions; current
authorization and lifecycle rules still decide acceptance. It materializes known
expiry, closes due attempts, collects eligible records and reconciles checkpoint
or payload deletion intents. It never dispatches an external effect. Opt-in
retention, dependency checks and recovery evidence remain required.

History is unlimited by default. A checkpoint requires the genesis
`allow_history_trim` opt-in. Maintenance verifies the committed floor and rereads
the published snapshot before trimming earlier authority records. Pending mailbox
values, receipts and resource roots remain independent of the trimmed journal
prefix. Resource history reclamation and physical payload deletion have their
own eligibility gates. See [retention](../../../docs/handbook/reference/retention.md).

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

Stream and Queue owners use a fixed interval around each trusted UTC sample:
the configured `genesis.max_clock_error_ms` on each side. The kernel-reported
error must fit inside that envelope. Keeping its width fixed prevents a normal
decrease in reported synchronization error from looking like a regressing upper
clock floor. Actual UTC regression still fails the native and persisted partition
floor checks; restart never resets those floors. Visibility and expiry use the
lower bound, while append timestamps and lease deadlines use the upper bound.
A larger configured error allowance therefore makes timed eligibility more
conservative; it is not just a health threshold. Missing or untrusted time still
refuses time-dependent work.

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
