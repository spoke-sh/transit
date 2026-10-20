//! Owned, verified immutable bytes for one bounded fetch. This buffer carries no
//! permission; its host binds the source cut and owns current disclosure checks.
const std = @import("std");
const p = @import("root.zig").protocol;
const g = p.Growth;
const Self = @This();
keys: [g.page_size]?p.Value,
entries: [g.page_size]?p.Blocks.Entry,
body: p.Blocks.Body,

pub fn init(keys: [g.page_size]?p.Value, entries: [g.page_size]?p.Blocks.Entry, body: p.Blocks.Body) !Self {
    try g.BlockRead.keys(keys);
    try body.validate();
    var offset: usize = 0;
    for (keys, entries) |key, slot| if (slot) |entry| {
        if (key == null or !key.?.eql(entry.key) or entry.revision == 0 or entry.revision > p.max_counter) return error.InvalidAuthorityResponse;
        if (entry.value.bytes > body.len - offset) return error.InvalidAuthorityResponse;
        try entry.value.verify(body.slice()[offset..][0..entry.value.bytes]);
        offset += entry.value.bytes;
    };
    if (offset != body.len) return error.InvalidAuthorityResponse;
    return .{ .keys = keys, .entries = entries, .body = body };
}
pub fn contains(self: *const Self, key: p.Value) bool {
    for (self.keys) |slot| if (slot) |requested| if (requested.eql(key)) return true;
    return false;
}
/// Copy only a previously validated complete block. Missing keys and uncached
/// keys are distinct; zero-length values remain present.
pub fn read(self: *const Self, key: p.Value, output: []u8) !?[]const u8 {
    var offset: usize = 0;
    for (self.keys, self.entries) |requested, slot| {
        if (requested) |selected| if (selected.eql(key)) {
            const entry = slot orelse return null;
            if (entry.value.bytes > output.len) return error.BlockBufferTooSmall;
            @memcpy(output[0..entry.value.bytes], self.body.slice()[offset..][0..entry.value.bytes]);
            return output[0..entry.value.bytes];
        };
        if (slot) |entry| offset += entry.value.bytes;
    }
    return error.UncachedBlock;
}

test "owned block batches preserve missing slots and reject partial or substituted bytes" {
    const t = std.testing;
    const a = try p.Value.init("a");
    const b = try p.Value.init("b");
    const empty = try p.Value.init("empty");
    var bytes: p.Blocks.Batch = .{};
    try bytes.put(a, &.{ 0, 255, 1 });
    try bytes.put(empty, "");
    const keys: [g.page_size]?p.Value = .{ a, b, empty, null, null, null, null, null };
    var entries: [g.page_size]?p.Blocks.Entry = @splat(null);
    entries[0] = .{ .key = a, .value = bytes.mutations[0].?.value.?, .revision = 2 };
    entries[2] = .{ .key = empty, .value = bytes.mutations[1].?.value.?, .revision = 2 };
    const batch = try init(keys, entries, bytes.body);
    bytes.body.data[0] = 7;
    var buffer: [8]u8 = undefined;
    try t.expectEqualSlices(u8, &.{ 0, 255, 1 }, (try batch.read(a, &buffer)).?);
    try t.expectEqual(null, try batch.read(b, &buffer));
    try t.expectEqualStrings("", (try batch.read(empty, &buffer)).?);
    try t.expectError(error.UncachedBlock, batch.read(try .init("unknown"), &buffer));
    try t.expectError(error.BlockBufferTooSmall, batch.read(a, buffer[0..2]));
    try t.expectError(error.CorruptBlock, init(keys, entries, bytes.body));
    entries[0].?.key = b;
    try t.expectError(error.InvalidAuthorityResponse, init(keys, entries, batch.body));
}
