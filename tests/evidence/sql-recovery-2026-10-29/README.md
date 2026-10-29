# SQL recovery comparison — 2026-10-29

This retained comparison supports [the performance qualification](../../../docs/history/qualification/performance.md#event-driven-sql-recovery--2026-10-29)
and [issue #211](https://github.com/spoke-sh/transit/issues/211). Its purpose is to
preserve both the foreground write regressions and the removal of idle polling
as a baseline for subsequent gateway and commit-envelope work. The performance
qualification topic owns this reference; correctness tests and packaging do not
consume these measurements or derive budgets from them.

Control binaries are from `3f14da60e4ec3dd3657a430f79bfc665a3bf7f6c`;
candidate binaries are from `bfe91aa56aaa4acb1960e84eace4958f29a90703`.
All five executables in each arm belong to that revision. Both use the same
current definition, pinned Zig 0.17 and ReleaseSafe. The [manifest](manifest.json)
records the exact definition, host/filesystem conditions, transformations and
hashes of both retained bytes and complete original logs. Each run's metadata
also records executable, driver and helper hashes, source revision, source diff,
load average and overrides.

| Run | Control | Candidate | Workload |
| --- | --- | --- | --- |
| Round 1 | [Raw JSONL](round1-control.jsonl) | [Raw JSONL](round1-candidate.jsonl) | Driver `c394c4f18`; 47 verified statements per arm |
| Round 2 | [Raw JSONL](round2-control.jsonl) | [Raw JSONL](round2-candidate.jsonl) | Driver `113e601a2`; same 47 statements, plus a post-statement idle sample |
| Diagnostic | [Selected JSONL](instrumented-control.jsonl) | [Selected JSONL](instrumented-candidate.jsonl) | Driver `113e601a2`; 15 verified statements per arm with a separate upstream probe |

Each pair runs control then candidate, sequentially on a shared Linux x86_64
host after owned builds and runtime checks finish. No resident-page or
worker-interval overrides are used. The uninstrumented rounds retain every JSON
output line, including human rendering and independent typed readback. The
diagnostic files retain metadata, both idle windows, the INSERT trace/sample and
the statement summary. Selection preserves original line bytes; it does not
reserialize or redact fields. Other diagnostic traces and non-JSON output remain
in the ignored original logs named and hashed in the manifest. No failed run is
included as a successful sample.

Round 2 changes only idle sampling after the original statement workload.
Readiness can precede completion of startup recovery, so the initial `idle`
window cannot establish settled behavior. Instrumented timings include proxy and
owner-metric overhead and must not be mixed into the uninstrumented comparison.
Five mutation samples and six warm reads per round establish neither tails nor
an isolated-host speedup. Single cold/zero-match observations remain in the raw
records. The 10–100× interactive target is not achieved.

To reproduce, build the five executables at each source revision:

```sh
zig build transit transit-node transit-query-host \
  transit-board transit-sql-gateway \
  -Doptimize=ReleaseSafe --prefix .cache/recovery-comparison
```

Freeze each arm's executables together. Run the [installed driver](../../performance/console/console_latency.py)
through `tests/runner/launch.py`, supplying its frozen CLI, node and query-host
paths, `--statements --repeat 5` and the matching `--binary-revision`. The adjacent
Board and SQL gateway are selected automatically. Repeat separately with
`--repeat 1 --instrument` for request attribution. Keep runtime and driver
revisions distinct and verify the actual executable hashes.
