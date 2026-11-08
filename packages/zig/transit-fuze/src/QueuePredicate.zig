//! Immutable, target-bound acquisition predicates. No lease fields participate
//! in selection; the result projection remains a separate unfiltered plan.
const std = @import("std");
const f = @import("root.zig");
const p = @import("transit_protocol");
const Field = f.WorkloadProjection.Field;

// These are definition-bound ceilings, independent of the output lease count.
pub const max_examined_rows = 4096;
pub const max_examined_bytes = 4 * 1024 * 1024;

fn basis(allocator: std.mem.Allocator, target: p.StreamQueue.Partition, schema: f.TableSchema.Schema, fields: []const Field) ![32]u8 {
    try target.validate();
    if (schema.object != target.interpretation.object.object) return error.SourceChanged;
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    const encoded = try schema.encode(&bytes);
    const body = try p.Json.valueAllocBounded(allocator, .{ .target = target, .fields = fields }, 16384);
    defer allocator.free(body);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.queue.predicate.v1\x00");
    hash.update(&p.Growth.definition_bytes);
    hash.update(encoded);
    hash.update(body);
    return hash.finalResult();
}

fn requireAtom(atom: f.LogicalQuery.Plan.Atom, fields: []const Field) !void {
    const column = switch (atom) {
        .all => return,
        .state => |value| value.column,
        .compare => |value| value.column,
        .null_compare => |value| value.column,
    };
    if (column >= fields.len) return error.UnknownColumn;
    switch (fields[column]) {
        .column, .partition, .offset => {},
        else => return error.QueuePredicateLeaseField,
    }
}
fn requirePlan(plan: f.LogicalQuery.Plan, fields: []const Field, layout: f.WorkloadProjection.Layout) !void {
    try plan.validate();
    if (plan.aggregate != .rows or plan.limit != null or plan.projection.len != 1 or plan.projection[0] != 0 or
        !std.meta.eql(plan.collations, layout.collations) or plan.scalars.instructions.len != 0) return error.InvalidQueuePredicate;
    for (plan.output_names) |name| if (name != null) return error.InvalidQueuePredicate;
    switch (plan.predicate) {
        .program => |program| for (program.instructions) |instruction| {
            if (instruction == .atom) try requireAtom(instruction.atom, fields);
        },
        inline else => |value, tag| try requireAtom(@unionInit(f.LogicalQuery.Plan.Atom, @tagName(tag), value), fields),
    }
}

pub fn encode(allocator: std.mem.Allocator, target: p.StreamQueue.Partition, schema: f.TableSchema.Schema, fields: []const Field, original: f.LogicalQuery.Plan) !p.QueuePredicate {
    const layout = try f.WorkloadProjection.schemaLayout(schema, fields, .claim);
    var plan = original;
    plan.projection = &.{0};
    plan.output_names = &.{};
    plan.limit = null;
    plan.aggregate = .rows;
    plan.source_basis = try basis(allocator, target, schema, fields);
    try requirePlan(plan, fields, layout);
    var bytes: [p.QueuePredicate.max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("QPR1");
    try writer.writeByte(@intCast(fields.len));
    for (fields) |field| switch (field) {
        .column => |id| {
            try writer.writeByte(0);
            try writer.writeInt(u64, id, .little);
        },
        .partition => try writer.writeByte(1),
        .offset => try writer.writeByte(2),
        .lease_epoch => try writer.writeByte(3),
        .attempt => try writer.writeByte(4),
        .receipt_handle => try writer.writeByte(5),
    };
    const prefix = writer.buffered().len;
    const encoded = f.LogicalPlanCodec.encode(plan, bytes[prefix..]) catch |err| return if (err == error.WriteFailed) error.QueuePredicateTooLarge else err;
    return p.QueuePredicate.init(bytes[0 .. prefix + encoded.len]);
}

/// All decoded literals and fields belong to one request arena. Per-row
/// evaluation is allocation-free and borrows only that row's decoded cells.
pub const Evaluator = struct {
    plan: f.LogicalQuery.Plan,
    fields: []const Field,
    columns: [f.TableSchema.max_columns]u8 = @splat(0),
    input: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined,
    partition: u32,
    width: usize,

    pub fn init(arena: std.mem.Allocator, target: p.StreamQueue.Partition, schema: f.TableSchema.Schema, predicate: p.QueuePredicate) !Evaluator {
        try predicate.validate();
        var reader: std.Io.Reader = .fixed(predicate.slice());
        if (!std.mem.eql(u8, try reader.take(4), "QPR1")) return error.InvalidQueuePredicate;
        const count = try reader.takeByte();
        if (count == 0 or count > f.TableSchema.max_columns) return error.InvalidQueuePredicate;
        const fields = try arena.alloc(Field, count);
        for (fields) |*field| field.* = switch (try reader.takeByte()) {
            0 => .{ .column = try reader.takeInt(u64, .little) },
            1 => .partition,
            2 => .offset,
            3 => .lease_epoch,
            4 => .attempt,
            5 => .receipt_handle,
            else => return error.InvalidQueuePredicate,
        };
        const layout = try f.WorkloadProjection.schemaLayout(schema, fields, .claim);
        const plan = try f.LogicalPlanCodec.decodeInto(arena, layout.typeOf(), try basis(arena, target, schema, fields), predicate.slice()[reader.seek..]);
        try requirePlan(plan, fields, layout);
        var result: Evaluator = .{ .plan = plan, .fields = fields, .partition = target.partition, .width = schema.columns.len };
        for (fields, 0..) |field, i| if (field == .column) {
            result.columns[i] = @intCast(try schema.index(field.column));
        };
        return result;
    }
    pub fn matches(self: *Evaluator, cells: []const f.Types.Values.Cell, offset: u64) !bool {
        if (cells.len != self.width) return error.InvalidQueuePredicate;
        for (self.fields, 0..) |field, i| self.input[i] = switch (field) {
            .column => cells[self.columns[i]],
            .partition => .{ .value = .{ .atom = .{ .unsigned = self.partition } } },
            .offset => .{ .value = .{ .atom = .{ .unsigned = offset } } },
            // These can be projection inputs but requirePlan excludes them
            // from every predicate atom before any row is visited.
            else => .null,
        };
        var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
        return self.plan.matches(self.input[0..self.fields.len], &failure);
    }
};
