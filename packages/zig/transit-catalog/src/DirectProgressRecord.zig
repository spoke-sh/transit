//! Replaceable external-owner progress. The catalog reserves one candidate
//! before creating bytes, then atomically replaces the current recovery record.
//! Original admission records have a separate, permanent retry lifetime.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const R = c.DirectRecord;

pub const format: u32 = 0x43505231; // CPR1
pub const Advance = struct {
    key: c.DirectClientToken.Key,
    expected: p.DataLifecycle.Position,
    pending: bool,
    cancel: bool,
    format: u32,
    bytes: c.DirectTableProtocol.Binary,

    pub fn validate(self: Advance) !void {
        try self.key.validate();
        try self.expected.validate();
        if (self.expected.next_lsn < 2 or self.format == 0 or self.format & R.guarded_bit != 0) return error.InvalidDirectRecord;
    }
};
pub const Envelope = struct {
    definition: p.Growth.Definition,
    advance: Advance,

    pub fn validate(self: Envelope, reference: R.Reference) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.advance.validate();
        try reference.validate();
        if (reference.format != format or !std.meta.eql(reference.scope, self.advance.key.scope())) return error.InvalidDirectRecord;
    }
};
pub const Pending = struct {
    reference: R.Reference,
    expected: p.DataLifecycle.Position,
    pending: bool,
    cancel: bool,

    pub fn init(request: Advance, reference: R.Reference) Pending {
        return .{ .reference = reference, .expected = request.expected, .pending = request.pending, .cancel = request.cancel };
    }
};

pub fn encode(allocator: std.mem.Allocator, request: Advance) ![]u8 {
    try request.validate();
    // Validate the encoded input as well as the bounded envelope.
    const payload = try request.bytes.decode(allocator, R.max_bytes);
    defer allocator.free(payload);
    return p.Json.valueAllocBounded(allocator, Envelope{ .definition = p.Growth.current_definition, .advance = request }, R.max_bytes);
}

pub fn advance(client: c.DirectTableClient, request: Advance) !c.DirectClientToken.Progress {
    const response = try client.call(.{ .client_progress = .{ .advance = request } });
    defer response.deinit();
    return response.value.result.client_progress.state orelse error.InvalidTableResponse;
}

test "owned progress signed request binds revision payload and mutation admission" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-progress-record-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    try t.expect(fixture.request.transport().mutation);
    var changed = fixture.request;
    changed.action.client_progress.advance.key.token[0] ^= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.client_progress.advance.expected.next_lsn += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.client_progress.advance.bytes.base64 = "Y2hhbmdlZA==";
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.client_progress.advance.pending = false;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
}
