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

## Signed native Table reads

`transit-query.TableSource` supplies a bounded adapter for public captured and
retained state readers. Its declaration contains the realm/resource/catalog,
owner, stable object, exact immutable metadata reference and complete logical row
descriptor. The metadata commitment binds the original column identities, keys,
defaults and schema revision. It does not bind by the Table's current name.

Canonical declaration bytes are `TQS1`, the 32-byte current shared definition,
uint64 realm/resource/catalog/owner/object, the metadata reference (uint64
revision, uint32 format and length, 32-byte Publication digest), uint16 descriptor
length and `FTY1` descriptor. Integers are little-endian. The envelope allows 126
bytes plus the existing 16-KiB logical descriptor budget. Decode owns all recursive
descriptor bytes and rejects foreign definitions, incomplete or noncanonical
input. `TableSource.decodeInto` composes the same decoder within a caller-owned
request arena, which owns every schema/name and partial-failure allocation.
`LogicalPlanCodec.decodeInto` does the same for the complete schema-bound plan.
Neither returns an independent owner; the enclosing request releases its arena.
The declaration fingerprint is SHA-256 of
`transit.table.query.declaration.v1\0` followed by those canonical bytes.

Capture validates the live object and exact metadata before admitting its source
cut. The captured binding hashes `transit.table.query.capture.v1\0`, the declaration
fingerprint, uint64 captured resource revision and canonical complete Table head.
The host owns native retention and atomic admission. A saved declaration or
computed binding alone does not prove either operation occurred.

Each adapter page owns at most eight decoded rows, in stable row-identity order,
with a binding/ordinal/row-count/identity continuation. Complete composite-key
equality can use the collision-safe typed index. The page still contains complete
source rows for the original Fuze predicate. Full scans check the head's exact row
count; source LIMIT completion belongs to the execution owner. Adapter pages are
independent of execution-vector sizes and durable Table cardinality.

Every page checks current CONNECT, schema USAGE and Table SELECT before and
after reading its original captured schema/root. Continuations may finish after
ALTER or DROP; new capture against a stale declaration rejects. The principal
must match the reader's independently authenticated original subject. A submitted
declaration or committed requester-policy number cannot authenticate that user.
`UnifiedRecords.Policy` constrains requester PID, request resource, scope/owner,
expected original principal, revision and budgets. Durable Table bundles carry
an original proof bound to their canonical bytes and intended reply route;
continuation and recovery preserve that proof. Native readers independently
retain resource access/lifetime checks. The page's `deinit` releases every row;
`engine` borrows those values until release. An error provides no page.

`transit-query.TableQuery` composes this compiler and executor with the general
catalog's signed connection and native leased snapshots. It resolves the supplied
Table name inside one captured resource cut, validates the catalog's exact owner
and configuration, and checks both inspect and read rights. Its binding commits
the current shared definition, realm/resource/catalog/owner, captured resource
revision, stable Table object, metadata commitment and complete Table head.

`next()` returns one independently owned row. `nextBatch(maximum)` returns an
owned batch of at most the requested one to eight rows and 16 MiB of canonical
cells. Release every returned row or batch with `deinit`. The query rechecks
current native authorization and scoped catalog policy after computation and
before returning the entire batch or successful completion. This observation
authorizes that bounded disclosure; a later call performs a fresh observation.
The same gate applies to cached data, empty results, aggregates and LIMIT 0.
Byte-bound lookahead remains private, is included in query-wide accounting, and
requires another current check before disclosure. Failure releases the proposed
batch and poisons the query. Sixty-four cached native
entries belong exclusively to the captured cut; they never establish current
permission. Complete primary-key equality uses the typed key index and still
evaluates the predicate. Other predicates scan stable row identities.

Schema evolution and DROP do not rewrite an already captured reader's identity.
It may finish against its original schema and row root after a name is reused,
subject to current read permission and native resource lifetime. A new name lookup
selects the replacement object. This does not supply general historical AS OF
queries, a cross-resource snapshot or authority to read a retired resource.

Every query supplies positive limits for native snapshot requests, returned rows
and canonical result bytes. The request budget includes acquisition, data reads
and final policy validation; capability negotiation and explicit cleanup are
outside it. Result bytes count the output descriptor and length-prefixed bound
logical cells. Transport/Arrow/JSON framing has its own additional bounds. A query
holds its two bounded schema owners, fixed cache, bounded index traversal and one
decoded row; it does not materialize the Table. Returned row ownership belongs to
the caller, which must release rows instead of retaining an unbounded result.

Final validation releases the native snapshot. Close/deinit, cancellation, expiry
and authority replacement preserve incomplete-output truth; no path silently
opens a replacement cut. A failed handle cannot continue. The native rejection
from a failed fetch is retained before cleanup can issue another native operation.
The public Zig adapter is separate from the configured console, durable query and
foreign-language integrations; their enabled capabilities are owned by those
interfaces.
