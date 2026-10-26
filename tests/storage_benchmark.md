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
decoded groups and logical replay frames. Object counters describe the public
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
fixture files and verify residency. This conditions fixture file pages at process
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

`python3 -B tests/storage_benchmark_test.py` verifies that incomplete phases,
changed result digests, unexpected writes, false replay counts and missing raw
repetitions reject. The ordinary core checks execute this report validator;
the disk measurement matrix is an explicit task with an output destination.

The [recorded owner matrix](storage_benchmarks/2026-10-26-owners/README.md)
retains all 768 samples, exact build identities and the observed limits of the
checkpoint comparison.

## Ingestion and commit measurement

```sh
nix develop --command just test::storage-ingest-benchmark --output .cache/storage-ingestion.json
```

The ingestion driver uses the same disk probe, value oracle, cache conditioning
and allocation accounting. Each sample starts from a fresh copy of its exact
baseline. Table arms append the same sixteen 1,024-byte payloads through either
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
