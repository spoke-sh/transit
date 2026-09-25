//! Durable one-for-one policy. This code records lifecycle intent; a separately
//! credentialed controller applies the generation-fenced public operation.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig").Legacy;
const Frame = @import("Frame.zig");
pub const max_children = 4;
pub const Kind = enum(u8) { activation = 1, failed = 2, suspended = 3, terminated = 4, expired = 5, placement_unavailable = 6, initializing = 7 };
pub const Phase = enum(u8) { watching = 1, retry_wait = 2, retry_requested = 3, exhausted = 4, retired = 5, suspended = 6, placement_unavailable = 7, initializing = 8 };
pub const Observation = struct {
    pid: u64,
    generation: u64,
    failure: u64 = 0,
    cut: u64,
    observed_ms: u64,
    kind: Kind,
    pub fn encode(self: Observation) !Frame {
        var bytes: [45]u8 = undefined;
        bytes[0..4].* = "SUP1".*;
        std.mem.writeInt(u64, bytes[4..12], self.pid, .little);
        std.mem.writeInt(u64, bytes[12..20], self.generation, .little);
        std.mem.writeInt(u64, bytes[20..28], self.failure, .little);
        std.mem.writeInt(u64, bytes[28..36], self.cut, .little);
        std.mem.writeInt(u64, bytes[36..44], self.observed_ms, .little);
        bytes[44] = @backingInt(self.kind);
        return .{ .kind = .cast, .payload = try p.Value.init(&bytes) };
    }
    pub fn decode(frame: Frame) !Observation {
        if (frame.kind != .cast or frame.payload.len != 45 or !std.mem.eql(u8, frame.payload.data[0..4], "SUP1")) return error.InvalidLifecycleObservation;
        const bytes = frame.payload.data;
        return .{ .pid = std.mem.readInt(u64, bytes[4..12], .little), .generation = std.mem.readInt(u64, bytes[12..20], .little), .failure = std.mem.readInt(u64, bytes[20..28], .little), .cut = std.mem.readInt(u64, bytes[28..36], .little), .observed_ms = std.mem.readInt(u64, bytes[36..44], .little), .kind = std.enums.fromInt(Kind, bytes[44]) orelse return error.InvalidLifecycleObservation };
    }
};
pub const Child = struct {
    pid: u64,
    observer: u8,
    limit: u8,
    backoff_ms: u32,
    attempts: u8 = 0,
    generation: u64 = 0,
    failure: u64 = 0,
    cut: u64 = 0,
    observed_ms: u64 = 0,
    retry_at_ms: u64 = 0,
    successor: ?u64 = null,
    phase: Phase = .watching,
    pub fn encode(self: Child) p.Value {
        var bytes: [68]u8 = @splat(0);
        bytes[0..4].* = "SUC1".*;
        std.mem.writeInt(u64, bytes[4..12], self.pid, .little);
        bytes[12] = self.observer;
        bytes[13] = self.limit;
        bytes[14] = self.attempts;
        bytes[15] = @backingInt(self.phase);
        std.mem.writeInt(u32, bytes[16..20], self.backoff_ms, .little);
        std.mem.writeInt(u64, bytes[20..28], self.generation, .little);
        std.mem.writeInt(u64, bytes[28..36], self.failure, .little);
        std.mem.writeInt(u64, bytes[36..44], self.cut, .little);
        std.mem.writeInt(u64, bytes[44..52], self.observed_ms, .little);
        std.mem.writeInt(u64, bytes[52..60], self.retry_at_ms, .little);
        std.mem.writeInt(u64, bytes[60..68], self.successor orelse 0, .little);
        return p.Value.init(&bytes) catch unreachable;
    }
    pub fn decode(value: p.Value) !Child {
        try value.validate();
        if (value.len != 68 or !std.mem.eql(u8, value.data[0..4], "SUC1")) return error.InvalidChild;
        const b = value.data;
        const successor = std.mem.readInt(u64, b[60..68], .little);
        const child: Child = .{ .pid = std.mem.readInt(u64, b[4..12], .little), .observer = b[12], .limit = b[13], .attempts = b[14], .phase = std.enums.fromInt(Phase, b[15]) orelse return error.InvalidChild, .backoff_ms = std.mem.readInt(u32, b[16..20], .little), .generation = std.mem.readInt(u64, b[20..28], .little), .failure = std.mem.readInt(u64, b[28..36], .little), .cut = std.mem.readInt(u64, b[36..44], .little), .observed_ms = std.mem.readInt(u64, b[44..52], .little), .retry_at_ms = std.mem.readInt(u64, b[52..60], .little), .successor = if (successor == 0) null else successor };
        if (child.pid == 0 or child.pid > p.max_counter or child.observer == 0 or child.observer >= p.max_principals or child.limit > 16 or child.attempts > child.limit or child.backoff_ms > 60000) return error.InvalidChild;
        return child;
    }
    pub fn action(self: Child) ?p.Lifecycle.Command {
        if (self.phase != .retry_requested) return null;
        return .{ .retry = .{ .pid = self.pid, .expected_generation = self.generation, .failure = self.failure } };
    }
};
pub fn key(pid: u64) p.Value {
    return @import("Query.zig").key('c', pid, 0);
}
pub fn get(turn: *const Turn, pid: u64) !Child {
    return Child.decode(turn.get(key(pid)) orelse return error.ChildNotFound);
}
pub fn register(turn: *Turn, child: Child) !void {
    _ = try Child.decode(child.encode());
    if (child.attempts != 0 or child.phase != .watching or child.successor != null) return error.InvalidChild;
    if (turn.get(key(child.pid)) != null) return error.ChildExists;
    var count: usize = 0;
    for (turn.entries) |slot| if (slot) |entry| {
        if (entry.key.len == 11 and entry.key.data[0] == 0 and entry.key.data[1] == 'c') count += 1;
    };
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (mutation.key.len == 11 and mutation.key.data[0] == 0 and mutation.key.data[1] == 'c' and mutation.value != null) {
            const existed = for (turn.entries) |old| {
                if (old) |entry| if (entry.key.eql(mutation.key)) break true;
            } else false;
            if (!existed) count += 1;
        }
    };
    if (count >= max_children) return error.ChildBudgetExceeded;
    try turn.write(key(child.pid), child.encode());
}
/// A trusted provisioner must supply a separately created PID. A stopped or
/// expired child is never revived and its old mailbox is never transferred.
pub fn replace(turn: *Turn, old_pid: u64, expected_cut: u64, child: Child) !void {
    var old = try get(turn, old_pid);
    if (old.phase != .retired or old.cut != expected_cut or old.successor != null or old_pid == child.pid) return error.InvalidReplacement;
    const before = turn.decision;
    errdefer turn.decision = before;
    try register(turn, child);
    old.successor = child.pid;
    try turn.write(key(old_pid), old.encode());
}
pub fn observe(turn: *Turn, observation: Observation) !void {
    var child = try get(turn, observation.pid);
    switch (turn.delivery.input.origin.source) {
        .external => |origin| if (origin.principal != child.observer) return error.UnexpectedLifecycleObserver,
        else => return error.UnexpectedLifecycleObserver,
    }
    if (observation.cut < child.cut or observation.generation < child.generation or observation.observed_ms < child.observed_ms) return;
    if (child.phase == .retired) return;
    if (child.phase == .exhausted and observation.kind != .terminated and observation.kind != .expired) return;
    const same = observation.cut == child.cut and observation.generation == child.generation and observation.failure == child.failure;
    if (same and child.phase != .retry_wait) return;
    child.cut = observation.cut;
    child.generation = observation.generation;
    child.observed_ms = observation.observed_ms;
    switch (observation.kind) {
        .terminated, .expired => {
            child.phase = .retired;
            child.failure = 0;
        },
        .suspended => child.phase = .suspended,
        .placement_unavailable => child.phase = .placement_unavailable,
        .initializing => child.phase = .initializing,
        .activation => {
            child.phase = .watching;
            child.failure = 0;
        },
        .failed => {
            if (observation.failure == 0) return error.InvalidLifecycleObservation;
            if (child.phase == .retry_requested and child.failure == observation.failure) {
                // A provider stop can fence ownership again. Update the intent's
                // generation without charging a second handler retry.
                try turn.write(key(child.pid), child.encode());
                return;
            }
            if (child.attempts >= child.limit) {
                child.phase = .exhausted;
            } else {
                if (child.phase != .retry_wait or child.failure != observation.failure) child.retry_at_ms = try std.math.add(u64, observation.observed_ms, child.backoff_ms);
                child.failure = observation.failure;
                child.phase = .retry_wait;
                if (observation.observed_ms >= child.retry_at_ms) {
                    child.attempts += 1;
                    child.phase = .retry_requested;
                }
            }
        },
    }
    try turn.write(key(child.pid), child.encode());
}

