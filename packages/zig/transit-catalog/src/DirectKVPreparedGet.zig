//! Prepared GET FROM <kv> KEY <key> read statements over named direct KV stores.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const s = c.storage;
const Self = @This();

connection: c.DirectTableProtocol.Connection,
namespace: u64,
definition: c.DirectKV.Definition,
prepared: f.KVWorkloadSql.PreparedGet,

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
    if (selected.kind != .get) return error.UnsupportedStatement;
    const response = try client.call(.{ .kv_lookup = .{ .namespace = namespace, .name = selected.source.name } });
    defer response.deinit();
    const definition = response.value.result.kv_lookup orelse return error.CatalogNameNotFound;
    const prepared = try f.KVWorkloadSql.PreparedGet.init(allocator, text, fuzeSpec(definition.spec), dialect, location);
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

pub fn outputType(self: *const Self) f.Types.Type {
    return self.prepared.output.type;
}

pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    const response = try client.call(.{ .kv = .{ .observe = self.definition.interpretation.interpretation.object } });
    defer response.deinit();
    const observed = response.value.result.kv.definition;
    if (observed.retired or !std.meta.eql(observed.interpretation, self.definition.interpretation)) return error.CatalogDefinitionChanged;
}
