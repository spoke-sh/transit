//! State-resource transitions over growing catalogs. All changes remain in a
//! private candidate until the authority publishes the root with its receipt.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const growth = @import("growing.zig");
const c = @import("catalog.zig");
const address = growth.address;
const read_rights = p.State.permission(.read) | p.State.permission(.inspect);
pub const graph_vertices = 4096;

pub fn resource(engine: anytype, id: u64) anyerror!g.Resource {
    var current = try engine.state();
    return (try current.get(g.Resource, address(.resource, id))) orelse error.UnknownStateResource;
}
pub fn view(engine: anytype, id: u64) anyerror!growth.StoredView {
    var current = try engine.state();
    return (try current.get(growth.StoredView, address(.view, id))) orelse error.StateViewExpired;
}
pub fn allowed(engine: anytype, id: u64, principal: u64, rights: u8) anyerror!void {
    const subject = try engine.principal(principal);
    var current = try engine.state();
    const grant = (try current.get(growth.ResourceGrant, try c.key(.grant, id, principal, ""))) orelse return error.Forbidden;
    if (grant.principal_epoch != subject.epoch or grant.permissions & rights != rights) return error.Forbidden;
}
pub fn usable(engine: anytype, value: g.Resource, sample: ?core.Time.Sample) anyerror!void {
    try basicUsable(engine, value, sample);
    if (value.owner) |pid| try dependencies(engine, pid, sample);
}
fn basicUsable(engine: anytype, value: g.Resource, sample: ?core.Time.Sample) anyerror!void {
    if (value.phase != .active) return error.StateResourceExpired;
    if (value.deadline_ms) |deadline| engine.before(sample, deadline) catch |err| {
        if (err == error.DeadlineExpired) return error.StateResourceExpired;
        return err;
    };
}
pub fn dependencies(engine: anytype, pid: u64, sample: ?core.Time.Sample) anyerror!void {
    var current = try engine.state();
    try dependenciesAt(engine, &current, pid, sample);
}
fn dependenciesAt(engine: anytype, current: anytype, pid: u64, sample: ?core.Time.Sample) anyerror!void {
    // A bounded traversal budget is explicit deployment policy for one checked
    // dependency graph, not a limit on total processes/resources in the realm.
    var pending: [graph_vertices]u64 = undefined;
    pending[0] = pid;
    var count: usize = 1;
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const process = (try current.get(g.Process, address(.process, pending[index]))) orelse return error.UnknownProcess;
        if (process.lifecycle != .running) return error.StateResourceExpired;
        var after: ?core.pages.Key = null;
        var associations: usize = 0;
        while (true) {
            const batch = try current.scan(g.Association, .{ .namespace = .required_association, .major = process.pid }, after);
            for (batch.records) |slot| if (slot) |record| {
                associations += 1;
                if (associations > engine.genesis.required_dependencies) return error.DependencyBudgetExceeded;
                const data = (try current.get(g.Resource, address(.resource, record.value.resource))) orelse return error.UnknownStateResource;
                try basicUsable(engine, data, sample);
                if (data.owner) |owner| {
                    if (std.mem.indexOfScalar(u64, pending[0..count], owner) == null) {
                        if (count >= engine.genesis.dependency_vertices) return error.DependencyBudgetExceeded;
                        pending[count] = owner;
                        count += 1;
                    }
                }
            };
            after = batch.next;
            if (after == null) break;
        }
    }
}
pub fn associated(engine: anytype, pid: u64, id: u64) !bool {
    var current = try engine.state();
    return (try current.get(u64, try c.key(.associated_resource, pid, id, "")) orelse 0) > 0;
}
fn nextInput(engine: anytype, process: g.Process, id: u64) !g.Input {
    if (process.consumed >= process.admitted) return error.MissingInput;
    var current = try engine.state();
    const input = (try current.get(g.Input, try c.key(.mailbox, process.pid, process.consumed + 1, ""))) orelse return error.IncompleteHistory;
    if (input.position != id) return error.InvalidInput;
    return input;
}
pub fn captured(engine: anytype, principal: u64, process: g.Process, id: u64, input: u64, sample: ?core.Time.Sample) !growth.StoredView {
    const stored = try view(engine, id);
    const meta = stored.meta;
    if (meta.closed_at != null) return error.StateViewExpired;
    if (meta.principal != principal or meta.pid != process.pid or meta.generation != process.generation or meta.process_revision != process.revision or meta.input != input) return error.InvalidStateView;
    engine.before(sample, meta.deadline_ms) catch |err| {
        if (err == error.DeadlineExpired) return error.StateViewExpired;
        return err;
    };
    if (!try associated(engine, process.pid, meta.resource)) return error.Forbidden;
    try allowed(engine, meta.resource, principal, read_rights);
    try usable(engine, try resource(engine, meta.resource), sample);
    return stored;
}
pub fn authorizeReceipt(engine: anytype, request: g.Request) anyerror!void {
    switch (request.command) {
        .associate => |command| if (command.resource) |id| try allowed(engine, id, request.principal, p.State.permission(.inspect)),
        .open_view => |command| try allowed(engine, command.resource, request.principal, read_rights),
        .turn => |command| for (command.views) |slot| if (slot) |id| {
            const stored = try view(engine, id);
            if (stored.meta.principal != request.principal or stored.meta.pid != command.pid) return error.InvalidHistory;
            try allowed(engine, stored.meta.resource, request.principal, read_rights | if (command.write_view == id) p.State.permission(.write) else @as(u8, 0));
        },
        else => {},
    }
}

