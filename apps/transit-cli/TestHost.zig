//! One private listener-free local database per case. All borrowers close before
//! the native owner; the caller checks deletion after this function returns.
const std = @import("std");
const testlib = @import("transit_test");
const g = testlib.service;
const p = g.catalog.protocol;
const node = @import("transit_node_role");
const Sources = @import("BuildSources.zig");
const telemetry = g.wire.observability.telemetry;
const bootstrap = testlib.Bootstrap;
pub const Resources = struct { memory_peak_bytes: usize = 0, storage_reserved_bytes: u64 = 0 };
pub const Observation = struct { actions: usize = 0, rows: usize = 0, bytes: usize = 0, operation: ?u64 = null, failure: ?testlib.Runner.Failure = null, resources: Resources = .{} };
pub const cleanup_ms = 5000;
pub const StorageLimits = struct { bytes: u64 = 192 * 1024 * 1024, control_bytes: u64 = 32 * 1024 * 1024 };

pub const Context = struct {
    session: *g.Session,
    runtime: *g.DatabaseRuntime,
    authority: bootstrap,
    role: u64,
    endpoint: g.wire.LocalEndpoint,
};
pub const Action = struct { context: *anyopaque, call: *const fn (*anyopaque, Context) anyerror!bool, resources: ?*Resources = null };
const CaseAction = struct {
    case: @import("transit_compiler").Test.Case,
    observed: *Observation,
    fn call(raw: *anyopaque, context: Context) !bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        var runner: testlib.Runner = .{ .allocator = context.session.allocator, .session = context.session };
        defer {
            self.observed.rows = runner.rows;
            self.observed.bytes = runner.bytes;
            self.observed.operation = context.session.operation;
        }
        const result = runner.run(self.case) catch |err| {
            self.observed.actions = runner.action + 1;
            return err;
        };
        self.observed.actions = result.actions;
        self.observed.failure = result.failure;
        return result.passed;
    }
};
const Worker = struct {
    runtime: *g.DatabaseRuntime,
    failure: std.atomic.Value(u16) = .init(0),
    fn run(self: *Worker) void {
        while (true) {
            const progressed = self.runtime.tick() catch |err| {
                if (err != error.Canceled and err != error.Cancelled) {
                    self.failure.store(@intFromError(err), .release);
                    self.runtime.ready.store(false, .release);
                }
                return;
            };
            if (!progressed) self.runtime.waitIdle(2) catch return;
        }
    }
};
pub fn run(init: std.process.Init, directory: std.Io.Dir, path: []const u8, case: @import("transit_compiler").Test.Case, deadline: g.wire.Deadline, observed: *Observation) !bool {
    var action: CaseAction = .{ .case = case, .observed = observed };
    return runAction(init, directory, path, deadline, .{ .context = &action, .call = CaseAction.call, .resources = &observed.resources });
}
/// Embedding seam for the real host qualification binary. The CLI exposes only
/// compiler cases; source input cannot install callbacks or acquire root keys.
pub fn runAction(init: std.process.Init, directory: std.Io.Dir, path: []const u8, deadline: g.wire.Deadline, action: Action) !bool {
    return runActionWithStorage(init, directory, path, deadline, action, .{});
}
/// Embedders may reduce provider quotas to qualify exhaustion; source input and
/// the CLI cannot raise or otherwise configure the isolated profile's limits.
pub fn runActionWithStorage(init: std.process.Init, directory: std.Io.Dir, path: []const u8, deadline: g.wire.Deadline, action: Action, storage: StorageLimits) !bool {
    const maximum: StorageLimits = .{};
    if (storage.bytes == 0 or storage.control_bytes == 0 or storage.bytes > maximum.bytes or storage.control_bytes > maximum.control_bytes) return error.InvalidTestStorageBudget;
    var quota: @import("transit_memory").Quota = .{ .limit = 256 * 1024 * 1024 };
    var adapter: @import("transit_memory").Quota.Allocator = .{ .parent = init.gpa, .quota = &quota };
    const a = adapter.allocator();
    var arena: std.heap.ArenaAllocator = .init(a);
    var process = init;
    process.gpa = a;
    process.arena = &arena;
    const result = bounded(bool, init.io, deadline, execute, .{ process, directory, path, deadline, action, storage });
    arena.deinit();
    if (action.resources) |resources| resources.memory_peak_bytes = quota.peak.load(.acquire);
    if (quota.used.load(.acquire) != 0) return error.TestAllocationLeak;
    return result catch |err| {
        return if (err == error.OutOfMemory and quota.refusals.load(.acquire) != 0) error.TestMemoryLimit else err;
    };
}
/// Cancellation joins the operation before any borrowed stack or directory is
/// released. Cleanup calls use a fresh deadline, independent of the case cap.
pub fn bounded(comptime T: type, io: std.Io, deadline: g.wire.Deadline, comptime call: anytype, args: anytype) !T {
    const Result = union(enum) { completed: anyerror!T, expired: anyerror!void };
    const Timer = struct {
        fn wait(clock: std.Io, cap: g.wire.Deadline) !void {
            try cap.timeout().sleep(clock);
            return error.TestDeadline;
        }
    };
    var results: [2]Result = undefined;
    var selection: std.Io.Select(Result) = .init(io, &results);
    defer selection.cancelDiscard();
    try selection.concurrent(.expired, Timer.wait, .{ io, deadline });
    try selection.concurrent(.completed, call, args);
    return switch (try selection.await()) {
        .completed => |result| result,
        .expired => |result| blk: {
            try result;
            break :blk error.TestDeadline;
        },
    };
}
pub fn delete(io: std.Io, parent: std.Io.Dir, name: []const u8) !void {
    return bounded(void, io, .init(io, cleanup_ms, null), std.Io.Dir.deleteTree, .{ parent, io, name });
}
fn key(io: std.Io, directory: std.Io.Dir, name: []const u8) !p.Ed25519.KeyPair {
    var seed: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &seed);
    try io.randomSecure(&seed);
    var encoded = std.fmt.bytesToHex(&seed, .lower);
    defer std.crypto.secureZero(u8, &encoded);
    try Sources.writeFile(io, directory, name, &encoded);
    return p.Ed25519.KeyPair.generateDeterministic(seed);
}
fn execute(init: std.process.Init, directory: std.Io.Dir, path: []const u8, deadline: g.wire.Deadline, action: Action, storage: StorageLimits) !bool {
    const a = init.arena.allocator();
    try deadline.check(init.io);
    var root = try key(init.io, directory, "root.seed");
    defer std.crypto.secureZero(u8, std.mem.asBytes(&root));
    var caller = try key(init.io, directory, "caller.seed");
    defer std.crypto.secureZero(u8, std.mem.asBytes(&caller));
    var registrar = try key(init.io, directory, "registrar.seed");
    defer std.crypto.secureZero(u8, std.mem.asBytes(&registrar));
    const storage_path = try std.fs.path.join(a, &.{ path, "storage" });
    const registrar_path = try std.fs.path.join(a, &.{ path, "registrar.seed" });
    const caller_path = try std.fs.path.join(a, &.{ path, "caller.seed" });
    const credential_path = try std.fs.path.join(a, &.{ path, "credential.json" });
    var diagnostics: telemetry.Runtime = .init(init.io, "transit-test", .{ .level = .off });
    const local = try node.LocalRuntime.open(init, .{
        .genesis = .{ .realm = bootstrap.realm, .root_key = root.public_key.toBytes() },
        .local_directory = storage_path,
        .resident_pages = 32,
        .storage = .{ .limits = .{ .bytes = storage.bytes, .control_bytes = storage.control_bytes } },
    }, .{ .initialize = false, .bootstrap = true }, &diagnostics);
    defer local.close();
    defer if (action.resources) |resources| {
        resources.storage_reserved_bytes = local.owner.allocated;
    };
    // Every route is handled by LocalEndpoint. This unusable address cannot be
    // selected by a source declaration, configuration file or environment.
    const url = "http://127.0.0.1:1";
    var wire = g.wire.Client.init(init.gpa, init.io, url);
    defer wire.deinit();
    wire.local = local.endpoint();
    wire.deadline = deadline;
    const installed = try (bootstrap{ .wire = &wire, .root = root }).provision(caller, registrar);
    try local.configureTable(.{ .catalog = installed.catalog, .registrar = .{ .principal = bootstrap.registrar, .seed_file = registrar_path } });
    const binding: g.DatabaseAccount.Binding = .{ .resource = installed.catalog.scope.resource, .catalog = 1, .owner = installed.catalog.audience };
    const connection: g.catalog.DirectTableProtocol.Connection = .{ .scope = installed.catalog.scope, .branch = 1, .principal = bootstrap.caller, .audience = binding.owner, .role = null };
    const table: g.catalog.DirectTableClient = .{ .allocator = init.gpa, .authority = &wire, .service = &wire, .connection = connection, .key = caller };
    const initialized = try table.call(.initialize);
    initialized.deinit();
    const execution: g.DatabaseAccount.Configuration = .{ .realm = bootstrap.realm, .table_principal = bootstrap.caller, .account = @splat(1), .bindings = &.{binding}, .operation_quota = 4096, .byte_quota = 16 * 1024 * 1024 };
    const runtime = try g.DatabaseRuntime.initEndpoint(init.gpa, init.io, url, .{ .configuration = execution }, 1, .{ .table = caller }, 5000, local.endpoint());
    defer runtime.deinit();
    runtime.background.deadline = deadline;
    runtime.ingress_wire.deadline = deadline;
    try runtime.attachReadCache(directory, .{});
    while (!runtime.ready.load(.acquire)) {
        try deadline.check(init.io);
        _ = try runtime.tick();
    }
    const identity = try wire.query(.{ .realm = bootstrap.realm, .principal = bootstrap.caller, .kind = .{ .authorization = .{ .kind = .identity } } }, caller);
    const credential: g.Configuration.Credential = .{ .version = 1, .definition = p.Growth.current_definition, .account = execution.account, .revision = 1, .principal = bootstrap.caller, .login_role = installed.role, .credential_epoch = identity.body.authorization.body.identity.credential_epoch, .enabled = true, .verifier = null };
    try Sources.writeFile(init.io, directory, "credential.json", try p.Json.valueAlloc(a, credential));
    const config: g.Configuration = .{
        .version = 1,
        .definition = p.Growth.current_definition,
        .native_url = url,
        .tls_mode = .disabled,
        .certificate_file = "",
        .certificate_key_file = "",
        .activation_directory = path,
        .spill_directory = path,
        .accounts = &.{.{ .name = "test", .authentication = .trust, .verifier_file = credential_path, .execution = execution, .generation = 1, .keys = .{ .table = caller_path }, .databases = &.{.{ .name = "transit", .binding = binding }} }},
    };
    try config.validate();
    var cancellation: std.atomic.Value(bool) = .init(false);
    var active: std.atomic.Value(bool) = .init(false);
    const session = try g.Session.initOptions(init.gpa, init.io, &config, 0, runtime, credential, "transit", .transit, &cancellation, &active, .{ .capture_settings = false, .deadline = deadline });
    defer session.deinit();
    // This host owns the real local endpoint and database scheduler. Select the
    // same native SQL profile as a cohosted caller; owner authorization remains
    // mandatory for every publication, control and observation.
    session.native_profile = true;
    const scope = session.withDeadline(deadline);
    defer scope.restore();
    var worker: Worker = .{ .runtime = runtime };
    var task = try init.io.concurrent(Worker.run, .{&worker});
    var joined = false;
    defer if (!joined) task.cancel(init.io);
    const result = action.call(action.context, .{ .session = session, .runtime = runtime, .authority = .{ .wire = &wire, .root = root }, .role = installed.role, .endpoint = local.endpoint() });
    task.cancel(init.io);
    joined = true;
    // All result readers have returned their borrows. Do not abandon warm
    // durable pins merely because their host is about to be disposed of.
    const protection = init.io.swapCancelProtection(.blocked);
    defer _ = init.io.swapCancelProtection(protection);
    const cleanup = session.withDeadline(.init(init.io, cleanup_ms, null));
    defer cleanup.restore();
    runtime.read_pins.?.drain(session.table) catch return error.TestReadCleanupFailed;
    if (worker.failure.load(.acquire) != 0) return @errorFromInt(worker.failure.load(.acquire));
    if (runtime.read_cleanup_failure.load(.acquire) != 0) return error.TestReadCleanupFailed;
    try deadline.check(init.io);
    return result;
}
