//! Manifest-backed historical catalog cuts (`manifest/v{N}`), conditional branch
//! head publication, historical `AS OF` name/definition resolution (`D1`),
//! explicit `PROJECTING TO` schema projection (`D2`), current `policy_epoch`
//! authorization with mid-stream batch revocation, retention expiry enforcement,
//! and versioned multi-model catalog descriptors (`ViewDescriptor`,
//! `PropertyGraphDescriptor`, and `ForeignTableDescriptor`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const Collation = fuze.Collation;
const DecimalArithmetic = fuze.DecimalArithmetic;
const TableConstraints = fuze.TableConstraints;
const TableEvolution = fuze.TableEvolution;
const TableSchemaProjection = fuze.TableSchemaProjection;
const PhysicalCodecs = fuze.PhysicalCodecs;

pub const ColumnCollationProfile = struct {
    column: s.ColumnId,
    profile: Collation.Profile,
};

pub const ZoneMapBound = struct {
    column: s.ColumnId,
    min_atom: v.Atom,
    max_atom: v.Atom,
};

pub const HistoricalRow = struct {
    cells: []const v.Cell,
};

pub const HistoricalSegment = struct {
    segment_id: u64,
    min_lsn: u64,
    max_lsn: u64,
    physical_schema: s.Schema,
    zone_maps: []const ZoneMapBound = &.{},
    rows: []const HistoricalRow = &.{},
};

pub fn filterInitialsForSegment(
    physical: s.Schema,
    logical: s.Schema,
    origins: []const TableSchemaProjection.Initial,
    out_buf: *[s.max_columns]TableSchemaProjection.Initial,
) []const TableSchemaProjection.Initial {
    var count: usize = 0;
    for (origins) |init| {
        const in_logical = if (logical.index(init.column)) |_| true else |_| false;
        const in_physical = if (physical.index(init.column)) |_| true else |_| false;
        if (in_logical and !in_physical) {
            out_buf[count] = init;
            count += 1;
        }
    }
    return out_buf[0..count];
}
pub const HistoricalTableBinding = struct {
    namespace: u64,
    name: []const u8,
    object: u64,
    revision: u64,
    schema: s.Schema,
    collation_profiles: []const ColumnCollationProfile = &.{},
    checks: []const TableConstraints.CheckConstraint = &.{},
    foreign_keys: []const TableConstraints.ForeignKeyConstraint = &.{},
    column_origins: []const TableSchemaProjection.Initial = &.{},
    segments: []const HistoricalSegment = &.{},

    pub fn validate(self: HistoricalTableBinding) !void {
        if (self.namespace == 0 or self.object == 0 or self.revision == 0) return error.InvalidHistoricalTableBinding;
        if (self.name.len == 0 or self.name.len > 63) return error.InvalidHistoricalTableName;
        if (self.schema.object != self.object or self.schema.revision != self.revision) return error.HistoricalSchemaIdentityMismatch;
        try self.schema.validate();
        for (self.collation_profiles) |cp| {
            _ = try self.schema.index(cp.column);
        }
        for (self.checks) |chk| {
            try chk.validate(self.schema);
        }
        for (self.segments) |seg| {
            if (seg.segment_id == 0 or seg.min_lsn == 0 or seg.max_lsn < seg.min_lsn) return error.InvalidHistoricalSegment;
            if (seg.physical_schema.object != self.object) return error.HistoricalSegmentObjectMismatch;
            try seg.physical_schema.validate();
            var init_buf: [s.max_columns]TableSchemaProjection.Initial = undefined;
            const seg_initials = filterInitialsForSegment(seg.physical_schema, self.schema, self.column_origins, &init_buf);
            _ = try TableSchemaProjection.init(seg.physical_schema, self.schema, seg_initials);
            for (seg.rows) |row| {
                if (row.cells.len != seg.physical_schema.columns.len) return error.InvalidHistoricalSegmentRowArity;
            }
        }
    }

    pub fn profileForColumn(self: HistoricalTableBinding, column_id: s.ColumnId) !Collation.Profile {
        for (self.collation_profiles) |cp| {
            if (cp.column == column_id) return cp.profile;
        }
        const idx = try self.schema.index(column_id);
        return Collation.Profile.fromCollation(self.schema.columns[idx].collation);
    }

    pub fn segmentProjectionSummary(
        self: HistoricalTableBinding,
        target_schema: s.Schema,
        target_origins: []const TableSchemaProjection.Initial,
    ) !TableConstraints.SegmentProjectionSummary {
        var summary: TableConstraints.SegmentProjectionSummary = .{
            .target_object = target_schema.object,
            .target_revision = target_schema.revision,
            .total_segments = 0,
            .native_target_segments = 0,
            .lazily_projected_segments = 0,
            .synthesized_default_columns = 0,
            .omitted_dropped_columns = 0,
            .total_rows = 0,
            .lazily_projected_rows = 0,
        };
        // One segment's bounded projection scratch, independent of retained cardinality.
        var initials: [s.max_columns]TableSchemaProjection.Initial = undefined;
        for (self.segments) |seg| {
            const descriptor: TableConstraints.SegmentDescriptor = .{
                .segment_id = seg.segment_id,
                .physical_schema = seg.physical_schema,
                .initials = filterInitialsForSegment(seg.physical_schema, target_schema, target_origins, &initials),
                .row_count = seg.rows.len,
            };
            const part = try TableConstraints.inspectSegmentProjectionCoverage(&.{descriptor}, target_schema);
            summary.total_segments = try std.math.add(u32, summary.total_segments, 1);
            summary.native_target_segments = try std.math.add(u32, summary.native_target_segments, part.native_target_segments);
            summary.lazily_projected_segments = try std.math.add(u32, summary.lazily_projected_segments, part.lazily_projected_segments);
            summary.total_rows = try std.math.add(u64, summary.total_rows, part.total_rows);
            summary.lazily_projected_rows = try std.math.add(u64, summary.lazily_projected_rows, part.lazily_projected_rows);
            summary.synthesized_default_columns = @max(summary.synthesized_default_columns, part.synthesized_default_columns);
            summary.omitted_dropped_columns = @max(summary.omitted_dropped_columns, part.omitted_dropped_columns);
        }
        return summary;
    }
};

