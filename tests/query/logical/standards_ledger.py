#!/usr/bin/env python3
"""Independent verification of the machine-readable SQL standards, collation and codec ledger."""
from runner.paths import ROOT
import argparse
import hashlib
import json

LEDGER = ROOT / 'contracts/sql/standards-ledger.json'
ZIG_LEDGER = ROOT / 'packages/zig/transit-fuze/src/StandardsLedger.zig'
ZIG_TRAITS = ROOT / 'packages/zig/transit-fuze/src/OperatorTraits.zig'
DEFINITION = 'transit.sql.standards-ledger.v1.2026-10-30'
TRAITS_DEFINITION = 'transit.fuze.operator-traits.v1.2026-10-30'


def build_ledger():
    collations = [
        {
            'id': 'UCS_BASIC',
            'sql_spelling': 'UTF8_BINARY',
            'runtime_tag': 'utf8_binary',
            'pad_attribute': 'NO_PAD',
            'repertoire': 'UTF-8 scalar code points',
            'normalized_key_order_preserving': True,
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/Collation.zig',
            'states': {
                'parse': 'implemented',
                'lower': 'implemented',
                'execute': 'implemented',
                'recover': 'implemented',
                'transport': 'implemented',
            },
        },
        {
            'id': 'ASCII_CI',
            'sql_spelling': 'ASCII_CI',
            'runtime_tag': 'ascii_ci',
            'pad_attribute': 'NO_PAD',
            'repertoire': 'UTF-8 with ASCII A-Z folded to a-z and deterministic raw-byte tiebreaker',
            'normalized_key_order_preserving': True,
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/Collation.zig',
            'states': {
                'parse': 'implemented',
                'lower': 'implemented',
                'execute': 'implemented',
                'recover': 'implemented',
                'transport': 'implemented',
            },
        },
        {
            'id': 'EBCDIC_037_NOPAD',
            'sql_spelling': 'EBCDIC_CP037',
            'runtime_tag': 'ebcdic_cp037',
            'pad_attribute': 'NO_PAD',
            'repertoire': 'IBM CP037 (US/Canada EBCDIC) single-byte repertoire',
            'normalized_key_order_preserving': True,
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/Collation.zig',
            'states': {
                'parse': 'implemented',
                'lower': 'implemented',
                'execute': 'implemented',
                'recover': 'implemented',
                'transport': 'implemented',
            },
        },
        {
            'id': 'EBCDIC_037_PAD',
            'sql_spelling': 'EBCDIC_037_PAD',
            'runtime_tag': None,
            'pad_attribute': 'PAD_SPACE',
            'repertoire': 'IBM CP037 (US/Canada EBCDIC) with trailing space padding normalization',
            'normalized_key_order_preserving': True,
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/Collation.zig',
            'states': {
                'parse': 'implemented',
                'lower': 'implemented',
                'execute': 'staged',
                'recover': 'staged',
                'transport': 'staged',
            },
        },
        {
            'id': 'EBCDIC_1047_NOPAD',
            'sql_spelling': 'EBCDIC_1047_NOPAD',
            'runtime_tag': None,
            'pad_attribute': 'NO_PAD',
            'repertoire': 'IBM CP1047 (z/OS UNIX System Services / Open Systems EBCDIC)',
            'normalized_key_order_preserving': True,
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/Collation.zig',
            'states': {
                'parse': 'implemented',
                'lower': 'implemented',
                'execute': 'staged',
                'recover': 'staged',
                'transport': 'staged',
            },
        },
        {
            'id': 'UCA_V15_1',
            'sql_spelling': 'ICU_ROOT',
            'runtime_tag': 'icu_root',
            'pad_attribute': 'NO_PAD',
            'repertoire': 'Unicode Standard v15.1 Default Unicode Collation Element Table (CLDR root)',
            'normalized_key_order_preserving': False,
            'zone_map_pruning_sound': False,
            'owner': 'packages/zig/transit-fuze/src/Collation.zig',
            'states': {
                'parse': 'rejected',
                'lower': 'rejected',
                'execute': 'rejected',
                'recover': 'rejected',
                'transport': 'rejected',
            },
        },
    ]

    physical_codecs = [
        {
            'id': 'PLAIN',
            'encoding': 'plain',
            'logical_families': ['boolean', 'int8..int128', 'uint8..uint128', 'float32', 'float64', 'decimal', 'date', 'time', 'timestamp', 'interval', 'uuid', 'utf8', 'binary', 'range', 'multirange', 'vector'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'BITPACKED',
            'encoding': 'bitpacked',
            'logical_families': ['boolean', 'int8..int64', 'uint8..uint64', 'date', 'time', 'timestamp'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'RLE',
            'encoding': 'rle',
            'logical_families': ['boolean', 'int8..int64', 'uint8..uint64', 'date', 'time', 'timestamp', 'utf8', 'binary'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'DICTIONARY',
            'encoding': 'dictionary',
            'logical_families': ['utf8', 'binary', 'int64', 'uint64', 'uuid'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'FSST',
            'encoding': 'fsst',
            'logical_families': ['utf8', 'binary'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'COMP',
            'encoding': 'comp',
            'logical_families': ['int16', 'int32', 'int64', 'decimal'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'COMP_3',
            'encoding': 'comp_3',
            'logical_families': ['int64', 'int128', 'decimal'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'ZONED',
            'encoding': 'zoned',
            'logical_families': ['int64', 'int128', 'decimal'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'IBM_HFP',
            'encoding': 'ibm_hfp',
            'logical_families': ['float32', 'float64', 'decimal'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'EBCDIC',
            'encoding': 'ebcdic',
            'logical_families': ['utf8'],
            'invalid_payload_cell_state': 'type_error',
            'zone_map_pruning_sound': True,
            'owner': 'packages/zig/transit-fuze/src/PhysicalCodecs.zig',
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
    ]

    features = [
        {
            'id': 'E021-E051',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §4.2-4.6',
            'title': 'Core scalar types, exact numeric DECIMAL, and character collations',
            'owner': 'packages/zig/transit-fuze/src/Types.zig',
            'dependencies': ['UCS_BASIC'],
            'deviations': 'No implicit lossy casts; checked int64/decimal overflow and explicit kappa_numeric rounding rules.',
            'corpus_sources': ['contracts/sql/corpus/statements.json', 'contracts/sql/corpus/parameters.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'F031-F034',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §11.3-11.36',
            'title': 'Basic schema manipulation: CREATE TABLE, ALTER TABLE, DROP TABLE',
            'owner': 'packages/zig/transit-fuze/src/TableDdl.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Separates O(1) lazy metadata/projection ALTER TABLE evolutions from online phased physical rewrites.',
            'corpus_sources': ['contracts/sql/corpus/declarations.json', 'contracts/sql/corpus/mutations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'F491',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §11.6-11.9',
            'title': 'Constraint management: deterministic row-level CHECK constraints',
            'owner': 'packages/zig/transit-fuze/src/TableSchema.zig',
            'dependencies': ['F031-F034'],
            'deviations': "Evaluated under Transit's 5-state cell algebra: true and null pass; false, missing, type_error, and conflict reject.",
            'corpus_sources': ['contracts/sql/corpus/declarations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'F492',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §11.8',
            'title': 'Declarative referential integrity: FOREIGN KEY ... REFERENCES with RESTRICT, NO ACTION, CASCADE, SET NULL',
            'owner': 'packages/zig/transit-catalog/src/DirectCatalogDependencies.zig',
            'dependencies': ['F031-F034'],
            'deviations': 'Binds stable (Object, DefinitionId, ColumnId) edges in DirectCatalogDependencies; gates runtime write enforcement on Milestone 11 index-backed enforcer.',
            'corpus_sources': ['contracts/sql/corpus/declarations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'F111',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §17',
            'title': 'Transaction isolation and savepoints: BEGIN, COMMIT, ROLLBACK, SAVEPOINT',
            'owner': 'packages/zig/transit-sql/src/TransactionSql.zig',
            'dependencies': ['F031-F034'],
            'deviations': 'Admits SERIALIZABLE and READ ONLY common cuts; rejects weaker isolation levels.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'T181-X003',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §AS-OF',
            'title': 'Manifest-backed historical queries (AS OF SNAPSHOT, AS OF MANIFEST, FOR SYSTEM_TIME AS OF) and PROJECTING TO',
            'owner': 'packages/zig/transit-catalog/src/DirectCatalog.zig',
            'dependencies': ['F031-F034', 'UCS_BASIC', 'EBCDIC_037_NOPAD'],
            'deviations': 'Binds immutable CatalogCut before name resolution while checking authorization against current policy_epoch.',
            'corpus_sources': ['contracts/sql/corpus/statements.json', 'contracts/sql/corpus/relational.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X001-RANGE',
            'standard': 'transit_extension_v1',
            'edition_clause': 'FUZE_TYPES_V1 §RANGE',
            'title': 'Canonical RANGE<T> and MULTIRANGE<T> intervals with Allen interval predicates (&&, @>, <@, -|-)',
            'owner': 'packages/zig/transit-fuze/src/Range.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Discrete domains canonicalize to half-open [lower, upper); MULTIRANGE stores sorted non-overlapping runs.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X002-VECTOR',
            'standard': 'iso_sql_2023_mda',
            'edition_clause': 'FUZE_TYPES_V1 §VECTOR',
            'title': 'Unboxed dense numeric vectors VECTOR(dim, elem_type) and distance metrics (L2_SQUARED, COSINE, DOT_PRODUCT, HAMMING)',
            'owner': 'packages/zig/transit-fuze/src/VectorMetric.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Stored as 64B-aligned unboxed SIMD slabs distinct from 5-state recursive ARRAY cells.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'G001-PGQ',
            'standard': 'iso_sql_2023_pgq',
            'edition_clause': 'ISO/IEC 9075-16:2023 §11-14',
            'title': 'SQL/PGQ CREATE PROPERTY GRAPH catalog descriptors and vertex/edge table bindings',
            'owner': 'packages/zig/transit-catalog/src/DirectCatalogRecords.zig',
            'dependencies': ['F031-F034', 'F492'],
            'deviations': 'Catalog descriptors bind by (Object, DefinitionId, ColumnId); cyclic WCOJ and GRAPH_TABLE execution land in Milestone 18.',
            'corpus_sources': ['contracts/sql/corpus/declarations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'staged', 'recover': 'staged', 'transport': 'staged'},
        },
        {
            'id': 'M001-MED',
            'standard': 'iso_sql_2023_med',
            'edition_clause': 'ISO/IEC 9075-9:2023 §11',
            'title': 'SQL/MED CREATE FOREIGN TABLE catalog descriptors and mainframe copybook codec bindings',
            'owner': 'packages/zig/transit-catalog/src/DirectCatalogRecords.zig',
            'dependencies': ['COMP', 'COMP_3', 'ZONED', 'IBM_HFP', 'EBCDIC'],
            'deviations': 'Binds immutable captured manifests and mainframe physical codecs; foreign scan execution lands in Milestone 18.',
            'corpus_sources': ['contracts/sql/corpus/declarations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'staged', 'recover': 'staged', 'transport': 'staged'},
        },
        {
            'id': 'X004-GERMAN-STRING',
            'standard': 'transit_extension_v1',
            'edition_clause': 'FUZE_TYPES_V1 §GERMAN_STRING',
            'title': '16B collation-prefixed GermanString vectors, comptime/frozen PerfectHash, and compressed-domain .dictionary/.fsst predicates',
            'owner': 'packages/zig/transit-fuze/src/GermanString.zig',
            'dependencies': ['E021-E051', 'UCS_BASIC', 'ASCII_CI', 'EBCDIC_037_NOPAD', 'DICTIONARY', 'FSST'],
            'deviations': 'Inline <=12B collation weights; >12B payloads use generation-checked handles into 64B-padded StringArena.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X005-SEARCH-WAND',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §SEARCH',
            'title': 'Declarative text/span search (TSearchSegment), 256-doc Block-Max BM25 / WAND execution, and single-snapshot hybrid search',
            'owner': 'packages/zig/transit-fuze/src/VectorizedSearch.zig',
            'dependencies': ['X004-GERMAN-STRING', 'X002-VECTOR'],
            'deviations': 'Intersects 256-doc posting blocks with .tdel and visibility Roaring bitmasks before scoring; enforces 5-state eager failure frontier.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X006-EXPLAIN',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §EXPLAIN',
            'title': 'Zero-work EXPLAIN with operator read/mutate/capture/dispatch effects, 5-state rules, and work bounds',
            'owner': 'packages/zig/transit-fuze/src/OperatorTraits.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Guaranteed to acquire zero data pins, read zero .tseg segments, and mutate zero durable state.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'implemented'},
        },
        {
            'id': 'F401-JOIN',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §7.7-7.11',
            'title': 'Multi-way joins, OUTER/SEMI/ANTI/LATERAL joins, and Neumann-Kemper universal D-Join correlated subquery unnesting',
            'owner': 'packages/zig/transit-fuze/src/AnalyticalSql.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Lowers correlated subqueries algebraically via deduplicated domain D = delta(pi_corr(T_outer)) without O(N*M) nested-loop probes.',
            'corpus_sources': ['contracts/sql/corpus/relational.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'T611-WINDOW',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §7.15 & §6.10',
            'title': 'Window functions (OVER PARTITION BY ... ORDER BY ... ROWS/RANGE/GROUPS), ranking/navigation, and QUALIFY',
            'owner': 'packages/zig/transit-fuze/src/AnalyticalSql.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Preserves 5-state cell failure witnesses across window frames and enforces bounded Tier 2 NVMe spill quotas.',
            'corpus_sources': ['contracts/sql/corpus/relational.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'T121-RECURSIVE-CTE',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §7.17',
            'title': 'Common table expressions (WITH and cycle-checked budget-bounded WITH RECURSIVE) and set operations (UNION/INTERSECT/EXCEPT)',
            'owner': 'packages/zig/transit-fuze/src/AnalyticalSql.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Requires explicit iteration/row work bounds and deterministic cycle detection.',
            'corpus_sources': ['contracts/sql/corpus/relational.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X007-PERFECT-HASH-IN',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §PERFECT-HASH-IN',
            'title': 'Comptime keyword and plan-bound constant WHERE col IN (...) perfect-hash tables with 16-byte SIMD comparisons',
            'owner': 'packages/zig/transit-fuze/src/PerfectHashIn.zig',
            'dependencies': ['UCS_BASIC', 'ASCII_CI', 'EBCDIC_037_PAD'],
            'deviations': 'Evaluates 5-state IN / NOT IN semantics with 16B SIMD prefix probes under the column\'s declared collation profile.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X008-VECTOR-UDF',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §UDF',
            'title': 'Deterministic SQL expression macros and sandboxed in-engine vectorized Wasm UDFs over Batch columns',
            'owner': 'packages/zig/transit-fuze/src/VectorUdf.zig',
            'dependencies': ['E021-E051'],
            'deviations': 'Rejects ambient WASI/network/clock imports and executes in-engine with per-row instruction fuel and memory bounds (zero actor-mailbox hops).',
            'corpus_sources': ['contracts/sql/corpus/declarations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'T182-BITEMPORAL-AS-OF',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §BITEMPORAL',
            'title': 'Bitemporal SQL combining FOR SYSTEM_TIME AS OF with PERIOD FOR valid_time (RANGE<TIMESTAMPTZ>) and streaming AS OF JOIN',
            'owner': 'packages/zig/transit-fuze/src/BitemporalAndTvf.zig',
            'dependencies': ['T181-X003', 'X001-RANGE'],
            'deviations': 'Isolates historical decision cuts from post-facto backfills and exposes kinematic interpolation hooks for Milestone 17 4D TRAJECTORY.',
            'corpus_sources': ['contracts/sql/corpus/relational.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X009-CHANGES-STREAM-SLICE',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §TVF',
            'title': 'Side-effect-free CHANGES(table, ...) and STREAM_SLICE(stream, ...) table-valued functions',
            'owner': 'packages/zig/transit-fuze/src/BitemporalAndTvf.zig',
            'dependencies': ['T181-X003'],
            'deviations': 'Enforces current policy_epoch per batch and guarantees STREAM_SLICE never mutates CONSUME ... FROM consumer-group watermarks.',
            'corpus_sources': ['contracts/sql/corpus/statements.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'F312-MERGE',
            'standard': 'iso_sql_2023_foundation',
            'edition_clause': 'ISO/IEC 9075-2:2023 §15.14',
            'title': 'Transactional SQL MERGE INTO (WHEN MATCHED / WHEN NOT MATCHED) and prepared-plan invalidation',
            'owner': 'packages/zig/transit-fuze/src/BitemporalAndTvf.zig',
            'dependencies': ['F031-F034', 'F111'],
            'deviations': 'Rejects duplicate source row matches deterministically (error.MergeCardinalityViolation) and invalidates plans on DefinitionId or policy_epoch transitions.',
            'corpus_sources': ['contracts/sql/corpus/mutations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X011-DBSP-ZSET',
            'standard': 'transit_extension_v1',
            'edition_clause': 'TRANSIT_SQL_V1 §DBSP-ZSET',
            'title': 'Incremental DBSP Z-set operator algebra (+1/-1 weights), durable .tseg arrangements, and finite-oracle equivalence (A3)',
            'owner': 'packages/zig/transit-fuze/src/FuzeDelta.zig',
            'dependencies': ['E021-E051', 'F401-JOIN'],
            'deviations': 'Preserves reversible 5-state and checked-arithmetic overflow witnesses across retractions; spatial boundary Z-set operators hand off to Milestone 17.',
            'corpus_sources': ['contracts/sql/corpus/relational.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X010-DATAFLOW-LIFECYCLE',
            'standard': 'transit_extension_v1',
            'edition_clause': 'DATAFLOW_V1 §LIFECYCLE',
            'title': 'Five-state computation lifecycle (Published, Authorized, Active, Suspended, Retired), ACTIVATE/SUSPEND/RESUME/REFRESH/RETIRE DDL, and WAL-activated scheduling (T5, T8)',
            'owner': 'packages/zig/transit-catalog/src/ManagedDataflow.zig',
            'dependencies': ['F111', 'T181-X003', 'X011-DBSP-ZSET'],
            'deviations': 'Replaces boolean ENABLE/DISABLE with a 5-state machine, aligns multi-object changes to M5 Transaction.Cut (0x54584331), and fails closed if history was compacted during suspension.',
            'corpus_sources': ['contracts/sql/corpus/declarations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
        {
            'id': 'X012-CONTROL-POLICY-PLANE',
            'standard': 'transit_extension_v1',
            'edition_clause': 'CONTROL_POLICY_PLANE_V1 §1-7',
            'title': 'Enterprise OIDC/SCIM federation, bounded delegation (DLG1/APV1), declarative secrets (SEC1) & OAuth2/PKCE challenge dataflows, security-barrier RLS/masking (RLM1), GDPR crypto-shredding/purge (ERS1), WLM (WLM1), and EXPLAIN POLICY',
            'owner': 'packages/zig/transit-fuze/src/RlsAndMasking.zig',
            'dependencies': ['F111', 'T181-X003', 'X010-DATAFLOW-LIFECYCLE'],
            'deviations': 'Enforces RLS as a mandatory security barrier before user predicates or 5-state errors, requires both USAGE ON SECRET and URI SCOPE match, and forbids plaintext secret literals in durable SQL.',
            'corpus_sources': ['contracts/sql/corpus/declarations.json'],
            'states': {'parse': 'implemented', 'lower': 'implemented', 'execute': 'implemented', 'recover': 'implemented', 'transport': 'staged'},
        },
    ]

    operator_effects = {
        'definition': TRAITS_DEFINITION,
        'effect_dimensions': ['read', 'mutate', 'capture', 'dispatch'],
        'five_state_rules': [
            'preserves_all_states',
            'filters_to_true_only',
            'checked_aggregate',
            'check_constraint_true_or_null',
            'total_state_predicate',
        ],
        'change_modes': [
            'explanation_zero_work',
            'snapshot_finite',
            'append_only_stream',
            'retractable_zset',
            'atomic_mutation',
        ],
        'explain_invariants': {
            'acquires_data_pins': False,
            'reads_storage_segments': False,
            'mutates_durable_state': False,
        },
    }

    payload = {
        'version': 1,
        'definition': DEFINITION,
        'operator_traits': operator_effects,
        'collations': collations,
        'physical_codecs': physical_codecs,
        'features': features,
    }
    digest = hashlib.sha256(
        json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()
    ).hexdigest()
    return {**payload, 'sha256': digest}


def validate_consistency(ledger):
    zig_ledger_text = ZIG_LEDGER.read_text()
    zig_traits_text = ZIG_TRAITS.read_text()
    assert f'"{DEFINITION}"' in zig_ledger_text, 'StandardsLedger.zig definition mismatch'
    assert f'"{TRAITS_DEFINITION}"' in zig_traits_text, 'OperatorTraits.zig definition mismatch'
    for col in ledger['collations']:
        assert f'.id = "{col["id"]}"' in zig_ledger_text, col['id']
        assert f'.sql_spelling = "{col["sql_spelling"]}"' in zig_ledger_text, col['sql_spelling']
        assert (ROOT / col['owner']).is_file(), col['owner']
    for codec in ledger['physical_codecs']:
        assert f'.id = "{codec["id"]}"' in zig_ledger_text, codec['id']
        assert (ROOT / codec['owner']).is_file(), codec['owner']
    for feat in ledger['features']:
        assert f'.id = "{feat["id"]}"' in zig_ledger_text, feat['id']
        for corpus_path in feat['corpus_sources']:
            assert (ROOT / corpus_path).is_file(), corpus_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    ledger = build_ledger()
    validate_consistency(ledger)
    text = json.dumps(ledger, indent=2, ensure_ascii=False) + '\n'
    if args.write:
        LEDGER.write_text(text)
    elif not LEDGER.is_file() or LEDGER.read_text() != text:
        raise SystemExit('Standards ledger drifted; regenerate deliberately with --write')
    print(f'Standards ledger: {len(ledger["features"])} features, '
          f'{len(ledger["collations"])} collations and '
          f'{len(ledger["physical_codecs"])} physical codecs checked')


if __name__ == '__main__':
    main()
