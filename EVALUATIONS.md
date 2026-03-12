# Evaluation Guide

`transit` has to prove three things together:

1. records stay correct and durable
2. append and replay stay fast
3. lineage and tiered storage do not collapse under real workloads

A single throughput chart is not enough.

## Evaluation Thesis

- No latency or throughput claim is meaningful without the durability mode.
- No lineage claim is credible without branch-correctness evidence.
- No tiered-storage claim is credible without cold replay and restore evidence.
- Embedded and server mode should share benchmark kernels whenever possible so overhead is visible instead of hidden.

## Required Benchmark Metadata

Every published benchmark or comparison should include:

- git revision
- workload name
- runtime mode: `embedded` or `server`
- storage provider and backend details
- durability mode: `memory`, `local`, or `tiered`
- record size distribution
- stream and branch counts
- hardware profile: CPU, memory, disk, network, object-store region
- operating system and kernel
- result summary with p50, p95, p99, throughput, and error count

## Core Evaluation Categories

### 1. Append Hot Path

Measure:

- records per second
- bytes per second
- append latency at p50, p95, p99
- fsync or flush behavior under each durability mode

Run with several payload profiles:

- tiny metadata-heavy events
- medium chat or agent events
- larger artifact-reference envelopes

### 2. Tail And Catch-Up Reads

Measure:

- tail wake-up latency
- catch-up throughput from recent local segments
- catch-up throughput from remote-only segments
- performance under one writer and many readers

### 3. Branch Creation And Replay

Measure:

- branch creation latency
- metadata growth per branch
- replay cost for child streams with deep ancestry
- correctness of parent-prefix replay at and before the fork offset

The bar here is semantic as well as performance-related:

- branch creation should behave like metadata publication, not data duplication
- replay of ancestor history must be byte-for-byte correct

### 4. Tiered Storage And Cold Restore

Measure:

- time to upload immutable segments
- restore latency for a cold node
- replay throughput when history exists only in remote storage
- cache hit and miss behavior during long scans

This workload must prove that object storage is part of the real design, not a checkbox.

### 5. Crash Recovery And Durability

Measure:

- committed-record survival after crash
- absence of false commits after restart
- manifest consistency after interrupted uploads or segment rolls
- ability to recover a stream head and its branches without manual repair

### 6. Mixed AI And Messaging Workloads

These are reference workloads for `transit`, not side demos.

Run mixed traces that include:

- root conversation or task streams
- many branch creations from classifier or planner decisions
- interleaved readers, writers, and cold replays
- large referenced artifacts stored outside the core record body

### 7. Auto-Threading Workload

This is the signature application-level benchmark.

The workload should model:

- one channel-like root stream
- continuous message append
- a classifier deciding when a thread boundary exists
- branch creation anchored to message offsets
- readers following both the root stream and active branches

Measure:

- classifier-to-branch latency
- branch creation overhead at sustained message rate
- replay correctness for threaded branches
- storage growth and metadata growth over time

## Correctness Requirements

The evaluation suite should fail fast when any of these break:

- offsets are not monotonic within a stream
- child streams do not exactly reproduce ancestor history through the fork point
- child appends leak into parents
- acknowledged records disappear after crash or cold restore
- cache eviction changes logical results
- server and embedded mode disagree on stream semantics

## Evidence Bar For Accepting A Change

A change should not be accepted on anecdote alone.

Required evidence depends on scope, but should usually include:

- targeted correctness tests
- before/after benchmark results on the relevant workload
- explicit hardware and storage context
- notes about durability mode and object-store backend
- migration notes if manifests, segments, or protocol surfaces changed

## Reference Environments

The repo should eventually standardize on at least these environments:

- local developer machine with filesystem-backed object storage
- Linux x86_64 with NVMe and S3-compatible object storage
- Linux ARM64 server-class environment

Mac laptops are valid local proof environments, but they should not become the only evidence source for storage or server claims.

## Comparison Discipline

If `transit` is compared against Kafka, Iggy, or another system, the report must state:

- exact workload model
- durability equivalence or difference
- payload size distribution
- storage medium
- whether the comparison includes branch or lineage behavior or only flat append/replay

Otherwise the comparison is marketing, not engineering.
