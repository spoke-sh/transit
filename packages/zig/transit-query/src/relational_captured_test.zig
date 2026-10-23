//! Codec and binding inputs only. Public direct-capture/failure schedules own
//! runtime retention, publication, budget, overflow and cleanup evidence.
const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const Fixture = @import("direct_query_fixture_test.zig");
const Captured = q.RelationalCaptured;
const Bundle = q.RelationalBundle;
fn roundtrip(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var owned = try Bundle.decode(allocator, bytes);
    defer owned.deinit();
    var output: [Bundle.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try owned.bundle.encode(&output));
}
test "direct captured bundles preserve signed grants across truncation and allocation failure" {
    var fixture = try Fixture.init(t.allocator, .captured, false);
    defer fixture.deinit();
    var bytes: [Bundle.max_bytes]u8 = undefined;
    const encoded = try fixture.bundle.encode(&bytes);
    try roundtrip(t.allocator, encoded);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), roundtrip, .{encoded});
    for (0..encoded.len) |size| {
        if (Bundle.decode(t.allocator, encoded[0..size])) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.AcceptedIncompleteBundle;
        } else |_| {}
    }
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Bundle.decode(t.allocator, encoded));
    bytes[4] ^= 1;
    // The former resource-wide cut tag cannot be reinterpreted as a Table cut.
    bytes[36] = 1;
    try t.expectError(error.UnsupportedRelationalConsistency, Bundle.decode(t.allocator, encoded));
    bytes[36] = 2;
    var sources = fixture.bundle.plan.sources[0..2].*;
    sources[0].schema.revision += 1;
    var changed = fixture.bundle;
    changed.plan.sources = &sources;
    try t.expectError(error.RelationalSourceChanged, changed.validate());
}
test "direct captured vectors bind independent partitions and share only exact Table aliases" {
    for ([_]bool{ false, true }) |independent| {
        var fixture = try Fixture.init(t.allocator, .captured, independent);
        defer fixture.deinit();
        const bundle = fixture.bundle;
        var vector: Captured.Vector = .{ .request = try bundle.fingerprint(), .count = 2 };
        for (fixture.vector.entries[0..2], vector.entries[0..2]) |source, *entry| entry.* = .{ .partition = source.record.basis.accepted.partition, .position = source.position, .commitment = try source.record.basis.fingerprint() };
        const encoded = try vector.encode(bundle);
        try t.expectEqualDeep(vector, try Captured.Vector.decode(bundle, encoded));
        for (0..encoded.len) |size| {
            _ = Captured.Vector.decode(bundle, try q.protocol.Value.init(encoded.slice()[0..size])) catch continue;
            return error.AcceptedIncompleteVector;
        }
        var foreign = encoded;
        foreign.data[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, Captured.Vector.decode(bundle, foreign));
        try t.expectEqual(@as(u32, if (independent) 1 else 0), (try Captured.slot(bundle, 42, 1)).source);
        var cuts: [q.fuze.Relational.max_sources]q.fuze.Relational.Cut = undefined;
        try vector.boundCuts(bundle, &cuts);
        try t.expectEqual(independent, !std.meta.eql(cuts[0].domain, cuts[1].domain));
        vector.entries[1].position += 1;
        if (!independent) try t.expectError(error.InconsistentRelationalCut, vector.validate(bundle)) else try vector.validate(bundle);
        vector.entries[1] = vector.entries[0];
        vector.entries[0].commitment = @splat(0);
        try t.expectError(error.InvalidRelationalCapture, vector.validate(bundle));
    }
}
