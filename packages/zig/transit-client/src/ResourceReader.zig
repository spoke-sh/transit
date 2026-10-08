//! Bounded reads at one exact current resource revision. Every operation checks
//! current authority; this owns neither a retained version nor execution rights.
const root = @import("root.zig");
const p = root.protocol;
const g = p.Growth;
const Self = @This();
wire: *root.Client,
realm: u64,
principal: u64,
key: p.Ed25519.KeyPair,
/// Optional owned evidence from this reader's failing operation. Never consult
/// a later metadata read or a rejection left by another use of the wire client.
failure: ?*?Failure = null,
pub const Failure = union(enum) {
    rejected: struct { resource: u64, cause: p.ErrorCode },
    unavailable: g.Resource,
};
pub fn withFailure(self: Self, context: *?Failure) Self {
    context.* = null;
    var reader = self;
    reader.failure = context;
    return reader;
}
pub const Reader = struct {
    client: Self,
    view: struct { id: u64 = 0, resource: u64, revision: u64 },
    failed: ?anyerror = null,
    pub fn read(self: *Reader, address: p.Value) !?p.Value {
        return if (try self.entry(address)) |value| value.value else null;
    }
    /// Exact entry metadata at this reader's cut; revision is resource-local.
    pub fn entry(self: *Reader, address: p.Value) !?g.Entry {
        const batch = try self.fetch(address, null);
        if (batch.next != null) {
            self.failed = error.InvalidResourceRead;
            return error.InvalidResourceRead;
        }
        for (batch.entries[1..]) |slot| if (slot != null) {
            self.failed = error.InvalidResourceRead;
            return error.InvalidResourceRead;
        };
        if (batch.entries[0]) |item| {
            if (!item.key.eql(address)) {
                self.failed = error.InvalidResourceRead;
                return error.InvalidResourceRead;
            }
            return item;
        }
        return null;
    }
    pub fn page(self: *Reader, after: ?p.Value) !g.Batch(g.Entry, p.Value) {
        return self.fetch(null, after);
    }
    fn fetch(self: *Reader, address: ?p.Value, after: ?p.Value) !g.Batch(g.Entry, p.Value) {
        if (self.failed) |err| return err;
        const response = self.client.query(.{ .entries = .{ .resource = self.view.resource, .revision = self.view.revision, .key = address, .after = after } }) catch |err| {
            self.failed = err;
            return err;
        };
        const result = switch (response.body) {
            .entries => |value| value,
            else => {
                self.failed = error.InvalidResourceRead;
                return error.InvalidResourceRead;
            },
        };
        if (result.resource.id != self.view.resource or result.resource.revision != self.view.revision or result.resource.phase != .active) {
            self.failed = error.InvalidResourceRead;
            return error.InvalidResourceRead;
        }
        return result.page;
    }
};
pub fn query(self: Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    if (self.failure) |context| context.* = null;
    return self.wire.query(.{ .realm = self.realm, .principal = self.principal, .kind = kind }, self.key) catch |err| {
        if (err == error.Rejected or err == error.Conflict or err == error.AccessDenied) {
            if (self.wire.last_rejection) |cause| if (self.failure) |context| {
                context.* = .{ .rejected = .{ .resource = switch (kind) {
                    .resource, .read_access => |id| id,
                    .entries => |input| input.resource orelse 0,
                    .read_entries => |input| input.resource,
                    else => 0,
                }, .cause = cause } };
            };
        }
        if (err == error.Rejected) switch (self.wire.last_rejection orelse return err) {
            .StateResourceExpired, .UnknownStateResource, .RetiredProcess => return error.ResourceUnavailable,
            else => {},
        };
        return err;
    };
}
pub fn open(self: Self, resource: u64) !Reader {
    const response = try self.query(.{ .resource = resource });
    const metadata = switch (response.body) {
        .resource => |value| value,
        else => return error.InvalidResourceRead,
    };
    if (metadata.id != resource or metadata.phase != .active) {
        if (self.failure) |context| context.* = .{ .unavailable = metadata };
        return error.ResourceUnavailable;
    }
    return .{ .client = self, .view = .{ .resource = resource, .revision = metadata.revision } };
}

/// One owned observation, not a retained version or an authorization cache.
/// It supports only the requested keys. Consumers revalidate current authority
/// before disclosure and never reuse it across independent acquisitions.
pub const Batch = struct {
    /// Native authority position for advisory waits, never a resource revision.
    position: u64 = 0,
    resource: g.Resource,
    view: struct { id: u64 = 0, resource: u64, revision: u64 },
    keys: [g.page_size]?p.Value,
    entries: [g.page_size]?g.Entry,
    pub fn read(self: *const Batch, key: p.Value) !?p.Value {
        return if (try self.entry(key)) |item| item.value else null;
    }
    pub fn entry(self: *const Batch, key: p.Value) !?g.Entry {
        for (self.keys, self.entries) |slot, item| if (slot) |requested| {
            if (requested.eql(key)) return item;
        };
        return error.UnrequestedResourceKey;
    }
};
pub fn readBatch(self: Self, resource: u64, revision: ?u64, keys: []const p.Value) !Batch {
    return (try self.batches()).read(resource, revision, keys);
}
/// Negotiate immutable protocol support once. The handle caches no permission,
/// resource metadata or values; each read still uses current signed authority.
pub fn batches(self: Self) !Batches {
    return Batches.init(self, (try self.query(.capabilities)).body.capabilities);
}
pub const Batches = struct {
    client: Self,
    pub fn cached(self: Batches, seed: Batch) Cached(Batches) {
        return Cached(Batches).init(self, seed);
    }
    /// Reuse the checked capability reply for this same caller/connection.
    /// This accepts protocol support only; every read rechecks current rights.
    pub fn init(client: Self, capabilities: g.Capabilities) !Batches {
        if (!capabilities.resource_read_batch) return error.ResourceReadBatchUnavailable;
        return .{ .client = client };
    }
    pub fn read(self: Batches, resource: u64, revision: ?u64, keys: []const p.Value) !Batch {
        if (keys.len == 0 or keys.len > g.page_size) return error.InvalidResourceRead;
        var requested: [g.page_size]?p.Value = @splat(null);
        for (keys, 0..) |key, i| requested[i] = key;
        const response = try self.client.query(.{ .read_entries = .{ .resource = resource, .revision = revision, .keys = requested } });
        const result = response.body.read_entries;
        return .{ .position = response.position, .resource = result.resource, .view = .{ .resource = resource, .revision = result.resource.revision }, .keys = requested, .entries = result.entries };
    }
};

