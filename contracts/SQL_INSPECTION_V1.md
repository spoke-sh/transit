# SQL inspection v1

SQL inspection is a read operation over one explicitly configured query source.
The query owner supplies its name, [source definition](UNIFIED_QUERY_V1.md),
and finite query budgets. This scope is not a realm-wide catalog. Current native
source and requester access and current query policy are required, as for
`UnifiedClient.describe`; a declaration alone never grants access.

The shared Fuze parser recognizes `DESCRIBE name`, `SHOW TABLES`, and
`EXPLAIN SELECT ...`. Inspection consumes one complete statement with the same
4096-byte UTF-8, identifier and comment bounds as SELECT. The query compiler's
SELECT entry point rejects all three inspection forms. `EXPLAIN ANALYZE`,
`DESCRIBE SELECT`, catalog filters and multiple statements are excluded.
`SHOW SOURCES`, `SHOW SINKS` and `SHOW CONNECTIONS` name connector catalogs;
their grammar recognition does not turn state adapters into connector entries.

The neutral request contains `scope` (`name`, `source`, `limits`) and `sql`.
The version-one response contains the scope kind `configured_source`, its name,
resource and source kind, full source contract and input schema fingerprints,
the resource and policy revisions of the final authorized metadata read, and
one `details` alternative:

- `description`: the configured source's ordered column names and types. The
  name must resolve exactly, with unquoted names folded by the SQL parser.
- `tables`: zero or one names. It contains the configured name only if the
  source is a typed Table. An empty listing does not assert a realm is empty.
- `explanation`: ordered logical operators (`scan`, optional `filter`, optional
  input `limit`, then `project`, `count` or `sum`), the predicate's column,
  operator and literal type or exact cell state, input projection names, input
  limit, aggregate, output columns and configured execution budgets. The
  ordinary compiler validates names, types and budgets. Literal values and
  original SQL text are excluded. Output columns use the same validated Fuze
  plan method as Arrow execution and result verification.

Explanation describes a proposed finite plan, with no captured data revision,
query identity, execution timing, estimated cost or result. The current metadata
revision is not a promised future SELECT snapshot. Operators retain declared
source order and filter → limit → aggregate semantics; no rewrite is implied.
Full-width limits, budgets and policy revisions use decimal strings in JSON.
Column lists are bounded to eight and operator lists to four.

The owner authorizes before name resolution and again before returning metadata.
Denial or a mismatched definition invalidates the entire response. It checks the
configured budgets against the final current policy for EXPLAIN. Reads do not
allocate a query namespace, acquire a retained source cut, upload a request,
increment a principal sequence, record an intent or dispatch an effect. Changes
to application rows between metadata reads do not themselves invalidate a plan
whose declaration and current access still validate.

The neutral values are owned by `transit-query.SqlInspection`; `Bridge` and
`Workspace` delegate to that owner. Host adapters and SDKs must not translate an
inspection request into query submission. Existing finite bundle, plan, Arrow,
stored progress and frozen-command definitions retain their meanings.
