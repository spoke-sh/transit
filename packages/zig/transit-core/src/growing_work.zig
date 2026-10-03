//! Bounded delivery/settlement transitions. Terminal process facts fence work
//! immediately; individual dispositions materialize without scanning a backlog.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const growth = @import("growing.zig");
const state = @import("growing_state.zig");
const c = @import("catalog.zig");
const address = growth.address;

pub fn output(engine: anytype, id: u64) !g.Outbox {
    var current = try engine.state();
    return (try current.get(g.Outbox, address(.output, id))) orelse error.UnknownOutput;
}
pub fn effect(engine: anytype, id: u64) !g.Effect {
    var current = try engine.state();
    const value = (try current.get(g.Effect, address(.effect, id))) orelse return error.UnknownEffect;
    g.validateEffect(value, engine.head.position) catch return error.InvalidHistory;
    return value;
}
pub fn routeKey(source: u64, destination: u64, id: u64) core.pages.Key {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, id, .big);
    return c.key(.pending_route, source, destination, &bytes) catch unreachable;
}

/// A positive result proves terminal lifetime, not transient failure or lag.
fn terminal(engine: anytype, process: g.Process, now: ?core.Time.Sample) !bool {
    if (process.lifecycle != .running) return true;
    if (process.settle_before_ms) |deadline| engine.before(now, deadline) catch |err| {
        if (err == error.DeadlineExpired) return true;
        return err;
    };
    state.dependencies(engine, process.pid, now) catch |err| {
        if (err == error.StateResourceExpired) return true;
        return err;
    };
    return false;
}
pub fn expired(engine: anytype, process: g.Process, now: ?core.Time.Sample) !void {
    if (try terminal(engine, process, now)) return;
    if (process.settle_before_ms != null) return error.DeadlineNotReached;
    return error.NoDeadline;
}
fn admit(candidate: anytype, process: *g.Process, position: u64, value: p.Value, origin: g.Origin) !void {
    if (process.admitted >= p.max_counter) return error.Overflow;
    process.admitted += 1;
    try candidate.put(try c.key(.mailbox, process.pid, process.admitted, ""), g.Input{ .position = position, .ordinal = process.admitted, .value = value, .origin = origin });
    try candidate.put(address(.process, process.pid), process.*);
}

/// Prepare delivery records without staging them. The engine combines these
/// with the caller sequence and receipt in one existing eight-key batch.
pub fn prepareDelivery(engine: anytype, candidate: anytype, request: g.Request, now: ?core.Time.Sample, mutations: *[6]core.pages.Mutation) anyerror!usize {
    const id = request.command.deliver;
    const position = engine.head.position;
    const caller = try engine.principal(request.principal);
    var out = try output(engine, id);
    if (out.phase != .pending) return error.OutputAlreadyResolved;
    const route = try candidate.scan(u64, .{ .namespace = .pending_route, .major = out.source, .minor = out.destination }, null);
    const first = route.records[0] orelse return error.InvalidHistory;
    if (first.value != id) return error.RouteBlocked;
    const source = try engine.process(out.source);
    var destination = try engine.process(out.destination);
    out.courier = request.principal;
    out.policy_revision = caller.revision;
    out.phase = if (try terminal(engine, source, now)) .cancelled else if (caller.grant.permissions & p.permission(.send) == 0) .denied else if (destination.lifecycle == .terminated) .retired else if (try terminal(engine, destination, now)) .expired else .delivered;
    if (out.phase == .delivered) if (destination.work_before_ms) |deadline| engine.before(now, deadline) catch |err| {
        if (err == error.DeadlineExpired) out.phase = .expired else return err;
    };
    out.resolved_at = position;
    mutations[0] = try c.putMutation(address(.output, id), out);
    mutations[1] = .{ .key = address(.pending_output, id), .value = null };
    mutations[2] = .{ .key = try c.key(.pending_destination, out.destination, id, ""), .value = null };
    mutations[3] = .{ .key = routeKey(out.source, out.destination, id), .value = null };
    var count: usize = 4;
    if (out.phase == .delivered) {
        if (destination.admitted >= p.max_counter) return error.Overflow;
        destination.admitted += 1;
        mutations[4] = try c.putMutation(try c.key(.mailbox, destination.pid, destination.admitted, ""), g.Input{
            .position = position,
            .ordinal = destination.admitted,
            .value = out.value,
            .origin = .{ .process = .{ .pid = out.source, .turn = out.turn, .output = out.id } },
        });
        mutations[5] = try c.putMutation(address(.process, destination.pid), destination);
        count = 6;
    }
    return count;
}

