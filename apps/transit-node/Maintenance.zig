//! Bounded, restartable maintenance in a separate trusted process. HTTP request
//! load cannot starve this scan, and scans never create authority by themselves.
const std = @import("std");
const transit = @import("transit");
const wire = @import("transit_client");

pub const Config = struct {
    principal: u8,
    seed_file: []const u8,
    interval_ms: u32 = 1000,
    operation_timeout_ms: u32 = 5000,
    checkpoint_every_records: ?u64 = null,
};
const Outcome = enum { idle, transition, checkpointed, trimmed };

fn step(engine: anytype, config: Config, key: transit.Ed25519.KeyPair, allocator: std.mem.Allocator, maintained: *u64) !Outcome {
    try engine.refresh();
    var time_error: ?anyerror = null;
    if (engine.clock) |source| {
        const due = blk: {
            const sample = source.sample() catch |err| {
                time_error = err;
                break :blk null;
            };
            break :blk engine.state.nextMaintenance(sample) catch |err| {
                time_error = err;
                break :blk null;
            };
        };
        if (due) |command| {
            _ = try engine.submit(try transit.sign(.{
                .realm = engine.state.realm,
                .principal = config.principal,
                .sequence = (try engine.state.principal(config.principal)).sequence + 1,
                .command = command,
            }, key));
            return .transition;
        }
    }
    // Resource retirement is independent of clock health. Only immutable,
    // positively published standalone payloads can enter deletion in M1.
    for (engine.state.payloads) |slot| if (slot) |payload| {
        const ref: transit.PayloadRef = .{ .pid = payload.pid, .payload = payload.id };
        const command: transit.Command = if (payload.phase == .ready and payload.allow_delete and
            (try engine.state.process(payload.pid)).lifecycle != .running)
            .{ .retire_payload = ref }
        else if (payload.phase == .retiring)
            .{ .payload_deleted = ref }
        else
            continue;
        const signed = try transit.sign(.{
            .realm = engine.state.realm,
            .principal = config.principal,
            .sequence = (try engine.state.principal(config.principal)).sequence + 1,
            .command = command,
        }, key);
        const prepared = try engine.prepare(signed);
        if (command == .payload_deleted) try engine.store.reclaimPayload(payload);
        // A conflict or lost acknowledgement leaves the committed retirement
        // intent available for the next scan; a confirmed 404 is idempotent.
        _ = try engine.commit(prepared);
        return .transition;
    };
    // A committed checkpoint intent survives every publication/trim crash.
    // Revalidate current rights before using the privileged storage adapter.
    const checkpoint_request: transit.Request = .{
        .realm = engine.state.realm,
        .principal = config.principal,
        .sequence = (try engine.state.principal(config.principal)).sequence + 1,
        .command = .{ .checkpoint = {} },
    };
    const signed = try transit.sign(checkpoint_request, key);
    try engine.state.authenticate(signed);
    try engine.state.authorize(checkpoint_request);
    if (engine.state.history_floor > maintained.*) {
        const checkpoint = try transit.Checkpoint.create(allocator, engine.genesis, &engine.state);
        try engine.store.maintain(&checkpoint);
        maintained.* = checkpoint.state.history_floor;
        return .trimmed;
    }
    if (config.checkpoint_every_records) |interval| {
        if (engine.state.position - engine.state.history_floor >= interval) {
            _ = engine.submit(signed) catch |err| switch (err) {
                error.PendingWork, error.HistoryPinned, error.RetentionNotEnabled, error.ControlAlreadyRecorded => return .idle,
                else => return err,
            };
            return .checkpointed;
        }
    }
    if (time_error) |err| return err;
    return .idle;
}

fn timeout(io: std.Io, milliseconds: u32) anyerror!void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}

fn boundedStep(io: std.Io, engine: anytype, config: Config, key: transit.Ed25519.KeyPair, allocator: std.mem.Allocator, maintained: *u64) !Outcome {
    const Task = struct {
        fn run(e: @TypeOf(engine), c: Config, k: transit.Ed25519.KeyPair, a: std.mem.Allocator, m: *u64) anyerror!Outcome {
            return step(e, c, k, a, m);
        }
    };
    const Result = union(enum) { completed: anyerror!Outcome, timeout: anyerror!void };
    var results: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(io, &results);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, timeout, .{ io, config.operation_timeout_ms });
    // Both sides must run concurrently even on a single-CPU runtime.
    try select.concurrent(.completed, Task.run, .{ engine, config, key, allocator, maintained });
    return switch (try select.await()) {
        .completed => |value| value,
        .timeout => error.MaintenanceTimeout,
    };
}

pub fn run(init: std.process.Init, engine: anytype, config: Config) !void {
    if (config.interval_ms == 0 or config.interval_ms > 60000 or
        config.operation_timeout_ms == 0 or config.operation_timeout_ms > 60000 or
        (config.checkpoint_every_records != null and config.checkpoint_every_records.? < 2)) return error.InvalidMaintenanceConfig;
    const key = try wire.readKey(init.gpa, init.io, config.seed_file);
    var maintained: u64 = 0;
    while (true) {
        const outcome = boundedStep(init.io, engine, config, key, init.gpa, &maintained) catch |err| {
            std.debug.print("maintenance: {s}\n", .{@errorName(err)});
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        if (outcome != .idle) std.debug.print("maintenance: {s}\n", .{@tagName(outcome)});
        try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}
