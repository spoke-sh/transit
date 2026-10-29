//! Authenticated remote admission and original reply routing. Every successful
//! reply shares the final fenced Document acceptance decision.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const c = @import("transit_document").codec;
const Request = @import("Request.zig");
const Service = @import("Service.zig");
const Client = @import("Client.zig");
pub const Policy = struct {
    caller: u64,
    resource: u64,
    replica: u64,
    revision: u64,
    pub fn allows(self: Policy, caller: u64, request: Request.Reference) bool {
        return self.caller != 0 and self.caller <= p.max_counter and self.caller == caller and self.resource == request.resource and self.replica == request.replica and self.revision == request.policy_revision;
    }
};
pub const Reason = enum(u8) { none = 0, invalid_request = 1, denied = 2, busy = 3, invalid_change = 4, dependency = 5, identity_conflict = 6, resynchronize = 7, capacity = 8, retired = 9, type_mismatch = 10 };
pub const Reply = struct {
    status: enum(u8) { accepted = 1, duplicate = 2, rejected = 3 },
    reason: Reason = .none,
    job: u64,
    basis: ?Client.Reference,
    pub fn encode(self: Reply) !p.Value {
        if (self.status == .rejected) {
            if (self.reason == .none) return error.InvalidDocumentReply;
        } else if (self.reason != .none or self.job == 0 or self.basis == null or self.basis.?.revision == 0) return error.InvalidDocumentReply;
        var bytes: [54]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDO1");
        try w.int(u8, @backingInt(self.status));
        try w.int(u8, @backingInt(self.reason));
        try w.int(u64, self.job);
        if (self.basis) |reference| try w.write((try reference.encode()).slice()) else try w.write(&@as([40]u8, @splat(0)));
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Reply {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDO1")) return error.InvalidDocumentReply;
        const status = std.enums.fromInt(@FieldType(Reply, "status"), try r.int(u8)) orelse return error.InvalidDocumentReply;
        const reason = std.enums.fromInt(Reason, try r.int(u8)) orelse return error.InvalidDocumentReply;
        const job = try r.int(u64);
        const reference = try r.read(40);
        const out: Reply = .{ .status = status, .reason = reason, .job = job, .basis = if (std.mem.allEqual(u8, reference, 0)) null else try Client.Reference.decode(try p.Value.init(reference)) };
        try r.finish();
        _ = try out.encode();
        return out;
    }
};
pub const Route = struct {
    owner: u64,
    caller: u64,
    input: u64,
    correlation: u64,
    request: Request.Reference,
    pub fn encode(self: Route) !p.Value {
        if (self.owner == 0 or self.owner > p.max_counter or self.caller == 0 or self.caller > p.max_counter or self.input == 0 or self.input > p.max_counter or self.correlation == 0) return error.InvalidDocumentRoute;
        var bytes: [132]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDT1");
        try w.int(u64, self.owner);
        try w.int(u64, self.caller);
        try w.int(u64, self.input);
        try w.int(u64, self.correlation);
        try w.write((try self.request.encode()).slice());
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Route {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDT1")) return error.InvalidDocumentRoute;
        const out: Route = .{ .owner = try r.int(u64), .caller = try r.int(u64), .input = try r.int(u64), .correlation = try r.int(u64), .request = try Request.Reference.decode(try p.Value.init(try r.read(96))) };
        try r.finish();
        _ = try out.encode();
        return out;
    }
};
pub fn jobId(input: u64) !u64 {
    if (input == 0 or input > p.max_counter) return error.InvalidDocumentRoute;
    return input | (@as(u64, 1) << 63);
}
pub fn route(service: Service, turn: *s.Turn, id: u64) !Route {
    const out = try Route.decode((try turn.read(service.key('r', id))) orelse return error.InvalidDocumentRoute);
    if (out.owner != turn.delivery.pid or out.request.document != service.document or try jobId(out.input) != id) return error.InvalidDocumentRoute;
    return out;
}
fn basis(service: Service, turn: *s.Turn, revision: ?u64) !Client.Reference {
    const head = try service.head(turn);
    return .{ .resource = service.resource, .document = service.document, .epoch = head.state.epoch, .type_revision = head.state.type_revision, .revision = revision orelse head.state.revision };
}
fn send(turn: *s.Turn, caller: u64, correlation: u64, reply: Reply) !void {
    try turn.send(caller, .{ .kind = .reply, .correlation = correlation, .payload = try reply.encode() });
}
fn decline(service: Service, turn: *s.Turn, caller: u64, correlation: u64, reason: Reason) !void {
    try send(turn, caller, correlation, .{ .status = .rejected, .reason = reason, .job = 0, .basis = if (reason == .denied or reason == .invalid_request) null else try basis(service, turn, null) });
}
/// Infrastructure/corruption failures are deliberately absent from this list.
fn candidateReason(err: anyerror) ?Reason {
    return switch (err) {
        error.DocumentBusy => .busy,
        error.DocumentRetired => .retired,
        error.DocumentIdentityMismatch, error.DocumentTypeError => .type_mismatch,
        error.DocumentResyncRequired => .resynchronize,
        error.DocumentDependencyMissing, error.DocumentWrongDependency => .dependency,
        error.DocumentIdentityConflict => .identity_conflict,
        error.DocumentConflictCapacity, error.DocumentRecordCapacity, error.DocumentRevisionCapacity, error.IndexCapacity => .capacity,
        else => null,
    };
}
fn requestReason(err: anyerror) ?Reason {
    return switch (err) {
        error.InvalidDocumentRequest, error.InvalidDocumentEncoding => .invalid_request,
        error.InvalidDocumentChange, error.InvalidDocumentIdentity, error.InvalidDocumentObserved, error.InvalidDocumentCausality, error.InvalidDocumentScalar, error.InvalidDocumentUnicode => .invalid_change,
        else => null,
    };
}
pub const Admission = enum { admitted, repeated, rejected };
pub fn admit(service: Service, turn: *s.Turn, policy: Policy, source: anytype, node_limit: u32) !Admission {
    const before = turn.decision;
    errdefer turn.decision = before;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call) return error.ExpectedDocumentCall;
    const caller = try s.Frame.source(turn.delivery.input);
    const request = Request.Reference.decode(frame.payload) catch {
        try decline(service, turn, caller, frame.correlation, .invalid_request);
        return .rejected;
    };
    if (!policy.allows(caller, request) or request.document != service.document) {
        try decline(service, turn, caller, frame.correlation, .denied);
        return .rejected;
    }
    const id = try jobId(turn.delivery.input.position);
    const stored: Route = .{ .owner = turn.delivery.pid, .caller = caller, .input = turn.delivery.input.position, .correlation = frame.correlation, .request = request };
    if (try turn.read(service.key('r', id))) |value| {
        if (!value.eql(try stored.encode())) return error.InvalidDocumentRoute;
        return .repeated;
    }
    if (try turn.read(service.key('j', id)) != null or try turn.read(service.key('c', id)) != null) return error.InvalidDocumentRoute;
    const head = try service.head(turn);
    const refusal: ?Reason = if (head.retired) .retired else if (head.active_job != 0) .busy else null;
    if (refusal) |reason| {
        try decline(service, turn, caller, frame.correlation, reason);
        return .rejected;
    }
    const change = Request.read(source, request) catch |err| {
        const reason = requestReason(err) orelse return err;
        try decline(service, turn, caller, frame.correlation, reason);
        return .rejected;
    };
    _ = service.prepare(turn, id, change, node_limit) catch |err| {
        const reason = candidateReason(err) orelse return err;
        try decline(service, turn, caller, frame.correlation, reason);
        return .rejected;
    };
    try turn.write(service.key('r', id), try stored.encode());
    return .admitted;
}
/// Explicit terminal rejection closes the candidate and freezes its correlated
/// response in one turn; independent cleanup never changes that disposition.
pub fn reject(service: Service, turn: *s.Turn, id: u64, reason: Reason) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (reason == .none) return error.InvalidDocumentReply;
    const record = try route(service, turn, id);
    const job = try service.job(turn, id);
    if (job.phase == .rejected) return;
    try service.reject(turn, id);
    try send(turn, record.caller, record.correlation, .{ .status = .rejected, .reason = reason, .job = id, .basis = if (reason == .denied or reason == .invalid_request) null else try basis(service, turn, null) });
}
pub const Progress = enum { idle, progress, accepted, duplicate, rejected };
pub fn advance(service: Service, turn: *s.Turn, policy: Policy, source: anytype) !Progress {
    const before = turn.decision;
    errdefer turn.decision = before;
    const head = try service.head(turn);
    if (head.retired) return error.DocumentRetired;
    if (head.active_job == 0) return .idle;
    const id = head.active_job;
    const record = try route(service, turn, id);
    if (!policy.allows(record.caller, record.request)) return error.AccessDenied;
    const job = try service.job(turn, id);
    if (job.phase == .preparing) {
        const change = Request.read(source, record.request) catch |err| {
            const reason = requestReason(err) orelse return err;
            try reject(service, turn, id, reason);
            return .rejected;
        };
        _ = try service.upload(turn, id, change);
        return .progress;
    }
    // The immutable caller request must remain authorized/available through
    // acceptance, even after its exact bytes have been copied to the local job.
    try Request.check(source, record.request);
    const result = service.advance(turn, id) catch |err| {
        const reason = candidateReason(err) orelse return err;
        try reject(service, turn, id, reason);
        return .rejected;
    };
    switch (result) {
        .progress => return .progress,
        .accepted, .duplicate => |revision| {
            const status: @FieldType(Reply, "status") = if (result == .accepted) .accepted else .duplicate;
            try send(turn, record.caller, record.correlation, .{ .status = status, .job = id, .basis = try basis(service, turn, revision) });
            return if (result == .accepted) .accepted else .duplicate;
        },
    }
}
