# Physical batch execution

`Batch` and `BatchExecution` execute typed file and general Table queries through
bounded columns. Resumable logical and Unified queries borrow their validated
pages through the same kernels.
There is no SQL option, native request mode or saved-format change. Linux x86_64 builds include a separate AVX2 comparison object. Explicit `Limits.implementation = .avx2` selects it
only after CPUID and OS XSAVE/XCR0 checks; forcing unavailable AVX2 rejects before
execution. Both `.automatic` and `.portable` use the portable kernels, selected
from the measured comparison. Build with
`-Dcpu=baseline` for a binary whose other code also targets the portable CPU
profile. Hosts can supply a `Runner`; Fuze itself performs no thread or I/O scheduling.

`Batch.init` validates a logical plan and copies its schema, projection, names,
program and variable literals into one owned buffer. It admits the same logical
plans as the row executor, including eager Boolean programs and ordered checked
int64 SUM. Int64, uint64, finite float64 and Boolean comparisons bind specialized
column kernels. Other admitted scalar comparisons and recursive projections use
generic logical storage; unsupported comparisons still fail plan admission.

Flat columns separate fixed-width values from five-state tags and error/conflict
sidecars. Owned appends deeply copy required recursive values and conflict alternatives.
Columns used only for state predicates or COUNT(column) retain states without
copying unused payloads. Such views support state access, not value disclosure.
Projection and comparison dependencies retain their complete values. Source
validation still checks the complete original row before this specialization.
Constant and validated-page views borrow their source owner; no view outlives it.
`append` validates and copies a complete row atomically. `appendValidated` skips
repeated validation only when the source has validated this exact schema. Failed
appends retain the previous prefix. Original source ordinals, validation boundaries
and optional stable Table identities survive selection without granting access.

`appendBorrowedValidated` stores fixed-width lanes and references variable,
recursive and conflict payloads without allocating payload memory. The caller
must validate the exact schema and keep every referenced payload immutable until
reset or destruction, including while a host runner joins its workers. This
method does not transfer ownership or extend a source lifetime. Its views are
logical compute columns, not an Arrow buffer or C data export.

Programs evaluate atoms in instruction order over columns. A per-lane error site
retains the first failing instruction even if Boolean composition determines the
truth earlier. Outcomes remain provisional until the ordered consumer applies
LIMIT and aggregates at each original source row. SUM checks every selected
contribution in source order; no partition totals replace intermediate checks.

A batch owns one backing allocation. `Limits.bytes` includes that allocation and
the batch struct: descriptor/plan copies, column metadata, values, state sidecars,
variable payloads, provenance, outcomes, error sites, Boolean scratch and selection positions. `Limits.rows`
sets a compute target, reduced by column width and the byte budget. Supported
compute bounds are 1–1024 rows and 4 KiB–1 MiB. Defaults are
256 rows/256 KiB. Half the space remaining after plan/column metadata is reserved
for variable payloads. A full payload arena flushes the prefix and retries
one held row. A valid decoded row that cannot fit an empty batch executes
directly under its source owner, with the same ordered operators; it does not
allocate a larger physical buffer or narrow logical admission.
Reserved payload pages are initialized when used; every active lane is written
before its length is published to a kernel. ReleaseSafe checks remain enabled.
No total source-cardinality limit is introduced.

The surrounding executor and decoder have separate memory owners: one source
scan, at most one held decoded row, existing bounded plan-admission scratch,
and independently owned output rows. These are **additional** to the compute
buffer. File pull executors also reserve one 4 KiB decoded-row cache
plus its allocator metadata. The stable cache owner reuses one allocation;
larger or simultaneous allocations use the original allocator. It changes no
decoder limits or validation. Oversized projected outputs copy into independent
arenas so that they, too, can outlive the executor and its cache.
Hosts must account for those owners under their enclosing query budget;
this byte limit is not a whole-query RSS cap. Returned rows deeply copy
recursive values and conflict alternatives and survive resetting or releasing the batch. Callers must
release each row with `deinit` instead of accumulating an unbounded result.

