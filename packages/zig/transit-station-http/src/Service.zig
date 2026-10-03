//! Finite configured exchanges with a distinct, authenticated recorded caller.
//! Execution and retirement remain separate from accepting a public request.
const std = @import("std");
const http = @import("root.zig");
const x = http.exchange;
pub const Reference = http.RequestRecord.Reference;
pub const Admission = struct { caller: u64, resource: u64, endpoint_revision: u64, reconcile_before_ms: u64, max_attempts: u32 };
pub const Scope = struct { method: std.http.Method, target: []const u8, headers: []const []const u8 = &.{} };
pub fn validateRequest(scope: Scope, request: http.Request, rendered: []const u8) !void {
    if (scope.headers.len > http.Request.maximum_headers or scope.method != request.method) return error.HttpRequestNotGranted;
    const end = std.mem.indexOf(u8, rendered, " HTTP/1.1\r\n") orelse return error.InvalidHttpRequest;
    const start = @tagName(request.method).len + 1;
    if (start > end or !std.mem.eql(u8, scope.target, rendered[start..end])) return error.HttpRequestNotGranted;
    for (request.headers) |header| {
        const allowed_header = for (scope.headers) |name| {
            if (std.ascii.eqlIgnoreCase(name, header.name)) break true;
        } else false;
        if (!allowed_header) return error.HttpRequestNotGranted;
    }
}
pub const Route = struct {
    pub const magic = "HTA1";
    caller: u64,
    input: u64,
    correlation: u64,
    phase: enum(u8) { admitted = 1, published = 2 } = .admitted,
    request: [x.codec.size(Reference)]u8,
    pub fn validate(self: Route) !void {
        if (self.caller == 0 or self.caller > x.p.max_counter or self.input == 0 or self.input > x.p.max_counter or self.correlation == 0) return error.InvalidHttpRoute;
        _ = try self.reference();
    }
    pub fn reference(self: Route) !Reference {
        return Reference.decode(try x.p.Value.init(&self.request));
    }
};
pub const Outcome = struct {
    pub const magic = "HTR1";
    phase: enum(u8) { observed = 1, closed_unknown = 2, not_dispatched = 3 },
    resource: u64,
    exchange: u64,
    effect: u64,
    attempt: u64,
    status: u16,
    chain: [32]u8,
    pub fn validate(self: Outcome) !void {
        if (self.resource == 0 or self.resource > x.p.max_counter or self.exchange == 0 or self.effect > x.p.max_counter or self.attempt > x.p.max_counter) return error.InvalidHttpOutcome;
        if (self.phase == .observed) {
            if (self.effect == 0 or self.attempt == 0 or self.status < 200 or self.status > 599) return error.InvalidHttpOutcome;
        } else if (self.status != 0 or !std.mem.allEqual(u8, &self.chain, 0)) return error.InvalidHttpOutcome;
        if (self.phase == .closed_unknown and (self.effect == 0 or self.attempt == 0)) return error.InvalidHttpOutcome;
        if (self.phase == .not_dispatched and self.attempt != 0) return error.InvalidHttpOutcome;
    }
    pub fn encode(self: Outcome) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Outcome {
        return x.codec.decode(Outcome, value);
    }
    pub fn diagnostic(self: Outcome, realm: ?u64) !x.p.Diagnostic {
        return x.OutcomeDiagnostic.outcome(.http, self, realm);
    }
    pub fn reference(self: Outcome) !x.Client.Reference {
        try self.validate();
        if (self.phase != .observed) return error.IncompleteExchange;
        return .{ .resource = self.resource, .exchange = self.exchange, .chain = self.chain };
    }
};
pub const Rejection = struct {
    pub const magic = "HTF1";
    reason: enum(u8) { denied = 1, invalid_request = 2, busy = 3 },
    pub fn validate(_: Rejection) !void {}
    pub fn diagnostic(self: Rejection) !x.p.Diagnostic {
        return x.OutcomeDiagnostic.rejection(.http, self);
    }
};
/// Explicit durable disposal of the original caller's replay hold. This is not
/// local reader disposal, remote cancellation or permission to delete history.
pub const Release = struct {
    pub const magic = "HTD1";
    resource: u64,
    exchange: u64,
    pub fn validate(self: Release) !void {
        if (self.resource == 0 or self.resource > x.p.max_counter or self.exchange == 0) return error.InvalidHttpRelease;
    }
    pub fn encode(self: Release) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Release {
        return x.codec.decode(Release, value);
    }
};
pub const Released = struct {
    pub const magic = "HTK1";
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
pub const FollowupTarget = struct { parent: u64, reason: http.Policy.Reason };
pub const Followup = struct {
    pub const magic = "HTU1";
    resource: u64,
    parent: u64,
    reason: http.Policy.Reason,
    request: [x.codec.size(Reference)]u8,
    pub fn validate(self: Followup) !void {
        if (self.resource == 0 or self.resource > x.p.max_counter or self.parent == 0) return error.InvalidHttpFollowup;
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
pub const FollowupValidation = union(enum) { accepted: http.Policy.Reference, rejected: @FieldType(Rejection, "reason") };

// Adapter hooks for the common routing/settlement helper. Layouts stay here.
pub const protocol_format = http.protocol_format;
pub const expected_call_error = error.ExpectedHttpCall;
pub const invalid_route_error = error.InvalidHttpRoute;
pub fn observedStatus(code: u32) !u16 {
    if (code < 200 or code > 599) return error.InvalidHttpOutcome;
    return @intCast(code);
}
const Engine = x.Service(@This());
pub const route = Engine.route;
pub const rejectCall = Engine.rejectCall;
pub const admit = Engine.admit;
pub const allowed = Engine.allowed;
pub const admitFollowup = Engine.admitFollowup;
pub const release = Engine.release;
pub const publish = Engine.publish;
