# 4. Multi-model and multi-format foreign relations

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31)

Compose KV, Table, Document, Graph and external dataset formats using the
[`.tseg` codec and collation architecture](01-storage-and-query-performance.md),
[standards/semantic contracts](02-standards-and-catalogs.md) and
[declaration/dataflow lifecycle](03-sql-and-dataflows.md).

Use the shared object/definition identities, policy references and inspection
model from the [data lifecycle](../handbook/reference/data-model.md). Every
projection or foreign table must expose its schema, physical encoding, collation,
captured manifest basis, dependencies and 5-state completeness through the shared
`Fuze` `SegmentReader` boundary.

## Delivery sequence

1. **Define explicit Document-to-SQL and richer multi-model projections with stable identities:**
   specify `missing`/`null`/`conflict`/`type_error` and arithmetic overflow
   behavior with no implicit conflict winner or silent default value.
2. **Map finite property graphs over existing resources:** lower fixed-pattern
   SQL/PGQ through graph-aware `Fuze` operators over `.tseg` adjacency/edge
   indexes, preserving parallel edges, self-loops, endpoint validity and
   multiplicity.
3. **Implement multi-format `FOREIGN TABLE` and `COPY` readers over POSIX and `TransitObjectStore` (S3/GCS/R2):**
   - **Analytical columnar formats (`PARQUET`, `ARROW_IPC`):** map column chunks,
     dictionary pages and row-group statistics (`min`/`max`/null count) directly
     into `Fuze` `Batch.zig` vectors and zone-map pruning, capturing immutable
     file manifests (`ETag`/`SHA-256`, byte length, row count) for repeatable
     snapshot reads.
   - **Text and semi-structured formats (`CSV`, `JSONL`):** bounded streaming
     parsers that record malformed fields as `type_error` or `missing` cells
     rather than aborting scans.
   - **Enterprise & mainframe sequential datasets (`FIXED_RECORD` / `FB`, `VARIABLE_RECORD` / `VB` with 4-byte `RDW`):**
     declarative record and COBOL Copybook layouts supporting `EBCDIC` codepages
     (`CP037`, `CP1047`, `CP500`), `COMP-3` (BCD packed decimal), `ZONED`
     (overpunched zoned decimal), `COMP`/`COMP-4` (big-endian scaled binary),
     `IBM_HFP` (`COMP-1`/`COMP-2` hexadecimal float), fixed `OCCURS` arrays, and
     `REDEFINES` variants projected losslessly through 5-state `type_error` and
     `missing` tags. Allow foreign mainframe datasets to be queried in place or
     compacted into native `.tseg` segments while preserving source collation
     (`COLLATE EBCDIC_037_PAD`).
4. **Extend maintained composition after independent finite verification:**
   include updates/deletes, graph changes, captured foreign-manifest refresh and
   backfill. Completed source bases must equal finite recomputation.

## Completion evidence

Use independent relational, graph and mainframe-dataset oracles and current
source rights. Qualify changed or missing files/objects, ETag mismatches,
interrupted captures, corrupted `COMP-3` nibbles / `HIGH-VALUES` (`0xFF`) / space
padding (`0x40`) surfaced as `IS TYPE_ERROR`, EBCDIC-collated joins against
UTF-8 tables, lost acknowledgements, revocation after partial disclosure, invalid
graph endpoints and datasets exceeding resident RAM and NVMe caches.

External writes remain separately activated recorded effects. Declarations do not
grant raw filesystem, network or backend access. Publish grammar, types, encodings,
collations, bounds and exclusions through consistent capability views across
shared interfaces.
