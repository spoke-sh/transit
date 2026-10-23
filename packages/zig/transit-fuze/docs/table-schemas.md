# Pure Table schemas

`TableSchema` validates immutable, borrowed schema revisions and Table cells.
It has no catalog, storage or authorization side effects. This model does not
change the executable [Table profile](../../../../docs/handbook/reference/tables.md).

A schema identifies its stable object, revision and monotonic next-column ID.
Columns have distinct nonzero IDs, UTF-8 names, logical types, nullability and
optional typed defaults. Names and positions do not imply keys. An empty
primary-key list leaves row identity to the storage owner; a nonempty ordered
list requires distinct, nonnullable columns. Scalar types except interval are
admitted key descriptors. Nested values and JSON remain storable without gaining
key traits. Descriptors use the shared [logical types](../../../../contracts/FUZE_TYPES_V1.md).

`insert` applies assignments by column ID. Omitted columns and explicit DEFAULT
use the typed default, then nullable NULL, otherwise fail as missing required
fields. Explicit NULL never invokes a default. `update` changes only assigned
cells. Both validate the complete row before returning; an error leaves the
supplied scratch output unusable. Returned cells borrow assignment/default/old-row
storage. Keep those owners alive; the model does not publish partial results.

Ordinary Table cells admit typed values and nullable SQL NULL. Nested optional
members may remain missing. Type-error and conflict states reject at every depth.
Top-level omission cannot be stored as missing. `max_characters` applies only to
UTF-8 and counts Unicode scalar values, including trailing spaces; it never
truncates, normalizes or counts grapheme clusters.

One schema has 1–128 columns, at most 64 KiB encoded bytes and the shared descriptor
budgets across the complete row type. One row shares the logical value byte,
child and depth budgets across all columns. These are per-operation bounds,
independent of Table or catalog cardinality. Defaults count toward the schema's
encoded-byte bound.

Physical encoding and collation are independent column properties. The
[representation contract](../../../../contracts/TABLE_SCHEMA_V1.md#physical-representation-and-collation)
lists exact admitted pairs and value restrictions. `validateCell` checks
representability before storage acceptance: CP037 rejects characters outside
its repertoire, and HFP rejects overflow or underflow. `icu_root` rejects;
the implementation supplies no locale-sensitive approximation.

`PhysicalCodecs` writes definition-bound `TCP1` pages. Integer packed/zoned
codecs preserve their admitted range; RLE, dictionary and HFP preserve floating
zero signs. CP037 conversion consumes UTF-8 scalars and produces valid UTF-8
on decode. Its complete mapping includes controls and Latin-1 characters.
`Collation` uses the same CP037 weights for comparison and sort keys, and folds
only ASCII A–Z for `ascii_ci`. Sort keys use no space padding.

`encode` writes canonical `FTS1` bytes. `decode` and `clone` return an arena-owned
schema; `deinit` frees names, recursive descriptors and defaults. Decoding rejects
truncation, trailing bytes, noncanonical boolean flags and a missing or foreign
definition. A SHA-256 fingerprint covers the complete schema, including identities,
revision, column order, defaults and key order.

`TableSchemaJson` projects the same schema into neutral JSON with mandatory
current-definition binding, full-width decimal-string identities, shared logical
descriptors and lossless defaults. `encode`/`decode` own their outputs; `foreign`
and `native` copy complete values into an explicit enclosing arena. The JSON
input limit is 2 MiB and the canonical schema still has a 64 KiB bound. The
[reflected schema](../api/logical-table-schema.schema.json) describes structural
shape; shared semantic validators enforce identities, keys, types and defaults.
The JSON envelope supports plain encoding and default collation; exporting
physical attributes rejects explicitly. `FTS1` preserves the full attributes
used by the direct Table interface.

The [Table schema contract](../../../../contracts/TABLE_SCHEMA_V1.md) owns the
exact envelope, identity and validation rules.

`TableRow` encodes schema-bound physical rows with stable identities and owns
decoded values. Its layout fingerprint excludes names/defaults/revisions, so
metadata-only changes retain row bytes while complete schema fingerprints still
fence old prepared work. It also supplies canonical equality-key bytes and typed
key comparison; the storage owner must handle digest collisions explicitly.

`TableEvolution.apply` returns a borrowed successor and classifies its required
work as metadata, complete existing-row validation or rewrite. `Transition.row`
preserves existing values by ID, initializes new columns and performs checked
exact numeric casts. Keep the input schema, change and supplied column scratch
alive. Storage owns source capture, complete iteration, indexes, publication and
recovery; successful pure validation does not complete ALTER.

`SqlTypes.resolve` normalizes selected scalar SQL names and validates their
parameters. Its [alias table](../../../../contracts/TABLE_SCHEMA_V1.md#scalar-sql-type-name-resolver)
defines widths, decimal defaults, VARCHAR character limits and exact temporal
precision. Unsupported padding/precision/time-zone semantics reject. A resolved
descriptor does not imply that a particular SQL transport admits that type.

`TableDdl.compile` supplies allocator-owned general CREATE/ALTER/DROP compilation
against this model. Its [compiler contract](../../../../contracts/TABLE_DDL_V1.md)
defines target binding, clauses, recursive type/value constructors and rejection
rules. `target` extracts only the header for authorized lookup; full compilation
is still required. This compiler does not widen native or console DDL admission.
