//! Shared reference-store fixture. Every Table is admitted through its real
//! catalog owner; fabricated declarations below are codec inputs only.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const c = q.catalog;
const f = q.fuze;
pub const Store = q.testing.Store;
pub const configuration: c.TableCatalogRecords.Configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .table_limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 8, .staging_records = 8 } };
pub const catalog: c.TableCatalog = .{ .configuration = configuration };
pub fn turn(store: *Store) !s.Turn {
    var result = try store.capture();
    result.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
    return result;
}
pub fn ddl(store: *Store, request: c.TableDdlRequest) !c.TableCatalog.Outcome {
    for (0..10000) |_| {
        var next = try turn(store);
        const result = try catalog.step(std.testing.allocator, &next, request);
        try store.commit(next);
        if (result.terminal()) return result;
    }
    return error.UnfinishedTestDdl;
}
pub fn create(store: *Store, sql: []const u8) !void {
    var next = try turn(store);
    try catalog.initialize(&next);
    try store.commit(next);
    var compiled = try f.TableDdl.compile(std.testing.allocator, sql, null, null);
    defer compiled.deinit();
    const statement = compiled.statement.create;
    const result = try ddl(store, .{ .principal = 17, .operation = 1, .object = 100, .expected_revision = 0, .name = try c.TableMetadata.Name.init(statement.name), .action = .{ .create = .{ .schema = try statement.bind(100) } } });
    try std.testing.expectEqual(.applied, result.operation.state);
}
pub fn definition(store: *Store) !c.TableCatalog.Definition {
    var next = try turn(store);
    return (try catalog.lookup(std.testing.allocator, &next, 17, try c.TableMetadata.Name.init("items"))).?;
}
pub fn source(store: *Store) !q.TableSource.Owned {
    var found = try definition(store);
    defer found.deinit();
    return q.TableSource.from(std.testing.allocator, configuration, found);
}
pub fn mutate(store: *Store, operation: u64, action: f.TableDml.Action) !void {
    var found = try definition(store);
    defer found.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = operation, .metadata = .{ .id = found.metadata.revision, .spec = try found.metadata.spec() }, .plan = .{ .name = "items", .schema = found.schema.schema, .action = action } };
    for (0..10000) |_| {
        var next = try turn(store);
        const result = try catalog.mutate(std.testing.allocator, &next, request);
        try store.commit(next);
        if (result.state != .building) {
            try std.testing.expectEqual(.applied, result.state);
            return;
        }
    }
    return error.UnfinishedTestMutation;
}
pub fn plan(allocator: std.mem.Allocator, declaration: q.SourceDefinition, projection: []const u8) !f.LogicalQuery.Plan {
    var fields: [q.SourceDefinition.max_columns]f.Types.Field = undefined;
    return .{ .schema = try (try declaration.schema(&fields)).cloneInto(allocator), .source_basis = try declaration.fingerprint(), .projection = projection };
}
