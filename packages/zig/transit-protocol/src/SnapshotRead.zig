//! Bounded captured data and current authorization metadata in one native read.
const std = @import("std");
const p = @import("root.zig");
const g = p.Growth;
pub const current_resources = 2;
pub const range_entries = 64;
pub const max_range_bytes = 32 * 1024;
pub const Keys = [g.page_size]?p.Value;
pub const Current = struct { resource: g.Id, keys: Keys };
pub const CurrentResult = struct { resource: g.Resource, entries: [g.page_size]?g.Entry };
pub const Range = struct {
    after: ?p.Value = null,
    prefix: ?p.Value = null,
    limit: u8 = range_entries,
    bytes: u32 = max_range_bytes,
};
pub const Query = struct {
    snapshot: union(enum) { open: struct { resource: g.Id, nonce: [16]u8 }, existing: g.SnapshotId },
    current: [current_resources]?Current = @splat(null),
    points: Keys = @splat(null),
    blocks: Keys = @splat(null),
    range: ?Range = null,
    finish: bool = false,
};
pub const Result = struct {
    snapshot: g.Snapshot,
    current: [current_resources]?CurrentResult = @splat(null),
    points: [g.page_size]?g.Entry = @splat(null),
    blocks: [g.page_size]?p.Blocks.Entry = @splat(null),
    entries: [range_entries]?g.Entry = @splat(null),
    next: ?p.Value = null,
    finished: bool = false,
};
pub fn entryBytes(entry: g.Entry) u32 {
    return 16 + @as(u32, entry.key.len) + entry.value.len;
}
fn keys(values: Keys) !void {
    var ended = false;
    for (values, 0..) |slot, i| {
        const key = slot orelse {
            ended = true;
            continue;
        };
        if (ended) return error.InvalidRead;
        try g.validateKey(key);
        for (values[0..i]) |previous| if (previous.?.eql(key)) return error.InvalidRead;
    }
}
pub fn validate(query: Query) !void {
    switch (query.snapshot) {
        .open => |value| if (value.resource == 0 or query.finish) return error.InvalidRead,
        .existing => |id| if (id.serial == 0) return error.InvalidRead,
    }
    try keys(query.points);
    try keys(query.blocks);
    if (query.finish and (query.points[0] != null or query.blocks[0] != null or query.range != null)) return error.InvalidRead;
    var ended = false;
    for (query.current, 0..) |slot, i| {
        const value = slot orelse {
            ended = true;
            continue;
        };
        if (ended or value.resource == 0 or value.keys[0] == null) return error.InvalidRead;
        try keys(value.keys);
        for (query.current[0..i]) |previous| if (previous.?.resource == value.resource) return error.InvalidRead;
    }
    if (query.range) |range| {
        if (range.limit == 0 or range.limit > range_entries or range.bytes < 512 or range.bytes > max_range_bytes) return error.InvalidRead;
        if (range.after) |after| try g.validateKey(after);
        if (range.prefix) |prefix| {
            try g.validateKey(prefix);
            if (range.after) |after| if (std.mem.order(u8, after.slice(), prefix.slice()) == .lt) return error.InvalidRead;
        }
    }
}
fn points(entries: [g.page_size]?g.Entry, requested: Keys, revision: u64) !void {
    for (entries, requested) |slot, key| if (slot) |entry| {
        if (key == null or !key.?.eql(entry.key) or entry.revision == 0 or entry.revision > revision) return error.InvalidRead;
        try g.validateKey(entry.key);
    };
}
pub fn validateResult(value: Result, query: Query) !void {
    try g.validateSnapshot(value.snapshot);
    switch (query.snapshot) {
        .open => |opened| if (opened.resource != value.snapshot.resource.id) return error.InvalidRead,
        .existing => |id| if (!std.meta.eql(id, value.snapshot.id)) return error.InvalidRead,
    }
    if (value.finished != query.finish) return error.InvalidRead;
    for (value.current, query.current) |slot, requested| {
        if ((slot == null) != (requested == null)) return error.InvalidRead;
        if (slot) |current| {
            if (current.resource.id != requested.?.resource or current.resource.phase != .active) return error.InvalidRead;
            try points(current.entries, requested.?.keys, current.resource.revision);
        }
    }
    try points(value.points, query.points, value.snapshot.resource.revision);
    try g.BlockRead.entries(value.blocks, query.blocks, value.snapshot.resource.revision);
    var ended = false;
    var previous = if (query.range) |range| range.after else null;
    var count: usize = 0;
    var bytes: u32 = 0;
    for (value.entries) |slot| {
        const entry = slot orelse {
            ended = true;
            continue;
        };
        const range = query.range orelse return error.InvalidRead;
        try g.validateKey(entry.key);
        if (ended or entry.revision == 0 or entry.revision > value.snapshot.resource.revision) return error.InvalidRead;
        if (previous) |key| if (std.mem.order(u8, key.slice(), entry.key.slice()) != .lt) return error.InvalidRead;
        if (range.prefix) |prefix| if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.InvalidRead;
        count += 1;
        bytes += entryBytes(entry);
        if (count > range.limit or bytes > range.bytes) return error.InvalidRead;
        previous = entry.key;
    }
    if (value.next) |next| {
        if (query.range == null or count == 0 or !next.eql(previous.?)) return error.InvalidRead;
    }
}

test "combined snapshot canonical signing and bounded coverage" {
    const t = std.testing;
    const Fixture = struct { query: g.Query, digest: []const u8 };
    const parsed = try std.json.parseFromSlice([]Fixture, t.allocator, @embedFile("fixtures/snapshot-read.json"), .{});
    defer parsed.deinit();
    for (parsed.value) |fixture| {
        const actual = try g.queryDigest(fixture.query);
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, fixture.digest);
        try t.expectEqualSlices(u8, &expected, &actual);
    }
    const query: Query = .{ .snapshot = .{ .open = .{ .resource = 3, .nonce = @splat(1) } }, .range = .{ .limit = 1 } };
    var value: Result = .{ .snapshot = .{ .id = .{ .epoch = @splat(1), .serial = 1 }, .resource = .{ .id = 3, .writer = 2, .owner = null, .revision = 7, .deadline_ms = null }, .deadline_ms = 100, .hard_deadline_ms = 200 } };
    value.entries[0] = .{ .key = try p.Value.init("a"), .value = .{}, .revision = 7 };
    value.next = value.entries[0].?.key;
    try validateResult(value, query);
    value.entries[1] = .{ .key = try p.Value.init("b"), .value = .{}, .revision = 7 };
    try t.expectError(error.InvalidRead, validateResult(value, query));
    value.entries[1] = null;
    value.next = try p.Value.init("b");
    try t.expectError(error.InvalidRead, validateResult(value, query));
    value.next = null;
    value.entries[0].?.revision = 8;
    try t.expectError(error.InvalidRead, validateResult(value, query));
    var invalid = query;
    invalid.finish = true;
    try t.expectError(error.InvalidRead, validate(invalid));
    invalid = query;
    invalid.range.?.bytes = 511;
    try t.expectError(error.InvalidRead, validate(invalid));
    invalid = query;
    invalid.points[0] = try p.Value.init("a");
    invalid.points[1] = invalid.points[0];
    try t.expectError(error.InvalidRead, validate(invalid));
}
