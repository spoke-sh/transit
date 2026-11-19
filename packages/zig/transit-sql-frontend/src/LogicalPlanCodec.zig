//! Canonical schema-bound logical plans. The enclosing source contract owns
//! capture, current-definition admission and authority; decoded plans own bytes.
const std = @import("std");
const q = @import("LogicalQuery.zig");
const t = @import("Types.zig");
const finite = @import("Finite.zig");
pub const max_bytes = 8192 + 256;
pub const definition = blk: {
    @setEvalBranchQuota(10000);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names:nullable-parameters:collations:scalar-programs:decimal-sum.2026-11-01", &hash, .{});
    break :blk hash;
};
pub const Owned = struct {
    descriptor: t.Decoded,
    plan: q.Plan,
    pub fn deinit(self: *Owned) void {
        self.descriptor.deinit();
        self.* = undefined;
    }
};
fn writeAtom(writer: *std.Io.Writer, schema: t.Type, atom: q.Plan.Atom) !void {
    switch (atom) {
        .all => try writer.writeByte(0),
        .state => |state| try writer.writeAll(&.{ 1, state.column, @backingInt(state.value) }),
        .null_compare => |comparison| try writer.writeAll(&.{ 4, comparison.column, @backingInt(comparison.op) }),
        .compare => |compare| {
            try writer.writeAll(&.{ 2, compare.column, @backingInt(compare.op) });
            var scratch: [t.Query.max_cell_bytes + 32]u8 = undefined;
            const bytes = try t.Codec.encodeBound(.{ .value = .{ .atom = compare.value } }, .{ .name = "literal", .type = schema.structure[compare.column].type }, &scratch);
            try writer.writeInt(u16, @intCast(bytes.len), .little);
            try writer.writeAll(bytes);
        },
    }
}
pub fn encode(plan: q.Plan, output: []u8) ![]const u8 {
    // Retain the operator's existing identity/8192-byte admission budget.
    _ = try plan.fingerprint();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("FQP1");
    try writer.writeAll(&definition);
    try writer.writeAll(&plan.source_basis);
    try writer.writeAll(&try plan.schema.fingerprint());
    try writer.writeByte(@backingInt(plan.aggregate));
    try writer.writeByte(@intCast(plan.projection.len));
    try writer.writeAll(plan.projection);
    for (0..plan.projection.len) |i| {
        const name = if (plan.output_names.len == 0) null else plan.output_names[i];
        try writer.writeByte(if (name) |bytes| @intCast(bytes.len) else 0);
        if (name) |bytes| try writer.writeAll(bytes);
    }
    try writer.writeByte(@intFromBool(plan.limit != null));
    try writer.writeInt(u64, plan.limit orelse 0, .little);
    switch (plan.predicate) {
        .program => |program| {
            try writer.writeAll(&.{ 3, @intCast(program.instructions.len) });
            for (program.instructions) |instruction| switch (instruction) {
                .atom => |atom| {
                    try writer.writeByte(0);
                    try writeAtom(&writer, plan.schema, atom);
                },
                .negate => try writer.writeByte(1),
                .conjunction => try writer.writeByte(2),
                .disjunction => try writer.writeByte(3),
            };
        },
        inline else => |value, tag| try writeAtom(&writer, plan.schema, @unionInit(q.Plan.Atom, @tagName(tag), value)),
    }
    try plan.collations.write(plan.schema, &writer);
    try plan.scalars.write(&writer);
    return writer.buffered();
}
fn readAtom(arena: std.mem.Allocator, reader: *std.Io.Reader, schema: t.Type, tag: u8) !q.Plan.Atom {
    return switch (tag) {
        0 => .all,
        1 => .{ .state = .{ .column = try reader.takeByte(), .value = std.enums.fromInt(t.State, try reader.takeByte()) orelse return error.InvalidPlanEncoding } },
        4 => .{ .null_compare = .{ .column = try reader.takeByte(), .op = std.enums.fromInt(finite.Comparison, try reader.takeByte()) orelse return error.InvalidPlanEncoding } },
        2 => blk: {
            const column = try reader.takeByte();
            if (column >= schema.structure.len) return error.UnknownColumn;
            const op = std.enums.fromInt(finite.Comparison, try reader.takeByte()) orelse return error.InvalidPlanEncoding;
            const size = try reader.takeInt(u16, .little);
            if (size > t.Query.max_cell_bytes + 32) return error.CellTooLarge;
            const value = try t.Codec.decodeBoundInto(arena, .{ .name = "literal", .type = schema.structure[column].type }, try reader.take(size));
            if (value != .value or value.value != .atom) return error.InvalidPlanEncoding;
            break :blk .{ .compare = .{ .column = column, .op = op, .value = value.value.atom } };
        },
        else => error.InvalidPlanEncoding,
    };
}
/// Compare the supplied immutable binding before decoding any dependent values.
/// All successful schema children, names and literals belong to the result.
pub fn decode(allocator: std.mem.Allocator, schema: t.Type, basis: [32]u8, bytes: []const u8) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const plan = try decodeInto(arena.allocator(), schema, basis, bytes);
    return .{ .descriptor = .{ .arena = arena, .type = plan.schema }, .plan = plan };
}
/// Compose canonical decoding within one caller-owned request arena. The arena
/// owns schema, names, literals and all partial allocations on failure.
pub fn decodeInto(arena: std.mem.Allocator, schema: t.Type, basis: [32]u8, bytes: []const u8) !q.Plan {
    if (bytes.len > max_bytes) return error.PlanTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FQP1")) return error.InvalidPlanEncoding;
    const saved_definition = reader.take(32) catch return error.UnsupportedPlanDefinition;
    if (!std.mem.eql(u8, saved_definition, &definition)) return error.UnsupportedPlanDefinition;
    if (!std.mem.eql(u8, try reader.take(32), &basis)) return error.SourceChanged;
    if (!std.mem.eql(u8, try reader.take(32), &try schema.fingerprint())) return error.SourceChanged;
    if (schema != .structure) return error.InvalidQuerySchema;
    const descriptor = try schema.cloneInto(arena);
    const a = arena;
    const aggregate = std.enums.fromInt(finite.Aggregate, try reader.takeByte()) orelse return error.InvalidPlanEncoding;
    const count = try reader.takeByte();
    if (count == 0 or count > 128) return error.InvalidProjection;
    const projection = try a.dupe(u8, try reader.take(count));
    const names = try a.alloc(?[]const u8, count);
    for (names) |*name| {
        const length = try reader.takeByte();
        name.* = if (length == 0) null else try a.dupe(u8, try reader.take(length));
    }
    const present = try reader.takeByte();
    const limit = try reader.takeInt(u64, .little);
    if (present > 1 or (present == 0 and limit != 0)) return error.InvalidPlanEncoding;
    var plan: q.Plan = .{ .schema = descriptor, .source_basis = basis, .aggregate = aggregate, .projection = projection, .output_names = names, .limit = if (present == 1) limit else null };
    const tag = try reader.takeByte();
    if (tag == 3) {
        const length = try reader.takeByte();
        if (length == 0 or length > q.Program.max_instructions) return error.InvalidPredicateProgram;
        const instructions = try a.alloc(q.Program.Instruction, length);
        for (instructions) |*instruction| instruction.* = switch (try reader.takeByte()) {
            0 => .{ .atom = try readAtom(arena, &reader, plan.schema, try reader.takeByte()) },
            1 => .negate,
            2 => .conjunction,
            3 => .disjunction,
            else => return error.InvalidPlanEncoding,
        };
        plan.predicate = .{ .program = .{ .instructions = instructions } };
    } else {
        const atom = try readAtom(arena, &reader, plan.schema, tag);
        plan.predicate = switch (atom) {
            inline else => |value, kind| @unionInit(@FieldType(q.Plan, "predicate"), @tagName(kind), value),
        };
    }
    plan.collations = try @import("QueryCollations.zig").read(plan.schema, &reader);
    plan.scalars = try @import("ScalarProgram.zig").read(arena, &reader);
    if (reader.bufferedLen() != 0) return error.InvalidPlanEncoding;
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(plan, &canonical))) return error.InvalidPlanEncoding;
    return plan;
}
