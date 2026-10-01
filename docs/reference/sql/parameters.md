# Query parameters

The Zig Fuze compiler accepts typed `$1`, `$2`, … placeholders through its
explicit `Prepared` API. A placeholder can replace a comparison's right operand
or an input LIMIT. Values bind directly into an ordinary plan; they are never
interpreted as SQL text. Templates support one comparison or cell-state test;
Boolean predicate composition remains available through ordinary SQL submission.

These templates are accepted through explicit compiler, SDK or CLI bindings; ordinary
console and SQL-shell text does not supply their parameter values:

```sql
SELECT value FROM items WHERE id > $1 LIMIT $2;
SELECT count(chosen.label) FROM
  (SELECT value AS label FROM items WHERE id > $2 LIMIT $1) AS chosen;
```

The first template requires int64 then uint64 when `id` is int64. The second
requires uint64 then int64. Ordinals must be contiguous from one. A repeated
ordinal requires the same exact type at every use. Comparison parameters support
the six native scalar types; LIMIT accepts uint64. No implicit casts or null
parameter values are provided. Source null/missing/error/conflict behavior stays
the same as for ordinary [comparisons](expressions.md).

The template owns its compiled plan and inferred types. Each binding returns
an independent owner and verifies the source name/schema again. Source resource
identity, current authorization and execution budgets belong to the query
caller. Rebinding does not recover an earlier uncertain submission: retain and
retry that submission's exact saved operation.

The Zig query client adds `prepareSql`/`bindSql` around the compiler. Its
`SqlTemplate` records the complete source definition and rejects a changed
resource, decoder, Table ID or Document revision/path. Both client operations
recheck current permission before returning; binding also rechecks execution
budgets. They return local owned values and do not submit work. See the
[query caller API](../../../packages/zig/transit-query/docs/unified-client.md#typed-query-templates).

The shared native query action `compile` accepts a source scope, SQL and an
optional ordered `parameters` array. `Workspace.compile` accepts the same array
with its configured source. Both return an owned ordinary bundle after checking
current source permission and budgets before and after compilation. Values use
the existing neutral scalar representation: decimal strings for full-width
integers, little-endian hexadecimal float bits, hexadecimal binary and UTF-8
text. The local `sql_capabilities` operation advertises parameter support and
its grammar bounds.
Compilation does not submit the bundle or retain source data. See the
[native caller boundary](../../../packages/zig/transit-station-bindings/docs/unified-query.md#signed-caller-ownership).

All ten [language SDKs](../sdks.md) expose one-shot typed compilation through this
shared operation. Supply the explicit source, its SQL name, SQL text, positive
budgets and optional ordered scalar bindings. The result is an ordinary owned
bundle for the existing admission/recovery workflow. Omitting bindings selects
ordinary SQL; an explicit empty collection selects a template with no
placeholders. Host integers and scalar types map through the existing exact
codecs. At most three values bind the current grammar sites. SDK guides describe
ownership and cancellation for each host language.

The [console](../../../apps/transit-cli/docs/console.md#typed-query-parameters)
accepts `--parameters FILE` with `-c SQL`, or `.execute FILE` with a JSON query
object containing `sql` and optional `parameters`. The
[durable SQL shell](../../../apps/transit-cli/docs/unified-query.md) accepts the
same query file after selecting a fresh namespace. These input files request
new compilations; uncertain work recovers from its original saved bundle and
command without reopening the input file.

Unresolved placeholders in ordinary SQL submission, named `PREPARE`/`EXECUTE`,
parameters for captured file sources and saved templates are unsupported. See the
[compiler API](../../../packages/zig/transit-fuze/docs/unified-sql.md#typed-templates)
and [exact parameter contract](../../../contracts/SQL_PARAMETERS_V1.md).
