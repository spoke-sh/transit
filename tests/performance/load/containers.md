# Nightly container performance

[Performance index](../README.md) · [Runner](container_suite.py) ·
[Image selection](../../../tasks/performance_image.py)

The [scheduled workflow](../../../.github/workflows/nightly-performance.yml) runs
at 19:17 UTC, twelve hours after the 07:17 UTC nightly release schedule. It reads
the last successfully promoted nightly once and freezes its channel commit,
publication run, release/checksum identities and OCI image digest. Every scenario
uses that image. It does not compile Transit or build a replacement image from
the driver's checkout. Driver and runtime revisions are recorded separately.
An absent channel, unavailable image or mismatched identity fails selection;
there is no automatic fallback to another build.

| Profile | Placement | Aggregate container budget |
| --- | --- | --- |
| One node | One local authority and six persistent SQL consoles | 4 CPU equivalents, 6 GiB RAM |
| Three nodes | Three independent authorities; clients assigned by worker ordinal modulo three | The same total, divided equally among nodes |

Each experiment runs on one physical Docker host, on separate Linux x86_64 CI
runners. The three-node profile is client-routed independent data, without shared
catalog, replication, cross-node SQL, atomic transactions or automatic failover.
It measures resource composition and independent-authority concurrency. It
establishes neither multi-host network performance nor replicated database scaling.
Replicated and clustered topologies require executable contracts before joining
the inventory.

Containers use the published image's unprivileged user, a read-only root,
private temporary directory and persistent Docker disk volume. The server runs
headless with ordinary synchronous durability, maintenance, deadlines and
admission limits. No ports are published; persistent `docker exec` console pipes
reach the normal local SQL connection. Per-statement timings include console
processing, pipe transport and consuming verified terminal result frames. Image
pulling, container creation, client startup, warmup and independent result-oracle
comparison are outside these timings. These are closed-loop measurements, not
independently offered load or raw storage throughput.

## Workloads and evidence

Each client performs two warmup operations and 32 measured operations per case.
The deterministic fixture starts with 64 integer rows per Table. Shared-Table
writes use distinct keys so expected values do not depend on execution order.

| Workload | Independent check |
| --- | --- |
| Shared-Table point reads | Clients read different keys of the same Table on each node |
| Separate-Table point reads | Each client reads its own Table |
| Full scans | Every row and terminal count agree with the generated fixture |
| Shared-Table writes | Concurrent UPDATEs have authoritative matched/changed counts of one |
| Separate-Table writes | The same operations across independent Tables |
| Mixed load | Alternating UPDATE and read-your-write checks in each client |
| Retained restart | Graceful shutdown/start of each node, then complete verification of every Table |

All Tables are independently verified after the workload and restart. Read
failures, incorrect values/counts, missing terminal coverage, unresolved writes,
failed shutdown, OOM or missing samples cannot produce a completed report. Writes
are never replayed as new operations to repair a sample. Workers join before
cleanup. Restart is a graceful disk-reopen experiment, not a physical fault or
promotion proof.

`samples.jsonl` retains warmup/measured operations, concurrent workload wall
windows, lifecycle stages and Docker resource observations. `summary.json` and
`summary.md` require the complete verified inventory. They show sample counts,
empirical p50/p95/p99/max and verified operations per workload wall second.
These small empirical distributions establish no tail SLO. Docker CPU, PIDs,
memory and block-I/O snapshots are outside timed windows; they are not peak RSS,
allocator or physical sync counts. Heap allocation, lock-wait and sync counters
remain explicitly unavailable.

Each statement has a total response deadline and frame/byte bounds. Client exit
codes and bounded typed diagnostic codes are retained without raw stderr text.

Results are exploratory until matched campaigns establish reviewed regression
budgets. Independent hosted runners do not isolate the effect of node count;
hardware, storage, cache and competing load remain relevant. Qualification
requires matching workloads, drivers, resource limits, durability and completion
semantics. These campaigns do not change the release channel or replace existing
correctness/latency gates.

CI retains safe artifacts for 30 days, including failed/incomplete campaigns.
It uploads no installation data, keys, console recovery files or raw server logs.
Local failed disk volumes remain private for investigation; successful campaigns
remove their containers and volumes. Cancelled hosted jobs rely on ephemeral
runner teardown for final process/storage cleanup.

## Run locally

Docker and authenticated GitHub release access are preparation dependencies.
The measured server comes only from the selected published image:

```sh
python3 -B tasks/performance_image.py --output .cache/performance/selection.json
nix develop --command just test::nightly-performance .cache/performance/selection.json .cache/performance/one-node 1
nix develop --command just test::nightly-performance .cache/performance/selection.json .cache/performance/three-node 3
```

Use new output directories. Run experiments sequentially without competing
builds or performance campaigns. `--clients`, `--rows`, `--repeat`, `--warmup`,
`--total-cpus` and `--total-memory-gib` select explicitly attributed diagnostic
controls. Warmup is even so mixed read/write pairs remain complete.

For an intentional unpromoted release investigation, pass `--candidate-tag` to
image selection or the workflow's manual input. Records are labeled
`explicit-unpromoted-candidate`; they cannot establish promoted-nightly success.
The default schedule never selects this mode. A release tag's existence alone
does not establish channel qualification.

The fast profile runs [negative controls](test_container_suite.py) for identities,
image/platform mismatch, wrong values/counts, omitted/duplicate/failed samples,
incomplete restart/cleanup and the schedule offset. The scheduled workflow owns
the real image experiments; registration alone records no pass.
