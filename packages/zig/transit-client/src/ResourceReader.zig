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
pub const Reader = struct {
    client: Self,
    view: struct { id: u64 = 0, resource: u64, revision: u64 },
    failed: ?anyerror = null,
    pub fn read(self: *Reader, address: p.Value) !?p.Value {
        const batch = try self.fetch(address, null);
        if (batch.next != null) {
            self.failed = error.InvalidResourceRead;
            return error.InvalidResourceRead;
        }
        for (batch.entries[1..]) |entry| if (entry != null) {
            self.failed = error.InvalidResourceRead;
            return error.InvalidResourceRead;
        };
        if (batch.entries[0]) |entry| {
            if (!entry.key.eql(address)) {
                self.failed = error.InvalidResourceRead;
                return error.InvalidResourceRead;
            }
            return entry.value;
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
    return self.wire.queryGrowing(.{ .realm = self.realm, .principal = self.principal, .kind = kind }, self.key);
}
pub fn open(self: Self, resource: u64) !Reader {
    const response = try self.query(.{ .resource = resource });
    const metadata = switch (response.body) {
        .resource => |value| value,
        else => return error.InvalidResourceRead,
    };
    if (metadata.id != resource or metadata.phase != .active) return error.ResourceUnavailable;
    return .{ .client = self, .view = .{ .resource = resource, .revision = metadata.revision } };
}
