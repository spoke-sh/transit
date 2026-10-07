//! Private-turn semantics over bounded reads of a captured state view.
const std = @import("std");
const client = @import("transit_client");
const p = client.protocol;
const Frame = @import("Frame.zig");
pub const WaitPhase = enum(u8) { waiting = 1, replied = 2, timed_out = 3, cancelled = 4 };
pub const Page = p.Growth.Batch(p.Growth.Entry, p.Value);
pub const Reader = struct {
    context: *anyopaque,
    cache_reads: bool = false,
    read: *const fn (*anyopaque, p.Growth.View, p.Value) anyerror!?p.Value,
    many: ?*const fn (*anyopaque, View, [p.Growth.page_size]?p.Value) anyerror![p.Growth.page_size]?p.Growth.Entry = null,
    page: ?*const fn (*anyopaque, p.Growth.View, ?p.Value) anyerror!Page = null,
    version: ?*const fn (*anyopaque, p.Growth.ReadVersionId) anyerror!p.Growth.ReadVersion = null,
    version_entries: ?*const fn (*anyopaque, p.Growth.ReadVersion, ?p.Value, ?p.Value) anyerror!Page = null,
};
const Turn = @This();
const Session = client.Session;
const View = p.Growth.View;
const Decision = Session.Decision;
pub const Observer = u64;
pub const read_cache_entries = 64;
delivery: Session.Delivery,
view: View,
reader: Reader,
read_error: ?anyerror = null,
decision: Decision,
resource_deadline_ms: ?u64 = null,
// One bounded metadata/row working set, independent of durable cardinality.
// A native prefetch still requests at most one eight-key protocol page.
read_cache: [read_cache_entries]?struct { key: p.Value, value: ?p.Value } = @splat(null),
cache_view: ?View = null,
cache_next: usize = 0,

/// A read-only borrow of this turn's captured committed cut. Point reads and
/// pages both exclude private writes, without acquiring/retaining a new view.
pub const Committed = struct {
    turn: *Turn,
    view: View,
    fn check(self: *@This()) !void {
        if (self.turn.read_error) |err| return err;
        if (!std.meta.eql(self.view, self.turn.view)) {
            self.turn.read_error = error.InvalidCommittedSource;
            return error.InvalidCommittedSource;
        }
    }
    pub fn read(self: *@This(), key: p.Value) !?p.Value {
        try self.check();
        try p.State.key(key);
        return self.turn.readCommitted(key);
    }
    pub fn page(self: *@This(), after: ?p.Value) !Page {
        try self.check();
        return self.turn.pageCommitted(after);
    }
};
pub fn committed(self: *Turn) Committed {
    return .{ .turn = self, .view = self.view };
}

/// A read-only source borrowed for this handler. Reopen its durable ID
/// from a later turn; never retain the native pointer across handlers.
pub const Retained = struct {
    turn: *Turn,
    view: p.Growth.ReadVersion,
    pub fn read(self: *@This(), key: p.Value) !?p.Value {
        try p.Growth.validateKey(key);
        const result = try self.fetch(key, null);
        return if (result.entries[0]) |entry| entry.value else null;
    }
    pub fn page(self: *@This(), after: ?p.Value) !Page {
        if (after) |key| try p.Growth.validateKey(key);
        return self.fetch(null, after);
    }
    fn fetch(self: *@This(), key: ?p.Value, after: ?p.Value) !Page {
        if (self.turn.read_error) |err| return err;
        try self.turn.dependVersion(self.view.id);
        const read_version = self.turn.reader.version_entries orelse return error.UnsupportedReadVersion;
        return read_version(self.turn.reader.context, self.view, key, after) catch |err| {
            self.turn.read_error = err;
            return err;
        };
    }
};

