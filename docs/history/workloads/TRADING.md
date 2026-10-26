# Trading application workload and capacity model

Status: planning assumptions, recorded 2026-09-24 for [Verification](../../handbook/reference/verification.md).
These calculations describe the intended downstream application. They are not
measurements of Transit, a venue selection, or production service objectives.
[Testing](../TESTING.md) owns qualification; the
[experiment matrix](../../../tests/verification/scale.json) owns experiment sizes.

The shared [workload priorities](../../handbook/reference/workloads.md),
[performance characteristics and improvement plan](../../handbook/reference/performance.md)
and [public examples](../../handbook/guides/workload-examples.md) own the cross-application
architectural direction. This record retains application-specific demand assumptions;
its synthetic rates do not describe achieved runtime capacity.

## Intended workload

The example application targets a broad universe of instruments, historical and live trades/quotes
through L2/L3, relevant internet ingestion, and a shared context surface for human
and agent collaboration. It will support algorithmic and high-frequency execution
services alongside strategy research, execution and optimization, including
reinforcement-learning agents and fast model inference. Trading semantics and
model choice stay above Transit. The selected execution class is **milliseconds
from receiving a market event to sending an order**. The exact budget, percentile,
load/failure conditions and initial feed coverage remain to be qualified.

Size these workloads independently:

| Workload | Dominant dimensions | Required failure behavior |
| --- | --- | --- |
| Market capture and history | Feed event/byte rates, microbursts, historical backfill, retained years | Preserve source coordinates and detect gaps, duplicates, corrections and incomplete history |
| Book/feature materialization | Active instruments/orders, hot partitions, per-event compute, subscriber fan-out | Recover a consistent source position and state; distinguish lag from freshness |
| Internet capture and enrichment | Fetches, response sizes, versions, extraction/embedding work | Durable attempt identity, bounded reconciliation, provenance and explicit incomplete capture |
| Shared context | Documents, edits, readers, versions, relationships and access scope | Convergent supported edits, current access checks and retained source evidence |
| Trading execution | Order/cancel rates, risk serialization, latency tails, outstanding exposure | Fence stale owners; reconcile uncertain orders without unsafe retries |
| Research and optimization | Dataset scans, experiment concurrency, simulation steps, model/feature versions | Reproducible input basis, isolated resource budgets and no live effects during replay |

