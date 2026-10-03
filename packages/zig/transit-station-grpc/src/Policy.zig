//! Frozen scope and explicit retry decisions. No decision grants dispatch or
//! refunds a root attempt budget; current service grants remain separate.
const std = @import("std");
const rpc = @import("root.zig");
pub const Reason = rpc.exchange.Exchange.FollowupReason;
const Rejection = rpc.Service.Rejection;
const Scalar = rpc.exchange.AdmissionRejection.Scalar;
fn fail(context: ?*?Rejection, check: rpc.exchange.AdmissionRejection.Check, field: []const u8, expected: Scalar, actual: Scalar, cause: anyerror) anyerror {
    if (context) |slot| if (slot.* == null) {
        slot.* = Rejection.detail(.denied, check, field, expected, actual, cause);
    };
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
        return self.validateDiagnostic(null);
    }
    pub fn validateDiagnostic(self: Prepared, context: ?*?Rejection) !void {
        if (self.version != 1) return fail(context, .equal, "policy.version", .{ .unsigned = 1 }, .{ .unsigned = self.version }, error.InvalidGrpcPolicy);
        if (self.endpoint_revision == 0) return fail(context, .different, "policy.endpoint_revision", .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.InvalidGrpcPolicy);
        if (self.tls != (self.trust_digest != null)) return fail(context, .equal, "policy.trust_digest", .{ .text = if (self.tls) "present" else "absent" }, if (self.trust_digest != null) .redacted else .inapplicable, error.InvalidGrpcPolicy);
        if (self.credentials.len > 16) return fail(context, .maximum, "policy.credentials.count", .{ .unsigned = 16 }, .{ .unsigned = self.credentials.len }, error.InvalidGrpcPolicy);
        if (self.response_metadata.len > 64) return fail(context, .maximum, "policy.response_metadata.count", .{ .unsigned = 64 }, .{ .unsigned = self.response_metadata.len }, error.InvalidGrpcPolicy);
        var transport_detail: ?rpc.transport.Validation = null;
        (rpc.transport.Endpoint{ .host = self.host, .address = self.address, .port = self.port, .tls = self.tls, .timeout_ms = self.timeout_ms, .limits = self.limits }).validateDiagnostic(&transport_detail) catch |err| return rpc.Request.transportFailure(context, transport_detail, .denied, err);
        try (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest }).validateDiagnostic(context);
        for (self.credentials, 0..) |credential, index| {
            if (!self.tls) return fail(context, .equal, "policy.tls", .{ .text = "true" }, .{ .text = "false" }, error.GrpcCredentialRequiresTls);
            var path_bytes: [64]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_bytes, "policy.credentials[{d}]", .{index});
            var detail: ?Rejection = null;
            (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest, .metadata = &.{.{ .name = credential.metadata, .value = .{ .secret = .{ .binding = credential.binding, .version = credential.version } } }} }).validateDiagnostic(&detail) catch |err| {
                if (context) |slot| if (slot.* == null) {
                    var member_path: [64]u8 = undefined;
                    slot.* = if (detail) |value| value.atField(try std.fmt.bufPrint(&member_path, "{s}.{s}", .{ path, if (std.mem.indexOf(u8, value.field[0..value.field_len], "binding") != null) "binding" else if (std.mem.endsWith(u8, value.field[0..value.field_len], "version")) "version" else "metadata" })) else Rejection.detail(.denied, .decode, path, .{ .text = "valid credential reference" }, .redacted, err);
                };
                return err;
            };
            for (self.credentials[0..index]) |previous| if (std.mem.eql(u8, previous.binding, credential.binding)) return fail(context, .occupied, path, .{ .text = "unique credential binding" }, .redacted, error.DuplicateGrpcCredential);
        }
        for (self.response_metadata, 0..) |name, index| {
            var path_bytes: [64]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_bytes, "policy.response_metadata[{d}]", .{index});
            if (sensitive(name)) return fail(context, .policy, path, .{ .text = "non-credential metadata name" }, .redacted, error.GrpcCredentialCaptureForbidden);
            for (self.credentials) |credential| if (std.mem.eql(u8, name, credential.metadata)) return fail(context, .policy, path, .{ .text = "non-credential metadata name" }, .redacted, error.GrpcCredentialCaptureForbidden);
            var detail: ?Rejection = null;
            (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest, .metadata = &.{.{ .name = name, .value = .{ .literal = "" } }} }).validateDiagnostic(&detail) catch |err| {
                if (context) |slot| if (slot.* == null) {
                    slot.* = if (detail) |value| value.atField(path) else Rejection.detail(.denied, .decode, path, .{ .text = "valid metadata name" }, .redacted, err);
                };
                return err;
            };
        }
        if (self.retry_policy) |retry| {
            if (retry.id == 0) return fail(context, .different, "policy.retry.id", .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.GrpcFollowupNotGranted);
            if (retry.revision == 0) return fail(context, .different, "policy.retry.revision", .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.GrpcFollowupNotGranted);
            if (sensitive(retry.key_metadata) or std.mem.endsWith(u8, retry.key_metadata, "-bin")) return fail(context, .policy, "policy.retry.key_metadata", .{ .text = "non-secret text metadata name" }, .redacted, error.InvalidGrpcIdempotencyKey);
            var detail: ?Rejection = null;
            (rpc.Request{ .method = self.method, .shape = self.shape, .descriptor_digest = self.descriptor_digest, .metadata = &.{.{ .name = retry.key_metadata, .value = .{ .literal = "" } }} }).validateDiagnostic(&detail) catch |err| {
                if (context) |slot| if (slot.* == null) {
                    slot.* = if (detail) |value| value.atField("policy.retry.key_metadata") else Rejection.detail(.denied, .decode, "policy.retry.key_metadata", .{ .text = "valid metadata name" }, .redacted, err);
                };
                return err;
            };
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
        try self.validateDiagnostic(context);
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
        const provenance = request.provenance(&bytes) catch |err| {
            if (err != error.WriteFailed) return err;
            return fail(context, .maximum, "request.metadata.bytes", .{ .unsigned = bytes.len }, .unrecorded, err);
        };
        const spec = try rpc.exchange.Publication.Digest.of(rpc.protocol_format, provenance);
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
