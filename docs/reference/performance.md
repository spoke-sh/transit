# Performance characteristics and improvement plan

The console executes fresh interactive queries through leased native snapshots
and client-side Fuze. It avoids the durable upload/result-publication workflow
whose measured costs motivated this change. This page records local measurements
from 2026-09-29, their limits and the remaining storage improvements.

Interactive `.timing` separates local `compile`, snapshot `open`, `fetch`
(including execution and current validation), `render` and snapshot `release`.
The instrumented fixture also records cumulative upstream elapsed nanoseconds
by native operation and principal. Those durations include provider/queue time
and proxy overhead; they are not independent CPU measurements.

## Interactive execution measurements

The default local server returns the empty typed Table in **121–146 ms** across
eight sequential queries (SELECT, COUNT and both output formats). The first
SELECT takes 131 ms; first stdout appears at 128 ms. These ReleaseSafe samples
use the default eight-page cache and background workers, without transport
proxies. Sampled console RSS is about 15 MB and node RSS about 10 MB. The earlier
14.014-second durable control below is historical evidence, not a simultaneous
comparison of otherwise identical revisions.

An isolated native-node fixture also checks populated sources. It uses a
64-page cache, disk Ursula and MinIO, with a native HTTP counting proxy and no
query workers. Times include CLI startup and verified output:

| Source | Rows | First stdout | Completion | Native requests | Durable updates |
| --- | ---: | ---: | ---: | ---: | ---: |
| Table | 41 | 50–60 ms | 147–157 ms | 39 | 0 |
| KV | 41 | 48–53 ms | 152–159 ms | 38 | 0 |
| Document list | 12 | 384–415 ms | 439–469 ms | 82 | 0 |

Each statement opens a new leased cut and releases it. Query execution uses
bounded native Arrow batches. A session-local cache holds at most 64 immutable
point reads; permissions, source policy and leases are checked again before
output. The same Document fixture previously needed 733 native reads and about
3.8 seconds without that cache. Batched current metadata reads and descriptor
reuse reduce the Table fixture from 75 requests to 39.

The final default-server run, after two explicit durable queries had added
history, returns eight uninstrumented empty-query samples in **159–196 ms**.
It uses the default eight-page cache and background workers, with no concurrent
qualification. A separate instrumented fresh fixture attributes 14 native reads
to the console and 10 to background callers during the query, with zero durable
updates and 188 provider attempts including background work. Its three-second
idle window has 108 native and 553 provider attempts. Background polling remains
a measurable cost even when SELECT itself is read-only.

After the storage batches, the 12-row Document fixture returns in about
318–344 ms with the same 82 native reads; `LIMIT 0` uses 26 reads and takes about
82 ms. Document provisioning remains a separate multi-minute durable workload.

These are a few local observations on a shared host, not percentiles or an
interactive latency guarantee. Fixture provisioning is excluded from query
latency. Document provisioning remains expensive; removing durable work from
SELECT does not make application writes or durable publication inexpensive.

After the storage changes, a 257-row Table fixture with 128 prior unrelated
durable operations uses 174 native requests for a full scan. Primary-key equality,
a three-row tail range and a three-row upper range each use **14 requests**;
point-query completion is about 43 ms in that run. A full scan still reads bounded
pages and completes in roughly 0.65 seconds. `LIMIT 0` validates policy and the
snapshot without traversing source data (12 requests). This proxy-instrumented
fixture ran during qualification; its request counts are the useful comparison.

## Historical durable-query measurements

The earlier workload is `SELECT * FROM items;` over an empty Table through the console's
unified v2 captured-query path. Each controlled first query uses a fresh local
disk-backed Ursula installation with MinIO cold storage. The optimized controls
use the same ReleaseSafe binaries, with the server's 100 ms worker/courier idle
interval and either eight or 64 resident cache pages.

| Observation | Empty-query elapsed time | Scope |
| --- | ---: | --- |
| User-reported console trace | 86.899 s | Existing installation; running node confirmed to be a Debug binary |
| Optimized control, eight cache pages | 14.014 s | Fresh fixture; no diagnostic instrumentation |
| Optimized control, 64 cache pages | 5.687 s | Same binaries and polling interval; fixture-only cache override |
| Whole-node diagnostic profile, eight pages | 12.958 s | Instrumented node; separate fresh fixture |

Render time is below 1 ms in both uninstrumented optimized controls. Node CPU
time is 6.12 s with eight cache pages and 1.91 s with 64. Cache tuning helps,
but this query still takes seconds after the increase. Rebuilding only a client
does not replace a running Debug server.

