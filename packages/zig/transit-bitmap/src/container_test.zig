const std = @import("std");
const b = @import("root.zig");
const t = std.testing;

test "Roaring sparse array and contiguous run have independent canonical bytes" {
    var scratch: b.Container = .{};
    var output: [b.max_encoded_bytes]u8 = undefined;
    for ([_]u16{ 1, 1024, 65535 }) |value| try t.expect(scratch.set(value));
    const sparse = try scratch.encode(&output);
    try t.expectEqualSlices(u8, &.{ 'R', 'B', 'C', '1', 1, 0, 0, 0, 3, 0, 0, 0, 1, 0, 0, 4, 255, 255 }, sparse);
    const view = try b.View.parse(sparse);
    try t.expect(view.contains(65535));
    try t.expect(!view.contains(65534));
    scratch.clear();
    for (100..200) |value| _ = scratch.set(@intCast(value));
    const run = try scratch.encode(&output);
    try t.expectEqualSlices(u8, &.{ 'R', 'B', 'C', '1', 3, 0, 0, 0, 100, 0, 0, 0, 1, 0, 0, 0, 100, 0, 99, 0 }, run);
    const r = try b.View.parse(run);
    try t.expectEqual(b.Kind.run, r.kind);
    var it = r.iterator();
    for (100..200) |value| try t.expectEqual(@as(?u16, @intCast(value)), it.next());
    try t.expectEqual(@as(?u16, null), it.next());
    try t.expectEqual(@as(?u16, null), it.next());
}

test "Roaring dense noncontiguous bitmap and full run preserve the upper boundary" {
    var scratch: b.Container = .{};
    var output: [b.max_encoded_bytes]u8 = undefined;
    for (0..b.values_per_container) |value| if (value % 2 == 0) {
        _ = scratch.set(@intCast(value));
    };
    const bytes = try scratch.encode(&output);
    const view = try b.View.parse(bytes);
    try t.expectEqual(b.Kind.bitmap, view.kind);
    try t.expectEqual(@as(usize, b.max_encoded_bytes), bytes.len);
    for (bytes[b.header_bytes..]) |byte| try t.expectEqual(@as(u8, 0x55), byte);
    var it = view.iterator();
    for (0..b.values_per_container / 2) |i| try t.expectEqual(@as(?u16, @intCast(i * 2)), it.next());
    try t.expectEqual(@as(?u16, null), it.next());
    for (0..b.values_per_container) |value| _ = scratch.set(@intCast(value));
    const full = try b.View.parse(try scratch.encode(&output));
    try t.expectEqual(b.Kind.run, full.kind);
    try t.expectEqual(@as(u32, 65536), full.cardinality);
    try t.expect(full.contains(65535));
    it = full.iterator();
    for (0..b.values_per_container) |value| try t.expectEqual(@as(?u16, @intCast(value)), it.next());
    try t.expectEqual(@as(?u16, null), it.next());
}

test "Roaring union intersection and scratch reuse match independent membership" {
    var left: b.Container = .{};
    var right: b.Container = .{};
    var joined: b.Container = .{};
    var output: [b.max_encoded_bytes]u8 = undefined;
    for (0..b.values_per_container) |i| {
        if (i % 7 == 0) _ = left.set(@intCast(i));
        if (i % 11 == 0) _ = right.set(@intCast(i));
    }
    joined = left;
    joined.unionWith(&right);
    var count: u32 = 0;
    for (0..b.values_per_container) |i| {
        const expected = i % 7 == 0 or i % 11 == 0;
        try t.expectEqual(expected, joined.contains(@intCast(i)));
        count += @intFromBool(expected);
    }
    try t.expectEqual(count, joined.cardinality);
    joined.intersectWith(&right);
    try t.expectEqual(right.cardinality, joined.cardinality);
    try t.expectEqualSlices(u64, &right.words, &joined.words);
    joined = left;
    joined.intersectWith(&right);
    const view = try b.View.parse(try joined.encode(&output));
    for (0..b.values_per_container) |i| try t.expectEqual(i % 77 == 0, view.contains(@intCast(i)));
    left.clear();
    try left.decode(view.bytes);
    try t.expectEqualSlices(u64, &joined.words, &left.words);
    left.unionWith(&left);
    left.intersectWith(&left);
    try t.expectEqual(joined.cardinality, left.cardinality);
    for (0..b.values_per_container) |i| {
        const value: u16 = @intCast(i);
        try t.expectEqual(i % 77 == 0, left.unset(value));
        try t.expect(!left.unset(value));
    }
    try t.expectEqual(@as(u32, 0), left.cardinality);
    try t.expectEqual(b.Kind.array, (try b.View.parse(try left.encode(&output))).kind);
}

