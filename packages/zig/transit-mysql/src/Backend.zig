//! Bounded classic-protocol replies. Each returned packet borrows the reusable
//! builder. The session supplies negotiated capabilities and current authority.
const std = @import("std");
const m = @import("root.zig");
const g = m.gateway;
const Self = @This();
allocator: std.mem.Allocator,
maximum: u32 = g.Limits.max_frame_bytes,
sequence: u8 = 0,
bytes: std.ArrayList(u8) = .empty,
pub const Column = struct { name: []const u8, type: g.Type };
pub fn deinit(self: *Self) void {
    self.bytes.deinit(self.allocator);
    self.* = undefined;
}
fn begin(self: *Self) !void {
    self.bytes.clearRetainingCapacity();
    try self.bytes.appendSlice(self.allocator, &try m.Frame.header(self.sequence, 0, self.maximum));
}
fn append(self: *Self, bytes: []const u8) !void {
    if (self.bytes.items.len < 4 or self.bytes.items.len - 4 > self.maximum or bytes.len > self.maximum - (self.bytes.items.len - 4)) return error.FrameTooLarge;
    try self.bytes.appendSlice(self.allocator, bytes);
}
fn int(self: *Self, comptime T: type, value: T) !void {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .little);
    try self.append(&bytes);
}
fn length(self: *Self, value: u64) !void {
    var buffer: [9]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var encoded = try std.ArrayList(u8).initCapacity(fixed.allocator(), buffer.len);
    try m.Codec.appendLength(fixed.allocator(), &encoded, value);
    try self.append(encoded.items);
}
fn string(self: *Self, value: []const u8) !void {
    try self.length(value.len);
    try self.append(value);
}
fn finish(self: *Self) []const u8 {
    std.mem.writeInt(u24, self.bytes.items[0..3], @intCast(self.bytes.items.len - 4), .little);
    self.sequence +%= 1;
    return self.bytes.items;
}
/// Status always reports autocommit, no transaction and no additional results.
pub fn ok(self: *Self, affected: u64, terminator: bool) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    try self.append(&.{if (terminator) 0xfe else 0x00});
    try self.length(affected);
    try self.length(0); // No generated IDs are supplied by the Table contract.
    try self.int(u16, 2);
    try self.int(u16, 0);
    return self.finish();
}
pub fn eof(self: *Self) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    try self.append("\xfe\x00\x00\x02\x00");
    return self.finish();
}
pub fn failure(self: *Self, code: u16, state: [5]u8, message: []const u8) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    if (code == 0 or message.len > 512 or !std.unicode.utf8ValidateSlice(message) or std.mem.indexOfScalar(u8, message, 0) != null) return error.InvalidWireText;
    for (state) |byte| if (!std.ascii.isUpper(byte) and !std.ascii.isDigit(byte)) return error.InvalidSqlState;
    try self.append("\xff");
    try self.int(u16, code);
    try self.append("#");
    try self.append(&state);
    try self.append(message);
    return self.finish();
}
pub fn columns(self: *Self, count: usize) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    if (count == 0 or count > g.Limits.max_parameters) return error.InvalidWireColumns;
    try self.length(count);
    return self.finish();
}
pub fn describe(self: *Self, column: Column) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    if (column.name.len > 255 or !std.unicode.utf8ValidateSlice(column.name) or std.mem.indexOfScalar(u8, column.name, 0) != null) return error.InvalidWireText;
    const descriptor = m.Scalar.descriptor(column.type, 309);
    try self.string("def");
    // No origin identity is invented for a computed/projected output.
    for (0..3) |_| try self.string("");
    try self.string(column.name);
    try self.string("");
    try self.append("\x0c");
    try self.int(u16, descriptor.charset);
    try self.int(u32, descriptor.length);
    try self.append(&.{descriptor.code});
    try self.int(u16, descriptor.flags);
    try self.append(&.{ descriptor.decimals, 0, 0 });
    return self.finish();
}
pub fn prepared(self: *Self, id: u32, column_count: usize, parameter_count: usize) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    if (id == 0 or column_count > g.Limits.max_parameters or parameter_count > g.Limits.max_parameters) return error.InvalidWireStatement;
    try self.append("\x00");
    try self.int(u32, id);
    try self.int(u16, @intCast(column_count));
    try self.int(u16, @intCast(parameter_count));
    try self.append("\x00");
    try self.int(u16, 0);
    return self.finish();
}
pub fn row(self: *Self, descriptors: []const Column, cells: []const g.fuze.Types.Values.Cell, binary: bool) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    if (descriptors.len == 0 or descriptors.len > g.Limits.max_parameters or descriptors.len != cells.len) return error.InvalidWireColumns;
    if (binary) {
        const bitmap_length = (cells.len + 9) / 8;
        var bitmap: [33]u8 = @splat(0);
        for (cells, 0..) |cell, i| if (cell == .null) {
            bitmap[(i + 2) / 8] |= @as(u8, 1) << @intCast((i + 2) % 8);
        };
        try self.append("\x00");
        try self.append(bitmap[0..bitmap_length]);
    }
    for (descriptors, cells) |column, cell| {
        const value = try column.type.value(cell);
        if (value == null) {
            if (!binary) try self.append("\xfb");
            continue;
        }
        if (column.type.kind == .utf8 or column.type.kind == .binary) {
            try self.string(value.?.bytes);
        } else {
            var scratch: [1024]u8 = undefined;
            var fixed = std.heap.FixedBufferAllocator.init(&scratch);
            var scalar: std.ArrayList(u8) = .empty;
            if (binary) try m.Scalar.encode(fixed.allocator(), &scalar, column.type.kind, value.?) else try m.Scalar.text(fixed.allocator(), &scalar, column.type.kind, value.?);
            try self.append(scalar.items);
        }
    }
    return self.finish();
}
/// The caller supplies fresh secure, nonzero nonce bytes. This server requests
/// full caching_sha2_password authentication over TLS; no fast-auth cache exists.
pub fn greeting(self: *Self, connection: u32, nonce: [20]u8, capabilities: u32) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    if (connection == 0 or std.mem.indexOfScalar(u8, &nonce, 0) != null) return error.InvalidAuthentication;
    try self.append("\x0a8.4.0-Transit\x00");
    try self.int(u32, connection);
    try self.append(nonce[0..8]);
    try self.append("\x00");
    try self.int(u16, @truncate(capabilities));
    try self.append("\xff"); // UTF-8 negotiation; selected comparison collation is 309.
    try self.int(u16, 2);
    try self.int(u16, @truncate(capabilities >> 16));
    try self.append("\x15\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00");
    try self.append(nonce[8..]);
    try self.append("\x00caching_sha2_password\x00");
    return self.finish();
}
pub fn fullAuthentication(self: *Self) ![]const u8 {
    try self.begin();
    errdefer self.bytes.clearRetainingCapacity();
    try self.append("\x01\x04");
    return self.finish();
}
test "binary rows offset NULL bits by two and preserve full uint64 metadata and counts" {
    const t = std.testing;
    var builder: Self = .{ .allocator = t.allocator, .sequence = 254 };
    defer builder.deinit();
    const column: Column = .{ .name = "n", .type = .{ .kind = .uint64, .nullable = true } };
    var columns_array: [9]Column = @splat(column);
    var cells: [9]g.fuze.Types.Values.Cell = @splat(.null);
    cells[0] = .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } };
    const encoded = try builder.row(&columns_array, &cells, true);
    try t.expectEqualSlices(u8, "\x0b\x00\x00\xfe\x00\xf8\x07\xff\xff\xff\xff\xff\xff\xff\xff", encoded);
    const ok_packet = try builder.ok(std.math.maxInt(u64), false);
    try t.expectEqual(@as(u8, 255), ok_packet[3]);
    var reader: g.Bytes = .{ .bytes = ok_packet[5..] };
    try t.expectEqual(std.math.maxInt(u64), try m.Codec.length(&reader));
    try t.expectEqual(@as(u64, 0), try m.Codec.length(&reader));
    try t.expectEqual(@as(u16, 2), try reader.int(u16, .little));
    try t.expectEqual(@as(u16, 0), try reader.int(u16, .little));
    try reader.finish();
    try t.expectEqual(@as(u8, 0), builder.sequence);
    builder.maximum = 8;
    try t.expectError(error.FrameTooLarge, builder.row(&columns_array, &cells, true));
    try t.expectEqual(@as(usize, 0), builder.bytes.items.len);
}
