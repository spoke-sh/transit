//! Canonical finite output record. Publication/manifest authority is external.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const values = @import("RelationalValues.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const fixed_bytes = 4 + 32 + 32 + 8 + 1 + @max(41, 1 + r.max_groups * values.fixed_bytes) + 1 + r.max_outputs * values.fixed_bytes + 1 + 44 + 2 * r.max_groups * values.fixed_bytes;
pub const max_bytes = fixed_bytes + 4 * values.max_text_bytes;
binding: [32]u8,
ordinal: u64,
row: e.Output,
pub fn deinit(self: *Self) void {
    self.row.deinit();
    self.* = undefined;
}
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}
pub fn encode(self: Self, bound: r.Bound, output: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try self.writeTo(bound, &writer);
    return writer.buffered();
}
pub fn encodeAlloc(self: Self, allocator: std.mem.Allocator, bound: r.Bound) ![]u8 {
    return values.encodeOwned(allocator, self, bound, max_bytes);
}
pub fn writeTo(self: Self, bound: r.Bound, writer: *std.Io.Writer) !void {
    try bound.validate();
    if (!std.mem.eql(u8, &self.binding, &try bound.fingerprint())) return error.RelationalSourceChanged;
    if (self.row.len != bound.plan.outputs.len or self.ordinal >= bound.plan.budgets.output_rows) return error.InvalidRelationalOutput;
    for (self.row.cells[self.row.len..]) |cell| if (cell != .null) return error.InvalidRelationalOutput;
    try writer.writeAll("FRO1");
    try writer.writeAll(&definition());
    try writer.writeAll(&self.binding);
    try writer.writeInt(u64, self.ordinal, .little);
    const grouped = @import("RelationalCheckpoint.zig").grouped(bound.plan);
    if (grouped != (self.row.identity == .group)) return error.InvalidRelationalOutput;
    switch (self.row.identity) {
        .pair => |pair| {
            try writer.writeByte(0);
            try writer.writeAll(&try pair.left.encode());
            try writer.writeByte(@intFromBool(pair.right != null));
            if (pair.right) |right| {
                if (bound.plan.join == null) return error.InvalidRelationalOutput;
                try writer.writeAll(&try right.encode());
            } else if (bound.plan.join != null and bound.plan.join.?.kind == .inner) return error.InvalidRelationalOutput;
        },
        .group => |key| {
            if (key.len != bound.plan.group_by.len) return error.InvalidRelationalOutput;
            try writer.writeByte(1);
            try writer.writeByte(key.len);
            _ = try values.payloadLength(key.values[0..key.len]);
            for (key.values[0..key.len], bound.plan.group_by) |value, reference| {
                var column = try bound.plan.resolveColumn(reference);
                column.nullable = true;
                try values.validate(value, column);
                try values.write(writer, value);
            }
            for (key.values[key.len..]) |value| if (value != null) return error.InvalidRelationalOutput;
        },
    }
    if ((self.row.ordering != null) != (bound.plan.order_by.len != 0)) return error.InvalidRelationalOutput;
    try writer.writeByte(@intFromBool(self.row.ordering != null));
    if (self.row.ordering) |key| {
        try key.validate(bound.plan);
        if (key.sorted != bound.plan.hasAggregateOrder()) return error.InvalidRelationalOutput;
        switch (self.row.identity) {
            .pair => |pair| if (key.pair == null or e.Key.pairOrder(pair, key.pair.?) != .eq) return error.InvalidRelationalOutput,
            .group => |identity| {
                var canonical = key;
                canonical.sorted = false;
                if (try canonical.order(identity, bound.plan) != .eq) return error.InvalidRelationalOutput;
            },
        }
        try key.write(writer);
    }
    try writer.writeByte(self.row.len);
    var fields: [r.max_outputs]@import("Types.zig").Field = undefined;
    const schema = try bound.plan.outputSchema(&fields);
    var text_bytes: usize = 0;
    for (self.row.cells[0..self.row.len], schema.structure) |cell, field| {
        const value = try values.fromCell(cell, .{ .id = 1, .name = field.name, .type = field.type, .nullable = field.nullable });
        if (cell == .value and cell.value.atom == .bytes) {
            const bytes = cell.value.atom.bytes;
            if (bytes.len > values.max_text_bytes - text_bytes) return error.InvalidRelationalOutput;
            text_bytes += bytes.len;
        }
        try values.write(writer, value);
    }
}
pub fn decode(allocator: std.mem.Allocator, bound: r.Bound, bytes: []const u8) !Self {
    try bound.validate();
    if (bytes.len > max_bytes) return error.InvalidRelationalOutput;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FRO1")) return error.InvalidRelationalOutput;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    var result: Self = .{ .binding = (try reader.takeArray(32)).*, .ordinal = try reader.takeInt(u64, .little), .row = .{ .identity = undefined, .len = 0 } };
    switch (try reader.takeByte()) {
        0 => {
            const left = try r.RowIdentity.decode(try reader.takeArray(20));
            const right: ?r.RowIdentity = switch (try reader.takeByte()) {
                0 => null,
                1 => try r.RowIdentity.decode(try reader.takeArray(20)),
                else => return error.InvalidRelationalOutput,
            };
            result.row.identity = .{ .pair = .{ .left = left, .right = right } };
        },
        1 => {
            var key: e.Key = .{ .len = try reader.takeByte() };
            if (key.len != bound.plan.group_by.len) return error.InvalidRelationalOutput;
            for (key.values[0..key.len]) |*value| value.* = try values.read(&reader);
            result.row.identity = .{ .group = key };
        },
        else => return error.InvalidRelationalOutput,
    }
    result.row.ordering = switch (try reader.takeByte()) {
        0 => null,
        1 => try e.Key.read(&reader, bound.plan),
        else => return error.InvalidRelationalOutput,
    };
    result.row.len = try reader.takeByte();
    if (result.row.len != bound.plan.outputs.len) return error.InvalidRelationalOutput;
    for (result.row.cells[0..result.row.len]) |*cell| cell.* = values.cell(try values.read(&reader));
    if (reader.bufferedLen() != 0) return error.InvalidRelationalOutput;
    values.checkEncoding(bytes, result, bound) catch |err| return switch (err) {
        error.WriteFailed, error.InvalidRelationalEncoding => error.InvalidRelationalOutput,
        else => err,
    };
    result.row = try result.row.clone(allocator);
    return result;
}

/// Validate adjacent output occurrences using their persisted ordering evidence.
pub fn order(a: e.Output, b: e.Output, plan: r.Plan) !std.math.Order {
    if (plan.order_by.len != 0) {
        const left = a.ordering orelse return error.InvalidRelationalOutput;
        const right = b.ordering orelse return error.InvalidRelationalOutput;
        return left.order(right, plan);
    }
    return @import("RelationalDelta.zig").identityOrder(a.identity, b.identity, plan);
}
