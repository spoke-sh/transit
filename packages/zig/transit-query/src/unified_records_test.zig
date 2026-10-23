const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const r = q.UnifiedRecords;
const m = q.fuze.Unified;
const p = q.protocol;
test "larger canonical request bundles use an independent immutable commitment" {
    var test_arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer test_arena.deinit();
    const Fixture = struct { kind: []const u8, wire_hex: []const u8, reference_hex: []const u8, named_wire_hex: []const u8, counted_wire_hex: []const u8 };
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
        bad.plan.output_names = &.{};
        try t.expectError(error.UnknownColumn, bad.encode(&output));
        bad = bundle;
        bad.limits.pages = 0;
        try t.expectError(error.InvalidQueryBudget, bad.encode(&output));
    }
}
test "durable source records fit unchanged values and preserve all continuation identities" {
    var test_arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer test_arena.deinit();
    const source: q.SourceDefinition = .{ .resource = 7, .source = .{ .kv = .{ .prefix = .{}, .key = .{ .type = .binary }, .value = .{ .type = .int64 } } } };
    const bundle: q.Bundle = .{ .source = source, .plan = try @import("catalog_store_test.zig").plan(test_arena.allocator(), source, &.{ 0, 1 }), .limits = .{ .pages = 1000, .segments = 500, .result_bytes = 1048576 } };
    const policy: r.Policy = .{ .peer = 9, .requests = 8, .revision = 1, .target = .{ .declaration = try q.Bundle.declaration(source) }, .allow = true, .limits = bundle.limits };
    try t.expectEqualDeep(policy, try r.Policy.decode(try policy.encode()));
    const job: r.Job = .{ .id = 100, .destination = 9, .correlation = 55, .policy_revision = 1, .source = .{ .native = .{ .pid = 3, .input = 100, .index = 0 } }, .request = try bundle.reference(8, 2), .continuation = 101 };
    try t.expectEqualDeep(job, try r.Job.decode(try job.encode()));
    const basis = try q.UnifiedSource.basis(source, 42);
    const bound = try bundle.bind(try basis.fingerprint());
    var checkpoint: r.Checkpoint = .{ .cut = basis.cut, .progress = try q.fuze.LogicalStream.Progress.start(bound) };
    checkpoint.progress.pages = 1;
    checkpoint.cursor.ordinal = 1;
    checkpoint.cursor.after = try p.Value.init(&@as([32]u8, @splat('a')));
    try t.expectEqual(@as(u16, 254), (try checkpoint.encode()).len);
    try t.expectEqualDeep(checkpoint, try r.Checkpoint.decode(try checkpoint.encode()));
    for ([_]m.SourceKind{ .table, .document }) |kind| {
        var changed = checkpoint;
        changed.cut.kind = kind;
        changed.cursor.after = null;
        if (kind == .table) changed.cursor.table_scanned = 8;
        if (kind == .table) changed.cursor.table_after = .{ .origin = 1, .operation = std.math.maxInt(u64), .ordinal = 0 } else changed.cursor.traversal = .{ .current = .{ .counter = std.math.maxInt(u64), .replica = std.math.maxInt(u64) }, .phase = .siblings };
        try t.expectEqualDeep(changed, try r.Checkpoint.decode(try changed.encode()));
    }
    const segment: r.Segment = .{ .ordinal = 0, .row_start = 0, .rows = 1, .reference = .{ .domain = .query_result, .resource = 7, .namespace = job.namespace(), .record = 1, .spec = try q.station.Publication.Digest.of(r.arrow_format, "fixture") }, .arrow_digest = @splat(3) };
    try t.expectEqualDeep(segment, try r.Segment.decode(try segment.encode()));
    checkpoint.progress.pages = 1;
    checkpoint.progress.counters.scanned = 1;
    checkpoint.progress.counters.selected = 1;
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
    try t.expectEqual(@as(usize, 405), (try manifest.encode(&output)).len);
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

test "failure records reject missing witnesses and preserve full-width budget evidence" {
    var test_arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer test_arena.deinit();
    const failure: q.QueryFailure = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .result_bytes, .limit = 1, .observed = std.math.maxInt(u64) };
    const encoded = try failure.encode();
    var expected: [q.QueryFailure.encoded_bytes]u8 = @splat(0);
    _ = try std.fmt.hexToBytes(expected[0..24], "55514631090002030100000000000000ffffffffffffffff");
    try t.expectEqualSlices(u8, &expected, encoded.slice());
    try t.expectEqualDeep(failure, try q.QueryFailure.decode(encoded));
    inline for (std.meta.tags(q.QueryFailure.Code)) |code| {
        const value: q.QueryFailure = .{ .code = code, .stage = .admission };
        try t.expectEqualDeep(value, try q.QueryFailure.decode(try value.encode()));
        try t.expect(value.message().len != 0);
    }
    try t.expect(q.QueryFailure.fromError(error.OutOfMemory, .execution) == null);
    try t.expect(q.QueryFailure.fromError(error.ReadFailed, .execution) == null);
    for (0..encoded.len) |length| try t.expectError(error.InvalidQueryFailure, q.QueryFailure.decode(try p.Value.init(encoded.slice()[0..length])));
    var invalid = failure;
    invalid.observed = 1;
    try t.expectError(error.InvalidQueryFailure, invalid.encode());
    invalid = failure;
    invalid.code = .arithmetic_overflow;
    try t.expectError(error.InvalidQueryFailure, invalid.encode());
    const source: q.SourceDefinition = .{ .resource = 7, .source = .{ .kv = .{ .prefix = .{}, .key = .{ .type = .binary }, .value = .{ .type = .int64 } } } };
    const bundle: q.Bundle = .{ .source = source, .plan = try @import("catalog_store_test.zig").plan(test_arena.allocator(), source, &.{1}), .limits = .{ .pages = 10, .segments = 10, .result_bytes = 1024 } };
    var job: r.Job = .{ .id = 100, .destination = 9, .correlation = 55, .policy_revision = 1, .source = .{ .native = .{ .pid = 3, .input = 100, .index = 0 } }, .request = try bundle.reference(8, 2), .continuation = 101, .phase = .failed };
    try t.expectError(error.InvalidQueryRecord, job.encode());
    job.failure = failure;
    const stored = try job.encode();
    try t.expectEqualDeep(job, try r.Job.decode(stored));
    for (0..stored.len) |length| {
        if (r.Job.decode(try p.Value.init(stored.slice()[0..length]))) |_| return error.AcceptedTruncatedFailure else |_| {}
    }
    var status: q.UnifiedRequest.Status = .{ .reference = job.request, .phase = .rejected, .correlation = 55 };
    try t.expectError(error.InvalidQueryUpload, status.encode());
    status.failure = failure;
    try t.expectEqualDeep(status, try q.UnifiedRequest.Status.decode(try status.encode()));
    status.phase = .denied;
    try t.expectError(error.InvalidQueryUpload, status.encode());
    status.phase = .retired;
    try t.expectEqualDeep(status, try q.UnifiedRequest.Status.decode(try status.encode()));
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const neutral = try q.Bridge.Status.fromNative(arena.allocator(), status);
    try t.expectEqualStrings("18446744073709551615", neutral.failure.?.observed);
    const diagnostic = neutral.diagnostic.?;
    try t.expectEqual(p.Diagnostic.Outcome.retired, diagnostic.outcome);
    try t.expectEqualStrings("query.budget_exceeded", diagnostic.code.slice());
    try t.expectEqual(std.math.maxInt(u64), try diagnostic.facts[2].?.value.?.unsigned.value());
    var json: [p.Diagnostic.max_json_bytes]u8 = undefined;
    try t.expectEqualDeep(diagnostic, try p.Diagnostic.decode(t.allocator, try diagnostic.encode(&json)));
    // Old payloads, changed reserved bytes and truncated witnesses cannot be
    // treated as the current saved outcome or quietly default their evidence.
    try t.expectError(error.InvalidQueryFailure, q.QueryFailure.decode(try p.Value.init(encoded.slice()[0..24])));
    var reserved = encoded;
    reserved.data[111] = 1;
    try t.expectError(error.InvalidQueryFailure, q.QueryFailure.decode(reserved));
}

