const std = @import("std");
const e = std.testing;
const f = @import("root.zig");
const q = f.LogicalQuery;
const s = f.LogicalStream;
const t = f.Types;
const Cell = t.Values.Cell;
const basis: [32]u8 = @splat(7);
fn integer(n: i128) Cell {
    return .{ .value = .{ .atom = .{ .signed = n } } };
}
const simple: t.Type = .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true, .optional = true }} };

test "durable logical records require plan validation after structural decoding" {
    const plan: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0} };
    var progress = try s.Progress.start(plan);
    try e.expectEqualDeep(progress, try s.Progress.decodeRecord(&try progress.encodeRecord()));
    progress.pages = 1;
    progress.counters = .{ .scanned = 1, .selected = 1, .value_count = 1 };
    progress.segments = 1;
    progress.rows = 1;
    // Valid counter structure can still contradict a rows plan. The host must
    // bind the immutable request before admitting a recovered checkpoint.
    const decoded = try s.Progress.decodeRecord(&try progress.encodeRecord());
    try e.expectError(error.InvalidQueryProgress, decoded.validate(plan));
    try e.expectError(error.InvalidQueryProgress, s.Progress.decode(plan, &try progress.encodeRecord()));
    progress.counters.value_count = 0;
    progress.binding[0] ^= 1;
    try e.expectError(error.SourceChanged, (try s.Progress.decodeRecord(&try progress.encodeRecord())).validate(plan));
    progress.binding[0] ^= 1;
    progress.counters.selected = 2;
    try e.expectError(error.InvalidQueryProgress, progress.encodeRecord());
}

test "logical steps resume all finite operators over recursive rows at every page width" {
    const workspace = try e.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer e.allocator.free(workspace);
    var output: [f.LogicalArrow.segment_bytes]u8 = undefined;
    var oracle: [f.LogicalArrow.segment_bytes]u8 = undefined;
    const schema: t.Type = .{ .structure = &.{
        .{ .name = "id", .type = .int32 },
        .{ .name = "n", .type = .int64, .nullable = true },
        .{ .name = "detail", .type = .{ .list = .{ .type = &.utf8, .nullable = true } } },
    } };
    var cells: [19][3]Cell = undefined;
    var rows: [19]f.LogicalArrow.Row = undefined;
    for (&cells, &rows, 0..) |*cell, *row, i| {
        cell.* = .{ integer(@intCast(i)), if (i % 3 == 0) .null else integer(@intCast(i * 2)), .{ .value = .{ .list = &.{ .{ .value = .{ .atom = .{ .bytes = "東京" } } }, .null } } } };
        row.* = .{ .cells = cell };
    }
    const cancelled = f.execution.Cancellation.init(false);
    for ([_]@FieldType(q.Plan, "aggregate"){ .rows, .count, .count_values, .sum }) |aggregate| {
        const plan: q.Plan = .{ .schema = schema, .source_basis = basis, .aggregate = aggregate, .projection = if (aggregate == .rows) &.{ 2, 0, 1 } else &.{1}, .limit = 9, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 4 } } } };
        for (1..s.max_rows + 1) |width| {
            var progress = try s.Progress.start(plan);
            var offset: usize = 0;
            while (progress.finished == null) {
                const end = @min(offset + width, rows.len);
                const page: s.Page = .{ .binding = basis, .ordinal = progress.pages, .rows = rows[offset..end], .end = end == rows.len };
                const next = try s.step(plan, progress, page, workspace, &output, &cancelled, null);
                var expected_cells: [s.max_rows][3]Cell = undefined;
                var expected_rows: [s.max_rows]f.LogicalArrow.Row = undefined;
                var count: usize = 0;
                if (aggregate == .rows) {
                    for (offset..end) |i| if (i >= 4 and i < 13) {
                        expected_cells[count] = .{ cells[i][2], cells[i][0], cells[i][1] };
                        expected_rows[count] = .{ .cells = &expected_cells[count] };
                        count += 1;
                    };
                } else if (next.progress.finished != null) {
                    expected_cells[0][0] = switch (aggregate) {
                        .count => .{ .value = .{ .atom = .{ .unsigned = 9 } } },
                        .count_values => .{ .value = .{ .atom = .{ .unsigned = 6 } } },
                        .sum => integer(90),
                        .rows => unreachable,
                    };
                    expected_rows[0] = .{ .cells = expected_cells[0][0..1] };
                    count = 1;
                }
                if (count == 0) {
                    try e.expect(next.segment == null);
                } else {
                    var fields: [128]t.Field = undefined;
                    try e.expectEqualSlices(u8, try f.LogicalArrow.encode(try plan.outputSchema(&fields), expected_rows[0..count], workspace, &oracle), next.segment.?.bytes);
                }
                // Replace both disposable plan and execution state after every
                // page; only canonical bytes cross the restart boundary.
                var plan_bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
                var restored = try f.LogicalPlanCodec.decode(e.allocator, schema, basis, try f.LogicalPlanCodec.encode(plan, &plan_bytes));
                defer restored.deinit();
                progress = try s.Progress.decode(restored.plan, &try next.progress.encode(plan));
                try e.expectEqualDeep(next.progress, progress);
                offset = end;
            }
            try e.expectEqual(.limit, progress.finished.?);
            try e.expectEqual(@as(u64, 13), progress.counters.scanned);
            try e.expectEqual(@as(u64, 9), progress.counters.selected);
            try e.expectEqual(@as(u64, if (aggregate == .rows) 9 else 1), progress.rows);
        }
    }
}

