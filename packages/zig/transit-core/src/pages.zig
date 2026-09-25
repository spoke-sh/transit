//! Immutable ordered pages. Staging returns a candidate root; only the authority
//! journal may publish it. A store is injected and owns persistence/cache policy.
const std = @import("std");
pub const version = 1;
pub const leaf_entries = 4;
pub const branch_children = 5;
pub const max_height = 32;
pub const max_encoded_bytes = 24 * 1024;
pub const page_entries = 8;
pub const Reference = [32]u8;

pub fn Bytes(comptime capacity: usize) type {
    return struct {
        const Self = @This();
        len: u16 = 0,
        data: [capacity]u8 = @splat(0),
        pub fn init(bytes: []const u8) !Self {
            if (bytes.len > capacity) return error.PageValueTooLarge;
            var result: Self = .{ .len = @intCast(bytes.len) };
            @memcpy(result.data[0..bytes.len], bytes);
            return result;
        }
        pub fn slice(self: *const Self) []const u8 {
            return self.data[0..self.len];
        }
        pub fn validate(self: *const Self) !void {
            if (self.len > capacity or !std.mem.allEqual(u8, self.data[self.len..], 0)) return error.InvalidPageValue;
        }
        pub fn jsonStringify(self: Self, out: anytype) !void {
            self.validate() catch return error.WriteFailed;
            var encoded: [capacity * 2]u8 = undefined;
            const hex = "0123456789abcdef";
            for (self.slice(), 0..) |byte, i| {
                encoded[2 * i] = hex[byte >> 4];
                encoded[2 * i + 1] = hex[byte & 15];
            }
            try out.write(encoded[0 .. self.len * 2]);
        }
        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Self {
            const hex = try std.json.innerParse([]const u8, allocator, source, options);
            if (hex.len > capacity * 2 or hex.len % 2 != 0) return error.InvalidCharacter;
            for (hex) |c| if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return error.InvalidCharacter;
            var result: Self = .{ .len = @intCast(hex.len / 2) };
            _ = std.fmt.hexToBytes(result.data[0..result.len], hex) catch return error.InvalidCharacter;
            return result;
        }
    };
}
pub const Key = Bytes(64);
pub const Value = Bytes(2048);
pub const Entry = struct { key: Key, value: Value };
pub const Child = struct { minimum: Key, reference: Reference };
pub const Mutation = struct { key: Key, value: ?Value };
pub const Slice = struct { entries: [page_entries]?Entry = @splat(null), next: ?Key = null };

fn order(a: *const Key, b: *const Key) std.math.Order {
    return std.mem.order(u8, a.slice(), b.slice());
}

