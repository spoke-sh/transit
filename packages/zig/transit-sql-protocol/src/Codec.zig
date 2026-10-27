//! Hex carriage of the existing canonical logical schema/value codecs. Numbers
//! never round-trip through JSON floats; nested, missing and conflict cells survive.
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
/// Metadata/recursive arrays belong to arena; text, binary and JSON borrow
/// output. Retain both owners until the cell is released or copied.
pub fn decodeCellBorrowing(arena: std.mem.Allocator, field: t.Field, text: []const u8, output: []u8) !t.Values.Cell {
    return t.Codec.decodeBoundBorrowingBytes(arena, field, try unhexInto(output, text));
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
pub fn cell(allocator: std.mem.Allocator, field: t.Field, value: t.Values.Cell) ![]const u8 {
    return encodeHex(allocator, value, field, false);
}
pub fn decodeCell(arena: std.mem.Allocator, field: t.Field, text: []const u8) !t.Values.Cell {
    const bytes = try unhex(arena, text, api.max_batch_bytes);
    defer arena.free(bytes);
    return t.Codec.decodeBoundInto(arena, field, bytes);
}
/// Parameters carry their descriptor, avoiding dependency on stale prepared metadata.
pub fn parameter(allocator: std.mem.Allocator, value: ?t.Values.Atom, kind: t.Type) ![]const u8 {
    return encodeHex(allocator, if (value) |atom| .{ .value = .{ .atom = atom } } else .null, .{ .name = "", .type = kind, .nullable = true }, true);
}
/// Count without retaining bytes, encode into the final allocation, then expand
/// backwards in place. No maximum-sized scratch or second payload allocation.
fn encodeHex(allocator: std.mem.Allocator, value: t.Values.Cell, field: t.Field, comptime standalone: bool) ![]const u8 {
    const write = if (standalone) t.Codec.write else t.Codec.writeBound;
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
test "logical session carriage preserves wide integers, NULL, missing and nested values" {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const fields = [_]t.Field{ .{ .name = "wide", .type = .uint128 }, .{ .name = "absent", .type = .int64, .optional = true }, .{ .name = "nullable", .type = .utf8, .nullable = true } };
    const values = [_]t.Values.Cell{ .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } }, .missing, .null };
    const encoded = try schema(a, &fields);
    const restored = try decodeSchema(a, encoded);
    for (fields, restored.structure, values) |field, decoded, value| try testing.expectEqualDeep(value, try decodeCell(a, decoded, try cell(a, field, value)));
    const nested: t.Field = .{ .name = "row", .type = .{ .structure = &fields } };
    const value: t.Values.Cell = .{ .value = .{ .structure = &values } };
    try testing.expectEqualDeep(value, try decodeCell(a, nested, try cell(a, nested, value)));
    try testing.expectError(error.InvalidSqlEncoding, unhex(a, "FF", 8));
    try testing.expectError(error.InvalidSqlEncoding, unhex(a, "0011", 1));
}
test "session batch bytes match the independent Python logical fixture" {
    const testing = std.testing;
    const Fixture = struct { schema: []const u8, cells: []const []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, testing.allocator, @embedFile("fixtures/logical.json"), .{});
    defer fixture.deinit();
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const actual = try decodeSchema(a, fixture.value.schema);
    try testing.expectEqualStrings(fixture.value.schema, try schema(a, actual.structure));
    const values = [_]t.Values.Cell{ .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } }, .missing, .null };
    for (actual.structure, values, fixture.value.cells) |field, value, bytes| {
        try testing.expectEqualStrings(bytes, try cell(a, field, value));
        try testing.expectEqualDeep(value, try decodeCell(a, field, bytes));
    }
}

test "borrowing decode keeps variable payload in caller storage and copies detach" {
    const testing = std.testing;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const fields = [_]t.Field{ .{ .name = "text", .type = .utf8 }, .{ .name = "bytes", .type = .binary } };
    const field: t.Field = .{ .name = "nested", .type = .{ .structure = &fields } };
    const children = [_]t.Values.Cell{
        .{ .value = .{ .atom = .{ .bytes = "hello" } } },
        .{ .value = .{ .atom = .{ .bytes = "\x00\xff" } } },
    };
    const value: t.Values.Cell = .{ .value = .{ .structure = &children } };
    const text = try cell(arena.allocator(), field, value);
    var payload: [128]u8 = undefined;
    const borrowed = try decodeCellBorrowing(arena.allocator(), field, text, &payload);
    try testing.expectEqualDeep(value, borrowed);
    const retained = try t.Values.cloneValidated(arena.allocator(), borrowed);
    for (borrowed.value.structure) |child| {
        const address = @intFromPtr(child.value.atom.bytes.ptr);
        try testing.expect(address >= @intFromPtr(&payload) and address < @intFromPtr(&payload) + payload.len);
    }
    @memset(&payload, 'x');
    try testing.expectEqualDeep(value, retained);
    try testing.expectEqualStrings("xxxxx", borrowed.value.structure[0].value.atom.bytes);
    try testing.expectError(error.InvalidSqlEncoding, unhexInto(&payload, "0F"));
    try testing.expectError(error.InvalidSqlEncoding, unhexInto(payload[0..1], "0000"));
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
