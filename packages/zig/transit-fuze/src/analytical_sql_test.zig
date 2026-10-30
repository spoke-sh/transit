const std = @import("std");
const testing = std.testing;
const f = @import("root.zig");
const AnalyticalSql = f.AnalyticalSql;
const PerfectHashIn = f.PerfectHashIn;
const VectorUdf = f.VectorUdf;
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

fn nullCell() v.Cell {
    return .{ .null = {} };
}

test "multi-way joins, outer/semi/anti joins and interval range predicates preserve 5-state cells" {
    const t0 = [_]AnalyticalSql.Row{
        try AnalyticalSql.Row.fromSlice(&.{ intCell(1), strCell("ALPHA") }),
        try AnalyticalSql.Row.fromSlice(&.{ intCell(2), strCell("BETA") }),
        try AnalyticalSql.Row.fromSlice(&.{ intCell(3), strCell("GAMMA") }),
    };
    const t1 = [_]AnalyticalSql.Row{
        try AnalyticalSql.Row.fromSlice(&.{ intCell(1), intCell(100) }),
        try AnalyticalSql.Row.fromSlice(&.{ intCell(2), intCell(200) }),
    };
    const t2 = [_]AnalyticalSql.Row{
        try AnalyticalSql.Row.fromSlice(&.{ intCell(100), strCell("TIER-1") }),
        try AnalyticalSql.Row.fromSlice(&.{ intCell(999), strCell("ORPHAN") }),
    };

    var out: [32]AnalyticalSql.Row = undefined;
    const steps = [_]AnalyticalSql.MultiWayJoinStep{
        .{
            .kind = .left_outer,
            .right_rows = &t1,
            .right_arity = 2,
            .predicate = .{ .equi = .{ .left_col = 0, .right_col = 0 } },
        },
        .{
            .kind = .left_outer,
            .right_rows = &t2,
            .right_arity = 2,
            .predicate = .{ .equi = .{ .left_col = 3, .right_col = 0 } },
        },
    };
    const count = try AnalyticalSql.executeMultiWayJoin(&t0, 2, &steps, &out);
    try testing.expectEqual(@as(usize, 3), count);
    try testing.expectEqualStrings("TIER-1", strVal(out[0].cells[5]));
    try testing.expect(out[1].cells[5] == .null);
    try testing.expect(out[2].cells[2] == .null);
    try testing.expect(out[2].cells[5] == .null);

    // SEMI (EXISTS) and ANTI (NOT EXISTS)
    var semi_out: [16]AnalyticalSql.Row = undefined;
    const semi_n = try AnalyticalSql.executeJoin(
        .left_semi,
        &t0,
        2,
        &t1,
        2,
        .{ .equi = .{ .left_col = 0, .right_col = 0 } },
        &semi_out,
    );
    try testing.expectEqual(@as(usize, 2), semi_n);

    var anti_out: [16]AnalyticalSql.Row = undefined;
    const anti_n = try AnalyticalSql.executeJoin(
        .left_anti,
        &t0,
        2,
        &t1,
        2,
        .{ .equi = .{ .left_col = 0, .right_col = 0 } },
        &anti_out,
    );
    try testing.expectEqual(@as(usize, 1), anti_n);
    try testing.expectEqual(@as(i64, 3), intVal(anti_out[0].cells[0]));
}

