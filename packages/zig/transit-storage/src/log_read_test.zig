const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("root.zig");
const R = s.LogRead;
const support = @import("log_test_support.zig");

test "log read MAC matches the independent Python fixture with full-width coverage" {
    const parsed = try p.Json.parseFromSlice(p.StreamRead.Cursor, t.allocator, @embedFile("stream_read_fixture.json"));
    defer parsed.deinit();
    const authority = try R.Authority.init(@splat(7));
    try authority.verify(parsed.value);
    try t.expectEqualDeep(parsed.value, try authority.issue(parsed.value.read, parsed.value.coverage));
}

test "log read bases survive disk reopen and authenticate exact finite coverage" {
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = 1 };
    const basis: R.Basis = .{
        .request = .{ .target = target, .operation = .{ .scope = target.interpretation.object.scope, .principal = 0, .operation = std.math.maxInt(u64) }, .group = null, .from = 0, .until = null, .timestamp = null },
        .declared = declared,
        .cut = .{ .target = target, .accepted = .{ .partition = 91, .next_lsn = 4 }, .retained_from = 0, .next = 0 },
        .until = 0,
        .batches = null,
        .segments = null,
    };
    const receipt = try R.stage(objects.objectStore(), basis);
    try t.expectEqual(@as(u64, 5), receipt.accepted.next_lsn);
    try t.expectEqualDeep(basis, try R.load(t.allocator, objects.objectStore(), receipt.handle()));
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    try t.expectEqualDeep(basis, try R.load(t.allocator, objects.objectStore(), receipt.handle()));
    const authority = try R.Authority.init(@splat(7));
    const cursor = try authority.issue(receipt.handle(), try receipt.initialCoverage());
    try authority.verify(cursor);
    try t.expect(cursor.coverage.complete);
    var other = cursor;
    other.coverage.until = 1;
    other.coverage.cut.next = 1;
    other.coverage.through = 1;
    try t.expectError(error.StreamCursorUnauthenticated, authority.verify(other));
    other = cursor;
    other.read.owner.operation -= 1;
    try t.expectError(error.StreamCursorUnauthenticated, authority.verify(other));
    other = cursor;
    other.read.source.sha256[0] ^= 1;
    try t.expectError(error.StreamCursorUnauthenticated, authority.verify(other));
    other = cursor;
    other.authentication[0] ^= 1;
    try t.expectError(error.StreamCursorUnauthenticated, authority.verify(other));
    try t.expectError(error.StreamCursorUnauthenticated, (try R.Authority.init(@splat(8))).verify(cursor));
    try t.expectError(error.InvalidStreamReadAuthority, R.Authority.init(@splat(0)));
    var handle = receipt.handle();
    handle.owner.operation -= 1;
    try t.expectError(error.StreamReadConflict, R.load(t.allocator, objects.objectStore(), handle));
    const pin: R.Pin = .{ .source = receipt.source, .released = false };
    try t.expectEqualDeep(pin, try R.Pin.decode(try pin.encode()));
    var bytes: [R.max_bytes]u8 = undefined;
    const encoded = try R.encode(basis, &bytes);
    bytes[8] ^= 1;
    handle = receipt.handle();
    handle.source = .{ .bytes = encoded.len, .sha256 = R.hash(encoded) };
    var name: [96]u8 = undefined;
    _ = try objects.objectStore().putImmutable(try R.key(handle.source, &name), encoded, handle.source.sha256);
    try t.expectError(error.IncompatibleDefinition, R.load(t.allocator, objects.objectStore(), handle));
    try objects.objectStore().delete(try R.key(receipt.source, &name));
    try t.expectError(error.StreamReadMissing, R.load(t.allocator, objects.objectStore(), receipt.handle()));
}
