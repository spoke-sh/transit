# Workloads and architectural priorities

Transit serves workloads with different lifetimes: durable application work,
short interactive reads, long analytical scans and external effects. Their data
can share accepted history without sharing the same execution or recovery policy.
This reference records the architectural direction. The capability column below
describes implemented interfaces; the improvement sections describe planned work.
The [performance reference](performance.md) supplies measurements and their limits.

## Workload families

| Workload | Implemented building blocks | Structures and behavior to prioritize | Measure success with |
| --- | --- | --- | --- |
| Console, Board and agent inspection | Finite declared KV/Table/Document queries and bounded Arrow results | Fresh snapshot sessions, efficient point/range reads, prompt cancellation | First batch and completion latency, concurrent readers, cancellation and revocation latency |
| Shared context and collaborative documents | Accepted Document revisions, structured edits, text, retained reads and explicit conflicts | Path/sequence indexes and versioned search or analytical projections | Edit acceptance, read latency, conflict fidelity, recovery and projection lag |
| Market capture, telemetry and operational features | Ordered mailboxes, bounded turns, KV and typed Tables | Bulk ordered capture, incremental materialization per partition, hot keyed state | Gaps, sustained and burst rates, capture-to-state delay, catch-up under continuing input |
| Historical research and optimization | Finite scans and aggregates over one declared source; captured result recovery | Partitioned columnar blocks, pruning, shared features and explicit dataset/plan/model versions | Bytes scanned, throughput, concurrent experiments and reproducibility |
| Internet capture and enrichment | Finite HTTP/gRPC connectors with recorded attempts, outcomes and replay | Bounded bulk payloads, shared captured content and versioned derived data | Capture completeness, bytes per attempt, extraction lag, uncertain outcomes |
| Workflow and service coordination | Durable calls, saved correlations, atomic state/input/output commits | Small bounded turns and efficient keyed access | Accepted-to-completed latency, backlog, recovery and duplicate suppression |
| Trading execution and other external actions | Fenced workers and authorized recorded connector attempts | Explicit ordering domains and isolated execution/control budgets | Event-to-send tails, remote acknowledgement, reconciliation and control response |

These are workload categories, not complete applications supplied by Transit.
Finite joins, grouping and sorting follow the bounded
[relational profile](queries.md). Continuous SQL and
arbitrary cross-resource transactions are unsupported. The [example gallery](../guides/workload-examples.md)
shows executable starting points and identifies what each leaves to the application.

## Interactive reads have a session lifetime

Each interactive SELECT acquires a fresh source snapshot. Completion releases
its read resources. The SQL service retains the last bounded response batch for
explicit fetch retries until cursor close, session close or expiry. Reconnecting
can continue an unexpired logical session; opening a new session does not resume
an old interactive query. A session is not a new durable PID or principal.

The SQL service owns console execution and cleanup. Explicit captured queries
retain recovery intent in the account ledger; disconnecting does not cancel them. The precise
[query lifecycle contract](queries.md#interactive-sessions) defines the
required boundaries, including server cleanup after an abnormal disconnect.
Existing explicit durable jobs retain their own recovery contract.

Shared verified immutable pages may outlive a query session. Its cursor, progress
and permissions may not. A reusable byte cache is compatible with a fresh
snapshot and current authorization. Accepted application data remains durable
regardless of whether an interactive answer needs recovery after console loss.

## Architectural priorities

**Interactive snapshot reads are the immediate query priority.** Separate their
session lifetime from durable captured jobs and bound data acquisition, Arrow
buffers and cancellation. Preserve an explicit source basis and current access
checks throughout disclosure. This requires a new shared contract before the
console, Board or SDKs can claim the behavior.

**Reduce shared read and write amplification.** Batch bounded native reads and
tree updates, avoid reconstructing the same metadata for each tiny step, and
measure cache budgets independently. This benefits queries, mutations, Documents
and recovery. A larger cache alone leaves publication work unchanged.

**Make bulk immutable data a shared storage capability.** The proposed boundary
persists finite blocks before atomically publishing their verified references
and source progress. It must specify availability, quotas, orphan cleanup and
recovery. Query engines and applications continue to use authorized interfaces;
they do not receive raw provider credentials.

**Choose read structures for each access pattern.** Prioritize KV point/range
indexes and hot state; Table primary-key access plus columnar blocks and pruning
for scans; Document path/sequence indexes and versioned projections for search
and analysis. Arrow result encoding alone supplies none of those storage features.
Materializations must name their source watermark, lag, freshness and rebuild
policy. Required checkpoints after history trimming remain recovery evidence.

The kernel stays generic and Zig native. Station, Fuze and application policy
remain above the public client. Adding a database engine dependency or moving
query execution into authority is not part of this direction. The
[remaining improvements](performance.md#remaining-improvements) connect these
priorities to evidence and qualification criteria.

## Size history, state and active work separately

A feed's retained events, its current book or feature state, and its active
workers are different populations. Choose PIDs for sequencing, ownership and
recovery boundaries; a row does not require its own PID or OS process. Measure
both active work and retained identities.

Keep source capture coordinates, gaps, duplicates and corrections. Point-in-time
research needs both event time and when information became available, together
with source and model versions. A later correction must not silently become
knowledge available to an earlier simulated decision. These are application
data-model requirements, not built-in temporal SQL semantics.

Bound resident pages, caches, batches and active work independently of durable
cardinality. Account for payloads, indexes, staging, replicas and recovery
evidence when measuring physical storage. Retention defaults to unlimited;
pressure never authorizes deletion or silently drops accepted input.

For constant arrival rate `lambda`, an outage of `D` seconds creates backlog
`lambda * D`. Catch-up at rate `mu` takes `backlog / (mu - lambda)` seconds only
when `mu > lambda`. As a sizing illustration, 1,000 events/s and a 60-second
outage create 60,000 events; a 1,500 events/s consumer needs another 120 seconds
while arrivals continue. This arithmetic is not a measured Transit rate and
excludes checkpoint loading and warmup. Restart time and return to freshness
are separate outcomes.

## Isolate competing work and preserve authority

Research, backfills, crawling and slow readers need explicit CPU, I/O, admission
and memory budgets so they cannot exhaust live execution or cancellation/control
capacity. Polling frequency is also offered load. Measure mixed workloads rather
than inferring isolation from separate processes.

The current realm journal serializes authority publication. Additional HTTP
replicas do not establish horizontal write capacity. Partitioning would need
explicit routing, ordering, fencing and cross-partition delivery contracts.
Per-feed order is not a global market order.

Trading remains downstream application policy. No venue, strategy, numeric money
representation or latency SLO is selected here. Durable pre-dispatch authorization
cannot become after-the-fact audit to meet a latency target. Replay never sends
live orders, and a lost remote response remains uncertain until reconciled.
See [connectors](connectors.md), [retention](retention.md) and
[architecture](architecture.md) for the shared boundaries.
