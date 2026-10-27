//! Canonical finite output record. Publication/manifest authority is external.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const values = @import("RelationalValues.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const fixed_bytes = 4 + 32 + 32 + 8 + 1 + @max(41, 1 + r.max_groups * 9) + 1 + r.max_outputs * 9;
pub const max_bytes = fixed_bytes + 2 * values.max_text_bytes;
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
    try writer.writeByte(self.row.len);
    var fields: [r.max_outputs]@import("Types.zig").Field = undefined;
    const schema = try bound.plan.outputSchema(&fields);
    var text_bytes: usize = 0;
    for (self.row.cells[0..self.row.len], schema.structure) |cell, field| {
        if (cell == .null) {
            if (!field.nullable) return error.InvalidRelationalOutput;
            try writer.writeByte(0);
        } else {
            if (cell != .value or cell.value != .atom) return error.InvalidRelationalOutput;
            if (field.type == .uint64) {
                if (cell.value.atom != .unsigned) return error.InvalidRelationalOutput;
                try writer.writeByte(3);
                try writer.writeInt(u64, std.math.cast(u64, cell.value.atom.unsigned) orelse return error.InvalidRelationalOutput, .little);
            } else if (field.type == .utf8) {
                if (cell.value.atom != .bytes or cell.value.atom.bytes.len > values.max_text_bytes - text_bytes) return error.InvalidRelationalOutput;
                const bytes = cell.value.atom.bytes;
                try @import("Types.zig").Semantics.validate(cell.value.atom, .utf8);
                text_bytes += bytes.len;
                try values.write(writer, .{ .text = bytes });
            } else {
                if (field.type != .int64 or cell.value.atom != .signed) return error.InvalidRelationalOutput;
                try writer.writeByte(1);
                try writer.writeInt(i64, std.math.cast(i64, cell.value.atom.signed) orelse return error.InvalidRelationalOutput, .little);
            }
        }
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
    result.row.len = try reader.takeByte();
    if (result.row.len != bound.plan.outputs.len) return error.InvalidRelationalOutput;
    for (result.row.cells[0..result.row.len]) |*cell| cell.* = switch (try reader.takeByte()) {
        0 => .null,
        1 => .{ .value = .{ .atom = .{ .signed = try reader.takeInt(i64, .little) } } },
        2 => value: {
            const length = try reader.takeInt(u32, .little);
            if (length > values.max_text_bytes) return error.InvalidRelationalOutput;
            break :value .{ .value = .{ .atom = .{ .bytes = try reader.take(length) } } };
        },
        3 => .{ .value = .{ .atom = .{ .unsigned = try reader.takeInt(u64, .little) } } },
        else => return error.InvalidRelationalOutput,
    };
    if (reader.bufferedLen() != 0) return error.InvalidRelationalOutput;
    values.checkEncoding(bytes, result, bound) catch |err| return switch (err) {
        error.WriteFailed, error.InvalidRelationalEncoding => error.InvalidRelationalOutput,
        else => err,
    };
    result.row = try result.row.clone(allocator);
    return result;
}
