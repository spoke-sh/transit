const std = @import("std");
const t = std.testing;
const f = @import("root.zig");
const m = f.Unified;
const s = m.Stream;
const schema: m.Schema = .{ .columns = &.{.{ .name = m.Name.init("value") catch unreachable, .type = .int64 }} };
fn bound(plan: m.Plan) !m.Plan.Bound {
    return plan.bind(.{ .kind = .table, .resource = 7, .revision = 9, .contract = @splat(1), .schema = try schema.fingerprint() }, schema);
}

test "current stream preserves all-null aggregates and signed overflow order" {
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [8192]u8 = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    const query = try bound(.{ .aggregate = .sum, .projection = &.{0} });
    for ([_]i64{ std.math.maxInt(i64), std.math.minInt(i64) }) |edge| {
        const first = try s.step(query, .start(query), .{ .basis = query.basis, .ordinal = 0, .rows = &.{.{ .cells = &.{.{ .value = .{ .int64 = edge } }} }}, .end = false }, workspace, &output, &cancellation);
        const delta: i64 = if (edge > 0) 1 else -1;
        try t.expectError(error.Overflow, s.step(query, first.progress, .{ .basis = query.basis, .ordinal = 1, .rows = &.{ .{ .cells = &.{.{ .value = .{ .int64 = delta } }} }, .{ .cells = &.{.{ .value = .{ .int64 = -delta } }} } }, .end = true }, workspace, &output, &cancellation));
        try t.expectEqual(@as(?i64, edge), first.progress.sum);
    }
    const first = try s.step(query, .start(query), .{ .basis = query.basis, .ordinal = 0, .rows = &.{.{ .cells = &.{.null} }}, .end = false }, workspace, &output, &cancellation);
    try t.expect(first.progress.sum == null and first.segment == null);
    const last = try s.step(query, first.progress, .{ .basis = query.basis, .ordinal = 1, .rows = &.{}, .end = true }, workspace, &output, &cancellation);
    var decoded: m.Inspect.Batch = undefined;
    try m.Inspect.decode(.{ .columns = &.{.{ .name = try m.Name.init("sum"), .type = .int64 }} }, last.segment.?.bytes, 1, workspace, t.allocator, &decoded);
    try t.expect(decoded.cells[0][0] == .null);
}

test "current steps retry exactly after allocation output and cancellation faults" {
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [8192]u8 = undefined;
    var cancellation = f.execution.Cancellation.init(false);
    const query = try bound(.{ .projection = &.{0} });
    const input: m.Page = .{ .basis = query.basis, .ordinal = 0, .rows = &.{.{ .cells = &.{.{ .value = .{ .int64 = 7 } }} }}, .end = false };
    const initial = s.Progress.start(query);
    try t.expectError(error.OutOfMemory, s.step(query, initial, input, workspace[0..1], &output, &cancellation));
    try t.expectError(error.WriteFailed, s.step(query, initial, input, workspace, output[0..1], &cancellation));
    cancellation.store(true, .release);
    try t.expectError(error.Cancelled, s.step(query, initial, input, workspace, &output, &cancellation));
    cancellation.store(false, .release);
    const good = try s.step(query, initial, input, workspace, &output, &cancellation);
    const digest = good.segment.?.digest;
    const retry = try s.step(query, initial, input, workspace, &output, &cancellation);
    try t.expectEqualSlices(u8, &digest, &retry.segment.?.digest);
    try t.expectEqual(@as(u64, 0), initial.pages);
    var other = query;
    other.plan.limit = 100;
    try t.expectError(error.SourceChanged, s.step(other, initial, input, workspace, &output, &cancellation));
    const different = try bound(.{ .projection = &.{0}, .limit = 100 });
    try t.expectError(error.SourceChanged, s.step(different, initial, input, workspace, &output, &cancellation));
    var encoding = try initial.encode();
    encoding[158] = 1; // Absent sum must have canonical zero bytes.
    try t.expectError(error.InvalidQueryProgress, s.Progress.decode(&encoding));
    encoding = try good.progress.encode();
    encoding[157] = 2; // Presence is a boolean.
    try t.expectError(error.InvalidQueryProgress, s.Progress.decode(&encoding));
    try t.expectError(error.InvalidQueryProgress, s.Progress.decode(encoding[0..100]));
    const count = try bound(.{ .projection = &.{0}, .aggregate = .count });
    var huge = s.Progress.start(count);
    huge.scanned = std.math.maxInt(i64);
    huge.pages = huge.scanned / m.max_rows + 1;
    huge.selected = huge.scanned;
    var changed = input;
    changed.ordinal = huge.pages;
    changed.end = true;
    const wide = try s.step(count, huge, changed, workspace, &output, &cancellation);
    try t.expectEqual(@as(u64, 1) << 63, wide.progress.selected);
    huge.scanned = std.math.maxInt(u64);
    huge.pages = huge.scanned / m.max_rows + 1;
    huge.selected = huge.scanned;
    changed.ordinal = huge.pages;
    try t.expectError(error.Overflow, s.step(count, huge, changed, workspace, &output, &cancellation));
}

test "current plan codec rejects truncation aliases and incompatible definitions" {
    const cells = [_]m.Scalar{ .{ .int64 = std.math.minInt(i64) }, .{ .uint64 = std.math.maxInt(u64) }, .{ .boolean = true }, .{ .utf8 = "東京" }, .{ .binary = &@as([220]u8, @splat(255)) } };
    var bytes: [m.Codec.max_plan_bytes + 1]u8 = undefined;
    var canonical: [m.Codec.max_plan_bytes]u8 = undefined;
    for (cells) |cell| {
        const plan: m.Plan = .{ .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = cell } }, .limit = std.math.maxInt(u64), .projection = &.{0} };
        const encoded = try m.Codec.encode(plan, &bytes);
        try t.expectEqualSlices(u8, encoded, try m.Codec.encode(try m.Codec.decode(encoded), &canonical));
        for (0..encoded.len) |len| {
            if (m.Codec.decode(encoded[0..len])) |_| return error.TruncatedPlanAccepted else |_| {}
        }
        try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(bytes[0 .. encoded.len + 1]));
    }
    const defaults: m.Plan = .{ .projection = &.{0} };
    const encoded = try m.Codec.encode(defaults, &bytes);
    bytes[8] = 1; // Absent limit has canonical zero bytes.
    try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(encoded));
    _ = try m.Codec.encode(defaults, &bytes);
    bytes[7] = 2;
    try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(encoded));
    _ = try m.Codec.encode(defaults, &bytes);
    bytes[3] = '2';
    try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(encoded));
    try t.expectError(error.WriteFailed, m.Codec.encode(defaults, bytes[0..1]));
    try t.expectError(error.UnsupportedPlan, m.Codec.encode(.{ .version = 2, .projection = &.{0} }, &bytes));
    inline for (.{ .count, .sum }) |aggregate| {
        const plan: m.Plan = .{ .aggregate = aggregate, .projection = &.{0}, .predicate = .{ .state = .{ .column = 0, .value = .null } }, .limit = 0 };
        const wire = try m.Codec.encode(plan, &bytes);
        try t.expectEqualSlices(u8, wire, try m.Codec.encode(try m.Codec.decode(wire), &canonical));
    }
}
