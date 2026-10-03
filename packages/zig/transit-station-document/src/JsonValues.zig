//! Neutral JSON representation of an accepted Document reference and checked
//! full-width values. Conversion validates the owning native contract.
const std = @import("std");
const document = @import("root.zig");
pub fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidDocumentInteger;
    for (text) |b| if (!std.ascii.isDigit(b)) return error.InvalidDocumentInteger;
    return std.fmt.parseInt(u64, text, 10) catch return error.InvalidDocumentInteger;
}
pub fn unhex(alloc: std.mem.Allocator, text: []const u8, limit: usize) ![]const u8 {
    if (text.len % 2 != 0 or text.len / 2 > limit) return error.DocumentEncodingCapacity;
    const bytes = try alloc.alloc(u8, text.len / 2);
    return std.fmt.hexToBytes(bytes, text);
}
pub fn decimal(allocator: std.mem.Allocator, value: anytype) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const output = try allocator.alloc(u8, bytes.len * 2);
    const digits = "0123456789abcdef";
    for (bytes, 0..) |byte, index| {
        output[index * 2] = digits[byte >> 4];
        output[index * 2 + 1] = digits[byte & 15];
    }
    return output;
}
pub const Reference = struct {
    resource: u64,
    document: []const u8,
    epoch: []const u8,
    type_revision: u32,
    revision: []const u8,
    pub fn native(self: Reference) !document.Client.Reference {
        const out: document.Client.Reference = .{ .resource = self.resource, .document = try unsigned(self.document), .epoch = try unsigned(self.epoch), .type_revision = self.type_revision, .revision = try unsigned(self.revision) };
        _ = try out.encode();
        return out;
    }
    pub fn fromNative(alloc: std.mem.Allocator, value: document.Client.Reference) !Reference {
        return .{ .resource = value.resource, .document = try decimal(alloc, value.document), .epoch = try decimal(alloc, value.epoch), .type_revision = value.type_revision, .revision = try decimal(alloc, value.revision) };
    }
};
