//! Value-owned comparison semantics, separate from logical types and codecs.
//! The fixed workspace follows the logical row's 128-column admission bound.
const std = @import("std");
const t = @import("Types.zig");
const s = @import("TableSchema.zig");
const c = @import("Collation.zig");
const Self = @This();
columns: [s.max_columns]s.Collation = @splat(.none),

/// The caller has validated the complete Table schema.
pub fn fromTable(schema: s.Schema) Self {
    var result: Self = .{};
    for (schema.columns, 0..) |column, i| result.columns[i] = column.collation;
    return result;
}
pub fn fromSlice(schema: t.Type, columns: []const s.Collation) !Self {
    if (schema != .structure or columns.len != schema.structure.len or columns.len > s.max_columns) return error.InvalidQueryCollations;
    var result: Self = .{};
    @memcpy(result.columns[0..columns.len], columns);
    try result.validate(schema);
    return result;
}
pub fn validate(self: Self, schema: t.Type) !void {
    if (schema != .structure or schema.structure.len > s.max_columns) return error.InvalidQuerySchema;
    for (schema.structure, self.columns[0..schema.structure.len]) |field, collation| {
        try c.validate(collation);
        if (collation != .none and field.type != .utf8) return error.IncompatibleColumnCollation;
    }
    for (self.columns[schema.structure.len..]) |collation| if (collation != .none) return error.InvalidQueryCollations;
}
pub fn validateCells(self: Self, cells: []const t.Values.Cell) !void {
    if (cells.len > s.max_columns) return error.InvalidRowWidth;
    for (cells, self.columns[0..cells.len]) |cell, collation| {
        if (collation == .ebcdic_cp037 and cell == .value) try c.validateBytes(cell.value.atom.bytes, collation);
    }
}
pub fn write(self: Self, schema: t.Type, writer: *std.Io.Writer) !void {
    try self.validate(schema);
    for (self.columns[0..schema.structure.len]) |collation| try writer.writeByte(@backingInt(collation));
}
pub fn read(schema: t.Type, reader: *std.Io.Reader) !Self {
    if (schema != .structure or schema.structure.len > s.max_columns) return error.InvalidQuerySchema;
    var result: Self = .{};
    for (result.columns[0..schema.structure.len]) |*collation| {
        collation.* = std.enums.fromInt(s.Collation, try reader.takeByte()) orelse return error.InvalidQueryCollations;
    }
    try result.validate(schema);
    return result;
}
