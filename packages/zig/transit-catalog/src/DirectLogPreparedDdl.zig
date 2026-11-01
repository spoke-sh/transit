//! Shared Stream/Queue SQL preparation and immutable declaration binding.
//! Preparation reads current metadata; native preview checks declaration rights
//! before staging. Token acceptance and reconciliation use DirectLogIntent.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const p = c.protocol;
const Self = @This();
connection: c.DirectTableProtocol.Connection,
namespace: u64,
compiled: f.LogDdl.Owned,
definition: ?c.DirectLog.Definition,
schema: ?f.TableSchema.Owned,
configured: ?f.LogDdl.Configured,
create_owner: ?u64,

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var compiled = try f.LogDdl.compile(allocator, text, dialect, location);
    errdefer compiled.deinit();
    var result: Self = .{ .connection = client.connection, .namespace = namespace, .compiled = compiled, .definition = null, .schema = null, .configured = null, .create_owner = null };
    errdefer if (result.schema) |*schema| schema.deinit();
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const syntax = compiled.statement;
    if (syntax.action == .create) {
        result.create_owner = (try client.require(.{ .namespace = namespace, .target = null, .access = .create_table })).role;
        result.configured = try syntax.configure(null, try syntax.action.create.bind(1));
    } else {
        const response = try client.call(.{ .log_lookup = .{ .namespace = namespace, .name = syntax.name } });
        defer response.deinit();
        const metadata = response.value.result.log_lookup orelse return error.CatalogNameNotFound;
        if (metadata.declaration.kind() != syntax.kind) return error.CatalogKindMismatch;
        result.definition = metadata.declaration;
        result.schema = try f.TableSchema.decode(allocator, try metadata.schema.decode(scratch.allocator(), f.TableSchema.max_bytes));
        if (syntax.action == .alter) result.configured = try syntax.configure(.{ .schema = result.schema.?.schema, .configuration = metadata.declaration.stored.declaration.configuration, .limits = metadata.declaration.stored.declaration.limits }, result.schema.?.schema);
    }
    if (result.configured) |*configured| switch (configured.destination) {
        .unchanged => {},
        .clear => configured.configuration.policy.queue.dead_letter = null,
        .name => |name| {
            const response = try client.call(.{ .log_lookup = .{ .namespace = namespace, .name = name } });
            defer response.deinit();
            const destination = response.value.result.log_lookup orelse return error.InvalidQueueDestination;
            if (destination.declaration.kind() != .queue) return error.InvalidQueueDestination;
            configured.configuration.policy.queue.dead_letter = destination.declaration.stored.declaration.interpretation;
        },
    };
    return result;
}
pub fn deinit(self: *Self) void {
    self.compiled.deinit();
    if (self.schema) |*schema| schema.deinit();
    self.* = undefined;
}
pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (self.definition) |expected| {
        try c.DirectLogClient.requireCurrent(client, expected);
    } else _ = try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table });
}
pub fn bindPrepared(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, fresh: bool) !c.DirectLogIntent {
    if (!fresh) try self.validate(client) else if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (operation == 0 or operation > p.max_counter) return error.InvalidDataOperation;
    const syntax = self.compiled.statement;
    const object = if (self.definition) |value| value.stored.declaration.interpretation.object else p.DataLifecycle.Object{ .scope = self.connection.scope, .branch = self.connection.branch, .object = operation };
    const intent: c.DirectLog.Intent = .{ .kind = syntax.kind, .namespace = self.namespace, .name = try .init(syntax.name), .action = switch (syntax.action) {
        .create => |shape| .{ .create = .{ .owner = self.create_owner.?, .schema = try shape.bind(object.object), .configuration = self.configured.?.configuration, .limits = self.configured.?.limits } },
        .alter => .{ .alter = .{ .configuration = self.configured.?.configuration, .limits = self.configured.?.limits } },
        .rename => |name| .{ .rename = try .init(name) },
        .drop => .drop,
    } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation }, .target = object, .action = switch (syntax.action) {
        .create => .create,
        .alter => .alter,
        .rename => .rename,
        .drop => .drop,
    }, .expected_definition = if (self.definition) |value| value.stored.declaration.interpretation else null, .expected_data = null, .intent = try intent.digest(allocator) } };
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const wire = try c.DirectLogProtocol.Ddl.encode(scratch.allocator(), request);
    // Native preview owns schema, DLQ dependencies and current administration
    // rights. Its position is an observation, never acceptance or completion.
    const preview = try client.call(.{ .log_preview = wire });
    defer preview.deinit();
    if (preview.value.result.log_preview.reason == .stale_definition) return error.CatalogDefinitionChanged;
    return c.DirectLogIntent.create(allocator, self.connection, wire);
}
