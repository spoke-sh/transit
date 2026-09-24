//! Deterministic bounded KV catalog. No I/O, application decoders, or clocks.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const s = p.State;
pub const Data = struct {
    meta: s.Resource,
    entries: [s.max_entries]?s.Entry = @splat(null),
    grants: [p.max_principals]u8 = @splat(0),
};
pub const Snapshot = struct { meta: s.View, entries: [s.max_entries]?s.Entry };
pub const ReceiptRights = struct {
    sequence: u64,
    reads: [s.max_views]?u64 = @splat(null),
    write: ?u64 = null,
};
pub const Catalog = struct {
    resources: [s.max_resources]?Data = @splat(null),
    associations: [s.max_associations]?s.Association = @splat(null),
    views: [s.max_views]?Snapshot = @splat(null),
    receipts: [p.max_principals]?ReceiptRights = @splat(null),

    pub fn resource(self: *Catalog, id: u64) !*Data {
        for (&self.resources) |*slot| if (slot.*) |*data| {
            if (data.meta.id == id) return data;
        };
        return error.UnknownStateResource;
    }
    pub fn view(self: *Catalog, id: u64) !*Snapshot {
        for (&self.views) |*slot| if (slot.*) |*value| {
            if (value.meta.id == id) return value;
        };
        return error.StateViewExpired;
    }
    pub fn allowed(self: *const Catalog, id: u64, principal: u8, permission: s.Permission) bool {
        if (principal >= p.max_principals) return false;
        for (self.resources) |slot| if (slot) |data| {
            if (data.meta.id == id) return data.grants[principal] & s.permission(permission) != 0;
        };
        return false;
    }
    pub fn associated(self: *const Catalog, pid: u64, resource_id: u64) bool {
        for (self.associations) |slot| if (slot) |association| {
            if (association.pid == pid and association.resource == resource_id) return true;
        };
        return false;
    }
    pub fn revoke(self: *Catalog, subject: u8) void {
        for (&self.resources) |*slot| if (slot.*) |*data| {
            data.grants[subject] = 0;
        };
    }
};

pub fn catalog(state: *core.State) !*Catalog {
    return if (state.resources) |*value| value else error.UnknownStateResource;
}
pub fn time(state: *const core.State, sample: ?core.Time.Sample) !core.Time.Sample {
    const bound = state.max_clock_error_ms orelse return error.UnsupportedDeadline;
    const value = sample orelse return error.ClockUnavailable;
    if (value.error_ms > bound or value.unix_ms > p.max_counter) return error.UntrustedTime;
    if (value.unix_ms < state.time_floor_ms) return error.ClockRollback;
    return value;
}
pub fn effectiveDeadline(state: *core.State, data: *const Data) ?u64 {
    var bound = data.meta.deadline_ms;
    if (data.meta.owner) |pid| if (core.lifecycle.suspensionDeadline(state.process(pid) catch return bound)) |cutoff| {
        bound = if (bound) |existing| @min(existing, cutoff) else cutoff;
    };
    return bound;
}
pub fn usable(state: *core.State, data: *const Data, sample: ?core.Time.Sample) !void {
    if (data.meta.phase != .active) return error.StateResourceExpired;
    if (effectiveDeadline(state, data)) |cutoff| (try time(state, sample)).before(cutoff) catch |err| {
        if (err == error.DeadlineExpired) return error.StateResourceExpired;
        return err;
    };
    if (data.meta.owner) |pid| if ((try state.process(pid)).lifecycle != .running) return error.StateResourceExpired;
}
pub fn checkProcess(state: *core.State, pid: u64, sample: ?core.Time.Sample) !void {
    const cat = if (state.resources) |*value| value else return;
    for (cat.associations) |slot| if (slot) |association| {
        if (association.pid == pid and association.required) try usable(state, try cat.resource(association.resource), sample);
    };
}
pub fn processNeedsTime(state: *core.State, pid: u64) bool {
    const cat = if (state.resources) |*value| value else return false;
    for (cat.associations) |slot| if (slot) |association| {
        if (association.pid == pid and association.required) {
            const data = cat.resource(association.resource) catch continue;
            if (effectiveDeadline(state, data) != null) return true;
        }
    };
    return false;
}
pub fn historyNeedsTime(state: *const core.State) bool {
    const cat = if (state.resources) |*value| value else return false;
    for (cat.resources) |slot| if (slot) |data| {
        if (data.meta.history_ms) |age| if (age > 0) return true;
    };
    return false;
}
pub fn needsTime(state: *core.State, command: s.Command) !bool {
    switch (command) {
        .create => |c| return processNeedsTime(state, c.writer) or c.deadline_ms != null or (c.history_ms orelse 0) > 0 or (c.owned and (try state.process(c.writer)).settle_before_ms != null),
        .open, .expire => return true,
        .turn => return true,
        .associate => |c| {
            if (processNeedsTime(state, c.pid)) return true;
            if (c.resource) |id| return effectiveDeadline(state, try (try catalog(state)).resource(id)) != null;
            return false;
        },
        .reclaim => |id| return ((try (try catalog(state)).resource(id)).meta.history_ms orelse 0) > 0,
        else => return false,
    }
}
pub fn checkpoint(state: *core.State, sample: ?core.Time.Sample) !void {
    const cat = if (state.resources) |*value| value else return;
    for (cat.resources) |slot| if (slot) |data| {
        const age = data.meta.history_ms orelse return error.HistoryPinned;
        if (age > 0 and (try time(state, sample)).lower() < data.meta.changed_ms + age) return error.HistoryPinned;
    };
}

