//! Private server child. Durable waits and child intent remain in Station;
//! this runner supplies trusted time, signed access checks and bounded polling.
const std = @import("std");
const q = @import("transit_query");
const tx_station = @import("station_transaction_internal");
const Controller = q.station.Controller;
const TxController = tx_station.ServiceController;
const Files = @import("Files.zig");
const telemetry = q.wire.observability.telemetry;

pub const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    mode: Controller.Mode,
    watches: []const Controller.Watch = &.{},
    transactional: []const TxController.Watch = &.{},
    lease_ms: u64 = 30000,
    interval_ms: u32 = 100,
    request_timeout_ms: u32 = 2000,
    status_file: []const u8,
    boot: [16]u8,
    local_stop: ?[]const u8 = null,
};

pub const Stop = struct { boot: [16]u8, pid: u64, generation: u64, failure: u64 };

const Gate = struct {
    init: std.process.Init,
    config: Config,
    scratch: std.heap.ArenaAllocator,
    fn stopped(context: *anyopaque, process: q.protocol.Growth.Process) anyerror!bool {
        const self: *Gate = @ptrCast(@alignCast(context));
        defer _ = self.scratch.reset(.retain_capacity);
        const allocator = self.scratch.allocator();
        const request: Stop = .{ .boot = self.config.boot, .pid = process.pid, .generation = process.generation, .failure = process.failure.? };
        const directory = self.config.local_stop.?;
        const response = Files.read(Stop, self.init.io, allocator, try std.fs.path.join(allocator, &.{ directory, "stopped.json" })) catch |err| blk: {
            if (err != error.FileNotFound) return err;
            break :blk null;
        };
        if (response) |value| if (std.meta.eql(value, request)) return true;
        _ = try Files.jsonIfChanged(self.init.io, allocator, try std.fs.path.join(allocator, &.{ directory, "stop.json" }), request);
        return false;
    }
};

pub const Status = struct { boot: [16]u8, ready: bool, completed_passes: u64, observed_ms: i64 = 0, error_name: ?[]const u8 = null };

pub fn main(init: std.process.Init) !void {
    const status = telemetry.runService(init, "transit-station-service", .info, run);
    if (status != 0) std.process.exit(status);
}

fn bootInstance(boot: [16]u8) u64 {
    return std.mem.readInt(u64, boot[0..8], .little) | 1;
}

fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfig;
    const config = try Files.read(Config, init.io, init.arena.allocator(), args[1]);
    if (config.interval_ms == 0 or config.interval_ms > 60000 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000 or
        config.lease_ms == 0 or ((config.watches.len > 0) == (config.transactional.len > 0)))
        return error.InvalidConfiguration;

    var client = q.wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.observer = diagnostics;
    client.timeout_ms = config.request_timeout_ms;

    var data_client = q.wire.Client.init(init.gpa, init.io, config.url);
    defer data_client.deinit();
    data_client.observer = diagnostics;
    data_client.timeout_ms = config.request_timeout_ms;

    var gate: Gate = .{ .init = init, .config = config, .scratch = .init(init.gpa) };
    defer gate.scratch.deinit();

    const is_tx = config.transactional.len > 0;
    var legacy_controller: ?Controller = if (!is_tx) .{
        .client = &client,
        .realm = config.realm,
        .principal = config.principal,
        .key = try q.wire.readKey(init.gpa, init.io, config.seed_file),
        .mode = config.mode,
        .watches = config.watches,
    } else null;
    defer if (legacy_controller) |*ctrl| std.crypto.secureZero(u8, std.mem.asBytes(&ctrl.key));

    var tx_controller: ?TxController = if (is_tx) try TxController.init(
        init.gpa,
        &client,
        &data_client,
        config.realm,
        config.principal,
        try q.wire.readKey(init.gpa, init.io, config.seed_file),
        switch (config.mode) {
            .observe => .observe,
            .lifecycle => .lifecycle,
        },
        config.transactional,
        config.lease_ms,
        bootInstance(config.boot),
    ) else null;
    defer if (tx_controller) |*ctrl| ctrl.deinit();

    if (config.local_stop != null) {
        if (legacy_controller) |*ctrl| ctrl.retry_gate = .{ .context = &gate, .stopped = Gate.stopped };
        if (tx_controller) |*ctrl| ctrl.retry_gate = .{ .context = &gate, .stopped = Gate.stopped };
    }

    var status: Status = .{ .boot = config.boot, .ready = false, .completed_passes = 0 };
    try Files.json(init.io, init.gpa, config.status_file, status);
    defer {
        status.ready = false;
        Files.json(init.io, init.gpa, config.status_file, status) catch {};
    }

    var checked: ?std.Io.Timestamp = null;
    var failures: u8 = 0;
    var published: ?std.Io.Timestamp = null;
    const pure_timer_wait = is_tx and config.mode == .observe and config.transactional.len == 1 and
        config.transactional[0].timers != null and config.transactional[0].child == null;

    while (true) {
        const now = std.Io.Clock.awake.now(init.io);
        const progress = advance(init, if (legacy_controller) |*c_ref| c_ref else null, if (tx_controller) |*t_ref| t_ref else null, config.interval_ms, &checked, now) catch |err| {
            status.ready = false;
            status.error_name = @errorName(err);
            status.observed_ms = @intCast(std.Io.Clock.awake.now(init.io).toMilliseconds());
            _ = try Files.jsonIfChanged(init.io, init.gpa, config.status_file, status);
            diagnostics.event(.{ .name = "station.controller.retry", .level = .warn, .error_type = @errorName(err), .outcome = .failed });
            const transient = (q.wire.Client.unavailable(err) or err == error.AuthorityUnavailable) and err != error.AuthorityTransportDenied;
            if (!transient) return err;
            // Admission pressure establishes neither owner failure nor an
            // outcome for a pending mutation. Keep its exact signed request.
            const capacity_refusal = client.last_rejection == .HttpCapacity or client.last_rejection == .ControlCapacity or
                data_client.last_rejection == .HttpCapacity or data_client.last_rejection == .ControlCapacity;
            if (!capacity_refusal) {
                if (failures == 2) return err;
                failures += 1;
            }
            checked = null;
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        failures = 0;
        const recovered = !status.ready;
        status.ready = true;
        status.error_name = null;
        if (recovered or published == null or published.?.durationTo(now).toMilliseconds() >= 1000) {
            status.completed_passes = if (legacy_controller) |ctrl| ctrl.completed_passes else tx_controller.?.completed_passes;
            status.observed_ms = @intCast(now.toMilliseconds());
            _ = try Files.jsonIfChanged(init.io, init.gpa, config.status_file, status);
            published = now;
        }
        if (!progress and !pure_timer_wait) try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}

fn advance(
    init: std.process.Init,
    legacy: ?*Controller,
    transactional: ?*TxController,
    interval_ms: u32,
    checked: *?std.Io.Timestamp,
    now: std.Io.Timestamp,
) !bool {
    if (checked.* == null or checked.*.?.durationTo(now).toMilliseconds() >= 1000) {
        if (legacy) |ctrl| try ctrl.check();
        if (transactional) |ctrl| try ctrl.check();
        checked.* = now;
    }
    if (legacy) |ctrl| {
        const wall = std.Io.Clock.real.now(init.io).toMilliseconds();
        if (wall <= 0 or wall > std.math.maxInt(u64)) return error.InvalidClock;
        return ctrl.step(@intCast(wall));
    }
    const wait_ms: u32 = @min(interval_ms, 1000);
    return transactional.?.step(wait_ms);
}
