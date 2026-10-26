//! Ordered full keys over immutable data pages. A 64-byte chunk names a terminal
//! row hash and/or a child index for the remaining bytes. Shorter keys precede
//! their extensions; no hash or prefix can establish full-key equality/order.
//! Candidate roots acquire authority only through their owner's accepted WAL.
const std = @import("std");
const Store = @import("TreeStore.zig");
const pages = Store.pages;
const Self = @This();

pub const max_key_bytes = @import("transit_fuze").Collation.max_sort_key_bytes;
const chunk_bytes = @sizeOf(@FieldType(pages.Key, "data"));
const max_depth = std.math.divCeil(usize, max_key_bytes, chunk_bytes) catch unreachable;
pub const Key = pages.Bytes(max_key_bytes);
pub const Entry = struct { key: Key, value: [32]u8 };
pub const Bound = struct { key: []const u8, inclusive: bool = true };
pub const Mutation = struct { key: []const u8, value: ?[32]u8 };
const Tree = pages.Tree(Store);

store: *Store,

// Fixed canonical value: flags, terminal row hash, child digest and location.
// This is data-index content, with the TreeStore's mandatory shared definition.
const Node = struct {
    value: ?[32]u8 = null,
    child: ?pages.Reference = null,
    fn encode(self: Node) !pages.Value {
        var bytes: [97]u8 = @splat(0);
        if (self.value) |value| {
            bytes[0] |= 1;
            bytes[1..33].* = value;
        }
        if (self.child) |child| {
            bytes[0] |= 2;
            bytes[33..65].* = child.digest;
            bytes[65..97].* = child.location;
        }
        if (bytes[0] == 0) return error.InvalidOrderedKeyNode;
        return pages.Value.init(&bytes);
    }
    fn decode(value: pages.Value, key: pages.Key) !Node {
        if (value.len != 97 or value.data[0] == 0 or value.data[0] > 3 or key.len == 0) return error.InvalidOrderedKeyNode;
        var result: Node = .{};
        if (value.data[0] & 1 != 0) {
            result.value = value.data[1..33].*;
        } else if (!std.mem.allEqual(u8, value.data[1..33], 0)) return error.InvalidOrderedKeyNode;
        if (value.data[0] & 2 != 0) {
            if (key.len != chunk_bytes) return error.InvalidOrderedKeyNode;
            result.child = .{ .digest = value.data[33..65].*, .location = value.data[65..97].* };
        } else if (!std.mem.allEqual(u8, value.data[33..97], 0)) return error.InvalidOrderedKeyNode;
        return result;
    }
};

fn validateKey(key: []const u8) !void {
    if (key.len == 0 or key.len > max_key_bytes) return error.InvalidTableKey;
}
fn tree(self: Self) Tree {
    return .{ .store = self.store };
}

pub fn get(self: Self, root: ?pages.Reference, key: []const u8) !?[32]u8 {
    try validateKey(key);
    var current = root;
    var offset: usize = 0;
    while (offset < key.len) {
        const end = @min(key.len, offset + chunk_bytes);
        const chunk = try pages.Key.init(key[offset..end]);
        const encoded = try self.tree().get(current, chunk) orelse return null;
        const node = try Node.decode(encoded, chunk);
        if (end == max_key_bytes and node.child != null) return error.InvalidOrderedKeyNode;
        if (end == key.len) return node.value;
        current = node.child orelse return null;
        offset = end;
    }
    unreachable;
}

/// Begin/end the TreeStore candidate outside this call so the whole accepting
/// operation shares one staging budget. Earlier roots remain independently valid.
pub fn put(self: Self, root: ?pages.Reference, key: []const u8, value: [32]u8) !pages.Reference {
    return (try self.change(root, key, value)).?;
}
pub fn remove(self: Self, root: ?pages.Reference, key: []const u8) !?pages.Reference {
    return self.change(root, key, null);
}

