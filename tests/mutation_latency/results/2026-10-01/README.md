# Durable mutation diagnostic evidence, 2026-10-01

This page retains measurement summaries at the stated revisions. References marked
“archived” name raw files removed from the current tree; those bytes are available
only in repository history before the cleanup. These observations do not qualify
current builds.

Raw owned-fixture observations for [issue #55](https://github.com/spoke-sh/transit/issues/55).
The [proof ledger](../../../../docs/history/qualification/performance.md#durable-table-mutation-latency) owns executed
qualification; the [performance reference](../../../../docs/handbook/reference/performance.md#durable-table-mutation-measurements)
owns mechanisms and measurement controls.

These gzip files preserve the original JSON bytes, including errors, failed
samples, executable hashes, fixture paths and controls. Fixture paths describe
local recovery evidence, not a portable running installation. No credentials or
request/row payloads are included. `source_revision` identifies the runner
checkout; binary hashes identify the executables. Earlier binaries and dirty
intermediate candidates are deliberate controls, not builds of that runner HEAD.

| Run | Status | Completed samples | Compressed SHA-256 |
| --- | --- | ---: | --- |
| baseline-matched (archived) | failed | 4 | `b004f974ec70eb7ba73f45fd912e5197651fd88ec90a8248ea9cede06450702a` |
| baseline64-matched (archived) | failed | 4 | `e71c3b4b95db1333894ffd55bfe9ee82658d806b76bec812c3a59d74c4d35381` |
| [candidate-batched](candidate-batched.json.gz) | complete | 7 | `1bdba3e9f93f65cc258789c039b7e84f24a4aea2e27aae445f0a0dce5675d1a7` |
| [candidate-idle](candidate-idle.json.gz) | complete | 21 | `9b94cf2f3ad9db1f5e04e50cc8d3512dbc0ff93af887125ef27c45109fa41489` |
| [candidate-poll20](candidate-poll20.json.gz) | failed | 6 | `8adf23abd3b6fdda667763f2c238541f0c83a0cd422149714953c979099eacdd` |
| [candidate-poll20-instrumented](candidate-poll20-instrumented.json.gz) | failed | 17 | `b49e55cc711f969cd3cad13cb7c9bd5c4324e27699872757e2bcb00a1c0f6e97` |
| [client-history-readers](client-history-readers.json.gz) | complete | 14 | `668d93832c2c1cb77a58a036c4b2ed2c9aa5e7fc0285d0d85bdc50a99f839215` |
| [followup-poll20](followup-poll20.json.gz) | failed | 77 | `edef8c3075dc628087bd9a6222f5bed6ec77a9bd56b9072b76ca5224faeabefb` |
| [qualification-poll20](qualification-poll20.json.gz) | failed | 34 | `68881a28c28d86dbc95fbc39a5652618293c79b9e844c6736075ea3e9fb4d29f` |
| [qualification-adaptive-idle](qualification-adaptive-idle.json.gz) | complete | 140 | `25cf2980d69e9d4dbc37aff188de069f8e9f7c680e05f42372869364b7076543` |
| [qualification-default](qualification-default.json.gz) | complete | 140 | `fa076129c469f6447fd211861b2857f8086b554d8bfdeb2529e492d6cebe7f89` |
| [qualification-counts](qualification-counts.json.gz) | complete | 21 | `38291ad1b8a9e449e952a1f1f56abd0b67df5e58e1688d0632377f60bccb2fd2` |
| [qualification-client](qualification-client.json.gz) | failed | 14 | `8bf9ab7f3967fd8f26cfd52b24b4d5de567dac833f1080c5feffe06caf7292c0` |

## Scope and interpretation

- `baseline-matched` and `baseline64-matched` use pre-optimization binaries based
  on `ac9ad43d`, default/adaptive workers and instrumented provider/native proxies.
  Both stop after four completed cases on an unavailable-authority observation.
  Their completed samples are not a successful baseline workload.
- `candidate-batched` uses an intermediate candidate after direct admission,
  catalog batching and captured-read batching. Seven instrumented cases complete.
  One sample per case cannot establish a latency distribution or controlled speedup.
- `candidate-idle` completes three repetitions of seven cases with 64 resident
  pages, adaptive workers and 1.5-second gaps before measured statements.
- `candidate-poll20` and its `-instrumented` counterpart use fixed 20 ms worker
  polling and the same gaps/cache. Both fail with `HttpConnectionClosing`; retain
  those failures when considering faster polling. They do not qualify the socket
  aging change as a complete fix. The later instrumented runner retains timing
  for its failed statement; earlier reports lack that field.
- `followup-poll20` uses clean source/build `3d0d7819` after #59's closing-response
  fix, with 64 cache pages, fixed 20 ms workers and 1.5-second gaps, without
  proxies. It completes 77 cases, then stops 233 ms into the next INSERT on an
  unavailable observation after a successful send. It does not establish p95 or
  completion of the requested 20 repetitions.
- `client-history-readers` completes two repetitions through the direct public
  Zig caller with 12 retained rows, six additional retained updates, one concurrent
  reader and 64 resident pages. Its checkpoint costs differ from the console.
- The `qualification-*` controls all use frozen `3d6ba315` binaries, after #61's
  bounded console read retries. `qualification-adaptive-idle` completes 20
  repetitions with 64 cache pages and 1.5-second gaps. `qualification-default`
  completes 20 repetitions with the default eight-page cache, adaptive workers
  and no artificial gaps. Each has 20 samples per case and empirical p95;
  neither establishes p99 or a controlled cache-only comparison.
- `qualification-poll20` fails after 34 cases during the next three-row INSERT's
  submission: 2,003 ms in send, no receipt, and the exact prepared identity
  retained. Retrying observations cannot repair an uncertain send automatically.
- `qualification-counts` completes 21 instrumented cases with defaults. Native
  counters include actual `HttpCapacity` refusals while the console completes;
  counters cover background work too, and proxies add overhead.
- `qualification-client` uses the same row/history/reader controls as the earlier
  direct-caller run. It completes 14 measured cases, then fails on a cleanup
  observation after receipt, retaining input 119 and its pending identity. Its
  single-attempt read policy differs from the console. No completed distribution
  is claimed for this failed workload.

All runs share a busy development host. Instrumented proxies create fresh
upstream connections and add work; compare counts and ordinary latency controls
separately. The artifact records a one-second idle counter interval where
instrumentation is enabled. Wait/work/provider durations can overlap and cannot
be summed as disjoint elapsed phases. Native metrics absent from older binaries
are missing measurements, not zeros. No run establishes an SLO, TPC result,
saturation throughput, cold host cache or p95/p99 from fewer than 20/100 samples
per case.

Reproduce through `just test::mutation-latency` in the pinned Nix environment;
see the proof ledger for exact commands. Failures preserve the original prepared
identity and owned fixture. Do not repeat SQL as a new operation to recover an
uncertain accepted write.

## Focused query storage controls

These raw logs preserve the pinned `just test::query` proof, including failures.
The runner at `38e5a328` additionally emits fixed native attempt counts for each
phase. All runs use one CPU, six segments, 41 rows/21,296 bytes and the same
180-second phase deadline. Explicit temporary-directory placement selects the
host's ext4 mount; ordinary development-shell placement was verified as tmpfs.

| Run | Source | Filesystem | Delivery | Compressed SHA-256 |
| --- | --- | --- | --- | --- |
| query-ext4-3d0 (archived) | `3d0d7819` | ext4 | timeout at 180 s | `b6908abb376a420998f17e9c0e65040373005531b3d08a9a27d8b562028ff4af` |
| [query-tmpfs-3d0](query-tmpfs-3d0.log.gz) | `3d0d7819` | tmpfs | 33.41 s | `204477b5976cf47d0d166e4c55fb43d992620ac26d9355e469fdba2799b8cbbb` |
| [query-ext4-3d6](query-ext4-3d6.log.gz) | `3d6ba315` | ext4 | 112.82 s | `f4e4ee5fc3d3e92b93848da61a05adb106881d573be2be9054ba32a19e0686cd` |
| query-ext4-batched (archived) | `38e5a328` | ext4 | 56.32 s | `b806de56fda982d3a705774edf36157c0ff469ece28f65e25eda6e4ab4dab807` |

The `3d6ba315` control includes the other changes merged before fragment batching.
Its 112.82-second ext4 delivery and the batched 56.32-second delivery are single
shared-host observations, not percentiles or a controlled speedup guarantee. The
older `3d0d7819` ext4 timeout cannot be attributed solely to fragment batching's
absence. Fixture paths describe local observations; successful fixtures are
cleaned up and failed query fixtures emit diagnostics before cleanup.