pub fn apply(engine: anytype, candidate: anytype, next: *growth.Head, request: g.Request, sample: ?core.Time.Sample) anyerror!void {
    const position = engine.head.position;
    switch (request.command) {
        .create_resource => |command| {
            const writer = try engine.process(command.writer);
            try engine.executable(writer, sample, false);
            var deadline = command.deadline_ms;
            if (command.owned) {
                if (writer.settle_before_ms) |bound| deadline = if (deadline) |explicit| @min(explicit, bound) else bound;
            }
            if (deadline) |bound| try engine.before(sample, bound);
            try candidate.put(address(.resource, position), g.Resource{ .id = position, .writer = writer.pid, .owner = if (command.owned) writer.pid else null, .revision = position, .deadline_ms = deadline });
        },
        .grant_resource => |command| {
            if (request.principal != 0 or command.permissions & ~p.State.all_permissions != 0) return error.Forbidden;
            _ = try resource(engine, command.resource);
            var principal = try engine.principal(command.subject);
            try candidate.put(try c.key(.grant, command.resource, command.subject, ""), growth.ResourceGrant{ .principal_epoch = principal.epoch, .permissions = command.permissions });
            principal.revision = position;
            try candidate.put(address(.principal, command.subject), principal);
        },
        .associate => |command| {
            var process = try engine.process(command.pid);
            if (process.lifecycle != .running) return error.RetiredProcess;
            if (process.owner != null or process.turn_permit != null) return error.PendingWork;
            // A broken required lifetime cannot be repaired into reactivation
            // of the old PID by removing/rebinding its expired dependency.
            try dependencies(engine, process.pid, sample);
            const key = try c.key(.association, command.pid, 0, command.name.slice());
            const required_key = try c.key(.required_association, command.pid, 0, command.name.slice());
            const previous = try candidate.get(g.Association, key);
            if ((if (previous) |old| old.revision else @as(u64, 0)) != command.expected_revision) return error.StaleAssociation;
            // Existing borrowers were admitted against this owner's bounded
            // graph. Freeze required topology until those borrowers detach or
            // retire; checking only the edited PID could strand its ancestors
            // beyond the graph budget after acknowledging the change.
            if ((previous != null and previous.?.required) or (command.resource != null and command.required)) {
                const borrowers = try candidate.scan(u64, .{ .namespace = .owner_required_users, .major = command.pid }, null);
                if (borrowers.records[0] != null) return error.DependencyInUse;
            }
            var next_owner: ?u64 = null;
            if (command.resource) |id| {
                try allowed(engine, id, request.principal, p.State.permission(.inspect));
                const data = try resource(engine, id);
                try usable(engine, data, sample);
                if (command.required and data.owner != command.pid) next_owner = data.owner;
                if (command.required) {
                    var after: ?core.pages.Key = null;
                    var count: usize = 0;
                    while (true) {
                        const batch = try candidate.scan(g.Association, .{ .namespace = .required_association, .major = command.pid }, after);
                        for (batch.records) |slot| if (slot != null) {
                            count += 1;
                        };
                        after = batch.next;
                        if (after == null) break;
                    }
                    if (!(previous != null and previous.?.required) and count >= engine.genesis.required_dependencies) return error.DependencyBudgetExceeded;
                }
                const association: g.Association = .{ .pid = command.pid, .name = command.name, .resource = id, .revision = position, .required = command.required };
                try candidate.put(key, association);
                try candidate.put(try c.key(.association_order, command.pid, position, ""), association);
                if (command.required) try candidate.put(required_key, association) else try candidate.remove(required_key);
                if (command.required) try candidate.put(try c.key(.required_resource_users, id, command.pid, command.name.slice()), command.pid);
                if (next_owner) |owner| try candidate.put(try c.key(.owner_required_users, owner, command.pid, command.name.slice()), command.pid);
                const index = try c.key(.associated_resource, command.pid, id, "");
                try candidate.put(index, (try candidate.get(u64, index) orelse 0) + 1);
            } else {
                if (previous == null) return error.StaleAssociation;
                try candidate.remove(key);
                try candidate.remove(required_key);
            }
            if (previous) |old| {
                try candidate.remove(try c.key(.association_order, command.pid, old.revision, ""));
                if (old.required and !(command.resource == old.resource and command.required)) try candidate.remove(try c.key(.required_resource_users, old.resource, command.pid, command.name.slice()));
                const old_owner = (try resource(engine, old.resource)).owner;
                if (old.required and old_owner != null and old_owner != command.pid and old_owner != next_owner)
                    try candidate.remove(try c.key(.owner_required_users, old_owner.?, command.pid, command.name.slice()));
                const index = try c.key(.associated_resource, command.pid, old.resource, "");
                const count = (try candidate.get(u64, index)) orelse return error.InvalidHistory;
                if (count == 0) return error.InvalidHistory;
                if (count == 1) try candidate.remove(index) else try candidate.put(index, count - 1);
            }
            process.generation += 1;
            try candidate.put(address(.process, command.pid), process);
            try dependenciesAt(engine, candidate, process.pid, sample);
        },
        .open_view => |command| {
            const process = try engine.process(command.pid);
            try engine.executable(process, sample, true);
            if (process.owner != request.principal or process.generation != command.generation) return error.StaleGeneration;
            if (process.revision != command.expected_revision) return error.StaleState;
            _ = try nextInput(engine, process, command.input);
            if (process.work_before_ms != null and process.turn_permit == null) return error.MissingTurnPermit;
            if (!try associated(engine, command.pid, command.resource)) return error.Forbidden;
            try allowed(engine, command.resource, request.principal, read_rights);
            const data = try resource(engine, command.resource);
            try usable(engine, data, sample);
            if (data.revision != command.revision) return error.StaleStateResource;
            try engine.before(sample, command.deadline_ms);
            if (command.deadline_ms > (sample orelse return error.ClockUnavailable).lower() + g.view_lifetime_ms) return error.InvalidLifetime;
            if (data.deadline_ms) |bound| if (command.deadline_ms > bound) return error.InvalidLifetime;
            if (process.settle_before_ms) |bound| if (command.deadline_ms > bound) return error.InvalidLifetime;
            try candidate.put(address(.view, position), growth.StoredView{ .meta = .{ .id = position, .pid = command.pid, .principal = request.principal, .generation = command.generation, .input = command.input, .process_revision = command.expected_revision, .resource = command.resource, .revision = command.revision, .deadline_ms = command.deadline_ms }, .snapshot = engine.head.catalog });
        },
        .close_view => |command| {
            var stored = try view(engine, command.view);
            if (stored.meta.pid != command.pid or stored.meta.principal != request.principal) return error.Forbidden;
            if (stored.meta.closed_at != null) return error.StateViewExpired;
            stored.meta.closed_at = position;
            try candidate.put(address(.view, command.view), stored);
        },
        .retire_resource, .expire_resource => |id| {
            var data = try resource(engine, id);
            if (data.phase != .active) return error.StateResourceExpired;
            if (request.command == .expire_resource) {
                const deadline = data.deadline_ms orelse return error.InvalidLifetime;
                try (sample orelse return error.ClockUnavailable).after(deadline);
            } else {
                var after: ?core.pages.Key = null;
                while (true) {
                    const batch = try candidate.scan(u64, .{ .namespace = .required_resource_users, .major = id }, after);
                    for (batch.records) |slot| if (slot) |record| {
                        if ((try engine.process(record.value)).lifecycle == .running) return error.StateResourceInUse;
                    };
                    after = batch.next;
                    if (after == null) break;
                }
            }
            data.phase = .retired;
            data.retired_at = position;
            try candidate.put(address(.resource, id), data);
        },
        .begin_turn => |command| {
            var process = try engine.process(command.pid);
            try engine.executable(process, sample, false);
            if (process.owner != request.principal or process.generation != command.generation) return error.StaleGeneration;
            if (process.work_before_ms == null or process.turn_permit != null) return error.InvalidTurnPermit;
            _ = try nextInput(engine, process, command.input);
            process.turn_permit = .{ .id = position, .input = command.input };
            try candidate.put(address(.process, command.pid), process);
        },
        .turn => |command| try turn(engine, candidate, next, request.principal, command, sample),
        else => return error.UnsupportedGrowthCommand,
    }
}

