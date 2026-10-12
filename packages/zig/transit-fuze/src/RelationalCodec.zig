//! Owned, canonical relational plans. Full immutable Table schemas accompany
//! the existing prepared identity bytes; decoding never resolves live names.
const std = @import("std");
const r = @import("Relational.zig");
const table = @import("TableSchema.zig");
const native = @import("transit_protocol").Growth;
pub const max_bytes = 39 + r.max_sources * (4 + table.max_bytes) + r.max_plan_bytes;
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    plan: r.Plan,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}
pub fn encode(plan: r.Plan, output: []u8) ![]const u8 {
    try plan.validate();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("FRP1");
    try writer.writeAll(&definition());
    try writer.writeByte(@intCast(plan.sources.len));
    var schema_bytes: [table.max_bytes]u8 = undefined;
    for (plan.sources) |source| {
        const bytes = try source.schema.encode(&schema_bytes);
        try writer.writeInt(u32, @intCast(bytes.len), .little);
        try writer.writeAll(bytes);
    }
    var prepared: [r.max_plan_bytes]u8 = undefined;
    const bytes = try plan.encodePrepared(&prepared);
    try writer.writeInt(u16, @intCast(bytes.len), .little);
    try writer.writeAll(bytes);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const plan = try decodeInto(arena.allocator(), bytes);
    return .{ .arena = arena, .plan = plan };
}
/// arena owns all descriptors, including nested Table schema allocations, and
/// must release them as one lifetime on either success or failure.
pub fn decodeInto(arena: std.mem.Allocator, bytes: []const u8) !r.Plan {
    if (bytes.len > max_bytes) return error.RelationalPlanTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FRP1")) return error.InvalidRelationalEncoding;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    const count = try reader.takeByte();
    if (count == 0 or count > r.max_sources) return error.InvalidRelationalSources;
    const sources = try arena.alloc(r.Source, count);
    for (sources) |*source| {
        const size = try reader.takeInt(u32, .little);
        if (size > table.max_bytes) return error.RelationalPlanTooLarge;
        source.schema = (try table.decode(arena, try reader.take(size))).schema;
    }
    const size = try reader.takeInt(u16, .little);
    if (size > r.max_plan_bytes) return error.RelationalPlanTooLarge;
    const prepared = try reader.take(size);
    if (reader.bufferedLen() != 0) return error.InvalidRelationalEncoding;
    var input: std.Io.Reader = .fixed(prepared);
    const prefix = r.definition ++ "\x00prepared\x00";
    if (!std.mem.eql(u8, try input.take(prefix.len), prefix)) return error.IncompatibleDefinition;
    if (try input.takeByte() != count) return error.InvalidRelationalSources;
    for (sources) |*source| {
        source.alias = try text(arena, &input);
        inline for (.{ "realm", "resource", "catalog", "owner" }) |field| @field(source, field) = try input.takeInt(u64, .little);
        if (!std.mem.eql(u8, try input.take(32), &try source.schema.fingerprint())) return error.RelationalSourceChanged;
    }
    const join_tag = try input.takeByte();
    const join: ?r.Join = switch (join_tag) {
        0 => null,
        1, 2 => .{ .kind = if (join_tag == 1) .inner else .left, .left = try column(&input), .right = try column(&input) },
        else => return error.InvalidRelationalEncoding,
    };
    var filters: [r.max_sources]r.Predicate = @splat(.{});
    for (filters[0..count]) |*filter| filter.* = try predicate(arena, &input);
    const filter = try predicate(arena, &input);
    const group_count = try input.takeByte();
    if (group_count > r.max_groups) return error.InvalidRelationalGroups;
    const groups = try arena.alloc(r.Column, group_count);
    for (groups) |*group| group.* = try column(&input);
    const output_count = try input.takeByte();
    if (output_count == 0 or output_count > r.max_outputs) return error.InvalidRelationalOutputs;
    const outputs = try arena.alloc(r.Output, output_count);
    for (outputs) |*output| {
        output.name = try text(arena, &input);
        const tag = std.enums.fromInt(std.meta.Tag(r.Expression), try input.takeByte()) orelse return error.InvalidRelationalEncoding;
        output.expression = switch (tag) {
            .count_all => .count_all,
            .column => .{ .column = try column(&input) },
            .count => .{ .count = try column(&input) },
            .sum => .{ .sum = try column(&input) },
        };
    }
    const lifetime = std.enums.fromInt(r.Lifetime, try input.takeByte()) orelse return error.InvalidRelationalEncoding;
    var budgets: r.Budgets = undefined;
    inline for (.{ "resident_bytes", "spill_bytes", "result_bytes", "output_rows", "work_steps" }) |field| @field(budgets, field) = try input.takeInt(u64, .little);
    budgets.source_pins = try input.takeByte();
    if (input.bufferedLen() != 0) return error.InvalidRelationalEncoding;
    const plan: r.Plan = .{ .sources = sources, .join = join, .source_filters = filters, .filter = filter, .group_by = groups, .outputs = outputs, .lifetime = lifetime, .budgets = budgets };
    try plan.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(plan, &canonical))) return error.InvalidRelationalEncoding;
    return plan;
}
fn text(arena: std.mem.Allocator, reader: *std.Io.Reader) ![]const u8 {
    return arena.dupe(u8, try reader.take(try reader.takeByte()));
}
fn column(reader: *std.Io.Reader) !r.Column {
    return .{ .source = try reader.takeByte(), .id = try reader.takeInt(u64, .little) };
}
fn predicate(arena: std.mem.Allocator, reader: *std.Io.Reader) !r.Predicate {
    const count = try reader.takeByte();
    if (count > r.max_instructions) return error.InvalidRelationalPredicate;
    const instructions = try arena.alloc(r.Instruction, count);
    for (instructions) |*instruction| {
        const tag = std.enums.fromInt(std.meta.Tag(r.Instruction), try reader.takeByte()) orelse return error.InvalidRelationalEncoding;
        instruction.* = switch (tag) {
            .compare => .{ .compare = .{ .column = try column(reader), .op = std.enums.fromInt(r.Comparison, try reader.takeByte()) orelse return error.InvalidRelationalEncoding, .value = try reader.takeInt(i64, .little) } },
            .is_null => .{ .is_null = try column(reader) },
            .is_not_null => .{ .is_not_null = try column(reader) },
            .negate => .negate,
            .conjunction => .conjunction,
            .disjunction => .disjunction,
        };
    }
    return .{ .instructions = instructions };
}

test {
    _ = @import("relational_codec_test.zig");
}