test "query policies bind explicit catalog delegation and reject old foreign or truncated records" {
    var test_arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer test_arena.deinit();
    const fixtures = try std.json.parseFromSlice([]const struct { wire_hex: []const u8, target: u8 }, t.allocator, @embedFile("fixtures/query-policy.json"), .{});
    defer fixtures.deinit();
    for (fixtures.value) |fixture| {
        var buffer: [r.Policy.max_bytes]u8 = undefined;
        const bytes = try std.fmt.hexToBytes(&buffer, fixture.wire_hex);
        const value = try p.Value.init(bytes);
        const policy = try r.Policy.decode(value);
        try t.expectEqualSlices(u8, bytes, (try policy.encode()).slice());
        try t.expectEqual(fixture.target, @backingInt(std.meta.activeTag(policy.target)));
        if (policy.target == .catalog) {
            try t.expectEqual(std.math.maxInt(u64), policy.target.catalog.scope.catalog);
            try t.expectEqual(@as(u64, 17), policy.target.catalog.principal);
            try t.expect(!policy.target.declarationMatches(@splat(0)));
        } else try t.expect(policy.target.declarationMatches(policy.target.declaration));
        for (0..bytes.len) |length| {
            if (r.Policy.decode(try p.Value.init(bytes[0..length]))) |_| return error.AcceptedTruncatedPolicy else |_| {}
        }
        var malformed = value;
        malformed.data[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, r.Policy.decode(malformed));
        malformed = value;
        malformed.data[60] = 0;
        try t.expectError(error.InvalidQueryPolicy, r.Policy.decode(malformed));
        malformed = value;
        malformed.data[malformed.len] = 0;
        malformed.len += 1;
        try t.expectError(error.InvalidQueryRecord, r.Policy.decode(malformed));
    }
    // Superseded 85-byte policies have no definition or target discriminator.
    var old: [85]u8 = @splat(0);
    old[0..4].* = "UQA1".*;
    try t.expectError(error.IncompatibleDefinition, r.Policy.decode(try p.Value.init(&old)));
}