test "logical steps preserve empty completion and nullable value-count semantics" {
    const workspace = try e.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer e.allocator.free(workspace);
    var output: [8192]u8 = undefined;
    var expected: [8192]u8 = undefined;
    const cancelled = f.execution.Cancellation.init(false);
    for ([_]@FieldType(q.Plan, "aggregate"){ .rows, .count, .count_values, .sum }) |aggregate| {
        const plan: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0}, .aggregate = aggregate };
        const empty = try s.step(plan, try .start(plan), .{ .binding = basis, .ordinal = 0, .rows = &.{}, .end = false }, workspace, &output, &cancelled, null);
        try e.expect(empty.segment == null and empty.progress.finished == null);
        const completed = try s.step(plan, empty.progress, .{ .binding = basis, .ordinal = 1, .rows = &.{}, .end = true }, workspace, &output, &cancelled, null);
        try e.expectEqual(@as(u64, 1), completed.progress.segments);
        const cell: Cell = if (aggregate == .sum) .null else .{ .value = .{ .atom = .{ .unsigned = 0 } } };
        var fields: [128]t.Field = undefined;
        try e.expectEqualSlices(u8, try f.LogicalArrow.encode(try plan.outputSchema(&fields), if (aggregate == .rows) &.{} else &.{.{ .cells = &.{cell} }}, workspace, &expected), completed.segment.?.bytes);
        try e.expectError(error.QueryComplete, s.step(plan, completed.progress, .{ .binding = basis, .ordinal = 2, .rows = &.{}, .end = true }, workspace, &output, &cancelled, null));
        var limited = plan;
        limited.limit = 0;
        const zero = try s.step(limited, try .start(limited), .{ .binding = basis, .ordinal = 0, .rows = &.{}, .end = false }, workspace, &output, &cancelled, null);
        try e.expectEqual(.limit, zero.progress.finished.?);
        try e.expectEqual(@as(u64, 0), zero.progress.counters.scanned);
    }
    const plan: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0}, .aggregate = .count_values };
    const counted = try s.step(plan, try .start(plan), .{ .binding = basis, .ordinal = 0, .end = true, .rows = &.{ .{ .cells = &.{.missing} }, .{ .cells = &.{.null} }, .{ .cells = &.{integer(0)} } } }, workspace, &output, &cancelled, null);
    try e.expectEqual(@as(u64, 3), counted.progress.counters.selected);
    try e.expectEqual(@as(u64, 1), counted.progress.counters.value_count);
}

