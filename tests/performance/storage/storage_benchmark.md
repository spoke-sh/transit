# Local disk owner measurements

```sh
nix develop --command just test::storage-benchmark --output .cache/storage-owners.json
```

The ReleaseSafe probe exercises the actual `TablePartition` and native
`Engine(Store, PageStore)` over local disk. It asks how accepted checkpoints
change recovery work and whether ordered access avoids unrelated segment reads.
Both arms use the same binary, compiler, accepted values, operation history and
cache limits. The checkpoint arm starts as a complete file copy of the baseline;
only the explicit checkpoint operation changes its accepted history. Independent
Python code verifies counts, sums and an order-independent SHA-256 aggregate of
every returned value and payload. The complete Table scan verifies all visited
rows as well as the selected interval. Missing completion, extra/missing phases,
changed values or publication during a measurement fail the report.

Table fixtures contain 128 and 1,024 rows in 16-row immutable segments, three
columns and a deterministic 1,024-byte UTF-8 payload. Row identity order differs
from key order. The same retained snapshot supplies a four-row interval crossing
two segments, through either an ordered range or a complete scan with the same
selection. Both arms have one resident index page, a 128 KiB encoded segment
cache and a separate 128 KiB decode limit. The checkpoint covers the complete
accepted root and replays its own publishing record. It retains the original
snapshot, WAL and logical history; it does not authorize trimming.

Native fixtures contain 16 and 64 accepted turns. Each turn commits one KV value,
one immutable 1,024-byte block, input progress and one recorded output to a second
process. Reopen checks consumed inputs/output counts and reads every KV value and
block through signed queries with block verification. Both arms use one resident
page. The fixture explicitly permits history trimming; the checkpoint arm
accepts a native checkpoint and advances the physical log's authorized read
floor. Whole segments below that floor can be removed; a segment straddling the
floor retains its bytes and startup validation. Its current
values match the untrimmed arm, while historical availability intentionally
differs. Blocks exercise the native storage boundary, not Document CRDT operators
or external effect dispatch.

## Measurement boundaries

| Phase | Included work |
| --- | --- |
| `physical_open` | WAL integrity/recovery, object-owner open and, for native storage, allocation inventory and disk quota recount |
| `recover` | Table definition/root/checkpoint validation or native engine open, with page caches initially empty |
| `measure` | Retained handle lookup, current checks, complete reads, selection and value verification; native query signing and block verification are included |
| `init` / `checkpoint` | One fixture setup/maintenance operation, recorded separately without percentile claims |

Timers are monotonic and exclude process launch, report serialization and
teardown. Total child CPU, faults, block I/O and elapsed process time are also
recorded. The fixture's files and allocated disk bytes are inventoried before
sampling and checked unchanged afterwards. The checkpoint fixture's extra files
or native trim savings remain visible in that inventory.

Owner counters distinguish WAL appends/bytes/syncs/startup frames, object
puts/ranges/payload bytes, immutable index misses and Table segment ranges/bytes,
decoded groups and logical replay frames. The `wal_*` fields count the Table or
native authority log. Separate `inventory_wal_*` fields count the native backend's
allocation queues, including their startup validation and syncs. Successful native
object creation must report its preceding durable inventory writes; readback
must append to neither log. The standalone Table fixture composes its WAL and
object store directly, so these inventory fields are zero. It does not measure
the installed direct-data adapter's allocation inventory or native authority
checks. Object counters describe the public
storage interface: they exclude descriptor/checksum reads, directory enumeration
and filesystem metadata. Kernel child block-I/O counters have their separate
whole-process scope. A lower Table replay count does not bypass WAL startup
validation or establish constant-time restart.

Allocation measurements count backing-allocator requests and simultaneous live
bytes, including arena backing slack. Each phase records the allocations already
live at its start; its peak is total tracked live bytes, not an incremental delta.
They exclude stack, allocator metadata, `std.Io` internals and the kernel cache.
Executable `VmHWM` supplies whole-process peak RSS. Separate `wait4` RSS includes
the launcher's inherited pre-exec image. The 2 GiB virtual address-space ceiling
is not an RSS or cache limit. These fixture sizes exceed configured owner caches;
they do not establish recovery for data larger than host RAM.

Every arm runs in a fresh process on one CPU, with one discarded warmup and 31
recorded repetitions under each of two page-cache conditions. Before a cold
sample the runner syncs each fixture file, applies `POSIX_FADV_DONTNEED` and
requires `mincore` to observe no resident file pages. Warm samples read all
fixture files and verify residency. A complete-fixture observation follows each
conditioning sweep. Up to three attempts recondition only mismatching files;
the report retains every attempt's page counts and the first eight mismatching
paths. A timed sample starts only after the entire observation satisfies the
requested condition. Exhaustion fails the run with those observations. This
conditions fixture file pages at process
entry, not device/controller caches, directory metadata, the executable or the
entire host. Physical startup can warm pages used by the later measured phases.
Alternating arm order and recording host load do not isolate CPU frequency,
filesystem activity or other processes.

The report retains every sample, compiler/source/binary/driver/lock identities,
fixture hashes and cache evidence. It reports a median and nearest-rank p95 with
31 or more observations, without claiming a confidence bound or p99 estimate.
`--repetitions 1 --table-rows 32 --native-rows 2` runs a smoke matrix and omits
p95. `status: passed` establishes completed, correctly verified measurements;
the timings must be assessed separately. A `running` or failed report cannot
establish full coverage. No installed SQL, SDK, distributed-provider latency or
universal memory/throughput target follows from these owner measurements.

