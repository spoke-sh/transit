//! Timeout and cancellation are ordered observations. Process hard expiry
//! remains kernel-enforced and does not wait for this service to deliver.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Frame = @import("Frame.zig");

pub fn observation(correlation: u64, observed_ms: u64) !Frame {
    if (correlation == 0 or observed_ms == 0) return error.InvalidTimerObservation;
    var bytes: [12]u8 = undefined;
    bytes[0..4].* = "TMO1".*;
    std.mem.writeInt(u64, bytes[4..12], observed_ms, .little);
    return .{ .kind = .timeout, .correlation = correlation, .payload = try p.Value.init(&bytes) };
}
/// A handler explicitly cancels its own wait. Already accepted work at the peer
/// may finish; this message cannot roll back effects or retract delivered bytes.
pub fn cancel(turn: anytype, correlation: u64) !bool {
    return close(turn, correlation, .cancelled);
}
fn close(turn: anytype, correlation: u64, phase: @FieldType(Turn.Wait, "phase")) !bool {
    var wait = (try turn.waiting(correlation)) orelse return error.UnknownCorrelation;
    if (wait.phase != .waiting) return false;
    const before = turn.decision;
    errdefer turn.decision = before;
    wait.phase = phase;
    wait.resolution_input = turn.delivery.input.position;
    try turn.write(Turn.waitKey(correlation), wait.encode());
    try turn.send(wait.target, .{ .kind = .cancel, .correlation = correlation });
    return true;
}
/// False means a first timeout was accepted and the application should receive
/// its callback. A duplicate/late timeout is consumed without reopening a wait.
pub fn dispatch(turn: anytype, frame: Frame) !bool {
    if (frame.kind != .timeout) return false;
    const wait = (try turn.waiting(frame.correlation)) orelse return error.UnknownCorrelation;
    const observer = wait.observer orelse return error.UnexpectedTimerObserver;
    switch (turn.delivery.input.origin) {
        .external => |origin| if (origin.principal != observer) return error.UnexpectedTimerObserver,
        else => return error.UnexpectedTimerObserver,
    }
    if (frame.payload.len != 12 or !std.mem.eql(u8, frame.payload.data[0..4], "TMO1")) return error.InvalidTimerObservation;
    const observed_ms = std.mem.readInt(u64, frame.payload.data[4..12], .little);
    if (observed_ms < (wait.deadline_ms orelse return error.InvalidTimerObservation)) return error.PrematureTimer;
    return !try close(turn, frame.correlation, .timed_out);
}

test "timeouts require the configured observer and race by input order" {
    var turn_store: @import("TestStore.zig") = .{};
    var turn = try turn_store.turn(.{});
    const correlation = try turn.callWithTimer(8, .{}, 100, 3);
    var next_store: @import("TestStore.zig") = .{};
    var next = try next_store.turn(.{});
    next_store.entries[0] = .{ .key = Turn.waitKey(correlation), .value = (try turn.waiting(correlation)).?.encode(), .revision = 1 };
    const timeout = try observation(correlation, 100);
    try std.testing.expectError(error.UnexpectedTimerObserver, dispatch(&next, timeout));
    next.delivery.input.origin = .{ .external = .{ .principal = 3, .policy_revision = 1 } };
    try std.testing.expectError(error.PrematureTimer, dispatch(&next, try observation(correlation, 99)));
    try std.testing.expect(!try dispatch(&next, timeout));
    try std.testing.expect((try next.waiting(correlation)).?.phase == .timed_out);
    next.delivery.input.value = try (Frame{ .kind = .reply, .correlation = correlation, .payload = try p.Value.init("late") }).encode();
    next.delivery.input.origin = .{ .process = .{ .pid = 8, .turn = 5, .output = 0 } };
    try std.testing.expect(try next.acceptReply() == .closed);
    try std.testing.expect(!try cancel(&next, correlation));
}
