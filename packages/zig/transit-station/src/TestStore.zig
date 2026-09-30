//! Independent paged state fixture; never imported by runtime code.
const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Store = @This();
entries: [128]?p.State.Entry = @splat(null),
reads: usize = 0,
fail: bool = false,
pages: usize = 0,
fail_page: bool = false,
pub fn read(context: *anyopaque, view: p.Growth.View, key: p.Value) anyerror!?p.Value {
    const self: *Store = @ptrCast(@alignCast(context));
    self.reads += 1;
    try t.expectEqual(@as(u64, 6), view.id);
    if (self.fail) return error.Unavailable;
    for (self.entries) |slot| if (slot) |entry| if (entry.key.eql(key)) return entry.value;
    return null;
}
pub fn turn(self: *Store, value: p.Value) !Turn {
    return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = 4, .ordinal = 1, .value = value, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 65536, .generation = 3, .input = 4, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100 }, .{ .context = self, .read = read, .page = page });
}
pub fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) anyerror!@import("Turn.zig").Page {
    const self: *Store = @ptrCast(@alignCast(raw));
    self.pages += 1;
    if (self.fail_page) return error.Unavailable;
    // Simple independent fixture ordering, not the production page index.
    var ordered: [128]p.State.Entry = undefined;
    var len: usize = 0;
    for (self.entries) |slot| if (slot) |entry| {
        ordered[len] = entry;
        len += 1;
    };
    std.mem.sort(p.State.Entry, ordered[0..len], {}, struct {
        fn less(_: void, a: p.State.Entry, b: p.State.Entry) bool {
            return std.mem.order(u8, a.key.slice(), b.key.slice()) == .lt;
        }
    }.less);
    var result: @import("Turn.zig").Page = .{};
    var count: usize = 0;
    for (ordered[0..len]) |entry| {
        if (after) |key| if (std.mem.order(u8, entry.key.slice(), key.slice()) != .gt) continue;
        if (count == result.entries.len) {
            result.next = result.entries[count - 1].?.key;
            break;
        }
        result.entries[count] = .{ .key = entry.key, .value = entry.value, .revision = entry.revision };
        count += 1;
    }
    return result;
}
