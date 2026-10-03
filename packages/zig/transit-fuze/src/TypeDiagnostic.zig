//! First recursive descriptor rejection, owned independently of schema memory.
const std = @import("std");
const Self = @This();
pub const Path = @import("DiagnosticPath.zig");
pub const Kind = enum {
    precision,
    scale,
    field_count,
    name_empty,
    name_length,
    name_utf8,
    name_nul,
    duplicate_name,
    optional_variant,
    array_length,
    map_key,
    depth,
    nodes,
    name_bytes,
    root,
};
path: Path,
kind: Kind,
actual: ?usize = null,
limit: ?usize = null,
earlier: ?usize = null,
value: [256]u8 = @splat(0),
value_len: u16 = 0,
value_truncated: bool = false,
pub fn capture(self: *Self, bytes: []const u8) void {
    var length = @min(bytes.len, self.value.len);
    if (std.unicode.utf8ValidateSlice(bytes)) while (!std.unicode.utf8ValidateSlice(bytes[0..length])) {
        length -= 1;
    };
    @memcpy(self.value[0..length], bytes[0..length]);
    self.value_len = @intCast(length);
    self.value_truncated = length < bytes.len;
}
pub fn supplied(self: *const Self) []const u8 {
    return self.value[0..self.value_len];
}
pub fn constraint(self: Self) []const u8 {
    return switch (self.kind) {
        .precision => "Decimal precision must be between 1 and 38.",
        .scale => "Decimal scale must not exceed its precision.",
        .field_count => "Structures and tagged unions require between 1 and 255 fields.",
        .name_empty => "Field names must not be empty.",
        .name_length => "Field names must occupy at most 255 UTF-8 bytes.",
        .name_utf8 => "Field names must contain valid UTF-8.",
        .name_nul => "Field names must not contain NUL bytes.",
        .duplicate_name => "Field names must be unique within their structure or tagged union.",
        .optional_variant => "Tagged union variants cannot be optional.",
        .array_length => "Fixed array length must be greater than zero.",
        .map_key => "Map keys cannot be structures, lists, arrays, maps, tagged unions, JSON or intervals.",
        .depth => "The descriptor exceeds its nesting-level budget; the root occupies one level.",
        .nodes => "The descriptor exceeds its total type-node budget.",
        .name_bytes => "The descriptor exceeds its total field-name byte budget.",
        .root => "An explicit file schema must have a structure at its root.",
    };
}
pub fn unit(self: Self) ?[]const u8 {
    return switch (self.kind) {
        .depth => "levels",
        .nodes => "nodes",
        .name_bytes => "bytes",
        else => null,
    };
}
