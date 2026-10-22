# Storage foundation comparison, 2026-10-19

This page retains measurement summaries at the stated revisions. References marked
“archived” name raw files removed from the current tree; those bytes are available
only in repository history before the cleanup. These observations do not qualify
current builds.

This compares the frozen integrated baseline `ee88a131` with the complete runtime
at `29765ef0`. Both use ReleaseSafe and the pinned Zig/Ursula/MinIO tools. Owned
disk fixtures run sequentially after builds finish on the same Linux/ext4 host
(Threadripper 3960X, 48 logical CPUs). Unrelated host services remain running;
there is no exclusive CPU or fsync isolation. The
qualification record (archived)
pins raw/compressed hashes, binary/provider hashes, source/harness revisions,
controls, reproduction scripts and the baseline wire build-only patch.

The question is whether shared immutable publication, concurrent native ownership
and bounded disclosure reduce complete caller work while preserving independently
checked values. These controls measure the combined implementation, not isolated
causal contributions from each change. Timings include authority and local
persistence. Console and SQL-wire fixtures differ; their absolute times do not
isolate transport overhead. No production SLO follows from these samples.

## Durable console mutations

Each narrow case has 20 samples; wide/nested each have three. p95 is absent for
three-sample cases and no case establishes p99. All final controls complete
without errors or uncertain outcomes and independently verify all typed values.

| Case | Baseline narrow p50 / p95, ms | Final narrow p50 / p95, ms | Baseline → final wide p50, ms | Baseline → final nested p50, ms |
| --- | ---: | ---: | ---: | ---: |
| insert_1 | 1,394.0 / 1,499.9 | 806.4 / 893.9 | 24,638.2 → 13,462.6 | 20,052.1 → 11,920.4 |
| update_1 | 1,415.7 / 1,549.4 | 852.4 / 917.0 | 5,564.6 → 857.2 | 4,275.7 → 886.0 |
| update_same | 843.8 / 915.4 | 791.2 / 827.8 | 984.6 → 849.8 | 920.9 → 843.7 |
| update_absent | 798.6 / 869.8 | 760.8 / 845.1 | 959.3 → 805.6 | 866.9 → 902.6 |
| delete_1 | 836.1 / 917.5 | 830.1 / 900.6 | 1,027.4 → 842.1 | 903.9 → 901.7 |
| delete_absent | 809.2 / 868.1 | 745.5 / 817.7 | 976.2 → 818.4 | 902.6 → 795.4 |
| insert_3 | 2,702.2 / 2,945.8 | 1,173.8 / 1,276.5 | 69,872.1 → 34,389.1 | 52,407.2 → 29,616.2 |

Wide adds 30 default 64-byte UTF8 fields; nested adds a structure with a 128-byte
label and 32-element nullable text list. Wide/nested INSERT still spends seconds
in small-message statement ingress before the bulk Table publication. DELETE and
no-op cases improve less than changing INSERT/UPDATE; absent UPDATE is slightly
slower in the three-sample nested control. The original
[baseline reports](../2026-10-18/README.md) remain unchanged.

## Snapshot reads and attribution

Both console read campaigns seed 32 rows and retain 32 extra updates, then run
20 repetitions each of point, eight-row range, full, empty and LIMIT 0 queries.
The source includes its initial row as well. Queries are unordered; the oracle
sorts copies after timing and verifies exact rows, multiplicity and values.

| Read | Baseline p50 / p95, ms | Final p50 / p95, ms | Baseline → final owned snapshot calls |
| --- | ---: | ---: | ---: |
| point | 212.4 / 240.1 | 208.6 / 230.8 | 15 → 13 |
| range | 451.5 / 501.8 | 353.3 / 389.5 | 39 → 26 |
| full | 833.7 / 879.8 | 392.7 / 428.8 | 64 → 29 |
| empty | 162.3 / 174.7 | 171.5 / 194.0 | 12 → 11 |
| limit_zero | 119.9 / 139.4 | 132.1 / 150.4 | 8 → 8 |