An instrument is not necessarily a feed symbol, venue listing or derivative
contract. Record those mappings over time, including delistings and expiries;
count active and historical identities separately. Order-book detail also changes
the event population: L3 needs order lifecycle events, not just trades or periodic
quotes. For example, [Nasdaq's ITCH specification](https://classic.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification.pdf)
defines add, execution, cancel, delete and replace messages and daily symbol
mapping. This is a reference for workload structure, not a selected integration.

## Market-data arithmetic

Use the sum of measured feed rates, not instrument count times a guessed constant:

```text
events/second = sum(rate for each captured feed partition)
logical bytes/day = sum(events/day by record kind * encoded bytes/record)
physical retained bytes = compressed payload copies
                        + indexes + materializations + control history
                        + versions/staging + backup policy + operating headroom
```

Count redundant feed copies explicitly. Keep source capture, normalized records
and derived data separate to avoid either forgetting a copy or counting one
twice. Compression, replication and write amplification must be measured per
representation. A compressed archive ratio does not predict hot-index size.

For a sensitivity calculation, assume **100 bytes per normalized event**, no
compression, one copy, and **6.5 hours at the stated average rate** per session.
Use **252 such sessions** for the annual illustration. These are synthetic sizing
inputs, not actual feed averages, a global trading calendar, or wire sizes.
Units below are decimal MB/TB/PB.

| Average events/s | Payload MB/s | Events/session | TB/session | PB/252 sessions | TB/24 hours at this rate |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 100,000 | 10 | 2.34 billion | 0.234 | 0.058968 | 0.864 |
| 1,000,000 | 100 | 23.4 billion | 2.34 | 0.58968 | 8.64 |
| 10,000,000 | 1,000 | 234 billion | 23.4 | 5.8968 | 86.4 |

At the middle scenario, 30 sessions occupy 70.2 TB for that representation alone;
three copies without compression occupy 210.6 TB before indexes and derived data.
Unlimited retention means this continues to grow. Archive tiering can change
cost and retrieval latency; it is not permission to delete authoritative data.

For an external magnitude check, [OPRA's August 2026 operating metrics](https://cdn.opraplan.com/documents/OPRA_SIP_Metrics_August_2026.pdf)
report **59.4 million messages in the peak second**, **0.18 million in the peak
millisecond**, and **194.8 billion transactions on the peak day** for that month.
These are separate maxima, not a simultaneous sample or daily average, and the
US options consolidated feed does not represent worldwide L3 coverage. Applying
our assumed 100-byte representation yields 19.48 TB for that peak-day count and
47.52 Gbit/s at the peak-second rate. These derived sizes are not OPRA's measured
wire bandwidth. Millisecond bursts require their own buffering/capacity tests.

## State, execution and read amplification

History size, current state and process count are different quantities. As an
illustration, 100,000 books with 50 levels on each side and 32 bytes per level
contain 320 MB of level data before indexes, metadata, multiple venues and copies.
L3 state instead depends on active orders: 10 million at an assumed 64 bytes each
already contributes 640 MB before indexes. Neither figure bounds event history.

Choose PIDs for independent sequencing, recovery and ownership. A record does
not need its own PID, nor does a PID inherently need a dedicated OS process or
pod. Measure retained PIDs separately from active handlers and worker pools.
The reference currently maps a PID to a Substrate Actor;
[Clustered execution](../../roadmap/18-clustered-execution.md) must qualify any multiplexing or alternative mapping.

At one million events/s, 10 microseconds of CPU per event consumes ten fully busy
CPU cores in ideal arithmetic, before I/O, contention or spare capacity. Giving
every event to 100 strategies creates 100 million strategy evaluations/s unless
filtering or shared feature computation reduces that work. Measure actual fan-out
and CPU/inference costs rather than estimating from the ingestion rate alone.

Historical ingestion is additional offered load. Importing ten years in ten days
requires one year of archive per day; budget it alongside live capture. Research
can multiply reads again: 1,000 runs over ten sessions in the middle scenario
would scan **23.4 PB** if each independently read every normalized event. Data
selection, shared scans, caches and feature reuse change that demand; record
their assumptions and the experiment's exact dataset/model/configuration basis.
GPU sizing requires model, batch, inference and training measurements; message
rate alone supplies no defensible accelerator count.

Point-in-time research needs both event time and when information became available,
plus corrections and source version. A later correction or crawled document must
not silently become knowledge available to an earlier simulated decision.

## Internet and shared context

One million captures/day at an assumed average of 1 MB contributes **1 TB/day**
before extraction, versions, indexes or copies. Ten million stored chunks with
1,536 float32 components each contribute **61.44 GB** of vector values alone;
model choice, vector indexes and retained source content are additional costs.
These are illustrative inputs, not a crawler or embedding-model decision.

Preserve captured content identity, source, timestamps and extraction/model version.
An item relevant to many instruments should have shared content with references
where access/lifetime rules permit, rather than a full copy per instrument.
Mutable shared context and immutable source capture have distinct lifetimes.
Collaboration needs Document semantics and per-user/application access policy;
the private shared-identity Board deployment is not that collaboration surface.
[Documents](../../handbook/reference/documents.md) owns Documents; identity and sharing scope still need
qualification before a multi-user trading application is deployed.

## Recovery headroom and latency

For a consumer unavailable for D seconds, with constant continuing arrival rate
lambda and catch-up processing rate mu:

```text
backlog = lambda * D
catch-up seconds = backlog / (mu - lambda), only when mu > lambda
```

At one million events/s, a ten-minute interruption leaves 600 million events.
Processing at 1.5 million/s takes another 20 minutes to catch up while arrivals
continue. This excludes checkpoint loading, warmup and other consumers. A worker
restart time is not a return-to-freshness objective. Storage exhaustion or a
non-backpressurable external feed can create an upstream capture gap; record it
explicitly and apply source-specific recovery. Do not acknowledge missing data.

Measure capture-to-durable, durable-to-materialized, market-event-to-order-send,
remote acknowledgement and research completion separately. The selected target
is millisecond-class market-event-to-order-send execution, with the precise budget
and tail percentile still open. Measure receive/decode, materialization/features,
strategy inference, risk ordering, durable dispatch authorization and network send
within that path. This is an application requirement, not a demonstrated Transit
capability. Kubernetes-native deployment alone establishes no latency guarantee.
Backfills, research, crawling and slow readers need separate resource budgets so
they cannot exhaust the execution path's CPU, I/O, admission or control capacity.

Order placement, cancellation and kill controls still cross authorized effect
boundaries. A faster path cannot silently turn durable pre-I/O authorization into
after-the-fact audit. A new latency profile would need an explicit protocol,
deployment and failure proof. Replaying data cannot submit live orders; unknown
remote outcomes remain unknown until valid reconciliation.

## Consequences for Transit and M10

The current realm-wide journal serializes publication. More HTTP replicas do not
remove that bottleneck. M10 must measure the single-authority limit;
[Clustered execution](../../roadmap/18-clustered-execution.md) owns authority partitioning, routing, fencing and
cross-partition delivery. Per-feed and per-PID order do not imply a global market
order. Splitting physical streams alone does not solve authorization or atomicity.

Bulk immutable batches with ordered source ranges, checksums, schema and explicit
completion are the intended direction for volume. Publish references only after
their payload is durable and their access/recovery lifetime is validated. Keep
control decisions, current-state indexes and append-heavy history distinct in
the storage layout while preserving one authoritative publication decision.
This bulk ingestion contract is not implemented by v2 or the developing v3 types.

Batching has a latency cost. At one million events/s, ideal full batches of 1,000
events imply 1,000 publications/s before other protocol operations. Spread over
100 equal partitions with a one-millisecond flush bound, an ideal steady stream
fills only ten events per partition per flush: about 100,000 publications/s.
Use both a byte/event budget and a maximum delay; benchmark source skew and the
full protocol operation count. Do not assume perfect large batches everywhere.

The earlier mapping created one closed Ursula stream per immutable page. The
current packed backend appends page records to shared streams; page misses and
appends still issue individual provider requests. Use the public
[storage reference](../../handbook/reference/storage.md) for the current mapping and
[performance evidence](../../handbook/reference/performance.md) for measured amplification.
Include provider stream count, provider RSS, requests and writes per committed
mutation, orphan staging and disk amplification in qualification. Bounded client
cache alone does not establish bounded system memory or cost.

Run small deterministic correctness cases in ordinary CI. Use separately budgeted
growth/load runs with retained data larger than memory, 1/10/100 ms bursts, skew,
live-plus-backfill competition, slow consumers, revocation and recovery under load.
Measure achieved rates and failures; the million-event scenarios above are
analytical demand scenarios, not new mandatory per-PR benchmark rates.

Before production qualification, select actual feeds/coverage, capture formats,
retention and replicas, peak distributions, active workloads, latency/freshness
objectives, deployment hardware and acceptable recovery windows. M10 can establish
measured foundations while those choices remain open; it cannot certify this
entire application from a small single-authority proof.
