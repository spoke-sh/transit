//! Offline vector/cursor contracts. Runtime recovery, no-op, gap and current
//! permission schedules run through tests/direct_maintained_query.zig and
//! tests/direct_relational_failures.zig against the public direct service.
const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const History = q.RelationalHistory;
const Fixture = @import("direct_query_fixture_test.zig");

test "direct history vectors preserve independent Table cuts and exact alias identity" {
    for ([_]bool{ false, true }) |independent| {
        var fixture = try Fixture.init(t.allocator, .maintained, independent);
        defer fixture.deinit();
        const bundle = fixture.bundle;
        const initial = fixture.vector;
        var after = initial;
        after.entries[0].position += 2;
        after.entries[0].record.basis.accepted.next_lsn += 2;
        after.entries[0].record.record.?[0] ^= 1;
        if (!independent) {
            try t.expectError(error.InconsistentRelationalCut, after.validate(bundle));
            after.entries[1] = after.entries[0];
        }
        try after.validate(bundle);
        // An accepted no-op changes the selected acceptance commitment without
        // claiming that the row-change frontier advanced.
        try t.expectEqual(initial.entries[0].record.basis.changed_lsn, after.entries[0].record.basis.changed_lsn);
        try t.expect(!std.mem.eql(u8, &try initial.fingerprint(bundle), &try after.fingerprint(bundle)));
        if (independent) try t.expectEqualDeep(initial.entries[1], after.entries[1]);
        var cuts: [q.fuze.Relational.max_sources]q.fuze.Relational.Cut = undefined;
        try after.boundCuts(bundle, &cuts);
        try t.expectEqual(independent, !std.meta.eql(cuts[0].domain, cuts[1].domain));
        try t.expectEqual(after.entries[0].position, cuts[0].revision);
        var bytes: [History.Vector.max_bytes]u8 = undefined;
        const encoded = try after.encode(bundle, &bytes);
        try t.expectEqualDeep(after, try History.Vector.decode(bundle, encoded));
        for (0..encoded.len) |length| {
            _ = History.Vector.decode(bundle, encoded[0..length]) catch continue;
            return error.AcceptedTruncatedHistory;
        }
        bytes[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, History.Vector.decode(bundle, encoded));
        var shifted = after;
        shifted.entries[0].position -= 1;
        try t.expectError(error.InvalidRelationalHistory, shifted.validate(bundle));
    }
}

test "direct history scan cursors bind the preceding vector and fixed independent upper bounds" {
    var fixture = try Fixture.init(t.allocator, .maintained, true);
    defer fixture.deinit();
    const bundle = fixture.bundle;
    const vector = fixture.vector;
    var scan: History.Scan = .{ .basis = try vector.fingerprint(bundle), .count = 2, .preference = 1, .cursors = .{ 10, 12 }, .uppers = .{ 30, 12 } };
    const encoded = try scan.encode(bundle, vector);
    try t.expectEqualDeep(scan, try History.Scan.decode(bundle, vector, encoded));
    for (0..encoded.len) |length| {
        _ = History.Scan.decode(bundle, vector, try q.protocol.Value.init(encoded.slice()[0..length])) catch continue;
        return error.AcceptedTruncatedHistory;
    }
    scan.cursors[0] = 31;
    try t.expectError(error.InvalidRelationalHistory, scan.validate(bundle, vector));
    scan.cursors[0] = 9;
    try t.expectError(error.InvalidRelationalHistory, scan.validate(bundle, vector));
    scan.cursors[0] = 10;
    scan.preference = 2;
    try t.expectError(error.InvalidRelationalHistory, scan.validate(bundle, vector));
    scan.preference = 1;
    var other = vector;
    other.entries[0].record.record.?[0] ^= 1;
    try t.expectError(error.InvalidRelationalHistory, scan.validate(bundle, other));
}

test "direct finite exchange vectors cannot be advanced as maintained history" {
    var fixture = try Fixture.init(t.allocator, .captured, false);
    defer fixture.deinit();
    const bundle = fixture.bundle;
    const vector = fixture.vector;
    var bytes: [History.Vector.max_bytes]u8 = undefined;
    try t.expectEqualDeep(vector, try History.Vector.decode(bundle, try vector.encode(bundle, &bytes)));
    try t.expect(vector.entries[0].record.point() == null);
    const scan: History.Scan = .{ .basis = try vector.fingerprint(bundle), .count = 2, .preference = 0, .cursors = .{ 10, 10 }, .uppers = .{ 10, 10 } };
    try t.expectError(error.InvalidRelationalHistory, scan.validate(bundle, vector));
    var changed = vector;
    changed.entries[0].record.basis.accepted.next_lsn += 1;
    changed.entries[0].position += 1;
    changed.entries[1] = changed.entries[0];
    try t.expectError(error.TableDelegationDenied, changed.validate(bundle));
}

test "direct history vectors reject schema reinterpretation and retired definitions" {
    var fixture = try Fixture.init(t.allocator, .maintained, true);
    defer fixture.deinit();
    var changed = fixture.vector;
    changed.entries[0].record.basis.interpretation.schema_fingerprint[0] ^= 1;
    try t.expectError(error.TableSchemaChanged, changed.validate(fixture.bundle));
    changed = fixture.vector;
    changed.entries[0].record.basis.interpretation.retired = true;
    try t.expectError(error.TableRetired, changed.validate(fixture.bundle));
}