Point reads remain approximately level; range/full scans improve. Empty and
LIMIT 0 reads regress by about 6% and 10% at p50 despite equal or fewer snapshot
calls. Fixed layout/cache/provider overhead remains measurable; these controls
do not isolate its precise cause. The retained `before-prefetch` reports show
the earlier fixed-request regression that motivated combined metadata/block reads.

Request attribution uses separate instrumented single repetitions. First INSERT
moves from two turns and one internal delivery to one turn and no delivery, with
71 → 29 staged pages, 153 → 144 native attempts and 1,443 → 1,072 provider attempts.
Provider request payload is 133,616 → 65,638 bytes. Counts include overlapping
background work and instrumentation; they are not fsyncs, deterministic whole-host
budgets or independent durations to add together.

## Retained history, load and resident memory

The final 32-row/32-update/one-reader control completes all 21 mutations and
92 reader queries with no failures. The baseline completes its foreground writes
but fails with reader `HttpCapacity`; it is not a passed concurrent workload.

| Read fixture process | Baseline HWM, KiB | Final HWM, KiB |
| --- | ---: | ---: |
| node | 53,664 | 82,484 |
| query_host | 20,048 | 24,560 |
| ursula | 96,860 | 69,804 |
| minio | 314,016 | 129,564 |

These observations use Linux VmHWM and the maximum child per role outside timed
requests, not summed RSS or exact allocations. The combined implementation has a
higher node footprint; independent engines own separate caches and work buffers.
The same resident_pages setting is per lane in the new implementation: ten lanes
plus the bootstrap context, versus one baseline engine.
This is a matched configuration comparison, not equal aggregate cache capacity.
Transit cache bounds do not bound Ursula's per-segment metadata or the whole
provider as durable cardinality grows.

The separate finite offered-load control schedules 48 public commands independently
of completion, with four generator workers, one resident page, 64 retained rows
and a 15-second native deadline. Queueing is included in latency. It validates
exact retries, denial after revocation, drain and disk/provider restart.

| Offered-load observation | Baseline | Final |
| --- | ---: | ---: |
| status | passed | passed |
| admitted | 2 | 2 |
| rejected | 46 | 46 |
| uncertain | 0 | 0 |
| control_initial_status | 503 | 503 |
| control_latency_ms | 1.691 | 0.964 |
| control_after_burst_ms | 71.667 | 70.042 |
| drain_seconds | 1.452 | 1.403 |

A control refused with explicit `HttpCapacity` is retried after the burst. Such a
result demonstrates eventual control completion, not uninterrupted control admission
or a saturated throughput guarantee. The raw reports retain generator queueing
and every attempt; single-run timing differences are descriptive.

## PostgreSQL and MySQL

The real TLS gateway uses four seeded rows and six scalar columns, retained
driver connections, literal/prepared paths and one excluded warmup per read case.
Each side completes 400 measured reads and 36 mutations. Every mutation checks
affected rows and reads its result through the other protocol. Reads have 20
samples per case/path; mutations have three and no tail claim. No nested wire
support is implied. PostgreSQL retains named prepared statements; the single MySQL
prepared cursor alternates SQL strings, so that path includes re-preparation.
These are matched caller paths, not equal prepared-handle reuse across drivers.
Baseline runtime code is unchanged; its retained build patch
only repairs a missing proof import and installs measurement binaries.

The gateway still publishes intents and saved steps through small framework
Publication chunks. Even a short SQL mutation includes that coordination work;
these controls do not isolate its time from Table execution. Bulk ingress and
gateway-ledger publication remain separate optimization work. Final point, range,
full and empty read times cluster closely within each path in this small fixture.
This suggests that fixed gateway work dominates the remaining read cost; the
campaign does not isolate that work into individual authorization or setup stages.

