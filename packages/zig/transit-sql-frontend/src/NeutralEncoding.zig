//! Canonical decimal/hex helpers shared by neutral query and Document adapters.
//! Errors and bytes belong to the current v1 contract. Composite callers supply
//! an operation arena so partial conversion allocations are reclaimed on failure.
const std = @import("std");
// Keep the current neutral contract's errors and representations unchanged.
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

test "neutral integer and hex encoding preserves full width and canonical refusals" {
    const t = std.testing;
    try t.expectEqual(std.math.maxInt(u64), try unsigned("18446744073709551615"));
    for ([_][]const u8{ "", "01", "+1", "-1", "1.0", "18446744073709551616" }) |text| {
        try t.expectError(error.InvalidDocumentInteger, unsigned(text));
    }
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    try t.expectEqualStrings("18446744073709551615", try decimal(alloc, std.math.maxInt(u64)));
    try t.expectEqualStrings("\x00\xff\x80", try unhex(alloc, "00ff80", 3));
    try t.expectEqualStrings("00ff80", try hex(alloc, "\x00\xff\x80"));
    try t.expectError(error.DocumentEncodingCapacity, unhex(alloc, "0", 3));
    try t.expectError(error.DocumentEncodingCapacity, unhex(alloc, "00ff80", 2));
}
