# Performance characteristics and improvement plan

For planned CSV/JSONL workloads, see
[schema-on-demand comparisons](#schema-on-demand-measurements). The native
query measurements below do not measure file discovery or type inference.

The console executes fresh interactive queries through leased native snapshots
and client-side Fuze. It avoids the durable upload/result-publication workflow
whose measured costs motivated this change. This page records local read and mutation measurements, their limits and the
remaining storage costs.

Interactive `.timer` separates local `compile`, snapshot `open`, `fetch`
(including execution and current validation), `render` and snapshot `release`.
The instrumented fixture also records cumulative upstream elapsed nanoseconds
by native operation and principal. Those durations include provider/queue time
and proxy overhead; they are not independent CPU measurements.

See [declarative benchmarks](benchmarks.md) for synthetic compiler/execution
measurements and explicit TPC-C, TPC-E, TPC-H and TPC-DS coverage gaps.

## Interactive execution measurements

The default local server returns the empty typed Table in **15–18 ms** across
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
[growing listener](../../apps/transit-node/docs/growing.md#public-surface-and-limits)
and [client transport](../../packages/zig/transit-client/README.md#public-surface).

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
its final catalog root. Shared paths are copied once. The packed backend sends
bounded groups of immutable sibling pages, checks every provider acknowledgement
and returns no references if any frame is uncertain. This uses page format 1,
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
| Shared read/write amplification | Implemented: combined snapshot/metadata reads, bounded ranges and Document chunks, separate immutable control/page caches, tree mutation/page staging batches and bounded transport reuse | Native/provider requests, staged bytes and pages per operation; unchanged atomicity, permission and retry behavior |
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

## Durable Table mutation measurements

The [mutation latency task](../../tests/README.md#durable-table-mutation-latency)
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
readers. Each experiment has a one-second idle counter interval. Optional
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

The small-request path uses one send, one captured view and one committed turn.
Requests up to 223 canonical bytes avoid the begin/part/seal/apply sequence.
Batched captured reads, an eight-key turn-local cache and compatible catalog
write batches reduce additional requests and page copies while retaining current
authorization and atomic outcome checks. The console attributes local compilation,
preparation, native send, processing wait, result reads and every recovery-file
save to their respective timing phases. `submit` no longer absorbs the entire
write lifecycle.

The [executed mutation evidence](../../tests/README.md#durable-table-mutation-latency)
records observations and outstanding limits. No latency SLO follows from these
shared-host samples. Empirical nearest-rank p95 requires at least 20 samples per
case and p99 at least 100; smaller runs report null for those percentiles.
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
The [raw controls](../../tests/mutation_latency/results/2026-10-05/README.md)
retain exact source/binary provenance and shared-host limitations.

The [finite offered-load fixture](../../tests/growing_load.py) uses ReleaseSafe binaries.
It schedules 48 requests independently, records generator queueing, separates
admitted and refused attempts, and captures authority wait/work counters.
Only accepted inputs are drained and checked after node/provider restart;
rejected sends are not silently retried. A control command refused during the
burst is checked separately after it. This native admission experiment does not
measure simultaneous end-to-end SQL writers or sustainable throughput.

A matched-provider comparison on the shared development host records these
single-row distributions, with 20 samples per case. Both use the same corrected
local Ursula provider, fresh disk fixtures, eight resident pages and default
workers. Each completes 140 cases with independent row verification:

| Control | INSERT p50 / p95 | UPDATE p50 / p95 | DELETE p50 / p95 |
| --- | ---: | ---: | ---: |
| Frozen earlier implementation | 346 / 404 ms | 334 / 402 ms | 329 / 546 ms |
| Shared candidates, scoped waits and compact pages | 135 / 154 ms | 152 / 179 ms | 143 / 148 ms |

The [raw campaign and reproduction](../../tests/mutation_latency/results/2026-10-04/README.md)
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
provider profile; see the [provider mapping](../../packages/zig/transit-backend-ursula/docs/upstream.md).
Native 503 responses still require exact saved recovery rather than fresh SQL.

Record the backing filesystem when comparing storage latency. A file-backed WAL
inside a temporary directory can reside on tmpfs; that run does not measure
physical-disk write cost. Place fixtures on the filesystem being measured and
verify the actual mount on the host. The
[physical-storage query controls](../../tests/README.md#physical-storage-query-follow-up)
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

Use the [benchmark reproduction commands](../../tests/README.md#query-performance-reproduction)
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

Local CSV/JSONL discovery, finite queries and explicit CLI capture have a
[reproducible comparison matrix](../../tests/fuze_benchmarks/README.md) and
[recorded baseline and budgets](../../tests/fuze_benchmarks/results/2026-09-30/README.md).
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
[baseline artifacts](../../tests/fuze_benchmarks/results/2026-09-30/README.md).
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
[experiment record](../../tests/fuze_benchmarks/results/2026-09-30/README.md#withdrawn-metadata-experiments)
retains both failures and the observed shared-host interference; it establishes
no qualified optimization benefit or isolated cause for every timing change.

After native output-name support changed the plan profile, the specialized
six-type control detected a separate validation regression. Native binding now
avoids rebuilding an unchanged output schema and repeating shape validation
within one canonical encoding. Complete source/plan checks and alias collision
checks remain. A subsequent nine-pair measurement at `a99a9c59` records ratios
1.0003–1.1219 against the original control, within the unchanged 1.15 budget.
The [post-merge record](../../tests/fuze_benchmarks/results/2026-09-30/README.md#post-merge-specialized-path-regression)
retains the failed trials and passing result. This evidence covers native
six-type execution; it does not remeasure file or DuckDB performance.

Independent [source, CLI and Arrow proofs](../../tests/README.md#fuze-bounded-file-sources)
cover extreme values, malformed/outlier input, changed content, denial,
cancellation and ownership. Those correctness schedules are separate from the
synthetic timing shapes. Native accepted-work recovery keeps its existing
contracts; local captured files do not admit durable jobs.
