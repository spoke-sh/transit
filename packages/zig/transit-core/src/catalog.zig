//! Typed records over an immutable ordered index. A Catalog is a private
//! candidate; only an authority journal decision may publish its Snapshot.
const std = @import("std");
const pages = @import("pages.zig");
pub const version = 1;
pub const record_bytes = 2048;
pub const parser_bytes = 64 * 1024;
pub const Namespace = enum(u8) {
    principal = 1,
    process,
    resource,
    association,
    view,
    receipt,
    mailbox,
    output,
    effect,
    payload,
    pending_output,
    pending_effect,
    entry,
    required_association,
    associated_resource,
    required_resource_users,
    owner_required_users,
    association_order,
    pending_route,
    effects_by_pid,
    read_version,
    runtime_resource,
    payloads_by_pid,
    pending_destination,
    outputs_by_source,
    outputs_by_destination,
    resources_by_writer,
    resources_by_owner,
    views_by_pid,
    views_by_resource,
    versions_by_resource,
    versions_by_pid,
    associations_by_resource,
    retired_process,
    authorization_role,
    authorization_name,
    authorization_object,
    authorization_domain,
    authorization_membership,
    authorization_member,
    authorization_grant,
    authorization_realm_grant,
    authorization_process_grant,
    authorization_resource_grant,
    authorization_domain_grant,
    authorization_default,
    authorization_creator_default,
    authorization_credential,
    authorization_change,
    authorization_outcome,
    authorization_native_resource_grant,
    authorization_binding,
    authorization_registration,
    authorization_origin,
    resource_blocks,
};
pub const Snapshot = struct {
    version: u32 = version,
    root: ?pages.Reference = null,
    records: u64 = 0,
    pub fn validate(self: Snapshot) !void {
        if (self.version != version) return error.UnsupportedCatalogVersion;
        if ((self.root == null) != (self.records == 0)) return error.InvalidCatalogSnapshot;
    }
};

