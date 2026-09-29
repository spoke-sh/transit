//! Persistent ordered index over immutable Publication nodes. Only the consumer's
//! final root decision accepts a Document change; this layer grants no authority.
const std = @import("std");
const Pub = @import("Publication.zig");
const Self = @This();
pub const format: u32 = 0x53495801;
pub const node_bytes = 4096;
pub const fanout = 8;
pub const max_level = 31;
pub const Key = Bytes(128);
pub const Value = Bytes(256);
pub const Entry = struct { key: Key, value: Value };
pub const Reference = struct {
    id: u64,
    spec: Pub.Spec,
    level: u8,
    minimum: Key,
    entries: u64,
    pub fn validate(self: Reference) !void {
        if (self.id == 0 or self.spec.format != format or self.spec.length < 6 or self.spec.length > node_bytes or self.level > max_level or self.entries == 0) return error.InvalidIndexReference;
        try self.minimum.validate(true);
    }
};
root: ?Reference = null,
pub fn Bytes(comptime capacity: usize) type {
    return struct {
        const B = @This();
        len: u16 = 0,
        data: [capacity]u8 = @splat(0),
        pub fn init(bytes: []const u8) !B {
            if (bytes.len > capacity) return error.IndexValueTooLarge;
            var result: B = .{ .len = @intCast(bytes.len) };
            @memcpy(result.data[0..bytes.len], bytes);
            return result;
        }
        pub fn slice(self: *const B) []const u8 {
            return self.data[0..self.len];
        }
        pub fn validate(self: B, nonempty: bool) !void {
            if (self.len > capacity or (nonempty and self.len == 0)) return error.InvalidIndexValue;
        }
        pub fn eql(a: B, b: B) bool {
            return a.len == b.len and std.mem.eql(u8, a.slice(), b.slice());
        }
    };
}
fn order(a: Key, b: Key) std.math.Order {
    return std.mem.order(u8, a.slice(), b.slice());
}
const Node = struct {
    level: u8,
    used: u8,
    items: union { leaves: [fanout]Entry, branches: [fanout]Reference },
    fn minimum(self: *const Node) Key {
        return if (self.level == 0) self.items.leaves[0].key else self.items.branches[0].minimum;
    }
    fn count(self: *const Node) !u64 {
        if (self.used == 0 or self.used > fanout or self.level > max_level) return error.InvalidIndexNode;
        if (self.level == 0) return self.used;
        var total: u64 = 0;
        for (self.items.branches[0..self.used]) |child| total = std.math.add(u64, total, child.entries) catch return error.IndexCapacity;
        return total;
    }
    fn validate(self: *const Node) !void {
        _ = try self.count();
        var previous: ?Key = null;
        for (0..self.used) |i| {
            const key = if (self.level == 0) self.items.leaves[i].key else self.items.branches[i].minimum;
            try key.validate(true);
            if (previous) |p| if (order(p, key) != .lt) return error.InvalidIndexNode;
            previous = key;
            if (self.level == 0) {
                try self.items.leaves[i].value.validate(false);
            } else {
                const child = self.items.branches[i];
                try child.validate();
                if (child.level + 1 != self.level) return error.InvalidIndexNode;
            }
        }
    }
};
const Encoder = struct {
    bytes: []u8,
    offset: usize = 0,
    fn write(self: *Encoder, bytes: []const u8) !void {
        if (bytes.len > self.bytes.len - self.offset) return error.IndexNodeTooLarge;
        @memcpy(self.bytes[self.offset..][0..bytes.len], bytes);
        self.offset += bytes.len;
    }
    fn int(self: *Encoder, comptime T: type, value: T) !void {
        var buffer: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &buffer, value, .little);
        try self.write(&buffer);
    }
    fn string(self: *Encoder, bytes: []const u8) !void {
        try self.int(u16, @intCast(bytes.len));
        try self.write(bytes);
    }
};
const Decoder = struct {
    bytes: []const u8,
    offset: usize = 0,
    fn read(self: *Decoder, length: usize) ![]const u8 {
        if (length > self.bytes.len - self.offset) return error.InvalidIndexNode;
        const result = self.bytes[self.offset..][0..length];
        self.offset += length;
        return result;
    }
    fn int(self: *Decoder, comptime T: type) !T {
        return std.mem.readInt(T, (try self.read(@sizeOf(T)))[0..@sizeOf(T)], .little);
    }
    fn string(self: *Decoder) ![]const u8 {
        return self.read(try self.int(u16));
    }
};
fn encode(node: Node, buffer: []u8) ![]const u8 {
    try node.validate();
    var out: Encoder = .{ .bytes = buffer };
    try out.write("SIX1");
    try out.int(u8, node.level);
    try out.int(u8, node.used);
    for (0..node.used) |i| {
        if (node.level == 0) {
            const entry = node.items.leaves[i];
            try out.string(entry.key.slice());
            try out.string(entry.value.slice());
        } else {
            const child = node.items.branches[i];
            try out.string(child.minimum.slice());
            try out.int(u64, child.id);
            try out.int(u32, child.spec.format);
            try out.int(u32, child.spec.length);
            try out.write(&child.spec.digest);
            try out.int(u64, child.entries);
        }
    }
    return buffer[0..out.offset];
}
fn decode(bytes: []const u8) !Node {
    if (bytes.len > node_bytes) return error.InvalidIndexNode;
    var input: Decoder = .{ .bytes = bytes };
    if (!std.mem.eql(u8, try input.read(4), "SIX1")) return error.InvalidIndexNode;
    var result: Node = .{ .level = try input.int(u8), .used = try input.int(u8), .items = undefined };
    if (result.level > max_level or result.used == 0 or result.used > fanout) return error.InvalidIndexNode;
    result.items = if (result.level == 0) .{ .leaves = undefined } else .{ .branches = undefined };
    for (0..result.used) |i| {
        const key = try Key.init(try input.string());
        if (result.level == 0) result.items.leaves[i] = .{ .key = key, .value = try Value.init(try input.string()) } else result.items.branches[i] = .{ .id = try input.int(u64), .spec = .{ .format = try input.int(u32), .length = try input.int(u32), .digest = (try input.read(32))[0..32].* }, .level = result.level - 1, .minimum = key, .entries = try input.int(u64) };
    }
    if (input.offset != bytes.len) return error.InvalidIndexNode;
    try result.validate();
    return result;
}
fn load(source: anytype, ref: Reference) !Node {
    try ref.validate();
    var buffer: [node_bytes]u8 = undefined;
    const bytes = try source.load(ref, &buffer);
    if (bytes.len != ref.spec.length or !std.meta.eql(try Pub.Digest.of(format, bytes), ref.spec)) return error.InvalidIndexCommitment;
    const node = try decode(bytes);
    if (node.level != ref.level or !Key.eql(node.minimum(), ref.minimum) or try node.count() != ref.entries) return error.InvalidIndexReference;
    return node;
}
fn save(store: anytype, node: Node) !Reference {
    var buffer: [node_bytes]u8 = undefined;
    const bytes = try encode(node, &buffer);
    const spec = try Pub.Digest.of(format, bytes);
    const ref: Reference = .{ .id = try store.save(spec, bytes), .spec = spec, .level = node.level, .minimum = node.minimum(), .entries = try node.count() };
    try ref.validate();
    return ref;
}
fn branchFor(node: *const Node, key: Key) usize {
    var i: usize = 0;
    while (i + 1 < node.used and order(node.items.branches[i + 1].minimum, key) != .gt) i += 1;
    return i;
}
/// Source owns authorization and root availability; this layer verifies exact
/// immutable node commitments and bounds resident work independently of history.
pub fn get(self: Self, source: anytype, key: Key) !?Value {
    try key.validate(true);
    var ref = self.root orelse return null;
    while (true) {
        const node = try load(source, ref);
        if (node.level == 0) {
            for (node.items.leaves[0..node.used]) |entry| switch (order(entry.key, key)) {
                .eq => return entry.value,
                .gt => return null,
                .lt => {},
            };
            return null;
        }
        ref = node.items.branches[branchFor(&node, key)];
    }
}
fn successor(source: anytype, ref: Reference, after: ?Key) anyerror!?Entry {
    const node = try load(source, ref);
    if (node.level == 0) {
        for (node.items.leaves[0..node.used]) |entry| if (after == null or order(entry.key, after.?) == .gt) return entry;
        return null;
    }
    const start = if (after) |key| branchFor(&node, key) else 0;
    for (node.items.branches[start..node.used]) |child| if (try successor(source, child, after)) |entry| return entry;
    return null;
}
/// Strict ordered continuation returning one owned entry. The caller bounds the
/// output page and preserves this exact root; errors never become end-of-input.
pub fn next(self: Self, source: anytype, after: ?Key) !?Entry {
    if (after) |key| try key.validate(true);
    return successor(source, self.root orelse return null, after);
}
const Split = struct { left: Reference, right: ?Reference = null };
fn leaf(store: anytype, items: []const Entry) !Reference {
    var node: Node = .{ .level = 0, .used = @intCast(items.len), .items = .{ .leaves = undefined } };
    @memcpy(node.items.leaves[0..items.len], items);
    return save(store, node);
}
fn branch(store: anytype, level: u8, items: []const Reference) !Reference {
    var node: Node = .{ .level = level, .used = @intCast(items.len), .items = .{ .branches = undefined } };
    @memcpy(node.items.branches[0..items.len], items);
    return save(store, node);
}
fn insert(store: anytype, ref: Reference, entry: Entry) anyerror!Split {
    const node = try load(store, ref);
    if (node.level == 0) {
        var items: [fanout + 1]Entry = undefined;
        var count: usize = 0;
        var added = false;
        for (node.items.leaves[0..node.used]) |old| {
            const compared = order(entry.key, old.key);
            if (compared == .eq and Value.eql(entry.value, old.value)) return .{ .left = ref };
            if (!added and compared != .gt) {
                items[count] = entry;
                count += 1;
                added = true;
            }
            if (compared != .eq) {
                items[count] = old;
                count += 1;
            }
        }
        if (!added) {
            items[count] = entry;
            count += 1;
        }
        if (count <= fanout) return .{ .left = try leaf(store, items[0..count]) };
        return .{ .left = try leaf(store, items[0 .. count / 2]), .right = try leaf(store, items[count / 2 .. count]) };
    }
    const index = branchFor(&node, entry.key);
    const updated = try insert(store, node.items.branches[index], entry);
    if (updated.right == null and updated.left.id == node.items.branches[index].id) return .{ .left = ref };
    var children: [fanout + 1]Reference = undefined;
    @memcpy(children[0..index], node.items.branches[0..index]);
    children[index] = updated.left;
    var count = index + 1;
    if (updated.right) |right| {
        children[count] = right;
        count += 1;
    }
    @memcpy(children[count..][0 .. node.used - index - 1], node.items.branches[index + 1 .. node.used]);
    count += node.used - index - 1;
    if (count <= fanout) return .{ .left = try branch(store, node.level, children[0..count]) };
    return .{ .left = try branch(store, node.level, children[0 .. count / 2]), .right = try branch(store, node.level, children[count / 2 .. count]) };
}
/// On failure, candidate nodes may remain unreachable. The consumer owns staging
/// reservations/recovery; this value and all previously accepted roots stay intact.
pub fn put(self: Self, store: anytype, key: Key, value: Value) !Self {
    try key.validate(true);
    try value.validate(false);
    const entry: Entry = .{ .key = key, .value = value };
    const previous = self.root orelse return .{ .root = try leaf(store, &.{entry}) };
    const split = try insert(store, previous, entry);
    const right = split.right orelse return .{ .root = split.left };
    if (previous.level == max_level) return error.IndexCapacity;
    return .{ .root = try branch(store, previous.level + 1, &.{ split.left, right }) };
}

