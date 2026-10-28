//! Local native node composition. Request semantics live in NativeServer.
const std = @import("std");
const core = @import("transit_core");
const backend = @import("transit_backend_local");
const telemetry = @import("transit_observability").telemetry;
const server = @import("NativeServer.zig");
const Maintenance = @import("GrowingMaintenance.zig");
const TableMaintenance = @import("LocalTableMaintenance.zig");
const Collection = @import("LocalCollection.zig");
pub const CollectionCursor = Collection.Cursor;
pub const TableHost = @import("LocalTableHost.zig");
const Self = @This();
pub const Store = backend.Store;
pub const PageStore = backend.PageStore;
pub const Engine = core.growing.Engine(Store, PageStore);

const Config = struct {
    profile: enum { native_v1 } = .native_v1,
    genesis: core.growing.Genesis,
    local_directory: []const u8,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    request_timeout_ms: u32 = 2000,
    resident_pages: u16 = 512,
    storage: core.protocol.Storage.Settings = .{},
    accept_trace_parent: bool = false,
    request_metrics: bool = false,
    maintenance: ?Maintenance.Config = null,
    table: ?TableHost.Config = null,
};

pub fn run(init: std.process.Init, bytes: []const u8, mode: anytype, diagnostics: *telemetry.Runtime) !void {
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidTimeout;
    try config.storage.maintenance.validate();
    try config.storage.requests.validate();
    const physical = config.storage.maintenance;
    if ((physical.flush.enabled or physical.archive.enabled or physical.compact) and (config.table == null or config.maintenance == null)) return error.LocalTableMaintenanceRequiresOwner;
    if (mode.maintain) return error.LocalMaintenanceRequiresOwner;
    var reopens: u8 = 0;
    while (true) {
        runOwner(init, config, .{
            .initialize = mode.initialize and reopens == 0,
            .bootstrap = mode.bootstrap and reopens == 0,
        }, diagnostics) catch |err| {
            if (err != error.LocalWalReopenRequired) return err;
            if (reopens == 3) return error.LocalWalReopenBudget;
            reopens += 1;
            // runOwner has joined requests/maintenance and released every
            // borrowed handle before its exclusive directory lock is closed.
            // A replacement opens existing history, never bootstrap/reset.
            diagnostics.event(.{ .name = "storage.owner.reopen", .level = .warn, .operation = "open", .error_type = "WalRecoveryRequired" });
            try init.io.sleep(.fromMilliseconds(@as(u32, reopens) * 250), .awake);
            continue;
        };
        return;
    }
}

fn runOwner(init: std.process.Init, config: Config, mode: anytype, diagnostics: *telemetry.Runtime) !void {
    var owner = try backend.Backend.open(init.gpa, init.io, std.Io.Dir.cwd(), config.local_directory, config.storage.limits);
    defer owner.deinit();
    owner.maintenance_settings = config.storage.maintenance;
    if (config.maintenance) |maintenance| owner.maintenance_activity = .{
        .enabled = true,
        .state = .waiting,
        .completed_steps = 0,
        .failed_steps = 0,
        .last_failure = null,
        .interval_ms = maintenance.interval_ms,
        .operation_timeout_ms = maintenance.operation_timeout_ms,
    };
    var pages = try PageStore.init(&owner, config.resident_pages);
    defer pages.deinit();
    pages.observe = .{ .runtime = diagnostics, .enabled = config.request_metrics };
    var journal: Store = .{ .backend = &owner, .observe = .{ .runtime = diagnostics, .enabled = config.request_metrics } };
    var recovery = @import("transit_observability").begin(diagnostics, .recovery, if (mode.initialize or mode.bootstrap) "bootstrap" else "open", null);
    journal.observe.parent = recovery.span.context;
    pages.observe.parent = recovery.span.context;
    var engine = (if (mode.initialize or mode.bootstrap) Engine.bootstrap(&journal, &pages, config.genesis) else Engine.open(&journal, &pages, config.genesis)) catch |err| {
        recovery.fail(err);
        recovery.finish();
        return err;
    };
    recovery.event.realm = config.genesis.realm;
    recovery.event.position = engine.head.position;
    recovery.finish();
    journal.observe.parent = null;
    pages.observe.parent = null;
    if (mode.initialize) return;
    var clock_context: u8 = 0;
    if (config.genesis.max_clock_error_ms != null) engine.clock = .{ .context = &clock_context, .read = @import("Clock.zig").read };
    var snapshot_epoch: [16]u8 = undefined;
    try init.io.randomSecure(&snapshot_epoch);
    engine.snapshot_epoch = snapshot_epoch;
    var table: ?TableHost = if (config.table) |configured| try TableHost.init(init.gpa, init.io, configured, &engine) else null;
    defer if (table) |*host| host.deinit();
    const lanes = try init.gpa.alloc(Lane, TableHost.request_owners);
    defer init.gpa.free(lanes);
    var initialized: usize = 0;
    defer for (lanes[0..initialized]) |*lane| lane.pages.deinit();
    for (lanes) |*lane| {
        lane.* = .{ .journal = .{ .backend = &owner, .observe = .{ .runtime = diagnostics, .enabled = config.request_metrics } }, .pages = try PageStore.init(&owner, config.resident_pages), .engine = engine };
        lane.pages.observe = .{ .runtime = diagnostics, .enabled = config.request_metrics };
        lane.engine.journal = &lane.journal;
        lane.engine.page_store = &lane.pages;
        lane.table = if (table) |*value| value else null;
        initialized += 1;
    }
    if (config.maintenance != null) {
        // This lane shares only the exclusive physical owner. Its mutable
        // authority, cache and scanner are private to the maintenance task.
        var maintenance_pages = try PageStore.init(&owner, config.resident_pages);
        defer maintenance_pages.deinit();
        maintenance_pages.observe = .{ .runtime = diagnostics, .enabled = config.request_metrics };
        var maintenance_journal: Store = .{ .backend = &owner, .observe = .{ .runtime = diagnostics, .enabled = config.request_metrics } };
        var maintenance_engine = engine;
        maintenance_engine.journal = &maintenance_journal;
        maintenance_engine.page_store = &maintenance_pages;
        return runServices(init, &engine, lanes, config, &maintenance_engine, diagnostics);
    }
    return runServices(init, &engine, lanes, config, null, diagnostics);
}

