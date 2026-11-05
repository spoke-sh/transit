//! Bounded group/row identities and immutable post-aggregation ordering keys.
const std = @import("std");
const r = @import("Relational.zig");
const v = @import("RelationalValues.zig");
const Self = @This();
pub const Pair = struct { left: r.RowIdentity, right: ?r.RowIdentity };
pair: ?Pair = null,
values: [r.max_groups]v.Value = @splat(null),
len: u8 = 0,
buffer: v.Buffer = .{},
/// Sorted records occupy a separate range in the same external tree. Their
/// immutable values are computed only after every contributor has settled.
sorted: bool = false,
sort_values: [r.max_groups]v.Value = @splat(null),
sort_len: u8 = 0,
sort_buffer: v.Buffer = .{},

pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
    var result = self;
    result.buffer = try v.Buffer.copy(allocator, result.values[0..result.len]);
    errdefer result.buffer.deinit();
    result.sort_buffer = try v.Buffer.copy(allocator, result.sort_values[0..result.sort_len]);
    return result;
}
pub fn borrow(self: Self) Self {
    var result = self;
    result.buffer = .{};
    result.sort_buffer = .{};
    return result;
}
pub fn deinit(self: *Self) void {
    self.buffer.deinit();
    self.sort_buffer.deinit();
    self.* = undefined;
}
pub fn validate(self: Self, plan: r.Plan) !void {
    var columns: [r.max_groups]r.Column = undefined;
    const keys = plan.keyColumns(&columns);
    if (self.len != keys.len or plan.isGrouped() != (self.pair == null)) return error.InvalidRelationalGroup;
    if (self.pair) |pair| {
        try pair.left.validate();
        if (pair.right) |right| {
            if (plan.join == null) return error.InvalidRelationalGroup;
            try right.validate();
        } else if (plan.join != null and plan.join.?.kind == .inner) return error.InvalidRelationalGroup;
    }
    _ = try v.payloadLength(self.values[0..self.len]);
    for (self.values[0..self.len], keys) |value, reference| {
        var column = try plan.resolveColumn(reference);
        column.nullable = true;
        try v.validate(value, column);
    }
    for (self.values[self.len..]) |value| if (value != null) return error.InvalidRelationalGroup;
    if (self.sorted and !plan.hasAggregateOrder()) return error.InvalidRelationalGroup;
    if (self.sort_len != (if (self.sorted) plan.order_by.len else 0)) return error.InvalidRelationalGroup;
    _ = try v.payloadLength(self.sort_values[0..self.sort_len]);
    for (self.sort_values[0..self.sort_len], plan.order_by[0..self.sort_len]) |value, item| {
        var column = try plan.expressionColumn(item.expression);
        column.nullable = true;
        try v.validate(value, column);
    }
    for (self.sort_values[self.sort_len..]) |value| if (value != null) return error.InvalidRelationalGroup;
}
pub fn order(a: Self, b: Self, plan: r.Plan) !std.math.Order {
    if (a.sorted != b.sorted) return if (a.sorted) .gt else .lt;
    if (a.sorted) {
        if (a.sort_len != plan.order_by.len or b.sort_len != plan.order_by.len) return error.InvalidRelationalGroup;
        for (plan.order_by, 0..) |item, i| {
            const result = try orderValue(a.sort_values[i], b.sort_values[i], try plan.expressionColumn(item.expression), item.direction, item.nulls);
            if (result != .eq) return result;
        }
    }
    var columns_buf: [r.max_groups]r.Column = undefined;
    const columns = plan.keyColumns(&columns_buf);
    if (a.len != columns.len or b.len != columns.len) return error.InvalidRelationalGroup;
    if (plan.isGrouped() != (a.pair == null) or plan.isGrouped() != (b.pair == null)) return error.InvalidRelationalGroup;
    for (plan.order_by) |item| {
        if (item.expression != .column) continue;
        const index = columnIndex(columns, item.expression.column) orelse return error.InvalidRelationalGroup;
        const result = try orderValue(a.values[index], b.values[index], try plan.resolveColumn(item.expression.column), item.direction, item.nulls);
        if (result != .eq) return result;
    }
    if (plan.isGrouped()) {
        for (columns, 0..) |column, i| {
            if (plan.ordersByColumn(column)) continue;
            const result = try v.order(a.values[i], b.values[i], try plan.resolveColumn(column));
            if (result != .eq) return result;
        }
        return .eq;
    }
    return pairOrder(a.pair.?, b.pair.?);
}
pub fn orderValue(a: v.Value, b: v.Value, column: @import("TableSchema.zig").Column, direction: r.Direction, nulls: r.NullOrder) !std.math.Order {
    if (a == null) return if (b == null) .eq else if (nulls == .first) .lt else .gt;
    if (b == null) return if (nulls == .first) .gt else .lt;
    const result = try v.order(a, b, column);
    return if (direction == .asc) result else result.invert();
}
fn columnIndex(columns: []const r.Column, reference: r.Column) ?usize {
    for (columns, 0..) |column, i| if (column.eql(reference)) return i;
    return null;
}
pub fn identityOrder(a: r.RowIdentity, b: r.RowIdentity) std.math.Order {
    inline for (.{ "origin", "operation", "ordinal" }) |field| {
        const result = std.math.order(@field(a, field), @field(b, field));
        if (result != .eq) return result;
    }
    return .eq;
}
pub fn pairOrder(a: Pair, b: Pair) std.math.Order {
    const left = identityOrder(a.left, b.left);
    if (left != .eq) return left;
    if (a.right) |right| return if (b.right) |other| identityOrder(right, other) else .gt;
    return if (b.right == null) .eq else .lt;
}
pub fn encodedLength(self: Self) usize {
    var length: usize = 3;
    if (self.pair) |pair| length += 21 + @as(usize, if (pair.right != null) 20 else 0);
    for (self.values[0..self.len]) |value| length += v.encodedLength(value);
    for (self.sort_values[0..self.sort_len]) |value| length += v.encodedLength(value);
    return length;
}
pub fn write(self: Self, writer: *std.Io.Writer) !void {
    try writer.writeAll(&.{ self.len, @intFromBool(self.sorted), self.sort_len });
    if (self.pair) |pair| {
        try writer.writeAll(&try pair.left.encode());
        try writer.writeByte(@intFromBool(pair.right != null));
        if (pair.right) |right| try writer.writeAll(&try right.encode());
    }
    for (self.values[0..self.len]) |value| try v.write(writer, value);
    for (self.sort_values[0..self.sort_len]) |value| try v.write(writer, value);
}
/// Returned variable-width values borrow the input until clone is called.
pub fn read(reader: *std.Io.Reader, plan: r.Plan) !Self {
    var key: Self = .{ .len = try reader.takeByte(), .sorted = switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => return error.InvalidRelationalGroup,
    }, .sort_len = try reader.takeByte() };
    if (key.len > r.max_groups or key.sort_len > r.max_groups) return error.InvalidRelationalGroup;
    if (!plan.isGrouped()) {
        const left = try r.RowIdentity.decode(try reader.takeArray(20));
        const right: ?r.RowIdentity = switch (try reader.takeByte()) {
            0 => null,
            1 => try r.RowIdentity.decode(try reader.takeArray(20)),
            else => return error.InvalidRelationalGroup,
        };
        key.pair = .{ .left = left, .right = right };
    }
    for (key.values[0..key.len]) |*value| value.* = try v.read(reader);
    for (key.sort_values[0..key.sort_len]) |*value| value.* = try v.read(reader);
    try key.validate(plan);
    return key;
}
