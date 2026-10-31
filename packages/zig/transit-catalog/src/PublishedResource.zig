//! Transport- and screen-independent published business resources (`PUBLISHED_RESOURCE_V1` /
//! `PBR1`, magic `0x50425231`) in the Direct Control Plane (`transit-catalog`).
//!
//! Decouples business resource definitions from `APPLICATION_V1`'s mandatory screen/theme
//! requirements and from `Station` `STATE_V1` 256-byte KV records (`NRC1`). Records stable
//! `(resource_object, definition_id, publication_revision)` identity, owning application,
//! business meaning, supported questions, semantic units, manifest-pinned `TzdbVersion`
//! ($\kappa_{\text{tz}}$), typed parameter specs with domain constraints, upstream column
//! dependencies, result schema ($\tau \perp \kappa \perp \epsilon$), freshness SLA,
//! execution `WorkBound`, and optional presentation bindings (`ChartSpec`,
//! `ReportLayoutSpec`, `SpatialLayerSpec`, `DrilldownSpec`, `McpUiTemplateRef`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const DecimalArithmetic = fuze.DecimalArithmetic;
const HistoricalCatalog = c.HistoricalCatalog;

pub const magic_pbr1: u32 = 0x50425231; // "PBR1"
pub const contract_id = "transit.catalog.published-resource.v1";
pub const max_name_bytes: usize = 63;
pub const max_parameters: usize = 16;
pub const max_questions: usize = 16;
pub const max_drilldowns: usize = 16;

pub const ResourceLifecycleState = enum(u8) {
    draft = 1,
    published = 2,
    withdrawn = 3,
    retired = 4,
};

pub const BackingKind = enum(u8) {
    compiled_sql_plan = 1, // FQP1 finite analytical query
    managed_dataflow = 2, // DFR1 maintained computation (M12)
};

pub const SemanticUnit = union(enum) {
    none: void,
    iso4217_currency: [3]u8,
    si_unit: []const u8,
    basis_points: void,
    percentage: void,
    spatial_srid: u32,

    pub fn validate(self: SemanticUnit) !void {
        switch (self) {
            .none, .basis_points, .percentage => {},
            .iso4217_currency => |code| {
                for (code) |ch| {
                    if (ch < 'A' or ch > 'Z') return error.InvalidIso4217CurrencyCode;
                }
            },
            .si_unit => |unit| {
                if (unit.len == 0 or unit.len > 32) return error.InvalidSemanticUnitText;
            },
            .spatial_srid => |srid| {
                if (srid == 0) return error.InvalidSpatialSridUnit;
            },
        }
    }
};

pub const ColumnSemanticBinding = struct {
    column_id: s.ColumnId,
    unit: SemanticUnit = .{ .none = {} },
    business_description: []const u8 = "",
};

