const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("root.zig");
const E = s.LogEvidence;
const support = @import("log_test_support.zig");

test "log evidence retains original receipt and declaration across disk reopen" {
    var directory = t.tmpDir(.{});
    defer directory.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, directory.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = 1 };
    const operation: p.DataLifecycle.Operation = .{ .scope = target.interpretation.object.scope, .principal = 0, .operation = std.math.maxInt(u64) };
    const record: E.Record = .{ .declared = declared, .outcome = .{ .append = .{
        .append = .{ .target = target, .operation = operation, .kind = .stream, .producer = .{ .id = @splat(9), .epoch = 1, .sequence = 1 }, .rows = 2, .payload = .{ .bytes = 1024, .sha256 = @splat(29) } },
        .first = std.math.maxInt(u64) - 2,
        .next = std.math.maxInt(u64),
        .accepted = .{ .partition = 91, .next_lsn = 6 },
    } } };
    const reference = try E.stage(objects.objectStore(), record);
    try t.expectEqualDeep(try E.expectedReference(record), reference);
    try t.expectEqualDeep(operation, record.operation());
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, directory.dir, "objects");
    try t.expectEqualDeep(record, try E.load(t.allocator, objects.objectStore(), reference));
    var invalid = record;
    invalid.outcome.append.append.target.partition = 2;
    try t.expectError(error.InvalidLogEvidence, E.stage(objects.objectStore(), invalid));
    invalid = record;
    invalid.outcome.append.append.kind = .queue;
    try t.expectError(error.InvalidLogEvidence, E.stage(objects.objectStore(), invalid));
    invalid = record;
    invalid.declared.retired = true;
    try t.expectError(error.InvalidLogEvidence, E.stage(objects.objectStore(), invalid));
    var buffer: [E.max_bytes]u8 = undefined;
    const encoded = try E.encode(record, &buffer);
    buffer[8] ^= 1;
    const foreign: p.DataLifecycle.Content = .{ .bytes = encoded.len, .sha256 = E.hash(encoded) };
    var name: [96]u8 = undefined;
    _ = try objects.objectStore().putImmutable(try E.key(foreign, &name), encoded, foreign.sha256);
    try t.expectError(error.IncompatibleDefinition, E.load(t.allocator, objects.objectStore(), try E.reference(foreign)));
    const original = try E.decodeReference(reference);
    try objects.objectStore().delete(try E.key(original, &name));
    try t.expectError(error.LogEvidenceMissing, E.load(t.allocator, objects.objectStore(), reference));
}

test "log evidence keys distinguish full-width operations and original principals" {
    const scope = support.definition(.stream).object.scope;
    const zero: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 0, .operation = std.math.maxInt(u64) };
    var another = zero;
    another.principal = 1;
    const first = try E.operationKey(zero);
    const second = try E.operationKey(another);
    try t.expectEqual(@as(usize, 16), first.len);
    try t.expectEqual(std.math.Order.lt, std.mem.order(u8, first.slice(), second.slice()));
    try t.expectEqual(std.math.maxInt(u64), std.mem.readInt(u64, first.data[8..16], .big));
}
