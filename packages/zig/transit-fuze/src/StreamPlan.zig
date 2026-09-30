//! Compact owned plan representation for durable caller jobs, independent of
//! the canonical typed-JSON fingerprint and of any Transit state value type.
const std = @import("std");
const f = @import("root.zig");
const Plan = f.Stream.Plan;
pub const encoded_bytes = 241;

pub fn encode(plan: Plan, output: []u8) ![]const u8 {
    if (plan.version != 1) return error.UnsupportedPlan;
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("FTL1");
    try writer.writeByte(switch (plan.aggregate) {
        .rows => 0,
        .count => 1,
        .sum => 2,
    });
    for (plan.projection) |column| {
        if (column) |index| if (index > 1) return error.UnknownColumn;
        try writer.writeByte(column orelse 255);
    }
    try writer.writeByte(@intFromBool(plan.limit != null));
    try writer.writeInt(u64, plan.limit orelse 0, .little);
    switch (plan.predicate) {
        .all => try writer.writeByte(0),
        .is_null => |column| {
            if (column > 1) return error.UnknownColumn;
            try writer.writeAll(&.{ 1, column });
        },
        .compare => |comparison| {
            if (comparison.column > 1) return error.UnknownColumn;
            const op: u8 = switch (comparison.op) {
                .eq => 0,
                .ne => 1,
                .lt => 2,
                .le => 3,
                .gt => 4,
                .ge => 5,
            };
            try writer.writeAll(&.{ 2, comparison.column, op });
            switch (comparison.value) {
                .null => try writer.writeByte(0),
                .int64 => |value| {
                    try writer.writeByte(1);
                    try writer.writeInt(i64, value, .little);
                },
                .boolean => |value| try writer.writeAll(&.{ 2, @intFromBool(value) }),
                .utf8, .binary => |bytes| {
                    try comparison.value.validate(if (comparison.value == .utf8) .utf8 else .binary);
                    // Padding in the typed plan participates in its fingerprint.
                    // Reject noncanonical padding instead of silently normalizing it.
                    if (!std.meta.eql(bytes, try f.model.Bytes.init(bytes.slice()))) return error.InvalidPlanEncoding;
                    try writer.writeAll(&.{ if (comparison.value == .utf8) @as(u8, 3) else 4, bytes.len });
                    try writer.writeAll(bytes.slice());
                },
            }
        },
    }
    return writer.buffered();
}

pub fn decode(bytes: []const u8) !Plan {
    if (bytes.len > encoded_bytes) return error.InvalidPlanEncoding;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FTL1")) return error.InvalidPlanEncoding;
    var plan: Plan = .{};
    plan.aggregate = switch (try reader.takeByte()) {
        0 => .rows,
        1 => .count,
        2 => .sum,
        else => return error.InvalidPlanEncoding,
    };
    for (&plan.projection) |*column| {
        const value = try reader.takeByte();
        column.* = if (value == 255) null else if (value < 2) value else return error.UnknownColumn;
    }
    const presence = try reader.takeByte();
    if (presence > 1) return error.InvalidPlanEncoding;
    const limit = try reader.takeInt(u64, .little);
    if (presence == 0 and limit != 0) return error.InvalidPlanEncoding;
    plan.limit = if (presence == 1) limit else null;
    plan.predicate = switch (try reader.takeByte()) {
        0 => .all,
        1 => .{ .is_null = try reader.takeByte() },
        2 => blk: {
            const column = try reader.takeByte();
            const op: f.Plan.Comparison = switch (try reader.takeByte()) {
                0 => .eq,
                1 => .ne,
                2 => .lt,
                3 => .le,
                4 => .gt,
                5 => .ge,
                else => return error.InvalidPlanEncoding,
            };
            const value: f.model.Cell = switch (try reader.takeByte()) {
                0 => .null,
                1 => .{ .int64 = try reader.takeInt(i64, .little) },
                2 => .{ .boolean = switch (try reader.takeByte()) {
                    0 => false,
                    1 => true,
                    else => return error.InvalidPlanEncoding,
                } },
                3 => .{ .utf8 = try f.model.Bytes.init(try reader.take(try reader.takeByte())) },
                4 => .{ .binary = try f.model.Bytes.init(try reader.take(try reader.takeByte())) },
                else => return error.InvalidPlanEncoding,
            };
            break :blk .{ .compare = .{ .column = column, .op = op, .value = value } };
        },
        else => return error.InvalidPlanEncoding,
    };
    if (reader.bufferedLen() != 0) return error.InvalidPlanEncoding;
    var canonical: [encoded_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(plan, &canonical))) return error.InvalidPlanEncoding;
    return plan;
}
