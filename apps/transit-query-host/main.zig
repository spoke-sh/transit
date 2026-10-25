const std = @import("std");
const q = @import("transit_query");
const serving = @import("transit_serving");
const catalog = @import("transit_catalog");
const telemetry = q.wire.observability.telemetry;
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: ?[]const u8 = null,
    bootstrap_timeout_ms: u32 = 120000,
    pid: u64 = 0,
    generation: u64 = 0,
    association: []const u8 = "state",
    activation_directory: ?[]const u8 = null,
    interval_ms: u32 = 10,
    idle_max_interval_ms: u32 = 0,
    request_timeout_ms: u32 = 5000,
    tables: ?q.UnifiedBehavior.TableEndpoint = null,
    role: union(enum) {
        finite_service: serving.FiniteService.Configuration,
        unified_source: struct { peer: u64, initializer: u64 },
        unified_requester: q.UnifiedBehavior.Requester,
        courier: struct { destinations: []const u64 = &.{}, all_destinations: bool = false },
    },
};
pub fn main(init: std.process.Init) !void {
    const status = telemetry.runService(init, "transit-query-host", .info, run);
    if (status != 0) std.process.exit(status);
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    if (args.len != 2 and !bootstrap) return error.ExpectedConfiguration;
    const bytes = if (bootstrap) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(8192));
    if (bytes.len > 8192) return error.ConfigurationTooLarge;
    const parsed = try q.Values.parse(Config, init.gpa, bytes);
    defer parsed.deinit();
    var config = parsed.value;
    if (config.principal == 0 or config.principal > p.max_counter or config.realm == 0 or config.interval_ms == 0 or config.interval_ms > 60000 or config.idle_max_interval_ms > 60000 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    var key = if (bootstrap) key: {
        if (config.seed_file != null or config.role == .courier) return error.InvalidBootstrapConfiguration;
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :key try p.Ed25519.KeyPair.generateDeterministic(seed);
    } else try q.wire.readKey(init.gpa, init.io, config.seed_file orelse return error.MissingSeedFile);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var wire = q.wire.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = config.request_timeout_ms;
    var table_wire: ?q.wire.Client = if (config.tables) |tables| q.wire.Client.init(init.gpa, init.io, tables.url) else null;
    defer if (table_wire) |*client| client.deinit();
    const direct_tables: ?catalog.DirectTableClient = if (config.tables) |tables| table: {
        if (tables.scope.realm != config.realm or config.role != .unified_source) return error.InvalidConfiguration;
        table_wire.?.timeout_ms = config.request_timeout_ms;
        const connection: catalog.DirectTableProtocol.Connection = .{ .scope = tables.scope, .branch = tables.branch, .audience = tables.audience, .principal = config.principal, .role = null };
        try connection.validate();
        break :table .{ .allocator = init.gpa, .authority = &wire, .service = &table_wire.?, .connection = connection, .key = key };
    } else null;
    wire.observer = diagnostics;
    if (config.role == .courier) return courier(init, &wire, config, key);
    if (config.pid == 0 or config.generation == 0) return error.MissingActivation;
    if (bootstrap) try q.wire.bootstrap.awaitGrowingOwnership(&wire, .{ .realm = config.realm, .pid = config.pid, .principal = config.principal, .generation = config.generation, .public_key = key.public_key.toBytes() }, key, config.bootstrap_timeout_ms);
    var server = try s.GenServer.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, config.association);
    // Check current ownership before recording that this activation has run.
    const starting = std.Io.Clock.awake.now(init.io);
    while (true) {
        _ = server.session.receive() catch |err| {
            if ((!q.wire.Client.unavailable(err) and !wire.contended(err)) or starting.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= config.request_timeout_ms) return err;
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        break;
    }
    const directory = config.activation_directory orelse return error.MissingActivationDirectory;
    const marker = try std.fmt.allocPrint(init.gpa, "{s}/{d}-{d}-{d}.activation", .{ directory, config.realm, config.pid, config.generation });
    defer init.gpa.free(marker);
    const file = std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired;
        return err;
    };
    file.close(init.io);
    const workspace = try init.gpa.alloc(u8, q.fuze.LogicalArrow.working_bytes);
    defer init.gpa.free(workspace);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    server.failure_policy = .stop;
    const adapter = try init.gpa.alloc(u8, if (config.role == .unified_source) q.UnifiedBehavior.adapter_bytes else 0);
    defer init.gpa.free(adapter);
    var unified_source: q.UnifiedBehavior.Source = .{
        .peer = switch (config.role) {
            .unified_source => |value| value.peer,
            else => 0,
        },
        .initializer = switch (config.role) {
            .unified_source => |value| value.initializer,
            else => 0,
        },
        .resources = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key },
        .tables = direct_tables,
        .adapter = adapter,
        .workspace = workspace,
        .cancellation = &cancellation,
    };
    var finite: serving.FiniteService = .{ .configuration = if (config.role == .finite_service) config.role.finite_service else undefined };
    const handler = switch (config.role) {
        .finite_service => blk: {
            server.input_guard = finite.guard();
            break :blk finite.interface();
        },
        .unified_source => unified_source.interface(),
        .unified_requester => |*requester| requester.interface(),
        .courier => unreachable,
    };
    diagnostics.event(.{ .name = "service.ready", .operation = @tagName(config.role), .realm = config.realm, .pid = config.pid, .generation = config.generation });
    var idle_ms = config.interval_ms;
    while (true) {
        const now: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds());
        var observation = diagnostics.begin(.application, null);
        wire.parent_context = observation.context;
        defer wire.parent_context = null;
        const step = server.step(handler, now + 30000) catch |err| {
            observation.finish(.{ .name = "query.worker.step", .operation = @tagName(config.role), .level = .warn, .outcome = if (server.pending != null) .uncertain else .failed, .error_type = @errorName(err) });
            // An ambiguous mutation retains exact bytes in server.pending. Never
            // discard/recompute it under this activation. A restarted OS worker
            // requires fresh fenced ownership, even if it exited while idle.
            if (server.pending == null and (err == error.Conflict or err == error.Rejected) and (wire.last_rejection == .StaleStateResource or wire.last_rejection == .QueryExpired or wire.last_rejection == .StateViewExpired)) {
                if (wire.last_rejection == .StateViewExpired) server.view_id = null;
                try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
                continue;
            }
            // Station retains every prepared mutation before dispatch and
            // discards poisoned, unsent private proposals. Temporary transport
            // loss can retry without replacing any uncertain signed command.
            if (q.wire.Client.unavailable(err) or wire.contended(err)) {
                if (server.pending == null and server.ready != null) try server.discard();
                try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
                continue;
            }
            if (err == error.AccessDenied or err == error.StaleActivation or err == error.Rejected or err == error.Conflict or server.pending == null) return err;
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        // A returned commit may recover a previous receipt. These are observed
        // host steps, never counters of newly completed queries or fresh turns.
        observation.finish(.{ .name = "query.worker.step", .operation = @tagName(config.role), .level = if (step == .blocked) .err else if (step == .committed) .info else .debug, .outcome = if (step == .idle) .idle else if (step == .blocked) .rejected else .ok, .protocol_outcome = if (step == .committed) .receipt else .none, .realm = config.realm, .pid = config.pid, .generation = config.generation });
        if (step == .blocked) return server.handler_error orelse error.QueryHostBlocked;
        if (step == .idle) {
            server.session.idle_wait_ms = @min(q.wire.WaitHint.max_ms, idle_ms);
            idle_ms = @min(@max(config.interval_ms, config.idle_max_interval_ms), idle_ms * 2);
        } else {
            idle_ms = config.interval_ms;
            server.session.idle_wait_ms = 0;
        }
    }
}
fn courier(init: std.process.Init, wire: *q.wire.Client, config: Config, key: p.Ed25519.KeyPair) !void {
    const destinations = config.role.courier.destinations;
    const all = config.role.courier.all_destinations;
    if ((all and destinations.len != 0) or (!all and destinations.len == 0) or destinations.len > 16) return error.InvalidConfiguration;
    for (destinations, 0..) |destination, index| {
        if (destination == 0 or destination > p.max_counter or std.mem.indexOfScalar(u64, destinations[0..index], destination) != null) return error.InvalidConfiguration;
    }
    wire.observer.?.event(.{ .name = "service.ready", .operation = "courier", .realm = config.realm });
    var after: ?u64 = null;
    var pending: ?g.SignedRequest = null;
    var idle_ms = config.interval_ms;
    var retry_ms = config.interval_ms;
    while (true) {
        if (pending) |signed| {
            _ = wire.submit(signed) catch |err| {
                if (err == error.AccessDenied or err == error.Rejected or (err == error.Conflict and !wire.contended(err))) return err;
                try courierBackoff(init.io, &retry_ms, config.interval_ms);
                continue;
            };
            after = signed.request.command.deliver;
            pending = null;
            idle_ms = config.interval_ms;
            retry_ms = config.interval_ms;
            continue;
        }
        const basis = wire.query(.{ .realm = config.realm, .principal = config.principal, .kind = .delivery }, key) catch |err| {
            if (!q.wire.Client.unavailable(err) and !wire.contended(err)) return err;
            try courierBackoff(init.io, &retry_ms, config.interval_ms);
            continue;
        };
        // The pending index avoids walking retained, resolved history after a
        // restart. A courier authorized for every visible destination can use
        // that observation directly; filtered couriers still inspect destinations.
        if (basis.body.delivery.next) |next| {
            if (all) {
                pending = try g.sign(.{ .realm = config.realm, .principal = config.principal, .sequence = basis.principal_sequence + 1, .command = .{ .deliver = next } }, key);
                continue;
            }
            if (after == null or after.? < next) after = if (next == 1) null else next - 1;
        } else {
            _ = wire.waitForChange(.{ .realm = config.realm, .principal = config.principal, .kind = .delivery }, key, .{
                .after = basis.position,
                .milliseconds = @min(q.wire.WaitHint.max_ms, idle_ms),
            }) catch |err| {
                if (!q.wire.Client.unavailable(err) and err != error.Conflict) return err;
                try courierBackoff(init.io, &retry_ms, config.interval_ms);
                continue;
            };
            idle_ms = @min(@max(config.interval_ms, config.idle_max_interval_ms), idle_ms * 2);
            retry_ms = config.interval_ms;
            continue;
        }
        const page = wire.query(.{ .realm = config.realm, .principal = config.principal, .kind = .{ .outputs = .{ .after = after, .position = basis.position } } }, key) catch |err| {
            if (err == error.Conflict and wire.last_rejection == .QueryExpired) {
                try courierBackoff(init.io, &retry_ms, config.interval_ms);
                continue;
            }
            if (q.wire.Client.unavailable(err) or wire.contended(err)) {
                try courierBackoff(init.io, &retry_ms, config.interval_ms);
                continue;
            }
            return err;
        };
        for (page.body.outputs.entries) |slot| if (slot) |output| {
            if (output.phase == .pending and (all or std.mem.indexOfScalar(u64, destinations, output.destination) != null)) {
                pending = try g.sign(.{ .realm = config.realm, .principal = config.principal, .sequence = basis.principal_sequence + 1, .command = .{ .deliver = output.id } }, key);
                break;
            }
            after = output.id;
        };
        if (pending == null and page.body.outputs.next == null) {
            _ = wire.waitForChange(.{ .realm = config.realm, .principal = config.principal, .kind = .delivery }, key, .{
                .after = page.position,
                .milliseconds = @min(q.wire.WaitHint.max_ms, idle_ms),
            }) catch |err| {
                if (!q.wire.Client.unavailable(err) and err != error.Conflict) return err;
                try courierBackoff(init.io, &retry_ms, config.interval_ms);
                continue;
            };
            idle_ms = @min(@max(config.interval_ms, config.idle_max_interval_ms), idle_ms * 2);
        } else idle_ms = config.interval_ms;
        retry_ms = config.interval_ms;
    }
}

/// Retry the same pending delivery, or repeat a current read, at a bounded
/// rate. Successful work resets this delay; capacity refusal cannot create a
/// tight loop that competes with the destination's execution requests.
fn courierBackoff(io: std.Io, interval: *u32, base: u32) !void {
    try io.sleep(.fromMilliseconds(interval.*), .awake);
    interval.* = @min(@max(base, 1000), interval.* * 2);
}