test "Roaring malformed bytes never mutate the caller container" {
    var scratch: b.Container = .{};
    _ = scratch.set(10);
    _ = scratch.set(1000);
    var output: [b.max_encoded_bytes]u8 = undefined;
    const encoded = try scratch.encode(&output);
    for (0..encoded.len) |len| {
        try t.expectError(error.InvalidBitmapEncoding, scratch.decode(encoded[0..len]));
        try t.expectEqual(@as(u32, 2), scratch.cardinality);
    }
    output[5] = 1;
    try t.expectError(error.InvalidBitmapEncoding, b.View.parse(encoded));
    output[5] = 0;
    output[8] = 3;
    try t.expectError(error.InvalidBitmapEncoding, b.View.parse(encoded));
    output[8] = 2;
    output[14] = 10;
    output[15] = 0;
    try t.expectError(error.InvalidBitmapEncoding, b.View.parse(encoded));
    // Valid but noncanonical bitmap for the empty set must not decode.
    @memset(&output, 0);
    @memcpy(output[0..4], "RBC1");
    output[4] = 2;
    try t.expectError(error.NonCanonicalBitmap, scratch.decode(&output));
    try t.expect(scratch.contains(10));
    try t.expect(scratch.contains(1000));
    var tiny: [1]u8 = .{42};
    try t.expectError(error.BitmapOutputTooSmall, scratch.encode(&tiny));
    try t.expectEqual(@as(u8, 42), tiny[0]);
}

test "Roaring rejects overflowing adjacent and overlapping run records" {
    var bytes = [_]u8{ 'R', 'B', 'C', '1', 3, 0, 0, 0, 40, 0, 0, 0, 2, 0, 0, 0, 0, 0, 19, 0, 100, 0, 19, 0 };
    _ = try b.View.parse(&bytes);
    bytes[20] = 20;
    try t.expectError(error.InvalidBitmapEncoding, b.View.parse(&bytes));
    bytes[20] = 19;
    try t.expectError(error.InvalidBitmapEncoding, b.View.parse(&bytes));
    bytes[20] = 255;
    bytes[21] = 255;
    try t.expectError(error.InvalidBitmapEncoding, b.View.parse(&bytes));
}

test "Roaring rejects input and output aliasing mutable scratch before changing it" {
    var scratch: b.Container = .{};
    _ = scratch.set(42);
    const before = scratch.words;
    const alias = std.mem.asBytes(&scratch.words);
    try t.expectError(error.BitmapBufferAlias, scratch.encode(alias));
    try t.expectError(error.BitmapBufferAlias, scratch.decode(alias));
    try t.expectEqualSlices(u64, &before, &scratch.words);
    try t.expectEqual(@as(u32, 1), scratch.cardinality);
}

test "Roaring deterministic mutation corpus roundtrips without allocator access" {
    var scratch: b.Container = .{};
    var recovered: b.Container = .{};
    var expected: [b.values_per_container]bool = @splat(false);
    var output: [b.max_encoded_bytes]u8 = undefined;
    var random: u64 = 0x123456789abcdef;
    for (0..100_000) |step| {
        random = random *% 6364136223846793005 +% 1442695040888963407;
        const value: u16 = @truncate(random >> 32);
        if (random & 1 == 0) {
            try t.expectEqual(!expected[value], scratch.set(value));
            expected[value] = true;
        } else {
            try t.expectEqual(expected[value], scratch.unset(value));
            expected[value] = false;
        }
        if (step % 1000 == 0) {
            const encoded = try scratch.encode(&output);
            try recovered.decode(encoded);
            const view = try b.View.parse(encoded);
            var count: u32 = 0;
            for (expected, 0..) |present, i| {
                try t.expectEqual(present, recovered.contains(@intCast(i)));
                try t.expectEqual(present, view.contains(@intCast(i)));
                count += @intFromBool(present);
            }
            try t.expectEqual(count, view.cardinality);
        }
    }
}
