//! Managed readiness and finite suspension over paged process/resource state.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const growing = @import("growing.zig");
const catalog = @import("catalog.zig");
const state = @import("growing_state.zig");

pub fn fence(process: *g.Process) !void {
    process.owner = null;
    process.turn_permit = null;
    process.generation = try std.math.add(u64, process.generation, 1);
    if (process.binding) |*binding| binding.activation = null;
}
pub fn restartBinding(process: *g.Process, position: u64) !void {
    const binding = if (process.binding) |*value| value else return;
    if (binding.desired != .stopped or binding.phase != .stopped or binding.upgrade_from != null) return error.ProviderNotReady;
    binding.desired = .running;
    binding.phase = .pending;
    binding.operation = position;
    binding.revision = try std.math.add(u64, binding.revision, 1);
    binding.activation = null;
}
pub fn required(engine: anytype, process: g.Process, sample: ?core.Time.Sample) !void {
    if (process.control) |control| {
        var current = try engine.state();
        for (control.required) |slot| if (slot) |name| {
            const association = (try current.get(g.Association, try catalog.key(.association, process.pid, 0, name.slice()))) orelse return error.MissingRequiredAssociation;
            if (!association.required) return error.MissingRequiredAssociation;
            try state.usable(engine, try state.resource(engine, association.resource), sample);
        };
    }
    try state.dependencies(engine, process.pid, sample);
}
pub fn apply(engine: anytype, candidate: anytype, request: g.Request, sample: ?core.Time.Sample) !void {
    const position = engine.head.position;
    if (request.command == .create) {
        const c = request.command.create;
        if ((c.process.work_before_ms == null) != (c.process.settle_before_ms == null)) return error.InvalidLifetime;
        if (c.process.work_before_ms) |cutoff| {
            if (c.process.settle_before_ms.? <= cutoff) return error.InvalidLifetime;
            try engine.before(sample, cutoff);
        }
        return candidate.put(growing.address(.process, position), g.Process{ .pid = position, .allow_collection = c.process.allow_collection, .code = c.process.code, .work_before_ms = c.process.work_before_ms, .settle_before_ms = c.process.settle_before_ms, .control = .{ .required = c.required } });
    }
    const pid = g.commandPid(request.command).?;
    var process = try engine.process(pid);
    if (process.lifecycle != .running) return error.RetiredProcess;
    if (request.command == .expire_suspension) {
        const control = process.control orelse return error.NoDeadline;
        if (control.phase != .suspended) return error.NoDeadline;
        const now = sample orelse return error.ClockUnavailable;
        try now.after(control.resume_before_ms.?);
        process.lifecycle = .expired;
        process.cancelled = process.admitted - process.consumed;
        try fence(&process);
        try candidate.put(growing.address(.process, pid), process);
        return state.retireIndexes(candidate, pid);
    }
    const generation = switch (request.command) {
        inline .initialize, .@"suspend", .@"resume" => |c| c.expected_generation,
        else => unreachable,
    };
    if (generation != process.generation) return error.StaleGeneration;
    if (process.work_before_ms) |deadline| try engine.before(sample, deadline);
    if (request.command == .@"resume") {
        const control = process.control orelse return error.InvalidLifecycle;
        if (control.phase != .suspended) return error.InvalidLifecycle;
        try engine.before(sample, control.resume_before_ms.?);
    }
    try required(engine, process, sample);
    switch (request.command) {
        .initialize => {
            const control = if (process.control) |*value| value else return error.InvalidLifecycle;
            if (control.phase != .initializing) return error.InvalidLifecycle;
            control.phase = .ready;
            try fence(&process);
        },
        .@"suspend" => |c| {
            try engine.executable(process, sample, false);
            if (process.turn_permit != null) return error.PendingWork;
            try engine.before(sample, c.resume_before_ms);
            if (process.work_before_ms) |deadline| if (c.resume_before_ms > deadline) return error.InvalidLifetime;
            // The proposed recovery window must fit every required resource.
            // This bounded graph walk neither extends a lease nor publishes state.
            try required(engine, process, .{ .unix_ms = c.resume_before_ms - 1 });
            if (process.control == null) process.control = .{ .phase = .ready };
            process.control.?.phase = .suspended;
            process.control.?.resume_before_ms = c.resume_before_ms;
            try fence(&process);
        },
        .@"resume" => {
            const control = if (process.control) |*value| value else return error.InvalidLifecycle;
            if (control.phase != .suspended) return error.InvalidLifecycle;
            try engine.before(sample, control.resume_before_ms.?);
            if (process.failure != null) return error.BlockedProcess;
            try restartBinding(&process, position);
            control.phase = .ready;
            control.resume_before_ms = null;
            try fence(&process);
        },
        else => unreachable,
    }
    try candidate.put(growing.address(.process, pid), process);
}