pub const DependencyColumnBinding = struct {
    source_object: u64,
    source_revision: u64,
    columns: []const s.ColumnId,
};

pub const ViewDescriptor = struct {
    object: u64,
    revision: u64,
    namespace: u64,
    name: []const u8,
    canonical_sql: []const u8,
    dependencies: []const DependencyColumnBinding,
    security_invoker: bool = true,

    pub fn validate(self: ViewDescriptor, tables: []const HistoricalTableBinding) !void {
        if (self.object == 0 or self.revision == 0 or self.namespace == 0) return error.InvalidViewDescriptor;
        if (self.name.len == 0 or self.name.len > 63 or self.canonical_sql.len == 0) return error.InvalidViewDescriptor;
        if (!self.security_invoker) return error.SecurityDefinerViewsUnsupported;
        if (self.dependencies.len == 0) return error.ViewRequiresDependencies;
        for (self.dependencies) |dep| {
            if (dep.columns.len == 0) return error.ViewDependencyMissingColumns;
            const tbl = findTableByObject(tables, dep.source_object) orelse return error.ViewDependencyTableNotFound;
            if (tbl.revision != dep.source_revision) return error.ViewDependencyRevisionMismatch;
            for (dep.columns) |col_id| {
                _ = try tbl.schema.index(col_id);
            }
        }
    }

    pub fn referencesColumn(self: ViewDescriptor, source_object: u64, column_id: s.ColumnId) bool {
        for (self.dependencies) |dep| {
            if (dep.source_object == source_object) {
                if (std.mem.indexOfScalar(s.ColumnId, dep.columns, column_id) != null) return true;
            }
        }
        return false;
    }
};

pub const VertexTableBinding = struct {
    table_object: u64,
    table_revision: u64,
    key_columns: []const s.ColumnId,
    label: []const u8,
    exposed_properties: []const s.ColumnId,
};

pub const EdgeTableBinding = struct {
    table_object: u64,
    table_revision: u64,
    key_columns: []const s.ColumnId,
    source_vertex_object: u64,
    source_key_columns: []const s.ColumnId,
    destination_vertex_object: u64,
    destination_key_columns: []const s.ColumnId,
    label: []const u8,
    exposed_properties: []const s.ColumnId,
};