pub const Page = struct {
    version: u32 = version,
    height: u8 = 0,
    count: u8,
    body: union(enum) { leaf: [leaf_entries]?Entry, branch: [branch_children]?Child },

    pub fn minimum(self: *const Page) Key {
        return switch (self.body) {
            .leaf => |entries| entries[0].?.key,
            .branch => |children| children[0].?.minimum,
        };
    }
    pub fn validate(self: *const Page) !void {
        if (self.version != version) return error.UnsupportedPageVersion;
        if (self.height > max_height or self.count == 0) return error.InvalidPage;
        switch (self.body) {
            .leaf => |entries| {
                if (self.height != 0 or self.count > leaf_entries) return error.InvalidPage;
                for (entries, 0..) |slot, i| {
                    if (i >= self.count) {
                        if (slot != null) return error.InvalidPage;
                    } else {
                        const entry = slot orelse return error.InvalidPage;
                        try entry.key.validate();
                        try entry.value.validate();
                        if (entry.key.len == 0) return error.InvalidPage;
                        if (i > 0 and order(&entries[i - 1].?.key, &entry.key) != .lt) return error.InvalidPage;
                    }
                }
            },
            .branch => |children| {
                if (self.height == 0 or self.count > branch_children) return error.InvalidPage;
                for (children, 0..) |slot, i| {
                    if (i >= self.count) {
                        if (slot != null) return error.InvalidPage;
                    } else {
                        const child = slot orelse return error.InvalidPage;
                        try child.minimum.validate();
                        if (child.minimum.len == 0) return error.InvalidPage;
                        if (i > 0 and order(&children[i - 1].?.minimum, &child.minimum) != .lt) return error.InvalidPage;
                    }
                }
            },
        }
    }
    pub fn encode(self: *const Page, bytes: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(bytes);
        try std.json.Stringify.value(self, .{}, &writer);
        return writer.buffered();
    }
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Page {
        if (bytes.len > max_encoded_bytes) return error.InvalidPage;
        const parsed = try std.json.parseFromSlice(Page, allocator, bytes, .{});
        defer parsed.deinit();
        try parsed.value.validate();
        return parsed.value;
    }
    pub fn reference(self: *const Page) !Reference {
        var bytes: [max_encoded_bytes]u8 = undefined;
        const encoded = try self.encode(&bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.immutable.page.v1\x00");
        hash.update(encoded);
        return hash.finalResult();
    }
};

/// Store.load returns an owned Page; Store.stage durably writes immutable bytes
/// under the supplied digest or reports uncertainty. Neither method publishes a
/// resource head. Missing/corrupt pages are errors, never empty state.
pub fn Tree(comptime Store: type) type {
    return struct {
        const Self = @This();
        store: *Store,
        const Split = struct { left: Child, right: ?Child = null, height: u8 };

        fn load(self: Self, ref: Reference, height: ?u8) !Page {
            const page = try self.store.load(ref);
            if (!std.mem.eql(u8, &ref, &try page.reference())) return error.CorruptPage;
            if (height) |expected| if (page.height != expected) return error.InvalidPageHeight;
            return page;
        }
        fn stage(self: Self, page: *const Page) !Child {
            const ref = try page.reference();
            try self.store.stage(ref, page);
            return .{ .minimum = page.minimum(), .reference = ref };
        }
        fn leaf(self: Self, entries: []const Entry) !Child {
            var page: Page = .{ .count = @intCast(entries.len), .body = .{ .leaf = @splat(null) } };
            for (entries, 0..) |entry, i| page.body.leaf[i] = entry;
            return self.stage(&page);
        }
        fn branch(self: Self, children: []const Child, height: u8) !Child {
            var page: Page = .{ .height = height, .count = @intCast(children.len), .body = .{ .branch = @splat(null) } };
            for (children, 0..) |child, i| page.body.branch[i] = child;
            return self.stage(&page);
        }
        fn childIndex(page: *const Page, key: *const Key) usize {
            var index: usize = 0;
            while (index + 1 < page.count and order(&page.body.branch[index + 1].?.minimum, key) != .gt) : (index += 1) {}
            return index;
        }
        pub fn get(self: Self, root: ?Reference, key: Key) !?Value {
            try key.validate();
            var ref = root orelse return null;
            var height: ?u8 = null;
            for (0..max_height + 1) |_| {
                const page = try self.load(ref, height);
                switch (page.body) {
                    .leaf => |entries| {
                        for (entries[0..page.count]) |slot| if (order(&slot.?.key, &key) == .eq) return slot.?.value;
                        return null;
                    },
                    .branch => |children| {
                        ref = children[childIndex(&page, &key)].?.reference;
                        height = page.height - 1;
                    },
                }
            }
            return error.InvalidPageHeight;
        }
        pub fn put(self: Self, root: ?Reference, key: Key, value: Value) !Reference {
            try key.validate();
            try value.validate();
            if (key.len == 0) return error.InvalidPageValue;
            const ref = root orelse return (try self.leaf(&.{.{ .key = key, .value = value }})).reference;
            const result = try self.insert(ref, null, .{ .key = key, .value = value });
            if (result.right) |right| {
                if (result.height == max_height) return error.PageDepthExceeded;
                return (try self.branch(&.{ result.left, right }, result.height + 1)).reference;
            }
            return result.left.reference;
        }
        fn insert(self: Self, ref: Reference, height: ?u8, entry: Entry) anyerror!Split {
            const page = try self.load(ref, height);
            switch (page.body) {
                .leaf => |entries| {
                    var merged: [leaf_entries + 1]Entry = undefined;
                    var count: usize = 0;
                    var inserted = false;
                    for (entries[0..page.count]) |slot| {
                        const comparison = order(&entry.key, &slot.?.key);
                        if (!inserted and comparison != .gt) {
                            merged[count] = entry;
                            count += 1;
                            inserted = true;
                            if (comparison == .eq) continue;
                        }
                        merged[count] = slot.?;
                        count += 1;
                    }
                    if (!inserted) {
                        merged[count] = entry;
                        count += 1;
                    }
                    if (count <= leaf_entries) return .{ .left = try self.leaf(merged[0..count]), .height = 0 };
                    return .{ .left = try self.leaf(merged[0 .. count / 2]), .right = try self.leaf(merged[count / 2 .. count]), .height = 0 };
                },
                .branch => |children| {
                    const index = childIndex(&page, &entry.key);
                    const result = try self.insert(children[index].?.reference, page.height - 1, entry);
                    var merged: [branch_children + 1]Child = undefined;
                    var count: usize = 0;
                    for (children[0..page.count], 0..) |slot, i| {
                        merged[count] = if (i == index) result.left else slot.?;
                        count += 1;
                        if (i == index) if (result.right) |right| {
                            merged[count] = right;
                            count += 1;
                        };
                    }
                    if (count <= branch_children) return .{ .left = try self.branch(merged[0..count], page.height), .height = page.height };
                    return .{ .left = try self.branch(merged[0 .. count / 2], page.height), .right = try self.branch(merged[count / 2 .. count], page.height), .height = page.height };
                },
            }
        }
        pub fn remove(self: Self, root: ?Reference, key: Key) !?Reference {
            try key.validate();
            const ref = root orelse return null;
            const changed = (try self.delete(ref, null, key)) orelse return null;
            var next = changed.reference;
            // Only the root may collapse a level. Internal one-child pages keep
            // sibling heights equal and avoid an unbounded rewrite on deletion.
            for (0..max_height + 1) |_| {
                const page = try self.load(next, null);
                if (page.body == .leaf or page.count != 1) return next;
                next = page.body.branch[0].?.reference;
            }
            return error.InvalidPageHeight;
        }
        fn delete(self: Self, ref: Reference, height: ?u8, key: Key) anyerror!?Child {
            const page = try self.load(ref, height);
            switch (page.body) {
                .leaf => |entries| {
                    var kept: [leaf_entries]Entry = undefined;
                    var count: usize = 0;
                    for (entries[0..page.count]) |slot| if (order(&slot.?.key, &key) != .eq) {
                        kept[count] = slot.?;
                        count += 1;
                    };
                    if (count == 0) return null;
                    if (count == page.count) return .{ .minimum = page.minimum(), .reference = ref };
                    return try self.leaf(kept[0..count]);
                },
                .branch => |children| {
                    const index = childIndex(&page, &key);
                    const child = try self.delete(children[index].?.reference, page.height - 1, key);
                    var kept: [branch_children]Child = undefined;
                    var count: usize = 0;
                    for (children[0..page.count], 0..) |slot, i| {
                        if (i == index) {
                            kept[count] = child orelse continue;
                        } else kept[count] = slot.?;
                        count += 1;
                    }
                    if (count == 0) return null;
                    return try self.branch(kept[0..count], page.height);
                },
            }
        }
        pub fn scan(self: Self, root: ?Reference, after: ?Key) !Slice {
            return self.scanBound(root, after, false);
        }
        pub fn scanFrom(self: Self, root: ?Reference, first: Key) !Slice {
            return self.scanBound(root, first, true);
        }
        fn scanBound(self: Self, root: ?Reference, after: ?Key, inclusive: bool) !Slice {
            if (after) |key| try key.validate();
            const ref = root orelse return .{};
            var found: [page_entries + 1]Entry = undefined;
            var count: usize = 0;
            try self.visit(ref, null, after, inclusive, &found, &count);
            var result: Slice = .{};
            for (found[0..@min(count, page_entries)], 0..) |entry, i| result.entries[i] = entry;
            if (count > page_entries) result.next = found[page_entries - 1].key;
            return result;
        }
        fn visit(self: Self, ref: Reference, height: ?u8, after: ?Key, inclusive: bool, out: *[page_entries + 1]Entry, count: *usize) anyerror!void {
            const page = try self.load(ref, height);
            switch (page.body) {
                .leaf => |entries| for (entries[0..page.count]) |slot| {
                    if (after) |key| {
                        const comparison = order(&slot.?.key, &key);
                        if (comparison == .lt or (comparison == .eq and !inclusive)) continue;
                    }
                    out[count.*] = slot.?;
                    count.* += 1;
                    if (count.* == out.len) return;
                },
                .branch => |children| for (children[0..page.count], 0..) |slot, i| {
                    if (after) |key| if (i + 1 < page.count and order(&children[i + 1].?.minimum, &key) != .gt) continue;
                    try self.visit(slot.?.reference, page.height - 1, after, inclusive, out, count);
                    if (count.* == out.len) return;
                },
            }
        }
    };
}
