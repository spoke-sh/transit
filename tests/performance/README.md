# Performance workloads and budgets

[Test index](../README.md) · [Contribution rules](AGENTS.md)

| Owner | Workloads and executable inputs |
| --- | --- |
| Declarative operations | [Guide](declarative/README.md), [manifest](declarative/manifest.json), [runner](declarative/run.py), [pure SQL probe](declarative/sql.py) |
| Query operators, files and pipelines | [Guide](query/README.md), [runners](query/), [active budgets](query/budgets/) |
| Storage and ingestion | [Owner measurement guide](storage/storage_benchmark.md), [paired runner](storage/storage_benchmark.py), [ingestion runner](storage/storage_ingest_benchmark.py) |
| Structural page experiments | [Geometry/codec runner](storage/page_layout.py), [native probe](storage/page_layout.zig); private variants, without provider I/O or native latency claims |
| Offered load and scale | [Load driver](load/growing_load.py), [scale matrix](scale/scale.json), [matrix runner](scale/scale.py) |
| Console and mutation latency | [Console runner](console/console_latency.py), [mutation runner](mutations/mutation_latency.py), [transport probe](../harness/http_probe.py) |
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

## SQL result consumption

The [allocation coverage inventory](allocations.json) records owner boundaries,
warmup limits and pending qualification. Its entries are scope declarations,
not passing evidence. `transit-memory`'s allocation probe counts attempts as well
as successes and can forbid backing allocation/growth after warmup. Counters
inside one owner do not establish process-wide or OS-level allocation behavior.

`just test::console-latency --rows 70 --repeat 3` creates an owned local Table
with fixed integers and deterministic variable-width text. It checks narrow,
wide, relational and metadata results, records first-output/terminal time and
sampled console RSS, then measures native batch counts, canonical/HTTP bytes and
an ordered cell digest independently. A 50-ms consumer delay exercises bounded
pull pacing. `--instrument` adds a native/Table proxy, operation counts and the
node's owner-work counters. Local storage has no separate provider HTTP endpoint;
reported provider counters describe the node's instrumented owner operations.
Compare those runs separately from unproxied latency. Every selected executable
is copied before startup so concurrent workspace rebuilds cannot replace it.

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
