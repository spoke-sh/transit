const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const p = c.protocol;
const b = c.Bridge;
const Fixture = struct {
    connection: b.Connection,
    configuration: b.Configuration,
    policy: b.Policy,
    change: b.PolicyChange,
    compiled: b.Compiled,
    receipt: b.Receipt,
    disposition: b.Disposition,
};
test "neutral catalog values match independent records and preserve owned wide identities" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const fixture = (try p.Json.parseFromSlice(Fixture, a, @embedFile("fixtures/catalog-neutral-v1.json"))).value;
    const records = (try std.json.parseFromSlice(std.json.Value, a, @embedFile("fixtures/catalog-v1.json"), .{})).value.object.get("records").?.object;
    const commands = [_]c.Model.Command{
        .{ .initialize = try fixture.configuration.native() },
        .{ .create_table = try fixture.compiled.request.native() },
        .{ .set_policy = try fixture.change.native() },
    };
    for (commands, [_][]const u8{ "configuration", "request", "policy_change" }) |command, name| {
        const encoded = try command.encode();
        const json = try p.Json.valueAlloc(a, encoded);
        const expected = try std.json.Stringify.valueAlloc(a, records.get(name).?.string, .{});
        try t.expectEqualStrings(expected, json);
    }
    var client: c.Client = .{ .transport = undefined, .connection = try fixture.connection.native(), .key = undefined };
    const compiled = (try b.apply(a, &client, .{ .compile = .{ .operation = "18446744073709551615", .object = "18446744073709551615", .table = 9, .sql = "CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)" } })).compiled;
    try t.expectEqualDeep(fixture.compiled, compiled);
    var request = try compiled.request.native();
    const owned = try b.CreateTable.fromNative(a, request);
    @memset(@constCast(compiled.request.operation), '0');
    @memset(@constCast(compiled.request.name), 'x');
    try t.expectEqual(std.math.maxInt(u64), request.operation);
    try t.expectEqualStrings("items", request.name.slice());
    @memset(&request.name.bytes, 'x');
    try t.expectEqualStrings("items", owned.name);
    const receipt: c.Model.Receipt = .{ .request = try fixture.compiled.request.native(), .principal = 17, .input = 2, .outcome = .applied };
    try t.expectEqualDeep(fixture.receipt, try b.Receipt.fromNative(a, receipt));
    const encoded = try std.json.Stringify.valueAlloc(a, records.get("disposition").?.string, .{});
    const native = try c.Records.decode(c.Model.Disposition, 'e', (try p.Json.parseFromSlice(p.Value, a, encoded)).value);
    try t.expectEqualDeep(fixture.disposition, try b.Disposition.fromNative(a, native));
    var policy = try fixture.policy.native();
    policy.revision = std.math.maxInt(u64);
    const wide = try b.Policy.fromNative(a, policy);
    try t.expectEqualStrings("18446744073709551615", wide.revision);
    try t.expectEqualDeep(policy, try wide.native());
}
test "neutral catalog commands reject unsafe numbers and malformed recovery without transport" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const fixture = (try p.Json.parseFromSlice(Fixture, a, @embedFile("fixtures/catalog-neutral-v1.json"))).value;
    var client: c.Client = .{ .transport = undefined, .connection = try fixture.connection.native(), .key = undefined };
    const caps = (try b.apply(a, &client, .capabilities)).capabilities;
    try t.expect(caps.initialize and caps.create_table and caps.conditional_policy);
    try t.expectEqual(p.Growth.current_definition, caps.definition);
    for ([_][]const u8{ "", "00", "+1", "-1", " 1", "18446744073709551616" }) |value| {
        var request = fixture.compiled.request;
        request.operation = value;
        try t.expectError(error.InvalidCatalogInteger, b.apply(a, &client, .{ .prepare_create = request }));
    }
    var request = fixture.compiled.request;
    request.scope.resource += 1;
    try t.expectError(error.CatalogScopeChanged, b.apply(a, &client, .{ .prepare_create = request }));
    try t.expectError(error.InvalidCatalogPrepared, b.apply(a, &client, .{ .submit = "{}" }));
    try t.expectError(error.InvalidCatalogPrepared, b.apply(a, &client, .{ .input_disposition = .{ .prepared = "{}", .input = 1 } }));
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(b.Connection, a, "{\"scope\":{\"realm\":1,\"resource\":7,\"catalog\":18446744073709551615},\"owner\":3,\"principal\":17}"));
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(b.Connection, a, "{\"scope\":{\"realm\":\"1\",\"resource\":7,\"catalog\":\"1\"},\"owner\":3,\"principal\":17}"));
    var connection = fixture.connection;
    connection.principal = p.max_counter + 1;
    try t.expectError(error.InvalidCatalogIdentity, connection.native());
}
