//! Frozen row projections for original workload results. The caller supplies
//! the verified frozen source schema; this compiler performs no catalog lookup,
//! admission or authorization. Source names are needed only during preparation.
const std = @import("std");
const f = @import("root.zig");
const p = @import("transit_protocol");
const codec = f.LogicalPlanCodec;

pub const Field = union(enum) {
    column: f.TableSchema.ColumnId,
    partition,
    offset,
    lease_epoch,
    attempt,
};
pub const Source = struct {
    binding: p.LogWorkload.Binding,
    schema: f.TableSchema.Schema,
    pub fn validate(self: Source) !void {
        try self.binding.validate();
        try self.schema.validate();
        if (self.schema.object != self.binding.target().interpretation.object.object) return error.WorkloadProjectionSourceChanged;
        switch (self.binding) {
            .stream => |value| if (value.kind != .append and value.kind != .consume) return error.WorkloadProjectionUnavailable,
            .queue => |value| if (value.kind != .enqueue and value.kind != .claim) return error.WorkloadProjectionUnavailable,
        }
    }
};
pub const Layout = struct {
    fields: [f.TableSchema.max_columns]f.Types.Field = undefined,
    count: usize,
    collations: f.QueryCollations,
    pub fn typeOf(self: *const Layout) f.Types.Type {
        return .{ .structure = self.fields[0..self.count] };
    }
};

/// The source adapter chooses fields before compilation, including any fields
/// used only by a predicate. Column IDs remain distinct from physical ordinals.
/// A star expansion can select application columns without inventing metadata.
pub fn layout(source: Source, fields: []const Field) !Layout {
    try source.validate();
    if (fields.len == 0 or fields.len > f.TableSchema.max_columns) return error.InvalidWorkloadProjection;
    var result: Layout = .{ .count = fields.len, .collations = .{} };
    for (fields, 0..) |field, index| {
        const descriptor: f.Types.Field = switch (field) {
            .column => |id| blk: {
                const column = source.schema.columns[try source.schema.index(id)];
                result.collations.columns[index] = column.collation;
                break :blk .{ .name = column.name, .type = column.type, .nullable = column.nullable };
            },
            .partition => .{ .name = "_partition", .type = .uint64 },
            .offset => .{ .name = "_offset", .type = .uint64 },
            .lease_epoch, .attempt => blk: {
                if (source.binding != .queue or source.binding.queue.kind != .claim) return error.WorkloadProjectionUnavailable;
                break :blk .{ .name = if (field == .lease_epoch) "_lease_epoch" else "_attempt", .type = .uint64 };
            },
        };
        for (result.fields[0..index]) |earlier| if (std.mem.eql(u8, earlier.name, descriptor.name)) return error.DuplicateColumn;
        result.fields[index] = descriptor;
    }
    try result.typeOf().validate(.{});
    try result.collations.validate(result.typeOf());
    return result;
}

/// Freeze the native operation, exact schema (including physical and semantic
/// descriptors), and ordered input layout. No result receipt is invented before
/// native acceptance; its actual selection belongs to the result owner later.
pub fn basis(allocator: std.mem.Allocator, source: Source, fields: []const Field) ![32]u8 {
    _ = try layout(source, fields);
    var schema_bytes: [f.TableSchema.max_bytes]u8 = undefined;
    const schema = try source.schema.encode(&schema_bytes);
    const body = try p.Json.valueAllocBounded(allocator, .{ .binding = source.binding, .fields = fields }, 32 * 1024);
    defer allocator.free(body);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.fuze.workload.projection.v1\x00");
    hash.update(&p.Growth.definition_bytes);
    hash.update(schema);
    hash.update(body);
    return hash.finalResult();
}

fn requireProjection(source: Source, plan: f.LogicalQuery.Plan, expected: Layout) !void {
    try plan.validate();
    // Acquisition bounds belong to the native workload. Projection cannot stop
    // early and manufacture complete native coverage, or aggregate away leases.
    if (plan.aggregate != .rows or plan.limit != null or !std.meta.eql(plan.collations, expected.collations)) return error.InvalidWorkloadProjection;
    // Claim predicates must select candidates before lease acquisition. A
    // projection may not claim unrelated messages and then hide their leases.
    // RETURNING likewise describes every accepted append row.
    if (plan.predicate != .all and !(source.binding == .stream and source.binding.stream.kind == .consume)) return error.InvalidWorkloadProjection;
}

pub fn compile(allocator: std.mem.Allocator, source: Source, fields: []const Field, name: []const u8, sql: []const u8, location: ?*f.Sql.Location) !f.TableSelect.Owned {
    const input = try layout(source, fields);
    var owned = try f.TableSelect.compile(allocator, sql, name, input.typeOf(), try basis(allocator, source, fields), location);
    errdefer owned.deinit();
    owned.plan.collations = input.collations;
    try requireProjection(source, owned.plan, input);
    return owned;
}

