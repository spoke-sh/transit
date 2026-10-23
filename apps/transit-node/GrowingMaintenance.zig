//! Bounded native maintenance. Its cursors are disposable hints;
//! only signed conditional transitions and committed floors authorize cleanup.
const std = @import("std");
const core = @import("transit_core");
const wire = @import("transit_client");
const observations = @import("transit_observability");
const g = wire.protocol.Growth;
pub const Config = struct {
    principal: u64,
    seed_file: []const u8,
    interval_ms: u32 = 1000,
    operation_timeout_ms: u32 = 5000,
    checkpoint_every_records: ?u64 = null,
    storage: core.protocol.Storage.Maintenance = .{},
};
const Progress = struct { scan: core.growing.Maintenance = .{}, maintained: u64 = 0, storage_turn: bool = false };
const Outcome = enum { idle, transition, checkpointed, trimmed, storage };
fn sample(engine: anytype) anyerror!?core.Time.Sample {
    const source = engine.clock orelse return null;
    return try source.sample();
}

fn step(comptime Provider: type, engine: *Provider.Engine, config: Config, key: core.Ed25519.KeyPair, progress: *Progress, observation: *observations.Observation) !Outcome {
    try engine.refresh();
    var request: g.Request = .{
        .realm = engine.genesis.realm,
        .principal = config.principal,
        .sequence = (try engine.principal(config.principal)).sequence + 1,
        .command = .{ .checkpoint = {} },
    };
    try engine.authorizeMaintenance(try g.sign(request, key));
    const subject = try engine.principal(config.principal);
    const needed = core.permission(.admin) | core.permission(.effect) | core.permission(.delivery);
    if (subject.grant.permissions & needed != needed or subject.grant.pid != null) return error.Forbidden;
    // Authentication may refresh after a competing publication. Rebuild only
    // this unpublished request; accepted work/receipts remain in the catalog.
    request.sequence = subject.sequence + 1;
    if (engine.head.history_floor > progress.maintained) {
        try engine.journal.maintain(engine.head);
        progress.maintained = engine.head.history_floor;
        return .trimmed;
    }
    // Alternate background storage work with lifecycle/control scans. Each
    // collection unit has its own durable cursor and shares this timeout budget.
    progress.storage_turn = !progress.storage_turn;
    if (progress.storage_turn and engine.clock != null) {
        if (try Provider.collect(engine, config, key, &request)) return .storage;
    }
    // Clock failure cannot disable already authorized physical maintenance or
    // terminal-source disposition. The scanner evaluates time only if needed.
    const clock = sample(engine);
    var scan_error: ?anyerror = null;
    const command = progress.scan.next(engine, clock) catch |err| failed: {
        scan_error = err;
        break :failed null;
    };
    if (command) |value| {
        request.command = value;
        observation.event.operation = @tagName(value);
        observation.event.pid = g.commandPid(value);
        const signed = try g.sign(request, key);
        if (value == .payload_deleted) {
            const prepared = try engine.prepare(signed);
            var state = try engine.state();
            const payload = (try state.get(g.Payload, core.growing.address(.payload, value.payload_deleted.payload))) orelse return error.UnknownPayload;
            try Provider.reclaimPayload(engine, payload);
            // Conflict or lost acknowledgement leaves the original durable
            // retirement intent for a later bounded scan and confirmed 404.
            _ = try engine.commit(prepared);
        } else _ = try engine.submit(signed);
        return .transition;
    }
    if (config.checkpoint_every_records) |interval| {
        if (engine.head.position - engine.head.history_floor >= interval) {
            _ = try engine.submit(try g.sign(request, key));
            return .checkpointed;
        }
    }
    if (scan_error) |err| return err;
    return .idle;
}
fn timeout(io: std.Io, milliseconds: u32) anyerror!void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
fn boundedStep(comptime Provider: type, io: std.Io, engine: *Provider.Engine, config: Config, key: core.Ed25519.KeyPair, progress: *Progress, observation: *observations.Observation) !Outcome {
    const Task = struct {
        fn run(e: @TypeOf(engine), c: Config, k: core.Ed25519.KeyPair, state: *Progress, o: *observations.Observation) anyerror!Outcome {
            return step(Provider, e, c, k, state, o);
        }
    };
    const Result = union(enum) { completed: anyerror!Outcome, timeout: anyerror!void };
    var results: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(io, &results);
    defer select.cancelDiscard(); // Join owned work before its state is reused.
    try select.concurrent(.timeout, timeout, .{ io, config.operation_timeout_ms });
    try select.concurrent(.completed, Task.run, .{ engine, config, key, progress, observation });
    return switch (try select.await()) {
        .completed => |value| value,
        .timeout => error.MaintenanceTimeout,
    };
}
pub fn run(comptime Provider: type, init: std.process.Init, engine: *Provider.Engine, config: Config, diagnostics: *observations.telemetry.Runtime) !void {
    if (config.storage.collection_every_records == 0 or config.storage.collection_every_records > core.protocol.max_counter or config.principal > core.protocol.max_counter or config.interval_ms == 0 or config.interval_ms > 60000 or
        config.operation_timeout_ms == 0 or config.operation_timeout_ms > 60000 or
        (config.checkpoint_every_records != null and (config.checkpoint_every_records.? < 2 or !engine.genesis.allow_history_trim))) return error.InvalidMaintenanceConfig;
    const key = try wire.readKey(init.gpa, init.io, config.seed_file);
    var progress: Progress = .{};
    while (true) {
        var observation = observations.begin(diagnostics, .maintenance_step, "scan", null);
        observation.event.realm = engine.genesis.realm;
        Provider.trace(engine, observation.span.context);
        defer Provider.trace(engine, null);
        const outcome = boundedStep(Provider, init.io, engine, config, key, &progress, &observation) catch |err| {
            observation.fail(err);
            observation.finish();
            if (err == error.Canceled) return err;
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        if (std.mem.eql(u8, observation.event.operation.?, "scan")) observation.event.operation = @tagName(outcome);
        observation.event.position = engine.head.position;
        observation.event.level = if (outcome == .idle) .debug else .info;
        observation.event.outcome = if (outcome == .idle) .idle else .ok;
        observation.finish();
        try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}
