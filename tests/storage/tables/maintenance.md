# Automatic Table and Stream maintenance qualification

Run `just test direct-table-maintenance` inside `nix develop`. The existing
[service fixture](direct_table_service.py) starts a local disk node and a signed
[Table caller](direct_table_maintenance.zig). It does not start Station workers
or a SQL service. The [schedule](direct_table_maintenance.py) preserves failed
installations under `/var/tmp` and the runner captures stdout automatically.
The target runs the Table schedule followed by the Stream schedule, sharing the
built node/caller artifacts while keeping their disk installations separate.

Three Tables retain 256, one and one point-written rows. Two identities collide
in the bounded maintenance age cache. Independent values, original snapshot
identities and unchanged logical positions must survive automatic flushing,
archive/checkpoint, compaction, SIGKILL during accepted work and another restart.
The small Tables must finish flushing before the large Table. Independent segment
footer/checksum checks verify all 258 physical rows. Packed segment files must
remain unchanged after compaction eligibility inspection, and settled maintenance
must stop publishing new work.

## Installed Stream maintenance

Run the Stream schedule alone with
`zig build test-direct-table-service -Doptimize=ReleaseSafe -- stream-maintenance`.
Two declared Stream partitions each accept eight rows with the same compaction
key. The caller saves append bytes and original read identities before issuing
them. With maintenance disabled, current and retained reads each return all
eight rows. With flush, archive and compaction enabled, new reads eventually
return only original offset seven, while the earlier read pins still return all
eight rows. Original producer receipts must remain unchanged.

The driver kills and restarts the node, then repeats public read and original
append recovery. Every observation has its own saved consume/release identities
and closes its temporary pin. A failed run preserves unsettled identities and
the private installation instead of submitting replacement work. The existing
60-second convergence budget remains unchanged. Numeric output records exact
source/binary identities, partition/row counts, sample count and node counters.
These checks establish installed visibility and caller recovery; native graph
collection separately proves when obsolete physical placements can be reclaimed.

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

Both arms enable the node's opt-in request metrics. The existing HTTP fixture
collects `request_memory` from each direct response into bounded operation-label
totals and maxima; it retains no request, row, key or credential bytes. Missing
or invalid observations fail the measurement. The counted live bytes must equal
the independently received HTTP response length, proving that no request scratch
remains charged during transmission. Each phase records allocation,
growing-resize and remap attempts, acquired bytes, and maximum live/peak bytes
through the complete handler allocator before response transmission. Totals
include concurrent inspection traffic, separated from `scan` by operation.
Individual request maxima cannot be added to infer simultaneous node memory.
They exclude provider/cache allocations, stacks and socket buffers. The
live-at-response count includes memory held while waiting on the client; it
does not measure post-cleanup leakage or response transmission cost.

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
observations do not isolate its contribution. The measurements do not cover
large Table cardinality, isolated collection cost or allocations through every
storage/provider owner. Keep the existing
[owner benchmarks](../../performance/storage/storage_benchmark.md), allocator
checks and collection/failure schedules separate; this schedule does not replace
them or establish a zero-allocation read path.

## Concurrent writes and admission pressure

After the packed-segment checks, the same installation saves a finite plan of
48 original point inserts, sixteen per Table, before dispatch. One writer runs
beside sixteen complete reads of the original retained cuts. A one-row flush
eligibility threshold makes the new rows eligible without changing the 32-row
work bound, private memory budget or maintenance deadline. The fixture requires
both a completed retained read and accepted segment relocation before the writer
finishes. It records complete admission/execution durations and the same node
and request-allocation counters used above. This phase has no matched disabled
write arm and establishes no implementation speedup.

The node then restarts with automatic flush/archive/compaction enabled, a 1 MiB
ordinary request budget and the existing 64 MiB Table-control reserve. Two partial
HTTP bodies exhaust ordinary allocation. An unchanged signed inspection resolves
an original committed insert while maintenance completes another bounded step.
Disconnect and the five-second request deadline must release all ordinary bytes.
The maintenance counter includes idle scans; it is not a count of relocated rows
or completed collection passes. The pressure phase does not claim a bound on the
whole process from the direct request budget.

After restoring ordinary settings, every original receipt must equal its
pre-restart result. Independent readers verify all 306 current rows and the 258
original rows, then repeat the same retained cuts after another owner restart.
Failed installations retain the saved write plan, completed receipt prefix,
signed inspection and process logs privately. The fixture never retries an
uncertain insert with a new identity.

## Discovery beyond resident coordination caches

`just test::catalog-growth` uses the existing 139-Table catalog fixture. The
first Table owns 139 point-written rows and an original retained pin; the other
138 Tables are empty. After SIGKILL and restart, automatic flush, archive and
compaction run with one resident native page, 64 host lock/recovery stripes and
bounded persisted catalog cursors. Public inspection visits every Table without
accumulating its definitions or rows. It checks unlimited history, fixed row
counts, completed physical targets and recovery coverage where archival is
eligible. Complete catalog listings and reads of the original pin overlap the
remaining work; the pin is released explicitly only after convergence.

The maintenance phase has a shared 600-second completion budget. It records raw
progress samples, exact binaries/source, and whole-node CPU/RSS/I/O counters.
This exercises discovery beyond resident caches, not 139 concurrent writers or
139 nonempty Tables. Pair it with the three-Table write/pressure schedule above;
neither profile establishes that untested cross-product or a whole-process quota.

The proxy saves each original setup mutation and pin request before forwarding
it, then saves any returned status/body beside it in the private installation's
`growth-attempts/` directory. A setup timeout can follow acceptance before the
final profile is written. These records preserve the original binding for
investigation; they do not authorize resubmitting setup under new identities or
count the unfinished schedule as passed. Signed requests stay private and are
removed with the installation only after success.

## Private maintenance allocation boundary

Run `just test local-catalog` to exercise the composed local maintenance owner
with its real disk backend. The
[catalog policy fixture](../../../apps/transit-node/local_catalog_policy_test.zig)
puts an allocation probe below the private Table maintenance budget.
The schedule spans flush, archive,
checkpoint, WAL cleanup and compaction across four Tables, then sixteen idle
units. It discards volatile discovery and recovery hints once.
This is not a process restart; the installed schedule above owns
that failure boundary.

The `Local Table maintenance backing allocations` record separates all work
units, including startup, from subsequent idle units. The probe is unsealed:
it records backing allocation and growing resize/remap attempts, successes,
requested/acquired/released bytes and peak live bytes. Every unit must release
its private allocations before the next begins. A zero retained-byte count is
not a zero-allocation result. The
[retained-workspace experiment](../../../docs/history/qualification/storage.md#reusable-private-table-maintenance-workspace--2026-10-28)
records why reducing those counts alone did not justify keeping its reserve.

This probe excludes native engine caches, provider I/O buffers, collection,
foreground requests and worker stacks. Pair its counts and peak bytes with installed
CPU/RSS/I/O and foreground measurements before making a resource improvement
claim. It does not establish an aggregate node bound or zero-allocation storage.
