//! A private proposal over one captured resource. No I/O, signing key or client
//! is exposed to the handler; runtime isolation remains a separate boundary.
const std = @import("std");
const client = @import("transit_client");
const p = client.protocol;
const Frame = @import("Frame.zig");
const Turn = @This();

delivery: client.Session.Delivery,
view: p.State.View,
entries: [p.State.max_entries]?p.State.Entry,
decision: client.Session.StateDecision,
resource_deadline_ms: ?u64 = null,

pub const Wait = struct {
    target: u64,
    deadline_ms: ?u64 = null,
    observer: ?u8 = null,
    phase: enum(u8) { waiting = 1, replied = 2, timed_out = 3, cancelled = 4 } = .waiting,
    resolution_input: u64 = 0,

    pub fn encode(self: Wait) p.Value {
        var bytes: [27]u8 = @splat(0);
        bytes[0] = 1;
        bytes[1] = @backingInt(self.phase);
        std.mem.writeInt(u64, bytes[2..10], self.target, .little);
        std.mem.writeInt(u64, bytes[10..18], self.deadline_ms orelse 0, .little);
        std.mem.writeInt(u64, bytes[18..26], self.resolution_input, .little);
        bytes[26] = self.observer orelse 255;
        return p.Value.init(&bytes) catch unreachable;
    }
    pub fn decode(value: p.Value) !Wait {
        try value.validate();
        if (value.len != 27 or value.data[0] != 1) return error.InvalidWait;
        const deadline = std.mem.readInt(u64, value.data[10..18], .little);
        return .{
            .target = std.mem.readInt(u64, value.data[2..10], .little),
            .deadline_ms = if (deadline == 0) null else deadline,
            .observer = if (value.data[26] == 255) null else value.data[26],
            .phase = std.enums.fromInt(@FieldType(Wait, "phase"), value.data[1]) orelse return error.InvalidWait,
            .resolution_input = std.mem.readInt(u64, value.data[18..26], .little),
        };
    }
};

pub fn init(delivery: client.Session.Delivery, view: p.State.View, entries: [p.State.max_entries]?p.State.Entry) !Turn {
    if (view.pid != delivery.pid or view.principal != delivery.principal or view.generation != delivery.generation or view.input != delivery.input.position or view.process_revision != delivery.revision) return error.InvalidStateView;
    for (entries, 0..) |slot, i| if (slot) |entry| {
        try p.State.key(entry.key);
        try entry.value.validate();
        for (entries[0..i]) |previous| if (previous) |other| if (other.key.eql(entry.key)) return error.DuplicateStateKey;
    };
    return .{
        .delivery = delivery,
        .view = view,
        .entries = entries,
        .decision = .{ .views = .{ view, null, null, null } },
    };
}

