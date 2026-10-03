//! Optional owned compiler failure context. Never a wire value or authority.
const std = @import("std");
const sql = @import("Sql.zig");
const Name = @import("model.zig").Name;
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
scope: [64]u8 = @splat(0),
scope_len: usize = 0,
literal: [192]u8 = @splat(0),
literal_len: usize = 0,

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
    value.subject = column.name;
    value.location = if (column.offset) |offset| .{ .offset = offset } else null;
    value.scope_len = @min(scope.len, value.scope.len);
    @memcpy(value.scope[0..value.scope_len], scope[0..value.scope_len]);
}

pub fn atError(self: ?*Self, column: sql.Column, scope: []const u8, cause: anyerror) void {
    at(self, column, scope);
    if (self) |value| if (cause == error.UnknownQualifier) {
        value.subject = column.qualifier;
    };
}

/// Caller-supplied scalar correction context, bounded and inert. No stored row
/// values or credentials are fetched to enrich a compilation failure.
pub fn supplied(self: ?*Self, value: anytype) void {
    const detail = self orelse return;
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
            if (bytes.len > 32) out.writeAll(" [truncated after 32 bytes]") catch unreachable;
        },
    }
    detail.literal_len = out.end;
}
