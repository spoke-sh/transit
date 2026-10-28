# Result codec measurements

Build the real probe with `just test::sql-wire-encoding` in the pinned shell.
The executable is named `transit-sql-wire-encoding` in Zig's artifact cache.
Freeze a baseline from its recorded source revision and a candidate built with
the same toolchain and ReleaseSafe options, then run:

```sh
python3 -B tests/runner/launch.py tests/performance/results/codecs.py \
  --baseline /absolute/path/to/baseline --baseline-revision COMMIT \
  --candidate /absolute/path/to/candidate --cpu 0
```

Choose an available affinity CPU and stop other measurements first. The runner
copies both executables into its private evidence directory, records their hashes,
alternates five paired processes on the same CPU, and preserves failures. Each
process runs its finite warmup and five measured repetitions. Medians are first
calculated within each process, then across the five pairs.

The [budgets](budgets.json) allow at most a 5% median-time regression for each
native one-row/full-batch encode/decode case and the four unchanged PostgreSQL/
MySQL controls. The native candidate must attempt zero backing allocations,
growing resizes or remaps and retain at most 16 MiB per encoder/decoder owner.
Both arms must report identical row counts, batch sizes and framed bytes. The
probe independently verifies native values, borrowed byte ranges and completion.
Malformed, incomplete and mismatched reports fail; negative controls run in the
fast suite. A codec pass makes no end-to-end SQL, TLS or OS-allocation claim.

Raw records stay under `.cache/allocations/runs/`. The source revision argument
identifies the caller's baseline build; the runner does not reconstruct that
build from a binary. Preserve its build record alongside the comparison.
