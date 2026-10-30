//! Machine-readable standards, collation, and physical-codec capability ledger.
//! Separates `parse`, `lower`, `execute`, `recover`, and `transport` states so
//! parser grammar or offline compilation is never conflated with runtime support.
const std = @import("std");
const Collation = @import("Collation.zig").Collation;
const PhysicalCodecs = @import("PhysicalCodecs.zig");

pub const definition = "transit.sql.standards-ledger.v1.2026-10-30";

pub const StageState = enum(u8) {
    implemented = 1,
    staged = 2,
    reference_only = 3,
    rejected = 4,
};

pub const LifecycleStates = struct {
    parse: StageState,
    lower: StageState,
    execute: StageState,
    recover: StageState,
    transport: StageState,

    pub const full_implemented: LifecycleStates = .{
        .parse = .implemented,
        .lower = .implemented,
        .execute = .implemented,
        .recover = .implemented,
        .transport = .implemented,
    };

    pub const compile_and_local_execute: LifecycleStates = .{
        .parse = .implemented,
        .lower = .implemented,
        .execute = .implemented,
        .recover = .implemented,
        .transport = .staged,
    };

    pub const compile_only: LifecycleStates = .{
        .parse = .implemented,
        .lower = .implemented,
        .execute = .staged,
        .recover = .staged,
        .transport = .staged,
    };

    pub const grammar_only: LifecycleStates = .{
        .parse = .reference_only,
        .lower = .rejected,
        .execute = .rejected,
        .recover = .rejected,
        .transport = .rejected,
    };

    pub const explicitly_rejected: LifecycleStates = .{
        .parse = .rejected,
        .lower = .rejected,
        .execute = .rejected,
        .recover = .rejected,
        .transport = .rejected,
    };
};

pub const StandardFamily = enum(u8) {
    iso_sql_2023_foundation = 1,
    iso_sql_2023_json = 2,
    iso_sql_2023_pgq = 3,
    iso_sql_2023_med = 4,
    iso_sql_2023_mda = 5,
    transit_extension_v1 = 6,
};

pub const PadAttribute = enum(u8) {
    no_pad = 0,
    pad_space = 1,
};

pub const CollationDescriptor = struct {
    id: []const u8,
    sql_spelling: []const u8,
    runtime_tag: ?Collation,
    pad_attribute: PadAttribute,
    repertoire: []const u8,
    normalized_key_order_preserving: bool,
    zone_map_pruning_sound: bool,
    states: LifecycleStates,
    owner: []const u8,
};

pub const PhysicalCodecDescriptor = struct {
    id: []const u8,
    encoding: PhysicalCodecs.Encoding,
    logical_families: []const []const u8,
    invalid_payload_cell_state: []const u8,
    zone_map_pruning_sound: bool,
    states: LifecycleStates,
    owner: []const u8,
};

pub const FeatureDescriptor = struct {
    id: []const u8,
    standard: StandardFamily,
    edition_clause: []const u8,
    title: []const u8,
    owner: []const u8,
    dependencies: []const []const u8,
    deviations: []const u8,
    states: LifecycleStates,
};

pub const collations = [_]CollationDescriptor{
    .{
        .id = "UCS_BASIC",
        .sql_spelling = "UTF8_BINARY",
        .runtime_tag = .utf8_binary,
        .pad_attribute = .no_pad,
        .repertoire = "UTF-8 scalar code points",
        .normalized_key_order_preserving = true,
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/Collation.zig",
    },
    .{
        .id = "ASCII_CI",
        .sql_spelling = "ASCII_CI",
        .runtime_tag = .ascii_ci,
        .pad_attribute = .no_pad,
        .repertoire = "UTF-8 with ASCII A-Z folded to a-z and deterministic raw-byte tiebreaker",
        .normalized_key_order_preserving = true,
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/Collation.zig",
    },
    .{
        .id = "EBCDIC_037_NOPAD",
        .sql_spelling = "EBCDIC_CP037",
        .runtime_tag = .ebcdic_cp037,
        .pad_attribute = .no_pad,
        .repertoire = "IBM CP037 (US/Canada EBCDIC) single-byte repertoire",
        .normalized_key_order_preserving = true,
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/Collation.zig",
    },
    .{
        .id = "EBCDIC_037_PAD",
        .sql_spelling = "EBCDIC_037_PAD",
        .runtime_tag = null,
        .pad_attribute = .pad_space,
        .repertoire = "IBM CP037 (US/Canada EBCDIC) with trailing space padding normalization",
        .normalized_key_order_preserving = true,
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.compile_only,
        .owner = "packages/zig/transit-fuze/src/Collation.zig",
    },
    .{
        .id = "EBCDIC_1047_NOPAD",
        .sql_spelling = "EBCDIC_1047_NOPAD",
        .runtime_tag = null,
        .pad_attribute = .no_pad,
        .repertoire = "IBM CP1047 (z/OS UNIX System Services / Open Systems EBCDIC)",
        .normalized_key_order_preserving = true,
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.compile_only,
        .owner = "packages/zig/transit-fuze/src/Collation.zig",
    },
    .{
        .id = "UCA_V15_1",
        .sql_spelling = "ICU_ROOT",
        .runtime_tag = .icu_root,
        .pad_attribute = .no_pad,
        .repertoire = "Unicode Standard v15.1 Default Unicode Collation Element Table (CLDR root)",
        .normalized_key_order_preserving = false,
        .zone_map_pruning_sound = false,
        .states = LifecycleStates.explicitly_rejected,
        .owner = "packages/zig/transit-fuze/src/Collation.zig",
    },
};

