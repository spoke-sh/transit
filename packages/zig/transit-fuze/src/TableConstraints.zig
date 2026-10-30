//! Declarative relational integrity (`CHECK` and `FOREIGN KEY` constraints),
//! lazy vs. online phased `ALTER TABLE` evolution classification, and
//! multi-version `.tseg` segment schema projection provenance.
const std = @import("std");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const v = t.Values;
const Collation = @import("Collation.zig");
const TableEvolution = @import("TableEvolution.zig");
const TableSchemaProjection = @import("TableSchemaProjection.zig");

pub const ConstraintId = u32;
pub const max_constraints_per_table: usize = 64;

pub const ReferentialAction = enum(u8) {
    restrict = 1,
    no_action = 2,
    cascade = 3,
    set_null = 4,
};

pub const ForeignKeyEnforcement = enum(u8) {
    /// Registered in the catalog dependency graph (`DirectCatalogDependencies`)
    /// so `DROP`/`ALTER` on parent columns is blocked, awaiting Milestone 11's
    /// index-backed runtime enforcer.
    staged_awaiting_index = 1,
    /// Requires an active parent unique index and Milestone 11's index-backed
    /// runtime enforcer on every DML write.
    enforced = 2,
};

/// Deterministic row-local comparison or state predicate for SQL `CHECK` constraints.
pub const CheckAtom = union(enum) {
    compare_literal: struct {
        column: s.ColumnId,
        op: std.math.CompareOperator,
        literal: v.Atom,
    },
    compare_columns: struct {
        left_column: s.ColumnId,
        op: std.math.CompareOperator,
        right_column: s.ColumnId,
    },
    is_not_null: s.ColumnId,
    is_null: s.ColumnId,
};

pub const CheckConstraint = struct {
    id: ConstraintId,
    name: []const u8,
    atoms: []const CheckAtom,
    validated: bool = true,

    pub fn validate(self: CheckConstraint, schema: s.Schema) !void {
        try schema.validate();
        if (self.id == 0 or self.name.len == 0 or self.name.len > 63) return error.InvalidConstraintName;
        if (self.atoms.len == 0 or self.atoms.len > 32) return error.InvalidCheckConstraint;
        for (self.atoms) |atom| switch (atom) {
            .compare_literal => |cmp| {
                const idx = try schema.index(cmp.column);
                const col = schema.columns[idx];
                try t.Semantics.validate(cmp.literal, col.type);
            },
            .compare_columns => |cmp| {
                const l_idx = try schema.index(cmp.left_column);
                const r_idx = try schema.index(cmp.right_column);
                const l_col = schema.columns[l_idx];
                const r_col = schema.columns[r_idx];
                if (!try l_col.type.eql(r_col.type) or l_col.collation != r_col.collation) {
                    return error.IncompatibleCheckColumns;
                }
            },
            .is_not_null => |col_id| _ = try schema.index(col_id),
            .is_null => |col_id| _ = try schema.index(col_id),
        };
    }

    pub fn referencesColumn(self: CheckConstraint, column_id: s.ColumnId) bool {
        for (self.atoms) |atom| switch (atom) {
            .compare_literal => |cmp| if (cmp.column == column_id) return true,
            .compare_columns => |cmp| if (cmp.left_column == column_id or cmp.right_column == column_id) return true,
            .is_not_null => |id| if (id == column_id) return true,
            .is_null => |id| if (id == column_id) return true,
        };
        return false;
    }
};

pub const CheckViolationReason = enum(u8) {
    predicate_false = 1,
    missing_cell = 2,
    type_error_cell = 3,
    conflict_cell = 4,
};

pub const CheckViolation = struct {
    constraint_id: ConstraintId,
    constraint_name: []const u8,
    column_id: s.ColumnId,
    cell_state: t.State,
    reason: CheckViolationReason,
};

