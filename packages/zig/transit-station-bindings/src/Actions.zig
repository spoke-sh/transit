//! Shared, versioned host operations. Foreign runtimes describe private work;
//! this Zig implementation supplies state, Tables, queries and message semantics.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const m = s.fuze.model;
pub const Cell = union(enum) { null, int64: []const u8, boolean: bool, utf8: []const u8, binary: p.Value };
pub const Row = struct { key: []const u8, value: Cell };
pub const BasicAction = union(enum) {
    put: struct { key: p.Value, value: p.Value },
    cast: struct { pid: u64, value: p.Value },
    table_create: struct { id: u32, key_name: []const u8, value_name: []const u8, value_type: m.Type },
    table_get: struct { id: u32, key: []const u8 },
    table_write: struct { id: u32, mode: enum { insert, update, upsert }, row: Row },
    table_delete: struct { id: u32, key: []const u8 },
    query_policy: struct { peer: u64, table: u32, expected_revision: u64, allow: bool },
};
pub fn decimal(allocator: std.mem.Allocator, value: anytype) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub fn nativeCell(cell: Cell) !m.Cell {
    return switch (cell) {
        .null => .null,
        .int64 => |value| .{ .int64 = try std.fmt.parseInt(i64, value, 10) },
        .boolean => |value| .{ .boolean = value },
        .utf8 => |value| .{ .utf8 = try m.Bytes.init(value) },
        .binary => |value| .{ .binary = try m.Bytes.init(value.slice()) },
    };
}
pub fn foreignCell(allocator: std.mem.Allocator, cell: m.Cell) !Cell {
    return switch (cell) {
        .null => .null,
        .int64 => |value| .{ .int64 = try decimal(allocator, value) },
        .boolean => |value| .{ .boolean = value },
        .utf8 => |value| .{ .utf8 = try allocator.dupe(u8, value.slice()) },
        .binary => |value| .{ .binary = try p.Value.init(value.slice()) },
    };
}
/// Client-side consumption of finite IPC without exposing borrowed Arrow/native
/// pointers to a foreign runtime. All int64 cells remain decimal strings.
pub const ArrowValue = union(enum) { null, int64: []const u8, uint64: []const u8, boolean: bool, utf8: []const u8, binary: p.Value };
pub const ArrowCell = struct { rows: u8, columns: u8, name: []const u8, value: ArrowValue };
pub fn arrowCellBounded(allocator: std.mem.Allocator, bytes: []const u8, row: u32, column: u32, limit: usize) !ArrowCell {
    if (bytes.len == 0 or bytes.len > limit) return error.InvalidArrowResult;
    const u = s.fuze.Unified;
    var workspace: [u.Arrow.working_bytes]u8 = undefined;
    var columns: [u.max_columns]u.Column = undefined;
    const metadata = try u.Inspect.infer(bytes, &workspace, &columns);
    if (column >= metadata.schema.columns.len) return error.InvalidColumn;
    if (row >= metadata.rows) return error.InvalidRow;
    var batch: u.Inspect.Batch = undefined;
    try u.Inspect.decode(metadata.schema, bytes, metadata.rows, &workspace, allocator, &batch);
    const cell: ArrowValue = switch (batch.cells[row][column]) {
        .null => .null,
        .value => |value| switch (value) {
            .int64 => |number| .{ .int64 = try decimal(allocator, number) },
            .uint64 => |number| .{ .uint64 = try decimal(allocator, number) },
            .boolean => |boolean| .{ .boolean = boolean },
            .utf8 => |text| .{ .utf8 = text },
            .binary => |data| .{ .binary = try p.Value.init(data) },
            else => return error.UnsupportedType,
        },
        else => return error.UnsupportedCellState,
    };
    return .{ .rows = metadata.rows, .columns = @intCast(metadata.schema.columns.len), .name = try allocator.dupe(u8, columns[column].name.slice()), .value = cell };
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
        .table_create => |table| {
            _ = try s.Table.create(turn, table.id, .{ .names = .{ try m.Name.init(table.key_name), try m.Name.init(table.value_name) }, .value_type = table.value_type });
        },
        .table_get => |request| {
            const table = try s.Table.open(turn, request.id);
            const row = (try table.get(turn, try std.fmt.parseInt(i64, request.key, 10))) orelse return .{ .row = null };
            return .{ .row = .{ .key = try decimal(allocator, row.key), .value = try foreignCell(allocator, row.value) } };
        },
        .table_write => |write| {
            const table = try s.Table.open(turn, write.id);
            const row: m.Row = .{ .key = try std.fmt.parseInt(i64, write.row.key, 10), .value = try nativeCell(write.row.value) };
            switch (write.mode) {
                .insert => try table.insert(turn, row),
                .update => try table.update(turn, row),
                .upsert => try table.upsert(turn, row),
            }
        },
        .table_delete => |request| try (try s.Table.open(turn, request.id)).delete(turn, try std.fmt.parseInt(i64, request.key, 10)),
        else => return null,
    }
    try turn.validate();
    return .none;
}
