//! Bounded owned logical rows. Independent of storage pages and wire framing.
const std = @import("std");
const r = @import("root.zig");
const Self = @This();
pub const max_rows = 32;
pub const max_bytes = 1024 * 1024;
allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
rows: [max_rows]?r.Row = @splat(null),
len: u8 = 0,
bytes: usize = 0,
row_limit: u8 = max_rows,
byte_limit: usize = max_bytes,
pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator, .arena = .init(allocator) };
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.* = undefined;
}
pub fn reset(self: *Self, row_limit: u8, byte_limit: usize) !void {
    if (row_limit == 0 or row_limit > max_rows or byte_limit == 0 or byte_limit > max_bytes) return error.InvalidResultBudget;
    _ = self.arena.reset(.free_all);
    self.rows = @splat(null);
    self.len = 0;
    self.bytes = 0;
    self.row_limit = row_limit;
    self.byte_limit = byte_limit;
}
/// False leaves this row with its source; the caller must retain it before
/// pulling again. A row too large for an empty batch fails rather than skipping.
pub fn append(self: *Self, fields: []const r.Types.Field, cells: r.Row) !bool {
    if (cells.len != fields.len) return error.InvalidResultRow;
    if (self.len == self.row_limit) return false;
    var scratch: [256]u8 = undefined;
    var count: std.Io.Writer.Discarding = .init(&scratch);
    for (fields, cells) |field, cell| {
        try r.Types.Codec.writeBound(cell, field, &count.writer);
        if (count.fullCount() > self.byte_limit) return error.ResultRowTooLarge;
    }
    const bytes: usize = @intCast(count.fullCount());
    if (bytes > self.byte_limit - self.bytes) return false;
    self.rows[self.len] = try r.copyRow(self.arena.allocator(), fields, cells);
    self.len += 1;
    self.bytes += bytes;
    return true;
}

test "batch budgets retain the next row and own overwritten scratch values" {
    const t = std.testing;
    var builder = init(t.allocator);
    defer builder.deinit();
    try builder.reset(32, 32);
    const fields = [_]r.Types.Field{.{ .name = "text", .type = .utf8 }};
    var text = "01234567890123456789".*;
    const row = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = &text } } }};
    try t.expect(try builder.append(&fields, &row));
    try t.expect(!try builder.append(&fields, &row));
    try t.expectEqual(1, builder.len);
    @memset(&text, 'x');
    try t.expectEqualStrings("01234567890123456789", builder.rows[0].?[0].value.atom.bytes);
    try builder.reset(1, 32);
    try t.expect(try builder.append(&fields, &row));
    try t.expect(!try builder.append(&fields, &row));
    try builder.reset(32, 4);
    try t.expectError(error.ResultRowTooLarge, builder.append(&fields, &row));
    try t.expectEqual(0, builder.len);
}
fn allocationSchedule(allocator: std.mem.Allocator) !void {
    var builder = init(allocator);
    defer builder.deinit();
    const fields = [_]r.Types.Field{.{ .name = "text", .type = .utf8 }};
    const row = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = "some variable width data" } } }};
    try builder.reset(32, max_bytes);
    _ = try builder.append(&fields, &row);
    try builder.reset(32, max_bytes);
    _ = try builder.append(&fields, &row);
}
test "batch allocation failures release all owned rows" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationSchedule, .{});
}
