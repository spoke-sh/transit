//! Machine-readable standards, collation, and physical-codec capability ledger.
//! Separates `parse`, `lower`, `execute`, `recover`, and `transport` states so
//! parser grammar or offline compilation is never conflated with runtime support.
const std = @import("std");
const Collation = @import("Collation.zig").Collation;
const PhysicalCodecs = @import("PhysicalCodecs.zig");

pub const definition = "transit.sql.standards-ledger.v1.2026-11-01";

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
    corpus_sources: []const []const u8,
    states: LifecycleStates,
    /// Standards clause references are provenance, not a conformance rating.
    reference_verified: bool,
    profile: []const u8,
    evidence_sources: []const []const u8,
};

pub const CompilerCase = struct {
    id: []const u8,
    feature: []const u8,
    entrypoint: enum { table_ddl, table_ddl_catalog, relational_sql, inspection },
    sql: []const u8,
    accept: bool,
};

// Generated from the single neutral ledger. See tests/query/logical/standards_ledger.py.
pub const collations = @import("StandardsLedgerData.zig").collations;
pub const physical_codecs = @import("StandardsLedgerData.zig").physical_codecs;
pub const features = @import("StandardsLedgerData.zig").features;
pub const compiler_cases = @import("StandardsLedgerData.zig").compiler_cases;

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
