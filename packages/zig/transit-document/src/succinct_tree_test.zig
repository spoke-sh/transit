const std = @import("std");
const t = std.testing;
const SuccinctTree = @import("SuccinctTree.zig").SuccinctTree;

test "succinct BP tree matches reference oracle across navigation and LCA" {
    // Tree topology (10 nodes in preorder):
    // 0 (root)
    // ├── 1
    // │   ├── 2
    // │   └── 3
    // │       └── 4
    // ├── 5
    // └── 6
    //     ├── 7
    //     ├── 8
    //     └── 9
    const parents = [_]?u32{
        null, // 0
        0, // 1
        1, // 2
        1, // 3
        3, // 4
        0, // 5
        0, // 6
        6, // 7
        6, // 8
        6, // 9
    };
    const expected_depths = [_]u32{ 0, 1, 2, 2, 3, 1, 1, 2, 2, 2 };
    const expected_subtrees = [_]u32{ 10, 4, 1, 2, 1, 1, 4, 1, 1, 1 };
    const expected_first_child = [_]?u32{ 1, 2, null, 4, null, null, 7, null, null, null };
    const expected_next_sibling = [_]?u32{ null, 5, 3, null, null, 6, null, 8, 9, null };

    var scratch_buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch_buf);
    var tree = try SuccinctTree.fromParentSlice(t.allocator, fba.allocator(), &parents);
    defer tree.deinit(t.allocator);

    try t.expectEqual(@as(u32, 10), tree.nodeCount());
    for (0..parents.len) |idx| {
        const u: u32 = @intCast(idx);
        try t.expectEqual(parents[idx], try tree.parent(u));
        try t.expectEqual(expected_depths[idx], try tree.depth(u));
        try t.expectEqual(expected_subtrees[idx], try tree.subtreeSize(u));
        try t.expectEqual(expected_first_child[idx], try tree.firstChild(u));
        try t.expectEqual(expected_next_sibling[idx], try tree.nextSibling(u));
    }

    try t.expect(try tree.isAncestor(1, 4));
    try t.expect(try tree.within(4, 1));
    try t.expect(!try tree.isAncestor(1, 6));
    try t.expectEqual(@as(u32, 1), try tree.lca(2, 4));
    try t.expectEqual(@as(u32, 0), try tree.lca(4, 8));
    try t.expectEqual(@as(u32, 6), try tree.lca(7, 9));

    // Verify encode/decode round-trip and corrupt header rejection.
    const encoded = try tree.encode(t.allocator);
    defer t.allocator.free(encoded);
    var decoded = try SuccinctTree.decode(t.allocator, encoded);
    defer decoded.deinit(t.allocator);
    try t.expectEqualSlices(u64, tree.words, decoded.words);
    try t.expectEqual(@as(u32, 1), try decoded.lca(2, 4));

    encoded[0] ^= 1;
    try t.expectError(error.InvalidSuccinctTree, SuccinctTree.decode(t.allocator, encoded));
}

test "succinct BP tree scales across multi-block trees and rejects invalid parent arrays" {
    const count: usize = 300;
    const parents = try t.allocator.alloc(?u32, count);
    defer t.allocator.free(parents);
    parents[0] = null;
    for (1..count) |i| {
        parents[i] = @intCast((i - 1) / 3);
    }
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();

    // Build preorder order from the heap-shaped tree using `VersionedMerge` or a DFS walk.
    var preorder_parents = try t.allocator.alloc(?u32, count);
    defer t.allocator.free(preorder_parents);
    preorder_parents[0] = null;
    for (1..count) |i| {
        // Chain with occasional branches so preorder invariant `parent < i` holds.
        preorder_parents[i] = if (i % 5 == 0) @intCast(i - 5) else @intCast(i - 1);
    }

    var tree = try SuccinctTree.fromParentSlice(t.allocator, arena.allocator(), preorder_parents);
    defer tree.deinit(t.allocator);

    try t.expectEqual(@as(u32, @intCast(count)), tree.nodeCount());
    for (0..count) |i| {
        const u: u32 = @intCast(i);
        try t.expectEqual(preorder_parents[i], try tree.parent(u));
    }

    // Invalid parent (`parents[1] = 2 >= 1`) must fail.
    const bad = [_]?u32{ null, 2, 0 };
    try t.expectError(error.InvalidSuccinctTree, SuccinctTree.fromParentSlice(t.allocator, arena.allocator(), &bad));
}
