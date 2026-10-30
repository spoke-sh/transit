const std = @import("std");
const f = @import("root.zig");
const s = f.TableSchema;
const t = f.Types;
const v = t.Values;
const BranchDiff = f.BranchDiff;
const TableConstraints = f.TableConstraints;
const TableSchemaProjection = f.TableSchemaProjection;

test "A4 segment-skipping algebra skips identical (.tseg, .tdel) pairs, compaction rewrites, and out-of-viewport 2D/3D spatial segments in O(1)" {
    const seg_shared: BranchDiff.SegmentDigestInfo = .{
        .segment_id = 1,
        .segment_sha256 = @splat(0x11),
        .tdel_sha256 = @splat(0x00),
        .logical_row_multiset_hash = @splat(0xAA),
        .row_count = 1000,
        .spatial = .{
            .bbox2d = .{ .min_x = 0.0, .min_y = 0.0, .max_x = 10.0, .max_y = 10.0 },
            .bbox3d = .{ .min_x = 0.0, .min_y = 0.0, .min_z = 0.0, .max_x = 10.0, .max_y = 10.0, .max_z = 10.0 },
            .s2_hilbert_min = 100,
            .s2_hilbert_max = 200,
            .oct_cell_min = 1000,
            .oct_cell_max = 2000,
        },
    };
    const seg_uncompacted_a: BranchDiff.SegmentDigestInfo = .{
        .segment_id = 2,
        .segment_sha256 = @splat(0x22),
        .tdel_sha256 = @splat(0x01),
        .logical_row_multiset_hash = @splat(0xBB),
        .row_count = 500,
        .spatial = .{
            .bbox2d = .{ .min_x = 0.0, .min_y = 0.0, .max_x = 10.0, .max_y = 10.0 },
        },
    };
    const seg_uncompacted_b: BranchDiff.SegmentDigestInfo = .{
        .segment_id = 3,
        .segment_sha256 = @splat(0x33),
        .tdel_sha256 = @splat(0x02),
        .logical_row_multiset_hash = @splat(0xBB),
        .row_count = 500,
        .spatial = .{
            .bbox2d = .{ .min_x = 0.0, .min_y = 0.0, .max_x = 10.0, .max_y = 10.0 },
        },
    };
    // Target branch compacted {seg 2, seg 3} -> seg 4 without mutating logical rows
    const seg_compacted: BranchDiff.SegmentDigestInfo = .{
        .segment_id = 4,
        .segment_sha256 = @splat(0x44),
        .tdel_sha256 = @splat(0x00),
        .logical_row_multiset_hash = @splat(0xBB),
        .row_count = 1000,
        .spatial = .{
            .bbox2d = .{ .min_x = 0.0, .min_y = 0.0, .max_x = 10.0, .max_y = 10.0 },
        },
    };
    // Out-of-viewport segment far away in 2D/3D space
    const seg_out_of_viewport: BranchDiff.SegmentDigestInfo = .{
        .segment_id = 5,
        .segment_sha256 = @splat(0x55),
        .tdel_sha256 = @splat(0x00),
        .logical_row_multiset_hash = @splat(0xCC),
        .row_count = 250,
        .spatial = .{
            .bbox2d = .{ .min_x = 500.0, .min_y = 500.0, .max_x = 600.0, .max_y = 600.0 },
            .bbox3d = .{ .min_x = 500.0, .min_y = 500.0, .min_z = 500.0, .max_x = 600.0, .max_y = 600.0, .max_z = 600.0 },
            .s2_hilbert_min = 9000,
            .s2_hilbert_max = 9500,
        },
    };
    // Genuinely added delta segment on source branch
    const seg_delta_source: BranchDiff.SegmentDigestInfo = .{
        .segment_id = 6,
        .segment_sha256 = @splat(0x66),
        .tdel_sha256 = @splat(0x00),
        .logical_row_multiset_hash = @splat(0xDD),
        .row_count = 50,
        .spatial = .{
            .bbox2d = .{ .min_x = 2.0, .min_y = 2.0, .max_x = 8.0, .max_y = 8.0 },
            .bbox3d = .{ .min_x = 2.0, .min_y = 2.0, .min_z = 2.0, .max_x = 8.0, .max_y = 8.0, .max_z = 8.0 },
            .s2_hilbert_min = 120,
            .s2_hilbert_max = 180,
        },
    };

    const comp_inputs = [_][32]u8{ seg_uncompacted_a.segment_sha256, seg_uncompacted_b.segment_sha256 };
    const comp_tdels = [_][32]u8{ seg_uncompacted_a.tdel_sha256, seg_uncompacted_b.tdel_sha256 };
    const edges = [_]BranchDiff.CompactionLineageEdge{
        .{
            .input_segment_sha256s = &comp_inputs,
            .input_tdel_sha256s = &comp_tdels,
            .output_segment_sha256 = seg_compacted.segment_sha256,
            .output_tdel_sha256 = seg_compacted.tdel_sha256,
            .logical_row_multiset_hash = @splat(0xBB),
        },
    };

    const base_segs = [_]BranchDiff.SegmentDigestInfo{ seg_shared, seg_uncompacted_a, seg_uncompacted_b, seg_out_of_viewport };
    const source_segs = [_]BranchDiff.SegmentDigestInfo{ seg_shared, seg_uncompacted_a, seg_uncompacted_b, seg_out_of_viewport, seg_delta_source };
    const target_segs = [_]BranchDiff.SegmentDigestInfo{ seg_shared, seg_compacted, seg_out_of_viewport };

    const viewport: BranchDiff.SpatialViewportFilter = .{
        .bbox2d = .{ .min_x = 0.0, .min_y = 0.0, .max_x = 20.0, .max_y = 20.0 },
        .s2_range = .{ .min_cell = 50, .max_cell = 300 },
    };

    const summary = try BranchDiff.planThreeWaySegmentDiff(&base_segs, &source_segs, &target_segs, &edges, viewport);
    try std.testing.expectEqual(@as(u32, 1), summary.identical_skipped_segments);
    try std.testing.expectEqual(@as(u32, 2), summary.compaction_equivalent_skipped_segments);
    try std.testing.expectEqual(@as(u32, 1), summary.spatial_viewport_skipped_segments);
    try std.testing.expectEqual(@as(u32, 0), summary.active_base_segments);
    try std.testing.expectEqual(@as(u32, 1), summary.active_source_segments);
    try std.testing.expectEqual(@as(u32, 0), summary.active_target_segments);
}

