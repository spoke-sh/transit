//! Public publication behavior. Malformed callers get retained dispositions;
//! infrastructure failures keep the input unresolved, never falsely rejected.
const std = @import("std");
const root = @import("root.zig");
const s = root.station;
const Failure = root.PublicationFailure;
const Self = @This();
allocator: std.mem.Allocator,
owner: root.Publication,
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn get(raw: ?*anyopaque) *Self {
    return @ptrCast(@alignCast(raw.?));
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    try get(raw).owner.initialize(turn);
}
fn disposition(self: Self, turn: *s.Turn, reason: Failure.Reason, command: ?root.Request.Command, context: Failure.Context) !void {
    const who = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0;
    const record = try Failure.capture(turn, command, reason, context);
    try turn.write(root.Records.key(self.owner.configuration.application, 'e', who, turn.delivery.input.position), try root.Records.encode('e', record));
    try turn.write(root.Records.key(self.owner.configuration.application, 'f', who, turn.delivery.input.position), try root.Records.encode('f', context.witness));
}
fn rejectInput(raw: ?*anyopaque, turn: *s.Turn) anyerror!bool {
    const self = get(raw);
    const frame = s.Frame.decode(turn.delivery.input.value) catch |err| {
        try self.disposition(turn, .InvalidApplicationFrame, null, .{ .cause = err });
        return true;
    };
    if (frame.kind != .cast or turn.delivery.input.origin != .external) {
        try self.disposition(turn, .ApplicationExternalOriginRequired, null, .{});
        return true;
    }
    _ = root.Request.Command.decode(frame.payload) catch |err| {
        try self.disposition(turn, .InvalidApplicationCommand, null, .{ .cause = err });
        return true;
    };
    return false;
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) anyerror!void {
    const self = get(raw);
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return self.disposition(turn, .ApplicationExternalOriginRequired, null, .{});
    const command = root.Request.Command.decode(frame.payload) catch |err| return self.disposition(turn, .InvalidApplicationCommand, null, .{ .cause = err });
    const before = turn.decision;
    var context: Failure.Context = .{};
    self.applyContext(turn, command, &context) catch |err| {
        turn.decision = before;
        if (turn.read_error != null) return err;
        const reason = Failure.reason(err) orelse return err;
        try self.disposition(turn, reason, command, context);
    };
}
pub fn apply(self: Self, turn: *s.Turn, command: root.Request.Command) !void {
    return self.applyContext(turn, command, null);
}
fn applyContext(self: Self, turn: *s.Turn, command: root.Request.Command, context: ?*Failure.Context) !void {
    try command.validate();
    var owner = self.owner;
    owner.failure = context;
    switch (command) {
        .initialize => try owner.initialize(turn),
        .policy => |value| try owner.setPolicy(turn, value.principal, value.expected, value.next),
        .begin => |proposal| _ = try owner.beginUpload(turn, proposal),
        .part => |value| _ = try owner.appendUpload(turn, value.operation, .{ .ordinal = value.ordinal, .second = value.second, .bytes = value.bytes.slice() }),
        .publish => |operation| _ = try owner.finishUpload(self.allocator, turn, operation),
        .abandon => |operation| try owner.abandon(turn, operation),
        .collect => |operation| _ = try owner.collect(turn, operation),
    }
}
