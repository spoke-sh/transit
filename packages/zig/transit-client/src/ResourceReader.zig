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
        const result = (try self.client.query(.{ .read_entries = .{ .resource = resource, .revision = revision, .keys = requested } })).body.read_entries;
        return .{ .resource = result.resource, .view = .{ .resource = resource, .revision = result.resource.revision }, .keys = requested, .entries = result.entries };
    }
};