pub const ParameterDomainConstraint = union(enum) {
    unconstrained: void,
    signed_range: struct { min: i64, max: i64 },
    unsigned_range: struct { min: u64, max: u64 },
    decimal128_range: struct { min: i128, max: i128, scale: u8 },
    utf8_enum: []const []const u8,
    max_temporal_window_ms: u64,

    pub fn validate(self: ParameterDomainConstraint) !void {
        switch (self) {
            .unconstrained => {},
            .signed_range => |r| if (r.min > r.max) return error.InvalidParameterDomainRange,
            .unsigned_range => |r| if (r.min > r.max) return error.InvalidParameterDomainRange,
            .decimal128_range => |r| if (r.min > r.max or r.scale > 38) return error.InvalidParameterDomainRange,
            .utf8_enum => |items| {
                if (items.len == 0 or items.len > 64) return error.InvalidParameterDomainEnum;
                for (items) |item| {
                    if (item.len == 0 or item.len > 128) return error.InvalidParameterDomainEnum;
                }
            },
            .max_temporal_window_ms => |ms| if (ms == 0) return error.InvalidParameterDomainRange,
        }
    }

    pub fn checkValue(self: ParameterDomainConstraint, cell: v.Cell) !void {
        const atom = switch (cell) {
            .value => |val| switch (val) {
                .atom => |a| a,
                else => return error.ParameterMustBeScalarValue,
            },
            .null, .missing, .type_error, .conflict => return error.NonValueParameterCellRejected,
        };
        switch (self) {
            .unconstrained => {},
            .signed_range => |r| switch (atom) {
                .signed => |x| if (x < r.min or x > r.max) return error.ParameterDomainViolation,
                else => return error.ParameterTypeMismatch,
            },
            .unsigned_range => |r| switch (atom) {
                .unsigned => |x| if (x < r.min or x > r.max) return error.ParameterDomainViolation,
                else => return error.ParameterTypeMismatch,
            },
            .decimal128_range => |r| switch (atom) {
                .decimal => |x| if (x < r.min or x > r.max) return error.ParameterDomainViolation,
                else => return error.ParameterTypeMismatch,
            },
            .utf8_enum => |allowed| switch (atom) {
                .bytes => |b| {
                    for (allowed) |candidate| {
                        if (std.mem.eql(u8, b, candidate)) return;
                    }
                    return error.ParameterDomainViolation;
                },
                else => return error.ParameterTypeMismatch,
            },
            .max_temporal_window_ms => |max_ms| switch (atom) {
                .unsigned => |ms| if (ms == 0 or ms > max_ms) return error.ParameterDomainViolation,
                else => return error.ParameterTypeMismatch,
            },
        }
    }
};

pub const ParameterSpec = struct {
    ordinal: u32,
    name: []const u8,
    logical_type: t.Type,
    required: bool = true,
    default_value: ?v.Cell = null,
    domain: ParameterDomainConstraint = .{ .unconstrained = {} },

    pub fn validate(self: ParameterSpec) !void {
        if (self.ordinal == 0 or self.ordinal > max_parameters) return error.InvalidParameterOrdinal;
        if (self.name.len == 0 or self.name.len > max_name_bytes) return error.InvalidParameterName;
        try self.domain.validate();
        if (self.default_value) |def| {
            try self.domain.checkValue(def);
        }
    }
};

pub const ParameterValueBinding = struct {
    ordinal: u32,
    value: v.Cell,
};

pub const QuestionTemplate = struct {
    question_id: []const u8,
    prompt_template: []const u8,
    required_parameter_ordinals: []const u32 = &.{},

    pub fn validate(self: QuestionTemplate, param_count: usize) !void {
        if (self.question_id.len == 0 or self.question_id.len > max_name_bytes) return error.InvalidQuestionTemplateId;
        if (self.prompt_template.len == 0 or self.prompt_template.len > 512) return error.InvalidQuestionPromptTemplate;
        for (self.required_parameter_ordinals) |ord| {
            if (ord == 0 or ord > param_count) return error.QuestionReferencesUnknownParameter;
        }
    }
};

pub const FreshnessRequirement = struct {
    max_staleness_ms: u64,
    require_complete_watermark: bool = true,
    allow_stale_with_warning: bool = false,

    pub fn validate(self: FreshnessRequirement) !void {
        if (self.max_staleness_ms == 0) return error.InvalidFreshnessRequirement;
    }
};

pub const WorkBound = struct {
    max_rows: u64,
    max_bytes: u64,
    max_cpu_micros: u64,
    max_iops: u64,
    execution_timeout_ms: u64,

    pub fn validate(self: WorkBound) !void {
        if (self.max_rows == 0 or self.max_bytes == 0 or self.max_cpu_micros == 0 or self.execution_timeout_ms == 0) {
            return error.InvalidResourceWorkBound;
        }
    }
};

pub const ChartMark = enum(u8) {
    bar = 1,
    line = 2,
    area = 3,
    point = 4,
    kpi_summary = 5,
};

pub const ChartSpec = struct {
    chart_id: []const u8,
    title: []const u8,
    mark: ChartMark,
    x_column: s.ColumnId,
    y_column: s.ColumnId,
    series_column: ?s.ColumnId = null,

    pub fn validate(self: ChartSpec, schema: s.Schema) !void {
        if (self.chart_id.len == 0 or self.title.len == 0) return error.InvalidChartSpec;
        _ = try schema.index(self.x_column);
        _ = try schema.index(self.y_column);
        if (self.series_column) |sc| _ = try schema.index(sc);
    }
};

