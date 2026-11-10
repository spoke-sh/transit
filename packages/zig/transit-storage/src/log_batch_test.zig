const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const B = s.LogBatch;
const support = @import("log_test_support.zig");
const cells = [_]f.Types.Values.Cell{
    .{ .value = .{ .atom = .{ .bytes = "AbC" } } },
    .{ .value = .{ .atom = .{ .bytes = "payload" } } },
};

fn operation() p.DataLifecycle.Operation {
    return .{ .scope = support.definition(.stream).object.scope, .principal = 0, .operation = std.math.maxInt(u64) };
}

fn request(owned: *const s.LogDeclaration.Owned, bytes: []const u8, rows: u64) !p.StreamQueue.Append {
    const stored = try owned.stored();
    // Independent SHA-256 of canonical ASCII_CI key 04 61 62 63 00 00
    // maps to partition one of two, including spelling variants of AbC.
    return .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = stored.declaration.interpretation, .partition = 1 }, .operation = operation(), .kind = if (owned.definition.configuration.policy == .stream) .stream else .queue, .producer = null, .rows = rows, .payload = B.content(bytes) };
}

test "log batches bind original identity schema kind and collated partition with reusable scratch" {
    var owned = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer owned.deinit();
    var bytes: [8192]u8 = undefined;
    const encoded = try B.encode(owned.definition.schema, operation(), .stream, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &bytes);
    try t.expectEqualStrings("LOGBAT01", encoded[0..8]);
    try t.expectEqualSlices(u8, &.{ 1, 0, 0, 0, 2 }, encoded[72..77]);
    var failing = t.FailingAllocator.init(t.allocator, .{});
    var scratch = std.heap.ArenaAllocator.init(failing.allocator());
    defer scratch.deinit();
    var key: [256]u8 = undefined;
    const append = try request(&owned, encoded, 2);
    for (0..2) |_| try B.validate(encoded, &owned, append, &scratch, &key);
    const allocations = failing.alloc_index;
    failing.fail_index = allocations;
    for (0..10) |_| try B.validate(encoded, &owned, append, &scratch, &key);
    try t.expectEqual(allocations, failing.alloc_index);
    var other = append;
    other.target.partition = 0;
    try t.expectError(error.LogPartitionKeyMismatch, B.validate(encoded, &owned, other, &scratch, &key));
    other = append;
    other.target.interpretation.digest[0] ^= 1;
    try t.expectError(error.LogPartitionConflict, B.validate(encoded, &owned, other, &scratch, &key));
    other = append;
    other.operation.operation -= 1;
    try t.expectError(error.LogRowIdentityConflict, B.validate(encoded, &owned, other, &scratch, &key));
    other = append;
    other.payload.sha256[0] ^= 1;
    try t.expectError(error.LogPayloadConflict, B.validate(encoded, &owned, other, &scratch, &key));
}

test "log batches preserve queue delay metadata and require explicit stream compaction" {
    var queue = try s.LogDeclaration.prepare(t.allocator, support.definition(.queue));
    defer queue.deinit();
    var stream = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer stream.deinit();
    var bytes: [8192]u8 = undefined;
    const encoded = try B.encode(queue.definition.schema, operation(), .queue, &.{.{ .cells = &cells, .visible_ms = std.math.maxInt(u64) }}, &bytes);
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    var key: [256]u8 = undefined;
    try B.validate(encoded, &queue, try request(&queue, encoded, 1), &scratch, &key);
    var iterator = try B.Iterator.init(encoded, queue.definition.schema, .queue, 1);
    const row = (try iterator.next()).?;
    try t.expectEqual(std.math.maxInt(u64), row.visible_ms);
    var retained = std.heap.ArenaAllocator.init(t.allocator);
    defer retained.deinit();
    const decoded = try row.decode(retained.allocator(), queue.definition.schema, operation());
    @memset(&bytes, 0);
    try t.expectEqualStrings("payload", decoded.cells[1].value.atom.bytes);
    try t.expectError(error.InvalidLogRowMetadata, B.encode(queue.definition.schema, operation(), .queue, &.{.{ .cells = &cells, .tombstone = true }}, &bytes));
    try t.expectError(error.InvalidLogRowMetadata, B.encode(stream.definition.schema, operation(), .stream, &.{.{ .cells = &cells, .visible_ms = 1 }}, &bytes));
    const tombstone = try B.encode(stream.definition.schema, operation(), .stream, &.{.{ .cells = &cells, .tombstone = true }}, &bytes);
    try t.expectError(error.StreamCompactionNotDeclared, B.validate(tombstone, &stream, try request(&stream, tombstone, 1), &scratch, &key));
}

