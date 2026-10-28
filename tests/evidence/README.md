# Results and reproducibility

Test runners produce their own results. Ordinary logs, timings, machine-readable
outcomes and failure artifacts belong in ignored `.cache/` output and CI artifacts.
They must not require a handwritten pass record or a commit of each run's output.

Start with the [runner](../runner/README.md) for execution and the
[qualification topics](../../docs/history/qualification/README.md) for scientific
interpretation and limits. Active budgets and independent expected values belong
with their performance or correctness checks, not with run output.

The [development workflow calibration](development-workflow-2026-10-27/README.md)
retains selected automatic measurements for CI cost thresholds and package-build
concurrency beyond ordinary artifact retention, including the failed cold attempt.

The [SQL result comparison](sql-results-2026-10-27/README.md) retains matched
pre/post-result-model measurements, independent value commitments, instrumented
request counts and isolated codec allocations for the batching qualification.

The [result reserve comparison](result-reserves-2026-10-28/README.md) retains the
paired allocation and timing samples behind the fixed codec regression budgets.

The [SQL database runtime comparison](sql-database-runtime-2026-10-28/README.md)
retains matched client-completion samples and source/definition provenance for
the removal of SQL account actors, including the observed point-read regression.

The earlier generated-output archive remains available at its
[original source revision](https://github.com/spoke-sh/transit/tree/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results).
The [file disposition map](../../docs/roadmap/development-workflow-migration.json)
records exact paths, immutable links and original hashes for all archived records,
including failures and incomplete runs. Verify those bytes with
`python3 -B tests/runner/layout.py --archive-integrity` from a checkout containing
the original revision. Historical links establish their original scope only.

Keep a record here only when a documented reproducibility need requires a durable,
reviewed reference beyond ordinary CI retention. State that purpose, source,
conditions and retention owner. Do not duplicate routine CI output. Follow the
[contribution rules](AGENTS.md).
