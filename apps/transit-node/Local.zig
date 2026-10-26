//! Local native node composition. Request semantics live in NativeServer.
const std = @import("std");
const core = @import("transit_core");
const backend = @import("transit_backend_local");
const telemetry = @import("transit_observability").telemetry;
const server = @import("NativeServer.zig");
const Maintenance = @import("GrowingMaintenance.zig");
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
    if (mode.maintain) return error.LocalMaintenanceRequiresOwner;
    if (config.storage.maintenance.compact) return error.LocalCompactionUnavailable;
    var owner = try backend.Backend.open(init.gpa, init.io, std.Io.Dir.cwd(), config.local_directory, config.storage.limits);
    defer owner.deinit();
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
    const lanes = try init.gpa.alloc(Lane, 10);
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
    if (config.maintenance) |configured| {
        // This lane shares only the exclusive physical owner. Its mutable
        // authority, cache and scanner are private to the maintenance task.
        var maintenance_pages = try PageStore.init(&owner, config.resident_pages);
        defer maintenance_pages.deinit();
        maintenance_pages.observe = .{ .runtime = diagnostics, .enabled = config.request_metrics };
        var maintenance_journal: Store = .{ .backend = &owner, .observe = .{ .runtime = diagnostics, .enabled = config.request_metrics } };
        var maintenance_engine = engine;
        maintenance_engine.journal = &maintenance_journal;
        maintenance_engine.page_store = &maintenance_pages;
        var maintenance = configured;
        maintenance.storage = config.storage.maintenance;
        const Task = struct {
            fn run(process: std.process.Init, owned: *Engine, settings: Maintenance.Config, runtime: *telemetry.Runtime) anyerror!void {
                return Maintenance.run(Self, process, owned, settings, runtime);
            }
            fn serve(process: std.process.Init, authority: *Engine, requests: []Lane, settings: Config, runtime: *telemetry.Runtime) anyerror!void {
                return server.Host(Self).serve(process, authority, requests, settings, runtime);
            }
        };
        const Result = union(enum) { server: anyerror!void, maintenance: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(init.io, &results);
        defer select.cancelDiscard(); // Join both tasks before releasing the owner.
        try select.concurrent(.maintenance, Task.run, .{ init, &maintenance_engine, maintenance, diagnostics });
        try select.concurrent(.server, Task.serve, .{ init, &engine, lanes, config, diagnostics });
        return switch (try select.await()) {
            .server => |result| result,
            .maintenance => |result| result,
        };
    }
    return server.Host(@This()).serve(init, &engine, lanes, config, diagnostics);
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

pub fn collect(_: *Engine, _: Maintenance.Config, _: core.Ed25519.KeyPair, _: *core.protocol.Growth.Request) !bool {
    // The backend exposes explicit native collection; this runtime does not
    // schedule it. Logical lifecycle progress is not physical reclamation.
    return false;
}

pub fn reclaimPayload(_: *Engine, _: core.protocol.Growth.Payload) !void {
    return error.LocalPayloadReclamationUnavailable;
}
