const std = @import("std");
const g = @import("root.zig");
const Pub = g.station.Publication;
const Upload = g.Upload;
const Store = @import("store_test.zig");
const t = std.testing;
test "gateway publication preserves exact parts across discarded turns and lost replies" {
    var store: Store = .{};
    defer store.deinit();
    var body: [1301]u8 = undefined;
    for (&body, 0..) |*byte, i| byte.* = @truncate(i * 37 + 11);
    const spec = try Pub.Digest.of(0x47534901, &body);
    var turn = try store.capture();
    const publication = try Pub.create(&turn, .sql_gateway, 19, .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 });
    _ = try publication.begin(&turn, 1, spec);
    try store.commit(turn);
    for (0..(body.len + Upload.part_bytes - 1) / Upload.part_bytes) |i| {
        const offset: u32 = @intCast(i * Upload.part_bytes);
        const bytes = body[offset..][0..@min(Upload.part_bytes, body.len - offset)];
        // A failed/discarded private proposal does not publish even a half-part.
        turn = try store.capture();
        _ = try Upload.append(publication, &turn, 1, offset, bytes);
        turn = try store.capture();
        var committed = turn.committed();
        try t.expectError(error.PublicationNotPublished, publication.open(&committed, 1));
        _ = try Upload.append(publication, &turn, 1, offset, bytes);
        try store.commit(turn);
        // Simulate a lost reply by repeating the accepted exact part.
        turn = try store.capture();
        const prior = turn.decision;
        _ = try Upload.append(publication, &turn, 1, offset, bytes);
        try t.expectEqualDeep(prior, turn.decision);
        var wrong: [Upload.part_bytes]u8 = undefined;
        @memcpy(wrong[0..bytes.len], bytes);
        wrong[0] ^= 1;
        try t.expectError(error.GatewayUploadConflict, Upload.append(publication, &turn, 1, offset, wrong[0..bytes.len]));
        try t.expectEqualDeep(prior, turn.decision);
    }
    turn = try store.capture();
    try Upload.seal(publication, &turn, 1);
    // Private seal does not authorize reading from the captured committed cut.
    var committed = turn.committed();
    try t.expectError(error.PublicationNotPublished, publication.open(&committed, 1));
    try store.commit(turn);
    turn = try store.capture();
    committed = turn.committed();
    const result = try Upload.read(t.allocator, publication, &committed, 1, body.len);
    defer t.allocator.free(result);
    try t.expectEqualSlices(u8, &body, result);
    try t.expectError(error.GatewayRecordTooLarge, Upload.read(t.allocator, publication, &committed, 1, body.len - 1));
    store.denied = true;
    turn = try store.capture();
    committed = turn.committed();
    try t.expectError(error.AccessDenied, Upload.read(t.allocator, publication, &committed, 1, body.len));
}
