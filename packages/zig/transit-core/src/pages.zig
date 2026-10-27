//! Immutable ordered pages. Staging returns a candidate root; only the authority
//! journal may publish it. A store is injected and owns persistence/cache policy.
const std = @import("std");
const Layout = @This();
pub const version = 1;
pub const leaf_entries = 8;
pub const branch_children = 32;
pub const max_height = 32;
pub const max_encoded_bytes = 24 * 1024;
pub const page_entries = 8;
pub const mutation_batch = 8;
pub const Reference = struct {
    digest: [32]u8,
    /// Opaque storage address; core never interprets provider coordinates.
    location: [32]u8 = @splat(0),
    pub fn verify(self: Reference, page: *const Page) !void {
        if (!std.mem.eql(u8, &self.digest, &(try page.reference()).digest)) return error.CorruptPage;
    }
};

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
comptime {
    if (6 + leaf_entries * (3 + 64 + 2048) > max_encoded_bytes or
        6 + branch_children * (1 + 64 + 32 + 32) > max_encoded_bytes)
        @compileError("Page geometry exceeds its encoded byte budget");
}
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
        return @import("PageCodec.zig").encode(self, bytes);
    }
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Page {
        _ = allocator;
        return @import("PageCodec.zig").decode(Layout, bytes) catch return error.InvalidPage;
    }
    pub fn reference(self: *const Page) !Reference {
        var bytes: [max_encoded_bytes]u8 = undefined;
        const encoded = try self.encode(&bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.immutable.page.v1\x00");
        hash.update(encoded);
        return .{ .digest = hash.finalResult() };
    }
};