| Path / case | Baseline p50 / p95, ms | Final p50 / p95, ms |
| --- | ---: | ---: | ---: |
| postgres_literal:point | 3,274.8 / 3,417.9 | 2,011.5 / 2,070.8 |
| postgres_literal:range | 4,170.3 / 4,485.4 | 2,028.8 / 2,082.4 |
| postgres_literal:full | 4,713.5 / 4,850.6 | 2,025.5 / 2,091.7 |
| postgres_literal:empty | 2,729.5 / 2,853.1 | 1,990.0 / 2,034.1 |
| postgres_literal:limit_zero | 2,665.1 / 2,789.2 | 1,980.3 / 2,059.0 |
| postgres_prepared:point | 2,845.7 / 2,965.6 | 1,721.5 / 1,794.0 |
| postgres_prepared:range | 3,869.2 / 4,029.6 | 1,734.6 / 1,825.3 |
| postgres_prepared:full | 4,316.4 / 4,540.0 | 1,731.3 / 1,784.4 |
| postgres_prepared:empty | 2,359.7 / 2,456.0 | 1,689.8 / 1,762.4 |
| postgres_prepared:limit_zero | 2,311.6 / 2,437.5 | 1,702.4 / 1,774.5 |
| mysql_literal:point | 2,465.9 / 2,573.6 | 1,449.5 / 1,491.2 |
| mysql_literal:range | 3,431.9 / 3,596.5 | 1,432.6 / 1,534.5 |
| mysql_literal:full | 3,916.0 / 4,157.4 | 1,437.8 / 1,523.1 |
| mysql_literal:empty | 1,967.4 / 2,054.4 | 1,406.5 / 1,498.7 |
| mysql_literal:limit_zero | 1,951.1 / 2,037.7 | 1,399.8 / 1,471.1 |
| mysql_prepared:point | 3,475.3 / 3,611.2 | 2,168.0 / 2,253.8 |
| mysql_prepared:range | 4,503.0 / 4,641.0 | 2,142.4 / 2,237.0 |
| mysql_prepared:full | 4,973.1 / 5,121.3 | 2,158.9 / 2,248.0 |
| mysql_prepared:empty | 2,917.8 / 3,121.1 | 2,153.7 / 2,191.4 |
| mysql_prepared:limit_zero | 2,951.7 / 3,123.3 | 2,130.7 / 2,189.3 |
| postgres_literal:insert | 23,259.3 / — | 13,237.6 / — |
| postgres_literal:update | 22,308.6 / — | 12,815.6 / — |
| postgres_literal:delete | 20,559.0 / — | 12,807.8 / — |
| postgres_prepared:insert | 23,644.2 / — | 12,655.4 / — |
| postgres_prepared:update | 23,086.9 / — | 13,507.9 / — |
| postgres_prepared:delete | 21,626.8 / — | 12,592.2 / — |
| mysql_literal:insert | 23,141.8 / — | 13,032.7 / — |
| mysql_literal:update | 23,341.0 / — | 13,321.9 / — |
| mysql_literal:delete | 21,094.9 / — | 13,364.4 / — |
| mysql_prepared:insert | 24,459.2 / — | 13,382.7 / — |
| mysql_prepared:update | 22,819.8 / — | 13,466.2 / — |
| mysql_prepared:delete | 22,805.3 / — | 13,167.7 / — |

## Failed and intermediate experiments

All original failed and intermediate reports remain attributable in the manifest:

- The first baseline read harness used unsupported ORDER BY after its first point
  read. Its separate instrumented setup was interrupted to correct the query.
  The successful reruns use unordered queries and compare sorted copies afterward.
- The first baseline and foundation wire setups failed before measurement because
  benchmark metadata used the reserved TRANSIT_ settings prefix. The harness now
  uses STORAGE_FOUNDATION_BUILD_REVISION. Production configuration validation and
  deadlines were not relaxed.
- The successful `before-prefetch` controls are intermediate observations, not
  substituted for final results. Earlier physical-capacity setup timeouts and the
  passing ReleaseSafe ENOSPC schedule have their own
  [record](../../../verification/results/storage-foundation-capacity-2026-10-19.json).

The [proof ledger](../../../README.md) owns correctness/recovery schedules.
Measured publication/disclosure gains do not implement historical-schema binding,
branches, merge, persistent columnar layouts or large statement ingress. Clean CI
has separate source provenance; the PR records its exact committed revision.
