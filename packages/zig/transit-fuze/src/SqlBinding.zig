//! Optional owned compiler failure context. Never a wire value or authority.
const std = @import("std");
const sql = @import("Sql.zig");
pub const Name = struct {
    bytes: [255]u8 = @splat(0),
    len: u8 = 0,
    pub fn init(text: []const u8) !Name {
        if (text.len == 0 or text.len > 255 or !std.unicode.utf8ValidateSlice(text) or std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidColumnName;
        var name: Name = .{ .len = @intCast(text.len) };
        @memcpy(name.bytes[0..text.len], text);
        return name;
    }
    pub fn slice(self: *const Name) []const u8 {
        return self.bytes[0..self.len];
    }
};
const Self = @This();
location: ?sql.Location = null,
subject: ?Name = null,
expected: ?[]const u8 = null,
actual: ?[]const u8 = null,
key: ?i64 = null,
input_row: ?usize = null,
previous_row: ?usize = null,
parameter: ?u32 = null,
missing_parameter: ?u32 = null,
parameter_sites: [3]?usize = @splat(null),
expected_count: ?usize = null,
actual_count: ?usize = null,
expected_schema: ?[32]u8 = null,
actual_schema: ?[32]u8 = null,
schema_version: ?u8 = null,
scope: [255]u8 = @splat(0),
scope_len: usize = 0,
literal: [192]u8 = @splat(0),
literal_len: usize = 0,
literal_truncated: bool = false,

pub fn parameterAt(self: ?*Self, sites: sql.ParameterSites, index: u32) void {
    const value = self orelse return;
    value.parameter = index;
    value.parameter_sites = @splat(null);
    var count: usize = 0;
    inline for (comptime std.meta.fieldNames(sql.ParameterSites)) |field| {
        if (@field(sites, field)) |site| if (site.index == index) {
            value.parameter_sites[count] = site.offset;
            count += 1;
        };
    }
    // Site fields follow grammar roles; display occurrences in source order.
    if (count != 0) {
        for (0..count) |i| for (i + 1..count) |j| {
            if (value.parameter_sites[i].? > value.parameter_sites[j].?) std.mem.swap(?usize, &value.parameter_sites[i], &value.parameter_sites[j]);
        };
        value.location = .{ .offset = value.parameter_sites[0].? };
    }
}

pub fn at(self: ?*Self, column: sql.Column, scope: []const u8) void {
    const value = self orelse return;
    value.subject = Name.init(column.name.slice()) catch null;
    value.location = if (column.offset) |offset| .{ .offset = offset } else null;
    value.scope_len = @min(scope.len, value.scope.len);
    @memcpy(value.scope[0..value.scope_len], scope[0..value.scope_len]);
}

pub fn atError(self: ?*Self, column: sql.Column, scope: []const u8, cause: anyerror) void {
    at(self, column, scope);
    if (self) |value| if (cause == error.UnknownQualifier) {
        value.subject = if (column.qualifier) |qualifier| Name.init(qualifier.slice()) catch null else null;
    };
}

/// A logical binder records the failing token offset. Recover only that caller
/// identifier, without lookup, allocation or guessing from a later parser token.
pub fn nameFailure(self: ?*Self, text: []const u8, scope: []const u8, cause: anyerror, location: sql.Location) void {
    const detail = self orelse return;
    switch (cause) {
        error.UnknownColumn, error.UnknownQualifier, error.UnknownSource => {},
        else => return,
    }
    if (detail.subject != null or location.offset >= text.len) return;
    var lexer: sql.Lexer = .{ .text = text, .position = location.offset, .parameters_enabled = true };
    const token = lexer.next() catch return;
    if (lexer.start != location.offset or (token.tag != .word and token.tag != .quoted)) return;
    var bytes: [255]u8 = undefined;
    var count: usize = 0;
    const raw = if (token.tag == .quoted) token.text[1 .. token.text.len - 1] else token.text;
    var index: usize = 0;
    while (index < raw.len) : (index += 1) {
        if (count == bytes.len) return;
        bytes[count] = if (token.tag == .quoted) raw[index] else std.ascii.toLower(raw[index]);
        count += 1;
        if (token.tag == .quoted and raw[index] == '"') {
            if (index + 1 == raw.len or raw[index + 1] != '"') return;
            index += 1;
        }
    }
    detail.subject = Name.init(bytes[0..count]) catch return;
    detail.scope_len = @min(scope.len, detail.scope.len);
    while (!std.unicode.utf8ValidateSlice(scope[0..detail.scope_len])) detail.scope_len -= 1;
    @memcpy(detail.scope[0..detail.scope_len], scope[0..detail.scope_len]);
    detail.location = location;
}

/// Caller-supplied scalar correction context, bounded and inert. No stored row
/// values or credentials are fetched to enrich a compilation failure.
pub fn supplied(self: ?*Self, value: anytype) void {
    const detail = self orelse return;
    detail.literal_truncated = false;
    var out: std.Io.Writer = .fixed(&detail.literal);
    switch (value) {
        inline .int64, .uint64 => |number| out.print("{d}", .{number}) catch unreachable,
        .float64 => |number| out.print("{e}", .{number}) catch unreachable,
        .boolean => |boolean| out.writeAll(if (boolean) "TRUE" else "FALSE") catch unreachable,
        .utf8, .binary => |bytes| {
            out.writeByte('"') catch unreachable;
            for (bytes[0..@min(bytes.len, 32)]) |byte| switch (byte) {
                '"', '\\' => {
                    out.writeByte('\\') catch unreachable;
                    out.writeByte(byte) catch unreachable;
                },
                0x20...0x21, 0x23...0x5b, 0x5d...0x7e => out.writeByte(byte) catch unreachable,
                else => out.print("\\x{x:0>2}", .{byte}) catch unreachable,
            };
            out.writeByte('"') catch unreachable;
            detail.literal_truncated = bytes.len > 32;
            if (detail.literal_truncated) out.writeAll(" [truncated after 32 bytes]") catch unreachable;
        },
    }
    detail.literal_len = out.end;
}

/// Scalar evidence for INSERT/UPDATE/DELETE uses the same bound as parameters.
pub fn literalValue(self: ?*Self, value: sql.Literal) void {
    const detail = self orelse return;
    detail.actual = @tagName(value);
    switch (value) {
        .null => {
            detail.literal = @splat(0);
            @memcpy(detail.literal[0..4], "NULL");
            detail.literal_len = 4;
            detail.literal_truncated = false;
        },
        inline .utf8, .binary => |text, tag| supplied(self, @unionInit(@import("Unified.zig").Scalar, @tagName(tag), text.slice())),
        inline else => |scalar, tag| supplied(self, @unionInit(@import("Unified.zig").Scalar, @tagName(tag), scalar)),
    }
}
