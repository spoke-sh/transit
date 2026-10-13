# Experimental physical batches

`Batch` and `BatchExecution` provide an internal int64 compute path for tests and
measurements. Production query callers retain their existing execution selection.
There is no SQL option, native request mode or saved-format change. SIMD and
parallel scheduling are not implemented by this path.

`Batch.init` validates a logical plan and copies its schema, projection, names and
literals into one owned buffer. It admits all-int64 schemas, projection,
COUNT(*), COUNT(column), LIMIT, state tests and one comparison atom (including
the compiler's single-instruction program). Other types, compound programs and
SUM return `UnsupportedBatchPlan`; callers use their existing general executor.
This experimental restriction does not narrow the production query interface.

Flat columns store int64 values separately from five-state tags and error/conflict
sidecars. Conflict alternatives are copied without choosing a winner. Constant
views borrow a validated cell and its alternatives. Borrowed views require equal
flat-slice lengths, valid indices and valid int64 cells; they expire when their
owner resets or deinitializes. `append` validates and copies a complete row
atomically. `appendValidated` skips repeated semantic validation only when the
source decoder has already validated the complete row against this exact schema.
Source ordinals, original validation boundaries and optional stable
Table row identities survive selection. They are evidence coordinates, not access
grants. `evaluate` produces one truth/error outcome per original row; the ordered
consumer applies LIMIT, counts and projections before accepting later failures.

A batch owns one backing allocation. `Limits.bytes` includes that allocation and
the batch struct: descriptor/plan copies, column metadata, values, state sidecars,
conflict storage, provenance, outcomes and selection positions. `Limits.rows`
sets a compute target, reduced by column width and the byte budget. Supported
experiment bounds are 1–1024 rows and 4 KiB–1 MiB. Defaults are experimental
256 rows/256 KiB. Half the space remaining after plan/column metadata is reserved
for variable conflict payloads. A full payload arena flushes the prefix and retries
one held row; a row that cannot fit an empty batch fails `BatchBudgetExceeded`.
No total source-cardinality limit is introduced.

The surrounding executor and decoder have separate memory owners: one source
scan, at most one held decoded row, existing bounded plan-admission scratch,
and independently owned output rows. These are **additional** to the compute
buffer. Hosts must account for those owners under their enclosing query budget;
this experimental byte limit is not a whole-query RSS cap. Returned rows copy
conflict alternatives and survive resetting or releasing the batch. Callers must
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
