//! Bounded, disposable scan cursors. Suggestions have no authority: the caller
//! signs each operation and the engine validates it again before publication.
const std = @import("std");
const core = @import("root.zig");
const g = core.protocol.Growth;
const work = @import("growing_work.zig");
const c = @import("catalog.zig");
const Self = @This();
const Family = enum { processes, resources, effects, outputs };
const Cursor = struct { after: ?core.pages.Key = null, through: ?u64 = null };

family: Family = .processes,
cursors: [4]Cursor = @splat(.{}),

fn sampled(engine: anytype, clock: anyerror!?core.Time.Sample) !?core.Time.Sample {
    const value = try clock;
    if (value) |now| try engine.validateTime(now);
    return value;
}
fn processDue(engine: anytype, process: g.Process, clock: anyerror!?core.Time.Sample) !bool {
    if (process.lifecycle != .running) return false;
    // Recorded dependency retirement needs no healthy clock. Sample only if
    // the actual dependency/settlement contract needs time to establish expiry.
    work.expired(engine, process, null) catch |err| switch (err) {
        error.ClockUnavailable => {
            work.expired(engine, process, try sampled(engine, clock)) catch |later| switch (later) {
                error.NoDeadline, error.DeadlineNotReached, error.DeadlineUncertain => return false,
                else => return later,
            };
            return true;
        },
        error.NoDeadline, error.DeadlineNotReached, error.DeadlineUncertain => return false,
        else => return err,
    };
    return true;
}

/// Inspect at most one record from one bounded page per call. Rotate families
/// even on error, and cap each pass at its initial identity frontier: continuous
/// admission cannot indefinitely postpone revisiting an earlier failed item.
/// Dependency validation retains the genesis graph/edge budgets.
pub fn next(self: *Self, engine: anytype, clock: anyerror!?core.Time.Sample) !?g.Command {
    const family = self.family;
    self.family = @fromBackingInt(@intCast((@as(usize, @backingInt(family)) + 1) % self.cursors.len));
    const cursor = &self.cursors[@backingInt(family)];
    if (cursor.through == null) cursor.through = if (family == .outputs) engine.head.outputs else engine.head.position - 1;
    var current = try engine.state();
    const namespace: c.Namespace = switch (family) {
        .processes => .process,
        .resources => .resource,
        .effects => .pending_effect,
        .outputs => .pending_output,
    };
    switch (family) {
        inline else => |kind| {
            const T = switch (kind) {
                .processes => g.Process,
                .resources => g.Resource,
                .effects, .outputs => u64,
            };
            const batch = try current.scan(T, .{ .namespace = namespace }, cursor.after);
            const record = batch.records[0] orelse {
                cursor.* = .{};
                return null;
            };
            const id = std.mem.readInt(u64, record.key.data[1..9], .big);
            if (id > cursor.through.?) {
                cursor.* = .{};
                return null;
            }
            // Advance before validating this item. A blocked/erroring item must
            // not starve the rest; it is revisited on the next finite pass.
            cursor.after = record.key;
            switch (kind) {
                .processes => if (try processDue(engine, record.value, clock)) return .{ .expire = id },
                .resources => {
                    const resource = record.value;
                    if (resource.phase != .active) return null;
                    if (resource.owner) |pid| if ((try engine.process(pid)).lifecycle != .running) {
                        const users = try current.scan(u64, .{ .namespace = .required_resource_users, .major = id }, null);
                        if (users.records[0] == null) return .{ .retire_resource = id };
                    };
                    if (resource.deadline_ms) |deadline| {
                        const now = (try sampled(engine, clock)) orelse return error.ClockUnavailable;
                        now.after(deadline) catch |err| {
                            if (err == error.DeadlineNotReached) return null;
                            return err;
                        };
                        return .{ .expire_resource = id };
                    }
                },
                .effects => {
                    const value = try work.effect(engine, id);
                    if (value.phase == .pending) {
                        if ((try engine.process(value.pid)).lifecycle != .running) return .{ .cancel_effect = .{ .pid = value.pid, .effect = id } };
                    } else if (value.phase == .authorized or value.phase == .unknown) {
                        if (value.reconcile_before_ms) |deadline| {
                            const now = (try sampled(engine, clock)) orelse return error.ClockUnavailable;
                            now.after(deadline) catch |err| {
                                if (err == error.DeadlineNotReached) return null;
                                return err;
                            };
                            return .{ .close_effect = .{ .pid = value.pid, .effect = id, .attempt = value.attempt orelse return error.InvalidHistory, .reason = .deadline } };
                        }
                    } else return error.InvalidHistory;
                },
                .outputs => {
                    const value = try work.output(engine, id);
                    if (value.phase != .pending) return error.InvalidHistory;
                    // Maintenance only materializes terminal-source cancellation.
                    // Ordinary delivery remains a separately authorized courier.
                    if ((try engine.process(value.source)).lifecycle != .running) {
                        const route = try current.scan(u64, .{ .namespace = .pending_route, .major = value.source, .minor = value.destination }, null);
                        if ((route.records[0] orelse return error.InvalidHistory).value == id) return .{ .deliver = id };
                    }
                },
            }
        },
    }
    return null;
}