/// SQL:2023 Part 16 (SQL/PGQ) `CREATE PROPERTY GRAPH` catalog descriptor bound
/// to immutable `(Object, Revision, ColumnId)` identities.
pub const PropertyGraphDescriptor = struct {
    object: u64,
    revision: u64,
    namespace: u64,
    name: []const u8,
    vertex_tables: []const VertexTableBinding,
    edge_tables: []const EdgeTableBinding,

    pub fn validate(self: PropertyGraphDescriptor, tables: []const HistoricalTableBinding) !void {
        if (self.object == 0 or self.revision == 0 or self.namespace == 0) return error.InvalidPropertyGraphDescriptor;
        if (self.name.len == 0 or self.name.len > 63) return error.InvalidPropertyGraphDescriptor;
        if (self.vertex_tables.len == 0) return error.PropertyGraphRequiresVertexTables;

        for (self.vertex_tables) |vt| {
            if (vt.label.len == 0 or vt.key_columns.len == 0) return error.InvalidPropertyGraphVertexTable;
            const tbl = findTableByObject(tables, vt.table_object) orelse return error.PropertyGraphVertexTableNotFound;
            if (tbl.revision != vt.table_revision) return error.PropertyGraphVertexRevisionMismatch;
            for (vt.key_columns) |col_id| _ = try tbl.schema.index(col_id);
            for (vt.exposed_properties) |col_id| _ = try tbl.schema.index(col_id);
        }

        for (self.edge_tables) |et| {
            if (et.label.len == 0 or et.key_columns.len == 0) return error.InvalidPropertyGraphEdgeTable;
            const edge_tbl = findTableByObject(tables, et.table_object) orelse return error.PropertyGraphEdgeTableNotFound;
            if (edge_tbl.revision != et.table_revision) return error.PropertyGraphEdgeRevisionMismatch;
            for (et.key_columns) |col_id| _ = try edge_tbl.schema.index(col_id);
            for (et.exposed_properties) |col_id| _ = try edge_tbl.schema.index(col_id);

            const src_vt = self.findVertex(et.source_vertex_object) orelse return error.PropertyGraphEndpointVertexNotFound;
            const dst_vt = self.findVertex(et.destination_vertex_object) orelse return error.PropertyGraphEndpointVertexNotFound;
            const src_tbl = findTableByObject(tables, src_vt.table_object).?;
            const dst_tbl = findTableByObject(tables, dst_vt.table_object).?;

            try validateEndpointKeyMatch(edge_tbl.schema, et.source_key_columns, src_tbl.schema, src_vt.key_columns);
            try validateEndpointKeyMatch(edge_tbl.schema, et.destination_key_columns, dst_tbl.schema, dst_vt.key_columns);
        }
    }

    fn findVertex(self: PropertyGraphDescriptor, vertex_table_object: u64) ?VertexTableBinding {
        for (self.vertex_tables) |vt| {
            if (vt.table_object == vertex_table_object) return vt;
        }
        return null;
    }

    pub fn referencesColumn(self: PropertyGraphDescriptor, table_object: u64, column_id: s.ColumnId) bool {
        for (self.vertex_tables) |vt| {
            if (vt.table_object == table_object) {
                if (std.mem.indexOfScalar(s.ColumnId, vt.key_columns, column_id) != null) return true;
                if (std.mem.indexOfScalar(s.ColumnId, vt.exposed_properties, column_id) != null) return true;
            }
        }
        for (self.edge_tables) |et| {
            if (et.table_object == table_object) {
                if (std.mem.indexOfScalar(s.ColumnId, et.key_columns, column_id) != null) return true;
                if (std.mem.indexOfScalar(s.ColumnId, et.source_key_columns, column_id) != null) return true;
                if (std.mem.indexOfScalar(s.ColumnId, et.destination_key_columns, column_id) != null) return true;
                if (std.mem.indexOfScalar(s.ColumnId, et.exposed_properties, column_id) != null) return true;
            }
        }
        return false;
    }

    /// Milestone 18 handoff gate: `GRAPH_TABLE` runtime pattern matching is deferred to M18.
    pub fn checkGraphTableExecutionAdmission(_: PropertyGraphDescriptor) !void {
        return error.SqlPgqExecutionDeferredToM18;
    }
};

fn validateEndpointKeyMatch(
    edge_schema: s.Schema,
    edge_cols: []const s.ColumnId,
    vertex_schema: s.Schema,
    vertex_cols: []const s.ColumnId,
) !void {
    if (edge_cols.len == 0 or edge_cols.len != vertex_cols.len) return error.PropertyGraphEndpointKeyArityMismatch;
    for (edge_cols, vertex_cols) |e_id, v_id| {
        const e_col = edge_schema.columns[try edge_schema.index(e_id)];
        const v_col = vertex_schema.columns[try vertex_schema.index(v_id)];
        if (!try e_col.type.eql(v_col.type) or e_col.collation != v_col.collation) {
            return error.PropertyGraphEndpointKeyTypeMismatch;
        }
    }
}

