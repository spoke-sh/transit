//! Bounded traversal of explicit immutable ownership edges. Selecting accepted
//! roots, current pins and deletion authority belongs to the maintenance owner.
//! Historical view/version metadata is deliberately not a recursive root source.
const std = @import("std");
const core = @import("root.zig");
const c = core.catalog;
const p = core.pages;
const Self = @This();
pub const Kind = enum { catalog, policy, blocks };
pub const Root = struct { reference: p.Reference, kind: Kind, height: ?u8 = null, resource: ?u64 = null };
pub const Edge = union(enum) { page: Root, block: core.blocks.Reference };
const Frame = struct { root: Root, child: u8 = 0, disclosed: bool = false };
// One catalog tree can own a block-index tree. Captured catalogs enter as
// independently selected roots, so traversal depth does not grow with history.
pub const max_depth = 2 * (p.max_height + 1);
stack: [max_depth]?Frame = @splat(null),
depth: u8 = 0,

pub fn init(root: Root) Self {
    var result: Self = .{};
    result.stack[0] = .{ .root = root };
    result.depth = 1;
    return result;
}
fn page(store: anytype, root: Root) !p.Page {
    const value = try store.load(root.reference);
    try root.reference.verify(&value);
    if (root.height) |height| if (value.height != height) return error.InvalidStorageGraph;
    return value;
}
fn owned(root: Root, entry: p.Entry) !?Edge {
    switch (root.kind) {
        .policy => return null,
        .catalog => {
            if (entry.key.data[0] != @backingInt(c.Namespace.resource_blocks)) return null;
            if (entry.key.len != 17 or std.mem.readInt(u64, entry.key.data[1..9], .big) == 0 or !std.mem.allEqual(u8, entry.key.data[9..17], 0)) return error.InvalidStorageGraph;
            if (root.resource) |id| if (std.mem.readInt(u64, entry.key.data[1..9], .big) != id) return null;
            const snapshot = try c.decode(c.Snapshot, &entry.value);
            try snapshot.validate();
            return if (snapshot.root) |ref| .{ .page = .{ .reference = ref, .kind = .blocks } } else null;
        },
        .blocks => {
            const record = try c.decode(core.blocks.Record, &entry.value);
            try core.protocol.State.key(record.key);
            const address = try c.key(.entry, 0, 0, record.key.slice());
            if (!std.mem.eql(u8, address.slice(), entry.key.slice()) or record.revision == 0 or record.revision > core.protocol.max_counter) return error.InvalidStorageGraph;
            try record.reference.value.validate();
            return .{ .block = record.reference };
        },
    }
}
/// Emits a verified page before its children, or a typed block reference whose
/// bytes the maintenance owner must verify. A failed step restores its cursor.
pub fn next(self: *Self, store: anytype) !?Edge {
    const before = self.*;
    errdefer self.* = before;
    if (self.depth > self.stack.len) return error.InvalidStorageGraph;
    for (self.stack[self.depth..]) |slot| if (slot != null) return error.InvalidStorageGraph;
    while (self.depth != 0) {
        const frame = if (self.stack[self.depth - 1]) |*value| value else return error.InvalidStorageGraph;
        const value = try page(store, frame.root);
        if (frame.child > value.count) return error.InvalidStorageGraph;
        if (!frame.disclosed) {
            if (frame.child != 0) return error.InvalidStorageGraph;
            frame.disclosed = true;
            return .{ .page = frame.root };
        }
        if (frame.child == value.count) {
            self.stack[self.depth - 1] = null;
            self.depth -= 1;
            continue;
        }
        const index = frame.child;
        frame.child += 1;
        const edge: ?Edge = switch (value.body) {
            .branch => |children| .{ .page = .{ .reference = children[index].?.reference, .kind = frame.root.kind, .height = value.height - 1, .resource = frame.root.resource } },
            .leaf => |entries| try owned(frame.root, entries[index].?),
        };
        if (edge) |child| switch (child) {
            .block => return child,
            .page => |root| {
                if (self.depth == self.stack.len) return error.InvalidStorageGraph;
                self.stack[self.depth] = .{ .root = root };
                self.depth += 1;
            },
        };
    }
    return null;
}
/// A durable mark index may skip an already verified subtree. Only the page
/// most recently returned can be skipped; arbitrary cursor changes are invalid.
pub fn skip(self: *Self) !void {
    if (self.depth == 0 or self.depth > self.stack.len) return error.InvalidStorageGraph;
    const frame = self.stack[self.depth - 1] orelse return error.InvalidStorageGraph;
    if (!frame.disclosed or frame.child != 0) return error.InvalidStorageGraph;
    self.stack[self.depth - 1] = null;
    self.depth -= 1;
}

