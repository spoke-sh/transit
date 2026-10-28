//! Bounded owned logical rows. Independent of storage pages and wire framing.
const std = @import("std");
const r = @import("root.zig");
const memory = @import("transit_memory");
const Self = @This();
pub const max_rows = 32;
pub const max_bytes = 1024 * 1024;
workspace: memory.Workspace,
lease: ?memory.Workspace.Lease = null,
rows: [max_rows]?r.Row = @splat(null),
len: u8 = 0,
bytes: usize = 0,
row_limit: u8 = max_rows,
byte_limit: usize = max_bytes,
/// Reserve once at admission. Capacity bounds resident representation, separately
/// from the canonical byte budget. Keep the builder stable after first reset.
pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
    return .{ .workspace = try .init(allocator, capacity) };
}
/// Caller-owned capacity has the same reset/borrow rules and no backing owner.
pub fn fromBuffer(buffer: []align(memory.Workspace.alignment) u8) Self {
    return .{ .workspace = .fromBuffer(buffer) };
}
pub fn deinit(self: *Self) void {
    if (self.lease) |lease| lease.release(false) catch unreachable;
    self.workspace.deinit();
    self.* = undefined;
}
pub fn reset(self: *Self, row_limit: u8, byte_limit: usize) !void {
    if (row_limit == 0 or row_limit > max_rows or byte_limit == 0 or byte_limit > max_bytes) return error.InvalidResultBudget;
    if (self.lease) |*lease| try lease.reset() else self.lease = try self.workspace.acquire();
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
    const lease = self.lease orelse return error.ResultBuilderNotReset;
    const checkpoint = try lease.mark();
    errdefer lease.rewind(checkpoint) catch unreachable;
    self.rows[self.len] = r.copyRow(try lease.allocator(), fields, cells) catch |err| {
        if (err == error.OutOfMemory) return error.ResultMemoryBudgetExceeded;
        return err;
    };
    self.len += 1;
    self.bytes += bytes;
    return true;
}

test "batch budgets retain the next row and own overwritten scratch values" {
    const t = std.testing;
    var builder = try init(t.allocator, 4096);
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
    var builder = try init(allocator, 4096);
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

test "warmed builder varies batch shapes without consulting its backing allocator" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var builder = try init(probe.allocator(), 128 * 1024);
    defer builder.deinit();
    const child: r.Types.Field = .{ .name = "text", .type = .utf8, .nullable = true, .optional = true };
    const fields = [_]r.Types.Field{.{ .name = "nested", .type = .{ .structure = &.{child} } }};
    var payload: [2048]u8 = undefined;
    probe.begin(true);
    for (0..1000) |iteration| {
        try builder.reset(max_rows, max_bytes);
        const count = ([_]usize{ 0, 1, 31, 32, 33 })[(iteration / 5) % 5];
        const fill: u8 = 'a' + @as(u8, @intCast(iteration % 26));
        @memset(&payload, fill);
        const alternatives = [_]r.Types.Values.Alternative{
            .{ .counter = 1, .replica = 1, .value = .null },
            .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .bytes = payload[0 .. 1 + iteration % payload.len] } } } },
        };
        const cell: r.Types.Values.Cell = switch (iteration % 5) {
            0 => .missing,
            1 => .null,
            2 => .{ .type_error = .int64 },
            3 => .{ .conflict = &alternatives },
            else => .{ .value = .{ .atom = .{ .bytes = payload[0 .. 1 + iteration % payload.len] } } },
        };
        const nested = [_]r.Types.Values.Cell{cell};
        const row = [_]r.Types.Values.Cell{.{ .value = .{ .structure = &nested } }};
        for (0..count) |index| try t.expectEqual(index < max_rows, try builder.append(&fields, &row));
        try t.expectEqual(@min(count, max_rows), builder.len);
        for (builder.rows[0..builder.len]) |owned| try t.expectEqualDeep(row[0], owned.?[0]);
        if (builder.len != 0 and cell == .value) {
            @memset(&payload, 0);
            try t.expectEqual(fill, builder.rows[0].?[0].value.structure[0].value.atom.bytes[0]);
        }
    }
    try probe.verify();
    try t.expectEqual(builder.workspace.buffer.len, probe.live_bytes);
}

test "failed recursive append rewinds capacity and preserves previously delivered rows" {
    const t = std.testing;
    var builder = try init(t.allocator, 1024);
    defer builder.deinit();
    try builder.reset(max_rows, max_bytes);
    const fields = [_]r.Types.Field{.{ .name = "text", .type = .utf8 }};
    const kept = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = "retained" } } }};
    try t.expect(try builder.append(&fields, &kept));
    const before = builder.workspace.fixed.end_index;
    const bytes_before = builder.bytes;
    const payload: [1024]u8 = @splat('x');
    const too_large = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = &payload } } }};
    for (0..100) |_| {
        try t.expectError(error.ResultMemoryBudgetExceeded, builder.append(&fields, &too_large));
        try t.expectEqual(before, builder.workspace.fixed.end_index);
        try t.expectEqual(bytes_before, builder.bytes);
        try t.expectEqual(1, builder.len);
        try t.expectEqualStrings("retained", builder.rows[0].?[0].value.atom.bytes);
    }
    try t.expect(try builder.append(&fields, &kept));
    try t.expectEqual(2, builder.len);
}

test "canonical byte boundary remains independent of reserved representation capacity" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var builder = try init(probe.allocator(), 2 * max_bytes);
    defer builder.deinit();
    const payload = try t.allocator.alloc(u8, max_bytes);
    defer t.allocator.free(payload);
    @memset(payload, 'x');
    const fields = [_]r.Types.Field{.{ .name = "bytes", .type = .binary }};
    probe.begin(true);
    // A binary cell contributes one state byte and a four-byte length.
    var row = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = payload[0 .. max_bytes - 5] } } }};
    try builder.reset(max_rows, max_bytes);
    try t.expect(try builder.append(&fields, &row));
    try t.expectEqual(max_bytes, builder.bytes);
    try t.expect(!try builder.append(&fields, &row));
    try builder.reset(max_rows, max_bytes);
    row[0].value.atom.bytes = payload[0 .. max_bytes - 4];
    try t.expectError(error.ResultRowTooLarge, builder.append(&fields, &row));
    try t.expectEqual(0, builder.len);
    try probe.verify();
}