pub const MainframeCodecKind = enum(u8) {
    comp3 = 1,
    zoned = 2,
    comp4_be = 3,
    ibm_hfp = 4,
    ebcdic = 5,
};

pub const MainframeColumnLayout = struct {
    column: s.ColumnId,
    codec: MainframeCodecKind,
    collation_profile: Collation.Profile = .none,
    byte_offset: u32,
    byte_length: u32,
};

/// SQL/MED (`ISO/IEC 9075-9`) `CREATE SERVER` and `CREATE FOREIGN TABLE` catalog
/// descriptor preserving mainframe physical codecs ($\epsilon$) and EBCDIC collations ($\kappa$).
pub const ForeignTableDescriptor = struct {
    server_object: u64,
    server_name: []const u8,
    wrapper_name: []const u8,
    object: u64,
    revision: u64,
    namespace: u64,
    name: []const u8,
    schema: s.Schema,
    record_byte_length: u32,
    mainframe_columns: []const MainframeColumnLayout,

    pub fn validate(self: ForeignTableDescriptor) !void {
        if (self.server_object == 0 or self.object == 0 or self.revision == 0 or self.namespace == 0) {
            return error.InvalidForeignTableDescriptor;
        }
        if (self.server_name.len == 0 or self.wrapper_name.len == 0 or self.name.len == 0) {
            return error.InvalidForeignTableDescriptor;
        }
        if (self.schema.object != self.object or self.schema.revision != self.revision) {
            return error.ForeignTableSchemaIdentityMismatch;
        }
        try self.schema.validate();
        if (self.mainframe_columns.len != self.schema.columns.len) return error.ForeignTableLayoutColumnMismatch;
        var expected_offset: u32 = 0;
        for (self.mainframe_columns) |layout| {
            const idx = try self.schema.index(layout.column);
            const col = self.schema.columns[idx];
            if (layout.byte_length == 0 or layout.byte_offset != expected_offset) {
                return error.InvalidMainframeRecordLayout;
            }
            expected_offset = try std.math.add(u32, expected_offset, layout.byte_length);
            switch (layout.codec) {
                .comp3, .zoned => switch (col.type) {
                    .decimal, .int64 => {},
                    else => return error.IncompatibleMainframeCodecType,
                },
                .comp4_be => switch (col.type) {
                    .int16, .int32, .int64 => {},
                    else => return error.IncompatibleMainframeCodecType,
                },
                .ibm_hfp => switch (col.type) {
                    .float64 => {},
                    else => return error.IncompatibleMainframeCodecType,
                },
                .ebcdic => switch (col.type) {
                    .utf8 => {
                        if (layout.collation_profile != .ebcdic_037_pad and layout.collation_profile != .ebcdic_1047_nopad) {
                            return error.MainframeEbcdicRequiresCollationProfile;
                        }
                    },
                    else => return error.IncompatibleMainframeCodecType,
                },
            }
        }
        if (expected_offset != self.record_byte_length) return error.InvalidMainframeRecordLayout;
    }

    /// Milestone 18 handoff gate: runtime foreign scan pushdown is deferred to M18.
    pub fn checkForeignScanAdmission(_: ForeignTableDescriptor) !void {
        return error.SqlMedScanDeferredToM18;
    }
};

/// Verify that a base-table `ALTER` or `DROP` change does not break any active
/// `ViewDescriptor` or `PropertyGraphDescriptor` in the catalog cut.
pub fn validateChangeAgainstMultiModel(
    table_object: u64,
    change: TableEvolution.Change,
    views: []const ViewDescriptor,
    graphs: []const PropertyGraphDescriptor,
) !void {
    const affected_column: ?s.ColumnId = switch (change) {
        .drop => |col_id| col_id,
        .type => |edit| edit.column,
        .physical => |edit| edit.column,
        .add, .rename, .default, .nullable => null,
    };
    if (affected_column) |col_id| {
        for (views) |vw| {
            if (vw.referencesColumn(table_object, col_id)) return error.ColumnReferencedByView;
        }
        for (graphs) |pg| {
            if (pg.referencesColumn(table_object, col_id)) return error.ColumnReferencedByPropertyGraph;
        }
    }
}

