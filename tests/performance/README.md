# Performance workloads and budgets

[Test index](../README.md) · [Contribution rules](AGENTS.md)

| Owner | Workloads and executable inputs |
| --- | --- |
| Declarative operations | [Guide](declarative/README.md), [manifest](declarative/manifest.json), [runner](declarative/run.py), [pure SQL probe](declarative/sql.py) |
| Query operators, files and pipelines | [Guide](query/README.md), [runners](query/), [active budgets](query/budgets/) |
| Storage and ingestion | [Owner measurement guide](storage/storage_benchmark.md), [paired runner](storage/storage_benchmark.py), [ingestion runner](storage/storage_ingest_benchmark.py) |
| Structural page experiments | [Geometry/codec runner](storage/page_layout.py), [native probe](storage/page_layout.zig); private variants, without provider I/O or native latency claims |
| Offered load and scale | [Load driver](load/growing_load.py), [scale matrix](scale/scale.json), [matrix runner](scale/scale.py) |
| Console, startup and mutation latency | [Console runner](console/console_latency.py), [startup workload](console/startup.py), [mutation runner](mutations/mutation_latency.py), [transport probe](../harness/http_probe.py) |
| Result codec allocations and paired costs | [Method and budgets](results/README.md), [comparison runner](results/codecs.py) |

Use the existing `just test` benchmark commands. Python entry points use
[the test launcher](../runner/README.md); pass the matching built binary and the
owning runner's workload/output arguments. Fast checks run benchmark reporting
controls and independent expected-value checks. Actual workloads have separate
execution owners and prerequisites.

The mutation runner measures a persistent console separately from the console
runner's process startup. `--repeat 0 --rows 8 --read-repeat 3` selects verified
point, range, full, empty and LIMIT-zero reads after setup, without the measured
mutation sequence. Setup still performs durable writes. `--instrument` reports
direct Table and native attempt counts; its timings include proxy overhead.
The legacy single-turn completion timeline does not attribute the multi-step SQL
recovery ledger. Failed writes retain their installation and original identity;
a fresh measurement is not recovery of that write.

Reports belong in ignored run output and CI artifacts. The
[historical experiments](../../docs/history/qualification/performance.md) retain
their source, machine, workload and measurement limits. Active budgets remain
executable inputs and invalidate their owning checks/builds. An older budget's
recorded driver, toolchain or machine identity does not automatically qualify a
new run after a path migration; qualify and freeze a matching comparison basis.

## Installed startup

`just test::console-latency --startup-restarts 3` measures one fresh headless
installation and three sequential graceful restarts of that same retained
installation. It uses the matching ReleaseSafe artifacts, JSON info logging and
existing readiness deadlines. Every start must serve a complete independently
checked console result; a row inserted after the first start must survive every
restart with the same installation identity and provisioning receipts. It never
opens the user's installation. A failed run retains its private fixture.
Add `--startup-ui` to include Board and verify its public atlas before measuring
the SQL result. Keep these samples separate from the headless profile.

Each raw `startup` sample reports external `ready_ns`, separate console
`verification_ns`, launch-inclusive `first_verified_result_ns`, phase durations
and all terminal attempt outcomes. Failed launches emit a failed sample before
the runner exits; they remain in the attempted-launch denominator. The external
timer includes process launch and the readiness observer's polling (up to 100 ms
for core output and 50 ms for SQL status). Internal monotonic spans attribute
the supervisor's phases; they are elapsed work including waits, not CPU or fsync
measurements. The attempt total contains its phases. Automatic retries remain
visible. Missing completion, telemetry loss, orphaned phases and overlapping
durations fail the diagnostic sample. Child logs and credentials stay private.
`--startup-debug` adds bounded child spans for executable validation, installation
journal checkpoints, native queries/submissions, and worker spawn/registration.
Count those records to distinguish request count from elapsed operation cost.
Their times are already included in their parent phase; never add them to its
duration. Debug runs include instrumentation overhead and are diagnostic controls,
separate from the info-level latency comparison.