/// Reads include this turn's private writes and deletions.
pub fn get(self: *const Turn, key: p.Value) ?p.Value {
    for (self.decision.mutations) |slot| if (slot) |mutation| if (mutation.key.eql(key)) return mutation.value;
    for (self.entries) |slot| if (slot) |entry| if (entry.key.eql(key)) return entry.value;
    return null;
}
pub fn put(self: *Turn, key: p.Value, value: p.Value) !void {
    try userKey(key);
    try self.write(key, value);
}
pub fn delete(self: *Turn, key: p.Value) !void {
    try userKey(key);
    try self.write(key, null);
}
fn userKey(key: p.Value) !void {
    try p.State.key(key);
    if (key.data[0] == 0) return error.ReservedFrameworkKey;
}
/// Framework records share the same commit/capacity and have no special rights.
pub fn write(self: *Turn, key: p.Value, value: ?p.Value) !void {
    try p.State.key(key);
    if (value) |v| try v.validate();
    var free: ?usize = null;
    for (&self.decision.mutations, 0..) |*slot, i| {
        if (slot.*) |*mutation| {
            if (mutation.key.eql(key)) {
                mutation.value = value;
                self.decision.write_view = self.view.id;
                return;
            }
        } else if (free == null) free = i;
    }
    const index = free orelse return error.MutationBudgetExceeded;
    self.decision.mutations[index] = .{ .key = key, .value = value };
    self.decision.write_view = self.view.id;
}
pub fn send(self: *Turn, destination: u64, frame: Frame) !void {
    if (destination == 0 or destination > p.max_counter) return error.InvalidDestination;
    const value = try frame.encode();
    for (&self.decision.outputs) |*slot| if (slot.* == null) {
        slot.* = .{ .pid = destination, .value = value };
        return;
    };
    return error.OutputBudgetExceeded;
}
pub fn cast(self: *Turn, destination: u64, value: p.Value) !void {
    try self.send(destination, .{ .kind = .cast, .payload = value });
}
pub fn waitKey(correlation: u64) p.Value {
    var bytes: [10]u8 = undefined;
    bytes[0..2].* = "\x00w".*;
    std.mem.writeInt(u64, bytes[2..10], correlation, .little);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn waiting(self: *const Turn, correlation: u64) !?Wait {
    return if (self.get(waitKey(correlation))) |value| try Wait.decode(value) else null;
}
/// One call identity per input; retain terminal evidence unless the application
/// explicitly selects a cleanup policy. Capacity never authorizes eviction.
pub fn call(self: *Turn, destination: u64, value: p.Value, deadline_ms: ?u64) !u64 {
    if (deadline_ms != null) return error.TimerObserverRequired;
    return self.callWithTimer(destination, value, null, null);
}
pub fn callWithTimer(self: *Turn, destination: u64, value: p.Value, deadline_ms: ?u64, observer: ?u8) !u64 {
    const correlation = self.delivery.input.position;
    if (deadline_ms == 0) return error.InvalidDeadline;
    if ((deadline_ms == null) != (observer == null) or observer == 255) return error.InvalidTimerObserver;
    if (observer) |principal| if (principal == 0 or principal >= p.max_principals) return error.InvalidTimerObserver;
    var bound = self.delivery.work_before_ms;
    if (self.resource_deadline_ms) |limit| bound = if (bound) |process_limit| @min(process_limit, limit) else limit;
    if (bound) |limit| if (deadline_ms == null or deadline_ms.? > limit) return error.InvalidWaitLifetime;
    const key = waitKey(correlation);
    if (self.get(key) != null) return error.CorrelationAlreadyUsed;
    const before = self.decision;
    errdefer self.decision = before;
    try self.send(destination, .{ .kind = .call, .correlation = correlation, .payload = value });
    try self.write(key, (Wait{ .target = destination, .deadline_ms = deadline_ms, .observer = observer }).encode());
    return correlation;
}
pub fn reply(self: *Turn, value: p.Value) !void {
    const request = try Frame.decode(self.delivery.input.value);
    if (request.kind != .call) return error.ExpectedCall;
    try self.send(try Frame.source(self.delivery.input), .{ .kind = .reply, .correlation = request.correlation, .payload = value });
}
pub const Reply = union(enum) { accepted: p.Value, closed };
pub fn acceptReply(self: *Turn) !Reply {
    const reply_frame = try Frame.decode(self.delivery.input.value);
    if (reply_frame.kind != .reply) return error.ExpectedReply;
    var wait = (try self.waiting(reply_frame.correlation)) orelse return error.UnknownCorrelation;
    if (wait.target != try Frame.source(self.delivery.input)) return error.UnexpectedReplySource;
    if (wait.phase != .waiting) return .closed;
    wait.phase = .replied;
    wait.resolution_input = self.delivery.input.position;
    try self.write(waitKey(reply_frame.correlation), wait.encode());
    return .{ .accepted = reply_frame.payload };
}
pub fn validate(self: *const Turn) !void {
    var live: usize = 0;
    for (self.entries) |slot| if (slot) |entry| {
        if (self.get(entry.key) != null) live += 1;
    };
    for (self.decision.mutations) |slot| if (slot) |mutation| {
        if (mutation.value == null) continue;
        const existed = for (self.entries) |entry| {
            if (entry) |e| if (e.key.eql(mutation.key)) break true;
        } else false;
        if (!existed) live += 1;
    };
    if (live > p.State.max_entries) return error.StateCapacityExceeded;
}

test "private writes read their own values and reject oversize batches before publication" {
    var turn = try fixture(.{});
    try turn.put(try p.Value.init("a"), try p.Value.init("one"));
    try turn.put(try p.Value.init("a"), try p.Value.init("two"));
    try std.testing.expectEqualStrings("two", turn.get(try p.Value.init("a")).?.slice());
    try turn.delete(try p.Value.init("a"));
    try std.testing.expect(turn.get(try p.Value.init("a")) == null);
    for ([_][]const u8{ "b", "c", "d" }) |key| try turn.put(try p.Value.init(key), .{});
    try std.testing.expectError(error.MutationBudgetExceeded, turn.put(try p.Value.init("e"), .{}));
    try std.testing.expectError(error.ReservedFrameworkKey, turn.put(waitKey(4), .{}));
}

test "call and waiting state are one proposal; forged and closed replies cannot resolve it" {
    var caller = try fixture(.{});
    const correlation = try caller.call(8, try p.Value.init("query"), null);
    try std.testing.expectEqual(@as(u64, 8), (try caller.waiting(correlation)).?.target);
    try std.testing.expectEqual(@as(u64, 8), caller.decision.outputs[0].?.pid);
    var reply_turn = try fixture(try (Frame{ .kind = .reply, .correlation = correlation, .payload = try p.Value.init("answer") }).encode());
    reply_turn.entries[0] = .{ .key = waitKey(correlation), .value = (try caller.waiting(correlation)).?.encode(), .revision = 3 };
    reply_turn.delivery.input.origin.source = .{ .process = .{ .pid = 9, .turn = 3, .output = 0 } };
    try std.testing.expectError(error.UnexpectedReplySource, reply_turn.acceptReply());
    reply_turn.delivery.input.origin.source = .{ .process = .{ .pid = 8, .turn = 3, .output = 0 } };
    try std.testing.expectEqualStrings("answer", (try reply_turn.acceptReply()).accepted.slice());
    try std.testing.expect((try reply_turn.acceptReply()) == .closed);
    try std.testing.expectEqual(@as(u64, 4), (try reply_turn.waiting(correlation)).?.resolution_input);
}

test "capacity includes framework state and a failed call restores every private output" {
    var turn = try fixture(.{});
    for (&turn.entries, 0..) |*entry, i| entry.* = .{ .key = p.Value.integer(@intCast(i)), .value = .{}, .revision = 1 };
    try turn.put(try p.Value.init("extra"), .{});
    try std.testing.expectError(error.StateCapacityExceeded, turn.validate());
    try turn.delete(p.Value.integer(0));
    try turn.validate();
    try turn.put(p.Value.integer(1), .{});
    try turn.put(p.Value.integer(2), .{});
    const before = turn.decision;
    try std.testing.expectError(error.MutationBudgetExceeded, turn.call(8, .{}, null));
    try std.testing.expect(std.meta.eql(before, turn.decision));
}

test "finite waits cannot outlive the process or required state" {
    var turn = try fixture(.{});
    turn.delivery.work_before_ms = 200;
    turn.resource_deadline_ms = 150;
    try std.testing.expectError(error.InvalidWaitLifetime, turn.call(8, .{}, null));
    try std.testing.expectError(error.InvalidWaitLifetime, turn.callWithTimer(8, .{}, 151, 3));
    try std.testing.expectError(error.InvalidTimerObserver, turn.callWithTimer(8, .{}, 100, 0));
    _ = try turn.callWithTimer(8, .{}, 150, 3);
}

pub fn fixture(value: p.Value) !Turn {
    return init(.{ .realm = 1, .principal = 1, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = 4, .value = value, .origin = .{ .source = .{ .external = .{ .principal = 0, .policy_revision = 0 } } } }, .state = .{}, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 1, .generation = 3, .input = 4, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100 }, @splat(null));
}
