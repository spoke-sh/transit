//! Catalog binding for partition-routed CLAIM. Preparing or freezing a body
//! grants no lease, admission or settlement authority.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();

connection: w.Connection,
definition: c.DirectLog.Definition,
compiled: f.LogClaimSql.Prepared,

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const target = try f.LogClaimSql.target(scratch.allocator(), text, dialect, location);
    const response = try client.call(.{ .log_lookup = .{ .namespace = namespace, .name = target.name } });
    defer response.deinit();
    return init(allocator, client.connection, namespace, text, response.value.result.log_lookup orelse return error.CatalogNameNotFound, dialect, location);
}

pub fn init(allocator: std.mem.Allocator, connection: w.Connection, namespace: u64, text: []const u8, metadata: c.DirectLogProtocol.Definition, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    try connection.validate();
    var declaration = try c.DirectLogProtocol.decodeMetadata(allocator, connection, metadata);
    defer declaration.deinit();
    if (metadata.declaration.properties.namespace != namespace or metadata.declaration.stored.retired) return error.CatalogDefinitionChanged;
    if (metadata.declaration.kind() != .queue) return error.CatalogKindMismatch;
    var compiled = try f.LogClaimSql.Prepared.init(allocator, text, declaration.definition.schema, dialect, location);
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

/// Admit only an unfiltered Queue acquisition on one exact partition. The
/// native owner retains eligibility, FIFO, capacity, time and lease authority.
/// Payload predicates and waits require their native admission owners first.
fn partition(bound: *const f.LogClaimSql.Bound, count: u32) !u32 {
    if (count == 0) return error.InvalidLogPartitioning;
    const predicate = bound.plan.plan.predicate;
    if (predicate == .all) return if (count == 1) 0 else error.LogPartitionRequired;
    // A single equality is routing, not payload selection. Never discard an
    // arbitrary conjunction or turn a row filter into post-acquisition hiding.
    if (predicate != .compare) return error.UnsupportedConstruct;
    const comparison = predicate.compare;
    if (bound.fields[comparison.column] != .partition or comparison.op != .eq) return error.UnsupportedConstruct;
    if (comparison.value != .unsigned or comparison.value.unsigned >= count) return error.InvalidLogPartitioning;
    return @intCast(comparison.value.unsigned);
}

pub fn freeze(self: *const Self, allocator: std.mem.Allocator, operation: u64, values: []const ?f.Types.Values.Atom, diagnostic: ?*f.Sql.Binding) !c.DirectWorkloadIntent {
    const identity: p.DataLifecycle.Operation = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation };
    try identity.validate();
    var bound = try self.compiled.bind(allocator, values, diagnostic);
    defer bound.deinit();
    if (bound.wait_ms != null) return error.UnsupportedConstruct;
    const selected = try partition(&bound, self.definition.stored.declaration.configuration.partitioning.count);
    const limits = self.definition.stored.declaration.limits;
    const maximum = bound.maximum orelse limits.claim_rows;
    if (maximum > limits.claim_rows) return error.QueueClaimLimitExceeded;
    // Check declared duration policy before reserving an operation. The native
    // owner independently checks the deadline against its trusted admission time.
    _ = try self.definition.stored.declaration.configuration.policy.queue.deadline(0, bound.lease_ms);
    const work: c.DirectWorkloadIntent.Work = .{ .queue = .{ .work = .{ .claim = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = self.definition.stored.declaration.interpretation, .partition = selected },
        .operation = identity,
        .maximum = maximum,
        .lease_ms = bound.lease_ms,
    } }, .payload = null } };
    // Routing has been discharged into the exact native target. The frozen
    // result plan must expose every originally acquired row without filtering.
    bound.plan.plan.predicate = .all;
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
        const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 5, .name = try .init("tasks") };
        var config = f.LogDdl.defaults(.queue);
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
    var prepared = try init(allocator, TestFixture.connection, 1, "CLAIM payload AS body, _partition, _offset, _lease_epoch, _attempt FROM tasks WHERE _partition = $1 LIMIT $2 WITH LEASE $3", metadata, .transit, null);
    var live = true;
    defer if (live) prepared.deinit();
    var lease = "30s".*;
    var intent = try prepared.freeze(allocator, 99, &.{ .{ .unsigned = 2 }, .{ .unsigned = 3 }, .{ .bytes = &lease } }, null);
    defer intent.deinit();
    prepared.deinit();
    live = false;
    @memset(&lease, 'z');
    var restored = try c.DirectWorkloadIntent.restore(allocator, intent.bytes);
    defer restored.deinit();
    try t.expectEqualDeep(try intent.reference(@splat(17)), try restored.reference(@splat(17)));
    const saved = restored.parsed.value;
    const request = saved.work.queue.work.claim;
    try t.expectEqual(@as(u32, 2), request.target.partition);
    try t.expectEqual(@as(u32, 3), request.maximum);
    try t.expectEqual(@as(u64, 30000), request.lease_ms);
    try t.expectEqual(@as(u64, 99), request.operation.operation);
    var schema = try c.DirectLogProtocol.decodeMetadata(allocator, TestFixture.connection, saved.source);
    defer schema.deinit();
    const source: f.WorkloadProjection.Source = .{ .binding = try saved.work.binding(allocator), .schema = schema.definition.schema };
    const projection = saved.projection.?;
    var plan = try projection.restore(allocator, source);
    defer plan.deinit();
    try t.expect(plan.plan.limit == null and plan.plan.predicate == .all);
    try t.expectEqualStrings("body", plan.plan.output_names[0].?);
    var projector = try f.WorkloadProjection.Projector.init(allocator, source, projection.fields, plan.plan);
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 42 } } }, .{ .value = .{ .atom = .{ .bytes = "alpha" } } } };
    const row = (try projector.row(&cells, .{ .offset = 11, .lease = .{ .target = request.target, .claim = request.operation, .offset = 11, .epoch = 7, .attempt = 2, .expires_ms = 40000 } })).?;
    try t.expectEqualStrings("alpha", row[0].value.atom.bytes);
    try t.expectEqual(@as(u128, 2), row[1].value.atom.unsigned);
    try t.expectEqual(@as(u128, 11), row[2].value.atom.unsigned);
    try t.expectEqual(@as(u128, 7), row[3].value.atom.unsigned);
    try t.expectEqual(@as(u128, 2), row[4].value.atom.unsigned);
}

