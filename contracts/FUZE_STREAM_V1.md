# Fuze incremental execution — proposed v1 extension

Status: M10 implementation design, not an advertised capability. The finite
[Fuze v1 profile](FUZE_V1.md) remains supported. This extension must be qualified
with Station's [retained read versions](READ_VERSIONS_V1.md) before it closes the
large-query/result gate.

## Execution boundary

The Zig-native engine accepts one bounded, ordered source batch at a time. It
has no authority, client, durable storage, task scheduler or source credentials.
Station supplies authorized pages from one retained Table version. KV/Document
source adapters remain subsequent roadmap work.

A separate incremental plan retains the existing typed predicates, projections
and aggregate meanings. Its optional 64-bit row limit applies to the entire
filtered selection; null means no logical row limit. A batch working bound must
never act as an implicit whole-query limit. Initial operators are rows, count
and checked int64 sum; joins, grouping, global sorting and external spilling
remain unsupported. SQL is not introduced.

A bound plan identifies the exact resource revision and schema plus its plan
fingerprint. Explicit owned progress records contain that identity, source batch
ordinal, last inspected primary key, selected-row count, aggregate carry and
termination state. They contain no native pointers or suspended stack. Every
batch validates its ordinal, basis, schema and strict ordering across boundaries.
An empty page alone is not end-of-source. Termination records either explicit
source completion or satisfaction of the declared whole-query limit.

Filter precedes the global limit. Count includes selected null rows. Sum ignores
nulls and yields null for an empty/all-null selection. Checked addition preserves
primary-key order across batch boundaries: aggregating each page independently
and adding page totals can hide an intermediate overflow and is insufficient.
Build on the qualified zarrow-compute kernels with the prior carry included in
their ordered input, or a separately qualified equivalent Zig operation.

## Outputs and retry

A step receives immutable progress, one source batch, caller-owned workspace and
output buffers, and cancellation. Success returns candidate progress and an
optional bounded Arrow segment; failure commits nothing and returns no usable
partial output. The caller must discard partially written buffers on failure.
Allocation and output limits apply per step independently of total source/result
size. Native intermediates never survive a call.

Row output produces bounded segments as selection advances. Count/sum produce
one final aggregate segment when complete. Empty row results preserve schema.
The initial segment representation is an independently valid Arrow IPC stream
with schema, one record batch and end marker. An ordered collection of segments
is not one IPC stream obtained by concatenating their bytes. Each segment has a
byte count, row count and digest; the durable result manifest must identify the
representation and ordered completeness evidence explicitly. Future Flight/ADBC
adapters can expose the decoded batches without changing query semantics.

Persisted progress and segment identity must be sufficient to reproduce the same
step after loss. Encoder and plan compatibility are explicit; an incompatible
worker rejects continuation rather than rewriting previously captured fragments.
A digest validates bytes, not the honesty of arbitrary application computation.

## Station integration gates

Station must bind the plan to one retained source and store a durable job identity,
authorized peer/correlation, policy revision, source cursor and engine progress.
Every source-dependent proposal declares its retained read dependencies. A page
or encoded segment can exceed the four-mutation turn budget: stage bounded
fragments with durable staging progress, then seal the segment together with
source/query progress. Partial fragments are not a complete segment or result.
Restart must reconcile exact pending mutations and resume or deterministically
recompute staging, without admitting duplicate output or changing the source.

A complete result records ordered segment/byte/row counts and digest evidence.
Consumers iterate bounded verified segments and distinguish partial capture,
complete capture, delivery and acknowledgement. Policy changes, source expiry,
release, cancellation and unknown submission outcomes need explicit terminal or
recoverable behavior. Acknowledgement never authorizes deletion implicitly.

Qualification must cover limits spanning pages, nulls and signed overflow across
boundaries, source/cursor/plan changes, cancellation and allocation faults, queries
and Arrow results beyond M9's total-size ceilings, interrupted fragment staging,
worker/node/provider restart, policy revocation, missing/duplicate/reordered
fragments, and independent PyArrow decoding. This design alone satisfies none of
those implementation gates.
