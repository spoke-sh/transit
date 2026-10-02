//! Typed, allocation-free Table mutation plans. No I/O, authority or execution.
const std = @import("std");
/// Witness from the rejecting private execution, never a subsequent lookup.
/// `row` is the one-based position in the submitted INSERT.
pub const Conflict = struct { key: i64, row: u8 };
const sql = @import("Sql.zig");
const m = @import("model.zig");
pub const max_rows = sql.max_mutation_rows;
pub const Target = struct { name: m.Name, schema: m.Schema };
pub const Operation = union(enum) { insert: [max_rows]?m.Row, update: m.Row, delete: i64 };
pub const Plan = struct {
    schema: m.Schema,
    operation: Operation,

    /// Typed callers receive the same bounds, duplicate and type checks as SQL.
    pub fn validate(self: Plan) !void {
        try self.schema.validate();
        switch (self.operation) {
            .insert => |rows| {
                if (rows[0] == null) return error.InvalidMutationPlan;
                var ended = false;
                for (rows, 0..) |slot, index| {
                    if (slot) |row| {
                        if (ended) return error.InvalidMutationPlan;
                        try row.value.validate(self.schema.value_type);
                        for (rows[0..index]) |previous| if (previous.?.key == row.key) return error.DuplicateMutationKey;
                    } else ended = true;
                }
            },
            .update => |row| try row.value.validate(self.schema.value_type),
            .delete => {},
        }
    }
};

pub fn compile(text: []const u8, target: Target) !Plan {
    return lower((try sql.parseMutation(text)) orelse return error.UnsupportedStatement, target);
}

pub fn lower(ast: sql.Mutation, target: Target) !Plan {
    try target.schema.validate();
    try validName(target.name);
    try validName(ast.source);
    if (!sameName(ast.source, target.name)) return error.UnknownSource;
    const operation: Operation = switch (ast.operation) {
        .insert => |value| blk: {
            const first = try column(.{ .name = value.columns[0] }, target);
            const second = try column(.{ .name = value.columns[1] }, target);
            if (first == second) return error.DuplicateColumn;
            var rows: [max_rows]?m.Row = @splat(null);
            for (value.rows, 0..) |slot, index| if (slot) |pair| {
                rows[index] = .{ .key = try primaryKey(pair[first]), .value = try sql.literalCell(pair[second]) };
            };
            break :blk .{ .insert = rows };
        },
        .update => |value| blk: {
            if (try column(value.column, target) != 1) return error.ImmutablePrimaryKey;
            if (try column(value.key.column, target) != 0) return error.UnsupportedMutationPredicate;
            break :blk .{ .update = .{ .key = try primaryKey(value.key.literal), .value = try sql.literalCell(value.literal) } };
        },
        .delete => |value| blk: {
            if (try column(value.column, target) != 0) return error.UnsupportedMutationPredicate;
            break :blk .{ .delete = try primaryKey(value.literal) };
        },
    };
    const result: Plan = .{ .schema = target.schema, .operation = operation };
    try result.validate();
    return result;
}

fn validName(name: m.Name) !void {
    if (name.len > name.bytes.len) return error.InvalidColumnName;
    if (!std.meta.eql(name, try m.Name.init(name.slice()))) return error.InvalidColumnName;
}
fn sameName(first: m.Name, second: m.Name) bool {
    return std.mem.eql(u8, first.slice(), second.slice());
}
fn column(value: sql.Column, target: Target) !usize {
    try validName(value.name);
    if (value.qualifier) |qualifier| {
        try validName(qualifier);
        if (!sameName(qualifier, target.name)) return error.UnknownQualifier;
    }
    for (target.schema.names, 0..) |name, index| if (sameName(name, value.name)) return index;
    return error.UnknownColumn;
}
fn primaryKey(literal: sql.Literal) !i64 {
    return switch (literal) {
        .int64 => |value| value,
        .null => error.NullPrimaryKey,
        else => error.TypeMismatch,
    };
}
