const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const r = q.UnifiedRecords;
const m = q.fuze.Unified;
const p = q.protocol;
test "larger canonical request bundles use an independent immutable commitment" {
    const Fixture = struct { kind: []const u8, wire_hex: []const u8, reference_hex: []const u8 };
    const cases = try std.json.parseFromSlice([]Fixture, t.allocator, @embedFile("fixtures/bundles.json"), .{});
    defer cases.deinit();
    for (cases.value) |case| {
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        var buffer: [q.Bundle.max_bytes]u8 = undefined;
        const bytes = try std.fmt.hexToBytes(&buffer, case.wire_hex);
        const bundle = try q.Bundle.decode(arena.allocator(), bytes);
        try t.expectEqualStrings(case.kind, @tagName(bundle.source.source));
        var output: [q.Bundle.max_bytes]u8 = undefined;
        try t.expectEqualSlices(u8, bytes, try bundle.encode(&output));
        var ref_bytes: [q.station.PublicationReference.encoded_bytes]u8 = undefined;
        const expected = try q.station.PublicationReference.decode(try p.Value.init(try std.fmt.hexToBytes(&ref_bytes, case.reference_hex)));
        const ref = try bundle.reference(8, std.math.maxInt(u64));
        try t.expectEqualDeep(expected, ref);
        if (bundle.source.source != .kv) try t.expect(bytes.len > q.station.Frame.max_payload);
        if (bundle.source.source == .document) {
            var changed = bundle.source;
            changed.source.document.reference.revision += 1;
            try t.expectEqualSlices(u8, &try q.Bundle.declaration(bundle.source), &try q.Bundle.declaration(changed));
            try t.expect(!std.mem.eql(u8, &try bundle.source.fingerprint(), &try changed.fingerprint()));
            changed.source.document.reference.epoch += 1;
            try t.expect(!std.mem.eql(u8, &try q.Bundle.declaration(bundle.source), &try q.Bundle.declaration(changed)));
        }
        for (0..@min(bytes.len, 40)) |len| {
            if (q.Bundle.decode(arena.allocator(), bytes[0..len])) |_| return error.AcceptedTruncatedBundle else |_| {}
        }
        var bad = bundle;
        bad.plan.projection = &.{7};
        try t.expectError(error.UnknownColumn, bad.encode(&output));
        bad = bundle;
        bad.limits.pages = 0;
        try t.expectError(error.InvalidQueryBudget, bad.encode(&output));
    }
}
test "durable source records fit unchanged values and preserve all continuation identities" {
    const source: q.SourceDefinition = .{ .resource = 7, .source = .{ .kv = .{ .prefix = .{}, .key = .{ .type = .binary }, .value = .{ .type = .int64 } } } };
    const bundle: q.Bundle = .{ .source = source, .plan = .{ .projection = &.{ 0, 1 } }, .limits = .{ .pages = 1000, .segments = 500, .result_bytes = 1048576 } };
    const policy: r.Policy = .{ .peer = 9, .requests = 8, .revision = 1, .declaration = try q.Bundle.declaration(source), .allow = true, .limits = bundle.limits };
    try t.expectEqualDeep(policy, try r.Policy.decode(try policy.encode()));
    const job: r.Job = .{ .id = 100, .destination = 9, .correlation = 55, .policy_revision = 1, .source = .{ .pid = 3, .input = 100, .index = 0 }, .request = try bundle.reference(8, 2), .continuation = 101 };
    try t.expectEqualDeep(job, try r.Job.decode(try job.encode()));
    var columns: [m.max_columns]m.Column = undefined;
    const bound = try bundle.plan.bind(try q.UnifiedSource.basis(source, 42), try source.schema(&columns));
    var checkpoint: r.Checkpoint = .{ .progress = m.Stream.Progress.start(bound) };
    checkpoint.cursor.after = try p.Value.init(&@as([32]u8, @splat('a')));
    try t.expectEqual(@as(u16, 246), (try checkpoint.encode()).len);
    try t.expectEqualDeep(checkpoint, try r.Checkpoint.decode(try checkpoint.encode()));
    for ([_]m.SourceKind{ .table, .document }) |kind| {
        var changed = checkpoint;
        changed.progress.basis.kind = kind;
        changed.cursor.after = null;
        if (kind == .table) changed.cursor.table_after = std.math.minInt(i64) else changed.cursor.traversal = .{ .current = .{ .counter = std.math.maxInt(u64), .replica = std.math.maxInt(u64) }, .phase = .siblings };
        try t.expectEqualDeep(changed, try r.Checkpoint.decode(try changed.encode()));
    }
    const segment: r.Segment = .{ .ordinal = 0, .row_start = 0, .rows = 1, .reference = .{ .domain = .query_result, .resource = 7, .namespace = job.namespace(), .record = 1, .spec = try q.station.Publication.Digest.of(r.arrow_format, "fixture") }, .arrow_digest = @splat(3) };
    try t.expectEqualDeep(segment, try r.Segment.decode(try segment.encode()));
    checkpoint.progress.pages = 1;
    checkpoint.progress.scanned = 1;
    checkpoint.progress.selected = 1;
    checkpoint.progress.segments = 1;
    checkpoint.progress.rows = 1;
    checkpoint.progress.finished = .source_end;
    checkpoint.cursor.ordinal = 1;
    checkpoint.cursor.done = true;
    checkpoint.bytes = 7;
    checkpoint.chain = try segment.extend(checkpoint.chain);
    var complete = job;
    complete.phase = .complete;
    const manifest: r.Manifest = .{ .job = complete, .checkpoint = checkpoint };
    var output: [r.Manifest.max_bytes]u8 = undefined;
    try t.expectEqualDeep(manifest, try r.Manifest.decode(try manifest.encode(&output)));
    try t.expectEqual(@as(usize, 396), (try manifest.encode(&output)).len);
    for ([_]p.Value{ try policy.encode(), try job.encode(), try checkpoint.encode(), try segment.encode() }, 0..) |value, kind| {
        var bad = value;
        bad.data[0] = 'X';
        switch (kind) {
            0 => try t.expectError(error.InvalidQueryRecord, r.Policy.decode(bad)),
            1 => try t.expectError(error.InvalidQueryRecord, r.Job.decode(bad)),
            2 => try t.expectError(error.InvalidQueryRecord, r.Checkpoint.decode(bad)),
            3 => try t.expectError(error.InvalidQueryRecord, r.Segment.decode(bad)),
            else => unreachable,
        }
    }
    const continuation: r.Continuation = .{ .job = p.max_counter, .input = p.max_counter };
    try t.expectEqualDeep(continuation, try r.Continuation.decode(try continuation.encode()));
}