test "retry intent is durable and bounded; expiry is terminal and replacement names a new PID" {
    var turn = try Turn.fixture(.{});
    try register(&turn, .{ .pid = 8, .observer = 3, .limit = 1, .backoff_ms = 10 });
    turn.delivery.input.origin.source = .{ .external = .{ .principal = 3, .policy_revision = 1 } };
    var event: Observation = .{ .pid = 8, .generation = 3, .failure = 20, .cut = 30, .observed_ms = 100, .kind = .failed };
    try observe(&turn, event);
    try std.testing.expect((try get(&turn, 8)).action() == null);
    event.observed_ms = 110;
    try observe(&turn, event);
    const pending = try get(&turn, 8);
    try std.testing.expectEqual(@as(u64, 3), pending.action().?.retry.expected_generation);
    try observe(&turn, event);
    try std.testing.expectEqual(@as(u8, 1), (try get(&turn, 8)).attempts);
    event.kind = .activation;
    event.generation = 4;
    event.cut = 31;
    try observe(&turn, event);
    event.kind = .failed;
    event.generation = 5;
    event.cut = 32;
    try observe(&turn, event);
    try std.testing.expect((try get(&turn, 8)).phase == .exhausted);
    try register(&turn, .{ .pid = 9, .observer = 3, .limit = 1, .backoff_ms = 0 });
    event.pid = 9;
    event.kind = .expired;
    try observe(&turn, event);
    event.kind = .activation;
    event.cut += 1;
    try observe(&turn, event);
    try std.testing.expect((try get(&turn, 9)).phase == .retired);
    try replace(&turn, 9, 32, .{ .pid = 10, .observer = 3, .limit = 1, .backoff_ms = 0 });
    try std.testing.expectEqual(@as(?u64, 10), (try get(&turn, 9)).successor);
    try std.testing.expectError(error.InvalidReplacement, replace(&turn, 9, 32, .{ .pid = 11, .observer = 3, .limit = 1, .backoff_ms = 0 }));
}
