//! Prepared PUT and DELETE ... KEY/KEYS statements over named direct KV stores.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const p = c.protocol;
const s = c.storage;
const Self = @This();

connection: c.DirectTableProtocol.Connection,
namespace: u64,
definition: c.DirectKV.Definition,
prepared: f.KVWorkloadSql.PreparedWrite,

fn fuzeSpec(spec: s.KVDeclaration.Spec) f.KVDdl.Spec {
    return .{
        .value_type = switch (spec.value_type) {
            .int64 => .int64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .binary => .binary,
        },
        .nullable = spec.nullable,
    };
}

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const selected = (try f.KVWorkloadSql.target(scratch.allocator(), text, dialect, location)) orelse return error.UnsupportedStatement;
    if (selected.kind == .get) return error.UnsupportedStatement;
    const response = try client.call(.{ .kv_lookup = .{ .namespace = namespace, .name = selected.source.name } });
    defer response.deinit();
    const definition = response.value.result.kv_lookup orelse return error.CatalogNameNotFound;
    const prepared = try f.KVWorkloadSql.PreparedWrite.init(allocator, text, fuzeSpec(definition.spec), dialect, location);
    return .{
        .connection = client.connection,
        .namespace = namespace,
        .definition = definition,
        .prepared = prepared,
    };
}

pub fn deinit(self: *Self) void {
    self.prepared.deinit();
    self.* = undefined;
}

pub fn parameterTypes(self: *const Self) []const f.Types.Type {
    return self.prepared.parameterTypes();
}

pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    const response = try client.call(.{ .kv = .{ .observe = self.definition.interpretation.interpretation.object } });
    defer response.deinit();
    const observed = response.value.result.kv.definition;
    if (observed.retired or !std.meta.eql(observed.interpretation, self.definition.interpretation)) return error.CatalogDefinitionChanged;
}

pub fn bindPrepared(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, values: []const ?f.Types.Values.Atom, operation: u64, fresh: bool) !c.DirectKVIntent {
    if (!fresh) try self.validate(client) else if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (operation == 0 or operation > p.max_counter) return error.InvalidDataOperation;
    var bound = try self.prepared.bind(allocator, values);
    defer bound.deinit();
    var output = std.heap.ArenaAllocator.init(allocator);
    defer output.deinit();
    const changes = try output.allocator().alloc(s.KVPartition.Change, bound.changes.len);
    for (bound.changes, changes) |item, *out| {
        out.* = switch (item) {
            .put => |put| .{ .put = .{
                .key = put.key,
                .value = put.value,
                .expect = switch (put.expect) {
                    .any => .any,
                    .absent => .absent,
                    .present => .present,
                },
            } },
            .remove => |key| .{ .remove = key },
        };
    }
    const binding: p.DataLifecycle.Binding = .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation },
        .target = self.definition.interpretation.interpretation.object,
        .action = .insert,
        .expected_definition = self.definition.interpretation.interpretation,
        .expected_data = null,
        .intent = @splat(0),
    };
    const mutation = try c.DirectKVClient.prepareMutation(&output, binding, self.definition.spec, changes);
    return c.DirectKVIntent.create(
        allocator,
        self.connection,
        self.namespace,
        if (self.prepared.target.kind == .delete) .{ .delete = mutation } else .{ .put = mutation },
    );
}
