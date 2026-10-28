//! Validate a native page from an already authorized catalog source.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
pub fn validatePage(entries: p.Growth.Batch(p.Growth.Entry, p.Value), after: p.Value, revision: u64) !void {
    var previous = after;
    var ended = false;
    for (entries.entries) |slot| {
        if (slot) |entry| {
            if (ended) return error.InvalidCatalogPage;
            try p.Growth.validateKey(entry.key);
            try entry.value.validate();
            if (entry.revision > revision or std.mem.order(u8, previous.slice(), entry.key.slice()) != .lt) return error.InvalidCatalogPage;
            previous = entry.key;
        } else ended = true;
    }
    if (entries.next) |next| if (previous.eql(after) or !previous.eql(next)) return error.InvalidCatalogPage;
}
