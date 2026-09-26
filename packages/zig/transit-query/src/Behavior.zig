//! Application-side admission above the kernel. One active query, no accepted
//! query queue. Transport admission and result admission are different facts.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const Turn = s.GrowingTurn;
const Frame = s.Frame;
const r = q.Request;

pub const Requester = struct {
    principal: u64,
    source: u64,
    pub fn interface(self: *Requester) s.GrowingGenServer.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
    fn initialize(raw: ?*anyopaque, turn: *Turn) anyerror!void {
        const self: *Requester = @ptrCast(@alignCast(raw.?));
        try turn.write(r.principalKey(), r.identity(self.principal));
        try turn.write(r.sourceKey(), r.identity(self.source));
    }
    fn finish(turn: *Turn, correlation: u64, phase: []const u8) !void {
        try turn.write(r.statusKey(correlation), try p.Value.init(phase));
        if (try turn.read(r.activeKey())) |value| if (try r.readIdentity(value) == correlation) try turn.write(r.activeKey(), null);
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: Frame) anyerror!void {
        const self: *Requester = @ptrCast(@alignCast(raw.?));
        if (frame.kind == .result_complete) {
            _ = try s.GrowingQuery.completed(turn, frame.correlation);
            // The framework already used two mutations for manifest and wait.
            return finish(turn, frame.correlation, "complete");
        }
        if (frame.kind == .reply) {
            if (try Frame.source(turn.delivery.input) != self.source) return error.UnexpectedReplySource;
            const phase = frame.payload.slice();
            return finish(turn, frame.correlation, if ((std.mem.eql(u8, phase, "denied") or std.mem.eql(u8, phase, "station.query.denied.v2"))) "denied" else if ((std.mem.eql(u8, phase, "cancelled") or std.mem.eql(u8, phase, "station.query.cancelled.v2"))) "cancelled" else "rejected");
        }
        if (frame.kind != .cast) return error.UnsupportedQueryFrame;
        switch (turn.delivery.input.origin) {
            .external => |origin| if (origin.principal != self.principal) return error.QueryPrincipalMismatch,
            else => return error.QueryPrincipalMismatch,
        }
        if (std.mem.eql(u8, frame.payload.slice(), "PQI1")) return;
        if (std.mem.startsWith(u8, frame.payload.slice(), "PQC1")) {
            const correlation = try r.cancelled(frame.payload);
            if (try s.Waiting.cancel(turn, correlation)) try finish(turn, correlation, "cancelled");
            return;
        }
        _ = r.Start.decode(frame.payload) catch {
            try turn.write(r.statusKey(turn.delivery.input.position), try p.Value.init("rejected"));
            return;
        };
        if (try turn.read(r.activeKey()) != null) {
            try turn.write(r.statusKey(turn.delivery.input.position), try p.Value.init("busy"));
            return;
        }
        const correlation = try turn.call(self.source, frame.payload, null);
        try turn.write(r.activeKey(), r.identity(correlation));
        try turn.write(r.statusKey(correlation), try p.Value.init("admitted"));
    }
};
pub const Source = struct {
    table: u32,
    peer: u64,
    pub fn interface(self: *Source) s.GrowingGenServer.Handler {
        return .{ .context = self, .handle = handle };
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: Frame) anyerror!void {
        const self: *Source = @ptrCast(@alignCast(raw.?));
        if (frame.kind != .call) return error.UnsupportedQueryFrame;
        if (try Frame.source(turn.delivery.input) != self.peer) return error.UnexpectedQueryPeer;
        const policy = (try s.GrowingQuery.policy(turn, self.peer)) orelse return turn.reply(try p.Value.init("denied"));
        if (!policy.allow or policy.table != self.table) return turn.reply(try p.Value.init("denied"));
        const start = r.Start.decode(frame.payload) catch return turn.reply(try p.Value.init("rejected"));
        const table = try s.Table.open(turn, self.table);
        if (!std.mem.eql(u8, &start.schema, &(try table.schema.fingerprint()))) return turn.reply(try p.Value.init("rejected"));
        _ = start.plan.bind(.{ .resource = table.resource, .revision = turn.view.revision, .schema = start.schema }, table.schema) catch return turn.reply(try p.Value.init("rejected"));
        _ = try s.GrowingQuery.start(turn, table, start.plan);
    }
};
