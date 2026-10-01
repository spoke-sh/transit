# Typed SQL parameter compilation v1

This contract defines caller-owned finite query templates in Zig Fuze. The
separate `Sql.parseTemplate` entry point accepts `$n` in the right operand of
the existing comparison predicate and in a `LIMIT` position. The ordinary
statement parser and public SQL submission routes reject unresolved parameters.
Named `PREPARE`, `EXECUTE`, prepared-state persistence and file-query parameters
are not implemented. The shared query boundary exposes the one-shot compilation
operation below; language convenience APIs and CLI argument handling have their
own integration scope.

## Syntax and typing

The [reference grammar](sql/TransitExtensions.g4) exposes `parameterTemplate`
separately from `statement`. All existing finite SELECT name, text, comment,
projection, qualifier and aggregate restrictions still apply. A parameter is not
an identifier, expression, cast, sign-prefixed literal or string interpolation.
Quoted strings and comments retain literal `$` bytes.

Ordinals are positive decimal u32 values, one-based and contiguous through the
greatest used index. Leading zeros identify the same ordinal (`$01` is `$1`).
Zero, missing digits and overflow reject. A sparse ordinal rejects during
preparation. The parameter-count bound derives from the comparison and two
LIMIT grammar sites; it does not bound retained application collection size.
The ordinary aggregate restriction still rejects an outer LIMIT, including a
parameterized outer LIMIT.

Comparison parameters have exactly the resolved input column's type: int64,
uint64, finite float64, boolean, UTF-8 or binary. LIMIT parameters are uint64.
Repeated uses of an ordinal must require the same type. Output aliases do not
enter predicate scope. Binding neither coerces types nor introduces null,
missing, conflict or type-error parameter values. Those source cell states keep
the existing comparison and aggregation semantics.

Bindings provide exactly one scalar per ordinal, in ordinal order. Scalars use
`Unified.Scalar` and its existing value, UTF-8 and 4096-byte limits. The shared
neutral scalar representation is `transit-query.Values.Scalar`, as specified by
the [query contract](UNIFIED_QUERY_V1.md); no second numeric or binary codec is
introduced.

## Neutral compilation operation

`Bridge.compile` accepts `{scope, sql, parameters?}`. `scope` contains the explicit
SQL `name`, neutral `source` definition and positive `limits`, using the same
representations as inspection. `parameters` is either omitted/null for ordinary
SQL or an ordered array of neutral scalars for the template grammar. An empty
array accepts only a template with no placeholders. Every ordinal must have one
value of its exact inferred type. The grammar-derived parameter-count bound,
4096-byte SQL limit and existing request/scalar/bundle limits apply before any
execution. SQL text is never constructed from parameter values.

`Workspace.compile` accepts the same optional `parameters` with its configured
scope. Both paths call `SqlCompilation`; they check current source permission
and permitted budgets before compiling and again after binding. A failure at
either check returns no result. These are read-only operations: no data snapshot,
query namespace, upload, admission, sequence allocation or dispatch is created.
The read-only local `sql_capabilities` action returns `version: 1`,
`parameters: true`, the grammar-derived `max_parameters` and `statement_bytes`.
It is additive: existing capability responses retain their exact fields. Source
admission still checks the running authority independently.

The `compiled` result contains canonical `bundle` hex plus the neutral `source`,
`plan` and `limits`, and exact source `contract` and `schema` fingerprints. Every
returned slice belongs to the supplied result allocator independently of the
request and temporary template. Native ABI and local-port result buffers own the
serialized response. A result is an ordinary finite bundle: callers use the
existing `next`/`submit` operations and retain their exact saved bundle and frozen
signed commands across uncertain outcomes. Compilation is not recovery, and a
new binding must never replace an uncertain original operation.

The [neutral compilation fixtures](../packages/zig/transit-query/src/fixtures/sql-compilation-v1.json)
define requests and expected typed plans for shared callers. The parameter
compiler corpus separately checks canonical bytes against an independent encoder.

## Ownership and admission

`Prepared.init(allocator, text, source)` resolves and validates the template,
owns its prototype plan, and records the SQL source name and schema fingerprint.
`parameterTypes()` borrows the ordered types until `deinit`. The template and
its fields are immutable after construction. Applications own template lifetime;
Fuze retains no global prepared-query registry or background task.

`bind(allocator, current_source, values)` verifies the source name and schema,
checks every value and count, and returns a separately owned ordinary plan.
Projection and literal bytes are independent of the template and input values.
The bound owner remains valid after either input is released; release it with
its own `deinit`. Allocation failures return no owner and leak no allocations.
An unresolved template AST is rejected by ordinary lowering and compilation.

The schema/name commitment is not a resource identity or permission. The query
owner must separately retain and check the exact source definition, current
grants, execution budgets and captured source basis. Preparation or binding
does not read source data, retain a snapshot, admit a query or sign a command.
An accepted query's exact saved bundle and signed commands remain its recovery
material; rebinding a template is a new query, never uncertain-operation retry.

`transit-query.SqlTemplate` supplies the resource binding above Fuze. Its pure
`init` records the entire canonical `SourceDefinition` fingerprint, including
resource, KV prefix/decoders, Table ID/schema, and Document identity, accepted
revision and projection paths. An equal schema on another definition is
insufficient. `bind` checks this fingerprint and returns an owned ordinary
`Bundle`, including independent copies of source paths and values. Explicit
positive execution budgets retain their existing definition.

`UnifiedClient.prepareSql` checks current source access before and after
compilation. `bindSql` checks current access and permitted budgets before and
after binding. Failure at either check releases candidate allocations and returns
no bundle. These methods use the shared read-only description operation; they
do not submit work. The source still independently checks current admission when
a bound bundle is uploaded. Neither a previously prepared template nor a bound
bundle preserves permission after revocation.

## Compatibility and evidence

Binding lowers placeholders to ordinary scalar/limit values. Canonical FZP1
bytes are identical to a manually constructed plan with the same values and
output names. The neutral compile action, response and capability are additive;
generated ABI/port/workspace schemas follow their shared Zig owners. Existing
requests retain their meanings. No unbound template codec, saved-template format,
signed native operation or C ABI function layout is added. Existing source,
plan and native definition identifiers retain their current meaning and checks.
Matching build requirements remain; an implementation without the new action
rejects it before any dispatch.

The [shared corpus](sql/corpus/parameters.json) uses an independent ANTLR tree,
PostgreSQL parser comparison for the declared subset, direct reference-AST
binding, independent canonical plan encoding and decoded Arrow results. The
[proof ledger](../tests/README.md#typed-parameter-compiler-foundation) records
executed evidence and limits. These compiler checks do not establish installed
caller execution, authorization, durability or named prepared-statement support.

The parameter-template predicate has one comparison or cell-state test.
Boolean programs are rejected by this entry point before binding; ordinary
SQL retains its Boolean predicate grammar.
