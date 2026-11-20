//! Transactional one-for-one supervisor policy over declared actor KV state and
//! the shared Timer Queue. Preserves `SUC1`/`SUP1` binary codecs, observer
//! origin authentication, `0..16` bounded retries, `0..60_000 ms` Timer Queue
//! backoffs, stop-before-retry generation updates, and conditional `replace`.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Turn = @import("Turn.zig");
const Timer = @import("Timer.zig");
const Observer = @import("Observer.zig");

pub const max_children = 4;

pub const Kind = enum(u8) {
    activation = 1,
    failed = 2,
    suspended = 3,
    terminated = 4,
    expired = 5,
    placement_unavailable = 6,
    initializing = 7,
};

pub const Phase = enum(u8) {
    watching = 1,
    retry_wait = 2,
    retry_requested = 3,
    exhausted = 4,
    retired = 5,
    suspended = 6,
    placement_unavailable = 7,
    initializing = 8,
};

pub const Observation = struct {
    pid: u64,
    generation: u64,
    failure: u64 = 0,
    cut: u64,
    observed_ms: u64,
    kind: Kind,

    pub fn validate(self: Observation) !void {
        if (self.pid == 0) return error.InvalidLifecycleObservation;
        inline for (.{ "pid", "generation", "failure", "cut", "observed_ms" }) |name| {
            if (@field(self, name) > p.max_counter) return error.InvalidLifecycleObservation;
        }
    }

    pub fn encode(self: Observation) ![45]u8 {
        try self.validate();
        var bytes: [45]u8 = undefined;
        bytes[0..4].* = "SUP1".*;
        std.mem.writeInt(u64, bytes[4..12], self.pid, .little);
        std.mem.writeInt(u64, bytes[12..20], self.generation, .little);
        std.mem.writeInt(u64, bytes[20..28], self.failure, .little);
        std.mem.writeInt(u64, bytes[28..36], self.cut, .little);
        std.mem.writeInt(u64, bytes[36..44], self.observed_ms, .little);
        bytes[44] = @backingInt(self.kind);
        return bytes;
    }

    pub fn decode(bytes: []const u8) !Observation {
        if (bytes.len != 45 or !std.mem.eql(u8, bytes[0..4], "SUP1"))
            return error.InvalidLifecycleObservation;
        const result: Observation = .{
            .pid = std.mem.readInt(u64, bytes[4..12], .little),
            .generation = std.mem.readInt(u64, bytes[12..20], .little),
            .failure = std.mem.readInt(u64, bytes[20..28], .little),
            .cut = std.mem.readInt(u64, bytes[28..36], .little),
            .observed_ms = std.mem.readInt(u64, bytes[36..44], .little),
            .kind = std.enums.fromInt(Kind, bytes[44]) orelse return error.InvalidLifecycleObservation,
        };
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

    pub fn encode(self: Child) [75]u8 {
        var bytes: [75]u8 = @splat(0);
        bytes[0..4].* = "SUC1".*;
        std.mem.writeInt(u64, bytes[4..12], self.pid, .little);
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
        std.mem.writeInt(u64, bytes[67..75], self.observer, .little);
        return bytes;
    }

    pub fn decode(bytes: []const u8) !Child {
        if (bytes.len != 75 or !std.mem.eql(u8, bytes[0..4], "SUC1"))
            return error.InvalidChild;
        const successor = std.mem.readInt(u64, bytes[59..67], .little);
        const child: Child = .{
            .pid = std.mem.readInt(u64, bytes[4..12], .little),
            .observer = std.mem.readInt(u64, bytes[67..75], .little),
            .limit = bytes[12],
            .attempts = bytes[13],
            .phase = std.enums.fromInt(Phase, bytes[14]) orelse return error.InvalidChild,
            .backoff_ms = std.mem.readInt(u32, bytes[15..19], .little),
            .generation = std.mem.readInt(u64, bytes[19..27], .little),
            .failure = std.mem.readInt(u64, bytes[27..35], .little),
            .cut = std.mem.readInt(u64, bytes[35..43], .little),
            .observed_ms = std.mem.readInt(u64, bytes[43..51], .little),
            .retry_at_ms = std.mem.readInt(u64, bytes[51..59], .little),
            .successor = if (successor == 0) null else successor,
        };
        if (child.pid == 0 or child.pid > p.max_counter or child.observer == 0 or child.observer > p.max_counter or
            child.limit > 16 or child.attempts > child.limit or child.backoff_ms > 60000)
            return error.InvalidChild;
        inline for (.{ "generation", "failure", "cut", "observed_ms", "retry_at_ms" }) |field| {
            if (@field(child, field) > p.max_counter) return error.InvalidChild;
        }
        if (child.successor) |pid| if (pid > p.max_counter) return error.InvalidChild;
        return child;
    }
};

pub const roster_key = "\x00sc";

pub fn key(pid: u64) [11]u8 {
    var bytes: [11]u8 = undefined;
    bytes[0..2].* = "\x00c".*;
    std.mem.writeInt(u64, bytes[2..10], pid, .little);
    bytes[10] = 0;
    return bytes;
}

const Roster = struct {
    pids: [max_children]u64 = @splat(0),
    len: u8 = 0,

    fn decode(bytes: ?[]const u8) !Roster {
        const raw = bytes orelse return .{};
        if (raw.len < 1 or raw[0] > max_children or raw.len != 1 + @as(usize, raw[0]) * 8)
            return error.InvalidChild;
        var out: Roster = .{ .len = raw[0] };
        for (0..out.len) |idx| {
            const pid = std.mem.readInt(u64, raw[1 + idx * 8 ..][0..8], .little);
            if (pid == 0 or pid > p.max_counter) return error.InvalidChild;
            out.pids[idx] = pid;
        }
        return out;
    }

    fn encodeInto(self: Roster, buf: *[1 + max_children * 8]u8) []const u8 {
        buf[0] = self.len;
        for (0..self.len) |idx| {
            std.mem.writeInt(u64, buf[1 + idx * 8 ..][0..8], self.pids[idx], .little);
        }
        return buf[0 .. 1 + @as(usize, self.len) * 8];
    }
};

pub fn activeRoster(bytes: ?[]const u8) !struct { pids: [max_children]u64, len: u8 } {
    const r = try Roster.decode(bytes);
    return .{ .pids = r.pids, .len = r.len };
}

pub fn get(turn: *Turn, pid: u64) !Child {
    const k = key(pid);
    return Child.decode((try turn.getFramework(&k)) orelse return error.ChildNotFound);
}

pub fn register(turn: *Turn, child: Child) !void {
    _ = try Child.decode(&child.encode());
    if (child.attempts != 0 or child.phase != .watching or child.successor != null)
        return error.InvalidChild;
    const k = key(child.pid);
    if (try turn.getFramework(&k) != null) return error.ChildExists;

    var roster = try Roster.decode(try turn.getFramework(roster_key));
    if (roster.len >= max_children) return error.SupervisorChildCapacity;
    roster.pids[roster.len] = child.pid;
    roster.len += 1;
    var r_buf: [1 + max_children * 8]u8 = undefined;
    try turn.putFramework(roster_key, roster.encodeInto(&r_buf));

    const encoded = child.encode();
    try turn.putFramework(&k, &encoded);
}

/// Replace a permanently retired child against its exact retirement `cut`,
/// preserving the 4-slot active child bound without reviving the old PID.
pub fn replace(turn: *Turn, old_pid: u64, expected_cut: u64, child: Child) !void {
    _ = try Child.decode(&child.encode());
    if (child.attempts != 0 or child.phase != .watching or child.successor != null)
        return error.InvalidChild;
    var old = try get(turn, old_pid);
    if (old.phase != .retired or old.cut != expected_cut or old.successor != null or old_pid == child.pid)
        return error.InvalidReplacement;
    const new_k = key(child.pid);
    if (try turn.getFramework(&new_k) != null) return error.ChildExists;

    var roster = try Roster.decode(try turn.getFramework(roster_key));
    var replaced_in_roster = false;
    for (roster.pids[0..roster.len]) |*slot| {
        if (slot.* == old_pid) {
            slot.* = child.pid;
            replaced_in_roster = true;
            break;
        }
    }
    if (!replaced_in_roster) {
        if (roster.len >= max_children) return error.SupervisorChildCapacity;
        roster.pids[roster.len] = child.pid;
        roster.len += 1;
    }
    var r_buf: [1 + max_children * 8]u8 = undefined;
    try turn.putFramework(roster_key, roster.encodeInto(&r_buf));

    const encoded_new = child.encode();
    try turn.putFramework(&new_k, &encoded_new);
    old.successor = child.pid;
    const old_k = key(old_pid);
    const encoded_old = old.encode();
    try turn.putFramework(&old_k, &encoded_old);
}

pub fn observe(turn: *Turn, observation: Observation) !void {
    try observation.validate();
    var child = try get(turn, observation.pid);
    const env = turn.context.envelope orelse return error.UnexpectedLifecycleObserver;
    const orig = turn.context.origin orelse return error.UnexpectedLifecycleObserver;
    if (env.kind != .cast or orig != .external or orig.external != child.observer)
        return error.UnexpectedLifecycleObserver;

    if (observation.cut < child.cut or observation.generation < child.generation or observation.observed_ms < child.observed_ms)
        return;
    if (child.phase == .retired) return;
    if (child.phase == .exhausted and observation.kind != .terminated and observation.kind != .expired)
        return;
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
                // Stop-before-retry generation bump updates expected_generation without charging another retry.
                const k = key(child.pid);
                const enc = child.encode();
                try turn.putFramework(&k, &enc);
                return;
            }
            if (child.attempts >= child.limit) {
                child.phase = .exhausted;
            } else {
                const newly_waiting = child.phase != .retry_wait or child.failure != observation.failure;
                if (newly_waiting) {
                    child.retry_at_ms = try std.math.add(u64, observation.observed_ms, child.backoff_ms);
                }
                child.failure = observation.failure;
                child.phase = .retry_wait;
                if (observation.observed_ms >= child.retry_at_ms) {
                    child.attempts += 1;
                    child.phase = .retry_requested;
                } else if (newly_waiting) {
                    try turn.scheduleSupervisorBackoff(
                        child.pid,
                        observation.generation,
                        observation.failure,
                        child.retry_at_ms,
                        child.observer,
                    );
                }
            }
        },
    }
    const k = key(child.pid);
    const enc = child.encode();
    try turn.putFramework(&k, &enc);
}

