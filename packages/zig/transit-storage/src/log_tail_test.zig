const std = @import("std");
const t = std.testing;
const Tail = @import("LogTail.zig");

fn binding(lsn: u64, bytes: []const u8) Tail.Binding {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .position = .{ .partition = 1, .next_lsn = lsn }, .content = .{ .bytes = bytes.len, .sha256 = digest } };
}

test "log tail retains simultaneous sparse and complete views without weakening original identity checks" {
    var cache = try Tail.init(t.allocator, .{ .slots = 2, .borrow_slots = 2, .slot_bytes = 128, .resident_bytes = 4096 });
    defer cache.deinit() catch unreachable;
    const original = binding(1, "original payload");
    var sparse = original;
    sparse.view = binding(1, "view").content;
    try cache.admit(original, "original payload");
    const old = (try cache.borrow(original)).?;
    defer old.release() catch unreachable;
    try cache.admit(sparse, "view");
    const new = (try cache.borrow(sparse)).?;
    defer new.release() catch unreachable;
    try t.expectEqualStrings("original payload", try old.bytes());
    try t.expectEqualStrings("view", try new.bytes());
    var foreign = sparse;
    foreign.content = binding(1, "foreign payload").content;
    try t.expectError(error.TailContentConflict, cache.borrow(foreign));
    foreign = sparse;
    foreign.view = binding(1, "a view larger than the original payload").content;
    try t.expectError(error.InvalidTailBinding, cache.borrow(foreign));
}

test "log tail pins survive eviction pressure and copied handles cannot release new borrows" {
    var cache = try Tail.init(t.allocator, .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 64, .resident_bytes = 4096 });
    defer cache.deinit() catch unreachable;
    try cache.admit(binding(1, "first"), "first");
    const first = (try cache.borrow(binding(1, "first"))).?;
    const second = (try cache.borrow(binding(1, "first"))).?;
    try t.expectError(error.TailBorrowLimitExceeded, cache.borrow(binding(1, "first")));
    try t.expectError(error.TailCachePinned, cache.admit(binding(2, "next"), "next"));
    try t.expectError(error.OutstandingTailBorrows, cache.deinit());
    try first.release();
    const third = (try cache.borrow(binding(1, "first"))).?;
    try t.expectError(error.InvalidTailBorrow, first.release());
    try second.release();
    try t.expectError(error.TailCachePinned, cache.admit(binding(2, "next"), "next"));
    try t.expectEqualStrings("first", try third.bytes());
    try third.release();
    try cache.admit(binding(2, "next"), "next");
    try t.expect(try cache.borrow(binding(1, "first")) == null);
    try t.expectError(error.InvalidTailBorrow, third.bytes());
    const next = (try cache.borrow(binding(2, "next"))).?;
    try t.expectEqualStrings("next", try next.bytes());
    try next.release();
}

test "log tail validates admission once and reuses aligned zero-padded slabs without allocations" {
    var failing = t.FailingAllocator.init(t.allocator, .{});
    var cache = try Tail.init(failing.allocator(), .{ .slots = 2, .borrow_slots = 2, .slot_bytes = 128, .resident_bytes = 4096 });
    defer cache.deinit() catch unreachable;
    const allocations = failing.alloc_index;
    failing.fail_index = allocations;
    for (1..100) |lsn| {
        const bound = binding(lsn, "payload");
        try cache.admit(bound, "payload");
        const count = cache.verified;
        try cache.admit(bound, "payload");
        try t.expectEqual(count, cache.verified);
        const borrowed = (try cache.borrow(bound)).?;
        const bytes = try borrowed.bytes();
        try t.expectEqualStrings("payload", bytes);
        try t.expectEqual(@as(usize, 0), @intFromPtr(bytes.ptr) % 64);
        try t.expect(std.mem.allEqual(u8, bytes.ptr[bytes.len..][0..64], 0));
        try borrowed.release();
    }
    try t.expectEqual(allocations, failing.alloc_index);
}

test "log tail rejects changed identities bad digests and exhausted budgets without eviction" {
    try t.expectError(error.InvalidTailBudget, Tail.init(t.allocator, .{ .slots = 1, .borrow_slots = 1, .slot_bytes = 64, .resident_bytes = 1 }));
    var cache = try Tail.init(t.allocator, .{ .slots = 1, .borrow_slots = 1, .slot_bytes = 64, .resident_bytes = 4096 });
    defer cache.deinit() catch unreachable;
    const bound = binding(1, "first");
    try cache.admit(bound, "first");
    try t.expectError(error.TailContentConflict, cache.admit(binding(1, "other"), "other"));
    try t.expectError(error.InvalidTailContent, cache.admit(binding(2, "third"), "wrong"));
    const original = (try cache.borrow(bound)).?;
    try t.expectEqualStrings("first", try original.bytes());
    try original.release();
    cache.next_serial = std.math.maxInt(u64);
    try t.expectError(error.TailBorrowIdentityExhausted, cache.borrow(bound));
}
