//! Dedicated SQL append preparation over exact Catalog metadata. Binding freezes
//! one native operation; it does not upload, reserve a token or publish rows.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const p = c.protocol;
const s = c.storage;
const w = c.DirectTableProtocol;
const Self = @This();
connection: w.Connection,
definition: c.DirectLog.Definition,
compiled: f.LogAppendSql.Prepared,

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const target = try f.LogAppendSql.target(scratch.allocator(), text, dialect, location);
    const response = try client.call(.{ .log_lookup = .{ .namespace = namespace, .name = target.source.name } });
    defer response.deinit();
    return init(allocator, client.connection, namespace, text, response.value.result.log_lookup orelse return error.CatalogNameNotFound, dialect, location);
}

/// Pure preparation against a verified explicit descriptor. The owning caller
/// separately supplies current authority; a saved descriptor cannot grant it.
pub fn init(allocator: std.mem.Allocator, connection: w.Connection, namespace: u64, text: []const u8, metadata: c.DirectLogProtocol.Definition, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    try connection.validate();
    var declaration = try c.DirectLogProtocol.decodeMetadata(allocator, connection, metadata);
    defer declaration.deinit();
    if (metadata.declaration.properties.namespace != namespace or metadata.declaration.stored.retired) return error.CatalogDefinitionChanged;
    var compiled = try f.LogAppendSql.Prepared.init(allocator, text, declaration.definition.schema, dialect, location);
    errdefer compiled.deinit();
    if (!std.mem.eql(u8, metadata.declaration.properties.name.slice(), compiled.target.source.name)) return error.CatalogDefinitionChanged;
    if (!std.mem.eql(u8, @tagName(metadata.declaration.kind()), @tagName(compiled.target.kind))) return error.CatalogKindMismatch;
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
pub fn bindPrepared(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, values: []const ?f.Types.Values.Atom, location: ?*f.Sql.Location, fresh: bool) !c.DirectWorkloadIntent {
    if (!fresh) try self.validate(client) else if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    return self.freeze(allocator, operation, values, location);
}

/// Canonical collation-aware routing must agree for every row in this native
/// append. A statement spanning partitions needs the transaction owner; never
/// split and publish a successful prefix through independent native mutations.
fn partition(self: *const Self, bound: *const f.LogAppendSql.Bound) !u32 {
    const routing = self.definition.stored.declaration.configuration.partitioning;
    var selected = bound.partition;
    if (selected) |value| if (value >= routing.count) return error.InvalidLogPartitioning;
    if (routing.key_column) |id| {
        const schema = self.compiled.template.schema.schema;
        const index = try schema.index(id);
        const column = schema.columns[index];
        var key_buffer: [f.Collation.max_sort_key_bytes]u8 = undefined;
        for (bound.rows.plan.action.insert) |cells| {
            const key = try f.Collation.encodeSortKey(cells[index], column.type, column.collation, &key_buffer);
            const routed = try routing.select(key);
            if (selected) |expected| {
                if (expected != routed) return if (bound.partition != null) error.LogPartitionKeyMismatch else error.CrossPartitionLogAppend;
            } else selected = routed;
        }
    }
    return selected orelse if (routing.count == 1) @as(u32, 0) else error.LogPartitionRequired;
}

/// The returned body owns all bytes, including the bound rows and projection.
/// Native token acceptance and dispatch recheck the exact target's rights.
pub fn freeze(self: *const Self, allocator: std.mem.Allocator, operation: u64, values: []const ?f.Types.Values.Atom, location: ?*f.Sql.Location) !c.DirectWorkloadIntent {
    const identity: p.DataLifecycle.Operation = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation };
    try identity.validate();
    var bound = try self.compiled.bind(allocator, values, location);
    defer bound.deinit();
    const rows = bound.rows.plan.action.insert;
    const limits = self.definition.stored.declaration.limits;
    if (rows.len == 0 or rows.len > limits.append_rows or limits.append_bytes < s.LogBatch.header_bytes) return error.LogAppendLimitExceeded;
    const selected = try self.partition(&bound);
    const schema = self.compiled.template.schema.schema;
    const output = try allocator.alloc(u8, @min(limits.append_bytes, w.max_work_bytes));
    defer allocator.free(output);
    var encoder = try s.LogBatch.Encoder.init(schema, identity, self.definition.kind(), @intCast(rows.len), output);
    for (rows) |cells| encoder.append(.{ .cells = cells, .visible_ms = bound.visible_ms }) catch |err| return switch (err) {
        error.LogBatchTooLarge, error.WriteFailed => error.LogAppendLimitExceeded,
        else => err,
    };
    const bytes = try encoder.finish();
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const a = scratch.allocator();
    const payload = try w.Binary.encode(a, bytes);
    const append: p.StreamQueue.Append = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = self.definition.stored.declaration.interpretation, .partition = selected },
        .operation = identity,
        .kind = if (self.definition.kind() == .stream) .stream else .queue,
        .producer = bound.producer,
        .rows = rows.len,
        .payload = s.LogBatch.content(bytes),
    };
    const work: c.DirectWorkloadIntent.Work = switch (self.definition.kind()) {
        .stream => .{ .stream = .{ .work = .{ .append = append }, .payload = payload } },
        .queue => .{ .queue = .{ .work = .{ .enqueue = append }, .payload = payload } },
    };
    var plan_buffer: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const projection: ?c.DirectWorkloadIntent.Projection = if (try self.compiled.projection(a, .{ .binding = try work.binding(a), .schema = schema }, &plan_buffer)) |value|
        .{ .fields = value.fields, .plan = try w.Binary.encode(a, value.bytes) }
    else
        null;
    var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const source: c.DirectLogProtocol.Definition = .{ .declaration = self.definition, .schema = try w.Binary.encode(a, try schema.encode(&schema_buffer)) };
    return c.DirectWorkloadIntent.createProjected(allocator, self.connection, source, work, projection);
}

