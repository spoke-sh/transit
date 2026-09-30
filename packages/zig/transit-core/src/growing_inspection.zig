//! Authenticated native inspection; bounded projections never expose control records.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const i = g.Inspection;
const growth = @import("growing.zig");
const c = @import("catalog.zig");
const address = growth.address;
fn allowed(grant: g.Grant, pid: u64) bool {
    return grant.pid == null or grant.pid == pid;
}
fn admission(process: g.Process, input: g.Input, policy: u64) i.Event {
    return .{ .position = input.position, .pid = process.pid, .kind = switch (input.origin) {
        .external => .send,
        .process => .deliver,
        .effect => .observe,
    }, .policy_revision = policy, .value = input.value, .admitted = true, .mailbox_status = if (input.ordinal <= process.consumed) .consumed else if (process.lifecycle != .running) .cancelled else .pending };
}
fn event(engine: anytype, record: growth.Record, grant: g.Grant, process: g.Process) !?i.Event {
    var basis = try engine.state();
    basis.snapshot = record.next.catalog;
    const command = record.request.command;
    const out: ?g.Outbox = if (command == .deliver) (try basis.get(g.Outbox, address(.output, command.deliver))) orelse return error.InvalidHistory else null;
    const pid = switch (command) {
        .spawn, .create => record.position,
        .deliver => out.?.destination,
        else => g.commandPid(command) orelse return null,
    };
    if (pid != process.pid) return null;
    const caller = (try basis.get(growth.Principal, address(.principal, record.request.principal))) orelse return error.InvalidHistory;
    var result: i.Event = .{ .pid = pid, .position = record.position, .kind = command, .policy_revision = caller.revision };
    if (record.time) |time| {
        result.unix_ms = time.unix_ms;
        result.clock_error_ms = time.error_ms;
    }
    switch (command) {
        .send, .deliver, .observe => {
            const after = (try basis.get(g.Process, address(.process, pid))) orelse return error.InvalidHistory;
            if (after.admitted != 0) if (try basis.get(g.Input, try c.key(.mailbox, pid, after.admitted, ""))) |input| {
                if (input.position == record.position) {
                    const value = admission(process, input, caller.revision);
                    result.admitted = true;
                    result.value = value.value;
                    result.mailbox_status = value.mailbox_status;
                }
            };
            if (out) |value| if (allowed(grant, value.source)) {
                result.output = value.id;
            };
            if (command == .observe) result.effect = command.observe.effect;
        },
        .turn, .turn_with_versions => {
            const turn = if (command == .turn) command.turn else command.turn_with_versions.turn;
            result.kind = .turn;
            result.input = turn.input;
            result.failed = turn.failed;
            if (turn.effect != null) result.effect = record.position;
        },
        .begin_turn => |v| result.input = v.input,
        inline .own, .activate => |v| result.generation = v.expected_generation + 1,
        inline .dispatch, .close_effect, .cancel_effect => |v| result.effect = v.effect,
        else => {},
    }
    return result;
}
pub fn read(engine: anytype, principal: growth.Principal, q: i.Query) !i.Page {
    try i.validate(q);
    if (q.pid) |pid| if (!allowed(principal.grant, pid)) return error.Forbidden;
    const cut: i.Cut = .{ .position = engine.head.position, .policy_revision = principal.revision, .retained_from = engine.head.history_floor };
    if (q.cut) |previous| {
        if (previous.retained_from < cut.retained_from) return error.HistoryReclaimed;
        if (!std.meta.eql(previous, cut)) return error.QueryExpired;
    }
    const process = if (q.pid) |pid| try engine.process(pid) else null;
    var result: i.Page = .{ .realm = engine.genesis.realm, .resource = q.resource, .pid = q.pid, .cut = cut, .reader = .{ .principal = principal.grant.subject, .permissions = principal.grant.permissions, .pid = principal.grant.pid, .policy_revision = principal.revision }, .last_collection = engine.head.last_collection, .history = if (cut.retained_from > 1) .prefix_reclaimed else .retained };
    var current = try engine.state();
    var count: usize = 0;
    switch (q.resource) {
        .process => {
            result.processes[0] = process;
            result.scanned = 1;
        },
        .processes => {
            if (principal.grant.pid) |pid| {
                if (q.after == 0) result.processes[0] = try engine.process(pid);
                result.scanned = 1;
            } else {
                const page = try current.scan(g.Process, .{ .namespace = .process }, if (q.after == 0) null else address(.process, q.after));
                for (page.records, 0..) |slot, n| if (slot) |r| {
                    result.processes[n] = r.value;
                    result.scanned += 1;
                };
                if (page.next) |next| result.next = std.mem.readInt(u64, next.data[1..9], .big);
            }
        },
        .outbox => {
            const page = try current.scan(g.Outbox, .{ .namespace = .output }, if (q.after == 0) null else address(.output, q.after));
            for (page.records) |slot| if (slot) |r| {
                result.scanned += 1;
                if (r.value.source == q.pid and allowed(principal.grant, r.value.destination)) {
                    result.outbox[count] = r.value;
                    count += 1;
                }
            };
            if (page.next) |next| result.next = std.mem.readInt(u64, next.data[1..9], .big);
        },
        .effects, .payloads => {
            const ns: c.Namespace = if (q.resource == .effects) .effects_by_pid else .payloads_by_pid;
            const page = try current.scan(u64, .{ .namespace = ns, .major = q.pid.? }, if (q.after == 0) null else try c.key(ns, q.pid.?, q.after, ""));
            for (page.records, 0..) |slot, n| if (slot) |r| {
                result.scanned += 1;
                if (q.resource == .effects) result.effects[n] = try @import("growing_work.zig").effect(engine, r.value) else result.payloads[n] = try @import("growing_payload.zig").get(engine, .{ .pid = q.pid.?, .payload = r.value });
            };
            if (page.next) |next| result.next = std.mem.readInt(u64, next.data[9..17], .big);
        },
        .mailbox => {
            const page = try current.scan(g.Input, .{ .namespace = .mailbox, .major = q.pid.? }, if (q.after == 0) null else try c.key(.mailbox, q.pid.?, q.after, ""));
            for (page.records, 0..) |slot, n| if (slot) |r| {
                const input = r.value;
                result.scanned += 1;
                result.events[n] = admission(process.?, input, if (input.origin == .external) input.origin.external.policy_revision else 0);
                if (input.origin == .process and allowed(principal.grant, input.origin.process.pid)) result.events[n].?.output = input.origin.process.output;
                if (input.origin == .effect) result.events[n].?.effect = input.origin.effect.id;
            };
            if (page.next) |next| result.next = std.mem.readInt(u64, next.data[9..17], .big);
        },
        .history => {
            if (q.after > cut.position) return error.InvalidRead;
            var at = @max(@max(1, cut.retained_from), q.after);
            while (at < cut.position and count < i.page_size and result.scanned < i.scan_limit) : (at += 1) {
                result.scanned += 1;
                const entry = (try engine.journal.read(at)) orelse return error.IncompleteHistory;
                if (entry != .operation) return error.InvalidHistory;
                if (try event(engine, entry.operation, principal.grant, process.?)) |value| {
                    result.events[count] = value;
                    count += 1;
                }
            }
            if (at < cut.position) result.next = at;
        },
    }
    result.complete = result.next == null;
    return result; // Caller rechecks authority tail before disclosure.
}
