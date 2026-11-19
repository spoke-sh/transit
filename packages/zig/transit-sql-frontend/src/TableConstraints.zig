//! Declarative relational integrity (`CHECK` and `FOREIGN KEY` constraints),
//! lazy vs. online phased `ALTER TABLE` evolution classification, and
//! multi-version `.tseg` segment schema projection provenance.
const std = @import("std");
const Definition = @import("transit_protocol").DataLifecycle.Definition;
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const v = t.Values;
const Collation = @import("Collation.zig");
const TableEvolution = @import("TableEvolution.zig");
const TableSchemaProjection = @import("TableSchemaProjection.zig");

pub const ConstraintId = u32;
pub const max_constraints_per_table: usize = 64;

fn validateName(id: ConstraintId, name: []const u8) !void {
    if (id == 0 or name.len == 0 or name.len > 63 or !std.unicode.utf8ValidateSlice(name) or std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidConstraintName;
}

/// Immutable schema-owned integrity. The floor survives DROP CONSTRAINT, so a
/// new declaration never reuses a historical constraint identity.
pub const Integrity = struct {
    pub const json_schema_sequence_bounds = .{ .checks = max_constraints_per_table, .foreign_keys = max_constraints_per_table };
    next_id: ConstraintId = 1,
    checks: []const CheckConstraint = &.{},
    foreign_keys: []const ForeignKeyConstraint = &.{},

    pub fn empty(self: Integrity) bool {
        return self.next_id == 1 and self.checks.len == 0 and self.foreign_keys.len == 0;
    }
    pub fn validate(self: Integrity, schema: s.Schema) !void {
        if (self.next_id == 0 or self.checks.len + self.foreign_keys.len > max_constraints_per_table) return error.InvalidConstraintCount;
        for (self.checks, 0..) |check, i| {
            if (check.id >= self.next_id) return error.InvalidConstraintIdentity;
            try check.validateShape(schema);
            for (self.checks[0..i]) |previous| try distinct(check.id, check.name, previous.id, previous.name);
        }
        for (self.foreign_keys, 0..) |fk, i| {
            if (fk.id >= self.next_id) return error.InvalidConstraintIdentity;
            try fk.validateShape(schema);
            try fk.checkWriteAdmission(false);
            const target = fk.target_definition orelse return error.ForeignKeyDefinitionRequired;
            try target.validate();
            if (target.object.object != fk.target_object or target.object.branch != 1) return error.ForeignKeyTargetMismatch;
            // One acceptance guard covers the dependent and at most four
            // distinct parent objects and their namespaces.
            var distinct_targets: usize = 0;
            for (self.foreign_keys[0 .. i + 1], 0..) |candidate, at| {
                var seen = false;
                for (self.foreign_keys[0..at]) |earlier| if (earlier.target_object == candidate.target_object) {
                    seen = true;
                    break;
                };
                if (!seen) distinct_targets += 1;
            }
            if (distinct_targets > 4) return error.ForeignKeySourceLimit;
            for (self.foreign_keys[0..i]) |previous| try distinct(fk.id, fk.name, previous.id, previous.name);
            for (self.checks) |check| try distinct(fk.id, fk.name, check.id, check.name);
        }
    }
    fn distinct(id: ConstraintId, name: []const u8, other_id: ConstraintId, other_name: []const u8) !void {
        if (id == other_id) return error.DuplicateConstraintIdentity;
        if (std.mem.eql(u8, name, other_name)) return error.DuplicateConstraintName;
    }
    pub fn enforce(self: Integrity, schema: s.Schema, cells: []const v.Cell, failure: ?*CheckViolation) !void {
        // NOT VALID skips only the existing-row validation scan. New writes
        // always execute every CHECK after assignment/default resolution.
        for (self.checks) |check| try evaluateBoundCheckRow(schema, check, cells, failure);
        for (self.foreign_keys) |fk| try fk.checkWriteAdmission(false);
    }
    /// The caller has already validated schema, descriptors and row shape.
    pub fn validateExisting(self: Integrity, schema: s.Schema, cells: []const v.Cell, failure: ?*CheckViolation) !void {
        for (self.checks) |check| if (check.validated) try evaluateBoundCheckRow(schema, check, cells, failure);
    }
    /// Returns whether an existing-row validation is required. Descriptors
    /// retain identity only while their meaning is unchanged.
    pub fn evolution(before: Integrity, after: Integrity) !bool {
        if (after.next_id < before.next_id) return error.ReusedConstraintIdentity;
        var scan = false;
        for (after.checks) |check| {
            var found = false;
            for (before.checks) |old| if (old.id == check.id) {
                found = true;
                if (!sameCheck(old, check) or (old.validated and !check.validated)) return error.ReusedConstraintIdentity;
                if (!old.validated and check.validated) scan = true;
                break;
            };
            if (!found) {
                if (check.id < before.next_id) return error.ReusedConstraintIdentity;
                if (check.validated) scan = true;
            }
        }
        for (after.foreign_keys) |fk| {
            var found = false;
            for (before.foreign_keys) |old| if (old.id == fk.id) {
                found = true;
                if (!std.mem.eql(u8, old.name, fk.name) or old.target_object != fk.target_object or old.target_revision != fk.target_revision or !std.meta.eql(old.target_definition, fk.target_definition) or
                    !std.mem.eql(s.ColumnId, old.local_columns, fk.local_columns) or !std.mem.eql(s.ColumnId, old.target_columns, fk.target_columns) or
                    old.on_delete != fk.on_delete or old.on_update != fk.on_update or old.enforcement != fk.enforcement) return error.ReusedConstraintIdentity;
                break;
            };
            if (!found and fk.id < before.next_id) return error.ReusedConstraintIdentity;
        }
        return scan;
    }
    fn sameCheck(a: CheckConstraint, b: CheckConstraint) bool {
        if (!std.mem.eql(u8, a.name, b.name) or a.atoms.len != b.atoms.len) return false;
        for (a.atoms, b.atoms) |left, right| {
            if (std.meta.activeTag(left) != std.meta.activeTag(right)) return false;
            switch (left) {
                .compare_literal => |l| {
                    const r = right.compare_literal;
                    if (l.column != r.column or l.op != r.op or std.meta.activeTag(l.literal) != std.meta.activeTag(r.literal)) return false;
                    if (l.literal == .bytes) {
                        if (!std.mem.eql(u8, l.literal.bytes, r.literal.bytes)) return false;
                    } else if (!std.meta.eql(l.literal, r.literal)) return false;
                },
                .compare_columns => |l| if (!std.meta.eql(l, right.compare_columns)) return false,
                .is_null => |id| if (id != right.is_null) return false,
                .is_not_null => |id| if (id != right.is_not_null) return false,
            }
        }
        return true;
    }
    pub fn write(self: Integrity, schema: s.Schema, writer: *std.Io.Writer) !void {
        try writer.writeInt(u32, self.next_id, .little);
        try writer.writeByte(@intCast(self.checks.len));
        var value: [s.max_bytes]u8 = undefined;
        for (self.checks) |check| {
            try writeName(writer, check.id, check.name);
            try writer.writeByte(@intFromBool(check.validated));
            try writer.writeByte(@intCast(check.atoms.len));
            for (check.atoms) |atom| switch (atom) {
                .compare_literal => |cmp| {
                    try writer.writeByte(1);
                    try writer.writeInt(u64, cmp.column, .little);
                    try writer.writeByte(@backingInt(cmp.op));
                    const column = schema.columns[try schema.index(cmp.column)];
                    const bytes = t.Codec.encode(.{ .value = .{ .atom = cmp.literal } }, column.field(), &value) catch |err| return if (err == error.WriteFailed) error.TableSchemaTooLarge else err;
                    try writer.writeInt(u32, @intCast(bytes.len), .little);
                    try writer.writeAll(bytes);
                },
                .compare_columns => |cmp| {
                    try writer.writeByte(2);
                    try writer.writeInt(u64, cmp.left_column, .little);
                    try writer.writeByte(@backingInt(cmp.op));
                    try writer.writeInt(u64, cmp.right_column, .little);
                },
                .is_null, .is_not_null => |id, tag| {
                    try writer.writeByte(if (tag == .is_null) 3 else 4);
                    try writer.writeInt(u64, id, .little);
                },
            };
        }
        try writer.writeByte(@intCast(self.foreign_keys.len));
        for (self.foreign_keys) |fk| {
            try writeName(writer, fk.id, fk.name);
            try writer.writeInt(u64, fk.target_object, .little);
            try writer.writeInt(u64, fk.target_revision, .little);
            const target = fk.target_definition.?;
            for ([_]u64{ target.object.scope.realm, target.object.scope.resource, target.object.scope.catalog, target.object.branch, target.object.object, target.revision }) |part| try writer.writeInt(u64, part, .little);
            try writer.writeAll(&target.digest);
            try writer.writeByte(@backingInt(fk.on_delete));
            try writer.writeByte(@backingInt(fk.on_update));
            try writer.writeByte(@backingInt(fk.enforcement));
            try writer.writeByte(@intCast(fk.local_columns.len));
            for (fk.local_columns, fk.target_columns) |local, remote_column| {
                try writer.writeInt(u64, local, .little);
                try writer.writeInt(u64, remote_column, .little);
            }
        }
    }
    fn writeName(writer: *std.Io.Writer, id: ConstraintId, name: []const u8) !void {
        try writer.writeInt(u32, id, .little);
        try writer.writeByte(@intCast(name.len));
        try writer.writeAll(name);
    }
    pub fn read(a: std.mem.Allocator, schema: s.Schema, reader: *std.Io.Reader) !Integrity {
        var out: Integrity = .{ .next_id = try reader.takeInt(u32, .little) };
        const count = try reader.takeByte();
        if (count > max_constraints_per_table) return error.InvalidConstraintCount;
        const checks = try a.alloc(CheckConstraint, count);
        for (checks) |*check| {
            const id = try reader.takeInt(u32, .little);
            const name = try a.dupe(u8, try reader.take(try reader.takeByte()));
            const validated = switch (try reader.takeByte()) {
                0 => false,
                1 => true,
                else => return error.InvalidTableSchemaEncoding,
            };
            const atoms_count = try reader.takeByte();
            if (atoms_count == 0 or atoms_count > 32) return error.InvalidCheckConstraint;
            const atoms = try a.alloc(CheckAtom, atoms_count);
            for (atoms) |*atom| {
                const tag = try reader.takeByte();
                const column_id = try reader.takeInt(u64, .little);
                atom.* = switch (tag) {
                    1 => blk: {
                        const op = try comparison(reader);
                        const size = try reader.takeInt(u32, .little);
                        if (size > s.max_bytes) return error.TableSchemaTooLarge;
                        const decoded = try t.Codec.decode(a, try reader.take(size));
                        const column = schema.columns[try schema.index(column_id)];
                        if (decoded.cell != .value or decoded.cell.value != .atom or !try decoded.field.type.eql(column.type) or decoded.field.nullable != column.nullable or decoded.field.optional) return error.InvalidCheckConstraint;
                        break :blk .{ .compare_literal = .{ .column = column_id, .op = op, .literal = decoded.cell.value.atom } };
                    },
                    2 => .{ .compare_columns = .{ .left_column = column_id, .op = try comparison(reader), .right_column = try reader.takeInt(u64, .little) } },
                    3 => .{ .is_null = column_id },
                    4 => .{ .is_not_null = column_id },
                    else => return error.InvalidCheckConstraint,
                };
            }
            check.* = .{ .id = id, .name = name, .validated = validated, .atoms = atoms };
        }
        out.checks = checks;
        const foreign_count = try reader.takeByte();
        if (@as(usize, count) + foreign_count > max_constraints_per_table) return error.InvalidConstraintCount;
        const foreign_keys = try a.alloc(ForeignKeyConstraint, foreign_count);
        for (foreign_keys) |*fk| {
            const id = try reader.takeInt(u32, .little);
            const name = try a.dupe(u8, try reader.take(try reader.takeByte()));
            const object = try reader.takeInt(u64, .little);
            const revision = try reader.takeInt(u64, .little);
            const target_definition: Definition = .{ .object = .{ .scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) }, .branch = try reader.takeInt(u64, .little), .object = try reader.takeInt(u64, .little) }, .revision = try reader.takeInt(u64, .little), .digest = (try reader.take(32))[0..32].* };
            const on_delete = std.enums.fromInt(ReferentialAction, try reader.takeByte()) orelse return error.InvalidForeignKeyAction;
            const on_update = std.enums.fromInt(ReferentialAction, try reader.takeByte()) orelse return error.InvalidForeignKeyAction;
            const enforcement = std.enums.fromInt(ForeignKeyEnforcement, try reader.takeByte()) orelse return error.InvalidForeignKeyEnforcement;
            const columns_count = try reader.takeByte();
            if (columns_count == 0 or columns_count > s.max_columns) return error.InvalidForeignKeyArity;
            const local = try a.alloc(s.ColumnId, columns_count);
            const target = try a.alloc(s.ColumnId, columns_count);
            for (local, target) |*l, *r| {
                l.* = try reader.takeInt(u64, .little);
                r.* = try reader.takeInt(u64, .little);
            }
            fk.* = .{ .id = id, .name = name, .target_object = object, .target_revision = revision, .target_definition = target_definition, .local_columns = local, .target_columns = target, .on_delete = on_delete, .on_update = on_update, .enforcement = enforcement };
        }
        out.foreign_keys = foreign_keys;
        try out.validate(schema);
        return out;
    }
    fn comparison(reader: *std.Io.Reader) !std.math.CompareOperator {
        return std.enums.fromInt(std.math.CompareOperator, try reader.takeByte()) orelse error.InvalidCheckConstraint;
    }
};

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
    pub const json_schema_sequence_bounds = .{ .atoms = 32 };
    id: ConstraintId,
    name: []const u8,
    atoms: []const CheckAtom,
    validated: bool = true,

    pub fn validate(self: CheckConstraint, schema: s.Schema) !void {
        try schema.validate();
        try self.validateShape(schema);
    }

    /// Schema validation calls this without recursively validating the schema.
    pub fn validateShape(self: CheckConstraint, schema: s.Schema) !void {
        _ = try self.traits(schema);
    }
    pub fn traits(self: CheckConstraint, schema: s.Schema) !@import("OperatorTraits.zig").Summary {
        return @import("OperatorTraits.zig").forCheck(schema, self);
    }
    /// Shape-only entry used by trait derivation without recursive schema checks.
    pub fn validateExpression(self: CheckConstraint, schema: s.Schema) !void {
        try validateName(self.id, self.name);
        if (self.atoms.len == 0 or self.atoms.len > 32) return error.InvalidCheckConstraint;
        for (self.atoms) |atom| switch (atom) {
            .compare_literal => |cmp| {
                const idx = try schema.index(cmp.column);
                const col = schema.columns[idx];
                try t.Semantics.validate(cmp.literal, col.type);
                _ = try Collation.compareAtom(cmp.literal, cmp.literal, col.type, col.collation);
            },
            .compare_columns => |cmp| {
                const l_idx = try schema.index(cmp.left_column);
                const r_idx = try schema.index(cmp.right_column);
                const l_col = schema.columns[l_idx];
                const r_col = schema.columns[r_idx];
                if (!s.keyType(l_col.type)) return error.UnsupportedCheckExpression;
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
    return evaluateBoundCheckRow(schema, constraint, row_cells, violation_out);
}
fn evaluateBoundCheckRow(schema: s.Schema, constraint: CheckConstraint, row_cells: []const v.Cell, violation_out: ?*CheckViolation) !void {
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
                        .missing, .type_error, .conflict => |_, tag| {
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
    pub const json_schema_sequence_bounds = .{ .local_columns = s.max_columns, .target_columns = s.max_columns };
    id: ConstraintId,
    name: []const u8,
    local_columns: []const s.ColumnId,
    target_object: u64,
    target_revision: u64,
    target_definition: ?Definition = null,
    target_columns: []const s.ColumnId,
    on_delete: ReferentialAction = .restrict,
    on_update: ReferentialAction = .restrict,
    enforcement: ForeignKeyEnforcement = .staged_awaiting_index,

    pub fn validateShape(self: ForeignKeyConstraint, child_schema: s.Schema) !void {
        try validateName(self.id, self.name);
        if (self.target_object == 0 or self.target_revision == 0) return error.ForeignKeyTargetMismatch;
        if (self.local_columns.len == 0 or self.local_columns.len > s.max_columns or self.local_columns.len != self.target_columns.len) return error.InvalidForeignKeyArity;
        for (self.local_columns, self.target_columns, 0..) |local_id, target_id, i| {
            const child_col = child_schema.columns[try child_schema.index(local_id)];
            if (target_id == 0) return error.InvalidColumnIdentity;
            for (self.local_columns[0..i]) |previous| if (previous == local_id) return error.DuplicateForeignKeyColumn;
            for (self.target_columns[0..i]) |previous| if (previous == target_id) return error.DuplicateForeignKeyColumn;
            if ((self.on_delete == .set_null or self.on_update == .set_null) and !child_col.nullable) return error.ForeignKeySetNullRequiresNullableColumn;
        }
    }

    pub fn validateAgainstSchemas(self: ForeignKeyConstraint, child_schema: s.Schema, parent_schema: s.Schema) !void {
        try child_schema.validate();
        try parent_schema.validate();
        try self.validateShape(child_schema);
        if (self.local_columns.len == 0 or self.local_columns.len != self.target_columns.len) {
            return error.InvalidForeignKeyArity;
        }
        if (parent_schema.object != self.target_object or parent_schema.revision != self.target_revision) return error.ForeignKeyTargetMismatch;
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
        .add, .rename, .default, .integrity => {},
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
    target_definition: ?Definition = null,
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