test "logical steps retain eager predicate and source-order overflow evidence" {
    var cancelled = f.execution.Cancellation.init(false);
    var failure: ?s.Failure = null;
    const plan: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0}, .predicate = .{ .program = .{ .instructions = &.{ .{ .atom = .{ .state = .{ .column = 0, .value = .null } } }, .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = 0 } } } }, .conjunction } } } };
    const page: s.Page = .{ .binding = basis, .ordinal = 1, .end = true, .rows = &.{.{ .cells = &.{.{ .type_error = .utf8 }} }} };
    var previous = try s.Progress.start(plan);
    previous.pages = 1;
    previous.counters.scanned = 8;
    try e.expectError(error.QueryTypeError, s.step(plan, previous, page, &.{}, &.{}, &cancelled, &failure));
    try e.expectEqualDeep(s.Failure{ .operation = .predicate, .row = 9, .page_row = 0, .column = 0, .instruction = 1 }, failure.?);
    cancelled.store(true, .release);
    try e.expectError(error.Cancelled, s.step(plan, previous, page, &.{}, &.{}, &cancelled, &failure));
    try e.expect(failure == null);
    cancelled.store(false, .release);
    const sum: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0}, .aggregate = .sum };
    for ([_]i64{ std.math.minInt(i64), std.math.maxInt(i64) }) |edge| {
        const first = try s.step(sum, try .start(sum), .{ .binding = basis, .ordinal = 0, .end = false, .rows = &.{.{ .cells = &.{integer(edge)} }} }, &.{}, &.{}, &cancelled, &failure);
        const delta: i64 = if (edge > 0) 1 else -1;
        try e.expectError(error.Overflow, s.step(sum, first.progress, .{ .binding = basis, .ordinal = 1, .end = true, .rows = &.{ .{ .cells = &.{integer(delta)} }, .{ .cells = &.{integer(-delta)} } } }, &.{}, &.{}, &cancelled, &failure));
        try e.expectEqualDeep(s.Failure{ .operation = .sum, .row = 2, .page_row = 0, .column = 0 }, failure.?);
        try e.expectEqual(@as(?i64, edge), first.progress.counters.sum);
    }
    const count: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0}, .aggregate = .count_values };
    try e.expectError(error.QueryTypeError, s.step(count, try .start(count), .{ .binding = basis, .ordinal = 0, .end = true, .rows = page.rows }, &.{}, &.{}, &cancelled, &failure));
    try e.expectEqualDeep(s.Failure{ .operation = .count, .row = 1, .page_row = 0, .column = 0 }, failure.?);
    const conflict: Cell = .{ .conflict = &.{ .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 1 } } } }, .{ .counter = 2, .replica = 1, .value = .null } } };
    try e.expectError(error.QueryConflict, s.step(count, try .start(count), .{ .binding = basis, .ordinal = 0, .end = true, .rows = &.{.{ .cells = &.{conflict} }} }, &.{}, &.{}, &cancelled, &failure));
    try e.expectEqualDeep(s.Failure{ .operation = .count, .row = 1, .page_row = 0, .column = 0 }, failure.?);
}

test "logical step errors leave exact progress recoverable with canonical checkpoints" {
    const workspace = try e.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer e.allocator.free(workspace);
    var output: [8192]u8 = undefined;
    var cancelled = f.execution.Cancellation.init(false);
    const plan: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0} };
    const page: s.Page = .{ .binding = basis, .ordinal = 0, .end = false, .rows = &.{.{ .cells = &.{integer(7)} }} };
    const initial = try s.Progress.start(plan);
    const saved = try initial.encode(plan);
    try e.expectError(error.OutOfMemory, s.step(plan, initial, page, workspace[0..1], &output, &cancelled, null));
    try e.expectError(error.WriteFailed, s.step(plan, initial, page, workspace, output[0..1], &cancelled, null));
    cancelled.store(true, .release);
    try e.expectError(error.Cancelled, s.step(plan, initial, page, workspace, &output, &cancelled, null));
    cancelled.store(false, .release);
    try e.expectEqualSlices(u8, &saved, &try initial.encode(plan));
    const first = try s.step(plan, initial, page, workspace, &output, &cancelled, null);
    const digest = first.segment.?.digest;
    const retry = try s.step(plan, try s.Progress.decode(plan, &saved), page, workspace, &output, &cancelled, null);
    try e.expectEqualDeep(first.progress, retry.progress);
    try e.expectEqualSlices(u8, &digest, &retry.segment.?.digest);
    var other = plan;
    other.limit = 100;
    try e.expectError(error.SourceChanged, s.Progress.decode(other, &saved));
    var wrong = page;
    wrong.binding = @splat(9);
    try e.expectError(error.SourceChanged, s.step(plan, initial, wrong, workspace, &output, &cancelled, null));
    wrong = page;
    wrong.ordinal = 1;
    try e.expectError(error.InvalidQueryOrdinal, s.step(plan, initial, wrong, workspace, &output, &cancelled, null));
    var corrupt = saved;
    corrupt[s.progress_bytes - 9] = 1;
    try e.expectError(error.InvalidQueryProgress, s.Progress.decode(plan, &corrupt));
    for (0..s.progress_bytes) |length| try e.expectError(error.InvalidQueryProgress, s.Progress.decode(plan, saved[0..length]));
    var impossible = first.progress;
    impossible.counters.value_count = 1;
    try e.expectError(error.InvalidQueryProgress, impossible.encode(plan));
    impossible = first.progress;
    impossible.rows = 0;
    try e.expectError(error.InvalidQueryProgress, impossible.encode(plan));
}