pub fn handle(turn: *Turn) !void {
    try observe(turn, try Observation.decode(turn.input));
}

/// Standard `Observer.BackoffBuilder` implementation: inspects the supervised
/// child's native process state on wakeup and emits a due `SUP1` observation.
pub const BackoffResponder = struct {
    process_view: Observer.ProcessView,

    pub fn builder(self: *BackoffResponder) Observer.BackoffBuilder {
        return .{ .context = self, .build = buildObservation };
    }

    fn buildObservation(
        raw: *anyopaque,
        allocator: std.mem.Allocator,
        ticket: Timer.Ticket,
        _: Observer.ProcessState,
        proven_ms: u64,
    ) !?[]const u8 {
        const self: *BackoffResponder = @ptrCast(@alignCast(raw));
        const child_pid = ticket.child_pid orelse return error.InvalidTimerTicket;
        const child_proc = try self.process_view.inspect(self.process_view.context, child_pid);
        if (child_proc.pid != child_pid) return error.InvalidAuthorityResponse;
        const kind: Kind = if (child_proc.lifecycle == .terminated)
            .terminated
        else if (child_proc.lifecycle == .expired)
            .expired
        else if (child_proc.generation == ticket.generation)
            .failed
        else if (child_proc.failure != null)
            .failed
        else
            .activation;
        const failure: u64 = switch (kind) {
            .failed => if (child_proc.generation == ticket.generation) ticket.failure else (child_proc.failure orelse ticket.failure),
            else => 0,
        };
        const obs: Observation = .{
            .pid = child_pid,
            .generation = child_proc.generation,
            .failure = failure,
            .cut = child_proc.position,
            .observed_ms = proven_ms,
            .kind = kind,
        };
        const encoded = try obs.encode();
        return try allocator.dupe(u8, &encoded);
    }
};

