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
values. NULL comparisons reject in favor of IS NULL/IS NOT NULL. All state
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

## Signed native Table reads

`transit-query.TableQuery` composes this compiler and executor with the general
catalog's signed connection and native leased snapshots. It resolves the supplied
Table name inside one captured resource cut, validates the catalog's exact owner
and configuration, and checks both inspect and read rights. Its binding commits
the current shared definition, realm/resource/catalog/owner, captured resource
revision, stable Table object, metadata commitment and complete Table head.

Each output row is independently owned and released with `deinit`. The query
rechecks current native authorization and scoped catalog policy after computation,
before returning that row or successful completion. The same gate applies to
cached data, empty results, aggregates and LIMIT 0. Sixty-four cached native
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