pub fn apply(engine: anytype, candidate: anytype, request: g.Request, now: ?core.Time.Sample) anyerror!void {
    const position = engine.head.position;
    const caller = try engine.principal(request.principal);
    switch (request.command) {
        .dispatch => |command| {
            var value = try effect(engine, command.effect);
            if (value.pid != command.pid) return error.InvalidEffect;
            const process = try engine.process(command.pid);
            try engine.executable(process, now, false);
            if (value.phase != .pending) return error.AttemptAlreadyAuthorized;
            if (command.max_observations == 0 or command.max_observations > p.max_effect_observations) return error.InvalidBudget;
            if (process.work_before_ms != null and command.reconcile_before_ms == null) return error.InvalidLifetime;
            if (command.reconcile_before_ms) |deadline| try engine.before(now, deadline);
            value.phase = .authorized;
            value.attempt = position;
            value.executor = request.principal;
            value.authorization_policy = caller.revision;
            value.reconcile_before_ms = command.reconcile_before_ms;
            value.max_observations = command.max_observations;
            try candidate.put(address(.effect, value.id), value);
        },
        .observe => |command| {
            var value = try effect(engine, command.effect);
            if (value.pid != command.pid or value.attempt != command.attempt or value.executor != request.principal) return error.InvalidAttempt;
            if (value.phase != .authorized and value.phase != .unknown) return error.ReconciliationClosed;
            if (value.reconcile_before_ms) |deadline| try engine.before(now, deadline);
            if (value.observations >= value.max_observations) return error.InvalidHistory;
            value.observations += 1;
            value.last_observation = .{ .input = position, .policy_revision = caller.revision };
            value.result = command.result;
            value.phase = if (command.result != null) .observed else if (value.observations == value.max_observations) .closed_unknown else .unknown;
            if (value.phase == .observed or value.phase == .closed_unknown) {
                value.closed_at = position;
                value.closure = .{ .reason = if (value.phase == .observed) .observed else .observation_budget, .principal = request.principal, .policy_revision = caller.revision };
                try candidate.remove(address(.pending_effect, value.id));
            }
            if (command.result) |result| {
                var process = try engine.process(command.pid);
                // A late connector result remains evidence. It cannot revive
                // a retired caller or create fresh work after its cutoff.
                var accepts = !try terminal(engine, process, now);
                if (accepts) if (process.work_before_ms) |deadline| {
                    accepts = (now orelse return error.ClockUnavailable).upper() < deadline;
                };
                if (accepts) try admit(candidate, &process, position, result, .{ .effect = .{ .id = value.id, .attempt = command.attempt, .executor = request.principal } });
            }
            try candidate.put(address(.effect, value.id), value);
        },
        .close_effect => |command| {
            var value = try effect(engine, command.effect);
            if (value.pid != command.pid or value.attempt != command.attempt) return error.InvalidAttempt;
            if (value.executor != request.principal and caller.grant.permissions & p.permission(.admin) == 0) return error.Forbidden;
            if (value.phase != .authorized and value.phase != .unknown) return error.ReconciliationClosed;
            if (command.reason == .deadline) try (now orelse return error.ClockUnavailable).after(value.reconcile_before_ms orelse return error.NoDeadline);
            value.phase = .closed_unknown;
            value.closed_at = position;
            value.closure = .{ .reason = if (command.reason == .deadline) .deadline else .abandoned, .principal = request.principal, .policy_revision = caller.revision, .clock_lower_ms = if (command.reason == .deadline) now.?.lower() else null };
            try candidate.put(address(.effect, value.id), value);
            try candidate.remove(address(.pending_effect, value.id));
        },
        .cancel_effect => |command| {
            var value = try effect(engine, command.effect);
            if (value.pid != command.pid) return error.InvalidEffect;
            if (value.phase != .pending) return error.AttemptAlreadyAuthorized;
            if (!try terminal(engine, try engine.process(command.pid), now)) return error.PendingWork;
            value.phase = .cancelled;
            value.closed_at = position;
            value.closure = .{ .reason = .unattempted_cancel, .principal = request.principal, .policy_revision = caller.revision };
            try candidate.put(address(.effect, value.id), value);
            try candidate.remove(address(.pending_effect, value.id));
        },
        else => return error.UnsupportedGrowthCommand,
    }
}
