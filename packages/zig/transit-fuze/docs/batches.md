# Physical batch execution

`Batch` and `BatchExecution` provide an internal logical compute path for tests and
measurements. Production query callers retain their existing execution selection.
There is no SQL option, native request mode or saved-format change. Linux x86_64 builds include a separate AVX2 comparison object. Binding selects it
only after CPUID and OS XSAVE/XCR0 checks; `Limits.implementation = .portable`
disables it, while forcing unavailable AVX2 rejects before execution. Build with
`-Dcpu=baseline` for a binary whose other code also targets the portable CPU
profile. Parallel scheduling is not implemented by this path.

`Batch.init` validates a logical plan and copies its schema, projection, names,
program and variable literals into one owned buffer. It admits the same logical
plans as the row executor, including eager Boolean programs and ordered checked
int64 SUM. Int64, uint64, finite float64 and Boolean comparisons bind specialized
column kernels. Other admitted scalar comparisons and recursive projections use
generic logical storage; unsupported comparisons still fail plan admission.

Flat columns separate fixed-width values from five-state tags and error/conflict
sidecars. Required recursive values and conflict alternatives are deeply copied.
Columns used only for state predicates or COUNT(column) retain states without
copying unused payloads. Such views support state access, not value disclosure.
Projection and comparison dependencies retain their complete values. Source
validation still checks the complete original row before this specialization.
Constant and validated-page views borrow their source owner; no view outlives it.
`append` validates and copies a complete row atomically. `appendValidated` skips
repeated validation only when the source has validated this exact schema. Failed
appends retain the previous prefix. Original source ordinals, validation boundaries
and optional stable Table identities survive selection without granting access.

Programs evaluate atoms in instruction order over columns. A per-lane error site
retains the first failing instruction even if Boolean composition determines the
truth earlier. Outcomes remain provisional until the ordered consumer applies
LIMIT and aggregates at each original source row. SUM checks every selected
contribution in source order; no partition totals replace intermediate checks.

A batch owns one backing allocation. `Limits.bytes` includes that allocation and
the batch struct: descriptor/plan copies, column metadata, values, state sidecars,
variable payloads, provenance, outcomes, error sites, Boolean scratch and selection positions. `Limits.rows`
sets a compute target, reduced by column width and the byte budget. Supported
experiment bounds are 1–1024 rows and 4 KiB–1 MiB. Defaults are experimental
256 rows/256 KiB. Half the space remaining after plan/column metadata is reserved
for variable payloads. A full payload arena flushes the prefix and retries
one held row; a row that cannot fit an empty batch fails `BatchBudgetExceeded`.
Reserved payload pages are initialized when used; every active lane is written
before its length is published to a kernel. ReleaseSafe checks remain enabled.
No total source-cardinality limit is introduced.

The surrounding executor and decoder have separate memory owners: one source
scan, at most one held decoded row, existing bounded plan-admission scratch,
and independently owned output rows. These are **additional** to the compute
buffer. Hosts must account for those owners under their enclosing query budget;
this experimental byte limit is not a whole-query RSS cap. Returned rows deeply copy
recursive values and conflict alternatives and survive resetting or releasing the batch. Callers must
release each row with `deinit` instead of accumulating an unbounded result.

Source reads are serial. A later read failure is retained until the already
acquired prefix has reached its operator frontier. A failure yields no complete
query and subsequent calls fail. The Table adapter initially acquires one row at a time until its first output.
The file adapter keeps single-row acquisition through the first eight output
rows, matching the existing Arrow batch boundary; later reads can fill the
compute target. This does not promise prompt
output from a stalled source inside a later fill. Native LIMIT caps private
acquisition by the remaining selected-row count. File LIMIT still decodes and
verifies every field and the captured EOF. Stored checkpoints, source page limits,
Arrow segments and publication chunks are unchanged and are not batch sizes.

`FileQuery.executeBatched` checks the same frozen binding as ordinary execution;
buffered disclosures recheck source access and cancellation. General Table
`ExperimentalTableQuery` uses the same signed snapshot, schema, request/result
budgets and disclosure gates as `TableQuery`. Current native/catalog rights are
checked after computation before every row and completion, even when a row came
from a private batch. Its source acquisition remains serial and uses the existing
immutable cache. The selector exists only for proof/measurement callers.

The [measurement guide](../../../../tests/fuze_benchmarks/README.md) owns commands
and metric boundaries. The [proof ledger](../../../../tests/README.md) records
executed evidence. Neither this API nor a fast decoded-column loop establishes
production defaults, whole-query speedup or broader type/hardware support.