test "log batches reject trailing bytes truncated rows wrong definitions and changed kind" {
    var owned = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer owned.deinit();
    var bytes: [8192]u8 = undefined;
    const encoded = try B.encode(owned.definition.schema, operation(), .stream, &.{.{ .cells = &cells }}, &bytes);
    var iterator = try B.Iterator.init(encoded[0 .. encoded.len - 1], owned.definition.schema, .stream, 1);
    try t.expectError(error.InvalidLogBatch, iterator.next());
    bytes[encoded.len] = 0;
    iterator = try B.Iterator.init(bytes[0 .. encoded.len + 1], owned.definition.schema, .stream, 1);
    try t.expectError(error.InvalidLogBatch, iterator.next());
    try t.expectError(error.LogBatchKindConflict, B.Iterator.init(encoded, owned.definition.schema, .queue, 1));
    try t.expectError(error.InvalidLogBatch, B.Iterator.init(encoded, owned.definition.schema, .stream, 2));
    bytes[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, B.Iterator.init(encoded, owned.definition.schema, .stream, 1));
    bytes[8] ^= 1;
    bytes[B.header_bytes + 12] = 2;
    iterator = try B.Iterator.init(encoded, owned.definition.schema, .stream, 1);
    try t.expectError(error.InvalidLogRowMetadata, iterator.next());
}

test "log batches preserve sparse original identities in TableRow headers with allocation-free buffers" {
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    const schema = declaration.definition.schema;
    const op: p.DataLifecycle.Operation = .{ .scope = declaration.definition.object.scope, .principal = 2, .operation = 99 };
    const rows: [7]B.Row = @splat(.{ .cells = &cells });
    var original: [8192]u8 = undefined;
    const bytes = try B.encode(schema, op, .stream, &rows, &original);
    var output: [8192]u8 = undefined;
    var encoder = try B.SparseEncoder.init(schema, 7, 3, &output);
    var input = try B.Iterator.init(bytes, schema, .stream, 7);
    while (try input.next()) |row| if (row.ordinal % 3 == 0) try encoder.append(row);
    const sparse = try encoder.finish();
    var iterator = try B.SparseIterator.init(sparse, schema, 7);
    var memory: [8192]u8 = undefined;
    var scratch = std.heap.FixedBufferAllocator.init(&memory);
    for ([_]u32{ 0, 3, 6 }) |ordinal| {
        const row = (try iterator.next()).?;
        try t.expectEqual(ordinal, row.ordinal);
        scratch.reset();
        const decoded = try row.decode(scratch.allocator(), schema, op);
        try t.expectEqualStrings("payload", decoded.cells[1].value.atom.bytes);
    }
    try t.expectEqual(@as(?B.EncodedRow, null), try iterator.next());
    try t.expectError(error.InvalidLogSegment, B.SparseIterator.init(bytes, schema, 7));
    try t.expectError(error.LogBatchKindConflict, B.Iterator.init(sparse, schema, .stream, 7));
    output[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, B.SparseIterator.init(sparse, schema, 7));
    output[8] ^= 1;
    iterator = try B.SparseIterator.init(sparse[0 .. sparse.len - 1], schema, 7);
    _ = try iterator.next();
    _ = try iterator.next();
    try t.expectError(error.InvalidLogSegment, iterator.next());
    iterator = try B.SparseIterator.init(sparse, schema, 7);
    _ = try iterator.next();
    std.mem.writeInt(u32, output[iterator.at + B.row_header_bytes + f.TableRow.header_bytes - 4 ..][0..4], 0, .big);
    try t.expectError(error.InvalidLogSegment, iterator.next());
    encoder = try B.SparseEncoder.init(schema, 7, 0, &output);
    iterator = try B.SparseIterator.init(try encoder.finish(), schema, 7);
    try t.expectEqual(@as(?B.EncodedRow, null), try iterator.next());
    output[B.header_bytes] = 0;
    try t.expectError(error.InvalidLogSegment, B.SparseIterator.init(output[0 .. B.header_bytes + 1], schema, 7));
}
