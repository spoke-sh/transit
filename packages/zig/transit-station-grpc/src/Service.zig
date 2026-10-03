//! Finite configured exchanges with a distinct, authenticated recorded caller.
//! Execution and retirement remain separate from accepting a public request.
const std = @import("std");
const rpc = @import("root.zig");
const x = rpc.exchange;
pub const Reference = rpc.RequestRecord.Reference;
pub const Admission = struct { caller: u64, resource: u64, endpoint_revision: u64, reconcile_before_ms: u64, max_attempts: u32 };
pub const Scope = struct { method: []const u8, shape: rpc.Shape, descriptor_digest: [32]u8, metadata: []const []const u8 = &.{} };
pub fn validateRequest(scope: Scope, request: rpc.Request) !void {
    return validateRequestDiagnostic(scope, request, null);
}
pub fn validateRequestDiagnostic(scope: Scope, request: rpc.Request, failure: ?*?Rejection) !void {
    request.validate() catch |err| {
        if (failure) |slot| slot.* = Rejection.detail(.invalid_request, .decode, "request", .unrecorded, .unrecorded, err);
        return err;
    };
    const rejected: ?Rejection = if (scope.metadata.len > 64)
        Rejection.detail(.denied, .maximum, "policy.metadata", .{ .unsigned = 64 }, .{ .unsigned = scope.metadata.len }, error.GrpcRequestNotGranted)
    else if (!std.mem.eql(u8, scope.method, request.method))
        Rejection.detail(.denied, .equal, "request.method", .{ .text = scope.method }, .{ .text = request.method }, error.GrpcRequestNotGranted)
    else if (scope.shape != request.shape)
        Rejection.detail(.denied, .equal, "request.shape", .{ .text = @tagName(scope.shape) }, .{ .text = @tagName(request.shape) }, error.GrpcRequestNotGranted)
    else if (!std.mem.eql(u8, &scope.descriptor_digest, &request.descriptor_digest))
        Rejection.detail(.denied, .equal, "request.descriptor_digest", .{ .digest = scope.descriptor_digest }, .{ .digest = request.descriptor_digest }, error.GrpcRequestNotGranted)
    else
        null;
    if (rejected) |detail| {
        if (failure) |slot| slot.* = detail;
        return error.GrpcRequestNotGranted;
    }
    for (request.metadata) |field| {
        const allowed_metadata = for (scope.metadata) |name| {
            if (std.mem.eql(u8, name, field.name)) break true;
        } else false;
        if (!allowed_metadata) {
            if (failure) |slot| slot.* = Rejection.detail(.denied, .policy, "request.metadata", .unrecorded, .{ .text = field.name }, error.GrpcRequestNotGranted);
            return error.GrpcRequestNotGranted;
        }
    }
}

pub const Route = struct {
    pub const magic = "GRA1";
    caller: u64,
    input: u64,
    correlation: u64,
    phase: enum(u8) { admitted = 1, published = 2 } = .admitted,
    request: [x.codec.size(Reference)]u8,
    pub fn validate(self: Route) !void {
        if (self.caller == 0 or self.caller > x.p.max_counter or self.input == 0 or self.input > x.p.max_counter or self.correlation == 0) return error.InvalidGrpcRoute;
        _ = try self.reference();
    }
    pub fn reference(self: Route) !Reference {
        return Reference.decode(try x.p.Value.init(&self.request));
    }
};
pub const Outcome = struct {
    pub const magic = "GRR1";
    phase: enum(u8) { observed = 1, closed_unknown = 2, not_dispatched = 3 },
    resource: u64,
    exchange: u64,
    effect: u64,
    attempt: u64,
    status: u32,
    chain: [32]u8,
    pub fn validate(self: Outcome) !void {
        if (self.resource == 0 or self.resource > x.p.max_counter or self.exchange == 0 or self.effect > x.p.max_counter or self.attempt > x.p.max_counter) return error.InvalidGrpcOutcome;
        if (self.phase == .observed) {
            if (self.effect == 0 or self.attempt == 0 or self.status > 16) return error.InvalidGrpcOutcome;
        } else if (self.status != 0 or !std.mem.allEqual(u8, &self.chain, 0)) return error.InvalidGrpcOutcome;
        if (self.phase == .closed_unknown and (self.effect == 0 or self.attempt == 0)) return error.InvalidGrpcOutcome;
        if (self.phase == .not_dispatched and self.attempt != 0) return error.InvalidGrpcOutcome;
    }
    pub fn encode(self: Outcome) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Outcome {
        return x.codec.decode(Outcome, value);
    }
    pub fn diagnostic(self: Outcome, realm: ?u64) !x.p.Diagnostic {
        return x.OutcomeDiagnostic.outcome(.grpc, self, realm);
    }
    pub fn reference(self: Outcome) !x.Client.Reference {
        try self.validate();
        if (self.phase != .observed) return error.IncompleteExchange;
        return .{ .resource = self.resource, .exchange = self.exchange, .chain = self.chain };
    }
};
pub const Rejection = x.AdmissionRejection.For("GRF1", .grpc);
/// Explicit durable disposal of the original caller's replay hold. This is not
/// local reader disposal, remote cancellation or permission to delete history.
pub const Release = struct {
    pub const magic = "GRD1";
    resource: u64,
    exchange: u64,
    pub fn validate(self: Release) !void {
        if (self.resource == 0 or self.resource > x.p.max_counter or self.exchange == 0) return error.InvalidGrpcRelease;
    }
    pub fn encode(self: Release) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Release {
        return x.codec.decode(Release, value);
    }
};
pub const Released = struct {
    pub const magic = "GRK1";
    resource: u64,
    exchange: u64,
    pub fn validate(self: Released) !void {
        try (Release{ .resource = self.resource, .exchange = self.exchange }).validate();
    }
    pub fn encode(self: Released) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Released {
        return x.codec.decode(Released, value);
    }
};
pub const FollowupTarget = struct { parent: u64, reason: rpc.Policy.Reason };
pub const Followup = struct {
    pub const magic = "GRU1";
    resource: u64,
    parent: u64,
    reason: rpc.Policy.Reason,
    request: [x.codec.size(Reference)]u8,
    pub fn validate(self: Followup) !void {
        if (self.resource == 0 or self.resource > x.p.max_counter or self.parent == 0 or self.reason != .retry) return error.InvalidGrpcFollowup;
        _ = try self.reference();
    }
    pub fn reference(self: Followup) !Reference {
        return Reference.decode(try x.p.Value.init(&self.request));
    }
    pub fn encode(self: Followup) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Followup {
        return x.codec.decode(Followup, value);
    }
};
pub const FollowupValidation = union(enum) { accepted: rpc.Policy.Reference, rejected: Rejection };

// Adapter hooks for the common routing/settlement helper. Layouts stay here.
pub const protocol_format = rpc.protocol_format;
pub const expected_call_error = error.ExpectedGrpcCall;
pub const invalid_route_error = error.InvalidGrpcRoute;
pub fn observedStatus(code: u32) !u32 {
    if (code == 0 or code > 17) return error.InvalidGrpcOutcome;
    return code - 1;
}
const Engine = x.Service(@This());
pub const route = Engine.route;
pub const rejectCall = Engine.rejectCall;
pub const admit = Engine.admit;
pub const allowed = Engine.allowed;
pub const admitFollowup = Engine.admitFollowup;
pub const release = Engine.release;
pub const publish = Engine.publish;
