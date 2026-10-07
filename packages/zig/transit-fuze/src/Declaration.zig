//! Pure KV/Document definition validation and review formatting. No catalog authority,
//! durable identity, storage, credential resolution or provisioning side effects.
const std = @import("std");
const sql = @import("Sql.zig");
const m = @import("model.zig");
pub const Body = union(enum) { kv: m.Type, document };
pub const Definition = struct {
    name: m.Name,
    body: Body,

    /// Typed callers and SQL share validation, including canonical owned names.
    pub fn validate(self: Definition) !void {
        try validName(self.name);
    }

    /// Canonical SQL for review, borrowing the caller's buffer. Reparse to a
    /// definition; this text is not a saved administrative command or authority.
    /// On failure discard the buffer; no partial formatted result is returned.
    pub fn format(self: Definition, output: []u8) ![]const u8 {
        try self.validate();
        var writer = std.Io.Writer.fixed(output);
        try writer.writeAll("CREATE ");
        try writer.writeAll(switch (self.body) {
            .kv => "KV ",
            .document => "DOCUMENT ",
        });
        try writeName(&writer, self.name);
        switch (self.body) {
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
pub fn compileDiagnostic(text: []const u8, binding: ?*sql.Binding) !Definition {
    if (binding) |detail| detail.* = .{};
    var location: sql.Location = .{};
    const definition = (sql.parseDeclarationLocated(text, &location) catch |err| {
        if (binding) |detail| detail.location = location;
        return err;
    }) orelse return error.UnsupportedStatement;
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
