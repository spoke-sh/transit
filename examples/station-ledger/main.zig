//! Reference Station caller. Credentials and provider placement stay outside
//! handlers; all state and messages use the public Transit protocol.
const std = @import("std");
const query = @import("transit_query");
const station = query.station;
const handler = @import("handler.zig");
const wire = station.client;
const telemetry = wire.observability.telemetry;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    pid: u64,
    generation: u64 = 0,
    seed_file: ?[]const u8 = null,
    association: []const u8 = "data",
    role: @FieldType(handler.Application, "role") = .ledger,
    destination: ?u64 = null,
    observer: ?u64 = null,
    registry: ?u64 = null,
    source_resource: ?u64 = null,
    peer_resource: ?u64 = null,
};

pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "example-station-ledger", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    diagnostics.event(.{ .name = "service.starting", .level = .info });
    defer diagnostics.event(.{ .name = "service.stopped", .level = .info });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const once = args.len == 3 and std.mem.eql(u8, args[1], "--once");
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    if (args.len != 2 and !once and !bootstrap) return error.ExpectedConfiguration;
    const bytes = if (bootstrap) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[if (once) 2 else 1], init.gpa, .limited(wire.max_body));
    defer if (!bootstrap) init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    var config = parsed.value;
    if (bootstrap and (config.seed_file != null or config.generation != 0)) return error.InvalidBootstrap;
    if (!bootstrap and config.seed_file == null) return error.MissingSeedFile;
    var key = if (config.seed_file) |path| try wire.readKey(init.gpa, init.io, path) else key: {
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :key try wire.protocol.Ed25519.KeyPair.generateDeterministic(seed);
    };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.observer = diagnostics;
    if (bootstrap) config.generation = try wire.bootstrap.awaitActivation(&client, config.realm, config.pid, config.principal, key);
    var behavior = try station.GenServer.init(.{
        .client = &client,
        .realm = config.realm,
        .principal = config.principal,
        .pid = config.pid,
        .generation = config.generation,
        .key = key,
    }, config.association);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&behavior.session.key));
    const resources: wire.ResourceReader = .{ .wire = &client, .realm = config.realm, .principal = config.principal, .key = key };
    var application: handler.Application = .{ .allocator = init.gpa, .resources = resources, .role = config.role, .destination = config.destination, .observer = config.observer, .registry = config.registry, .source_resource = config.source_resource, .peer_resource = config.peer_resource };
    const enabled = config.role == .ledger and config.destination != null;
    const adapter: []u8 = if (enabled) try init.gpa.alloc(u8, query.UnifiedBehavior.adapter_bytes) else &.{};
    defer if (enabled) init.gpa.free(adapter);
    const workspace: []u8 = if (enabled) try init.gpa.alloc(u8, query.fuze.Unified.Arrow.working_bytes) else &.{};
    defer if (enabled) init.gpa.free(workspace);
    const cancellation = query.fuze.execution.Cancellation.init(false);
    if (enabled) application.capture = .{ .adapter = adapter, .workspace = workspace, .cancellation = &cancellation };
    while (true) {
        const proposed_deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30_000);
        const result = behavior.step(application.behavior(), proposed_deadline) catch |err| switch (err) {
            error.AccessDenied, error.StaleActivation, error.ProcessExpired, error.ProcessTerminated, error.BlockedProcess, error.MissingStateAssociation, error.RequiredStateAssociation, error.InvalidStateAssociation, error.MissingStateResource => return err,
            else => {
                if (behavior.pending == null and (err == error.Rejected or err == error.Conflict)) {
                    if (client.last_rejection != .StaleStateResource and client.last_rejection != .QueryExpired and client.last_rejection != .StateViewExpired) return err;
                    if (client.last_rejection == .StateViewExpired) behavior.view_id = null;
                    if (behavior.ready != null) try behavior.discard();
                } else if (wire.Client.unavailable(err) and behavior.pending == null and behavior.ready != null) try behavior.discard();
                diagnostics.event(.{ .name = "station.retry", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
                try init.io.sleep(.fromMilliseconds(100), .awake);
                continue;
            },
        };
        switch (result) {
            .idle => if (once) return error.NoPendingInput else try init.io.sleep(.fromMilliseconds(50), .awake),
            .progress => {},
            .blocked => return behavior.handler_error orelse error.BlockedProcess,
            .committed => {
                diagnostics.event(.{ .name = "station.turn", .level = .info, .outcome = .ok });
                if (once) return;
            },
        }
    }
}
