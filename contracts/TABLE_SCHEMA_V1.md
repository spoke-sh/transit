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

## Declarative integrity

`integrity` contains a monotonic `next_id` allocation floor and at most 64 total
CHECK/foreign-key descriptors. Constraint IDs are nonzero u32 values below that
floor; names are distinct, nonempty UTF-8 strings of at most 63 bytes without NUL.
Dropping a constraint preserves its allocation floor. Reusing an identity for a
changed expression, target or referential action rejects.

A CHECK is an ordered conjunction of 1–32 deterministic comparisons between a
column and a typed scalar literal, comparisons between two identically typed and
collated columns, or `IS NULL`/`IS NOT NULL` predicates. References bind stable
ColumnIds. Comparison literals must be representable under the column's declared
collation. Parameters, subqueries, external reads, capture and dispatch are not
CHECK expressions. TRUE and SQL UNKNOWN pass; FALSE, missing, type_error and
conflict reject. A failure rejects the whole mutation before publication.

`validated=false` means older rows have not been proved to satisfy the CHECK.
Every new INSERT, UPDATE, replacement and private transaction write still
enforces it after assignment/default resolution. Stored-row decoding and
historical projection validate shape independently of CHECK enforcement, keeping
older violations readable. Validation of existing rows must complete against
one unchanged source basis before `validated=true` becomes visible. A failed
validation preserves the earlier definition and data.

CHECK/local foreign-key columns cannot be dropped or have their type/collation
changed while referenced. A compatible rename preserves those bindings.
Foreign keys carry ordered local and target columns, an exact target object and
schema revision, exact `DataLifecycle.Definition`, referential actions and
explicit enforcement state. The schema revision and definition revision are
different identities. At most four distinct parent objects may be referenced,
within the same catalog and branch one at publication. Staged
descriptors do not assert referential integrity; `enforced` rejects without the
owning index-backed runtime enforcer. Parent candidate-key/type/collation checks
and dependency protection belong to catalog publication, beyond shape decoding.

## Physical representation and collation

Logical types, physical encodings and collations are separate descriptors.
The supported encoding/type pairs are:

| Encoding | Admitted logical types and value constraints |
| --- | --- |
| `plain` | Every admitted Table type |
| `bitpacked` | Signed/unsigned integers through 64 bits and boolean |
| `rle`, `dictionary` | Scalar key types; floating zero signs remain distinct stored values |
| `fsst` | UTF-8 or binary; Transit's bounded symbol-table page format, without upstream FSST wire compatibility |
| `comp` | Signed 8/16/32/64-bit integers; 16/32-bit types use 2/4 bytes and other admitted widths use 8 bytes, big-endian |
| `comp_3`, `zoned` | Signed integers through 64 bits or decimal precision at most 31; 16-byte packed decimal or 31-byte zoned decimal |
| `ibm_hfp` | Float32/64 exactly representable in normalized 8-byte HFP; nonzero magnitude from `2^-260` inclusive to `2^252` exclusive; signed zero preserved |
| `ebcdic` | UTF-8 containing only U+0000–U+00FF, transcoded exactly to CP037 |

Unsupported combinations reject at schema validation. Value constraints also
apply to defaults and every inserted or transformed row before acceptance.
HFP underflow/overflow and unmappable CP037 characters reject without rounding,
replacement characters or successful-prefix publication. Physical page decoding
does not turn an incompatible schema into another codec.

`none` uses the type's ordinary order. Text supports `utf8_binary` (unsigned
UTF-8 byte order), `ascii_ci` (ASCII A–Z folded only) and `ebcdic_cp037` (unsigned
CP037 weights after UTF-8 decoding). All use NO PAD; trailing spaces remain
significant. CP037 collation has the same U+0000–U+00FF repertoire restriction
even with another physical codec. `ebcdic_037_pad` uses CP037 weights and virtual
space padding: trailing U+0020 is insignificant, but control weights below CP037
space remain ordered below padding. `ebcdic_1047_nopad` uses the CP1047 table and
NO PAD. Both admit only U+0000–U+00FF and preserve original stored text.
Collation tags 5 and 6 are distinct from existing CP037 tag 3.
`icu_root` is a reserved descriptor rejected
by validation and comparison; no Unicode collation version or locale is implied.
Table CREATE/ADD COLUMN and finite query comparisons admit these five text
profiles through the shared schema and comparison owners. Locale-dependent
Unicode rules remain unsupported. Ordered storage keys, equality hashes and
zone-map boundaries use the declared comparison; CP037 physical encoding remains
independent of a column’s collation.

