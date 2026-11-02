//! Read-only composition of public catalog callers for data exploration.
const std = @import("std");
const c = @import("root.zig");
const h = c.DirectTableValues;
pub const Request = struct {
    definition: c.protocol.Growth.Definition,
    action: union(enum) {
        describe,
        history: c.DirectCatalogHistory.Read,
        definitions: c.DirectCatalogDefinitions.Action,
        namespaces: ?c.DirectCatalogInspection.Cursor,
        tables: @FieldType(c.DirectCatalogInspection.Action, "tables"),
        resources: @FieldType(c.DirectCatalogResources.Action, "list"),
        table: struct { namespace: u64, name: []const u8, expected: h.Interpretation },
        storage: h.PreparedBinding,
        dependencies: @FieldType(c.DirectCatalogDependencies.Action, "page"),
    },
};
pub const Response = union(enum) {
    catalog: c.DirectCatalogInspection.Result,
    history: c.DirectCatalogHistory.ReadResult,
    definitions: c.DirectCatalogDefinitions.Result,
    resources: @FieldType(c.DirectCatalogResources.Result, "list"),
    table: struct { metadata: h.Metadata, preview_sql: []const u8, expected_definition: []const u8 },
    storage: Storage,
    dependencies: @FieldType(c.DirectCatalogDependencies.Result, "page"),
};
pub fn apply(arena: *std.heap.ArenaAllocator, client: c.DirectTableClient, request: Request) !Response {
    if (request.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    const a = arena.allocator();
    return switch (request.action) {
        .definitions => |input| .{ .definitions = try c.DirectCatalogDefinitions.apply(a, client, input) },
        .history => |input| .{ .history = try c.DirectCatalogHistory.ReadResult.from(try c.DirectCatalogHistory.apply(a, client, input.action())) },
        .describe => .{ .catalog = try c.DirectCatalogInspection.apply(a, client, .describe) },
        .namespaces => |cursor| .{ .catalog = try c.DirectCatalogInspection.apply(a, client, .{ .namespaces = cursor }) },
        .tables => |input| .{ .catalog = try c.DirectCatalogInspection.apply(a, client, .{ .tables = input }) },
        .resources => |input| .{ .resources = (try c.DirectCatalogResources.apply(a, client, .{ .list = input })).list },
        .dependencies => |input| .{ .dependencies = (try c.DirectCatalogDependencies.apply(a, client, .{ .page = input })).page },
        .storage => |input| .{ .storage = try storage(a, client, input) },
        .table => |input| blk: {
            var session: c.DirectTableBridge.Session = .{ .allocator = a };
            defer session.deinit();
            const result = try session.apply(arena, client, .{ .lookup = .{ .namespace = input.namespace, .name = input.name } }, null);
            const metadata = result.metadata orelse return error.CatalogNameNotFound;
            if (!std.meta.eql(try metadata.binding.interpretation.interpretation.native(), try input.expected.native())) return error.CatalogDefinitionChanged;
            var sql: std.Io.Writer.Allocating = .init(a);
            try sql.writer.writeAll("SELECT * FROM \"");
            for (metadata.binding.name) |byte| {
                try sql.writer.writeByte(byte);
                if (byte == '"') try sql.writer.writeByte('"');
            }
            try sql.writer.writeByte('"');
            break :blk .{ .table = .{ .metadata = metadata, .preview_sql = sql.written(), .expected_definition = try c.protocol.Json.valueAlloc(a, try input.expected.native()) } };
        },
    };
}

pub const Storage = struct { binding: h.PreparedBinding, observed: h.StorageObservation };

/// Exact current Table evidence. No query, retained cut or maintenance is created.
pub fn storage(allocator: std.mem.Allocator, client: c.DirectTableClient, input: h.PreparedBinding) !Storage {
    const binding = try input.native();
    if (!std.meta.eql(binding.connection, client.connection)) return error.RelationalCallerChanged;
    const response = try client.call(.{ .storage = .{ .object = binding.interpretation.interpretation.object, .pending_limit = 1024 } });
    defer response.deinit();
    const observed = response.value.result.storage;
    if (!std.meta.eql(binding.interpretation, observed.interpretation)) return error.CatalogDefinitionChanged;
    const current = try client.call(.{ .lookup = .{ .namespace = binding.namespace, .name = binding.name.slice() } });
    defer current.deinit();
    const current_binding = try c.DirectTableBinding.init(client.connection, current.value.result.lookup orelse return error.CatalogDefinitionChanged);
    if (!std.meta.eql(binding, current_binding)) return error.CatalogDefinitionChanged;
    return .{ .binding = try h.PreparedBinding.foreign(allocator, binding), .observed = try h.StorageObservation.foreign(allocator, observed) };
}
