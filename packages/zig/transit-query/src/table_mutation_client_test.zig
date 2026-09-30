const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const Client = q.TableMutationClient;
const connection: Client.Connection = .{ .realm = 46, .principal = 1234, .writer = 65536, .resource = 7, .table = 1 };

fn fixture() !Client.Prepared {
    const table: s.Table = .{ .resource = 7, .id = 1, .schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .utf8 } };
    const request = try q.TableMutationRequest.fromSql(46, 65536, table, try .init("items"), "INSERT INTO items (id,value) VALUES(1,'owned')");
    const command: q.TableMutationRecords.Command = .{ .begin = .{ .reference = try request.reference(99), .table = 1, .policy_revision = 1 } };
    return .{ .version = 1, .definition = g.current_definition, .connection = connection, .signed = try g.sign(.{ .realm = 46, .principal = 1234, .sequence = 3, .command = .{ .send = .{ .pid = 65536, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, try p.Ed25519.KeyPair.generateDeterministic(@splat(10))) };
}
test "mutation prepared bytes own recovery state and reject missing or foreign definitions" {
    const prepared = try fixture();
    const bytes = try prepared.save(t.allocator);
    defer t.allocator.free(bytes);
    const recovered = try Client.Prepared.restore(t.allocator, bytes);
    try t.expect(std.meta.eql(prepared, recovered));
    // Restoring owns every signature/request byte independently of the input.
    @memset(bytes, 0);
    try t.expect(std.meta.eql(prepared, recovered));
    const canonical = try recovered.save(t.allocator);
    defer t.allocator.free(canonical);
    for (0..5) |change| {
        var parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, canonical, .{});
        defer parsed.deinit();
        const object = &parsed.value.object;
        switch (change) {
            0 => try t.expect(object.swapRemove("definition")),
            1 => object.getPtr("definition").?.* = .{ .string = "foreign-v1-definition" },
            2 => try t.expect(object.getPtr("signed").?.object.getPtr("request").?.object.swapRemove("definition")),
            3 => object.getPtr("signed").?.object.getPtr("request").?.object.getPtr("definition").?.* = .{ .string = "foreign-v1-definition" },
            4 => object.getPtr("version").?.* = .{ .integer = 2 },
            else => unreachable,
        }
        const invalid = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
        defer t.allocator.free(invalid);
        try t.expectError(error.InvalidMutationPrepared, Client.Prepared.restore(t.allocator, invalid));
    }
    const spaced = try std.fmt.allocPrint(t.allocator, "{s}\n", .{canonical});
    defer t.allocator.free(spaced);
    try t.expectError(error.InvalidMutationPrepared, Client.Prepared.restore(t.allocator, spaced));
}
test "mutation retry validates original connection and signature before accessing the transport" {
    var client: Client = .{ .wire = undefined, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    const prepared = try fixture();
    try client.validate(prepared);
    inline for (.{ "realm", "principal", "writer", "resource", "table" }) |field| {
        client.connection = connection;
        @field(client.connection, field) += 1;
        try t.expectError(error.MutationIdentityConflict, client.submit(prepared));
    }
    client.connection = connection;
    var forged = prepared;
    forged.signed.request.sequence += 1;
    try t.expectError(error.SignatureVerificationFailed, client.submit(forged));
    forged = prepared;
    forged.signed.request.command = .{ .checkpoint = {} };
    try t.expectError(error.InvalidMutationPrepared, client.submit(forged));
    // A namespace-only old control payload cannot reach native submit either.
    forged = prepared;
    forged.signed.request.command.send.value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("TMX1\x01\x00\x00\x00\x00\x00\x00\x00") }).encode();
    if (client.submit(forged)) |_| return error.AcceptedLegacyCommand else |_| {}
}
