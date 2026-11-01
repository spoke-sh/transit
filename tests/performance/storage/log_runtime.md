# Installed Stream and Queue budgets

Run `nix develop --command just test::log-runtime-baseline --output PATH` with
a new output directory. The default is three warmup iterations and twenty
measured iterations per profile. `--profiles 1 3 --warmup 1 --repeat 1` is a
small correctness check; it establishes no tail percentile. `--repeat 100`
provides enough observations to report p99. Run measurements separately from
builds, fault suites and other load on the same host.

| Profile | Payloads per append/enqueue | Ordering | Claim maximum |
| --- | --- | --- | --- |
| 1 | Stream, 1 | offset | — |
| 2 | Stream, 128 | offset | — |
| 3 | Queue, 1 | unordered | 1 |
| 4 | Queue, 128 | unordered | 16 |
| 5 | Queue, 128 | `key_fifo`, 64 keys | 16 |
| 6 | Queue, 128 | `key_fifo`, 1 key | 16 |

Each schema contains an int64 offset, a deterministic 128-byte binary payload
and an int64 entity key. Runs use one sequential caller, one logical partition,
unlimited retention, 60-second leases, at most 64 active leases and one resident
catalog page. The node stores accepted history on local disk. The driver copies
matching ReleaseSafe binaries before creating a private installation and uses
the public signed client directly, without the fault proxy in the measured path.
Declaration and request-file writes are outside individual operation timing.
Each sample includes authorization, transport, durable owner work, response
validation and copying to the caller's output arena. It is not an isolated fsync
or storage-owner measurement.

Original canonical mutations are saved before dispatch. Reads check every offset,
payload and entity key. Queue ACKs copy fixed lease evidence before resetting
the page arena. The node is then stopped with SIGTERM and reopened on the same directory;
every original receipt is inspected and every retained Stream/claim selection
is read again before its explicit release. An independent Python oracle verifies
the exact row coverage and digest, including duplicate and missing rows. This
restart does not establish power-loss durability, a cold OS cache or recovery
from unknown remote effects. Failed installations and original requests remain
private for investigation.
The report records the stop exit code; requiring a fallback SIGKILL fails this
restart profile. SIGTERM completion alone does not claim application-level drain.

A cold owner's bounded replay may require several read-only requests. The driver
retains the original operation or cursor, records each recovery-progress response
and includes its time in that logical call. The recovery wait has a 30-second
budget. Mutations and waits are never automatically repeated by the driver.

`report.json` retains source, driver and binary identities, all phase outcomes,
raw stdout/diagnostic identities, machine/load observations and the configured
budgets. Raw JSONL stdout records every attempted and successful call and each
readback digest. Missing completion and failed/unknown attempts fail the run;
they cannot be discarded from the denominator. p95 needs 20 successful samples
and p99 needs 100. No automatic regression threshold is inferred from one run.

The allocation probe covers the public client, its transport and result arena
after the prior output reset. It counts attempted backing allocations and growth
without forbidding them. It does not cover the node or the process I/O runtime.
Linux node snapshots provide process-lifetime peak RSS, CPU ticks and kernel I/O
byte deltas around each phase; these include setup/recovery work within that
phase and are not per-call attribution. Storage IOPS, CPU cycles and server
allocation counts remain explicitly unmeasured.

This first driver supplies sequential hot reads and original-selection restart
readback. Sealed/cold reads, consumer-group offset commits, delayed visibility,
wait wakeups, lease-expiry recovery and offered-load concurrency require their
own added profiles before the full M6 baseline gate is complete. Station handler
turns use a separate workload and are not inferred from these measurements.

Reporting controls run in the fast profile through
`tests/performance/storage/log_runtime_test.py`. Real installed measurements have
the explicit `test::log-runtime-baseline` task owner.