pub fn retireIndexes(candidate: anytype, pid: u64) !void {
    var after: ?core.pages.Key = null;
    while (true) {
        const batch = try candidate.scan(g.Association, .{ .namespace = .required_association, .major = pid }, after);
        for (batch.records) |slot| if (slot) |record| {
            const association = record.value;
            try candidate.remove(try c.key(.required_resource_users, association.resource, pid, association.name.slice()));
            const data = (try candidate.get(g.Resource, address(.resource, association.resource))) orelse return error.InvalidHistory;
            if (data.owner) |owner| if (owner != pid) try candidate.remove(try c.key(.owner_required_users, owner, pid, association.name.slice()));
        };
        after = batch.next;
        if (after == null) break;
    }
}

fn turn(engine: anytype, candidate: anytype, next: *growth.Head, principal: u64, command: g.Turn, sample: ?core.Time.Sample) anyerror!void {
    const position = engine.head.position;
    var process = try engine.process(command.pid);
    try engine.executable(process, sample, true);
    if (process.owner != principal or process.generation != command.generation) return error.StaleGeneration;
    if (process.revision != command.expected_revision) return error.StaleState;
    _ = try nextInput(engine, process, command.input);
    if (process.turn_permit) |permit| {
        if (command.permit != permit.id or permit.input != command.input) return error.InvalidTurnPermit;
    } else if (command.permit != null or process.work_before_ms != null) return error.MissingTurnPermit;
    var write: ?g.Resource = null;
    for (command.views, 0..) |slot, i| if (slot) |id| {
        for (command.views[0..i]) |previous| if (previous == id) return error.InvalidStateView;
        var stored = try captured(engine, principal, process, id, command.input, sample);
        if (command.write_view == id) {
            const data = try resource(engine, stored.meta.resource);
            if (data.writer != process.pid) return error.Forbidden;
            try allowed(engine, data.id, principal, p.State.permission(.write));
            if (data.revision != stored.meta.revision) return error.StaleStateResource;
            write = data;
        }
        stored.meta.closed_at = position;
        try candidate.put(address(.view, id), stored);
    };
    if (command.write_view != null and write == null) return error.InvalidStateView;
    if (command.failed) {
        if (command.effect != null or command.write_view != null) return error.InvalidFailure;
        for (command.outputs) |slot| if (slot != null) return error.InvalidFailure;
        for (command.mutations) |slot| if (slot != null) return error.InvalidFailure;
        process.failure = command.input;
        process.owner = null;
        process.generation += 1;
    } else {
        for (command.mutations) |slot| if (slot) |mutation| {
            const data = if (write) |*value| value else return error.MissingWriteView;
            const key = try c.key(.entry, data.id, 0, mutation.key.slice());
            const exists = try candidate.get(g.Entry, key) != null;
            if (mutation.value) |value| {
                try candidate.put(key, g.Entry{ .key = mutation.key, .value = value, .revision = position });
                if (!exists) data.entries += 1;
            } else if (exists) {
                try candidate.remove(key);
                data.entries -= 1;
            }
        };
        if (write) |*data| {
            data.revision = position;
            try candidate.put(address(.resource, data.id), data.*);
        }
        const subject = try engine.principal(principal);
        for (command.outputs, 0..) |slot, i| if (slot) |output| {
            try engine.executable(process, sample, false);
            if (subject.grant.permissions & p.permission(.publish) == 0) return error.Forbidden;
            _ = try engine.process(output.pid);
            if (next.outputs >= p.max_counter) return error.Overflow;
            next.outputs += 1;
            try candidate.put(address(.output, next.outputs), g.Outbox{ .id = next.outputs, .source = process.pid, .turn = position, .index = @intCast(i), .destination = output.pid, .value = output.value });
        };
        if (command.effect) |payload| {
            try engine.executable(process, sample, false);
            if (subject.grant.permissions & p.permission(.effect) == 0) return error.Forbidden;
            try candidate.put(address(.effect, position), g.Effect{ .id = position, .pid = process.pid, .payload = payload });
        }
        process.consumed += 1;
        process.revision = position;
    }
    process.turn_permit = null;
    try candidate.put(address(.process, process.pid), process);
}
