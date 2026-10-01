# Declarative benchmark tooling

The [public benchmark reference](../../docs/reference/benchmarks.md) owns scope,
interpretation and declarative coverage. These are Transit-authored component
fixtures, not full TPC implementations or standard scale factors.

Enter the pinned `nix develop` shell and run from the repository root:

```sh
just test::declarative-benchmark
just test::declarative-benchmark --rows 257 --page-rows 3 --samples 3
just test::declarative-benchmark --rows 0 --samples 1 --iterations 1
just test::declarative-benchmark --require-full
```

The task builds the real Zig consumer in ReleaseSafe. The default report is
`.cache/verification/benchmarks/report.json`; use `--output PATH` to preserve
separate runs. No TPC software download, server or credential is required.
Python orchestrates and verifies; Fuze/Station execute in Zig through public
package imports. SQLite and PyArrow are independent test oracles, not runtime
engines. Temporary oracle databases and Arrow verification files are removed
after the run; reports preserve the actual output/progress and proposal records.

`--samples` is 1–100, `--rows` is 0–1,000,000, `--page-rows` is 1–8,
`--seed` is uint32, `--iterations` is 1–1000, and `--compile-iterations` is
1–1,000,000. Defaults are five samples, 8192 rows, eight rows per page, seed 42,
ten executions and 2000 compilations/proposals. The per-process timeout defaults
to 120 seconds; `--timeout` accepts 1–3600 seconds. Large combinations can exceed
it; a timeout fails the run and does not manufacture a throughput result.

Exit 0 means **all component oracles passed**, with all full workloads still
blocked. `--require-full` writes the same report and exits 2 for that coverage gap.
Exit 1 means a harness, compiler, execution, timeout or correctness failure.
Invalid arguments exit 2 before starting a run. Failure reports have no summary;
any retained earlier raw samples do not establish a successful run. A `running`
report left by a hard kill is incomplete. Never infer success from file existence.

## Workload and measurement boundaries

`manifest.json` owns the 33 executable components, nine rejection probes, pinned
specification references and full-workload inventory. Every workload entry has
its common schema and driver blockers; additional requirements are suite-level
prerequisites, not an exhaustive per-query operator audit. TPC-DS entries count
99 templates, including their constituent statements and permitted variants in
each blocked unit, plus all eleven maintenance functions. TPC-E includes the
setup-only Trade-Cleanup separately from timed transaction mixes.

The inventory is intentionally independent from component completion. Removing
an operation, accepting a blocker probe or changing a component result fails
review checks. Promoting coverage requires real full-workload implementations and
oracles; deleting a blocker label is insufficient.

The selected-count pair uses identical data, predicate and output with and
without an explicit source alias. It records their compilation and execution
costs separately while SQLite/PyArrow verify the same result. This additional
component does not promote any full-workload coverage.

Four output-name components cover named count, named sum over a renamed derived
input, renamed rows and repeated inputs with distinct names. The first three
have existing controls with identical values. SQLite supplies expected names
and values, preserving alias case; the manifest supplies independent result
types by position. A name such as `Total` cannot determine whether its cells are
signed or unsigned. Every run verifies both names and types before reporting
timings. These components do not promote full-workload coverage.

The separate `just test::sql-benchmark` probe keeps its default thirteen-case
compiler/aggregate workload unchanged for frozen-control comparisons. Pass
`--profile count-values` for the new COUNT(column) cost profile: all six native
scalar types, all-value and mixed null/missing/value pages, and both COUNT forms.
It records compilation separately from 8192-row execution with checkpoint
encode/decode on every eight-row page, checks selected and contributing counters,
and decodes the final Arrow count outside the timed interval. Different COUNT
forms intentionally return different results on mixed cells; these are feature
costs, not an equivalent-result speedup. The profile has 24 compile and 24
execution cases, with nine samples selected explicitly for comparisons.

For example, `just test::sql-benchmark --profile count-values --samples 9`
records this pure profile. It does not measure authorization, native source
acquisition, publication or network delivery. The report retains CPU affinity,
driver/source-diff/binary hashes and a 300-second per-probe timeout. Candidate
and control samples must have identical workload metadata; old probes cannot
serve as controls for a profile they do not implement.

`--profile parameters` records literal compilation, template preparation and
repeated typed binding as separate phases across all six native scalar types.
Each bound plan must have the exact canonical bytes of its equivalent literal
query before measurement. Preparation is outside the binding interval, and both
template/bound owners are released. The existing thirteen-case default remains
the unchanged-workload control. This profile measures pure Fuze costs only;
complete source-definition checks, authorization, transport and admission are
outside it. It does not imply that preparing once is beneficial for one query.

Every SELECT uses the production SQL compiler, FZP1 encode/decode and bound
`Unified.Stream`. The source is a synthetic two-column Table basis with eight
or fewer resident rows, not a native Table adapter. Fixture row generation,
stream validation, filtering, aggregation, Arrow encoding and digest computation
are inside execution timing. Compilation/binding, verification file I/O and
SQLite/PyArrow are outside it. Each SELECT has an untimed local execution before
its timed loop. Reports include scanned/selected/output counts and completion.
The point-filter component scans synthetic pages; it does not measure the native
primary-key index. Generation and page work remain bounded as row count grows.

Mutation compilation is timed separately from applying its typed plan to a fresh
private Station turn. Each proposal sees the same descriptor, row 1 = 50 and row
2 = null. INSERT proposes rows 3–5; UPDATE proposes row 1 = 42; DELETE proposes
row 2 removal. Oracles verify affected counts and all four mutation slots using
independent little/big-endian bytes. Nothing commits or persists; iteration does
not accumulate accepted rows. Declaration compilation is followed by an untimed
schema compatibility and canonical SQL check; it does not publish a catalog.

There is one verification process, one unrecorded warm-up process and the requested
sample processes. Summaries give min/median/max nanoseconds per iteration, never
transaction throughput or tail-latency percentiles. Raw timings and exact SQL,
fixture digest, binary hash, manifest/harness/driver hashes, lock hash, source and
dirty state, compiler/build mode, CPU/affinity/load, platform and oracle versions
are retained. Fixture digest input is each `(id, present, quantity-or-zero)` as
little-endian signed int64, one byte, signed int64. No hardware isolation is
assumed and no performance threshold is asserted.

For comparisons, use committed source, separate output paths and frozen binaries;
keep fixture digest, page size, iteration counts, build profile, CPU allocation
and system load comparable. Alternate candidate/control runs externally and
retain both reports. Do not compare a compile number with an execution number or
infer network/durability costs from a private proposal. The ordinary SQL proof
continues to own wider cell-state, error, rollback and independent grammar tests.
