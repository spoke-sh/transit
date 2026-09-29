# Performance characteristics and improvement plan

An empty interactive query currently spends most of its time in native
orchestration and storage, with negligible table-rendering time. The evidence
supports reducing that protocol and storage work before optimizing SQL operators.
This page records local measurements from 2026-09-29 and planned improvements;
it does not claim the proposed session or storage changes are implemented.

## What was measured

The workload is `SELECT * FROM items;` over an empty Table through the console's
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

The current console uploads a plan, records its call, captures a source version,
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
experiment resolves the multi-second latency; neither is adopted on this evidence.
Faster 20 ms polling measured 15.52 s and 36,604 misses. Slower 200 ms polling
measured 15.67 s. All are separate single samples with host variance.

Idle work matters too: at the default 100 ms interval, three seconds of idle time
used 0.24 node CPU seconds and issued 114 native requests with 924 page misses.
At 20 ms, those became 0.97 CPU seconds, 467 requests and 3,832 misses. Faster
polling increases load; slower polling can delay completion. Neither is a
substitute for reducing work or introducing appropriate wake-ups.

## Planned improvements

These priorities implement the [workload model](workloads.md); they are design
direction, not shipped capabilities or promised dates/speedups.

| Priority | Intended change | Required evidence |
| --- | --- | --- |
| Interactive sessions | Fresh snapshot per SELECT, bounded Arrow streaming, cancel on exit, server-enforced cleanup after disconnect; retain explicit durable jobs separately | First batch/completion and cancellation tails, revocation after a prefix, complete/incomplete framing, bounded pins and memory |
| Shared read/write amplification | Bounded batched native reads and tree updates, reusable verified pages with current authorization, fewer repeated metadata reads | Native/provider requests, staged bytes and pages per operation; unchanged atomicity, permission and retry behavior |
| Bulk immutable publication | Persist bounded blocks before atomic publication of verified references and source progress | Uncertain commits, orphan handling, payload availability, quotas, recovery and actual physical write amplification |
| Workload-specific read structures | KV point/range access, columnar Table blocks and pruning, Document path/sequence and versioned projections | Selective/full scans, retained data beyond cache, source freshness, rebuild cost and concurrent writes |

The accepted interactive lifecycle is documented in
[query sessions](queries.md#planned-interactive-sessions). A new neutral contract
must define the cancellation/completion race, abnormal-disconnect lease or
deadline, current-policy checks and resource accounting before implementation.
Snapshot pin accounting may still require durable decisions; the aim is to avoid
durable progress and result writes for each small interactive fragment.

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
```

The runner reports first stdout byte, completion, sampled console RSS (20 ms
sampling), node CPU and executable hashes. Repetitions share an installation;
`--age-queries` adds completed query history before measurement. A first query
is post-bootstrap, not a cold OS or provider cache. `--resident-pages 0` disables
the native immutable-page cache without flushing the operating system.

`--instrument` inserts owned loopback proxies and counts native attempts by
operation and principal, plus provider methods and request/response body bytes.
It reports a separate three-second idle interval. These are transport attempts,
not unique durable commits or retained disk bytes. Proxy overhead can alter
polling and retries substantially: compare these runs separately from ordinary
elapsed-time measurements. No payloads or credentials are logged.

The task builds ReleaseSafe binaries into its own cache directory, freezes their
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
