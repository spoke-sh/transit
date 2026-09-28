//! Opt-in composition of serving sessions and a finite query requester in one
//! durable owner. Existing standalone service deployments keep their profile.
const std = @import("std");
const root = @import("root.zig");
const s = root.station;
const q = root.query;
const p = root.protocol;
const Turn = s.GrowingTurn;
const Self = @This();
pub const Configuration = struct { service: root.Model.Configuration, query_principal: u64, source: u64 };
configuration: Configuration,
resources: s.client.ResourceReader,
scratch: []u8,
/// Qualified conservative wall-clock bound supplied by the host per dispatch.
upper_ms: u64,

pub fn interface(self: *Self) s.GrowingGenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GrowingGenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn service(self: Self) root.Service {
    return .{ .configuration = self.configuration.service };
}
fn requester(self: Self) q.UnifiedBehavior.Requester {
    return .{ .principal = self.configuration.query_principal, .source = self.configuration.source };
}
fn refresh(self: Self) root.Refresh {
    return .{ .principal = self.configuration.query_principal, .source = self.configuration.source };
}
fn reader(self: Self, turn: *Turn) root.RefreshReader {
    return .{ .resources = self.resources, .ingress = turn.delivery.pid, .resource = turn.view.resource, .scratch = self.scratch };
}
fn initialize(raw: ?*anyopaque, turn: *Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    var base = self.service();
    const handler = base.interface();
    try handler.initialize.?(handler.context, turn);
    var query = self.requester();
    const queries = query.interface();
    try queries.initialize.?(queries.context, turn);
}
fn reject(turn: *Turn, reason: []const u8) !bool {
    const principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0;
    try turn.write(root.Model.key('e', principal, turn.delivery.input.position), try p.Value.init(reason));
    return true;
}
fn rejectQuery(turn: *Turn, reason: []const u8) !bool {
    // Use the owning client's disposition contract. One write also preserves
    // the four-mutation bound when an input is rejected during initialization.
    try turn.write(q.UnifiedRecords.key('e', turn.delivery.input.position, 0), try p.Value.init(reason));
    return true;
}
fn selfCast(turn: *Turn) bool {
    return turn.delivery.input.origin == .process and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid;
}
fn rejectInput(raw: ?*anyopaque, turn: *Turn) anyerror!bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = s.Frame.decode(turn.delivery.input.value) catch return reject(turn, "InvalidServingFrame");
    if (frame.kind == .cast) {
        if (frame.payload.eql(root.RefreshModel.wake)) return if (selfCast(turn)) false else reject(turn, "UnexpectedRefreshWake");
        if (std.mem.startsWith(u8, frame.payload.slice(), "UQ")) {
            const command = q.UnifiedRequest.Command.decode(&frame.payload) catch return rejectQuery(turn, "InvalidQueryUpload");
            if (turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == self.configuration.query_principal) return false;
            return if (command == .collect and selfCast(turn)) false else rejectQuery(turn, "QueryPrincipalMismatch");
        }
    }
    if (frame.kind == .timeout and try turn.read(q.UnifiedRecords.key('i', frame.correlation, 0)) != null) {
        if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.configuration.query_principal) return rejectQuery(turn, "UnexpectedTimerObserver");
        const wait = (try turn.waiting(frame.correlation)) orelse return rejectQuery(turn, "UnknownServingCorrelation");
        if (wait.observer != self.configuration.query_principal or frame.payload.len != 12 or !std.mem.eql(u8, frame.payload.data[0..4], "TMO1")) return rejectQuery(turn, "InvalidTimerObservation");
        if (std.mem.readInt(u64, frame.payload.data[4..12], .little) < (wait.deadline_ms orelse return rejectQuery(turn, "InvalidTimerObservation"))) return rejectQuery(turn, "PrematureTimer");
        return false;
    }
    var base = self.service();
    const input = base.guard();
    return input.reject(input.context, turn);
}
fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    var base = self.service();
    var query = self.requester();
    try query.check(turn);
    const stored = (try turn.read(root.Model.key('c', 0, 0))) orelse return error.UninitializedService;
    if (!stored.eql(try root.Codec.encode('g', self.configuration.service))) return error.ServingConfigurationChanged;
    if (frame.kind == .cast and frame.payload.eql(root.RefreshModel.wake)) {
        if (!selfCast(turn)) {
            _ = try reject(turn, "UnexpectedRefreshWake");
            return;
        }
        if (try self.refresh().drive(turn, self.reader(turn), self.upper_ms)) try turn.cast(turn.delivery.pid, root.RefreshModel.wake);
        return;
    }
    const is_query = if (frame.kind == .cast) std.mem.startsWith(u8, frame.payload.slice(), "UQ") else (frame.kind == .reply or frame.kind == .timeout) and try turn.read(q.UnifiedRecords.key('i', frame.correlation, 0)) != null;
    var wake = is_query;
    if (is_query) {
        const handler = query.interface();
        try handler.handle(handler.context, turn, frame);
    } else if (frame.kind == .cast) {
        const command = try root.Model.Command.decode(frame.payload);
        if (command == .refresh) {
            wake = true;
            const before = turn.decision;
            self.refresh().apply(turn, if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0, command.refresh, self.reader(turn), self.upper_ms) catch |err| {
                turn.decision = before;
                if (turn.read_error != null or !root.Refresh.requestError(err)) return err;
                _ = try reject(turn, @errorName(err));
            };
        } else {
            const handler = base.interface();
            try handler.handle(handler.context, turn, frame);
            // Session attachment/renewal and ordinary application traffic do
            // not create query demand. A clock tick can release recorded
            // spacing only after the scheduler has selected work at least once.
            wake = command == .reactive and command.reactive == .observe_clock and try turn.read(root.RefreshModel.scheduler_key) != null;
        }
    } else {
        const handler = base.interface();
        try handler.handle(handler.context, turn, frame);
    }
    // Handler mutations and refresh work never share a turn. Only query work
    // and qualified clock progress schedule recoverable refresh wakeups.
    if (wake) try turn.cast(turn.delivery.pid, root.RefreshModel.wake);
}