pub const ManifestCut = struct {
    manifest_version: u64,
    commit_lsn: u64,
    branch_id: u64 = 1,
    branch_name: []const u8 = "main",
    tzdb: DecimalArithmetic.TzdbVersion,
    previous_manifest_digest: [32]u8 = @splat(0),
    tables: []const HistoricalTableBinding,
    views: []const ViewDescriptor = &.{},
    property_graphs: []const PropertyGraphDescriptor = &.{},
    foreign_tables: []const ForeignTableDescriptor = &.{},

    pub fn validate(self: ManifestCut) !void {
        if (self.manifest_version == 0 or self.commit_lsn == 0 or self.branch_id == 0 or self.branch_name.len == 0) {
            return error.InvalidManifestCut;
        }
        try self.tzdb.validate();
        for (self.tables, 0..) |tbl, i| {
            try tbl.validate();
            for (self.tables[0..i]) |prev| {
                if (prev.namespace == tbl.namespace and std.mem.eql(u8, prev.name, tbl.name)) {
                    return error.DuplicateHistoricalTableName;
                }
                if (prev.object == tbl.object) {
                    return error.DuplicateHistoricalTableObject;
                }
            }
            for (tbl.foreign_keys) |fk| {
                const parent = findTableByObject(self.tables, fk.target_object) orelse return error.ForeignKeyTargetNotFound;
                if (parent.revision != fk.target_revision) return error.ForeignKeyTargetRevisionMismatch;
                try fk.validateAgainstSchemas(tbl.schema, parent.schema);
            }
        }
        for (self.views) |vw| try vw.validate(self.tables);
        for (self.property_graphs) |pg| try pg.validate(self.tables);
        for (self.foreign_tables) |ft| try ft.validate();
    }

    pub fn digest(self: ManifestCut) ![32]u8 {
        try self.validate();
        var scratch: [1024]u8 = undefined;
        var hash: std.Io.Writer.Hashing(std.crypto.hash.sha2.Sha256) = .init(&scratch);
        hash.hasher.update("transit.catalog.manifest.v1.2026-10-30.complete\x00");
        // Include every interpreted field, including segment data and metadata
        // outside TableSchema. JSON provides length/tag boundaries; pointers
        // and slice addresses never participate in this commitment.
        var encoder: std.json.Stringify = .{ .writer = &hash.writer };
        try c.protocol.Json.write(self, &encoder);
        try hash.writer.flush();
        return hash.hasher.finalResult();
    }
};

pub fn findTableByObject(tables: []const HistoricalTableBinding, object: u64) ?HistoricalTableBinding {
    for (tables) |tbl| {
        if (tbl.object == object) return tbl;
    }
    return null;
}

pub fn findTableByName(tables: []const HistoricalTableBinding, namespace: u64, name: []const u8) ?HistoricalTableBinding {
    for (tables) |tbl| {
        if (tbl.namespace == namespace and std.mem.eql(u8, tbl.name, name)) return tbl;
    }
    return null;
}

pub const BranchHead = struct {
    branch_id: u64,
    branch_name: []const u8,
    manifest_version: u64,
    commit_lsn: u64,
    manifest_digest: [32]u8,
};

