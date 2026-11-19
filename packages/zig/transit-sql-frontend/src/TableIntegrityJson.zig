//! Neutral integrity descriptors. Stable object/column/revision identities are
//! decimal strings; CHECK literals use the shared five-state logical codec.
const std = @import("std");
const c = @import("TableConstraints.zig");
const s = @import("TableSchema.zig");
const j = @import("LogicalJson.zig");
const n = @import("NeutralEncoding.zig");

pub const Atom = union(enum) {
    compare_literal: struct { column: []const u8, op: std.math.CompareOperator, literal: j.Cell },
    compare_columns: struct { left_column: []const u8, op: std.math.CompareOperator, right_column: []const u8 },
    is_not_null: []const u8,
    is_null: []const u8,
};
pub const Check = struct {
    pub const json_schema_sequence_bounds = .{ .atoms = 32 };
    id: c.ConstraintId,
    name: []const u8,
    atoms: []const Atom,
    validated: bool,
};
pub const Definition = struct {
    realm: []const u8,
    resource: []const u8,
    catalog: []const u8,
    branch: []const u8,
    object: []const u8,
    revision: []const u8,
    digest: []const u8,
    fn foreign(a: std.mem.Allocator, value: @import("transit_protocol").DataLifecycle.Definition) !Definition {
        return .{ .realm = try n.decimal(a, value.object.scope.realm), .resource = try n.decimal(a, value.object.scope.resource), .catalog = try n.decimal(a, value.object.scope.catalog), .branch = try n.decimal(a, value.object.branch), .object = try n.decimal(a, value.object.object), .revision = try n.decimal(a, value.revision), .digest = try a.dupe(u8, &std.fmt.bytesToHex(&value.digest, .lower)) };
    }
    fn native(self: Definition) !@import("transit_protocol").DataLifecycle.Definition {
        if (self.digest.len != 64) return error.ForeignKeyTargetMismatch;
        var digest: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&digest, self.digest) catch return error.ForeignKeyTargetMismatch;
        if (!std.mem.eql(u8, self.digest, &std.fmt.bytesToHex(&digest, .lower))) return error.ForeignKeyTargetMismatch;
        return .{ .object = .{ .scope = .{ .realm = try n.unsigned(self.realm), .resource = try n.unsigned(self.resource), .catalog = try n.unsigned(self.catalog) }, .branch = try n.unsigned(self.branch), .object = try n.unsigned(self.object) }, .revision = try n.unsigned(self.revision), .digest = digest };
    }
};
pub const ForeignKey = struct {
    pub const json_schema_sequence_bounds = .{ .local_columns = s.max_columns, .target_columns = s.max_columns };
    id: c.ConstraintId,
    name: []const u8,
    local_columns: []const []const u8,
    target_object: []const u8,
    target_revision: []const u8,
    target_definition: Definition,
    target_columns: []const []const u8,
    on_delete: c.ReferentialAction,
    on_update: c.ReferentialAction,
    enforcement: c.ForeignKeyEnforcement,
};
pub const Integrity = struct {
    pub const json_schema_sequence_bounds = .{ .checks = c.max_constraints_per_table, .foreign_keys = c.max_constraints_per_table };
    next_id: c.ConstraintId = 1,
    checks: []const Check = &.{},
    foreign_keys: []const ForeignKey = &.{},
};

