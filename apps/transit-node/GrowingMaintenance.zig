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
pub fn Extension(comptime Provider: type) type {
    return struct {
        context: *anyopaque,
        step: *const fn (*anyopaque, *Provider.Engine, Config, g.SignedRequest) anyerror!bool,
    };
}
const StorageClass = enum { trim, collection, extension };
const Progress = struct {
    scan: core.growing.Maintenance = .{},
    maintained: u64 = 0,
    trim_target: ?core.growing.Head = null,
    storage_turn: bool = false,
    next_storage: StorageClass = .trim,
};
const Outcome = enum { idle, transition, checkpointed, trimmed, storage };
fn sample(engine: anytype) anyerror!?core.Time.Sample {
    const source = engine.clock orelse return null;
    return try source.sample();
}

fn step(comptime Provider: type, engine: *Provider.Engine, config: Config, key: core.Ed25519.KeyPair, progress: *Progress, observation: *observations.Observation, extension: ?Extension(Provider)) !Outcome {
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
    // Alternate background storage work with lifecycle/control scans. Each
    // selected unit shares this timeout budget. Incomplete physical trimming
    // cannot take every turn and starve accepted lifecycle/control work.
    progress.storage_turn = !progress.storage_turn;
    if (progress.storage_turn) {
        // Skip idle classes within a finite pass. Advance before I/O so a
        // failed or persistently busy class cannot monopolize the next turn.
        for (0..3) |_| {
            const selected = progress.next_storage;
            progress.next_storage = switch (selected) {
                .trim => .collection,
                .collection => .extension,
                .extension => .trim,
            };
            switch (selected) {
                .trim => {
                    if (progress.trim_target == null and engine.head.history_floor > progress.maintained) progress.trim_target = engine.head;
                    if (progress.trim_target) |target| {
                        if (try Provider.maintain(engine, target)) {
                            progress.maintained = target.history_floor;
                            progress.trim_target = null;
                        }
                        return .trimmed;
                    }
                },
                .collection => if (engine.clock != null) {
                    if (try Provider.collect(engine, config, key, &request)) return .storage;
                },
                .extension => if (extension) |extra| {
                    // Physical Table work needs no trusted expiry clock.
                    if (try extra.step(extra.context, engine, config, try g.sign(request, key))) return .storage;
                },
            }
        }
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
            try Provider.reclaimPayload(engine, payload, signed);
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
fn boundedStep(comptime Provider: type, io: std.Io, engine: *Provider.Engine, config: Config, key: core.Ed25519.KeyPair, progress: *Progress, observation: *observations.Observation, extension: ?Extension(Provider)) !Outcome {
    const Task = struct {
        fn run(e: @TypeOf(engine), c: Config, k: core.Ed25519.KeyPair, state: *Progress, o: *observations.Observation, extra: ?Extension(Provider)) anyerror!Outcome {
            return step(Provider, e, c, k, state, o, extra);
        }
    };
    const Result = union(enum) { completed: anyerror!Outcome, timeout: anyerror!void };
    var results: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(io, &results);
    defer select.cancelDiscard(); // Join owned work before its state is reused.
    try select.concurrent(.timeout, timeout, .{ io, config.operation_timeout_ms });
    try select.concurrent(.completed, Task.run, .{ engine, config, key, progress, observation, extension });
    return switch (try select.await()) {
        .completed => |value| value,
        .timeout => error.MaintenanceTimeout,
    };
}
pub fn run(comptime Provider: type, init: std.process.Init, engine: *Provider.Engine, config: Config, diagnostics: *observations.telemetry.Runtime, extension: ?Extension(Provider)) !void {
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
        const outcome = boundedStep(Provider, init.io, engine, config, key, &progress, &observation, extension) catch |err| {
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

test "unfinished or failed native trim cannot starve lifecycle and other storage classes" {
    const t = std.testing;
    const backend = @import("transit_backend_local");
    const Provider = struct {
        pub const Engine = backend.DataAuthority.Engine;
        var trims: usize = 0;
        var collections: usize = 0;
        var extensions: usize = 0;
        var fail_trim = false;
        fn maintain(_: *Engine, target: core.growing.Head) !bool {
            try t.expect(target.history_floor != 0);
            trims += 1;
            if (fail_trim) return error.InjectedTrimFailure;
            return false; // Deliberately never completes during this schedule.
        }
        fn collect(_: *Engine, _: Config, _: core.Ed25519.KeyPair, _: *g.Request) !bool {
            collections += 1;
            return true;
        }
        fn extra(_: *anyopaque, engine: *Engine, _: Config, signed: g.SignedRequest) !bool {
            try engine.authorizeMaintenance(signed);
            extensions += 1;
            return true;
        }
        fn reclaimPayload(_: *Engine, _: g.Payload, _: g.SignedRequest) !void {
            return error.UnexpectedPayload;
        }
        fn clock(_: *anyopaque) !core.Time.Sample {
            return .{ .unix_ms = 100 };
        }
    };
    Provider.trims = 0;
    Provider.collections = 0;
    Provider.extensions = 0;
    Provider.fail_trim = false;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    const key = try core.Ed25519.KeyPair.generateDeterministic(@splat(17));
    var engine = try Provider.Engine.bootstrap(&journal, &pages, .{ .realm = 42, .root_key = key.public_key.toBytes(), .max_clock_error_ms = 5, .allow_history_trim = true });
    var context: u8 = 0;
    engine.clock = .{ .context = &context, .read = Provider.clock };
    _ = try engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{} } }, key));
    _ = try engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = 2, .command = .{ .checkpoint = {} } }, key));
    const accepted = engine.head.position;
    var progress: Progress = .{};
    var observation = observations.begin(null, .maintenance_step, "scan", null);
    defer observation.finish();
    const config: Config = .{ .principal = 0, .seed_file = "unused-by-step" };
    const extension: Extension(Provider) = .{ .context = &context, .step = Provider.extra };
    var lifecycle_turns: usize = 0;
    for (0..6) |_| {
        if (try step(Provider, &engine, config, key, &progress, &observation, extension) == .idle) lifecycle_turns += 1;
    }
    try t.expect(lifecycle_turns != 0);
    try t.expect(Provider.trims != 0 and Provider.collections != 0 and Provider.extensions != 0);
    try t.expectEqual(@as(u64, 0), progress.maintained);
    try t.expectEqual(accepted, engine.head.position);
    Provider.fail_trim = true;
    try t.expectError(error.InjectedTrimFailure, step(Provider, &engine, config, key, &progress, &observation, extension));
    try t.expectEqual(.idle, try step(Provider, &engine, config, key, &progress, &observation, extension));
    const collections = Provider.collections;
    _ = try step(Provider, &engine, config, key, &progress, &observation, extension);
    try t.expect(Provider.collections > collections);
}
