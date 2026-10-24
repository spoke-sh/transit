const std = @import("std");
const g = @import("root.zig");
const c = g.CapturedLedger;
const ops = g.SessionOperations;
const Store = @import("store_test.zig");
const t = std.testing;
const binding: g.Ledger.Binding = .{ .resource = 8, .catalog = 1, .owner = 9 };
const configuration: g.Ledger.Configuration = .{ .realm = 1, .resource = 7, .owner = 3, .worker = 2, .ingress = 4, .control = 5, .coordinator = 10, .table_principal = 6, .account = @splat(7), .bindings = &.{binding}, .intent_bytes = 4096, .operation_quota = 1000, .byte_quota = 8 * 1024 * 1024, .pending_quota = 4 };
const ledger: g.Ledger = .{ .configuration = configuration };
fn apply(store: *Store, command: c.Command) !void {
    var turn = try store.capture();
    try c.apply(ledger, &turn, command);
    try store.commit(turn);
}
fn begin(store: *Store, nonce: u8) !u64 {
    var turn = try store.capture();
    const item = try ops.begin(ledger, &turn, .{ .nonce = @splat(nonce), .fingerprint = @splat(nonce), .kind = .captured, .binding = binding, .original = @splat(nonce), .source = @splat(99), .expected_generation = 1, .reservation = 1024 * 1024 });
    try store.commit(turn);
    return item.id;
}
fn stage(store: *Store, id: u64, record: u64, format: u32, bytes: []const u8) !void {
    const target: g.Control.Record = .{ .operation = id, .generation = store.generation, .record = record };
    const start: c.Command = .{ .begin = .{ .target = target, .spec = try g.station.Publication.Digest.of(format, bytes) } };
    try apply(store, start);
    try apply(store, start); // Lost begin acknowledgement is idempotent.
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = @min(128, bytes.len - offset);
        const part: c.Command = .{ .part = .{ .target = target, .part = try g.Control.Part.init(@intCast(offset), bytes[offset..][0..count]) } };
        try apply(store, part);
        try apply(store, part);
        offset += count;
    }
}
test "captured publication fences dispatch and serializes exact source requests across restart" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    try ledger.initialize(&turn);
    try store.commit(turn);
    store.origin = configuration.ingress;
    const id = try begin(&store, 1);
    const second = try begin(&store, 2);
    const bundle: [259]u8 = @splat(3);
    try stage(&store, id, 1, g.query.Bundle.format, &bundle);
    try stage(&store, second, 1, g.query.Bundle.format, &bundle);
    const first: g.Control.Record = .{ .operation = id, .generation = 1, .record = 1 };
    try apply(&store, .{ .publish = first });
    try apply(&store, .{ .publish = first });
    try apply(&store, .{ .publish = .{ .operation = second, .generation = 1, .record = 1 } });
    turn = try store.capture();
    var reader = turn.committed();
    const retained = try g.Upload.read(t.allocator, ledger.publication(id), &reader, 1, bundle.len);
    defer t.allocator.free(retained);
    try t.expectEqualSlices(u8, &bundle, retained);
    const key = try g.catalog.protocol.Ed25519.KeyPair.generateDeterministic(@splat(10));
    const request: g.query.UnifiedClient.Prepared = .{ .signed = try g.catalog.protocol.Growth.sign(.{ .realm = 1, .principal = 20, .sequence = 1, .command = .{ .send = .{ .pid = 21, .value = try (g.station.Frame{ .kind = .cast, .payload = try (g.query.UnifiedRequest.Command{ .cancel = 7 }).encode() }).encode() } } }, key) };
    var buffer: [g.query.SavedSubmission.max_bytes]u8 = undefined;
    const encoded = try g.query.SavedSubmission.encode(request, &buffer);
    try stage(&store, id, 2, g.query.SavedSubmission.format, encoded);
    turn = try store.capture();
    try t.expectError(error.SqlSourceBusy, c.apply(ledger, &turn, .{ .begin = .{ .target = .{ .operation = second, .generation = 1, .record = 2 }, .spec = try g.station.Publication.Digest.of(g.query.SavedSubmission.format, encoded) } }));
    try t.expectError(error.GatewayUnresolvedStep, ops.complete(ledger, &turn, id, 1, .applied));
    // A replacement publishes the committed proposal; the old generation
    // cannot change its payload or record a receipt afterwards.
    store.generation = 2;
    turn = try store.capture();
    try t.expectError(error.StaleGatewayCoordinator, c.apply(ledger, &turn, .{ .publish = .{ .operation = id, .generation = 1, .record = 2 } }));
    const target: g.Control.Record = .{ .operation = id, .generation = 2, .record = 2 };
    try apply(&store, .{ .publish = target });
    turn = try store.capture();
    reader = turn.committed();
    const restored = try g.Upload.read(t.allocator, ledger.publication(id), &reader, 2, g.query.SavedSubmission.max_bytes);
    defer t.allocator.free(restored);
    try t.expectEqualDeep(request, try g.query.SavedSubmission.decode(restored));
    try t.expectError(error.GatewayUnresolvedStep, c.apply(ledger, &turn, .{ .abandon = target }));
    try apply(&store, .{ .receipt = .{ .target = target, .input = 123 } });
    try apply(&store, .{ .receipt = .{ .target = target, .input = 123 } });
    turn = try store.capture();
    try t.expectError(error.InvalidCapturedQueryReceipt, c.apply(ledger, &turn, .{ .receipt = .{ .target = target, .input = 124 } }));
    try apply(&store, .{ .processed = .{ .target = target, .rejected = 0 } });
    try stage(&store, second, 2, g.query.SavedSubmission.format, encoded);
    turn = try store.capture();
    try ops.complete(ledger, &turn, id, 2, .applied);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(@as(u64, 1024 * 1024), (try ledger.head(&turn)).used_bytes);
    try t.expectEqual(ops.Kind.captured, (try ops.reference(ledger, &turn, id)).kind);
}
test "an incomplete captured admission can be cancelled without compiling or dispatching" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    try ledger.initialize(&turn);
    try store.commit(turn);
    store.origin = configuration.ingress;
    const id = try begin(&store, 4);
    try stage(&store, id, 1, g.query.Bundle.format, "frozen-but-unpublished");
    try apply(&store, .{ .cancel = .{ .operation = id, .generation = 1 } });
    turn = try store.capture();
    try t.expectError(error.GatewayUnresolvedStep, c.apply(ledger, &turn, .{ .publish = .{ .operation = id, .generation = 1, .record = 1 } }));
    try ops.complete(ledger, &turn, id, 1, .cancelled);
    try store.commit(turn);
    turn = try store.capture();
    const item = try ops.external(ledger, &turn, id);
    try t.expectEqual(.cancelled, item.summary);
    try t.expectEqual(@as(u64, 0), (try ledger.head(&turn)).unsettled);
}