## Canonical envelope

The envelope contains magic `FTS1`, a u8-length mandatory definition
`transit.table.schema.v1.2026-11-01.integrity`, three u64 identities (object, revision,
next-column), and a u16 column count. Each column contains its u64 ID, u8-length
UTF-8 name, u16-length `FTY1` descriptor, boolean nullable byte, u32 character
limit (zero means absent), and boolean default-present byte. A present default
is a u32-length `FVL1` value with matching type/nullability and optional=false.
After the u16 key count and ordered u64 column IDs, schemas with non-default
physical attributes include `FTP1` followed by each column's u8 encoding and u8
collation in column order. All-default schemas omit the trailer; a redundant
all-default trailer rejects. Enum values follow `TableSchema.Encoding` and
`TableSchema.Collation` in the owning Zig types.
Nonempty integrity follows the physical trailer, when present, as `FTI1`, u32
next-ID, u8 CHECK count and CHECK records, then u8 foreign-key count and records.
Each CHECK contains u32 ID, u8-length name, boolean validated flag, u8 atom count,
and atoms: tag 1 + u64 column + u8 comparison + u32-length typed `FVL1` literal;
tag 2 + u64 left column + u8 comparison + u64 right column; tag 3 (`IS NULL`) or
4 (`IS NOT NULL`) + u64 column. Literal descriptors match column type/nullability.
Each foreign key contains ID/name, u64 target object/schema revision, its exact
80-byte target definition (u64 realm/resource/catalog/branch/object/revision,
then 32 digest bytes), u8 delete/update/
enforcement tags, u8 arity, then ordered pairs of u64 local/target columns. Tags
use the owning Zig enums. The empty integrity value (floor 1, no constraints)
omits `FTI1`; a redundant empty trailer rejects. A noninitial floor is retained
even when the last constraint is dropped.
All integers are little-endian; strings and blobs follow their length directly.

Booleans are exactly 0 or 1. Decode rejects missing/foreign definitions,
truncation, trailing bytes, invalid identities/types/defaults/keys and exceeded
budgets. No fallback interpretation or default definition is permitted.
SHA-256 over the complete envelope is the schema fingerprint.

## Neutral schema value

`TableSchemaJson.Schema` is the language-neutral schema projection. Its reflected
[JSON Schema](../packages/zig/transit-fuze/api/logical-table-schema.schema.json)
requires the current shared Transit `definition`, decimal-string `object`,
`revision` and `next_column`, an ordered `columns` array and an ordered
`primary_key` array of decimal-string column IDs. Integer identity strings are
canonical unsigned u64 values: no signs, leading zeroes or precision loss.

The optional `integrity` member defaults to the empty declaration. Its column,
target-object and target-revision IDs use the same decimal-string rule; CHECK
literals use the shared logical cell projection. Foreign-key `target_definition`
contains decimal-string realm/resource/catalog/branch/object/revision and a
64-character lowercase hexadecimal digest. This default defines an empty
current-format declaration and never substitutes a missing shared definition.

Each column has `id`, `name`, a shared logical `type`, `nullable`, `default`,
`max_characters`, `encoding` and `collation`. All fields are present, including
explicit `plain` and `none` for default physical descriptors. JSON null for `default` means no default;
a logical cell containing SQL NULL remains an explicit default. Logical defaults
use the shared neutral cell representation: exact integer/decimal strings,
floating-point bits, binary hex and recursive typed constructors. A schema never
turns rich values into an untyped string.