/// Evaluate a row against a `CheckConstraint` under Transit's 5-state cell algebra:
/// - `value(true)` and `null` (SQL UNKNOWN) pass;
/// - `value(false)`, `missing`, `type_error`, and `conflict` reject with `error.CheckConstraintViolation`.
pub fn evaluateCheckRow(
    schema: s.Schema,
    constraint: CheckConstraint,
    row_cells: []const v.Cell,
    violation_out: ?*CheckViolation,
) !void {
    try constraint.validate(schema);
    if (row_cells.len != schema.columns.len) return error.InvalidColumnCount;

    for (constraint.atoms) |atom| {
        switch (atom) {
            .compare_literal => |cmp| {
                const idx = try schema.index(cmp.column);
                const col = schema.columns[idx];
                const cell = row_cells[idx];
                switch (cell) {
                    .null => continue, // SQL CHECK treats UNKNOWN (NULL comparison) as passing
                    .missing => {
                        if (violation_out) |out| out.* = .{
                            .constraint_id = constraint.id,
                            .constraint_name = constraint.name,
                            .column_id = cmp.column,
                            .cell_state = .missing,
                            .reason = .missing_cell,
                        };
                        return error.CheckConstraintViolation;
                    },
                    .type_error => {
                        if (violation_out) |out| out.* = .{
                            .constraint_id = constraint.id,
                            .constraint_name = constraint.name,
                            .column_id = cmp.column,
                            .cell_state = .type_error,
                            .reason = .type_error_cell,
                        };
                        return error.CheckConstraintViolation;
                    },
                    .conflict => {
                        if (violation_out) |out| out.* = .{
                            .constraint_id = constraint.id,
                            .constraint_name = constraint.name,
                            .column_id = cmp.column,
                            .cell_state = .conflict,
                            .reason = .conflict_cell,
                        };
                        return error.CheckConstraintViolation;
                    },
                    .value => |val| {
                        const ord = try Collation.compareAtom(val.atom, cmp.literal, col.type, col.collation);
                        if (!orderMatches(ord, cmp.op)) {
                            if (violation_out) |out| out.* = .{
                                .constraint_id = constraint.id,
                                .constraint_name = constraint.name,
                                .column_id = cmp.column,
                                .cell_state = .value,
                                .reason = .predicate_false,
                            };
                            return error.CheckConstraintViolation;
                        }
                    },
                }
            },
            .compare_columns => |cmp| {
                const l_idx = try schema.index(cmp.left_column);
                const r_idx = try schema.index(cmp.right_column);
                const l_col = schema.columns[l_idx];
                for ([_]struct { id: s.ColumnId, cell: v.Cell }{
                    .{ .id = cmp.left_column, .cell = row_cells[l_idx] },
                    .{ .id = cmp.right_column, .cell = row_cells[r_idx] },
                }) |side| {
                    switch (side.cell) {
                        .missing, .type_error, .conflict => | _, tag | {
                            if (violation_out) |out| out.* = .{
                                .constraint_id = constraint.id,
                                .constraint_name = constraint.name,
                                .column_id = side.id,
                                .cell_state = tag,
                                .reason = switch (tag) {
                                    .missing => .missing_cell,
                                    .type_error => .type_error_cell,
                                    .conflict => .conflict_cell,
                                    else => unreachable,
                                },
                            };
                            return error.CheckConstraintViolation;
                        },
                        else => {},
                    }
                }
                if (row_cells[l_idx] == .null or row_cells[r_idx] == .null) continue;
                const ord = try Collation.compareAtom(
                    row_cells[l_idx].value.atom,
                    row_cells[r_idx].value.atom,
                    l_col.type,
                    l_col.collation,
                );
                if (!orderMatches(ord, cmp.op)) {
                    if (violation_out) |out| out.* = .{
                        .constraint_id = constraint.id,
                        .constraint_name = constraint.name,
                        .column_id = cmp.left_column,
                        .cell_state = .value,
                        .reason = .predicate_false,
                    };
                    return error.CheckConstraintViolation;
                }
            },
            .is_not_null => |col_id| {
                const idx = try schema.index(col_id);
                const cell = row_cells[idx];
                switch (cell) {
                    .value => {},
                    .null => {
                        if (violation_out) |out| out.* = .{
                            .constraint_id = constraint.id,
                            .constraint_name = constraint.name,
                            .column_id = col_id,
                            .cell_state = .null,
                            .reason = .predicate_false,
                        };
                        return error.CheckConstraintViolation;
                    },
                    .missing, .type_error, .conflict => |_, tag| {
                        if (violation_out) |out| out.* = .{
                            .constraint_id = constraint.id,
                            .constraint_name = constraint.name,
                            .column_id = col_id,
                            .cell_state = tag,
                            .reason = switch (tag) {
                                .missing => .missing_cell,
                                .type_error => .type_error_cell,
                                .conflict => .conflict_cell,
                                else => unreachable,
                            },
                        };
                        return error.CheckConstraintViolation;
                    },
                }
            },
            .is_null => |col_id| {
                const idx = try schema.index(col_id);
                const cell = row_cells[idx];
                switch (cell) {
                    .null => {},
                    .value => {
                        if (violation_out) |out| out.* = .{
                            .constraint_id = constraint.id,
                            .constraint_name = constraint.name,
                            .column_id = col_id,
                            .cell_state = .value,
                            .reason = .predicate_false,
                        };
                        return error.CheckConstraintViolation;
                    },
                    .missing, .type_error, .conflict => |_, tag| {
                        if (violation_out) |out| out.* = .{
                            .constraint_id = constraint.id,
                            .constraint_name = constraint.name,
                            .column_id = col_id,
                            .cell_state = tag,
                            .reason = switch (tag) {
                                .missing => .missing_cell,
                                .type_error => .type_error_cell,
                                .conflict => .conflict_cell,
                                else => unreachable,
                            },
                        };
                        return error.CheckConstraintViolation;
                    },
                }
            },
        }
    }
}

