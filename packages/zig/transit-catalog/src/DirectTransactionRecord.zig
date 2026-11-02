//! Immutable result staging owned by an original transaction. Registration
//! precedes object creation; only authoritative abort cleanup releases bytes.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const r = @import("DirectCatalogRecords.zig");
const pages = c.storage.TreeStore.pages;
const R = c.DirectRecord;

pub const format: u32 = 0x54585231; // TXR1
pub const metadata_charge: u64 = 32 * 1024;
pub const Request = struct {
    transaction: c.DirectClientToken.Key,
    format: u32,
    bytes: c.DirectTableProtocol.Binary,

    pub fn validate(self: Request) !void {
        try self.transaction.validate();
        if (self.format & R.guarded_bit == 0) return error.InvalidTransactionRecord;
    }
};
pub const Envelope = struct {
    definition: p.Growth.Definition,
    transaction: c.DirectClientToken.Key,
    format: u32,
    payload: c.DirectTableProtocol.Binary,

    pub fn validate(self: Envelope, reference: R.Reference) !void {
        try self.transaction.validate();
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (reference.format != format or self.format & R.guarded_bit == 0 or
            !std.meta.eql(self.transaction.scope(), reference.scope)) return error.InvalidTransactionRecord;
    }
};
/// Mandatory persisted fields. Pending reservations cannot be committed. Bytes
/// include fixed metadata allowances and share the transaction work quota.
pub const Directory = struct {
    entries: ?pages.Reference,
    count: u64,
    pending: u64,
    bytes: u64,

    pub const empty: Directory = .{ .entries = null, .count = 0, .pending = 0, .bytes = 0 };
    pub fn validate(self: Directory) !void {
        if ((self.entries == null) != (self.count == 0) or self.pending > self.count or
            self.bytes / metadata_charge < self.count) return error.InvalidTransactionRecord;
    }
};
pub const Entry = struct {
    content: p.DataLifecycle.Content,
    ready: bool,
    pub fn validate(self: Entry) !void {
        try self.content.validate();
        if (self.content.bytes == 0 or self.content.bytes > R.max_bytes) return error.InvalidTransactionRecord;
    }
};
pub const Publication = struct { transaction: c.DirectClientToken.Key, entry: Entry };

pub fn ownerKey(key: c.DirectClientToken.Key) !pages.Key {
    return pages.Key.init(&try key.digest());
}
pub fn entryKey(content: p.DataLifecycle.Content) !pages.Key {
    try content.validate();
    return pages.Key.init(&content.sha256);
}
pub fn directory(allocator: std.mem.Allocator, index: *c.storage.TreeStore, root: ?pages.Reference, key: c.DirectClientToken.Key) !Directory {
    var tree: pages.Tree(c.storage.TreeStore) = .{ .store = index };
    const value = try tree.get(root, try ownerKey(key)) orelse return .empty;
    const result = try r.fromValue(Directory, allocator, value);
    try result.validate();
    return result;
}
pub fn entry(allocator: std.mem.Allocator, index: *c.storage.TreeStore, owner: Directory, content: p.DataLifecycle.Content) !?Entry {
    var tree: pages.Tree(c.storage.TreeStore) = .{ .store = index };
    const value = try tree.get(owner.entries, try entryKey(content)) orelse return null;
    const result = try r.fromValue(Entry, allocator, value);
    try result.validate();
    if (!std.meta.eql(result.content, content)) return error.DataIdentityConflict;
    return result;
}
pub fn encode(allocator: std.mem.Allocator, key: c.DirectClientToken.Key, inner_format: u32, bytes: []const u8) ![]u8 {
    const payload = try c.DirectTableProtocol.Binary.encode(allocator, bytes);
    defer allocator.free(payload.base64);
    const envelope: Envelope = .{ .definition = p.Growth.current_definition, .transaction = key, .format = inner_format, .payload = payload };
    const encoded = try p.Json.valueAllocBounded(allocator, envelope, R.max_bytes);
    errdefer allocator.free(encoded);
    try envelope.validate(try R.reference(key.scope(), format, encoded));
    return encoded;
}
pub fn stage(client: c.DirectTableClient, transaction: c.DirectClientToken.Key, inner_format: u32, bytes: []const u8) !R.Reference {
    const encoded = try encode(client.allocator, transaction, inner_format, bytes);
    defer client.allocator.free(encoded);
    const expected = try R.reference(transaction.scope(), format, encoded);
    const binary = try c.DirectTableProtocol.Binary.encode(client.allocator, bytes);
    defer client.allocator.free(binary.base64);
    const response = try client.call(.{ .record = .{ .stage_transaction = .{ .transaction = transaction, .format = inner_format, .bytes = binary } } });
    defer response.deinit();
    try expected.requireSame(response.value.result.record.reference);
    return expected;
}

test "transaction record signed request binds owner format payload and mutation admission" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-transaction-record-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    try t.expect(fixture.request.transport().mutation);
    var changed = fixture.request;
    changed.action.record.stage_transaction.transaction.token[0] ^= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.record.stage_transaction.format += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.record.stage_transaction.bytes.base64 = "Y2hhbmdlZA==";
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.record.stage_transaction.format = 1;
    try t.expectError(error.InvalidTransactionRecord, changed.action.record.validate());
}