fn runServices(init: std.process.Init, engine: *Engine, lanes: []Lane, config: Config, maintenance_engine: ?*Engine, diagnostics: *telemetry.Runtime) !void {
    var table_maintenance: ?TableMaintenance = if (lanes[0].table) |host| .{ .host = host, .allocator = init.gpa } else null;
    const Task = struct {
        fn maintain(process: std.process.Init, owned: *Engine, settings: Maintenance.Config, runtime: *telemetry.Runtime, extension: ?Maintenance.Extension(Self)) anyerror!void {
            return Maintenance.run(Self, process, owned, settings, runtime, extension);
        }
        fn maintainTable(raw: *anyopaque, owned: *Engine, settings: Maintenance.Config, signed: core.protocol.Growth.SignedRequest) anyerror!bool {
            return TableMaintenance.step(raw, owned, settings.storage, signed);
        }
        fn serve(process: std.process.Init, authority: *Engine, requests: []Lane, settings: Config, runtime: *telemetry.Runtime) anyerror!void {
            return server.Host(Self).serve(process, authority, requests, settings, runtime);
        }
        fn watch(io: std.Io, owner: *backend.Backend, runtime: *telemetry.Runtime) anyerror!void {
            while (true) {
                if (try owner.recoverySource()) |source| {
                    runtime.event(.{ .name = "storage.owner.recovery_required", .level = .warn, .operation = @tagName(source), .error_type = "WalRecoveryRequired" });
                    return error.LocalWalReopenRequired;
                }
                try io.sleep(.fromMilliseconds(100), .awake);
            }
        }
    };
    const Result = union(enum) { server: anyerror!void, maintenance: anyerror!void, recovery: anyerror!void };
    var results: [3]Result = undefined;
    var select: std.Io.Select(Result) = .init(init.io, &results);
    // Cancellation joins the HTTP listener and all request lanes, maintenance
    // and the observer before runOwner releases any pages or physical storage.
    defer select.cancelDiscard();
    if (maintenance_engine) |owned| {
        var maintenance = config.maintenance.?;
        maintenance.storage = config.storage.maintenance;
        const extension: ?Maintenance.Extension(Self) = if (table_maintenance) |*work| .{ .context = work, .step = Task.maintainTable } else null;
        try select.concurrent(.maintenance, Task.maintain, .{ init, owned, maintenance, diagnostics, extension });
    }
    try select.concurrent(.server, Task.serve, .{ init, engine, lanes, config, diagnostics });
    try select.concurrent(.recovery, Task.watch, .{ init.io, engine.journal.backend, diagnostics });
    return switch (try select.await()) {
        .server => |result| result,
        .maintenance => |result| result,
        .recovery => |result| result,
    };
}

/// Called only within a signed realm-wide inspection and its final authority
/// check. Snapshot the small live owner record; never enumerate physical files.
pub fn storageObservation(engine: *Engine) !core.protocol.Storage.Observation {
    const owner = engine.journal.backend;
    try owner.mutex.lock(owner.io);
    defer owner.mutex.unlock(owner.io);
    var result = core.protocol.Storage.Observation.unavailable;
    result.backend = .local;
    result.root = owner.resolved_root;
    result.allocated_bytes = owner.allocated;
    result.limits = owner.limits;
    result.maintenance = owner.maintenance_activity;
    result.settings = owner.maintenance_settings;
    return result;
}