pub const ReportSectionKind = enum(u8) {
    executive_summary = 1,
    kpi_table = 2,
    chart_panel = 3,
    evidence_narrative = 4,
};

pub const ReportLayoutSpec = struct {
    report_id: []const u8,
    title: []const u8,
    sections: []const ReportSectionKind,

    pub fn validate(self: ReportLayoutSpec) !void {
        if (self.report_id.len == 0 or self.title.len == 0 or self.sections.len == 0) {
            return error.InvalidReportLayoutSpec;
        }
    }
};

pub const SpatialLayerSpec = struct {
    layer_id: []const u8,
    geometry_column: s.ColumnId,
    srid: u32,
    is_3d: bool = false,

    pub fn validate(self: SpatialLayerSpec, schema: s.Schema) !void {
        if (self.layer_id.len == 0 or self.srid == 0) return error.InvalidSpatialLayerSpec;
        _ = try schema.index(self.geometry_column);
    }
};

pub const DrilldownSpec = struct {
    action_id: []const u8,
    target_resource_object: u64,
    target_minimum_revision: u64 = 1,
    source_column_to_target_param_ordinal: []const struct {
        source_column: s.ColumnId,
        target_param_ordinal: u32,
    } = &.{},
    requires_source_row_rights: bool = false,

    pub fn validate(self: DrilldownSpec, schema: s.Schema) !void {
        if (self.action_id.len == 0 or self.target_resource_object == 0 or self.target_minimum_revision == 0) {
            return error.InvalidDrilldownSpec;
        }
        for (self.source_column_to_target_param_ordinal) |mapping| {
            _ = try schema.index(mapping.source_column);
            if (mapping.target_param_ordinal == 0 or mapping.target_param_ordinal > max_parameters) {
                return error.InvalidDrilldownParameterMapping;
            }
        }
    }
};

/// Optional presentation bindings attached to a `PublishedResourceDescriptor`.
/// Unlike `APPLICATION_V1`, a published resource requires zero screens and zero themes.
pub const PresentationBindings = struct {
    charts: []const ChartSpec = &.{},
    reports: []const ReportLayoutSpec = &.{},
    spatial_layers: []const SpatialLayerSpec = &.{},
    drilldowns: []const DrilldownSpec = &.{},
    mcp_ui_template_uri: ?[]const u8 = null,

    pub fn validate(self: PresentationBindings, schema: s.Schema) !void {
        if (self.drilldowns.len > max_drilldowns) return error.TooManyDrilldownSpecs;
        for (self.charts) |chart| try chart.validate(schema);
        for (self.reports) |report| try report.validate();
        for (self.spatial_layers) |layer| try layer.validate(schema);
        for (self.drilldowns) |dd| try dd.validate(schema);
        if (self.mcp_ui_template_uri) |uri| {
            if (!std.mem.startsWith(u8, uri, "ui://") or uri.len <= 5 or uri.len > 256) {
                return error.InvalidMcpUiTemplateUri;
            }
        }
    }
};

