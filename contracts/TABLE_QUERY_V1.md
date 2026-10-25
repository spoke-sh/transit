# General Table queries v1

`TableSelect` compiles finite SELECT against a supplied Table name, complete
logical row type and 32-byte source binding. It owns the cloned schema, names and
typed literals. Compilation performs no catalog lookup, snapshot acquisition or
authorization. The source owner must establish the binding and validate current
permission before disclosing schemas, rows or data-derived failure evidence.

## Finite language and values

Identifiers and constants use the same typed parser as
[Table DML](TABLE_DML_V1.md). Unquoted identifiers fold ASCII case; quoted names
preserve UTF-8 and doubled quotes. Names admit 1–255 bytes and schemas admit up
to 128 columns within the logical descriptor budgets. SELECT supports all
stored logical families in projections and COUNT(column); it does not coerce
recursive values into the six-scalar query representation.

The compiler accepts `SELECT *`, named projections with optional `AS` output
aliases, an optional source alias, WHERE, and a nonnegative uint64 LIMIT. Qualified
columns resolve only against the selected source alias or original source name.
Repeated input columns require distinct output names. Unknown/duplicate output
names, foreign qualifiers, trailing statements and unsupported constructs reject.

WHERE shares the typed scalar comparison and eager Boolean program used by
UPDATE and DELETE. Decimal, date, timestamp and integer literals bind to the
declared logical type without passing through float64 or narrowing integer
values. Literal NULL comparisons reject in favor of IS NULL/IS NOT NULL. Bound
NULL operands from typed templates retain SQL unknown truth. All state
tests and error/conflict behavior retain the shared logical predicate semantics.

COUNT(*), COUNT(column) and checked int64 SUM(column) use the shared finite
accumulators. Other SUM input types reject explicitly. Aggregates may consume
one projected, filtered, limited input subquery with a required `AS` alias:

```sql
SELECT SUM(p.amount) AS total
FROM (SELECT n AS amount FROM people WHERE n >= 0 LIMIT 20) AS p;
```

An outer aggregate LIMIT, nested derived inputs, row-returning derived queries,
joins, grouped aggregates, expression projections and general functions are
outside this finite compiler. These are explicit limits, not parser-only forms
that claim execution support.

## Execution ownership

`LogicalQuery` owns the plan, fingerprint and pull operators shared with file
queries. A scan returns one owned logical row; the executor retains bounded
aggregate state. A source adapter chooses either complete-source verification
or selected-prefix verification. File scans verify their entire captured input
even after LIMIT; an immutable native source may finish at the selected limit.
Query completion does not claim that an unvisited source tail was verified.

Output remains incomplete after any read, validation, allocation, arithmetic or
operator failure. The first operator failure retains its original row, column,
logical type, cell state, predicate instruction and source/plan fingerprints.
That evidence does not itself authorize disclosure. Neither the compiler nor
the generic executor implements source capture, persistence or query resumption.

## Canonical logical plans

`LogicalPlanCodec` encodes the same logical plan used by Table and file queries
as `FQP1`. An enclosing source contract supplies the complete immutable row
descriptor and source binding. Decoding checks the codec definition, source
binding and descriptor fingerprint before allocating or interpreting dependent
literals, then owns all descriptor children, names, projections and literals.
Releasing the encoded input or original descriptor does not invalidate the plan.

The codec definition is SHA-256 of the UTF-8 bytes
`transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names:nullable-parameters`.
All multibyte integers below are little-endian:

1. `FQP1`, the 32-byte codec definition, 32-byte source binding and 32-byte logical
   descriptor fingerprint.
2. Aggregate tag (rows 0, count 1, sum 2, count-values 3), one-byte projection
   count and that many one-byte input positions.
3. One optional output name per position: one-byte UTF-8 length, then bytes;
   length zero retains the default name.
4. LIMIT presence byte (0 or 1) and uint64 value; an absent value must be zero.
5. One predicate atom or program. Atom tags are all 0, state 1 (column byte and
   state byte), compare 2 (column byte, comparison byte, uint16 payload length
   and a descriptor-bound canonical logical value payload), or bound NULL
   comparison 4 (column byte and comparison byte, no literal payload). Program tag 3 is
   followed by a one-byte instruction count and ordered instructions: atom 0
   followed by its atom; negate 1; conjunction 2; disjunction 3.

The existing logical-plan fingerprint and 8-KiB identity allowance remain the
operator admission boundary. The encoded envelope allows 8 KiB plus 256 bytes
for its explicit definition, binding and per-output framing. Predicates retain
their 64-instruction and 4-KiB variable-width literal bounds. Unknown tags,
noncanonical absent fields, invalid Boolean stacks, trailing bytes, stale bindings
and oversized plans reject. Re-encoding a decoded plan reproduces its input.
These local codec operations do not admit a durable job or acquire a snapshot.

## Bounded resumable steps