test "universal D-Join correlated subquery unnesting eliminates nested-loop probes and enforces scalar cardinality" {
    const outer_orders = [_]AnalyticalSql.Row{
        try AnalyticalSql.Row.fromSlice(&.{ intCell(10), strCell("cust_a") }),
        try AnalyticalSql.Row.fromSlice(&.{ intCell(20), strCell("cust_a") }),
        try AnalyticalSql.Row.fromSlice(&.{ intCell(30), strCell("cust_b") }),
        try AnalyticalSql.Row.fromSlice(&.{ intCell(40), strCell("cust_c") }),
    };
    const inner_limits = [_]AnalyticalSql.Row{
        try AnalyticalSql.Row.fromSlice(&.{ strCell("CUST_A"), intCell(500) }),
        try AnalyticalSql.Row.fromSlice(&.{ strCell("CUST_B"), intCell(900) }),
    };

    var out: [16]AnalyticalSql.Row = undefined;
    const stats = try AnalyticalSql.executeUnnestedDJoin(
        .scalar_single_row,
        &outer_orders,
        2,
        1,
        &inner_limits,
        0,
        1,
        .ascii_ci,
        &out,
    );
    try testing.expectEqual(@as(usize, 4), stats.outer_row_count);
    try testing.expectEqual(@as(usize, 3), stats.deduplicated_domain_size);
    try testing.expectEqual(@as(usize, 0), stats.nested_loop_probes);
    try testing.expectEqual(@as(usize, 4), stats.output_row_count);
    try testing.expectEqual(@as(i64, 500), intVal(out[0].cells[2]));
    try testing.expectEqual(@as(i64, 500), intVal(out[1].cells[2]));
    try testing.expectEqual(@as(i64, 900), intVal(out[2].cells[2]));
    try testing.expect(out[3].cells[2] == .null);

    // Duplicate inner row for the same correlation key must fail closed for scalar subqueries
    const duplicate_inner = [_]AnalyticalSql.Row{
        try AnalyticalSql.Row.fromSlice(&.{ strCell("cust_a"), intCell(500) }),
        try AnalyticalSql.Row.fromSlice(&.{ strCell("cust_a"), intCell(600) }),
    };
    try testing.expectError(
        error.ScalarSubqueryMultipleRows,
        AnalyticalSql.executeUnnestedDJoin(
            .scalar_single_row,
            &outer_orders,
            2,
            1,
            &duplicate_inner,
            0,
            1,
            .ascii_ci,
            &out,
        ),
    );
}

test "window functions support ROWS/RANGE/GROUPS frames, ranking, navigation and QUALIFY" {
    const rows = [_]AnalyticalSql.Row{
        try AnalyticalSql.Row.fromSlice(&.{ strCell("dept_1"), intCell(10), intCell(100) }),
        try AnalyticalSql.Row.fromSlice(&.{ strCell("dept_1"), intCell(10), intCell(200) }),
        try AnalyticalSql.Row.fromSlice(&.{ strCell("dept_1"), intCell(20), intCell(300) }),
        try AnalyticalSql.Row.fromSlice(&.{ strCell("dept_2"), intCell(5), intCell(50) }),
    };

    var out: [16]AnalyticalSql.Row = undefined;
    // DENSE_RANK() with QUALIFY <= 1
    const qualified_n = try AnalyticalSql.evaluateWindow(&rows, .{
        .partition_col = 0,
        .order_col = 1,
        .function = .dense_rank,
        .qualify_max_int64 = 1,
    }, &out);
    try testing.expectEqual(@as(usize, 3), qualified_n);

    // Sliding ROWS BETWEEN 1 PRECEDING AND CURRENT ROW SUM(col 2)
    const sum_n = try AnalyticalSql.evaluateWindow(&rows, .{
        .partition_col = 0,
        .order_col = 1,
        .frame_mode = .rows,
        .preceding_bound = 1,
        .following_bound = 0,
        .function = .{ .frame_sum_int64 = .{ .value_col = 2 } },
    }, &out);
    try testing.expectEqual(@as(usize, 4), sum_n);
    try testing.expectEqual(@as(i64, 100), intVal(out[0].cells[3]));
    try testing.expectEqual(@as(i64, 300), intVal(out[1].cells[3]));
    try testing.expectEqual(@as(i64, 500), intVal(out[2].cells[3]));
    try testing.expectEqual(@as(i64, 50), intVal(out[3].cells[3]));
}

