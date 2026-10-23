//! Local native node composition. Request semantics live in NativeServer.
const std = @import("std");
const core = @import("transit_core");
const backend = @import("transit_backend_local");
const telemetry = @import("transit_observability").telemetry;
const server = @import("NativeServer.zig");
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
};

pub fn run(init: std.process.Init, bytes: []const u8, mode: anytype, diagnostics: *telemetry.Runtime) !void {
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidTimeout;
    if (config.request_metrics) return error.LocalRequestMetricsUnsupported;
    if (mode.maintain) return error.LocalMaintenanceRequiresOwner;
    var owner = try backend.Backend.open(init.gpa, init.io, std.Io.Dir.cwd(), config.local_directory, config.storage.limits);
    defer owner.deinit();
    var pages = try PageStore.init(&owner, config.resident_pages);
    defer pages.deinit();
    var journal: Store = .{ .backend = &owner };
    var recovery = @import("transit_observability").begin(diagnostics, .recovery, if (mode.initialize or mode.bootstrap) "bootstrap" else "open", null);
    var engine = (if (mode.initialize or mode.bootstrap) Engine.bootstrap(&journal, &pages, config.genesis) else Engine.open(&journal, &pages, config.genesis)) catch |err| {
        recovery.fail(err);
        recovery.finish();
        return err;
    };
    recovery.event.realm = config.genesis.realm;
    recovery.event.position = engine.head.position;
    recovery.finish();
    if (mode.initialize) return;
    var clock_context: u8 = 0;
    if (config.genesis.max_clock_error_ms != null) engine.clock = .{ .context = &clock_context, .read = @import("Clock.zig").read };
    var snapshot_epoch: [16]u8 = undefined;
    try init.io.randomSecure(&snapshot_epoch);
    engine.snapshot_epoch = snapshot_epoch;
    const lanes = try init.gpa.alloc(Lane, 10);
    defer init.gpa.free(lanes);
    var initialized: usize = 0;
    defer for (lanes[0..initialized]) |*lane| lane.pages.deinit();
    for (lanes) |*lane| {
        lane.* = .{ .journal = .{ .backend = &owner }, .pages = try PageStore.init(&owner, config.resident_pages), .engine = engine };
        lane.engine.journal = &lane.journal;
        lane.engine.page_store = &lane.pages;
        initialized += 1;
    }
    return server.Host(@This()).serve(init, &engine, lanes, config, diagnostics);
}

pub const Lane = struct {
    journal: Store,
    pages: PageStore,
    engine: Engine,
    busy: bool = false,
    pages_epoch: u64 = 0,
    acquired_access: u64 = 0,
    acquired_created: u64 = 0,
    acquired_misses: u64 = 0,
};

pub fn readMetrics(_: *Engine) ?server.Metrics {
    return null;
}
pub fn trace(_: *Engine, _: ?telemetry.Context) void {}
