# Syntax, names and literals

The [SQL reference](../sql.md) distinguishes executable queries from
grammar-only statements. The checked syntax owner is
[TransitExtensions.g4](../../../contracts/sql/TransitExtensions.g4).
[Application declarations](application.md) have their own grammar and bounds.
See [data types and cell states](types.md) for type coverage and
[functions and operators](expressions.md) for expression support.

## Reading the syntax

In syntax blocks, uppercase words and punctuation are literal SQL. Lowercase
names such as `source` stand for values supplied by the caller. Square brackets
mean optional text, `|` separates alternatives, and `...` repeats the preceding
item. These markers are notation, not characters to type. Examples ending in a
semicolon are complete statements unless explicitly labeled as fragments.

The query grammar accepts one statement and an optional final semicolon. Extra
statements and trailing tokens reject. Keywords are case-insensitive. Whitespace,
`--` line comments and nested `/* ... */` comments can separate tokens.

## Names

Unquoted names start with an ASCII letter or underscore and continue with ASCII
letters, digits or underscores. They fold to lowercase. Double quotes preserve
case; a doubled double quote is the grammar's escape inside a quoted identifier.
Reserved keywords need quotes when used as names.

The Fuze compiler additionally requires every decoded name to be a valid ASCII
identifier of at most 16 bytes. Quoting does not admit spaces, punctuation or
longer names into an executable query. Reference-grammar acceptance alone does
not enforce these production bounds.

`source.column` qualifies a column with the exact declared source name.
The compiler performs no schema, namespace or catalog lookup. Ordinary source
aliases are unsupported; `AS alias` exists only in the restricted
[aggregate subquery](select.md#aggregate-a-limited-input).

## Query literals

| Form | Example | Meaning |
| --- | --- | --- |
| Signed decimal integer | `-42`, `+7`, `0` | int64, from -9223372036854775808 through 9223372036854775807 |
| Boolean | `TRUE`, `FALSE` | Boolean value |
| Null | `NULL` | Explicit null; use `IS NULL` |
| String | `'it''s ready'` | UTF-8 text; doubled single quotes encode a quote |
| Binary | `'\x00ff'::bytea` | Hexadecimal bytes; `::bytea` is the only cast form |

Backslashes are literal, including the `\x` prefix decoded by the binary literal
handler. E strings, dollar quoting, adjacent-string concatenation, floating-point
literals, implicit casts and general expressions are unsupported. Uint64 and
float64 columns can be projected by query v1; comparison literals of those
types require typed plans.

`LIMIT` accepts unsigned decimal digits without a sign. Its allowed value is
0–18446744073709551615. No limit means no
implicit truncation; finite execution budgets still apply.

## Administrative options and types

The grammar-only connector statements use a nonempty parenthesized list:

```text
(option = 'value' [, option = 'value' | option = SECRET('reference') ...])
```

Each value is a string or `SECRET('reference')`; numbers and booleans must be
quoted here. Keys and connector kinds are identifiers. Grammar acceptance does
not validate option names, duplicates, a connector's configuration or a secret
binding. `SECRET` names a credential reference; it does not carry resolved bytes.
See [CREATE CONNECTION](create-connection.md).

The declared types for [CREATE TABLE](create-table.md) and
[CREATE KV](create-kv.md) are `INT64`, `BOOL`, `UTF8` and `BINARY`. These tokens do
not imply SQL provisioning support or encode every type in a unified query schema.

## Query bounds and rejection

The production parser accepts at most 4096 UTF-8 bytes, 16-byte identifiers,
16 levels of block comments and 220 bytes per decoded literal cell. It rejects
NUL, malformed UTF-8, unterminated tokens and out-of-range integers. The AST holds
at most eight explicit projected columns and one predicate. Durable queries have finite plan upload and execution budgets.

These are per-operation bounds, independent of source cardinality. A syntactically
valid query may still fail name/type checking, authorization or execution. See
[SELECT failures](select.md#failures-and-unsupported-forms) and the
[compiler reference](../../../packages/zig/transit-fuze/docs/unified-sql.md).
