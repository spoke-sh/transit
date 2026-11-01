//! Direct local Table bootstrap. The retained installation owns its initial
//! declaration and exact operation; readiness never recreates a dropped Table.
const std = @import("std");
const c = @import("transit_query").catalog;
const Installation = @import("Installation.zig");
pub const Node = struct {
    catalog: c.DirectCatalog.Configuration,
    registrar: struct { principal: u64, seed_file: []const u8 },
};
pub fn configured(installation: *Installation) bool {
    return installation.record.authorization_steps[12] != null and installation.record.table_registrar_receipt != null;
}
pub fn node(installation: *Installation) !?Node {
    if (!configured(installation)) return null;
    return .{ .catalog = installation.directCatalog(), .registrar = .{ .principal = Installation.table_registrar, .seed_file = try installation.path("table-registrar.seed") } };
}
pub fn ready(installation: *Installation) !void {
    const config = installation.directCatalog();
    const client: c.DirectTableClient = .{ .allocator = installation.init.gpa, .authority = installation.wire, .service = installation.wire, .connection = .{ .scope = config.scope, .branch = config.branch, .audience = config.audience, .principal = Installation.caller, .role = null }, .key = installation.caller_key };
    const description = try client.call(.describe);
    defer description.deinit();
    if (!std.meta.eql(description.value.result.description, config)) return error.CatalogConfigurationChanged;
    var arena: std.heap.ArenaAllocator = .init(installation.init.gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const schema: c.fuze.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .int64 } }, .primary_key = &.{1} };
    var buffer: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    var work: c.DirectTableProtocol.Ddl = .{ .binding = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .scope = config.scope, .principal = Installation.caller, .operation = 1 }, .target = .{ .scope = config.scope, .branch = config.branch, .object = 1 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) }, .namespace = 1, .name = "items", .action = .{ .create = .{ .owner = installation.record.authorization_steps[0].?, .schema = try .encode(a, try schema.encode(&buffer)) } } };
    work.binding.intent = try work.digest(a);
    var intent = try c.DirectTableIntent.create(a, client.connection, .{ .ddl = work });
    defer intent.deinit();
    const expected = try intent.reference(1);
    if (installation.record.default_table) |retained| try retained.requireSame(expected);
    if (installation.record.default_table_complete) {
        if (installation.record.default_table == null) return error.InstallationIdentityMismatch;
        // Observe the initialized owner without reapplying administrative work
        // or requiring the original caller to retain schema-creation rights.
        const namespace = try client.call(.{ .namespace = config.authority.initial_schema });
        defer namespace.deinit();
        if (namespace.value.result.namespace == null) return error.CatalogSchemaMissing;
        return;
    }
    const initialized = try client.call(.initialize);
    initialized.deinit();
    if (installation.record.default_table == null) {
        // Staging can leave private bytes but cannot admit an operation. Save
        // the exact reference durably before the first admission attempt.
        installation.record.default_table = try intent.stage(client, 1);
        try installation.save();
    }
    const reference = installation.record.default_table.?;
    const observed = try reference.operation(client, .inspect, 1);
    defer observed.deinit();
    if (observed.value.result.ddl == .not_observed) {
        const admission = try reference.admit(client);
        admission.deinit();
    }
    const response = try reference.operation(client, .execute, 32);
    defer response.deinit();
    switch (response.value.result.ddl) {
        .not_observed, .admitted, .finalizing => return error.TableWriterNotReady,
        .rejected, .cancelled => return error.InstallationDefaultTableRejected,
        .committed => |evidence| {
            try reference.binding.requireSame(evidence.binding);
            installation.record.default_table_complete = true;
            try installation.save();
        },
    }
}
