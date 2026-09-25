# Immutable pages

`PageStore` and `PackedPageStore` implement the
[core page interface](../../transit-core/docs/pages.md).
It is an M10 primitive; the running node, client and Station still use the legacy
state profile. Page persistence alone does not qualify a growing authority.

Each store borrows a journal/client and owns a configurable FIFO cache of decoded
pages. Evicting a slot never removes durable bytes. Zero slots disables caching;
the 1,024-slot configuration guard bounds this implementation's resident cache,
not the number of retained pages. `residentBytes` reports cache allocation only;
HTTP buffers, parsing, tree stack and the process runtime require additional memory.

The original `PageStore` puts each page in a closed Ursula stream. Its location hashes the journal's
bucket/name and domain-separated page digest. Staging first reconciles an existing
stream, or creates it with its complete immutable body, then verifies closure,
complete read and content identity before returning success. Corrupt or mutable
content is an error, never an overwrite opportunity. Loading an absent page fails
and cannot create a stream. Retrying creation after a lost acknowledgement can
reconcile the same content; failure must never be interpreted as publication.

The adapter does not discover or authorize roots. A conditional append to the
authority journal must publish them; all candidate pages must be durable first.
Pages are retained without TTL or GC, including unreachable candidates. No page
deletion is authorized until retained-root and staging races are qualified.
This mapping is deliberately measurable: one stream per page and small tree
fanout can cause substantial metadata and write amplification. It is not yet a
recommended production layout or a claim of provider scaling.

## Packed mapping under qualification

`PackedPageStore` appends immutable page records to one separate JSON journal
scoped by the authority's bucket and stream name. Bootstrap explicitly creates
that journal; loads never create missing history. A reference carries a digest
plus an opaque format-tagged record locator. Core page/catalog format 2 includes
the locator without interpreting Ursula coordinates. The adapter reads exactly
one record, verifies returned coordinates and checks the page digest.

Staging conditionally appends against a cached verified tail. Conflicts or lost
acknowledgements invalidate that cached tail and return an error; they do not
silently retry or publish a root. A caller's later retry may leave a duplicate
unreachable page, which remains retained. Only the separate authority decision
publishes the new root. Packing changes placement, not the commit boundary.

The page journal has no trimming, page GC or rotation yet. Root-journal trimming
in the proof cannot remove referenced page records. Access is privileged storage
infrastructure; application clients receive neither locators nor provider access.
This mapping still serializes page appends and retains path copies, so fewer
streams alone do not qualify production scale or horizontal throughput.

`page.stage` and `page.load` emit storage spans through the journal's borrowed
observer. Expected absence during staging does not emit a failed-load warning.
Cache hits are excluded from network-operation counts. No keys, values, stream
names or page digests enter diagnostic events.

## Disk proof and measurement

```sh
just test::pages
just test::pages --keys 256 --cache 2
just test::pages --keys 256 --cache 16
just test::pages --layout closed --keys 64 --cache 2
just test::pages-cold --keys 1024 --cache 2
```

The proof creates owned disk-backed Ursula, publishes two competing-checked root
versions, stages an unpublished candidate, and deletes keys only in the later
root. It verifies both retained versions across SIGKILL/restart with a cold cache.
It then publishes a root-only snapshot, trims the root journal, restarts again
and recovers the same views without creating any page streams. This isolates
page/root persistence; it does not claim process progress or authorization is
yet included in that publication.

The default exercises packed format-2 pages with 64 KiB of values and two decoded
cache slots; the artifact reports their actual size. The original format-1 cache
used 17,032 bytes. Evidence under
`.cache/verification/pages-<layout>-<hot|s3>-<keys>-<cache>.json` records revision,
dirty status, binary hash, tool/platform, elapsed time, cache statistics and page/stream creation counts. It also records page HTTP request attempts and
attempted page payload bytes; these omit root-journal/bootstrap HTTP work, headers and the
provider's internal replication/WAL amplification. Linux `/proc` sampling every
20 ms reports both client and Ursula process metrics. RSS is the kernel's process
high-water mark; thread/FD counts are sampled peaks that can miss short spikes.
Unsupported or unavailable metrics remain null with an explicit sample count,
never zero resource use. Provider startup/recovery precedes the measured client
phase, but its memory high-water mark includes that work.
WAL file bytes are logical file lengths sampled after each phase, not allocated
blocks or a measurement of live application bytes. Exceptions and timeouts retain
`inconclusive` status. The proof has a per-phase deadline, configurable with
`--timeout`, and kills/joins its owned child on failure.

