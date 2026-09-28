//! Versioned reactive identities and bounded records. No sockets or clocks.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const m = root.Model;
const c = root.Codec;
pub const version: u8 = 1;
pub const max_sessions = 4;
pub const max_caller_sessions = 2;
pub const max_lease_ms = 30000;
pub const max_message_bytes = 8192;
pub const max_fragments = 32;
pub const subprotocol = "transit.reactive.v1";

pub const Source = struct {
    revision: u64,
    target: u64,
    resource: u64,
    table: u32,
    progress_key: p.Value,
    schema: [32]u8,
    published: bool = true,
    pub fn validate(self: Source) !void {
        inline for (.{ "revision", "target", "resource", "table" }) |name| try m.identity(@field(self, name));
        try self.progress_key.validate();
        if (self.progress_key.len == 0 or self.progress_key.len > 32 or std.mem.allEqual(u8, &self.schema, 0)) return error.InvalidReactiveSource;
    }
};
pub const SessionIdentity = struct { session: u64, generation: u64 };
pub const Open = struct { session: u64, source_revision: u64, lease_before_ms: u64 };
pub const Attach = struct { identity: SessionIdentity, expected: u64, nonce: [16]u8 };
pub const Subscribe = struct { identity: SessionIdentity, expected: u64, subscription: u64, operation: u64 = 0 };
pub const Command = union(enum(u8)) {
    publish: struct { expected: u64, source: Source } = 0,
    observe_clock: u64 = 1,
    open: Open = 2,
    attach: Attach = 3,
    subscribe: Subscribe = 4,
    renew: struct { identity: SessionIdentity, expected: u64, lease_before_ms: u64 } = 5,
    unsubscribe: struct { identity: SessionIdentity, subscription: u64, generation: u64 } = 6,
    close: SessionIdentity = 7,
    expire: struct { principal: u64, identity: SessionIdentity, observed_ms: u64 } = 8,
};
pub const Phase = enum(u8) { open = 1, closed = 2, expired = 3 };
pub const Session = struct {
    principal: u64,
    session: u64,
    generation: u64,
    source_revision: u64,
    open_digest: [32]u8,
    lease_before_ms: u64,
    phase: Phase = .open,
    attachment: u64 = 0,
    nonce: [16]u8 = @splat(0),
    subscription: u64 = 0,
    subscription_generation: u64 = 0,
    operation: u64 = 0,
};
pub const Slot = struct { principal: u64 = 0, session: u64 = 0 };
pub const Active = struct { slots: [max_sessions]Slot = @splat(.{}) };
pub const Scope = struct {
    realm: u64,
    principal: u64,
    service: u64,
    ingress: u64,
    session: u64,
    generation: u64,
    subscription: u64 = 0,
    subscription_generation: u64 = 0,
    pub fn validate(self: Scope) !void {
        inline for (.{ "realm", "principal", "service", "ingress", "session", "generation" }) |name| try m.identity(@field(self, name));
        if (self.subscription > p.max_counter or self.subscription_generation > p.max_counter or
            (self.subscription == 0) != (self.subscription_generation == 0)) return error.InvalidReactiveScope;
    }
};
pub const Position = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = version } };
    version: u8 = version,
    scope: Scope,
    watch_revision: u64,
    resource: u64,
    schema: [32]u8,
    data_revision: u64,
    outcome_position: u64 = 0,
    pub fn validate(self: Position) !void {
        try self.scope.validate();
        if (self.version != version or self.scope.subscription == 0 or self.data_revision > p.max_counter or
            self.outcome_position > p.max_counter or std.mem.allEqual(u8, &self.schema, 0)) return error.InvalidReactiveCursor;
        try m.identity(self.watch_revision);
        try m.identity(self.resource);
    }
    pub fn digest(self: Position) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.reactive.cursor.v1\x00");
        hash.update((try c.encode('E', self)).slice());
        return hash.finalResult();
    }
};
pub const Cursor = struct {
    position: Position,
    signature: [64]u8,
    pub fn sign(position: Position, pair: p.Ed25519.KeyPair) !Cursor {
        return .{ .position = position, .signature = (try pair.sign(&try position.digest(), null)).toBytes() };
    }
    pub fn verify(self: Cursor, public_key: [32]u8) !void {
        try p.Ed25519.Signature.fromBytes(self.signature).verify(&try self.position.digest(), try p.Ed25519.PublicKey.fromBytes(public_key));
    }
    pub fn encode(self: Cursor) !p.Value {
        try self.position.validate();
        return c.encode('K', self);
    }
    pub fn decode(value: p.Value) !Cursor {
        const result = try c.decode(Cursor, 'K', value);
        try result.position.validate();
        return result;
    }
};
pub const Read = struct {
    scope: Scope,
    kind: enum(u8) { session = 1, snapshot = 2, events = 3 },
    attachment: u64 = 0,
    nonce: [16]u8 = @splat(0),
    cursor: ?Cursor = null,
    pub fn digest(self: Read) ![32]u8 {
        try self.scope.validate();
        if (self.attachment > p.max_counter) return error.InvalidReactiveScope;
        if (self.kind != .session and (self.attachment == 0 or self.scope.subscription == 0 or std.mem.allEqual(u8, &self.nonce, 0))) return error.InvalidReactiveScope;
        if (self.cursor) |cursor| {
            if (self.kind != .events or !std.meta.eql(cursor.position.scope, self.scope)) return error.InvalidReactiveCursor;
            try cursor.position.validate();
        }
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.reactive.read.v1\x00");
        hash.update((try c.encode('U', self.scope)).slice());
        hash.update(&.{@backingInt(self.kind)});
        var attachment: [8]u8 = undefined;
        std.mem.writeInt(u64, &attachment, self.attachment, .little);
        hash.update(&attachment);
        hash.update(&self.nonce);
        hash.update(&.{@intFromBool(self.cursor != null)});
        if (self.cursor) |cursor| hash.update((try cursor.encode()).slice());
        return hash.finalResult();
    }
};
pub const SignedRead = struct {
    read: Read,
    signature: [64]u8,
    identity: m.Identity,
    pub fn sign(read: Read, pair: p.Ed25519.KeyPair) !SignedRead {
        return .{ .read = read, .signature = (try pair.sign(&try read.digest(), null)).toBytes(), .identity = try m.Identity.sign(read.scope.realm, read.scope.principal, pair) };
    }
    pub fn verify(self: SignedRead, public_key: [32]u8) !void {
        if (self.identity.query.realm != self.read.scope.realm or self.identity.query.principal != self.read.scope.principal or self.identity.query.kind != .identity) return error.InvalidReactiveScope;
        const pk = try p.Ed25519.PublicKey.fromBytes(public_key);
        try p.Ed25519.Signature.fromBytes(self.signature).verify(&try self.read.digest(), pk);
        try p.Ed25519.Signature.fromBytes(self.identity.signature).verify(&try p.Growth.queryDigest(self.identity.native().query), pk);
    }
};

