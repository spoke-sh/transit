//! One consumer, many producers. Notifications arriving during a bounded sweep
//! remain outstanding until a subsequent sweep covers them. Durable discovery,
//! not this volatile signal, recovers accepted work after process replacement.
const std = @import("std");
const Self = @This();
mutex: std.Io.Mutex = .init,
condition: std.Io.Condition = .init,
state: State = .{},

pub const State = struct {
    requested: u64 = 1,
    completed: u64 = 0,
    retry: bool = false,

    pub fn notify(self: *State) void {
        self.requested +%= 1;
    }
    pub fn begin(self: State) ?u64 {
        return if (self.requested != self.completed or self.retry) self.requested else null;
    }
    pub fn finish(self: *State, generation: u64, retry: bool) void {
        self.completed = generation;
        self.retry = retry;
    }
};

pub fn notify(self: *Self, io: std.Io) void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    self.state.notify();
    self.condition.broadcast(io);
}
pub fn begin(self: *Self, io: std.Io) ?u64 {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    return self.state.begin();
}
pub fn finish(self: *Self, io: std.Io, generation: u64, retry: bool) void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    self.state.finish(generation, retry);
}
/// Only unresolved work has a retry timer. New work wakes immediately, including
/// a notification between the last sweep observation and entering this wait.
pub fn wait(self: *Self, io: std.Io, retry_ms: u32) !void {
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    while (self.state.requested == self.state.completed) {
        if (self.state.retry) {
            self.condition.waitTimeout(io, &self.mutex, .{ .duration = .{ .raw = .fromMilliseconds(retry_ms), .clock = .awake } }) catch |err| switch (err) {
                error.Timeout => return,
                else => return err,
            };
            return;
        }
        try self.condition.wait(io, &self.mutex);
    }
}

test "notifications at every sweep boundary preserve an obligation" {
    const t = std.testing;
    // Exhaust the placements of two producer events around discovery, terminal
    // settlement and parking. The oracle is the latest producer event covered
    // by discovery; finishing an earlier sweep must not consume a later event.
    for (0..4) |first| for (first..4) |second| {
        var state: State = .{};
        var events: usize = 0;
        if (first == 0) {
            state.notify();
            events += 1;
        }
        if (second == 0) {
            state.notify();
            events += 1;
        }
        const covered = events;
        const generation = state.begin().?;
        for (1..3) |boundary| {
            if (first == boundary) {
                state.notify();
                events += 1;
            }
            if (second == boundary) {
                state.notify();
                events += 1;
            }
        }
        state.finish(generation, false);
        if (first == 3) {
            state.notify();
            events += 1;
        }
        if (second == 3) {
            state.notify();
            events += 1;
        }
        try t.expectEqual(events > covered, state.begin() != null);
        if (state.begin()) |next| state.finish(next, false);
        try t.expectEqual(@as(?u64, null), state.begin());
    };
}

test "failed or incomplete discovery cannot establish quiescence" {
    const t = std.testing;
    var state: State = .{};
    state.finish(state.begin().?, true);
    try t.expect(state.begin() != null);
    const retry = state.begin().?;
    state.notify();
    state.finish(retry, false);
    try t.expect(state.begin() != null);
    state.finish(state.begin().?, false);
    try t.expectEqual(@as(?u64, null), state.begin());
    // Process replacement always requires discovery, even when no volatile
    // producer notification survived the crash.
    state = .{};
    try t.expect(state.begin() != null);
}

test "park is cancellable and a notification before waiting needs no timer" {
    const t = std.testing;
    var work: Self = .{};
    work.finish(t.io, work.begin(t.io).?, false);
    const Wait = struct {
        fn run(value: *Self, io: std.Io) !void {
            try value.wait(io, 1);
            return error.IdleWorkerWokeWithoutWork;
        }
    };
    var task = try t.io.concurrent(Wait.run, .{ &work, t.io });
    if (task.cancel(t.io)) |_| return error.CancellationMissing else |err| try t.expect(err == error.Canceled or err == error.Cancelled);
    work.notify(t.io);
    try work.wait(t.io, 60000);
    try t.expect(work.begin(t.io) != null);
}
