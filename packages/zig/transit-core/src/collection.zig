//! Explicitly opted-in working catalog reclamation. Identities never recycle.
const core = @import("root.zig");
const p = core.protocol;
const std = @import("std");
pub const Request = p.Collection;

pub fn enable(state: *core.State, pid: u64) !void {
    const process = try state.process(pid);
    if (state.retry_policy != .last_per_principal or !process.allow_trim) return error.RetentionNotEnabled;
    // Retention cannot retroactively weaken already accepted work. Provision it
    // before the first activation, association fence or admitted message.
    if (process.lifecycle != .running or process.generation != 0 or process.admitted != 0 or process.owner != null or process.collection) return error.InvalidLifetime;
    process.collection = true;
}

pub fn evidence(state: *core.State, request: Request) !?u64 {
    if (request.kind != .output) return null;
    const out = try state.output(request.id);
    if (out.source != request.pid) return error.InvalidOutput;
    if (out.phase != .delivered) return null;
    const destination = try state.process(out.destination);
    if (destination.lifecycle == .running and destination.input_cursor < out.resolved_at.?) return out.resolved_at;
    return null;
}

pub fn eligible(state: *core.State, c: Request) !void {
    const process = try state.process(c.pid);
    if (state.retry_policy != .last_per_principal or !process.collection) return error.RetentionNotEnabled;
    switch (c.kind) {
        .output => {
            const out = try state.output(c.id);
            if (out.source != c.pid) return error.InvalidOutput;
            if (out.phase == .pending) return error.PendingWork;
        },
        .effect => {
            const effect = try state.effect(c.id);
            if (effect.pid != c.pid) return error.InvalidEffect;
            switch (effect.phase) {
                .observed, .cancelled, .closed_unknown => {},
                else => return error.PendingWork,
            }
        },
        .payload => {
            const payload = try state.payload(.{ .pid = c.pid, .payload = c.id });
            if (payload.phase != .deleted) return error.PendingWork;
        },
        .resource => {
            const cat = try core.resources.catalog(state);
            const data = try cat.resource(c.id);
            if (data.meta.writer != c.pid) return error.Forbidden;
            if (data.meta.phase != .reclaimed) return error.PendingWork;
            for (cat.views) |slot| if (slot) |view| if (view.meta.resource == c.id) return error.StateViewInUse;
            for (cat.associations) |slot| if (slot) |association| {
                if (association.resource == c.id and (try state.process(association.pid)).lifecycle == .running) return error.StateResourceInUse;
            };
        },
        .process => {
            if (c.id != c.pid) return error.InvalidRequest;
            if (process.lifecycle == .running) return error.PendingWork;
            if (process.binding) |binding| if (binding.phase != .stopped or binding.desired != .stopped or binding.upgrade_from != null) return error.PendingProviderOperation;
            for (state.outputs) |slot| if (slot) |out| if (out.source == c.pid or out.destination == c.pid) return error.PendingWork;
            for (state.effects) |slot| if (slot) |effect| if (effect.pid == c.pid) return error.PendingWork;
            for (state.payloads) |slot| if (slot) |payload| if (payload.pid == c.pid) return error.PendingWork;
            if (state.resources) |cat| {
                for (cat.resources) |slot| if (slot) |data| if (data.meta.writer == c.pid or data.meta.owner == c.pid) return error.StateResourceInUse;
                for (cat.views) |slot| if (slot) |view| if (view.meta.pid == c.pid) return error.StateViewInUse;
            }
        },
    }
}

pub fn apply(state: *core.State, c: Request, retained: ?core.Record) !void {
    try eligible(state, c);
    if (try evidence(state, c)) |position| {
        const record = retained orelse return error.PendingWork;
        const out = try state.output(c.id);
        const expected: p.Origin = .{ .source = .{ .process = .{ .pid = out.source, .turn = out.turn, .output = out.id } } };
        // An unconsumed legacy admission has no self-contained origin. Leave its
        // catalog evidence pinned until consumed; new envelopes can be collected.
        if (record.position != position or record.admission == null or record.admission.?.pid != out.destination or record.origin == null or !std.meta.eql(record.origin.?, expected)) return error.PendingWork;
    }
    switch (c.kind) {
        .output => for (&state.outputs) |*slot| {
            if (slot.* != null and slot.*.?.id == c.id) {
                slot.* = null;
                break;
            }
        },
        .effect => for (&state.effects) |*slot| {
            if (slot.* != null and slot.*.?.id == c.id) {
                slot.* = null;
                break;
            }
        },
        .payload => for (&state.payloads) |*slot| {
            if (slot.* != null and slot.*.?.id == c.id) {
                slot.* = null;
                break;
            }
        },
        .resource => {
            const cat = &state.resources.?;
            for (&cat.associations) |*slot| if (slot.* != null and slot.*.?.resource == c.id) {
                slot.* = null;
            };
            for (&cat.resources) |*slot| if (slot.* != null and slot.*.?.meta.id == c.id) {
                slot.* = null;
                break;
            };
        },
        .process => {
            if (state.resources) |*cat| for (&cat.associations) |*slot| if (slot.* != null and slot.*.?.pid == c.pid) {
                slot.* = null;
            };
            for (&state.processes) |*slot| if (slot.* != null and slot.*.?.pid == c.pid) {
                slot.* = null;
                break;
            };
        },
    }
}

/// Bounded candidate scan. Maintenance leaves unconsumed legacy outputs pinned;
/// explicit collection can additionally prove a retained, self-contained origin.
pub fn next(state: *core.State) ?p.Command {
    inline for (.{ "outputs", "effects", "payloads", "processes" }, .{ .output, .effect, .payload, .process }) |field, kind| {
        for (@field(state, field)) |slot| if (slot) |value| {
            const c: Request = .{ .kind = kind, .id = if (comptime kind == .process) value.pid else value.id, .pid = if (comptime kind == .output) value.source else value.pid };
            eligible(state, c) catch continue;
            if ((evidence(state, c) catch continue) != null) continue;
            return .{ .collect = c };
        };
    }
    if (state.resources) |cat| for (cat.resources) |slot| if (slot) |data| {
        const c: Request = .{ .kind = .resource, .id = data.meta.id, .pid = data.meta.writer };
        eligible(state, c) catch continue;
        return .{ .collect = c };
    };
    return null;
}