pub const HistoricalTimeline = struct {
    cuts: []const ManifestCut,
    head: BranchHead,
    min_retained_manifest_version: u64 = 1,
    min_retained_lsn: u64 = 1,

    pub fn init(cuts: []const ManifestCut) !HistoricalTimeline {
        if (cuts.len == 0) return error.EmptyHistoricalTimeline;
        var prev_digest: [32]u8 = @splat(0);
        for (cuts, 0..) |cut, i| {
            if (cut.manifest_version != i + 1) return error.NonContiguousManifestVersion;
            if (i > 0 and cut.commit_lsn <= cuts[i - 1].commit_lsn) return error.NonMonotonicManifestLsn;
            if (!std.mem.eql(u8, &cut.previous_manifest_digest, &prev_digest)) return error.BrokenManifestDigestChain;
            prev_digest = try cut.digest();
        }
        const latest = cuts[cuts.len - 1];
        return .{
            .cuts = cuts,
            .head = .{
                .branch_id = latest.branch_id,
                .branch_name = latest.branch_name,
                .manifest_version = latest.manifest_version,
                .commit_lsn = latest.commit_lsn,
                .manifest_digest = prev_digest,
            },
        };
    }

    /// Pure conditional successor over caller-owned immutable cuts. The caller
    /// supplies the complete retained successor history and keeps it alive.
    /// This helper performs no durable publication or synchronization.
    pub fn publishHeadConditional(
        self: *HistoricalTimeline,
        expected_manifest_version: u64,
        next_cuts: []const ManifestCut,
    ) !BranchHead {
        if (self.head.manifest_version != expected_manifest_version) return error.ConditionalBranchHeadConflict;
        if (next_cuts.len != try std.math.add(usize, self.cuts.len, 1)) return error.InvalidNextManifestVersion;
        for (self.cuts, next_cuts[0..self.cuts.len]) |before, after| {
            if (!std.mem.eql(u8, &(try before.digest()), &(try after.digest()))) return error.BrokenManifestDigestChain;
        }
        const next_cut = next_cuts[next_cuts.len - 1];
        if (!std.mem.eql(u8, next_cut.branch_name, self.head.branch_name) or next_cut.branch_id != self.head.branch_id) {
            return error.MultiCommitBranchingDeferredToM19;
        }
        if (self.head.manifest_version != expected_manifest_version) {
            return error.ConditionalBranchHeadConflict;
        }
        if (next_cut.manifest_version != expected_manifest_version + 1 or next_cut.commit_lsn <= self.head.commit_lsn) {
            return error.InvalidNextManifestVersion;
        }
        if (!std.mem.eql(u8, &next_cut.previous_manifest_digest, &self.head.manifest_digest)) {
            return error.BrokenManifestDigestChain;
        }
        const next_digest = try next_cut.digest();
        self.cuts = next_cuts;
        self.head = .{
            .branch_id = next_cut.branch_id,
            .branch_name = next_cut.branch_name,
            .manifest_version = next_cut.manifest_version,
            .commit_lsn = next_cut.commit_lsn,
            .manifest_digest = next_digest,
        };
        return self.head;
    }

    pub fn expireBelow(self: *HistoricalTimeline, min_manifest_version: u64, min_lsn: u64) !void {
        if (min_manifest_version > self.head.manifest_version or min_lsn > self.head.commit_lsn) {
            return error.CannotExpireActiveHead;
        }
        if (min_manifest_version < self.min_retained_manifest_version or min_lsn < self.min_retained_lsn) {
            return error.InvalidRetentionRegression;
        }
        self.min_retained_manifest_version = min_manifest_version;
        self.min_retained_lsn = min_lsn;
    }

    pub fn selectCut(self: HistoricalTimeline, selector: AsOfSelector) !ManifestCut {
        const chosen: ManifestCut = switch (selector) {
            .head => |branch_name| blk: {
                if (!std.mem.eql(u8, branch_name, self.head.branch_name)) return error.UnknownBranchName;
                break :blk self.cuts[self.head.manifest_version - 1];
            },
            .manifest_version => |ver| blk: {
                if (ver == 0 or ver > self.cuts.len) return error.UnknownManifestVersion;
                break :blk self.cuts[ver - 1];
            },
            .commit_lsn => |target_lsn| blk: {
                var match: ?ManifestCut = null;
                for (self.cuts) |cut| {
                    if (cut.commit_lsn <= target_lsn) {
                        match = cut;
                    } else break;
                }
                break :blk match orelse return error.HistoricalSnapshotExpired;
            },
        };
        if (chosen.manifest_version < self.min_retained_manifest_version or chosen.commit_lsn < self.min_retained_lsn) {
            return error.HistoricalSnapshotExpired;
        }
        return chosen;
    }
};

pub const AsOfSelector = union(enum) {
    head: []const u8,
    manifest_version: u64,
    commit_lsn: u64,
};

pub const AccessKind = enum(u8) {
    metadata_only = 1,
    select_rows = 2,
};