pub const PublishedResourceDescriptor = struct {
    namespace_id: u64,
    resource_object: u64,
    definition_id: u64,
    publication_revision: u64,
    previous_revision: ?u64 = null,
    branch_id: u64 = 1,
    owning_application: ?u64 = null,
    created_at_lsn: u64,
    state: ResourceLifecycleState = .published,
    canonical_name: []const u8,
    business_title: []const u8,
    business_meaning: []const u8,
    /// Null explicitly declares that this resource uses no timezone rules.
    /// Temporal computation must bind an actual immutable database identity.
    tzdb_version: ?DecimalArithmetic.TzdbVersion,
    backing_kind: BackingKind = .compiled_sql_plan,
    canonical_plan_or_sql: []const u8,
    dependencies: []const HistoricalCatalog.DependencyColumnBinding,
    parameters: []const ParameterSpec = &.{},
    supported_questions: []const QuestionTemplate = &.{},
    result_schema: s.Schema,
    column_semantics: []const ColumnSemanticBinding = &.{},
    freshness_requirement: FreshnessRequirement,
    work_bound: WorkBound,
    presentation: PresentationBindings = .{},

    pub fn validate(self: PublishedResourceDescriptor) !void {
        if (self.namespace_id == 0 or self.resource_object == 0 or self.definition_id == 0 or self.publication_revision == 0) {
            return error.InvalidPublishedResourceIdentity;
        }
        if (self.branch_id == 0 or self.created_at_lsn == 0) return error.InvalidPublishedResourceIdentity;
        if (self.publication_revision == 1) {
            if (self.previous_revision != null) return error.InvalidPublishedResourceRevisionLineage;
        } else {
            const prev = self.previous_revision orelse return error.InvalidPublishedResourceRevisionLineage;
            if (prev + 1 != self.publication_revision) return error.InvalidPublishedResourceRevisionLineage;
        }
        if (self.canonical_name.len == 0 or self.canonical_name.len > max_name_bytes) {
            return error.InvalidPublishedResourceName;
        }
        if (self.business_title.len == 0 or self.business_meaning.len == 0) {
            return error.MissingPublishedResourceBusinessMeaning;
        }
        if (self.canonical_plan_or_sql.len == 0) return error.MissingPublishedResourceBackingPlan;
        if (self.dependencies.len == 0) return error.MissingPublishedResourceDependencies;
        for (self.dependencies) |dep| {
            if (dep.source_object == 0 or dep.source_revision == 0 or dep.columns.len == 0) {
                return error.InvalidPublishedResourceDependency;
            }
        }
        if (self.parameters.len > max_parameters) return error.TooManyPublishedResourceParameters;
        for (self.parameters, 0..) |param, idx| {
            try param.validate();
            if (param.ordinal != idx + 1) return error.NonContiguousParameterOrdinals;
        }
        if (self.supported_questions.len > max_questions) return error.TooManySupportedQuestions;
        for (self.supported_questions) |q| {
            try q.validate(self.parameters.len);
        }
        if (self.result_schema.object != self.resource_object or self.result_schema.revision != self.publication_revision) {
            return error.PublishedResourceSchemaIdentityMismatch;
        }
        try self.result_schema.validate();
        for (self.column_semantics) |sem| {
            _ = try self.result_schema.index(sem.column_id);
            try sem.unit.validate();
        }
        if (self.tzdb_version) |version| try version.validate();
        try self.freshness_requirement.validate();
        try self.work_bound.validate();
        try self.presentation.validate(self.result_schema);
    }

    pub fn definitionDigest(self: PublishedResourceDescriptor) ![32]u8 {
        try self.validate();
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(contract_id ++ "\x00");
        var header: [65]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], magic_pbr1, .little);
        std.mem.writeInt(u64, header[4..12], self.namespace_id, .little);
        std.mem.writeInt(u64, header[12..20], self.resource_object, .little);
        std.mem.writeInt(u64, header[20..28], self.definition_id, .little);
        std.mem.writeInt(u64, header[28..36], self.publication_revision, .little);
        std.mem.writeInt(u64, header[36..44], self.previous_revision orelse 0, .little);
        std.mem.writeInt(u64, header[44..52], self.branch_id, .little);
        std.mem.writeInt(u64, header[52..60], self.owning_application orelse 0, .little);
        std.mem.writeInt(u32, header[60..64], @truncate(self.created_at_lsn), .little);
        header[64] = @backingInt(self.backing_kind);
        hasher.update(&header);
        hasher.update(self.canonical_name);
        hasher.update("\x00");
        hasher.update(self.business_title);
        hasher.update("\x00");
        hasher.update(self.business_meaning);
        hasher.update("\x00");
        if (self.tzdb_version) |version| {
            hasher.update(&.{1});
            hasher.update(version.version_id);
            hasher.update("\x00");
            hasher.update(&version.digest);
        } else hasher.update(&.{0});
        hasher.update(self.canonical_plan_or_sql);
        hasher.update("\x00");
        for (self.dependencies) |dep| {
            var dep_buf: [16]u8 = undefined;
            std.mem.writeInt(u64, dep_buf[0..8], dep.source_object, .little);
            std.mem.writeInt(u64, dep_buf[8..16], dep.source_revision, .little);
            hasher.update(&dep_buf);
            for (dep.columns) |col_id| {
                var col_buf: [8]u8 = undefined;
                std.mem.writeInt(u64, &col_buf, col_id, .little);
                hasher.update(&col_buf);
            }
        }
        for (self.parameters) |param| {
            var ord_buf: [5]u8 = undefined;
            std.mem.writeInt(u32, ord_buf[0..4], param.ordinal, .little);
            ord_buf[4] = if (param.required) 1 else 0;
            hasher.update(&ord_buf);
            hasher.update(param.name);
            hasher.update("\x00");
        }
        for (self.result_schema.columns) |col| {
            var col_meta: [9]u8 = undefined;
            std.mem.writeInt(u64, col_meta[0..8], col.id, .little);
            col_meta[8] = @backingInt(col.collation);
            hasher.update(&col_meta);
            hasher.update(col.name);
            hasher.update("\x00");
        }
        var bounds_buf: [48]u8 = undefined;
        std.mem.writeInt(u64, bounds_buf[0..8], self.freshness_requirement.max_staleness_ms, .little);
        std.mem.writeInt(u64, bounds_buf[8..16], self.work_bound.max_rows, .little);
        std.mem.writeInt(u64, bounds_buf[16..24], self.work_bound.max_bytes, .little);
        std.mem.writeInt(u64, bounds_buf[24..32], self.work_bound.max_cpu_micros, .little);
        std.mem.writeInt(u64, bounds_buf[32..40], self.work_bound.max_iops, .little);
        std.mem.writeInt(u64, bounds_buf[40..48], self.work_bound.execution_timeout_ms, .little);
        hasher.update(&bounds_buf);
        return hasher.finalResult();
    }

    /// Validates caller parameter bindings against declared `ParameterSpec` ordinals,
    /// required flags, and `ParameterDomainConstraint`s, and computes a deterministic
    /// parameter bindings digest.
    pub fn validateAndDigestParameters(
        self: PublishedResourceDescriptor,
        bindings: []const ParameterValueBinding,
    ) ![32]u8 {
        try self.validate();
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("transit.catalog.published-resource.params.v1\x00");
        for (self.parameters) |spec| {
            var found: ?v.Cell = null;
            for (bindings) |b| {
                if (b.ordinal == spec.ordinal) {
                    if (found != null) return error.DuplicateParameterBinding;
                    found = b.value;
                }
            }
            const effective = found orelse spec.default_value orelse {
                if (spec.required) return error.MissingRequiredParameter;
                continue;
            };
            try spec.domain.checkValue(effective);
            var ord_buf: [4]u8 = undefined;
            std.mem.writeInt(u32, &ord_buf, spec.ordinal, .little);
            hasher.update(&ord_buf);
            switch (effective.value.atom) {
                .signed => |val| {
                    hasher.update(&[_]u8{1});
                    var b16: [16]u8 = undefined;
                    std.mem.writeInt(i128, &b16, val, .little);
                    hasher.update(&b16);
                },
                .unsigned => |val| {
                    hasher.update(&[_]u8{2});
                    var b16: [16]u8 = undefined;
                    std.mem.writeInt(u128, &b16, val, .little);
                    hasher.update(&b16);
                },
                .decimal => |val| {
                    hasher.update(&[_]u8{3});
                    var b16: [16]u8 = undefined;
                    std.mem.writeInt(i128, &b16, val, .little);
                    hasher.update(&b16);
                },
                .bytes => |str| {
                    hasher.update(&[_]u8{4});
                    hasher.update(str);
                    hasher.update("\x00");
                },
                .boolean => |flag| {
                    hasher.update(&[_]u8{ 5, if (flag) 1 else 0 });
                },
                else => return error.UnsupportedParameterAtomType,
            }
        }
        for (bindings) |b| {
            if (b.ordinal == 0 or b.ordinal > self.parameters.len) return error.UnknownParameterOrdinal;
        }
        return hasher.finalResult();
    }
};