These are individual local samples on a shared developer host, not latency
percentiles, throughput limits or deployment SLOs. The existing developer server
remained running; no build or other qualification ran concurrently with the
optimized controls. The user trace and controlled fixtures differ in build and
history and are not a controlled speedup comparison. Detailed attribution below
covers the empty Table, not populated scans, KV or Document latency. The
[proof ledger](../../tests/README.md#native-query-latency-whole-node-attribution)
records binary/probe provenance, controls and verification limits.

## Where the time and requests go

In the user's trace, prepare takes 195 ms, compile 465 ms, submit 18,968 ms,
wait 64,700 ms, fetch 2,555 ms, render 1 ms and persistence 15 ms. These are
client phases, not independent engine components. Submission includes advancing
durable upload inputs; waiting includes source capture, result publication and
reply delivery. See [console timing](../../apps/transit-cli/docs/console.md).

The instrumented optimized profile attributes the same execution path:

| Metric | Observation | Meaning |
| --- | ---: | --- |
| Native requests | 1,120 | 1,069 reads and 51 durable updates |
| Read handlers | 8.63 s | Includes authorization, decoding and their storage I/O |
| Update handlers | 3.94 s | Includes validation and their storage I/O |
| Page provider I/O | 9.16 s | Overlaps the handler times; do not add it to them |
| Page cache misses / hits | 31,466 / 22,815 | About 58% of 54,281 loads miss |
| Staged immutable pages | 1,471 | About 28.8 per durable update in this sample |
| Attempted encoded page payload | 1,836,481 bytes | Excludes journal, transport, provider WAL and replication overhead |
| Source-worker step spans / native-call spans | 8.756 s / 8.701 s | About 55 ms remains for local bookkeeping and computation |

The final row is not an isolated Fuze CPU benchmark. Attempted page bytes are
not a measurement of total retained disk growth. Likewise, dividing these times
into a rate does not establish sustainable offered-load throughput.

### Why a SELECT writes durable state

The explicitly selected durable execution mode uploads a plan, records its call, captures a source version,
stages Arrow segments and publishes a complete manifest. Empty results still
carry schema and completion evidence. The measured 51 updates comprise four
console sends, 17 durable view opens, 17 worker turns and 13 deliveries. Query
bookkeeping writes leave the source rows unchanged.

The requester takes four upload turns and one completion turn; the source takes
12 capture/publication turns. Publication values are 256-byte chunks, with four
mutations per turn; capture stages at most two result chunks per turn. Source
page/candidate reconstruction and repeated policy reads accompany continuations.
This supports exact durable recovery but is costly for a short interactive read.
These turn counts are an observation, not a minimum imposed by durability.

Each update also maintains receipts and protocol indexes. The current immutable
catalog tree holds four entries per leaf and five children per branch; successive
key updates copy paths. The packed backend performs a provider request for each
page miss or staged page. This multiplies small logical operations into many
reads and writes. Increasing cache capacity leaves the measured 1,471 staged
pages unchanged.

### Snapshots, checkpoints and indexes already exist

| Resource or mechanism | Current structure | What it does not supply |
| --- | --- | --- |
| Growing KV | Immutable ordered catalog roots and retained versions | A SQL result cache or efficient bulk columnar scan |
| Table | Schema-aware rows over the ordered KV index | Persistent Arrow row groups, general secondary indexes or scan pruning |
| Document | Accepted revision roots, immutable ordered indexes and checkpoints preserving causal/conflict evidence | Arbitrary full-text/vector search or analytical projections |
| Storage checkpoint | Validated recovery basis, with retained tail where required | Removal of query upload, capture and result-publication work |

An ordinary authority read loads pages from the latest accepted catalog root;
it does not replay the entire history for every query. A read snapshot chooses
a data version, a checkpoint preserves recovery evidence, and a captured query
records its own progress and answer. Improving one does not automatically remove
the cost of the others. See [storage](storage.md), [Tables](tables.md) and
[Documents](documents.md).

### Controls that constrain the diagnosis

At eight pages, diagnostic LRU replacement measured 12.50 s and 27,397 page
misses; bounded catalog range scans measured 11.99 s and 24,548 misses. Neither
experiment resolved the multi-second latency on its own. Bounded range scans and
LRU replacement are now implemented with the separate storage qualification below.
Faster 20 ms polling measured 15.52 s and 36,604 misses. Slower 200 ms polling
measured 15.67 s. All are separate single samples with host variance.

Idle work matters too: at the default 100 ms interval, three seconds of idle time
used 0.24 node CPU seconds and issued 114 native requests with 924 page misses.
At 20 ms, those became 0.97 CPU seconds, 467 requests and 3,832 misses. Faster
polling increases load; slower polling can delay completion. Neither is a
substitute for reducing work or introducing appropriate wake-ups.

## Bounded storage batches

The growing authority batches one turn's resource-entry changes before publishing
its final catalog root. Shared paths are copied once. The packed backend sends
bounded groups of immutable sibling pages, checks every provider acknowledgement
and returns no references if any frame is uncertain. This retains page format 2,
old roots and the existing authority commit. Namespace scans stop at their upper
boundary; the verified packed-page cache uses LRU replacement.

A ReleaseSafe storage-primitive comparison uses the same binary, two cache slots,
256 keys with 1 KiB values, half-key deletion, retained-root verification and
unpublished candidates:

| Write-phase metric | Single-key updates | Eight-key batches |
| --- | ---: | ---: |
| Staged immutable pages | 1,960 | 330 |
| Page-provider request attempts | 5,820 | 2,617 |
| Encoded page payload attempted | 4,099,816 bytes | 1,252,826 bytes |
| Sampled client peak RSS | 3,068 KiB | 3,904 KiB |

Both paths pass disk restart and root checkpoint/trim, including old values and
deleted-key absence. Accepted appends with lost, incomplete or failed per-frame
acknowledgements cannot publish authority. A separate 1,024-key cold-storage run
passes with two resident pages. These counts include verification and candidate
staging; they are not application throughput or total physical write amplification.
Other qualification ran concurrently, so elapsed times are not used here.

Application turn quotas, inline-value limits and durable result-publication
chunks are unchanged. Bulk page staging is a backend primitive, not an application
blob upload API. Persistent columnar Table blocks and larger application payload
publication remain separate storage work.

## Planned improvements

These priorities implement the [workload model](workloads.md). Interactive
snapshots and bounded page/read batching are implemented. The remaining payload
and read-structure changes below remain planned. No dates or speedups are promised.

| Priority | Intended change | Required evidence |
| --- | --- | --- |
| Interactive sessions | Fresh snapshot per SELECT, bounded Arrow streaming, cancel on exit, server-enforced cleanup after disconnect; retain explicit durable jobs separately | First batch/completion and cancellation tails, revocation after a prefix, complete/incomplete framing, bounded pins and memory |
| Shared read/write amplification | Implemented: bounded native metadata reads, tree mutation/page staging batches, verified LRU pages and snapshot-local point caching | Native/provider requests, staged bytes and pages per operation; unchanged atomicity, permission and retry behavior |
| Application bulk immutable publication | Persist bounded application blocks before atomic publication of verified references and source progress | Uncertain commits, orphan handling, payload availability, quotas, recovery and actual physical write amplification |
| Workload-specific read structures | KV point/range access, persistent columnar Table blocks and block-statistics pruning, Document path/sequence and versioned projections | Selective/full scans, retained data beyond cache, source freshness, rebuild cost and concurrent writes |

The implemented interactive lifecycle is documented in
[query sessions](queries.md#interactive-sessions) and the
[neutral contract](../../contracts/INTERACTIVE_QUERY_V1.md), including cancellation,
leases, current-policy checks and resource accounting. The append-only page
profile permits volatile snapshot pins; physical reclamation must account for
them before being enabled. Explicit durable jobs retain their separate contract.

Batching must preserve the final atomic publication boundary. New tree layouts
require explicit format compatibility. Fuze and applications stay outside raw
provider access; no upstream database becomes a runtime dependency. Storage
changes benefit both sessions and durable jobs, while authority partitioning
needs its own ordering and fencing design.

## Reproduce and compare

From the repository's pinned development environment:

```sh
nix develop
just test::console-latency --single
just test::console-latency --single --resident-pages 64
just test::console-latency --single --worker-interval-ms 200
just test::console-latency --single --repeat 3 --age-queries 5
just test::console-latency --single --instrument
just test::console-latency --single --execution durable
just test::interactive-query
just test::interactive-query --source table --rows 257 --age 128
just test::interactive-query --source table --resident-pages 0
just test::pages --keys 256 --cache 2 --mutation-batch 1
just test::pages --keys 256 --cache 2 --mutation-batch 8
just test::pages-cold --keys 1024 --cache 2
```

The runner reports first stdout byte, completion, sampled console RSS (20 ms
sampling), node CPU, sampled node RSS and executable hashes. Repetitions share an installation;
`--age-queries` uses explicit durable execution to add completed query history before measurement. A first query
is post-bootstrap, not a cold OS or provider cache. `--resident-pages 0` disables
the native immutable-page cache without flushing the operating system.

`--instrument` inserts owned loopback proxies and counts native attempts by
operation and principal, plus provider methods and request/response body bytes.
It reports a separate three-second idle interval. These are transport attempts,
not unique durable commits or retained disk bytes. Proxy overhead can alter
polling and retries substantially: compare these runs separately from ordinary
elapsed-time measurements. No payloads or credentials are logged.

The populated-source task reports native requests and checks distinct session IDs,
completion framing, cancellation and revocation after a prefix. `--age` adds
unrelated durable operations before querying; it does not reuse a query session.

The tasks build ReleaseSafe binaries into its own cache directory, freezes their
hashes, creates an owned local fixture, checks the empty result and joins its
children. Overrides apply only to that fixture. This is a local diagnostic task,
not a request to reconfigure or reinitialize a running installation.

Compare candidate changes independently with the same binaries, source semantics
and hardware. Cover empty and populated sources; KV point/range reads, Table
selective/full scans and Document path/list/text reads; cold/warm caches; retained
data larger than memory; aged query history; concurrent writes and independently
offered load. Report p50/p95/p99 only from enough samples under stated conditions.
Include native calls, durable decisions, provider requests, bytes staged/retained,
node/provider memory, time to first batch, completion and source freshness.

Recovery, current revocation, cancellation, expiry, source changes and uncertain
commits belong in the same evaluation. Durable-job recovery remains a separate
requirement. A fast read that skips these boundaries does not qualify the design.
