const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;

pub fn suspensionDeadline(process: *const core.Process) ?u64 {
    const control = process.control orelse return null;
    return if (control.phase == .suspended) control.resume_before_ms else null;
}
pub fn required(state: *core.State, process: *const core.Process, sample: ?core.Time.Sample) !void {
    const control = process.control orelse return;
    for (control.required) |slot| if (slot) |name| {
        const cat = if (state.resources) |*cat| cat else return error.MissingRequiredAssociation;
        const id = for (cat.associations) |association| {
            if (association) |a| if (a.pid == process.pid and a.required and a.name.eql(name)) break a.resource;
        } else return error.MissingRequiredAssociation;
        try core.resources.usable(state, try cat.resource(id), sample);
    };
}
fn fence(process: *core.Process) !void {
    process.owner = null;
    process.turn_permit = null;
    process.generation = try std.math.add(u64, process.generation, 1);
    if (process.binding) |*binding| binding.activation = null;
}
fn restartBinding(process: *core.Process, position: u64) !void {
    const binding = if (process.binding) |*b| b else return;
    // Same resource/incarnation. Require a confirmed stop before requesting a
    // fresh activation; resumption is never proof that the provider has resumed.
    if (binding.desired != .stopped or binding.phase != .stopped or binding.upgrade_from != null) return error.ProviderNotReady;
    binding.desired = .running;
    binding.phase = .pending;
    binding.operation = position;
    binding.revision = try std.math.add(u64, binding.revision, 1);
    binding.activation = null;
}
pub fn apply(state: *core.State, command: p.Lifecycle.Command, record: core.Record) !void {
    if (command == .create) {
        const c = command.create;
        const process = try state.spawnProcess(.{ .code = c.code, .initial_state = c.initial_state, .deadline_ms = c.deadline_ms, .settle_before_ms = c.settle_before_ms, .allow_trim = c.allow_trim }, record);
        if (c.collect_catalog) try core.collection.enable(state, process.pid);
        process.control = .{ .required = c.required };
        return;
    }
    const process = try state.process(p.Lifecycle.pid(command).?);
    if (process.lifecycle != .running) return error.RetiredProcess;
    if (command == .expire_suspension) {
        const deadline = suspensionDeadline(process) orelse return error.NoDeadline;
        try (try core.resources.time(state, record.time)).after(deadline);
        state.retireProcess(process, record.position, .expired);
        return;
    }
    const generation = switch (command) {
        inline .initialize, .@"suspend", .@"resume", .retry => |c| c.expected_generation,
        else => unreachable,
    };
    if (process.generation != generation) return error.StaleGeneration;
    try core.resources.checkProcess(state, process.pid, record.time);
    if (process.work_before_ms) |deadline| try (try core.resources.time(state, record.time)).before(deadline);
    switch (command) {
        .initialize => {
            const control = if (process.control) |*c| c else return error.InvalidLifecycle;
            if (control.phase != .initializing) return error.InvalidLifecycle;
            try required(state, process, record.time);
            control.phase = .ready;
            try fence(process);
        },
        .@"suspend" => |c| {
            try core.executable(process);
            try required(state, process, record.time);
            if (process.turn_permit != null) return error.PendingWork;
            if (c.resume_before_ms > p.max_counter) return error.InvalidLifetime;
            try (try core.resources.time(state, record.time)).before(c.resume_before_ms);
            if (process.work_before_ms) |deadline| if (c.resume_before_ms > deadline) return error.InvalidLifetime;
            if (state.resources) |*cat| for (cat.associations) |slot| if (slot) |association| {
                if (association.pid == process.pid and association.required) {
                    const data = try cat.resource(association.resource);
                    if (core.resources.effectiveDeadline(state, data)) |bound| if (c.resume_before_ms > bound) return error.InvalidLifetime;
                }
            };
            if (process.control == null) process.control = .{ .phase = .ready };
            process.control.?.phase = .suspended;
            process.control.?.resume_before_ms = c.resume_before_ms;
            try fence(process);
        },
        .@"resume" => {
            const deadline = suspensionDeadline(process) orelse return error.InvalidLifecycle;
            try (try core.resources.time(state, record.time)).before(deadline);
            try required(state, process, record.time);
            if (process.failure != null) return error.BlockedProcess;
            try restartBinding(process, record.position);
            process.control.?.phase = .ready;
            process.control.?.resume_before_ms = null;
            try fence(process);
        },
        .retry => |c| {
            const failure = process.failure orelse return error.InvalidFailure;
            if (failure.recorded_at != c.failure) return error.InvalidFailure;
            if (process.control) |control| if (control.phase != .ready) return error.InvalidLifecycle;
            try required(state, process, record.time);
            try restartBinding(process, record.position);
            process.failure = null;
            try fence(process);
        },
        else => unreachable,
    }
}
pub fn needsTime(state: *core.State, command: p.Lifecycle.Command) !bool {
    return switch (command) {
        .create => |c| c.deadline_ms != null,
        .@"suspend", .@"resume", .expire_suspension => true,
        .initialize, .retry => blk: {
            const pid = p.Lifecycle.pid(command).?;
            break :blk (try state.process(pid)).work_before_ms != null or core.resources.processNeedsTime(state, pid);
        },
    };
}
