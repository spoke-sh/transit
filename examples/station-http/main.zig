//! A finite synthetic caller. Configuration and source bytes are local inputs;
//! publication progress, call identity and the received outcome are durable state.
const std = @import("std");
const http = @import("transit_station_http");
const x = http.exchange;
const s = x.station;
const p = s.protocol;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    pid: u64,
    generation: u64,
    seed_file: ?[]const u8 = null,
    worker: u64,
    namespace: u64 = 1,
    endpoint_revision: u64 = 1,
    reconcile_before_ms: u64,
    request: http.Request,
    body_file: ?[]const u8 = null,
    body: ?p.Value = null,
    bootstrap_timeout_ms: u32 = 120000,
    park_after_result_ms: u32 = 0,
    mode: enum { publish, receive, replay },
};
const call_key = p.Value.init("http-call") catch unreachable;
const outcome_key = p.Value.init("http-outcome") catch unreachable;
const Driver = x.Caller(http, .{ .call_key = call_key, .outcome_key = outcome_key, .tick = "example.http.tick.v1" });
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    if (args.len != 2 and !bootstrap) return error.ExpectedConfiguration;
    const gpa = init.arena.allocator();
    const bytes = if (bootstrap) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], gpa, .limited(65536));
    if (bytes.len > 65536) return error.ConfigurationTooLarge;
    const config = (try std.json.parseFromSlice(Config, gpa, bytes, .{})).value;
    if (config.principal == 0 or config.pid == 0 or config.worker == 0 or config.generation == 0) return error.InvalidConfiguration;
    if (config.park_after_result_ms > 300000 or (!bootstrap and config.park_after_result_ms != 0)) return error.InvalidConfiguration;
    if ((config.body_file == null) == (config.body == null)) return error.ExpectedOneBodySource;
    const body = if (config.body) |*value| value.slice() else try std.Io.Dir.cwd().readFileAlloc(init.io, config.body_file.?, gpa, .limited(http.RequestRecord.maximum_body_bytes));
    var key = if (bootstrap) key: {
        if (config.seed_file != null) return error.BootstrapSeedForbidden;
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :key try p.Ed25519.KeyPair.generateDeterministic(seed);
    } else try s.client.readKey(gpa, init.io, config.seed_file orelse return error.MissingSeedFile);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var wire = s.client.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    if (bootstrap) try s.client.bootstrap.awaitGrowingOwnership(&wire, .{ .realm = config.realm, .pid = config.pid, .principal = config.principal, .generation = config.generation, .public_key = key.public_key.toBytes() }, key, config.bootstrap_timeout_ms);
    var server = try s.GrowingGenServer.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, "state");
    server.failure_policy = .stop;
    const resource = (try server.session.association(try p.Value.init("state"))) orelse return error.MissingStateAssociation;
    var metadata: [8192]u8 = undefined;
    var driver: Driver = .{ .server = server, .reader = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key }, .peer = config.worker, .io = init.io, .prepared = try http.RequestRecord.prepare(resource.resource, config.namespace, config.request, body, config.endpoint_revision, config.reconcile_before_ms, 1, &metadata), .content = body };
    var buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (config.mode == .publish) {
        // Resume interrupted upload using the same immutable input. No socket or
        // credential resolver exists in this caller.
        for (0..320) |_| {
            if (try driver.read(call_key) != null) break;
            if (try driver.server.session.receive() != null) try driver.drive() else try driver.tick();
        } else return error.PublicationBudgetExceeded;
        const saved = (try driver.read(call_key)).?;
        const reference = (try driver.read(http.RequestRecord.key(config.namespace))) orelse return error.MissingRequest;
        if (saved.len != 16 or std.mem.readInt(u64, saved.data[0..8], .little) != config.worker or !reference.eql(try driver.prepared.reference.encode())) return error.ChangedCallConfiguration;
        try output.interface.print("{{\"phase\":\"called\",\"peer\":\"{d}\",\"correlation\":\"{d}\"}}\n", .{ std.mem.readInt(u64, saved.data[0..8], .little), std.mem.readInt(u64, saved.data[8..16], .little) });
    } else {
        if (config.mode == .receive) {
            for (0..32) |_| {
                if (try driver.read(outcome_key) != null) break;
                try driver.drive();
            } else return error.OutcomeNotDelivered;
        }
        const outcome = try http.Service.Outcome.decode((try driver.read(outcome_key)) orelse return error.OutcomeNotDelivered);
        if (config.mode == .replay) {
            var replay = try http.Replay.open(&driver.reader, try outcome.reference(), .captured);
            var hash = std.crypto.hash.sha2.Sha256.init(.{});
            var count: u64 = 0;
            while (try replay.read()) |part| {
                if (part.kind == .response_body) {
                    hash.update(part.bytes.slice());
                    count += part.bytes.len;
                }
                if (part.complete) break;
            }
            if (!replay.done) return error.IncompleteExchange;
            try output.interface.print("{{\"phase\":\"replayed\",\"body_bytes\":{d},\"sha256\":\"{x}\"}}\n", .{ count, hash.finalResult() });
        } else {
            try std.json.Stringify.value(outcome, .{}, &output.interface);
            try output.interface.writeByte('\n');
        }
    }
    try output.interface.flush();
    if (config.park_after_result_ms != 0) try init.io.sleep(.fromMilliseconds(config.park_after_result_ms), .awake);
}
