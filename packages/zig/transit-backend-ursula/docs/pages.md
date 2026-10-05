# Immutable pages

`PageStore` and `PackedPageStore` implement the
[core page interface](../../transit-core/docs/pages.md).
The native v1 node composes the packed mapping. Page persistence alone does not establish authority
validation or application computation.

Each store borrows a journal/client and owns a bounded decoded-page cache.
`PackedPageStore` uses least-recently-used replacement; `PageStore` uses FIFO. Evicting a slot never removes durable bytes. Zero slots disables caching;
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
fanout can cause substantial metadata and write amplification. Provider scaling requires separate measurement.

## Packed mapping

`PackedPageStore` appends immutable page records to one separate JSON journal
scoped by the authority's bucket and stream name. Bootstrap explicitly creates
that journal; loads never create missing history. A reference carries a digest
plus an opaque format-tagged record locator. Core page/catalog format 1 includes
the locator without interpreting Ursula coordinates. The adapter reads exactly
one record, verifies returned coordinates and checks the page digest.

Staging appends one immutable record and takes its locator from the verified
single-record acknowledgement. It does not predict a tail or compete for an
authority position. Independent node/maintenance candidates can interleave page
records without spurious staging conflicts. Missing/malformed acknowledgements
fail without a hidden retry or a usable locator; a caller's later retry may leave
a duplicate unreachable page, which remains retained. Only the separate,
conditional authority append publishes the root and fences concurrent changes.
Packing changes placement, not the commit boundary.

`stageMany` accepts at most eight immutable pages and sends a length-prefixed
provider batch. Each frame is an independent append. The adapter validates every
JSON acknowledgement, status and exact single-record coordinate before returning
any reference; concurrent writers may create gaps between coordinates. A lost,
partial or malformed acknowledgement fails the whole staging call without an
automatic retry. Accepted records remain unreachable until the authority commits
an enclosing root. Single-page and batched staging use the same format-1 locators.

Tree mutation batches use this operation for sibling pages. The encoded staging
buffer is bounded by eight times 32,770 bytes (a base64 JSON string for at most
24 KiB of compact bytes); upstream request framing owns a second
bounded copy. This primitive reduces provider requests and discarded path copies.
It does not change application mutation quotas, expand inline values or replace
the durable query result-publication protocol.

The page journal has no trimming, page GC or rotation yet. Root-journal trimming
in the proof cannot remove referenced page records. Access is privileged storage
infrastructure; application clients receive neither locators nor provider access.
The authority remains a conditional serial journal. Batching reduces page work
without establishing horizontal throughput.

`page.stage`, `page.stage_batch` and `page.load` emit storage spans through the journal's borrowed
observer. Expected absence during staging does not emit a failed-load warning.
Cache hits are excluded from network-operation counts. No keys, values, stream
names or page digests enter diagnostic events.

## Disk proof and measurement

```sh
just test::pages
just test::pages --keys 256 --cache 2
just test::pages --keys 256 --cache 2 --mutation-batch 1
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
Interleaved independent page writers each issue one append, obtain distinct
verified locators and reload their exact content without advancing the authority.
Competing root publication still admits exactly one successor.
`just test::growing-service` also drops an actual accepted page append's reply
and kills its staging worker before another request can pass. Authority stays
unchanged; a fresh worker stages again and completes from committed roots.
The orphan never becomes a discovered root or an implicit accepted operation.

The default applies mutations in groups of eight; `--mutation-batch 1` retains
the single-key control using the same binary and cache. It also exercises lost,
incomplete and failed per-frame replies after accepted provider appends; no
locators or authority publication escape those failures.

The default exercises packed format-1 pages with 64 KiB of values and two decoded
cache slots; the artifact reports their actual size. Evidence under
`.cache/verification/pages-<layout>-<hot|s3>-<keys>-<cache>-batch<1|8>.json` records revision,
dirty status, binary hash, tool/platform, elapsed time, cache statistics and page/stream creation counts. It also records page HTTP request attempts and
attempted page payload bytes, including unsuccessful staging attempts; these omit batch framing, root-journal/bootstrap HTTP work, headers and the
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

Historical measurements and their execution limits live in the
[proof ledger](../../../../tests/README.md).
The [workload priorities](../../../../docs/reference/workloads.md) require
measuring both Transit and provider memory. A fixed client cache does not bound
provider memory, metadata, request amplification or recovery costs.

## Cold-tier qualification

The ordinary proof deliberately disables Ursula cold storage and uses inline
snapshots. It establishes disk-WAL correctness; its retained payloads remain in
the provider's hot tier. A bounded Transit cache does not bound that provider
memory. `just test::pages-cold` is an explicit Linux x86_64 qualification using
an owned loopback MinIO process, built from pinned source in
[minio.nix](../../../../nix/minio.nix) and managed by
[cold_storage.py](../../../../tests/cold_storage.py). It uses synthetic temporary
credentials and a temporary disk directory, with no cloud account. Failure is
inconclusive; a missing provider executable is not a skipped success.

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

Core pages use the current compact `TPG1` encoding. The closed mapping stores
raw `application/octet-stream` bodies. The packed mapping uses canonical base64
JSON strings because the pinned provider exposes record coordinates for JSON
streams. Reads remove exactly the provider's final newline delimiter, then
reject whitespace, escapes, noncanonical base64 and old JSON page
objects; the envelope belongs to the adapter, not the core tree. Eight-entry
leaves and 32-child branches fit the 24 KiB binary bound; the packed envelope
fits 32,770 bytes. Attempted provider payload counters include the envelope. A cache slot owns one decoded page (16,952 bytes on the
measured 64-bit target), independent of the durable population. The current
contract definition rejects pre-cutover heads before reading their catalogs;
there is no old JSON decoder, conversion or empty-state fallback.
