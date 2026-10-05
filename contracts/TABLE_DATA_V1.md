# General Table candidate data v1

This format composes pure general Table candidates over the
[Station immutable index](STATION_INDEX_V1.md). It does not define or admit a
native Table head, catalog lifecycle or transaction. The owner supplies current
authorization, frozen source identity, staging and atomic publication.

Each Table uses one index with unsigned lexicographic keys. Row keys are ASCII
`R` followed by the 20-byte big-endian row identity from
[Table schema v1](TABLE_SCHEMA_V1.md). Their values are immutable row-blob
references: u64 record ID, u32 format, u32 length and 32-byte Publication digest,
exactly 48 bytes. These reference integers are little-endian. Row format is
`0x54525701`; its complete payload is `FTR1` with the exact logical values and
physical layout fingerprint. The record ID is nonzero; length is bounded by the
Fuze row codec. The owning store supplies the fixed resource/namespace.

Primary-key keys are ASCII `K`, the 32-byte SHA-256 canonical equality-key digest,
then the 20-byte row identity. Their values are empty. Different row identities
retain distinct equal-digest candidates. Readers compare actual typed key values
before concluding equality; collisions never establish a constraint violation.
Unkeyed Tables have no `K` entries and permit duplicate payloads. A row's identity
does not change when its primary key changes.

Index node loads verify reference metadata and Publication commitments. Blob
loads verify their complete commitment, physical descriptor and row identity.
Missing records, malformed references or mismatched layouts reject. Source
errors are never converted into absent rows or successful empty scans.

Insert requires an unused row identity and, when declared, a unique typed key.
Update/delete return matched=0 and changed=0 for an absent row. Existing updates
return matched=1; changed=0 means canonical stored row bytes are identical and
stages no new record. Changed counts preserve representation differences such as
JSON whitespace and IEEE zero sign, independently of query operator support.
Updating a key replaces its index entry; updating another value leaves the key
entry unchanged. Delete removes both row and key entries from the successor.

Every result is a candidate root with counts. An owner must validate a complete
statement and atomically publish rows/indexes, schema/data head, terminal result
and input progress. Intermediate immutable pages are staging artifacts and do
not make a statement prefix visible. Failed builds retain old roots and may
leave unreachable records subject to explicit, reference-safe cleanup.

One index read is at most 4 KiB; one row is bounded by its logical codec. Traversal
holds one decoded collision/scan candidate at a time and releases it before the
next. Small encodings use 4 KiB scratch; larger encodings allocate only within
the row/key envelope bounds. Total Table size is not a resident-memory bound.
Owners enforce operation work/deployment quotas and source lifetime separately.