/// Retain this turn's committed source. Private writes are excluded.
/// The returned identity becomes live only with the whole proposal.
pub fn retain(self: *Turn) !p.Growth.ReadVersionId {
    if (self.read_error) |err| return err;
    var free: ?usize = null;
    for (self.decision.retain, 0..) |slot, i| {
        if (slot == self.view.id) return .{ .pid = self.delivery.pid, .input = self.delivery.input.position, .index = @intCast(i) };
        if (slot == null and free == null) free = i;
    }
    const index = free orelse return error.VersionBudgetExceeded;
    self.decision.retain[index] = self.view.id;
    return .{ .pid = self.delivery.pid, .input = self.delivery.input.position, .index = @intCast(index) };
}
fn versionSlot(self: *Turn, slots: *[p.Growth.version_changes]?p.Growth.ReadVersionId, id: p.Growth.ReadVersionId) !void {
    try p.Growth.validateVersionId(id);
    if (id.pid != self.delivery.pid) return error.WrongActivation;
    var free: ?usize = null;
    for (slots, 0..) |slot, i| {
        if (slot) |value| {
            if (std.meta.eql(id, value)) return;
        } else if (free == null) {
            free = i;
        }
    }
    slots[free orelse return error.VersionBudgetExceeded] = id;
}
fn dependVersion(self: *Turn, id: p.Growth.ReadVersionId) !void {
    try self.versionSlot(&self.decision.read_versions, id);
}
pub fn release(self: *Turn, id: p.Growth.ReadVersionId) !void {
    try self.versionSlot(&self.decision.release, id);
}
pub fn openVersion(self: *Turn, id: p.Growth.ReadVersionId) !Retained {
    if (self.read_error) |err| return err;
    try self.dependVersion(id);
    const get_version = self.reader.version orelse return error.UnsupportedReadVersion;
    const version = get_version(self.reader.context, id) catch |err| {
        self.read_error = err;
        return err;
    };
    if (!std.meta.eql(id, version.id) or version.released_at != null) {
        self.read_error = error.InvalidReadVersion;
        return error.InvalidReadVersion;
    }
    return .{ .turn = self, .view = version };
}

pub const Wait = struct {
    target: u64,
    deadline_ms: ?u64 = null,
    observer: ?Observer = null,
    phase: WaitPhase = .waiting,
    resolution_input: u64 = 0,

    pub fn encode(self: Wait) p.Value {
        var bytes: [34]u8 = @splat(0);
        bytes[0] = 1;
        bytes[1] = @backingInt(self.phase);
        std.mem.writeInt(u64, bytes[2..10], self.target, .little);
        std.mem.writeInt(u64, bytes[10..18], self.deadline_ms orelse 0, .little);
        std.mem.writeInt(u64, bytes[18..26], self.resolution_input, .little);
        std.mem.writeInt(u64, bytes[26..34], self.observer orelse 0, .little);
        return p.Value.init(&bytes) catch unreachable;
    }
    pub fn decode(value: p.Value) !Wait {
        try value.validate();
        if (value.len != 34 or value.data[0] != 1) return error.InvalidWait;
        const observer: ?Observer = blk: {
            const id = std.mem.readInt(u64, value.data[26..34], .little);
            if (id > p.max_counter) return error.InvalidWait;
            break :blk if (id == 0) null else id;
        };
        const deadline = std.mem.readInt(u64, value.data[10..18], .little);
        return .{
            .target = std.mem.readInt(u64, value.data[2..10], .little),
            .deadline_ms = if (deadline == 0) null else deadline,
            .observer = observer,
            .phase = std.enums.fromInt(@FieldType(Wait, "phase"), value.data[1]) orelse return error.InvalidWait,
            .resolution_input = std.mem.readInt(u64, value.data[18..26], .little),
        };
    }
};

pub fn init(delivery: Session.Delivery, view: View, data: Reader) !Turn {
    if (view.pid != delivery.pid or view.principal != delivery.principal or view.generation != delivery.generation or view.input != delivery.input.position or view.process_revision != delivery.revision) return error.InvalidStateView;
    return .{
        .delivery = delivery,
        .view = view,
        .reader = data,
        .decision = .{ .views = .{ view, null, null, null } },
    };
}

