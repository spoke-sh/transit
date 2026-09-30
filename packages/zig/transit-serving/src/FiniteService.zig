//! Service composition for the current finite query requester.
//! It owns no transport, SQL parser, ticket or additional result store.
const std = @import("std");
const root = @import("root.zig");
const s = root.station;
const q = root.query;
const p = root.protocol;
const Turn = s.Turn;
const Self = @This();
pub const Configuration = struct { service: root.Model.Configuration, query_principal: u64, source: u64, binding_revision: u64 = 1 };
configuration: Configuration,
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn requester(self: Self) q.UnifiedBehavior.Requester {
    return .{ .principal = self.configuration.query_principal, .source = self.configuration.source };
}
fn initialize(raw: ?*anyopaque, turn: *Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    try root.Model.identity(self.configuration.query_principal);
    try root.Model.identity(self.configuration.source);
    try root.Model.identity(self.configuration.binding_revision);
    var service: root.Service = .{ .configuration = self.configuration.service };
    const base = service.interface();
    try base.initialize.?(base.context, turn);
    var query = self.requester();
    const handler = query.interface();
    try handler.initialize.?(handler.context, turn);
    // Service, requester and GenServer descriptor fit one bounded turn.
}
fn queryCast(frame: *const s.Frame) bool {
    if (frame.kind != .cast) return false;
    _ = q.UnifiedRequest.Command.decode(&frame.payload) catch return false;
    return true;
}
fn denied(turn: *Turn) !bool {
    try turn.write(q.UnifiedRecords.key('e', turn.delivery.input.position, 0), try p.Value.init("ServingDenied"));
    return true;
}
fn rejectInput(raw: ?*anyopaque, turn: *Turn) anyerror!bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = s.Frame.decode(turn.delivery.input.value) catch return denied(turn);
    if (queryCast(&frame)) {
        const command = try q.UnifiedRequest.Command.decode(&frame.payload);
        if (command == .collect and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid) return false;
        if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.configuration.query_principal) return denied(turn);
        if (command == .begin or command == .part or command == .seal or command == .submit or command == .draft_open or command == .draft_submit) {
            const policy = (try root.Service.policy(turn, self.configuration.query_principal)) orelse return denied(turn);
            const binding = (try root.Service.binding(turn)) orelse return denied(turn);
            if (!policy.commands or !policy.reads or !binding.published or binding.revision != self.configuration.binding_revision or binding.target != self.configuration.source or binding.active_limit != 1) return denied(turn);
        }
        return false;
    }
    if (frame.kind == .timeout) return false; // Waiting validates the recorded timer and observer.
    if (frame.kind == .reply) {
        // QueryDelivery/Waiting subsequently validates exact correlation, source,
        // digest and closure. Publication fragments never invoke this handler.
        if ((s.Frame.source(turn.delivery.input) catch 0) != self.configuration.source) return denied(turn);
        return false;
    }
    var service: root.Service = .{ .configuration = self.configuration.service };
    const guard_value = service.guard();
    return guard_value.reject(guard_value.context, turn);
}
fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const config = (try turn.read(root.Model.key('c', 0, 0))) orelse return error.UninitializedService;
    if (!config.eql(try root.Codec.encode('g', self.configuration.service))) return error.ServingConfigurationChanged;
    try self.requester().check(turn);
    if (queryCast(&frame) or frame.kind == .reply or frame.kind == .timeout) {
        var query = self.requester();
        const handler = query.interface();
        return handler.handle(handler.context, turn, frame);
    }
    var service: root.Service = .{ .configuration = self.configuration.service };
    const handler = service.interface();
    return handler.handle(handler.context, turn, frame);
}