test "two-way and three-way relational DIFF aligns keys under declared collations, projects ColumnId evolutions, and emits 5-state IS CONFLICT cells" {
    const base_cols = [_]s.Column{
        .{ .id = 1, .name = "code", .type = .{ .utf8 = {} }, .nullable = false, .collation = .ebcdic_cp037 },
        .{ .id = 2, .name = "price", .type = .{ .int64 = {} }, .nullable = false },
    };
    const pk = [_]s.ColumnId{1};
    const base_schema: s.Schema = .{
        .object = 10,
        .revision = 1,
        .next_column = 3,
        .columns = &base_cols,
        .primary_key = &pk,
    };

    // Evolved target schema adds column 3 (`region` DEFAULT 'EU-WEST') and renames `price` -> `unit_price` (ColumnId 2)
    const evolved_cols = [_]s.Column{
        .{ .id = 1, .name = "code", .type = .{ .utf8 = {} }, .nullable = false, .collation = .ebcdic_cp037 },
        .{ .id = 2, .name = "unit_price", .type = .{ .int64 = {} }, .nullable = false },
        .{
            .id = 3,
            .name = "region",
            .type = .{ .utf8 = {} },
            .nullable = false,
            .default = .{ .value = .{ .atom = .{ .bytes = "EU-WEST" } } },
        },
    };
    const evolved_schema: s.Schema = .{
        .object = 10,
        .revision = 2,
        .next_column = 4,
        .columns = &evolved_cols,
        .primary_key = &pk,
    };
    const origins = [_]TableSchemaProjection.Initial{
        .{ .column = 3, .value = .{ .value = .{ .atom = .{ .bytes = "EU-WEST" } } } },
    };
    const profiles = [_]BranchDiff.CollationProfileBinding{
        .{ .column = 1, .profile = .ebcdic_037_pad },
    };

    // Base rows:
    // - "A1  " -> price 100
    // - "B2  " -> price 200
    // - "C3  " -> price 300
    const b_r1 = [_]v.Cell{ .{ .value = .{ .atom = .{ .bytes = "A1  " } } }, .{ .value = .{ .atom = .{ .signed = 100 } } } };
    const b_r2 = [_]v.Cell{ .{ .value = .{ .atom = .{ .bytes = "B2  " } } }, .{ .value = .{ .atom = .{ .signed = 200 } } } };
    const b_r3 = [_]v.Cell{ .{ .value = .{ .atom = .{ .bytes = "C3  " } } }, .{ .value = .{ .atom = .{ .signed = 300 } } } };
    const base_rows = [_]BranchDiff.RowEntry{
        .{ .cells = &b_r1 },
        .{ .cells = &b_r2 },
        .{ .cells = &b_r3 },
    };
    const base_snap: BranchDiff.BranchTableSnapshot = .{
        .branch_id = 1,
        .commit_lsn = 10,
        .schema = base_schema,
        .collation_profiles = &profiles,
        .rows = &base_rows,
    };

    // Source branch (branch_id 2, lsn 20):
    // - "A1" (matches "A1  " under ebcdic_037_pad!) updated to price 150 (conflict with target's 180)
    // - "B2  " updated to price 250 (clean change on source only)
    // - "C3  " deleted on source (conflict with target modifying "C3  " to 350!)
    // - "D4" added on source with price 400
    const s_r1 = [_]v.Cell{ .{ .value = .{ .atom = .{ .bytes = "A1" } } }, .{ .value = .{ .atom = .{ .signed = 150 } } } };
    const s_r2 = [_]v.Cell{ .{ .value = .{ .atom = .{ .bytes = "B2  " } } }, .{ .value = .{ .atom = .{ .signed = 250 } } } };
    const s_r4 = [_]v.Cell{ .{ .value = .{ .atom = .{ .bytes = "D4" } } }, .{ .value = .{ .atom = .{ .signed = 400 } } } };
    const source_rows = [_]BranchDiff.RowEntry{
        .{ .cells = &s_r1 },
        .{ .cells = &s_r2 },
        .{ .cells = &s_r4 },
    };
    const source_snap: BranchDiff.BranchTableSnapshot = .{
        .branch_id = 2,
        .commit_lsn = 20,
        .schema = base_schema,
        .collation_profiles = &profiles,
        .rows = &source_rows,
    };

    // Target branch (branch_id 1, lsn 30, evolved_schema):
    // - "A1  " updated to unit_price 180, region 'EU-WEST'
    // - "B2  " unchanged at unit_price 200, region 'EU-WEST'
    // - "C3  " updated to unit_price 350, region 'US-EAST'
    const t_r1 = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "A1  " } } },
        .{ .value = .{ .atom = .{ .signed = 180 } } },
        .{ .value = .{ .atom = .{ .bytes = "EU-WEST" } } },
    };
    const t_r2 = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "B2  " } } },
        .{ .value = .{ .atom = .{ .signed = 200 } } },
        .{ .value = .{ .atom = .{ .bytes = "EU-WEST" } } },
    };
    const t_r3 = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "C3  " } } },
        .{ .value = .{ .atom = .{ .signed = 350 } } },
        .{ .value = .{ .atom = .{ .bytes = "US-EAST" } } },
    };
    const target_rows = [_]BranchDiff.RowEntry{
        .{ .cells = &t_r1 },
        .{ .cells = &t_r2 },
        .{ .cells = &t_r3 },
    };
    const target_snap: BranchDiff.BranchTableSnapshot = .{
        .branch_id = 1,
        .commit_lsn = 30,
        .schema = evolved_schema,
        .collation_profiles = &profiles,
        .column_origins = &origins,
        .rows = &target_rows,
    };

    var diff_out: [8]BranchDiff.DiffRowResult = undefined;
    const diff_count = try BranchDiff.computeThreeWayRowDiff(base_snap, source_snap, target_snap, &diff_out);
    try std.testing.expectEqual(@as(usize, 4), diff_count);

    // Row 0 ("A1  "): conflicting price edit (150 vs 180) -> _diff_op = 'conflict', column 1 IS CONFLICT
    try std.testing.expectEqual(BranchDiff.DiffOp.conflict, diff_out[0].op);
    try std.testing.expect(!diff_out[0].isColumnConflict(0));
    try std.testing.expect(diff_out[0].isColumnConflict(1));
    try std.testing.expectEqual(t.State.conflict, std.meta.activeTag(diff_out[0].cells[1]));
    try diff_out[0].cells[1].validate(evolved_schema.columns[1].field(), .{});

    // Five-state CHECK constraint evaluation rejects the conflicted row with `.conflict_cell`
    const chk_atoms = [_]TableConstraints.CheckAtom{
        .{ .compare_literal = .{ .column = 2, .op = .gt, .literal = .{ .signed = 0 } } },
    };
    const chk: TableConstraints.CheckConstraint = .{
        .id = 1,
        .name = "chk_positive_price",
        .atoms = &chk_atoms,
    };
    var violation: TableConstraints.CheckViolation = undefined;
    try std.testing.expectError(
        error.CheckConstraintViolation,
        TableConstraints.evaluateCheckRow(evolved_schema, chk, diff_out[0].cells[0..3], &violation),
    );
    try std.testing.expectEqual(TableConstraints.CheckViolationReason.conflict_cell, violation.reason);

    // Row 1 ("B2  "): clean modification on source (250) projected with lazy default 'EU-WEST'
    try std.testing.expectEqual(BranchDiff.DiffOp.modified, diff_out[1].op);
    try std.testing.expectEqual(@as(i128, 250), diff_out[1].cells[1].value.atom.signed);
    try std.testing.expectEqualStrings("EU-WEST", diff_out[1].cells[2].value.atom.bytes);

    // Row 2 ("C3  "): deleted on source while modified on target -> delete_modify_conflict!
    try std.testing.expectEqual(BranchDiff.DiffOp.conflict, diff_out[2].op);
    try std.testing.expect(diff_out[2].delete_modify_conflict);
    try std.testing.expect(diff_out[2].isColumnConflict(1));

    // Row 3 ("D4"): added on source, projected with lazy default 'EU-WEST'
    try std.testing.expectEqual(BranchDiff.DiffOp.added, diff_out[3].op);
    try std.testing.expectEqual(@as(i128, 400), diff_out[3].cells[1].value.atom.signed);
    try std.testing.expectEqualStrings("EU-WEST", diff_out[3].cells[2].value.atom.bytes);
}