/// Read one captured key, with private writes taking precedence. A failed read
/// poisons this proposal even when application code catches the returned error.
pub fn read(self: *Turn, key: p.Value) !?p.Value {
    try p.State.key(key);
    if (self.read_error) |err| return err;
    for (self.decision.mutations) |slot| if (slot) |mutation| if (mutation.key.eql(key)) return mutation.value;
    return self.readCommitted(key);
}
/// Prefetch only missing committed keys, bounded by one protocol page. Errors
/// poison the entire proposal. Private writes retain read-your-writes precedence.
pub fn prefetch(self: *Turn, keys: []const p.Value) !void {
    if (self.read_error) |err| return err;
    if (keys.len > p.Growth.page_size) return error.MutationBudgetExceeded;
    const many = self.reader.many orelse return;
    if (!self.reader.cache_reads) return;
    self.checkCache();
    var requested: [p.Growth.page_size]?p.Value = @splat(null);
    var count: usize = 0;
    outer: for (keys) |key| {
        try p.State.key(key);
        for (self.read_cache) |slot| if (slot) |entry| if (entry.key.eql(key)) continue :outer;
        for (requested[0..count]) |slot| if (slot.?.eql(key)) continue :outer;
        requested[count] = key;
        count += 1;
    }
    if (count == 0) return;
    const entries = many(self.reader.context, self.view, requested) catch |err| {
        self.read_error = err;
        return err;
    };
    for (requested[0..count], entries[0..count]) |key, entry| self.seedRead(key.?, if (entry) |value| value.value else null);
}
fn checkCache(self: *Turn) void {
    if (self.cache_view == null or !std.meta.eql(self.cache_view.?, self.view)) {
        self.read_cache = @splat(null);
        self.cache_next = 0;
        self.cache_view = self.view;
    }
}
/// Seed only a read already validated against this exact captured view.
pub fn seedRead(self: *Turn, key: p.Value, value: ?p.Value) void {
    if (!self.reader.cache_reads) return;
    self.checkCache();
    self.read_cache[self.cache_next] = .{ .key = key, .value = value };
    self.cache_next = (self.cache_next + 1) % self.read_cache.len;
}
fn readCommitted(self: *Turn, key: p.Value) !?p.Value {
    if (self.read_error) |err| return err;
    if (self.reader.cache_reads) {
        self.checkCache();
        for (self.read_cache) |slot| if (slot) |entry| if (entry.key.eql(key)) return entry.value;
    }
    const value = self.reader.read(self.reader.context, self.view, key) catch |err| {
        self.read_error = err;
        return err;
    };
    self.seedRead(key, value);
    return value;
}
pub fn put(self: *Turn, key: p.Value, value: p.Value) !void {
    try userKey(key);
    try self.write(key, value);
}
/// One page of committed state. Private mutations cannot be silently
/// mixed into a query over a captured version.
pub fn page(self: *Turn, after: ?p.Value) !Page {
    if (self.read_error) |err| return err;
    for (self.decision.mutations) |slot| if (slot != null) return error.QueryAfterMutation;
    return self.pageCommitted(after);
}
fn pageCommitted(self: *Turn, after: ?p.Value) !Page {
    const scan = self.reader.page orelse return error.UnsupportedStateScan;
    return scan(self.reader.context, self.view, after) catch |err| {
        self.read_error = err;
        return err;
    };
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
pub fn waiting(self: *Turn, correlation: u64) !?Wait {
    return if (try self.read(waitKey(correlation))) |value| try Wait.decode(value) else null;
}
/// One call identity per input; retain terminal evidence unless the application
/// explicitly selects a cleanup policy. Capacity never authorizes eviction.
pub fn call(self: *Turn, destination: u64, value: p.Value, deadline_ms: ?u64) !u64 {
    if (deadline_ms != null) return error.TimerObserverRequired;
    return self.callWithTimer(destination, value, null, null);
}
pub fn callWithTimer(self: *Turn, destination: u64, value: p.Value, deadline_ms: ?u64, observer: ?Observer) !u64 {
    const correlation = self.delivery.input.position;
    if (deadline_ms == 0) return error.InvalidDeadline;
    if ((deadline_ms == null) != (observer == null)) return error.InvalidTimerObserver;
    if (observer) |principal| if (principal == 0 or principal > p.max_counter) return error.InvalidTimerObserver;
    var bound = self.delivery.work_before_ms;
    if (self.resource_deadline_ms) |limit| bound = if (bound) |process_limit| @min(process_limit, limit) else limit;
    if (bound) |limit| if (deadline_ms == null or deadline_ms.? > limit) return error.InvalidWaitLifetime;
    const key = waitKey(correlation);
    if (try self.read(key) != null) return error.CorrelationAlreadyUsed;
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
    if (self.read_error) |err| return err;
}

test "private writes read their own values and reject oversize batches before publication" {
    var turn_store: @import("TestStore.zig") = .{};
    var turn = try turn_store.turn(.{});
    try turn.put(try p.Value.init("a"), try p.Value.init("one"));
    try turn.put(try p.Value.init("a"), try p.Value.init("two"));
    try std.testing.expectEqualStrings("two", (try turn.read(try p.Value.init("a"))).?.slice());
    try turn.delete(try p.Value.init("a"));
    try std.testing.expect((try turn.read(try p.Value.init("a"))) == null);
    for ([_][]const u8{ "b", "c", "d" }) |key| try turn.put(try p.Value.init(key), .{});
    try std.testing.expectError(error.MutationBudgetExceeded, turn.put(try p.Value.init("e"), .{}));
    try std.testing.expectError(error.ReservedFrameworkKey, turn.put(Turn.waitKey(4), .{}));
}

test "call and waiting state are one proposal; forged and closed replies cannot resolve it" {
    var caller_store: @import("TestStore.zig") = .{};
    var caller = try caller_store.turn(.{});
    const correlation = try caller.call(8, try p.Value.init("query"), null);
    try std.testing.expectEqual(@as(u64, 8), (try caller.waiting(correlation)).?.target);
    try std.testing.expectEqual(@as(u64, 8), caller.decision.outputs[0].?.pid);
    var reply_turn_store: @import("TestStore.zig") = .{};
    var reply_turn = try reply_turn_store.turn(try (Frame{ .kind = .reply, .correlation = correlation, .payload = try p.Value.init("answer") }).encode());
    reply_turn_store.entries[0] = .{ .key = Turn.waitKey(correlation), .value = (try caller.waiting(correlation)).?.encode(), .revision = 3 };
    reply_turn.delivery.input.origin = .{ .process = .{ .pid = 9, .turn = 3, .output = 0 } };
    try std.testing.expectError(error.UnexpectedReplySource, reply_turn.acceptReply());
    reply_turn.delivery.input.origin = .{ .process = .{ .pid = 8, .turn = 3, .output = 0 } };
    try std.testing.expectEqualStrings("answer", (try reply_turn.acceptReply()).accepted.slice());
    try std.testing.expect((try reply_turn.acceptReply()) == .closed);
    try std.testing.expectEqual(@as(u64, 4), (try reply_turn.waiting(correlation)).?.resolution_input);
}

test "a failed call restores every private output when the mutation budget is exhausted" {
    var store: @import("TestStore.zig") = .{};
    var turn = try store.turn(.{});
    for ([_][]const u8{ "a", "b", "c", "d" }) |key| try turn.put(try p.Value.init(key), .{});
    const before = turn.decision;
    try std.testing.expectError(error.MutationBudgetExceeded, turn.call(8, .{}, null));
    try std.testing.expect(std.meta.eql(before, turn.decision));
}

test "finite waits cannot outlive the process or required state" {
    var turn_store: @import("TestStore.zig") = .{};
    var turn = try turn_store.turn(.{});
    turn.delivery.work_before_ms = 200;
    turn.resource_deadline_ms = 150;
    try std.testing.expectError(error.InvalidWaitLifetime, turn.call(8, .{}, null));
    try std.testing.expectError(error.InvalidWaitLifetime, turn.callWithTimer(8, .{}, 151, 3));
    try std.testing.expectError(error.InvalidTimerObserver, turn.callWithTimer(8, .{}, 100, 0));
    _ = try turn.callWithTimer(8, .{}, 150, 3);
}

test "captured cache preserves private precedence, absence, poison and view boundaries" {
    var source: @import("TestStore.zig") = .{};
    var turn = try source.turn(.{});
    turn.reader.cache_reads = true;
    const key = try p.Value.init("a");
    try std.testing.expectEqual(null, try turn.read(key));
    try std.testing.expectEqual(null, try turn.read(key));
    try std.testing.expectEqual(1, source.reads);
    try turn.put(key, p.Value.integer(7));
    try std.testing.expectEqual(7, try (try turn.read(key)).?.asInteger());
    var committed_source = turn.committed();
    try std.testing.expectEqual(null, try committed_source.read(key));
    source.fail = true;
    try std.testing.expectError(error.Unavailable, turn.read(try p.Value.init("b")));
    try std.testing.expectError(error.Unavailable, turn.read(key));
    try std.testing.expectError(error.Unavailable, turn.validate());
    source.fail = false;
    var next = try source.turn(.{});
    next.reader.cache_reads = true;
    _ = try next.read(key);
    try std.testing.expectEqual(3, source.reads);
    next.view.revision += 1;
    _ = try next.read(key);
    try std.testing.expectEqual(4, source.reads);
}

test "captured metadata working set is bounded and survives more than one read page" {
    const t = std.testing;
    var source: @import("TestStore.zig") = .{};
    for (0..read_cache_entries + 1) |i| source.entries[i] = .{ .key = p.Value.integer(@intCast(i)), .value = p.Value.integer(@intCast(i)), .revision = 0 };
    var turn = try source.turn(.{});
    turn.reader.cache_reads = true;
    for (0..2) |_| for (0..read_cache_entries) |i| {
        const value = (try turn.read(p.Value.integer(@intCast(i)))).?;
        try t.expectEqual(@as(i64, @intCast(i)), try value.asInteger());
    };
    try t.expectEqual(read_cache_entries, source.reads);
    _ = try turn.read(p.Value.integer(read_cache_entries));
    _ = try turn.read(p.Value.integer(0));
    try t.expectEqual(read_cache_entries + 2, source.reads);
    try turn.put(p.Value.integer(4), p.Value.integer(-4));
    try t.expectEqual(@as(i64, -4), try (try turn.read(p.Value.integer(4))).?.asInteger());
    var committed_source = turn.committed();
    try t.expectEqual(@as(i64, 4), try (try committed_source.read(p.Value.integer(4))).?.asInteger());
    source.fail = true;
    try t.expectError(error.Unavailable, turn.read(p.Value.integer(100)));
    try t.expectError(error.Unavailable, turn.read(p.Value.integer(4)));
    try t.expectError(error.Unavailable, turn.validate());
    source.fail = false;
    var next = try source.turn(.{});
    next.reader.cache_reads = true;
    _ = try next.read(p.Value.integer(4));
    try t.expectEqual(read_cache_entries + 4, source.reads);
    const oversized: [p.Growth.page_size + 1]p.Value = @splat(p.Value.integer(0));
    try t.expectError(error.MutationBudgetExceeded, next.prefetch(&oversized));
}