Artifact preparation, the retained-row setup write, verification and shutdown
are outside startup timing. No OS page-cache eviction is performed: `fresh` means
new installation state and `restart` means reopened state, not cold disk. Run on
the filesystem being investigated and record its mount/storage and competing
host load. These few diagnostic observations establish no percentile, regression
budget or speedup. Unclean recovery, larger retained histories, Board-enabled
startup and full SDK host costs need separate controlled workloads.

## SQL result consumption

The [allocation coverage inventory](allocations.json) records owner boundaries,
warmup limits, allocator owners, executable checks and remaining gaps. An
`executable` entry identifies an available scoped gate; `component` means the
local reserve checks do not cover every composed owner. Neither records a pass:
the corresponding run artifacts establish execution. `transit-memory`'s allocation probe counts attempts as well
as successes and can forbid backing allocation/growth after warmup. Counters
inside one owner do not establish process-wide or OS-level allocation behavior.

`just test::console-latency --rows 70 --repeat 3` creates an owned local Table
with fixed integers and deterministic variable-width text. It checks narrow,
wide, relational and metadata results, records first-output/terminal time and
sampled console RSS, then measures native batch counts, canonical/HTTP bytes and
an ordered cell digest independently. A 50-ms consumer delay exercises bounded
pull pacing. `--instrument` records bounded typed native/Table attempt counters for the
co-hosted installed SQL path. `--remote-sql --instrument` selects the historical
standalone gateway proxy with per-operation HTTP and node-work diagnostics.
Aggregate local counters do not classify statements or prove durable outcomes. Local storage has no separate provider HTTP endpoint;
reported provider counters describe the node's instrumented owner operations.
Compare those runs separately from unproxied latency. Every selected executable
is copied before startup so concurrent workspace rebuilds cannot replace it.

`--instrument --local-trace` selects a separate co-hosted debug run. It exports
bounded client and local-owner spans with route/operation tags, durations and
owner admission wait, plus trace-loss counters. At most 8,192 selected records
are exported; additional records are counted as omitted. The node's raw stderr
stays in the private fixture and is removed only after successful verification.
Statement start/end wall timestamps correlate these spans approximately; nested
client/owner durations must not be added together. Debug logging adds work and
can lose records, so use uninstrumented runs for latency comparisons.

`--representations` adds a separate row/column payload experiment using the
pinned PyArrow LZ4/Zstd codecs. It verifies every decompressed byte, reports
encoded sizes and codec times, and counts schema/observation JSON separately.
These are length-framed canonical cells, not Arrow IPC or a proposed complete
wire format; they exclude envelope negotiation, alignment and transport costs.
Codec work is excluded from the preceding console/native timing runs. The fast
reporting control checks independent byte expectations and rejects a deliberately
corrupt decompression result.

The zero-row default preserves the empty-result workload. For an explicitly
frozen pre-result-model executable, `--historical-result-profile` checks its
recorded console and native shapes solely for baseline comparison; ordinary
callers do not accept that profile. Run baseline and candidate sequentially with
the same seeded data, optimization, driver and sampling options, preserve binary
hashes, compare value digests, and record background load. Do not compare latency
while concurrent heavy builds or proofs are running. These observations are not
service guarantees or complete deployment memory measurements.

`just test::console-latency --statements --repeat 5` exercises one persistent
`transit console --no-rc --format table` with `.timer on`. It verifies an empty
SELECT, warm SELECTs, single-row INSERT, UPDATE and DELETE completions, unchanged
UPDATEs, zero-match UPDATE/DELETE and the complete contents after each changed
write, then switches the same session to JSON for independent
typed readback. Each sample retains the human output, total and phase timings;
Linux node process CPU deltas include all node threads and concurrent recovery,
with the kernel's clock-tick resolution; they are not per-statement CPU attribution.
The summary uses empirical distributions without estimating tails from a small
sample. The first external elapsed time includes connection startup; the console
timer measures the statement. Later samples reuse the session. This is the real
console script path and table renderer, without terminal editor/PTY timing.
The timer's submit phase includes server preparation and execution; a zero
client compile phase does not mean the server did no planning. The wait phase
includes observing durable completion, not just the client's polling sleep.
The installed runner records separate three-second `idle` and
`idle_after_statements` windows with node CPU and optional upstream counters.
The first follows readiness and can include startup discovery; the second follows
verified readback and console closure. Neither label alone proves an empty
recovery backlog. Use the observed requests and owning recovery evidence to
interpret quiescence.

