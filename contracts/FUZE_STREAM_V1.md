# Fuze incremental execution — v1 development extension

Status: the pure Zig execution/owned-progress boundary is implemented by
`transit_fuze.Stream`. Station integration below remains a required M10 gate;
this is not yet an advertised end-to-end query capability. The finite
[Fuze v1 profile](FUZE_V1.md) remains supported.

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
remain unsupported. M12's [SQL frontend](../packages/zig/transit-fuze/docs/sql.md)
now compiles the declared Table SELECT subset to this same plan; it changes
no engine or authorization semantics.

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

## Progress encoding and compatibility

`Stream.Plan.bind(basis, schema)` returns a bound plan. `bound.start()` returns
initial progress. `Stream.step` accepts an explicit `Page {ordinal, source, end}`
and returns `Step {progress, segment}`. Source batches admit at most 32 rows;
neither total scanned rows nor output segment count is limited to 32. Counters
are checked u64; a count aggregate must also fit its Arrow int64 result. Cell,
schema and per-step workspace bounds remain those of Fuze v1. The caller sizes
the output buffer and receives an error if a segment does not fit.

The plan fingerprint is SHA-256 over `transit.fuze.stream.plan.v1` followed by
a zero byte and compact JSON of the typed `Stream.Plan`, in declaration order:
`version`, `predicate`, `projection`, `limit`, `aggregate`. It includes exact
typed predicate encodings, including fixed byte arrays; it is not a hash of
arbitrary submitted JSON text or an optimizer equivalence claim. Basis/schema
are checked separately. A changed plan, schema or revision rejects continuation.

The owned binary progress format is exactly 143 bytes. Integers are little
endian; absent optional numeric fields have zero bytes. Decoding rejects other
lengths, magic, tags and noncanonical absent values; `validate(bound)` additionally
checks identity and counter/state consistency before execution. Neither check
proves that an untrusted application computed the recorded counters honestly.

| Offset | Encoding |
| --- | --- |
| 0 | Four-byte `FZS1` magic (version 1) |
| 4, 12 | u64 resource and revision |
| 20, 52 | 32-byte schema and plan fingerprints |
| 84, 92, 100, 108, 116 | u64 pages, scanned, selected, segments, output rows |
| 124, 125 | last-key presence (0/1), i64 primary key |
| 133, 134 | sum presence (0/1), i64 carry |
| 142 | termination: 0 pending, 1 source end, 2 limit |

The format contains no source read capability, Table cursor or result manifest.
Station must durably associate those with the same query identity. A resumed
worker must support this plan, progress and IPC segment representation explicitly.

`Stream.PlanCodec` separately owns a compact `FZP1` plan encoding (at most 241
bytes). After the four-byte magic are: aggregate u8 (rows=0, count=1, sum=2),
two projection bytes (0/1, 255 absent), limit presence 0/1, and little-endian u64
limit (zero when absent). The predicate follows: tag 0 means all; tag 1 adds a
column byte for `is_null`; tag 2 adds column, comparison (eq/ne/lt/le/gt/ge =
0–5) and literal tag. Literals use null=0, int64=1 plus eight little-endian bytes,
boolean=2 plus 0/1, utf8=3 or binary=4 plus u8 length and that many bytes.
Decoding rejects trailing bytes and noncanonical encodings. Schema-dependent
validation still belongs to binding. Typed byte-literal padding must be canonical
zero, so durable encode/decode cannot silently change a plan fingerprint.

## Station integration gates

The [Station query v2 design](STATION_QUERY_V2.md) specifies the durable job,
staging and delivery boundaries; its status is separate from this pure engine.

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

Pure execution tests and independent PyArrow checks cover limits spanning pages,
nulls and signed overflow across boundaries, source/ordinal/plan changes,
cancellation/allocation faults, owned progress encoding, and results beyond
the legacy whole-query ceilings (70 rows and a 16,008-byte text result in seven
independently decoded segments). This is bounded caller-side evidence, not
durable publication or restart qualification.

Remaining integration qualification must cover source/cursor/plan changes,
cancellation and allocation faults, queries and Arrow results beyond M9's
total-size ceilings, interrupted fragment staging,
worker/node/provider restart, policy revocation, missing/duplicate/reordered
fragments, and independent PyArrow decoding of durably captured bytes. The pure
engine checks alone do not satisfy those integration gates.
