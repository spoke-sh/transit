# Offline state declarations v1

Fuze's `Declaration` module owns bounded, typed state definitions for offline
review. `Sql.parseDeclaration` uses the shared SQL lexer; `Declaration.compile`
adds semantic validation. This contract defines an in-memory Zig value and SQL
formatting, not a persisted catalog, wire format, ABI action or saved command.
The native contract definition and existing query/mutation formats are unchanged.

## Definition and validation

A definition owns its name and one body:

| Body | Fields |
| --- | --- |
| `table` | One to eight ordered columns, each with a name, scalar type and nullability |
| `kv` | One scalar value type |
| `document` | No fields |

Names use the existing SQL rules: one to sixteen ASCII identifier bytes,
unquoted names folded to lowercase and quoted names preserved. Owned names must
have canonical zero padding; typed callers cannot bypass validation with invalid
lengths or hidden suffix bytes. Table column names must be distinct after name
normalization. Columns occupy a contiguous prefix of the owned eight-slot array.
This is a per-definition work bound, not a bound on retained catalog size.

Scalar types are `INT64`, `BOOL`, `UTF8` and `BINARY`. Column nullability is one
of `unspecified`, `null` or `not_null`. Omission remains `unspecified`: compilation
does not choose a default. KV declarations choose no key/value codec or
nullability policy. Document declarations choose no replica, projection or
initial value. The syntax follows `createTable`, `createKv` and `createDocument`
in the [SQL grammar](sql/TransitExtensions.g4).

The parser consumes complete input, allowing one optional terminator, whitespace,
line comments and block comments nested up to sixteen levels. Input is valid UTF-8,
contains no NUL and is at most 4096 bytes. Unsupported types, clauses, extra
statements and more than eight columns reject. `parseDeclaration` returns null
for a non-`CREATE` statement; unsupported `CREATE` families reject with
`UnsupportedDeclaration`. `compile` rejects non-declarations with
`UnsupportedStatement`. Connection/source/sink definitions are not part of this
compiler.

## Current Table capability

`Definition.tableSchema()` converts only an explicitly compatible definition to
the existing `model.Schema`: exactly two columns, an `INT64 NOT NULL` first
column and a nullable second column of any listed scalar type. This adapter
identifies the first column with Station's existing immutable int64 primary key;
it does not introduce a general SQL primary-key clause. Both nullability fields
must be explicit. It returns the same schema consumed by Table mutation and
query owners, without creating a Table.

Other valid declarations remain reviewable but fail this capability check:
`NotTableDeclaration`, `UnsupportedTableColumnCount`, `UnspecifiedNullability`,
`UnsupportedTableKey` or `UnsupportedTableNullability`. There is no automatic
widening, column removal, nullability coercion or silent default.

## Formatting and ownership

`Definition.validate()` applies the same structural checks to typed callers.
`Definition.format(output)` validates before formatting canonical SQL into the
caller's bounded output buffer. Keywords/types are uppercase, all names are
double-quoted, columns retain their order, explicit nullability is retained and
one semicolon terminates the statement. Omitted nullability stays omitted.
Parsing this output yields the same owned definition. Comments and input layout
are not retained. The returned slice borrows `output`; on `WriteFailed` discard
the buffer, which may contain an incomplete prefix. Definition values have no
borrowed pointers or allocation lifetime.

Formatting produces review text, not a durable identity, revision or capability.
SQL query interfaces continue to reject `CREATE`. Compilation, validation and
formatting perform no catalog lookup, resource provisioning, grants, writes,
snapshot acquisition, connector dispatch or secret resolution. Publication needs
its own authorized conditional operation, exact dependency basis and recoverable
result; none is implied by this offline interface.
