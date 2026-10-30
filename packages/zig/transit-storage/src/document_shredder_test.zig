const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const doc_lib = @import("transit_document");
const vm = doc_lib.VersionedMerge;

test "document shredder builds five-state subcolumns zone maps and matches unshredded oracle" {
    var conflict_items = [_]vm.Scalar{
        .{ .int64 = 10 },
        .{ .int64 = 20 },
    };

    var row0_meta = [_]vm.Field{
        .{ .name = "author", .value = .{ .kind = .{ .scalar = .{ .string = "alice" } } } },
    };
    var row0_fields = [_]vm.Field{
        .{ .name = "meta", .value = .{ .kind = .{ .object = &row0_meta } } },
        .{ .name = "rare_note", .value = .{ .kind = .{ .scalar = .{ .string = "only-in-row-0" } } } },
        .{ .name = "severity", .value = .{ .kind = .{ .scalar = .{ .int64 = 5 } } } },
    };

    var row1_meta = [_]vm.Field{
        .{ .name = "author", .value = .{ .kind = .{ .scalar = .{ .string = "BOB" } } } },
    };
    var row1_fields = [_]vm.Field{
        .{ .name = "meta", .value = .{ .kind = .{ .object = &row1_meta } } },
        .{ .name = "severity", .value = .{ .kind = .null_value } },
    };

    var row2_fields = [_]vm.Field{
        .{ .name = "severity", .value = .{ .kind = .{ .conflict = &conflict_items } } },
    };

    const docs = [_]vm.Node{
        .{ .kind = .{ .object = &row0_fields } },
        .{ .kind = .{ .object = &row1_fields } },
        .{ .kind = .{ .object = &row2_fields } },
    };

    const declared = [_][]const []const u8{
        &.{"severity"},
    };

    var scratch_arena = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch_arena.deinit();

    var batch = try s.DocumentShredder.shredBatch(
        t.allocator,
        scratch_arena.allocator(),
        .{
            .frequent_path_threshold = 2,
            .max_shredded_columns = 8,
            .default_collation = .ascii_ci,
        },
        &declared,
        &docs,
    );
    defer batch.deinit(t.allocator);

    // `severity` (declared) and `meta.author` (frequency 2 >= threshold 2) are shredded;
    // `rare_note` (frequency 1 < 2) stays in the residual tree!
    try t.expectEqual(@as(usize, 2), batch.subcolumns.len);
    const author_col = batch.findSubcolumn("meta.author").?;
    const sev_col = batch.findSubcolumn("severity").?;
    try t.expect(batch.findSubcolumn("rare_note") == null);

    // Check zone map and bitmaps on `severity` and `meta.author`.
    try t.expectEqual(@as(u32, 1), sev_col.zone_map.value_count);
    try t.expectEqual(@as(u32, 1), sev_col.zone_map.null_count);
    try t.expectEqual(@as(u32, 1), sev_col.zone_map.conflict_count);
    try t.expect(sev_col.zone_map.mayContainInt64(5));
    try t.expect(!sev_col.zone_map.mayContainInt64(6));

    const present_view = try sev_col.presentView();
    try t.expect(present_view.contains(0));
    try t.expect(!present_view.contains(1));
    const null_view = try sev_col.nullView();
    try t.expect(null_view.contains(1));
    const conflict_view = try sev_col.conflictView();
    try t.expect(conflict_view.contains(2));

    // Under `ascii_ci`, "alice" <= "BOB", and "bob" is matched by zone map!
    try t.expect(author_col.zone_map.mayContainString(.ascii_ci, "bob"));
    try t.expect(author_col.zone_map.mayContainString(.ascii_ci, "ALICE"));
    try t.expect(!author_col.zone_map.mayContainString(.ascii_ci, "charlie"));

    // Differential equivalence between shredded evaluation and unshredded tree traversal
    // across all rows and paths (including unshredded `rare_note` and missing paths).
    const test_paths = [_][]const []const u8{
        &.{"severity"},
        &.{ "meta", "author" },
        &.{"rare_note"},
        &.{"missing_field"},
    };
    for (&docs, 0..) |*doc, row_idx| {
        for (test_paths) |path| {
            const shredded_cell = try batch.evaluatePath(scratch_arena.allocator(), row_idx, doc, path);
            const oracle_cell = vm.evaluatePath(doc, path);
            try t.expectEqual(std.meta.activeTag(oracle_cell), std.meta.activeTag(shredded_cell));
            if (oracle_cell == .value) {
                try t.expect(oracle_cell.value.eql(shredded_cell.value));
            }
        }
    }
}
