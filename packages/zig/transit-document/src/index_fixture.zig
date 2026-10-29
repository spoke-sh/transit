//! Independent append-only test oracle for the evaluator's ordered index port.
//! This volatile fixture is neither a production index nor durability evidence.
const std = @import("std");
const t = std.testing;
const Bytes = @import("Bytes.zig").Bytes;
const Self = @This();
pub const Key = Bytes(128);
pub const Value = Bytes(256);
pub const Entry = struct { key: Key, value: Value };
pub const Root = struct {
    entries: usize,
    pub fn validate(self: Root) !void {
        if (self.entries == 0) return error.InvalidTestRoot;
    }
};
root: ?Root = null,
pub const Store = struct {
    records: std.ArrayList(struct { parent: ?Root, entry: Entry }) = .empty,
    fail_after: ?usize = null,
    denied: bool = false,
    pub fn deinit(self: *Store) void {
        self.records.deinit(t.allocator);
    }
};
pub fn get(self: Self, store: *Store, key: Key) !?Value {
    if (store.denied) return error.AccessDenied;
    var root = self.root;
    while (root) |current| {
        const record = store.records.items[current.entries - 1];
        if (Key.eql(key, record.entry.key)) return record.entry.value;
        root = record.parent;
    }
    return null;
}
pub fn next(self: Self, store: *Store, after: ?Key) !?Entry {
    if (store.denied) return error.AccessDenied;
    var result: ?Entry = null;
    var root = self.root;
    while (root) |current| {
        const record = store.records.items[current.entries - 1];
        const candidate = record.entry;
        if ((after == null or std.mem.order(u8, candidate.key.slice(), after.?.slice()) == .gt) and
            (result == null or std.mem.order(u8, candidate.key.slice(), result.?.key.slice()) == .lt))
            result = candidate;
        root = record.parent;
    }
    return result;
}
pub fn put(self: Self, store: *Store, key: Key, value: Value) !Self {
    if (store.denied) return error.AccessDenied;
    if (store.fail_after) |limit| if (store.records.items.len >= limit) return error.StorageUnavailable;
    try store.records.append(t.allocator, .{ .parent = self.root, .entry = .{ .key = key, .value = value } });
    return .{ .root = .{ .entries = store.records.items.len } };
}