`python3 -B tests/runner/launch.py tests/performance/storage/storage_benchmark_test.py` verifies that incomplete phases,
changed result digests, unexpected writes, false replay counts and missing raw
repetitions reject. The ordinary core checks execute this report validator;
the disk measurement matrix is an explicit task with an output destination.

The [recorded owner matrix](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/storage_benchmarks/2026-10-26-owners/README.md)
retains all 768 samples, exact build identities and the observed limits of the
checkpoint comparison.

## Ingestion and commit measurement

```sh
nix develop --command just test::storage-ingest-benchmark --output .cache/storage-ingestion.json
```

The ingestion driver uses the same disk probe, value oracle, cache conditioning
and allocation accounting. It freezes and verifies the executable so later
developer builds cannot replace it during the matrix. Each sample starts from a
fresh copy of its exact baseline. Table arms append the same sixteen 1,024-byte payloads through either
point/WAL or direct bulk-segment ingestion. Schema, keys, identities, starting
rows, cache configuration and input values match; the owner checks which
physical path advanced the segment counter. Baselines contain 128 and 1,024
rows. The `ingest` phase includes row construction, acceptance and the input
value digest. Its separately reported `wal_append_ns` brackets the actual
synchronous `Log.append`, including durability work. It is a subset of the
phase, not another operation or an estimate obtained by subtracting timings.
The driver requires one accepted append, positive sync count and complete timer
attribution. These are sixteen-row atomic writes, not single-row measurements
or group commit across independent accepted operations.

Native baselines contain 16 and 64 turns. Each sample appends one further turn
with a KV value, immutable block, consumed input and output. `prepare` includes
signed input admission, view opening, authoritative queries and turn preparation;
its two input/view appends remain visible. `commit` times the real engine commit
and its counter snapshot, excluding the later value digest. Native commit is an
owner operation, while the Table append timer measures the log interface. Their
different scopes and payload counts preclude interpreting them as equivalent
writes. Startup and recovery remain separate phases for both owners.

Every successful write is followed by a fresh-process read of every original and
new value. The Python oracle checks complete counts, sums, payload hashes and
accepted positions. Table verification also checks the original operation
receipt, physical ingestion path and unchanged retained snapshot size. Native
verification checks KV/block values, input progress and output counts through
signed reads. Readback must publish no work. A successful timed call without
successful readback cannot make a passing sample.

The report retains raw write and readback records, baseline file commitments,
physical/logical retained bytes before and after each sample, cache residency,
CPU/process metrics and all source/build identities. Point and bulk order reverses
between repetitions. Warm/cold samples each have one discarded warmup plus 31
recorded repetitions; p95 is omitted for smaller smoke runs. Baseline copies,
cache conditioning and later readback/inventory are outside the write timers.
Fresh-process recovery can warm file pages before the write phase. This does not
measure installed SQL, concurrent commit batching, device-cache coldness or data
larger than host RAM. Shared-host contention remains visible in recorded load.

## Growth under a process memory ceiling

```sh
nix develop --command just test::storage-growth --output .cache/storage-growth.json
```

The growth task builds a separate ReleaseSafe executable with 16 KiB payloads.
The driver freezes that executable, then creates increasing Table (2,048 and
8,192 rows) and native (512 and 2,048 turns) fixtures. Each creation and fresh
readback process runs on one CPU with a **128 MiB RLIMIT_AS ceiling**. This is a
limit on process virtual address space, including mappings, stacks and heap;
it is not a host-RAM, kernel-page-cache or whole-test-runner limit. Native memory
uses one index page. Tables use one index page, a 512 KiB encoded segment-cache
allowance, 16-row groups and a separate 128 KiB decoded allowance. Per-operation
build allocations retain the owning Table's existing limit.

Each fixture verifies every value during a fresh-process read, exact accepted
positions, retained receipts and Table snapshot size or native input/output
progress. File pages are synced, evicted and checked with `mincore` before that
readback. File hashes and physical allocation must remain unchanged afterwards;
verification cannot append or publish objects. The report records complete phase
allocation accounting, executable peak virtual memory/RSS, retained logical and
allocated disk bytes, cache evidence and source/build identities. A complete
normal run requires the larger retained fixture of **each selected owner** to
exceed the process address-space ceiling. Both owners run by default;
`--owner native` or `--owner table` selects one complete growth matrix for
independent diagnosis. A single-owner report does not qualify the other owner.
No latency percentile is derived from these single fixture observations.
Reports retain the requested fixture matrix and per-child time guard, including
incomplete runs. The default guard is 1,800 seconds per creation/readback process;
`--timeout` selects a different finite execution profile. A completed run with a
longer guard does not turn an earlier timeout into a pass or establish that the
default execution budget was met. Value checks, fixture sizes and memory limits
remain independently required.

A failed growth run retains its working directory and frozen executable under
`/var/tmp`; `retained_failure_directory` in the report identifies it. Inspect
that exact fixture when diagnosing partial acceptance or recovery. Successful
runs remove their private directory. Remove a failed fixture only after retaining
the evidence needed for its diagnosis; a later passing run does not clean it up.

`--table-rows 32 --native-rows 2 --smoke` validates the harness without asserting
that the data exceed the ceiling. The report labels this profile explicitly.
The initial 64 MiB smoke attempt failed during Table construction; the subsequent
128 MiB smoke observed about 74 MiB virtual peak and 32.8 MiB RSS during that
construction, with bounded readback below 11 MiB virtual. Neither smoke result
establishes the full growth matrix. The driver and its file inventory/value
oracle run outside the child limit, and the report retains host memory size;
data exceeding a process ceiling must not be described as exceeding host RAM.
