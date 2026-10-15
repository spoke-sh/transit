const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const codec = root.Codec;
pub const max_active = 8;
pub const inline_bytes = 64;
pub fn identity(id: u64) !void {
    if (id == 0 or id > p.max_counter) return error.InvalidServingIdentity;
}
pub fn key(tag: u8, first: u64, second: u64) p.Value {
    var bytes: [21]u8 = undefined;
    bytes[0..4].* = "\x00sv1".*;
    bytes[4] = tag;
    std.mem.writeInt(u64, bytes[5..13], first, .big);
    std.mem.writeInt(u64, bytes[13..21], second, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub const Configuration = struct { service: u64, administrator: u64, observer: u64 };
pub const Binding = struct {
    revision: u64,
    target: u64,
    codec: u16,
    active_limit: u8,
    wait_before_ms: u64,
    published: bool = true,
    pub fn validate(self: Binding) !void {
        try identity(self.revision);
        try identity(self.target);
        try identity(self.wait_before_ms);
        if (self.codec == 0 or self.active_limit == 0 or self.active_limit > max_active) return error.InvalidServiceBinding;
    }
};
pub const Policy = struct {
    revision: u64,
    commands: bool,
    reads: bool,
    active_limit: u8,
    pub fn validate(self: Policy) !void {
        try identity(self.revision);
        if (self.active_limit == 0 or self.active_limit > max_active) return error.InvalidServicePolicy;
    }
};
pub const Submit = struct {
    operation: u64,
    binding: u64,
    codec: u16,
    deadline_ms: u64,
    payload: p.Value,
    pub fn validate(self: Submit) !void {
        try identity(self.operation);
        try identity(self.binding);
        try identity(self.deadline_ms);
        try self.payload.validate();
        if (self.codec == 0 or self.payload.len > inline_bytes) return error.InvalidServingCommand;
    }
    pub fn digest(self: Submit) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.serving.command.v1\x00");
        hash.update((try codec.encode('s', self)).slice());
        return hash.finalResult();
    }
};
pub const Command = union(enum(u8)) {
    initialize = 0,
    publish: struct { expected: u64, binding: Binding } = 1,
    policy: struct { principal: u64, expected: u64, policy: Policy } = 2,
    submit: Submit = 3,
    cancel: u64 = 4,
    reactive: root.ReactiveModel.Command = 5,
    refresh: root.RefreshModel.Command = 6,
    pub fn encode(self: Command) !p.Value {
        return codec.encode('c', self);
    }
    pub fn decode(value: p.Value) !Command {
        return codec.decode(Command, 'c', value);
    }
};
pub const Invocation = struct { service: u64, principal: u64, operation: u64, binding: u64, codec: u16, payload: p.Value };
pub const Phase = enum(u8) { admitted = 1, completed = 2, cancelled = 3, timed_out = 4, failed = 5 };
pub const Operation = struct {
    principal: u64,
    operation: u64,
    binding: u64,
    codec: u16,
    deadline_ms: u64,
    digest: [32]u8,
    target: u64,
    correlation: u64,
    policy_revision: u64,
    phase: Phase = .admitted,
    resolution_input: u64 = 0,
    result: p.Value = .{},
    reply_bytes: u16 = 0,
    pub fn validate(self: Operation) !void {
        inline for (.{ "principal", "operation", "binding", "deadline_ms", "target", "correlation", "policy_revision" }) |field| {
            identity(@field(self, field)) catch return error.InvalidServingRecord;
        }
        try self.result.validate();
        if (self.codec == 0 or self.reply_bytes > root.station.Frame.max_payload) return error.InvalidServingRecord;
        if (self.phase == .admitted) {
            if (self.resolution_input != 0) return error.InvalidServingRecord;
        } else identity(self.resolution_input) catch return error.InvalidServingRecord;
        switch (self.phase) {
            .admitted, .cancelled, .timed_out => if (self.result.len != 0 or self.reply_bytes != 0) return error.InvalidServingRecord,
            .completed => if (self.result.len > inline_bytes or self.reply_bytes != self.result.len) return error.InvalidServingRecord,
            .failed => if (self.reply_bytes <= inline_bytes or self.result.len != 0) return error.InvalidServingRecord,
        }
    }
};
pub const Slot = struct { correlation: u64 = 0, principal: u64 = 0, operation: u64 = 0 };
pub const Active = struct { slots: [max_active]Slot = @splat(.{}) };
pub const Read = struct {
    realm: u64,
    principal: u64,
    service: u64,
    ingress: u64,
    kind: enum(u8) { discovery = 1, status = 2, result = 3, disposition = 4 },
    operation: u64 = 0,
    pub fn digest(self: Read) ![32]u8 {
        inline for (.{ "realm", "principal", "service", "ingress" }) |field| try identity(@field(self, field));
        if (self.kind == .discovery) {
            if (self.operation != 0) return error.InvalidServingRead;
        } else try identity(self.operation);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.serving.read.v1\x00");
        hash.update((try codec.encode('r', self)).slice());
        return hash.finalResult();
    }
};
/// The complete read is bound to a current original-caller credential and role.
/// Native authority independently checks the proof at every disclosure boundary.
pub const SignedRead = struct {
    read: Read,
    proof: p.Authorization.Proof,
    pub fn sign(read: Read, pair: p.Ed25519.KeyPair, credential_epoch: u64, role: ?u64) !SignedRead {
        return fromProof(read, try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = read.realm, .principal = read.principal, .credential_epoch = credential_epoch, .role = role, .audience = read.ingress, .context = try read.digest() }, pair));
    }
    pub fn prepare(read: Read, caller: @import("root.zig").station.client.AuthorizationClient) !SignedRead {
        if (caller.realm != read.realm or caller.principal != read.principal) return error.ServingDenied;
        return fromProof(read, (try caller.proof(read.ingress, try read.digest())).signed);
    }
    pub fn fromProof(read: Read, proof: p.Authorization.Proof) !SignedRead {
        try proof.claim.validate();
        if (proof.claim.realm != read.realm or proof.claim.principal != read.principal or proof.claim.audience != read.ingress or !std.mem.eql(u8, &proof.claim.context, &try read.digest())) return error.ServingDenied;
        return .{ .read = read, .proof = proof };
    }
    pub fn verify(self: SignedRead, public_key: [32]u8) !void {
        _ = try fromProof(self.read, self.proof);
        try self.proof.verify(public_key);
    }
};
