const std = @import("std");
const t = std.testing;
const SpanText = @import("SpanText.zig").SpanText;
const SpanKey = @import("SpanText.zig").SpanKey;
const Boundary = @import("SpanText.zig").Boundary;
const Operation = @import("SpanText.zig").Operation;

test "span text supports large spans interior splitting deletes and bounded sequence reads" {
    var doc = SpanText.init(t.allocator);
    defer doc.deinit();

    // Insert a >96-byte span (exceeding the legacy 96-byte scalar limit).
    const base_text =
        "Alpha-Alpha-Alpha-Alpha-Alpha-Alpha-Alpha-Alpha-Alpha-Alpha-" ++
        "Omega-Omega-Omega-Omega-Omega-Omega-Omega-Omega-Omega-Omega-";
    try t.expect(base_text.len > 96);
    const root_key: SpanKey = .{ .counter = 1, .replica = 10 };
    try t.expectEqual(.applied, try doc.apply(.{
        .insert = .{
            .span = root_key,
            .after = null,
            .utf8 = base_text,
        },
    }));
    // Duplicate apply with identical content returns `.duplicate`.
    try t.expectEqual(.duplicate, try doc.apply(.{
        .insert = .{
            .span = root_key,
            .after = null,
            .utf8 = base_text,
        },
    }));
    // Conflicting reuse of the same SpanKey fails.
    try t.expectError(error.SpanIdentityConflict, doc.apply(.{
        .insert = .{
            .span = root_key,
            .after = null,
            .utf8 = "different",
        },
    }));

    // Insert UTF-8 multibyte text inside `root_key` at byte offset 6 ("Alpha-").
    const mid_key: SpanKey = .{ .counter = 2, .replica = 20 };
    try t.expectEqual(.applied, try doc.apply(.{
        .insert = .{
            .span = mid_key,
            .after = .{ .span = root_key, .byte_offset = 6 },
            .utf8 = "[Δ-middle]",
        },
    }));

    // Delete bytes 6..12 ("Alpha-") of the original `root_key` span.
    try t.expectEqual(.applied, try doc.apply(.{
        .delete = .{
            .span = root_key,
            .start_byte = 6,
            .end_byte = 12,
        },
    }));

    const materialized = try doc.materializeAlloc(t.allocator);
    defer t.allocator.free(materialized);
    try t.expect(std.mem.startsWith(u8, materialized, "Alpha-[Δ-middle]Alpha-"));

    // Read in bounded steps (1 step at a time, 32-byte buffer) and verify exact reconstruction.
    var reconstructed: std.ArrayListUnmanaged(u8) = .empty;
    defer reconstructed.deinit(t.allocator);
    var piece_idx: usize = 0;
    var byte_in_piece: u32 = 0;
    var buf: [32]u8 = undefined;
    while (true) {
        const step = try doc.readBounded(piece_idx, byte_in_piece, 1, &buf);
        try t.expect(step.steps_taken <= 1);
        try reconstructed.appendSlice(t.allocator, buf[0..step.bytes_written]);
        piece_idx = step.next_piece;
        byte_in_piece = step.next_byte_in_piece;
        if (step.complete) break;
    }
    try t.expectEqualStrings(materialized, reconstructed.items);
}

test "span text converges across all 24 permutations of 4 concurrent operations" {
    const base_key: SpanKey = .{ .counter = 1, .replica = 1 };
    const base_op: Operation = .{
        .insert = .{
            .span = base_key,
            .after = null,
            .utf8 = "HelloWorld",
        },
    };

    const concurrent_ops = [4]Operation{
        // 0: Insert " Brave" at offset 5 (after "Hello")
        .{
            .insert = .{
                .span = .{ .counter = 2, .replica = 10 },
                .after = .{ .span = base_key, .byte_offset = 5 },
                .utf8 = " Brave",
            },
        },
        // 1: Concurrent insert " New" also at offset 5 (after "Hello") from higher replica
        .{
            .insert = .{
                .span = .{ .counter = 2, .replica = 20 },
                .after = .{ .span = base_key, .byte_offset = 5 },
                .utf8 = " New",
            },
        },
        // 2: Insert "!" at offset 10 (after "World")
        .{
            .insert = .{
                .span = .{ .counter = 3, .replica = 15 },
                .after = .{ .span = base_key, .byte_offset = 10 },
                .utf8 = "!",
            },
        },
        // 3: Delete "loWo" (bytes 3..7 of "HelloWorld")
        .{
            .delete = .{
                .span = base_key,
                .start_byte = 3,
                .end_byte = 7,
            },
        },
    };

    const permutations = [24][4]usize{
        .{ 0, 1, 2, 3 }, .{ 0, 1, 3, 2 }, .{ 0, 2, 1, 3 }, .{ 0, 2, 3, 1 }, .{ 0, 3, 1, 2 }, .{ 0, 3, 2, 1 },
        .{ 1, 0, 2, 3 }, .{ 1, 0, 3, 2 }, .{ 1, 2, 0, 3 }, .{ 1, 2, 3, 0 }, .{ 1, 3, 0, 2 }, .{ 1, 3, 2, 0 },
        .{ 2, 0, 1, 3 }, .{ 2, 0, 3, 1 }, .{ 2, 1, 0, 3 }, .{ 2, 1, 3, 0 }, .{ 2, 3, 0, 1 }, .{ 2, 3, 1, 0 },
        .{ 3, 0, 1, 2 }, .{ 3, 0, 2, 1 }, .{ 3, 1, 0, 2 }, .{ 3, 1, 2, 0 }, .{ 3, 2, 0, 1 }, .{ 3, 2, 1, 0 },
    };

    var expected: ?[]u8 = null;
    defer if (expected) |e| t.allocator.free(e);

    for (permutations) |perm| {
        var doc = SpanText.init(t.allocator);
        defer doc.deinit();
        _ = try doc.apply(base_op);
        for (perm) |idx| {
            _ = try doc.apply(concurrent_ops[idx]);
        }
        const text = try doc.materializeAlloc(t.allocator);
        if (expected == null) {
            expected = text;
            try t.expectEqualStrings("Hel New Braverld!", text);
        } else {
            defer t.allocator.free(text);
            try t.expectEqualStrings(expected.?, text);
        }
    }
}