test "2D/3D topological (.topo_arc/.topo_face) and SCENE3D volumetric clash edits promote to 5-state IS CONFLICT cells" {
    var topo_alts: [2]v.Alternative = undefined;
    const topo_cell = try BranchDiff.evaluateTopologicalEditConflict(.{
        .primitive_id = 42,
        .base_wkb_digest = @splat(0x01),
        .source_wkb_digest = @splat(0x02),
        .target_wkb_digest = @splat(0x03),
        .source_lsn = 15,
        .source_branch_id = 2,
        .target_lsn = 18,
        .target_branch_id = 1,
        .preserves_manifold_closure = false,
    }, &topo_alts);
    try std.testing.expectEqual(t.State.conflict, std.meta.activeTag(topo_cell));

    var clash_alts: [2]v.Alternative = undefined;
    const clash_cell = try BranchDiff.evaluateScene3DClashConflict(.{
        .assembly_node_id = 99,
        .source_bbox3d = .{ .min_x = 0.0, .min_y = 0.0, .min_z = 0.0, .max_x = 2.0, .max_y = 2.0, .max_z = 2.0 },
        .target_bbox3d = .{ .min_x = 2.1, .min_y = 0.0, .min_z = 0.0, .max_x = 4.0, .max_y = 2.0, .max_z = 2.0 },
        .required_clearance = 0.5, // distance is 0.1 < 0.5 -> hard volumetric clearance clash!
        .source_lsn = 21,
        .source_branch_id = 2,
        .target_lsn = 25,
        .target_branch_id = 1,
        .source_transform_bytes = "tx_src",
        .target_transform_bytes = "tx_tgt",
    }, &clash_alts);
    try std.testing.expectEqual(t.State.conflict, std.meta.activeTag(clash_cell));
}

