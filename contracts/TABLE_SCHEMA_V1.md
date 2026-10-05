# Table schema v1

This contract defines the pure general Table schema model implemented by
`transit-fuze.TableSchema`. It does not widen the executable native Table,
catalog, SQL or transport profiles; their owning contracts govern admission.

## Identity and validation

Schemas carry nonzero u64 object and revision identities and a monotonic
next-column allocation floor. Column IDs are distinct, nonzero and below that
floor. Names are distinct valid UTF-8, with the shared logical descriptor name
rules. Column order determines row position, independently of identity.

Columns have logical types, nullable flags, optional typed defaults and optional
positive Unicode-scalar character limits for UTF-8 only. Missing assignments and
DEFAULT select the default, then nullable NULL; a required field without either
rejects. Explicit NULL never selects the default. Ordinary stored cells reject
type-error/conflict at every depth. Nested optional members may be missing;
top-level cells cannot. Complete rows share recursive value budgets.

An ordered primary-key list contains distinct column IDs. Every key column is
nonnullable. Admitted descriptors are signed/unsigned integers, finite floats,
decimal, boolean, UTF-8, binary, date, time, civil/UTC timestamp and UUID. Interval,
nested types and JSON reject as key columns. An empty key list implies no user
uniqueness constraint; row identity belongs to the storage owner. This schema
contract alone does not define an index or establish uniqueness.

One schema has 1–128 columns and at most 64 KiB encoded bytes. The complete row
descriptor shares the [logical descriptor budgets](FUZE_TYPES_V1.md); defaults
count toward schema bytes. One row shares the logical value byte/child/depth
budgets across every column. These limits never bound total Table cardinality.

## Canonical envelope

The envelope contains magic `FTS1`, a u8-length mandatory definition
`transit.table.schema.v1.2026-10-05`, three u64 identities (object, revision,
next-column), and a u16 column count. Each column contains its u64 ID, u8-length
UTF-8 name, u16-length `FTY1` descriptor, boolean nullable byte, u32 character
limit (zero means absent), and boolean default-present byte. A present default
is a u32-length `FVL1` value with matching type/nullability and optional=false.
The envelope ends with a u16 key count followed by ordered u64 column IDs.
All integers are little-endian; strings and blobs follow their length directly.

Booleans are exactly 0 or 1. Decode rejects missing/foreign definitions,
truncation, trailing bytes, invalid identities/types/defaults/keys and exceeded
budgets. No fallback interpretation or default definition is permitted.
SHA-256 over the complete envelope is the schema fingerprint.

## Ownership

Borrowed schemas and assignment results retain their original owners. Decode
and clone return an arena owning names, nested descriptors and defaults, released
by `deinit`. A failed assignment invalidates scratch output and returns no
successful row. Validation, encoding and decoding perform no I/O or publication.
