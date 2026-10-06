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