/// Scoped authorization state at a specific `policy_epoch`.
/// Per Decision D1, historical `AS OF` queries resolve names and schemas against
/// the historical `ManifestCut`, but always evaluate authorization against the
/// **current** `policy_epoch`.
pub const GrantSet = struct {
    policy_epoch: u64,
    metadata_objects: []const u64 = &.{},
    select_objects: []const u64 = &.{},

    pub fn authorize(self: GrantSet, object: u64, access: AccessKind) !void {
        if (self.policy_epoch == 0) return error.InvalidPolicyEpoch;
        switch (access) {
            .metadata_only => {
                if (std.mem.indexOfScalar(u64, self.metadata_objects, object) != null) return;
                if (std.mem.indexOfScalar(u64, self.select_objects, object) != null) return;
                return error.MetadataPermissionDenied;
            },
            .select_rows => {
                if (std.mem.indexOfScalar(u64, self.select_objects, object) != null) return;
                return error.RowSelectPermissionDenied;
            },
        }
    }
};

pub const ProvenanceEvidence = struct {
    manifest_version: u64,
    commit_lsn: u64,
    manifest_digest: [32]u8,
    tzdb_version_name: []const u8,
    tzdb_sha256_digest: [32]u8,
    admitted_policy_epoch: u64,
    resolved_object: u64,
    historical_revision: u64,
    output_revision: u64,
    segment_projection: TableConstraints.SegmentProjectionSummary,
};

pub const EqualityFilter = struct {
    column: s.ColumnId,
    literal: v.Atom,
};

pub const AdmittedHistoricalQuery = struct {
    cut: ManifestCut,
    binding: HistoricalTableBinding,
    output_schema: s.Schema,
    output_initials: []const TableSchemaProjection.Initial,
    provenance: ProvenanceEvidence,
    access: AccessKind,
    filter: ?EqualityFilter = null,
    next_segment_index: usize = 0,
    exhausted: bool = false,
};

/// Admit a historical query (`SELECT ... AS OF` or `DESCRIBE ... AS OF`) with optional
/// explicit `PROJECTING TO` a target revision of the same `Object` lineage.
pub fn admitHistoricalQuery(
    timeline: HistoricalTimeline,
    selector: AsOfSelector,
    namespace: u64,
    table_name: []const u8,
    access: AccessKind,
    current_grants: GrantSet,
    project_to_manifest_version: ?u64,
    filter: ?EqualityFilter,
) !AdmittedHistoricalQuery {
    // 1. Bind immutable historical CatalogCut (checking retention watermark first)
    const cut = try timeline.selectCut(selector);

    // 2. Resolve (namespace, table_name) inside the selected historical cut (Decision D1)
    const binding = findTableByName(cut.tables, namespace, table_name) orelse return error.HistoricalTableNotFound;

    // 3. Enforce current policy_epoch authorization on the resolved Object identity (Decision D1)
    try current_grants.authorize(binding.object, access);

    // 4. Determine output schema: native historical schema by default, or explicit PROJECTING TO (Decision D2)
    var output_schema = binding.schema;
    var output_initials = binding.column_origins;
    if (project_to_manifest_version) |target_ver| {
        if (target_ver == 0 or target_ver > timeline.cuts.len) return error.UnknownManifestVersion;
        const target_cut = timeline.cuts[target_ver - 1];
        const target_binding = findTableByObject(target_cut.tables, binding.object) orelse {
            return error.IncompatibleHistoricalObjectLineage;
        };
        // Validate that every historical segment can project cleanly into target_binding.schema
        output_schema = target_binding.schema;
        output_initials = target_binding.column_origins;
    }

    const seg_summary = try binding.segmentProjectionSummary(output_schema, output_initials);
    const cut_digest = try cut.digest();

    return .{
        .cut = cut,
        .binding = binding,
        .output_schema = output_schema,
        .output_initials = output_initials,
        .provenance = .{
            .manifest_version = cut.manifest_version,
            .commit_lsn = cut.commit_lsn,
            .manifest_digest = cut_digest,
            .tzdb_version_name = cut.tzdb.version_id,
            .tzdb_sha256_digest = cut.tzdb.digest,
            .admitted_policy_epoch = current_grants.policy_epoch,
            .resolved_object = binding.object,
            .historical_revision = binding.revision,
            .output_revision = output_schema.revision,
            .segment_projection = seg_summary,
        },
        .access = access,
        .filter = filter,
    };
}

pub const HistoricalBatchResult = struct {
    segment_id: u64,
    row_count: usize,
    is_terminal: bool,
    verified_policy_epoch: u64,
};