test "node codec rejects truncation ordering and trailing data" {
    const t = std.testing;
    var node: Node = .{ .level = 0, .used = 2, .items = .{ .leaves = undefined } };
    node.items.leaves[0] = .{ .key = try Key.init("a"), .value = try Value.init("\x00\xff") };
    node.items.leaves[1] = .{ .key = try Key.init("b"), .value = try Value.init("") };
    var buffer: [node_bytes]u8 = undefined;
    const bytes = try encode(node, &buffer);
    const parsed = try decode(bytes);
    try t.expectEqual(@as(u64, 2), try parsed.count());
    try t.expectEqualSlices(u8, "\x00\xff", parsed.items.leaves[0].value.slice());
    for (0..bytes.len) |length| try t.expectError(error.InvalidIndexNode, decode(bytes[0..length]));
    buffer[bytes.len] = 0;
    try t.expectError(error.InvalidIndexNode, decode(buffer[0 .. bytes.len + 1]));
    node.items.leaves[1].key = try Key.init("a");
    try t.expectError(error.InvalidIndexNode, encode(node, &buffer));
}

/// Eight immutable node bodies, scoped to one exact publication/read basis.
/// Every hit still opens the current descriptor and rechecks authority/lifecycle;
/// this caches bytes, never a permission decision or an accepted Document head.
pub const Cache = struct {
    pub const capacity = 8;
    const CachedNode = struct { id: u64 = 0, spec: Pub.Spec = undefined, bytes: [node_bytes]u8 = undefined };
    basis: ?Pub.Basis = null,
    namespace: u64 = 0,
    next: usize = 0,
    entries: [capacity]CachedNode = @splat(.{}),
    pub fn load(self: *Cache, publication: Pub, source: anytype, ref: Reference, buffer: []u8) ![]const u8 {
        try ref.validate();
        if (ref.spec.length > buffer.len) return error.IndexNodeTooLarge;
        var cursor = try publication.open(source, ref.id);
        if (!std.meta.eql(cursor.spec, ref.spec)) return error.InvalidIndexReference;
        if (self.basis == null or !std.meta.eql(self.basis.?, cursor.basis) or self.namespace != publication.namespace) {
            for (&self.entries) |*entry| entry.id = 0;
            self.basis = cursor.basis;
            self.namespace = publication.namespace;
            self.next = 0;
        }
        for (&self.entries) |*entry| if (entry.id == ref.id and std.meta.eql(entry.spec, ref.spec)) {
            @memcpy(buffer[0..ref.spec.length], entry.bytes[0..ref.spec.length]);
            return buffer[0..ref.spec.length];
        };
        var offset: usize = 0;
        while (true) {
            const Source = switch (@typeInfo(@TypeOf(source))) {
                .pointer => |pointer| pointer.child,
                else => @TypeOf(source),
            };
            if (comptime @hasDecl(Source, "prefetch")) {
                const p = @import("root.zig").protocol;
                if (cursor.index % p.Growth.page_size == 0) {
                    var keys: [p.Growth.page_size]p.Value = undefined;
                    const count = @min(p.Growth.page_size, cursor.spec.chunks() - cursor.index);
                    for (keys[0..count], 0..) |*key, i| key.* = Pub.key(publication.namespace, 'c', cursor.id, cursor.index + @as(u32, @intCast(i)));
                    try source.prefetch(keys[0..count]);
                }
            }
            const part = try publication.read(source, cursor);
            if (part.bytes.len > buffer.len - offset) return error.IndexNodeTooLarge;
            @memcpy(buffer[offset..][0..part.bytes.len], part.bytes.slice());
            offset += part.bytes.len;
            cursor = part.next orelse break;
        }
        if (offset != ref.spec.length) return error.InvalidIndexCommitment;
        const entry = &self.entries[self.next];
        self.next = (self.next + 1) % capacity;
        entry.id = ref.id;
        entry.spec = ref.spec;
        @memcpy(entry.bytes[0..offset], buffer[0..offset]);
        return buffer[0..offset];
    }
};
/// Adapt an authorized current/retained Publication source. The consumer
/// separately owns Document root availability; a byte cache never grants it.
pub fn Reader(comptime Source: type) type {
    return struct {
        publication: Pub,
        source: Source,
        cache: Cache = .{},
        pub fn load(self: *@This(), ref: Reference, buffer: []u8) ![]const u8 {
            return self.cache.load(self.publication, self.source, ref, buffer);
        }
    };
}

