# Incremental execution

`transit_fuze.Unified.Stream` evaluates bounded pages from one exact source
without loading its complete data or result into memory. The
[query v1 contract](../../../../contracts/UNIFIED_QUERY_V1.md) owns the plan,
source basis, progress encoding and nested Arrow representation.

Bind `Unified.Plan` with `plan.bind(basis, schema)`, then initialize
`Unified.Stream.Progress.start(bound)`. Each `Stream.step` takes the previous
progress, a `Unified.Page`, caller-owned workspace/output and cancellation.
Success returns candidate progress and an optional segment borrowing the output
buffer. Consume or copy those bytes before reusing it. On failure discard the
partial output and retain the previous committed progress.

Each step revalidates the source schema, projected columns, output-name shape,
literal types and exact bound plan. When there are no output aliases, validated
unique source names and projection indices determine a valid row schema;
aggregate output names and types are fixed. Validation reconstructs the combined
output schema when aliases are present so collisions still reject before output.

Pages have consecutive ordinals and at most eight rows. Source adapters own
ordering and cursor validation; `end` requires their completion evidence. An
empty page alone does not establish completion. The pointer-free `FZS1` progress
record is 167 bytes. It binds source kind, resource/revision, source declaration,
schema and plan fingerprints, counters, aggregate carry and termination. Adapter
cursors are stored beside it, never hidden in a native iterator.

The optional u64 limit applies after filtering across the whole query; null
means no logical row limit. Count includes selected null/missing rows and emits
uint64. Checked int64 sum ignores null/missing values and remains null for an
empty/all-null selection. Type errors or conflicts in compared/summed cells
fail the step. Addition preserves source order across page boundaries; summing
independent page totals could hide an intermediate overflow and is unsupported.

Callers supply up to 4 MiB of Arrow workspace and a separate output buffer.
The general segment ceiling is 64 KiB; a consumer may impose a smaller explicit
budget. Allocation/output exhaustion and counter overflow fail the candidate,
never return a successful prefix. Cancellation is cooperative within the bounded
step and does not cancel previously committed work.

Row output emits independently valid nested Arrow IPC streams as selection
advances. An empty complete result still emits a schema-bearing empty stream.
Count/sum emit one scalar segment on completion. Each segment contains schema,
one record batch and an end marker, with a row count and SHA-256 digest.
Concatenating complete streams does not create one IPC stream.

`Unified.Inspect.decode` checks an expected logical schema and copies decoded
values into a caller-owned allocator. `Inspect.segment` infers the schema from
the current nested layout, validates the complete stream and returns its logical
schema fingerprint. It rejects primitive legacy result layouts.

A pure result is local evidence. The owning integration commits source progress
and captured output together before claiming durability. Station supplies
[Table capture, credit and acknowledgement](../../transit-station/docs/queries.md);
transit-query supplies [interactive and durable query clients](../../transit-query/README.md).
Neither a basis nor an engine checkpoint grants access to source data.

`just test::arrow` checks independent PyArrow decoding, plan fingerprints and
checkpoint bytes. The proof ledger records executed schedules; package tests
cover ordered overflow, empty/all-null results, changed identity, cancellation,
allocation/output faults and deterministic retry.
