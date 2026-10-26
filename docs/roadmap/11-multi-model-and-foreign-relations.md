# 11. Multi-model and multi-format foreign relations

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Compose KV, Table, Document, Graph and external dataset formats using the
[`.tseg` codec and collation architecture](02-storage-and-query-performance.md),
[standards/semantic contracts](07-standards-and-catalogs.md) and
[declaration/dataflow lifecycle](09-sql-and-dataflows.md).

Use the shared object/definition identities, policy references and inspection
model from the [data lifecycle](01-declarative-data-lifecycle.md). Every
projection or foreign table must expose its schema, physical encoding, collation,
captured manifest basis, dependencies and 5-state completeness through the shared
reader/column-array boundary specified in
[#128](https://github.com/spoke-sh/transit/issues/128). Codec/collation correctness
belongs to [#118](https://github.com/spoke-sh/transit/issues/118); native
KV/Document persistence belongs to [#126](https://github.com/spoke-sh/transit/issues/126).
This milestone adds projections and actual foreign adapters, not another native
storage engine. This milestone receives typed `COPY`/import/export operations
from the dataflow owner and qualifies them with the actual adapters. Reuse
[transaction admission and outcomes](05-transactions-and-atomic-composition.md)
and the direct-ingestion protocol. Each format becomes executable only when its
adapter and caller path are qualified; external sources are not automatically
participants in a native atomic commit.

## Delivery sequence

Reuse [index identities, maintenance and coverage](08-indexing-and-access-paths.md)
for graph adjacency, admitted document projections, **segment-backed Full-Text
Search (BM25)** and **Vector / Hybrid Search**. Qualify each specialized
key/predicate, scoring/distance function and source-refresh profile; ordered index
support alone does not deliver inverted full-text, document-path or vector search
without the dedicated segment layouts and recall/exactness contracts below. External
statistics and indexes must match the captured manifest and comparison semantics.
Extend the [performance scorecard](10-data-structures-and-performance.md) with
actual foreign decoding, pruning, graph multiplicity, full-text/vector retrieval,
streaming CDC ingestion and import/export costs.

1. **Define explicit Document-to-SQL and richer multi-model projections with stable identities:**
   specify `missing`/`null`/`conflict`/`type_error` and arithmetic overflow
   behavior with no implicit conflict winner or silent default value.
2. **Map finite property graphs over existing resources:** lower fixed-pattern
   SQL/PGQ through graph-aware `Fuze` operators over `.tseg` adjacency/edge
   indexes, preserving parallel edges, self-loops, endpoint validity and
   multiplicity.
3. **Deliver native segment-backed Full-Text Search (BM25) and Vector / Hybrid Retrieval over Tables and Documents:**
   keep search and AI/agent retrieval inside Transit's data gravity, `SnapshotId`
   cuts, branches and `policy_epoch` governance rather than forcing exports to
   external search or vector engines:
   - **Inverted Full-Text Indexes (BM25):** build immutable inverted-index segments
     (tokenized term dictionaries, Roaring-bitmap/posting lists, positional/field
     weights and BM25 length-normalized scoring) over Table text columns and
     Document blocks, respecting declared collations/analyzers, `.tdel` deletion
     vectors and online snapshot-to-tail maintenance.
   - **Vector Similarity and Hybrid Search:** support fixed-dimension vector/embedding
     columns in `.tseg` with exact SIMD distance kernels (`L2`, cosine, inner
     product) and bounded disk-backed quantized/graph ANN index segments (such as
     DiskANN/HNSW with explicit exact-oracle recall reporting), composable with
     relational predicates, temporal `AS OF` cuts, security-barrier RLS and BM25
     lexical scores in a single hybrid query plan.
4. **Implement multi-format `FOREIGN TABLE` and `COPY` readers over POSIX and `TransitObjectStore` (S3/GCS/R2):**
   - **Analytical columnar formats (`PARQUET`, `ARROW_IPC`):** use qualified
     borrowed layouts or bounded decoding for column chunks/dictionaries, with
     row-group statistics (`min`/`max`/null count) driving sound pruning. Capture immutable
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
     `REDEFINES` variants with explicit selection and five-state interpretation.
     Allow foreign mainframe datasets to be queried in place or
     compacted into native `.tseg` segments while preserving source collation
     (`COLLATE EBCDIC_037_PAD`).
     Preserve layout/codepage/collation fingerprints and original-byte diagnostic
     provenance through read, materialization and export. A five-state tag alone
     does not establish lossless source preservation. Distinguish field-local
     conversion failures from unreadable/corrupt record framing; incomplete
     capture must not be published as a complete relation.
5. **Deliver typed import/export and continuous Change Data Capture (CDC) ingress:**
   support native `.tseg`, Parquet, Arrow IPC and CSV/JSONL transfer with explicit
   schemas, codecs, collations, five-state/error policy and bounded progress.
   Alongside batch `COPY`, provide governed **streaming CDC and logical-replication
   ingress adapters** (consuming external change envelopes such as PostgreSQL
   logical replication, MySQL binlog and Debezium/Kafka CDC streams) that apply
   ordered inserts, updates, deletes, schema-evolution checks and source
   watermarks into native Transit Tables with idempotent checkpoint recovery.
   Define import and CDC transaction scope, whole-operation versus watermark-committed
   publication, cancellation and original-operation recovery. Stage/verify data
   before atomic publication where promised; export bytes are external
   disclosure/effects and cannot be undone by database rollback. Qualify each
   actual format/direction.
6. **Extend maintained composition after independent finite verification:**
   include updates/deletes, graph changes, full-text/vector index catch-up,
   streaming CDC watermarks, captured foreign-manifest refresh and backfill.
   Completed source bases must equal finite recomputation.

## Completion evidence

Use independent relational, graph and mainframe-dataset oracles and current
source rights. Qualify changed or missing files/objects, ETag mismatches,
interrupted captures, corrupted `COMP-3` nibbles / `HIGH-VALUES` (`0xFF`) / space
padding (`0x40`) surfaced as `IS TYPE_ERROR`, EBCDIC-collated joins against
UTF-8 tables, lost acknowledgements, revocation after partial disclosure, invalid
graph endpoints and datasets exceeding resident RAM and NVMe caches.

Qualify a captured mainframe dataset through foreign query, native Table
materialization and export with independent byte/value oracles. Include
PAD/NO PAD behavior, mixed-collation resolution or rejection, malformed bytes,
REDEFINES selection, rounding/overflow and retained diagnostic provenance.
Document which physical layouts can be borrowed, decoded or operated on while
encoded; no format name alone promises universal zero-copy interoperability.

External writes remain separately activated recorded effects. Declarations do not
grant raw filesystem, network or backend access. Publish grammar, types, encodings,
collations, bounds and exclusions through consistent capability views across
shared interfaces.