An initial **format-1 closed-stream** Debug run with 256 keys retained 256 KiB of values and produced 1,947
page streams across insertion, deletion and orphan staging. Two cache slots
took 13.38 s to write and 5.32 s to recover/verify all retained values; 16 slots
took 8.22 s and 1.60 s respectively. Sampled child RSS was about 8.5–8.7 MiB.
The WAL occupied about 4.27 MiB after restart in both cases. These are local
primitive measurements (artifacts `pages-256-2.json` and `pages-256-16.json`),
including verification reads, not startup latency or service benchmarks.
They show cache sensitivity and storage amplification that require attention
before claiming an efficient growing service.

A subsequent fixed two-page-cache run measured the provider as well:

| Retained keys (1 KiB values) | Created page streams | Page HTTP requests in write phase | Client peak RSS, write | Ursula peak RSS, write | Ursula peak RSS after restart/verification |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 376 | 2,955 | 8,684 KiB | 49,244 KiB | 48,648 KiB |
| 256 | 1,947 | 15,489 | 8,792 KiB | 64,528 KiB | 59,412 KiB |
| 1,024 | 10,059 | 83,979 | 8,972 KiB | 602,504 KiB | 1,138,952 KiB |

These single local Debug runs include insertions, half-key deletion, unreachable
staging and verification reads. They are not per-insert costs or throughput SLOs.
At 1,024 keys the write phase took 74.11 seconds, and recovery plus full retained
value verification took 31.46 seconds; WAL file lengths after restart totaled
178,186,090 bytes for 1 MiB of original logical values. All persistence assertions
passed. The provider growth and amplification **do not pass efficient storage
qualification**. This mapping needs investigation or replacement before service
scale claims. The measurements alone do not identify an upstream defect or
separate stream metadata from snapshot/WAL and request allocation costs.

The packed format-2 mapping passed the same 1,024-key persistence phases with
one page stream, 31,932 write-phase page HTTP requests, 43.37 seconds for write/
verification and 18.22 seconds for restart/full-value verification. That run still
reached 1,141,696 KiB provider RSS during recovery, with 172,174,210 WAL file bytes.
Packing reduced requests but did not solve recovery memory in this fixture.
Both runs used `storage.cold.backend = "none"` and inline provider snapshots:
they do not qualify the provider's cold-tier growth behavior. Cold storage and
snapshot configuration need separate measurements before selecting a scale profile.

The [Rey workload model](../../../../docs/workloads/REY.md) motivates measuring
the whole storage boundary, including Ursula's memory and stream metadata. A
fixed client cache is not evidence that provider memory stays fixed as retained
pages grow. This primitive mapping must pass those growth/amplification gates
before any recommendation for bulk capture or long-lived large Tables.

## Cold-tier qualification

The ordinary proof deliberately disables Ursula cold storage and uses inline
snapshots. It establishes disk-WAL correctness; its retained payloads remain in
the provider's hot tier. A bounded Transit cache does not bound that provider
memory. `just test::pages-cold` is an explicit Linux/Docker qualification using
an owned loopback MinIO container, pinned by digest in
[cold_storage.py](../../../../tests/cold_storage.py). It uses synthetic temporary
credentials and a temporary disk directory, with no cloud account. Failure is
inconclusive; missing Docker is not a skipped success.

This profile configures Ursula's S3 cold tier with 256 KiB flushes, an 8 MiB
per-group hot budget, an 8 MiB read cache and S3 snapshots. The evidence records
Ursula and MinIO process peaks separately, plus WAL and object-store file lengths.
Configured data/cache budgets do not bound whole-process RSS: allocator, indexes,
queues and recovery need measurement too. Restart currently interrupts Ursula;
it does not simulate an object-store crash, network partition or distributed S3
replication. The pinned MinIO fixture is test infrastructure, not a deployment
recommendation or an additional authority.

The first packed 1,024-key S3 run passed all four persistence phases. Write/full
verification took 42.27 seconds; restart/full verification took 15.99 seconds.
Ursula peaked at 86,436 KiB during write and 66,156 KiB after restart, compared
with 1,141,696 KiB recovery RSS in the hot-only packed run. MinIO peaked at
234,244 KiB during that recovery phase (its process spans all phases), and its
file lengths totaled 18,620,141 bytes. WAL lengths after restart totaled
3,594,617 bytes. These are single local Debug runs, not controlled performance
comparisons or a bound for arbitrary dataset sizes. The unchanged roughly 32,000
write-phase page requests still require amplification work. The S3 fixture now
also requires persisted Ursula chunk objects; startup metadata alone cannot pass.
