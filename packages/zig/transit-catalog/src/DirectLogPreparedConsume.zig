//! Catalog binding for finite positional CONSUME. Preparing or freezing a body
//! grants no read pin, admission, group assignment or settlement authority.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();

connection: w.Connection,
definition: c.DirectLog.Definition,
compiled: f.LogConsumeSql.Prepared,

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const target = try f.LogConsumeSql.target(scratch.allocator(), text, dialect, location);
    const response = try client.call(.{ .log_lookup = .{ .namespace = namespace, .name = target.name } });
    defer response.deinit();
    return init(allocator, client.connection, namespace, text, response.value.result.log_lookup orelse return error.CatalogNameNotFound, dialect, location);
}

pub fn init(allocator: std.mem.Allocator, connection: w.Connection, namespace: u64, text: []const u8, metadata: c.DirectLogProtocol.Definition, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    try connection.validate();
    var declaration = try c.DirectLogProtocol.decodeMetadata(allocator, connection, metadata);
    defer declaration.deinit();
    if (metadata.declaration.properties.namespace != namespace or metadata.declaration.stored.retired) return error.CatalogDefinitionChanged;
    if (metadata.declaration.kind() != .stream) return error.CatalogKindMismatch;
    var compiled = try f.LogConsumeSql.Prepared.init(allocator, text, declaration.definition.schema, dialect, location);
    errdefer compiled.deinit();
    if (!std.mem.eql(u8, metadata.declaration.properties.name.slice(), compiled.template.name)) return error.CatalogDefinitionChanged;
    return .{ .connection = connection, .definition = metadata.declaration, .compiled = compiled };
}

pub fn deinit(self: *Self) void {
    self.compiled.deinit();
    self.* = undefined;
}
pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    try c.DirectLogClient.requireCurrent(client, self.definition);
}
pub fn bindPrepared(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, values: []const ?f.Types.Values.Atom, diagnostic: ?*f.Sql.Binding, fresh: bool) !c.DirectWorkloadIntent {
    if (!fresh) try self.validate(client) else if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    return self.freeze(allocator, operation, values, diagnostic);
}

/// A conservative enclosure of matching metadata values. Payload predicates
/// retain their exact Fuze evaluation; they never provide routing authority.
const Interval = struct {
    first: u64 = 0,
    last: u64 = std.math.maxInt(u64),
    empty: bool = false,
    fn intersect(a: Interval, b: Interval) Interval {
        const first = @max(a.first, b.first);
        const last = @min(a.last, b.last);
        return .{ .first = first, .last = last, .empty = a.empty or b.empty or first > last };
    }
    fn enclose(a: Interval, b: Interval) Interval {
        if (a.empty) return b;
        if (b.empty) return a;
        return .{ .first = @min(a.first, b.first), .last = @max(a.last, b.last) };
    }
};
const Bounds = struct {
    partition: Interval = .{},
    offset: Interval = .{},
    fn empty(self: Bounds) bool {
        return self.partition.empty or self.offset.empty;
    }
    fn atom(value: f.LogicalQuery.Plan.Atom, fields: []const f.WorkloadProjection.Field) Bounds {
        if (value != .compare) return .{};
        const comparison = value.compare;
        const field = fields[comparison.column];
        if (field != .partition and field != .offset) return .{};
        // Admitted metadata types are uint32/uint64; do not reinterpret another
        // logical value if this helper is used with a different layout later.
        if (comparison.value != .unsigned or comparison.value.unsigned > std.math.maxInt(u64)) return .{};
        const number: u64 = @intCast(comparison.value.unsigned);
        const range: Interval = switch (comparison.op) {
            .eq => .{ .first = number, .last = number },
            .ne => .{},
            .ge => .{ .first = number },
            .gt => if (number == std.math.maxInt(u64)) .{ .empty = true } else .{ .first = number + 1 },
            .le => .{ .last = number },
            .lt => if (number == 0) .{ .empty = true } else .{ .last = number - 1 },
        };
        return if (field == .partition) .{ .partition = range } else .{ .offset = range };
    }
    fn combine(a: Bounds, b: Bounds, conjunction: bool) Bounds {
        if (!conjunction) {
            if (a.empty()) return b;
            if (b.empty()) return a;
        }
        return .{
            .partition = if (conjunction) a.partition.intersect(b.partition) else a.partition.enclose(b.partition),
            .offset = if (conjunction) a.offset.intersect(b.offset) else a.offset.enclose(b.offset),
        };
    }
};
fn bounds(bound: *const f.LogConsumeSql.Bound) !Bounds {
    const plan = bound.plan.plan;
    try plan.validate();
    if (plan.schema.structure.len != bound.fields.len) return error.InvalidWorkloadProjection;
    return switch (plan.predicate) {
        .program => |program| blk: {
            var stack: [f.LogicalQuery.Program.max_instructions]Bounds = undefined;
            var depth: usize = 0;
            for (program.instructions) |instruction| switch (instruction) {
                .atom => |value| {
                    stack[depth] = Bounds.atom(value, bound.fields);
                    depth += 1;
                },
                // Complementing an enclosure is unsound. Exact negation stays
                // in the predicate, while its routing enclosure becomes all.
                .negate => stack[depth - 1] = .{},
                .conjunction, .disjunction => {
                    const right = stack[depth - 1];
                    depth -= 1;
                    stack[depth - 1] = stack[depth - 1].combine(right, instruction == .conjunction);
                },
            };
            break :blk stack[0];
        },
        inline else => |value, tag| Bounds.atom(@unionInit(f.LogicalQuery.Plan.Atom, @tagName(tag), value), bound.fields),
    };
}

