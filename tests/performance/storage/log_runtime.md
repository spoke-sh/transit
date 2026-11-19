# Installed Stream and Queue budgets

Run `nix develop --command just test::log-runtime-baseline --output PATH` with
a new output directory. The default is three warmup iterations and twenty
measured iterations per profile. `--profiles 1 3 --warmup 1 --repeat 1` is a
small correctness check; it establishes no tail percentile. `--repeat 100`
provides enough observations to report p99. Run measurements separately from
builds, fault suites and other load on the same host.

| Profile | Mode | Payloads per append/enqueue | Ordering | Claim / concurrency |
| --- | --- | --- | --- | --- |
| 1 | `hot` | Stream, 1 | offset | — |
| 2 | `hot` | Stream, 128 | offset | — |
| 3 | `hot` | Queue, 1 | unordered | claim max 1 |
| 4 | `hot` | Queue, 128 | unordered | claim max 16 |
| 5 | `hot` | Queue, 128 | `key_fifo`, 64 keys | claim max 16 |
| 6 | `hot` | Queue, 128 | `key_fifo`, 1 key | claim max 16 |
| 7 | `sealed_segment` | Stream, 128 | offset | post-seal `.tseg` read |
| 8 | `consumer_group` | Stream, 1 | offset | durable offset commit |
| 9 | `delayed_visibility` | Queue, 1 | unordered | `visible_ms` timer wait, claim max 1 |
| 10 | `wait_wakeup` | Queue, 1 | unordered | concurrent enqueue wakeup, claim max 1 |
| 11 | `lease_expiry` | Queue, 1 | unordered | expired-lease reclaim, claim max 1 |
| 12 | `concurrent_load` | Queue, 2 | `key_fifo`, 64 keys | 2 concurrent workers, claim max 1 |

Each schema contains an int64 offset, a deterministic 128-byte binary payload
and an int64 entity key. Profiles 1 through 11 use one measured caller (with a
concurrent producer thread supplying wakeups in Profile 10) and Profile 12 uses
two concurrent consumer workers over 64 affinity keys within the bare node's
four-lane HTTP data admission ceiling. Runs use one logical
partition, unlimited retention, 60-second leases (except the short initial
expired leases prepared before Profile 11), at most 64 active leases and one
resident page per native page cache. The catalog and log owners have separate
configured caches; the caller records their compiled defaults under
`owner_budgets` in each phase, including index-work, tail and Queue
candidate/scheduling bounds. These are configuration limits, not measured memory
use. Restart must preserve them. The report also records the actual native cache,
server timeout and configured clock-error allowance from the private node
configuration. Measured phases run the bare node without automatic maintenance:
Profile 7 seals pre-populated Stream WAL rows into verified `.tseg` segments and
restarts before timing cold-owner segment reads, and Profile 11 expires prepared
short leases through maintenance and restarts before timing post-expiry reclaim.
Its 10,000-ms clock allowance governs the local Stream/Queue time envelope; it
does not extend the 60-second lease or the caller's 30-second timeout.
The node stores accepted history on local disk. The driver copies
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
and includes its time in that logical call. Every logical call, including its
final response, must finish before the existing 30-second budget. A late known
mutation receipt is saved before failing the measurement; this failure does not
turn accepted work into an unknown outcome or authorize resubmission. Independent
report validation also rejects late samples. Mutations and waits are never
automatically repeated by the driver.

For a failed partial run, the matching proof caller also accepts
`URL log-baseline-inspect-OPERATION_ID PROFILE_PATH`. Reopen the retained private
installation with its matching node and configuration first. Inspection loads
and validates the saved canonical request, checks its original connection and
operation identity, and performs only the public operation lookup. It writes a
private `.inspection` observation beside the request without requiring the
successful run's final state file. A null receipt leaves the outcome unresolved;
this mode never resubmits work or converts missing evidence into rejection.

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

The 12 profiles cover sequential hot Stream and Queue paths, sealed `.tseg`
segment reads, consumer-group offset commits, delayed visibility, wait wakeups,
expired-lease reclaim, 2-worker offered-load concurrency, and original-selection
restart readback across all modes. Station handler turns use a separate workload
and are not inferred from these measurements.

Reporting controls run in the fast profile through
`tests/performance/storage/log_runtime_test.py`. Real installed measurements have
the explicit `test::log-runtime-baseline` task owner.
