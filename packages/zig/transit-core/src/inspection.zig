//! The authority's filtered read projection. Never expose raw control records.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const i = p.Inspection;

fn allowed(grant: p.Grant, pid: u64) bool {
    return grant.pid == null or grant.pid == pid;
}
fn processView(process: core.Process) p.ProcessView {
    var view: p.ProcessView = undefined;
    inline for (@typeInfo(p.ProcessView).@"struct".field_names) |name| @field(view, name) = @field(process, name);
    return view;
}
fn event(state: *core.State, record: core.Record, grant: p.Grant, pid: u64) !?i.Event {
    const command = record.request.command;
    const subject: ?u64 = switch (command) {
        .grant, .revoke, .checkpoint, .inspect => null,
        .lifecycle => |c| if (c == .create) record.position else p.Lifecycle.pid(c),
        .state => |c| if (c == .turn) c.turn.turn.pid else null,
        .deliver_next => if (record.delivery) |ref| ref.destination else null,
        .spawn => record.position,
        .terminate, .expire => |id| id,
        inline else => |c| c.pid,
    };
    if (subject != pid) return null;
    var result: i.Event = .{ .pid = pid, .position = record.position, .kind = command, .policy_revision = record.policy_revision };
    if (record.time) |sample| {
        result.unix_ms = sample.unix_ms;
        result.clock_error_ms = sample.error_ms;
    }
    if (record.admission) |admission| {
        result.admitted = admission.pid == pid;
        if (result.admitted) {
            result.value = admission.value;
            const process = try state.process(pid);
            result.mailbox_status = if (record.position <= process.input_cursor) .consumed else if (process.lifecycle != .running) .cancelled else .pending;
        }
    }
    switch (command) {
        .state => |c| if (c == .turn) {
            // A normal turn projection, with no resource IDs, keys or values.
            // Resource metadata separately discloses its committing position.
            result.kind = .turn;
            result.input = c.turn.turn.input;
            result.failed = c.turn.turn.failed;
            if (c.turn.turn.effect != null) result.effect = record.position;
        },
        inline .own, .activate => |c| result.generation = c.expected_generation + 1,
        .spawn => |c| result.value = c.initial_state,
        .begin_turn => |c| result.input = c.input,
        .turn => |c| {
            result.input = c.input;
            result.value = c.result;
            result.failed = c.failed;
            if (c.effect != null) result.effect = record.position;
        },
        inline .dispatch, .observe, .close_effect => |c| result.effect = c.effect,
        .deliver, .deliver_next => {
            if (record.delivery) |ref| {
                if (allowed(grant, ref.source)) result.output = ref.id;
            } else if (command == .deliver) {
                const output = state.output(command.deliver.output) catch return result;
                if (allowed(grant, output.source)) result.output = output.id;
            }
        },
        else => {},
    }
    return result;
}

pub fn read(engine: anytype, signed: i.SignedQuery) !i.Page {
    try engine.refresh();
    const state = &engine.state;
    const q = signed.query;
    // Authentication precedes parameter/existence errors and pagination checks.
    if (q.realm != state.realm) return error.Unauthorized;
    const principal = state.principal(q.principal) catch return error.Unauthorized;
    const key = p.Ed25519.PublicKey.fromBytes(principal.grant.public_key) catch return error.Unauthorized;
    p.Ed25519.Signature.fromBytes(signed.signature).verify(&i.digest(q), key) catch return error.Unauthorized;
    if (principal.grant.permissions & p.permission(.inspect) == 0) return error.Forbidden;
    if (q.pid) |pid| if (!allowed(principal.grant, pid)) return error.Forbidden;
    try i.validate(q);
    if (q.pid) |pid| _ = try state.process(pid);
    const cut: i.Cut = .{ .position = state.position, .policy_revision = principal.revision, .retained_from = state.history_floor };
    if (q.cut) |previous| {
        if (previous.retained_from < cut.retained_from) return error.HistoryReclaimed;
        if (!std.meta.eql(previous, cut)) return error.QueryExpired;
    }
    var result: i.Page = .{ .realm = state.realm, .resource = q.resource, .pid = q.pid, .cut = cut, .reader = .{ .principal = q.principal, .permissions = principal.grant.permissions, .pid = principal.grant.pid }, .history = if (state.history_floor > 1) .prefix_reclaimed else .retained };
    var count: usize = 0;
    switch (q.resource) {
        .process => {
            if (q.after != 0) return error.InvalidRead;
            result.processes[0] = processView((try state.process(q.pid.?)).*);
            result.scanned = 1;
        },
        .processes, .outbox, .effects, .payloads => {
            const length: usize = switch (q.resource) {
                .processes => p.max_processes,
                .outbox => p.max_outputs,
                .effects => p.max_effects,
                .payloads => p.max_payloads,
                else => unreachable,
            };
            if (q.after > length) return error.InvalidRead;
            var at: usize = @intCast(q.after);
            while (at < length and count < i.page_size and result.scanned < i.scan_limit) : (at += 1) {
                result.scanned += 1;
                switch (q.resource) {
                    .processes => if (state.processes[at]) |value| {
                        if (allowed(principal.grant, value.pid)) {
                            result.processes[count] = processView(value);
                            count += 1;
                        }
                    },
                    .outbox => if (state.outputs[at]) |value| {
                        if (value.source == q.pid and allowed(principal.grant, value.destination)) {
                            result.outbox[count] = value;
                            count += 1;
                        }
                    },
                    .effects => if (state.effects[at]) |value| {
                        if (value.pid == q.pid) {
                            result.effects[count] = value;
                            count += 1;
                        }
                    },
                    .payloads => if (state.payloads[at]) |value| {
                        if (value.pid == q.pid) {
                            result.payloads[count] = value;
                            count += 1;
                        }
                    },
                    else => unreachable,
                }
            }
            if (at < length) result.next = at;
        },
        .history, .mailbox => {
            if (q.after > cut.position) return error.InvalidRead;
            var at = @max(@max(1, cut.retained_from), q.after);
            while (at < cut.position and count < i.page_size and result.scanned < i.scan_limit) : (at += 1) {
                result.scanned += 1;
                const entry = (try engine.store.read(at)) orelse return error.IncompleteHistory;
                const record = switch (entry) {
                    .operation => |r| r,
                    else => return error.CorruptHistory,
                };
                if (try event(state, record, principal.grant, q.pid.?)) |value| {
                    if (q.resource == .mailbox and !value.admitted) continue;
                    result.events[count] = value;
                    count += 1;
                }
            }
            if (at < cut.position) result.next = at;
        },
    }
    result.complete = result.next == null;
    // A concurrent commit/revoke invalidates the entire batch before disclosure.
    if (try engine.store.tail() != cut.position) return error.Conflict;
    return result;
}
