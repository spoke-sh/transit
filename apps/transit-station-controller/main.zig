const std = @import("std");
const station = @import("transit_station");
const wire = station.client;
const telemetry = wire.observability.telemetry;
const Config = struct { url: []const u8, realm: u64, principal: u64, seed_file: []const u8, mode: station.Controller.Mode, watches: []const station.Controller.Watch, interval_ms: u32 = 100, request_timeout_ms: u32 = 5000 };
pub fn main(init: std.process.Init) !void {
    const status = telemetry.runService(init, "transit-station-controller", .info, run);
    if (status != 0) std.process.exit(status);
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2 or args.len > 3 or (args.len == 3 and !std.mem.eql(u8, args[2], "--once"))) return error.ExpectedConfig;
    const once = args.len == 3;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(8192));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.interval_ms == 0 or config.interval_ms > 60000 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.observer = diagnostics;
    client.timeout_ms = config.request_timeout_ms;
    var controller: station.Controller = .{ .client = &client, .realm = config.realm, .principal = config.principal, .key = try wire.readKey(init.gpa, init.io, config.seed_file), .mode = config.mode, .watches = config.watches };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&controller.key));
    while (true) {
        const now = std.Io.Clock.real.now(init.io).toMilliseconds();
        if (now <= 0 or now > std.math.maxInt(u64)) return error.InvalidClock;
        const progress = controller.step(@intCast(now)) catch |err| {
            diagnostics.event(.{ .name = "station.controller.retry", .level = .warn, .error_type = @errorName(err), .outcome = .failed });
            if (err == error.AccessDenied or (err == error.Rejected and client.last_rejection != .QueryExpired and client.last_rejection != .Conflict) or once) return err;
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        if (progress and controller.pending == null) diagnostics.event(.{ .name = "station.controller.observation", .level = .info, .outcome = .ok });
        if (once and controller.pending == null and controller.completed_passes != 0) return;
        if (!progress) try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}
