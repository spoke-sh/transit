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
    view: struct { id: u64 = 0, resource: u64, revision: u64, position: u64 },
    pub fn read(self: *Reader, key: p.Value) !?p.Value {
        return if (try self.entry(key)) |value| value.value else null;
    }
    pub fn entry(self: *Reader, key: p.Value) !?g.Entry {
        const response = try self.client.query(.{ .entries = .{ .resource = self.view.resource, .revision = self.view.revision, .key = key } });
        self.view.position = response.position;
        return response.body.entries.page.entries[0];
    }
};
pub fn readConflict(self: *const Self, err: anyerror) bool {
    return (err == error.Conflict or err == error.Rejected) and (self.wire.last_rejection == .QueryExpired or self.wire.last_rejection == .StaleStateResource);
}
pub fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    return self.wire.query(.{ .realm = self.realm, .principal = self.principal, .kind = kind }, self.key);
}
pub fn reader(self: *Self, resource: u64) !Reader {
    const response = try self.query(.{ .resource = resource });
    const meta = response.body.resource;
    if (meta.phase != .active) return error.ExchangeUnavailable;
    return .{ .client = self, .view = .{ .resource = resource, .revision = meta.revision, .position = response.position } };
}
pub fn inspect(self: *Self, resource: u64, id: u64) !x.Descriptor {
    for (0..32) |_| {
        var source = try self.reader(resource);
        return (x.Exchange{ .resource = resource, .id = id }).inspect(&source) catch |err| {
            if (self.readConflict(err)) continue;
            return err;
        };
    }
    return error.Conflict;
}
pub fn failure(self: *Self, resource: u64, id: u64) !?x.Failure {
    for (0..32) |_| {
        var source = try self.reader(resource);
        return (x.Exchange{ .resource = resource, .id = id }).failure(&source) catch |err| {
            if (self.readConflict(err)) continue;
            return err;
        };
    }
    return error.Conflict;
}
pub const DiagnosticKind = enum { capture_failure, native_effect };
/// Separate current-authorized reads: capture closure is not a native outcome.
/// Retired exchanges retain their control/failure evidence. No transcript/body
/// read, cursor, dispatch or fresh retry is created by inspection.
pub fn diagnostic(self: *Self, resource: u64, id: u64, protocol: u32, kind: DiagnosticKind) !?p.Diagnostic {
    for (0..32) |_| return self.diagnosticOnce(resource, id, protocol, kind) catch |err| {
        if (self.readConflict(err)) continue;
        return err;
    };
    return error.Conflict;
}
fn diagnosticOnce(self: *Self, resource: u64, id: u64, protocol: u32, kind: DiagnosticKind) !?p.Diagnostic {
    var source = try self.reader(resource);
    const ex: x.Exchange = .{ .resource = resource, .id = id };
    const descriptor = try ex.inspect(&source);
    if (descriptor.protocol != protocol) return error.WrongExchangeProtocol;
    const result: ?p.Diagnostic = switch (kind) {
        .capture_failure => try ex.captureDiagnostic(&source, self.realm),
        .native_effect => blk: {
            const intent = (try source.entry(x.Exchange.key(id, 'i', 0))) orelse {
                // An absent intent is not an absent effect after admission.
                if (descriptor.effect != 0 or descriptor.attempt != 0 or (try ex.control(&source)).disposition != .no_intent) return error.InvalidExchangeAttempt;
                break :blk null;
            };
            if (intent.revision == 0) return error.InvalidExchangeAttempt;
            const control = try ex.control(&source);
            if ((control.effect != 0 and control.effect != intent.revision) or (descriptor.effect != 0 and descriptor.effect != intent.revision)) return error.InvalidExchangeAttempt;
            const original = try x.Intent.decode(intent.value);
            if (original.resource != resource or original.exchange != id) return error.InvalidExchangeAttempt;
            const observed = try self.query(.{ .effects = .{ .pid = descriptor.owner, .after = intent.revision - 1, .position = source.view.position } });
            const effect = observed.body.effects.entries[0] orelse return error.UnknownEffect;
            if (effect.id != intent.revision or effect.pid != descriptor.owner or !effect.payload.eql(intent.value)) return error.InvalidExchangeAttempt;
            break :blk try p.EffectDiagnostic.from(self.realm, observed.position, effect);
        },
    };
    // Check resource permission and the same cut again after the independent
    // native read. A concurrent change or revocation cannot release stale data.
    _ = try ex.inspect(&source);
    return result;
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
test "readConflict classifies only moving cut and resource revision rejections" {
    const t = std.testing;
    var wire = x.station.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    const client: Self = .{ .wire = &wire, .realm = 1, .principal = 2, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7)) };
    wire.last_rejection = .QueryExpired;
    try t.expect(client.readConflict(error.Conflict));
    try t.expect(!client.readConflict(error.AuthorityTimeout));
    wire.last_rejection = .StaleStateResource;
    try t.expect(client.readConflict(error.Rejected));
    wire.last_rejection = .StateResourceExpired;
    try t.expect(!client.readConflict(error.Rejected));
    wire.last_rejection = .Forbidden;
    try t.expect(!client.readConflict(error.AccessDenied));
}
