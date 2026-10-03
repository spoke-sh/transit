//! Frozen scope and explicit retry decisions. No decision grants dispatch or
//! refunds a root attempt budget; current service grants remain separate.
const std = @import("std");
const rpc = @import("root.zig");
pub const Reason = rpc.exchange.Exchange.FollowupReason;
const Rejection = rpc.Service.Rejection;
const Scalar = rpc.exchange.AdmissionRejection.Scalar;
fn fail(context: ?*?Rejection, check: rpc.exchange.AdmissionRejection.Check, field: []const u8, expected: Scalar, actual: Scalar, cause: anyerror) anyerror {
    if (context) |slot| slot.* = Rejection.detail(.denied, check, field, expected, actual, cause);
    return cause;
}
pub const Reference = struct {
    id: u64,
    revision: u64,
    pub fn validate(self: Reference) !void {
        if (self.id == 0 or self.revision == 0) return error.GrpcFollowupNotGranted;
    }
};
pub const Credential = struct { binding: []const u8, version: u64, metadata: []const u8 };
pub const Retry = struct { id: u64, revision: u64, key_metadata: []const u8 };
pub const Prepared = struct {
    version: u32 = 1,
    endpoint_revision: u64,
    host: []const u8,
    address: []const u8,
    port: u16,
    tls: bool,
    timeout_ms: u32,
    limits: rpc.transport.Limits,
    response_metadata: []const []const u8 = &.{},
    credentials: []const Credential = &.{},
    trust_digest: ?[32]u8,
    method: []const u8,
    shape: rpc.Shape,
    descriptor_digest: [32]u8,
    metadata_digest: [32]u8,
    batch_digest: [32]u8,
    retry_policy: ?Retry = null,
    pub fn validate(self: Prepared) !void {
        if (self.version != 1 or self.endpoint_revision == 0 or self.tls != (self.trust_digest != null) or self.credentials.len > 16 or self.response_metadata.len > 64) return error.InvalidGrpcPolicy;
        try (rpc.transport.Endpoint{ .host = self.host, .address = self.address, .port = self.port, .tls = self.tls, .timeout_ms = self.timeout_ms, .limits = self.limits }).validate();
        try (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest }).validate();
        for (self.credentials, 0..) |credential, index| {
            if (!self.tls) return error.GrpcCredentialRequiresTls;
            try (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest, .metadata = &.{.{ .name = credential.metadata, .value = .{ .secret = .{ .binding = credential.binding, .version = credential.version } } }} }).validate();
            for (self.credentials[0..index]) |previous| if (std.mem.eql(u8, previous.binding, credential.binding)) return error.DuplicateGrpcCredential;
        }
        for (self.response_metadata) |name| {
            if (sensitive(name)) return error.GrpcCredentialCaptureForbidden;
            for (self.credentials) |credential| if (std.mem.eql(u8, name, credential.metadata)) return error.GrpcCredentialCaptureForbidden;
            try (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest, .metadata = &.{.{ .name = name, .value = .{ .literal = "" } }} }).validate();
        }
        if (self.retry_policy) |retry| {
            try (Reference{ .id = retry.id, .revision = retry.revision }).validate();
            if (sensitive(retry.key_metadata) or std.mem.endsWith(u8, retry.key_metadata, "-bin")) return error.InvalidGrpcIdempotencyKey;
            try (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest, .metadata = &.{.{ .name = retry.key_metadata, .value = .{ .literal = "" } }} }).validate();
        }
    }
    pub fn encode(self: Prepared, buffer: []u8) ![]const u8 {
        try self.validate();
        var out: std.Io.Writer = .fixed(buffer[0..@min(buffer.len, 8192)]);
        try std.json.Stringify.value(self, .{}, &out);
        return out.buffered();
    }
    pub fn validateRequest(self: Prepared, request: rpc.Request) !void {
        return self.validateRequestDiagnostic(request, null);
    }
    pub fn validateRequestDiagnostic(self: Prepared, request: rpc.Request, context: ?*?Rejection) !void {
        try self.validate();
        try request.validateDiagnostic(context);
        if (!std.mem.eql(u8, self.method, request.method)) return fail(context, .equal, "request.method", .{ .text = self.method }, .{ .text = request.method }, error.GrpcRequestNotGranted);
        if (self.shape != request.shape) return fail(context, .equal, "request.shape", .{ .text = @tagName(self.shape) }, .{ .text = @tagName(request.shape) }, error.GrpcRequestNotGranted);
        if (!std.mem.eql(u8, &self.descriptor_digest, &request.descriptor_digest)) return fail(context, .equal, "request.descriptor_digest", .{ .digest = self.descriptor_digest }, .{ .digest = request.descriptor_digest }, error.GrpcRequestNotGranted);
        for (request.metadata, 0..) |field, index| {
            var path_bytes: [64]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_bytes, "request.metadata[{d}]", .{index});
            switch (field.value) {
                .secret => |secret| {
                    if (!self.tls) return fail(context, .equal, "policy.tls", .{ .text = "true" }, .{ .text = "false" }, error.GrpcCredentialRequiresTls);
                    const credential = for (self.credentials) |candidate| {
                        if (candidate.version == secret.version and std.mem.eql(u8, candidate.binding, secret.binding)) break candidate;
                    } else return fail(context, .available, path, .redacted, .redacted, error.GrpcCredentialNotGranted);
                    if (!std.mem.eql(u8, credential.metadata, field.name)) return fail(context, .equal, path, .redacted, .redacted, error.GrpcCredentialNotGranted);
                },
                .literal => {
                    if (sensitive(field.name)) return fail(context, .policy, path, .{ .text = "credential reference" }, .redacted, error.GrpcCredentialReferenceRequired);
                    for (self.credentials) |credential| if (std.mem.eql(u8, field.name, credential.metadata)) return fail(context, .policy, path, .{ .text = "credential reference" }, .redacted, error.GrpcCredentialReferenceRequired);
                },
            }
        }
        var bytes: [8192]u8 = undefined;
        const spec = try rpc.exchange.Publication.Digest.of(rpc.protocol_format, try request.provenance(&bytes));
        if (!std.mem.eql(u8, &spec.digest, &self.metadata_digest)) return fail(context, .equal, "request.provenance_digest", .{ .digest = self.metadata_digest }, .{ .digest = spec.digest }, error.GrpcRequestChanged);
    }
};
pub fn sensitive(name: []const u8) bool {
    for ([_][]const u8{ "authorization", "cookie", "set-cookie", "x-api-key", "proxy-authorization" }) |key| if (std.ascii.eqlIgnoreCase(name, key)) return true;
    return false;
}
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    policy: Prepared,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
    }
};
pub fn parse(gpa: std.mem.Allocator, bytes: []const u8) !Owned {
    if (bytes.len == 0 or bytes.len > 8192) return error.InvalidGrpcPolicy;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    errdefer arena.deinit();
    const policy = try std.json.parseFromSliceLeaky(Prepared, arena.allocator(), bytes, .{ .allocate = .alloc_always });
    var canonical: [8192]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try policy.encode(&canonical))) return error.NonCanonicalGrpcPolicy;
    return .{ .arena = arena, .policy = policy };
}
pub fn followup(reason: rpc.exchange.Exchange.FollowupReason, parent: Prepared, next: Prepared, request: rpc.Request) !Reference {
    return followupDiagnostic(reason, parent, next, request, null);
}
pub fn followupDiagnostic(reason: rpc.exchange.Exchange.FollowupReason, parent: Prepared, next: Prepared, request: rpc.Request, context: ?*?Rejection) !Reference {
    if (reason != .retry) return fail(context, .equal, "followup.reason", .{ .text = "retry" }, .{ .text = @tagName(reason) }, error.GrpcFollowupNotGranted);
    try parent.validateRequestDiagnostic(request, context);
    try next.validateRequestDiagnostic(request, context);
    const retry = parent.retry_policy orelse return fail(context, .available, "policy.retry", .{ .text = "declared retry policy" }, .inapplicable, error.GrpcFollowupNotGranted);
    var count: usize = 0;
    for (request.metadata) |field| if (std.mem.eql(u8, field.name, retry.key_metadata)) {
        if (field.value != .literal) return fail(context, .equal, "retry.key.kind", .{ .text = "literal" }, .{ .text = @tagName(field.value) }, error.InvalidGrpcIdempotencyKey);
        if (field.value.literal.len == 0) return fail(context, .different, "retry.key.bytes", .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.InvalidGrpcIdempotencyKey);
        if (field.value.literal.len > 128) return fail(context, .maximum, "retry.key.bytes", .{ .unsigned = 128 }, .{ .unsigned = field.value.literal.len }, error.InvalidGrpcIdempotencyKey);
        count += 1;
    };
    if (count != 1) return fail(context, .equal, "retry.key.count", .{ .unsigned = 1 }, .{ .unsigned = count }, error.InvalidGrpcIdempotencyKey);
    var before: [8192]u8 = undefined;
    var after: [8192]u8 = undefined;
    if (!std.mem.eql(u8, try parent.encode(&before), try next.encode(&after))) {
        if (context) |slot| slot.* = rpc.exchange.PolicyDifference.first(Rejection, parent, next, error.GrpcFollowupChanged) orelse Rejection.detail(.denied, .equal, "policy", .redacted, .redacted, error.GrpcFollowupChanged);
        return error.GrpcFollowupChanged;
    }
    return .{ .id = retry.id, .revision = retry.revision };
}