fn orderMatches(ord: std.math.Order, op: std.math.CompareOperator) bool {
    return switch (op) {
        .lt => ord == .lt,
        .lte => ord == .lt or ord == .eq,
        .eq => ord == .eq,
        .gte => ord == .gt or ord == .eq,
        .gt => ord == .gt,
        .neq => ord != .eq,
    };
}

/// Declarative cross-table `FOREIGN KEY ... REFERENCES ...` constraint bound to
/// stable `(Object, DefinitionRevision, ColumnId)` identities.
pub const ForeignKeyConstraint = struct {
    id: ConstraintId,
    name: []const u8,
    local_columns: []const s.ColumnId,
    target_object: u64,
    target_revision: u64,
    target_columns: []const s.ColumnId,
    on_delete: ReferentialAction = .restrict,
    on_update: ReferentialAction = .restrict,
    enforcement: ForeignKeyEnforcement = .staged_awaiting_index,

    pub fn validateAgainstSchemas(self: ForeignKeyConstraint, child_schema: s.Schema, parent_schema: s.Schema) !void {
        try child_schema.validate();
        try parent_schema.validate();
        if (self.id == 0 or self.name.len == 0 or self.name.len > 63) return error.InvalidConstraintName;
        if (self.local_columns.len == 0 or self.local_columns.len != self.target_columns.len) {
            return error.InvalidForeignKeyArity;
        }
        if (parent_schema.object != self.target_object) return error.ForeignKeyTargetMismatch;
        if (!std.mem.eql(s.ColumnId, parent_schema.primary_key, self.target_columns)) {
            return error.ForeignKeyTargetNotUniqueKey;
        }
        for (self.local_columns, self.target_columns, 0..) |local_id, target_id, i| {
            for (self.local_columns[0..i]) |prev| if (prev == local_id) return error.DuplicateForeignKeyColumn;
            const child_col = child_schema.columns[try child_schema.index(local_id)];
            const parent_col = parent_schema.columns[try parent_schema.index(target_id)];
            if (!try child_col.type.eql(parent_col.type) or child_col.collation != parent_col.collation) {
                return error.IncompatibleForeignKeyColumnType;
            }
            if ((self.on_delete == .set_null or self.on_update == .set_null) and !child_col.nullable) {
                return error.ForeignKeySetNullRequiresNullableColumn;
            }
        }
    }

    pub fn referencesLocalColumn(self: ForeignKeyConstraint, column_id: s.ColumnId) bool {
        return std.mem.indexOfScalar(s.ColumnId, self.local_columns, column_id) != null;
    }

    pub fn referencesTargetColumn(self: ForeignKeyConstraint, target_object: u64, column_id: s.ColumnId) bool {
        if (self.target_object != target_object) return false;
        return std.mem.indexOfScalar(s.ColumnId, self.target_columns, column_id) != null;
    }

    /// Milestone 11 handoff gate: never silently ignore an enforced foreign key when
    /// the covering unique index and runtime FK enforcer are not active.
    pub fn checkWriteAdmission(self: ForeignKeyConstraint, index_enforcer_active: bool) !void {
        if (self.enforcement == .enforced and !index_enforcer_active) {
            return error.ForeignKeyIndexEnforcementUnavailable;
        }
    }
};

