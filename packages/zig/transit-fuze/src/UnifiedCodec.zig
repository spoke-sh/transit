//! Canonical, finite FZP1 bytes. Decode borrows its input until the owner dies.
const std = @import("std");
const m = @import("Unified.zig");
pub const max_plan_bytes = 8192;
/// SHA-256 of the exact domain specified in UNIFIED_QUERY_V1.md.
pub const definition = [_]u8{ 0x58, 0xae, 0x72, 0xe1, 0xf9, 0xa4, 0xb5, 0x89, 0x53, 0x6e, 0x5a, 0x0d, 0x26, 0x2d, 0x6e, 0x6a, 0xeb, 0xcc, 0x2f, 0xab, 0x40, 0x69, 0x8b, 0x4b, 0xfe, 0xa6, 0x83, 0x32, 0x81, 0xad, 0x9f, 0x3c };
pub fn encode(plan: m.Plan, output: []u8) ![]const u8 {
    try plan.validateShape();
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("FZP1");
    try writer.writeAll(&definition);
    try writer.writeByte(@backingInt(plan.aggregate));
    try writer.writeByte(@intCast(plan.projection.len));
    try writer.writeAll(plan.projection);
    for (plan.output_names[0..plan.projection.len]) |name| {
        try writer.writeByte(if (name) |value| value.len else 0);
        if (name) |value| try writer.writeAll(value.slice());
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
    if (!std.mem.eql(u8, try reader.take(4), "FZP1")) return error.InvalidPlanEncoding;
    const saved_definition = reader.take(definition.len) catch return error.UnsupportedPlanDefinition;
    if (!std.mem.eql(u8, saved_definition, &definition)) return error.UnsupportedPlanDefinition;
    const aggregate = std.enums.fromInt(m.Plan.Aggregate, try reader.takeByte()) orelse return error.InvalidPlanEncoding;
    const projection = try reader.take(try reader.takeByte());
    if (projection.len == 0 or projection.len > m.max_columns) return error.InvalidProjection;
    var output_names: [m.max_columns]?m.Name = @splat(null);
    for (output_names[0..projection.len]) |*name| {
        const length = try reader.takeByte();
        if (length > 0) name.* = try m.Name.init(try reader.take(length));
    }
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
    const plan: m.Plan = .{ .projection = projection, .output_names = output_names, .limit = if (present == 1) limit else null, .aggregate = aggregate, .predicate = predicate };
    var canonical: [max_plan_bytes]u8 = undefined;
    if (reader.bufferedLen() != 0 or !std.mem.eql(u8, try encode(plan, &canonical), bytes)) return error.InvalidPlanEncoding;
    return plan;
}
