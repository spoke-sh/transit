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
        .value_type = spec.value_type,
        .nullable = spec.nullable,
        .fields = spec.fields,
    };
}

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const selected = (try f.KVWorkloadSql.target(scratch.allocator(), text, dialect, location)) orelse return error.UnsupportedStatement;
    if (selected.kind != .get) return error.UnsupportedStatement;
    const response = try client.call(.{ .kv_lookup = .{ .namespace = namespace, .name = selected.source.name } });
    defer response.deinit();
    var definition = response.value.result.kv_lookup orelse return error.CatalogNameNotFound;
    const prepared = try f.KVWorkloadSql.PreparedGet.init(allocator, text, fuzeSpec(definition.spec), dialect, location);
    definition.spec.fields = prepared.spec.fields;
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

pub fn checkValues(self: *const Self, allocator: std.mem.Allocator, values: []const ?f.Types.Values.Atom) !void {
    const key = try self.prepared.bind(allocator, values);
    allocator.free(key);
}

pub const Read = struct {
    arena: std.heap.ArenaAllocator,
    definition: c.DirectKV.Definition,
    workspace: ?c.protocol.Transaction.ReadView = null,
    cells: ?[2]f.Types.Values.Cell,
    emitted: bool = false,
    subject: ?c.DirectKV.Definition = null,

    pub fn deinit(self: *Read) void {
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn next(self: *Read) !?[]const f.Types.Values.Cell {
        self.subject = null;
        if (self.emitted) return null;
        self.emitted = true;
        if (self.cells) |*row| {
            self.subject = self.definition;
            return row;
        }
        return null;
    }

    pub fn complete(self: *const Read) bool {
        return self.emitted or self.cells == null;
    }
};

pub fn open(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, values: []const ?f.Types.Values.Atom) !Read {
    try self.validate(client);
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const key = try self.prepared.bind(arena.allocator(), values);
    const result = try c.DirectKVClient.apply(&arena, client, .{ .get = .{ .object = self.definition.interpretation.interpretation.object, .key = key } });
    if (!std.meta.eql(result.value.interpretation, self.definition.interpretation)) return error.CatalogDefinitionChanged;
    const cells: ?[2]f.Types.Values.Cell = if (result.value.value) |cell| .{
        .{ .value = .{ .atom = .{ .bytes = key } } },
        cell,
    } else null;
    return .{
        .arena = arena,
        .definition = try self.definition.cloneInto(arena.allocator()),
        .workspace = result.value.workspace,
        .cells = cells,
    };
}
