const std = @import("std");
const t = std.testing;
const app = @import("root.zig");
test "host compile and visual formatting share canonical meaning without transport" {
    var config: app.Host.Config = .{ .scope = .{ .realm = 49, .application = 9, .pid = 17, .resource = 19, .namespace = .{ .value = 23 } } };
    config.operators[0] = 44;
    var wire = app.station.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    var compiled = try app.Host.run(t.allocator, &wire, config, .{ .compile = .{ .source = @embedFile("fixtures/board.sql") } });
    defer compiled.deinit();
    var formatted = try app.Host.run(t.allocator, &wire, config, .{ .format = compiled.value.compiled.definition });
    defer formatted.deinit();
    try t.expectEqualDeep(compiled.value.compiled, formatted.value.compiled);
    try t.expectEqualDeep(try app.station.Publication.Digest.of(app.Publication.format, compiled.value.compiled.canonical), compiled.value.compiled.spec);
    try t.expectError(error.InvalidApplicationProgram, app.Host.run(t.allocator, &wire, config, .{ .compile = .{ .source = "CREATE INTERFACE broken;" } }));
    try t.expectError(error.ApplicationOperatorDenied, app.Host.run(t.allocator, &wire, config, .{ .prepare = .{ .principal = 45, .sequence = .{ .value = 1 }, .command = .initialize } }));
    var signed: app.Native.Signed = .{ .prepared = try app.Native.prepare(config.scope, 45, .{ .value = 1 }, .initialize), .signature = @splat(0) };
    try t.expectError(error.ApplicationOperatorDenied, app.Host.run(t.allocator, &wire, config, .{ .submit = signed }));
    signed.prepared = try app.Native.prepare(config.scope, 44, .{ .value = 1 }, .initialize);
    signed.prepared.digest[0] ^= 1;
    try t.expectError(error.ApplicationDigestMismatch, app.Host.run(t.allocator, &wire, config, .{ .submit = signed }));
    config.operators[1] = 44;
    try t.expectError(error.InvalidApplicationOperators, config.validate());
    config.operators[1] = null;
    config.operators[2] = 46;
    try t.expectError(error.InvalidApplicationOperators, config.validate());
}
