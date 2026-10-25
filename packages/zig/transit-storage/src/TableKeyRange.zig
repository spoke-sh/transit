//! Bounds and continuation identity for a retained full-key interval. Keys are
//! already encoded under the retained declaration's collation or row identity.
const std = @import("std");
const p = @import("transit_protocol");
const Index = @import("OrderedKeyIndex.zig");
const Self = @This();

pub const Bound = Index.Bound;
pub const Key = Index.Key;
pub const Cursor = struct { source: p.DataLifecycle.Content, interval: [32]u8, after: Key };
lower: ?Bound = null,
upper: ?Bound = null,

pub fn validate(self: Self) !void {
    for ([_]?Bound{ self.lower, self.upper }) |slot| if (slot) |bound| {
        if (bound.key.len == 0 or bound.key.len > Index.max_key_bytes) return error.InvalidTableKey;
    };
}
pub fn contains(self: Self, key: []const u8) bool {
    if (self.lower) |bound| {
        const order = std.mem.order(u8, key, bound.key);
        if (order == .lt or (order == .eq and !bound.inclusive)) return false;
    }
    if (self.upper) |bound| {
        const order = std.mem.order(u8, key, bound.key);
        if (order == .gt or (order == .eq and !bound.inclusive)) return false;
    }
    return true;
}
pub fn fingerprint(self: Self) ![32]u8 {
    try self.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.table.key-range.v1\x00");
    hash.update(&p.Growth.definition_bytes);
    for ([_]?Bound{ self.lower, self.upper }) |slot| {
        const tag: [1]u8 = .{if (slot) |bound| if (bound.inclusive) 1 else 2 else 0};
        hash.update(&tag);
        if (slot) |bound| {
            var length: [2]u8 = undefined;
            std.mem.writeInt(u16, &length, @intCast(bound.key.len), .big);
            hash.update(&length);
            hash.update(bound.key);
        }
    }
    return hash.finalResult();
}