/// Verify that a proposed `TableEvolution.Change` does not drop or incompatibly alter
/// any column bound by an active `CheckConstraint` or `ForeignKeyConstraint`.
pub fn validateChangeAgainstConstraints(
    schema: s.Schema,
    change: TableEvolution.Change,
    checks: []const CheckConstraint,
    local_foreign_keys: []const ForeignKeyConstraint,
    inbound_foreign_keys: []const ForeignKeyConstraint,
) !void {
    switch (change) {
        .drop => |col_id| {
            for (checks) |chk| if (chk.referencesColumn(col_id)) return error.ColumnReferencedByCheckConstraint;
            for (local_foreign_keys) |fk| if (fk.referencesLocalColumn(col_id)) return error.ColumnReferencedByForeignKey;
            for (inbound_foreign_keys) |fk| if (fk.referencesTargetColumn(schema.object, col_id)) return error.ColumnReferencedByInboundForeignKey;
        },
        .type => |edit| {
            for (checks) |chk| if (chk.referencesColumn(edit.column)) return error.ColumnReferencedByCheckConstraint;
            for (local_foreign_keys) |fk| if (fk.referencesLocalColumn(edit.column)) return error.ColumnReferencedByForeignKey;
            for (inbound_foreign_keys) |fk| if (fk.referencesTargetColumn(schema.object, edit.column)) return error.ColumnReferencedByInboundForeignKey;
        },
        .physical => |edit| {
            const existing = schema.columns[try schema.index(edit.column)];
            if (existing.collation != edit.collation) {
                for (checks) |chk| if (chk.referencesColumn(edit.column)) return error.ColumnReferencedByCheckConstraint;
                for (local_foreign_keys) |fk| if (fk.referencesLocalColumn(edit.column)) return error.ColumnReferencedByForeignKey;
                for (inbound_foreign_keys) |fk| if (fk.referencesTargetColumn(schema.object, edit.column)) return error.ColumnReferencedByInboundForeignKey;
            }
        },
        .nullable => |edit| {
            if (!edit.value) {
                for (local_foreign_keys) |fk| {
                    if (fk.referencesLocalColumn(edit.column) and (fk.on_delete == .set_null or fk.on_update == .set_null)) {
                        return error.ForeignKeySetNullRequiresNullableColumn;
                    }
                }
            }
        },
        .add, .rename, .default => {},
    }
}