pub fn observeMaintenance(engine: *Engine, running: bool, failure: ?anyerror) void {
    const owner = engine.journal.backend;
    owner.mutex.lockUncancelable(owner.io);
    defer owner.mutex.unlock(owner.io);
    const value = &owner.maintenance_activity;
    value.state = if (running) .running else if (failure != null) .failed else .waiting;
    if (running) return;
    if (failure) |err| {
        value.failed_steps = @min(core.protocol.max_counter, value.failed_steps +| 1);
        value.last_failure = switch (err) {
            error.StorageMaintenanceBudget, error.StorageQuota, error.OutOfMemory => .capacity,
            error.Forbidden, error.Unauthorized, error.CatalogDenied, error.AuthorizationChanged => .denied,
            error.ClockUnavailable, error.ClockUncertain, error.ClockRollback => .clock,
            error.MaintenanceTimeout => .timeout,
            error.LocalWalReopenRequired, error.WalRecoveryRequired => .recovery,
            error.InputOutput, error.NoSpaceLeft, error.DiskQuota => .storage,
            else => .other,
        };
    } else value.completed_steps = @min(core.protocol.max_counter, value.completed_steps +| 1);
}

pub const Lane = struct {
    journal: Store,
    pages: PageStore,
    engine: Engine,
    table: ?*TableHost = null,
    busy: bool = false,
    pages_epoch: u64 = 0,
    acquired_access: u64 = 0,
    acquired_created: u64 = 0,
    acquired_misses: u64 = 0,
};

pub fn readMetrics(engine: *Engine) ?server.Metrics {
    if (!engine.journal.observe.enabled) return null;
    var result: server.Metrics = undefined;
    inline for (@typeInfo(server.Metrics).@"struct".field_names) |field| {
        @field(result, field) = @field(engine.journal.observe.metrics, field) +| @field(engine.page_store.observe.metrics, field);
    }
    return result;
}
pub fn trace(engine: *Engine, parent: ?telemetry.Context) void {
    engine.journal.observe.parent = parent;
    engine.page_store.observe.parent = parent;
}

pub fn maintain(engine: *Engine, authorized: core.growing.Head) !bool {
    return (try engine.journal.maintainUnit(authorized)).complete;
}

pub fn collect(engine: *Engine, config: Maintenance.Config, key: core.Ed25519.KeyPair, request: *core.protocol.Growth.Request, cursor: *CollectionCursor) !bool {
    return Collection.step(cursor, engine, config, key, request);
}

pub fn reclaimPayload(engine: *Engine, value: core.protocol.Growth.Payload, signed: core.protocol.Growth.SignedRequest) !void {
    const Admission = struct {
        signed: core.protocol.Growth.SignedRequest,
        fn check(context: *anyopaque, authority: *Engine) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            try authority.authorizePayloadRetirement(self.signed);
        }
    };
    var admission: Admission = .{ .signed = signed };
    var store: backend.PayloadStore = .{ .engine = engine, .guard = .{ .context = &admission, .check = Admission.check } };
    try store.reclaimPayload(value);
}

pub fn payload(engine: *Engine, request: *const core.protocol.NativePayload.Request, response: *core.protocol.NativePayload.Response) !void {
    try request.validate();
    const Admission = struct {
        request: *const core.protocol.NativePayload.Request,
        fn check(context: *anyopaque, authority: *Engine) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            _ = try authority.authorizePayload(self.request.operation, self.request.proof);
        }
    };
    // This first observation selects an exact declaration. The adapter checks
    // both current authorization and that declaration again under its I/O fence.
    const value = try engine.authorizePayload(request.operation, request.proof);
    var admission: Admission = .{ .request = request };
    var store: backend.PayloadStore = .{ .engine = engine, .observe = engine.journal.observe, .guard = .{ .context = &admission, .check = Admission.check } };
    store.observe.metrics = .{};
    defer inline for (@typeInfo(@TypeOf(store.observe.metrics)).@"struct".field_names) |name| {
        @field(engine.journal.observe.metrics, name) +|= @field(store.observe.metrics, name);
    };
    response.* = .{ .definition = core.protocol.Growth.current_definition, .realm = engine.genesis.realm, .payload = value, .outcome = undefined, .body = .{} };
    switch (request.operation.kind) {
        .create => {
            store.createPayloadOnce(value, request.body.slice()) catch |err| {
                if (err != error.PayloadCreationAttempted) return err;
                response.outcome = .verify_required;
                return;
            };
            response.outcome = .created;
        },
        .verify => {
            try store.verifyPayload(value);
            response.outcome = .verified;
        },
        .read => {
            const bytes = try store.readPayload(value, response.body.data[0..core.protocol.max_payload_bytes]);
            response.body.len = @intCast(bytes.len);
            response.outcome = .read;
        },
    }
}
