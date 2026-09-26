//! One admitted exchange per worker PID, with a distinct recorded caller.
//! Execution and retirement remain separate from accepting a public request.
const std = @import("std");
const http = @import("root.zig");
const x = http.exchange;
const Turn = x.station.GrowingTurn;
const Frame = x.station.Frame;
const Reference = http.RequestRecord.Reference;
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
pub fn route(exchange: x.Exchange, source: anytype) !?Route {
    return if (try source.read(x.Exchange.key(exchange.id, 'r', 0))) |value| try x.codec.decode(Route, value) else null;
}
fn reject(turn: *Turn, caller: u64, frame: Frame, reason: @FieldType(Rejection, "reason")) !void {
    try turn.send(caller, .{ .kind = .reply, .correlation = frame.correlation, .payload = try x.codec.encode(Rejection{ .reason = reason }) });
}
pub fn admit(turn: *Turn, id: u64, policy: Admission, limits: x.Limits) !enum { admitted, duplicate, rejected } {
    const before = turn.decision;
    errdefer turn.decision = before;
    const frame = try Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call) return error.ExpectedHttpCall;
    const caller = try Frame.source(turn.delivery.input);
    const reference = Reference.decode(frame.payload) catch {
        try reject(turn, caller, frame, .invalid_request);
        return .rejected;
    };
    if (caller != policy.caller or reference.resource != policy.resource or reference.endpoint_revision != policy.endpoint_revision or reference.reconcile_before_ms > policy.reconcile_before_ms or reference.max_attempts > policy.max_attempts) {
        try reject(turn, caller, frame, .denied);
        return .rejected;
    }
    const ex: x.Exchange = .{ .resource = turn.view.resource, .id = id };
    if (try route(ex, turn)) |previous| {
        if (previous.caller == caller and previous.correlation == frame.correlation and std.mem.eql(u8, &previous.request, frame.payload.slice())) return .duplicate;
        try reject(turn, caller, frame, .busy);
        return .rejected;
    }
    const created = try x.Exchange.create(turn, id, .{ .caller = caller, .input = turn.delivery.input.position, .protocol = http.protocol_format }, limits, reference.reconcile_before_ms);
    const stored: Route = .{ .caller = caller, .input = turn.delivery.input.position, .correlation = frame.correlation, .request = frame.payload.data[0..x.codec.size(Reference)].* };
    try turn.write(x.Exchange.key(created.id, 'r', 0), try x.codec.encode(stored));
    return .admitted;
}
/// Current service policy is separate from PID ownership. No name lookup can
/// redirect a previously accepted call to a replacement caller.
pub fn allowed(record: Route, policy: Admission) bool {
    const reference = record.reference() catch return false;
    return record.caller == policy.caller and reference.resource == policy.resource and reference.endpoint_revision == policy.endpoint_revision and reference.max_attempts <= policy.max_attempts and reference.reconcile_before_ms <= policy.reconcile_before_ms;
}
/// Admit one authenticated disposal call against an already published route.
/// Mutation and correlated acknowledgement share the same fenced turn. Duplicate
/// disposal returns the same identity, including after explicit retirement.
pub fn release(turn: *Turn, ex: x.Exchange, policy: Admission) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    const frame = try Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call) return error.ExpectedHttpCall;
    const caller = try Frame.source(turn.delivery.input);
    const request = Release.decode(frame.payload) catch return reject(turn, caller, frame, .invalid_request);
    if (caller != policy.caller or request.resource != ex.resource or request.exchange != ex.id) return reject(turn, caller, frame, .denied);
    const record = (try route(ex, turn)) orelse return reject(turn, caller, frame, .denied);
    if (record.caller != caller or !allowed(record, policy)) return reject(turn, caller, frame, .denied);
    if (record.phase != .published) return reject(turn, caller, frame, .busy);
    const descriptor = try ex.inspect(turn);
    if (descriptor.owner != turn.delivery.pid or descriptor.caller != record.caller or descriptor.input != record.input) return error.InvalidHttpRoute;
    // Abandoned preparation never acquired a caller hold or dispatch obligation.
    if ((try ex.control(turn)).disposition != .no_intent) _ = try ex.releaseCaller(turn, caller);
    try turn.send(caller, .{ .kind = .reply, .correlation = frame.correlation, .payload = try (Released{ .resource = ex.resource, .exchange = ex.id }).encode() });
}
pub fn publish(turn: *Turn, ex: x.Exchange) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var record = (try route(ex, turn)) orelse return false;
    if (record.phase == .published) return false;
    const descriptor = try ex.inspect(turn);
    if (descriptor.owner != turn.delivery.pid or descriptor.caller != record.caller or descriptor.input != record.input) return error.InvalidHttpRoute;
    const control = try ex.control(turn);
    const phase: @FieldType(Outcome, "phase") = switch (control.disposition) {
        .observed => if (descriptor.phase == .complete) .observed else return error.IncompleteExchange,
        .closed_unknown => .closed_unknown,
        .cancelled => .not_dispatched,
        .no_intent => if (descriptor.phase == .unknown) .not_dispatched else return error.UnsettledExchange,
        .pending => return error.UnsettledExchange,
    };
    const value: Outcome = .{ .phase = phase, .resource = ex.resource, .exchange = ex.id, .effect = control.effect, .attempt = descriptor.attempt, .status = if (phase == .observed) @intCast(descriptor.terminal_code) else 0, .chain = if (phase == .observed) descriptor.chain else @splat(0) };
    try turn.send(record.caller, .{ .kind = .reply, .correlation = record.correlation, .payload = try value.encode() });
    record.phase = .published;
    try turn.write(x.Exchange.key(ex.id, 'r', 0), try x.codec.encode(record));
    return true;
}