test "recursive CTEs, set operations, rich aggregates and NVMe spill budgets" {
    const dag_edges = [_]AnalyticalSql.GraphEdge{
        .{ .from_node = 1, .to_node = 2, .weight = 5 },
        .{ .from_node = 2, .to_node = 3, .weight = 7 },
    };
    var paths: [16]AnalyticalSql.RecursivePathRow = undefined;
    const path_n = try AnalyticalSql.evaluateRecursiveGraphCte(&.{1}, &dag_edges, .{}, &paths);
    try testing.expectEqual(@as(usize, 3), path_n);
    try testing.expectEqual(@as(i64, 12), paths[2].total_weight);

    const cyclic_edges = [_]AnalyticalSql.GraphEdge{
        .{ .from_node = 1, .to_node = 2 },
        .{ .from_node = 2, .to_node = 1 },
    };
    try testing.expectError(
        error.RecursiveCteCycleDetected,
        AnalyticalSql.evaluateRecursiveGraphCte(&.{1}, &cyclic_edges, .{ .reject_on_cycle = true }, &paths),
    );

    // Rich aggregates (mean, stddev, median) and 5-state propagation
    const sample = [_]v.Cell{ intCell(10), intCell(20), nullCell(), intCell(30), intCell(40) };
    const agg = try AnalyticalSql.computeRichAggregateSummary(&sample);
    try testing.expectEqual(@as(usize, 4), agg.non_null_count);
    try testing.expectApproxEqAbs(@as(f64, 25.0), agg.mean.?, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 25.0), agg.median_cont.?, 1e-9);
    try testing.expect(agg.stddev_pop.? > 11.0 and agg.stddev_samp.? > 12.0);

    // Bounded Tier 2 NVMe spill tracking
    var spill: AnalyticalSql.SpillTracker = .{
        .max_resident_bytes = 4096,
        .max_spill_bytes = 8192,
    };
    try spill.recordAllocation(2048);
    try spill.recordAllocation(3072);
    try testing.expectEqual(@as(usize, 1), spill.spilled_run_count);
    try testing.expectEqual(@as(usize, 5120), spill.spilled_bytes);
    try testing.expectError(error.SpillQuotaExceeded, spill.recordAllocation(5000));
    spill.closeAndCleanup();
    try testing.expect(spill.cleaned_up);
}

test "comptime and plan-bound perfect-hash IN (...) with 16-byte SIMD comparisons and collations" {
    try testing.expectEqual(PerfectHashIn.KeywordKind.activate, PerfectHashIn.lookupKeyword("activate").?);
    try testing.expectEqual(PerfectHashIn.KeywordKind.qualify, PerfectHashIn.lookupKeyword("QUALIFY").?);
    try testing.expectEqual(PerfectHashIn.KeywordKind.stream_slice, PerfectHashIn.lookupKeyword("stream_slice").?);
    try testing.expect(PerfectHashIn.lookupKeyword("UNKNOWN_VERB") == null);

    // EBCDIC_037_PAD trailing-space normalization + 5-state NOT IN semantics
    const literals = [_]?[]const u8{ "A1", "B2  ", null };
    const in_set = try PerfectHashIn.StringInSet.compile(&literals, .ebcdic_037_pad, false);
    try testing.expectEqual(PerfectHashIn.EvalState.value_true, try in_set.evaluateCell(strCell("A1   ")));
    try testing.expectEqual(PerfectHashIn.EvalState.value_true, try in_set.evaluateCell(strCell("B2")));
    try testing.expectEqual(PerfectHashIn.EvalState.null_unknown, try in_set.evaluateCell(strCell("C3")));

    const not_in_set = try PerfectHashIn.StringInSet.compile(&literals, .ebcdic_037_pad, true);
    try testing.expectEqual(PerfectHashIn.EvalState.value_false, try not_in_set.evaluateCell(strCell("A1  ")));
    try testing.expectEqual(PerfectHashIn.EvalState.null_unknown, try not_in_set.evaluateCell(strCell("C3")));
    try testing.expectEqual(PerfectHashIn.EvalState.missing, try not_in_set.evaluateCell(.{ .missing = {} }));
}