A source can expose `nextBorrowed` and `batchAvailable` to retain one decoded
page while the executor borrows its cells. `batchAvailable` counts the rows
remaining before a call may replace that page. Earlier returned cells must stay
valid across subsequent calls within the page, including failed calls. The
executor stops filling at that boundary, consumes the ordered prefix, then
resets its views before acquiring another page. Startup and LIMIT can choose a
smaller prefix. No pending owned row or decoded-row cache is needed for this
path; the source's full page remains additional to the compute budget. Sources
without this contract retain owned acquisition and oversized-row handling.

Finite direct Table execution uses this borrowed-page path over its existing
at-most-eight-row reader page. Decoding and transport still own their allocations;
this removes the intervening compute payload copy. Final projected results are
independent copies and survive page replacement, query close and destruction.
Early close releases the page with the executor and never releases the durable
Table pin. Current rights still gate each disclosed result batch and completion.

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

A source that filters rows before supplying a batch can expose `batchOrdinal`
for the last acquired row and `batchCoverage` for its verified completed source.
Ordinals are one-based, strictly increasing and independent of returned-row
counts. Completed coverage includes skipped tails and empty filtered results;
selected-prefix LIMIT does not adopt later coverage. Buffered and oversized rows
retain their original ordinals, so ordered aggregate errors name the original
source row. A regressing ordinal or terminal count rejects with `SourceChanged`.
These hooks report source evidence; they cannot create retention or authorization.

Such a source can also expose `batchFailure` when acquisition returns a semantic
predicate error. The executor holds that copied failure behind already acquired
rows, allowing their earlier aggregate failures to win. At disclosure it checks
the error state, source binding, original diagnostic plan and increasing row
position. A selected-prefix LIMIT can finish before that later failure. Physical
read failures retain their existing behavior. These execution hooks do not
establish a filtered service protocol or automatically lower a SQL predicate.

`FileQuery.execute` checks the frozen binding and preserves its borrowed immutable
plan contract; changed names or literals reject before the next disclosure.
`executeWith` additionally accepts physical limits and a host runner. Buffered
outputs check source access and cancellation. `DirectTableQuery.openRetained`
uses an explicitly supplied direct Table pin, compute configuration and bounded
request/result budgets. Current source rights gate each returned batch and
completion. The reader owns decoded rows while borrowing the retained pin;
closing the reader does not release that durable pin.

`transit-query.ComputePool` is a stable, host-owned allocation. `init` takes the
host allocator and `std.Io`, one to four workers (one by default), a resident
reservation (4 MiB by default), and a minimum operator-lane count (8192). Pass
`pool.runner(cancellation)` to the file/Table compute configuration. The host
must stop new calls and join its query callers before `pool.deinit()`.

The pool reserves its own metadata and 1 MiB per additional thread; the pinned
runtime includes its thread-local signal storage in this stack reservation.
Guard pages and thread bootstrap arguments are also charged. Atomic admission
checks the pool reservation plus all concurrently active physical batches against
the configured resident budget, including callers that compute locally. An
exhausted reservation rejects computation before any worker writes. Decoder, transport, output, OS bookkeeping and concurrently
executing queries have separate host budgets. There is one admitted borrowed
batch and no queued batch. Contending or short work computes on its caller;
this avoids a pool queue behind a long query, but does not itself bound host
query concurrency. SUM stays local and always checks each ordered contribution.
Workers receive disjoint decoded lane/scratch ranges, never source clients.
Worker jobs check cancellation between 64-lane chunks. Local fallback checks it
before and after its bounded batch. Return waits for all writes to
join before the private candidate can be released. No worker waits for output
consumption or performs publication.

Relational execution prebinds stable column IDs and comparison kernels for
finite, captured and maintained callers. It uses constant one-lane views at its
existing one-source-read/one-group-update work quantum. Join traversal, group
updates and checked SUM remain ordered; this path does not perform multilane
join lookahead. Restoring a checkpoint rebinds private operators without changing
saved work, cursors, group roots or publication bytes.

The [measurement guide](../../../../tests/fuze_benchmarks/README.md) owns commands
and metric boundaries. The [proof ledger](../../../../docs/history/qualification/README.md) records
executed evidence. A fast decoded-column loop does not establish whole-query speedup or broader
type/hardware support. The measurement records distinguish those costs.
