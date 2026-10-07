# Offline KV and Document declarations v1

Fuze's `Declaration` module owns typed `CREATE KV` and `CREATE DOCUMENT`
definitions for offline review. `Sql.parseDeclaration` uses the shared SQL lexer;
`Declaration.compile` adds semantic validation. This contract defines an owned
in-memory Zig value and SQL formatting, not a persisted catalog, wire format,
ABI action or saved command.

General Table declarations use `TableDdl.compile(allocator, text, basis, location)`
and the [Table DDL contract](TABLE_DDL_V1.md). That compiler owns CREATE/ALTER/DROP,
general logical types, aliases, defaults, nullability and primary keys. Its owned
result requires `deinit`; creation binds an explicit object identity to the shared
[Table schema](TABLE_SCHEMA_V1.md). `Declaration` has no separate Table parser,
Table column array or conversion to a two-column schema.

## Definition and validation

A definition owns its name and either a `kv` body with one scalar value type or
a fieldless `document` body. Names contain one to sixteen ASCII identifier bytes;
unquoted names fold to lowercase and quoted names preserve case. Owned names
require canonical zero padding: typed callers cannot bypass validation with
invalid lengths or hidden suffix bytes.

KV value types are `INT64`, `BOOL`, `UTF8` and `BINARY`. A KV declaration chooses
no application key/value codec or nullability policy. A Document declaration
chooses no replica, projection or initial value. These limits belong to offline
KV/Document declarations and do not restrict Table schemas. The syntax follows
`createKv` and `createDocument` in the [SQL grammar](sql/TransitExtensions.g4).

The parser consumes complete input, allowing one optional terminator, whitespace,
line comments and block comments nested up to sixteen levels. Input is valid UTF-8,
contains no NUL and is at most 4096 bytes. Unsupported types, clauses and extra
statements reject. `parseDeclaration` returns null for a non-`CREATE` statement;
unsupported CREATE families, including TABLE, reject with `UnsupportedDeclaration`.
`compile` rejects non-declarations with `UnsupportedStatement`. Use the Table DDL
compiler for Table declarations. Connection/source/sink definitions have separate
reference grammar and no publication route through this compiler.

## Formatting and ownership

`Definition.validate()` checks typed callers' owned names.
`Definition.format(output)` validates before formatting canonical SQL into the
caller's bounded output buffer. Keywords/types are uppercase, names are
double-quoted and one semicolon terminates the statement. Parsing that output
reproduces the definition. Comments and input layout are not retained. The
returned slice borrows `output`; on `WriteFailed`, discard the buffer, which can
contain an incomplete prefix. KV/Document definitions have no borrowed pointers
or allocation lifetime.

Compilation, validation and formatting perform no catalog lookup, provisioning,
grants, writes, snapshot acquisition, connector dispatch or secret resolution.
SQL query interfaces do not publish these offline definitions. Table publication
uses its authorized catalog operations, exact schema basis and recoverable result;
compiling a Table declaration likewise confers no execution authority.
