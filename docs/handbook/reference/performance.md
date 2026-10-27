# Performance characteristics and improvement plan

For planned CSV/JSONL workloads, see
[schema-on-demand comparisons](#schema-on-demand-measurements). The native
query measurements below do not measure file discovery or type inference.

The console executes through [server-managed SQL sessions](sql-sessions.md),
sharing Fuze execution with PostgreSQL and MySQL adapters. Ordinary interactive
reads use leased snapshots; explicitly captured queries pay for durable intent
and result publication. The [service account](../internals/service-interfaces.md#shared-sql-sessions-ownership-and-recovery)
describes the current session mechanism and its scoped measurement evidence.

This page preserves measurements from their stated source revisions. The older
interactive fixture below ran Fuze in the client and separated local compilation,
snapshot open/fetch, rendering and release. Those phase timings are not the
current server-managed console's timing contract. Instrumented upstream durations
include provider/queue time and proxy overhead; they are not independent CPU
measurements or latency promises for the current build.

See [declarative benchmarks](benchmarks.md) for synthetic compiler/execution
measurements and explicit TPC-C, TPC-E, TPC-H and TPC-DS coverage gaps.

## Column execution measurements

File and general Table queries use bounded typed columns. Resumable logical,
Unified and relational execution share the typed comparison/state kernels while
preserving their original work and publication boundaries. Defaults are portable
kernels, 256 compute rows, a 256 KiB physical buffer and one host worker. Explicit
AVX2 is guarded by CPU and OS capability checks. The [batch guide](../../../packages/zig/transit-fuze/docs/batches.md)
explains configuration, source/output ownership and the separate pool budget.

On the measured Linux x86_64 host, 4096-row owned-row pipelines take **0.084–0.199
times** the scalar reference's median time across hot types, eager predicates,
ordered SUM, UTF8 and nested COUNT. Reusing one bounded temporary-row allocation
and avoiding repeated operator interpretation contribute to this result. The
measurement includes validation, packing and result consumption; it excludes
file decoding, native storage/authorization and Arrow export. Tiny eight-row
pipelines cost **117–163 microseconds more per query** in these samples.

Real captured CSV/JSONL pipeline ratios are **0.945–1.085** at the defaults;
eight existing native controls are **0.979–1.035**. These do not show the synthetic
CPU gain carrying through complete source costs. Explicit AVX2 is slightly slower
than portable in the decoded comparison, and two/four workers show no consistent
whole-pipeline gain. Those measurements support the portable, one-worker defaults
on this host; they are not a universal hardware recommendation.

The [reproducible measurement account](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-10-13-pipelines/README.md)
identifies exact source/build/fixture hashes, paired repetitions, failed trials,
allocation boundaries and frozen numerical budgets. The host is shared; affinity
does not isolate frequency, caches or memory bandwidth. Hardware performance
counters are unavailable, so no cycle, instruction or bandwidth attribution is
claimed. Medians are not tail percentiles or service latency guarantees.

## Segment membership filter selectivity

Segment groups retain a fixed 64-bit, two-hash membership filter per indexed
column. A controlled range-reader experiment uses 256 int64 rows per group and
4, 16, 64 or 256 distinct values. Each arm asks about the same 2,048 absent values
inside the group's minimum/maximum bounds. The control disables only membership
pruning; page layout, integrity checks and predicate evaluation stay identical.

| Distinct values | Filter bits per distinct value | False positives | Payload bytes with filter / control |
| --- | ---: | ---: | ---: |
| 4 | 16 | 22 / 2,048 (1.07%) | 53,504 / 4,980,736 |
| 16 | 4 | 379 / 2,048 (18.51%) | 921,728 / 4,980,736 |
| 64 | 1 | 1,803 / 2,048 (88.04%) | 4,384,896 / 4,980,736 |
| 256 | 0.25 | 2,048 / 2,048 (100%) | 4,980,736 / 4,980,736 |

The fixed filter helps low-distinct-count groups and saturates on the 256-value
fixture. It is not an adaptive filter or a guaranteed false-positive bound.
Every present value also returns its independently expected multiplicity; no
false negative is observed. Counts measure requested payload ranges from an
in-memory immutable source, excluding the common footer reads. They do not
measure filesystem I/O or latency. The [executed account](../../history/qualification/storage.md#segment-membership-selectivity--2026-10-27)
records the source, controls and reproduction.

## Retained Table key-range measurements

A paired ReleaseSafe disk-owner matrix measures 1,024-row Table scans and a
four-row interval at the same retained snapshot. With warm fixture pages, the
baseline median / p95 read times are **621.72 / 645.94 ms** for a complete scan
and **11.89 / 16.33 ms** for the interval. With verified cold fixture pages at
process entry, they are **1,675.38 / 3,059.07 ms** and **68.00 / 122.30 ms**.
Each arm has 31 observations on a shared Linux Threadripper host, one resident
index page and separate 128 KiB encoded/decode limits. The interval opens two
of 64 segments and requests 40,950 segment bytes versus 1,310,400 for the scan.
Both verify the same selected values; the scan also verifies all visited rows.

In that matrix, a Table recovery checkpoint reduces logical replay from 65
records to one and warm logical recovery median from 8.21 to 0.92 ms. Physical
startup still validates the WAL. Cold logical recovery shows no consistent
latency improvement. A separate native 64-turn fixture preserves KV values,
blocks and process progress after checkpoint, with essentially unchanged read
costs: its history floor falls inside one retained WAL segment. No physical
space reclamation is demonstrated. Maximum observed executable RSS is 8,968 KiB
for Table and 6,868 KiB for native samples. These are observations, not limits.
The [complete measurement account and raw samples](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/storage_benchmarks/2026-10-26-owners/README.md)
identify source hashes, all phases, memory/I/O boundaries and contention. These
fixtures exceed owner caches, not host RAM; they do not measure installed SQL or
ingestion/commit percentiles.

The disk-backed Table owner can traverse complete primary keys within an
inclusive or exclusive interval on a retained snapshot. In a 512-row fixture
with eight immutable segments, a four-row interval crossing a segment boundary
reads two segments. A complete identity-ordered scan of the same snapshot
checks every row against its original key and 2,048-byte text payload.

| Observation | Four-row interval | Complete scan |
| --- | ---: | ---: |
| Segment bytes requested | 280,488 | 1,121,952 |
| Segment range requests | 10 | 40 |
| Immutable index-page cache misses | 70 | 2,109 |
| Decoded row groups | 2 | 8 |

Both paths start with newly opened disk owners, an empty segment cache and one
resident index page. Each cached decoded group uses less than 1 MiB of arena
backing allocations. Segment byte/request counts exclude index objects, retained
snapshot metadata and filesystem checksum reads. These are component I/O counts,
not physical device traffic, process RSS or installed SQL latency. The operating
system page cache is not cleared. SQL inequality predicates still use their
existing scan path; this measurement exercises the retained range operation.
The [proof ledger](../../history/qualification/storage.md#retained-table-cross-segment-range-control--2026-10-26)
records the fixture and reproduction command.

## Local ingestion and bounded growth measurements

A separate disk-owner matrix completes 384 verified write/readback samples,
including 31 observations per arm. At a 1,024-row baseline, inserting sixteen
1 KiB rows takes median / p95 **473.68 / 1,188.34 ms** through point ingestion
and **486.99 / 641.78 ms** through bulk ingestion with warm fixture pages.
Verified cold entry raises these to **4,861.01 / 5,795.64 ms** and
**4,882.02 / 6,883.45 ms**. Every sample verifies the complete original and new
values, receipt and retained snapshot in a fresh process.

Bulk ingestion reduces that batch's WAL bytes from 23,552 to 3,712, but total
staging bytes and latency do not improve consistently. Both paths append once
with three measured WAL syncs; final append medians are about 0.5–1.2% of total
owner ingestion medians in these fixtures. A native turn's preparation includes
input/view acceptance and private staging, so its timing is a separate workload.
The [ingestion account and raw observations](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/storage_benchmarks/2026-10-26-ingestion/README.md)
record both owners, exact source/build identities, allocation/RSS boundaries,
cache conditioning and shared-host contention. Later Table evidence and native
policy caching changes are outside this measurement; installed SQL and concurrent
group commit are not measured.

A [separate growth attempt](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/storage_benchmarks/2026-10-26-growth/README.md)
verifies 8,192 Table rows with 16 KiB values and 191,717,253 retained file bytes
under a 134,217,728-byte process address-space ceiling. Fresh-process cold readback
checks every value without changing storage. This exceeds the process ceiling,
not host RAM. The full growth run fails when native setup exceeds its unchanged
1,800-second timeout; completed Table observations do not establish native growth
or a complete growth-matrix pass.

## Table point-read decoding measurements

Point reads can retain one verified encoded row group and decode the requested
row under a separate memory allowance. In a disk-backed 512-row Table with
256-row groups and 2,048-byte text values, the selected and full-group readers
produce the same values and identities. The measurement uses one resident index
page and the pinned Debug build on Linux x86_64.

| Retained allocation | Selected point | Full-group scan |
| --- | ---: | ---: |
| Decoded arena backing bytes | 3,898 | 891,024 |
| Encoded page cache and directory | 530,562 | 0 |

The scan also uses a transient encoded page while decoding. The selected path's
peak decoded allocation is 3,898 bytes for this plain-text fixture; dictionary
entries, nested values and compressed-string validation can increase that peak.
Footer/index allocations, returned row copies, allocator overhead and process RSS
are outside this table. Both complete decoder arenas and selected scratch/output
are budgeted; the encoded cache has its own limit.

A cold point requests 563,420 segment bytes in five ranges. An adjacent point
requests no additional segment bytes. The complete same-root scan requests
1,093,934 bytes in seven ranges and checks all 512 original keys and payloads.
Current and retained-snapshot point reads succeed with a 16 KiB decoded budget;
full-group decoding refuses that budget. Selections still validate complete
pages, so reduced retained allocation does not establish lower CPU cost or
installed SQL latency. OS caches remain available. The
[proof ledger](../../history/qualification/storage.md#selected-table-segment-decoding--2026-10-26)
records the checks and reproduction command.

## Interactive execution measurements

In the recorded client-side execution fixture, the local server returns the
empty typed Table in **15–18 ms** across
eight sequential queries (SELECT, COUNT and both output formats), including CLI
startup. The first SELECT takes 17 ms, with first stdout at 15 ms. Console timing
reports 11–14 ms: local compilation rounds to zero, opening takes 8–10 ms, fetching
2–3 ms and rendering 0–1 ms. Final validation and release share the final fetch;
the separate release phase is zero in these samples.

These ReleaseSafe samples use the default eight-page cache, background workers
and no proxies or concurrent qualification. The same fixture before this round
of changes returned its first empty query in 91 ms. That is one baseline sample,
not a percentile or an isolated comparison of any one optimization. The earlier
user-reported 636 ms trace used a different installation and is not a controlled
speedup comparison.

Sampled console RSS is 13–16 MB and node RSS 23–24 MB, compared with about 10 MB
node RSS in the earlier sequential-listener fixture. The bounded concurrent
listener trades additional resident transport/task memory for connection reuse
and isolation from stalled peers. Sampling every 20 ms can miss short peaks.

An isolated native-node fixture checks populated sources using a 64-page cache,
disk Ursula and MinIO, a native counting proxy and no query workers:

| Query | Rows | Earlier native requests | Current native requests | Durable updates |
| --- | ---: | ---: | ---: | ---: |
| Table full scan | 41 | 39 | 8 | 0 |
| KV full scan | 41 | 38 | 8 | 0 |
| Table full scan after 128 unrelated operations | 257 | 174 | 39 | 0 |
| Table primary-key equality or three-row range | 1–3 | 14 | 3 | 0 |
| Document list full scan | 12 | 82 | 30 | 0 |
| Document `LIMIT 0` | 0 | 26 | 3 | 0 |

These counts include one capabilities request per new CLI process. A continuing
console reuses protocol support, while every statement still acquires its own
fresh cut. Table/KV scan reads prefetch at most 64 entries and 32 KiB; output
remains in eight-row Arrow batches with current checks before disclosure.
Document indexes acquire up to eight known immutable chunks together, preserving
descriptor, length, digest and commitment validation. Query compilation avoids
remote description and binding reads that snapshot acquisition already supplies.

The aged 257-row Table scan completes in 169–190 ms and the 12-row Document scan
in 106–171 ms in their proxy-instrumented runs. These overlapped qualification;
request counts are the useful comparison. Document provisioning remains a
separate multi-minute durable workload, excluded from query latency. Removing
durable work from SELECT does not make application writes inexpensive.

A separate instrumented default-server fixture attributes **three native reads**
to the console and one to a background caller during the empty query, with zero
durable updates and **11 provider attempts** including background work. The
previous interactive implementation used 14 console reads and 188 provider
attempts including its background work. Proxy overhead is separate from ordinary
elapsed time; these counts do not isolate the contribution of each change.

During three idle seconds, the new fixture observes **16 native and 60 provider
attempts**, versus 108 and 553 in the previous fixture. Uninstrumented idle node
CPU is 0.03 seconds versus 0.18 in this round's baseline. Worker and courier
polling backs off from 100 ms to one second and resets on activity. Newly queued
durable work can therefore wait for the next poll; interactive reads do not
wait for those workers. These measurements precede the bounded worker
notifications described with the mutation measurements below.

## Why the read path is cheaper

- Generic `snapshot_read` combines acquisition, initial data and current metadata,
  then combines final validation and release. Captured source data stays fixed;
  final authorization uses current state. Unrelated writes need not restart data
  acquisition. Changed grants, lifetimes or source policy still deny disclosure.
- Sixteen immutable catalog control records have a cache separate from scan pages.
  It is keyed by the exact catalog root and invalidated on root changes. Cached
  principal/grant bytes are inputs to authorization, never cached permission.
- The growing node and local gateway reuse bounded HTTP connections. Idle sockets
  retain no request admission, and body reads/response writes hold no authority
  lock. Four data and two control requests share a serialized engine; health and
  checked snapshot cleanup have reserved admission. This is not authority sharding
  or a per-principal fairness guarantee.
- Bounded native ranges and Document chunk batches reduce round trips without
  expanding Arrow batches, mutation budgets or retained collection limits.

[Request telemetry](observability.md) separates authority waiting, engine work and
page-cache access. The exact bounds and compatibility behavior belong to
[interactive sessions](queries.md#interactive-sessions), the
[growing listener](../../../apps/transit-node/docs/growing.md#public-surface-and-limits)
and [client transport](../../../packages/zig/transit-client/README.md#public-surface).

## Historical durable-query measurements

The earlier workload is `SELECT * FROM items;` over an empty Table through the console's
captured-query path. Each controlled first query uses a fresh local
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
[proof ledger](../../history/qualification/interfaces.md#native-query-latency-whole-node-attribution)
records binary/probe provenance, controls and verification limits.

## Where the time and requests go

In the user's trace, prepare takes 195 ms, compile 465 ms, submit 18,968 ms,
wait 64,700 ms, fetch 2,555 ms, render 1 ms and persistence 15 ms. These are
client phases, not independent engine components. Submission includes advancing
durable upload inputs; waiting includes source capture, result publication and
reply delivery. See [console timing](../../../apps/transit-cli/docs/console.md).

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

Each update also maintains receipts and protocol indexes. The measured revision used four entries per leaf and five children per branch;
successive key updates copied paths. The current compact tree has eight entries
per leaf and 32 children per branch, and complete bounded candidates share path
copies. The packed backend performs a provider request for each page miss or
bounded group of staged pages. This multiplies small logical operations into many
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

Idle work mattered in that fixed-polling profile too: at 100 ms, three seconds of idle time
used 0.24 node CPU seconds and issued 114 native requests with 924 page misses.
At 20 ms, those became 0.97 CPU seconds, 467 requests and 3,832 misses. Faster
polling increases load; slower polling can delay completion. Neither is a
substitute for reducing work or introducing appropriate wake-ups.

## Bounded storage batches

The growing authority batches one turn's resource-entry changes before publishing
its final catalog root. Shared paths are copied once. The packed backend groups
immutable pages and blocks into private segments, reserves their encoded bytes,
verifies every frame and seals the segment before reference publication. Namespace
scans stop at their upper boundary; the verified page cache uses LRU replacement.

The earlier page-only ReleaseSafe storage-primitive comparison used the same
binary, two cache slots, 256 keys with 1 KiB values, half-key deletion,
retained-root verification and unpublished candidates:

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

Native turns now have a separate immutable publication budget of 16 records and
128 KiB, alongside the existing four small metadata mutations. A signed descriptor
binds each body to its key, length and digest. Only the accepted resource root
makes it visible. Table rows, indexes, schemas and retained predecessors use this
boundary; large SQL statement ingress still uses the framework's small messages.
See [storage](storage.md) and [Table storage](tables.md).

Independent native engines overlap immutable reads and preparation. Publication
still rechecks the accepted authority cut; bounded retries preserve the exact
signed identity. Snapshot slots are shared across engines. Bounded Table batches
reduce per-row disclosure requests while retaining current authorization before
each batch. Metadata and a record's first block can share one snapshot read.

Physical collection verifies all protected roots before deletion. Storage epochs
fence old candidates; the maximum snapshot/request lifetime and a durable time
floor protect volatile readers. Relocation can release partially live segments
without changing logical revisions. Unlimited retention retains reachable history.
Accounted segment deletion is distinct from immediate WAL shrink, cold-tier
cleanup and backup erasure. The provider still retains per-segment metadata in RAM.

## Remaining improvements

These priorities implement the [workload model](workloads.md). The shared block,
concurrency and reclamation boundaries are implemented; workload-specific layouts
and larger ingress need their own contracts and measurements.

| Priority | Intended change | Required evidence |
| --- | --- | --- |
| Ingress and gateway coordination | Reduce small-message statement uploads and gateway intent/saved-step publication before Table execution | Exact uncertain recovery, authority, input bounds and wide/nested end-to-end cost |
| Workload-specific read structures | Persistent columnar Table blocks, statistics/pruning, scalar range indexes and versioned projections | Selective/full scans, retained data beyond cache, source freshness, rebuild cost and concurrent writes |
| Scheduling and contention | Reduce background polling and retry work where measured | Control latency, fairness, bounded queues and unchanged exact operation identity |
| Provider accounting | Measure segment-count metadata, WAL and cold-tier costs separately from Transit caches | Durable growth, physical recovery, reclamation lag and whole-process memory |

The interactive lifecycle is documented in
[query sessions](queries.md#interactive-sessions) and the
[neutral contract](../../../contracts/INTERACTIVE_QUERY_V1.md). Explicit durable jobs
retain their separate contract. Fuze and applications stay outside raw provider
access. Authority partitioning needs its own ordering and fencing design.

## Shared storage comparison

The [integrated comparison](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-19/README.md)
measures baseline `ee88a131` against `29765ef0` with ReleaseSafe, pinned providers
and sequential disk fixtures on the same shared host. Builds finish before
timing. The complete reports preserve failures, source/binary hashes and
instrumented request controls separately from ordinary latency.

| Selected control | Baseline p50 | Current p50 |
| --- | ---: | ---: |
| Console narrow one-row INSERT | 1,394 ms | 806 ms |
| Console narrow changing UPDATE | 1,416 ms | 852 ms |
| Console narrow three-row INSERT | 2,702 ms | 1,174 ms |
| Console 33-row full read | 834 ms | 393 ms |
| Console point read | 212 ms | 209 ms |
| Console empty read | 162 ms | 172 ms |
| Console LIMIT 0 | 120 ms | 132 ms |
| PostgreSQL literal four-row full read | 4,714 ms | 2,025.5 ms |
| MySQL literal four-row full read | 3,916 ms | 1,438 ms |
| PostgreSQL literal one-row INSERT | 23,259 ms | 13,238 ms |

Narrow mutations and reads have 20 samples per case; wire mutations have three.
The full report includes p95 where supported, every literal/prepared path,
wide/nested controls and their slower cases. Console and wire fixtures differ;
their absolute times do not isolate protocol overhead. These are observations,
not a latency SLO or an isolated causal estimate for one mechanism.

The retained-history/concurrent-reader workload now completes all 21 mutations
and 92 reader queries; the baseline reader fails with `HttpCapacity`. A separate
48-command offered burst still admits two commands and explicitly refuses 46 on
both builds. Revocation completes after a retry following the burst, with exact
receipts, drain and restart verified. This does not establish uninterrupted
control admission under saturated writes.

The instrumented first INSERT uses one turn instead of two, stages 29 pages
instead of 71, and records 1,072 provider attempts instead of 1,443. Owned snapshot
calls for the full console read fall from 64 to 29. These counts include
instrumentation and, except the qualified snapshot calls, overlapping background
work; they are not fsync counts or durations to add together.

The same page setting is a per-lane budget in the concurrent node, so aggregate
cache capacity differs. In the console read fixture, node HWM rises from 53,664
to 82,484 KiB, while Ursula HWM falls from 96,860 to 69,804 KiB. These are maximum
child observations per role, not summed memory or a whole-provider growth bound.
Empty and LIMIT 0 console reads remain slower in this control.

Wire reads still take roughly 1.4–2.2 seconds at p50 across the selected paths,
and wire mutations roughly 13 seconds. Point, range, full and empty reads now
cluster closely within each path, suggesting substantial fixed work; this
campaign does not isolate its authorization or setup components. Gateway intents
and saved steps still use small-message Publication records, as does large
statement ingress. Those costs remain separate optimization work.

## Durable Table mutation measurements

The phase descriptions and console recovery files in this section belong to
the recorded client-side console experiments. Current console execution and
recovery run in the SQL service; see [SQL sessions](sql-sessions.md). These
historical samples do not measure the current service's end-to-end latency.

The [mutation latency task](../../history/qualification/performance.md#durable-table-mutation-latency)
measures the full public writer path against an owned disk-backed local installation. It records
raw samples, executable hashes, source provenance, console phases, affected-row
checks and independent reads. A failed or interrupted experiment is incomplete;
its JSON report and original recovery files remain available. Completed samples
from a failed run do not establish a successful workload result.
Failed samples retain the caller's elapsed time and timing line when available.
Instrumented native rejections distinguish capacity refusal from unavailable
authority work using fixed error categories; arbitrary error text is not retained.

The fixture uses a persistent console. `--client` selects the separately compiled
`transit-mutation-latency-client` public Zig consumer. That control checkpoints
exact prepared requests and receipts and emits terminal outcomes, but does not
perform console rendering or maintain the console's full recovery record; its
local persistence costs therefore differ. Both callers retry unavailable observations within the original bounded write
wait; exact mutation submission remains single-attempt. Neither caller automatically retries
an uncertain send. Terminal outcome and row visibility, rather than admission
acknowledgement, define completion.

Controls vary retained rows (`--rows`) separately from retained mutation history
(`--age`), one/three-row INSERT, existing/same-value/absent UPDATE and DELETE,
resident cache pages, fixed worker polling, idle gaps and concurrent independent
readers. Each experiment has a one-second idle counter interval.
`--schema-profile wide` uses 32 columns with 30 fixed synthetic text defaults;
`--schema-profile nested` adds a struct containing text and a nullable text list.
Both verify every additional typed value after each measured mutation and record
their DROP/CREATE setup timings separately. The default `narrow` profile preserves
the two-column workload for comparisons with earlier implementations; wider
profiles are separate storage controls, not matched historical baselines. Optional
`--instrument` proxies add overhead; compare them separately from ordinary
latency runs. Opt-in native diagnostics report complete per-attempt work and
provider counters independently of sampled logs. Lock waits can overlap across
requests, and provider time is included in work time; sums are not an exclusive
wall-time decomposition. `--no-native-metrics` supports comparison with binaries
that lack this diagnostic configuration field.

The shared caller prepares a new request in one authorized batch and combines
processed-input disposition with terminal status observation. It retains exact
request identity, authorization and input-progress checks. Console recovery
keeps the last acknowledged input until an atomic next-request or completion
checkpoint replaces it. A restored checkpoint can discover a completed outcome
without sending another mutation.

General Table commands that fit a Station frame avoid upload. Small point writes
publish the row, final index and retained predecessor as immutable blocks, together
with the small head/outcome changes in one turn. Larger values and indexes use
bounded resumable block publication. A 128-bit primary-key lookup prefix
keeps two keyed rows in one inline index, while full typed-key comparison and
256-bit node/row commitments retain equality and integrity checks. Finite INSERT
builds up to eight rows within the existing candidate record/byte budget and
stages only the final reachable records. Neither optimization increases native
values, write slots or collection cardinality limits.

Batched reads and a 64-entry captured-turn cache reduce repeated metadata work.
A snapshot request can combine up to eight metadata keys and eight block keys,
with a separate 128 KiB block-body bound. Cache entries cannot outlive their
captured turn or mask a poisoned read. The console attributes local compilation,
preparation, native send, processing wait, result reads and every recovery-file
save to their respective timing phases. `submit` no longer absorbs the entire
write lifecycle.

The [executed mutation evidence](../../history/qualification/performance.md#durable-table-mutation-latency)
records observations and outstanding limits. No latency SLO follows from these
shared-host samples. Empirical nearest-rank p95 requires at least 20 samples per
case and p99 at least 100; smaller runs report null for those percentiles.
The [general Table comparison](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-07/README.md)
records higher mutation latency and request amplification than the earlier
fixed-column storage profile. It also measures wide/nested values and retained
data with a concurrent reader. The record separates ordinary timings,
instrumented counts and failed setups;
general type support does not establish the earlier performance budgets.
Those general-schema costs remain the historical accepted baseline; the
integrated storage campaign above provides the current comparison. For the
41-row configured-source Table fixture with 64 resident authority pages and no
setup aging, regression ceilings are 75 requests for scan/COUNT and scalar
ranges, 23 for LIMIT 3, 13 for LIMIT 0, 22 for primary-key equality, 20 for its
COUNT, and 11 for metadata inspection. Explicit bindings add ten requests.
These ceilings apply to that fixture; they are not latency promises or allowances
for arbitrary schema/cardinality growth. The earlier failed-budget reports remain
part of the evidence. [Further optimization](https://github.com/spoke-sh/transit/issues/76)
tracks the remaining ingress, layout and workload controls while preserving
authority, recovery and resource bounds.

Complete Table history adds one retained old-head record at each replacement.
The earlier small-KV representation moved narrow INSERT and changing UPDATE from
one turn to two, with three-row INSERT taking four turns. The
[complete-history campaign](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-12/README.md)
preserves that historical cost and its concurrent-load limits. Its elapsed times
overlap maintenance qualification and do not isolate change-capture cost. The
current block representation retains the predecessor in the same publication
batch; the matched storage-foundation evidence above measures that change.

Idle workers use bounded authorized waits on the observed process or output
position. Waits release the authority lock, have separate admission capacity,
and revalidate current authorization after a publication or timeout. Notifications
are volatile and coalesced; timeout reads cover missed or other-node publications.
An unavailable wait falls back to the bounded worker interval. Fixed worker
intervals remain a measurement control, not a latency guarantee.

Mutation callers also use bounded authorized waits after observing the exact
admitted input pending. The console and native SDK observation owner retain
only a scheduling position, never cached permission or completion. They replace
fixed completion sleeps with waits of at most 50 ms, then read current progress.
Wait-slot exhaustion uses bounded backoff and ordinary read admission. The
console still saves its original command and receipt before advancing; denied
or unavailable observations never authorize another SQL submission.

The instrumented mutation fixture correlates each small request's admission,
view capture, turn receipt and caller observation by native PID/input identity.
It reports request/response times and the tail after processed observation.
These are proxy observations, not exact fsync/commit instants: another reader can
observe publication before the worker receives its receipt. Missing, ambiguous
or evicted trace evidence remains explicitly incomplete. Instrumented timing is
separate from ordinary latency and does not change the console's phase meanings.

A later physical-disk control compares the merged baseline with bounded caller
waits and leaf-frontier staging. Each uninstrumented run completes all 140 cases
with independent row verification and zero uncertain writes:

| Control | INSERT p50 / p95 | UPDATE p50 / p95 | DELETE p50 / p95 |
| --- | ---: | ---: | ---: |
| Merged baseline | 142 / 151 ms | 153 / 187 ms | 138 / 150 ms |
| Bounded caller waits | 131 / 140 ms | 149 / 177 ms | 129 / 140 ms |
| Waits and leaf batches | 113 / 123 ms | 130 / 169 ms | 112 / 126 ms |

Separate instrumented 21-case controls attribute median admission/view/turn
provider requests of 16/11/29 before leaf batching and 14/8/22 afterward. Median
authority work falls from 25.1/22.4/41.2 ms to 19.8/13.0/29.4 ms. The latter
control observes processed input about 5 ms after the turn receipt and completes
about 9 ms after that observation. These overlapping proxy observations do not
measure independent fsync costs. A concurrent-reader control completes 140 writes
and 1,280 reads, with INSERT/UPDATE/DELETE p50 138/156/137 ms.
The [raw controls](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-05/README.md)
retain exact source/binary provenance and shared-host limitations.

The [finite offered-load fixture](../../../tests/performance/load/growing_load.py) uses ReleaseSafe binaries.
It schedules 48 requests independently, records generator queueing, separates
admitted and refused attempts, and captures authority wait/work counters.
Only accepted inputs are drained and checked after node/provider restart;
rejected sends are not silently retried. A control command refused during the
burst is checked separately after it. This native admission experiment does not
measure simultaneous end-to-end SQL writers or sustainable throughput.

An earlier matched-provider comparison on the shared development host records these
single-row distributions, with 20 samples per case. Both use the same corrected
local Ursula provider, fresh disk fixtures, eight resident pages and default
workers. Each completes 140 cases with independent row verification:

| Control | INSERT p50 / p95 | UPDATE p50 / p95 | DELETE p50 / p95 |
| --- | ---: | ---: | ---: |
| Frozen earlier implementation | 346 / 404 ms | 334 / 402 ms | 329 / 546 ms |
| Shared candidates, scoped waits and compact pages | 135 / 154 ms | 152 / 179 ms | 143 / 148 ms |

The [raw campaign and reproduction](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-04/README.md)
retain source/binary hashes, all seven cases, failed controls and instrumentation
limits. The runs match provider and fixture settings, while shared-host load
remains uncontrolled. They establish no p99 or latency SLO.

A separate unproxied direct caller completes 700 cases and 5,729 concurrent reads
with 12 retained rows, six setup updates and a 64-page cache. Its single-row
INSERT/UPDATE/DELETE p50 is 285/346/285 ms and p95 323/405/323 ms. Independent
row-count, retained-history, cache, idle-gap, reader and fixed-polling controls
also complete. Longer loaded default and row-count controls record supervisor
authority-timeout restarts; the longest default statement takes 13.6 seconds.
An earlier combined control fails when its concurrent reader stops during a
restart. Completed repeats do not erase those availability and tail limits.

The local provider includes a bounded cold-flush correction: a small journal
prefix previously prevented a larger page stream from fitting into the same
flush batch, eventually producing `ColdBackpressure`. Subsequent chunks now
use the remaining batch budget. The hot-memory limit and acknowledgement rules
are unchanged. The official container image remains a separate, unpatched
provider profile; see the [provider mapping](../../../packages/zig/transit-backend-ursula/docs/upstream.md).
Native 503 responses still require exact saved recovery rather than fresh SQL.

Record the backing filesystem when comparing storage latency. A file-backed WAL
inside a temporary directory can reside on tmpfs; that run does not measure
physical-disk write cost. Place fixtures on the filesystem being measured and
verify the actual mount on the host. The
[physical-storage query controls](../../history/qualification/performance.md#physical-storage-query-follow-up)
record the executed placements and reproduction commands.
Process/provider restart checks establish their stated recovery boundaries;
filesystem placement alone does not establish power-loss durability.

TPC components answer different questions. The local compiler/proposal cases
exclude durable admission, owner processing, provider I/O and caller checkpoints;
they cannot diagnose multi-second single-row writes. The
[TPC-C](https://www.tpc.org/tpcc/) and [TPC-E](https://www.tpc.org/tpce/) workloads
provide later transaction-processing comparisons. [TPC-H](https://www.tpc.org/tpch/)
and [TPC-DS](https://www.tpc.org/tpcds/) address decision-support workloads.
Transit's component measurements and incomplete workload coverage are not TPC
scores or conformance results; consult the [benchmark reference](benchmarks.md).

## Reproduce and compare

Use the [benchmark reproduction commands](../../history/qualification/performance.md#query-performance-reproduction)
in the proof ledger with the repository’s pinned development environment.
They cover console latency, populated interactive sources, cache and worker
polling controls, durable-history aging, transport instrumentation, mutation
batch sizes and cold storage. The settings below describe those fixture runners.

The runner reports first stdout byte, completion, sampled console RSS (20 ms
sampling), node CPU, sampled node RSS and executable hashes. Repetitions share an installation;
`--age-queries` uses explicit durable execution to add completed query history before measurement. A first query
is post-bootstrap, not a cold OS or provider cache. `--resident-pages 0` disables
the native immutable-page cache without flushing the operating system; the separate
16-record immutable control cache remains bounded and enabled. An explicit
`--worker-interval-ms` selects fixed polling for that fixture, disabling idle backoff.

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

## Schema on demand measurements

Local CSV/JSONL discovery, finite queries and explicit test-host capture have a
[reproducible comparison matrix](../../../tests/performance/query/README.md) and
[recorded baseline and budgets](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-09-30/README.md).
DuckDB 1.5.2 (build `8a5851971f`) and PyArrow 23.0.0 are pinned development
comparators; neither supplies Transit's execution engine or authorization.
The [type and source reference](sql/types.md#schema-discovery-and-binding)
defines supported modes and deliberate semantic differences.

The recorded baseline uses 4096 deterministic rows across narrow/wide CSV,
nested/sparse/decimal JSONL, leading-zero identifiers, reordered files, gzip and
stdin. Explicit, partial, sampled, full and raw modes run with cold/warm input
pages, three raw repetitions and one CPU per child. Separate projection,
one-row/eight-row batch, filter, COUNT and SUM runs bring the matrix to 792
samples across both engines. The reports retain fixture hashes, resolved schemas,
reader options, compiler/build hashes, resource limits, CPU/RSS, allocation/I/O
counters, exact row/query checksums and every raw repetition.

### Measured phases and limits

Capture, discovery, compilation, full scan/conversion, query execution and cached
batch export have separate timers. Query execution starts a fresh scan; its time
must not be added to or subtracted from the earlier scan as an isolated operator
cost. First-batch timing starts after acquisition/discovery and means logical
rows in Fuze; DuckDB's streaming API also constructs Arrow. Fuze rows remain
provisional until verified EOF. Cached export serializes at most eight decoded
rows, not a retained full result or full-source output throughput.

The frozen pre-optimization baseline at `420e3279` has these explicit-schema,
warm-input medians on the shared Linux Threadripper 3960X host:

| Shape | Fuze full query pipeline | DuckDB query/Arrow pipeline | Fuze executable peak RSS |
| --- | ---: | ---: | ---: |
| Narrow CSV | 38.966 ms | 7.463 ms | 9696 KiB |
| Wide CSV | 461.055 ms | 42.623 ms | 9712 KiB |
| Nested JSONL | 224.880 ms | 11.967 ms | 10728 KiB |

These are observations for different validation/output contracts, with no parity
or speedup claim. Both phases include checked result consumption. Fuze validates
all fields and rows; DuckDB can prune work. Allocator scopes also differ: Fuze
counts backing-allocator requests, while the comparator's process hook includes
Python/glue. Jemalloc and PyArrow counters remain separately labeled. RSS uses
the executable's VmHWM counter; separate process-lifetime counters include the
launcher before exec. Three repetitions do not establish p95/p99 tails.

Cold-input runs verify eviction of the fixture's file pages. Captures are newly
written and warm; this is not a cold-device or whole-host-cache claim. A separate
Transit proof completes a 600058901-byte input under a 256 MiB cgroup RAM-plus-file-
cache limit with swap disabled in explicit/sampled/full/raw modes. Each records
actual peak and zero OOM events. That proof establishes the selected resource
boundary, not large-input DuckDB performance. Temporary storage must be disk
backed when input exceeds the desired memory budget.

### Regression and execution choices

Numeric limits were committed with the baseline before optimization. They bound
per-case phase/first-batch latency, CPU, executable RSS, tracked live bytes,
allocation requests/bytes and source-read work. A paired eight-query control uses
the same driver against the original six-scalar implementation; each median
candidate/control ratio must remain at most 1.15. Exact limits, source report
hashes, failures and reproduction commands live with the
[baseline artifacts](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-09-30/README.md).
Incomplete or changed-workload evidence cannot pass the checker.

CSV scans retain bounded header/schema metadata and validate the current binding
before rows and completion. Full-row conversion and EOF verification apply after
projection, predicates or LIMIT. Delaying or skipping unused conversions would
hide errors under this contract and is not admitted. There is no retained result
cache, cross-query inference cache or implicit refetch.

Two optional metadata optimizations were evaluated after the baseline: avoiding
one repeated descriptor-validation traversal and caching header-to-column indices.
Their full result, allocation, I/O-count, memory and six-type checks passed, but
two complete repetitions failed different capture/discovery timing limits. Both
optimizations were withdrawn without changing the budgets. File discovery and
scanning retain the measured baseline's metadata algorithm. The
[experiment record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-09-30/README.md#withdrawn-metadata-experiments)
retains both failures and the observed shared-host interference; it establishes
no qualified optimization benefit or isolated cause for every timing change.

After native output-name support changed the plan profile, the specialized
six-type control detected a separate validation regression. Native binding now
avoids rebuilding an unchanged output schema and repeating shape validation
within one canonical encoding. Complete source/plan checks and alias collision
checks remain. A subsequent nine-pair measurement at `a99a9c59` records ratios
1.0003–1.1219 against the original control, within the unchanged 1.15 budget.
The [post-merge record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/fuze_benchmarks/results/2026-09-30/README.md#post-merge-specialized-path-regression)
retains the failed trials and passing result. This evidence covers native
six-type execution; it does not remeasure file or DuckDB performance.

Independent [source, CLI and Arrow proofs](../../history/qualification/query.md#fuze-bounded-file-sources)
cover extreme values, malformed/outlier input, changed content, denial,
cancellation and ownership. Those correctness schedules are separate from the
synthetic timing shapes. Native accepted-work recovery keeps its existing
contracts; local captured files do not admit durable jobs.

## Tiered storage, `.tseg` segments and multi-writer OCC

The [tiered storage package](../../../packages/zig/transit-storage/README.md) and
[storage format contract](../../../contracts/TRANSIT_STORAGE_V1.md) decouple direct
data-plane table ingestion and analytical/point reads from the actor-turn block
staging pipeline:

- **Direct Table acceptance:** `DirectCatalog` and `TablePartition` publish one
  WAL acceptance record for a statement's rows, paged indexes and original
  receipt. Point data can remain in the WAL. Bulk writes and explicit bounded
  flushes publish immutable `.tseg` objects through the same acceptance owner.
  Recovery follows contiguous hash-linked records and restores paged roots;
  retained reads include accepted unflushed data.
- **Bounded segment reads:** The paged row directory locates the containing
  segment. `TSegReader` verifies footer and column ranges, retains encoded pages
  for selected point reads and decoded groups for scans, and enforces separate
  byte budgets. Full-key ranges use the paged ordered index with declared
  collations. Finite direct scans select required columns before reading segment
  pages and execute bounded predicates before materializing selected rows.
  Relational predicate pushdown remains separate; the
  [query owner](../../../packages/zig/transit-query/README.md) defines the finite
  scan's source-coverage, failure-order and authorization gates.
- **Cache and manifest components:** `NvmeCache` caches `64 KiB`
  SHA-256-verified ranges and protects `.metadata_or_index` chunks from
  sequential `.column_data` scans. `PartitionLease.OccCoordinator` can rebase
  disjoint manifest candidates and reject overlapping primary keys with
  `WriteWriteConflict`. These separately tested components, `.tdel` deletion
  vectors and `.tman` manifests do not establish installed concurrent writers,
  provider performance or automatic Table compaction.
- **Measurement scope:**
  The earlier 33-operation, 217-turn gateway run measured 122.759 seconds before
  and 55.770 seconds after cache/wakeup changes on its recorded actor/native path
  ([executed evidence](../../history/qualification/sql.md#live-storage-engine-and-sql-execution-cutover)).
  That result does not measure the current direct storage path. Matched workloads,
  toolchains, storage and failure conditions are required for a new comparison.
