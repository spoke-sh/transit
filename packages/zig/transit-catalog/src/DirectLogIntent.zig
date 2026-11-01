//! Frozen declaration work for database-owned caller tokens. Staging preserves
//! complete bytes; only the existing log declaration owner admits or executes it.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();
pub const format = 0x4c444c31;
pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    work: c.DirectLogProtocol.Ddl,
    pub fn validate(self: Saved, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        var scratch = std.heap.ArenaAllocator.init(allocator);
        defer scratch.deinit();
        try self.work.validate(scratch.allocator(), self.connection);
    }
};
pub const Reference = struct {
    connection: w.Connection,
    namespace: u64,
    kind: c.DirectLog.Kind,
    binding: p.DataLifecycle.Binding,
    record: c.DirectRecord.Reference,
    pub fn validate(self: Reference) !void {
        try self.connection.validate();
        try self.connection.binding(self.binding);
        try c.Model.nativeId(self.namespace);
        try self.record.validate();
        if (self.record.format != format or !std.meta.eql(self.connection, self.record.scope.connection)) return error.InvalidLogIntent;
        switch (self.binding.action) {
            .create, .alter, .rename, .drop => {},
            else => return error.InvalidLogIntent,
        }
    }
    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
    pub fn admit(self: Reference, client: c.DirectTableClient) !std.json.Parsed(w.Response) {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        const bytes = try c.DirectRecord.read(client.allocator, client, self.record);
        defer client.allocator.free(bytes);
        var intent = try restore(client.allocator, bytes);
        defer intent.deinit();
        try self.requireSame(try intent.reference(self.record.scope.account));
        return client.call(.{ .log_admit = intent.parsed.value.work });
    }
    pub fn operation(self: Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !std.json.Parsed(w.Response) {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        return client.call(.{ .log_operation = .{ .binding = self.binding, .command = switch (command) {
            .inspect => .inspect,
            .execute => .execute,
            .cancel => .cancel,
        }, .steps = steps } });
    }
};
allocator: std.mem.Allocator,
bytes: []u8,
parsed: std.json.Parsed(Saved),

pub fn create(allocator: std.mem.Allocator, connection: w.Connection, work: c.DirectLogProtocol.Ddl) !Self {
    const value: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .work = work };
    try value.validate(allocator);
    const bytes = try p.Json.valueAlloc(allocator, value);
    errdefer allocator.free(bytes);
    if (bytes.len > c.DirectRecord.max_bytes) return error.CatalogRecordTooLarge;
    return .{ .allocator = allocator, .bytes = bytes, .parsed = try p.Json.parseFromSlice(Saved, allocator, bytes) };
}
pub fn deinit(self: *Self) void {
    self.parsed.deinit();
    self.allocator.free(self.bytes);
    self.* = undefined;
}
pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len == 0 or bytes.len > c.DirectRecord.max_bytes) return error.InvalidLogIntent;
    const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes);
    defer parsed.deinit();
    try parsed.value.validate(allocator);
    var result = try create(allocator, parsed.value.connection, parsed.value.work);
    errdefer result.deinit();
    if (!std.mem.eql(u8, bytes, result.bytes)) return error.InvalidLogIntent;
    return result;
}
pub fn reference(self: *const Self, account: [32]u8) !Reference {
    const value = self.parsed.value;
    const result: Reference = .{ .connection = value.connection, .namespace = value.work.namespace, .kind = value.work.kind, .binding = value.work.binding, .record = try c.DirectRecord.reference(.{ .definition = value.definition, .connection = value.connection, .account = account }, format, self.bytes) };
    try result.validate();
    return result;
}
pub fn stage(self: *const Self, client: c.DirectTableClient, account: [32]u8) !Reference {
    const expected = try self.reference(account);
    if (!std.meta.eql(expected.connection, client.connection)) return error.CatalogIdentityConflict;
    try expected.record.requireSame(try c.DirectRecord.stage(client, account, format, self.bytes));
    return expected;
}
pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, expected: Reference) !Self {
    try expected.validate();
    const bytes = try c.DirectRecord.load(allocator, objects, expected.record);
    defer allocator.free(bytes);
    var intent = try restore(allocator, bytes);
    errdefer intent.deinit();
    try expected.requireSame(try intent.reference(expected.record.scope.account));
    return intent;
}

test "log intent token verifies independent saved bytes and original signed binding" {
    const t = std.testing;
    const Fixture = struct { request: w.Request, public_key: [32]u8, bytes: w.Binary, digest: [32]u8 };
    const fixture = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-log-token-v1.json"));
    defer fixture.deinit();
    const original = fixture.value.request;
    try original.validate(t.allocator);
    try original.proof.verify(fixture.value.public_key);
    const reference_value = original.action.client_token.bind.intent;
    try t.expectEqualSlices(u8, &fixture.value.digest, &try reference_value.digest());
    const bytes = try fixture.value.bytes.decode(t.allocator, c.DirectRecord.max_bytes);
    defer t.allocator.free(bytes);
    var saved = try restore(t.allocator, bytes);
    defer saved.deinit();
    try reference_value.log.requireSame(try saved.reference(original.action.client_token.bind.key.account));
    var transport = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    var caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = original.connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1)) };
    caller.connection.branch += 1;
    try t.expectError(error.CatalogIdentityConflict, saved.stage(caller, original.action.client_token.bind.key.account));
    try t.expectError(error.CatalogIdentityConflict, reference_value.admit(caller));
    try t.expectError(error.CatalogIdentityConflict, reference_value.operation(caller, .inspect, 1));
    var changed = original;
    changed.action.client_token.bind.intent.log.kind = .stream;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = original;
    changed.action.client_token.bind.key.account[0] ^= 1;
    try t.expectError(error.InvalidClientToken, changed.action.client_token.bind.validate());
    const noncanonical = try std.fmt.allocPrint(t.allocator, " {s}", .{bytes});
    defer t.allocator.free(noncanonical);
    try t.expectError(error.InvalidLogIntent, restore(t.allocator, noncanonical));
}