/// Share affected page paths for up to one bounded mutation batch. Full-key
/// validation precedes staging. Long keys retain bounded chunk traversal; short
/// terminal updates preserve any existing child for longer keys with that prefix.
pub fn mutate(self: Self, root: ?pages.Reference, mutations: []const Mutation) !?pages.Reference {
    if (mutations.len > pages.mutation_batch) return error.PageMutationBudget;
    for (mutations, 0..) |mutation, i| {
        try validateKey(mutation.key);
        for (mutations[0..i]) |previous| if (std.mem.eql(u8, previous.key, mutation.key)) return error.DuplicatePageMutation;
    }
    var current = root;
    var pending: [pages.mutation_batch]pages.Mutation = undefined;
    var count: usize = 0;
    for (mutations) |mutation| {
        if (mutation.key.len > chunk_bytes) {
            current = try self.tree().mutate(current, pending[0..count]);
            count = 0;
            current = try self.change(current, mutation.key, mutation.value);
            continue;
        }
        const key = try pages.Key.init(mutation.key);
        const previous = try self.tree().get(current, key);
        var node = if (previous) |value| try Node.decode(value, key) else Node{};
        node.value = mutation.value;
        pending[count] = .{ .key = key, .value = if (node.value == null and node.child == null) null else try node.encode() };
        count += 1;
    }
    return self.tree().mutate(current, pending[0..count]);
}
fn change(self: Self, root: ?pages.Reference, key: []const u8, value: ?[32]u8) !?pages.Reference {
    try validateKey(key);
    const Frame = struct { root: ?pages.Reference, chunk: pages.Key, node: Node };
    var path: [max_depth]Frame = undefined;
    var depth: usize = 0;
    var current = root;
    var offset: usize = 0;
    while (offset < key.len) {
        const end = @min(key.len, offset + chunk_bytes);
        const chunk = try pages.Key.init(key[offset..end]);
        const encoded = try self.tree().get(current, chunk);
        if (encoded == null and value == null) return root;
        var node = if (encoded) |found| try Node.decode(found, chunk) else Node{};
        if (end == max_key_bytes and node.child != null) return error.InvalidOrderedKeyNode;
        if (end == key.len) {
            if (value == null and node.value == null) return root;
            node.value = value;
        }
        path[depth] = .{ .root = current, .chunk = chunk, .node = node };
        depth += 1;
        current = node.child;
        offset = end;
    }
    var child: ?pages.Reference = null;
    var last = true;
    while (depth != 0) {
        depth -= 1;
        var frame = path[depth];
        if (!last) frame.node.child = child;
        last = false;
        child = if (frame.node.value == null and frame.node.child == null)
            try self.tree().remove(frame.root, frame.chunk)
        else
            try self.tree().put(frame.root, frame.chunk, try frame.node.encode());
    }
    return child;
}

/// First complete key in the requested interval. Work follows bounded index
/// pages and at most 64 chunk levels, without collecting the retained key set.
/// Call again with the returned key as an exclusive lower bound to continue.
pub fn seek(self: Self, root: ?pages.Reference, lower: ?Bound, upper: ?Bound) !?Entry {
    if (lower) |bound| if (bound.key.len > max_key_bytes) return error.InvalidTableKey;
    if (upper) |bound| if (bound.key.len > max_key_bytes) return error.InvalidTableKey;
    if (lower != null and upper != null) {
        const order = std.mem.order(u8, lower.?.key, upper.?.key);
        if (order == .gt or (order == .eq and (!lower.?.inclusive or !upper.?.inclusive))) return null;
    }
    const Frame = struct { root: ?pages.Reference, after: ?pages.Key = null, constrained: bool };
    var path: [max_depth]Frame = undefined;
    path[0] = .{ .root = root, .constrained = lower != null };
    var depth: usize = 0;
    var key: Key = .{};
    while (true) {
        const frame = &path[depth];
        const offset = depth * chunk_bytes;
        const batch = if (frame.after == null and frame.constrained and lower.?.key.len > offset)
            try self.tree().scanFrom(frame.root, try pages.Key.init(lower.?.key[offset..@min(lower.?.key.len, offset + chunk_bytes)]))
        else
            try self.tree().scan(frame.root, frame.after);
        const entry = batch.entries[0] orelse {
            // A child referenced by a node must contain at least one entry.
            if (depth != 0 and frame.after == null and !frame.constrained) return error.InvalidOrderedKeyNode;
            if (depth == 0) return null;
            depth -= 1;
            continue;
        };
        frame.after = entry.key;
        frame.constrained = false;
        const node = try Node.decode(entry.value, entry.key);
        key.len = @intCast(offset + entry.key.len);
        @memcpy(key.data[offset..key.len], entry.key.slice());
        // Zero the inactive suffix so returned keys have one canonical shape.
        @memset(key.data[key.len..], 0);
        if (key.len == max_key_bytes and node.child != null) return error.InvalidOrderedKeyNode;
        if (upper) |bound| {
            const order = std.mem.order(u8, key.slice(), bound.key);
            if (order == .gt or (order == .eq and !bound.inclusive)) return null;
        }
        if (node.value) |value| {
            const order = if (lower) |bound| std.mem.order(u8, key.slice(), bound.key) else .gt;
            if (order == .gt or (order == .eq and lower.?.inclusive)) return .{ .key = key, .value = value };
        }
        if (node.child) |child| {
            if (depth + 1 >= max_depth) return error.InvalidOrderedKeyNode;
            depth += 1;
            path[depth] = .{ .root = child, .constrained = if (lower) |bound| bound.key.len > key.len and std.mem.startsWith(u8, bound.key, key.slice()) else false };
        }
    }
}