/// The caller supplies an enclosing arena, released as one operation/result.
pub fn foreign(a: std.mem.Allocator, schema: s.Schema) !Integrity {
    const value = schema.integrity;
    const checks = try a.alloc(Check, value.checks.len);
    for (checks, value.checks) |*out, check| {
        const atoms = try a.alloc(Atom, check.atoms.len);
        for (atoms, check.atoms) |*atom, input| atom.* = switch (input) {
            .compare_literal => |cmp| .{ .compare_literal = .{ .column = try n.decimal(a, cmp.column), .op = cmp.op, .literal = try j.foreignCell(a, .{ .value = .{ .atom = cmp.literal } }, schema.columns[try schema.index(cmp.column)].type) } },
            .compare_columns => |cmp| .{ .compare_columns = .{ .left_column = try n.decimal(a, cmp.left_column), .op = cmp.op, .right_column = try n.decimal(a, cmp.right_column) } },
            .is_null => |id| .{ .is_null = try n.decimal(a, id) },
            .is_not_null => |id| .{ .is_not_null = try n.decimal(a, id) },
        };
        out.* = .{ .id = check.id, .name = try a.dupe(u8, check.name), .atoms = atoms, .validated = check.validated };
    }
    const foreign_keys = try a.alloc(ForeignKey, value.foreign_keys.len);
    for (foreign_keys, value.foreign_keys) |*out, fk| out.* = .{
        .id = fk.id,
        .name = try a.dupe(u8, fk.name),
        .local_columns = try foreignColumns(a, fk.local_columns),
        .target_object = try n.decimal(a, fk.target_object),
        .target_revision = try n.decimal(a, fk.target_revision),
        .target_definition = try Definition.foreign(a, fk.target_definition.?),
        .target_columns = try foreignColumns(a, fk.target_columns),
        .on_delete = fk.on_delete,
        .on_update = fk.on_update,
        .enforcement = fk.enforcement,
    };
    return .{ .next_id = value.next_id, .checks = checks, .foreign_keys = foreign_keys };
}
fn foreignColumns(a: std.mem.Allocator, columns: []const s.ColumnId) ![]const []const u8 {
    const out = try a.alloc([]const u8, columns.len);
    for (out, columns) |*item, id| item.* = try n.decimal(a, id);
    return out;
}
fn nativeColumns(a: std.mem.Allocator, columns: []const []const u8) ![]const s.ColumnId {
    if (columns.len > s.max_columns) return error.InvalidForeignKeyArity;
    const out = try a.alloc(s.ColumnId, columns.len);
    for (out, columns) |*item, id| item.* = try n.unsigned(id);
    return out;
}
pub fn native(a: std.mem.Allocator, value: Integrity, schema: s.Schema) !c.Integrity {
    if (value.checks.len + value.foreign_keys.len > c.max_constraints_per_table) return error.InvalidConstraintCount;
    const checks = try a.alloc(c.CheckConstraint, value.checks.len);
    for (checks, value.checks) |*out, check| {
        if (check.atoms.len == 0 or check.atoms.len > 32) return error.InvalidCheckConstraint;
        const atoms = try a.alloc(c.CheckAtom, check.atoms.len);
        for (atoms, check.atoms) |*atom, input| atom.* = switch (input) {
            .compare_literal => |cmp| blk: {
                const id = try n.unsigned(cmp.column);
                const column = schema.columns[try schema.index(id)];
                const literal = try j.fromForeign(a, cmp.literal, column.field());
                if (literal != .value or literal.value != .atom) return error.InvalidCheckConstraint;
                break :blk .{ .compare_literal = .{ .column = id, .op = cmp.op, .literal = literal.value.atom } };
            },
            .compare_columns => |cmp| .{ .compare_columns = .{ .left_column = try n.unsigned(cmp.left_column), .op = cmp.op, .right_column = try n.unsigned(cmp.right_column) } },
            .is_null => |id| .{ .is_null = try n.unsigned(id) },
            .is_not_null => |id| .{ .is_not_null = try n.unsigned(id) },
        };
        out.* = .{ .id = check.id, .name = check.name, .atoms = atoms, .validated = check.validated };
    }
    const foreign_keys = try a.alloc(c.ForeignKeyConstraint, value.foreign_keys.len);
    for (foreign_keys, value.foreign_keys) |*out, fk| out.* = .{
        .id = fk.id,
        .name = fk.name,
        .local_columns = try nativeColumns(a, fk.local_columns),
        .target_object = try n.unsigned(fk.target_object),
        .target_revision = try n.unsigned(fk.target_revision),
        .target_definition = try fk.target_definition.native(),
        .target_columns = try nativeColumns(a, fk.target_columns),
        .on_delete = fk.on_delete,
        .on_update = fk.on_update,
        .enforcement = fk.enforcement,
    };
    const out: c.Integrity = .{ .next_id = value.next_id, .checks = checks, .foreign_keys = foreign_keys };
    try out.validate(schema);
    return out;
}
