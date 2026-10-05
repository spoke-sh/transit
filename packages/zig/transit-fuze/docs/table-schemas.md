# Pure Table schemas

`TableSchema` validates immutable, borrowed schema revisions and Table cells.
It has no catalog, storage or authorization side effects. This model does not
change the executable [Table profile](../../../../docs/reference/tables.md).

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

`encode` writes canonical `FTS1` bytes. `decode` and `clone` return an arena-owned
schema; `deinit` frees names, recursive descriptors and defaults. Decoding rejects
truncation, trailing bytes, noncanonical boolean flags and a missing or foreign
definition. A SHA-256 fingerprint covers the complete schema, including identities,
revision, column order, defaults and key order.

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
