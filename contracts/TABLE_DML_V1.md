# Typed Table DML compiler v1

`TableDml` compiles finite INSERT/UPDATE/DELETE against an explicitly supplied
Table name and [complete schema](TABLE_SCHEMA_V1.md). It returns owned typed rows,
stable column assignments and a shared logical predicate. This is a compiler
contract, not catalog resolution, authorization or native SQL admission. Its
statement owner must freeze selection and publish one complete successor; running
single-row publication in a loop does not make an atomic multi-row statement.

Identifiers, logical types and constant values use the shared
[typed SQL parser](TABLE_DDL_V1.md). Unquoted names fold ASCII case; quoted names
preserve decoded UTF-8 and doubled quote escapes. A supplied Table name must match
the parsed name exactly. Qualified columns require that same Table name; aliases,
joins and cross-Table mutation references are outside this compiler profile.
The compiler clones the complete schema and owns its input literals and names.
Outputs do not borrow SQL text or the caller's original schema lifetime.

## INSERT

`INSERT INTO name [(column, ...)] VALUES (value, ...), ...` accepts a column list
or all columns in schema order. Each named column appears once. Omitted columns
use their typed default or nullable NULL; required columns without a default
reject. Explicit DEFAULT and NULL remain distinct. `INSERT INTO name DEFAULT
VALUES` creates one fully defaulted row. Empty input rows, unknown/repeated
columns, wrong widths, invalid values and trailing statements reject.

All rows are typed and checked before returning a plan. One invalid later row
rejects the compilation without a partial plan. Schema defaults, NOT NULL,
Unicode character limits, exact numeric bounds and nested-value rules come from
the schema/value owners. Duplicate unkeyed values remain separate row inputs.
The execution owner checks declared uniqueness against the complete candidate
and current frozen data; compilation does not claim a primary key is available.

SQL has a 4096-byte input bound. The owned plan admits 1–1024 INSERT rows, each
within the existing schema/value limits. These bound one operation, not total
Table cardinality. Row identities come from durable operation identity and row
ordinal at execution; this compiler does not invent identities or consume IDs.

`Plan.fingerprint` binds the complete schema, action, ordered typed rows or stable
assignments, DEFAULT versus explicit values, and every predicate instruction.
It hashes length-prefixed parts with the `transit.table.dml.v1\0` domain. Whitespace
and keyword case do not affect the compiled intent. Names resolve before this
step; schema/object identity prevents later name rebinding. Explicit assignment
order remains part of intent. The canonical intent has a 4 MiB operation bound;
encoding uses at most one value envelope or one predicate atom as workspace.
This additional typed-caller bound does not change SQL's 4096-byte text limit.

## Schema-bound plan payload

`TableDmlCodec` encodes `FDM1`, the 32-byte full schema fingerprint, a u8-length
UTF-8 Table name, and action tag INSERT=1, UPDATE=2 or DELETE=3. Names contain
1–255 bytes without NUL. Integers are little-endian. INSERT adds row count:u16
and each complete structured row as length:u32 plus canonical bound cell bytes.
UPDATE adds assignment count:u16 and each stable column ID:u64 followed by
DEFAULT=0 or value=1; a value uses length:u32 and bound bytes under that column.
DELETE has no action payload.

Every action ends with predicate presence:u8. A present predicate has instruction
count:u8 and tags atom=0, NOT=1, AND=2, OR=3. Atoms encode all=0; state=1 followed
by column position:u8 and logical state:u8; or comparison=2 followed by column
position:u8, comparison:u8 and length-prefixed bound scalar cell. Comparison
codes are eq=0, ne=1, lt=2, le=3, gt=4, ge=5. State codes match FVL1. Predicate
shape, selected types, row/default constraints and the complete 4 MiB intent
budget are validated after decoding. The payload envelope allows at most that
budget plus 512 bytes; no total Table/cardinality bound is introduced.

The decoder requires the original schema and rejects a fingerprint mismatch
before allocating or interpreting schema-dependent cells. Its result owns the
schema, names, values and predicate literals. Truncation, invalid flags/tags and
trailing data reject. Enclosing native requests supply the current shared
definition, exact catalog metadata/identity and authorization; FDM1 alone does
not admit work or authorize rebinding to a newer schema. Schema references let
small point requests avoid retransmitting a complete descriptor.

## UPDATE and DELETE

`UPDATE name SET column = value|DEFAULT, ... [WHERE predicate]` binds assignments
to stable column IDs. Constants use the declared type, including nested values.
An assignment is checked even if selection would match no rows. Every assigned
column appears once; the compiler admits key-column changes, whose complete
uniqueness check belongs to execution. Column expressions, function calls,
subqueries and RETURNING are not admitted here.

`DELETE FROM name [WHERE predicate]` and UPDATE without WHERE select all rows at
the owner's frozen source. Predicates admit qualified/unqualified column versus
typed scalar literal comparisons (`=`, `<>`, `!=`, `<`, `<=`, `>`, `>=`), state
tests (`IS [NOT] NULL|MISSING|VALUE|TYPE_ERROR|CONFLICT`), parentheses, NOT, AND and OR.
These state names match the shared SQL grammar. Ordinary Table rows persist only
values and SQL NULL; the other state predicates do not authorize storing missing,
source type errors or conflicts.
Precedence is NOT, then AND, then OR. Ordinary persisted Table rows still obey
their separate state constraints; state-test syntax does not admit stored errors.
Comparing to NULL rejects with IS NULL guidance. Unsupported scalar/operator or
nested/JSON comparisons reject before row execution.

Predicates use the same `LogicalPredicate` atoms and eager postfix Boolean
machine as logical file plans. NULL comparisons retain unknown truth, NOT does
not turn unknown into selected, and evaluated errors are not hidden by Boolean
identities. Programs have at most 64 instructions and fewer than 16 levels of
parenthesis/NOT nesting. Literal byte limits and scalar comparison admission
remain the shared logical predicate limits; storage support does not expand them.

`primaryKeyEquality` qualifies a point lookup only when the complete predicate
is a conjunction of exactly one equality per declared primary-key column. It
returns values in declared key order. Partial keys, repeated atoms, extra
conditions, inequalities, OR and NOT retain scan semantics; no predicate is
dropped to obtain a faster path. This classification performs no source reads.

## Binding, diagnostics and execution boundary

Header-only `target` inspection provides a kind/name for authorized resolution;
it does not validate or admit a complete statement. `compile` consumes the whole
input, owns the bound schema and reports the current byte location. Its diagnostic
projection preserves the actual compiler cause and `not_submitted` outcome;
unknown/allocator errors remain at the caller boundary. It does not reparse
typed failures with another profile or attach uncertain-write resume advice.

The execution owner checks current access, object/schema identity and the exact
source basis, generates stable insert identities, validates complete successors
and atomically publishes data/index/head, matched/changed counts and outcomes.
Prepared or saved work must never rebind to a replacement Table by name or
recompile against a newer schema. The compiler alone establishes none of those
runtime or recovery guarantees.
