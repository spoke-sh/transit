# Performance experiments: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

Measured storage, query and runtime workloads with their source-specific limits.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Installed startup publication reduction — 2026-10-31

The [startup workload](../../../tests/performance/README.md#installed-startup)
compares frozen ReleaseSafe binaries from control
`a52ea10cf74ace63634581927cd35e122ec18cb4` and candidate
`76ab6352f356c4946c676daf19c19b8c928400a3`, using clean driver source
`6addec46c7b085d09f5451b09eb9afbb11e442ff`. The candidate batches private native
pages, overlaps independent file barriers, rotates enrolled workers conditionally
and avoids rewriting unchanged derived files. These observations precede the
integration of main's branch-foundation changes; they do not qualify later source.

Each of five alternating pairs per profile creates a fresh installation, checks
an empty SQL result, inserts exactly `(1, 73)`, then checks that row through two
graceful restarts. Every restart must retain installation identity and provisioning
receipts. Headless uses standalone role binaries; the default profile uses the
embedded roles with Board and application management enabled. External readiness
includes the existing SQL/gateway gates and, for Board, a verified authorized atlas
read. Its bounded retries count toward the same launch deadline and elapsed time.

All **60 attempted launches** complete with exact result verification and no
telemetry loss. All 30 candidate launches complete in one supervisor attempt;
20 of 30 control launches do. The control records 13 extra attempts: six failed
provisioning phases and seven failed worker phases. Failed attempts and backoff
remain in the successful launch's elapsed time; the records do not establish the
specific transport/storage cause of each failed phase.

| Profile / launch | Samples per arm | Ready median, control → candidate | First verified result median, control → candidate |
| --- | ---: | ---: | ---: |
| Headless / fresh | 5 | 61.119 → 21.707 s | 62.166 → 23.062 s |
| Headless / restart | 10 | 10.411 → 3.208 s | 11.186 → 3.975 s |
| Embedded UI / fresh | 5 | 76.259 → 22.836 s | 77.316 → 23.767 s |
| Embedded UI / restart | 10 | 7.856 → 2.666 s | 9.518 → 4.074 s |

| Profile / launch | Observed readiness range, control | Observed readiness range, candidate |
| --- | ---: | ---: |
| Headless / fresh | 60.264–138.864 s | 18.270–45.317 s |
| Headless / restart | 8.099–24.154 s | 3.044–5.920 s |
| Embedded UI / fresh | 63.548–94.587 s | 20.486–35.725 s |
| Embedded UI / restart | 7.047–21.045 s | 2.460–7.397 s |

Retained worker activation has median phase time 6.225 → 0.510 seconds headless
and 5.342 → 0.536 seconds with embedded roles. Fresh provisioning has median
37.120 → 12.996 seconds headless and 42.161 → 12.944 seconds with embedded roles.
Phase totals include every supervisor attempt in that launch.

These are iteration probes on a shared Linux x86_64 host with 48 logical CPUs,
Linux 6.17.0-41, ext4 on `/dev/nvme0n1p2`, pinned Zig
`0.17.0-dev.2267+48abf1a34` and default JSON info logging. Recorded one-minute load
ranges from 14.09 to 38.58. No agent-owned build or heavy proof runs during this
campaign; other host work is uncontrolled. OS caches are not evicted. A fresh
installation is not a cold-device measurement. Both arms use unchanged configured
durability, residency and deadlines; the candidate additionally reserves eight
private page slots. Fresh worker enrollment moves into provisioning, so the
fresh worker-phase reduction alone would overstate the activation optimization.

The roughly threefold readiness improvement also reduces launch-to-first-verified
result. It does not establish the roadmap's 5-second/1-second targets, p95/p99,
aged-history recovery, allocation/CPU/I/O budgets or an SDK throughput improvement.
The [larger acceptance campaign](../../roadmap/08-gateway-architecture-and-protocol-ingress.md#installed-startup-reduction-plan--2026-10-31)
remains open; no startup regression budget is frozen from these samples.

Executed through the shared launcher in pinned `nix develop`, for each frozen
artifact prefix and profile:

```sh
python3 -B tests/runner/launch.py tests/performance/console/console_latency.py \
  "$prefix/bin/transit" "$prefix/bin/transit-node" "$prefix/bin/transit-query-host" \
  --startup-restarts 2 --binary-revision "$revision"
# Add --startup-default for the embedded UI/application profile.
```

Ignored records under `.cache/performance/startup-implementation/` retain all
twenty `paired-*.jsonl` files, the exact invocation order in `campaign.json`, and
their hashes, complete executable/helper identities and recomputed statistics in
`campaign-summary.json` (SHA-256
`2257418579335bdada495a74a8317d28d3c7bc9c45f5b3876cf2483634e7b01e`).
The driver SHA-256 is
`b5d3bd2b3676c84d5e11bf1cdf024c2d567490ed263ae48a6b706a6ec91fd76e`;
control/candidate CLI hashes are
`51e73ca3bb214d20132ec1e95203a0ce32842b211d8e721bdf76e38a98b0ffe2` /
`5b4bb6eea868a7f0f232eeeac920f00f3c9cbd726784c70449e660488ddb507d`.
These local artifacts are not distributed with the repository.

Two preliminary failures remain separate from this final-observer campaign.
The traced control receives HTTP 503 before its old observer waits for SQL
readiness; it records 5,642 completed fsyncs with 9.623 ms median duration.
Their summed 71.416 seconds span processes and are not a critical-path estimate.
`control-fsync.trace` has SHA-256
`7ebd87898a6132dfa05d4e1eec63b48056899ac7757947d8bdccabc773fc6881`.
The first default candidate probe receives Board HTTP 429 because the observer
reads inside Board's 100 ms read interval; `candidate-default-probe.jsonl` has
SHA-256 `77b7b925611fcc8bce9f43b778ec45abb7b6df54afbb19e69d3e841e7286eadc`.
The final observer counts these retryable responses within the original deadline,
requires actual readiness and still rejects denial. Neither preliminary failure
is erased or relabeled as a passing sample.

## Installed startup phase attribution — 2026-10-31

The [startup workload](../../../tests/performance/console/startup.py) measures
fresh provisioning separately from graceful retained restart, using the
[supervisor timing events](../../../apps/transit-cli/docs/server.md#logging-and-readiness).
The executed working tree is based on `0e2fba44727ca858bd1e8e4a775b62fbcf1a665d`;
the report records its pre-measurement tracked diff and every binary/helper hash.
The new `Startup.zig` SHA-256 is
`7974dd29cc65699798dee84d76cdb225c5f817ff568eb95c3c06d1a07fc123f0`;
`Server.zig` is
`e1575335c66e0bb3e365809868d0dfe610d787c92d66a4fd2896f951e78c2376`.

Executed inside pinned `nix develop`:

```sh
just test::console-latency --startup-restarts 2
```

The ReleaseSafe Linux x86_64 run uses the default headless local installation,
48 logical CPUs, `/var/tmp` on ext4 `/dev/nvme0n1p2`, and no residency/deadline
overrides or cache eviction. Initial load averages are 12.14/11.87/8.22 on this
shared host. Each start passes existing core/SQL readiness and complete typed
console readback. The fresh result is empty; a subsequently inserted `(1, 73)`
row survives both restarts along with installation identity and provisioning
receipts. No measured attempt retries or reports telemetry loss.

| Elapsed observation (seconds) | Fresh | Restart 1 | Restart 2 |
| --- | ---: | ---: | ---: |
| External time to readiness | 59.081 | 8.550 | 7.898 |
| Installation validation/preparation | 1.389 | 1.184 | 1.185 |
| Provisioning | 35.036 | <0.001 | <0.001 |
| Worker activation/initialization | 7.738 | 5.185 | 5.090 |
| Table readiness | 6.730 | 0.009 | 0.010 |
| SQL setup | 6.519 | 1.182 | 1.029 |
| Separate console verification | 1.527 | 0.736 | 0.736 |

The selected phase rows are not the whole startup; the raw report retains every
phase, total and unattributed remainder. This points to fresh provisioning and
repeated worker activation as profiling priorities. Phases include waits and
child/provider work and do not establish CPU, fsync or allocation attribution.
There is one fresh sample and two same-installation restarts, no matched control,
no cold-device condition, no latency percentile and no demonstrated speedup.
The run excludes Board, aged retained history and unclean recovery.

Local raw JSON records are retained at
`.cache/performance/startup-2026-10-31.jsonl`, SHA-256
`d9e15bf325b6219b6294b15c39c22ef43008a62b44ee3e31f1bc228771d3655a`;
the sibling `.log` preserves the original combined build/runner stdout.
These ignored local artifacts are not distributed with the repository.

Selected validation passes: `zig build test-cli-lifecycle -Doptimize=ReleaseSafe`,
`just test::server-logging`, all 13 console reporting controls, documentation
links and `just transit-docs::check`. The separate logging fixture's fresh startup
recovers after a provisioning `HttpConnectionClosing` failure; that attempt is
not part of the successful three-sample measurement above. Logging checks cover
phase timing, parent attribution, terminal/JSON/off output, retained restart and
early admission failure. No committed-source clean lane, full repository suite
or cross-language SDK performance campaign was executed.

## Pipelined batch writes, cached client-token progress, deduplicated `OperationBinding` claims, and same-turn SQL coordination — 2026-10-30

Building on `1db733365`, commits `37685ecb7`, `2b61da3cd`, and `5c4081e95`
pipeline multi-file batch writes before `fsync`, cache recent client-token
progress records in [`DirectCatalogStore`](../../../packages/zig/transit-catalog/src/DirectCatalogStore.zig),
skip duplicate [`OperationBinding`](../../../packages/zig/transit-catalog/src/OperationBinding.zig)
object writes when `.stage` has already persisted the binding, and reuse
same-turn prepared metadata and session fencing across [`transit-catalog`](../../../packages/zig/transit-catalog/README.md),
[`transit-query-direct`](../../../packages/zig/transit-query-direct/README.md),
[`transit-sql`](../../../packages/zig/transit-sql/README.md), and
[`transit-sql-service`](../../../packages/zig/transit-sql-service/README.md):

- **Pipelined batch writes before `fsync` (`37685ecb7`):**
  [`LocalFiles`](../../../packages/zig/transit-backend-local/src/LocalFiles.zig)
  exposes `stage` and `publishStaged` so [`DataAllocations`](../../../packages/zig/transit-backend-local/src/DataAllocations.zig)
  and [`NativeAllocations`](../../../packages/zig/transit-backend-local/src/NativeAllocations.zig)
  pipeline `createFileAtomic` + `writeStreamingAll` across all allocation records
  in a batch before issuing per-file `sync` + `link` and the shared directory
  barrier. [`DiskObjects`](../../../packages/zig/transit-storage/src/DiskObjects.zig)
  pipelines `prepareContent` / `publishStagedContent` and `prepareRecordName` /
  `publishRecordName` across `putImmutableBatch` while preserving single-chunk
  `.checks` elision (`needsChecksFile`) and multi-chunk `.checks` staging
  verified by
  [`local_storage_faults.py`](../../../tests/storage/local/local_storage_faults.py).
- **Bounded recent client-token cache and duplicate `OperationBinding` elision (`2b61da3cd`):**
  [`DirectCatalogStore`](../../../packages/zig/transit-catalog/src/DirectCatalogStore.zig)
  maintains a 16-entry ring buffer (`recent_tokens`) of `ClientToken.Progress`
  records populated on `publish` (`.client_token`) and `tokenRecord` and cleared
  on `recoverSinceOptions`, avoiding repeated catalog WAL reads and JSON parses
  during `client_progress.inspect` and `client_progress.update`.
  [`OperationBinding.claimStored`](../../../packages/zig/transit-catalog/src/OperationBinding.zig)
  and `claimStoredInTree` check `objects.head(object_key)` and verify the
  existing stored binding via `lookupStored` + `requireSame` before calling
  `putImmutable` / `stageObject`, eliminating two redundant `"TOPBIND1"`
  object writes on `.client_token = .bind` and `.commit_saved` after
  [`DirectTableIntentStore.stageWithBinding`](../../../packages/zig/transit-catalog/src/DirectTableIntentStore.zig)
  has already persisted the binding during `.stage`.
- **Same-turn prepared metadata and session fencing reuse (`5c4081e95`):**
  [`DirectTablePreparedDml`](../../../packages/zig/transit-catalog/src/DirectTablePreparedDml.zig),
  [`DirectTablePreparedDdl`](../../../packages/zig/transit-catalog/src/DirectTablePreparedDdl.zig),
  and [`DirectTablePrepared`](../../../packages/zig/transit-query-direct/src/DirectTablePrepared.zig)
  retain the table `Definition` metadata and `create_owner` validated during
  `prepare` and expose `bindPrepared(..., fresh_prepared: bool)`.
  [`ReadCache`](../../../packages/zig/transit-sql/src/ReadCache.zig) adds
  `acquireCurrentWithMetadata` so `Session.acquireRead` reuses the `metadata`
  from `DirectTablePrepared.prepare` without a second `.lookup` RPC.
  [`Statement`](../../../packages/zig/transit-sql/src/Statement.zig),
  [`DatabaseRuntime`](../../../packages/zig/transit-sql/src/DatabaseRuntime.zig),
  [`Session`](../../../packages/zig/transit-sql-service/src/Session.zig), and
  [`Registry`](../../../packages/zig/transit-sql-service/src/Registry.zig) add
  `bindWritePrepared`, `submitPrepared`, and `executePrepared` so ad-hoc SQL
  execution reuses the `fence`, `checkValues`, `.lookup`, and `.check`
  performed during `host.begin()` and `host.prepare()` in the same command turn.
  Per-statement instrumented RPC counts (`attempts`) drop from
  `{"local:table": 17, "local:native": 1}` to
  **`{"local:table": 9, "local:native": 1}`** across `INSERT`, `UPDATE`, and
  `DELETE` (a 47% reduction in `local:table` RPCs), and from
  `{"local:table": 16, "local:native": 3}` to
  **`{"local:table": 15, "local:native": 3}`** on warm `SELECT`.

At `5c4081e95`:

- `just test::storage-io-faults` passes **11/11**.
- `zig build test-local-storage-faults` passes **193/193** SIGKILL crash-recovery
  schedules.
- `zig build test-sql-gateway -Doptimize=ReleaseSafe` passes completely with
  **999** Table requests (`exact_token_recovery: true`, `station_sends: 0`,
  `station_turns: 0`).
- `just test::console-latency --statements --repeat 1 --cycles 1 --warm-reads 50`
  and `--statements --repeat 5 --resources` pass all statements on the shared
  Linux x86_64 host (`ReleaseSafe`, pinned Zig `0.17.0-dev.2267+48abf1a34`;
  sampled under concurrent host NVMe `fsync` load `load_average` 6.23–12.09,
  with per-statement `node_cpu_seconds` of `0.03–0.04 s` on warm `SELECT` and
  `0.06–0.07 s` on `INSERT`/`UPDATE`/`DELETE`):

| Statement | Samples | Min (ms) | Median p50 (ms) | p95 (ms) | Max (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Warm empty `SELECT` (`--warm-reads 50`) | 50 | 24.0 | 29.0 | 38.0 | 51.0 |
| Warm one-row `SELECT` (`--warm-reads 50`) | 50 | 22.0 | 29.0 | 32.0 | 51.0 |
| Warm `SELECT` (`--repeat 5 --resources`) | 6 | 31.0 | 34.0 | — | 45.0 |
| `SELECT` JSON after `INSERT` / `UPDATE` / `DELETE` | 3 | 26.0 | 29.0 | — | 29.0 |
| `INSERT` (host NVMe `fsync` load avg 6.2–12.1; `node_cpu` 60–70 ms) | 5 | 903.0 | 925.0 | — | 989.0 |
| `SELECT` after `INSERT` (`node_cpu` 80–110 ms) | 5 | 570.0 | 599.0 | — | 1646.0 |
| Changed `UPDATE` (`node_cpu` 70–80 ms) | 5 | 843.0 | 1420.0 | — | 1578.0 |
| Unchanged `UPDATE` (`node_cpu` 60–70 ms) | 5 | 783.0 | 989.0 | — | 1197.0 |
| `SELECT` after `UPDATE` (`node_cpu` 80–90 ms) | 5 | 557.0 | 726.0 | — | 1418.0 |
| `DELETE` (`node_cpu` 60–70 ms) | 5 | 911.0 | 1134.0 | — | 1997.0 |
| `SELECT` after `DELETE` (`node_cpu` 80–90 ms) | 5 | 594.0 | 732.0 | — | 1381.0 |

## Single-chunk `.checks` elision, coalesced DML intent staging, and warm `ReadCache` eviction — 2026-10-30

Building on `4adae5c04`, commits `b07e9b559`, `08699352b`, `0453946b7`, and
`8a8c1293e` eliminate single-chunk `.checks` sidecar files, directory reopens in
[`LocalFiles`](../../../packages/zig/transit-backend-local/src/LocalFiles.zig),
separate DML intent and operation-binding staging calls, and redundant
`pin_status`/`lookup` RPCs during warm [`ReadCache`](../../../packages/zig/transit-sql/src/ReadCache.zig)
eviction:

- **Single-chunk `.checks` elision and persistent `LocalFiles` directory handles (`b07e9b559`):**
  [`DiskObjects`](../../../packages/zig/transit-storage/src/DiskObjects.zig)
  already stores the complete object SHA-256 in the 60-byte `.meta` file (`TOBJ1`)
  and verifies it on `readDiskPayload`. For objects fitting in a single chunk
  (`<= chunk_bytes = 64 KiB`, which covers all B-tree pages, receipts, operation
  records, pins, intents, and bindings), the 32-byte `.checks` file is an
  identical copy of `.meta`'s SHA-256 digest. `putImmutable` and
  `putImmutableBatch` now omit `.tmp.checks` / `.checks` creation, `fsync`, and
  `rename` when `bytes.len <= self.options.chunk_bytes`, and `verifyRange`,
  `readVerifiedRange`, and `recoverPartialWrites` derive the single-chunk digest
  directly from `meta.sha256` when `.checks` is absent (while retaining `.checks`
  for multi-chunk objects `> 64 KiB` and backward compatibility with existing
  on-disk `.checks` files). This reduces single-object `putImmutable` from 5
  `fsync`s to 4 (`2n + 2` instead of `3n + 2` for batches of `n` single-chunk
  objects) and halves staging `open`/`write`/`rename` syscalls.
  [`LocalFiles`](../../../packages/zig/transit-backend-local/src/LocalFiles.zig)
  syncs `dir.handle` directly in `syncDir` instead of reopening `"."` on every
  atomic file save.
- **Coalesced DML intent and operation-binding staging (`08699352b`):**
  [`OperationBinding`](../../../packages/zig/transit-catalog/src/OperationBinding.zig)
  exposes `encodeData`, and [`DirectTableIntentStore`](../../../packages/zig/transit-catalog/src/DirectTableIntentStore.zig)
  adds `stageWithBinding` so [`DirectTableDispatch.stage`](../../../packages/zig/transit-catalog/src/DirectTableDispatch.zig)
  coalesces the `"TDI1"` (`direct-intents/<sha>.data`) and `"TOPBIND1"`
  (`data-operations/<sha>.data`) objects into a single `putImmutableBatch` call
  on first staging instead of two sequential `Backend.put` calls.
- **Warm `ReadCache` eviction `pin_status` and `lookup` elision (`0453946b7`):**
  When [`ReadCache.acquireCurrent`](../../../packages/zig/transit-sql/src/ReadCache.zig)
  replaces a live in-memory cached snapshot pin (`cached != null`), `to_release`
  already carries its verified `handle` from `.pin`. Instead of calling
  `closeOriginalPin` (`.pin_status` + `.release`) followed by a second `.lookup`
  RPC, `acquireCurrent` releases the verified handle directly via `.release` and,
  when `to_release` belongs to the same table object, advances
  `selected.position.next_lsn` by 1 (falling back to `.pin_status` + `.lookup`
  in the existing `error.Conflict` retry loop if a concurrent writer raced with
  `.release`), reducing post-mutation `SELECT` from 7 local Table RPCs and 5
  native queries to 5 local Table RPCs and 3 native queries.

At `8a8c1293e`:

- `just test::storage-io-faults` passes **11/11**.
- `zig build test-sql-gateway -Doptimize=ReleaseSafe` passes completely in
  **26.07 seconds** (down from **28.17 seconds** at `2d6ceaf0d`, **104.20 seconds**
  at `4d0a98b6b`, and `>300 s` before `9cfe38b9c`) with **968** Table requests
  (`exact_token_recovery: true`).
- `just test::console-latency --statements --repeat 5 --resources` and
  `--statements --repeat 1 --warm-reads 50 --instrument` pass all statements on
  the shared Linux x86_64 host (`ReleaseSafe`, pinned Zig
  `0.17.0-dev.2267+48abf1a34`):

| Statement | Samples | Min (ms) | Median p50 (ms) | Max (ms) |
| --- | ---: | ---: | ---: | ---: |
| Warm empty `SELECT` (`--warm-reads 50`) | 50 | 24.0 | 36.0 | 47.0 |
| Warm one-row `SELECT` (`--warm-reads 50`) | 50 | 29.0 | 36.0 | 57.0 |
| Warm `SELECT` (`--repeat 5 --resources`) | 6 | 44.0 | 45.0 | 53.0 |
| `INSERT` | 5 | 122.0 | 130.0 | 158.0 |
| `SELECT` after `INSERT` | 5 | 107.0 | 123.0 | 151.0 |
| Changed `UPDATE` | 5 | 166.0 | 192.0 | 229.0 |
| Unchanged `UPDATE` | 5 | 138.0 | 157.0 | 182.0 |
| `SELECT` after `UPDATE` | 5 | 144.0 | 175.0 | 178.0 |
| `DELETE` | 5 | 148.0 | 166.0 | 179.0 |
| `SELECT` after `DELETE` | 5 | 153.0 | 158.0 | 208.0 |

## Batched auxiliary staging, deduplicated allocation reads, and client-token index deduplication — 2026-10-30

Building on `54e176fd0` (`f9a46d2a3`), commits `461a76332`, `ff8f404cc`, and
`2d6ceaf0d` eliminate redundant object staging, duplicate allocation inventory
reads, and unchanged client-token B-tree index rewrites across the storage,
local backend, and catalog layers:

- **Direct-commit `Dml.stage` elision and batched auxiliary object staging (`461a76332`):**
  [`TableDmlIntent`](../../../packages/zig/transit-storage/src/TableDmlIntent.zig)
  exposes `expectedContentWithSchema` so [`TablePartition.commit`](../../../packages/zig/transit-storage/src/TablePartition.zig)
  computes the deterministic `"TDMLREQ1"` digest against the resident
  `self.declaration.schema.schema` without staging an unreferenced
  `table-intents/<sha>.data` object on committed direct DML (while preserving
  `Dml.stage` on rejection paths before `writeOperation`).
  [`TreeStore`](../../../packages/zig/transit-storage/src/TreeStore.zig)
  generalizes `TreeStore.Batch` via `stageObject` to coalesce auxiliary
  immutable objects (`TableEvidence` receipts and operations, `TableSnapshot`
  pins, and `.tseg` segments `<= 24,616` bytes) into the same
  `putImmutableBatch` group as candidate B-tree pages.
- **Deduplicated allocation inventory reads and directory syncs (`ff8f404cc`):**
  [`DiskWal`](../../../packages/zig/transit-storage/src/DiskWal.zig) syncs
  `self.dir.handle` directly instead of reopening `"."` on every directory
  barrier and tracks `has_metadata` per partition state so `appendFrames` does
  not reopen, stat, read, and hash `part-N.meta` on every append after metadata
  creation.
  [`DataAllocations`](../../../packages/zig/transit-backend-local/src/DataAllocations.zig),
  [`NativeAllocations`](../../../packages/zig/transit-backend-local/src/NativeAllocations.zig),
  and [`Backend`](../../../packages/zig/transit-backend-local/src/Backend.zig)
  pass already-loaded `previous`/`existing` allocation records into
  `recordTrackedWithPrevious` / `recordBatchTrackedWithPrevious` and
  `recordTrackedWithExisting` / `recordBatchTrackedWithExisting`, eliminating
  the second per-key disk read and SHA-256 verification under the inventory lock.
- **Client-token B-tree deduplication and batched operation bindings (`2d6ceaf0d`):**
  [`DirectCatalogStore`](../../../packages/zig/transit-catalog/src/DirectCatalogStore.zig)
  stores the immutable 32-byte `key.digest()` in `client_operations` and
  `client_pending` (resolved through `client_tokens` on `clientOperation` and
  `clientPage`), so `clientIndices` never rewrites `client_operations` on
  progress updates (`prior != null`) and only updates `client_pending` when
  `prior.?.pending != state.pending`.
  [`OperationBinding`](../../../packages/zig/transit-catalog/src/OperationBinding.zig)
  and [`CatalogIntentCodec`](../../../packages/zig/transit-catalog/src/CatalogIntentCodec.zig)
  add `claim*InTree` and `stageInTree` so [`DirectCatalog`](../../../packages/zig/transit-catalog/src/DirectCatalog.zig)
  flushes control-plane operation bindings and DDL intents in the same
  `TreeStore` batch as catalog B-tree pages.

At `2d6ceaf0d`:

- `just test::storage-io-faults` passes **11/11**.
- `zig build test-sql-gateway -Doptimize=ReleaseSafe` passes completely in
  **28.17 seconds** (down from **104.20 seconds** at `4d0a98b6b` and `>300 s`
  before `9cfe38b9c`, a **3.7×** additional speedup and **>10.6×** cumulative
  speedup) with **967** Table requests (`exact_token_recovery: true`).
- `python3 -B tests/runner/launch.py tests/performance/console/console_latency.py .cache/transit-latency/release/bin/transit .cache/transit-latency/release/bin/transit-node .cache/transit-latency/release/bin/transit-query-host --statements --repeat 5 --resources`
  and `--statements --repeat 1 --warm-reads 50` pass all statements on the
  shared Linux x86_64 host (`ReleaseSafe`, pinned Zig
  `0.17.0-dev.2267+48abf1a34`):

| Statement | Samples | Min (ms) | Median p50 (ms) | Max (ms) |
| --- | ---: | ---: | ---: | ---: |
| Warm empty `SELECT` (`--warm-reads 50`) | 50 | 33.0 | 38.0 | 49.0 |
| Warm one-row `SELECT` (`--warm-reads 50`) | 50 | 30.0 | 38.0 | 63.0 |
| Warm `SELECT` (`--repeat 5 --resources`) | 6 | 40.0 | 41.0 | 56.0 |
| `INSERT` | 5 | 143.0 | 148.0 | 164.0 |
| `SELECT` after `INSERT` | 5 | 128.0 | 145.0 | 150.0 |
| Changed `UPDATE` | 5 | 162.0 | 206.0 | 212.0 |
| Unchanged `UPDATE` | 5 | 152.0 | 153.0 | 174.0 |
| `SELECT` after `UPDATE` | 5 | 150.0 | 176.0 | 192.0 |
| `DELETE` | 5 | 162.0 | 177.0 | 183.0 |
| `SELECT` after `DELETE` | 5 | 177.0 | 212.0 | 214.0 |

## Batched allocation inventory, cross-tree index staging, and SQL validation trimming — 2026-10-30

Commits `9cfe38b9c`, `00fca46d4`, and `4d0a98b6b` (on `main` `54e176fd0`) reduce
per-batch allocation inventory sync calls, coalesce candidate index-page staging
across B-trees, and remove duplicate current-command authorization and client-token
lookups:

- **Batched allocation inventory persistence (`9cfe38b9c`):**
  [`DiskWal.appendFrames`](../../../packages/zig/transit-storage/src/DiskWal.zig)
  and [`LocalWal.appendFrames`](../../../packages/zig/transit-storage/src/LocalWal.zig)
  append a batch of frames to one partition in a single segment write/sync and
  metadata update (three `fsync`s instead of `3m`).
  [`DataAllocations`](../../../packages/zig/transit-backend-local/src/DataAllocations.zig)
  and [`NativeAllocations`](../../../packages/zig/transit-backend-local/src/NativeAllocations.zig)
  cache their queue head after first load, write individual marker files via
  [`LocalFiles.saveWithoutDirSync`](../../../packages/zig/transit-backend-local/src/LocalFiles.zig),
  and persist `head.json` plus a single directory sync across the batch in
  `Backend.putBatch` and `Backend.putNativePages`.
- **Cross-tree candidate index-page coalescing (`00fca46d4`):**
  [`TreeStore.Batch`](../../../packages/zig/transit-storage/src/TreeStore.zig)
  buffers and deduplicates staged B-tree pages across index trees during a
  candidate mutation in
  [`TablePartition`](../../../packages/zig/transit-storage/src/TablePartition.zig),
  [`DirectCatalog`](../../../packages/zig/transit-catalog/src/DirectCatalog.zig),
  and [`DirectCatalogStore`](../../../packages/zig/transit-catalog/src/DirectCatalogStore.zig),
  serves buffered pages on cache misses during multi-row mutations, and flushes
  them in full `putImmutableBatch` groups of up to eight pages before `publish`.
- **SQL statement validation and token-lookup trimming (`4d0a98b6b`):**
  Removes duplicate `binding.require` checks within single prepare/bind calls
  in `DirectTablePrepared`, `DirectTablePreparedDml`, and
  `DirectTablePreparedDdl`, avoids repeating `Self.lookupState` in
  `DatabaseRuntime.submit` after `Registry.execute`'s pre-prepare token check
  (while reconciling contended concurrent submissions on `bindWrite` or `bind`),
  and reuses fresh single-command preparation evidence across `Session`,
  `transit-postgres`, and `transit-mysql` while preserving revalidation before
  disclosure and across subsequent batches.

At `4d0a98b6b`:

- `just test::storage-io-faults` passes **11/11**.
- `zig build test-sql-gateway -Doptimize=ReleaseSafe` passes completely in
  **104.20 seconds** with **1,041** Table requests (`exact_token_recovery: true`),
  including the unchanged 67-row atomic `INSERT` within the existing 10-second
  node request and 300-second helper budgets.
- `python3 -B tests/runner/launch.py tests/performance/console/console_latency.py .cache/transit-latency/release/bin/transit .cache/transit-latency/release/bin/transit-node .cache/transit-latency/release/bin/transit-query-host --statements --repeat 5 --resources`
  and `just test::console-latency --statements --repeat 1 --warm-reads 50` pass
  all statements on the shared Linux x86_64 host (`ReleaseSafe`, pinned Zig
  `0.17.0-dev.2267+48abf1a34`):

| Statement | Samples | Min (ms) | Median p50 (ms) | Max (ms) |
| --- | ---: | ---: | ---: | ---: |
| Warm empty `SELECT` (`--warm-reads 50`) | 50 | 30.0 | 36.0 | 47.0 |
| Warm one-row `SELECT` (`--warm-reads 50`) | 50 | 30.0 | 37.0 | 41.0 |
| Warm `SELECT` (`--repeat 5 --resources`) | 6 | 37.0 | 40.0 | 49.0 |
| `INSERT` | 5 | 158.0 | 175.0 | 181.0 |
| `SELECT` after `INSERT` | 5 | 147.0 | 155.0 | 266.0 |
| Changed `UPDATE` | 5 | 202.0 | 221.0 | 244.0 |
| Unchanged `UPDATE` | 5 | 169.0 | 174.0 | 185.0 |
| `SELECT` after `UPDATE` | 5 | 155.0 | 201.0 | 208.0 |
| `DELETE` | 5 | 171.0 | 194.0 | 202.0 |
| `SELECT` after `DELETE` | 5 | 210.0 | 223.0 | 237.0 |

These measurements run on a shared host without CPU affinity or frequency
isolation; the account-wide token/commit envelope (`#211` W6) and
reconstructible allocation bookkeeping (`#211` W5b) remain open for the tighter
`<20 ms` interactive write target.

## Bounded publication console attempts — 2026-10-30

The [storage change](storage.md#bounded-immutable-publication-groups--2026-10-30)
reduces object-publication sync calls, but these installed-console attempts do
**not** establish a latency improvement. Both use the persistent statement driver
with `--statements --repeat 1 --cycles 5`, default service deadlines and independent
row/count checks. No owned build or disk test runs alongside the timed commands;
unrelated work continues on the shared host, without affinity or frequency control.

The control is frozen ReleaseSafe source
`61cf1ffd85833f71bb35d3f869a6863a30f51d5e`; its runtime matches merged base
`c09b0d8796b11cefe9e3885ba10c7b0badda48f0` (the intervening changes are handbook
images). It completes 12 statements, then stops on `Canceled (57014)` at the
first SELECT after DELETE. Its private installation remains at
`/var/tmp/transit-server-proof-sbhs5fbv`. The paired driver stops on that failure.

A separately invoked candidate at
`da01bb340fb909220de0d3fa315dea898e37da9a` completes 52 statements, including
three complete cycles. In cycle four it acknowledges an UPDATE in 8,428 ms, then
stops on `SqlSessionExpired` at the following SELECT. Its private installation
remains at `/var/tmp/transit-server-proof-tmu_bdq7`. Neither failed statement is
resubmitted as new work. The longer matched matrix is not run after these failures.

Raw stdout, failure stderr, source/executable/driver hashes and the control's
host-pressure observations remain under `.cache/write-publication/`.
`matched-5cycles-1-control.jsonl` has SHA-256
`eb67c2e02bff06d4d15601a98151f94ecd87e70b25f0ee5be8b161bb278e3042`;
`candidate-iteration.jsonl` has
`d4401d6acd085fc0a5aadd29ffccef010ee6903989733aff4668ed4e54496fb3`.
These are incomplete, sequential samples with different failure points, not a
completed matched comparison. Host contention is observed, not established as
the cause of either failure. No percentile, speedup, regression attribution or
milestone completion is inferred. These binaries predate the subsequent rebase
on Document storage source `a4e695de6`; they do not qualify that integrated runtime.


## Shared client resource baseline — 2026-10-29

The query/value ownership extraction preserves the installed SQL workload but
does not reduce its process or console-thread count. The
[retained comparison](../../../tests/evidence/client-foundation-2026-10-29/README.md)
records matching driver/helper hashes, exact executable/source identities and
all observations for future shared-context work. Both arms pass 47 statements,
including completion counts and independent typed readback.

Control is `4c536bc3fd3e80a5e5f473bbec70635b69aac5b9`; candidate is
`96786c46df12903a54a936828f43e492052e0fc8`. Both use pinned Zig
`0.17.0-dev.2267+48abf1a34`, ReleaseSafe and the same current definition. The
command is `just test::console-latency --statements --repeat 5 --resources`.
These revisions use the historical remote SQL gateway placement and remain
reachable through the evidence branch linked in the retained comparison. The
implementation rebase includes later node co-hosting; these measurements do not
qualify that placement or the rebased runtime.
Each owned build completes before measurement. The shared Linux/NVMe host has
48 logical CPUs, unrelated active builds/services and no affinity/frequency
control. Load averages at the start are 3.84/4.78/4.55 and 8.98/10.92/8.18.

| Observation | Control | Candidate |
| --- | ---: | ---: |
| Owned processes, including supervisor and console | 8 | 8 |
| Total sampled threads | 217 | 218 |
| Console threads | 9 | 9 |
| Console sampled RSS range, MiB | 14.88–20.16 | 14.88–19.98 |
| Total sampled PSS range, MiB | 716.72–780.43 | 723.05–790.98 |
| First console call including connection setup, ms | 285.50 | 304.27 |
| Warm SELECT median, ms (6 samples) | 97 | 104 |
| INSERT median, ms (5 samples) | 295 | 306 |
| Changed UPDATE median, ms (5 samples) | 375 | 378 |
| DELETE median, ms (5 samples) | 350 | 359 |

Statement medians use the console timer; the first-call observation uses external
elapsed time and excludes `Popen`. One installation child has an additional
thread in the candidate snapshots. This extraction adds no shared context or
new I/O pool, and the measurements do not identify a cause for that observation.
Timings are generally higher in the candidate arm under higher background load;
these small, sequential samples establish neither an isolated regression nor a
speedup. No p95/p99 estimate or new performance budget is derived from them.

The eight sampler/reporting controls pass, including independent byte/codec
expectations, malformed/missing procfs fields, PID reuse, changing trees and
process-count overflow. Resource reads happen outside timed calls but add
inter-statement work. They are non-atomic snapshots, not heap allocation counts,
allocator reserve accounting or whole-statement peaks. The console/service
profile does not qualify foreign-language native/port startup, cancellation,
joined disposal or future context fairness. Those measurements require their
own implemented owners and workloads.

## Persistent console statement latency — 2026-10-28

### Event-driven SQL recovery — 2026-10-29

The recovery change removes observed idle SQL polling, but it does **not** meet
[issue #211's](https://github.com/spoke-sh/transit/issues/211) 10–100× interactive
target. Foreground pending-accounting settlement adds latency to small INSERT,
unchanged UPDATE and DELETE in both measured rounds. Subsequent fresh reads and
changed UPDATE improve; warm SELECT is approximately unchanged. The
[retained comparison](../../../tests/evidence/sql-recovery-2026-10-29/README.md)
preserves both rounds, executable/driver hashes, raw samples and separate
instrumented evidence. [SQL qualification](sql.md#event-driven-sql-recovery--2026-10-29)
owns the correctness and recovery results.

Frozen control is `3f14da60e4ec3dd3657a430f79bfc665a3bf7f6c`; candidate is
`bfe91aa56aaa4acb1960e84eace4958f29a90703`. Each pair runs control then candidate
through the default installed persistent console, with no residency, interval or
deadline overrides. Both pairs pass all 47 statements per arm, including exact
completion/counts and independent typed readback. All five binaries in each arm
belong to its declared revision and use pinned Zig `0.17.0-dev.2267+48abf1a34`,
ReleaseSafe and the same current definition. The shared Linux x86_64 host exposes
48 CPUs on a Threadripper 3960X, with the fixture on NVMe-backed ext4. No competing
owned build or runtime proof runs during measurement; unrelated host services
remain active. CPU affinity/frequency are uncontrolled and CPU quota is not
established by the recorded root-cgroup observation.

External console elapsed-time medians, milliseconds; each mutation/fresh-read
case has five samples per arm and warm SELECT has six:

| Statement | Round 1 control | Round 1 candidate | Round 2 control | Round 2 candidate |
| --- | ---: | ---: | ---: | ---: |
| Warm SELECT | 100.0 | 102.4 | 95.9 | 95.4 |
| INSERT | 261.9 | 297.2 | 257.2 | 292.7 |
| SELECT after INSERT | 353.1 | 296.5 | 355.8 | 291.4 |
| Changed UPDATE | 416.9 | 387.8 | 421.0 | 372.9 |
| Unchanged UPDATE | 261.3 | 306.5 | 267.7 | 304.5 |
| SELECT after UPDATE | 504.2 | 402.9 | 502.5 | 392.1 |
| DELETE | 295.5 | 342.8 | 316.9 | 351.0 |
| SELECT after DELETE | 568.5 | 426.1 | 539.5 | 419.3 |

Round 1 uses measurement source `c394c4f18`; round 2 uses `113e601a2`, which
adds only a separate three-second idle observation after verified statements and
console closure. The statement workload/timing remains unchanged. Cold SELECT
is a single observation per arm: 669.9 → 802.5 ms in round 1 and 274.7 → 274.4 ms
in round 2. Zero-match observations are also single samples and remain in the
raw records. Neither round supplies tail percentiles or an isolated-host ratio.

The initial three-second idle window follows readiness and includes startup
discovery: node CPU rises 0.44 → 0.78 seconds in round 1 and 0.42 → 0.80 seconds
in round 2. The new post-statement window instead observes **0.41 → 0.05 CPU
seconds**. Separate instrumented one-repeat runs pass all 15 statements per arm;
their post-statement windows count **208 → 0 SQL upstream requests**. Startup
windows count 206 → 418 requests, consistent with the candidate completing its
bounded pin-slot discovery promptly. Readiness alone does not certify a drained
recovery backlog, and whole-node CPU includes work outside SQL.

The instrumented candidate INSERT uses 18 upstream requests, including one
pending-accounting update taking 41.9 ms and one `commit_saved` taking 101.3 ms.
These are diagnostic request observations, not an additive timing model or
uninstrumented latency. The additional foreground update explains a concrete
cost to investigate alongside the paired regressions. No durability barrier was
removed and no earlier acknowledgement was substituted for verified completion.
Co-hosted execution, the combined token/commit envelope and fresh-cut work remain
open; the 190/19 ms INSERT and 10–20 ms warm-read objectives remain unmet here.

### Shared content-directory barrier — 2026-10-29

The question is whether removing one redundant object-publication directory
sync improves the human console without changing durable completion. Runtime
control is `2dbed4e432e866aab0dccf35b7d0dc8e0cd8d565`; candidate is
`b7d2980048305c66449b340861b114bb2a0e1024`. Driver/CI source
`5595d15cce200e90949439b8436a8eac85f58e58` adds only diagnostic inventory and
test-registration updates to the candidate. The
[storage account](storage.md#shared-object-content-directory-barrier--2026-10-29)
owns barrier counts and fault evidence.

Both arms run the same persistent `.timer on` workload with five mutation
samples, six warm reads, exact values/counts and independent typed JSON readback.
Each of the four runs below passes all 47 statements. Binaries use pinned Zig
`0.17.0-dev.2267+48abf1a34`, ReleaseSafe, Linux x86_64 and local disk on a shared
host. There are no tail-percentile or isolated-host claims.

The default installed-server comparison runs **candidate then control**, with
no resident-page or worker-interval overrides, no instrumentation, the same
driver and the same three helper binaries. Both bootstrap successfully. The
earlier bootstrap failures are not reproduced here; because the control also
passes, this does not establish a bootstrap fix or explain those failures.
Empirical console p50, milliseconds:

| Statement | Control | Candidate |
| --- | ---: | ---: |
| Warm SELECT | 104 | 99 |
| INSERT | 279 | 260 |
| SELECT after INSERT | 383 | 382 |
| Changed UPDATE | 432 | 450 |
| Unchanged UPDATE | 291 | 286 |
| SELECT after UPDATE | 529 | 523 |
| DELETE | 332 | 341 |
| SELECT after DELETE | 591 | 611 |

INSERT's observed median is about 7% lower; the other cases are mixed and the
fresh-read cost remains. This is a modest local observation, not a 10×/100×
result. Load averages at startup are 8.59 for the candidate and 5.29 for control.
Both use the same Board executable (built at `5595d15cc`, UI disabled), query
host and SQL gateway. Only the node and combined CLI differ. Node hashes are
`c8f20bd79915b3e27ea7b26225b84b11da7259a147ab2d9f538b5f4221009f04`
and `7ecc0375798ca27e605130cda3b5721ad6a266faf5a9f613b14773d4ad980cad`;
CLI hashes are
`f31bbf87eaf553cf829001397e6c331bb590b039333195489cc5d4de8e599c5e`
and `dce09a62352744af028e87f463bc0797ed800ad33c9a2f421b495d8349e3e663`
(control then candidate).

Raw default-driver stdout/stderr is retained under `.cache/io-publication/`:
`default-control.log` has SHA-256
`d0f3248f6c2b36361fe9fb2451bc837bd852fb89bcc94e40993903310a42e8f8`;
`default-console.log` has SHA-256
`84e367c19e4d4e03a070d645c98d50ec8bfe4661b62f0833276cc6f94d3cb48a`.
They contain executable/driver hashes, declared binary revision, actual driver
source and diff hash, configuration, raw timers and complete result checks.
The [installed driver](../../../tests/performance/console/console_latency.py)
runs with frozen CLI/node/query-host paths, `--statements --repeat 5` and the
appropriate `--binary-revision`; `TEST_TRANSIT_BOARD_BINARY` and
`TEST_TRANSIT_SQL_GATEWAY_BINARY` select the same frozen helper paths in both
arms. This is equivalent to the default `test::console-latency` workload,
without rebuilding or replacing the frozen executables.

A separate TLS component comparison runs **control then candidate** with the
fixture's eight resident pages and 30-second request budget. `nix develop -c
just test::console-latency-tls 5` reports INSERT p50 **1,668 → 1,519 ms**, warm
SELECT **78 → 77 ms**, changed UPDATE **3,062 → 2,656 ms**, unchanged UPDATE
**1,439 → 1,316 ms** and DELETE **1,939 → 1,798 ms**. Those levels differ
substantially from the installed fixture and must not be mixed into its speedup
ratio. Only node/CLI hashes differ here too; the other five executable hashes
and statement driver hash match. The control's runtime was unmodified while
model/documentation/test edits made its workspace dirty; candidate provenance
records clean `5595d15cc` with the frozen candidate runtime binaries above.
Candidate raw output is `candidate-console.log`, SHA-256
`aab94e2185c372cafb244acd2ed83f77ada97efdff56af06dd2f5eb7f32b39f3`.
`baseline.json` is an explicitly extracted control stdout summary and binary
identity record, not the complete raw control log; it has SHA-256
`0c17d114ad12c57c0ec1db56dd758ee3d9ee7560487edbb7f842f34251990dd3`.

The measurements establish neither gateway co-hosting nor zero idle traffic.
The unchanged [native recovery schedule](../../../tests/interfaces/sql/sql_gateway_native.py)
also passes with the candidate node and matching frozen helpers: the original
67-row atomic INSERT completes within the existing 10-second node request and
300-second helper budgets. The complete schedule takes **29.64 seconds** and
records **1,329** Table requests, two lost-commit-reply crashes, two fenced
replacements, one saved-receipt recovery, exact counts/history, 17 framing
refusals, 15 exact repeats, two advanced recoveries, three revoked disclosures,
one exact capacity retry and cancelled/joined cleanup. Station sends and turns
are zero. Raw `.cache/io-publication/native-recovery.log` has SHA-256
`8a48c164ebae6197549c8265824d2c77fc781bf2681c14a473140f1096eea979`.
This is a fresh passing execution, not proof that the barrier change explains
the earlier timeout or meets the proposed two-second recovery target. No fixture
size, residency or deadline was changed.

The [gateway implementation plan](../../roadmap/08-gateway-architecture-and-protocol-ingress.md)
and [#211](https://github.com/spoke-sh/transit/issues/211) retain event-driven
recovery, coarse statement execution, physical/WAL composition and matching
installed-caller qualification as separate tasks.

### Merged runtime recovery checks — 2026-10-29

The follow-up to [PR #222](https://github.com/spoke-sh/transit/pull/222)
corrects the lost-reply schedule and records unresolved publication latency.
Source `22316f4738bc` runs on main `3cb07950e`, including PR #225's valid
maximum-path metadata fixture. Linux x86_64, pinned Zig
`0.17.0-dev.2267+48abf1a34`, ReleaseSafe binaries and local disk remain the
execution profile. The host is shared; no isolated-load or speedup claim follows.

The [SQL service recovery method](../../../packages/zig/transit-sql-service/README.md)
now withholds a confirmed committed reply until the client's existing deadline
expires. A gate prevents subsequent recovery requests from reaching authority
until the helper and node are killed and all old proxy connections are joined.
Restart must recover the same saved binding/result, rows and counts. This avoids
treating a helper's exit status as evidence that a particular reply fault fired.
Normal foreground/background traffic remains concurrent. Failed installations
are retained privately outside the temporary Nix shell.

The first revised native schedule reached both DDL and INSERT crash/recovery
checks but serialized ordinary traffic as well, then timed out in the later
capacity-retry case. Restricting the gate to the crash schedules removed that
fixture interference. The next run at `7767d856a` passed those earlier assertions
and capacity retry, then failed on the 67-row INSERT: repeated `commit_saved`
attempts reached the unchanged ten-second node deadline during
`data.object_put`. The complete schedule did not pass, and those timeouts do not
establish rejection or a terminal outcome for the original operation. Its private installation
is `/var/tmp/transit-sql-database-xuk7djsw`; the raw log
`.cache/sql-qualification/gateway-final.log` has SHA-256
`d571deadda1beed278e88fb47327c27cceab559c8ca84820487570527210177d`.

The default installed console attempt used frozen binaries from `7767d856a`,
the unchanged statement driver at `92c91cec1`, `--statements --repeat 5`, no
proxy and no cache/deadline overrides. Installation failed before any timed SQL:
native `associate` requests repeatedly exceeded two seconds and the manager
exhausted its node restart budget. There is no latency distribution from this
attempt. The original installation remains private at
`/var/tmp/transit-server-proof-xq2x465q`. Source/tool/binary identity is in
`.cache/sql-qualification/console-unproxied.jsonl` (SHA-256
`8dfe09e58306df5bd57dd86d4768b41482cf1c6fe86dd40f767c8c0deaf03ccf`);
the failure log is `console-unproxied.stderr` (SHA-256
`339c2d568a7f37fcab49b551b36ba2ef812ea5c3c7148c4885e573d32cf58bfb`).

At `22316f4738bc`, `zig build test-local-owner-recovery -Doptimize=ReleaseSafe`
passes unchanged, including the original receipts, bounded owner reopen,
atomic input/KV/block/output/effect publication, retained blocks and process
restart. This does not establish the cause of the earlier association timeout
or qualify installed bootstrap. The log
`.cache/sql-qualification/local-owner.log` has SHA-256
`889706ba0ae61943f5121e898ad6c2a9f42800c1d7391733f9d3305b7d9ca241`.
All 47 clean fast checks also pass at that source; they do not establish native
runtime or latency qualification.

The separate unproxied TLS console control completes all 47 statements with
verified values, counts and final typed readback. Runtime binaries were built
at `22316f4738bc`; the driver records `065ba33ba`, whose additional change is
the preceding evidence account. The existing component fixture uses eight
native resident pages and a 30-second native request budget. It is not the
default installed-server profile. Six warm reads and five samples of each
mutation/refreshed-read case yield these empirical p50s; the small samples do
not establish p95/p99 or a speedup against another build.

| Actual console timer | Unproxied TLS p50 |
| --- | ---: |
| Warm SELECT | 81 ms |
| INSERT | 1,676 ms |
| SELECT after INSERT | 1,882 ms |
| Changed UPDATE | 3,165 ms |
| Unchanged UPDATE | 1,494 ms |
| SELECT after UPDATE | 2,899 ms |
| DELETE | 2,026 ms |
| SELECT after DELETE | 2,885 ms |

The five INSERTs report zero milliseconds for wait and rendering, with their
entire measured duration in submit. Submit includes server preparation and
execution; it is not an exclusive storage timer. The unproxied log
`.cache/sql-qualification/console-tls.log` has SHA-256
`3e3f22ad473f5e9a7925497740cfef4e0030590aca1e77d19361d7580bba3eba`.

Driver `b83d4bc6f` adds `just test::console-latency-tls 5 --instrument` through
the existing bounded native probe. The executed diagnostic run supplies the
same seven frozen executable hashes as the unproxied run to the shared SQL-wire
driver through `tests/runner/launch.py`, with `console-statements 5 --instrument`.
All 47 statements and their traces complete, with no omitted trace events,
Station sends/turns or new pins during warm-read windows. The first INSERT takes
1,573 ms and observes 58 upstream POSTs. Its intent staging takes 105 ms, token
binding 551 ms and direct commit 833 ms. The corresponding provider elapsed
counters are 99, 543 and 814 ms. Background pending-list/inspection requests
overlap these operations; neither their durations nor nested provider/owner
counters are additive exclusive phases.

That commit's measured owner counters report 69 allocation attempts, 39 growing
resizes and a 5,030,723-byte peak. These scoped counters do not support a zero
allocation claim or measure process-wide memory. The diagnostic log
`.cache/sql-qualification/console-tls-instrumented.log` has SHA-256
`b8381980bac2f38c5731252fb3cde689b5bca61ecb0df5509ff839ca2778029b`.
Durable publication, token/accounting coordination and refreshed read cuts
remain optimization work; the 10–100× targets are not achieved by these runs.

Clean-source qualification at `75e8ec6056fc` passes all 47 fast checks, the
documentation type checks, nine documentation tests and the complete site
build. The clean interfaces lane passes TLS in 21.40 seconds and shared-client
allocation checks in 183.85 seconds, including the deliberate allocation-failure
control. Native SQL recovery then fails after 626.06 seconds including its build:
the 67-row INSERT repeatedly reaches the ten-second node deadline and the
helper exceeds its unchanged 300-second budget. Later interface tasks do not
run. The private fixture is `/var/tmp/transit-sql-database-o9dto4yj`; the clean
source and runner records remain at `/var/tmp/transit-ci-hohkp2sd`. The log
`.cache/sql-qualification/clean-interfaces.log` has SHA-256
`a2b7658fec1f82dd7ae6d5be63f9e50e2a26c37e2f5b4dcafd5633932eb65464`.

A final standalone default-installation attempt after these checks uses the
same frozen binaries and unchanged settings. It also fails during native
association bootstrap, exhausts the restart budget and produces no timed SQL
samples. Its driver source is `75e8ec6056fc`, initial one-minute load is 5.92,
and private installation is `/var/tmp/transit-server-proof-a9qerxx1`. These
observations do not establish the cause of the storage delays. Raw identity is
in `.cache/sql-qualification/console-unproxied-repeat.jsonl` (SHA-256
`db60cd022090a5479b165dee796c92b42f2e1fa609d0dd15ff0a8fa5c719f247`),
with failure evidence in `console-unproxied-repeat.stderr` (SHA-256
`989567b3d3c790f3cad212f199d48077e3a4cd1dd57e842a555aba959a85d014`).

### Resident owners, foreground completion and snapshot acquisition

This follow-up to [#211](https://github.com/spoke-sh/transit/issues/211) measures
bounded resident catalog/Table owners, exact proof/principal reuse and
acknowledged immutable-object reuse, then foreground completion of the original
accepted INSERT/UPDATE/DELETE. It preserves separate Catalog acceptance and
Table completion. The [storage account](../../handbook/internals/storage-runtime.md)
and [SQL runtime](../../../packages/zig/transit-sql/docs/runtime.md) own the
mechanisms and their authority, lifetime and recovery assumptions.

Four successful unproxied installed workloads use the real persistent console
with `.timer on`, ReleaseSafe, Zig `0.17.0-dev.2267+48abf1a34`, file-backed local
storage, eight resident native pages and the unchanged two-second native attempt
budget. The shared Linux x86_64 host reports 48 logical CPUs; starting load
averages range from 3.0 to 9.7. Each run starts with an empty Table and verifies
exact rows, schema, authoritative matched/changed counts, completion and typed
readback after the mutation families. TRUNCATE is unsupported and unmeasured.

The frozen control runtime is `67c44d32a0b7949362cfc369d504da9e74fc42ee`, with
console `2650bccce`; its product sources equal the merged PR #214 baseline.
The candidate gateway is `06246f539d3308a89d696e00f03f6c6515168464`; its node was
built at `d20f32bdd` with identical affected node sources. Other executables,
including the console, remain byte-identical. The later main integration
`6d62b8e73` changes release/model work, not these runtime owners; clean CI rebuilds
the integrated tree separately. Frozen identities are retained in
`.cache/sql-performance/pin-repair/identity.json` (SHA-256
`f75028340ac4bb0bee82b226213311135d6aa83ad3e5c700887fd7e2828db17d`).
The measurement driver has SHA-256
`b010c73b099d7bae706ac292aa7dbda4909f0027f60fc686e2f498c37ad5b3be`,
and its statement helper has SHA-256
`d274f444775c8d926ac037ce88a63469a7ea1eaa6a99bb88aaad200b80c624c1`.

Reproduction uses the [console method](../../../tests/performance/README.md):
`just test::console-latency --statements --repeat 5`, with each frozen executable
set selected through the driver's explicit paths and `--binary-revision`.
Diagnostics use a separate `--instrument` run. Control A precedes the failed
experiments and repair below; repaired A, control B and repaired B then run
sequentially. These are small samples on a shared host, not an isolated causal
experiment or tail-latency qualification. The table uses ordinary medians of
the raw timers (averaging the middle pair for six warm SELECTs).

| Console timer median | Control A | Repaired A | Control B | Repaired B |
| --- | ---: | ---: | ---: | ---: |
| Warm SELECT, six samples | 250.5 ms | 90.5 ms | 216.5 ms | 92.5 ms |
| INSERT, five samples | 501 ms | 362 ms | 2,055 ms | 338 ms |
| SELECT after INSERT, five samples | 631 ms | 478 ms | 2,217 ms | 478 ms |
| Changed UPDATE, five samples | 802 ms | 648 ms | 3,555 ms | 568 ms |
| Unchanged UPDATE, five samples | 606 ms | 357 ms | 1,949 ms | 334 ms |
| DELETE, five samples | 1,178 ms | 438 ms | 2,460 ms | 1,325 ms |
| SELECT after DELETE, five samples | 710 ms | 754 ms | 3,587 ms | 2,983 ms |

Warm SELECT improves by an observed 2.3–2.8×. Candidate DML polling wait is
0–1 ms, but durable work remains in submission. The identical controls' INSERT
medians differ fourfold. Repaired B DELETE samples are 381, 375, 2,186, 2,126
and 1,325 ms; its following SELECTs reach 5,144 ms. Repaired A post-DELETE reads
regress against control A. These data do not establish a reliable write speedup
factor, nor achieve the 190 ms/19 ms INSERT targets or 10–20 ms warm SELECT target.

All raw reports below are retained under ignored `.cache/sql-performance/` with
source/binary hashes, host load, outputs and individual samples. `comparison.json`
derives the table without discarding slower or failed experiments.

| Artifact | SHA-256 |
| --- | --- |
| `unproxied-control-a.jsonl` | `d541e412872f38bc9d0025e7423f3533f1f3ca9b9c989dfb9e6cebecd7381979` |
| `unproxied-repaired-a.jsonl` | `99f6be04c3cee3554b53bdf1773b58e417d9dde56303248b136dafefd0073282` |
| `unproxied-control-b.jsonl` | `c0c44116ecf89a725c82639f486f99cee14d7ef562b4283917d31c7d2ebff715` |
| `unproxied-repaired-b.jsonl` | `77bddc664e7efa797d06b5e691c0131178f707c45b5b26944b31edaa23236d00` |
| `unproxied-candidate-a.jsonl` — before pin repair | `e268eed148ea29125bc49b096881c74f01663519db48f43ea70bcb13ed34a8a9` |
| `diagnostic-candidate-a.jsonl` — before pin repair | `cdbf003b7fee872e9d255d01adb70e201f25cd95e683476657a2bf9b104e122c` |
| `diagnostic-final.jsonl` — bootstrap failure | `519cc344f6fb7cf38967d30c913a4c6c8135a7fe829a7911c84b3604b43fa6a5` |
| `diagnostic-final.stderr` | `6cc70c9001c2aeaf6888ac9b48e010605ea0da8b5356af695c8e17fff2c9ea03` |

The pre-repair unproxied candidate fails a read after its fifth INSERT. A separate
diagnostic run identifies `table:pin` returning `Conflict` with underlying
`TableDataChanged` after the third UPDATE. The new bounded failure trace preserves
completed native work even when the console statement fails. One preceding
INSERT window includes 36 native attempts: token binding takes 51.88 ms,
`commit_saved` 109.10 ms and staging 23 ms, with provider work of 45.17, 90.39
and 16.45 ms respectively. Background and overlapping work are included; these
are not additive exclusive wall-time stages. The evidence points toward remaining
Catalog and durable publication cost, without proving a hardware sync floor.

The snapshot repair permits at most four pre-result acquisitions. A conflict
alone is insufficient: current inspection must prove the original pin absent at
a strictly later frontier in the same partition, ruling out both earlier success
and delayed acceptance. Closure is recorded before another identity is prepared;
the exact object/definition is revalidated. Accepted or uncertain pins retain
their identity, and an opened SELECT never restarts or changes its cut.

The deterministic session schedule injects an actual concurrent INSERT between
lookup and pinning, verifies absence before reacquisition, and independently
checks the returned rows. Its second schedule replaces a successful pin reply
with Conflict and requires all later attempts to preserve the original owner and
frontier. The old gateway fails the first schedule (`pin-negative-control.log`,
SHA-256 `576e07609d605a094d678c746e2efae918910c41a12a072c99c4f929e3216761`).
The repaired gateway passes the full `sessions-basic` profile, including lost
commit reply, immediate terminal counts, no-op/empty outcomes, retry of an old
DELETE after reinsertion, revocation and restart (`pin-repair-sessions.log`,
SHA-256 `30ea39a8fa9dc4096fa22506c65582873a9713d9292789933a27eec6d2eb07f0`).
That component fixture uses a 30-second native budget, distinct from the installed
measurements. Driver provenance reports `00938220c` plus the patch later committed
as `06246f539`; the frozen product identities above identify the actual binaries.

The later instrumented installed attempt fails during bootstrap: native
authorization exceeds the unchanged two-second deadline and startup exhausts its
restart budget. It produces no SQL samples; its installation remains at
`/var/tmp/transit-server-proof-0xbmo9oy`. Successful unproxied runs do not erase
this failure or establish its cause. Earlier exploratory resident/combined-owner
bootstrap failures are retained at `/var/tmp/transit-server-proof-6cxqgw8m` and
`/var/tmp/transit-server-proof-nodlxutr`; the identical combined binary later
passes an instrumented three-repetition run. Installed startup and broader
latency qualification remain open in #211.

Focused owner checks pass: all 129 core package tests; the two-test local catalog
policy schedule (including cold/warm reuse, external pin/release suffixes,
retained reads, revocation, control capacity and zero budget after teardown);
and three selected backend/proof-cache tests covering first-publication faults,
same-epoch reuse, reopen/new epochs and exact proof keys. Their logs are
`principal-tests.log` (SHA-256
`d6770e80319c31a43897098b6fb57465a19646b099ba1566f9b32dda6f9ca147`),
`candidate-build-policy.log` (SHA-256
`971fa108680ed1f4fd73b9e6490efa76fb969c3c0dcc7f832ae498fa15ea8146`),
and `candidate-storage-tests.log` (SHA-256
`691c2e08b2815179e4dfd51d02b53374e1ddc635b27f17e18d5ae26052cc8342`).
These are focused checks of the respective implementation commits, not a full
installed or repository qualification.

The final focused `sessions-basic` rerun passes at clean driver source
`9ac5ad55d`, with the frozen candidate binaries above. It includes `f01dafdcf`'s
oracle clarification: cleanup may repeat the original pin request, but every
attempt must retain the exact owner and expected frontier. The log is
`final-sessions-basic.log` (SHA-256
`e767ec975bd1abd16a2cd46dd6c1d93b4e4b75fda3d86ab891784b42ac614055`).

Clean `interfaces` at `6d62b8e73` passes SQL TLS (21.68 s), result allocation
checks (180.55 s), gateway recovery (268.59 s) and PostgreSQL/MySQL gateway
checks (887.27 s). The result-allocation negative control detects allocation;
Unix/HTTP/HTTPS warm paths have zero measured backing-memory events. The wire
checks include lost/detached writes, cancellation, revocation, credential and
certificate rotation, capacity, retained data and a 40 KiB row. The following
session task times out after 1,800 s while its helper builds the Document source
fixture, before session assertions. Its node continues accepting setup work,
but no completion is inferred. The lane fails after 3,243.70 s; later interface
tasks are not reached. The clean checkout is `/var/tmp/transit-ci-zyqvd4b4`;
`clean-interfaces.log` has SHA-256
`4792b4d8e195a2287e57d7e25577892d9926db0e3fd2bbea4a60848dc6c0f538`.
The focused session pass does not replace this failed lane.

Clean `growth` actually checks out `9ac5ad55d`, as recorded in
`/var/tmp/transit-ci-w3dfas67/preparation.json` (the outer wrapper captured
`f01dafdcf` just before the documentation commit and checkout). Thirteen tasks
pass, including file-query bounds, native/Station recovery, local-owner recovery,
payload service, the full local catalog check (1,248.09 s) and direct Table
service (328.63 s). The catalog check observes eight cold versus zero warm WAL
frames, maintenance of four Tables, retained graph collection and automatic
collection/revocation after restart. The direct service covers 2,125 typed calls,
CRUD/DDL, predicate UPDATE/DELETE, original receipts, pin-journal cleanup,
retained pins across rewrite/drop/recreation, three restarts, current denial and
reserved-control rejection.

The following maintenance task fails during its 256-row fixture preparation with
`AuthorityTimeout` under the caller's unchanged 30-second deadline. Its proxy
then encounters a daemon-thread stderr lock error during interpreter shutdown;
the process abort is not a successful proof. The task fails after 56.06 s and the
lane after 2,479.44 s. The fixture remains at
`/var/tmp/transit-table-maintenance-oz7de1uc`; `clean-growth.log` has SHA-256
`58e7cbf4ee4b4ff08ec960ffaf388811e83c97509146fe7149cb66ea6584eb98`.
Later growth tasks are not reached. This failure is neither attributed solely
to shared-host load nor replaced by the earlier component maintenance pass.

Clean `core` at `342c75151` passes the full foundation check (including native
components and console lifecycle), properties/simulation, package builds (39/39),
Zig SDK, packaged runtime boundary, SQL wire contracts and C ABI. It then fails
the Station invalid-input check: after a briefly quiet mailbox, the next worker
turn succeeds where the test expected failure. The assertion does not establish
which accepted input that turn consumed. The lane fails after 3,743.14 s;
later tasks are not reached. The checkout is `/var/tmp/transit-ci-gpydibfg`;
`clean-core.log` has SHA-256
`a62521dc1ad05d6d05417435923fb95da1096e45e6e2db561772df47bee210c6`.

A focused rerun with an exact-input oracle stops earlier, during captured-query
progress, with `ConnectionRefusedError`. Node logs show `page.stage` cancellation,
`WalRecoveryRequired` and owner reopen immediately beforehand. This run does not
validate the oracle repair or establish the connection failure's root cause.
`station-exact-input.log` has SHA-256
`b82d4798a7549d391ff6615bdb8de3c790f87f4be4f7ccbefdfc3d5cac3b60cc`. The deadlines are unchanged.

Integration of main `78ac1df3c` includes storage observations/settings, smaller
Table staging buffers and transaction workspaces, including a current-definition
cutover. The frozen console measurements and preceding passes above describe
their recorded revisions; they do not qualify this newer integrated runtime.

Clean fast checks at `9ac5ad55d` pass all 45 checks, including 7,569 local links
across 664 files; the isolated checkout is `/var/tmp/transit-ci-0qm1r7fa`.
The pinned documentation site check also passes types, tests and the production
build. Their logs are `final-fast-check.log` (SHA-256
`019cbf8e92b5afbc285aeeff9e4abd7247ae66edf24b0174b36285151708fb1a`)
and `final-docs-check.log` (SHA-256
`154591794c1137024f158dbe680447805e34915b06b64a6ac514f9eeccb1d6a9`).

### Write-lifecycle completion experiment

The follow-up to [issue #211](https://github.com/spoke-sh/transit/issues/211)
extends the persistent console workload to changed, unchanged and zero-match
UPDATE, DELETE, and typed readback after each mutation family. Exact rows,
schema, matched/changed counts and verified completion remain acceptance
conditions. TRUNCATE is modeled as a proposal and is not executed by this test.
`just test::console-latency-tls 5` runs the same workload in the existing
unproxied TLS component fixture, separate from the default installation.

A foreground-completion experiment (`881e4d97c`) drives the accepted DML before
returning submission, rereads pending/cancellation state and skips redundant
pre-commit inspection. The comparison uses frozen ReleaseSafe binaries from
`7cd91723efc3f7182ba757c202a8818633642b13` (whose tree equals merged PR #210),
and the experiment binaries identified in the raw report. The measurement
driver at `d0b552443616e6b7667b73406d266f86648b6784` has SHA-256
`a770734b0f28375c768bec6e9259374c1a67f3b548b2667dc9d20874aa34d078`.
Both complete workloads pass their independent oracles on the same shared
Linux host, with file-backed local storage and a 30-second native request
budget. These sequential five-write samples do not establish isolated causal
effects, tail latency or a service guarantee.

| Console timer median | Merged-build control | Foreground experiment |
| --- | ---: | ---: |
| Warm SELECT, six samples | 196 ms | 197 ms |
| INSERT, five samples | 1,949 ms | 3,150 ms |
| SELECT after INSERT, five samples | 2,131 ms | 1,905 ms |
| Changed UPDATE, five samples | 3,606 ms | 4,489 ms |
| Unchanged UPDATE, five samples | 1,852 ms | 3,172 ms |
| DELETE, five samples | 2,406 ms | 3,710 ms |

Foreground submission removes the reported wait phase but does not remove
durable publication work. It regresses INSERT in this comparison; commit
`9277de972` removes foreground execution and retains only the direct
`commit_saved` recovery transition, which resolves the original receipt before
execution without another inspection request. No 10× or 100× improvement is
claimed from this experiment. Consolidating Catalog acceptance, data commit and
pending settlement, and deferring immutable publication remain separate work.

Raw reports under `.cache/write-lifecycle/` are
`control-final-statements.jsonl` (SHA-256
`33aa173662e2ad5b062a4dc7b4763bfdb675c664863bc4a447172fe36070b76f`)
and `candidate-statements.jsonl` (SHA-256
`e748570434d18cc53f535181d8c36b8895b2ccadd156f663fa2536308579e7a4`).
Each includes executable hashes, source/driver attribution, host load, individual
timers and exact outputs. The earlier `control-statements.jsonl` uses a prior
driver without typed readback between mutation families and is not the matched
control above.

The default installed-server attempt still fails before SQL readiness: native
`associate` requests exceed the unchanged two-second attempt budget, then
startup exhausts its restart budget. `installed-statements.jsonl` (SHA-256
`8cc93afb03a7b5322cc86eac1da897860ec158330112fecbcebeae253cb731ab`)
contains provenance but no completed statement timings; the private failed
installation is `/var/tmp/transit-server-proof-xecspoo2`. The TLS component
comparison does not qualify that installation path.

The first basic-session attempt passes the injected lost `commit_saved` reply
and original terminal-count assertion, then fails during real console completion:
an idle `touch` receives `SqlSessionBusy` after cancelled assistance and exits
the terminal. Its retained log is `sessions-basic.log` (SHA-256
`bff43e484a58ad6af71d5ec2fd88e73d39463f17c2a0d02d0d4b304d0719b0df`).
A deterministic editor peer reproduces the exit with the old binary; the repair
retries only `touch` on the next idle turn, preserving the session and leaving
expiry/access-denial handling intact. The negative-control log is
`keepalive-control.log` (SHA-256
`4894e4cb5f008956960895473f2d1db2612133eb00e8a717303cc47205026b56`).

The complete console-history/editor/outcome suite then passes with the repaired
pre-rebase binary, including two busy renewals, a successful renewal and a
subsequent access denial without session reopening or SQL submission. Its log
is `keepalive-final.log` (SHA-256
`2b7a6d3087d87b011dbd47bdc027dd964c653064e2a534397f07c0f41fbbb122`).
An earlier attempt exits 130 in the multiline Ctrl-C schedule before reaching
that case; `keepalive-final-signal-failure.log` retains the failure. No runtime
change occurs between these two attempts.

Clean interface qualification at `e983417a1` passes TLS and SQL allocation
checks, then stops at the SQL gateway recovery oracle's prohibition on any
repeated `commit_saved` RPC. The revised oracle distinguishes an explicit
`execute` from resolution through `commit_saved`: the latter must carry the
identical complete frozen reference and return the identical original durable
receipt, with exact rows and mutation counts checked independently. The failed
checkout and logs remain at `/var/tmp/transit-ci-d9x508hi`; this attempt is not
reported as a lane pass.

After rebasing onto `ee5c31c80`, clean interfaces at `093b33794` passes TLS and
allocation checks and the SQL gateway's lost-reply, fencing, exact-value/count,
retained-history and original-token capacity schedules. Its subsequent 67-row
INSERT exceeds the unchanged ten-second authority budget with `AuthorityTimeout`;
the enclosing gateway task and interface lane fail. The source, command and
failure records remain in `/var/tmp/transit-ci-22fw2j1a`, and the local log is
`rebased-interfaces.log` (SHA-256
`7f6c9b0b7f0a09baef4cc4ae696d6449d25ffca9e9f01465d58b7230232bdd44`).

The multiline Ctrl-C failure also recurs with the rebased console. Prompt
rendering can finish writing visible bytes while its joined output task is
still interruptible. `2650bccce` handles that interruption through the same
clear-draft transition as input; termination signals still exit. The complete
terminal suite passes with that binary, including 32 repeated clear-draft
checks and the busy-keepalive case. `redraw-final.log` retains the result and
`final-binaries.json` identifies the compiled console and matching runtime set.
The repeated schedule is not a deterministic injection of every rendering race.

### Rebased recovery-path comparison and installed-server limit

The final focused `sessions-basic` profile passes with runtime source
`67c44d32a0b7949362cfc369d504da9e74fc42ee` and console source `2650bccce`.
It covers the lost native commit reply and original identity/counts, typed
native/PostgreSQL/MySQL reads, outage and revocation schedules, real TLS console
completion and restart token resolution. The driver reports a dirty checkout
because qualification prose was being edited; the compiled product binaries
were unchanged. `rebased-sessions-basic.log` has SHA-256
`d1e207ac35dc156fafbca0186aa1b393919a7e12d5b9f6624f04e28d96de5cc1`.
This focused pass does not replace the failed clean interface lane above.

Three sequential unproxied TLS workloads compare the final recovery-only change
with the gateway built from `ee5c31c80`. All other executables are byte-identical;
`final-binaries.json` and `control-current/identity.json` retain their identities.
The candidate gateway has SHA-256
`f503b3f119a576e9bb4566f1d2f47f5b8c65c27d39cd68b44ca37a66384bf1d5`;
the control gateway has SHA-256
`18d1d56acaa7f74fb7795eb0b6f5154355059c03164bd2d1ba38b8ce05e56f76`.
The console and statement driver are identical across all three runs. Candidate
A uses driver source `e303e8f6`; candidate B uses `68fc4d681`, whose intervening
change only strengthens the model's atomic-visibility invariant. The fixture
uses file-backed storage, eight resident pages and a 30-second native budget.

| Console timer median | Candidate A | Current-main gateway control | Identical candidate B |
| --- | ---: | ---: | ---: |
| Warm SELECT, six samples | 222 ms | 212 ms | 229 ms |
| INSERT, five samples | 2,313 ms | 1,123 ms | 470 ms |
| SELECT after INSERT, five samples | 2,503 ms | 1,349 ms | 606 ms |
| Changed UPDATE, five samples | 3,651 ms | 2,138 ms | 750 ms |
| Unchanged UPDATE, five samples | 2,196 ms | 1,154 ms | 520 ms |
| DELETE, five samples | 2,544 ms | 1,599 ms | 718 ms |

All three workloads pass exact row/count/schema and typed-readback checks.
However, the identical candidate's INSERT medians differ by almost fivefold;
its second INSERT range is 444–2,204 ms. Other work is active on this shared
host. These runs establish neither causal benefit nor regression from removing
one inspection RPC, and the fastest run is not an achieved latency target.
Warm-read stability does not identify the source of durable-path variation.

The raw reports under `.cache/write-lifecycle/` retain per-statement phases,
outputs, binary hashes and host load:

| Report | SHA-256 |
| --- | --- |
| `final-statements.jsonl` | `3a051191611e4e89e3c113aca1cb644ce715873b6f294a5cb3cce8aef09db535` |
| `control-current-statements.jsonl` | `71f90285960ba296875a1521dfd6fab5a991937236095480389782ad6191356f` |
| `final-repeat-statements.jsonl` | `76fa5117d1bd3e701f26607ebbde9a80862b5ffbeff386592cd1cb6bb2bbacbe` |

The final default installed-server run at clean driver source `68fc4d681`
reaches readiness and completes three INSERTs (406, 452 and 475 ms), two
read-after-write checks and three warm SELECTs. The SELECT immediately after
the third INSERT fails with `Conflict (55000): SqlServiceError`; the workload
stops before UPDATE/DELETE and before typed readback. Its default two-second
native attempt budget and resident-page configuration are unchanged. This is a
**failed** workload, not a qualified 452 ms INSERT result. The logs do not identify
the underlying conflict, and no baseline equivalence or harmless retry is
assumed. The private installation remains at
`/var/tmp/transit-server-proof-lfepi0hk`. `final-installed-statements.jsonl` has
SHA-256 `221da1629f8296426baecd43e5c62a0c1321c4d9ce0bbf18e728230d435a9ec2`;
its `.stderr` has SHA-256
`141ce930e7ddb7aa908efaea60cb2ec32e860aa0a7ff33d824d3a26db39d77c9`.
The installed conflict, broader authority timeout and controlled latency
qualification remain open in [#211](https://github.com/spoke-sh/transit/issues/211).

### Original decoupling comparison

The [console workload](../../../tests/performance/console/statements.py) exercises
the actual persistent `transit console` with `.timer on`, the human table
renderer, five single-row INSERTs, exact contents after each write, warm reads
and a final typed JSON readback. It asserts verified completion and mutation
counts. Instrumented runs also reject Station sends/turns and new pins during
warm reads. The [method](../../../tests/performance/README.md) extends the database
decoupling latency investigation; it does not establish a latency guarantee.

The control is committed `27bb9cd7ba5deed5797703ee35624f641d81d6f5`. The initial
candidate is that source plus the frozen working patch
`fb796bc2efb95e1598071443f18b295f3ff6759e42ba78f6d3d9c6cf6b704d79`, retained as
`.cache/console-perf/candidate.patch`. The final candidate includes the denial
ordering repair below, with patch
`af6d399d87b71aaca5d5d5b98e141721211d1cb66dac7bb7faea5c7a7e04f7c4`
retained as `.cache/console-perf/verified.patch`. All use ReleaseSafe with Zig
`0.17.0-dev.2267+48abf1a34` on Linux x86_64. Executable hashes are in the reports;
the new workload helper is identified separately by SHA-256
`9a95dc1a8119d34b9eba86c24418a17401a9e10c4adfcf287a68022e1fdebc7b`.

Sequential unproxied TLS runs reuse the existing SQL wire fixture, its eight-page
native cache, file-backed local storage, request budgets and setup binaries.
Only the node, SQL gateway and console under comparison differ. The retained
experiment adapter `.cache/console-perf/wire_statements.py` calls the same workload
through that fixture; its SHA-256 is
`8c8e94d8c0519ce97080fbce1ec75e8293b2bb4db7f530f2b6766b09cd2314b1`.
This is a component-launched TLS comparison, separate from default
`transit server` installation. Other users' validation was active on the host;
these small samples cannot attribute every timing difference to the patch.

| Console timer observation | Control | Final candidate |
| --- | ---: | ---: |
| First empty SELECT, one sample | 2,581 ms | 1,717 ms |
| Warm SELECT, p50 of six | 386 ms | 188 ms |
| Single-row INSERT, p50 of five | 2,537 ms | 1,912 ms |
| SELECT immediately after INSERT, p50 of five | 2,661 ms | 2,126 ms |

All three complete workloads pass their independent values/counts/completion
oracles. The initial candidate has warm-read p50 203 ms and INSERT p50 1,965 ms,
with one post-write SELECT at 3,552 ms. Variation between candidate runs remains
unisolated. Final rendering takes 0–1 ms, INSERT submission 845–871 ms and
completion observation 1,027–1,076 ms. Server preparation and execution belong
to the client-observed submit phase, not the zero-valued client compile phase.
The final post-write SELECT range is 2,091–2,156 ms; warm-read gains do not eliminate
cold acquisition or replacement costs.

A separate initial-candidate proxy run passes the same assertions, observes zero
Station sends/turns, zero warm-read pin requests and one `commit_saved` per
INSERT. The first INSERT window contains 79 owner-work responses and 1,779 ms
of accumulated provider time. Its direct commit request takes 1,072 ms and
Catalog token binding 587 ms. Background recovery and overlapping requests are
included; these durations are not additive exclusive SQL stages. The evidence
locates substantial remaining cost in durable publication and Catalog control
work, rather than console rendering or SQL actor turns.

Raw reports under `.cache/console-perf/` are `wire-baseline.jsonl`
(`b5eed5de6db0e807bb3eed87831f4129d6747d4792b96326e87a5ea9f7a59b80`),
`wire-final.jsonl`
(`bb1a042c25758bdb7fb61660da23788dbd77b32e93a01c82acc2364d91a1727b`),
`wire-final-instrumented.jsonl`
(`707fa5bbdaed62d25226c7851e706237c69d95b2a0ca0835f3470c23aea045e9`),
and the final-build repeat `wire-verified.jsonl`
(`476a3e15e22fd7183f7e43d64bc7e53e9193693a76c9bbb009b826bdd78a3817`).

The registered default-installation reproduction is
`just test::console-latency --statements --repeat 5`; run `--instrument`
separately. Three initial-candidate attempts exhaust the existing native
bootstrap retry budget before SQL becomes ready. A diagnostic fixture captures
storage page staging consuming the two-second native attempt budget. The clean
control reaches a 707 ms cold SELECT and a 2,336 ms first INSERT, then fails a
later SELECT with `Conflict`; its prefix is not a completed benchmark. These
failures remain in `baseline.jsonl`, `final*.stderr` and their retained private
installations. No deadline is increased or failed SQL replayed to manufacture
a passing latency sample.

The basic session schedule exposes a denial-ordering race: role revocation
withdraws background recovery readiness, which can mask `AccessDenied` behind
`GatewayOwnerUnavailable`. The final repair checks credentials and namespace
authority first, retaining readiness and activation fencing before execution.
The test now waits for the public recovery endpoint to become unavailable before
fetching the protected batch. The complete `sessions-basic` schedule then passes:
data, empty terminal results, DESCRIBE, catalog, storage and EXPLAIN disclose no
rows after revocation; the original token survives service restart; three-second
authority outage recovery, independent SCRAM, concurrent sessions, wide values
and the real TLS console checks pass. The log is
`.cache/console-perf/sessions-basic-verified.log`, SHA-256
`ce8609fe2afc400f77d8a909e9e7bf996d4fcbad9875e1b0dd446423b1fd41bb`.

Package checks pass for memory, SQL, SQL client, SQL service and SQL gateway;
focused Catalog signing/client-token/quota and storage-object tests also pass.
Python console/probe oracles, test layout, Zig formatting, whitespace and
documentation links pass. Broader attempts remain incomplete: the full session
schedule times out while seeding Document source change 3/13; direct Table
recovery passes lost-pin, warm reuse, replacement cleanup and conditional-name
assertions, then its larger recovery function hits a stack probe (14.8 MiB frame,
8 MiB shell stack); the final native SQL schedule times out on `commit_saved`
under its unchanged ten-second node budget. Logs are `sessions.log`,
`direct-table.log` and `native-verified.log` under `.cache/console-perf/`.
These prefixes do not establish full-suite passes or power-loss qualification.

PR preparation rebases the candidate onto
`6c4c6843fc3a6d6e629a28366f549aacd7192bae`, which already contains the denial-ordering
repair and its deterministic session checks. The memory reconciliation preserves
that base's lazy slab initialization: the first erasure covers unknown initial
contents, and later erasures cover the tracked high-water range. Memory, SQL,
SQL-client, SQL-service and SQL-gateway package tests, focused Catalog signing and
storage-object tests, Python console/probe controls, layout and documentation
checks pass on the rebased implementation. The timing table remains evidence for
the original frozen patches; it is not a new measurement of the rebased source.

## Result reserves and codec costs — 2026-10-28

The [retained automatic comparison](../../../tests/evidence/result-reserves-2026-10-28/README.md)
asks whether fixed result workspaces eliminate backing growth while preserving
the encoded workload and staying within a frozen timing budget. Control
`a87d7ac1c` precedes the reserve implementation; candidate
`00dce3a06225bddc7529be046a3d27adb1221446` includes it. Both use the pinned Zig
compiler in ReleaseSafe. The method alternates five paired processes on CPU 47,
with one finite warmup and five measured repetitions inside each process. Each
sample handles 10,000 independently checked rows with seven scalar/NULL columns.
Medians are computed within each process, then across the five processes.

The frozen budget permits at most a 5% median-time regression in each case,
zero native backing allocation/growing-resize/remap attempts, and at most 16 MiB
reserved by each native encoder/decoder owner. Malformed or incomplete reports,
changed framed workloads, allocation attempts and invalid timings fail the gate;
the runner's negative controls exercise those refusals. Results are:

| Case | Control median ms | Candidate median ms | Candidate/control |
| --- | --- | --- | --- |
| PostgreSQL text | 34.188 | 33.550 | 0.981 |
| PostgreSQL binary | 21.993 | 21.598 | 0.982 |
| MySQL text | 12.382 | 12.923 | 1.044 |
| MySQL binary | 10.575 | 10.635 | 1.006 |
| Native one-row encode | 784.251 | 601.380 | 0.767 |
| Native one-row decode | 423.782 | 405.350 | 0.957 |
| Native 32-row encode | 597.037 | 571.741 | 0.958 |
| Native 32-row decode | 388.916 | 381.278 | 0.980 |

All eight timing cases pass. Native backing attempts are zero in every measured
repetition. Each encoder/decoder retains 8 MiB, charged even when empty. Internal
reservations and reuse remain visible separately from backing growth; the decoder
borrows its input frame, whose maximum size is separately recorded. Frame sizes,
batch counts and logical values agree across arms. No wire limits are increased.

The host is a 24-core/48-thread AMD Threadripper 3960X. Background user work
remained active, with one-minute loads of 15.68 to 19.05 at the recorded endpoints.
This supports the scoped local gate, not a universal speedup. Unmatched preliminary
samples had included a slower full-batch encoder; they lack the paired conditions
needed to establish a regression. The earlier larger-batch first-output cost in
the following account remains relevant and is not resolved by this codec result.
Source reads, authority, service scheduling, sockets, TLS, rendering, OS allocation
and end-to-end latency are outside this comparison. Reproduction, binary hashes,
all raw repetitions and the fixed budget/driver identities are retained with the
report; the owning method is the [codec guide](../../../tests/performance/results/README.md).

## Statement result batching and consumption — 2026-10-27

The [retained reports](../../../tests/evidence/sql-results-2026-10-27/README.md)
compare frozen control `7d30e2c502c29243424617155b51296d6d778861` with candidate
`8a866f513a015f7487f67e07bbcaa82fa48b6275`. Both contain the same early live-storage
cutover: storage/core/log/object-store sources are unchanged between the arms.
Both use Zig `0.17.0-dev.2267+48abf1a34`, ReleaseSafe, native disk storage and the
same measurement driver. Subsequent rebasing adds documentation/guidance only.
The 24-core/48-thread AMD Threadripper 3960X host has 130,380,296,192 bytes of RAM;
background user processes remain active. Owned builds and disk proofs finish
before the sequential measurements. Recorded one-minute loads range from 6.9
to 9.0. This is one matched pair with repeated queries, not isolated or randomized
host qualification.

`console_latency.py --rows 70 --repeat 3 --representations` seeds deterministic
integer/text rows, verifies exact console output, then independently decodes native
results. Historical mode is explicit and confined to the frozen control driver.
There is no production fallback decoder. All 46 native cross-run comparisons,
including the separate instrumented and slow-consumer cases, match schema hashes,
row multisets, counts and canonical cell bytes. Row order is not assumed for
unordered SQL. The three native timing samples per query give these medians:

| Query | Batches control → candidate | First batch ms | Terminal ms | Response body bytes control → candidate |
| --- | --- | --- | --- | --- |
| 70 integer rows | 9 → 3 | 429 → 698 | 2,120 → 1,572 | about 12,900 → 2,688 |
| 70 integer/text rows | 9 → 3 | 439 → 736 | 2,088 → 1,610 | about 23,200 → 8,384 |
| 70 grouped count rows | 71 → 3 | 3,398 → 7,174 | 22,347 → 12,104 | about 63,900 → 3,392 |
| DESCRIBE, two rows | 3 → 1 | 197 → 339 | 508 → 340 | about 2,240 → 2,560 |
| SHOW TABLES, two rows | 3 → 1 | 160 → 352 | 359 → 352 | about 1,450 → 832 |

Candidate data batches are 32 + 32 + 6, matching `ceil(70/32)` without an empty
terminal fetch. The grouped control emits 70 one-row batches and an empty
terminal: it detects the amplification that the new batching removes. The
canonical payloads remain 630, 5,635 and 1,260 bytes. Binary framing removes most
result-body expansion on data queries, but DESCRIBE grows because its small
payload does not amortize the typed columns, alignment and observation evidence.
Larger batches delay first disclosure in every sampled query. These costs are
part of the result, not hidden by the improved completion times.

Separate console measurements include process startup, rendering and pipe output.
Median total/first-output milliseconds are 2,201/488 → 1,688/762 for narrow text,
2,254/506 → 1,681/783 for wide JSON and 19,775/3,037 → 9,687/5,762 for grouped JSON.
Sampled console peak RSS falls from roughly 16–17 MiB to 14–15 MiB. Sampling every
20 ms can miss short peaks and does not measure aggregate deployment memory.
Grouped node CPU falls from 22.05–24.47 to 11.23–12.67 seconds in those windows;
the counters include background work. A 50-ms delay between pulls completes wide
native output in 2,571 → 1,673 ms, with the same values and three bounded candidate
batches. Width sampling never collects the full relation.

The separate `--repeat 1 --instrument` pair includes a loopback proxy and node
metrics. Physical Table scans stay at nine per 70-row query in both arms; SQL
batching does not enlarge storage pages. Narrow/wide native attempts fall from
511/526 to 363/359. For grouping, attempts fall 4,315 → 1,810, authorization reads
1,107 → 405, Table checks 289 → 23 and check-set calls 429 → 299. Owner provider
operations fall 88,577 → 56,075 for grouping. These are whole-window counts with
background recovery included, not exclusively query-attributed disk I/O. Reduced
batch disclosure count does not remove the current-authorization boundary;
[fault/security qualification](sql.md#transport-independent-statement-results--2026-10-27)
separately verifies revocation after buffering and on repeated/terminal reads.

### Codec allocation and compression controls

`just test::sql-wire-encoding` measures actual TSR1/TCP1 production encoding and
decoding of 10,000 rows with seven scalar/NULL columns, one warmup and five samples.
Independent values, borrowed variable bytes and terminal counts are checked; every
batch releases all accounted allocations. The one-row control versus 32-row batches
produces 10,000 → 313 frames and 19,200,256 → 3,680,704 bytes. Median encode/decode
times are 792.8/438.5 → 615.4/405.6 ms. Encoder allocations fall 30,001 → 1,565,
decoder allocations 10,002 → 314. Encoder accounted peak grows 18,328 → 63,475 bytes;
decoder peak remains 10,162 bytes, excluding its borrowed frame. Maximum frame size
grows 2,176 → 12,032 bytes. This excludes sockets, SQL, source authority and storage,
and does not establish zero allocations after warmup. PostgreSQL/MySQL scalar
controls remain in the same raw report with their narrower representation scope.

The separate PyArrow experiment round-trips all 6,195 bytes of length-framed wide
canonical cells. With candidate batch boundaries, row/column layouts compress to
1,535/1,375 bytes with LZ4 and 672/765 with Zstd. These are one-shot payload results;
codec times are retained, but framing, negotiation, Arrow IPC and network costs are
excluded. They do not justify enabling compression universally. The current
native profile still admits identity encoding only.

### Controls that do not qualify the comparison

An earlier `f5a43c353` baseline predates the live-storage integration and cannot
attribute a speedup to result batching. Initial setup used an oversized INSERT
and failed before the driver split seeds into 20-row statements. A manually
interrupted self-join supplies no complete sample. The codec's first assertion
incorrectly required allocator counts to be identical despite possible in-place
arena growth; the corrected report retains per-sample allocation arrays. Earlier
codec timings overlapped a build and are excluded from the timing comparison.

The matched control's diagnostic startup also encountered unavailable authority
replies; later private write observations measure admission/completion but are
not the fresh matched workload. The [SQL account](sql.md#failed-controls-and-recovery-limits)
preserves startup, write-timeout and original-outcome limits. All four retained
installed measurement runs and the isolated codec run finish successfully; no
failed or incomplete run is substituted for one of these samples.

## Complete-history mutation cost

The [complete-history campaign](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-12/README.md)
completes 140 ordinary console mutations and seven instrumented cases with no
errors or unknown outcomes. It retains comparisons with both the earlier
fixed-profile and accepted general Table baselines. One-row INSERT and changing
UPDATE now use two native turns instead of one; the extra history write respects
the existing four-write bound. Three-row INSERT remains four turns. The record
reports the increased provider work and elapsed times explicitly. Runtime
measurements overlap maintained-query qualification, so the timing difference
does not isolate history overhead or establish a latency SLO.

## Declarative benchmark components

The [component harness](../../../tests/performance/declarative/README.md) measures synthetic SQL compilation,
paged Fuze/Arrow execution, declarations and private Station mutation proposals.
It enumerates all 151 full-workload units across TPC-C/E/H/DS as blocked.
Component correctness never changes full-suite coverage or implies a TPC score.
Executed in the pinned development shell, using locked frontend dependencies:

- Eight report/inventory tests pass, including missing/duplicate results,
  incompatible definitions, wrong build mode, absent timings and failure reports.
- The 28 components pass independent SQLite/PyArrow results, declaration schema
  checks and mutation-byte oracles. Smoke runs cover zero rows/page width one,
  one null row, 17 rows with the maximum uint32 seed, and 257 rows/page width
  three. Nine exact rejection probes pass; `--require-full` exits 2.
- `just test::sql` passes its 49 public examples, 104 SELECT AST cases,
  86 plan/Arrow cases, 24 unified results, 31 mutation cases and 182 declaration
  cases. These remain component/grammar proofs, not complete TPC execution.

Full `just check` passes, including the unit/protocol checks, 346 CLI diagnostic
cases, generated contracts, frontend tests/types and production handbook build.
The final report tests and a 17-row/three-row-page smoke pass after report
validation was tightened to reject missing timings and retain decoded outputs.
Logs: `/tmp/transit-benchmark-check.log`, `/tmp/transit-benchmark-sql.log`,
`/tmp/transit-benchmark-smoke.log` and `/tmp/transit-benchmark-final-smoke.log`.

At clean committed source `8446688afda8d0662bea1503ec8151fd3a6ac942`,
`just test::declarative-benchmark` passes all 28 components and nine blocker probes
with five samples, 8192 synthetic rows, eight-row pages, seed 42, ten query
executions and 2000 compilations/proposals. The
[retained report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-09-30.json) has `dirty: false`, all 52
timed phases, independently verified query outputs and mutation proposals,
fixture/build/source hashes and host metadata. Binary SHA-256 is
`4b8457964e12931d1058c2149d6483676e54618890863bb45959d600e2023e19`.
The [public summary](../../handbook/reference/benchmarks.md#recorded-component-measurements)
reports the exact scope and shared-host limits. Measurement log:
`/tmp/transit-benchmark-measurement.log`. These are unpaired component timings;
all 151 complete-workload units remain blocked. Native authority, disk durability
and public transport latency are outside this harness's measured boundary.
A separate fresh clone of `95d0107797551fbf6e4c7d0a47c72aa0e26830c1` builds
`transit-declarative-benchmark` without inherited workspace outputs and passes
all component oracles with 257 rows, three-row pages, one sample/execution and
50 compilations/proposals. The copied report is
`.cache/verification/benchmarks/clean-smoke.json` with `dirty: false`.
Broader committed-HEAD clean-lane outcomes are recorded in PR #38 after
those runs; they do not expand the benchmark's execution boundary.

After rebasing onto `main` at `4c22b426058c7299af62a8cba03ab5925336ba44`,
the default measurement repeats at clean source
`bc9476ba7c9613df625a28e9277bf10e568e0f6c`. The
[second raw report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-09-30-main.json) retains five samples,
all 52 timed phases and the same 28 passing components/nine rejection probes.
The executable, fixture, manifest, harness, driver and lock hashes match the
earlier report, as do independently decoded query outputs. The new SDK catalog
metadata readers do not change the measured Fuze/Station implementation or
remove any full-workload blocker. Both reports preserve their original source
identity; the public summary uses this repeat without claiming a speedup.
Log: `/tmp/transit-benchmark-rebased-measurement.log`.

The rebased executable also passes zero-row/one-row-page, one-null-row,
maximum-uint32-seed and 257-row/three-row-page cases; `--require-full` writes a
component-success/full-workloads-blocked report and exits 2. These focused
runs use one sample/execution and 50 compilations/proposals; documentation/report
updates are present in the working tree and their reports record `dirty: true`.
Log: `/tmp/transit-benchmark-rebased-edges.log`.

With these report/documentation updates, `just transit-board::install`, full
`just check` and `just test::sql` pass in the pinned shell. This includes all
eight report tests, 399 CLI diagnostics, generated contracts, frontend checks,
the production handbook and the same SQL case counts listed above. Log:
`/tmp/transit-benchmark-rebased-check.log`. Committed-HEAD clean-lane outcomes
remain separately recorded in PR #38; earlier clean runs do not qualify
the rebased source by inheritance.

## Query performance reproduction

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

Interpret the measurements using the [performance reference](../../handbook/reference/performance.md#reproduce-and-compare).
These are reproduction commands, not a record of a new execution.

## SQL performance iteration

### Output-name component coverage

The declarative benchmark includes four additional output-name components:
named count, named sum over a renamed derived input, renamed row projection,
and repeated inputs with distinct names. Its independent manifest declares
result types by position; the oracle no longer infers signedness from names.
SQLite supplies expected names/values and PyArrow checks complete output.

All **33 components and nine rejection probes** pass for both 257 rows in
three-row pages and zero rows, including quoted mixed-case output names.
Reports are `/tmp/transit-sql-output-aliases-benchmark-oracle-fixed.json` and
`/tmp/transit-sql-output-aliases-benchmark-empty.json`. These correctness runs
use one sample, one execution and ten compilations; they are not performance
comparisons. The eight benchmark-runner negative checks and local documentation
links also pass. Full TPC workloads remain blocked.
Reports identify dirty source based on `4e9a8bca`, with exact binary,
manifest, harness and fixture hashes; runtime code is unchanged from that commit.

The first run fails on a fixture's unquoted mixed-case alias: Transit correctly
folds it to lowercase while SQLite preserves case. The fixture now uses quoted
identifiers when expecting mixed case. That failed report remains at
`/tmp/transit-sql-output-aliases-benchmark-oracle.json`; the corrected passes do
not overwrite it. Logs are
`/tmp/transit-sql-output-aliases-benchmark-build.log` and
`/tmp/transit-sql-output-aliases-benchmark-oracles-fixed.log`.

### Direct-query compilation measurement

Direct queries now use the already validated source schema instead of building
and validating an identity input projection. Derived inputs still build and
validate their projected scope; all plans retain final validation. Fuze's
standalone tests and `just test::sql` pass, including 105 independently encoded
plans and 44 paged result cases. Logs are
`/tmp/transit-sql-output-aliases-compile-optimization-unit.log` and
`/tmp/transit-sql-output-aliases-compile-optimization-check.log`.

The [paired raw report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-output-aliases.json)
records control/candidate order **A B B A A B**, five samples per run, one warm-up,
8192 rows in eight-row pages, ten executions and 2000 compilations per sample.
Both frozen binaries pass all 33 components and nine rejection probes in each
run, with identical verified output cells and Arrow segment hashes. The report
retains raw durations, fixture/harness/compiler/binary identities, source plus
the exact candidate patch, host load and result evidence. The control is runtime
source `7e6e2905` (unchanged from `4e9a8bca`); the candidate adds only the recorded
compiler change.

Medians across the three per-build run medians, in microseconds:

| Compilation component           | Control | Candidate |
| ------------------------------- | ------: | --------: |
| Selected count                  |   1.073 |     0.725 |
| Selected count with output name |   1.172 |     0.828 |
| Row projection                  |   1.527 |     1.188 |
| Renamed row projection          |   1.747 |     1.412 |
| Named sum over derived input    |   1.841 |     1.723 |

The direct named cases show about 19–29% less compilation time in these samples.
Execution timings overlap; no execution speedup is established. The derived
path retains its validation work, so its small observed difference is not
attributed to a removed operation. This shared host also runs installed recovery;
the measurements do not establish isolated-host, native, transport or storage
latency. The installed recovery run uses frozen pre-optimization binaries and
does not independently qualify the later compiler change. The subsequent full
check passes as recorded above; committed-HEAD clean lanes remain outstanding.

### Finite SQL probe

`just test::sql-benchmark` builds a ReleaseSafe public-package consumer and records
five independent process samples after one warm-up. Four compile cases each run
10,000 times; count and sum each consume 8,192 rows in eight-row pages, 100 times.
The aggregate probe validates completion and row coverage, and sum's exact value.
Independent Arrow correctness remains in `just test::sql`.

The JSON report at `.cache/verification/sql/benchmark.json` records raw durations,
per-case median/range, source revision, dirty state, compiler, host and executable
SHA-256. `--samples N` and `--output PATH` select repetitions and report location.
The compiler uses a reset 16 KiB arena; execution uses the existing 4 MiB Arrow
workspace and 64 KiB output buffer. These are supplied budgets, not measured RSS.
There is no timing assertion. Run controls without competing builds; compare the
same cases and optimization mode. These measurements exclude source adapters,
authorization, network, storage, result publication and rendering.

The wider projection iteration passes `just test::sql`: 104 Zig/ANTLR/PostgreSQL
AST comparisons, 91 Table plans, 16 unified results across three source bases
and eight page widths, plus nine unified rejection/failure cases. The added
cases cover eight-column reversed output, a wider derived input, duplicates,
unknown names and a ninth column. Canonical plans and result layouts are unchanged.
`just check` also passes for this iteration, including generated contract parity,
shared native/port codecs, CLI diagnostics, frontend checks and the documentation
build. Five local performance samples put compilation at 0.393–0.897 µs per
statement across the four cases and 8,192-row count/sum at 0.772/0.788 ms.
A documentation build overlapped this sample, so it is not a controlled speedup
claim; the raw report is `.cache/verification/sql/projection.json`.

The typed-filter iteration passes `just test::sql` (24 unified results across
three source bases and eight page widths) and `just test::unit`. New unit cases
check exact state tags, canonical plan agreement, full uint64 range, signed zero
through the plan codec, malformed/non-finite literals and type mismatches. Cursor
fixtures cover numeric operators, typed literals and all five state suggestions.
`just check` and `just test::interactive-query --source table` pass. The real
console selects 41 values and zero missing/type-error/conflict keys with eight
native read attempts per full scan and no durable updates; the same fixture
checks cancellation, fresh cuts, complete framing and current denial. Individual
new-predicate samples took 32–39 ms with sampled console RSS of 16.2–16.4 MiB;
these are local observations, not latency percentiles. An initial optimized build
failed on duplicate Arrow C objects; reusing the root Fuze dependency in the
benchmark build fixed it before the successful fixture run.

The aggregate-copy iteration skips row projection materialization for count/sum;
row validation, source-order matching, overflow, cancellation and checkpoint
validation remain on the same path. `just test::sql` and `just test::unit` pass.
Nine alternating ReleaseSafe control/candidate samples over 8,192 rows measured
count at 0.776/0.753 ms and sum at 0.788/0.765 ms (about 2.9% lower medians).
A second nine-pair run measured 1.037/0.903 ms and 0.970/0.894 ms with overlapping
ranges and substantial variation in unchanged compiler cases. These local runs
establish reduced copying and intact results, not a reliable deployment speedup.
Both controls use source `c8583767`; frozen binary hashes, candidate diff and raw
samples are in `.cache/verification/sql/aggregate-comparison.json` and
`.cache/verification/sql/aggregate-paired.json`.

For an alternating comparison, preserve the baseline executable, then run:

```sh
just test::sql-benchmark --samples 9 --control /path/to/frozen-probe \
  --control-revision BASE_COMMIT --output .cache/verification/sql/comparison.json
```

The runner rejects mismatched case/workload shapes, alternates process order and
retains both sets of samples and executable hashes. Use the actual baseline
revision and a frozen probe built with the same optimization and toolchain.
`--cpu N` pins warm-up and sampled processes to an available CPU; the default
leaves affinity unchanged. Reports include the selected CPU, host load, driver,
probe, lockfile and Fuze source hashes, plus the runtime diff. Pinning does not
reserve a CPU or remove shared-host interference.

### Scoped SQL inspection iteration

The inspection change adds shared Fuze parsing, validated output schemas and the
query owner's `DESCRIBE`, `SHOW TABLES` and `EXPLAIN SELECT` operations. Before
rebasing onto the protocol-consolidation revision, `just check` (including the
full docs build), `just test::unit` and `just test::sql` pass: 104 SELECT ASTs, 16 syntax exclusions, 14 extensions,
44 documentation examples, 91 executable Table fixtures and 24 unified results
across three source bases and eight page widths. Neutral inspection fixtures
cover operator order, output types, literal redaction, exact names, full-width
limits/policy revisions, empty KV listings, initial/final denial and reduced
final budgets. Browser fixtures consume the same JSON and reject impossible
operator order, duplicate projections, overflow and foreign Table names.

`just test::interactive-query` completes Table and KV cases against disk Ursula
with 41 rows. Each of the three inspection statements uses five native reads,
zero snapshots and zero durable writes. Table wall times are 15.1–21.0 ms and
KV times 16.6–17.7 ms, including process startup; sampled console peak RSS is
8.4–9.4 MiB. Revocation returns no metadata. Existing finite-query fresh-cut,
cancellation and current-denial checks pass for both kinds. The Document run is
stopped during provisioning to apply the user's requested protocol rebase; it
is incomplete and establishes no Document execution evidence for inspection.

Five pure benchmark samples record compile medians 0.45–0.97 microseconds and
8192-row count/sum medians 0.789/0.808 ms. The raw report records dirty source
state and the executable digest; these are local observations, not a paired
performance improvement claim. All of this evidence predates the protocol
rebase and must be rechecked on the consolidated implementation.

### SQL integration after protocol consolidation

The SQL branch is rebased onto `3ea81aaa`, retaining the consolidated native
contract definition and the removal of the older Fuze compiler/executor.
`Unified.Sql`, `Unified.Plan`, `Unified.Codec` and `Unified.Stream` remain the
single lowering/execution path; generated ABI/browser resources are regenerated
from the merged Zig types. The duplicate-projection fixture now expects the
current compiler's `DuplicateProjection`, instead of the removed Table
compiler's width error.

`just check`, the independent SQL proof and a further `just test::unit` pass.
The SQL proof covers 104 AST cases, 86 executable current plans, 16 syntax
exclusions, 14 extensions, 44 documentation examples and 24 independent unified
results across three source bases and eight page widths. Rebuilt Table/KV
runtime inspection again uses five reads, no snapshots and no durable writes;
revocation and the existing interactive controls pass. Individual inspection
wall times are 16.9–19.5 ms in this run. The Document fixture also completes:
12 rows, 14 native reads per inspection, no snapshots or durable writes and
current denial without output. DESCRIBE, SHOW and EXPLAIN take 50.25, 34.98 and
35.12 ms respectively, including console startup; sampled peak RSS is 10.3 MiB.
The Document fixture including provisioning and existing interactive checks
takes 299.69 s. These are single-run observations, not comparative speedup claims.

`just bindings::node-check` initially fails in this fresh worktree because
Station imports the client package's `dist` exports, which the task only
checked with `--noEmit`. The task now builds that direct dependency first.
The standalone check then passes strict types, formatting/lint and all ten
Node handler/ownership tests. This is a task-dependency correction, not a
substitute for installed-SDK runtime qualification.

### Installed SQL inspection callers

Python sync/async `inspect_sql` and TypeScript `inspectSql` expose owned typed
description, Table-list and explanation results through the shared native owner.
Python type checking and `just bindings::node-check` pass. After rebuilding the
installed wheels/tarballs, `zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node -Dunified-source=table` passes the disk-backed recovery
schedule in 62.05 s: 41 rows, six segments, eight resident authority pages and
an 8 MiB hot store. All five native/port/installed callers agree on inspection
details, full-width limits, output types and redacted literals without query
admission; current revocation and permanent source retirement reject disclosure.
The existing frozen retry, worker/node/store restart and released-pin checks pass.

The first run reaches retirement but fails an incomplete assertion: typed SDKs
preserve the authority's `StateResourceExpired` code, while native results also
carry the mapped `ResourceUnavailable` error. The assertion now accepts that
specific retirement rejection; no production error translation is changed.
Other language SDKs and installed KV/Document inspection are not covered by
this run.

### Current Document metadata batching

`UnifiedClient` shares the current metadata key selection between inspection and
interactive snapshots. Document description batches policy, lifecycle head and
accepted revision records at one current resource revision, then uses the same
`UnifiedSource.checkCurrent` checks as before. The reader caches protocol support,
never permissions or source state.

`just test::unit` passes, including current batch checks for exact Document
identity, missing requested keys, access denial, reclaimed history and permanent
retirement. `just test::interactive-query` passes all three source kinds. Each
inspection now requires exactly five native requests, enforced by the fixture:
one capability read plus source/requester reads before and after resolution.
The earlier Document baseline used 14 requests. No snapshots or writes occur;
current denial, bounded results, fresh cuts and cancellation remain verified.

Document DESCRIBE/SHOW/EXPLAIN wall times are 27.75/16.03/17.35 ms, with sampled
peak RSS 9.5–10.2 MiB; the full Document fixture takes 304.08 s. The corresponding
earlier statement times were 50.25/34.98/35.12 ms. These separate local runs
establish the nine-request reduction, not a paired latency or memory claim.

### Ruby and Rust SQL inspection

The Ruby and Rust packages add typed inspection over the same native operation.
Ruby syntax checks and Rust formatting/type checks pass. Rebuilt installed
gems/crates participate with Python sync/async, TypeScript, native and port
callers in `zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node,ruby,rust`. KV and Table complete the full disk-backed
schedule in 113.60 and 226.46 s respectively. Seven callers agree on description,
listing, count schema, comparison redaction, all/state predicate variants and
zero/full-width limits. Revocation and permanent retirement reject inspection
and results; frozen upload retry and worker/node/store recovery pass.

Two pre-existing negative codec fixtures incorrectly select decoder version 1;
they now select unsupported version 2. An earlier clean Rust build exhausts
shared `/tmp`, so the successful KV/Table run uses a dedicated disk temporary
directory outside the workspace. Document setup then receives HTTP 503 from the
cold-store bucket creation before provisioning. Document is not passed by this
run and requires its own continuation. These fixture timings include concurrent
host load and are not performance comparisons.

### Java and .NET SQL inspection

Rebuilt JAR and NuGet packages expose immutable inspection details through their
existing bounded future/task workers. Installed consumers compile with warnings
as errors. `zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=java,dotnet` completes KV and Table in 76.10 and 81.29 s: four
native/port/SDK callers agree on the same metadata and predicate cases, reject
revoked and retired disclosure, and preserve the full signed recovery schedule.
The Java test adapter now treats an omitted cursor as no cursor, allowing the
existing final retirement probe to reach the public SDK. The Document continuation
also passes: 12 rows, two segments, 64 resident authority pages, an 8 MiB hot
store and the same four-caller inspection/denial/recovery checks. Provisioning
takes 1409.61 s and the complete Document fixture takes 1562.99 s under concurrent
host load. These are fixture costs, not query latency or improvement claims.

### C and C++ SQL inspection

`just bindings::c-build` compiles the independent archives, C11/C++17 examples
and C++ ownership checks. The public C result contains bounded inline metadata
with no borrowed pointers; C++ returns owned strings, vectors and variants.
`zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=c,cpp
-Dunified-source=table` passes in 159.85 s, including four-caller metadata
agreement, predicate variants, redaction, zero/full-width limits, zeroed C error
output, current denial, permanent retirement and the existing disk recovery
schedule. The test adapters normalize public typed results through a shared
fixture printer; they do not invoke the raw inspection action. KV and Document
installed coverage remain outstanding for this increment.

### Erlang and Elixir SQL inspection

`just bindings::beam-build` compiles the OTP applications and Elixir structs.
`zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=erlang,elixir
-Dunified-source=table` passes in 157.89 s. The installed adapters use public
records/structs and normalize their results for comparison with native and port
callers. The same description/list/plan, redaction, state/limit, current denial,
retirement and signed disk recovery checks pass. Atom conversion uses fixed
allowlists. The controller now handles omitted page cursors for the final
retirement probe. KV/Document installed coverage remains outstanding.

### Bounded application-owned Table mutations

The shared lexer/parser and typed Fuze compiler accept literal INSERT and
primary-key UPDATE/DELETE. Station applies the validated plan within an explicitly
supplied private writer turn. This increment does not add public admission or a
query-client mutation route. Typed validation and SQL use the same three-row,
exact-type and duplicate-key rules; no native/storage definition changes.

`just test::unit` passes, including atomic proposal rollback after a later duplicate
or exhausted budget, missing/same-value affected counts, full-width keys, all four
Table value types, cross-resource/schema rejection and sticky read failure after
an earlier row change. `just test::sql` passes its existing 104 SELECT ASTs,
86 current plans and 24 unified results across three bases/eight page widths.
The new corpus adds 24 ANTLR/Postgres mutation AST comparisons and 31 independent
storage-byte/outcome or rejection cases. All 49 public SQL examples parse. These
private-turn fixtures do not establish native mutation admission, disk recovery,
current revocation or language-SDK mutation coverage; those remain required.

The ReleaseSafe performance probe now includes 10,000 compilations each of a
three-row insert, key update and key delete, with five independent process samples.
Their median costs are 1.081, 0.627 and 0.447 microseconds respectively. The
independent outcome probe observes at most nine private point reads for three-row
insertion and five for an existing-row update. This is a baseline for compiler
and helper work, excluding authority, network and disk. Raw samples, executable
hash, dirty-source flag and compiler identity remain in the generated report;
no end-to-end performance improvement is inferred.

`just check` passes, including the production documentation build; a further
`just test::unit` passes after the 220-byte literal boundary cases are added.
The first broad check exposes a catalog omission in the rebased CI consolidation:
`bindings::test` remains an invariant owner but was removed from lane membership.
It is now listed as an external aggregate, preserving the once-per-lane SDK run.

### Avoid repeated mutation selection

After the initial mutation baseline, the Station helper uses `Table.upsert` only
after finding the existing row in the same private view. It retains descriptor,
type and write validation without repeating the existence lookup. The independent
oracle now asserts exactly three private point reads for each existing-row update,
down from five, with identical proposed bytes and affected counts. This is a
40% reduction in those callback reads, not a network or commit-latency claim.
`just test::unit test::sql` passes again, including rollback, sticky read failure,
all 31 mutation cases and the unchanged query corpus. Inserts remain at most
nine private point reads for three rows.

### Cold-store setup readiness

Repeated SQL ingress attempts observe an owned MinIO health response followed by
HTTP 503 from bucket creation, before any authority/source setup. The fixture now
includes the signed empty PutBucket in its existing 30-second readiness deadline.
It retries that 503 and accepts only an explicit `BucketAlreadyOwnedByYou`
conflict when recovering a completed creation. Other conflicts and authorization
failures still reject. Three fresh pinned MinIO fixtures pass readiness, a second
creation of the same owned bucket and cleanup. This qualifies setup only; the
interrupted query/browser runs are not passing evidence.

### Worksheet SQL inspection

The worksheet adds explicit Inspect SQL submission and a separate metadata/plan
region, bound to the inspected draft and observed source/policy revisions. The
real Board API rejects unsupported catalogs and malformed explicit numeric
literals with 400 `UnsupportedQuery`; these errors formerly fell through to 503.
The fixture now preserves and retries the exact frozen submission body after a
503, still requiring the original receipt and its current disclosure checks.

`just transit-board::check` and the broader `just check` pass. The real Table
API/Chromium run (`zig build test-unified-query -Doptimize=ReleaseSafe
-Dunified-source=table -Dunified-board=true -Dunified-browser=true`) passes in
524.40 s. It verifies DESCRIBE, SHOW TABLES and EXPLAIN without query admission,
operator/output-column presentation, stale-draft labeling, failed-inspection
clearing and current revocation clearing. Existing uncertain submission, cross-
instance retry, finite Live draft recovery and worker/node/store recovery pass.
Two Board result readers peak at 41,209,856 combined RSS bytes in the API probe;
that measurement excludes Chromium. The run uses 41 rows, six segments, eight
resident authority pages and an 8 MiB hot store. These are whole-fixture costs,
not comparative inspection latency. KV/Document browser coverage remains open.

### Canonical Table mutation requests

`TableMutationRequest` binds the current native definition, realm, writer,
resource, Table descriptor and typed operation in at most 799 owned bytes.
It reuses Station's Table value codecs and immutable publication commitments;
it does not admit work or add a query-client write route.

`just test::unit` passes with five independently encoded fixtures across four
Table value types, full-width signed keys and nullable/Unicode/binary values.
The Zig checks compare canonical bytes, overwrite the input buffer before using
the decoded value, reject every truncated fixture and reject missing/foreign
definitions, query-bundle magic, trailing input, invalid identities/operation
counts and foreign publication records. The maximum-size fixture occupies
exactly 799 bytes and a one-byte-short output rejects. The ownership/bound
catalog and `just transit-docs::check` also pass. Public mutation admission,
revocation and durable outcome recovery remain subsequent proof boundaries.

### Remaining KV callers and browser

`zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source=kv
-Dunified-sdk=c,cpp,erlang,elixir -Dunified-board=true -Dunified-browser=true`
passes in 191.17 s. Six native/port/installed callers agree on SQL inspection;
revocation, permanent retirement, frozen retry and worker/node/store recovery
pass. The real browser additionally verifies the empty SHOW TABLES listing,
read-only plan/description display, stale draft, error clearing and current
revocation clearing alongside the existing finite-query recovery flow. The two
Board reader processes peak at 41,189,376 combined RSS bytes; Chromium is excluded.
This completes the installed KV inspection set across all ten SDKs when combined
with the earlier language runs. The remaining eight SDK Document callers and
Document browser are still being verified.

### Application-composed Table mutation admission

`TableMutationAdmission` passes `just test::unit` and the independent package
`zig build test`. It uses the existing publication/half-chunk components and
an explicit per-principal/Table policy. Begin uses four private mutations;
application of three rows uses three row mutations plus one result. A terminal
active pointer is replaced on the next begin without discarding the old result.

Reference-store schedules cover interrupted/repeated halves and owner
reconstruction, identical recomputed pre-commit proposals, repeated terminal
apply/cancel with the original input identity, conflicting/foreign namespaces,
forged process origin, another principal, busy uploads, conditional policy
updates, zero-mask revocation, same-mask revision fencing and per-operation
permissions. INSERT conflict leaves every row unchanged; same-value UPDATE
counts one and missing UPDATE/DELETE count zero. Declaration drift rejects.
A read failure on the second insert restores the first proposed row and leaves
sticky read poison; no terminal record is fabricated. Foreign definition bytes
with a valid publication commitment produce an invalid-request result, while
post-publication chunk corruption propagates as an integrity error.

The independent Python contract oracle additionally encodes the source
fingerprint, publication commitment, one policy, five status phases and six
commands. Zig matches their bytes and rejects truncated fixed records/commands,
inconsistent terminal fields, permission bits, part flags and exceeded part
bounds. These are private-turn/model checks, not native durability, transport
uncertainty or public mutation-client proofs. The supplied query hosts still
reject mutation messages; the native integration is the next proof boundary.
`just check`, including generated-contract, frontend and documentation checks,
passes for this increment. The verification catalog also passes.

### SQL worktree main rebase

The SQL worktree is rebased from `3ea81aaa` onto `2c1a9d2d`. One retired-source
fixture conflict was resolved by keeping the explicit null cursor and concrete
authority errors together with SQL inspection denial checks. Main's bounded
startup/browser retries, installed SDK ready/reconcile schedules and current
Arrow fixtures are retained. Its ten-language source evidence above qualifies
the base query path; it is not substituted for the new inspection assertions.

The remaining-eight-SDK Document/browser run was interrupted during provisioning
to avoid mixing source revisions during the rebase. It had completed installed
codec checks, but no source/browser success was reported. It is not a pass and
will be rerun from the rebased worktree. The unfinished native mutation proof was
saved and restored intact. Post-rebase `just check` and `just test::sql` pass.
The transport package's formatting/lint, TypeScript check and eight focused
transport tests pass. The added inspection schedule checks upstream's exact
500/1000/2000 ms availability backoff, identical request bodies and immediate
termination at current denial. Its first draft used an invalid request field
and failed before dispatch; the corrected request passes without unhandled
promises. Public-query and Document integration reruns remain in progress.

### Native Table mutation visibility and recovery

`just test::table-mutation` passes in **7.890 s** against owned disk-backed Ursula
and the real native node, with eight resident authority pages. The test
application calls the public mutation admission owner through ordinary Station
casts. It does not add a supplied host, CLI or SDK write route.

The schedule stages a multi-chunk UTF-8/null request and confirms no rows exist
before the final native commit. All three rows and the terminal result then have
the same resource revision, the original terminal input identity is retained,
and native input progress is consumed. The proxy removes the accepted commit's
receipt; after process exit and node/store SIGKILL/restart, the unchanged frozen
signed proposal returns the original receipt and unchanged rows/result. A changed
signed retry rejects. A new apply of the same namespace returns the original
result without row writes.

A two-row INSERT conflict after the first absent key leaves that key absent and
the existing rows unchanged. An earlier resource revision cannot open a captured
view after intervening staging commits. A prepared update from an older writer
generation rejects without changing rows/result, then the fresh fenced writer
resumes the original admitted input. Revoking native write rights rejects an
already frozen delete; restoring rights permits that exact saved request.
Separate application-policy revocation records a denied result with no row
change, and revoked read rights prevent inspection of an earlier result.

The proxy observed **555 read requests** and **26 successful turn responses**,
including exact receipt retries; these are transport counts, not 26 unique
accepted mutations. The largest proposal has four mutations and the largest
stored value has 256 bytes. Runtime includes the fixture's provisioning,
inspection, fault injection and recovery, but excludes compilation. This is one
local schedule, not a statement-latency target or a paired performance comparison.
The fixture freezes and hashes both executables before running. Unit/catalog
checks and the independent SQL oracle retain their own evidence above.

The initial schedule also passed before adding the stale-resource-view case;
the final schedule above is the qualifying result. The ordinary growth lane now
owns `test::table-mutation`, and invariant `SQL-MUTATION-01` maps its contracts,
implementation, SQL oracle and native proof. Native integration does not complete
the remaining supplied-host and public caller work.

### Installed mutation operation profiles

`just test::table-mutation` runs seven profiles for the native ABI, port and
real CLI. Each selected `--sdk` adds the same profiles through independently
installed public language APIs; Python adds both synchronous and asynchronous
callers. Build the selected packages with their `bindings::*-build` tasks first;
`bindings::c-build` covers C/C++ and `bindings::beam-build` covers Erlang/Elixir.
The complete selection is:

```sh
just test::table-mutation --cold --sdk python --sdk node --sdk rust --sdk ruby \
  --sdk c --sdk cpp --sdk java --sdk dotnet --sdk erlang --sdk elixir
```

The profiles cover UPDATE, DELETE of an existing row, DELETE and UPDATE of an
absent row, INSERT with reversed column order, conflicting two-row INSERT and
cancellation after a committed upload part. Each caller compares current rows
with independent expectations, including NULL versus absence and rollback
of an earlier private insert when a later key conflicts. The conflicting batch
must leave that earlier key absent. Missing-row operations and rejected or
cancelled operations preserve all row revisions. A successful insert shares its
revision with the durable result.

The proxy loses the begin receipt for UPDATE and the final apply/cancel receipt
for each added profile. The caller closes and is recreated, then resubmits the
exact saved command before selecting a successor. Repeated explicit apply and
cancel controls preserve the original terminal outcome, input and result
revision. All retained outcomes are checked again across physical node/store
restart and denied after current read revocation. Per-profile intervals include
recovery and assertions; they are functional schedule timings, not statement
latencies or language performance rankings. The success record is emitted only
after fixture cleanup and retains the source, dirty state, runner and binary hashes.

`--cold` selects the existing owned S3 fixture with an 8 MiB hot-store limit and
8 MiB cold cache, requires actual persisted cold chunks and records their count
and filesystem bytes. Eight resident authority pages, four mutations and all
operation deadlines stay unchanged. The installed profiles use one UTF-8 Table;
wider literals and three-row bounds retain their private-turn/native proofs.
Upload cancellation does not implement SQL transactions or undo applied rows.

The initial native/port/CLI expansion passes **21 profiles** in **197.977 s**,
with **6120 reads**, **150 turn responses** and **23 lost receipts**. That run
cancels immediately after begin, before the subsequent partial-upload extension;
it does not qualify that extension or the optional cold/installed-SDK schedule.
Its log is `/tmp/transit-sql-installed-mutation-profiles-native.log`.

The complete cold-storage selection above passes at clean source `207003bf`:
**98 profiles across fourteen caller variants in 988.246 s**, including
**42.403 s** of installed-consumer setup. It records **25,692 reads**, **582 turn
responses**, **677 mutation-send responses** and **100 lost receipts** (99 caller
receipts and one writer receipt). All retained outcomes survive physical
node/store restart and current read revocation denies every selected status.
Row/revision assertions run before that restart; the native application cases
separately check atomic row/result recovery. Cleanup completes before the final
success marker. The store records **604 cold objects / 71,935,123 filesystem
bytes**, including provider metadata. Four mutations, 256-byte values and eight
resident authority pages remain the observed maxima. The log and full report are
`/tmp/transit-sql-installed-mutation-profiles-all.log` and
`/tmp/transit-sql-installed-mutation-profiles-all.json`. The runner SHA-256 is
`a18888ead65bd90e49300be94231afd82cb83e531e30954369f2cc27da719a02`;
the report records every frozen binary digest. All ten SDK package builds and
full `just check` also pass at this source.

The separate committed-head clean growth run at `207003bf` remains **failed**:
Arrow, pages and growing authority pass, then `test::growing-service` exceeds the
query delivery subprocess's **180-second** deadline. That task takes **598.71 s**;
the lane takes **792.65 s**, with its remaining **17 tasks unrun**, including the
changed mutation schedule. The isolated checkout and lane records remain at
`/var/tmp/transit-ci-i4cuegoj/src`; the log is
`/tmp/transit-sql-installed-mutation-profiles-ci-clean-growth.log`.

That run uses Debug binaries. The unchanged focused schedule
`zig build test-query -Doptimize=ReleaseSafe` passes at the same source: write
**9.986 s**, seal **7.731 s**, recover **13.546 s**, publish **1.768 s** and deliver
**79.959 s**. It verifies **41 rows / 21,296 bytes**, exact retries, bounded Arrow
validation, cancellation and retained acknowledgement. Its log is
`/tmp/transit-sql-growth-query-release-safe.log`. These are separate build-profile
observations, not a diagnosis of the Debug timeout or an engine speedup claim.
The growing service and focused query recipes now explicitly select ReleaseSafe,
as other installed integration proofs do. Safety checks, workload, fault
injections, timeouts and resident limits remain unchanged; Debug remains
available through the direct Zig commands. A new committed-head clean run is
required to qualify the recipe change.

The clean growth retry at `7f2ef35f` passes its first **seven tasks**, including
the ReleaseSafe growing service (**300.67 s**) and the expanded mutation task
(**333.20 s**, including compilation). The mutation schedule itself completes
**21 profiles in 210.849 s**, with **6231 reads**, **153 turn responses**,
**23 lost receipts** and successful cleanup. It covers native ABI, port and CLI;
the separate 98-profile installed proof above covers all ten SDKs.
The lane then fails in `test::table-query-writer` after **115.47 s** when the
console reports `AuthorityTimeout`. The **1340.14 s** lane is failed, with its
last **13 tasks unrun**. Evidence remains at `/var/tmp/transit-ci-w350glyv/src`
and `/tmp/transit-sql-mutation-coverage-clean-growth-release-safe.log`;
the completed mutation record is copied to
`/tmp/transit-sql-mutation-coverage-clean-native.json`.

### Full-reference mutation command cutover

Mutation parts, seal, apply and cancel now carry the complete 68-byte immutable
publication reference. Unit schedules reject a different resource with the same
writer/principal/Table/namespace/policy revision, changed request length/digest,
and changed references to terminal results. Namespace-only payloads reject.
The largest part is 205 bytes; native frame, request, row and turn bounds remain.

The shared native/ABI definition is replaced with `b17eab6aefacb9013afbbcfebf9eededea9f57dcd8be304bab4a18e5d41cd016`.
Generated native/install schemas, ABI/binding resources, browser schemas and
independent request/query/serving/signing fixtures are regenerated together.
Existing missing/foreign-definition and canonical saved-request checks remain.
`just check`, the package-local query tests, the independent mutation fixture
check and application signing check pass. The first root check caught two
hard-coded native signing digests; independently recomputing their current
canonical bytes corrected the fixtures. An initial package invocation using
`--build-file` failed configuration; running from the package directory passes.

`just test::table-mutation` passes on this definition in **7.682 s**, with the
same 555 read requests, 26 successful turn responses (including exact retries),
four-mutation maximum, 256-byte maximum stored value and eight resident authority
pages. The fixture persists the original reference alongside its required
definition before staging, then loads that reference for later apply/cancel.
It never resolves a replacement reference from the current namespace.
The frozen node digest is `a511cb9f1f8996f93a94cdb795fece1d8cbdbb46bf2663e2fa2b034947362835`;
the proof digest is `6d1b6ce699f80e0f09d28ec5c6e54f66b3a8f99c10106e121698a3259fa404ee`.
These independent runs are not a paired performance comparison.

The earlier rebased Document schedule completed on the preceding definition:
Python, Node, Ruby, Rust, C, C++, Erlang and Elixir plus native/port/CLI inspection
agree, and real Board API/browser checks pass. Combined with the previously
recorded Java/.NET schedule, all ten SDK source sets are covered on that
revision. The final Document run takes **1805.83 s**, including **1436.92 s**
provisioning; it produces 12 rows in two segments (9880 bytes), uses 64 resident
authority pages, and retains 1255 cold objects (139076558 bytes). Two concurrent
Board readers sample 45101056 bytes RSS, excluding Chromium. Worker/node/store
restart, prefix revocation, released source pins, current denial and exact
uncertain retries pass. This completed earlier-build evidence is not substituted
for post-cutover caller qualification.

The first committed-HEAD `just ci-clean` run, at `d3fab512`, passed the core lane
and growth Arrow/page proofs, then failed in `test::growing` with
`LegacyAcceptedGrowthHistory`. The old assertion expected the now-consolidated
current adapter to reject its own history. Later clean-CI lanes did not run.
The isolated checkout and failure evidence remain at
`/var/tmp/transit-ci-rb8z_6yk`. A replacement current-owner definition-rejection
proof and new committed-HEAD validation are tracked separately; the failed run
is not a clean pass.

### Consolidated storage definition rejection

`just test::growing` passes after replacing the obsolete legacy-adapter assertion.
A fresh current adapter reads valid genesis history. Separate disk-backed fixture
journals with a missing or foreign head definition reject through both `Store.read`
and `Engine.open`, before and after provider restart. Their tails and stored bytes
remain unchanged. The first replacement compared append-input ordering to Ursula's
canonical JSON and failed; the corrected proof captures the stored bytes before
rejection and compares them after, preserving the intended no-rewrite assertion.

The final write/recover/checkpoint/trim-recover phases take **115.883 / 3.918 /
6.575 / 3.734 s** with one resident page, 64 rows and 1011 catalog records before
the checkpoint. All existing root, mailbox, captured-view, grant, exact-receipt,
trim and missing-page checks remain. This focused pass does not turn the earlier
incomplete clean-CI run into a pass.

On the replacement definition, `just test::client-abi` and `just bindings::native`
also pass canonical signing, missing/foreign-definition refusal, seedless exact
recovery after host/store restart, current revocation, poisoned-read controls,
shared local codecs and six independently decoded query segments. Installed
language/browser cutover schedules and complete committed-HEAD CI remain separate.

### Shared signed Table mutation client

`TableMutationClient` now owns current metadata/SQL compilation, one-command
preparation, canonical save/restore, explicit submit, processed-input observation,
reference-bound status and bounded upload resumption. Package tests prove owned
saved bytes, required outer/nested definitions, canonical framing, and target or
signature rejection before touching the transport. The first test compile caught
a slice binding that should be `const`; correcting the binding preserves the
intentional mutation of its allocated bytes in the ownership test.

The expanded `just test::table-mutation` passes in **9.711 s**. It exercises the
shared client through real native commands, recreates each writer between stage
commands, and checks pending/processed input progress. The proxy removes the
accepted caller-send receipt, then the process exits and node/store restart.
The restored signed command returns the same admission position; only after that
receipt is reconciled and its original input processed does upload continue.
The separate accepted writer-commit receipt loss/restart proof remains intact.
Conflicting namespace preparation cannot overwrite the fixture's saved reference,
a busy active upload cannot admit a second begin, and policy denial prevents new
compilation. Cancelling a terminal denied request retains its original result.

The proxy counts **674 reads**, **25 successful mutation-send responses** and
**27 successful turn responses**, including exact retries. Bounds remain four
mutations, 256-byte values and eight resident authority pages. The frozen node
digest is `a511cb9f1f8996f93a94cdb795fece1d8cbdbb46bf2663e2fa2b034947362835`;
the proof digest is `5e45e18b7f74d9fc117093f41c78476d8cad741c4b386882f620c3066dd02c2e`.
This expanded schedule adds a second node/store restart, explicit stage progress
reads, failed preparations and duplicate cancellation, so its totals are not an
equivalent-workload comparison with the earlier admission-only proof.

Metadata acquisition requests at most six keys in one native batch. Replacing
a terminal active pointer needs one additional prior-status batch; immutable
feature support is cached, while current credentials, grants, source metadata
and policy are not. Saved retry submission performs no metadata read or new
signing. Supplied host/CLI/language SDK write integration remains outstanding.

### Consolidated service capability follow-up

The second committed-HEAD `just ci-clean`, at `775b4bc9`, passed core and the
corrected growing-storage proof, then failed in `test::growing-service`: its old
assertion expected Station and runtime bindings to be unavailable. The current
service advertises both. The focused `just test::growing-service` passes after
requiring those capabilities together with batched reads, retained versions and
worker rotation. It preserves signed reads/turns, current denial, exact retry,
maintenance faults, disk restart and quota/backlog checks. Station write/recover
takes **55.584 / 16.132 s**; the retained query publishes 41 rows / 21296 bytes
through write/seal/recover/publish/deliver phases. This is a focused pass; later
clean-CI lanes did not run. The failed checkout remains at
`/var/tmp/transit-ci-zzrnm6qv`.

### Supplied Table mutation writer

The explicit `table_writer` host role composes the same mutation admission owner
and requires an authorized initializer, an immutable stored configuration and
separate per-principal policy. Independent bytes cover configuration, initializer
commitment, policy changes and all twelve input rejection reasons. Package tests
cover the four-slot initialization boundary, changed configuration/resource,
unauthorized/stale policy changes, namespace conflicts, rollback, poisoned reads
and corrupt status. Rejected inputs have a retained disposition and do not
replace a request's terminal result.

`just test::table-mutation` passes in **12.481 s** using the actual supplied host,
including termination during upload, fresh fenced ownership, premature-apply
rejection, continued upload/application and activation-marker reuse refusal.
The caller reads a processed input's reference-bound rejection separately from
its mutation result. The first run exposed a missing fixture activation directory;
creating that owned directory fixes startup without changing host recovery gates.
All earlier caller-send and writer-commit receipt-loss/restart, atomicity,
conflicting retry, current grant/policy and duplicate-result schedules remain.

The expanded schedule records **1010 reads**, **30 successful mutation-send
responses** and **33 successful turn responses**, including retries. Bounds stay
at four mutations, 256-byte values and eight resident authority pages. The node
SHA256 is `a511cb9f1f8996f93a94cdb795fece1d8cbdbb46bf2663e2fa2b034947362835`,
the proof SHA256 is `af0313622dc0bd760d7684b42899e3fca22ae27ac109216358edfcc29e1294b7`,
and the host SHA256 is `2e620499a4df9b472cc8f52b90e8a9e0855cff8b062430e14515a1f1a0a9b0fe`.
These totals add host polling and rejection/recovery work; they are not a paired
performance comparison. CLI/language SDK mutation entry points and a combined
query-source/writer host remain outstanding.

### Main relational and verification integration

The SQL branch is rebased onto `5e0efd19`, retaining the new delivery simulation,
SDK administrative exact retries, disk-backed language-ring storage and actual
CPU-affinity reporting. Storage conflicts retain main's no-page-request/no-page-
creation gates and add direct current Store-read rejection. The service proof
requires Station/runtime support plus batching, retained versions and rotation.
The pre-rebase supplied-writer tree passes full `just check`, independent mutation
bytes, documentation and the verification catalog. Rebased committed-HEAD clean
qualification is a separate run; no unexecuted lane is reported as passed.

### Neutral Table mutation caller

The post-rebase supplied-host schedule passes at `8314f17b` in **12.407 s** with
1008 reads, the same node/proof/host digests as the preceding host run and unchanged
native bounds. Full clean CI at that committed revision is tracked separately.

`TableMutationBridge` adds owned neutral actions and results above the shared Zig
caller. Package tests match all six independently encoded commands, five request
variants and five stored phases. They preserve full-width namespaces, safe-counter
policy revision bounds, owned cells/strings and rejection before transport of
changed references, malformed saved commands and truncated references. An initial
test incorrectly gave policy revision the full u64 namespace range; the corrected
case uses its existing native safe-counter bound rather than widening the contract.

The real native proof now drives the supplied host through serialized neutral
compile/prepare/next/submit/observe/rejection/status actions. Compiled bytes and
opaque prepared text survive caller recreation and host replacement; premature
apply preserves upload status, terminal cancellation preserves the original result,
and current read revocation stops neutral status lookup. All earlier atomicity,
caller-send/writer-commit receipt loss, disk restart and fencing schedules remain.
The pass takes **12.347 s**, with **1063 reads**, **31 mutation-send responses**,
**34 turn responses**, two lost receipts, four mutations maximum and eight resident
authority pages. Its proof SHA256 is
`5c4d0ce1f6edea1c8faba49a8688012f75afea3e6eac10504e162cfcf7ef6e58`;
node and host digests remain those in the supplied-writer record. Extra metadata,
status and terminal-cancellation observations make this a different workload,
not a paired performance improvement. Package tests, independent wire fixtures
and documentation checks pass. Native ABI/port and installed SDK/CLI exposure
remain separate integration work.

### Mutation ABI and port callers

The explicit `station_table_mutation_create/call/destroy` API and
`mutation_client` port profile delegate to the neutral Zig bridge. Schemas and
all generated language resources are regenerated from public types. A structural
comparison confirms that existing exported signatures and all existing standalone
schemas remain unchanged; only HostConfig/HostRequest gain the new optional
profile/action, with three new mutation schemas. No existing wire or stored
meaning changes in this additive export.

Binding package tests pass current-target/signature validation before dispatch,
malformed recovery rejection, bounded handle overlap, unconfirmed transport
classification and buffers that outlive their client. The native schedule also
checks conflicting local/query/mutation profiles and read-query refusal of
mutation actions. The header generator initially needed the new opaque handle
name registered; generated declarations now include it in C and foreign resources.

`just test::table-mutation` passes in **16.044 s**. In addition to the earlier
native/host schedule, real C ABI and port callers each compile, stage and apply
an UPDATE, lose its accepted admission receipt, replace their handle/child, and
recover the identical saved command. Both read their original durable result,
and both stop after current native read revocation. Three caller receipts and one
writer-commit receipt are lost independently. The schedule records **1406 reads**,
**41 mutation-send responses** and **42 turn responses**, retaining four mutations,
256-byte values and eight resident authority pages. These additional callers and
faults expand the workload; the elapsed time is not a paired speedup comparison.

The port SHA256 is `85ca4859050fc68e0859c4a446464c488ee747b11e29c787b7e0fb15a6e2c436`
and library SHA256 is `b1bf78601f65df27a1038ee993fc8596ce0c770bb010a50905054a66e5dd603b`.
The node, proof and writer digests match the preceding neutral-caller record.
Actual idiomatic SDK callers, CLI integration and combined read/write source
composition remain separate boundaries; generated declarations alone do not
qualify them.

The final mutation tree also passes full `just check`, `just bindings::check`,
`just bindings::native`, documentation and the verification catalog. The broader
binding regression preserves local-codec/native-port parity, scoped controls,
poisoned reads, exact disk/host recovery, six independently decoded query segments,
current denial and materialization update/delete/reinsert behavior.

The separate committed-HEAD clean run at `8314f17b` passed core, growing authority,
service/maintenance and Station recovery, then exceeded the existing **180 s**
query-delivery deadline inside `test::growing-service`. The last recorded native
history position was 560 and commands were still succeeding; no assertion proved
incorrect results. This is an incomplete proof, not a pass or evidence that the
deadline is sufficient under shared-host contention. The failure checkout remains
`/var/tmp/transit-ci-n_3e42w_`. A focused `just test::query` rerun on that frozen
revision, after the binding regression finished, passed with the same binaries
and original deadline: write **7.550 s**, seal **11.852 s**, recovery **31.933 s**,
publication **3.586 s**, delivery **146.497 s**. It independently decoded 41 rows,
21,296 bytes and six IPC segments through exact retry and disk restarts during
staging, sealing, publication and partial consumption. The initial rerun stopped
before testing because Nix could not recreate a cached shell derivation; disabling
Nix's evaluation cache allowed the pinned bindings shell to start. This focused
pass does not convert the preceding incomplete clean run into a pass.

### Installed Python Table mutation callers

`just test::table-mutation --sdk python` passes with independently installed
0.2.0 wheels in a clean environment outside the checkout. Both public synchronous
and asynchronous callers compile an UPDATE, preserve opaque prepared bytes, lose
the admitted send receipt, close and recreate their caller, recover that exact
receipt, finish staging, and read the durable one-row result. Both stop status
disclosure after current native read revocation. Their exception adapters check
that uncertainty retains the exact original recovery bytes. The earlier native,
ABI, port and supplied-writer schedules remain in the same run.

The expanded schedule takes **22.645 s**, including **1.628 s** for installation.
The synchronous and asynchronous caller intervals take **2.455 s** and **2.444 s**;
they include caller creation, replacement, upload and result checks. The proxy
records **1791 reads**, **51 mutation-send responses**, **50 turn responses** and
six lost receipts (five caller sends plus one writer commit). The bounds remain
four mutations, 256-byte stored values and eight resident authority pages. Native
binary digests match the preceding ABI/port record. These are unpaired workload
measurements, not comparative SDK throughput claims.

An initial wrapper omitted Just's positional-arguments attribute, so its green
run exercised only native/port callers; it is excluded from Python evidence.
The corrected schedule prints its selected SDKs and per-caller completion.
Its first actual Python run exposed a test-adapter result-key mismatch; the
adapter now preserves the bridge's `observation` field. Both modes pass after
that correction. Shared native cases cover INSERT/UPDATE/DELETE; this installed
Python extension exercises UPDATE recovery, not an independent full SQL corpus.
The public Python API passes strict type checking across 21 source files, and
the complete repository `just check` passes. `bindings::python-test` owns
the installed mutation schedule, and `bindings::mutation-python` provides its
focused entry point. Other language mutation clients and the CLI remain separate
integration work.

The final `just bindings::mutation-python` rebuild/install/type-check rerun also
passes: **23.170 s**, **1777 reads**, unchanged send/turn/lost-receipt counts and
native digests, with **1.731 s** installation and **2.322/2.421 s** Python caller
intervals. Poll-dependent read counts and shared-host timings vary between runs.

### Installed TypeScript Table mutation caller

`just bindings::mutation-node` builds and installs the public/native packages
outside the checkout, passes strict TypeScript and formatting/lint checks, then
runs the same disk-backed mutation schedule through typed promise methods.
Its UPDATE uses namespace **18446744073709551615**, preserving the full uint64
through `bigint`, owned request/reference buffers, caller replacement and exact
admission retry. Current read revocation denies the original result afterward.
The caller's uncertainty object retains the original prepared text.

Seven boundary tests pass mutable-input/getter ownership, malformed saved text,
cross-realm targets, three unconfirmed receipt responses, a foreign status phase,
and missing/foreign contract definitions with otherwise matching v1 labels. The
shared Node Station port now checks its generated definition before caller work,
using the existing native capability owner. A version label alone never qualifies
a different native build. Generated schemas validate response variants at runtime;
semantic receipt validation also rejects position zero while retaining uncertainty.

The final focused schedule takes **22.768 s**, including **2.753 s** installation
and **3.796 s** for the installed Node caller interval. It records **1686 reads**,
**46 mutation-send responses**, **46 turn responses**, four lost caller receipts
and one lost writer-commit receipt. The four-mutation, 256-byte-value and
eight-resident-page bounds and native binary digests match the preceding ABI
record. The earlier installed trial took 23.433 s with 1680 reads; these unpaired
runs do not establish a performance improvement. The first focused task stopped
on Markdown formatting before its proof; the formatted guide and complete rerun
pass. The verification catalog and local documentation links pass.

`bindings::node-sdk-test` owns the installed mutation schedule, and the ordinary
Node checks include its runtime boundary tests. The installed mutation extension
exercises UPDATE; the shared native fixture remains the independent
INSERT/UPDATE/DELETE and rollback oracle. Remaining language adapters, CLI
integration and read-query/writer composition remain separate work.

The broader `just bindings::node-sdk-test` also passes with the shared definition
check: raw-client owned I/O and revoked exact retry; runner scope/gates, poisoned
reads, fencing/expiry, exact disk/host recovery, retained Tables and six owned IPC
segments; ordinary installed HTTP (**76.74 s**) and RPC (**77.52 s**) with staged
recovery, binary TLS, current denial and authenticated disposal/followup. Its
final mutation rerun takes **22.589 s** with 1685 reads and unchanged send/turn/
fault counts and native digests. No skipped case is counted as passed.

The next committed-HEAD `just ci-clean`, at
`d5f909864d11025849c76da28b1c9c48d2745b16`, also exceeded the unchanged **180 s**
query-delivery deadline in `test::growing-service`. Core, growing authority,
signed service/maintenance and Station recovery completed first. The failed
service task took 452.48 s; later lanes did not run. The retained clean checkout
is `/var/tmp/transit-ci-ljgt0r26`. This is incomplete clean evidence for the
Python/TypeScript checkpoint, not qualification of subsequent Ruby/Rust commits.
No timeout or authority bound was relaxed.

### Installed Ruby Table mutation caller

`just bindings::mutation-ruby` rebuilds and installs the public/native gems in
an external consumer, checks Ruby syntax, and passes the shared native schedule.
Typed value constructors copy and freeze request/reference bytes; the consumer
mutates the original strings and verifies that the saved request is unchanged.
The UPDATE uses namespace **9223372036854775825**, survives a lost admission
receipt and caller replacement, recovers the exact original send, observes the
durable one-row result, and stops disclosure after current read revocation.
The native ABI, port and Ruby callers also reject a changed complete request
commitment before preparing a valid stage. No adapter reconstructs that identity.

The final focused run takes **19.970 s**, including **1.810 s** installation and
**2.325 s** for the Ruby caller interval. It records **1592 reads**, **46 send
responses**, **46 turn responses**, four lost caller receipts and one lost writer
receipt. Four mutations, 256-byte stored values, eight resident authority pages
and all five native artifact digests match the ABI/port record. The initial
installed trial before the altered-commitment case took 20.861 s with 1617 reads.
These are unpaired shared-host measurements with poll-dependent counts; no
comparative throughput improvement is claimed. The installed extension exercises
UPDATE recovery; shared native cases cover INSERT/UPDATE/DELETE and rollback.

Block-based acquisition reuses the existing all-interrupt mask so its ensure
clause owns worker/child cleanup before caller interruption can arrive. The port
uses the existing generated definition and action/result validation. The ordinary
Ruby SDK task now includes the mutation schedule; this focused evidence does not
claim that the entire Ruby runner/connector regression was rerun for this additive
adapter. CLI and seven other typed language mutation clients remain outstanding.

### Installed Rust Table mutation caller

`just bindings::mutation-rust` builds the public/native crates and an external
consumer without source-checkout artifact overrides. The installed blocking
client uses namespace **9223372036854775826**, rejects an altered full request
commitment, preserves the borrowed prepared command across receipt loss, replaces
its native caller and recovers the identical admitted send. It observes the
one-row UPDATE result, then stops disclosure after current native read revocation.
A separate compiler check rejects overlapping mutable borrows of the client.
The executable runs after its consumer source, vendor directory and build outputs
are removed, so its embedded native dependency owns execution.

The focused schedule passes in **30.939 s**, including **12.434 s** for external
compilation/installation and **2.311 s** for the Rust caller interval. It records
**1587 reads**, **46 send responses**, **46 turn responses**, four lost caller
receipts and one lost writer receipt. Four mutations, 256-byte stored values,
eight resident authority pages and all five native artifact digests match the
ABI/port record. These unpaired measurements include compilation and polling;
they do not establish comparative SDK throughput. This installed extension
exercises UPDATE recovery; shared native cases cover INSERT/UPDATE/DELETE and
rollback.

The first installed attempt stopped at a test-only lockfile equality assertion
before mutation execution: Cargo pruned the unused optional Arrow dependency
graph. No registry package version or checksum changed or was added. The consumer
now requires every retained registry identity to match the packaged lock, rejects
an unexpected Arrow dependency and builds with `--locked --offline` after that
check. A source development check initially lacked embedded native artifacts;
selecting the documented local native-directory override allowed it to pass.
Neither initial failure is counted as mutation evidence.

The ordinary Rust SDK task now includes this schedule. This focused result does
not claim a rerun of the entire Rust runner/connector regression. CLI and six
other typed language mutation clients remain outstanding.

### Installed C and C++ Table mutation callers

`just bindings::mutation-c` rebuilds the public/native archives and compiles C11
and C++17 consumers outside the checkout using installed pkg-config discovery.
Their UPDATE namespaces are **9223372036854775827** and **9223372036854775828**.
Each rejects a changed complete request commitment, replaces its caller after an
accepted-but-lost receipt, retries the original saved bytes, observes application
and stops disclosure after current read revocation. Imports copy caller buffers;
the consumers overwrite those buffers and verify unchanged compiled/prepared
values. Saved prepared commands remain readable after native client close. C
failure outputs clear, and C++ client copying rejects during compilation.

The focused schedule passes in **24.933 s**, including **4.196 s** for installed
consumer compilation and **2.214/2.245 s** for the C/C++ caller intervals. It
records **1768 reads**, **51 send responses**, **50 turn responses**, five lost
caller receipts and one lost writer receipt. Four mutations, 256-byte stored
values, eight resident authority pages and all five native artifact digests match
the ABI/port record. The command ran with CPU affinity 2–47, separate from the
concurrent clean run's first allowed CPU. Timings and polling counts are unpaired
observations, not comparative throughput claims. The installed extension exercises
UPDATE; shared native cases remain the INSERT/UPDATE/DELETE and rollback oracle.

The ordinary C/C++ SDK task includes the mutation schedule. Java, .NET, Erlang,
Elixir and CLI mutation clients remain separate implementation boundaries.

The C/C++ tree passes full `just check`, including native contract drift, unit
checks, the verification catalog, frontend checks and documentation build. The
broader installed runner/connector regression is recorded separately when complete.

The broader `just bindings::c-sdk-test` also passes after loading the added native
mutation entry points through the shared C bridge. Both installed raw clients
preserve owned I/O, exact seedless recovery and current denial. Both Station
runners preserve scope/gates, callback errors, poisoned reads, fencing/expiry,
exact disk/host recovery, retained Tables and six owned IPC segments. Installed
C/C++ HTTP schedules pass in **75.51/78.73 s**, and gRPC in **79.47/86.94 s**,
including staged recovery, binary TLS, current denial and authenticated disposal
and followup. The final mutation rerun passes in **24.968 s** with 1776 reads,
unchanged send/turn/fault counts and native artifact digests. No skipped case is
counted as passed. This working-tree regression is separate from committed-HEAD
clean qualification.

### Installed Java Table mutation caller

`just bindings::mutation-java` builds the public/native JARs with the pinned Java
21 compiler, then compiles an external consumer using `-Xlint:all -Werror`.
Immutable values retain full-width namespace **9223372036854775829**. The caller
rejects a changed full request commitment, preserves owned input/getter copies,
replaces its port/worker after receipt loss, recovers the exact admitted send,
observes the one-row result and stops status disclosure after current native
read revocation. Saved prepared bytes remain unchanged on success or uncertainty.
Generated request/result schemas and the existing bounded worker remain shared.

The focused schedule passes in **19.824 s**, including **0.936 s** for installed
consumer compilation and **2.964 s** for the Java caller interval. It records
**1628 reads**, **46 send responses**, **46 turn responses**, four lost caller
receipts and one lost writer receipt. Four mutations, 256-byte stored values,
eight resident authority pages and all five native artifact digests match the
ABI/port record. The command ran on allowed CPUs 3–47. These unpaired shared-host
measurements do not establish comparative throughput; this installed extension
exercises UPDATE, while native cases cover INSERT/UPDATE/DELETE and rollback.

The first consumer compilation stopped on missing optional Error Prone annotations
referenced by Gson's `JsonParser` class. Using the same `Gson.fromJson` test-frame
reader as the existing installed consumers resolves that warning without adding
dependencies or relaxing lint. This compile-only failure is not mutation evidence.
The ordinary Java SDK task now includes the schedule; no full Java runner/connector
regression rerun is claimed for this additive adapter. .NET, Erlang, Elixir and
CLI mutation callers remain outstanding.

The Java increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build. Its installed consumer passes strict Java 21 compilation.

### Installed .NET Table mutation caller

`just bindings::mutation-dotnet` builds the public/native NuGet packages and
restores an external .NET 8 consumer from only those exact local artifacts.
Compilation treats warnings as errors. The executable runs after its source and
restore cache are removed, without a checkout native-library override. Immutable
values retain namespace **9223372036854775830**, copy input/output arrays and
expose read-only column names. The caller rejects a changed request commitment,
replaces its worker after receipt loss, recovers the exact admitted send, observes
the one-row result and rejects current status disclosure after read revocation.
Prepared bytes survive both successful and uncertain submission unchanged.

The focused schedule passes in **21.404 s**, including **2.577 s** for installed
consumer restore/compilation and **2.560 s** for the .NET caller interval. It
records **1598 reads**, **46 send responses**, **46 turn responses**, four lost
caller receipts and one lost writer receipt. Four mutations, 256-byte stored
values, eight resident authority pages and all five native digests match the
ABI/port record. The command ran on allowed CPUs 2–47. These unpaired shared-host
measurements do not establish comparative throughput. The installed extension
exercises UPDATE; native cases cover INSERT/UPDATE/DELETE and rollback.

The adapter uses the existing bounded worker's cancellation and joined disposal
semantics. This schedule observes asynchronous disposal and caller replacement;
it does not independently inject cancellation into every mutation method. The
ordinary .NET SDK task now includes the schedule. No full .NET runner/connector
regression rerun is claimed for this additive adapter. Erlang, Elixir and CLI
mutation callers remain outstanding.

The .NET increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build.

### Installed Erlang and Elixir Table mutation callers

`just bindings::mutation-beam` builds separate public/native OTP applications,
checks Elixir formatting and compiles external consumers with warnings as errors.
The callers run after their source is removed, without a checkout native-host
override. Erlang records and Elixir structs preserve immutable binaries and
full-width namespaces **9223372036854775831** and **9223372036854775832**.
Both reject changed request commitments, retain the original prepared value in
uncertain results, replace their caller after receipt loss, recover the exact
admitted send and observe the one-row result. Saved values remain readable after
close; current read revocation denies status disclosure. Generated validation
and the existing bounded worker/port own every crossing.

The focused schedule passes in **23.190 s**, including **2.151 s** for installed
consumer compilation and **2.462 / 2.610 s** for the Erlang/Elixir caller intervals.
It records **1790 reads**, **51 send responses**, **50 turn responses**, five lost
caller receipts and one lost writer receipt. Four mutations, 256-byte stored
values, eight resident authority pages and all five native digests match the
ABI/port record. The command ran on allowed CPUs 2–47. These unpaired shared-host
measurements do not establish comparative throughput. Installed extensions
exercise UPDATE; native cases cover INSERT/UPDATE/DELETE and rollback.

The ordinary BEAM SDK task includes both schedules. No full BEAM runner/connector
regression rerun or new process-death injection is claimed for these adapters;
they reuse the existing worker's ownership and joined cleanup. Ten language SDKs
now expose the bounded mutation profile. CLI composition, broader SQL operations
and post-cutover inspection qualification remain outstanding.

The BEAM increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build. The installed consumers pass Erlang and Elixir compilation
with warnings as errors.

### Standards-main rebase and clean CI boundary

The SQL branch rebases through main `f481f2b9`, including `c50ee96a`'s standards,
multi-model and historical-schema analysis. Runtime, fixtures, generated contracts
and SDK source remain byte-for-byte unchanged by this rebase. The conflicts were
the roadmap index and the independently added M38: main's standards/branching M38
is preserved, and the SQL continuation becomes M39 at that checkpoint (now
[SQL and dataflows](../../roadmap/12-sql-and-dataflows.md) after inserting the type-system prerequisite). Original author and committer
dates are preserved by `git rebase --committer-date-is-author-date`.

The committed clean run at pre-rebase Rust checkpoint `0b680b71` did not finish.
It passed core and the growing-service schedule in **428.16 s**, including query
delivery in **148.517 s** under its unchanged 180-second bound. Public query,
publication, native mutation, HTTP/gRPC libraries/transport/server and Flight
metadata also passed. The ordinary gRPC worker proof passed in **736.96 s**
(**726.53 s** excluding compilation), with nine sends and eight applications.

`test::grpc-faults` then failed after **402.84 s**, after its preparation,
dispatch, completion and observation recovery cases. During preparation of the
second finite-lifetime exchange, an accepted send was followed by a native read
returning HTTP 503 `DeadlineUncertain`, surfaced as `AuthorityUnavailable`.
This is in the scenario that provisions a 60-second work cutoff before staging
two exchanges; it did not reach the blocked-peer/control assertions. The log
does not establish a generic transport outage. Deadlines and authority gates
remain unchanged. The retained checkout is `/var/tmp/transit-ci-zlmded5l`, with
the command log at `/tmp/transit-sql-rust-ci-clean.log`. Later suite tasks did
not run. This failure is not a pass and the frozen checkpoint does not qualify
the later C/C++, Java, .NET or BEAM mutation adapters.

A separate `just test::grpc-faults` rerun in that same frozen checkout passes in
**191.38 s** excluding compilation, on allowed CPUs 2–47. It covers all four
recovery boundaries, current dispatch revocation, the work cutoff, forged
observation, blocked-peer closure and retirement. It records five sends and five
applications, an 8 MiB hot budget, and 402 cold objects totaling 40,130,309 bytes.
The log is `/tmp/transit-sql-rust-frozen-grpc-faults.log`. This focused pass does
not complete the failed full clean run or qualify later code.

### Explicit CLI Table mutation caller

`just test::table-mutation` now includes the real `transit mutate` executable in
the native/port fault schedule. Every command runs in a fresh process. The CLI
compiles UPDATE with namespace **9223372036854775833**, saves new private 0600
artifacts and refuses an existing output path without replacing its bytes.
Altered commitments reject. After an accepted-but-lost receipt, another process
locates the original prepared file and recovers the same receipt. Observation,
separate input rejection and durable status remain distinct. Explicit apply
before sealing rejects; cancellation after application preserves the terminal
result. Current read revocation denies status disclosure. Input artifact bytes
remain unchanged on success and uncertainty.

The schedule passes in **19.383 s**, with **1657 reads**, **48 send responses**,
**48 turn responses**, four lost caller receipts and one lost writer receipt.
Native, port and CLI intervals are **1.625 / 1.848 / 2.999 s**. Four mutations,
256-byte stored values, eight resident authority pages and the five native
artifact digests match the ABI/port record. The CLI ReleaseSafe digest is
`9c82e91ef5180c1ce6fde4e578262b03ed65a1150f91fb3a09f536a55629a0bb`.
Commands ran on allowed CPUs 2–47. These unpaired shared-host measurements are
not comparative throughput evidence. The CLI extension exercises UPDATE;
native cases cover INSERT/DELETE/rollback. This does not establish combined
read/write sessions or a power-loss proof for local artifact persistence.

`just test::cli-diagnostics` passes **237 real-command cases**, including offline
mutation help/capabilities, strict options and numeric bounds, version and URL
validation, and malformed local artifacts rejecting before credential loading.
The log is `/tmp/transit-sql-cli-mutation-diagnostics.log`; the mutation schedule
is `/tmp/transit-sql-cli-mutation-proof.log`.

After tightening the test adapter to require a CLI-created prepared artifact
instead of permitting a reconstructed fallback file, the schedule passes again
in **18.423 s**, with **1653 reads**, the same 48 send/turn responses, lost-receipt
counts, bounds and artifact digests. Caller intervals are **1.575 / 1.800 /
2.742 s**. The log is `/tmp/transit-sql-cli-mutation-final.log`.

The CLI increment passes full `just check`, including generated-contract drift,
native unit/CLI checks, the verification catalog, frontend checks and the
documentation build. The log is `/tmp/transit-sql-cli-mutation-check.log`.

### CLI checkpoint clean validation

Committed `42325495` ran `just ci-clean --lane core`. Foundation checks,
properties, simulation, independent package builds, ABI, Station and disk
storage recovery passed. The service proof failed at its first worker Table
turn after an accepted view: HTTP 503 `AuthorityUnavailable` replaced the
expected success (`tests/service.py:146`). Later core tasks did not run. No
deadline or authority bound was relaxed. The checkout remains at
`/var/tmp/transit-ci-66hrmfd0/src`; the log is
`/tmp/transit-sql-cli-ci-clean.log`. A separate `just test::service` in that
unchanged frozen checkout passes, including scoped revocation, worker fencing,
disk recovery, retirement/trim and uncertain dispatch closure/replay. Its log is
`/tmp/transit-sql-cli-frozen-service.log`. This focused pass does not complete
the failed clean lane.

### Publication domains and coordinated caller cutover

The current native definition is
`2577b1247a78a2f8a3eae59b3b36a286fedf9836759d19325edd9b3318b5bad5`.
Publication keys include a required domain; SPF1 references are 72 bytes.
This separates query results from mutation requests with the same full-width
namespace and record ID. Native SDK publication actions and caller-staged
HTTP/RPC/Document bodies use the application domain. Generated definitions,
neutral resources, signing fixtures and all ten SDK reference validators change
together. Earlier proof entries retain their original definition and evidence.

Full `just check` passes, including contract drift, independent wire fixtures,
237 CLI diagnostics, frontend checks and the documentation build. After adding
the index-cache isolation regression, `just test::unit` passes again. Unit
schedules cover independent budgets/content/cleanup/cursors at equal full-width
IDs, missing/old-length references, upload-marker retargeting, typed domain
rejection before resource reads and a cached node that cannot conceal a missing
chunk in another domain. Logs are
`/tmp/transit-sql-publication-domains-check.log` and
`/tmp/transit-sql-publication-domains-unit-final.log`.

`just test::publication` passes with a 64 KiB record and 41 additional retained
records, four killed workers, exact append/publication/cleanup retries and
one-page recovery. Stage/seal/publish/cleanup/finish intervals are
**33.816 / 2.926 / 20.478 / 14.006 / 87.795 s**. It records **2447 reads** and
**309 turns**, at most four mutations and 256-byte values. The record's logical
key/value size is **72579 bytes**, with **59 bytes** per domain/namespace
budget. The first attempt exposed an outdated fault-injector key offset, now
corrected. The next attempt failed on an expired-view read with HTTP 503
`DeadlineUncertain` surfaced as `AuthorityUnavailable`, instead of the expected
`StateViewExpired` rejection. An unchanged rerun passed all phases; this is
not a deadline reliability guarantee. Logs are
`/tmp/transit-sql-publication-domains-native.log` and
`/tmp/transit-sql-publication-domains-native-rerun.log`.

All SDK package builds pass. `just test::table-mutation --sdk python --sdk node
--sdk rust --sdk ruby --sdk c --sdk cpp --sdk java --sdk dotnet --sdk erlang
--sdk elixir` passes native/port/CLI and every installed language caller,
including both Python schedules. The native case still covers INSERT/UPDATE/
DELETE and rollback; installed extensions cover UPDATE recovery. It completes
in **78.473 s**, with **3859 reads**, **103 send responses**, **92 turn responses**,
15 lost caller receipts and one lost writer receipt. Four mutations, 256-byte
values and eight resident pages remain the bounds. SDK installation takes
**29.975 s**. Caller intervals range from **1.654 s** (native) to **3.841 s**
(Node); these expanded, unpaired intervals do not establish comparative
throughput. The log is `/tmp/transit-sql-publication-domains-mutations.log`.
The proof freezes and hashes its ReleaseSafe artifacts before the schedule:

| Artifact       | SHA-256                                                            |
| -------------- | ------------------------------------------------------------------ |
| Node           | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Mutation proof | `0c78c1dbf03eec1f793f6dfb89ed9bd53b719e1cca3efcc4a93ce505c1a4f264` |
| Supplied host  | `dcc9d8410d9e42d896c54561b589353079a177c7fdf37f2976a4827481e9ebef` |
| Native port    | `e27d4229e22812c09e74bfcec9224231cee323d7d596f04ea1d44e7752551196` |
| Shared library | `946c36f43c9736e6905309bf21ed1374bdb858f740360c866f87b1e012753992` |
| CLI            | `34f72173cd1b2338e2756f7c1040852a055999c6e272f0540c72e044da9c5e28` |

The domain prerequisite does not enable a combined query/writer host. Separate
read/write policies, bounded initialization and interleaved snapshot/mutation
proofs remain M36 work. Query and other owner recovery qualifications are
recorded separately from the mutation schedule; it does not prove them.

`just test::build` compiles all application and integration entry points with the
required domains, including HTTP request readers and the application proof.
`just test::application` passes signed publication, exact append/final receipt
recovery, three worker kills, disk restart with one resident page and current
policy/resource denial. Its stage/seal/publish/finish intervals are **0.956 /
1.058 / 0.507 / 0.817 s**, with **195 reads** and **20 turns**, at most four
mutations and 256-byte values. The independent fault selector now checks the
application-definition domain and the new record offset. Logs are
`/tmp/transit-sql-publication-domains-build.log` and
`/tmp/transit-sql-publication-domains-owners-final.log`.

`just test::reactive-refresh` passes in **70.95 s**, including two shared-principal
views, one active admission, exact lost follow receipt, worker replacement,
full-width identities and entry-read denial while metadata remains readable.
An initial run timed out because the independent UQU1 decoder still selected
the old phase offset; the corrected decoder selects the phase after the 72-byte
reference. The successful log is
`/tmp/transit-sql-publication-domains-refresh-document.log`.

The separate clean bindings run at pre-cutover `f6698e0c` has passed Python,
Node, Rust, Ruby and C/C++ complete SDK regression tasks in **594.61 / 714.73 /
795.18 / 467.73 / 1018.21 s**, respectively. It continues with Java and later
tasks in `/var/tmp/transit-ci-aupu5a9d/src`. These completed tasks qualify that
frozen definition only; neither the unfinished lane nor these earlier runtime
artifacts qualify the publication-domain cutover. The log is
`/tmp/transit-sql-ten-sdk-ci-clean.log`.

`just test::unified-query -Doptimize=ReleaseSafe
-Dunified-sdk=python,node,ruby,rust,c,cpp,java,dotnet,erlang,elixir` passes all
three source schedules on the new definition. Each agrees on SQL inspection
across thirteen enabled native/port/SDK caller variants, retries the frozen
upload, restarts both workers, node and disk store after segment staging, reads
verified results, enforces prefix revocation and checks released source pins.
Each installed SDK also runs independent Arrow/schema/cell-state codec cases.

| Source   | Rows / segments / IPC bytes | Resident pages | Schedule seconds |
| -------- | --------------------------- | -------------- | ---------------- |
| KV       | 41 / 6 / 13584              | 8              | 139.07           |
| Table    | 41 / 6 / 13584              | 8              | 147.78           |
| Document | 12 / 2 / 9880               | 64             | 431.70           |

The source intervals include isolated SDK installation and provisioning; they
are not query-latency or cross-source performance comparisons. Every schedule
uses an 8 MiB hot-store budget with persisted cold objects. The log is
`/tmp/transit-sql-publication-domains-query.log`. Shell/Board/browser options
were not selected by this run.

`just test::http-worker` passes disk recovery, exact native retry, credential-free
replay, cleanup, explicit/public followups and disposal, caller termination,
name rebinding and partial-capture loss: **16 sends**, **8 remote applications**,
**2 cancellation requests**, **526.93 s** excluding compilation. Its 8 MiB hot
store leaves **1087 cold objects / 129751880 object-store bytes**. The log is
`/tmp/transit-sql-publication-domains-http.log`. Final `just check-core` also
passes after the owner and test-adapter corrections; its log is
`/tmp/transit-sql-publication-domains-core-final.log`.

`just test::document` passes staged index, acceptance, checkpoint and terminal
cleanup recovery, with exact lost receipts at all four boundaries. Its independent
fault selector uses the Document publication domain and new key offsets.
Stage/accept/checkpoint/finish take **6.394 / 56.199 / 89.802 / 209.724 s**;
the final phase recovers with one resident authority page. It records **8984
reads**, **361 turns**, three killed workers, at most four mutations and 256-byte
values. The 8 MiB hot store leaves **460 cold objects / 43721160 bytes**. The
log is `/tmp/transit-sql-publication-domains-refresh-document.log`.

The committed-HEAD clean core run at `fd929ddc` passed foundation checks,
properties, simulation, codecs, deployment/telemetry, independent package builds
and compute. It then failed in the raw client ABI's signing vectors: the SDK
operation fixture's canonical definition had changed but its expected digest
and signature were stale. This is a fixture defect, not a passing ABI proof.
Later core tasks did not run. The source/log evidence is retained at
`/var/tmp/transit-ci-uwms4hww/src` and
`/tmp/transit-sql-publication-domains-ci-clean.log`.

The two SDK operation digests and Ed25519 signatures are regenerated from the
fixture's public test seed using independent SHA-256 and OpenSSL signing.
The foundation verification check now checks their definition, canonical JSON
and digest before native builds. `just test::client-abi` then passes standalone
port checks, canonical signatures, full-width growing identities, disk/host
restart, exact uncertain recovery, current revocation and malformed replies.
The log is `/tmp/transit-sql-publication-domains-client-abi.log`. This focused
pass does not complete the earlier failed clean lane.

After the fixture correction, **`just ci-clean --lane core` passes at committed
`79b648b2`** without inherited workspace build outputs. All core tasks complete,
including foundation/CLI checks (**74.24 s**), properties/simulation, independent
package builds (**136.52 s**), raw client ABI (**6.32 s**), Station (**149.86 s**),
disk storage (**390.85 s**), signed service (**64.94 s**), runtime upgrade,
runnable callers (**22.81 s**), inspection (**7.50 s**) and state (**17.61 s**).
The readiness write takes **241.79 s** within the existing fixture bound. The
log is `/tmp/transit-sql-publication-domains-ci-clean-fixed.log`; completion
evidence is `.cache/ci/clean/79b648b2c3ed-transit-ci-vz30niqm`. This is a complete
core-lane pass, not a full-suite pass.

`just test::unified-ingress table` and `just test::unified-ingress kv` pass the
actual SQL shell, generated Board client, concurrent Board instances and browser
worksheet on this definition. They preserve frozen signed retries, separate
inspection/query grants, current prefix denial, complete results, retirement and
draft/view separation. Table also proves finite Live draft budgets and exact
saved recovery. The full source schedules take **212.76 / 177.37 s**, each with
41 rows, six IPC segments and eight resident authority pages. Two Board instances
use **42582016 / 40566784 bytes RSS** in the respective samples. The Table draft
budget schedule takes **17.25 s**. The log is
`/tmp/transit-sql-publication-domains-ingress-rerun.log`. Document ingress also
passes: **12 rows / 2 segments / 9880 bytes**, 64 resident pages, **501.78 s**
including provisioning, and **45400064 bytes** for the two-Board RSS sample.
Its independent browser checks cover SQL inspection, exact uncertain retry,
current denial and provenance. The first invocation failed before execution
on a missing cached Nix shell derivation. Disabling the Nix evaluation cache
recreates the pinned shell; no toolchain or lockfile changes are involved.

The older clean bindings lane at `f6698e0c` finishes the individual Java,
.NET and BEAM suites in **506.37 / 480.87 / 1173.37 s**. All selected language
suites pass at that earlier definition. Cross-language `bindings::sdk-interop`
then fails after **298.97 s**: MinIO returns HTTP 507 `XMinioStorageFull`, Ursula
cannot stage pages and the exact delivery retry reaches its existing deadline
with `AuthorityUnavailable`. This is a failed lane; later tasks did not run.
The checkout and evidence remain at `/var/tmp/transit-ci-aupu5a9d` and
`/tmp/transit-sql-ten-sdk-ci-clean.log`. Only ignored compiler caches in other
inactive proof clones are removed to recover disk capacity; retained source and
failure logs remain. These older language passes do not qualify the current
publication-domain definition.

After restoring disk capacity, the unchanged frozen-checkout
`just bindings::sdk-interop` rerun passes all **ten different-language pairs**
in **462.5 s**, including isolated consumer installation, lost receipts, worker
restart, typed Table/query results and owned IPC. Its log is
`/tmp/transit-sql-ten-sdk-interop-rerun.log`. This focused pass does not complete
the failed bindings lane or qualify the current definition.

### Combined Table owner component checks

`TableQueryWriter`'s independent configuration/state/control vectors and five
component schedules pass with the pinned compiler. They model four-mutation
initialization phases, replacement of the in-memory owner, duplicate and forged
continuations, early ingress, independent policy revisions, whole-proposal
rollback and poisoned reads. These in-memory tests are not native durability
evidence. `just check-core` passes with the supplied `table_query_writer` role.

The existing `just test::table-mutation` native/port/CLI schedule also passes
after extracting the shared two-write declaration helper: **19.287 s**, **1661
reads**, **48 turns**, four lost caller receipts plus one lost writer receipt,
eight resident authority pages, four mutations and 256-byte values. This proves
the existing standalone host still recovers; it does not yet prove the new
combined host's two-turn or interleaved query/mutation schedule. Logs are
`/tmp/transit-sql-combined-table-unit.log` and
`/tmp/transit-sql-combined-table-check.log`.

`just test::table-query-writer` now passes against the actual supplied host,
disk-backed Ursula and public ABI/CLI callers. It loses each initialization
commit's receipt, kills the worker, restarts node/storage, recovers the original
signed commit, and requires fresh ownership while refusing activation reuse.
The staged phase has neither initial policy; the ready phase has both. Repeated
initialization leaves their revisions unchanged.

The schedule admits a durable query, pauses its self continuation, opens an
interactive console snapshot, then commits a CLI UPDATE using the durable
query's **same numeric publication namespace**. Both earlier snapshots contain
the old row; subsequent durable and interactive queries contain the new row.
Query-policy revocation prevents old-result disclosure while separately
authorized mutations still succeed. Mutation-policy revocation rejects new
mutations while new queries succeed. Native read revocation finally prevents
disclosure. Independent PyArrow decoding verifies the complete typed cell
envelopes and values.

The clean attempt at `7f2ef35f` exposed a synchronization problem in that fixture:
it held an interactive snapshot read while performing the entire CLI mutation
upload, seal and apply. The console keeps its ordinary five-second request
timeout; the extra setup exceeded it. The fixture now stages and seals before
opening the console snapshot, freezes the final apply command, and holds the
snapshot read only until that apply input is processed. It checks the applied
outcome, affected row and original input separately, then compares both retained
cuts and both later queries. `snapshot_pause_seconds` records the harness's final
apply interval. Workload rows, numeric namespace collision, request deadlines,
resident bounds and recovery/policy assertions remain unchanged. The focused
rerun reaches all retained/latest query assertions, then fails in later policy
progress polling on `StaleStateResource`: that poll opened a Table-policy view
while the turn being observed could change its resource revision. The progress
probe now reads only the current process input. Separate phase, policy and row
assertions still check their owning state; no rejection is swallowed or retried.
The first focused log is `/tmp/transit-sql-combined-snapshot-final-apply.log`.

With both fixture corrections, `just test::table-query-writer` passes in
**106.683 s**, with **5001 reads**, **70 turn responses**, both recovered
initialization receipts and a **1.085 s** final-apply pause. Four mutations,
256-byte values, eight authority pages, and the five-second console deadline
remain unchanged. The log is `/tmp/transit-sql-combined-snapshot-progress.log`.
This run covers native/CLI callers; it does not expand installed SDK coverage.
A new committed-head clean growth run is still required; neither earlier failed
run is reclassified as a pass.

The schedule takes **54.355 s**, including provisioning/recovery, with **5303
reads**, **70 accepted turn responses**, two recovered initialization receipts,
at most four mutations, 256-byte values and eight resident authority pages.
It uses an 8 MiB hot store with disk-backed cold storage. Read counts include
10 ms worker polling and the fixture's explicit one-output delivery scans;
this is not a query latency or operator throughput benchmark. The log is
`/tmp/transit-sql-combined-table-cli-leases.log`. ReleaseSafe binary SHA-256 values:

| Binary                 | SHA-256                                                            |
| ---------------------- | ------------------------------------------------------------------ |
| Node                   | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Query host             | `12abd330c24290badb25df477fe5133613a726c46394e702b6525ce7d872c1a6` |
| Proof                  | `f59d9965cc31aa9aeddeaf14ce3052a600a5b1fa99c3ab8bcf286075c5524380` |
| Shared Station library | `946c36f43c9736e6905309bf21ed1374bdb858f740360c866f87b1e012753992` |
| CLI                    | `34f72173cd1b2338e2756f7c1040852a055999c6e272f0540c72e044da9c5e28` |

Earlier attempts exposed fixture defects: its delivery scan failed to reacquire
an expired read, its first result assertion expected flat values instead of the
shared Arrow cell envelopes, and its command runner expected JSON from a void
revocation command. These attempts remain failures in
`/tmp/transit-sql-combined-table-native{,-rerun,-final}.log`; correcting them did
not change the combined owner's implementation or relax its bounds. Full
`just check` also passes, including frontend validation/tests and the documentation
site build (`/tmp/transit-sql-combined-table-full-check.log`). The new native
schedule is registered in the growth lane; it is separate from a committed-HEAD
clean run and from the installed SDK matrix.

The optional combined-host mutation SDK matrix also passes:
`just test::table-query-writer --sdk python --sdk node --sdk rust --sdk ruby
--sdk c --sdk cpp --sdk java --sdk dotnet --sdk erlang --sdk elixir`.
All ten installed SDKs (eleven caller variants with Python sync/async) resume
the exact saved command after losing an admitted send receipt and replacing the
caller, then observe one applied full-width-namespace UPDATE. Current native
read revocation prevents each caller from disclosing its earlier status. The
same run includes the initialization and durable/interactive CLI snapshot cases
above. Query result reads here use the public native ABI and console; installed
query SDK source coverage is recorded in the preceding query matrix.

This larger schedule takes **132.498 s**, including **29.646 s** isolated SDK
installation, **8736 reads**, **114 accepted turn responses** and eleven lost
SDK admission receipts in addition to the two initialization receipts. Caller
intervals span **2.894–4.279 s** and include upload, deliberate failure, caller
replacement and status checks; they are not statement execution timings. The
four-mutation, 256-byte and eight-page bounds hold. Frozen native binary hashes
match the table above. The log is `/tmp/transit-sql-combined-table-sdks.log`.

**`just ci-clean --lane core` passes at committed `a3c40a0d`** in a fresh
checkout without inherited build outputs. It completes foundation checks
(**68.31 s**), properties/simulation, independent package builds (**137.49 s**),
client ABI (**6.20 s**), Station (**147.94 s**), disk storage (**212.77 s**),
signed service (**44.19 s**), runtime upgrade (**4.94 s**), callers (**16.99 s**),
inspection (**4.23 s**) and state (**11.08 s**). Readiness write takes **129.48 s**;
these unpaired runs do not establish a performance improvement. The log is
`/tmp/transit-sql-combined-table-ci-clean.log`; copied timing/completion evidence
is `.cache/ci/clean/a3c40a0d6006-transit-ci-ux_5ezz5`. Later commits add the optional
SDK test schedule and documentation, with the production source unchanged.
This is a complete core-lane pass plus the separately executed combined-host
proofs, not a complete clean-suite pass.

### Console SQL routes, diagnostics and exact write recovery

The console dispatches bounded mutations and compatible Table declarations to the
shared signed clients through explicit `writes.table` / `writes.catalog` routes.
Located parser failures and the shared diagnostic presenter distinguish syntax,
unsupported constructs, reference-only families, unavailable interfaces and
binding errors. This does not extend the accepted mutation grammar, install
writers/catalogs, grant rights or enable Flight writes.

Local focused runs for issue #46 completed with the pinned development shell:

```sh
just check
just test::sql
just test::table-query-writer
just test::catalog
just test::flight
```

`just check` includes **419 real CLI cases**, including both reported INSERT
forms, missing catalog routes, incompatible Table definitions, statement/batch
bounds, locations, escaped/redacted context, and a listening trap proving invalid
SQL makes no authority call. The SQL corpus retains **113 SELECT ASTs, 92 plans,
28 unified results, 31 mutation cases and 182 declaration cases**. These compiler
checks alone make no admission or durability claim.

The real console in `tests/table_query_writer.py` runs against the combined host
and disk Ursula. It inserts, updates and deletes, observes zero-row results and
atomic duplicate-key rejection, and reads the resulting rows. It loses a native
receipt, verifies the original saved signature, reopens without submission, rejects
changed key/connection or missing-definition recovery, and explicitly resumes
exactly once. SIGINT preserves admitted work and prevents the following batch
statement from running; `.cancel` reconciles the input and observes cancellation.
A proxy holds a prepared part while a distinct administrator revokes policy.
The rejected input leaves its upload recoverable, blocks replacement work and
can still be cancelled. The policy-race focused run completed in **51.73 seconds**,
with at most four mutations per turn, 256-byte values and eight authority pages.

The real catalog proof runs CREATE TABLE through the console, loses its receipt,
verifies no replay on open, resumes the original signed command, checks the
explicit creation-cancellation limitation, and resolves the created definition
through DESCRIBE and paged SHOW TABLES. Duplicate names report the recorded
conflict; revoked inspection prevents `.status` disclosure. The final catalog
report has `completed: true` and no cleanup failures. The first attempt's new
Python variable shadowed its report function during finalization; that attempt
failed and is not counted as a complete proof.

Flight schema and execution tests cover error categories, coordinates, guidance,
redaction, authentication/current authorization before diagnostics, and no
admission for rejected SQL. Full finite-result recovery and independent PyArrow,
ADBC Python and ADBC C checks pass. Remote public messages retain their 128-byte
ASCII bound; a longer draft message failed its unit check and was shortened.

Console batch and controlling-PTY regressions keep result stdout separate from
errors and preserve recovery files on rejected SQL. Valid INSERT without a writer
has configuration guidance, while malformed SELECT has a caret. The idle-interrupt
fixture acknowledges a queued `.show` after the final result, so an earlier input
redraw cannot be mistaken for completed recovery persistence. Deadlines and
recovery assertions are unchanged. These fixtures do not establish arbitrary
SQL, automatic query registration after CREATE TABLE, multi-resource transactions,
or cancellation of an already applied write. Clean-checkout lane execution is
reported separately with the PR's committed revision.

The console recovery reader also requires exact canonical JSON, preventing native
type defaults from filling in omitted nested request definitions or schema
versions. The writer proof removes each field from otherwise canonical saved
bytes and checks rejection before resubmission. The initial clean growth run at
`7d97b4fd` was interrupted after Arrow, page and growing-authority checks passed
to include this additional check; it is not a complete clean-lane result.

The subsequent full `just test::console table` run completed: console batch, PTY,
interruption and TLS checks took **237.72 seconds** inside the **275.64-second**
disk-backed unified proof. The earlier terminal attempt expected a parse caret
for valid INSERT without a writer and failed; the corrected assertion requires
the caret only for malformed SELECT and keeps the no-send/stdout checks.

### Default local Table writes — 2026-09-30

The automatic local console now uses the server's combined Table query/writer
owner for `items`, with an explicitly initialized INSERT/UPDATE/DELETE policy,
allocated route identities and private write recovery. Gateway readiness checks
the exact durable ready configuration plus authorized query metadata. The
superseded local `TableSource` initializer and host role are removed.

This is a hard cutover to shared definition
`ccd596113a3719c6d38afdffe907f04e90f4703472c91aaaffa7875364b5b31e`.
Schemas, ABI/binding resources and independent signing, mutation and catalog
fixtures are regenerated. Missing, foreign and previous query-only installation
definitions reject in both server and automatic console before use, preserving
the original installation record. Existing histories are not converted or reset.

Executed on Linux x86_64 in `nix develop` with pinned Zig
`0.17.0-dev.2267+48abf1a34`, native MinIO and disk-backed Ursula:

- `just transit-board::install` installed the locked dependencies; `just check`
  passed formatting, generated contracts, units, CLI diagnostics, frontend and
  documentation checks, including the site build. The first check stopped on
  Zig formatting; the corrected rerun passed.
- `just test::server` passed the expanded local lifecycle in **41.19 s**.
  The bare console inserts two rows, updates and deletes by key, and verifies
  fresh reads. An explicit connection without a writer rejects mutations.
  The fixture stops the Table owner, admits a console write, kills the console,
  restarts the server and resumes the same saved operation. Rows survive worker,
  node, store and manager replacement. Mutation revocation persists across
  restart while query reads continue. Recovery files retain mode 0600.
  After removing the old initializer, `just test::unit` and `just test::server`
  passed again; the final local lifecycle took **37.94 s** and additionally
  compares the entire saved operation before resuming its original identity.
- `just test::server-faults` passed that lifecycle again in **37.68 s** and its
  bootstrap/gateway/rollback schedules in **20.64 s**, retaining exact initial
  provisioning receipts and refusing changed artifacts or rolled-back storage.
- `just test::table-query-writer` passed in **51.424 s**, with **7,009 reads**,
  **105 turn responses** and both initialization receipts recovered. It checks
  independent query/mutation policies, lost write receipts, cancellation,
  retained query snapshots across writes and current native disclosure gates.
  The run retains four mutations per turn, 256-byte values and eight resident
  authority pages; no installed SDK matrix was selected.

- `just test::server-board` passed default/headless behavior, embedded assets,
  application replacement, inspection revocation, owned process failures and
  both lost-reply/manager-death provisioning schedules. The final lifecycle took
  **34.12 s**. The initial fixture incorrectly requested configuration version 3;
  it now requests the implemented version 1. A later run correctly rejected
  shared build outputs replaced during recovery, so the proof now freezes all
  its binaries. One frozen-artifact run stopped on `AuthorityUnavailable` during
  application status polling; the unchanged rerun passed all scenarios. No
  runtime identity, authorization or availability assertion was relaxed.
  Final evidence: `/tmp/transit-local-writes-board-verified.log`.

Logs: `/tmp/transit-local-writes-check.log`,
`/tmp/transit-local-writes-server.log`, `/tmp/transit-local-writes-faults.log`
and `/tmp/transit-local-writes-combined.log`; final unit/lifecycle evidence is in
`/tmp/transit-local-writes-final.log`. These are working-tree executions, not
clean committed-HEAD or hosted CI evidence. `just ci-clean`, physical ENOSPC and
installed SDK matrices were not run for this cutover.

## Durable Table mutation latency

The [2026-10-04 campaign](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-04/README.md) preserves
all intermediate and corrected-provider reports, fixed diagnostic categories,
executable hashes, temporary probe patches and failed recovery fixtures. The
matched-provider comparison completes 140 cases per implementation: one-row
INSERT/UPDATE/DELETE p50 changes 346/334/329 to 135/152/143 ms, and p95 changes
404/402/546 to 154/179/148 ms. Each case verifies affected rows and an independent
read. Both use the corrected Ursula, fresh ext4 installations, default caches
and workers. Shared-host work remains a confounder; these are not SLOs or p99s.

Corrected-provider default and fixed-20-ms controls each complete 700 cases.
Independent direct-client, 120-row, 120-update-history, cache-64, reader and
idle-gap controls complete 140 cases each. The combined direct-client repeat
completes 700 cases and 5,729 concurrent reads with no uncertainty or restart.
The earlier combined control remains failed because its reader stopped during
an authority-timeout restart, despite verification of all 700 writes. Longer
loaded default/row controls also record supervisor restarts; the longest default
statement is 13.6 seconds. Setup retries, failed controls and bounded telemetry
omissions remain visible in the reports.

The temporary provider probe identifies `ProviderColdBackpressure` after 273
cases. Pinned Ursula's planner left a large second stream unflushed whenever a
small first stream consumed part of the batch budget. The local Nix correction
sizes subsequent chunks against remaining budget. Both final upstream checks
pass: 83 stream units and six integration tests. `just doctor`, full `just check`
and the corrected-provider 1,024-key S3 proof with two cache pages pass. Official
container images are not qualified by the local patched-provider results.

The clean run at `d4c1eb3f` was interrupted after 63 passed tasks when the provider
correction superseded it; the `4ef3f598` run was interrupted after discovering a
public-document ownership error. Neither is complete. At `fe4b5181`, clean CI
passes 43 tasks, including the unchanged-deadline physical query-delivery proof,
then fails the gRPC worker's cold-object count. Diagnostic inspection finds
actual Ursula `_packs` cold data; the fixture counted only `chunks`. The
`1fda5643` counter correction recognizes both pinned paths and tests that startup,
snapshot and empty-directory metadata do not count. Spill requirements, provider
limits and proof deadlines remain unchanged.

On 2026-10-05 UTC, committed-source `just ci-clean` at `3a52d102` completes all
**75 ordinary tasks** in 6,789.17 seconds. The [task results](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-04/clean-3a-complete.json)
and [completion metadata](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-04/clean-3a-complete.meta.json)
retain exact task order, source and exit codes. The physical query-delivery phase
passes in 18.065 seconds under its existing 600-second deadline. Native/port/CLI
Table mutation recovery checks 23 lost receipts; the
[structured records](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-04/clean-3a-runtime-evidence.json)
preserve the phase and binary evidence. The gRPC worker observes 135 cold objects;
the HTTP worker observes 193, with unchanged 8 MiB hot limits. All installed SDK
tasks pass, and the [ten-language ring](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-04/clean-3a-public-interop.json)
checks restarted replies, lost receipts, typed Tables/queries and original IPC.
The [local Station readiness proof](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-04/clean-3a-station-readiness.json)
retains its injected outage, replacement and cleanup results.

A separate clean experience lane at `cd9fde43` completes all seven tasks after
public documentation updates. Changes following the fully qualified runtime
contain documentation/evidence only. Ordinary clean CI does not include the
browser tier or external Compose/Substrate profiles; these results do not qualify
the unpatched official Ursula container. Failed earlier controls remain failed,
and the recorded loaded-run timeout/restart tails remain a performance limit.

Compact-page qualification on 2026-10-04 (the current-definition cutover candidate
following `213acb3b`) passed root units, `just check`, hot packed/closed disk page
proofs, the 1,024-key S3 page proof with two cache slots, resource-simulation smoke,
and real server/service lifecycle proofs. The deepest supported tree test also
passes a complete-candidate mutation at height 32. Malformed/truncated/old page
bytes reject; packed-provider newline framing and the canonical base64 envelope
are checked separately. The S3 write phase stages 758 pages and attempts 3,985,924
page payload bytes, including the envelope; retained-root recovery stages none.
This is format/recovery evidence, not completed transport-pressure qualification.
The shared definition and independently signed/generated consumers cut over
together; old installations reject rather than being reset or decoded as new.

The isolated `just test::page-layout --output /var/tmp/page-layout.json` study
uses the production immutable-tree algorithm in temporary modules. Four codec/
geometry variants and monolithic/separate roots retain the old snapshots and
round-trip every staged page. Its store counts reads, stages and encoded bytes
for 50 synthetic private turn candidates at 64/1024 rows and equal receipt history.
It does not execute native authorization, provider I/O, durability or latency.
The study alone does not qualify an installation format; the current codec and
its native qualification have separate evidence.

The 2026-10-04 run at `fdb449a4` completed all sixteen cases. At 1024 rows,
compact 8-entry leaves/32-child branches used 782 page reads, 468 stages and
613,884 encoded bytes versus 1,790/1,391/1,403,546 for 4/5 JSON pages. Resident
page objects grew from 8,480 to 16,952 bytes. Separate roots in that compact
geometry used 938 reads, 550 stages and 696,327 bytes: partitioning is not selected
as a latency optimization from this workload. Native qualification remains
necessary before accepting any format change.

Tracked by [issue #55](https://github.com/spoke-sh/transit/issues/55). The historical
measurements below retain their original scope and failures. Completed clean
qualification is recorded above; no measurement establishes a latency SLO or
turns an unexecuted gate into a pass.

The initial supplied transcript placed 5.78–6.28 seconds inside `submit` for
single-row mutations. Read-only source and owned ReleaseSafe experiments at
`ac9ad43d` found four writer commands and twelve native durable operations per
small statement, about 300 provider POSTs, and thirteen console checkpoints.
Larger decoded caches removed most provider GETs but not the POST count; fixed
20 ms polling did not reliably improve completion. Compiler/proposal component
benchmarks excluded this work.

An instrumented candidate fixture completed seven cases after catalog batching,
direct admission and captured-read batching: INSERT 1.061 s, UPDATE 0.813 s,
DELETE 0.845 s. Each used one send/view/turn and about 58–59 provider POSTs.
These are single shared-host samples, including proxy overhead, from intermediate
dirty source. The artifact records exact binary hashes. They do not establish
percentile tails or a controlled speedup. Raw local artifact:
`/var/tmp/transit-mutation-triage/candidate-batched.json`.

The same harness with earlier binaries completed four instrumented statements
(5.163, 4.317, 7.104 and 10.172 s) before `AuthorityUnavailable`; its status is
failed with an unknown outcome. Evidence and the original pending request remain
at `/var/tmp/transit-server-proof-jmnsc_bm` and
`/var/tmp/transit-mutation-triage/baseline-matched.json`. This is incomplete
baseline evidence, not a completed comparison. An earlier triage run also saw
`HttpConnectionClosing`; that observation alone does not establish which peer or
idle/deadline boundary closed the connection.

Reproduce in `nix develop`:

```sh
just test::mutation-latency --repeat 20 --output /var/tmp/mutations-console.json
just test::mutation-latency --repeat 20 --instrument --output /var/tmp/mutations-counts.json
just test::mutation-latency --repeat 20 --rows 100 --age 100 --resident-pages 64 --output /var/tmp/mutations-aged.json
just test::mutation-latency --repeat 20 --idle-ms 1500 --worker-interval-ms 20 --output /var/tmp/mutations-poll20.json
just test::mutation-latency --repeat 20 --readers 1 --client .cache/transit-latency/release/bin/transit-mutation-latency-client --output /var/tmp/mutations-client.json
just test::mutation-latency --repeat 3 --schema-profile wide --output /var/tmp/mutations-wide.json
just test::mutation-latency --repeat 3 --schema-profile nested --output /var/tmp/mutations-nested.json
```

The ordinary task freezes ReleaseSafe binaries, creates an owned disk fixture,
validates every affected count and selected row plus final cardinality, and joins
its children. Row/history preparation is excluded from measured cases. A direct
caller failure preserves `client-pending.json` with exact prepared bytes; a
console failure preserves its ordinary recovery file. The runner does not resume
or reset failed work. These are finite closed-loop experiments, not saturation,
open-loop throughput or cold operating-system cache tests.

### Transport and observation follow-up

[Archived diagnostic reports](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-01/README.md)
retain the original JSON, binary hashes, failed samples and controls. The early
adaptive-worker control completes 21 cases; the direct-caller control completes
14 cases with 12 rows, six additional retained updates and one reader. Neither
has enough samples per case to establish p95. Both older fixed-20-ms polling
controls fail with connection closure; faster polling is not a qualified fix.

At `3d0d7819`, after the closing-response fix in
[PR #59](https://github.com/spoke-sh/transit/pull/59), the ordinary fixed-20-ms control
completes 77 cases before an unavailable observation stops the next INSERT
233 ms after starting it. Admission succeeded. The preserved request must be
recovered explicitly; the run is failed and still has fewer than 20 samples per
case. The report does not identify which unavailable condition occurred.

The console now retries unavailable preparation/observation reads inside its
original wait deadline. The fault schedule in
[server_write_observation.py](../../../tests/interfaces/installation/server_write_observation.py), included in
`just test::server`, injects one preflight and three post-admission `HttpCapacity`
responses. The statement succeeds with exactly one submitted command and an
independently verified row. A separate accepted command loses its reply: the
console stops without resending, keeps the unresolved request, and explicit
`.resume` uses identical signed bytes and produces the expected row. The focused
real-console schedule passes with candidate CLI `43f14b71` and frozen node/host
binaries from `3d0d7819`; the pre-change CLI fails the same schedule on its first
unavailable read. This is fault recovery evidence, not a latency comparison.
`zig build test-cli-lifecycle` also passes and now actually includes the console
retry/deadline and gateway diagnostic unit tests.

Earlier full `just check`, native Table mutation recovery and local-server proofs
passed. Clean qualification at `313fe1c3` stopped in the growing-service
query-delivery phase after its existing 180-second deadline; it is not passed.
A focused `just test::query` rerun at `3d0d7819` passes with delivery in 35.52 s.
That rerun does not establish the cause of the earlier timeout. Full clean
qualification of this follow-up remains pending.

### Completed console controls after observation retries

Frozen ReleaseSafe binaries at `3d6ba315` complete two 20-repetition console
controls on owned ext4 fixtures. Each has 140 measured cases, independent row
checks and verified final cardinality. Times exclude preparation of retained
history and the requested idle gaps. The default control has eight resident pages
and adaptive workers; the idle control has 64 pages and a 1.5-second gap before
each measured statement. They vary two controls and are not a cache-only comparison.

| Case              | Default p50 / p95 (ms) | Idle, 64 pages p50 / p95 (ms) |
| ----------------- | ---------------------: | ----------------------------: |
| INSERT one row    |            933 / 1,232 |                 1,679 / 2,533 |
| UPDATE one row    |            926 / 1,398 |                 1,558 / 2,220 |
| UPDATE same value |            919 / 1,837 |                 1,604 / 2,002 |
| UPDATE absent key |            897 / 2,249 |                 1,568 / 4,154 |
| DELETE one row    |            980 / 1,677 |                 1,681 / 2,967 |
| DELETE absent key |            898 / 1,116 |                 1,652 / 2,760 |
| INSERT three rows |            955 / 2,419 |                 1,698 / 2,276 |

These are empirical nearest-rank percentiles from 20 samples per case on a shared
host. They are neither an SLO nor a paired speedup against the earlier failed
baseline. The [raw reports](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-01/README.md) retain
all samples, controls and executable hashes. No p99 is established.

The same build's fixed-20-ms/idle/cache-64 control fails after 34 cases. Its next
three-row INSERT spends 2,003 ms in submission and returns unavailable without a
receipt; the exact pending identity remains at the reported fixture path. No
automatic resend is attempted. The direct caller with 12 rows, six retained
updates and one reader completes 14 measured cases, then stops during cleanup
on an unavailable observation with input 119 already recorded. Its read policy
is single-attempt, and the run remains failed.

The default instrumented control completes 21 cases. Ten `HttpCapacity` refusals
occur across native traffic during those measurements; the counters include
background workers and do not attribute every refusal to the console. Initial
cases retain about 57–60 provider POSTs per statement. Provider work dominates
the reported authority work; their durations overlap and must not be summed as
separate elapsed phases. One idle second records seven native requests, versus
145 in the earlier fixed-20-ms instrumented control. This evidence does not
justify changing adaptive worker defaults to faster fixed polling.

At `3d6ba315`, full `just check` passes, including 422 CLI diagnostic cases, and
`just test::server` passes in 59.56 s with the new fault schedule. Its clean run
was interrupted to retire the merged worktree; it is incomplete, not passed.
The earlier clean run at `3d0d7819` repeats the 180-second query-delivery timeout.

### Physical-storage query follow-up

The combined and focused query schedules each create fresh state and constrain
execution to one CPU. Inspection found a placement difference: the successful
focused `3d0d7819` control used `/tmp` on tmpfs, while clean CI uses ext4 under
`/var/tmp`. An isolated ext4 rerun at the same revision also times out in delivery
after 180 seconds; a subsequent tmpfs control passes delivery in 33.41 s.
Shared-host interference remains uncontrolled, but accumulated fixture history
is not the explanation: the schedules use independent stores.

Station now batches up to eight captured/received fragment reads per native
request. At `38e5a328`, package units verify identical bytes/manifests with fewer
reader calls, missing/corrupt fragment rejection and sticky unavailable/denied
batch failures. The focused ext4 proof passes without changing its deadline:
write 6.93 s, seal 2.77 s, recovery 10.05 s, publication 1.12 s, delivery 56.32 s.
Delivery records 1,849 native queries (146 batched reads) and 467 command
attempts. It verifies 41 rows/21,296 bytes, lost replies, disk-provider restart,
cancellation, complete segment/chain validation and retained acknowledgement.
An ext4 control at merged `3d6ba315`, including the other intervening changes but
without fragment batching, completes delivery in 112.82 s. These are single
shared-host observations, not a percentile comparison or a guaranteed speedup.
The entire difference from the earlier `3d0d7819` timeout cannot be attributed to
fragment batching. [Raw query logs](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-01/README.md#focused-query-storage-controls)
retain the phases and failures. Focused results alone do not establish complete
clean qualification.

Match clean CI's physical placement explicitly, after checking the host's mount:

```sh
mkdir -p /var/tmp/transit-query-proof
nix develop --command env TMPDIR=/var/tmp/transit-query-proof just test::query
```

The query runner reports each completed or failed phase's elapsed time and fixed
native attempt counts, including on timeout. Attempts are transport observations,
not counts of distinct durable effects.

## Direct mutation measurement driver — 2026-10-24

The persistent mutation measurement client now retains its exact direct Table
intent and reference before staging/admission. It drives the direct owner and
reports that owner's committed row counts. Independent SQL-session reads check
the resulting values outside the timed interval.

`just test::mutation-latency --output REPORT --repeat 1 --client CLIENT` passed
all seven mutation cases against native local storage with the ReleaseSafe
client (`transit-direct-mutation-client-smoke-2.json`). The first migrated attempt
failed because its verifier supplied the removed console `execution` setting;
it supplies no complete-run evidence. The corrected smoke run observed no unknown
outcomes. One sample per case verifies the driver and oracle only: it does not
establish percentiles, a comparative speedup, sustained load or instrumented
native completion timelines. The four measurement-helper tests also passed.

## Paired local storage measurement harness — 2026-10-26

The ReleaseSafe native/Table [owner measurement harness](../../../tests/performance/storage/storage_benchmark.md)
passes a **24-sample** smoke matrix: 32 Table rows, two native turns, one warmup
and one recorded repetition per arm under both warm and cold fixture-page
conditions. Independent Python expectations verify every visited value/payload,
the four selected Table rows and exact checkpoint/replay coordinates. The paired
arms preserve current native KV/block/process state and the same retained Table
snapshot. No sample publishes work. The report validator's three tests reject
false completion, wrong values, incomplete phases, writes during reads, incorrect
replay counts and missing repetitions.

The harness records physical startup, logical recovery and read/verification
phases separately, with owner I/O counters, backing allocation peaks, executable
RSS, child resource usage and retained file inventories. Cold runs require
verified file-page eviction. This smoke run establishes the harness and selected
value controls; it has too few samples for latency percentiles, and its fixtures
do not exceed host RAM. The 31-repetition matrix remains a separate executed
measurement, not a conclusion inferred from this smoke run.

The subsequent full matrix completes **768/768** samples with **24** arms,
one discarded warmup and **31** recorded repetitions per arm. The
[archived report and account](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/storage_benchmarks/2026-10-26-owners/README.md)
record the frozen production revision, then-uncommitted harness hashes and
matching committed harness, shared-host contention, cache conditioning and
complete phase/I/O/allocation/RSS evidence. All returned and visited values,
payload digests, non-publication checks, checkpoint coordinates and repetition
sets pass. Independent validation and summary recomputation pass again when
archiving the report. Native trim advances its read floor but retains the
straddling segment; this run does not demonstrate physical reclamation or a
native read improvement. Ingestion/commit percentiles, growth beyond host RAM,
installed latency and clean qualification of later changes remain unproved.

## Disk ingestion measurement harness — 2026-10-26

`just test::storage-ingest-benchmark` completes a **12-sample smoke matrix** with
32 existing Table rows and two existing native turns. Both Table ingestion paths
append the same sixteen new rows. Native samples prepare and commit one further
KV/block/input/output turn. Warm/cold conditions each include one discarded
warmup and one recorded repetition. Every sample reopens and verifies all data;
Table checks also preserve the original retained cut, accepted receipt and
physical point/bulk distinction. This is executable harness validation, not
percentile evidence. The full 31-repetition matrix remains to run.

The extended probe also passes the existing **24-sample read/checkpoint smoke
matrix**. Six report-validator tests reject missing/changed values, incomplete
phase or repetition sets, missing sync/append attribution, invented native append
timers, invalid allocation peaks and verification writes. The
[measurement guide](../../../tests/performance/storage/storage_benchmark.md#ingestion-and-commit-measurement)
defines the distinct Table ingestion/append and native preparation/commit scopes.

The buffered-reader signed projection rerun passes, including encoded filtering,
owned output, prepared comparisons, ordered failures and post-compute/terminal
revocation. The broader repository check and clean core lane at `d80f5c1ed` are
still running; no completed clean-lane result is claimed here.

## Bounded growth harness smoke — 2026-10-26

`storage_growth.py` passes its two-fixture smoke with 32 Table rows and two
native turns, each carrying 16 KiB payloads. Creation and cold fresh-process
readback run under a **128 MiB RLIMIT_AS limit**, verify all values and accepted
positions, and leave file content/allocation unchanged. Table creation records
**76,204 KiB** peak virtual memory, **33,592 KiB** RSS and **67,015,687 bytes** of
tracked live allocation; its readback records **10,992 KiB**, **7,288 KiB** and
**323,252 bytes**, respectively. Native creation/readback peak virtual memory is
**10,496/9,480 KiB**. These smoke fixtures do not exceed the process limit.
The earlier 64 MiB Table creation failed with OutOfMemory; it is not a pass.

Seven report-validator tests pass, including rejection of a wrong payload
configuration, incomplete values/positions, missing memory evidence, peaks over
the ceiling and writes during readback. The normal increasing-size proof still
requires both owners' larger retained fixtures to exceed that ceiling. The
[method](../../../tests/performance/storage/storage_benchmark.md#growth-under-a-process-memory-ceiling) distinguishes
this process limit from host RAM and the Python inventory/oracle's memory.

The workspace `just check` was interrupted while duplicating the clean core
lane's disk-heavy unit suite. Its completed phases include contract fixtures,
92 storage and 15 native collection process-death schedules, relational growth
and retained-metadata checks; the run as a whole remains incomplete. The clean
core run at `d80f5c1ed` continues independently. No lane or milestone completion
is inferred from these partial runs.

## Archived ingestion and growth observations — 2026-10-26

The [ingestion account](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/storage_benchmarks/2026-10-26-ingestion/README.md) preserves
the exact successful 384-sample report and all twelve recomputed summaries.
Every sample's independent value/count/digest, accepted position, retained
snapshot and original receipt checks are revalidated before archiving. Recorded
source hashes match clean revision `e7334f03e6c645f26de8186fc00e4aa8b7994f14`;
later rebases do not change that attribution. The earlier conditioning failure
remains a separate failed run. The [growth account](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/storage_benchmarks/2026-10-26-growth/README.md)
similarly preserves the exact failed attempt from `b85a0a076`: its completed
Table fixtures pass the independent validators and cold-entry checks, while
native setup exceeds the unchanged 1,800-second deadline. There is no complete
growth or beyond-host-RAM result to infer from these artifacts.

## Process-limited growth attempt and native setup timeout — 2026-10-26

The frozen full growth run started at `b85a0a076` finishes **failed** when the
first native fixture (512 rows) exceeds its unchanged 1,800-second setup limit.
`/var/tmp/transit-m2-aligned-growth-full.json` and its sibling `.log` retain the
failure and completed Table samples; the temporary fixtures are removed by the
driver. The probe SHA-256 is
`4d1bddccb9ecf0366dd20d583d1314499e1069abeb44edccbb42cbb1385581a0`.

Both Table cases complete independent value/digest checks, strictly cold reopened
readback and unchanged file manifests under a **134,217,728-byte** address-space
limit. The 2,048-row fixture retains 44,586,146 bytes; the 8,192-row fixture retains
191,717,253 bytes and allocates 501,526,528 filesystem bytes. The latter setup
takes 1,794.4 seconds and readback 17.5 seconds; its probe-image virtual peaks are
76,216 KiB and 10,996 KiB respectively. These are process-image observations,
distinct from `wait4` RSS including inherited pre-exec driver memory. Retained
bytes exceed the process ceiling, not host RAM. Native growth and the complete
growth matrix remain unproved; this run also predates compact evidence staging.