pub fn apply(state: *core.State, command: s.Command, record: core.Record, input: ?core.Record) anyerror!void {
    const caller = record.request.principal;
    if (state.resources == null) {
        if (command != .create) return error.UnknownStateResource;
        state.resources = .{};
    }
    const cat = &state.resources.?;
    switch (command) {
        .create => |c| {
            const process = try state.process(c.writer);
            if (process.lifecycle != .running) return error.RetiredProcess;
            if (core.lifecycle.suspensionDeadline(process) != null) return error.SuspendedProcess;
            try checkProcess(state, c.writer, record.time);
            var deadline = c.deadline_ms;
            if (c.owned) if (process.settle_before_ms) |bound| {
                deadline = if (deadline) |d| @min(d, bound) else bound;
            };
            if (deadline) |d| {
                if (d > p.max_counter) return error.InvalidLifetime;
                try (try time(state, record.time)).before(d);
            }
            for (&cat.resources) |*slot| if (slot.* == null) {
                slot.* = .{ .meta = .{ .id = record.position, .writer = c.writer, .owner = if (c.owned) c.writer else null, .revision = record.position, .deadline_ms = deadline, .history_ms = c.history_ms, .changed_ms = if ((c.history_ms orelse 0) > 0) (try time(state, record.time)).upper() else 0 } };
                return;
            };
            return error.StateResourceCapacity;
        },
        .grant => |c| {
            if (caller != 0 or c.subject >= p.max_principals or c.permissions & ~s.all_permissions != 0) return error.Forbidden;
            _ = try state.principal(c.subject);
            (try cat.resource(c.resource)).grants[c.subject] = c.permissions;
            state.principals[c.subject].?.revision = record.position;
        },
        .associate => |c| {
            const process = try state.process(c.pid);
            if (process.lifecycle != .running) return error.RetiredProcess;
            try checkProcess(state, c.pid, record.time);
            // Changing a recovery dependency fences old proposals and snapshots.
            if (process.owner != null or process.turn_permit != null) return error.PendingWork;
            var existing: ?*?s.Association = null;
            var free: ?*?s.Association = null;
            for (&cat.associations) |*slot| {
                if (slot.*) |association| {
                    if (association.pid == c.pid and association.name.eql(c.name)) existing = slot;
                } else if (free == null) {
                    free = slot;
                }
            }
            if ((if (existing) |slot| slot.*.?.revision else @as(u64, 0)) != c.expected_revision) return error.StaleAssociation;
            if (c.resource) |id| {
                if (!cat.allowed(id, caller, .inspect)) return error.Forbidden;
                const data = try cat.resource(id);
                try usable(state, data, record.time);
                if (c.required) if (core.lifecycle.suspensionDeadline(process)) |resumption_bound| {
                    if (effectiveDeadline(state, data)) |bound| if (resumption_bound > bound) return error.InvalidLifetime;
                };
                const slot = existing orelse free orelse return error.StateAssociationCapacity;
                slot.* = .{ .pid = c.pid, .name = c.name, .resource = id, .revision = record.position, .required = c.required };
            } else if (existing) |slot| {
                slot.* = null;
            } else return error.StaleAssociation;
            process.generation = try std.math.add(u64, process.generation, 1);
        },
        .open => |c| {
            const process = try state.process(c.pid);
            if (process.lifecycle != .running) return error.RetiredProcess;
            if (process.failure != null) return error.BlockedProcess;
            if (process.owner != caller or process.generation != c.generation) return error.StaleGeneration;
            if (process.revision != c.expected_revision) return error.StaleState;
            const message = input orelse return error.MissingInput;
            if (message.position != c.input or (core.messageOf(message) orelse return error.InvalidInput).pid != c.pid) return error.InvalidInput;
            try checkProcess(state, c.pid, record.time);
            const now = try time(state, record.time);
            if (process.work_before_ms) |cutoff| try now.before(if (process.turn_permit != null) process.settle_before_ms.? else cutoff);
            if (c.deadline_ms > p.max_counter or c.deadline_ms > now.lower() + s.max_view_ms) return error.InvalidLifetime;
            try now.before(c.deadline_ms);
            if (!cat.associated(c.pid, c.resource) or !cat.allowed(c.resource, caller, .read) or !cat.allowed(c.resource, caller, .inspect)) return error.Forbidden;
            const data = try cat.resource(c.resource);
            try usable(state, data, record.time);
            if (data.meta.revision != c.revision) return error.StaleStateResource;
            if (data.meta.deadline_ms) |deadline| if (c.deadline_ms > deadline) return error.InvalidLifetime;
            if (process.settle_before_ms) |deadline| if (c.deadline_ms > deadline) return error.InvalidLifetime;
            for (cat.views) |slot| if (slot) |view| {
                if (view.meta.pid == c.pid and view.meta.resource == c.resource) return error.StateViewInUse;
            };
            for (&cat.views) |*slot| if (slot.* == null) {
                slot.* = .{ .meta = .{ .id = record.position, .pid = c.pid, .principal = caller, .generation = c.generation, .input = c.input, .process_revision = c.expected_revision, .resource = c.resource, .revision = c.revision, .deadline_ms = c.deadline_ms }, .entries = data.entries };
                return;
            };
            return error.StateViewCapacity;
        },
        .close => |c| {
            const view = try cat.view(c.view);
            const admin = (try state.principal(caller)).grant.permissions & p.permission(.admin) != 0;
            if (view.meta.pid != c.pid or (!admin and view.meta.principal != caller)) return error.Forbidden;
            release(cat, c.view);
        },
        .turn => |c| {
            const process = try state.process(c.turn.pid);
            const now = try time(state, record.time);
            var write: ?*Data = null;
            var rights: ReceiptRights = .{ .sequence = record.request.sequence };
            for (c.views, 0..) |slot, index| if (slot) |id| {
                for (c.views[0..index]) |previous| if (previous == id) return error.InvalidStateView;
                const view = try cat.view(id);
                if (view.meta.pid != c.turn.pid or view.meta.principal != caller or view.meta.generation != c.turn.generation or view.meta.input != c.turn.input or view.meta.process_revision != c.turn.expected_revision) return error.InvalidStateView;
                now.before(view.meta.deadline_ms) catch |err| {
                    if (err == error.DeadlineExpired) return error.StateViewExpired;
                    return err;
                };
                if (!cat.associated(process.pid, view.meta.resource) or !cat.allowed(view.meta.resource, caller, .read) or !cat.allowed(view.meta.resource, caller, .inspect)) return error.Forbidden;
                const data = try cat.resource(view.meta.resource);
                rights.reads[index] = data.meta.id;
                try usable(state, data, record.time);
                if (c.write_view == id) {
                    if (data.meta.writer != process.pid or !cat.allowed(data.meta.id, caller, .write)) return error.Forbidden;
                    if (data.meta.revision != view.meta.revision) return error.StaleStateResource;
                    write = data;
                    rights.write = data.meta.id;
                }
            };
            if (c.write_view != null and write == null) return error.InvalidStateView;
            if (c.turn.failed and c.write_view != null) return error.InvalidFailure;
            var changed = false;
            for (c.mutations, 0..) |slot, index| if (slot) |mutation| {
                for (c.mutations[0..index]) |previous| if (previous) |other| if (other.key.eql(mutation.key)) return error.InvalidStateMutation;
                const data = write orelse return error.InvalidStateMutation;
                if (c.turn.failed) return error.InvalidFailure;
                var existing: ?*?s.Entry = null;
                var free: ?*?s.Entry = null;
                for (&data.entries) |*entry| {
                    if (entry.*) |value| {
                        if (value.key.eql(mutation.key)) existing = entry;
                    } else if (free == null) {
                        free = entry;
                    }
                }
                if (mutation.value) |value| {
                    const entry = existing orelse free orelse return error.StateEntryCapacity;
                    entry.* = .{ .key = mutation.key, .value = value, .revision = record.position };
                } else if (existing) |entry| {
                    entry.* = null;
                }
                changed = true;
            };
            if (changed) {
                write.?.meta.revision = record.position;
                write.?.meta.changed_ms = now.upper();
                write.?.meta.last_turn = record.position;
            }
            // All mutations above are in the engine's private candidate copy.
            try state.applyTurn(c.turn, record, input);
            cat.receipts[caller] = rights;
            for (c.views) |slot| if (slot) |id| release(cat, id);
        },
        .retire, .expire => |id| {
            const data = try cat.resource(id);
            if (data.meta.phase != .active) return error.StateResourceExpired;
            if (command == .expire) {
                try (try time(state, record.time)).after(data.meta.deadline_ms orelse return error.NoDeadline);
            } else {
                for (cat.associations) |slot| if (slot) |association| {
                    if (association.resource == id and association.required and (try state.process(association.pid)).lifecycle == .running) return error.StateResourceInUse;
                };
            }
            data.meta.phase = .retired;
            data.meta.retired_at = record.position;
        },
        .reclaim => |id| {
            const data = try cat.resource(id);
            if (data.meta.phase != .retired) return error.StateResourceInUse;
            const age = data.meta.history_ms orelse return error.HistoryPinned;
            if (age > 0 and (try time(state, record.time)).lower() < data.meta.changed_ms + age) return error.HistoryPinned;
            for (cat.views) |slot| if (slot) |view| if (view.meta.resource == id) return error.StateViewInUse;
            data.entries = @splat(null);
            data.meta.phase = .reclaimed;
        },
    }
}