// This narrower public envelope describes the only native operation a serving
// gateway forwards. Schema generation must not advertise arbitrary kernel calls.
pub const SignedSend = struct {
    request: struct {
        pub const json_schema_fields = .{ .version = .{ .@"const" = p.Growth.version } };
        version: u32 = p.Growth.version,
        realm: u64,
        principal: u64,
        sequence: u64,
        command: struct { send: @FieldType(p.Growth.Command, "send") },
    },
    signature: [64]u8,
    pub fn native(self: SignedSend) p.Growth.SignedRequest {
        return .{ .request = .{ .version = self.request.version, .realm = self.request.realm, .principal = self.request.principal, .sequence = self.request.sequence, .command = .{ .send = self.request.command.send } }, .signature = self.signature };
    }
};

test "reactive records fit one bounded value and signatures bind scope and progress" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(17));
    const scope: Scope = .{ .realm = 49, .principal = p.max_counter, .service = 1, .ingress = 9, .session = 7, .generation = 10, .subscription = 3, .subscription_generation = 12 };
    const cursor = try Cursor.sign(.{ .scope = scope, .watch_revision = 2, .resource = 11, .schema = @splat(3), .data_revision = p.max_counter }, key);
    try cursor.verify(key.public_key.toBytes());
    try t.expect(std.meta.eql(cursor, try Cursor.decode(try cursor.encode())));
    var forged = cursor;
    forged.position.data_revision -= 1;
    try t.expectError(error.SignatureVerificationFailed, forged.verify(key.public_key.toBytes()));
    const request = try SignedRead.sign(.{ .scope = scope, .kind = .events, .attachment = 3, .nonce = @splat(8), .cursor = cursor }, key);
    try request.verify(key.public_key.toBytes());
    var changed = request;
    changed.read.attachment += 1;
    try t.expectError(error.SignatureVerificationFailed, changed.verify(key.public_key.toBytes()));
    var trailing = try cursor.encode();
    trailing.data[trailing.len] = 0;
    trailing.len += 1;
    try t.expectError(error.InvalidServingRecord, Cursor.decode(trailing));
    const record: Session = .{ .principal = scope.principal, .session = scope.session, .generation = scope.generation, .source_revision = 2, .open_digest = @splat(4), .lease_before_ms = 10000 };
    try t.expect(std.meta.eql(record, try c.decode(Session, 'S', try c.encode('S', record))));
    _ = try c.encode('L', Active{});
}

/// Lossless JSON integer for the selected int64 Table watch profile. Protocol
/// identities stay safe JSON counters; application integers do not.
pub const Integer = struct {
    value: i64,
    pub fn jsonStringify(self: Integer, out: *std.json.Stringify) !void {
        var bytes: [20]u8 = undefined;
        try out.write(std.fmt.bufPrint(&bytes, "{d}", .{self.value}) catch unreachable);
    }
    pub fn jsonSchema(out: *std.json.Stringify) std.Io.Writer.Error!void {
        try out.write(.{ .type = "string", .pattern = "^(0|-[1-9][0-9]*|[1-9][0-9]*)$", .maxLength = 20, .@"x-transit-encoding" = "signed-decimal-i64" });
    }
};