test "log claim Catalog binding owns routed acquisition and unfiltered original output" {
    var fixture = try TestFixture.init(3);
    defer fixture.deinit();
    try testOwned(std.testing.allocator, fixture.metadata);
    var no_resize = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
    try std.testing.checkAllAllocationFailures(no_resize.allocator(), testOwned, .{fixture.metadata});
}

test "log claim Catalog binding refuses unsupported selection before admission" {
    const t = std.testing;
    var fixture = try TestFixture.init(3);
    defer fixture.deinit();
    for ([_]struct { suffix: []const u8, expected: anyerror }{
        .{ .suffix = "WITH LEASE '1s'", .expected = error.LogPartitionRequired },
        .{ .suffix = "WHERE _partition = 3 WITH LEASE '1s'", .expected = error.InvalidLogPartitioning },
        .{ .suffix = "WHERE id = 1 WITH LEASE '1s'", .expected = error.UnsupportedConstruct },
        .{ .suffix = "WHERE _offset >= 1 WITH LEASE '1s'", .expected = error.UnsupportedConstruct },
        .{ .suffix = "WHERE _partition = 1 AND id = 1 WITH LEASE '1s'", .expected = error.UnsupportedConstruct },
        .{ .suffix = "WHERE _partition = 1 WITH LEASE '1s' WAIT '1s'", .expected = error.UnsupportedConstruct },
        .{ .suffix = "WHERE _partition = 1 LIMIT 4294967295 WITH LEASE '1s'", .expected = error.QueueClaimLimitExceeded },
        .{ .suffix = "WHERE _partition = 1 WITH LEASE '31s'", .expected = error.InvalidQueueLeaseDuration },
    }) |case| {
        const text = try std.fmt.allocPrint(t.allocator, "CLAIM id FROM tasks {s}", .{case.suffix});
        defer t.allocator.free(text);
        var prepared = try init(t.allocator, TestFixture.connection, 1, text, fixture.metadata, .transit, null);
        defer prepared.deinit();
        try t.expectError(case.expected, prepared.freeze(t.allocator, 99, &.{}, null));
    }
}

test "log claim Catalog defaults the acquisition maximum to the declaration" {
    const t = std.testing;
    var fixture = try TestFixture.init(1);
    defer fixture.deinit();
    var prepared = try init(t.allocator, TestFixture.connection, 1, "CLAIM * FROM tasks WITH LEASE '1s'", fixture.metadata, .transit, null);
    defer prepared.deinit();
    var intent = try prepared.freeze(t.allocator, 99, &.{}, null);
    defer intent.deinit();
    const claim = intent.parsed.value.work.queue.work.claim;
    try t.expectEqual(@as(u32, 0), claim.target.partition);
    try t.expectEqual(fixture.metadata.declaration.stored.declaration.limits.claim_rows, claim.maximum);
}
