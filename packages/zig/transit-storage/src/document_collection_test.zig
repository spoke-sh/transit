const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("root.zig");
const C = s.DocumentCollection;

test "document collection MAC matches independent fixture and binds every continuation field" {
    const parsed = try p.Json.parseFromSlice(p.DocumentRead.Collection.Cursor, t.allocator, @embedFile("document_collection_fixture.json"));
    defer parsed.deinit();
    const cursor = parsed.value;
    try C.verify(@splat(7), cursor);
    try t.expectEqualDeep(cursor, try C.sign(@splat(7), cursor.read, cursor.coverage));
    inline for (.{ "after", "heads", "steps", "bytes", "complete", "owner", "source", "authentication" }) |field| {
        var changed = cursor;
        if (comptime std.mem.eql(u8, field, "after")) changed.coverage.after.?[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "heads")) changed.coverage.heads += 1;
        if (comptime std.mem.eql(u8, field, "steps")) changed.coverage.steps += 1;
        if (comptime std.mem.eql(u8, field, "bytes")) changed.coverage.bytes += 1;
        if (comptime std.mem.eql(u8, field, "complete")) changed.coverage.complete = !changed.coverage.complete;
        if (comptime std.mem.eql(u8, field, "owner")) changed.read.owner.operation -= 1;
        if (comptime std.mem.eql(u8, field, "source")) changed.read.source.sha256[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "authentication")) changed.authentication[0] ^= 1;
        try t.expectError(error.InvalidDocumentCursor, C.verify(@splat(7), changed));
    }
    try t.expectError(error.InvalidDocumentCursor, C.verify(@splat(8), cursor));
    try t.expectError(error.InvalidDocumentReadSecret, C.sign(@splat(0), cursor.read, cursor.coverage));
}

test "document collection sources reject foreign definitions missing artifacts and mismatched roots" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const target: p.DocumentOperation.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 5 }, .revision = 1, .digest = @splat(2) },
        .partition = 0,
    };
    const source: C.Source = .{
        .definition = p.Growth.current_definition,
        .request = .{ .target = target, .operation = .{ .scope = target.interpretation.object.scope, .principal = 7, .operation = 1 }, .max_steps = 32, .max_bytes = 4096, .page_heads = 2, .page_bytes = 2048 },
        .cut = .{ .target = target, .observed = .{ .partition = 123, .next_lsn = 1 }, .changed_next_lsn = 1, .heads_digest = null },
        .heads_root = null,
    };
    const content = try C.stage(objects.objectStore(), source);
    try t.expectEqualDeep(source, try C.load(t.allocator, objects.objectStore(), content));
    var invalid = source;
    invalid.cut.heads_digest = @splat(3);
    invalid.cut.changed_next_lsn = 2;
    invalid.cut.observed.next_lsn = 2;
    try t.expectError(error.InvalidDocumentCollection, invalid.validate());
    var buffer: [C.max_bytes]u8 = undefined;
    const encoded = try C.encode(source, &buffer);
    buffer[8] ^= 1;
    const foreign: p.DataLifecycle.Content = .{ .bytes = encoded.len, .sha256 = s.DocumentEvidence.hash(encoded) };
    var name: [96]u8 = undefined;
    _ = try objects.objectStore().putImmutable(try C.key(foreign, &name), encoded, foreign.sha256);
    try t.expectError(error.IncompatibleDefinition, C.load(t.allocator, objects.objectStore(), foreign));
    const comma = std.mem.indexOfScalar(u8, encoded[40..], ',').? + 40;
    const missing = try std.fmt.allocPrint(t.allocator, "{{{s}", .{encoded[comma + 1 ..]});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(C.Source, t.allocator, missing));
    try objects.objectStore().delete(try C.key(content, &name));
    try t.expectError(error.DocumentReadMissing, C.load(t.allocator, objects.objectStore(), content));
}
