//! Canonical finite output record. Publication/manifest authority is external.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const Index = @import("RelationalIndex.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const max_bytes = 4 + 32 + 32 + 8 + 1 + @max(41, 1 + r.max_groups * 9) + 1 + r.max_outputs * 9;
binding: [32]u8,
ordinal: u64,
row: e.Output,
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}
pub fn encode(self: Self, bound: r.Bound, output: []u8) ![]const u8 {
    try bound.validate();
    if (!std.mem.eql(u8, &self.binding, &try bound.fingerprint())) return error.RelationalSourceChanged;
    if (self.row.len != bound.plan.outputs.len or self.ordinal >= bound.plan.budgets.output_rows) return error.InvalidRelationalOutput;
    for (self.row.cells[self.row.len..]) |cell| if (cell != .null) return error.InvalidRelationalOutput;
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
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
            for (key.values[0..key.len]) |value| try Index.writeOptional(&writer, value);
            for (key.values[key.len..]) |value| if (value != null) return error.InvalidRelationalOutput;
        },
    }
    try writer.writeByte(self.row.len);
    var fields: [r.max_outputs]@import("Types.zig").Field = undefined;
    const schema = try bound.plan.outputSchema(&fields);
    for (self.row.cells[0..self.row.len], schema.structure) |cell, field| {
        try writer.writeByte(@intFromBool(cell != .null));
        if (cell == .null) {
            if (!field.nullable) return error.InvalidRelationalOutput;
            try writer.writeInt(u64, 0, .little);
        } else {
            if (cell != .value or cell.value != .atom) return error.InvalidRelationalOutput;
            if (field.type == .uint64) {
                if (cell.value.atom != .unsigned) return error.InvalidRelationalOutput;
                try writer.writeInt(u64, std.math.cast(u64, cell.value.atom.unsigned) orelse return error.InvalidRelationalOutput, .little);
            } else {
                if (field.type != .int64 or cell.value.atom != .signed) return error.InvalidRelationalOutput;
                try writer.writeInt(i64, std.math.cast(i64, cell.value.atom.signed) orelse return error.InvalidRelationalOutput, .little);
            }
        }
    }
    return writer.buffered();
}
pub fn decode(bound: r.Bound, bytes: []const u8) !Self {
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
            for (key.values[0..key.len]) |*value| value.* = try Index.readOptional(&reader);
            result.row.identity = .{ .group = key };
        },
        else => return error.InvalidRelationalOutput,
    }
    result.row.len = try reader.takeByte();
    if (result.row.len != bound.plan.outputs.len) return error.InvalidRelationalOutput;
    var fields: [r.max_outputs]@import("Types.zig").Field = undefined;
    const schema = try bound.plan.outputSchema(&fields);
    for (result.row.cells[0..result.row.len], schema.structure) |*cell, field| {
        const present = try reader.takeByte();
        const raw = try reader.takeInt(u64, .little);
        if (present > 1 or (present == 0 and raw != 0)) return error.InvalidRelationalOutput;
        cell.* = if (present == 0) .null else if (field.type == .uint64) .{ .value = .{ .atom = .{ .unsigned = raw } } } else .{ .value = .{ .atom = .{ .signed = @as(i64, @bitCast(raw)) } } };
    }
    if (reader.bufferedLen() != 0) return error.InvalidRelationalOutput;
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try result.encode(bound, &canonical))) return error.InvalidRelationalOutput;
    return result;
}