/// Freeze one exact native read and its owned projection. The native owner
/// chooses the retained upper cut at acceptance. LIMIT never becomes an offset
/// span; upper-offset comparisons remain exact row predicates within that cut.
/// Named groups and waits need their own admission owners before this adapter
/// can accept them. No group ID is inferred from text and no wait is discarded.
pub fn freeze(self: *const Self, allocator: std.mem.Allocator, operation: u64, values: []const ?f.Types.Values.Atom, diagnostic: ?*f.Sql.Binding) !c.DirectWorkloadIntent {
    const identity: p.DataLifecycle.Operation = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation };
    try identity.validate();
    var bound = try self.compiled.bind(allocator, values, diagnostic);
    defer bound.deinit();
    if (bound.group != null or bound.wait_ms != null) return error.UnsupportedConstruct;
    const selected = try bounds(&bound);
    if (selected.empty()) return error.UnsupportedConstruct;
    const count = self.definition.stored.declaration.configuration.partitioning.count;
    if (count == 0) return error.InvalidLogPartitioning;
    const partitions = selected.partition.intersect(.{ .last = count - 1 });
    if (partitions.empty) return error.InvalidLogPartitioning;
    if (partitions.first != partitions.last) return error.LogPartitionRequired;
    const work: c.DirectWorkloadIntent.Work = .{ .stream = .{ .work = .{ .consume = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = self.definition.stored.declaration.interpretation, .partition = @intCast(partitions.first) },
        .operation = identity,
        .group = null,
        .from = selected.offset.first,
        .until = null,
        .timestamp = null,
    } }, .payload = null } };
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const a = scratch.allocator();
    const schema = self.compiled.schema.schema;
    const input: f.WorkloadProjection.Source = .{ .binding = try work.binding(a), .schema = schema };
    bound.plan.plan.source_basis = try f.WorkloadProjection.basis(a, input, bound.fields);
    var plan_buffer: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const projection: c.DirectWorkloadIntent.Projection = .{ .fields = bound.fields, .plan = try w.Binary.encode(a, try f.WorkloadProjection.encode(input, bound.fields, bound.plan.plan, a, &plan_buffer)) };
    var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const source: c.DirectLogProtocol.Definition = .{ .declaration = self.definition, .schema = try w.Binary.encode(a, try schema.encode(&schema_buffer)) };
    return c.DirectWorkloadIntent.createProjected(allocator, self.connection, source, work, projection);
}

