//! Non-trading Table application. The serving framework never decodes its values.
const std = @import("std");
const serving = @import("transit_serving");
const s = serving.station;
const p = s.protocol;
const q = serving.query;
const c = q.catalog;
const Counter = @import("Counter.zig");
const Self = @This();
pub const Configuration = struct { ingress: u64, initializer: u64, table_limits: s.Publication.Limits, queries: bool = false };
allocator: std.mem.Allocator,
configuration: Configuration,
query: ?q.UnifiedBehavior.Source = null,
pub const progress_key = Counter.progress_key;
const create_counter = p.Value.init("create-counter") catch unreachable;
const continue_counter = p.Value.init("continue-counter") catch unreachable;
fn catalog(self: *Self, turn: *s.Turn) c.TableCatalog {
    return .{ .configuration = .{ .scope = .{ .realm = turn.delivery.realm, .resource = turn.view.resource, .catalog = 1 }, .owner = turn.delivery.pid, .administrator = self.configuration.initializer, .table_limits = self.configuration.table_limits } };
}
fn create(self: *Self, turn: *s.Turn, continuing: bool) !void {
    const owner = self.catalog(turn);
    const request: c.TableDdlRequest = .{ .principal = self.configuration.initializer, .operation = 1, .object = Counter.object, .expected_revision = 0, .name = try .init("counter"), .action = .{ .create = .{ .schema = Counter.schema } } };
    const result = if (continuing) try owner.continueDdl(self.allocator, turn, request) else try owner.step(self.allocator, turn, request);
    if (result.terminal()) {
        if (result.operation.state != .applied) return error.CounterInitializationRejected;
    } else try turn.cast(turn.delivery.pid, continue_counter);
}
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or frame.payload.len != 0 or turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.configuration.initializer) return error.UninitializedCounter;
    try self.catalog(turn).initialize(turn);
    if (self.query) |*source| {
        const handler = source.interface();
        try handler.initialize.?(handler.context, turn);
    }
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (frame.kind == .cast and turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == self.configuration.initializer) {
        if (frame.payload.len == 0) return;
        if (frame.payload.eql(create_counter)) return self.create(turn, false);
        if (std.mem.startsWith(u8, frame.payload.slice(), "TCA1")) {
            // This application exposes explicit policy controls. It owns its
            // Table shape and counter mutation semantics; no raw SQL mutation
            // route can write behind a frozen counter command.
            if (try c.TableControl.Command.decode(frame.payload) != .policy) return error.UnsupportedCounterControl;
            var behavior: c.TableBehavior = .{ .allocator = self.allocator, .configuration = self.catalog(turn).configuration };
            const handler = behavior.interface();
            return handler.handle(handler.context, turn, frame);
        }
        if (self.query != null and std.mem.startsWith(u8, frame.payload.slice(), "UQA1")) {
            const policy = try q.UnifiedRecords.Policy.decode(frame.payload);
            if (policy.peer != self.configuration.ingress) return error.UnexpectedQueryPeer;
            return q.UnifiedCapture.setPolicy(turn, policy);
        }
    }
    if (frame.kind == .cast and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid) {
        if (frame.payload.eql(continue_counter)) return self.create(turn, true);
        if (frame.payload.eql(Counter.continuation)) return Counter.drive(self.allocator, turn);
    }
    if (self.query) |*source| {
        // Query continuations and query cancellation have their own durable
        // provenance checks. Serving calls remain the SV1 invocation profile.
        if (frame.kind == .cast or frame.kind == .cancel or (frame.kind == .call and !std.mem.startsWith(u8, frame.payload.slice(), "SV1i"))) {
            const handler = source.interface();
            return handler.handle(handler.context, turn, frame);
        }
    }
    if (try s.Frame.source(turn.delivery.input) != self.configuration.ingress) return error.UnexpectedServingIngress;
    if (frame.kind == .cancel) return; // Ordered cancellation cannot undo a committed update.
    if (frame.kind != .call) return error.UnsupportedServingInvocation;
    return Counter.enqueue(turn, self.configuration.ingress, frame);
}