test "storage walk follows resource blocks and keeps captured root selection explicit" {
    const t = std.testing;
    var store: @import("pages_test.zig").Store = .{};
    defer store.deinit();
    var batch: core.protocol.Blocks.Batch = .{};
    try batch.put(try .init("row"), "complete immutable bytes");
    const index = try (core.blocks.Index(@TypeOf(store)){ .store = &store }).publish(.{}, batch.mutations, &batch.body, 5);
    var catalog = try c.Catalog(@TypeOf(store)).open(&store, .{});
    try catalog.put(try c.key(.resource_blocks, 7, 0, ""), index);
    // A historical view-like value is opaque here. Its root must not acquire
    // ownership merely because that old metadata remains inside a catalog.
    try catalog.put(try c.key(.view, 9, 0, ""), index);
    var walk = init(.{ .reference = catalog.snapshot.root.?, .kind = .catalog });
    var data: usize = 0;
    var pages: usize = 0;
    while (try walk.next(&store)) |edge| switch (edge) {
        .page => pages += 1,
        .block => |ref| {
            var bytes: [64]u8 = undefined;
            try t.expectEqualStrings("complete immutable bytes", try store.loadBlock(ref, &bytes));
            data += 1;
        },
    };
    try t.expectEqual(@as(usize, 1), data);
    try t.expectEqual(@as(usize, 2), pages);
    walk = init(.{ .reference = catalog.snapshot.root.?, .kind = .catalog });
    store.corrupt = true;
    const before = walk;
    try t.expectError(error.CorruptPage, walk.next(&store));
    try t.expectEqual(before.depth, walk.depth);
    try t.expect(!walk.stack[0].?.disclosed);
    store.corrupt = false;
    _ = (try walk.next(&store)).?;
    try walk.skip();
    try t.expectEqual(null, try walk.next(&store));
    try t.expectError(error.InvalidStorageGraph, walk.skip());
}

test "captured catalog scope survives branches and serialized traversal resume" {
    const t = std.testing;
    var store: @import("pages_test.zig").Store = .{};
    defer store.deinit();
    var catalog = try c.Catalog(@TypeOf(store)).open(&store, .{});
    for (1..18) |resource| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, resource, .big);
        var batch: core.protocol.Blocks.Batch = .{};
        try batch.put(try .init("row"), &bytes);
        const index = try (core.blocks.Index(@TypeOf(store)){ .store = &store }).publish(.{}, batch.mutations, &batch.body, 1);
        try catalog.put(try c.key(.resource_blocks, resource, 0, ""), index);
    }
    try t.expect((try store.load(catalog.snapshot.root.?)).height > 0);
    for ([_]u64{ 2, 16 }) |resource| {
        var walk = init(.{ .reference = catalog.snapshot.root.?, .kind = .catalog, .resource = resource });
        var blocks: usize = 0;
        while (try walk.next(&store)) |edge| {
            if (edge == .block) {
                var bytes: [8]u8 = undefined;
                _ = try store.loadBlock(edge.block, &bytes);
                try t.expectEqual(resource, std.mem.readInt(u64, &bytes, .big));
                blocks += 1;
            }
            const encoded = try std.json.Stringify.valueAlloc(t.allocator, walk, .{});
            defer t.allocator.free(encoded);
            const parsed = try std.json.parseFromSlice(Self, t.allocator, encoded, .{});
            defer parsed.deinit();
            walk = parsed.value;
        }
        try t.expectEqual(@as(usize, 1), blocks);
    }
}
