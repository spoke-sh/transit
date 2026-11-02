//! Bounded catalog directory traversal. Object entries retain the seed Table
//! declaration even when the Table's current interpretation has since changed.
const std = @import("std");
const c = @import("root.zig");
const r = @import("DirectCatalogRecords.zig");
const pages = c.storage.TreeStore.pages;
const Self = @This();

pub const Kind = enum { pages_only, objects, values };
pub const Root = struct { reference: pages.Reference, kind: Kind };
pub const Edge = union(enum) { page: Root, declaration: c.storage.TableDeclaration.Stored, value: struct { key: pages.Key, value: pages.Value } };
const Frame = struct { reference: pages.Reference, height: ?u8 = null, child: u8 = 0, disclosed: bool = false };
pub const max_depth = pages.max_height + 1;

configuration: r.Configuration,
next_lsn: u64,
next_partition: u64,
root: Root,
stack: [max_depth]?Frame = @splat(null),
depth: u8 = 1,

pub fn init(basis: r.Root, root: Root) !Self {
    try basis.validate();
    if (basis.next_lsn == 0) return error.InvalidDirectCatalogHistory;
    var result: Self = .{ .configuration = basis.configuration, .next_lsn = basis.next_lsn, .next_partition = basis.next_partition, .root = root };
    result.stack[0] = .{ .reference = root.reference };
    return result;
}

/// A page is verified before it is emitted. At most max_depth + 1 page loads
/// occur per call; seeds own their fields and do not borrow a decoded page.
pub fn next(self: *Self, allocator: std.mem.Allocator, store: anytype) !?Edge {
    const before = self.*;
    errdefer self.* = before;
    if (self.depth > self.stack.len) return error.InvalidDirectCatalogHistory;
    for (self.stack[self.depth..]) |slot| if (slot != null) return error.InvalidDirectCatalogHistory;
    while (self.depth != 0) {
        const frame = if (self.stack[self.depth - 1]) |*value| value else return error.InvalidDirectCatalogHistory;
        const page = try store.load(frame.reference);
        try frame.reference.verify(&page);
        if (frame.height) |height| if (page.height != height) return error.InvalidDirectCatalogHistory;
        if (frame.child > page.count) return error.InvalidDirectCatalogHistory;
        if (!frame.disclosed) {
            if (frame.child != 0) return error.InvalidDirectCatalogHistory;
            frame.disclosed = true;
            return .{ .page = .{ .reference = frame.reference, .kind = self.root.kind } };
        }
        switch (page.body) {
            .branch => |children| if (frame.child < page.count) {
                const child = children[frame.child].?;
                frame.child += 1;
                if (self.depth == self.stack.len) return error.InvalidDirectCatalogHistory;
                self.stack[self.depth] = .{ .reference = child.reference, .height = page.height - 1 };
                self.depth += 1;
                continue;
            },
            .leaf => |entries| while (frame.child < page.count) {
                const entry = entries[frame.child].?;
                frame.child += 1;
                if (self.root.kind == .pages_only) continue;
                if (self.root.kind == .values) return .{ .value = .{ .key = entry.key, .value = entry.value } };
                const object = try r.fromValue(r.Entry, allocator, entry.value);
                try object.validate(self.configuration);
                if (!std.meta.eql(entry.key, try r.idKey(object.object))) return error.InvalidDirectCatalogEntry;
                if (object.resource == null and object.partition >= self.next_partition) return error.InvalidDirectCatalogEntry;
                if (object.resource) |at| if (at >= self.next_lsn) return error.InvalidDirectCatalogEntry;
                if (object.descriptor) |at| if (at >= self.next_lsn) return error.InvalidDirectCatalogEntry;
                if (object.log) |at| if (at >= self.next_lsn) return error.InvalidDirectCatalogEntry;
                if (object.seed) |seed| return .{ .declaration = seed };
            },
        }
        self.stack[self.depth - 1] = null;
        self.depth -= 1;
    }
    return null;
}

/// A retained mark must establish that this exact typed subtree, under this
/// configuration and frontier, has already been scheduled for complete traversal.
pub fn skip(self: *Self) !void {
    if (self.depth == 0 or self.depth > self.stack.len) return error.InvalidDirectCatalogHistory;
    const frame = self.stack[self.depth - 1] orelse return error.InvalidDirectCatalogHistory;
    if (!frame.disclosed or frame.child != 0) return error.InvalidDirectCatalogHistory;
    self.stack[self.depth - 1] = null;
    self.depth -= 1;
}
