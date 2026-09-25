const std = @import("std");
const t = std.testing;
const f = @import("root.zig");
const s = f.Stream;
const m = f.model;
const schema: m.Schema = .{ .names = .{ m.Name.init("id") catch unreachable, m.Name.init("value") catch unreachable }, .value_type = .int64 };
fn source(rows: []const m.Row) !m.Source {
    return .{ .basis = .{ .resource = 7, .revision = 9, .schema = try schema.fingerprint() }, .schema = schema, .rows = rows };
}
fn bound(plan: s.Plan) !s.Bound {
    return plan.bind((try source(&.{})).basis, schema);
}
fn scalar(bytes: []const u8) !?i64 {
    var buffer = std.Io.Reader.fixed(bytes);
    var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(t.allocator, &buffer);
    defer reader.deinit();
    _ = try reader.readSchema();
    var batch = (try reader.nextRecordBatch()).?;
    defer batch.deinit();
    try t.expectEqual(@as(usize, 1), batch.numRows());
    const column = batch.column(0);
    const values: f.arrow.Int64Array = .{ .data = column.data() };
    const result: ?i64 = if (values.isNull(0)) null else try values.value(0);
    try t.expect((try reader.nextRecordBatch()) == null);
    return result;
}

test "incremental filter and limit span pages and owned progress without a total row ceiling" {
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [8192]u8 = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    var rows: [70]m.Row = undefined;
    for (&rows, 0..) |*row, i| row.* = .{ .key = @intCast(i), .value = if (i % 5 == 0) .null else .{ .int64 = @intCast(i * 10) } };
    const physical = try bound(.{ .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .int64 = 3 } } }, .limit = 37 });
    var progress = physical.start();
    var expected: i64 = 3;
    for (0..9) |i| {
        const next = try s.step(physical, progress, .{ .ordinal = i, .source = try source(rows[i * 8 .. @min(rows.len, i * 8 + 8)]), .end = i == 8 }, &workspace, &output, &cancellation);
        if (next.segment) |segment| {
            var buffer = std.Io.Reader.fixed(segment.bytes);
            var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(t.allocator, &buffer);
            defer reader.deinit();
            _ = try reader.readSchema();
            var batch = (try reader.nextRecordBatch()).?;
            defer batch.deinit();
            const keys: f.arrow.Int64Array = .{ .data = batch.column(0).data() };
            for (0..batch.numRows()) |at| {
                try t.expectEqual(expected, try keys.value(at));
                expected += 1;
            }
            try t.expect((try reader.nextRecordBatch()) == null);
        }
        progress = try s.Progress.decode(&try next.progress.encode());
        try t.expect(std.meta.eql(progress, next.progress));
        if (progress.finished != null) break;
    }
    try t.expectEqual(@as(u64, 37), progress.rows);
    try t.expectEqual(@as(u64, 40), progress.scanned);
    try t.expectEqual(@as(i64, 40), expected);
    try t.expectEqual(s.Finish.limit, progress.finished.?);
    try t.expectError(error.QueryComplete, s.step(physical, progress, .{ .ordinal = progress.pages, .source = try source(&.{}), .end = true }, &workspace, &output, &cancellation));

    inline for (.{ .count, .sum }) |aggregate| {
        const query = try bound(.{ .aggregate = aggregate, .projection = .{ 1, null } });
        progress = query.start();
        for (0..10) |i| {
            // An empty non-terminal page is not completion.
            const input = if (i == 0) try source(&.{}) else try source(rows[(i - 1) * 8 .. @min(rows.len, i * 8)]);
            const next = try s.step(query, progress, .{ .ordinal = i, .source = input, .end = i == 9 }, &workspace, &output, &cancellation);
            try t.expectEqual(i == 9, next.segment != null);
            if (next.segment) |segment| try t.expectEqual(@as(?i64, if (aggregate == .count) 70 else 19600), try scalar(segment.bytes));
            progress = try s.Progress.decode(&try next.progress.encode());
        }
        try t.expectEqual(@as(u64, 70), progress.selected);
        try t.expectEqual(@as(u64, 1), progress.rows);
        try t.expectEqual(s.Finish.source_end, progress.finished.?);
    }
}

