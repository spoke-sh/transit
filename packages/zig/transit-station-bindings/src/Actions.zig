//! Shared, versioned host operations. Foreign runtimes describe private work;
//! this Zig implementation supplies state, Tables, queries and message semantics.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
pub const BasicAction = union(enum) {
    put: struct { key: p.Value, value: p.Value },
    cast: struct { pid: u64, value: p.Value },
    query_policy: struct { peer: u64, table: []const u8, expected_revision: []const u8, allow: bool },
};
pub fn decimal(allocator: std.mem.Allocator, value: anytype) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
/// Owned logical cells and descriptors from one complete plain IPC segment.
/// Exact scalar bits and recursive states share the neutral logical JSON codec.
pub const ArrowCell = struct { rows: u8, columns: u8, name: []const u8, type: s.fuze.Types.Type, value: s.fuze.LogicalJson.Cell };
pub fn arrowCellBounded(allocator: std.mem.Allocator, bytes: []const u8, row: u32, column: u32, limit: usize) !ArrowCell {
    if (bytes.len == 0 or bytes.len > limit) return error.InvalidArrowResult;
    const f = s.fuze;
    var workspace: [f.LogicalArrow.working_bytes]u8 = undefined;
    var metadata = try f.LogicalInspect.infer(allocator, bytes, &workspace);
    defer metadata.deinit();
    const fields = metadata.descriptor.type.structure;
    if (column >= fields.len) return error.InvalidColumn;
    if (row >= metadata.rows) return error.InvalidRow;
    var batch = try f.LogicalInspect.decode(allocator, metadata.descriptor.type, bytes, metadata.rows, &workspace);
    defer batch.deinit();
    return .{ .rows = metadata.rows, .columns = @intCast(fields.len), .name = try allocator.dupe(u8, fields[column].name), .type = try fields[column].type.cloneInto(allocator), .value = try f.LogicalJson.foreignCell(allocator, batch.rows[row].cells[column], fields[column].type) };
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
/// The result borrows the supplied arena; serialize/copy before releasing it.
/// All actions mutate only the private turn. The host explicitly finishes it.
pub fn basic(comptime R: type, allocator: std.mem.Allocator, turn: anytype, action: anytype) !?R {
    switch (action) {
        .get => |key| return .{ .value = try turn.read(key) },
        .put => |put| try turn.put(put.key, put.value),
        .delete => |key| try turn.delete(key),
        .cast => |cast| try turn.cast(cast.pid, cast.value),
        .call => |call| return .{ .correlation = try decimal(allocator, try turn.callWithTimer(call.pid, call.value, call.deadline_ms, call.observer)) },
        .reply => |value| try turn.reply(value),
        .cancel => |correlation| {
            const cancelled = try s.Waiting.cancel(turn, try std.fmt.parseInt(u64, correlation, 10));
            if (@hasField(R, "cancelled")) {
                try turn.validate();
                return .{ .cancelled = cancelled };
            }
        },
        .effect => |value| {
            try value.validate();
            if (turn.decision.effect != null) return error.EffectBudgetExceeded;
            turn.decision.effect = value;
        },
        else => return null,
    }
    try turn.validate();
    return .none;
}
