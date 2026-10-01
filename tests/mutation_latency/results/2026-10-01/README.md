# Durable mutation diagnostic evidence, 2026-10-01

Raw owned-fixture observations for [issue #55](https://github.com/rupurt/rey/issues/55).
The [proof ledger](../../../README.md#durable-table-mutation-latency) owns executed
qualification; the [performance reference](../../../../docs/reference/performance.md#durable-table-mutation-measurements)
owns mechanisms and measurement controls.

These gzip files preserve the original JSON bytes, including errors, failed
samples, executable hashes, fixture paths and controls. Fixture paths describe
local recovery evidence, not a portable running installation. No credentials or
request/row payloads are included. `source_revision` identifies the runner
checkout; binary hashes identify the executables. Earlier binaries and dirty
intermediate candidates are deliberate controls, not builds of that runner HEAD.

| Run | Status | Completed samples | Compressed SHA-256 |
| --- | --- | ---: | --- |
| [baseline-matched](baseline-matched.json.gz) | failed | 4 | `b004f974ec70eb7ba73f45fd912e5197651fd88ec90a8248ea9cede06450702a` |
| [baseline64-matched](baseline64-matched.json.gz) | failed | 4 | `e71c3b4b95db1333894ffd55bfe9ee82658d806b76bec812c3a59d74c4d35381` |
| [candidate-batched](candidate-batched.json.gz) | complete | 7 | `1bdba3e9f93f65cc258789c039b7e84f24a4aea2e27aae445f0a0dce5675d1a7` |
| [candidate-idle](candidate-idle.json.gz) | complete | 21 | `9b94cf2f3ad9db1f5e04e50cc8d3512dbc0ff93af887125ef27c45109fa41489` |
| [candidate-poll20](candidate-poll20.json.gz) | failed | 6 | `8adf23abd3b6fdda667763f2c238541f0c83a0cd422149714953c979099eacdd` |
| [candidate-poll20-instrumented](candidate-poll20-instrumented.json.gz) | failed | 17 | `b49e55cc711f969cd3cad13cb7c9bd5c4324e27699872757e2bcb00a1c0f6e97` |
| [client-history-readers](client-history-readers.json.gz) | complete | 14 | `668d93832c2c1cb77a58a036c4b2ed2c9aa5e7fc0285d0d85bdc50a99f839215` |
| [followup-poll20](followup-poll20.json.gz) | failed | 77 | `edef8c3075dc628087bd9a6222f5bed6ec77a9bd56b9072b76ca5224faeabefb` |

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
