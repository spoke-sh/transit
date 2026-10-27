//! Standalone native payload I/O. Native commands retain declaration, readiness
//! and retirement authority; these requests only publish, verify or read bytes.
const std = @import("std");
const p = @import("root.zig");

pub const Content = struct { bytes: u32, sha256: [32]u8 };
pub const Operation = struct {
    kind: enum { create, verify, read },
    payload: p.PayloadRef,
    content: ?Content,

    pub fn validate(self: Operation) !void {
        if (self.payload.pid == 0 or self.payload.pid > p.max_counter or
            self.payload.payload == 0 or self.payload.payload > p.max_counter) return error.InvalidPayload;
        if ((self.kind == .create) != (self.content != null)) return error.InvalidPayload;
        if (self.content) |content| if (content.bytes == 0 or content.bytes > p.max_payload_bytes) return error.InvalidPayload;
    }

    pub fn context(self: Operation) ![32]u8 {
        try self.validate();
        var buffer: [1024]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.native.payload.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(writer.buffered());
        return hash.finalResult();
    }

    pub fn subject(self: Operation, proof: p.Authorization.Proof) !void {
        try proof.claim.validate();
        if (proof.claim.audience != self.payload.pid or
            !std.mem.eql(u8, &proof.claim.context, &try self.context())) return error.InvalidAuthorizationCredential;
    }
};

pub const Request = struct {
    operation: Operation,
    proof: p.Authorization.Proof,
    body: p.Blocks.Body,

    pub fn validate(self: *const Request) !void {
        try self.operation.subject(self.proof);
        try self.body.validate();
        if (self.operation.content) |content| {
            if (self.body.len != content.bytes) return error.InvalidPayload;
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(self.body.slice(), &digest, .{});
            if (!std.mem.eql(u8, &digest, &content.sha256)) return error.PayloadIntegrity;
        } else if (self.body.len != 0) return error.InvalidPayload;
    }
};

pub const Response = struct {
    definition: p.Growth.Definition,
    realm: u64,
    payload: p.Growth.Payload,
    outcome: enum { created, verify_required, verified, read },
    body: p.Blocks.Body,

    pub fn validate(self: *const Response, request: *const Request) !void {
        try request.validate();
        if (self.definition != p.Growth.current_definition or self.realm != request.proof.claim.realm or
            self.payload.id != request.operation.payload.payload or self.payload.pid != request.operation.payload.pid or
            self.payload.bytes == 0 or self.payload.bytes > p.max_payload_bytes) return error.InvalidPayloadResponse;
        try self.body.validate();
        switch (request.operation.kind) {
            .create => {
                if ((self.outcome != .created and self.outcome != .verify_required) or self.payload.phase != .creating or
                    self.payload.publisher != request.proof.claim.principal or
                    !std.meta.eql(request.operation.content.?, Content{ .bytes = self.payload.bytes, .sha256 = self.payload.sha256 })) return error.InvalidPayloadResponse;
            },
            .verify => if (self.outcome != .verified or (self.payload.phase != .creating and self.payload.phase != .ready) or
                self.payload.publisher != request.proof.claim.principal) return error.InvalidPayloadResponse,
            .read => {
                if (self.outcome != .read or self.payload.phase != .ready or self.body.len != self.payload.bytes) return error.InvalidPayloadResponse;
                var digest: [32]u8 = undefined;
                std.crypto.hash.sha2.Sha256.hash(self.body.slice(), &digest, .{});
                if (!std.mem.eql(u8, &digest, &self.payload.sha256)) return error.InvalidPayloadResponse;
            },
        }
        if (request.operation.kind != .read and self.body.len != 0) return error.InvalidPayloadResponse;
    }
};

test "native payload callers reject substituted identities, bytes and signed operations" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("abc", &digest, .{});
    const operation: Operation = .{ .kind = .read, .payload = .{ .pid = 3, .payload = 17 }, .content = null };
    const claim: p.Authorization.Claim = .{ .definition = p.Growth.current_definition, .realm = 42, .principal = 65536, .credential_epoch = 1, .role = null, .audience = 3, .context = try operation.context() };
    var request: Request = .{ .operation = operation, .proof = try p.Authorization.Proof.sign(claim, key), .body = .{} };
    try request.validate();
    var response: Response = .{ .definition = p.Growth.current_definition, .realm = 42, .payload = .{ .id = 17, .pid = 3, .publisher = 0, .sha256 = digest, .bytes = 3, .phase = .ready }, .outcome = .read, .body = .{ .len = 3 } };
    @memcpy(response.body.data[0..3], "abc");
    try response.validate(&request);
    response.payload.id += 1;
    try t.expectError(error.InvalidPayloadResponse, response.validate(&request));
    response.payload.id -= 1;
    response.body.data[0] ^= 1;
    try t.expectError(error.InvalidPayloadResponse, response.validate(&request));
    response.body.data[0] ^= 1;
    response.payload.phase = .retiring;
    try t.expectError(error.InvalidPayloadResponse, response.validate(&request));
    request.operation.kind = .verify;
    try t.expectError(error.InvalidAuthorizationCredential, request.validate());
    request.operation = operation;
    request.body.len = 1;
    try t.expectError(error.InvalidPayload, request.validate());
}
