//! Pure state definition validation and review formatting. No catalog authority,
//! durable identity, storage, credential resolution or provisioning side effects.
const std = @import("std");
const sql = @import("Sql.zig");
const m = @import("model.zig");
pub const max_columns = @import("Unified.zig").max_columns;
pub const Nullability = enum { unspecified, null, not_null };
pub const Column = struct { name: m.Name, type: m.Type, nullability: Nullability = .unspecified };
pub const Columns = [max_columns]?Column;
pub const Body = union(enum) { table: Columns, kv: m.Type, document };
pub const Definition = struct {
    name: m.Name,
    body: Body,

    /// Typed callers and SQL share validation, including canonical owned names.
    /// The column bound is per definition, never a bound on catalog cardinality.
    pub fn validate(self: Definition) !void {
        try validName(self.name);
        switch (self.body) {
            .table => |columns| {
                if (columns[0] == null) return error.InvalidColumnCount;
                var ended = false;
                for (columns, 0..) |slot, index| {
                    if (slot) |column| {
                        if (ended) return error.InvalidColumnCount;
                        try validName(column.name);
                        for (columns[0..index]) |previous| {
                            if (std.meta.eql(column.name, previous.?.name)) return error.DuplicateColumn;
                        }
                    } else ended = true;
                }
            },
            .kv, .document => {},
        }
    }

    /// Explicit capability check for Station's existing two-column Table model.
    /// Never infer primary-key/nullability semantics from a wider declaration.
    /// The result still needs an authorized resource, writer and Table identity.
    pub fn tableSchema(self: Definition) !m.Schema {
        try self.validate();
        const columns = switch (self.body) {
            .table => |columns| columns,
            else => return error.NotTableDeclaration,
        };
        if (columns[1] == null or columns[2] != null) return error.UnsupportedTableColumnCount;
        const key = columns[0].?;
        const value = columns[1].?;
        if (key.nullability == .unspecified or value.nullability == .unspecified) return error.UnspecifiedNullability;
        if (key.type != .int64 or key.nullability != .not_null) return error.UnsupportedTableKey;
        if (value.nullability != .null) return error.UnsupportedTableNullability;
        const result: m.Schema = .{ .names = .{ key.name, value.name }, .value_type = value.type };
        try result.validate();
        return result;
    }

    /// Canonical SQL for review, borrowing the caller's buffer. Reparse to a
    /// definition; this text is not a saved administrative command or authority.
    /// On failure discard the buffer; no partial formatted result is returned.
    pub fn format(self: Definition, output: []u8) ![]const u8 {
        try self.validate();
        var writer = std.Io.Writer.fixed(output);
        try writer.writeAll("CREATE ");
        try writer.writeAll(switch (self.body) {
            .table => "TABLE ",
            .kv => "KV ",
            .document => "DOCUMENT ",
        });
        try writeName(&writer, self.name);
        switch (self.body) {
            .table => |columns| {
                try writer.writeAll(" (");
                for (columns, 0..) |slot, index| {
                    const column = slot orelse break;
                    if (index != 0) try writer.writeAll(", ");
                    try writeName(&writer, column.name);
                    try writer.writeByte(' ');
                    try writer.writeAll(typeName(column.type));
                    try writer.writeAll(switch (column.nullability) {
                        .unspecified => "",
                        .null => " NULL",
                        .not_null => " NOT NULL",
                    });
                }
                try writer.writeByte(')');
            },
            .kv => |value| {
                try writer.writeAll(" (");
                try writer.writeAll(typeName(value));
                try writer.writeByte(')');
            },
            .document => {},
        }
        try writer.writeByte(';');
        return writer.buffered();
    }
};

pub fn compile(text: []const u8) !Definition {
    const definition = (try sql.parseDeclaration(text)) orelse return error.UnsupportedStatement;
    try definition.validate();
    return definition;
}

fn validName(name: m.Name) !void {
    if (name.len > name.bytes.len) return error.InvalidColumnName;
    if (!std.meta.eql(name, try m.Name.init(name.slice()))) return error.InvalidColumnName;
}
fn writeName(writer: *std.Io.Writer, name: m.Name) !void {
    try writer.writeByte('"');
    try writer.writeAll(name.slice());
    try writer.writeByte('"');
}
fn typeName(value: m.Type) []const u8 {
    return switch (value) {
        .int64 => "INT64",
        .boolean => "BOOL",
        .utf8 => "UTF8",
        .binary => "BINARY",
    };
}
