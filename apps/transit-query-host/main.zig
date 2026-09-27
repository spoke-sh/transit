const std = @import("std");
const q = @import("transit_query");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    pid: u64 = 0,
    generation: u64 = 0,
    association: []const u8 = "state",
    activation_directory: ?[]const u8 = null,
    interval_ms: u32 = 20,
    request_timeout_ms: u32 = 5000,
    role: union(enum) {
        source: q.Behavior.Source,
        requester: q.Behavior.Requester,
        unified_source: struct { peer: u64, initializer: u64 },
        unified_requester: q.UnifiedBehavior.Requester,
        courier: struct { destinations: [2]u64 },
    },
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(8192));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    var config = parsed.value;
    if (config.principal == 0 or config.principal > p.max_counter or config.realm == 0 or config.interval_ms == 0 or config.interval_ms > 60000 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    const key = try q.wire.readKey(init.gpa, init.io, config.seed_file);
    var wire = q.wire.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = config.request_timeout_ms;
    if (config.role == .courier) return courier(init, &wire, config, key);
    if (config.pid == 0 or config.generation == 0) return error.MissingActivation;
    var server = try s.GrowingGenServer.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, config.association);
    // Check current ownership before recording that this activation has run.
    _ = try server.session.receive();
    const directory = config.activation_directory orelse return error.MissingActivationDirectory;
    const marker = try std.fmt.allocPrint(init.gpa, "{s}/{d}-{d}-{d}.activation", .{ directory, config.realm, config.pid, config.generation });
    defer init.gpa.free(marker);
    const file = std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired;
        return err;
    };
    file.close(init.io);
    const unified = config.role == .unified_source or config.role == .unified_requester;
    const workspace = try init.gpa.alloc(u8, if (unified) q.fuze.Unified.Arrow.working_bytes else q.fuze.execution.working_bytes);
    defer init.gpa.free(workspace);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    if (!unified) server.query = .{ .workspace = workspace, .cancellation = &cancellation };
    server.failure_policy = if (unified) .stop else .block_input;
    const adapter = try init.gpa.alloc(u8, if (config.role == .unified_source) q.UnifiedBehavior.adapter_bytes else 0);
    defer init.gpa.free(adapter);
    var unified_source: q.UnifiedBehavior.Source = .{
        .peer = if (config.role == .unified_source) config.role.unified_source.peer else 0,
        .initializer = if (config.role == .unified_source) config.role.unified_source.initializer else 0,
        .resources = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key },
        .adapter = adapter,
        .workspace = workspace,
        .cancellation = &cancellation,
    };
    const handler = switch (config.role) {
        .source => |*source| source.interface(),
        .requester => |*requester| requester.interface(),
        .unified_source => unified_source.interface(),
        .unified_requester => |*requester| requester.interface(),
        .courier => unreachable,
    };
    while (true) {
        const now: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds());
        const step = server.step(handler, now + 30000) catch |err| {
            // An ambiguous mutation retains exact bytes in server.pending. Never
            // discard/recompute it under this activation. A restarted OS worker
            // requires fresh fenced ownership, even if it exited while idle.
            if (unified and server.pending == null and (err == error.Conflict or err == error.Rejected) and (wire.last_rejection == .StaleStateResource or wire.last_rejection == .QueryExpired or wire.last_rejection == .StateViewExpired)) {
                if (wire.last_rejection == .StateViewExpired) server.view_id = null;
                try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
                continue;
            }
            if (err == error.AccessDenied or err == error.StaleActivation or err == error.Rejected or err == error.Conflict or server.pending == null) return err;
            try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
            continue;
        };
        if (step == .blocked) return server.handler_error orelse error.QueryHostBlocked;
        if (step == .idle) try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}
fn courier(init: std.process.Init, wire: *q.wire.Client, config: Config, key: p.Ed25519.KeyPair) !void {
    const destinations = config.role.courier.destinations;
    if (destinations[0] == 0 or destinations[1] == 0 or destinations[0] == destinations[1]) return error.InvalidConfiguration;
    var after: ?u64 = null;
    var pending: ?g.SignedRequest = null;
    while (true) {
        if (pending) |signed| {
            _ = wire.submitGrowing(signed) catch |err| {
                if (err == error.AccessDenied or err == error.Rejected or err == error.Conflict) return err;
                try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
                continue;
            };
            after = signed.request.command.deliver;
            pending = null;
            continue;
        }
        const basis = try wire.queryGrowing(.{ .realm = config.realm, .principal = config.principal, .kind = .{ .capabilities = {} } }, key);
        const page = wire.queryGrowing(.{ .realm = config.realm, .principal = config.principal, .kind = .{ .outputs = .{ .after = after, .position = basis.position } } }, key) catch |err| {
            if (err == error.Conflict and wire.last_rejection == .QueryExpired) continue;
            return err;
        };
        for (page.body.outputs.entries) |slot| if (slot) |output| {
            if (output.phase == .pending and (output.destination == destinations[0] or output.destination == destinations[1])) {
                pending = try g.sign(.{ .realm = config.realm, .principal = config.principal, .sequence = basis.principal_sequence + 1, .command = .{ .deliver = output.id } }, key);
                break;
            }
            after = output.id;
        };
        if (pending == null and page.body.outputs.next == null) try init.io.sleep(.fromMilliseconds(config.interval_ms), .awake);
    }
}