test "private transactional supervisor enforces observer origin, Timer Queue backoff, stop-before-retry, exhaustion and retirement replace" {
    const t = std.testing;
    var kv_map: std.StringHashMapUnmanaged([]u8) = .empty;
    defer {
        var it = kv_map.iterator();
        while (it.next()) |entry| {
            t.allocator.free(entry.key_ptr.*);
            t.allocator.free(entry.value_ptr.*);
        }
        kv_map.deinit(t.allocator);
    }

    const MapReader = struct {
        map: *std.StringHashMapUnmanaged([]u8),
        fn get(raw: *anyopaque, alloc: std.mem.Allocator, k: []const u8) !?[]const u8 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const v = self.map.get(k) orelse return null;
            return try alloc.dupe(u8, v);
        }
        fn row(_: *anyopaque, _: []const c.fuze.Types.Values.Cell) !?Turn.Row {
            return null;
        }
        fn table(_: *anyopaque, _: Turn.Table) !void {}
        fn applyDraft(self: *@This(), alloc: std.mem.Allocator, draft: Turn.Draft) !void {
            for (draft.puts) |put| {
                const k = try put.key.decode(alloc, 256);
                defer alloc.free(k);
                if (put.value) |val| {
                    const v = try val.decode(alloc, 4096);
                    defer alloc.free(v);
                    if (self.map.fetchRemove(k)) |old| {
                        alloc.free(old.key);
                        alloc.free(old.value);
                    }
                    try self.map.put(alloc, try alloc.dupe(u8, k), try alloc.dupe(u8, v));
                }
            }
        }
    };

    var reader_ctx: MapReader = .{ .map = &kv_map };
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const inbox: p.StreamQueue.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 20 }, .revision = 1, .digest = @splat(2) },
        .partition = 0,
    };
    const timers: p.StreamQueue.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 21 }, .revision = 1, .digest = @splat(3) },
        .partition = 0,
    };
    const source: p.StreamQueue.RecordIdentity = .{
        .target = inbox,
        .operation = .{ .scope = scope, .principal = 109, .operation = 1 },
        .ordinal = 0,
    };

    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();

    // Register child 8 (limit = 1, backoff_ms = 50, observer = 109).
    var t1 = try Turn.initWithContext(arena.allocator(), .{}, .{ .context = &reader_ctx, .get = MapReader.get, .row = MapReader.row, .table = MapReader.table }, source, "", .{
        .turn_id = 1,
        .actor_pid = 4,
        .inbox = inbox,
        .timers = timers,
        .envelope = .{ .kind = .cast, .payload = "" },
        .origin = .{ .external = 109 },
    });
    try register(&t1, .{ .pid = 8, .observer = 109, .limit = 1, .backoff_ms = 50 });

    // Failure at t=100 schedules Timer Queue backoff ticket at visible_ms = 150.
    try observe(&t1, .{ .pid = 8, .generation = 1, .failure = 3, .cut = 10, .observed_ms = 100, .kind = .failed });
    const after_fail = try get(&t1, 8);
    try t.expectEqual(Phase.retry_wait, after_fail.phase);
    try t.expectEqual(@as(u64, 150), after_fail.retry_at_ms);
    const d1 = try t1.finish();
    try t.expectEqual(@as(usize, 1), d1.messages.len);
    try t.expectEqual(@as(u64, 150), d1.messages[0].visible_ms);
    try reader_ctx.applyDraft(t.allocator, d1);

    // Forged actor origin for SUP1 is rejected.
    var forged_turn = try Turn.initWithContext(arena.allocator(), .{}, .{ .context = &reader_ctx, .get = MapReader.get, .row = MapReader.row, .table = MapReader.table }, source, "", .{
        .turn_id = 2,
        .actor_pid = 4,
        .inbox = inbox,
        .timers = timers,
        .envelope = .{ .kind = .cast, .payload = "" },
        .origin = .{ .actor = .{ .realm = 1, .pid = 99, .principal = 109, .generation = 1, .code = 1, .workload = null, .transaction = source.operation } },
    });
    try t.expectError(error.UnexpectedLifecycleObserver, observe(&forged_turn, .{ .pid = 8, .generation = 1, .failure = 3, .cut = 11, .observed_ms = 160, .kind = .failed }));

    // Due observation at t=150 transitions to retry_requested (attempts = 1); stop-before-retry generation bump updates generation without charging a 2nd attempt.
    var t2 = try Turn.initWithContext(arena.allocator(), .{}, .{ .context = &reader_ctx, .get = MapReader.get, .row = MapReader.row, .table = MapReader.table }, source, "", .{
        .turn_id = 3,
        .actor_pid = 4,
        .inbox = inbox,
        .timers = timers,
        .envelope = .{ .kind = .cast, .payload = "" },
        .origin = .{ .external = 109 },
    });
    try observe(&t2, .{ .pid = 8, .generation = 1, .failure = 3, .cut = 10, .observed_ms = 150, .kind = .failed });
    try t.expectEqual(Phase.retry_requested, (try get(&t2, 8)).phase);
    try t.expectEqual(@as(u8, 1), (try get(&t2, 8)).attempts);

    // Stop-before-retry intermediate generation bump (gen 2, same failure 3).
    try observe(&t2, .{ .pid = 8, .generation = 2, .failure = 3, .cut = 11, .observed_ms = 155, .kind = .failed });
    try t.expectEqual(Phase.retry_requested, (try get(&t2, 8)).phase);
    try t.expectEqual(@as(u64, 2), (try get(&t2, 8)).generation);
    try t.expectEqual(@as(u8, 1), (try get(&t2, 8)).attempts);
    try reader_ctx.applyDraft(t.allocator, try t2.finish());

    var t3 = try Turn.initWithContext(arena.allocator(), .{}, .{ .context = &reader_ctx, .get = MapReader.get, .row = MapReader.row, .table = MapReader.table }, source, "", .{
        .turn_id = 4,
        .actor_pid = 4,
        .inbox = inbox,
        .timers = timers,
        .envelope = .{ .kind = .cast, .payload = "" },
        .origin = .{ .external = 109 },
    });
    // Activation at gen 3 followed by second failure exhausts retry limit.
    try observe(&t3, .{ .pid = 8, .generation = 3, .failure = 0, .cut = 12, .observed_ms = 160, .kind = .activation });
    try observe(&t3, .{ .pid = 8, .generation = 3, .failure = 4, .cut = 13, .observed_ms = 170, .kind = .failed });
    try t.expectEqual(Phase.exhausted, (try get(&t3, 8)).phase);

    // Expiry transitions to retired; conditional replace binds successor PID 12.
    try observe(&t3, .{ .pid = 8, .generation = 3, .failure = 0, .cut = 14, .observed_ms = 180, .kind = .expired });
    try t.expectEqual(Phase.retired, (try get(&t3, 8)).phase);
    try replace(&t3, 8, 14, .{ .pid = 12, .observer = 109, .limit = 2, .backoff_ms = 0 });
    try t.expectEqual(@as(?u64, 12), (try get(&t3, 8)).successor);
    try t.expectEqual(Phase.watching, (try get(&t3, 12)).phase);
}
