//! Read-only composition of public catalog callers for data exploration.
const std = @import("std");
const c = @import("root.zig");
const h = c.DirectTableValues;
pub const Request = struct {
    definition: c.protocol.Growth.Definition,
    action: union(enum) {
        describe,
        history: c.DirectCatalogHistory.Read,
        namespaces: ?c.DirectCatalogInspection.Cursor,
        tables: @FieldType(c.DirectCatalogInspection.Action, "tables"),
        resources: @FieldType(c.DirectCatalogResources.Action, "list"),
        table: struct { namespace: u64, name: []const u8, expected: h.Interpretation },
        dependencies: @FieldType(c.DirectCatalogDependencies.Action, "page"),
    },
};
pub const Response = union(enum) {
    catalog: c.DirectCatalogInspection.Result,
    history: c.DirectCatalogHistory.Result,
    resources: @FieldType(c.DirectCatalogResources.Result, "list"),
    table: struct { metadata: h.Metadata, preview_sql: []const u8, expected_definition: []const u8 },
    dependencies: @FieldType(c.DirectCatalogDependencies.Result, "page"),
};
pub fn apply(arena: *std.heap.ArenaAllocator, client: c.DirectTableClient, request: Request) !Response {
    if (request.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    const a = arena.allocator();
    return switch (request.action) {
        .history => |input| .{ .history = try c.DirectCatalogHistory.apply(a, client, input.action()) },
        .describe => .{ .catalog = try c.DirectCatalogInspection.apply(a, client, .describe) },
        .namespaces => |cursor| .{ .catalog = try c.DirectCatalogInspection.apply(a, client, .{ .namespaces = cursor }) },
        .tables => |input| .{ .catalog = try c.DirectCatalogInspection.apply(a, client, .{ .tables = input }) },
        .resources => |input| .{ .resources = (try c.DirectCatalogResources.apply(a, client, .{ .list = input })).list },
        .dependencies => |input| .{ .dependencies = (try c.DirectCatalogDependencies.apply(a, client, .{ .page = input })).page },
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