Encoding and collation use the owning `TableSchema.Encoding` and
`TableSchema.Collation` enum names, including `comp_3` for packed decimal.
Conversion preserves every descriptor and the exact `FTS1` fingerprint. The
shared validator rejects unsupported type/codec pairs and reserved collations;
structural JSON acceptance does not establish executable support. The direct
Table interface carries the same information in complete `FTS1` schema bytes,
including `FTP1` attributes.

The standalone JSON decoder accepts at most 2 MiB of input before applying the
same 128-column, 64 KiB encoded-schema and complete descriptor/default constraints.
Structural schema validation is separate from those semantic checks. Missing or
foreign definitions, wrong JSON shapes, invalid canonical identities and invalid
keys/defaults reject. `native` and `foreign` take an enclosing arena and copy all
borrowed descriptor/default/name storage; their results survive destruction of
the input owner. `decode` returns an independently owned native schema.
These conversions perform no catalog lookup or execution and confer no rights.

## Physical rows and keys

`TableRow` defines pure row/value envelopes, independently of publication and
index admission. A row identity is `(origin: u64, operation: u64, ordinal: u32)`;
origin and operation are nonzero, ordinal is zero-based. The owning writer assigns
and durably retains these identities. Exact retries reuse the original identity;
different duplicate rows have different identities. Identity bytes are the three
big-endian integers in that order, so byte order is identity order.

The physical row type is a logical struct in column order. Each field uses its
column ID as 16 lowercase hexadecimal ASCII digits, with the column's type and
nullable flag; optional is false. Validate both the user-named and physical
descriptors under shared descriptor limits. The layout fingerprint is SHA-256 of
`transit.table.layout.v1` followed by NUL, the schema definition string without a
length, the object u64 little-endian and the physical type's 32-byte fingerprint.
Names, defaults, schema revision and key declarations do not change this digest.
When physical attributes are present, append `FTP1` and each column's encoding
and collation bytes to the hash input, preserving their interpretation.
It describes physical interpretation, never admission to a newer schema revision.
Prepared and saved operations still require the complete schema fingerprint.

`FTR1` contains magic, u8-length mandatory definition
`transit.table.row.v1.2026-10-05`, the 32-byte layout fingerprint, the 20 identity
bytes and an `FVL1` nonnullable/nonoptional struct cell of the physical type. The
maximum envelope is the fixed header plus the logical value codec's 2 MiB bound.
Decoding requires an expected schema, checks layout and exact physical descriptor,
owns every decoded value, then checks current row constraints. It rejects source
error/conflict states, foreign definitions, truncation and trailing bytes.

Canonical equality keys are `FTK1`, u8-length row definition, object u64,
u16 key-column count, then each column's u64 ID and complete `FVL1` nonnullable
value envelope in declared key order. Integers outside identity bytes are
little-endian. Variable components retain their codec framing. Floating zero
normalizes to positive zero for keys only; row codecs retain the original bits.
UTF-8 and binary keys use exact bytes, with no collation or Unicode normalization.
The maximum canonical key is 2 MiB plus 64 KiB, under the row's shared value
budgets. This is an equality encoding, not an ordered SQL index encoding.

An index may address a key by SHA-256 of the canonical key, but a matching digest
never establishes uniqueness. It must compare actual typed key values using
`sameKey`, retaining distinct collision candidates. `sameKey` and `encodeKey`
reject schemas without a declared primary key. The pure APIs do not implement
index collision buckets or publish a uniqueness decision.

## Pure schema evolution

`TableEvolution.apply` produces one validated successor revision for add/drop/
rename column, set/drop default, nullability and admitted type changes. Addition
allocates the current next-column ID and advances the floor; dropping never
lowers it. A primary-key column cannot be dropped or made nullable. Dropping the
last column rejects. Rename preserves ID and rejects duplicate names.

Name/default changes and NOT VALID CHECK additions classify as metadata-only.
Tighter nullability/UTF-8 character limits and CHECK validation require an
existing-row validation scan while preserving physical row indexes. A changed
physical type, codec, comparison or key layout requires a phased rewrite on a
populated Table. These classifications are work requirements, not evidence that existing
rows passed. Adding a required field without a default may be valid for an empty
Table; transforming any existing row fails. Changing defaults affects subsequent
inserts/DEFAULT assignments, never earlier stored cells.