Use `--statements --repeat 1 --cycles 50` for repeated zero/one-row measurements.
Every cycle inserts, updates and deletes one row, verifies all counts and typed
readbacks, and returns the same persistent session to an empty table. The
`select_empty_warm` and `select_one_warm` distributions keep cardinality fixed;
only the first cycle's first SELECT is `select_cold`. Later cycles include a
separate `select_empty` observation. Records include the zero-based cycle ordinal.
Use `--statements --repeat 1 --warm-reads 50` to qualify unchanged reads separately
from the mutation workload: it takes 50 empty and 50 one-row warm samples, with
one verified INSERT/UPDATE/DELETE cycle. That run cannot qualify write latency
distributions. Both profiles are bounded, sequential workloads, not concurrent
throughput experiments.

Add `--resources` to sample the persistent console and the owned installation
process tree after each timed statement. Linux `/proc` supplies actual thread
counts, RSS, proportional shared memory (PSS), virtual address space and each
process's lifetime RSS high-water mark. The sampler bounds the tree to 128
processes and rejects missing fields, disappearing processes, changed identities
and changing process sets. It records no command lines. Snapshots are sequential,
non-atomic observations, outside the timed call; their extra inter-statement work
can still affect caches and scheduling, so compare runs with the same option.
Summed RSS double-counts shared pages; PSS apportions them. Virtual address space
is not allocator reserve, high-water RSS is not the peak of this statement, and
these samples do not prove zero allocation or cover other language hosts. A
snapshot is evidence only when the entire workload's value/count checks pass.

`just test::console-latency-tls 5` runs the same value/count workload through the
existing matching TLS SQL fixture without a proxy. This separate component
control keeps that fixture's 30-second native request budget and records its
binary/driver identities. It does not replace the default installation check
or establish that a failed installed-server sample passed.
`just test::console-latency-tls 5 --instrument` selects a separate diagnostic run
with the same bounded upstream probe, per-statement traces and Station-dispatch
checks as the installed workload. It interposes only the SQL gateway's native
connection after fixture provisioning. Keep its proxy timings separate from
the unproxied TLS control; overlapping/background attempts are not additive
statement phases.

Add `--instrument` in a separate run to count the SQL gateway's upstream native
and Table operations, including Catalog token/record work and direct commits.
The probe observes only SQL upstream traffic, leaving installation bootstrap and
other services on their ordinary endpoint. Each instrumented statement retains
a bounded native operation trace, including failed statements, with owner/provider
work counters and no native payloads or credentials. Truncated trace windows report
the omitted count. The statement workload rejects
Station send/turn dispatch in its measured windows. Proxy and background recovery
work affect these measurements; summed request durations may overlap and are
not pure query-engine time. Setup and idle observations remain separate. Run
baseline and candidate sequentially with matching options and no competing builds.

`just test::sql-wire-encoding` also exercises the actual native result encoder and
decoder, independently of SQL execution. It checks 10,000 scalar rows with binary
payloads and NULL, compares one-row and full-batch controls, and reports frame
bytes, encode/decode time, allocation calls and accounted peak memory. It verifies
values against the generated occurrence index, confirms variable bytes borrow the
frame, checks terminal counts and releases every accounted allocation after each
batch. The decoder peak excludes its borrowed input frame; the report includes
the largest frame separately. Allocation counts can vary when the underlying
allocator grows an arena in place. These isolated costs exclude sockets, source
execution, authority checks and storage.
