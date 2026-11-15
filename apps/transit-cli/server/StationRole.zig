//! Private server child. Durable waits and child intent remain in Station;
//! this runner supplies trusted time, signed access checks and bounded polling.
const std = @import("std");
const q = @import("transit_query");
const Controller = q.station.Controller;
const Files = @import("Files.zig");
const telemetry = q.wire.observability.telemetry;
pub const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    mode: Controller.Mode,
    watches: []const Controller.Watch,
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
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfig;
    const config = try Files.read(Config, init.io, init.arena.allocator(), args[1]);
    if (config.interval_ms == 0 or config.interval_ms > 60000 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    var client = q.wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.observer = diagnostics;
    client.timeout_ms = config.request_timeout_ms;
    var controller: Controller = .{ .client = &client, .realm = config.realm, .principal = config.principal, .key = try q.wire.readKey(init.gpa, init.io, config.seed_file), .mode = config.mode, .watches = config.watches };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&controller.key));
    var gate: Gate = .{ .init = init, .config = config, .scratch = .init(init.gpa) };
    defer gate.scratch.deinit();
    if (config.local_stop != null) controller.retry_gate = .{ .context = &gate, .stopped = Gate.stopped };
    var status: Status = .{ .boot = config.boot, .ready = false, .completed_passes = 0 };
    try Files.json(init.io, init.gpa, config.status_file, status);
    defer {
        status.ready = false;
        Files.json(init.io, init.gpa, config.status_file, status) catch {};
    }
    var checked: ?std.Io.Timestamp = null;
    var failures: u8 = 0;
    var published: ?std.Io.Timestamp = null;
    while (true) {
        const now = std.Io.Clock.awake.now(init.io);
        const progress = advance(init, &controller, &checked, now) catch |err| {
            status.ready = false;
            status.error_name = @errorName(err);
            status.observed_ms = @intCast(std.Io.Clock.awake.now(init.io).toMilliseconds());
            _ = try Files.jsonIfChanged(init.io, init.gpa, config.status_file, status);
            diagnostics.event(.{ .name = "station.controller.retry", .level = .warn, .error_type = @errorName(err), .outcome = .failed });
            if (!q.wire.Client.unavailable(err) or err == error.AuthorityTransportDenied) return err;
            // Admission pressure establishes neither owner failure nor an
            // outcome for a pending mutation. Keep its exact signed request.
            if (client.last_rejection != .HttpCapacity and client.last_rejection != .ControlCapacity) {
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
            status.completed_passes = controller.completed_passes;
            status.observed_ms = @intCast(now.toMilliseconds());
            _ = try Files.jsonIfChanged(init.io, init.gpa, config.status_file, status);
            published = now;
        }
        if (!progress) try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}
fn advance(init: std.process.Init, controller: *Controller, checked: *?std.Io.Timestamp, now: std.Io.Timestamp) !bool {
    if (checked.* == null or checked.*.?.durationTo(now).toMilliseconds() >= 1000) {
        try controller.check();
        checked.* = now;
    }
    const wall = std.Io.Clock.real.now(init.io).toMilliseconds();
    if (wall <= 0 or wall > std.math.maxInt(u64)) return error.InvalidClock;
    return controller.step(@intCast(wall));
}
