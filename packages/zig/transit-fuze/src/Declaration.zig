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
        return self.tableSchemaDiagnostic(null);
    }
    pub fn tableSchemaDiagnostic(self: Definition, binding: ?*sql.Binding) !m.Schema {
        try self.validate();
        const columns = switch (self.body) {
            .table => |columns| columns,
            else => return error.NotTableDeclaration,
        };
        if (columns[1] == null or columns[2] != null) {
            if (binding) |detail| {
                detail.expected_count = 2;
                var count: usize = 0;
                for (columns) |column| if (column != null) {
                    count += 1;
                };
                detail.actual_count = count;
            }
            return error.UnsupportedTableColumnCount;
        }
        const key = columns[0].?;
        const value = columns[1].?;
        if (key.nullability == .unspecified or value.nullability == .unspecified) {
            columnContext(binding, self.name, if (key.nullability == .unspecified) key else value, "explicit NULL or NOT NULL", "unspecified");
            return error.UnspecifiedNullability;
        }
        if (key.type != .int64 or key.nullability != .not_null) {
            columnContext(binding, self.name, key, if (key.type != .int64) "int64" else "not_null", if (key.type != .int64) @tagName(key.type) else @tagName(key.nullability));
            return error.UnsupportedTableKey;
        }
        if (value.nullability != .null) {
            columnContext(binding, self.name, value, "null", @tagName(value.nullability));
            return error.UnsupportedTableNullability;
        }
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
    return compileDiagnostic(text, null);
}
fn columnContext(binding: ?*sql.Binding, scope: m.Name, column: Column, expected: ?[]const u8, actual: ?[]const u8) void {
    sql.Binding.at(binding, .{ .name = column.name }, scope.slice());
    if (binding) |detail| {
        detail.expected = expected;
        detail.actual = actual;
    }
}
fn compileDetailed(text: []const u8, binding: ?*sql.Binding, locations: *sql.DeclarationLocations) !Definition {
    if (binding) |detail| detail.* = .{};
    var location: sql.Location = .{};
    const definition = (sql.parseDeclarationDetailed(text, &location, locations) catch |err| {
        if (binding) |detail| detail.location = location;
        return err;
    }) orelse return error.UnsupportedStatement;
    definition.validate() catch |err| {
        if (err == error.DuplicateColumn and definition.body == .table) {
            for (definition.body.table, 0..) |slot, index| {
                const column = slot orelse break;
                for (definition.body.table[0..index]) |previous| if (std.meta.eql(previous.?.name, column.name)) {
                    columnContext(binding, definition.name, column, null, null);
                    if (binding) |detail| detail.location = .{ .offset = locations.columns[index].? };
                    return err;
                };
            }
        }
        return err;
    };
    return definition;
}
pub fn compileDiagnostic(text: []const u8, binding: ?*sql.Binding) !Definition {
    var locations: sql.DeclarationLocations = .{};
    return compileDetailed(text, binding, &locations);
}
pub fn compileTableDiagnostic(text: []const u8, binding: ?*sql.Binding) !struct { definition: Definition, schema: m.Schema } {
    var locations: sql.DeclarationLocations = .{};
    const definition = try compileDetailed(text, binding, &locations);
    const schema = definition.tableSchemaDiagnostic(binding) catch |err| {
        if (binding) |detail| if (detail.subject) |subject| {
            for (definition.body.table, 0..) |slot, index| if (slot) |column| {
                if (std.mem.eql(u8, column.name.slice(), subject.slice())) detail.location = .{ .offset = locations.columns[index].? };
            };
        };
        return err;
    };
    return .{ .definition = definition, .schema = schema };
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
