# Automatic Table maintenance qualification

Run `just test direct-table-maintenance` inside `nix develop`. The existing
[service fixture](direct_table_service.py) starts a local disk node and a signed
[Table caller](direct_table_maintenance.zig). It does not start Station workers
or a SQL service. The [schedule](direct_table_maintenance.py) preserves failed
installations under `/var/tmp` and the runner captures stdout automatically.

Three Tables retain 256, one and one point-written rows. Two identities collide
in the bounded maintenance age cache. Independent values, original snapshot
identities and unchanged logical positions must survive automatic flushing,
archive/checkpoint, compaction, SIGKILL during accepted work and another restart.
The small Tables must finish flushing before the large Table. Independent segment
footer/checksum checks verify all 258 physical rows. Packed segment files must
remain unchanged after compaction eligibility inspection, and settled maintenance
must stop publishing new work.

## Foreground resource observations

The disabled-Table-maintenance control and automatic-flush phase each run sixteen
complete scans of the same three original retained cuts. Each sample independently
checks all 258 row values and reports its monotonic duration only after completion.
No new read pins or mutations are submitted. Concurrent inspection records physical
progress. The active phase requires a completed read while flushing has both made
progress and retained pending rows; simply starting two processes is insufficient.
The existing maintenance convergence and request deadlines remain unchanged.

The `Table maintenance resource observations` JSON line identifies the source,
toolchain lock, binaries, drivers, platform and fixture configuration overrides.
It retains each raw read duration and Linux node counters before and after the
phase: CPU ticks, faults, kernel I/O bytes, character I/O, resident bytes and
process-lifetime peak RSS. Convert tick differences with the recorded clock rate.
Counter snapshots must belong to the same process incarnation. Readers are joined
on success and killed/joined on failure; incomplete samples do not pass.

This is an installed-owner contention observation with an uncontrolled host page
cache. Each arm restarts the node, but prior verification warms different paths;
the active phase also waits for flush convergence. Report these scopes alongside
the measurements. Peak RSS includes owner initialization and other prior activity;
it is neither a per-phase allocation peak nor the private maintenance allocator
budget. Kernel I/O excludes unrelated processes and does not count logical object
bytes. The HTTP proxy and caller have separate processes whose resources are not
part of the node counters. These sixteen samples do not establish a tail-latency
guarantee or a matched implementation speedup.

Native/direct collection retains its default eligibility in both arms; these
observations do not isolate its contribution. The measurements do not yet cover
concurrent foreground writes, large Table cardinality, isolated collection cost,
archive/compaction contention, allocator backing
attempts or aggregate admission limits. Keep the existing
[owner benchmarks](../../performance/storage/storage_benchmark.md), allocator
checks and collection/failure schedules separate; this schedule does not replace
them or establish a zero-allocation read path.
