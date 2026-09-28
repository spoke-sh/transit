const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const n = root.Native;
const p = root.protocol;
test "native application signing agrees with independent v3 bytes and fences altered scope" {
    const Fixture = struct { version: u8, command: n.Prepared, read: n.PreparedRead };
    const fixture = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/native-signing-v1.json"));
    defer fixture.deinit();
    const command = fixture.value.command;
    const read = fixture.value.read;
    try t.expectEqualDeep(command, try n.prepare(command.scope, command.principal, command.sequence, command.command));
    try t.expectEqualDeep(read, try n.prepareRead(read.scope, read.principal, read.selection));
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const signed: n.Signed = .{ .prepared = command, .signature = (try key.sign(&command.digest, null)).toBytes() };
    const forwarded = try n.envelope(command.scope, signed);
    try p.Ed25519.Signature.fromBytes(forwarded.signature).verify(&try p.Growth.digest(forwarded.request), key.public_key);
    const signed_read: n.SignedRead = .{ .prepared = read, .signature = (try key.sign(&read.digest, null)).toBytes() };
    const forwarded_read = try n.queryEnvelope(read.scope, signed_read);
    try p.Ed25519.Signature.fromBytes(forwarded_read.signature).verify(&try p.Growth.queryDigest(forwarded_read.query), key.public_key);
    var changed = signed;
    changed.prepared.command.publish.value -= 1;
    try t.expectError(error.ApplicationDigestMismatch, n.envelope(command.scope, changed));
    changed = signed;
    changed.prepared.principal += 1;
    try t.expectError(error.ApplicationDigestMismatch, n.envelope(command.scope, changed));
    changed = signed;
    changed.prepared.scope.resource += 1;
    try t.expectError(error.ApplicationScopeChanged, n.envelope(command.scope, changed));
    var changed_read = signed_read;
    changed_read.prepared.selection.state.operation.value -= 1;
    try t.expectError(error.ApplicationDigestMismatch, n.queryEnvelope(read.scope, changed_read));
    changed_read = signed_read;
    changed_read.prepared.scope.namespace.value += 1;
    try t.expectError(error.ApplicationScopeChanged, n.queryEnvelope(read.scope, changed_read));
    try t.expectError(error.InvalidApplicationScope, n.prepare(command.scope, 0, .{ .value = 1 }, .initialize));
    try t.expectError(error.InvalidCounter, n.prepare(command.scope, command.principal, .{ .value = std.math.maxInt(u64) }, .initialize));
}
test "optional status selectors always generate a contiguous bounded native read batch" {
    const scope: n.Scope = .{ .realm = 49, .application = 9, .pid = 17, .resource = 19, .namespace = .{ .value = 23 } };
    for ([_]n.Selection{ .identity, .{ .state = .{} }, .{ .state = .{ .input = 5 } }, .{ .state = .{ .operation = .{ .value = 1 } } }, .{ .state = .{ .operation = .{ .value = 1 }, .record = .{ .value = 2 } } } }) |selection| {
        const prepared = try n.prepareRead(scope, 44, selection);
        const signed = try n.queryEnvelope(scope, .{ .prepared = prepared, .signature = @splat(0) });
        try p.Growth.validateQuery(signed.query);
    }
    try t.expectError(error.InvalidApplicationSelection, n.prepareRead(scope, 44, .{ .state = .{ .record = .{ .value = 2 } } }));
}
