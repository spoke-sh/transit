# Incremental execution

`transit_fuze.Stream` executes ordered source pages without loading the whole
source or result into memory. It is a caller library with no client, storage or
authority dependency. The [development contract](../../../../contracts/FUZE_STREAM_V1.md)
owns exact semantics and the versioned progress encoding.

Bind `Stream.Plan` to a resource/revision/schema with `plan.bind(basis, schema)`.
Use `bound.start()` once, then pass each `Stream.Page` to `Stream.step`, with
caller-owned workspace, output buffer and cancellation flag. A successful step
returns candidate progress and optionally one segment whose bytes borrow the
output buffer. Copy or consume those bytes before reusing it. A failed step
returns no result; discard any partially written buffer and retain prior progress.

Pages have consecutive ordinals and strictly increasing primary keys across
boundaries. Set `end` only from the source adapter's completion evidence; an empty
page does not establish completion. `Progress.encode/decode` makes an owned,
pointer-free 143-byte checkpoint; validate it against the same bound plan before
resuming. Cancellation is cooperative within a bounded synchronous step, not an
external task cancellation or durable result rollback.

The nullable u64 `limit` applies after filtering across the **whole query**. Null
means no logical row limit. Each source batch still has a 32-row safety bound,
and each value/schema keeps the existing qualified encodings. Per-step workspace
is caller-supplied (the usual budget is 1 MiB); output capacity is a separate
caller-owned bound. Exhaustion returns an error, never a shortened successful
result. Counter overflow also fails the candidate step.

Rows produce an independently valid Arrow IPC stream per nonempty selection.
An empty final result still produces one schema-bearing empty segment. Count
and sum carry across pages and produce a single scalar segment at termination.
Sum feeds its previous carry into the pinned zarrow-compute kernel before the
current selected values, preserving checked overflow in source order. It does
not sum independent page totals. Count includes selected null rows; sum skips
nulls and remains null when none of the selected values is nonnull.

Read each output segment independently, or decode/re-encode its batches through
an Arrow adapter. Concatenating complete IPC stream bytes does not produce one
IPC stream. Each returned segment has a row count and SHA-256 digest; this is
local evidence only. The caller must commit source progress and captured output
together before describing it as durable or complete. The Station integration
is still being implemented; `Stream` alone does not authorize sources, retain
versions, stage fragments, deliver results or acknowledge a consumer.

`just test::arrow` independently checks all admitted types and multi-page results
with PyArrow, plus plan fingerprints and progress bytes with Python. The text
case decodes 70 rows/16,008 bytes in seven segments. Package unit tests check
global limits, nulls, ordered overflow, exact identity, cancellation, too-small
workspace/output and retry determinism. These finite checks establish no
throughput, parallel execution, join/spill or durable recovery capability.
