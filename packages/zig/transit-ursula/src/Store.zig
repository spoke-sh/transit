//! Transit store contract over Ursula JSON record coordinates.
const std = @import("std");
const transit = @import("transit");
const adapter = @import("root.zig");
const Store = @This();

journal: adapter.Journal,
cache: [adapter.read_window]transit.Entry = undefined,
cache_start: u64 = 0,
cache_len: usize = 0,

pub fn tail(self: *Store) !u64 {
    return self.journal.tail();
}

pub fn append(self: *Store, expected: u64, entry: transit.Entry) !bool {
    const allocator = self.journal.client.http.allocator;
    const bytes = try std.json.Stringify.valueAlloc(allocator, entry, .{});
    defer allocator.free(bytes);
    return self.journal.append(expected, bytes);
}

pub fn read(self: *Store, at: u64) !?transit.Entry {
    if (at >= self.cache_start and at - self.cache_start < self.cache_len) return self.cache[@intCast(at - self.cache_start)];
    var response = try self.journal.read(at);
    defer response.deinit();
    const next = (try response.head.metadata()).record_next.?;
    self.cache_start = at;
    self.cache_len = 0;
    errdefer self.cache_len = 0;
    var lines = std.mem.splitScalar(u8, response.body, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            if (lines.peek() != null) return error.InvalidFraming;
            break;
        }
        if (line.len > adapter.max_record_bytes or self.cache_len == adapter.read_window) return error.RecordTooLarge;
        var parsed = try std.json.parseFromSlice(transit.Entry, self.journal.client.http.allocator, line, .{});
        defer parsed.deinit();
        const position = at + self.cache_len;
        if (parsed.value == .genesis) {
            if (position != 0) return error.InvalidHistory;
        } else if (parsed.value.operation.position != position) return error.InvalidPosition;
        self.cache[self.cache_len] = parsed.value;
        self.cache_len += 1;
    }
    if (self.cache_len != next - at) {
        self.cache_len = 0;
        return error.InvalidFraming;
    }
    return if (self.cache_len == 0) null else self.cache[0];
}
