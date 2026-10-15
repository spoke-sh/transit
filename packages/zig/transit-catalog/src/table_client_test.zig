const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const p = c.protocol;
const g = p.Growth;
const Client = c.TableClient;
const connection: Client.Connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .principal = 1234 };
fn intent() !c.TableIntent {
    const request: c.TableDdlRequest = .{ .principal = connection.principal, .operation = std.math.maxInt(u64), .object = 0, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .drop = .{ .if_exists = true } } };
    return c.TableIntent.create(t.allocator, try c.TableCommand.fromDdl(connection.scope, connection.owner, request, null), 1000);
}
fn signed(value: p.Value) !Client.Prepared {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
    return .{ .version = 1, .definition = g.current_definition, .connection = connection, .public_key = key.public_key.toBytes(), .signed = try g.sign(.{ .realm = connection.scope.realm, .principal = connection.principal, .sequence = 3, .command = .{ .send = .{ .pid = connection.owner, .value = try (c.station.Frame{ .kind = .cast, .payload = value }).encode() } } }, key) };
}
test "unsigned mediated candidates preserve the caller's exact native request" {
    var operation = try intent();
    defer operation.deinit();
    const original = try signed(try p.Value.init(operation.body));
    var candidate: Client.Candidate = .{ .definition = g.current_definition, .connection = connection, .request = original.signed.request };
    try t.expect(try candidate.matches(&operation));
    const prepared = try candidate.sign(try p.Ed25519.KeyPair.generateDeterministic(@splat(10)));
    try t.expectEqualDeep(original, prepared);
    var rotated: Client = .{ .transport = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11)) };
    try rotated.validate(prepared);
    var forged = prepared;
    forged.public_key = rotated.key.public_key.toBytes();
    try t.expectError(error.SignatureVerificationFailed, rotated.validate(forged));
    candidate.connection.principal += 1;
    try t.expectError(error.CatalogIdentityConflict, candidate.command());
    candidate.connection = connection;
    candidate.request.command.send.role = 9;
    try t.expectError(error.CatalogIdentityConflict, candidate.command());
}
test "signed typed Table sends persist exact bytes and require explicit definitions" {
    var operation = try intent();
    defer operation.deinit();
    const commands = [_]p.Value{
        try p.Value.init(operation.body),
        try (c.TableControl.Command{ .begin = .{ .header = try operation.header.encode(), .namespace = operation.namespace, .spec = operation.spec } }).encode(),
        try (c.TableControl.Command{ .part = try c.TableControl.Part.init(operation.upload(), 0, operation.body[0..128]) }).encode(),
        try (c.TableControl.Command{ .drive = operation.upload() }).encode(),
        try (c.TableControl.Command{ .cancel_ddl = operation.identity.ddl }).encode(),
    };
    for (commands) |value| {
        const prepared = try signed(value);
        try t.expect(try prepared.matches(&operation));
        const bytes = try prepared.save(t.allocator);
        defer t.allocator.free(bytes);
        const restored = try Client.Prepared.restore(t.allocator, bytes);
        @memset(bytes, 0);
        try t.expectEqualDeep(prepared, restored);
        const canonical = try restored.save(t.allocator);
        defer t.allocator.free(canonical);
        for (0..8) |index| {
            var parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, canonical, .{});
            defer parsed.deinit();
            const object = &parsed.value.object;
            switch (index) {
                0 => try t.expect(object.swapRemove("definition")),
                1 => object.getPtr("definition").?.* = .{ .string = "foreign-v1-definition" },
                2 => try t.expect(object.getPtr("signed").?.object.getPtr("request").?.object.swapRemove("definition")),
                3 => object.getPtr("signed").?.object.getPtr("request").?.object.getPtr("definition").?.* = .{ .string = "foreign-v1-definition" },
                4 => object.getPtr("version").?.* = .{ .integer = 2 },
                5 => object.getPtr("connection").?.object.getPtr("owner").?.* = .{ .integer = 4 },
                6 => object.getPtr("connection").?.object.getPtr("scope").?.object.getPtr("resource").?.* = .{ .integer = 8 },
                7 => try t.expect(object.swapRemove("public_key")),
                else => unreachable,
            }
            const invalid = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
            defer t.allocator.free(invalid);
            try t.expectError(error.InvalidCatalogPrepared, Client.Prepared.restore(t.allocator, invalid));
        }
        const spaced = try std.fmt.allocPrint(t.allocator, "{s}\n", .{canonical});
        defer t.allocator.free(spaced);
        try t.expectError(error.InvalidCatalogPrepared, Client.Prepared.restore(t.allocator, spaced));
    }
}
test "signed Table caller rejects altered signatures identities and recovery steps before network access" {
    var client: Client = .{ .transport = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    var operation = try intent();
    defer operation.deinit();
    const prepared = try signed(try p.Value.init(operation.body));
    try client.validate(prepared);
    var changed = prepared;
    changed.signed.request.sequence += 1;
    try t.expectError(error.SignatureVerificationFailed, client.submit(changed));
    changed = prepared;
    changed.signed.request.command = .{ .checkpoint = {} };
    try t.expectError(error.InvalidCatalogPrepared, client.submit(changed));
    inline for (.{ "realm", "resource", "catalog" }) |field| {
        client.connection = connection;
        @field(client.connection.scope, field) -= 1;
        try t.expectError(error.CatalogIdentityConflict, client.submit(prepared));
        try t.expectError(error.CatalogIdentityConflict, client.next(&operation));
        try t.expectError(error.CatalogIdentityConflict, client.waitForChange(&operation));
        try t.expectError(error.CatalogIdentityConflict, client.prepareResume(&operation));
        try t.expectError(error.CatalogIdentityConflict, client.status(&operation));
    }
    client.connection = connection;
    var ref = operation.identity.ddl;
    ref.principal += 1;
    try t.expectError(error.CatalogIdentityConflict, client.prepareControl(.{ .cancel_ddl = ref }));
    try t.expectError(error.InvalidCatalogIdentity, client.observe(prepared, 0));
    try t.expectError(error.InvalidCatalogIdentity, client.waitObserve(prepared, 0));
    try t.expectError(error.InvalidCatalogIdentity, client.progress(&operation, prepared, 0));
    try t.expectError(error.InvalidCatalogIdentity, client.waitProgress(&operation, prepared, 0));
    try t.expectError(error.InvalidCatalogIdentity, client.inputDisposition(prepared, 0));
    var foreign = operation.upload();
    foreign.namespace += 1;
    try t.expect(!try (try signed(try (c.TableControl.Command{ .drive = foreign }).encode())).matches(&operation));
}
test "Table work waits cannot reuse another connection or operation hint" {
    var client: Client = .{ .transport = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    var operation = try intent();
    defer operation.deinit();
    // Without a preceding running observation this is a local no-op.
    try client.waitForChange(&operation);
    for (0..3) |change| {
        client.pending_change = .{ .connection = connection, .identity = operation.identity, .namespace = operation.namespace, .position = 100 };
        switch (change) {
            0 => client.pending_change.?.namespace += 1,
            1 => client.pending_change.?.identity.ddl.operation -= 1,
            2 => client.pending_change.?.connection.principal += 1,
            else => unreachable,
        }
        try t.expectError(error.CatalogIdentityConflict, client.waitForChange(&operation));
        try t.expectEqual(null, client.pending_change);
    }
}
test "typed catalog metadata caller validates connection before opening any source" {
    var client: Client = .{ .transport = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    client.connection.scope.resource = 0;
    try t.expectError(error.InvalidCatalogIdentity, client.describe());
    try t.expectError(error.InvalidCatalogIdentity, client.lookup(t.allocator, try c.TableMetadata.Name.init("people")));
    try t.expectError(error.InvalidCatalogIdentity, client.list(null));
}

test "general SQL creation compiles offline into the same typed intent" {
    var client: Client = .{ .transport = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    var original = try client.compile(t.allocator, "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL, active BOOLEAN DEFAULT TRUE)", .{ .operation = 1, .namespace = 1000, .create_object = 100 }, null);
    defer original.deinit();
    var command = try original.command(t.allocator);
    defer command.deinit();
    const schema = command.body.request.ddl.action.create.schema;
    try t.expectEqual(@as(usize, 3), schema.columns.len);
    try t.expectEqual(.int32, schema.columns[0].type);
    try t.expectEqualSlices(u64, &.{1}, schema.primary_key);
    try t.expectEqual(@as(?u32, 200), schema.columns[1].max_characters);
    try t.expect(schema.columns[2].default.?.value.atom.boolean);
    try t.expectError(error.InvalidCatalogIdentity, client.compile(t.allocator, "CREATE TABLE people (id INTEGER)", .{ .operation = 1, .namespace = 1000 }, null));
    try t.expectError(error.InvalidCatalogIdentity, client.compile(t.allocator, "DELETE FROM people", .{ .operation = 1, .namespace = 1000, .create_object = 100 }, null));
}
test "invalid Table headers report their location before reading the authority" {
    var client: Client = .{ .transport = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    inline for (.{ "CREATE people", "INSERT people", "DELETE people" }) |text| {
        var location: c.fuze.Sql.Location = .{ .offset = 999 };
        try t.expectError(error.InvalidSqlSyntax, client.compile(t.allocator, text, .{ .operation = 1, .namespace = 1000 }, &location));
        try t.expectEqual(@as(usize, 7), location.offset);
    }
}