/// Current resource rights are required to disclose a previous state receipt.
/// Last state-turn dependencies survive view release and checkpoint/trim.
/// Unlimited older receipts resolve at most four retained view-opening records.
pub fn authorizeReceipt(engine: anytype, request: p.Request) !void {
    if (request.command != .state) return;
    const cat = try catalog(&engine.state);
    const caller = request.principal;
    switch (request.command.state) {
        .open => |c| {
            if (!cat.allowed(c.resource, caller, .inspect) or !cat.allowed(c.resource, caller, .read)) return error.Forbidden;
        },
        .associate => |c| if (c.resource) |id| {
            if (!cat.allowed(id, caller, .inspect)) return error.Forbidden;
        },
        .turn => |c| {
            var rights: ReceiptRights = .{ .sequence = request.sequence };
            const saved = cat.receipts[caller];
            if (saved != null and saved.?.sequence == request.sequence) {
                rights = saved.?;
            } else {
                for (c.views, 0..) |slot, index| if (slot) |id| {
                    const entry = (try engine.store.read(id)) orelse return error.IncompleteHistory;
                    if (entry != .operation or entry.operation.request.command != .state or entry.operation.request.command.state != .open) return error.InvalidHistory;
                    const resource = entry.operation.request.command.state.open.resource;
                    rights.reads[index] = resource;
                    if (c.write_view == id) rights.write = resource;
                };
            }
            for (rights.reads) |slot| if (slot) |id| {
                if (!cat.allowed(id, caller, .inspect) or !cat.allowed(id, caller, .read)) return error.Forbidden;
            };
            if (rights.write) |id| if (!cat.allowed(id, caller, .write)) return error.Forbidden;
        },
        else => {},
    }
}
fn release(cat: *Catalog, id: u64) void {
    for (&cat.views) |*slot| if (slot.*) |view| if (view.meta.id == id) {
        slot.* = null;
        return;
    };
}

