//! Stateless courier. Accepted decisions and retry identities live in Transit.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const g = p.Growth;
const observations = wire.observability;
const telemetry = observations.telemetry;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    interval_ms: u32 = 100,
    request_timeout_ms: u32 = 5000,
};

pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-delivery", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped", .level = .info });
    diagnostics.event(.{ .name = "service.starting", .level = .info });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const check = args.len == 3 and std.mem.eql(u8, args[2], "--check");
    const once = args.len == 3 and std.mem.eql(u8, args[2], "--once");
    if (args.len < 2 or args.len > 3 or (args.len == 3 and !check and !once)) return error.ExpectedConfigAndOptionalMode;
    const body = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(8192));
    defer init.gpa.free(body);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, body, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.principal == 0 or config.principal > p.max_counter or config.interval_ms == 0 or config.interval_ms > 60000 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    const key = try wire.readKey(init.gpa, init.io, config.seed_file);
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.timeout_ms = config.request_timeout_ms;
    client.observer = diagnostics;
    const query: g.Query = .{ .realm = config.realm, .principal = config.principal, .kind = .delivery };
    if (check) {
        _ = try client.query(query, key);
        return;
    }
    var pending: ?g.SignedRequest = null;
    while (true) {
        var observation = observations.begin(diagnostics, .delivery_step, "deliver", null);
        observation.event.realm = config.realm;
        client.parent_context = observation.span.context;
        defer client.parent_context = null;
        const progressed = wire.delivery.step(&client, query, key, &pending) catch |err| {
            observation.fail(err);
            observation.finish();
            // Access loss cannot be repaired by resubmitting with a different
            // identity. Ambiguous transport results retain the exact request.
            if (err == error.AccessDenied or err == error.Rejected or once) return err;
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        observation.event.level = if (progressed) .info else .debug;
        observation.event.outcome = if (progressed) .ok else .idle;
        observation.finish();
        if (once) return;
        try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}