/// Store.load returns an owned Page; Store.stage durably writes immutable bytes
/// under the supplied digest and returns an owned locator, or reports uncertainty.
/// Neither method publishes a
/// resource head. Missing/corrupt pages are errors, never empty state.
pub fn Tree(comptime Store: type) type {
    return BoundedTree(Store, mutation_batch);
}
/// A private command's record budget can exceed one public mutation batch.
/// It does not change page geometry, read budgets or provider batch bounds.
pub fn BoundedTree(comptime Store: type, comptime budget: usize) type {
    return struct {
        const Self = @This();
        store: *Store,
        const Split = struct { left: Child, right: ?Child = null, height: u8 };

        fn load(self: Self, ref: Reference, height: ?u8) !Page {
            const page = try self.store.load(ref);
            try ref.verify(&page);
            if (height) |expected| if (page.height != expected) return error.InvalidPageHeight;
            return page;
        }
        fn stage(self: Self, page: *const Page) !Child {
            const ref = try self.store.stage(try page.reference(), page);
            try ref.verify(page);
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
        fn stages(self: Self, batch: []const Page, output: []Child) !void {
            var offset: usize = 0;
            while (offset < batch.len) {
                const count = @min(mutation_batch, batch.len - offset);
                const group = batch[offset..][0..count];
                const children = output[offset..][0..count];
                if (@hasDecl(Store, "stageMany") and count > 1) {
                    var refs: [mutation_batch]Reference = undefined;
                    try self.store.stageMany(group, refs[0..count]);
                    for (group, refs[0..count], children) |*page, ref, *child| {
                        try ref.verify(page);
                        child.* = .{ .minimum = page.minimum(), .reference = ref };
                    }
                } else for (group, children) |*page, *child| child.* = try self.stage(page);
                offset += count;
            }
        }
        // At the leaf frontier, independent siblings share one bounded provider
        // batch. Destination pointers refer to the caller's stable child array;
        // none may be read or returned until flush has verified every locator.
        const LeafStages = struct {
            tree: Self,
            pages: [mutation_batch]Page = undefined,
            destinations: [mutation_batch]*Child = undefined,
            count: usize = 0,
            fn add(self: *LeafStages, page: Page, destination: *Child) !void {
                self.pages[self.count] = page;
                self.destinations[self.count] = destination;
                self.count += 1;
                if (self.count == mutation_batch) try self.flush();
            }
            fn flush(self: *LeafStages) !void {
                if (self.count == 0) return;
                var children: [mutation_batch]Child = undefined;
                try self.tree.stages(self.pages[0..self.count], children[0..self.count]);
                for (self.destinations[0..self.count], children[0..self.count]) |destination, child| destination.* = child;
                self.count = 0;
            }
        };
        fn leaves(entries: []const Entry, output: []Child, pending: *LeafStages) !usize {
            const count = std.math.divCeil(usize, entries.len, leaf_entries) catch unreachable;
            for (output[0..count], 0..) |*child, i| {
                // Leave room on both sides of a split. Packing the first page
                // full repeatedly splits the left spine on descending inserts.
                const group = entries[i * entries.len / count .. (i + 1) * entries.len / count];
                var page: Page = .{ .count = @intCast(group.len), .body = .{ .leaf = @splat(null) } };
                for (group, 0..) |entry, j| page.body.leaf[j] = entry;
                try pending.add(page, child);
            }
            return count;
        }
        fn branches(self: Self, children: []const Child, output: *Changed) !void {
            var batch: [(branch_children + budget + branch_children - 1) / branch_children]Page = undefined;
            const count = std.math.divCeil(usize, children.len, branch_children) catch unreachable;
            for (batch[0..count], 0..) |*page, i| {
                const group = children[i * children.len / count .. (i + 1) * children.len / count];
                page.* = .{ .height = output.height, .count = @intCast(group.len), .body = .{ .branch = @splat(null) } };
                for (group, 0..) |child, j| page.body.branch[j] = child;
            }
            try self.stages(batch[0..count], output.children[0..count]);
            output.count = count;
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
        /// Observe the largest key through one verified path. A maintenance
        /// pass can retain this scalar boundary without pinning a directory or
        /// letting later insertions extend its pass indefinitely.
        pub fn lastEntry(self: Self, root: ?Reference) !?Entry {
            var ref = root orelse return null;
            var height: ?u8 = null;
            for (0..max_height + 1) |_| {
                const page = try self.load(ref, height);
                switch (page.body) {
                    .leaf => |entries| return entries[page.count - 1].?,
                    .branch => |children| {
                        ref = children[page.count - 1].?.reference;
                        height = page.height - 1;
                    },
                }
            }
            return error.InvalidPageHeight;
        }
        /// One bounded immutable observation, in caller order. Pending paths
        /// partition the requested keys, so at most page_entries references and
        /// one decoded page are resident; ancestors are not retained recursively.
        pub fn getMany(self: Self, root: ?Reference, keys: []const Key) ![page_entries]?Value {
            if (keys.len > page_entries) return error.PageReadBudget;
            for (keys) |key| try key.validate();
            var values: [page_entries]?Value = @splat(null);
            if (keys.len == 0 or root == null) return values;
            const Work = struct { reference: Reference, height: ?u8, selected: [page_entries]bool };
            var pending: [page_entries]Work = undefined;
            pending[0] = .{ .reference = root.?, .height = null, .selected = @splat(false) };
            @memset(pending[0].selected[0..keys.len], true);
            var count: usize = 1;
            while (count != 0) {
                count -= 1;
                const work = pending[count];
                const page = try self.load(work.reference, work.height);
                switch (page.body) {
                    .leaf => |entries| for (keys, 0..) |key, i| {
                        if (!work.selected[i]) continue;
                        for (entries[0..page.count]) |slot| if (order(&slot.?.key, &key) == .eq) {
                            values[i] = slot.?.value;
                            break;
                        };
                    },
                    .branch => |children| for (children[0..page.count], 0..) |slot, child| {
                        var next: Work = .{ .reference = slot.?.reference, .height = page.height - 1, .selected = @splat(false) };
                        var selected = false;
                        for (keys, 0..) |key, i| if (work.selected[i] and childIndex(&page, &key) == child) {
                            next.selected[i] = true;
                            selected = true;
                        };
                        if (selected) {
                            std.debug.assert(count < keys.len);
                            pending[count] = next;
                            count += 1;
                        }
                    },
                }
            }
            return values;
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
        /// Rewrite each affected path once for a bounded atomic candidate.
        /// Staging is immutable; only the caller may publish the returned root.
        pub fn mutate(self: Self, root: ?Reference, mutations: []const Mutation) !?Reference {
            if (mutations.len > budget) return error.PageMutationBudget;
            if (mutations.len == 0) return root;
            var sorted: [budget]Mutation = undefined;
            for (mutations, 0..) |mutation, i| {
                try mutation.key.validate();
                if (mutation.key.len == 0) return error.InvalidPageValue;
                if (mutation.value) |value| try value.validate();
                sorted[i] = mutation;
            }
            std.mem.sort(Mutation, sorted[0..mutations.len], {}, struct {
                fn less(_: void, a: Mutation, b: Mutation) bool {
                    return order(&a.key, &b.key) == .lt;
                }
            }.less);
            for (1..mutations.len) |i| if (order(&sorted[i - 1].key, &sorted[i].key) == .eq) return error.DuplicatePageMutation;
            var changed = try self.mutatePage(root, null, sorted[0..mutations.len]);
            if (changed.count == 0) return null;
            while (changed.count > 1) {
                if (changed.height >= max_height) return error.PageDepthExceeded;
                var parent: Changed = .{ .height = changed.height + 1 };
                try self.branches(changed.children[0..changed.count], &parent);
                changed = parent;
            }
            var next = changed.children[0].reference;
            for (0..max_height + 1) |_| {
                const page = try self.load(next, null);
                if (page.body == .leaf or page.count != 1) return next;
                next = page.body.branch[0].?.reference;
            }
            return error.InvalidPageHeight;
        }
        const Changed = struct { children: [branch_children + budget]Child = undefined, count: usize = 0, height: u8 };
        /// Absorb split growth into sparse neighbors before growing the parent.
        /// Only adjacent pages at this level are loaded, two at a time; roots
        /// and all unaffected descendant references remain immutable.
        fn coalesce(self: Self, children: []Child, previous_count: usize, height: u8) !usize {
            var count = children.len;
            var index: usize = 0;
            while (count > previous_count and index + 1 < count) {
                var left = try self.load(children[index].reference, height);
                const right = try self.load(children[index + 1].reference, height);
                const combined = @as(usize, left.count) + right.count;
                const capacity: usize = if (height == 0) leaf_entries else branch_children;
                if (combined > capacity) {
                    index += 1;
                    continue;
                }
                if (height == 0) {
                    @memcpy(left.body.leaf[left.count..combined], right.body.leaf[0..right.count]);
                } else {
                    @memcpy(left.body.branch[left.count..combined], right.body.branch[0..right.count]);
                }
                left.count = @intCast(combined);
                children[index] = try self.stage(&left);
                std.mem.copyForwards(Child, children[index + 1 .. count - 1], children[index + 2 .. count]);
                count -= 1;
            }
            return count;
        }
        // Leaf merge workspace is not retained on recursive branch frames.
        // Its bound follows the private write set, not tree depth/cardinality.
        fn mutateLeaf(self: Self, original: ?Page, ref: ?Reference, mutations: []const Mutation) !Changed {
            var result: Changed = .{ .height = 0 };
            var pending: LeafStages = .{ .tree = self };
            result.count = try mutateLeafInto(original, ref, mutations, &result.children, &pending);
            try pending.flush();
            return result;
        }
        // Keep this merge workspace out of recursive branch frames. Its bound
        // depends on the command write set, never retained tree cardinality.
        fn mutateLeafInto(original: ?Page, ref: ?Reference, mutations: []const Mutation, output: []Child, pending: *LeafStages) !usize {
            var merged: [leaf_entries + budget]Entry = undefined;
            var count: usize = 0;
            var index: usize = 0;
            const previous_count: usize = if (original) |page| page.count else 0;
            for (mutations) |mutation| {
                while (index < previous_count and order(&original.?.body.leaf[index].?.key, &mutation.key) == .lt) : (index += 1) {
                    merged[count] = original.?.body.leaf[index].?;
                    count += 1;
                }
                if (index < previous_count and order(&original.?.body.leaf[index].?.key, &mutation.key) == .eq) index += 1;
                if (mutation.value) |value| {
                    merged[count] = .{ .key = mutation.key, .value = value };
                    count += 1;
                }
            }
            while (index < previous_count) : (index += 1) {
                merged[count] = original.?.body.leaf[index].?;
                count += 1;
            }
            if (original != null and count == previous_count) {
                const unchanged = for (merged[0..count], 0..) |entry, i| {
                    if (!std.meta.eql(entry, original.?.body.leaf[i].?)) break false;
                } else true;
                if (unchanged) {
                    output[0] = .{ .minimum = original.?.minimum(), .reference = ref.? };
                    return 1;
                }
            }
            return leaves(merged[0..count], output, pending);
        }
        // One leaf frontier at a time. The eight-page staging buffer is not
        // retained on ancestor frames and does not grow with the write set.
        fn mutateLeafChildren(self: Self, original: *const Page, mutations: []const Mutation, output: []Child) !usize {
            var pending: LeafStages = .{ .tree = self };
            var count: usize = 0;
            var first: usize = 0;
            const children = original.body.branch;
            for (children[0..original.count], 0..) |slot, i| {
                var end = first;
                while (end < mutations.len and (i + 1 == original.count or order(&mutations[end].key, &children[i + 1].?.minimum) == .lt)) : (end += 1) {}
                if (first == end) {
                    output[count] = slot.?;
                    count += 1;
                } else {
                    const page = try self.load(slot.?.reference, 0);
                    count += try mutateLeafInto(page, slot.?.reference, mutations[first..end], output[count..], &pending);
                }
                first = end;
            }
            try pending.flush();
            return count;
        }
        fn mutatePage(self: Self, ref: ?Reference, height: ?u8, mutations: []const Mutation) anyerror!Changed {
            const original: ?Page = if (ref) |reference| try self.load(reference, height) else null;
            const level: u8 = if (original) |page| page.height else 0;
            var result: Changed = .{ .height = level };
            if (level == 0) return self.mutateLeaf(original, ref, mutations);
            var merged: [branch_children + budget]Child = undefined;
            var count: usize = 0;
            var first: usize = 0;
            const children = original.?.body.branch;
            if (level == 1) {
                count = try self.mutateLeafChildren(&original.?, mutations, &merged);
            } else for (children[0..original.?.count], 0..) |slot, i| {
                var end = first;
                while (end < mutations.len and (i + 1 == original.?.count or order(&mutations[end].key, &children[i + 1].?.minimum) == .lt)) : (end += 1) {}
                if (first == end) {
                    merged[count] = slot.?;
                    count += 1;
                } else {
                    const changed = try self.mutatePage(slot.?.reference, level - 1, mutations[first..end]);
                    @memcpy(merged[count..][0..changed.count], changed.children[0..changed.count]);
                    count += changed.count;
                }
                first = end;
            }
            count = try self.coalesce(merged[0..count], original.?.count, level - 1);
            if (count == original.?.count) {
                const unchanged = for (merged[0..count], 0..) |child, i| {
                    if (!std.meta.eql(child, children[i].?)) break false;
                } else true;
                if (unchanged) {
                    result.children[0] = .{ .minimum = original.?.minimum(), .reference = ref.? };
                    result.count = 1;
                    return result;
                }
            }
            try self.branches(merged[0..count], &result);
            return result;
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
            return self.scanBound(root, after, false, null);
        }

        pub const Rewritten = struct { root: ?Reference, after: ?Key };
        /// Relocate one leaf and its path without changing any logical entries.
        /// A current-only cursor is a work hint, never a snapshot or authority.
        /// Concurrent insertions behind it are visited by the next pass.
        pub fn rewrite(self: Self, root: ?Reference, after: ?Key) !Rewritten {
            const reference = root orelse return .{ .root = null, .after = null };
            if (after) |key| try key.validate();
            const result = try self.rewritePage(reference, null, after);
            return .{ .root = result.reference, .after = result.after };
        }
        const Relocated = struct { reference: Reference, after: ?Key };
        fn rewritePage(self: Self, reference: Reference, height: ?u8, after: ?Key) anyerror!Relocated {
            var page = try self.load(reference, height);
            switch (page.body) {
                .leaf => |entries| {
                    const last = entries[page.count - 1].?.key;
                    if (after) |key| if (order(&last, &key) != .gt) return .{ .reference = reference, .after = null };
                    return .{ .reference = try self.store.stage(try page.reference(), &page), .after = last };
                },
                .branch => |children| {
                    for (children[0..page.count], 0..) |slot, i| {
                        if (after) |key| if (i + 1 < page.count and order(&children[i + 1].?.minimum, &key) != .gt) continue;
                        const child = try self.rewritePage(slot.?.reference, page.height - 1, after);
                        if (child.after) |last| {
                            page.body.branch[i].?.reference = child.reference;
                            return .{ .reference = try self.store.stage(try page.reference(), &page), .after = last };
                        }
                    }
                    return .{ .reference = reference, .after = null };
                },
            }
        }
        pub fn scanFrom(self: Self, root: ?Reference, first: Key) !Slice {
            return self.scanBound(root, first, true, null);
        }
        pub fn scanRange(self: Self, root: ?Reference, first: Key, inclusive: bool, until: Key) !Slice {
            try until.validate();
            if (order(&first, &until) != .lt) return error.InvalidPageRange;
            return self.scanBound(root, first, inclusive, until);
        }
        fn scanBound(self: Self, root: ?Reference, after: ?Key, inclusive: bool, until: ?Key) !Slice {
            if (after) |key| try key.validate();
            const ref = root orelse return .{};
            var found: [page_entries + 1]Entry = undefined;
            var count: usize = 0;
            try self.visit(ref, null, after, inclusive, until, &found, &count);
            var result: Slice = .{};
            for (found[0..@min(count, page_entries)], 0..) |entry, i| result.entries[i] = entry;
            if (count > page_entries) result.next = found[page_entries - 1].key;
            return result;
        }
        fn visit(self: Self, ref: Reference, height: ?u8, after: ?Key, inclusive: bool, until: ?Key, out: *[page_entries + 1]Entry, count: *usize) anyerror!void {
            const page = try self.load(ref, height);
            switch (page.body) {
                .leaf => |entries| for (entries[0..page.count]) |slot| {
                    if (until) |key| if (order(&slot.?.key, &key) != .lt) return;
                    if (after) |key| {
                        const comparison = order(&slot.?.key, &key);
                        if (comparison == .lt or (comparison == .eq and !inclusive)) continue;
                    }
                    out[count.*] = slot.?;
                    count.* += 1;
                    if (count.* == out.len) return;
                },
                .branch => |children| for (children[0..page.count], 0..) |slot, i| {
                    if (until) |key| if (order(&slot.?.minimum, &key) != .lt) return;
                    if (after) |key| if (i + 1 < page.count and order(&children[i + 1].?.minimum, &key) != .gt) continue;
                    try self.visit(slot.?.reference, page.height - 1, after, inclusive, until, out, count);
                    if (count.* == out.len) return;
                },
            }
        }
    };
}
