const std = @import("std");
const testing = std.testing;
const f = @import("root.zig");
const AnalyticalSql = f.AnalyticalSql;
const BitemporalAndTvf = f.BitemporalAndTvf;
const FuzeDelta = f.FuzeDelta;
const v = f.Types.Values;

fn intCell(n: i64) v.Cell {
    return .{ .value = .{ .atom = .{ .signed = n } } };
}

fn strCell(s: []const u8) v.Cell {
    return .{ .value = .{ .atom = .{ .bytes = s } } };
}

fn intVal(cell: v.Cell) i64 {
    return @intCast(cell.value.atom.signed);
}

fn strVal(cell: v.Cell) []const u8 {
    return cell.value.atom.bytes;
}

fn linearTrajectoryInterpolator(
    matched: BitemporalAndTvf.BitemporalRightRow,
    next: ?BitemporalAndTvf.BitemporalRightRow,
    query_ts: i64,
) v.Cell {
    const nxt = next orelse return matched.payload;
    const x0 = intVal(matched.payload);
    const x1 = intVal(nxt.payload);
    const dt_total = nxt.valid_from - matched.valid_from;
    if (dt_total <= 0) return matched.payload;
    const dt = query_ts - matched.valid_from;
    const interp = x0 + @divTrunc((x1 - x0) * dt, dt_total);
    return intCell(interp);
}

test "bitemporal AS OF JOIN isolates historical decision cuts from post-facto backfills and supports trajectory interpolation" {
    try testing.expectError(error.InvalidValidTimePeriod, BitemporalAndTvf.ValidTimePeriod.initClosedOpen(100, 100));
    const p1 = try BitemporalAndTvf.ValidTimePeriod.initClosedOpen(100, 200);
    const p2 = try BitemporalAndTvf.ValidTimePeriod.initClosedOpen(150, 250);
    try testing.expect(p1.containsTimestamp(150));
    try testing.expect(!p1.containsTimestamp(200));
    try testing.expect(p1.overlaps(p2));

    // Right-hand price/position history for entity 42:
    // At system LSN 10, valid [100, 300) was recorded as 1000.
    // Later at system LSN 25 (retroactive backfill!), valid [100, 300) was corrected to 9999.
    // Also at system LSN 10, valid [300, 500) was recorded as 2000.
    const right_history = [_]BitemporalAndTvf.BitemporalRightRow{
        .{
            .entity_key = 42,
            .valid_from = 100,
            .valid_to = 300,
            .system_commit_lsn = 10,
            .system_superseded_lsn = 25,
            .payload = intCell(1000),
        },
        .{
            .entity_key = 42,
            .valid_from = 100,
            .valid_to = 300,
            .system_commit_lsn = 25,
            .system_superseded_lsn = null,
            .payload = intCell(9999),
        },
        .{
            .entity_key = 42,
            .valid_from = 300,
            .valid_to = 500,
            .system_commit_lsn = 10,
            .system_superseded_lsn = null,
            .payload = intCell(2000),
        },
    };

    const probes = [_]BitemporalAndTvf.BitemporalLeftProbe{
        .{ .probe_id = 1, .entity_key = 42, .event_ts = 200 },
    };

    var out: [4]BitemporalAndTvf.AsOfJoinOutputRow = undefined;

    // 1. Decision backtest at FOR SYSTEM_TIME AS OF 15 must see 1000 (not the LSN 25 backfill 9999!)
    const n_at_15 = try BitemporalAndTvf.executeBitemporalAsOfJoin(&probes, &right_history, .{
        .system_cut_lsn = 15,
    }, &out);
    try testing.expectEqual(@as(usize, 1), n_at_15);
    try testing.expectEqual(@as(i64, 1000), intVal(out[0].payload));
    try testing.expectEqual(@as(?u64, 10), out[0].matched_system_lsn);

    // 2. Audit at FOR SYSTEM_TIME AS OF 30 sees the corrected backfill 9999
    const n_at_30 = try BitemporalAndTvf.executeBitemporalAsOfJoin(&probes, &right_history, .{
        .system_cut_lsn = 30,
    }, &out);
    try testing.expectEqual(@as(usize, 1), n_at_30);
    try testing.expectEqual(@as(i64, 9999), intVal(out[0].payload));
    try testing.expectEqual(@as(?u64, 25), out[0].matched_system_lsn);

    // 3. Kinematic trajectory interpolation hook (Milestone 17 integration) at ts=200 between 100 (1000) and 300 (2000) -> 1500
    const n_interp = try BitemporalAndTvf.executeBitemporalAsOfJoin(&probes, &right_history, .{
        .system_cut_lsn = 15,
        .interpolator = linearTrajectoryInterpolator,
    }, &out);
    try testing.expectEqual(@as(usize, 1), n_interp);
    try testing.expectEqual(@as(i64, 1500), intVal(out[0].payload));
}