Row transformation selects preserved values by column ID and initializes only
new IDs. Type changes admit identical descriptors, checked signed/unsigned/
decimal conversions, integer-to-float and float-width conversions. All conversions
reject overflow and inexact rounding, including typed defaults. Text, temporal
and nested conversions between different descriptors reject. Key type changes
require index rebuilding. Tightened constraints validate every existing row.

Storage must freeze the source basis, process complete validation/rewrites with
bounded work, fence conflicting publication and atomically publish the successor
head. A pure transition does not perform these steps. Retained readers continue
to use their original schema; accepted operations cannot rebind to its successor.
The direct Table owner's validation scan uses its statement row/byte quotas and
one reused page arena. Exceeding a quota refuses activation. Ordinary ALTER does
not perform a synchronous physical rewrite of a populated Table. An empty current
root may adopt a new layout while retaining all earlier definitions and data cuts.

## Scalar SQL type-name resolver

`SqlTypes.resolve(name, parameters, zone)` is a pure name/parameter resolver.
Its availability does not widen SQL parser or native Table admission. Names
compare case-insensitively; multiword names use one ASCII space. Every alias
returns the same logical descriptor as its canonical spelling.

| Spellings | Result |
| --- | --- |
| INT8, TINYINT | int8 |
| INT16, SMALLINT | int16 |
| INT32, INT, INTEGER | int32 |
| INT64, BIGINT | int64 |
| INT128 | int128 |
| UINT8/16/32/64/128 | corresponding unsigned width |
| FLOAT32, REAL | float32 |
| FLOAT64, DOUBLE, DOUBLE PRECISION, FLOAT | float64 |
| BOOL, BOOLEAN | boolean |
| UTF8, TEXT, VARCHAR, CHARACTER VARYING | UTF-8 |
| BINARY, BLOB, BYTEA | binary |
| DECIMAL, NUMERIC | exact decimal |
| DATE, TIME, TIMESTAMP, TIMESTAMPTZ, INTERVAL, UUID, JSON | corresponding logical family |

INT8 always means eight bits, including under SQL alias resolution. PostgreSQL's
internal eight-byte alias is not imported. Numeric display widths reject.
VARCHAR(n)/CHARACTER VARYING(n) set a positive Unicode-scalar character limit;
without a parameter they are unbounded within row byte/work limits. TEXT/UTF8
parameters reject. CHAR/CHARACTER padding and BINARY(n)/VARBINARY length semantics
are unqualified and reject. FLOAT(p) rejects; FLOAT without p means float64.

DECIMAL/NUMERIC without parameters means (38,0), one parameter selects precision
with scale zero, and two select precision/scale. Precision is 1–38 and scale is
0–precision; binding/conversion is exact with no silent rounding.
TIME has nanosecond precision, admitting an explicit (9); TIMESTAMP has microsecond
precision, admitting an explicit (6). Other precisions reject rather than being
ignored. TIMESTAMP defaults to civil; WITH TIME ZONE selects UTC and WITHOUT TIME
ZONE selects civil. TIMESTAMPTZ means UTC and conflicts with WITHOUT TIME ZONE.
TIME WITHOUT TIME ZONE is admitted; TIME WITH TIME ZONE rejects. No named-zone,
calendar conversion, enum/domain/spatial or arbitrary-precision type is implied.

## Ownership

Borrowed schemas and assignment results retain their original owners. Decode
and clone return an arena owning names, nested descriptors and defaults, released
by `deinit`. A failed assignment invalidates scratch output and returns no
successful row. Validation, encoding and decoding perform no I/O or publication.

Neutral schema conversion checks each default's canonical payload against the
shared 64-KiB schema allowance before converting the next default. It retains at
most one individually bounded conversion beyond the remaining allowance.
Complete schema validation also counts descriptors and framing. A shared input
tree cannot postpone the aggregate check until every default is materialized.
