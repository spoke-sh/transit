//! Durable caller identity over Station's call/reply boundary. Host fields may
//! schedule work, but these resource records own pending calls and outcomes.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const c = @import("codec.zig");
const m = @import("Model.zig");
const Request = @import("Request.zig");
const Remote = @import("Remote.zig");
pub const Target = struct { pid: u64, resource: u64 };
pub const Call = struct {
    target: Target,
    correlation: u64,
    request: Request.Reference,
    pub fn encode(self: Call) !p.Value {
        if (self.target.pid == 0 or self.target.pid > p.max_counter or self.target.resource == 0 or self.target.resource > p.max_counter or self.correlation == 0) return error.InvalidDocumentCall;
        var bytes: [124]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDW1");
        try w.int(u64, self.target.pid);
        try w.int(u64, self.target.resource);
        try w.int(u64, self.correlation);
        try w.write((try self.request.encode()).slice());
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Call {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDW1")) return error.InvalidDocumentCall;
        const out: Call = .{ .target = .{ .pid = try r.int(u64), .resource = try r.int(u64) }, .correlation = try r.int(u64), .request = try Request.Reference.decode(try p.Value.init(try r.read(96))) };
        try r.finish();
        _ = try out.encode();
        return out;
    }
};
pub fn key(namespace: u64, tag: enum(u8) { call = 'c', outcome = 'o' }) p.Value {
    var bytes: [11]u8 = undefined;
    bytes[0..2].* = "\x00q".*;
    std.mem.writeInt(u64, bytes[2..10], namespace, .big);
    bytes[10] = @backingInt(tag);
    return p.Value.init(&bytes) catch unreachable;
}
pub const Progress = enum { progress, sent, waiting, complete };
/// Freeze the target with the call in the same turn. Changing a name/configuration
/// afterward cannot redirect it. A rejected call needs an explicit new namespace
/// to resubmit; this helper never retries a semantic rejection automatically.
pub fn stage(turn: *s.GrowingTurn, target: Target, reference: Request.Reference, change: m.Change) !Progress {
    const before = turn.decision;
    errdefer turn.decision = before;
    const expected = try Request.prepare(turn.view.resource, reference.namespace, reference.policy_revision, change);
    if (!std.meta.eql(reference, expected)) return error.InvalidDocumentCall;
    const prototype: Call = .{ .target = target, .correlation = 1, .request = reference };
    _ = try prototype.encode();
    if (try pending(turn, reference.namespace)) |saved| {
        if (!std.meta.eql(saved.target, target) or !std.meta.eql(saved.request, reference)) return error.DocumentCallIdentityConflict;
        return if (try outcome(turn, reference.namespace) != null) .complete else .waiting;
    }
    if (!try Request.stage(turn, reference, change)) return .progress;
    const correlation = try turn.call(target.pid, try reference.encode(), null);
    const saved: Call = .{ .target = target, .correlation = correlation, .request = reference };
    try turn.write(key(reference.namespace, .call), try saved.encode());
    return .sent;
}
pub fn pending(source: anytype, namespace: u64) !?Call {
    const saved = (try source.read(key(namespace, .call))) orelse return null;
    const out = try Call.decode(saved);
    if (out.request.namespace != namespace or out.request.resource != source.view.resource) return error.InvalidDocumentCall;
    return out;
}
pub fn outcome(source: anytype, namespace: u64) !?Remote.Reply {
    const saved = (try source.read(key(namespace, .outcome))) orelse return null;
    return try Remote.Reply.decode(saved);
}
/// Call from the Station reply handler (which already settles its wait record).
/// The durable call binding independently validates provenance and response basis.
pub fn accept(turn: *s.GrowingTurn, namespace: u64) !Remote.Reply {
    const before = turn.decision;
    errdefer turn.decision = before;
    const saved = (try pending(turn, namespace)) orelse return error.UnknownDocumentCall;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .reply or frame.correlation != saved.correlation or try s.Frame.source(turn.delivery.input) != saved.target.pid) return error.UnexpectedDocumentReply;
    const reply = try Remote.Reply.decode(frame.payload);
    if (reply.basis) |basis| {
        if (basis.resource != saved.target.resource or basis.document != saved.request.document) return error.UnexpectedDocumentReply;
        if (reply.status != .rejected and (basis.epoch != saved.request.epoch or basis.type_revision != saved.request.type_revision)) return error.UnexpectedDocumentReply;
    }
    const address = key(namespace, .outcome);
    if (try turn.read(address)) |previous| {
        if (!previous.eql(frame.payload)) return error.DocumentReplyIdentityConflict;
        return reply;
    }
    try turn.write(address, frame.payload);
    return reply;
}