const TestFixture = struct {
    declaration: c.storage.LogDeclaration.Owned,
    metadata: c.DirectLogProtocol.Definition,
    const connection: w.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 1, .principal = 1, .role = null };
    fn init(count: u32) !TestFixture {
        const columns = [_]f.TableSchema.Column{
            .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
            .{ .id = 9, .name = "payload", .type = .utf8, .nullable = false, .collation = .ascii_ci },
        };
        const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 10, .columns = &columns, .primary_key = &.{} };
        const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 5, .name = try .init("events") };
        var config = f.LogDdl.defaults(.stream);
        config.partitioning.count = count;
        var property_buffer: [c.storage.LogDeclaration.max_properties_bytes]u8 = undefined;
        var declaration = try c.storage.LogDeclaration.prepare(std.testing.allocator, .{
            .object = .{ .scope = connection.scope, .branch = 1, .object = 7 },
            .revision = 1,
            .schema = schema,
            .configuration = config,
            .limits = f.LogDdl.default_limits,
            .properties = try properties.encode(&property_buffer),
        });
        errdefer declaration.deinit();
        const stored = try declaration.stored();
        var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
        return .{ .declaration = declaration, .metadata = .{
            .declaration = .{ .stored = stored, .seed = stored, .properties = properties, .initialization = .{ .scope = connection.scope, .principal = 1, .operation = 10 }, .first_partition = 100 },
            .schema = try w.Binary.encode(std.testing.allocator, try schema.encode(&schema_buffer)),
        } };
    }
    fn deinit(self: *TestFixture) void {
        std.testing.allocator.free(self.metadata.schema.base64);
        self.declaration.deinit();
    }
};

fn testOwned(allocator: std.mem.Allocator, metadata: c.DirectLogProtocol.Definition) !void {
    const t = std.testing;
    var prepared = try init(allocator, TestFixture.connection, 1, "CONSUME payload AS body, _offset FROM events WHERE _partition = $1 AND _offset >= $2 AND payload = $3 LIMIT $4", metadata, .transit, null);
    var live = true;
    defer if (live) prepared.deinit();
    var text = "ALPHA".*;
    var intent = try prepared.freeze(allocator, 99, &.{ .{ .unsigned = 2 }, .{ .unsigned = 10 }, .{ .bytes = &text }, .{ .unsigned = 5 } }, null);
    defer intent.deinit();
    prepared.deinit();
    live = false;
    @memset(&text, 'z');
    var restored = try c.DirectWorkloadIntent.restore(allocator, intent.bytes);
    defer restored.deinit();
    try t.expectEqualDeep(try intent.reference(@splat(17)), try restored.reference(@splat(17)));
    const saved = restored.parsed.value;
    const request = saved.work.stream.work.consume;
    try t.expectEqual(@as(u32, 2), request.target.partition);
    try t.expectEqual(@as(u64, 10), request.from);
    try t.expectEqual(null, request.until);
    try t.expectEqual(null, request.group);
    try t.expectEqual(@as(u64, 99), request.operation.operation);
    var schema = try c.DirectLogProtocol.decodeMetadata(allocator, TestFixture.connection, saved.source);
    defer schema.deinit();
    const source: f.WorkloadProjection.Source = .{ .binding = try saved.work.binding(allocator), .schema = schema.definition.schema };
    const projection = saved.projection.?;
    var plan = try projection.restore(allocator, source);
    defer plan.deinit();
    try t.expectEqual(@as(?u64, 5), plan.plan.limit);
    try t.expectEqualStrings("body", plan.plan.output_names[0].?);
    var projector = try f.WorkloadProjection.Projector.init(allocator, source, projection.fields, plan.plan);
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 42 } } }, .{ .value = .{ .atom = .{ .bytes = "alpha" } } } };
    const row = (try projector.row(&cells, .{ .offset = 11 })).?;
    try t.expectEqualStrings("alpha", row[0].value.atom.bytes);
    try t.expectEqual(@as(u128, 11), row[1].value.atom.unsigned);
    try t.expectEqual(null, try projector.row(&cells, .{ .offset = 9 }));
    var failed = cells;
    failed[1] = .{ .type_error = .utf8 };
    // Routing never weakens eager predicate semantics for a traversed row.
    try t.expectError(error.QueryTypeError, projector.row(&failed, .{ .offset = 9 }));
}