/// Full-width identities have a canonical big-endian ordering. No identity is
/// an array offset. Suffixes are opaque and cannot cross namespace boundaries.
pub fn key(namespace: Namespace, major: u64, minor: u64, suffix: []const u8) !pages.Key {
    if (suffix.len > 47) return error.CatalogKeyTooLarge;
    var bytes: [64]u8 = undefined;
    bytes[0] = @backingInt(namespace);
    std.mem.writeInt(u64, bytes[1..9], major, .big);
    std.mem.writeInt(u64, bytes[9..17], minor, .big);
    @memcpy(bytes[17..][0..suffix.len], suffix);
    return pages.Key.init(bytes[0 .. 17 + suffix.len]);
}
pub const Range = struct {
    namespace: Namespace,
    major: ?u64 = null,
    minor: ?u64 = null,
    pub fn prefix(self: Range) pages.Key {
        std.debug.assert(self.minor == null or self.major != null);
        var bytes: [17]u8 = undefined;
        bytes[0] = @backingInt(self.namespace);
        if (self.major) |id| std.mem.writeInt(u64, bytes[1..9], id, .big);
        if (self.minor) |id| std.mem.writeInt(u64, bytes[9..17], id, .big);
        return pages.Key.init(bytes[0..if (self.minor != null) @as(usize, 17) else if (self.major != null) @as(usize, 9) else 1]) catch unreachable;
    }
    pub fn end(self: Range) pages.Key {
        var value = self.prefix();
        var i: usize = value.len;
        while (i > 0) {
            i -= 1;
            if (value.data[i] != 255) {
                value.data[i] += 1;
                return pages.Key.init(value.data[0 .. i + 1]) catch unreachable;
            }
        }
        unreachable; // Namespace tags are strictly below 255.
    }
};
fn validateKey(value: *const pages.Key) !void {
    try value.validate();
    if (value.len < 17) return error.InvalidCatalogKey;
    _ = std.enums.fromInt(Namespace, value.data[0]) orelse return error.InvalidCatalogKey;
}
fn encode(value: anytype) !pages.Value {
    var bytes: [record_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(value, .{}, &writer) catch return error.CatalogRecordTooLarge;
    return pages.Value.init(writer.buffered());
}
pub fn putMutation(address: pages.Key, value: anytype) !pages.Mutation {
    comptime owned(@TypeOf(value));
    try validateKey(&address);
    return .{ .key = address, .value = try encode(value) };
}
fn owned(comptime T: type) void {
    switch (@typeInfo(T)) {
        .pointer => @compileError("Catalog records must own all bytes; slices/pointers are not persistent values"),
        .optional => |info| owned(info.child),
        .array => |info| owned(info.child),
        inline .@"struct", .@"union" => |info| inline for (info.field_types) |Child| owned(Child),
        else => {},
    }
}
pub fn decode(comptime T: type, value: *const pages.Value) !T {
    comptime owned(T);
    // A bounded record cannot grow parser memory with total catalog cardinality.
    var workspace: [parser_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&workspace);
    const parsed = try std.json.parseFromSlice(T, fixed.allocator(), value.slice(), .{});
    defer parsed.deinit();
    return parsed.value;
}
pub fn Batch(comptime T: type) type {
    return struct {
        pub const Record = struct { key: pages.Key, value: T };
        records: [pages.page_entries]?Record = @splat(null),
        next: ?pages.Key = null,
    };
}

/// Verified immutable control records, keyed by the entire catalog root.
/// Data scans cannot evict them. This supplies bytes to normal validation,
/// never a cached permission decision or a substitute for an authority barrier.
pub const RecordCache = struct {
    const capacity = 16;
    const Cached = struct { key: pages.Key, value: ?pages.Value };
    root: ?pages.Reference = null,
    entries: [capacity]?Cached = @splat(null),
    next: usize = 0,
    hits: u64 = 0,
    misses: u64 = 0,
    fn select(self: *RecordCache, root: ?pages.Reference) void {
        if (!std.meta.eql(root, self.root)) {
            self.entries = @splat(null);
            self.root = root;
            self.next = 0;
        }
    }
    fn eligible(key_value: pages.Key) bool {
        const namespace: Namespace = @fromBackingInt(@intCast(key_value.data[0]));
        return switch (namespace) {
            .principal, .process, .resource, .association, .associated_resource, .required_association, .required_resource_users, .owner_required_users => true,
            .authorization_role, .authorization_credential, .authorization_object, .authorization_grant => true,
            else => false,
        };
    }
};

/// Bounded verified policy pages, including empty pages and continuation keys.
/// Identity is the complete immutable root, namespace range and exact cursor.
/// Evaluation still charges and validates every record on every request.
pub const PolicyScanCache = struct {
    pub const capacity = 8;
    const Cached = struct { range: Range, after: ?pages.Key, page: pages.Slice };
    root: ?pages.Reference = null,
    entries: [capacity]?Cached = @splat(null),
    next: usize = 0,
    hits: u64 = 0,
    misses: u64 = 0,

    fn select(self: *PolicyScanCache, root: ?pages.Reference) void {
        if (!std.meta.eql(root, self.root)) {
            self.entries = @splat(null);
            self.root = root;
            self.next = 0;
        }
    }
    fn eligible(range: Range) bool {
        return switch (range.namespace) {
            .authorization_member,
            .authorization_realm_grant,
            .authorization_process_grant,
            .authorization_resource_grant,
            .authorization_domain_grant,
            => true,
            else => false,
        };
    }
};

/// Complete native turn: closed views, rows/resource, outputs/effect, process,
/// principal/receipt, and retained-version creation/release. The bound follows
/// per-command protocol limits; it is independent of durable catalog size.
pub const Candidate = struct {
    const g = @import("root.zig").protocol.Growth;
    // One resource metadata record and its independently paged block root.
    pub const capacity = g.turn_views * 3 + g.turn_mutations + 2 + g.turn_outputs * 6 + 3 + 1 + 2 + g.version_changes * 6;
    mutations: [capacity]pages.Mutation = undefined,
    len: usize = 0,
    fn put(self: *Candidate, mutation: pages.Mutation) !void {
        for (self.mutations[0..self.len]) |*previous| {
            if (std.mem.eql(u8, previous.key.slice(), mutation.key.slice())) {
                previous.* = mutation;
                return;
            }
        }
        if (self.len == capacity) return error.CandidateMutationBudget;
        self.mutations[self.len] = mutation;
        self.len += 1;
    }
};

pub fn Catalog(comptime Store: type) type {
    return struct {
        const Self = @This();
        tree: pages.Tree(Store),
        snapshot: Snapshot,
        record_cache: ?*RecordCache = null,
        policy_scan_cache: ?*PolicyScanCache = null,
        pending: ?*Candidate = null,

        pub fn open(store: *Store, snapshot: Snapshot) !Self {
            try snapshot.validate();
            return .{ .tree = .{ .store = store }, .snapshot = snapshot };
        }
        pub fn get(self: *const Self, comptime T: type, address: pages.Key) !?T {
            try validateKey(&address);
            const value = (try self.getBytes(address)) orelse return null;
            return try decode(T, &value);
        }
        /// Bounded data reads at this root, without caching permission decisions.
        pub fn getMany(self: *const Self, comptime T: type, addresses: []const pages.Key) ![pages.page_entries]?T {
            if (addresses.len > pages.page_entries) return error.PageReadBudget;
            for (addresses) |address| try validateKey(&address);
            var values = try self.tree.getMany(self.snapshot.root, addresses);
            if (self.pending) |pending| for (addresses, 0..) |address, i| {
                for (pending.mutations[0..pending.len]) |mutation| if (std.mem.eql(u8, mutation.key.slice(), address.slice())) {
                    values[i] = mutation.value;
                    break;
                };
            };
            var result: [pages.page_entries]?T = @splat(null);
            for (values, 0..) |value, i| if (value) |bytes| {
                result[i] = try decode(T, &bytes);
            };
            return result;
        }
        fn getBytes(self: *const Self, address: pages.Key) !?pages.Value {
            if (self.pending) |pending| for (pending.mutations[0..pending.len]) |mutation| {
                if (std.mem.eql(u8, mutation.key.slice(), address.slice())) return mutation.value;
            };
            const cache = if (RecordCache.eligible(address)) self.record_cache else null;
            if (cache) |records| {
                records.select(self.snapshot.root);
                for (records.entries) |slot| if (slot) |cached| {
                    if (std.mem.eql(u8, cached.key.slice(), address.slice())) {
                        records.hits +|= 1;
                        return cached.value;
                    }
                };
                records.misses +|= 1;
            }
            const value = try self.tree.get(self.snapshot.root, address);
            if (cache) |records| {
                records.entries[records.next] = .{ .key = address, .value = value };
                records.next = (records.next + 1) % RecordCache.capacity;
            }
            return value;
        }
        pub fn put(self: *Self, address: pages.Key, value: anytype) !void {
            comptime owned(@TypeOf(value));
            try validateKey(&address);
            const bytes = try encode(value);
            if (self.pending) |pending| return pending.put(.{ .key = address, .value = bytes });
            const exists = try self.tree.get(self.snapshot.root, address) != null;
            const count = if (exists) self.snapshot.records else try std.math.add(u64, self.snapshot.records, 1);
            // Construct completely before changing the candidate. A failed page
            // stage may leave unreachable bytes but never a half-updated root.
            const next = try self.tree.put(self.snapshot.root, address, bytes);
            self.snapshot = .{ .root = next, .records = count };
        }
        pub fn mutate(self: *Self, mutations: []const pages.Mutation) !void {
            if (mutations.len > pages.mutation_batch) return error.PageMutationBudget;
            var addresses: [pages.mutation_batch]pages.Key = undefined;
            for (mutations, 0..) |mutation, i| {
                try validateKey(&mutation.key);
                if (mutation.value) |value| try value.validate();
                for (mutations[0..i]) |previous| if (std.mem.eql(u8, previous.key.slice(), mutation.key.slice())) return error.DuplicatePageMutation;
                addresses[i] = mutation.key;
            }
            if (self.pending) |pending| {
                for (mutations) |mutation| try pending.put(mutation);
                return;
            }
            // Count against one immutable cut before staging. Share paths for
            // this bounded batch, just as native point reads do; retain no
            // observations across candidates or authority changes.
            const previous = try self.tree.getMany(self.snapshot.root, addresses[0..mutations.len]);
            var added: u64 = 0;
            var removed: u64 = 0;
            for (mutations, 0..) |mutation, i| {
                const exists = previous[i] != null;
                if (mutation.value != null and !exists) added += 1;
                if (mutation.value == null and exists) removed += 1;
            }
            const records = try std.math.add(u64, try std.math.sub(u64, self.snapshot.records, removed), added);
            const next = try self.tree.mutate(self.snapshot.root, mutations);
            self.snapshot = .{ .root = next, .records = records };
        }
        /// Structural removal only. The authority must independently establish
        /// retention/deletion permission; this method grants neither.
        pub fn remove(self: *Self, address: pages.Key) !void {
            try validateKey(&address);
            if (self.pending) |pending| return pending.put(.{ .key = address, .value = null });
            if (try self.tree.get(self.snapshot.root, address) == null) return;
            const next = try self.tree.remove(self.snapshot.root, address);
            self.snapshot = .{ .root = next, .records = try std.math.sub(u64, self.snapshot.records, 1) };
        }
        /// Stage only after validating the complete command. Failure retains
        /// the old snapshot; staged orphan bytes grant no publication authority.
        pub fn flush(self: *Self) !void {
            const pending = self.pending orelse return;
            var records = self.snapshot.records;
            var offset: usize = 0;
            while (offset < pending.len) {
                const group = pending.mutations[offset..@min(offset + pages.page_entries, pending.len)];
                var keys: [pages.page_entries]pages.Key = undefined;
                for (group, 0..) |mutation, i| keys[i] = mutation.key;
                const previous = try self.tree.getMany(self.snapshot.root, keys[0..group.len]);
                for (group, 0..) |mutation, i| {
                    if (previous[i] == null and mutation.value != null) records = try std.math.add(u64, records, 1);
                    if (previous[i] != null and mutation.value == null) records = try std.math.sub(u64, records, 1);
                }
                offset += group.len;
            }
            const tree: pages.BoundedTree(Store, Candidate.capacity) = .{ .store = self.tree.store };
            const root = try tree.mutate(self.snapshot.root, pending.mutations[0..pending.len]);
            self.snapshot = .{ .root = root, .records = records };
            self.pending = null;
        }
        pub fn scan(self: *const Self, comptime T: type, range: Range, after: ?pages.Key) !Batch(T) {
            // Deferred candidates are enabled only for commands whose reads are
            // points. Never silently scan an earlier cut after private writes.
            if (self.pending) |pending| if (pending.len != 0) return error.UnflushedCandidateScan;
            const prefix = range.prefix();
            if (after) |cursor| {
                try validateKey(&cursor);
                if (!std.mem.startsWith(u8, cursor.slice(), prefix.slice())) return error.InvalidCatalogCursor;
            }
            const page = try self.scanBytes(range, after);
            var result: Batch(T) = .{};
            for (page.entries, 0..) |slot, i| if (slot) |entry| {
                if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return result;
                try validateKey(&entry.key);
                result.records[i] = .{ .key = entry.key, .value = try decode(T, &entry.value) };
            };
            result.next = page.next;
            return result;
        }
        fn scanBytes(self: *const Self, range: Range, after: ?pages.Key) !pages.Slice {
            const cache = if (PolicyScanCache.eligible(range)) self.policy_scan_cache else null;
            if (cache) |scans| {
                scans.select(self.snapshot.root);
                for (&scans.entries) |*slot| if (slot.*) |*cached| {
                    if (std.meta.eql(cached.range, range) and std.meta.eql(cached.after, after)) {
                        scans.hits +|= 1;
                        return cached.page;
                    }
                };
                scans.misses +|= 1;
            }
            const page = try self.tree.scanRange(self.snapshot.root, after orelse range.prefix(), after == null, range.end());
            if (cache) |scans| {
                scans.entries[scans.next] = .{ .range = range, .after = after, .page = page };
                scans.next = (scans.next + 1) % PolicyScanCache.capacity;
            }
            return page;
        }
    };
}
