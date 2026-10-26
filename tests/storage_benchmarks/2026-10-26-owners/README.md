# Paired disk-backed owner measurements

The [raw report](samples.json.gz) completes 768 verified samples: 24 arms, one
discarded warmup and 31 observations per arm. It compares full/range reads and
checkpoint recovery through the actual Table and native local owners. See the
[method and reproduction command](../../storage_benchmark.md) for fixture values,
cache conditioning, timers, allocation boundaries and independent value checks.

## Source and environment

The frozen ReleaseSafe binary was built against production revision
`76ec1587f8095483cbbb2fc8e48ca14b55baa40a` with the then-uncommitted harness.
The report deliberately retains `dirty: true`. Harness commit `b3577e39c`
contains the identical probe and driver; its production `apps/`, `packages/`
and lockfile have no changes from that revision. Later projection and candidate
filtering changes are outside this measurement. Source hashes were checked
against that commit when archiving the result.

| Identity | SHA-256 |
| --- | --- |
| Frozen executable | `c0f8b56dced5f7c5524cf78a9a6a9a92721c58f2cece33cba6ce9f84a8e3ec99` |
| Probe | `451dd29b2852a2cc1ba079154ea141df70d32429fb0770cf6d0cbca73c4ee73e` |
| Driver | `96d844eaf7ee7ccf445e25ae1a4e15b4e9af810f11406ba8070983f6baacc877` |
| Lockfile | `865faed173c5a710f77c231ce13c427bfe9eeaf3900e7edc7fa7e9d6233b1264` |
| Uncompressed report | `e5df1521b4fd1043a31709f66ee0bd376f24f250b89050db82dfbfb3bd393dcc` |

The host runs Linux 6.17.0-41, glibc 2.42, on an AMD Ryzen Threadripper 3960X.
Zig is `0.17.0-dev.2267+48abf1a34`; children use CPU 0 and a 2 GiB address-space
limit. The filesystem reports the `ext2/ext3` family. Other checks and workloads
ran on this shared host, including repository checks and part of a direct-service
proof. Affinity and alternating arm order do not remove that contention. Every
sample records host load and whole-child resource usage.

## Read and recovery observations

Times below are milliseconds, median / nearest-rank p95. Each cell contains 31
observations. Cold means verified eviction of fixture file pages at process
entry; physical open and recovery can warm pages before the read phase.

| Fixture and phase | Warm baseline | Warm checkpoint | Cold baseline | Cold checkpoint |
| --- | ---: | ---: | ---: | ---: |
| Table 128, logical recovery before scan | 1.81 / 2.68 | 0.96 / 1.85 | 3.38 / 4.81 | 2.69 / 3.75 |
| Table 1,024, logical recovery before scan | 8.21 / 12.37 | 0.92 / 1.76 | 31.17 / 57.67 | 31.40 / 54.00 |
| Table 1,024, complete scan | 621.72 / 645.94 | 618.18 / 676.97 | 1,675.38 / 3,059.07 | 1,730.13 / 2,997.88 |
| Table 1,024, four-row range | 11.89 / 16.33 | 12.28 / 16.15 | 68.00 / 122.30 | 70.18 / 130.12 |
| Native 64, physical open | 131.31 / 478.29 | 127.31 / 396.05 | 108.36 / 157.58 | 142.93 / 347.78 |
| Native 64, logical recovery | 5.69 / 8.35 | 5.67 / 9.27 | 29.23 / 67.00 | 24.27 / 56.88 |
| Native 64, complete KV/block reads | 1,354.23 / 1,937.67 | 1,374.70 / 2,378.99 | 1,651.03 / 2,351.40 | 1,650.38 / 2,537.97 |

The Table checkpoint reduces logical replay from 65 records to one, and recovery
backing allocations from 270 to 17. Startup still validates 65 baseline or 66
checkpoint WAL frames. Cold recovery includes immutable index/root validation;
this matrix does not show a consistent cold recovery latency improvement.

The same-snapshot range checks the same four requested keys and payloads as the
full scan, while the full scan independently verifies every visited row. For
1,024 rows, measured read counters are identical across checkpoint variants:

| Owner read counter | Complete scan | Four-row range |
| --- | ---: | ---: |
| Segment opens / decoded groups | 64 | 2 |
| Segment ranges | 384 | 12 |
| Segment payload bytes | 1,310,400 | 40,950 |
| All object payload bytes | 6,355,678 | 140,341 |
| Immutable index cache misses | 4,225 | 70 |
| Backing allocations | 3,008 | 44 |
| Peak tracked live bytes | 2,173,423 | 2,171,188 |

The native checkpoint changes the accepted history floor from zero to 199.
Both native fixtures fit in a single WAL segment, so the straddling segment
remains: startup validates 199 baseline or 200 checkpoint frames. Neither
compaction nor object collection runs. Native reads make 20,176 object requests
and request 15,346,453 payload bytes for 64 values/blocks with one resident index
page, identically in both arms. The checkpoint provides no measured reduction
in those read costs. Repeated signed authorization and index traversal are
included; attributing their individual CPU costs needs further measurement.

## Memory, disk and scope

The largest executable peak RSS is 8,968 KiB for Table and 6,868 KiB for native
samples. These are observed process peaks, not enforced RSS ceilings. The one
resident index page and 128 KiB segment/decode allowances do not include result
pages, operation scratch, stack or all process allocations. In particular the
Table read's tracked peak is about 2.17 MB despite those smaller cache limits.

The 1,024-row baseline Table has 11,681 files, 5,923,983 logical bytes and
37,433,344 allocated bytes. The native 64-turn baseline has 11,736 files,
5,826,704 logical bytes and 39,743,488 allocated bytes. Checkpoint variants add
metadata; this fixture does not demonstrate disk-space reclamation. Inventory
hashes and allocated byte counts are retained for all eight fixtures and checked
unchanged after sampling. Tiny immutable files and repeated index traversal
remain visible costs, not hidden behind segment-only counters.

All value/digest, completion, phase, non-publication, checkpoint/replay,
repetition and cache-residency checks pass. Archiving reruns every sample's
independent value validator and recomputes all 24 summaries. The report has no
p99 estimate or confidence interval. Counters exclude checksum/descriptor and
filesystem metadata I/O; child resource counters have their own broader scope.
Setup ingestion and checkpoint operations are single observations, so they do
not qualify ingestion/commit percentiles. The data exceed owner caches, not
host RAM. This is neither an installed SQL measurement nor final clean-tree
qualification of later code.
