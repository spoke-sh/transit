//! Non-trading Table application. The serving framework never decodes its values.
const std = @import("std");
const serving = @import("transit_serving");
const s = serving.station;
const p = s.protocol;
const q = serving.query;
const Counter = @import("Counter.zig");
const Self = @This();
pub const Configuration = struct { ingress: u64, initializer: u64, data: Counter.Data.Binding, queries: bool = false };
allocator: std.mem.Allocator,
configuration: Configuration,
query: ?q.UnifiedBehavior.Source = null,
data: Counter.Data.Client,
pub const progress_key = Counter.progress_key;
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or frame.payload.len != 0 or turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.configuration.initializer) return error.UninitializedCounter;
    var declared = Counter.schema;
    declared.object = self.configuration.data.object;
    var definition = try Counter.Data.definition(self.data, self.configuration.data, declared);
    defer definition.deinit();
    try self.configuration.data.bind(turn, true);
    if (self.query) |*source| {
        const handler = source.interface();
        try handler.initialize.?(handler.context, turn);
    }
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    try self.configuration.data.bind(turn, false);
    if (frame.kind == .cast and turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == self.configuration.initializer) {
        if (frame.payload.len == 0) return;
        if (self.query != null and std.mem.startsWith(u8, frame.payload.slice(), "UQA1")) {
            const policy = try q.UnifiedRecords.Policy.decode(frame.payload);
            if (policy.peer != self.configuration.ingress) return error.UnexpectedQueryPeer;
            return q.UnifiedCapture.setPolicy(turn, policy);
        }
    }
    if (frame.kind == .cast and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid) {
        if (frame.payload.eql(Counter.continuation)) return Counter.drive(self.allocator, turn, self.data, self.configuration.data) catch |err| {
            turn.read_error = err;
            return err;
        };
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