/// Monotone bounded closure over owner retirement and required dependencies.
/// Applied with the triggering record, never delegated to an application handler.
pub fn retireDependents(state: *core.State, position: u64) !void {
    const cat = if (state.resources) |*value| value else return;
    for (0..p.max_processes + s.max_resources) |_| {
        var changed = false;
        for (&cat.resources) |*slot| if (slot.*) |*data| if (data.meta.phase == .active) {
            if (data.meta.owner) |pid| if ((try state.process(pid)).lifecycle != .running) {
                data.meta.phase = .retired;
                data.meta.retired_at = position;
                changed = true;
            };
        };
        for (cat.associations) |slot| if (slot) |association| if (association.required) {
            const process = try state.process(association.pid);
            if (process.lifecycle == .running and (try cat.resource(association.resource)).meta.phase != .active) {
                state.retireProcess(process, position, .expired);
                changed = true;
            }
        };
        if (!changed) break;
    }
    for (&cat.views) |*slot| if (slot.*) |view| {
        const process = try state.process(view.meta.pid);
        if (process.lifecycle != .running or process.generation != view.meta.generation or process.owner != view.meta.principal or (try cat.resource(view.meta.resource)).meta.phase != .active) slot.* = null;
    };
}

pub fn maintenance(state: *const core.State, sample: core.Time.Sample) ?p.Command {
    const cat = if (state.resources) |*value| value else return null;
    for (cat.resources) |slot| if (slot) |data| {
        if (data.meta.phase == .active) if (data.meta.deadline_ms) |deadline| if (sample.lower() >= deadline) return .{ .state = .{ .expire = data.meta.id } };
    };
    for (cat.views) |slot| if (slot) |view| {
        if (sample.lower() >= view.meta.deadline_ms) return .{ .state = .{ .close = .{ .pid = view.meta.pid, .view = view.meta.id } } };
    };
    for (cat.resources) |slot| if (slot) |data| if (data.meta.phase == .retired) {
        if (data.meta.history_ms) |age| if (sample.lower() >= data.meta.changed_ms + age) return .{ .state = .{ .reclaim = data.meta.id } };
    };
    return null;
}
