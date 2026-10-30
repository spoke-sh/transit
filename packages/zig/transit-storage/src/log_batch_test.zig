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
