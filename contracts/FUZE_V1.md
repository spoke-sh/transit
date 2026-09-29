# Fuze v1 bounded Table profile

Status: implemented bounded Table profile. This is the structured query contract;
joins, grouping, windowing and user-selected sorting are unsupported.
The [SQL frontend](../packages/zig/transit-fuze/docs/sql.md) lowers read-only
Table syntax to the separate incremental `Stream.Plan` without extending these
operator semantics.

Sources present one authorized snapshot with an identity, schema fingerprint
and revision. The initial Table schema has two named columns (1–16 ASCII
identifier bytes): a non-null `int64` primary key and a nullable `int64`, `bool`,
`utf8` or `binary` value. Names differ. At most 32 rows arrive in strictly
increasing primary-key order. Variable-width cells contain at most 220 bytes.
Missing columns, malformed UTF-8, duplicate keys and schema mismatch fail closed.

A v1 logical plan contains one predicate, a projection of one or both columns,
a limit from 0 through 32, and either row output, row count or integer sum.
Predicates are all, is-null, or a typed comparison. Equality/inequality support
all four types; ordered comparisons support integers only. A comparison with
null is unknown and does not select the row. `is_null` explicitly selects nulls.
Filter precedes limit; aggregates consume that limited selection. Count counts
selected rows including nulls; sum ignores nulls, returns null for an empty/all-null
selection, and rejects any signed 64-bit overflow in deterministic key order.
Sum is supported only for an int64 projected column. Aggregates return a one-row
Arrow batch. Empty row results preserve their projected schema.

Physical planning binds the logical plan to the source identity, schema and
capabilities. The first profile enables no optimizer rewrites. Explanation
contains operator names, read identity, output/row limits and schema fingerprint;
it excludes data and predicate literals. Station must authorize access before
either planning or explanation. An engine source token is not an access grant.

Execution is synchronous, demand-driven and bounded to one finite batch. The
caller supplies the allocation arena and output buffer; no spill, background
task or queued batch exists. Source iteration and result publication check a
cancellation flag, and Arrow kernels have the 32-row whole-input bound.
Returning bytes means the finite IPC stream includes schema, one record batch
and end marker. Allocation/output exhaustion and cancellation return errors,
never a successful prefix. Arrow buffers do not survive the call; durable
capture belongs to Station, outside this engine.
