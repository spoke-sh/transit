//! Real application worker. The provider supplies physical placement only.
const std = @import("std");
const W = @import("work_items");
const s = W.app.station;
const p = W.app.protocol;
const telemetry = s.client.observability.telemetry;
pub const Configuration = struct {
    url: []const u8,
    principal: u64,
    pid: u64,
    generation: u64,
    seed_file: ?[]const u8 = null,
    activation_directory: []const u8,
    application: W.Configuration,
    query_peer: ?u64 = null,
    publication: ?W.app.Publication.Configuration = null,
    request_timeout_ms: u32 = 3000,
};
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-work-items", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    if (args.len != 2 and !bootstrap) return error.ExpectedConfiguration;
    const bytes = if (bootstrap) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(16384));
    if (bytes.len > 16384) return error.ConfigurationTooLarge;
    const config = (try p.Json.parseFromSlice(Configuration, init.arena.allocator(), bytes)).value;
    if (config.query_peer != null and config.publication != null) return error.ConflictingWorkerRoles;
    if (config.publication) |publication| if (publication.realm != config.application.realm or publication.application != config.application.application) return error.InvalidConfiguration;
    if (config.pid == 0 or config.generation == 0 or config.principal == 0 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    var key = if (bootstrap) value: {
        if (config.seed_file != null) return error.InvalidBootstrap;
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :value try p.Ed25519.KeyPair.generateDeterministic(seed);
    } else try s.client.readKey(init.gpa, init.io, config.seed_file orelse return error.MissingSeedFile);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var wire = s.client.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = config.request_timeout_ms;
    wire.observer = diagnostics;
    if (bootstrap) try s.client.bootstrap.awaitGrowingOwnership(&wire, .{ .realm = config.application.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .public_key = key.public_key.toBytes() }, key, 120000);
    var host = try s.GrowingGenServer.init(.{ .client = &wire, .realm = config.application.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, "state");
    _ = try host.session.receive();
    const marker = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{d}-{d}-{d}.activation", .{ config.activation_directory, config.application.realm, config.pid, config.generation });
    const file = std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired;
        return err;
    };
    file.close(init.io);
    var behavior: W.Behavior = .{ .owner = .{ .configuration = config.application } };
    const adapter: []u8 = if (config.query_peer != null) try init.gpa.alloc(u8, W.query.UnifiedBehavior.adapter_bytes) else &.{};
    defer if (adapter.len != 0) init.gpa.free(adapter);
    const workspace: []u8 = if (config.query_peer != null) try init.gpa.alloc(u8, W.query.fuze.Unified.Arrow.working_bytes) else &.{};
    defer if (workspace.len != 0) init.gpa.free(workspace);
    const cancellation = W.query.fuze.execution.Cancellation.init(false);
    if (config.query_peer) |peer| behavior.capture = .{ .peer = peer, .initializer = config.application.administrator, .resources = .{ .wire = &wire, .realm = config.application.realm, .principal = config.principal, .key = key }, .adapter = adapter, .workspace = workspace, .cancellation = &cancellation };
    var publication: W.app.Behavior = .{ .allocator = init.gpa, .owner = .{ .configuration = config.publication orelse undefined } };
    host.input_guard = if (config.publication != null) publication.guard() else behavior.guard();
    const handler = if (config.publication != null) publication.interface() else behavior.interface();
    diagnostics.event(.{ .name = "service.ready", .operation = if (config.publication != null) "interface" else "data", .pid = config.pid, .generation = config.generation });
    while (true) {
        const now: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds());
        const step = host.step(handler, now + 30000) catch |err| {
            diagnostics.event(.{ .name = "worker.step", .level = .warn, .outcome = if (host.pending != null) .uncertain else .failed, .error_type = @errorName(err) });
            if (s.client.Client.unavailable(err)) {
                if (host.pending == null and host.ready != null) try host.discard();
            } else if (host.pending == null and (err == error.Conflict or err == error.Rejected) and (wire.last_rejection == .StaleStateResource or wire.last_rejection == .QueryExpired or wire.last_rejection == .StateViewExpired)) {
                if (wire.last_rejection == .StateViewExpired) host.view_id = null;
            } else if (host.pending == null or err == error.AccessDenied or err == error.StaleActivation or err == error.Rejected or err == error.Conflict) return err;
            try std.Io.sleep(init.io, .fromMilliseconds(100), .awake);
            continue;
        };
        switch (step) {
            .idle => try std.Io.sleep(init.io, .fromMilliseconds(25), .awake),
            .blocked => return host.handler_error orelse error.WorkItemBlocked,
            .progress, .committed => {},
        }
    }
}
