# Installed managed-work and connection-pressure measurements

[Performance index](../README.md) · [Runner](installed.py) · [Reporter](report.py)

These finite diagnostic experiments run ordinary operations on a private,
cohosted, native-local installation with automatic maintenance and synchronous
durability enabled. They preserve the ordinary server deadlines and capacities.
Run each profile separately from other disk-heavy checks or timing campaigns:

```sh
nix develop --command just test::installed-performance managed --rows 16 --repeat 3
nix develop --command just test::installed-performance managed --rows 16 --repeat 3 --attribution
nix develop --command just test::installed-performance connections --peers 4 --repeat 3
```

Commit before building: the task requires a clean, revision-attributed CLI.
The task builds ReleaseSafe artifacts and uses the pinned SQL-wire environment
for independent PostgreSQL/MySQL clients. Every selected executable is copied
before startup. To reuse frozen binaries, invoke `installed.py` through the test
launcher in `nix develop .#sql-wire`, supplying `--cli`, `--node`, `--host`,
`--binary-revision` and `--profile`. Sibling Board and gateway binaries must match.
Failed installations and original console recovery files remain private.
All peer connections and installation processes are closed/joined before the
terminal campaign record. Output contains no passwords, payloads or argv.

The runner prints its automatic ignored JSONL artifact path to stderr. Summarize
it with `python3 -B tests/runner/launch.py tests/performance/load/report.py PATH`.
`--control CONTROL` refuses mismatched workload, source definition, driver,
host/storage/toolchain, maintenance and cache conditions, and changed admission
outcomes. Failed samples, missing expected cases, resources or terminal cleanup
cannot produce an accepted report. A small diagnostic run supplies sample counts,
medians, empirical p95 and maxima; it establishes no tail SLO or sustainable
throughput. Do not interpret startup or a single restart as a distribution.

The manifest includes CPU affinity, inherited cgroup-v2 CPU/memory limits when
available, CPU model and filesystem type. `--attribution` enables the existing
node `request_metrics` option through a fixture-owned executable wrapper. Binary
hashes still identify the copied executables, and the wrapper's source and choice
are attributed separately. These diagnostic runs cannot compare against timing
controls with counters disabled. Provider/header instrumentation is enabled by
that same option; its overhead is part of the diagnostic profile.

Before/after owner snapshots are outside operation timing. They contain only
fixed field names, integer values and a deployment instance, with an explicit
overflow flag. The reporter rejects missing fields, reset/wrapped counters,
changed instances and deltas inconsistent with those snapshots. Failed operations
retain their available counters and original error; an inspection failure cannot
replace that error or convert the sample to success. Snapshot loads are not an
atomic cut and can include unrelated background work.
If final inspection fails, the initial snapshot remains available without an
invented final snapshot or delta.

`managed` reports phase calls and inclusive nanoseconds, evaluation rows, pages
and encoded result-record bytes. Preparation and execution are separate from the
checkpoint pair. `decide` includes common-decision settlement and cleanup;
telemetry cannot divide those internally overlapping activities into exclusive
elapsed costs. `owned_records` reports stage calls/failures, reservation/readiness
attempts and observed returns, ready-record reuse, stored envelope bytes and
logical reservation charges (envelope plus the current 32 KiB metadata charge).
These charges are cumulative observed reservations, not resident memory or
physical storage occupancy. Lost replies can make publication returns lower than
durable counts. Exact result/completion checks remain the success oracle.
Counters accumulate work: retries can count rows, pages and stored bytes again,
so these totals do not establish unique result cardinality.

Heap allocation counts, live allocation bytes, peak workspace bytes, physical
object/log writes and syncs, retained bytes, reclaimable debt and copy counts are
explicitly unavailable. Process RSS/PSS/high-water observations retain their
separate procfs meaning. Never infer those missing values from attempt counts or
logical reservation bytes.

## Managed computation profile

The workload creates ordinary input/output Tables and a finite projection. It
measures baseline point reads, activation to complete verified output, and each
single-row input INSERT through a complete successor. A separate duration starts
after the source command returns; neither timestamp claims to be the storage
commit instant. Every observation checks the declared completed revision and
all expected output values through verified native result completion.

While waiting, the same independent native session measures foreground point
reads between distinct SHOW observations. `foreground_ns`, `pending_observations`
and poll count distinguish observed pending work from a refresh that already
finished. Samples include 50 ms observation pauses, output verification and
result closure. The fixed completion bound is 180 seconds / 2,000 observations;
queries keep the server's ordinary deadlines. Failed reads fail the experiment;
there is no resampling, mutation replay or automatic replacement snapshot.
The final verified output must also arrive within that completion bound. A late
known output remains in the failed sample, and a failed observation retains its
completed foreground timings and observed progress without restarting the read.

Typed local attempt deltas and process CPU surround the operation, including
background activity and observations. They are not unique commits, physical
syncs or additive exclusive phases. A one-second settled idle interval records
background attempts without SQL polling; automatic maintenance can still run.
A graceful retained restart records readiness and launch-to-verified-output
separately, then retires the computation. Result cardinality is bounded at 1,000;
`--rows` admits 1–900 and `--repeat` 1–100. Growth controls use separate fixtures
and remain distinct from unclean recovery qualification.

## Connection profile

The fixture enables both wire listeners and one explicit password account bound
to the installation's local owner. TLS is required and both independent drivers
verify the generated CA and hostname. Each cold sample includes connect, TLS,
authentication, exact SELECT 1 and close. Warm samples use an existing connection.
The driver then opens `--peers` additional authenticated idle connections and
measures the existing session plus native control inspection under that pressure.

Every additional peer attempt is retained as admitted or an observed wire refusal.
The current startup engines can encode final admission refusal as authentication
SQLSTATE; the report preserves that code without inferring capacity as its cause.
When libpq omits the startup SQLSTATE, only the exact server-owned fatal admission
diagnostic is recognized, with a null SQLSTATE and an explicit diagnostic basis.
Other errors fail the campaign. Compare admission outcomes as well as latency.
Choose 4 peers for below-limit controls and 8 or more to cross the default
per-account capacity of 8 (the measured connection occupies one slot).

A separate interval holds up to three peers at partial startup and measures
native control response. All partial sockets close before proceeding. This is
finite connection pressure, not independently offered request load, a deadline
exhaustion proof or cancellation qualification. Existing wire fault schedules
remain the authority for those guarantees.

Linux procfs snapshots record the complete stable installation process tree,
threads, RSS/PSS and virtual bytes before the connection workload, with each
protocol's idle peers, and after cleanup, outside timed samples. CPU uses process ticks
and includes all threads. Sampling can miss peaks; RSS is not an allocation count.
Allocator and copy counters remain explicitly unavailable. SDK text measurements
and encoded string reader measurements have separate owners.