pub const RewriteKind = enum(u8) {
    /// Class A: O(1) control-WAL metadata update; existing `.tseg` segments are projected lazily on read.
    lazy_metadata_or_projection = 1,
    /// Class B1: Physical `.tseg` layout is unchanged, but existing rows require validation scan.
    validation_scan_only = 2,
    /// Class B2: Physical type, codec, collation or key rewrite required; must execute via
    /// Milestone 11's recoverable online phased rewrite (`Staged -> Backfilling -> CatchingUp -> Validating -> Cutover`).
    online_phased_rewrite = 3,
};

pub fn classifyTransition(transition: TableEvolution.Transition, has_retained_rows: bool) !RewriteKind {
    if (try transition.canProject()) {
        return .lazy_metadata_or_projection;
    }
    if (!has_retained_rows) {
        return .lazy_metadata_or_projection;
    }
    return switch (transition.work) {
        .metadata => .lazy_metadata_or_projection,
        .validate_rows => .validation_scan_only,
        .rewrite_rows => .online_phased_rewrite,
    };
}

/// Enforce Decision D3: refuse synchronous blocking full-table physical rewrites on populated tables,
/// requiring Milestone 11's online phased rewrite lifecycle instead.
pub fn checkSynchronousEvolutionAdmission(transition: TableEvolution.Transition, has_retained_rows: bool) !RewriteKind {
    const kind = try classifyTransition(transition, has_retained_rows);
    if (kind == .online_phased_rewrite and has_retained_rows) {
        return error.OnlinePhasedRewriteRequired;
    }
    return kind;
}

pub const SegmentDescriptor = struct {
    segment_id: u64,
    physical_schema: s.Schema,
    initials: []const TableSchemaProjection.Initial,
    row_count: u64,
};

pub const SegmentProjectionSummary = struct {
    target_object: u64,
    target_revision: u64,
    total_segments: u32,
    native_target_segments: u32,
    lazily_projected_segments: u32,
    synthesized_default_columns: u16,
    omitted_dropped_columns: u16,
    total_rows: u64,
    lazily_projected_rows: u64,
};

/// Compute exact per-segment schema projection provenance across multi-version `.tseg` segments
/// into `target_schema` (either the active head or an explicit `PROJECTING TO` schema).
pub fn inspectSegmentProjectionCoverage(
    segments: []const SegmentDescriptor,
    target_schema: s.Schema,
) !SegmentProjectionSummary {
    try target_schema.validate();
    var summary: SegmentProjectionSummary = .{
        .target_object = target_schema.object,
        .target_revision = target_schema.revision,
        .total_segments = @intCast(segments.len),
        .native_target_segments = 0,
        .lazily_projected_segments = 0,
        .synthesized_default_columns = 0,
        .omitted_dropped_columns = 0,
        .total_rows = 0,
        .lazily_projected_rows = 0,
    };

    const target_fp = try target_schema.fingerprint();
    for (segments) |seg| {
        summary.total_rows = try std.math.add(u64, summary.total_rows, seg.row_count);
        const seg_fp = try seg.physical_schema.fingerprint();
        if (seg.physical_schema.revision == target_schema.revision and std.mem.eql(u8, &seg_fp, &target_fp)) {
            summary.native_target_segments += 1;
            continue;
        }
        const proj = try TableSchemaProjection.init(seg.physical_schema, target_schema, seg.initials);
        summary.lazily_projected_segments += 1;
        summary.lazily_projected_rows = try std.math.add(u64, summary.lazily_projected_rows, seg.row_count);

        var synth: u16 = 0;
        for (proj.sources[0..target_schema.columns.len]) |src| {
            if (src == .initial) synth += 1;
        }
        if (synth > summary.synthesized_default_columns) summary.synthesized_default_columns = synth;

        var dropped: u16 = 0;
        for (seg.physical_schema.columns) |phys_col| {
            _ = target_schema.index(phys_col.id) catch |err| {
                if (err == error.UnknownColumn) {
                    dropped += 1;
                    continue;
                }
                return err;
            };
        }
        if (dropped > summary.omitted_dropped_columns) summary.omitted_dropped_columns = dropped;
    }
    return summary;
}
