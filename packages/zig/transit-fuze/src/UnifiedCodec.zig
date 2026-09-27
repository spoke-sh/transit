//! Canonical, finite FZP2 bytes. Decode borrows its input until the owner dies.
const std = @import("std");
const m = @import("Unified.zig");
pub const max_plan_bytes = 8192;
pub fn encode(plan: m.Plan, output: []u8) ![]const u8 {
    if (plan.version != 2) return error.UnsupportedPlan;
    if (plan.projection.len == 0 or plan.projection.len > m.max_columns) return error.InvalidProjection;
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("FZP2");
    try writer.writeByte(@backingInt(plan.aggregate));
    try writer.writeByte(@intCast(plan.projection.len));
    for (plan.projection, 0..) |column, index| {
        if (column >= m.max_columns) return error.UnknownColumn;
        for (plan.projection[0..index]) |previous| if (column == previous) return error.DuplicateProjection;
        try writer.writeByte(column);
    }
    try writer.writeByte(@intFromBool(plan.limit != null));
    try writer.writeInt(u64, plan.limit orelse 0, .little);
    switch (plan.predicate) {
        .all => try writer.writeByte(0),
        .state => |state| {
            if (state.column >= m.max_columns) return error.UnknownColumn;
            try writer.writeAll(&.{ 1, state.column, @backingInt(state.value) });
        },
        .compare => |comparison| {
            if (comparison.column >= m.max_columns) return error.UnknownColumn;
            try comparison.value.validate(std.meta.activeTag(comparison.value));
            try writer.writeAll(&.{ 2, comparison.column, @backingInt(comparison.op), @backingInt(std.meta.activeTag(comparison.value)) });
            switch (comparison.value) {
                .int64 => |value| try writer.writeInt(i64, value, .little),
                .uint64 => |value| try writer.writeInt(u64, value, .little),
                .float64 => |value| try writer.writeInt(u64, @bitCast(value), .little),
                .boolean => |value| try writer.writeByte(@intFromBool(value)),
                .utf8, .binary => |value| {
                    try writer.writeInt(u32, @intCast(value.len), .little);
                    try writer.writeAll(value);
                },
            }
        },
    }
    if (writer.end > max_plan_bytes) return error.PlanTooLarge;
    return writer.buffered();
}
pub fn decode(bytes: []const u8) !m.Plan {
    if (bytes.len > max_plan_bytes) return error.PlanTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FZP2")) return error.InvalidPlanEncoding;
    const aggregate = std.enums.fromInt(m.Plan.Aggregate, try reader.takeByte()) orelse return error.InvalidPlanEncoding;
    const projection = try reader.take(try reader.takeByte());
    const present = try reader.takeByte();
    if (present > 1) return error.InvalidPlanEncoding;
    const limit = try reader.takeInt(u64, .little);
    if (present == 0 and limit != 0) return error.InvalidPlanEncoding;
    const predicate: m.Plan.Predicate = switch (try reader.takeByte()) {
        0 => .all,
        1 => .{ .state = .{ .column = try reader.takeByte(), .value = std.enums.fromInt(m.State, try reader.takeByte()) orelse return error.InvalidPlanEncoding } },
        2 => blk: {
            const column = try reader.takeByte();
            const op = std.enums.fromInt(m.Plan.Comparison, try reader.takeByte()) orelse return error.InvalidPlanEncoding;
            const value: m.Scalar = switch (try reader.takeByte()) {
                1 => .{ .int64 = try reader.takeInt(i64, .little) },
                2 => .{ .uint64 = try reader.takeInt(u64, .little) },
                3 => .{ .float64 = @bitCast(try reader.takeInt(u64, .little)) },
                4 => .{ .boolean = switch (try reader.takeByte()) {
                    0 => false,
                    1 => true,
                    else => return error.InvalidPlanEncoding,
                } },
                5 => .{ .utf8 = try reader.take(try reader.takeInt(u32, .little)) },
                6 => .{ .binary = try reader.take(try reader.takeInt(u32, .little)) },
                else => return error.InvalidPlanEncoding,
            };
            break :blk .{ .compare = .{ .column = column, .op = op, .value = value } };
        },
        else => return error.InvalidPlanEncoding,
    };
    const plan: m.Plan = .{ .projection = projection, .limit = if (present == 1) limit else null, .aggregate = aggregate, .predicate = predicate };
    var canonical: [max_plan_bytes]u8 = undefined;
    if (reader.bufferedLen() != 0 or !std.mem.eql(u8, try encode(plan, &canonical), bytes)) return error.InvalidPlanEncoding;
    return plan;
}
