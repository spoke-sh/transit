//! Typed records over an immutable ordered index. A Catalog is a private
//! candidate; only an authority journal decision may publish its Snapshot.
const std = @import("std");
const pages = @import("pages.zig");
pub const version = 2;
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
    grant,
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

pub fn Catalog(comptime Store: type) type {
    return struct {
        const Self = @This();
        tree: pages.Tree(Store),
        snapshot: Snapshot,

        pub fn open(store: *Store, snapshot: Snapshot) !Self {
            try snapshot.validate();
            return .{ .tree = .{ .store = store }, .snapshot = snapshot };
        }
        pub fn get(self: *const Self, comptime T: type, address: pages.Key) !?T {
            try validateKey(&address);
            const value = (try self.tree.get(self.snapshot.root, address)) orelse return null;
            return try decode(T, &value);
        }
        pub fn put(self: *Self, address: pages.Key, value: anytype) !void {
            comptime owned(@TypeOf(value));
            try validateKey(&address);
            const bytes = try encode(value);
            const exists = try self.tree.get(self.snapshot.root, address) != null;
            const count = if (exists) self.snapshot.records else try std.math.add(u64, self.snapshot.records, 1);
            // Construct completely before changing the candidate. A failed page
            // stage may leave unreachable bytes but never a half-updated root.
            const next = try self.tree.put(self.snapshot.root, address, bytes);
            self.snapshot = .{ .root = next, .records = count };
        }
        /// Structural removal only. The authority must independently establish
        /// retention/deletion permission; this method grants neither.
        pub fn remove(self: *Self, address: pages.Key) !void {
            try validateKey(&address);
            if (try self.tree.get(self.snapshot.root, address) == null) return;
            const next = try self.tree.remove(self.snapshot.root, address);
            self.snapshot = .{ .root = next, .records = try std.math.sub(u64, self.snapshot.records, 1) };
        }
        pub fn scan(self: *const Self, comptime T: type, range: Range, after: ?pages.Key) !Batch(T) {
            const prefix = range.prefix();
            if (after) |cursor| {
                try validateKey(&cursor);
                if (!std.mem.startsWith(u8, cursor.slice(), prefix.slice())) return error.InvalidCatalogCursor;
            }
            const page = if (after) |cursor| try self.tree.scan(self.snapshot.root, cursor) else try self.tree.scanFrom(self.snapshot.root, prefix);
            var result: Batch(T) = .{};
            for (page.entries, 0..) |slot, i| if (slot) |entry| {
                if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return result;
                try validateKey(&entry.key);
                result.records[i] = .{ .key = entry.key, .value = try decode(T, &entry.value) };
            };
            result.next = page.next;
            return result;
        }
    };
}