test "CHANGES(...) and STREAM_SLICE(...) TVFs and transactional SQL MERGE INTO with plan invalidation" {
    // 1. CHANGES(table, ...) with A -> B -> A oscillation and uncommitted tx filtering
    const log = [_]BitemporalAndTvf.CommittedChangeRecord{
        .{ .tx_id = 1, .tx_committed = true, .commit_lsn = 11, .manifest_version = 2, .primary_key = 7, .op = .insert, .payload = strCell("A") },
        .{ .tx_id = 2, .tx_committed = true, .commit_lsn = 12, .manifest_version = 2, .primary_key = 7, .op = .delete, .payload = strCell("A") },
        .{ .tx_id = 2, .tx_committed = true, .commit_lsn = 12, .manifest_version = 2, .primary_key = 7, .op = .insert, .payload = strCell("B") },
        .{ .tx_id = 3, .tx_committed = false, .commit_lsn = 13, .manifest_version = 2, .primary_key = 99, .op = .insert, .payload = strCell("ABORTED") },
    };

    var changes_out: [16]BitemporalAndTvf.ChangesTvfRow = undefined;
    const all_n = try BitemporalAndTvf.evaluateChangesTvf(&log, 10, 20, .all_ordered, 5, 5, true, &changes_out);
    try testing.expectEqual(@as(usize, 3), all_n);

    const net_n = try BitemporalAndTvf.evaluateChangesTvf(&log, 10, 20, .net_relation, 5, 5, true, &changes_out);
    try testing.expectEqual(@as(usize, 1), net_n);
    try testing.expectEqual(@as(i64, 7), changes_out[0].primary_key);
    try testing.expectEqual(@as(i64, 1), changes_out[0].change_weight);
    try testing.expectEqualStrings("B", strVal(changes_out[0].payload));

    // Mid-stream policy_epoch revocation must fail closed
    try testing.expectError(
        error.AuthorizationRevokedMidStream,
        BitemporalAndTvf.evaluateChangesTvf(&log, 10, 20, .net_relation, 5, 6, false, &changes_out),
    );

    // 2. STREAM_SLICE is side-effect-free and preserves consumer-group watermark
    try testing.expect(BitemporalAndTvf.streamSliceEffects().isPureRead());
    const stream = [_]BitemporalAndTvf.StreamRecord{
        .{ .offset = 0, .timestamp_ns = 1000, .partition_id = 0, .key = "k1", .payload = intCell(10) },
        .{ .offset = 1, .timestamp_ns = 2000, .partition_id = 0, .key = "k2", .payload = intCell(20) },
        .{ .offset = 2, .timestamp_ns = 3000, .partition_id = 0, .key = "k3", .payload = intCell(30) },
    };
    var consumer_watermark: u64 = 1;
    var slice_out: [8]BitemporalAndTvf.StreamRecord = undefined;
    const slice_n = try BitemporalAndTvf.evaluateStreamSliceTvf(
        &stream,
        .{ .offset_range = .{ .start_inclusive = 1, .end_exclusive = 3 } },
        &consumer_watermark,
        &slice_out,
    );
    try testing.expectEqual(@as(usize, 2), slice_n);
    try testing.expectEqual(@as(u64, 1), consumer_watermark);

    // 3. SQL MERGE INTO + cardinality check + prepared-plan invalidation
    const target = [_]BitemporalAndTvf.MergeTargetRow{
        .{ .key = 1, .value = intCell(100) },
        .{ .key = 2, .value = intCell(200) },
    };
    const source = [_]BitemporalAndTvf.MergeSourceRow{
        .{ .key = 1, .action = .upsert, .new_value = intCell(150) },
        .{ .key = 2, .action = .delete_matched, .new_value = .{ .null = {} } },
        .{ .key = 3, .action = .upsert, .new_value = intCell(300) },
    };
    var merged_target: [8]BitemporalAndTvf.MergeTargetRow = undefined;
    const merge_res = try BitemporalAndTvf.executeTransactionalMerge(&target, &source, false, &merged_target);
    try testing.expectEqual(@as(usize, 1), merge_res.updated_count);
    try testing.expectEqual(@as(usize, 1), merge_res.deleted_count);
    try testing.expectEqual(@as(usize, 1), merge_res.inserted_count);
    try testing.expectEqual(@as(usize, 2), merge_res.final_row_count);

    const dup_source = [_]BitemporalAndTvf.MergeSourceRow{
        .{ .key = 1, .action = .upsert, .new_value = intCell(150) },
        .{ .key = 1, .action = .upsert, .new_value = intCell(160) },
    };
    try testing.expectError(
        error.MergeCardinalityViolation,
        BitemporalAndTvf.executeTransactionalMerge(&target, &dup_source, false, &merged_target),
    );

    const plan_binding: BitemporalAndTvf.PreparedPlanBinding = .{
        .plan_id = 9,
        .bound_policy_epoch = 4,
        .objects = &.{.{ .object_id = 10, .definition_id = 2 }},
    };
    try plan_binding.validateAgainstCurrent(&.{.{ .object_id = 10, .definition_id = 2 }}, 4);
    try testing.expectError(
        error.PreparedPlanInvalidatedByDdl,
        plan_binding.validateAgainstCurrent(&.{.{ .object_id = 10, .definition_id = 3 }}, 4),
    );
    try testing.expectError(
        error.PreparedPlanInvalidatedByPolicyEpoch,
        plan_binding.validateAgainstCurrent(&.{.{ .object_id = 10, .definition_id = 2 }}, 5),
    );
}

