//! Provider evidence is durable authority data, never permission to execute.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const growing = @import("growing.zig");
const catalog = @import("catalog.zig");

fn resourceKey(instance: [16]u8, resource: [32]u8) !core.pages.Key {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(&instance);
    hash.update(&resource);
    return catalog.key(.runtime_resource, 0, 0, &hash.finalResult());
}

pub fn apply(engine: anytype, candidate: anytype, next: *growing.Head, request: g.Request, sample: ?core.Time.Sample) !void {
    const pid = switch (request.command) {
        inline .runtime_intent, .runtime_observe, .runtime_upgrade, .activate => |c| c.pid,
        else => unreachable,
    };
    var process = try engine.process(pid);
    const position = engine.head.position;
    switch (request.command) {
        .runtime_intent => |c| {
            if (c.desired == .running) try engine.executable(process, sample, true);
            const previous = process.binding;
            if (c.expected_revision != (if (previous) |old| old.revision else @as(u64, 0))) return error.StaleBinding;
            if (previous) |old| {
                if (old.phase == .pending or old.phase == .unknown or old.upgrade_from != null) return error.PendingProviderOperation;
                if (!std.meta.eql(c.instance, old.instance) or !std.meta.eql(c.resource, old.resource) or !std.meta.eql(c.workload, old.workload)) return error.BindingReplacementUnsupported;
            }
            if (std.mem.allEqual(u8, &c.instance, 0) or std.mem.allEqual(u8, &c.resource, 0) or std.mem.allEqual(u8, &c.workload, 0)) return error.InvalidBinding;
            const key = try resourceKey(c.instance, c.resource);
            if (try candidate.get(u64, key)) |owner| if (owner != pid) return error.ResourceAlreadyBound;
            // The reservation remains after retirement: provider names cannot
            // resurrect a different PID or take over its recorded destination.
            try candidate.put(key, pid);
            process.binding = .{
                .revision = try std.math.add(u64, c.expected_revision, 1),
                .operation = position,
                .instance = c.instance,
                .resource = c.resource,
                .workload = c.workload,
                .incarnation = if (previous) |old| old.incarnation else null,
                .desired = if (c.desired == .running) .running else .stopped,
                .last_worker_incarnation = if (previous) |old| old.last_worker_incarnation else null,
            };
            process.owner = null;
            process.generation = try std.math.add(u64, process.generation, 1);
        },
        .runtime_upgrade => |c| {
            try engine.executable(process, sample, false);
            const binding = if (process.binding) |*value| value else return error.InvalidBinding;
            if (binding.revision != c.expected_revision or !std.meta.eql(binding.workload, c.expected_workload)) return error.StaleBinding;
            if (binding.phase != .stopped or binding.desired != .stopped or binding.incarnation == null or binding.upgrade_from != null or process.owner != null or binding.activation != null) return error.ProviderNotReady;
            if (c.expected_state_revision != process.revision) return error.StaleState;
            if (c.expected_code != process.code or std.meta.eql(c.workload, binding.workload) or std.mem.allEqual(u8, &c.workload, 0)) return error.UnsupportedWorkload;
            binding.upgrade_from = binding.workload;
            binding.workload = c.workload;
            binding.revision = try std.math.add(u64, binding.revision, 1);
            binding.operation = position;
            binding.phase = .pending;
            process.generation = try std.math.add(u64, process.generation, 1);
        },
        .runtime_observe => |c| {
            const binding = if (process.binding) |*value| value else return error.InvalidBinding;
            if (c.revision != binding.revision or c.operation != binding.operation) return error.StaleBinding;
            if (binding.phase != .pending and binding.phase != .unknown) return error.ProviderOperationClosed;
            if (binding.upgrade_from != null and (c.outcome == .ready or c.incarnation == null)) return error.InvalidBinding;
            if (c.incarnation) |id| {
                if (std.mem.allEqual(u8, &id, 0)) return error.InvalidBinding;
                if (binding.incarnation) |old| if (!std.meta.eql(old, id)) return error.ProviderIncarnationMismatch;
                binding.incarnation = id;
            }
            switch (c.outcome) {
                .unknown => binding.phase = .unknown,
                .ready => {
                    if (binding.desired != .running or c.incarnation == null) return error.InvalidBinding;
                    binding.phase = .ready;
                },
                .stopped => {
                    if (binding.desired != .stopped and process.lifecycle == .running) return error.InvalidBinding;
                    binding.phase = .stopped;
                    binding.upgrade_from = null;
                },
            }
        },
        .activate => |c| {
            try engine.executable(process, sample, true);
            const binding = if (process.binding) |*value| value else return error.InvalidBinding;
            if (c.revision != binding.revision) return error.StaleBinding;
            if (binding.desired != .running or binding.phase != .ready or binding.incarnation == null) return error.ProviderNotReady;
            if (binding.activation != null) return error.AlreadyActivated;
            if (binding.last_worker_incarnation) |old| if (std.meta.eql(old, c.worker_incarnation)) return error.StaleWorkerIncarnation;
            if (c.expected_generation != process.generation) return error.StaleGeneration;
            if (c.worker == 0 or std.mem.allEqual(u8, &c.worker_incarnation, 0)) return error.InvalidGrant;
            const worker = try engine.principal(c.worker);
            const rights = p.permission(.execute) | p.permission(.inspect);
            if (worker.grant.pid != pid or worker.grant.permissions & rights != rights) return error.Forbidden;
            if (std.meta.eql(worker.grant.public_key, c.public_key)) return error.FreshKeyRequired;
            _ = try p.Ed25519.PublicKey.fromBytes(c.public_key);
            // Preserve the bound role, resource grants and request sequence.
            try @import("growing_authorization.zig").rotate(engine, next, c.worker, c.public_key);
            process.generation = try std.math.add(u64, process.generation, 1);
            process.owner = c.worker;
            binding.activation = .{ .worker_incarnation = c.worker_incarnation, .generation = process.generation };
            binding.last_worker_incarnation = c.worker_incarnation;
        },
        else => unreachable,
    }
    try candidate.put(growing.address(.process, pid), process);
}
