//! Public read adapter. Each bounded call fetches a fresh current resource cut;
//! completed immutable content is identified by its coverage commitment. This
//! requires read grants, not ownership of a retained execution source.
const std = @import("std");
const x = @import("root.zig");
const p = x.p;
const g = p.Growth;
const Self = @This();
wire: *x.station.client.Client,
realm: u64,
principal: u64,
key: p.Ed25519.KeyPair,
pub const Reference = struct {
    pub const magic = "EXR1";
    resource: u64,
    exchange: u64,
    chain: [32]u8,
    pub fn validate(self: Reference) !void {
        if (self.resource == 0 or self.exchange == 0) return error.InvalidExchangeRecord;
    }
    pub fn encode(self: Reference) !p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: p.Value) !Reference {
        return x.codec.decode(Reference, value);
    }
};
pub const Reader = struct {
    client: *Self,
    view: struct { id: u64 = 0, resource: u64, revision: u64 },
    pub fn read(self: *Reader, key: p.Value) !?p.Value {
        const result = (try self.client.query(.{ .entries = .{ .resource = self.view.resource, .revision = self.view.revision, .key = key } })).body.entries;
        return if (result.page.entries[0]) |entry| entry.value else null;
    }
};
pub fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    return self.wire.queryGrowing(.{ .realm = self.realm, .principal = self.principal, .kind = kind }, self.key);
}
pub fn reader(self: *Self, resource: u64) !Reader {
    const meta = (try self.query(.{ .resource = resource })).body.resource;
    if (meta.phase != .active) return error.ExchangeUnavailable;
    return .{ .client = self, .view = .{ .resource = resource, .revision = meta.revision } };
}
pub fn inspect(self: *Self, resource: u64, id: u64) !x.Descriptor {
    var source = try self.reader(resource);
    return (x.Exchange{ .resource = resource, .id = id }).inspect(&source);
}
pub fn open(self: *Self, reference: Reference) !x.Exchange.Cursor {
    try reference.validate();
    var source = try self.reader(reference.resource);
    const ex: x.Exchange = .{ .resource = reference.resource, .id = reference.exchange };
    const cursor = try ex.open(&source, &source);
    if (!std.mem.eql(u8, &reference.chain, &cursor.descriptor.chain)) return error.InvalidExchangeCoverage;
    return cursor;
}
pub fn read(self: *Self, reference: Reference, cursor: x.Exchange.Cursor) !x.Exchange.Part {
    try reference.validate();
    if (!std.mem.eql(u8, &reference.chain, &cursor.descriptor.chain)) return error.InvalidExchangeCoverage;
    var source = try self.reader(reference.resource);
    const ex: x.Exchange = .{ .resource = reference.resource, .id = reference.exchange };
    const current = try ex.open(&source, &source);
    if (!std.meta.eql(current.descriptor, cursor.descriptor)) return error.StaleExchangeSource;
    var resumed = cursor;
    if (cursor.member_cursor) |previous| {
        // A different root may add other exchanges. Rebind only after proving
        // this group's complete manifest and member commitment unchanged. The
        // accumulated digest still verifies every returned byte at completion.
        var next = try ex.publication().open(&source, previous.id);
        if (!std.meta.eql(next.spec, previous.spec) or previous.id != @as(u64, cursor.next_member) + 1) return error.InvalidExchangeCoverage;
        next.index = previous.index;
        next.chain = previous.chain;
        resumed.member_cursor = next;
    }
    return ex.read(&source, &source, resumed);
}
