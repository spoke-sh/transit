//! Volatile text snapshots. Draft and search share a fixed byte/group budget;
//! eviction never affects the durable command history.
const std = @import("std");
const Self = @This();
pub const max_groups = 128;
pub const max_bytes = 256 * 1024;
pub const Domain = enum { draft, search };
pub const Group = enum { atomic, typing, backspace, delete };
const Entry = struct { start: usize, length: usize, cursor: usize, domain: Domain };
bytes: [max_bytes]u8 = undefined,
entries: [max_groups]Entry = undefined,
used: usize = 0,
count: usize = 0,
group: Group = .atomic,

pub fn boundary(self: *Self) void {
    self.group = .atomic;
}
pub fn clear(self: *Self) void {
    std.crypto.secureZero(u8, &self.bytes);
    self.used = 0;
    self.count = 0;
    self.boundary();
}
pub fn discardSearch(self: *Self) void {
    while (self.count > 0 and self.entries[self.count - 1].domain == .search) self.discardLast();
    self.boundary();
}
fn discardLast(self: *Self) void {
    self.count -= 1;
    const entry = self.entries[self.count];
    std.crypto.secureZero(u8, self.bytes[entry.start..self.used]);
    self.used = entry.start;
}
pub fn save(self: *Self, text: []const u8, cursor: usize, domain: Domain, group: Group) void {
    std.debug.assert(text.len <= max_bytes);
    if (group != .atomic and self.group == group and self.count > 0 and self.entries[self.count - 1].domain == domain) return;
    while (self.count == max_groups or self.used + text.len > max_bytes) {
        const length = self.entries[0].length;
        std.mem.copyForwards(u8, &self.bytes, self.bytes[length..self.used]);
        std.crypto.secureZero(u8, self.bytes[self.used - length .. self.used]);
        self.used -= length;
        std.mem.copyForwards(Entry, &self.entries, self.entries[1..self.count]);
        self.count -= 1;
        for (self.entries[0..self.count]) |*entry| entry.start -= length;
    }
    self.entries[self.count] = .{ .start = self.used, .length = text.len, .cursor = cursor, .domain = domain };
    @memcpy(self.bytes[self.used..][0..text.len], text);
    self.used += text.len;
    self.count += 1;
    self.group = group;
}
pub fn restore(self: *Self, domain: Domain, output: []u8) ?struct { length: usize, cursor: usize } {
    self.boundary();
    if (self.count == 0) return null;
    const entry = self.entries[self.count - 1];
    if (entry.domain != domain) return null;
    @memcpy(output[0..entry.length], self.bytes[entry.start..][0..entry.length]);
    self.discardLast();
    return .{ .length = entry.length, .cursor = entry.cursor };
}

test "undo groups preserve cursors, isolate search and evict both bounded budgets" {
    const t = std.testing;
    var journal: Self = .{};
    defer journal.clear();
    var output: [4096]u8 = undefined;
    journal.save("draft", 2, .draft, .typing);
    journal.save("draftx", 3, .draft, .typing);
    journal.boundary();
    journal.save("q", 1, .search, .typing);
    try t.expect(journal.restore(.draft, &output) == null);
    journal.discardSearch();
    const restored = journal.restore(.draft, &output).?;
    try t.expectEqualStrings("draft", output[0..restored.length]);
    try t.expectEqual(2, restored.cursor);
    for (0..max_groups + 10) |_| journal.save("", 0, .draft, .atomic);
    try t.expectEqual(max_groups, journal.count);
    @memset(&output, 'x');
    for (0..max_groups) |_| journal.save(&output, 0, .draft, .atomic);
    try t.expectEqual(max_bytes / output.len, journal.count);
    try t.expectEqual(max_bytes, journal.used);
}