test "incremental sum preserves global overflow order and all-null semantics" {
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [8192]u8 = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    const query = try bound(.{ .aggregate = .sum, .projection = .{ 1, null } });
    for ([_]i64{ std.math.maxInt(i64), std.math.minInt(i64) }) |edge| {
        const first = try s.step(query, query.start(), .{ .ordinal = 0, .source = try source(&.{.{ .key = 0, .value = .{ .int64 = edge } }}), .end = false }, &workspace, &output, &cancellation);
        const delta: i64 = if (edge > 0) 1 else -1;
        try t.expectError(error.Overflow, s.step(query, first.progress, .{ .ordinal = 1, .source = try source(&.{ .{ .key = 1, .value = .{ .int64 = delta } }, .{ .key = 2, .value = .{ .int64 = -delta } } }), .end = true }, &workspace, &output, &cancellation));
        try t.expectEqual(@as(?i64, edge), first.progress.sum);
    }
    const first = try s.step(query, query.start(), .{ .ordinal = 0, .source = try source(&.{.{ .key = 0, .value = .null }}), .end = false }, &workspace, &output, &cancellation);
    try t.expect(first.progress.sum == null and first.segment == null);
    const last = try s.step(query, first.progress, .{ .ordinal = 1, .source = try source(&.{}), .end = true }, &workspace, &output, &cancellation);
    try t.expectEqual(@as(?i64, null), try scalar(last.segment.?.bytes));
}

test "incremental steps reject changed evidence and preserve progress through allocation output and cancellation faults" {
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [8192]u8 = undefined;
    var cancellation = f.execution.Cancellation.init(false);
    const query = try bound(.{});
    const input: s.Page = .{ .ordinal = 0, .source = try source(&.{.{ .key = 1, .value = .{ .int64 = 7 } }}), .end = false };
    const initial = query.start();
    try t.expectError(error.OutOfMemory, s.step(query, initial, input, workspace[0..1], &output, &cancellation));
    try t.expectError(error.WriteFailed, s.step(query, initial, input, &workspace, output[0..1], &cancellation));
    cancellation.store(true, .release);
    try t.expectError(error.Cancelled, s.step(query, initial, input, &workspace, &output, &cancellation));
    cancellation.store(false, .release);
    const good = try s.step(query, initial, input, &workspace, &output, &cancellation);
    const digest = good.segment.?.digest;
    const retry = try s.step(query, initial, input, &workspace, &output, &cancellation);
    try t.expectEqualSlices(u8, &digest, &retry.segment.?.digest);
    try t.expectEqual(@as(u64, 0), initial.pages);
    var changed = input;
    changed.ordinal = 2;
    try t.expectError(error.InvalidQueryOrdinal, s.step(query, initial, changed, &workspace, &output, &cancellation));
    changed.ordinal = 1;
    try t.expectError(error.UnorderedSource, s.step(query, good.progress, changed, &workspace, &output, &cancellation));
    changed = input;
    changed.source.basis.revision += 1;
    try t.expectError(error.SourceChanged, s.step(query, initial, changed, &workspace, &output, &cancellation));
    var other = query;
    other.logical.limit = 100;
    try t.expectError(error.SourceChanged, s.step(other, initial, input, &workspace, &output, &cancellation));
    const different = try bound(.{ .limit = 100 });
    try t.expectError(error.SourceChanged, s.step(different, initial, input, &workspace, &output, &cancellation));
    var encoding = try initial.encode();
    encoding[134] = 1; // A null sum cannot hide noncanonical bytes.
    try t.expectError(error.InvalidQueryProgress, s.Progress.decode(&encoding));
    encoding = try good.progress.encode();
    encoding[124] = 2;
    try t.expectError(error.InvalidQueryProgress, s.Progress.decode(&encoding));
    try t.expectError(error.InvalidQueryProgress, s.Progress.decode(encoding[0..100]));
    const zero = try bound(.{ .limit = 0 });
    const empty = try s.step(zero, zero.start(), input, &workspace, &output, &cancellation);
    try t.expect(empty.progress.finished == .limit and empty.progress.scanned == 0);
    try t.expectEqual(@as(u8, 0), empty.segment.?.rows);
    const count = try bound(.{ .aggregate = .count });
    var huge = count.start();
    huge.scanned = std.math.maxInt(i64);
    huge.pages = huge.scanned / m.max_rows + 1;
    huge.selected = huge.scanned;
    huge.last_key = 0;
    changed = input;
    changed.ordinal = huge.pages;
    changed.end = true;
    try t.expectError(error.Overflow, s.step(count, huge, changed, &workspace, &output, &cancellation));
}

