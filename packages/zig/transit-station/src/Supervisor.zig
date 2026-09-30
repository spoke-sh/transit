//! Durable one-for-one policy. This code records lifecycle intent; a separately
//! credentialed controller applies the generation-fenced public operation.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Frame = @import("Frame.zig");
pub const Kind = enum(u8) { activation = 1, failed = 2, suspended = 3, terminated = 4, expired = 5, placement_unavailable = 6, initializing = 7 };
pub const Phase = enum(u8) { watching = 1, retry_wait = 2, retry_requested = 3, exhausted = 4, retired = 5, suspended = 6, placement_unavailable = 7, initializing = 8 };
pub const Observation = struct {
    pid: u64,
    generation: u64,
    failure: u64 = 0,
    cut: u64,
    observed_ms: u64,
    kind: Kind,
    fn validate(self: Observation) !void {
        if (self.pid == 0) return error.InvalidLifecycleObservation;
        inline for (.{ "pid", "generation", "failure", "cut", "observed_ms" }) |name| if (@field(self, name) > p.max_counter) return error.InvalidLifecycleObservation;
    }
    pub fn encode(self: Observation) !Frame {
        try self.validate();
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
        const result: Observation = .{ .pid = std.mem.readInt(u64, bytes[4..12], .little), .generation = std.mem.readInt(u64, bytes[12..20], .little), .failure = std.mem.readInt(u64, bytes[20..28], .little), .cut = std.mem.readInt(u64, bytes[28..36], .little), .observed_ms = std.mem.readInt(u64, bytes[36..44], .little), .kind = std.enums.fromInt(Kind, bytes[44]) orelse return error.InvalidLifecycleObservation };
        try result.validate();
        return result;
    }
};
pub const Child = struct {
    pid: u64,
    observer: u64,
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
        var bytes: [75]u8 = @splat(0);
        bytes[0..4].* = "SUC1".*;
        std.mem.writeInt(u64, bytes[4..12], self.pid, .little);
        std.mem.writeInt(u64, bytes[67..75], self.observer, .little);
        bytes[12] = self.limit;
        bytes[13] = self.attempts;
        bytes[14] = @backingInt(self.phase);
        std.mem.writeInt(u32, bytes[15..19], self.backoff_ms, .little);
        std.mem.writeInt(u64, bytes[19..27], self.generation, .little);
        std.mem.writeInt(u64, bytes[27..35], self.failure, .little);
        std.mem.writeInt(u64, bytes[35..43], self.cut, .little);
        std.mem.writeInt(u64, bytes[43..51], self.observed_ms, .little);
        std.mem.writeInt(u64, bytes[51..59], self.retry_at_ms, .little);
        std.mem.writeInt(u64, bytes[59..67], self.successor orelse 0, .little);
        return p.Value.init(&bytes) catch unreachable;
    }
    pub fn decode(value: p.Value) !Child {
        try value.validate();
        if (value.len != 75 or !std.mem.eql(u8, value.data[0..4], "SUC1")) return error.InvalidChild;
        const b = value.data;
        const successor = std.mem.readInt(u64, b[59..67], .little);
        const child: Child = .{ .pid = std.mem.readInt(u64, b[4..12], .little), .observer = std.mem.readInt(u64, b[67..75], .little), .limit = b[12], .attempts = b[13], .phase = std.enums.fromInt(Phase, b[14]) orelse return error.InvalidChild, .backoff_ms = std.mem.readInt(u32, b[15..19], .little), .generation = std.mem.readInt(u64, b[19..27], .little), .failure = std.mem.readInt(u64, b[27..35], .little), .cut = std.mem.readInt(u64, b[35..43], .little), .observed_ms = std.mem.readInt(u64, b[43..51], .little), .retry_at_ms = std.mem.readInt(u64, b[51..59], .little), .successor = if (successor == 0) null else successor };
        if (child.pid == 0 or child.pid > p.max_counter or child.observer == 0 or child.observer > p.max_counter or child.limit > 16 or child.attempts > child.limit or child.backoff_ms > 60000) return error.InvalidChild;
        inline for (.{ "generation", "failure", "cut", "observed_ms", "retry_at_ms" }) |field| if (@field(child, field) > p.max_counter) return error.InvalidChild;
        if (child.successor) |pid| if (pid > p.max_counter) return error.InvalidChild;
        return child;
    }
    pub fn action(self: Child) ?p.Growth.Command {
        if (self.phase != .retry_requested) return null;
        return .{ .retry = .{ .pid = self.pid, .expected_generation = self.generation, .failure_input = self.failure } };
    }
};
pub fn key(pid: u64) p.Value {
    return @import("QueryPolicy.zig").key('c', pid, 0);
}
pub fn get(turn: anytype, pid: u64) !Child {
    return Child.decode((try turn.read(key(pid))) orelse return error.ChildNotFound);
}
pub fn register(turn: anytype, child: Child) !void {
    _ = try Child.decode(child.encode());
    if (child.attempts != 0 or child.phase != .watching or child.successor != null) return error.InvalidChild;
    if ((try turn.read(key(child.pid))) != null) return error.ChildExists;
    try turn.write(key(child.pid), child.encode());
}
/// A trusted provisioner must supply a separately created PID. A stopped or
/// expired child is never revived and its old mailbox is never transferred.
pub fn replace(turn: anytype, old_pid: u64, expected_cut: u64, child: Child) !void {
    var old = try get(turn, old_pid);
    if (old.phase != .retired or old.cut != expected_cut or old.successor != null or old_pid == child.pid) return error.InvalidReplacement;
    const before = turn.decision;
    errdefer turn.decision = before;
    try register(turn, child);
    old.successor = child.pid;
    try turn.write(key(old_pid), old.encode());
}
pub fn observe(turn: anytype, observation: Observation) !void {
    try observation.validate();
    var child = try get(turn, observation.pid);
    switch (turn.delivery.input.origin) {
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
    var turn_store: @import("TestStore.zig") = .{};
    var turn = try turn_store.turn(.{});
    try register(&turn, .{ .pid = 8, .observer = 3, .limit = 1, .backoff_ms = 10 });
    turn.delivery.input.origin = .{ .external = .{ .principal = 3, .policy_revision = 1 } };
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

test "supervisor observation carries independent full-width identity and time fields" {
    const t = std.testing;
    const value: Observation = .{ .pid = 65536, .generation = p.max_counter, .failure = 0x010203040506, .cut = 0x111213141516, .observed_ms = 0x212223242526, .kind = .failed };
    const frame = try value.encode();
    try t.expectEqualDeep(value, try Observation.decode(frame));
    // Independent byte coordinates prevent adjacent fields from aliasing.
    try t.expectEqual(value.generation, std.mem.readInt(u64, frame.payload.data[12..20], .little));
    try t.expectEqual(value.failure, std.mem.readInt(u64, frame.payload.data[20..28], .little));
    try t.expectEqual(value.cut, std.mem.readInt(u64, frame.payload.data[28..36], .little));
    try t.expectEqual(value.observed_ms, std.mem.readInt(u64, frame.payload.data[36..44], .little));
    var bad = frame;
    bad.payload.len -= 1;
    try t.expectError(error.InvalidLifecycleObservation, Observation.decode(bad));
    bad = frame;
    std.mem.writeInt(u64, bad.payload.data[12..20], p.max_counter + 1, .little);
    try t.expectError(error.InvalidLifecycleObservation, Observation.decode(bad));
}