test "deterministic SQL macros and sandboxed vectorized Wasm UDFs execute without actor mailbox hops" {
    // 1. SQL Macro: COALESCE(param 0, 10) + param 1
    const p0 = VectorUdf.MacroExpr{ .param = 0 };
    const lit10 = VectorUdf.MacroExpr{ .literal_int64 = 10 };
    const coal = VectorUdf.MacroExpr{ .coalesce = .{ .primary = &p0, .fallback = &lit10 } };
    const p1 = VectorUdf.MacroExpr{ .param = 1 };
    const macro_expr = VectorUdf.MacroExpr{ .add_checked = .{ .left = &coal, .right = &p1 } };

    const macro_fn: VectorUdf.FunctionDescriptor = .{
        .function_id = 1,
        .name = "add_with_default",
        .definition_id = 1,
        .runtime = .sql_macro,
        .param_count = 2,
        .macro_body = macro_expr,
    };

    const row0 = [_]v.Cell{ nullCell(), intCell(5) };
    const row1 = [_]v.Cell{ intCell(20), intCell(7) };
    const batch_args = [_][]const v.Cell{ &row0, &row1 };
    var out_cells: [2]v.Cell = undefined;

    const macro_stats = try VectorUdf.evaluateScalarBatch(macro_fn, &batch_args, &out_cells);
    try testing.expectEqual(@as(usize, 0), macro_stats.actor_mailbox_hops);
    try testing.expectEqual(@as(i64, 15), intVal(out_cells[0]));
    try testing.expectEqual(@as(i64, 27), intVal(out_cells[1]));

    // 2. Reject Wasm UDF with ambient WASI/network imports at validation time
    const ambient_wasm: VectorUdf.FunctionDescriptor = .{
        .function_id = 2,
        .name = "bad_network_udf",
        .definition_id = 1,
        .runtime = .wasm_vector_v1,
        .param_count = 1,
        .wasm_module = .{
            .param_count = 1,
            .ambient_imports = &.{.network_socket},
            .instructions = &.{.{ .local_get = 0 }},
        },
    };
    try testing.expectError(error.AmbientUdfImportRejected, ambient_wasm.validate());

    // 3. Valid vectorized Wasm UDF: (x * 3) + y
    const wasm_ins = [_]VectorUdf.WasmInstr{
        .{ .local_get = 0 },
        .{ .i64_const = 3 },
        .i64_mul_checked,
        .{ .local_get = 1 },
        .i64_add_checked,
    };
    const wasm_fn: VectorUdf.FunctionDescriptor = .{
        .function_id = 3,
        .name = "linear_scale",
        .definition_id = 1,
        .runtime = .wasm_vector_v1,
        .param_count = 2,
        .wasm_module = .{
            .param_count = 2,
            .instructions = &wasm_ins,
        },
    };
    const wasm_stats = try VectorUdf.evaluateScalarBatch(wasm_fn, &batch_args, &out_cells);
    try testing.expectEqual(@as(usize, 0), wasm_stats.actor_mailbox_hops);
    try testing.expect(out_cells[0] == .null);
    try testing.expectEqual(@as(i64, 67), intVal(out_cells[1]));

    // 4. Infinite-loop Wasm UDF is deterministically terminated by max_fuel_per_row
    const loop_ins = [_]VectorUdf.WasmInstr{
        .{ .i64_const = 1 },
        .{ .branch_back_if_positive = 0 },
    };
    const loop_fn: VectorUdf.FunctionDescriptor = .{
        .function_id = 4,
        .name = "infinite_loop",
        .definition_id = 1,
        .runtime = .wasm_vector_v1,
        .param_count = 2,
        .max_fuel_per_row = 16,
        .on_trap = .abort_statement,
        .wasm_module = .{
            .param_count = 2,
            .instructions = &loop_ins,
        },
    };
    const non_null_batch = [_][]const v.Cell{&row1};
    try testing.expectError(
        error.UdfFuelExhausted,
        VectorUdf.evaluateScalarBatch(loop_fn, &non_null_batch, &out_cells),
    );
}
