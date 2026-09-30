const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const p = c.protocol;
const g = p.Growth;
const Client = c.Client;
const connection: Client.Connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .principal = 1234 };
fn fixture() !Client.Prepared {
    const request = try c.Model.CreateTable.compile(connection.scope, std.math.maxInt(u64), std.math.maxInt(u64), 9, "CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)");
    return .{ .version = 1, .definition = g.current_definition, .connection = connection, .signed = try g.sign(.{ .realm = 46, .principal = 1234, .sequence = 3, .command = .{ .send = .{ .pid = 3, .value = try (c.station.Frame{ .kind = .cast, .payload = try c.Records.encode('q', request) }).encode() } } }, try p.Ed25519.KeyPair.generateDeterministic(@splat(10))) };
}
test "saved catalog commands own their bytes and require exact definitions and canonical input" {
    const prepared = try fixture();
    const bytes = try prepared.save(t.allocator);
    defer t.allocator.free(bytes);
    const restored = try Client.Prepared.restore(t.allocator, bytes);
    @memset(bytes, 0);
    try t.expect(std.meta.eql(prepared, restored));
    try t.expectEqual(std.math.maxInt(u64), (try restored.request()).operation);
    const canonical = try restored.save(t.allocator);
    defer t.allocator.free(canonical);
    for (0..7) |change| {
        var parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, canonical, .{});
        defer parsed.deinit();
        const object = &parsed.value.object;
        switch (change) {
            0 => try t.expect(object.swapRemove("definition")),
            1 => object.getPtr("definition").?.* = .{ .string = "foreign-v1-definition" },
            2 => try t.expect(object.getPtr("signed").?.object.getPtr("request").?.object.swapRemove("definition")),
            3 => object.getPtr("signed").?.object.getPtr("request").?.object.getPtr("definition").?.* = .{ .string = "foreign-v1-definition" },
            4 => object.getPtr("version").?.* = .{ .integer = 2 },
            5 => object.getPtr("connection").?.object.getPtr("owner").?.* = .{ .integer = 4 },
            6 => object.getPtr("connection").?.object.getPtr("scope").?.object.getPtr("resource").?.* = .{ .integer = 8 },
            else => unreachable,
        }
        const invalid = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
        defer t.allocator.free(invalid);
        try t.expectError(error.InvalidCatalogPrepared, Client.Prepared.restore(t.allocator, invalid));
    }
    const spaced = try std.fmt.allocPrint(t.allocator, "{s}\n", .{canonical});
    defer t.allocator.free(spaced);
    try t.expectError(error.InvalidCatalogPrepared, Client.Prepared.restore(t.allocator, spaced));
    try t.expectError(error.InvalidCatalogPrepared, Client.Prepared.restore(t.allocator, ""));
}
test "catalog caller rejects changed scope, identity and signatures before transport access" {
    var client: Client = .{ .transport = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    const prepared = try fixture();
    try client.validate(prepared);
    inline for (.{ "realm", "resource", "catalog" }) |field| {
        client.connection = connection;
        @field(client.connection.scope, field) -= 1;
        try t.expectError(error.CatalogIdentityConflict, client.submit(prepared));
    }
    inline for (.{ "owner", "principal" }) |field| {
        client.connection = connection;
        @field(client.connection, field) += 1;
        try t.expectError(error.CatalogIdentityConflict, client.submit(prepared));
    }
    client.connection = connection;
    var forged = prepared;
    forged.signed.request.sequence += 1;
    try t.expectError(error.SignatureVerificationFailed, client.submit(forged));
    forged = prepared;
    forged.signed.request.command = .{ .checkpoint = {} };
    try t.expectError(error.InvalidCatalogPrepared, client.submit(forged));
    var request = try prepared.request();
    request.scope.resource += 1;
    try t.expectError(error.CatalogScopeChanged, client.prepareCreate(request));
    try t.expectError(error.CatalogScopeChanged, client.status(request));
    try t.expectError(error.InvalidCatalogIdentity, client.observe(prepared, 0));
}
