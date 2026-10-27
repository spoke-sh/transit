//! Prepared metadata and parameter carriage in JSON control messages. Result
//! payloads use ResultFrame/ResultColumns; numbers never pass through JSON floats.
const std = @import("std");
const api = @import("root.zig");
const t = api.fuze.Types;
pub fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    const digits = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[2 * i] = digits[byte >> 4];
        result[2 * i + 1] = digits[byte & 15];
    }
    return result;
}
/// Decode into caller-owned storage. The returned bytes borrow output.
pub fn unhexInto(output: []u8, text: []const u8) ![]u8 {
    if (text.len % 2 != 0 or text.len / 2 > output.len) return error.InvalidSqlEncoding;
    for (text) |byte| if (!(byte >= '0' and byte <= '9') and !(byte >= 'a' and byte <= 'f')) return error.InvalidSqlEncoding;
    return std.fmt.hexToBytes(output, text);
}
pub fn unhex(allocator: std.mem.Allocator, text: []const u8, maximum: usize) ![]const u8 {
    if (text.len % 2 != 0 or text.len / 2 > maximum) return error.InvalidSqlEncoding;
    const result = try allocator.alloc(u8, text.len / 2);
    errdefer allocator.free(result);
    return unhexInto(result, text);
}
pub fn schema(allocator: std.mem.Allocator, fields: []const t.Field) ![]const u8 {
    var buffer: [t.max_encoding_bytes]u8 = undefined;
    return hex(allocator, try (t.Type{ .structure = fields }).encode(&buffer));
}
pub fn descriptor(allocator: std.mem.Allocator, value: t.Type) ![]const u8 {
    var buffer: [t.max_encoding_bytes]u8 = undefined;
    return hex(allocator, try value.encode(&buffer));
}
pub fn decodeSchema(arena: std.mem.Allocator, text: []const u8) !t.Type {
    const bytes = try unhex(arena, text, t.max_encoding_bytes);
    defer arena.free(bytes);
    return t.decodeInto(arena, bytes);
}
/// Parameters carry their descriptor, avoiding dependency on stale prepared metadata.
pub fn parameter(allocator: std.mem.Allocator, value: ?t.Values.Atom, kind: t.Type) ![]const u8 {
    return encodeHex(allocator, if (value) |atom| .{ .value = .{ .atom = atom } } else .null, .{ .name = "", .type = kind, .nullable = true });
}
/// Count without retaining bytes, encode into the final allocation, then expand
/// backwards in place. No maximum-sized scratch or second payload allocation.
fn encodeHex(allocator: std.mem.Allocator, value: t.Values.Cell, field: t.Field) ![]const u8 {
    const write = t.Codec.write;
    var scratch: [256]u8 = undefined;
    var count: std.Io.Writer.Discarding = .init(&scratch);
    try write(value, field, &count.writer);
    if (count.fullCount() > api.max_batch_bytes) return error.SqlMessageTooLarge;
    const size: usize = @intCast(count.fullCount());
    const output = try allocator.alloc(u8, size * 2);
    errdefer allocator.free(output);
    var writer: std.Io.Writer = .fixed(output[0..size]);
    try write(value, field, &writer);
    std.debug.assert(writer.buffered().len == size);
    const digits = "0123456789abcdef";
    var i = size;
    while (i != 0) {
        i -= 1;
        const byte = output[i];
        output[2 * i] = digits[byte >> 4];
        output[2 * i + 1] = digits[byte & 15];
    }
    return output;
}
pub fn decodeParameter(allocator: std.mem.Allocator, text: []const u8) !t.Codec.Decoded {
    const bytes = try unhex(allocator, text, api.max_batch_bytes);
    defer allocator.free(bytes);
    return t.Codec.decode(allocator, bytes);
}
test "prepared schema preserves the independent logical descriptor" {
    const testing = std.testing;
    const Fixture = struct { schema: []const u8, cells: []const []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, testing.allocator, @embedFile("fixtures/logical.json"), .{});
    defer fixture.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const actual = try decodeSchema(a, fixture.value.schema);
    try testing.expectEqualStrings(fixture.value.schema, try schema(a, actual.structure));
    try testing.expectEqual(.uint128, std.meta.activeTag(actual.structure[0].type));
    try testing.expect(actual.structure[1].optional and actual.structure[2].nullable);
    try testing.expectError(error.InvalidSqlEncoding, unhex(a, "FF", 8));
    try testing.expectError(error.InvalidSqlEncoding, unhex(a, "0011", 1));
}

test "maximum scalar parameter count fits a small arena without maximum-size scratch" {
    var memory: api.fuze.MemoryBudget = .{ .parent = std.testing.allocator, .limit = 16 * 1024 };
    var arena: std.heap.ArenaAllocator = .init(memory.allocator());
    defer arena.deinit();
    for (0..api.max_parameters) |i| {
        const encoded = try parameter(arena.allocator(), .{ .unsigned = i }, .uint64);
        var decoded = try decodeParameter(std.testing.allocator, encoded);
        defer decoded.deinit();
        try std.testing.expectEqual(i, decoded.cell.value.atom.unsigned);
    }
    try std.testing.expect(memory.peak < 16 * 1024);
}

fn parameterAllocations(allocator: std.mem.Allocator) !void {
    const encoded = try parameter(allocator, .{ .bytes = "variable payload" }, .utf8);
    defer allocator.free(encoded);
}
test "parameter encoding allocates only its exact final hex payload" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parameterAllocations, .{});
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try parameterAllocations(failing.allocator());
    try std.testing.expectEqual(1, failing.alloc_index);
}