test "independent logical checkpoint bytes preserve exact plan binding and full-width counters" {
    const Fixture = struct { schema_hex: []const u8, select_hex: []const u8, select_progress_hex: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, e.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    var schema_bytes: [f.TableSchema.max_bytes]u8 = undefined;
    var table = try f.TableSchema.decode(e.allocator, try std.fmt.hexToBytes(&schema_bytes, fixture.value.schema_hex));
    defer table.deinit();
    var fields: [128]t.Field = undefined;
    var plan_bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    var owned = try f.LogicalPlanCodec.decode(e.allocator, try table.schema.rowType(&fields), basis, try std.fmt.hexToBytes(&plan_bytes, fixture.value.select_hex));
    defer owned.deinit();
    var bytes: [s.progress_bytes]u8 = undefined;
    const expected = try std.fmt.hexToBytes(&bytes, fixture.value.select_progress_hex);
    const checkpoint = try s.Progress.decode(owned.plan, expected);
    try e.expectEqualSlices(u8, expected, &try checkpoint.encode(owned.plan));
    try e.expectEqual(@as(u64, 2), checkpoint.counters.scanned);
    try e.expectEqual(@as(u64, 1), checkpoint.counters.selected);
    try e.expectEqual(.source_end, checkpoint.finished.?);
    const workspace = try e.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer e.allocator.free(workspace);
    var output: [8192]u8 = undefined;
    const cancelled = f.execution.Cancellation.init(false);
    const count: q.Plan = .{ .schema = simple, .source_basis = basis, .projection = &.{0}, .aggregate = .count };
    var large = try s.Progress.start(count);
    large.counters.scanned = std.math.maxInt(i64);
    large.counters.selected = large.counters.scanned;
    large.pages = large.counters.scanned / s.max_rows + 1;
    var page: s.Page = .{ .binding = basis, .ordinal = large.pages, .end = true, .rows = &.{.{ .cells = &.{integer(1)} }} };
    const next = try s.step(count, large, page, workspace, &output, &cancelled, null);
    try e.expectEqual(@as(u64, 1) << 63, next.progress.counters.selected);
    try e.expectEqualDeep(next.progress, try s.Progress.decode(count, &try next.progress.encode(count)));
    large.counters.scanned = std.math.maxInt(u64);
    large.counters.selected = large.counters.scanned;
    large.pages = large.counters.scanned / s.max_rows + 1;
    page.ordinal = large.pages;
    try e.expectError(error.Overflow, s.step(count, large, page, workspace, &output, &cancelled, null));
}

test "logical pages exceed the old eight-column shape and validate whole-row budgets" {
    const workspace = try e.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer e.allocator.free(workspace);
    var output: [f.LogicalArrow.segment_bytes]u8 = undefined;
    var fields: [12]t.Field = undefined;
    var names: [12][8]u8 = undefined;
    var projection: [12]u8 = undefined;
    var cells: [12]Cell = undefined;
    for (&fields, &names, &projection, &cells, 0..) |*field, *name, *index, *cell, i| {
        field.* = .{ .name = try std.fmt.bufPrint(name, "col{d}", .{i}), .type = .int128 };
        index.* = @intCast(i);
        cell.* = integer(std.math.maxInt(i128) - @as(i128, i));
    }
    const plan: q.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = basis, .projection = &projection };
    const cancelled = f.execution.Cancellation.init(false);
    const page: s.Page = .{ .binding = basis, .ordinal = 0, .end = true, .rows = &.{.{ .cells = &cells }} };
    const result = try s.step(plan, try .start(plan), page, workspace, &output, &cancelled, null);
    try e.expectEqual(@as(u64, 1), result.progress.rows);
    var input: std.Io.Reader = .fixed(result.segment.?.bytes);
    var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(e.allocator, &input);
    defer reader.deinit();
    const physical = try reader.readSchema();
    try e.expectEqual(@as(usize, 12), physical.fields.len);
    var batch = (try reader.nextRecordBatch()).?;
    defer batch.deinit();
    try e.expectEqual(@as(usize, 1), batch.numRows());
    try e.expect((try reader.nextRecordBatch()) == null);
    var invalid = page;
    invalid.rows = &.{.{ .cells = cells[0..11] }};
    var failure: ?s.Failure = null;
    if (s.step(plan, try .start(plan), invalid, workspace, &output, &cancelled, &failure)) |_| return error.AcceptedMalformedRow else |_| {}
    try e.expectEqualDeep(s.Failure{ .operation = .validate, .row = 1, .page_row = 0 }, failure.?);
    const big = try e.allocator.alloc(u8, 600000);
    defer e.allocator.free(big);
    @memset(big, 0);
    const binary: q.Plan = .{ .schema = .{ .structure = &.{ .{ .name = "x", .type = .binary }, .{ .name = "y", .type = .binary } } }, .source_basis = basis, .projection = &.{0} };
    const value: Cell = .{ .value = .{ .atom = .{ .bytes = big } } };
    try e.expectError(error.ValueBudgetExceeded, s.step(binary, try .start(binary), .{ .binding = basis, .ordinal = 0, .end = true, .rows = &.{.{ .cells = &.{ value, value } }} }, workspace, &output, &cancelled, &failure));
    try e.expectEqualDeep(s.Failure{ .operation = .validate, .row = 1, .page_row = 0 }, failure.?);
}