`LogicalStream.step` evaluates one page of at most eight logical rows under the
exact bound plan. It uses `LogicalQuery.Counters` for the same eager predicates,
row/value counts and source-order int64 SUM as pull execution. A page carries its
binding, ordinal and source-end flag; a changed binding, repeated/skipped ordinal
or already completed checkpoint rejects. Empty continuation pages are valid.
LIMIT can finish a selected prefix without claiming to verify the source tail.

Each successful step returns provisional progress and an optional complete Arrow
segment in caller-owned buffers. A filtered page can produce no segment. Even an
empty completed result produces schema/completion evidence; aggregates produce
one final row. Nested values retain the logical Arrow layout and five states.
The logical Arrow encoder retains its 4-MiB workspace and 64-KiB segment bounds.
An oversized output fails; no successful partial segment or checkpoint is
returned. Eight input rows bound this operation, independently of durable source
cardinality and any future execution-vector layout.

`FQS1` checkpoints are exactly 126 bytes: magic; 32-byte binding; 32-byte plan
fingerprint; uint64 pages, scanned, selected, value-count, segments and output
rows; sum-presence byte and int64 sum; finish byte (0 pending, 1 source-end,
2 LIMIT). Integers are little-endian. Absent SUM has a zero payload. Decode checks
the original plan and counter relationships, including selected/scanned ordering,
page/segment coverage, aggregate state and exact LIMIT completion.

An enclosing durable record can use `encodeRecord`/`decodeRecord` before its
immutable request has been loaded. These methods check canonical bytes and
plan-independent counter relationships only. Their result must pass
`validate(plan)` against the original bound plan before execution, continuation
or result disclosure; successful structural decoding is not query admission.

Allocation/output failure, invalid rows, operator failure and cancellation return
no candidate. Repeating a step from the same checkpoint and input yields the same
bytes. First-failure evidence retains scan/page position and, where an operator
provides it, column and predicate instruction. The source owner must validate
current disclosure rights, retain its original cut, and atomically commit the
adapter cursor, returned progress and publication evidence. These local steps do
not themselves implement native durable admission, retention or publication.

## Captured direct Table reads

`transit-query.TableSource` declares an exact direct Table interpretation. Its
identity includes realm/resource/catalog, service audience, branch, namespace,
stable object, declaration revision/content commitment, schema fingerprint and
complete logical row descriptor. The query worker's progress resource is separate
from the catalog resource. Neither a current name nor a native KV revision binds
this data source.

Canonical declaration bytes are `TQS1`, the 32-byte current shared definition,
uint64 realm/resource/catalog/audience/branch/namespace/object, uint64 declaration
revision, its 32-byte digest, uint64 declaration byte length, 32-byte schema
fingerprint, uint16 logical descriptor length and the `FTY1` descriptor. Integers
are little-endian. The envelope is 174 bytes plus the existing 16-KiB logical
descriptor budget. Decode owns recursive descriptors and rejects incompatible,
incomplete or noncanonical bytes. `decodeInto` instead borrows the caller's
request arena. The declaration fingerprint hashes
`transit.table.query.declaration.v1`, a zero byte and those canonical bytes.

Explicit capture supplies the original caller's signed grant for one executor,
exact interpretation, pin operation and Table frontier. Admission records durable
acquisition eligibility before any pin operation. Capture reopens that original
pin and verifies the complete declaration and decoded schema, including for
LIMIT 0. The retained basis binds immutable pin content, interpretation, accepted
WAL frontier, logical-change frontier, row count and native authority references.
Its canonical fingerprint and the enclosing query basis follow the
[unified query contract](UNIFIED_QUERY_V1.md#ownership-and-source-identity).

Each adapter page owns at most eight decoded rows, in stable row-identity order.
Its continuation binds the captured source, ordinal, consumed row count and last
identity; a byte-limited page may contain fewer than eight rows. Full traversal
checks exact source coverage. The Fuze plan owns filtering, projection,
aggregation and LIMIT completion. Current direct traversal scans row identities;
this adapter does not expose a composite-key point-seek operation.

Every page checks current CONNECT/USAGE/SELECT under the original grant before
and after reading. ALTER, RENAME, DROP and name reuse cannot replace the retained
interpretation. A new capture against a stale declaration rejects. Native
progress and result publication also carry the original subject's source guard;
a completed direct read alone cannot authorize a later native commit. The page's
`deinit` releases its rows, and `engine` borrows them until release. An error
provides no page. Completed results retain source evidence after pin release and
require separate current disclosure authorization.

The installed finite reader is `DirectTableQuery.openRetained`, described above.
Its retained Table basis is separate from native computation progress. The SQL
session owner acquires and journals its pins explicitly and closes them through
its original identities. The public pull reader borrows its supplied pin; closing
that reader does not release the durable pin.

The [direct request contract](DIRECT_TABLE_V1.md) owns retention and current
policy checks. The [SQL session contract](SQL_SESSION_V1.md) owns statement,
result-reader and session lifecycle. Neither reader silently opens a replacement
cut after a failure or treats incomplete output as complete.