test "A3 incremental DBSP Z-set join and group-by match the finite recomputation oracle across retractions and overflows" {
    var left_arr: FuzeDelta.Arrangement = .{ .key_col = 0, .event_ts_col = 1 };
    var right_arr: FuzeDelta.Arrangement = .{ .key_col = 0 };
    var materialized_join: FuzeDelta.ZSet = .{};

    // Step 1: initial insertions into R and S
    var d_left_1: FuzeDelta.ZSet = .{};
    try d_left_1.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ intCell(1), intCell(100) }), 1);
    try d_left_1.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ intCell(2), intCell(110) }), 1);

    var d_right_1: FuzeDelta.ZSet = .{};
    try d_right_1.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ intCell(1), strCell("X") }), 1);

    var d_join_1: FuzeDelta.ZSet = .{};
    try FuzeDelta.stepIncrementalInnerJoin(&left_arr, &right_arr, &d_left_1, &d_right_1, .utf8_binary, &d_join_1);
    try materialized_join.addZSet(&d_join_1);

    var oracle_1: FuzeDelta.ZSet = .{};
    try FuzeDelta.evaluateFiniteJoinOracle(&left_arr.state, &right_arr.state, 0, 0, .utf8_binary, &oracle_1);
    try testing.expect(try materialized_join.equals(&oracle_1));

    // Step 2: retract key 1 from R, insert key 2 into S, and oscillate key 3 (+1 then -1 in same batch)
    var d_left_2: FuzeDelta.ZSet = .{};
    try d_left_2.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ intCell(1), intCell(100) }), -1);
    try d_left_2.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ intCell(3), intCell(120) }), 1);
    try d_left_2.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ intCell(3), intCell(120) }), -1);

    var d_right_2: FuzeDelta.ZSet = .{};
    try d_right_2.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ intCell(2), strCell("Y") }), 1);

    var d_join_2: FuzeDelta.ZSet = .{};
    try FuzeDelta.stepIncrementalInnerJoin(&left_arr, &right_arr, &d_left_2, &d_right_2, .utf8_binary, &d_join_2);
    try materialized_join.addZSet(&d_join_2);

    var oracle_2: FuzeDelta.ZSet = .{};
    try FuzeDelta.evaluateFiniteJoinOracle(&left_arr.state, &right_arr.state, 0, 0, .utf8_binary, &oracle_2);
    try testing.expect(try materialized_join.equals(&oracle_2));
    try testing.expectEqual(@as(usize, 1), materialized_join.len);
    try testing.expectEqual(@as(i64, 2), intVal(materialized_join.entries[0].row.cells[0]));

    // Reversible checked-arithmetic overflow witness in Z-set GROUP BY:
    // Insert MAX_INT64 and +10 into group "g1" -> sum overflows to type_error(.int64);
    // Retract MAX_INT64 (-1) -> group "g1" recovers exact valid sum 10!
    var agg: FuzeDelta.ZSetGroupByAggregator = .{ .key_col = 0, .value_col = 1 };
    var d_agg_1: FuzeDelta.ZSet = .{};
    try d_agg_1.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ strCell("g1"), intCell(std.math.maxInt(i64)) }), 1);
    try d_agg_1.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ strCell("g1"), intCell(10) }), 1);
    try agg.applyDelta(&d_agg_1);

    var mat_agg_1: FuzeDelta.ZSet = .{};
    try agg.materializeZSet(&mat_agg_1);
    try testing.expectEqual(@as(usize, 1), mat_agg_1.len);
    try testing.expect(mat_agg_1.entries[0].row.cells[2] == .type_error);

    var d_agg_2: FuzeDelta.ZSet = .{};
    try d_agg_2.addRowWeight(try AnalyticalSql.Row.fromSlice(&.{ strCell("g1"), intCell(std.math.maxInt(i64)) }), -1);
    try agg.applyDelta(&d_agg_2);

    var mat_agg_2: FuzeDelta.ZSet = .{};
    try agg.materializeZSet(&mat_agg_2);
    try testing.expectEqual(@as(usize, 1), mat_agg_2.len);
    try testing.expectEqual(@as(i64, 10), intVal(mat_agg_2.entries[0].row.cells[2]));

    // Watermark progression and Milestone 17 spatial Z-set handoff gate
    var wm: FuzeDelta.WatermarkTracker = .{ .allowed_lateness_ts = 50, .late_policy = .retract_and_emit };
    try testing.expectEqual(FuzeDelta.LateEventOutcome.admitted_on_time, wm.observeEventTimestamp(200));
    try testing.expectEqual(@as(i64, 150), wm.current_watermark_ts);
    try testing.expectEqual(FuzeDelta.LateEventOutcome.admitted_within_allowed_lateness, wm.observeEventTimestamp(160));
    try testing.expectEqual(FuzeDelta.LateEventOutcome.retracted_late_update, wm.observeEventTimestamp(120));
    try testing.expectEqual(@as(usize, 1), wm.retracted_late_count);

    try testing.expectError(
        error.SpatialZSetExecutionDeferredToM17,
        FuzeDelta.invokeSpatialZSetOperator(.{
            .operator_kind = .planar_half_edge_boundary_d2,
            .srid = 4326,
            .snap_grid_scale = 1_000_000,
        }),
    );
}