const TestFixture = struct {
    owned: s.LogDeclaration.Owned,
    metadata: c.DirectLogProtocol.Definition,
    const connection: w.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 1, .principal = 1, .role = null };
    fn init(kind: p.StreamQueueDeclaration.Kind, routing: p.StreamQueueDeclaration.Partitioning, limits: p.StreamQueueDeclaration.Limits) !TestFixture {
        const columns = [_]f.TableSchema.Column{
            .{ .id = 1, .name = "key", .type = .utf8, .nullable = false, .collation = .ascii_ci },
            .{ .id = 9, .name = "value", .type = .int64, .nullable = true },
        };
        const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 10, .columns = &columns, .primary_key = &.{} };
        const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 5, .name = try .init("items") };
        var config = f.LogDdl.defaults(kind);
        config.partitioning = routing;
        var property_buffer: [s.LogDeclaration.max_properties_bytes]u8 = undefined;
        var owned = try s.LogDeclaration.prepare(std.testing.allocator, .{
            .object = .{ .scope = connection.scope, .branch = 1, .object = 7 },
            .revision = 1,
            .schema = schema,
            .configuration = config,
            .limits = limits,
            .properties = try properties.encode(&property_buffer),
        });
        errdefer owned.deinit();
        const stored = try owned.stored();
        var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
        return .{ .owned = owned, .metadata = .{
            .declaration = .{ .stored = stored, .seed = stored, .properties = properties, .initialization = .{ .scope = connection.scope, .principal = 1, .operation = 10 }, .first_partition = 100 },
            .schema = try w.Binary.encode(std.testing.allocator, try schema.encode(&schema_buffer)),
        } };
    }
    fn deinit(self: *TestFixture) void {
        std.testing.allocator.free(self.metadata.schema.base64);
        self.owned.deinit();
    }
};

fn testOwned(allocator: std.mem.Allocator, metadata: c.DirectLogProtocol.Definition) !void {
    var prepared = try init(allocator, TestFixture.connection, 1, "ENQUEUE INTO items (key, value) VALUES ($1, 42), ('a', 43) PRODUCER ID UUID '00112233-4455-6677-8899-aabbccddeeff' EPOCH 1 SEQUENCE 2 WITH (visible_at = TIMESTAMP '1970-01-01T00:00:01Z') RETURNING value, _offset, _partition", metadata, .transit, null);
    var live = true;
    defer if (live) prepared.deinit();
    var key = "A".*;
    var intent = try prepared.freeze(allocator, 99, &.{.{ .bytes = &key }}, null);
    defer intent.deinit();
    prepared.deinit();
    live = false;
    key[0] = 'Z';
    const work = intent.parsed.value.work.queue;
    // Independent SHA-256 over ASCII_CI key bytes 04 61 00 00: first
    // big-endian u64 modulo four is one, for both application keys A and a.
    try std.testing.expectEqual(@as(u32, 1), work.work.enqueue.target.partition);
    try std.testing.expectEqual(@as(u64, 99), work.work.enqueue.operation.operation);
    try std.testing.expectEqual(@as(u64, 2), work.work.enqueue.producer.?.sequence);
    const payload = try work.payload.?.decode(allocator, w.max_work_bytes);
    defer allocator.free(payload);
    var declaration = try c.DirectLogProtocol.decodeMetadata(allocator, TestFixture.connection, intent.parsed.value.source);
    defer declaration.deinit();
    var iterator = try s.LogBatch.Iterator.init(payload, declaration.definition.schema, .queue, 2);
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const row = try (try iterator.next()).?.decode(scratch.allocator(), declaration.definition.schema, work.work.enqueue.operation);
    try std.testing.expectEqualStrings("A", row.cells[0].value.atom.bytes);
    try std.testing.expectEqual(@as(u64, 1000), row.visible_ms);
    var plan = try intent.parsed.value.projection.?.restore(allocator, .{ .binding = try intent.parsed.value.work.binding(allocator), .schema = declaration.definition.schema });
    defer plan.deinit();
    try std.testing.expectEqualStrings("_offset", plan.plan.output_names[1].?);
    var restored = try c.DirectWorkloadIntent.restore(allocator, intent.bytes);
    defer restored.deinit();
    try std.testing.expectEqualDeep(try intent.reference(@splat(17)), try restored.reference(@splat(17)));
}