test "durable plan codec owns all admitted literals and rejects truncation aliases and incompatible versions" {
    const cells = [_]m.Cell{ .null, .{ .int64 = std.math.minInt(i64) }, .{ .int64 = std.math.maxInt(i64) }, .{ .boolean = true }, .{ .utf8 = try m.Bytes.init("東京") }, .{ .binary = try m.Bytes.init(&@as([m.max_cell_bytes]u8, @splat(255))) } };
    var bytes: [s.PlanCodec.encoded_bytes + 1]u8 = undefined;
    for (cells) |cell| {
        const plan: s.Plan = .{ .predicate = .{ .compare = .{ .column = 1, .op = .eq, .value = cell } }, .limit = std.math.maxInt(u64), .projection = .{ 1, null } };
        const encoded = try s.PlanCodec.encode(plan, &bytes);
        try t.expect(std.meta.eql(plan, try s.PlanCodec.decode(encoded)));
        for (0..encoded.len) |len| {
            if (s.PlanCodec.decode(encoded[0..len])) |_| return error.TruncatedPlanAccepted else |_| {}
        }
        try t.expectError(error.InvalidPlanEncoding, s.PlanCodec.decode(bytes[0 .. encoded.len + 1]));
    }
    const defaults: s.Plan = .{};
    const encoded = try s.PlanCodec.encode(defaults, &bytes);
    try t.expect(std.meta.eql(defaults, try s.PlanCodec.decode(encoded)));
    bytes[8] = 1; // Absent limit has canonical zero bytes.
    try t.expectError(error.InvalidPlanEncoding, s.PlanCodec.decode(encoded));
    _ = try s.PlanCodec.encode(defaults, &bytes);
    bytes[7] = 2;
    try t.expectError(error.InvalidPlanEncoding, s.PlanCodec.decode(encoded));
    _ = try s.PlanCodec.encode(defaults, &bytes);
    bytes[3] = '2';
    try t.expectError(error.InvalidPlanEncoding, s.PlanCodec.decode(encoded));
    try t.expectError(error.WriteFailed, s.PlanCodec.encode(defaults, bytes[0..1]));
    try t.expectError(error.UnsupportedPlan, s.PlanCodec.encode(.{ .version = 2 }, &bytes));
    var padded = try m.Bytes.init("one");
    padded.data[100] = 1;
    try t.expectError(error.InvalidPlanEncoding, s.PlanCodec.encode(.{ .predicate = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .utf8 = padded } } } }, &bytes));
    inline for (.{ .count, .sum }) |aggregate| {
        const plan: s.Plan = .{ .aggregate = aggregate, .projection = .{ 1, null }, .predicate = .{ .is_null = 1 }, .limit = 0 };
        try t.expect(std.meta.eql(plan, try s.PlanCodec.decode(try s.PlanCodec.encode(plan, &bytes))));
    }
}