pub fn encode(source: Source, fields: []const Field, plan: f.LogicalQuery.Plan, allocator: std.mem.Allocator, output: []u8) ![]const u8 {
    const input = try layout(source, fields);
    try requireProjection(source, plan, input);
    if (!std.mem.eql(u8, &plan.source_basis, &try basis(allocator, source, fields)) or
        !std.mem.eql(u8, &try plan.schema.fingerprint(), &try input.typeOf().fingerprint())) return error.WorkloadProjectionSourceChanged;
    return codec.encode(plan, output);
}

/// Own all restored names, literals and schema independently of caller buffers.
/// Restore verifies the frozen binding and layout; it never reparses SQL.
pub fn restore(allocator: std.mem.Allocator, source: Source, fields: []const Field, bytes: []const u8) !codec.Owned {
    const input = try layout(source, fields);
    var owned = try codec.decode(allocator, input.typeOf(), try basis(allocator, source, fields), bytes);
    errdefer owned.deinit();
    try requireProjection(source, owned.plan, input);
    return owned;
}

/// A bounded evaluator over validated native rows. Stable column IDs resolve
/// once at initialization. Schema, layout and plan remain borrowed and immutable
/// for its lifetime; output borrows the input values until the next row/reset.
pub const Projector = struct {
    pub const Metadata = struct { offset: u64, lease: ?p.StreamQueue.Lease = null };
    source: Source,
    fields: []const Field,
    plan: f.LogicalQuery.Plan,
    columns: [f.TableSchema.max_columns]u8 = @splat(0),
    input: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined,
    output: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined,
    failure: ?f.LogicalQuery.Plan.PredicateFailure = null,

    pub fn init(allocator: std.mem.Allocator, source: Source, fields: []const Field, plan: f.LogicalQuery.Plan) !Projector {
        const expected = try layout(source, fields);
        try requireProjection(source, plan, expected);
        if (!std.mem.eql(u8, &plan.source_basis, &try basis(allocator, source, fields)) or
            !std.mem.eql(u8, &try plan.schema.fingerprint(), &try expected.typeOf().fingerprint())) return error.WorkloadProjectionSourceChanged;
        var result: Projector = .{ .source = source, .fields = fields, .plan = plan };
        for (fields, 0..) |field, i| if (field == .column) {
            result.columns[i] = @intCast(try source.schema.index(field.column));
        };
        return result;
    }

    /// The source owns row decoding/validation and native result authentication.
    /// This pure evaluator allocates nothing and never alters delivery coverage.
    pub fn row(self: *Projector, cells: []const f.Types.Values.Cell, metadata: Metadata) !?[]const f.Types.Values.Cell {
        self.failure = null;
        if (cells.len != self.source.schema.columns.len) return error.InvalidWorkloadProjectionRow;
        if (self.source.binding == .queue and self.source.binding.queue.kind == .claim) {
            const lease = metadata.lease orelse return error.InvalidWorkloadProjectionRow;
            try lease.validate();
            if (!std.meta.eql(lease.target, self.source.binding.target()) or
                !std.meta.eql(lease.claim, self.source.binding.operation()) or lease.offset != metadata.offset) return error.WorkloadProjectionSourceChanged;
        } else if (metadata.lease != null) return error.InvalidWorkloadProjectionRow;
        for (self.fields, 0..) |field, i| self.input[i] = switch (field) {
            .column => cells[self.columns[i]],
            .partition => .{ .value = .{ .atom = .{ .unsigned = self.source.binding.target().partition } } },
            .offset => .{ .value = .{ .atom = .{ .unsigned = metadata.offset } } },
            .lease_epoch => .{ .value = .{ .atom = .{ .unsigned = metadata.lease.?.epoch } } },
            .attempt => .{ .value = .{ .atom = .{ .unsigned = metadata.lease.?.attempt } } },
        };
        if (!try self.plan.matches(self.input[0..self.fields.len], &self.failure)) return null;
        for (self.plan.projection, 0..) |index, i| self.output[i] = self.input[index];
        return self.output[0..self.plan.projection.len];
    }
};

