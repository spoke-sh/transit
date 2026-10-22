# 8. Qualification and complete benchmarks

[Roadmap](README.md)

Turn component coverage into complete workload and release evidence. The
[verification reference](../handbook/reference/verification.md),
[benchmark inventory](../handbook/reference/benchmarks.md) and
[test ledger](../../tests/README.md) own current results. Focused qualification
remains a gate for every preceding milestone.

## Remaining work

- Execute required suites at a common committed revision: installed SDKs, protocol
  peers, browsers and selected physical placements. Distinguish failures and
  unexecuted checks from passing evidence.
- Extend deterministic schedules and external faults at new storage, historical,
  branching and distributed boundaries. Save reproducible counterexamples and
  check forbidden outcomes as well as eventual success.
- Build full benchmark drivers after prerequisites exist: generators/scales,
  variants, schemas, result/transaction oracles, load/refresh/concurrency schedules
  and disk recovery.
- Cover inventoried TPC-C, TPC-E, TPC-H and TPC-DS operations without presenting
  component measurements as compliant full-suite scores. Keep standard versions
  and workload semantics explicit.
- Measure hosted setup/build/fixture/scenario/cleanup costs before changing CI
  lanes. Reuse artifacts without sharing authority or dropping coverage; local
  timings do not establish hosted budgets.

## Completion evidence

Record source/toolchain/binary provenance, workload configuration, ordinary versus
instrumented measurements, samples and host-variance limits. Require full oracles,
negative controls, nonzero coverage gates, bounded resources and explicit failures.
Publish reproducible commands and limits with claims instead of delivery history.
