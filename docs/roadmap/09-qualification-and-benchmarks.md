# 9. Qualification and complete benchmarks

[Roadmap](README.md) · **Status:** Planned

Turn component coverage into complete workload and release evidence. The
[verification reference](../handbook/reference/verification.md),
[benchmark inventory](../handbook/reference/benchmarks.md) and
[test ledger](../../tests/README.md) own current results. Focused qualification
remains a gate for every preceding milestone.

## Remaining work

- Qualify full declaration lifecycles: define data and computation, apply policy,
  inspect publication/results/progress, evolve dependencies and recover accepted
  work after faults. Use independent data/result oracles at exact source bases;
  process health and parser coverage cannot substitute for fulfilled intent.
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

## Documentation publication

The handbook is deployed through GitHub Pages; the
[publication evidence](../../tests/README.md#published-handbook-observations-2026-10-21)
records successful deployments and direct public-content checks. Remaining work
is qualification of that existing service, not implementing publication again:

1. Verify live direct navigation/refresh, canonical URLs, assets, sitemap, search,
   exact schema downloads and a nonexistent route's HTTP 404 across public guides,
   SDKs, Internals and generated references.
2. Exercise desktop/mobile navigation, diagrams and keyboard access on the live
   site. Confirm individual roadmap/design/history records remain outside search.
   Keep these results separate from local production-browser checks.
3. Use a controlled content change and reviewed revert through `main` to exercise
   recovery. Verify the recovered revision publicly and test that a superseded
   workflow rerun cannot replace newer content. Record cache observations without
   inferring a general GitHub CDN guarantee.

These checks do not claim runtime qualification. Release-versioned documentation
and immutable release links remain part of [release distribution](10-releases.md).
