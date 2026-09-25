# Immutable pages

`PageStore` implements the [core page interface](../../transit-core/docs/pages.md).
It is an M10 primitive; the running node, client and Station still use the legacy
state profile. Page persistence alone does not qualify a growing authority.

The store borrows a journal/client and owns a configurable FIFO cache of decoded
pages. Evicting a slot never removes durable bytes. Zero slots disables caching;
the 1,024-slot configuration guard bounds this implementation's resident cache,
not the number of retained pages. `residentBytes` reports cache allocation only;
HTTP buffers, parsing, tree stack and the process runtime require additional memory.

Each page occupies a closed Ursula stream. Its location hashes the journal's
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

`page.stage` and `page.load` emit storage spans through the journal's borrowed
observer. Expected absence during staging does not emit a failed-load warning.
Cache hits are excluded from network-operation counts. No keys, values, stream
names or page digests enter diagnostic events.

## Disk proof and measurement

```sh
just test::pages
just test::pages --keys 256 --cache 2
just test::pages --keys 256 --cache 16
```

The proof creates owned disk-backed Ursula, publishes two competing-checked root
versions, stages an unpublished candidate, and deletes keys only in the later
root. It verifies both retained versions across SIGKILL/restart with a cold cache.
It then publishes a root-only snapshot, trims the root journal, restarts again
and recovers the same views without creating any page streams. This isolates
page/root persistence; it does not claim process progress or authorization is
yet included in that publication.

The default retains 64 KiB of values with two decoded cache slots (17,032 bytes).
Evidence under `.cache/verification/pages-<keys>-<cache>.json` records revision,
dirty status, binary hash, tool/platform, elapsed time, cache statistics and page
creation counts. Linux `/proc` sampling every 20 ms reports peak RSS, threads and
file descriptors; short peaks can be missed and other systems leave these zero.
WAL file bytes are logical file lengths sampled after each phase, not allocated
blocks or a measurement of live application bytes. Exceptions and timeouts retain
`inconclusive` status. The proof has a per-phase deadline, configurable with
`--timeout`, and kills/joins its owned child on failure.

An initial Debug run with 256 keys retained 256 KiB of values and produced 1,947
page streams across insertion, deletion and orphan staging. Two cache slots
took 13.38 s to write and 5.32 s to recover/verify all retained values; 16 slots
took 8.22 s and 1.60 s respectively. Sampled child RSS was about 8.5–8.7 MiB.
The WAL occupied about 4.27 MiB after restart in both cases. These are local
primitive measurements (artifacts `pages-256-2.json` and `pages-256-16.json`),
including verification reads, not startup latency or service benchmarks.
They show cache sensitivity and storage amplification that require attention
before claiming an efficient growing service.
