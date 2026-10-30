const std = @import("std");
const t = std.testing;
const vm = @import("VersionedMerge.zig");

test "versioned three-way merge commutes preserves five-state cells and lowers to succinct tree" {
    var base_fields = [_]vm.Field{
        .{ .name = "a_unchanged", .value = .{ .kind = .{ .scalar = .{ .int64 = 10 } } } },
        .{ .name = "b_ours_only", .value = .{ .kind = .{ .scalar = .{ .string = "old" } } } },
        .{ .name = "c_theirs_only", .value = .{ .kind = .{ .scalar = .{ .boolean = false } } } },
        .{ .name = "d_conflict", .value = .{ .kind = .{ .scalar = .{ .int64 = 1 } } } },
        .{ .name = "e_null", .value = .{ .kind = .null_value } },
    };
    const base: vm.Node = .{
        .kind = .{ .object = &base_fields },
        .provenance = .{ .part_id = 1, .byte_start = 0, .byte_end = 120 },
    };

    var our_fields = [_]vm.Field{
        .{ .name = "a_unchanged", .value = .{ .kind = .{ .scalar = .{ .int64 = 10 } } } },
        .{ .name = "b_ours_only", .value = .{ .kind = .{ .scalar = .{ .string = "updated_by_ours" } } } },
        .{ .name = "c_theirs_only", .value = .{ .kind = .{ .scalar = .{ .boolean = false } } } },
        .{ .name = "d_conflict", .value = .{ .kind = .{ .scalar = .{ .int64 = 200 } } } },
        .{ .name = "e_null", .value = .{ .kind = .null_value } },
    };
    const ours: vm.Node = .{ .kind = .{ .object = &our_fields } };

    var their_fields = [_]vm.Field{
        .{ .name = "a_unchanged", .value = .{ .kind = .{ .scalar = .{ .int64 = 10 } } } },
        .{ .name = "b_ours_only", .value = .{ .kind = .{ .scalar = .{ .string = "old" } } } },
        .{ .name = "c_theirs_only", .value = .{ .kind = .{ .scalar = .{ .boolean = true } } } },
        .{ .name = "d_conflict", .value = .{ .kind = .{ .scalar = .{ .int64 = 100 } } } },
        .{ .name = "e_null", .value = .{ .kind = .null_value } },
    };
    const theirs: vm.Node = .{ .kind = .{ .object = &their_fields } };

    var arena_ab = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_ab.deinit();
    var merged_ab = try vm.mergeThreeWay(t.allocator, arena_ab.allocator(), &base, &ours, &theirs);
    defer merged_ab.deinit(t.allocator);

    var arena_ba = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_ba.deinit();
    var merged_ba = try vm.mergeThreeWay(t.allocator, arena_ba.allocator(), &base, &theirs, &ours);
    defer merged_ba.deinit(t.allocator);

    // Commutative: merge(base, ours, theirs) == merge(base, theirs, ours).
    try t.expectEqual(@as(u32, 1), merged_ab.unresolved_conflicts);
    try t.expectEqualSlices(u8, &merged_ab.state_sha256, &merged_ba.state_sha256);
    try t.expect(merged_ab.root.eql(&merged_ba.root));

    // Verify all 5 cell states via `evaluatePath`.
    const cell_val = vm.evaluatePath(&merged_ab.root, &.{"b_ours_only"});
    try t.expectEqual(vm.CellState.value, std.meta.activeTag(cell_val));
    try t.expectEqualStrings("updated_by_ours", cell_val.value.string);

    const cell_null = vm.evaluatePath(&merged_ab.root, &.{"e_null"});
    try t.expectEqual(vm.CellState.null_value, std.meta.activeTag(cell_null));

    const cell_missing = vm.evaluatePath(&merged_ab.root, &.{"nonexistent"});
    try t.expectEqual(vm.CellState.missing, std.meta.activeTag(cell_missing));

    const cell_type_err = vm.evaluatePath(&merged_ab.root, &.{ "a_unchanged", "nested" });
    try t.expectEqual(vm.CellState.type_error, std.meta.activeTag(cell_type_err));

    const cell_conflict = vm.evaluatePath(&merged_ab.root, &.{"d_conflict"});
    try t.expectEqual(vm.CellState.conflict, std.meta.activeTag(cell_conflict));
    try t.expectEqual(@as(usize, 2), cell_conflict.conflict.len);
    try t.expectEqual(@as(i64, 100), cell_conflict.conflict[0].int64);
    try t.expectEqual(@as(i64, 200), cell_conflict.conflict[1].int64);

    // Lower merged tree to `SuccinctTree` and verify node count (1 object + 5 fields = 6 nodes).
    var succinct = try vm.buildSuccinctTree(t.allocator, arena_ab.allocator(), &merged_ab.root);
    defer succinct.deinit(t.allocator);
    try t.expectEqual(@as(u32, 6), succinct.nodeCount());
    try t.expectEqual(@as(?u32, 1), try succinct.firstChild(0));
}
