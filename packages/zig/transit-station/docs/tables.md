# Tables and finite Arrow results

A Table has two named columns: a non-null int64 primary key and a nullable
int64, boolean, UTF-8 or binary value. Names are distinct ASCII identifiers of
1–16 bytes; variable-width values are at most 220 bytes. `Table.create/open`,
insert/update/upsert/delete and get operate on a private `Turn`. `Table.atomic`
restores the entire proposal on error and never splits a transaction.

`TableMutation.applySql(turn, table, name, sql)` compiles bounded INSERT, UPDATE
and DELETE statements through Fuze and applies them to that private turn.
`TableMutation.apply` accepts the same validated typed plan. The application
explicitly authorizes and routes these operations to its writer; the helper
neither submits nor commits. Inserts accept one to three literal rows and reject
duplicate keys. Updates and deletes require primary-key equality, returning zero
for a missing row. The provisional affected-row count becomes durable only with
the enclosing commit. The [mutation contract](../../../../contracts/TABLE_MUTATION_V1.md)
defines rollback, exact typing, bounds and recovery. Public query transports do
not admit these statements.

`Table.page` reads at most eight rows in increasing primary-key order. Its
continuation binds the captured or retained source identity, resource revision,
Table and storage-schema fingerprint. A cursor cannot move to a newer snapshot.
See [paged state](growing.md#bounded-access) for the view and retained-read rules.
No fixed resident array limits the total Table cardinality.

Descriptors use key `00 t <table:u32le>` and `TBL1`, value-type byte
(int64=1, boolean=2, UTF-8=3, binary=4), then two length-prefixed column names.
Rows use `00 r <table:u32le> <key:u64be>`, with the signed key's high bit flipped
to preserve numeric order. Values start with version 1 and a non-null byte;
the body is i64le, a boolean byte or UTF-8/binary bytes. Null has no body. Every
decode validates type and length.

Table queries use the current [query v1 definition](../../../../contracts/UNIFIED_QUERY_V1.md).
`Table.querySchema`, `queryDefinition` and `queryBasis` supply the same logical
schema and source declaration to both Station capture and transit-query.
Query schema fingerprints describe the logical columns; Table cursor fingerprints
describe the storage descriptor. Neither supplies authorization.

A handler can use [query capture and delivery](queries.md) for durable
Table results returned to an authenticated caller. `Query.start` binds a
`fuze.Unified.Plan` to a retained committed version and records a revisioned
peer/Table policy. It rejects private source mutations. The shared engine emits
nested Arrow cells in bounded segments; capture, publication, receipt and
acknowledgement each retain their own durable evidence.

For interactive reads or durable KV/Table/Document submissions, use
[transit-query](../../transit-query/README.md). These interfaces share query
semantics and result encoding. All reads and commits retain the native grant,
resource lifetime, fencing and recovery checks.