test "workload projections freeze original identity layout aliases and collations" {
    const t = std.testing;
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(5) }, .partition = 1 };
    var columns = [_]f.TableSchema.Column{
        .{ .id = 11, .name = "payload", .type = .utf8, .nullable = false, .collation = .ascii_ci },
        .{ .id = 17, .name = "value", .type = .int64, .nullable = true },
    };
    var source: Source = .{ .binding = .{ .stream = .{ .definition = p.Growth.current_definition, .operation = .{ .scope = scope, .principal = 1, .operation = 19 }, .target = target, .kind = .consume, .intent = @splat(6) } }, .schema = .{ .object = 7, .revision = 1, .next_column = 18, .columns = &columns, .primary_key = &.{} } };
    const fields = [_]Field{ .offset, .{ .column = 17 }, .{ .column = 11 }, .partition };
    var bytes: [codec.max_bytes]u8 = undefined;
    var length: usize = undefined;
    {
        var compiled = try compile(t.allocator, source, &fields, "events", "SELECT _offset, payload AS body, _partition FROM events WHERE payload = 'Alpha'", null);
        defer compiled.deinit();
        try t.expectEqualSlices(u8, &.{ 0, 2, 3 }, compiled.plan.projection);
        length = (try encode(source, &fields, compiled.plan, t.allocator, &bytes)).len;
    }
    var restored = try restore(t.allocator, source, &fields, bytes[0..length]);
    defer restored.deinit();
    @memset(bytes[0..length], 0);
    try t.expectEqualStrings("body", restored.plan.output_names[1].?);
    try t.expectEqual(.ascii_ci, restored.plan.collations.columns[2]);
    try t.expectEqual(f.Types.Type.uint64, restored.plan.schema.structure[0].type);
    try t.expectEqualStrings("Alpha", restored.plan.predicate.compare.value.bytes);
    length = (try encode(source, &fields, restored.plan, t.allocator, &bytes)).len;
    var projector = try Projector.init(t.allocator, source, &fields, restored.plan);
    var cells = [_]f.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .bytes = "aLpHa" } } },
        .{ .value = .{ .atom = .{ .signed = 42 } } },
    };
    const projected = (try projector.row(&cells, .{ .offset = 23 })).?;
    try t.expectEqual(23, projected[0].value.atom.unsigned);
    try t.expectEqualStrings("aLpHa", projected[1].value.atom.bytes);
    try t.expectEqual(target.partition, projected[2].value.atom.unsigned);
    cells[0] = .{ .value = .{ .atom = .{ .bytes = "beta" } } };
    try t.expectEqual(null, try projector.row(&cells, .{ .offset = 24 }));
    source.binding.stream.operation.operation += 1;
    try t.expectError(error.SourceChanged, restore(t.allocator, source, &fields, bytes[0..length]));
    source.binding.stream.operation.operation -= 1;
    const reordered = [_]Field{ .offset, .{ .column = 11 }, .{ .column = 17 }, .partition };
    try t.expectError(error.SourceChanged, restore(t.allocator, source, &reordered, bytes[0..length]));
    columns[0].collation = .utf8_binary;
    try t.expectError(error.SourceChanged, restore(t.allocator, source, &fields, bytes[0..length]));
    columns[0].collation = .ascii_ci;
    try t.expectError(error.InvalidWorkloadProjection, compile(t.allocator, source, &fields, "tasks", "SELECT value FROM tasks LIMIT 1", null));
    try t.expectError(error.InvalidWorkloadProjection, compile(t.allocator, source, &fields, "tasks", "SELECT COUNT(*) FROM tasks", null));
    try t.expectError(error.DuplicateColumn, layout(source, &.{ .offset, .offset }));
    try t.expectError(error.WorkloadProjectionUnavailable, layout(source, &.{.lease_epoch}));
    const original = source.binding.operation();
    source.binding = .{ .queue = .{ .definition = p.Growth.current_definition, .operation = original, .target = target, .kind = .claim, .intent = @splat(7) } };
    const claimed_fields = [_]Field{ .lease_epoch, .attempt, .{ .column = 17 } };
    var claim = try compile(t.allocator, source, &claimed_fields, "tasks", "SELECT _lease_epoch, _attempt, value FROM tasks", null);
    defer claim.deinit();
    var claim_projector = try Projector.init(t.allocator, source, &claimed_fields, claim.plan);
    var lease: p.StreamQueue.Lease = .{ .target = target, .claim = original, .offset = 13, .epoch = 7, .attempt = 2, .expires_ms = 1000 };
    const selected = (try claim_projector.row(&cells, .{ .offset = 13, .lease = lease })).?;
    try t.expectEqual(7, selected[0].value.atom.unsigned);
    try t.expectEqual(2, selected[1].value.atom.unsigned);
    try t.expectEqual(42, selected[2].value.atom.signed);
    try t.expectError(error.InvalidWorkloadProjectionRow, claim_projector.row(&cells, .{ .offset = 13 }));
    lease.claim.operation += 1;
    try t.expectError(error.WorkloadProjectionSourceChanged, claim_projector.row(&cells, .{ .offset = 13, .lease = lease }));
    try t.expectError(error.InvalidWorkloadProjection, compile(t.allocator, source, &claimed_fields, "tasks", "SELECT value FROM tasks WHERE value = 42", null));
    source.binding.queue.kind = .enqueue;
    try t.expectError(error.WorkloadProjectionUnavailable, layout(source, &claimed_fields));
}
