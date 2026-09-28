//! Public publication behavior. Malformed callers get retained dispositions;
//! infrastructure failures keep the input unresolved, never falsely rejected.
const std = @import("std");
const root = @import("root.zig");
const s = root.station;
const p = root.protocol;
const Self = @This();
allocator: std.mem.Allocator,
owner: root.Publication,
pub fn interface(self: *Self) s.GrowingGenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GrowingGenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn get(raw: ?*anyopaque) *Self {
    return @ptrCast(@alignCast(raw.?));
}
fn initialize(raw: ?*anyopaque, turn: *s.GrowingTurn) !void {
    try get(raw).owner.initialize(turn);
}
fn disposition(self: Self, turn: *s.GrowingTurn, reason: []const u8) !void {
    const who = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0;
    try turn.write(root.Records.key(self.owner.configuration.application, 'e', who, turn.delivery.input.position), try p.Value.init(reason));
}
fn rejectInput(raw: ?*anyopaque, turn: *s.GrowingTurn) anyerror!bool {
    const self = get(raw);
    const frame = s.Frame.decode(turn.delivery.input.value) catch {
        try self.disposition(turn, "InvalidApplicationFrame");
        return true;
    };
    if (frame.kind != .cast or turn.delivery.input.origin != .external) {
        try self.disposition(turn, "ApplicationExternalOriginRequired");
        return true;
    }
    _ = root.Request.Command.decode(frame.payload) catch {
        try self.disposition(turn, "InvalidApplicationCommand");
        return true;
    };
    return false;
}
fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) anyerror!void {
    const self = get(raw);
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return self.disposition(turn, "ApplicationExternalOriginRequired");
    const command = root.Request.Command.decode(frame.payload) catch return self.disposition(turn, "InvalidApplicationCommand");
    const before = turn.decision;
    self.apply(turn, command) catch |err| {
        turn.decision = before;
        if (turn.read_error != null or !requestError(err)) return err;
        try self.disposition(turn, @errorName(err));
    };
}
pub fn apply(self: Self, turn: *s.GrowingTurn, command: root.Request.Command) !void {
    try command.validate();
    switch (command) {
        .initialize => try self.owner.initialize(turn),
        .policy => |value| try self.owner.setPolicy(turn, value.principal, value.expected, value.next),
        .begin => |proposal| _ = try self.owner.beginUpload(turn, proposal),
        .part => |value| _ = try self.owner.appendUpload(turn, value.operation, .{ .ordinal = value.ordinal, .second = value.second, .bytes = value.bytes.slice() }),
        .publish => |operation| _ = try self.owner.finishUpload(self.allocator, turn, operation),
        .abandon => |operation| try self.owner.abandon(turn, operation),
        .collect => |operation| _ = try self.owner.collect(turn, operation),
    }
}
fn requestError(err: anyerror) bool {
    return switch (err) {
        error.ApplicationDenied,
        error.ApplicationPolicyConflict,
        error.ApplicationIdentityConflict,
        error.ApplicationRecordOccupied,
        error.ApplicationOperationNotFound,
        error.ApplicationAlreadyApplied,
        error.ApplicationNotAbandoned,
        error.ApplicationDigestMismatch,
        error.ApplicationDefinitionMismatch,
        error.NoncanonicalApplicationProgram,
        error.ApplicationUploadPartConflict,
        error.InvalidApplicationPart,
        error.InvalidApplicationOperation,
        error.InvalidApplicationPolicy,
        error.InvalidApplicationProposal,
        error.PublicationQuotaExceeded,
        error.PublicationGap,
        error.InvalidPublicationPart,
        error.PublicationPartConflict,
        error.IncompletePublication,
        error.InvalidApplicationProgram,
        error.InterfaceProgramTooLarge,
        => true,
        else => false,
    };
}