/// Bounded scratch for one exact observation. Discard it after the operation;
/// it retains neither a resource version nor permission. Missing entries are
/// cached too. Callers still need fresh authorization before disclosure.
pub fn Cached(comptime Backend: type) type {
    return struct {
        const Cache = @This();
        backend: Backend,
        view: @FieldType(Batch, "view"),
        resource: g.Resource,
        slots: [64]?struct { key: p.Value, entry: ?g.Entry } = @splat(null),
        next: usize = 0,
        failed: ?anyerror = null,

        pub fn init(backend: Backend, seed: Batch) Cache {
            var result: Cache = .{ .backend = backend, .view = seed.view, .resource = seed.resource };
            for (seed.keys, seed.entries) |key, value| if (key) |requested| result.remember(requested, value);
            return result;
        }
        fn remember(self: *Cache, key: p.Value, value: ?g.Entry) void {
            self.slots[self.next] = .{ .key = key, .entry = value };
            self.next = (self.next + 1) % self.slots.len;
        }
        pub fn read(self: *Cache, key: p.Value) !?p.Value {
            return if (try self.entry(key)) |value| value.value else null;
        }
        pub fn entry(self: *Cache, key: p.Value) !?g.Entry {
            if (self.failed) |err| return err;
            for (self.slots) |slot| if (slot) |value| if (value.key.eql(key)) return value.entry;
            try self.prefetch(&.{key});
            for (self.slots) |slot| if (slot) |value| if (value.key.eql(key)) return value.entry;
            return error.InvalidResourceRead;
        }
        pub fn prefetch(self: *Cache, keys: []const p.Value) !void {
            if (self.failed) |err| return err;
            self.fetch(keys) catch |err| {
                self.failed = err;
                return err;
            };
        }
        fn fetch(self: *Cache, keys: []const p.Value) !void {
            if (keys.len > g.page_size) return error.InvalidResourceRead;
            var missing: [g.page_size]p.Value = undefined;
            var count: usize = 0;
            outer: for (keys) |key| {
                for (self.slots) |slot| if (slot) |value| if (value.key.eql(key)) continue :outer;
                for (missing[0..count]) |previous| if (previous.eql(key)) continue :outer;
                missing[count] = key;
                count += 1;
            }
            if (count == 0) return;
            const batch = try self.backend.read(self.view.resource, self.view.revision, missing[0..count]);
            if (!@import("std").meta.eql(batch.resource, self.resource) or !@import("std").meta.eql(batch.view, self.view)) return error.InvalidResourceRead;
            for (missing[0..count]) |key| self.remember(key, try batch.entry(key));
        }
    };
}

test "one-cut cache bounds memory, coalesces misses and preserves read poison" {
    const std = @import("std");
    const t = std.testing;
    const Backend = struct {
        calls: *usize,
        change_cut: *bool,
        pub fn read(self: @This(), resource: u64, revision: ?u64, keys: []const p.Value) !Batch {
            self.calls.* += 1;
            const cut = revision.? + @as(u64, if (self.change_cut.*) 1 else 0);
            var result: Batch = .{ .resource = .{ .id = resource, .writer = 2, .owner = null, .revision = cut, .deadline_ms = null }, .view = .{ .resource = resource, .revision = cut }, .keys = @splat(null), .entries = @splat(null) };
            for (keys, 0..) |key, i| {
                result.keys[i] = key;
                if (!key.eql(try p.Value.init("absent"))) result.entries[i] = .{ .key = key, .value = key, .revision = cut };
            }
            return result;
        }
    };
    var calls: usize = 0;
    var change_cut = false;
    const backend: Backend = .{ .calls = &calls, .change_cut = &change_cut };
    const first = try p.Value.init("seed");
    const second = try p.Value.init("next");
    const absent = try p.Value.init("absent");
    var cache = Cached(Backend).init(backend, try backend.read(7, 9, &.{first}));
    try t.expect((try cache.read(first)).?.eql(first));
    try t.expectEqual(@as(usize, 1), calls);
    try cache.prefetch(&.{ first, second, absent, second });
    try t.expectEqual(@as(usize, 2), calls);
    try t.expect((try cache.read(second)).?.eql(second));
    try t.expect(try cache.read(absent) == null);
    try t.expectEqual(@as(usize, 2), calls);
    for (0..65) |i| {
        const key = p.Value.integer(@intCast(i));
        try t.expect((try cache.read(key)).?.eql(key));
    }
    const before = calls;
    try t.expect((try cache.read(first)).?.eql(first));
    try t.expectEqual(before + 1, calls); // Eviction is a miss, never a collection limit.
    change_cut = true;
    try t.expectError(error.InvalidResourceRead, cache.read(try p.Value.init("foreign")));
    const failed = calls;
    try t.expectError(error.InvalidResourceRead, cache.read(first));
    try t.expectEqual(failed, calls); // Even cached data cannot clear a failed read.
}