/// Resumable candidate publisher. Restart deterministic construction from the
/// SAME accepted root, frozen changes and reserved ID interval on every turn.
/// IndexStaging means one bounded Publication mutation was prepared: commit that
/// staging turn, without accepting the Document change. Other errors discard it.
/// A successful build returns references to already-published immutable nodes.
/// No Document head, reservation, authorization or retry identity is invented here.
pub const Staging = struct {
    turn: *@import("Turn.zig").Growing,
    publication: Pub,
    next_id: u64,
    end_id: u64,
    cache: Cache = .{},
    pub fn load(self: *Staging, ref: Reference, buffer: []u8) ![]const u8 {
        return self.cache.load(self.publication, self.turn, ref, buffer);
    }
    pub fn save(self: *Staging, spec: Pub.Spec, bytes: []const u8) !u64 {
        if (self.next_id == 0 or self.next_id >= self.end_id) return error.IndexCapacity;
        if (spec.format != format or spec.length > node_bytes or !std.meta.eql(try Pub.Digest.of(format, bytes), spec)) return error.InvalidIndexCommitment;
        const id = self.next_id;
        self.next_id += 1;
        const descriptor = self.publication.inspect(self.turn, id) catch |err| switch (err) {
            error.PublicationNotFound => {
                _ = try self.publication.begin(self.turn, id, spec);
                return error.IndexStaging;
            },
            else => return err,
        };
        if (!std.meta.eql(descriptor.spec, spec)) return error.IndexCandidateChanged;
        switch (descriptor.state) {
            .abandoned, .retired => return error.IndexCandidateClosed,
            .published => return id,
            .staging => {
                if (descriptor.written < spec.chunks()) {
                    const offset = @as(usize, descriptor.written) * Pub.chunk_bytes;
                    _ = try self.publication.append(self.turn, id, descriptor.written, bytes[offset..][0..try spec.size(descriptor.written)]);
                } else _ = try self.publication.publish(self.turn, id);
                return error.IndexStaging;
            },
        }
    }
};
