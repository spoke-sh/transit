//! Foreground, explicitly configured local placement. OS liveness grants no authority.
const std = @import("std");
const q = @import("transit_query");
const Config = @import("Config.zig");
const Installation = @import("Installation.zig");
const Files = @import("Files.zig");
const Process = @import("Process.zig");
const Board = @import("Board.zig");
const Provider = @import("Provider.zig");
const Sql = @import("Sql.zig");
const Signals = @import("../Signals.zig");
const Self = @This();
const Diagnostic = @import("../Diagnostic.zig");
const Role = enum { cold, store, node, maintenance, source, requester, courier, gateway, board, sql };
init: std.process.Init,
installation: *Installation,
executable: []const u8,
ui: bool,
diagnostic: *Diagnostic,
config_path: []const u8,
loaded: Config.Loaded,
boot: [16]u8,
processes: [9]Process = @splat(.{}),
active_role: Role = .cold,
pub fn run(init: std.process.Init, options: @import("../Options.zig").Options, diagnostic: *Diagnostic) !void {
    const loaded = try Config.capture(init, options.path, diagnostic, true);
    const config = loaded.config;
    const executable = try std.process.executablePathAlloc(init.io, init.arena.allocator());
    const identity = try config.identities(init, executable, diagnostic);
    // The sibling lock also serializes first initialization before the directory exists.
    diagnostic.field = "installation";
    const lock_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}.lock", .{config.installation});
    const lock = try std.Io.Dir.cwd().createFile(init.io, lock_path, .{ .truncate = false, .permissions = .fromMode(0o600) });
    defer lock.close(init.io);
    if (!try lock.tryLock(init.io, .exclusive)) return error.InstallationInUse;
    diagnostic.field = null;
    try config.preflight(init.io, !options.no_ui, diagnostic);
    diagnostic.atFile(config.installation);
    if (options.initialize) try Installation.create(init, config, identity);
    const record_path = try std.fs.path.join(init.arena.allocator(), &.{ config.installation, "installation.json" });
    diagnostic.atFile(record_path);
    const record = Files.read(Installation.Record, init.io, init.arena.allocator(), record_path) catch |err| {
        return diagnostic.fail(err, "cannot read the retained installation record", "Verify the installation path and restore missing data from its recovery source. Use --initialize only for a deliberately new installation, never to repair missing retained storage.");
    };
    if (record.definition != q.protocol.Growth.current_definition or record.version != 1 or !std.meta.eql(record.identity, identity)) return error.InstallationIdentityMismatch;
    if (record.complete) {
        const checkpoint = try std.fs.path.join(init.arena.allocator(), &.{ config.installation, "configuration.json" });
        diagnostic.atFile(checkpoint);
        @import("Configuration.zig").checkRetained(init, checkpoint, try Installation.settingsBinding(record, config.realm)) catch |err| {
            return diagnostic.fail(err, "cannot read the retained configuration checkpoint", "Restore the installation's configuration checkpoint and history together from its recovery source. Startup never recreates missing accepted configuration state.");
        };
    }
    const signals = try Signals.install();
    defer signals.close();
    var wire = q.wire.Client.init(init.gpa, init.io, try Provider.url(init.arena.allocator(), config.ports.node));
    defer wire.deinit();
    wire.timeout_ms = 2000;
    var installation: Installation = .{ .init = init, .config = config, .record = record, .record_path = record_path, .wire = &wire, .root = try q.wire.readKey(init.gpa, init.io, try std.fs.path.join(init.arena.allocator(), &.{ config.installation, "root.seed" })), .caller_key = try q.wire.readKey(init.gpa, init.io, try std.fs.path.join(init.arena.allocator(), &.{ config.installation, "caller.seed" })) };
    defer {
        std.crypto.secureZero(u8, std.mem.asBytes(&installation.root));
        std.crypto.secureZero(u8, std.mem.asBytes(&installation.caller_key));
    }
    if (!std.mem.eql(u8, &record.root_public, &installation.root.public_key.toBytes())) return error.InstallationIdentityMismatch;
    try installation.checkStorage();
    const self = try init.gpa.create(Self);
    defer init.gpa.destroy(self);
    var boot: [16]u8 = undefined;
    try init.io.randomSecure(&boot);
    self.* = .{ .loaded = loaded, .boot = boot, .init = init, .installation = &installation, .executable = executable, .diagnostic = diagnostic, .config_path = options.path orelse "transit.yaml / server defaults", .ui = !options.no_ui };
    defer self.stop();
    var restarts: u8 = 0;
    while (!Signals.interrupted()) {
        self.cycle() catch |err| {
            self.stop();
            self.transportDiagnostic();
            if (Signals.interrupted() or err == error.ServerStopped) return;
            diagnostic.role = @tagName(self.active_role);
            if (diagnostic.cause == null) diagnostic.cause = err;
            // Storage identity/rollback, local durability failure and explicit
            // native denials are never repaired by rewriting installation state.
            if (installation.failed or err == error.AuthorityRollback or err == error.StorageIdentityMismatch or err == error.ConfigurationUnavailable or err == error.AccessDenied or err == error.InvalidBoardResponse or err == error.UnsafeBoardPrincipal or err == error.InstallationSyncFailed or err == error.NoSpaceLeft) return err;
            if (restarts == 3) return error.RestartBudgetExhausted;
            restarts += 1;
            diagnostic.setFailure(err, "server role failed; retrying the same installation", "Wait for a ready record or terminal failure. The server preserves installation history and allows at most three automatic restarts.");
            diagnostic.emit(init.io, err);
            try init.io.sleep(.fromMilliseconds(@as(u32, restarts) * 250), .awake);
            continue;
        };
        return;
    }
}
fn stop(self: *Self) void {
    var i: usize = self.processes.len;
    while (i > 0) {
        i -= 1;
        self.processes[i].stop(self.init.io);
    }
}
fn allAlive(self: *Self) bool {
    for (&self.processes, 0..) |*process, i| if (process.child != null and !process.alive()) {
        self.active_role = @fromBackingInt(@intCast(i));
        return false;
    };
    return true;
}
fn start(self: *Self, allocator: std.mem.Allocator, role: Role, args: []const []const u8, environment: []const Process.Variable, registration: bool) !void {
    if (Signals.interrupted()) return error.ServerStopped;
    self.active_role = role;
    try self.processes[@backingInt(role)].start(self.init, self.executable, try std.fmt.allocPrint(allocator, "{s}/{s}.launch.json", .{ self.installation.config.installation, @tagName(role) }), .{ .argv = args, .environment = environment }, registration);
}
fn ready(self: *Self, address: []const u8) !void {
    const start_time = std.Io.Clock.awake.now(self.init.io);
    while (start_time.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() < 30000) {
        if (Signals.interrupted()) return error.ServerStopped;
        if (!self.allAlive()) return error.ChildExited;
        if (Provider.health(self.init, address)) return;
        try self.init.io.sleep(.fromMilliseconds(100), .awake);
    }
    return error.RoleReadinessTimeout;
}
fn cycle(self: *Self) !void {
    var arena: std.heap.ArenaAllocator = .init(self.init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const installation = self.installation;
    const config = installation.config;
    self.diagnostic.atFile(config.installation);
    try installation.checkStorage();
    self.diagnostic.atFile(self.config_path);
    try config.preflight(self.init.io, self.ui, self.diagnostic);
    self.diagnostic.atFile(config.installation);
    const secret = try std.Io.Dir.cwd().readFileAlloc(self.init.io, try installation.path("cold.seed"), allocator, .limited(65));
    defer std.crypto.secureZero(u8, secret);
    if (secret.len != 64) return error.InvalidCredentialFile;
    try self.start(allocator, .cold, &.{ config.executables.minio, "server", try installation.path("cold"), "--certs-dir", try installation.path("certs"), "--address", try std.fmt.allocPrint(allocator, "127.0.0.1:{d}", .{config.ports.cold}), "--console-address", try std.fmt.allocPrint(allocator, "127.0.0.1:{d}", .{config.ports.cold_console}) }, &.{ .{ .name = "MINIO_ROOT_USER", .value = "transit" }, .{ .name = "MINIO_ROOT_PASSWORD", .value = secret }, .{ .name = "MINIO_BROWSER", .value = "off" }, .{ .name = "GOMAXPROCS", .value = "2" }, .{ .name = "GOMEMLIMIT", .value = "256MiB" }, .{ .name = "HOME", .value = try installation.path("provider-home") } }, false);
    try self.ready(try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/minio/health/ready", .{config.ports.cold}));
    // PutBucket is idempotent only during recorded first bootstrap. A recovered
    // installation never creates replacement cold storage or authority streams.
    if (!installation.record.genesis_observed) try Provider.bucket(self.init, config.ports.cold, secret);
    const store_config = try installation.path("ursula.toml");
    try Files.write(self.init.io, store_config, try Provider.configuration(allocator, config, secret));
    try self.start(allocator, .store, &.{ config.executables.ursula, "server", "--config", store_config }, &.{ .{ .name = "RUST_LOG", .value = "error" }, .{ .name = "TOKIO_WORKER_THREADS", .value = "2" } }, false);
    try self.ready(try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/__ursula/ready", .{config.ports.store}));
    const node_config = try installation.path("node.json");
    try Files.json(self.init.io, allocator, node_config, .{ .profile = "native_v1", .genesis = .{ .realm = config.realm, .root_key = installation.record.root_public, .max_clock_error_ms = 10000, .admission_ceiling = config.admission_ceiling, .control_reserve = config.control_reserve }, .ursula_url = try Provider.url(allocator, config.ports.store), .bucket = "transit", .journal = "authority", .port = config.ports.node, .resident_pages = 8, .request_timeout_ms = 2000, .storage = config.storage, .maintenance = .{ .principal = Installation.maintenance, .seed_file = try installation.path("maintenance.seed"), .interval_ms = 1000, .operation_timeout_ms = 2000 } });
    const node_args = [_][]const u8{ config.executables.node, node_config, "--bootstrap" };
    try self.start(allocator, .node, node_args[0..if (installation.record.genesis_observed) @as(usize, 2) else 3], &.{}, false);
    const node_health = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/health", .{config.ports.node});
    try self.ready(node_health);
    _ = try installation.query(.{ .capabilities = {} });
    try installation.flush();
    self.active_role = .sql;
    try Sql.recover(installation);
    const applications = if (config.applications != null) try @import("Applications.zig").create(self.init, installation, self.executable) else null;
    defer if (applications) |manager| manager.destroy();
    if (applications) |manager| try manager.recover();
    try installation.provision();
    if (self.ui) try installation.provisionBoard();
    try self.start(allocator, .maintenance, &.{ config.executables.node, node_config, "--maintain" }, &.{}, false);
    try self.worker(allocator, .source);
    try self.worker(allocator, .requester);
    const connection = installation.connection();
    const courier_config = try installation.path("courier.json");
    const destinations = [_]u64{ connection.source, connection.requester };
    try Files.json(self.init.io, allocator, courier_config, .{ .url = installation.wire.url, .realm = config.realm, .principal = Installation.courier, .seed_file = try installation.path("courier.seed"), .role = .{ .courier = .{ .destinations = if (applications != null) destinations[0..0] else destinations[0..], .all_destinations = applications != null } }, .interval_ms = 100, .idle_max_interval_ms = 1000, .request_timeout_ms = 2000 });
    try self.start(allocator, .courier, &.{ config.executables.query_host, courier_config }, &.{}, false);
    try installation.initializeBehaviors();
    var query: q.UnifiedClient = .{ .wire = installation.wire, .connection = connection, .key = installation.caller_key };
    const started = std.Io.Clock.awake.now(self.init.io);
    while (true) {
        if (Signals.interrupted()) return error.ServerStopped;
        if (!self.allAlive()) return error.ChildExited;
        self.tableReady(&query) catch |err| {
            if (started.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() >= 60000) return err;
            try self.init.io.sleep(.fromMilliseconds(100), .awake);
            continue;
        };
        break;
    }
    // The retained record outlives this cycle, including automatic child
    // restarts. Keep its endpoint in the installation's process arena.
    installation.record.endpoint = try Provider.url(self.init.arena.allocator(), config.ports.gateway);
    try installation.save();
    const configuration = try installation.path("configuration.json");
    const binding = try Installation.settingsBinding(installation.record, config.realm);
    try @import("Configuration.zig").boot(self.init, configuration, binding, self.boot, self.loaded, installation.record.identity, installation.record.complete);
    // Publish completion only after the first settings checkpoint is durable.
    // A crash before this save can resume bootstrap; a completed installation
    // must never replace a missing accepted checkpoint with generation one.
    installation.record.complete = true;
    try installation.save();
    const gateway_config = try installation.path("gateway.json");
    try Files.json(self.init.io, allocator, gateway_config, @import("Gateway.zig").Config{ .port = config.ports.gateway, .upstream = installation.wire.url, .allowed_hosts = config.gateway_allowed_hosts, .configuration = .{ .path = configuration, .binding = binding } });
    try self.start(allocator, .gateway, &.{ self.executable, "__transit_gateway_v1", gateway_config }, &.{}, false);
    try self.ready(try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/health", .{config.ports.gateway}));
    self.active_role = .sql;
    const sql = try Sql.create(installation, allocator, self.executable);
    defer if (sql) |manager| manager.destroy();
    if (self.ui) {
        const board_path = try Board.configuration(installation, allocator);
        try self.start(allocator, .board, &.{ config.executables.board.?, board_path }, &.{}, false);
        const board_started = std.Io.Clock.awake.now(self.init.io);
        while (true) {
            if (Signals.interrupted()) return error.ServerStopped;
            if (!self.allAlive()) return error.ChildExited;
            Board.ready(installation) catch |err| {
                if (err == error.AccessDenied or err == error.UnsafeBoardPrincipal or err == error.InvalidBoardResponse or board_started.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() >= 30000) return err;
                try self.init.io.sleep(.fromMilliseconds(100), .awake);
                continue;
            };
            break;
        }
    }
    const report = try std.json.Stringify.valueAlloc(allocator, .{
        .ready = true,
        .profile = if (applications != null) "local_applications_v1" else "local_table_v1",
        .installation = config.installation,
        .management_config = if (applications != null) try installation.path("management.yaml") else null,
        .gateway_url = try Provider.url(allocator, config.ports.gateway),
        .allowed_hosts = try @import("Hosts.zig").list(allocator, config.ports.gateway, config.gateway_allowed_hosts),
        .board_url = if (self.ui) config.board.?.public_origin else null,
        .ui = if (self.ui) "ready" else "disabled",
        .sql = if (sql) |manager| try manager.report(allocator) else null,
    }, .{});
    var output_buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(self.init.io, &output_buffer);
    try @import("../Output.zig").write(self.init, &output.interface, try std.fmt.allocPrint(allocator, "{s}\n", .{report}));
    var last = std.Io.Clock.awake.now(self.init.io);
    var unavailable_probes: u8 = 0;
    while (!Signals.interrupted()) {
        if (!self.allAlive()) return error.ChildExited;
        if (sql) |manager| {
            self.active_role = .sql;
            try manager.tick();
        }
        if (sql == null or !sql.?.hasPending()) {
            if (applications) |manager| try manager.tick();
        }
        const now = std.Io.Clock.awake.now(self.init.io);
        if (last.durationTo(now).toMilliseconds() >= 1000) {
            self.active_role = .node;
            _ = installation.query(.{ .capabilities = {} }) catch |err| {
                // One unavailable read does not establish process death. Keep
                // exact pending work and live owners while the next scheduled
                // observation checks availability. Denial/corruption still
                // fails immediately; persistent outage remains bounded.
                if (!q.wire.Client.unavailable(err) or err == error.AuthorityTransportDenied) return err;
                // Explicit admission pressure is not evidence of a dead owner.
                // Restarting every child here amplifies load and fences work
                // that is still making progress. Keep the next probe bounded;
                // ordinary transport outages retain their finite restart gate.
                if (installation.wire.last_rejection != .HttpCapacity) {
                    if (unavailable_probes == 2) return err;
                    unavailable_probes += 1;
                }
                last = std.Io.Clock.awake.now(self.init.io);
                try self.init.io.sleep(.fromMilliseconds(100), .awake);
                continue;
            };
            unavailable_probes = 0;
            if (self.ui) {
                self.active_role = .board;
                try Board.check(installation);
            }
            last = now;
        }
        try self.init.io.sleep(.fromMilliseconds(100), .awake);
    }
}
fn tableReady(self: *Self, query: *q.UnifiedClient) !void {
    const config = Installation.catalogFor(query.connection, self.installation.record);
    var catalog: q.catalog.TableClient = .{ .transport = query.wire, .connection = .{ .scope = config.scope, .owner = config.owner, .principal = query.connection.principal }, .key = query.key };
    const description = try catalog.describe();
    if (!std.meta.eql(description.configuration, config)) return error.CatalogConfigurationChanged;
    // Readiness never restores revoked policy or recreates a deliberately
    // dropped default Table. First creation has its own exact saved recovery.
    try self.installation.ensureDefaultTable(&catalog);
}
fn worker(self: *Self, allocator: std.mem.Allocator, role: Role) !void {
    const installation = self.installation;
    const connection = installation.connection();
    const pid = if (role == .source) connection.source else connection.requester;
    const principal: u64 = if (role == .source) Installation.source else Installation.requester;
    const process = (try installation.query(.{ .process = pid })).body.process.process;
    if (process.lifecycle != .running or process.failure != null) return error.ProcessUnavailable;
    const generation = try std.math.add(u64, process.generation, 1);
    const Common = struct { url: []const u8, realm: u64, principal: u64, pid: u64, generation: u64, activation_directory: []const u8, interval_ms: u32 = 100, idle_max_interval_ms: u32 = 1000, request_timeout_ms: u32 = 2000, role: union(enum) { catalog: q.catalog.TableCatalogRecords.Configuration, unified_requester: q.UnifiedBehavior.Requester } };
    const config: Common = .{ .url = installation.wire.url, .realm = connection.realm, .principal = principal, .pid = pid, .generation = generation, .activation_directory = try installation.path("activations"), .role = if (role == .source) .{ .catalog = Installation.catalogFor(connection, installation.record) } else .{ .unified_requester = .{ .principal = Installation.caller, .source = connection.source } } };
    const json = try std.json.Stringify.valueAlloc(allocator, config, .{});
    try self.start(allocator, role, &.{ installation.config.executables.query_host, "--bootstrap-json", json }, &.{}, true);
    var bytes: [1024]u8 = undefined;
    const registration = try self.processes[@backingInt(role)].registration(self.init.io, &bytes);
    const parsed = try std.json.parseFromSlice(struct { growing_bootstrap: q.wire.bootstrap.GrowingRegistration }, allocator, registration, .{});
    const observed = parsed.value.growing_bootstrap;
    if (observed.version != 1 or observed.realm != connection.realm or observed.pid != pid or observed.principal != principal or observed.generation != generation) return error.InvalidRegistration;
    try installation.activate(observed);
}

fn transportDiagnostic(self: *Self) void {
    const log = &self.processes[@backingInt(Role.gateway)].stderr;
    const prefix = "gateway transport: ";
    const offset = std.mem.lastIndexOf(u8, log.bytes[0..log.length], prefix) orelse return;
    const tail = log.bytes[offset + prefix.len .. log.length];
    const end = std.mem.indexOfScalar(u8, tail, '\n') orelse return;
    if (end == 0 or end > 64) return;
    for (tail[0..end]) |byte| if (!std.ascii.isAlphanumeric(byte)) return;
    std.debug.print("server gateway transport: {s}\n", .{tail[0..end]});
}