/// Fetch the next bounded segment batch from an `AdmittedHistoricalQuery`.
/// Rechecks `live_grants` (`policy_epoch`) before disclosing each batch so
/// mid-stream revocation after Batch 1 deterministically rejects Batch 2.
pub fn fetchNextHistoricalBatch(
    query: *AdmittedHistoricalQuery,
    live_grants: GrantSet,
    out_rows: [][s.max_columns]v.Cell,
) !?HistoricalBatchResult {
    if (query.access != .select_rows) return error.MetadataQueryCannotFetchRows;

    // Recheck current authorization before disclosing any buffered or next batch (Decision D1)
    live_grants.authorize(query.binding.object, .select_rows) catch {
        return error.AuthorizationRevokedMidStream;
    };

    if (query.exhausted) return null;

    while (query.next_segment_index < query.binding.segments.len) {
        const seg_idx = query.next_segment_index;
        query.next_segment_index += 1;
        const seg = query.binding.segments[seg_idx];
        if (seg.max_lsn > query.cut.commit_lsn) continue;

        // Collation-aware zone-map pruning under the historical column's declared kappa profile
        if (query.filter) |flt| {
            if (try shouldPruneSegmentByZoneMap(query.binding, seg, flt)) {
                continue;
            }
        }

        var init_buf: [s.max_columns]TableSchemaProjection.Initial = undefined;
        const seg_initials = filterInitialsForSegment(
            seg.physical_schema,
            query.output_schema,
            query.output_initials,
            &init_buf,
        );
        const projection = try TableSchemaProjection.init(
            seg.physical_schema,
            query.output_schema,
            seg_initials,
        );

        var written: usize = 0;
        for (seg.rows) |phys_row| {
            if (query.filter) |flt| {
                if (!try rowMatchesHistoricalFilter(query.binding, seg.physical_schema, phys_row.cells, flt)) {
                    continue;
                }
            }
            if (written >= out_rows.len) return error.HistoricalBatchBufferTooSmall;
            const projected = try projection.row(
                phys_row.cells,
                out_rows[written][0..query.output_schema.columns.len],
            );
            _ = projected;
            written += 1;
        }

        const is_last = (query.next_segment_index >= query.binding.segments.len);
        if (is_last) query.exhausted = true;
        return .{
            .segment_id = seg.segment_id,
            .row_count = written,
            .is_terminal = is_last,
            .verified_policy_epoch = live_grants.policy_epoch,
        };
    }

    query.exhausted = true;
    return null;
}

fn compareAtomsWithProfile(
    left: v.Atom,
    right: v.Atom,
    col_type: t.Type,
    profile: Collation.Profile,
) !std.math.Order {
    try t.Semantics.validate(left, col_type);
    try t.Semantics.validate(right, col_type);
    return switch (left) {
        .bytes => |lb| Collation.compareBytesProfile(lb, right.bytes, profile),
        else => Collation.compareAtom(left, right, col_type, .none),
    };
}

fn shouldPruneSegmentByZoneMap(
    binding: HistoricalTableBinding,
    seg: HistoricalSegment,
    flt: EqualityFilter,
) !bool {
    const col_idx = try binding.schema.index(flt.column);
    const col = binding.schema.columns[col_idx];
    const profile = try binding.profileForColumn(flt.column);

    for (seg.zone_maps) |zm| {
        if (zm.column == flt.column) {
            const cmp_min = try compareAtomsWithProfile(flt.literal, zm.min_atom, col.type, profile);
            const cmp_max = try compareAtomsWithProfile(flt.literal, zm.max_atom, col.type, profile);
            if (cmp_min == .lt or cmp_max == .gt) return true;
        }
    }
    return false;
}

fn rowMatchesHistoricalFilter(
    binding: HistoricalTableBinding,
    physical_schema: s.Schema,
    phys_cells: []const v.Cell,
    flt: EqualityFilter,
) !bool {
    const hist_idx = try binding.schema.index(flt.column);
    const hist_col = binding.schema.columns[hist_idx];
    const profile = try binding.profileForColumn(flt.column);

    const cell: v.Cell = blk: {
        if (physical_schema.index(flt.column)) |phys_idx| {
            break :blk phys_cells[phys_idx];
        } else |err| {
            if (err != error.UnknownColumn) return err;
            for (binding.column_origins) |init| {
                if (init.column == flt.column) break :blk init.value;
            }
            return error.MissingProjectedColumnDefault;
        }
    };

    switch (cell) {
        .value => |val| {
            const ord = try compareAtomsWithProfile(val.atom, flt.literal, hist_col.type, profile);
            return ord == .eq;
        },
        .null, .missing, .type_error, .conflict => return false,
    }
}
