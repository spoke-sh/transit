const std = @import("std");
const t = std.testing;
const TDel = @import("TDel.zig");
const Vector = TDel.DeletionVector;

fn resign(bytes: []u8) void {
    std.crypto.hash.sha2.Sha256.hash(bytes[0 .. bytes.len - 32], bytes[bytes.len - 32 ..][0..32], .{});
}

test "Roaring tdel sparse u32 domain stays bounded with no mutation allocations" {
    var failing = t.FailingAllocator.init(t.allocator, .{});
    var vector = try Vector.initBounded(failing.allocator(), 1, std.math.maxInt(u32), 4096);
    defer vector.deinit();
    const allocations = failing.alloc_index;
    failing.fail_index = allocations;
    const offsets = [_]u32{ 65536, 3, 0xfffffffe, 131074, 65535, 65537 };
    for (offsets) |offset| try t.expect(try vector.markDeleted(offset));
    for (offsets) |offset| {
        try t.expect(vector.isDeleted(offset));
        try t.expect(!try vector.markDeleted(offset));
    }
    try t.expect(!vector.isDeleted(0xffffffff));
    try t.expectError(error.RowOffsetOutOfBounds, vector.markDeleted(0xffffffff));
    var buffer: [4096]u8 = undefined;
    const bytes = try vector.encode(&buffer);
    try t.expect(bytes.len < 256);
    try t.expectEqual(allocations, failing.alloc_index);
    var decoded = try Vector.decode(t.allocator, bytes);
    defer decoded.deinit();
    for (offsets) |offset| try t.expect(decoded.isDeleted(offset));
    try t.expectEqual(@as(u32, offsets.len), decoded.deleted_count);
}

test "Roaring tdel independently spelled container and canonical roundtrip" {
    var vector = try Vector.init(t.allocator, 9, 0x20000);
    defer vector.deinit();
    _ = try vector.markDeleted(0x10007);
    var buffer: [256]u8 = undefined;
    const bytes = try vector.encode(&buffer);
    // high prefix 1, 14-byte RBC1 array, cardinality 1, low offset 7.
    const expected = [_]u8{ 1, 0, 14, 0, 'R', 'B', 'C', '1', 1, 0, 0, 0, 1, 0, 0, 0, 7, 0 };
    try t.expectEqualSlices(u8, &expected, bytes[TDel.header_bytes .. bytes.len - 32]);
    var decoded = try Vector.decode(t.allocator, bytes);
    defer decoded.deinit();
    var other: [256]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try decoded.encode(&other));
}

test "Roaring tdel capacity refusal and union are atomic" {
    var vector = try Vector.initBounded(t.allocator, 1, 200000, TDel.header_bytes + 32 + 18);
    defer vector.deinit();
    _ = try vector.markDeleted(1);
    try t.expectError(error.DeletionVectorCapacityExceeded, vector.markDeleted(65536));
    var other = try Vector.init(t.allocator, 1, 200000);
    defer other.deinit();
    _ = try other.markDeleted(2);
    _ = try other.markDeleted(65536);
    try t.expectError(error.DeletionVectorCapacityExceeded, vector.unionWith(&other));
    try t.expectEqual(@as(u32, 1), vector.deleted_count);
    try t.expect(vector.isDeleted(1));
    try t.expect(!vector.isDeleted(2));
    try t.expect(!vector.isDeleted(65536));
    try other.unionWith(&vector);
    try t.expectEqual(@as(u32, 3), other.deleted_count);
    try other.unionWith(&other);
    try t.expectEqual(@as(u32, 3), other.deleted_count);
}

test "Roaring tdel rejects corrupt containers counts ranges and definitions before allocation" {
    var vector = try Vector.init(t.allocator, 1, 70000);
    defer vector.deinit();
    _ = try vector.markDeleted(65536);
    var buffer: [256]u8 = undefined;
    const canonical = try vector.encode(&buffer);
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var mutated: [256]u8 = undefined;
    const edits = [_]struct { at: usize, value: u8, err: anyerror }{
        .{ .at = 5, .value = buffer[5] ^ 1, .err = error.IncompatibleDefinition },
        .{ .at = 49, .value = 2, .err = error.InvalidDeletionVector },
        .{ .at = 53, .value = 2, .err = error.InvalidDeletionVector },
        .{ .at = TDel.header_bytes, .value = 2, .err = error.InvalidDeletionVector },
        .{ .at = TDel.header_bytes + 9, .value = 1, .err = error.InvalidBitmapEncoding },
        .{ .at = TDel.header_bytes + 17, .value = 255, .err = error.InvalidDeletionVector },
    };
    for (edits) |edit| {
        const bytes = mutated[0..canonical.len];
        @memcpy(bytes, canonical);
        bytes[edit.at] = edit.value;
        resign(bytes);
        try t.expectError(edit.err, Vector.decode(failing.allocator(), bytes));
    }
    @memcpy(mutated[0..canonical.len], canonical);
    mutated[canonical.len - 1] ^= 1;
    try t.expectError(error.CorruptDeletionVector, Vector.decode(failing.allocator(), mutated[0..canonical.len]));
    try t.expectEqual(@as(usize, 0), failing.alloc_index);
}

test "Roaring tdel dense runs encode compactly and union without new allocation" {
    var failing = t.FailingAllocator.init(t.allocator, .{});
    var left = try Vector.init(failing.allocator(), 1, 1000);
    defer left.deinit();
    var right = try Vector.init(t.allocator, 1, 1000);
    defer right.deinit();
    for (0..500) |offset| _ = try left.markDeleted(@intCast(offset * 2));
    for (0..500) |offset| _ = try right.markDeleted(@intCast(offset * 2 + 1));
    const allocations = failing.alloc_index;
    failing.fail_index = allocations;
    try left.unionWith(&right);
    var buffer: [256]u8 = undefined;
    const bytes = try left.encode(&buffer);
    try t.expectEqual(@as(usize, TDel.header_bytes + 24 + 32), bytes.len);
    try t.expectEqual(@as(u8, 3), bytes[TDel.header_bytes + 8]);
    try t.expectEqual(@as(u32, 1000), left.deleted_count);
    for (0..1000) |offset| try t.expect(left.isDeleted(@intCast(offset)));
    try t.expectEqual(allocations, failing.alloc_index);
}