test "log append Catalog preparation freezes independently owned routed payloads and projections" {
    var fixture = try TestFixture.init(.queue, .{ .count = 4, .key_column = 1, .hash = .sha256_64 }, f.LogDdl.default_limits);
    defer fixture.deinit();
    try testOwned(std.testing.allocator, fixture.metadata);
    // Make growth use allocations during fault enumeration: the backing
    // allocator can otherwise remap different blocks in place between runs.
    // The ordinary run above separately exercises its normal resize behavior.
    var no_resize = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
    try std.testing.checkAllAllocationFailures(no_resize.allocator(), testOwned, .{fixture.metadata});
    var mixed = try init(std.testing.allocator, TestFixture.connection, 1, "ENQUEUE INTO items (key) VALUES ('a'), ('b')", fixture.metadata, .transit, null);
    defer mixed.deinit();
    try std.testing.expectError(error.CrossPartitionLogAppend, mixed.freeze(std.testing.allocator, 99, &.{}, null));
    var wrong = try init(std.testing.allocator, TestFixture.connection, 1, "ENQUEUE INTO items (key) VALUES ('A') PARTITION 0", fixture.metadata, .transit, null);
    defer wrong.deinit();
    try std.testing.expectError(error.LogPartitionKeyMismatch, wrong.freeze(std.testing.allocator, 99, &.{}, null));
}

test "log append Catalog preparation refuses changed targets and partial partition publication" {
    const t = std.testing;
    var fixture = try TestFixture.init(.stream, .{ .count = 4, .key_column = null, .hash = .sha256_64 }, f.LogDdl.default_limits);
    defer fixture.deinit();
    try t.expectError(error.CatalogKindMismatch, init(t.allocator, TestFixture.connection, 1, "ENQUEUE INTO items (key) VALUES ('a')", fixture.metadata, .transit, null));
    try t.expectError(error.CatalogDefinitionChanged, init(t.allocator, TestFixture.connection, 2, "PRODUCE INTO items (key) VALUES ('a')", fixture.metadata, .transit, null));
    try t.expectError(error.CatalogDefinitionChanged, init(t.allocator, TestFixture.connection, 1, "PRODUCE INTO renamed (key) VALUES ('a')", fixture.metadata, .transit, null));
    var prepared = try init(t.allocator, TestFixture.connection, 1, "PRODUCE INTO items (key) VALUES ('a')", fixture.metadata, .transit, null);
    defer prepared.deinit();
    try t.expectError(error.LogPartitionRequired, prepared.freeze(t.allocator, 99, &.{}, null));
    var explicit = try init(t.allocator, TestFixture.connection, 1, "PRODUCE INTO items (key) VALUES ('a') PARTITION $1", fixture.metadata, .transit, null);
    defer explicit.deinit();
    try t.expectError(error.InvalidLogPartitioning, explicit.freeze(t.allocator, 99, &.{.{ .unsigned = 4 }}, null));
    var accepted = try explicit.freeze(t.allocator, 99, &.{.{ .unsigned = 3 }}, null);
    defer accepted.deinit();
    try t.expectEqual(@as(u32, 3), accepted.parsed.value.work.stream.work.append.target.partition);
    try t.expect(accepted.parsed.value.projection == null);
}

test "log append Catalog preparation enforces declared row and byte budgets before staging" {
    const t = std.testing;
    var limits = f.LogDdl.default_limits;
    limits.append_rows = 1;
    limits.append_bytes = s.LogBatch.header_bytes;
    var fixture = try TestFixture.init(.queue, .{ .count = 1, .key_column = null, .hash = .sha256_64 }, limits);
    defer fixture.deinit();
    var rows = try init(t.allocator, TestFixture.connection, 1, "ENQUEUE INTO items (key) VALUES ('a'), ('a')", fixture.metadata, .transit, null);
    defer rows.deinit();
    try t.expectError(error.LogAppendLimitExceeded, rows.freeze(t.allocator, 99, &.{}, null));
    var bytes = try init(t.allocator, TestFixture.connection, 1, "ENQUEUE INTO items (key) VALUES ('a')", fixture.metadata, .transit, null);
    defer bytes.deinit();
    try t.expectError(error.LogAppendLimitExceeded, bytes.freeze(t.allocator, 99, &.{}, null));
}