test "log consume Catalog binding retains owned plans original positions and logical limits" {
    var fixture = try TestFixture.init(3);
    defer fixture.deinit();
    try testOwned(std.testing.allocator, fixture.metadata);
    var no_resize = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
    try std.testing.checkAllAllocationFailures(no_resize.allocator(), testOwned, .{fixture.metadata});
}

test "log consume Catalog routing conservatively encloses Boolean metadata predicates" {
    const t = std.testing;
    var fixture = try TestFixture.init(3);
    defer fixture.deinit();
    for ([_]struct { predicate: []const u8, partition: u32, from: u64 }{
        .{ .predicate = "_partition = 1 AND _offset >= 9", .partition = 1, .from = 9 },
        .{ .predicate = "_partition >= 1 AND _partition < 2 AND _offset > 9", .partition = 1, .from = 10 },
        .{ .predicate = "(_partition = 1 AND _offset >= 4) OR (_partition = 1 AND _offset >= 8)", .partition = 1, .from = 4 },
        .{ .predicate = "_partition = 0 AND NOT (_offset < 9)", .partition = 0, .from = 0 },
        .{ .predicate = "_partition = 2 AND _offset < 100", .partition = 2, .from = 0 },
    }) |case| {
        const sql = try std.fmt.allocPrint(t.allocator, "CONSUME * FROM events WHERE {s} LIMIT 7", .{case.predicate});
        defer t.allocator.free(sql);
        var prepared = try init(t.allocator, TestFixture.connection, 1, sql, fixture.metadata, .transit, null);
        defer prepared.deinit();
        var intent = try prepared.freeze(t.allocator, 99, &.{}, null);
        defer intent.deinit();
        const request = intent.parsed.value.work.stream.work.consume;
        try t.expectEqual(case.partition, request.target.partition);
        try t.expectEqual(case.from, request.from);
        try t.expectEqual(null, request.until);
    }
    for ([_]struct { sql: []const u8, failure: anyerror }{
        .{ .sql = "CONSUME id FROM events", .failure = error.LogPartitionRequired },
        .{ .sql = "CONSUME id FROM events WHERE _partition = 0 OR _partition = 1", .failure = error.LogPartitionRequired },
        .{ .sql = "CONSUME id FROM events WHERE _partition = 0 OR id = 1", .failure = error.LogPartitionRequired },
        .{ .sql = "CONSUME id FROM events WHERE _partition = 3", .failure = error.InvalidLogPartitioning },
        .{ .sql = "CONSUME id FROM events WHERE _partition = 0 AND _offset > 18446744073709551615", .failure = error.UnsupportedConstruct },
        .{ .sql = "CONSUME id FROM events GROUP 'workers'", .failure = error.UnsupportedConstruct },
        .{ .sql = "CONSUME id FROM events WAIT '1ms'", .failure = error.UnsupportedConstruct },
    }) |case| {
        var prepared = try init(t.allocator, TestFixture.connection, 1, case.sql, fixture.metadata, .transit, null);
        defer prepared.deinit();
        try t.expectError(case.failure, prepared.freeze(t.allocator, 99, &.{}, null));
    }
    try t.expectError(error.CatalogDefinitionChanged, init(t.allocator, TestFixture.connection, 2, "CONSUME id FROM events", fixture.metadata, .transit, null));
    try t.expectError(error.CatalogDefinitionChanged, init(t.allocator, TestFixture.connection, 1, "CONSUME id FROM other", fixture.metadata, .transit, null));
}