test "DIFF_SCHEMA distinguishes ColumnId-preserving renames and lazy additions from drop-and-recreate" {
    const pk = [_]s.ColumnId{1};
    const s1_cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "legacy_code", .type = .{ .utf8 = {} }, .nullable = false },
        .{ .id = 3, .name = "obsolete", .type = .{ .int64 = {} }, .nullable = true },
    };
    const s1: s.Schema = .{
        .object = 10,
        .revision = 1,
        .next_column = 4,
        .columns = &s1_cols,
        .primary_key = &pk,
    };

    const s2_cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "code", .type = .{ .utf8 = {} }, .nullable = false },
        .{
            .id = 4,
            .name = "region",
            .type = .{ .utf8 = {} },
            .nullable = false,
            .default = .{ .value = .{ .atom = .{ .bytes = "EU" } } },
        },
    };
    const s2: s.Schema = .{
        .object = 10,
        .revision = 2,
        .next_column = 5,
        .columns = &s2_cols,
        .primary_key = &pk,
    };

    var entries: [8]BranchDiff.SchemaDiffEntry = undefined;
    const count = try BranchDiff.diffTableSchemas("orders", s1, "orders_v2", s2, &entries);
    try std.testing.expectEqual(@as(usize, 4), count);
    try std.testing.expectEqual(BranchDiff.SchemaDiffKind.table_renamed, entries[0].kind);
    try std.testing.expectEqual(BranchDiff.SchemaDiffKind.column_renamed, entries[1].kind);
    try std.testing.expectEqual(@as(s.ColumnId, 2), entries[1].column_id.?);
    try std.testing.expectEqual(BranchDiff.SchemaDiffKind.column_dropped, entries[2].kind);
    try std.testing.expectEqual(@as(s.ColumnId, 3), entries[2].column_id.?);
    try std.testing.expectEqual(BranchDiff.SchemaDiffKind.column_added_lazy, entries[3].kind);
    try std.testing.expectEqual(TableConstraints.RewriteKind.lazy_metadata_or_projection, entries[3].rewrite_kind);

    // Recreated table with different `object` identity reports `.table_recreated`
    const s_recreated: s.Schema = .{
        .object = 99,
        .revision = 1,
        .next_column = 4,
        .columns = &s1_cols,
        .primary_key = &pk,
    };
    const rec_count = try BranchDiff.diffTableSchemas("orders", s1, "orders", s_recreated, &entries);
    try std.testing.expectEqual(@as(usize, 1), rec_count);
    try std.testing.expectEqual(BranchDiff.SchemaDiffKind.table_recreated, entries[0].kind);
}
