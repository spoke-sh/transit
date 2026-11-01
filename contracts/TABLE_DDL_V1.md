# General Table DDL compiler v1

`transit-fuze.TableDdl` compiles allocator-owned general Table declarations and
schema changes. It shares the SQL lexer, statement byte/encoding/comment bounds,
[logical types](FUZE_TYPES_V1.md) and [Table schema semantics](TABLE_SCHEMA_V1.md).
This is an in-memory compiler contract, not catalog/native/console admission.
The executable state-declaration profile remains governed by
[state declarations](STATE_DECLARATION_V1.md) until its runtime cutover.

## Compilation and binding

`compile(allocator, sql, basis, location)` returns an `Owned` statement whose arena
owns parsed names, recursive descriptors and defaults; release with `deinit`.
All failures release partial allocations. The location sidecar retains a source
byte offset. Complete input, with one optional semicolon, is required.
Compilation performs no lookup, staging, policy change, write or effect.

`target` reads only the header to obtain the operation and allocator-owned name
for authorized catalog resolution. It is not statement validation or execution
admission. The caller resolves that exact name in its configured catalog and
supplies the captured basis to compilation. Table/column identifiers fold ASCII
unquoted names to lowercase; double-quoted UTF-8 names preserve case and decode
doubled double quotes. Names are nonempty and at most 255 decoded UTF-8 bytes.

CREATE supports IF NOT EXISTS, a general ordered column list, typed constant
defaults, nullable omission, explicit NULL/NOT NULL and one inline or composite
PRIMARY KEY. A key implies NOT NULL; explicit NULL conflicts. The first column
has no implicit key. Multiple primary-key declarations, duplicate/unknown key
columns and unsupported key types reject. Column IDs allocate from one in source
order. `Create.bind(object)` produces revision one with the caller's nonzero
object identity; a parsed name never supplies identity or authorization.

ALTER requires an exact captured schema and returns its object and complete
schema fingerprint alongside one action. Supported actions are ADD/DROP COLUMN,
RENAME COLUMN, RENAME TO, SET/DROP DEFAULT, SET/DROP NOT NULL, TYPE and SET DATA
TYPE. Column names resolve to stable IDs. Column actions pass the pure evolution
validator; this does not prove that all existing rows can be transformed.
Publication requires the frozen basis and complete validation/rewrite rules in
the Table schema contract. USING expressions and unqualified constraint changes
reject. An old accepted action cannot be rebound to a later schema.

DROP supports IF EXISTS and optional RESTRICT. Its compiled target includes the
captured object/schema, or explicit absence for IF EXISTS. That absence must not
later become permission to delete a newly created object with the same name.
An absent basis without IF EXISTS rejects. CASCADE rejects. Dependency inspection,
tombstones, original-operation outcomes and cleanup belong to the runtime owner.

## Type and literal profile

Scalar spellings and parameters use the
[shared resolver](TABLE_SCHEMA_V1.md#scalar-sql-type-name-resolver). Recursive type
constructors are STRUCT(name type, ...), LIST(type), ARRAY(type, length),
MAP(key_type, value_type) and UNION(name type, ...). Nested fields/elements default
to nullable and admit NULL/NOT NULL; struct/union fields additionally admit
OPTIONAL for missing state. Map keys are required; explicit NULL rejects.
Parameterized VARCHAR inside a nested descriptor rejects because that descriptor
does not carry a nested character constraint. No parameter is silently ignored.

Numeric/boolean defaults bind directly to the declared type. UTF-8 uses quoted
strings with doubled single quotes. Binary uses X'hex'. Date/time/timestamp/UUID
use strings with optional corresponding type prefix and the shared exact literal
rules. JSON accepts an optionally JSON-prefixed string containing validated exact
JSON text; its result is a typed JSON cell. Interval uses
INTERVAL(months, days, nanoseconds), checked as int32/int32/int64 components.

Recursive defaults use STRUCT(values...), LIST(values...), ARRAY(values...),
MAP(key,value,...) and UNION(alternative_name,value). Struct values follow field
order; arrays require their declared length. Maps canonicalize typed key order
and reject duplicates. NULL and nested OPTIONAL MISSING retain separate states.
Complete descriptor/default validation enforces recursive budgets, exact numeric
ranges, NOT NULL and character constraints before returning a declaration.

Table-level `[CONSTRAINT name] CHECK (...)` declarations bind a conjunction of
column/scalar comparisons, compatible column/column comparisons and `IS [NOT]
NULL` tests. Columns may appear later in the declaration. Anonymous constraints
receive `constraint_<id>` names. `ALTER TABLE ... ADD [CONSTRAINT name] CHECK (...)`
optionally accepts `NOT VALID`, which still enforces new writes. `VALIDATE
CONSTRAINT name` requests existing-row validation; `DROP CONSTRAINT name
[RESTRICT]` preserves the allocation floor. CASCADE, OR, effectful expressions,
subqueries and parameters reject. The schema contract defines exact state rules
and bounds; compilation does not claim that a validation scan has completed.

Table-level `[CONSTRAINT name] FOREIGN KEY (local_columns) REFERENCES parent
(target_columns) [ON DELETE action] [ON UPDATE action] NOT ENFORCED` freezes
the parent's exact object, definition and ordered primary-key columns. Actions
are `RESTRICT` (default), `NO ACTION`, `CASCADE` or `SET NULL`; they describe a
staged constraint and do not execute. Each action clause may occur once, in either
order. The same declaration is available through `ALTER TABLE ... ADD`.
The catalog resolver requires current parent metadata access. Missing explicit
`NOT ENFORCED`, self-references, cross-catalog references and activation
of enforcement reject. Referenced types and collations must match; SET NULL
requires nullable local columns. The catalog protects referenced parent columns
before child publication, recovering each step with the original DDL identity.

Inline CHECK/REFERENCES, UNIQUE, generated/identity columns and auto-increment
clauses reject. Text column declarations admit
`COLLATE UTF8_BINARY`, `ASCII_CI`, `EBCDIC_CP037`, `EBCDIC_037_PAD` and
`EBCDIC_1047_NOPAD`; defaults undergo the same repertoire validation as writes.
Expression-level collation overrides and SQL changes to an existing column’s
collation reject. The compiler does not admit
CTAS, arbitrary expressions, multi-action ALTER, transaction sessions or query
execution. These limits are independent of the capabilities of typed values.