pub const physical_codecs = [_]PhysicalCodecDescriptor{
    .{
        .id = "PLAIN",
        .encoding = .plain,
        .logical_families = &.{ "boolean", "int8..int128", "uint8..uint128", "float32", "float64", "decimal", "date", "time", "timestamp", "interval", "uuid", "utf8", "binary", "range", "multirange", "vector" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "BITPACKED",
        .encoding = .bitpacked,
        .logical_families = &.{ "boolean", "int8..int64", "uint8..uint64", "date", "time", "timestamp" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "RLE",
        .encoding = .rle,
        .logical_families = &.{ "boolean", "int8..int64", "uint8..uint64", "date", "time", "timestamp", "utf8", "binary" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "DICTIONARY",
        .encoding = .dictionary,
        .logical_families = &.{ "utf8", "binary", "int64", "uint64", "uuid" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "FSST",
        .encoding = .fsst,
        .logical_families = &.{ "utf8", "binary" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "COMP",
        .encoding = .comp,
        .logical_families = &.{ "int16", "int32", "int64", "decimal" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "COMP_3",
        .encoding = .comp_3,
        .logical_families = &.{ "int64", "int128", "decimal" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "ZONED",
        .encoding = .zoned,
        .logical_families = &.{ "int64", "int128", "decimal" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "IBM_HFP",
        .encoding = .ibm_hfp,
        .logical_families = &.{ "float32", "float64", "decimal" },
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
    .{
        .id = "EBCDIC",
        .encoding = .ebcdic,
        .logical_families = &.{"utf8"},
        .invalid_payload_cell_state = "type_error",
        .zone_map_pruning_sound = true,
        .states = LifecycleStates.full_implemented,
        .owner = "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    },
};

pub const features = [_]FeatureDescriptor{
    .{
        .id = "E021-E051",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §4.2-4.6",
        .title = "Core scalar types, exact numeric DECIMAL, and character collations",
        .owner = "packages/zig/transit-fuze/src/Types.zig",
        .dependencies = &.{"UCS_BASIC"},
        .deviations = "No implicit lossy casts; checked int64/decimal overflow and explicit kappa_numeric rounding rules.",
        .states = LifecycleStates.full_implemented,
    },
    .{
        .id = "F031-F034",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §11.3-11.36",
        .title = "Basic schema manipulation: CREATE TABLE, ALTER TABLE, DROP TABLE",
        .owner = "packages/zig/transit-fuze/src/TableDdl.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Separates O(1) lazy metadata/projection ALTER TABLE evolutions from online phased physical rewrites.",
        .states = LifecycleStates.full_implemented,
    },
    .{
        .id = "F491",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §11.6-11.9",
        .title = "Constraint management: deterministic row-level CHECK constraints",
        .owner = "packages/zig/transit-fuze/src/TableSchema.zig",
        .dependencies = &.{"F031-F034"},
        .deviations = "Evaluated under Transit's 5-state cell algebra: true and null pass; false, missing, type_error, and conflict reject.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "F492",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §11.8",
        .title = "Declarative referential integrity: FOREIGN KEY ... REFERENCES with RESTRICT, NO ACTION, CASCADE, SET NULL",
        .owner = "packages/zig/transit-catalog/src/DirectCatalogDependencies.zig",
        .dependencies = &.{"F031-F034"},
        .deviations = "Binds stable (Object, DefinitionId, ColumnId) edges in DirectCatalogDependencies; gates runtime write enforcement on Milestone 11 index-backed enforcer.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "F111",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §17",
        .title = "Transaction isolation and savepoints: BEGIN, COMMIT, ROLLBACK, SAVEPOINT",
        .owner = "packages/zig/transit-sql/src/TransactionSql.zig",
        .dependencies = &.{"F031-F034"},
        .deviations = "Admits SERIALIZABLE and READ ONLY common cuts; rejects weaker isolation levels.",
        .states = LifecycleStates.full_implemented,
    },
    .{
        .id = "T181-X003",
        .standard = .transit_extension_v1,
        .edition_clause = "TRANSIT_SQL_V1 §AS-OF",
        .title = "Manifest-backed historical queries (AS OF SNAPSHOT, AS OF MANIFEST, FOR SYSTEM_TIME AS OF) and PROJECTING TO",
        .owner = "packages/zig/transit-catalog/src/DirectCatalog.zig",
        .dependencies = &.{ "F031-F034", "UCS_BASIC", "EBCDIC_037_NOPAD" },
        .deviations = "Binds immutable CatalogCut before name resolution while checking authorization against current policy_epoch.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "X001-RANGE",
        .standard = .transit_extension_v1,
        .edition_clause = "FUZE_TYPES_V1 §RANGE",
        .title = "Canonical RANGE<T> and MULTIRANGE<T> intervals with Allen interval predicates (&&, @>, <@, -|-)",
        .owner = "packages/zig/transit-fuze/src/Range.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Discrete domains canonicalize to half-open [lower, upper); MULTIRANGE stores sorted non-overlapping runs.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "X002-VECTOR",
        .standard = .iso_sql_2023_mda,
        .edition_clause = "FUZE_TYPES_V1 §VECTOR",
        .title = "Unboxed dense numeric vectors VECTOR(dim, elem_type) and distance metrics (L2_SQUARED, COSINE, DOT_PRODUCT, HAMMING)",
        .owner = "packages/zig/transit-fuze/src/VectorMetric.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Stored as 64B-aligned unboxed SIMD slabs distinct from 5-state recursive ARRAY cells.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "G001-PGQ",
        .standard = .iso_sql_2023_pgq,
        .edition_clause = "ISO/IEC 9075-16:2023 §11-14",
        .title = "SQL/PGQ CREATE PROPERTY GRAPH catalog descriptors and vertex/edge table bindings",
        .owner = "packages/zig/transit-catalog/src/DirectCatalogRecords.zig",
        .dependencies = &.{ "F031-F034", "F492" },
        .deviations = "Catalog descriptors bind by (Object, DefinitionId, ColumnId); cyclic WCOJ and GRAPH_TABLE execution land in Milestone 18.",
        .states = LifecycleStates.compile_only,
    },
    .{
        .id = "M001-MED",
        .standard = .iso_sql_2023_med,
        .edition_clause = "ISO/IEC 9075-9:2023 §11",
        .title = "SQL/MED CREATE FOREIGN TABLE catalog descriptors and mainframe copybook codec bindings",
        .owner = "packages/zig/transit-catalog/src/DirectCatalogRecords.zig",
        .dependencies = &.{ "COMP", "COMP_3", "ZONED", "IBM_HFP", "EBCDIC" },
        .deviations = "Binds immutable captured manifests and mainframe physical codecs; foreign scan execution lands in Milestone 18.",
        .states = LifecycleStates.compile_only,
    },
    .{
        .id = "X004-GERMAN-STRING",
        .standard = .transit_extension_v1,
        .edition_clause = "FUZE_TYPES_V1 §GERMAN_STRING",
        .title = "16B collation-prefixed GermanString vectors, comptime/frozen PerfectHash, and compressed-domain .dictionary/.fsst predicates",
        .owner = "packages/zig/transit-fuze/src/GermanString.zig",
        .dependencies = &.{ "E021-E051", "UCS_BASIC", "ASCII_CI", "EBCDIC_037_NOPAD", "DICTIONARY", "FSST" },
        .deviations = "Inline <=12B collation weights; >12B payloads use generation-checked handles into 64B-padded StringArena.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "X005-SEARCH-WAND",
        .standard = .transit_extension_v1,
        .edition_clause = "TRANSIT_SQL_V1 §SEARCH",
        .title = "Declarative text/span search (TSearchSegment), 256-doc Block-Max BM25 / WAND execution, and single-snapshot hybrid search",
        .owner = "packages/zig/transit-fuze/src/VectorizedSearch.zig",
        .dependencies = &.{ "X004-GERMAN-STRING", "X002-VECTOR" },
        .deviations = "Intersects 256-doc posting blocks with .tdel and visibility Roaring bitmasks before scoring; enforces 5-state eager failure frontier.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "X006-EXPLAIN",
        .standard = .transit_extension_v1,
        .edition_clause = "TRANSIT_SQL_V1 §EXPLAIN",
        .title = "Zero-work EXPLAIN with operator read/mutate/capture/dispatch effects, 5-state rules, and work bounds",
        .owner = "packages/zig/transit-fuze/src/OperatorTraits.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Guaranteed to acquire zero data pins, read zero .tseg segments, and mutate zero durable state.",
        .states = LifecycleStates.full_implemented,
    },
    .{
        .id = "F401-JOIN",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §7.7-7.11",
        .title = "Multi-way joins, OUTER/SEMI/ANTI/LATERAL joins, and Neumann-Kemper universal D-Join correlated subquery unnesting",
        .owner = "packages/zig/transit-fuze/src/AnalyticalSql.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Lowers correlated subqueries algebraically via deduplicated domain D = delta(pi_corr(T_outer)) without O(N*M) nested-loop probes.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "T611-WINDOW",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §7.15 & §6.10",
        .title = "Window functions (OVER PARTITION BY ... ORDER BY ... ROWS/RANGE/GROUPS), ranking/navigation, and QUALIFY",
        .owner = "packages/zig/transit-fuze/src/AnalyticalSql.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Preserves 5-state cell failure witnesses across window frames and enforces bounded Tier 2 NVMe spill quotas.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "T121-RECURSIVE-CTE",
        .standard = .iso_sql_2023_foundation,
        .edition_clause = "ISO/IEC 9075-2:2023 §7.17",
        .title = "Common table expressions (WITH and cycle-checked budget-bounded WITH RECURSIVE) and set operations (UNION/INTERSECT/EXCEPT)",
        .owner = "packages/zig/transit-fuze/src/AnalyticalSql.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Requires explicit iteration/row work bounds and deterministic cycle detection.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "X007-PERFECT-HASH-IN",
        .standard = .transit_extension_v1,
        .edition_clause = "TRANSIT_SQL_V1 §PERFECT-HASH-IN",
        .title = "Comptime keyword and plan-bound constant WHERE col IN (...) perfect-hash tables with 16-byte SIMD comparisons",
        .owner = "packages/zig/transit-fuze/src/PerfectHashIn.zig",
        .dependencies = &.{ "UCS_BASIC", "ASCII_CI", "EBCDIC_037_PAD" },
        .deviations = "Evaluates 5-state IN / NOT IN semantics with 16B SIMD prefix probes under the column's declared collation profile.",
        .states = LifecycleStates.compile_and_local_execute,
    },
    .{
        .id = "X008-VECTOR-UDF",
        .standard = .transit_extension_v1,
        .edition_clause = "TRANSIT_SQL_V1 §UDF",
        .title = "Deterministic SQL expression macros and sandboxed in-engine vectorized Wasm UDFs over Batch columns",
        .owner = "packages/zig/transit-fuze/src/VectorUdf.zig",
        .dependencies = &.{"E021-E051"},
        .deviations = "Rejects ambient WASI/network/clock imports and executes in-engine with per-row instruction fuel and memory bounds (zero actor-mailbox hops).",
        .states = LifecycleStates.compile_and_local_execute,
    },
};

pub fn findCollation(id_or_spelling: []const u8) ?CollationDescriptor {
    for (collations) |desc| {
        if (std.ascii.eqlIgnoreCase(desc.id, id_or_spelling) or
            std.ascii.eqlIgnoreCase(desc.sql_spelling, id_or_spelling))
        {
            return desc;
        }
    }
    return null;
}

pub fn findPhysicalCodec(id: []const u8) ?PhysicalCodecDescriptor {
    for (physical_codecs) |desc| {
        if (std.ascii.eqlIgnoreCase(desc.id, id) or
            std.ascii.eqlIgnoreCase(@tagName(desc.encoding), id))
        {
            return desc;
        }
    }
    return null;
}

pub fn findFeature(id: []const u8) ?FeatureDescriptor {
    for (features) |desc| {
        if (std.ascii.eqlIgnoreCase(desc.id, id)) return desc;
    }
    return null;
}
