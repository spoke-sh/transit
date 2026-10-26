# Disk-backed ingestion and durable acceptance measurements

The [raw report](samples.json.gz) completes **384 verified samples**: twelve
arms, one discarded warmup and 31 observations per arm. Each write is followed
by fresh-process readback of all original and new values. Independent counts,
sums, payload digests, accepted positions, original Table receipts and retained
snapshot size pass; readback publishes no work. The
[method](../../storage_benchmark.md#ingestion-and-commit-measurement)
defines cache conditioning and the distinct owner timers.

## Source and environment

The run starts on clean commit
`e7334f03e6c645f26de8186fc00e4aa8b7994f14`; its frozen executable contains the
aligned-column implementation from `040959617`. The intervening change affects
cache-conditioning drivers. Later history floors, compact Table evidence and
native policy-page reuse are outside this measurement. Source/driver hashes
match the recorded commit. Rebase changes do not relabel the archived revision.

| Identity | SHA-256 |
| --- | --- |
| Frozen executable | `89317d07dbe556d4c638a620b38c8d5600f885f9392c75d8805d1f971063f05b` |
| Probe | `ae7f66300d9769d74d0404edb7e92b9a86ffb4d733a49d53630b29ed66e4f1b9` |
| Ingestion driver | `f6fbf534b8be5da6d87ea94d7ea2f26fda6713cd5122c16bcdac8bbe8f8085e8` |
| Common driver | `0dfbd0d3795977afe2794e0d7f79d430d4431b0e92ec7e097249671cb937311b` |
| Lockfile | `865faed173c5a710f77c231ce13c427bfe9eeaf3900e7edc7fa7e9d6233b1264` |
| Uncompressed report | `6db06bf083304b1af752e06290036aa9448398f5dac29032dc6360cf1f623a5a` |

Zig is `0.17.0-dev.2267+48abf1a34`, Linux is 6.17.0-41 with glibc 2.42, and
the CPU is an AMD Ryzen Threadripper 3960X. Children use CPU 0 and a 2 GiB
address-space ceiling. The filesystem reports the `ext2/ext3` family. Payloads
are 1 KiB. Other repository checks, growth tests and workloads share the host;
recorded one-minute load ranges from 6.40 to 20.68. Arm groups run sequentially,
so size/cache differences also include changing host conditions. Only point/bulk
order alternates inside each Table group.

Every fixture's input file pages meet the exact requested `mincore` condition
before process entry, on the first conditioning attempt in this run. Startup
and recovery can warm them before the write phase. Cold does not mean a cold
device cache. Copies, conditioning, readback and inventory are outside write
timers. Archiving re-runs all 384 independent sample validators and recomputes
all twelve summaries. The earlier 231/384 conditioning failure remains a failed
run; it is not replaced by this separate result.

## Table writes

Each sample inserts the same sixteen rows after a retained 128- or 1,024-row
baseline, through point WAL payloads or a staged bulk segment. Times are
milliseconds, median / nearest-rank p95, with 31 observations in every cell.

| Baseline rows / cache | Point owner ingest | Bulk owner ingest | Point WAL append | Bulk WAL append |
| --- | ---: | ---: | ---: | ---: |
| 128 / warm | 264.74 / 285.42 | 287.56 / 304.42 | 3.09 / 3.78 | 2.86 / 3.61 |
| 128 / cold | 282.53 / 295.70 | 299.92 / 320.77 | 3.06 / 3.80 | 2.90 / 6.88 |
| 1,024 / warm | 473.68 / 1,188.34 | 486.99 / 641.78 | 3.33 / 5.90 | 2.98 / 4.39 |
| 1,024 / cold | 4,861.01 / 5,795.64 | 4,882.02 / 6,883.45 | 25.98 / 30.26 | 25.13 / 30.18 |

Bulk publication reduces the 1,024-row arm's WAL append from **23,552 bytes to
3,712 bytes**. Both append once with three measured WAL syncs. Total ingestion
does not improve consistently: staging the segment and immutable indexes remains
inside the owner timer. Final append medians are only about 0.5–1.2% of owner
ingest medians in these cases; reducing that append alone would not remove the
measured preparation work. This is not a concurrent group-commit experiment.

For the 1,024-row baseline, point staging makes 66 object puts and requests
65,587 payload bytes; bulk makes 67 puts and requests 86,177 bytes. Point and bulk
make 608 and 609 index misses respectively. Retained file growth is 117,199 and
118,493 logical bytes, or 745,472 and 757,760 allocated bytes, with 240 and 244
new files. Bulk's smaller WAL does not establish smaller total storage for this
batch. These counters exclude checksum/descriptor and filesystem metadata I/O.

The tracked write allocation peak is about 23.05 MB for point and 67.02 MB for
bulk across both fixture sizes. This includes reserved arena backing storage,
not just touched physical RAM. The largest observed Table executable RSS across
write/readback samples is 33,192 KiB. Cache allowance, tracked live allocation,
process virtual memory and RSS are distinct measures.

## Native turns

Each native sample admits one input, opens its view and prepares one turn with
one KV value, immutable block and recorded output. `prepare` includes the input
and view acceptances plus private staging; `commit` is the separate conditional
publication of the prepared turn. These phases do not represent the same work
as a sixteen-row Table insertion.

| Baseline turns / cache | Prepare median / p95 ms | Commit median / p95 ms |
| --- | ---: | ---: |
| 16 / warm | 3,885.20 / 5,250.65 | 29.00 / 30.94 |
| 16 / cold | 3,934.51 / 4,169.22 | 28.32 / 41.30 |
| 64 / warm | 573.20 / 2,547.17 | 3.09 / 15.12 |
| 64 / cold | 5,106.05 / 5,756.08 | 28.63 / 31.16 |

The faster warm 64-turn arm is not evidence that larger native state improves
latency: it runs later under different shared-host conditions. Preparation for
that arm stages 43 objects and makes 1,301 index misses; commit stages no objects
and appends one 2,304-byte frame with three WAL syncs. Later policy-page reuse
addresses some repeated reads but is not measured here. The largest observed
native executable RSS across write/readback is 7,900 KiB. Native filenames,
locations and serialized metadata contain fresh candidate identities, so exact
retained byte deltas can vary between otherwise equivalent samples.

## Limits

These observations qualify the recorded local owner paths and build only. They
do not measure installed SQL, concurrent writers, group commit, device power
loss, data larger than host RAM, or later-revision clean CI. There is no p99 or
confidence interval. Complete value verification establishes each sample's
result, not a latency guarantee. The separate
[growth attempt](../2026-10-26-growth/README.md) retains its native timeout and
does not become a pass because this smaller ingestion matrix completes.
