//! Native v1 service over the paged authority. Incompatible histories reject.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const wire = @import("transit_client");
const observations = @import("transit_observability");
const telemetry = observations.telemetry;
const g = wire.protocol.Growth;
pub const Store = adapter.Store;
pub const PageStore = adapter.PackedPageStore;
pub const Engine = core.growing.Engine(Store, PageStore);
const Maintenance = @import("GrowingMaintenance.zig");
// Admission admits four reads, two controls and four long polls. Each admitted
// request exclusively owns one lane; idle HTTP connections own no lane.
const lane_count = 10;
const Config = struct {
    profile: enum { native_v1 } = .native_v1,
    genesis: core.growing.Genesis,
    ursula_url: []const u8,
    bucket: []const u8,
    journal: []const u8,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    request_timeout_ms: u32 = 2000,
    resident_pages: u16 = 512,
    storage: core.protocol.Storage.Settings = .{},
    accept_trace_parent: bool = false,
    request_metrics: bool = false,
    maintenance: ?Maintenance.Config = null,
};

pub fn run(init: std.process.Init, bytes: []const u8, mode: anytype, diagnostics: *telemetry.Runtime) !void {
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    try config.storage.limits.validate();
    try config.storage.maintenance.flush.validate();
    if (config.storage.maintenance.flush.enabled) return error.TableMaintenanceUnavailable;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidTimeout;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = config.ursula_url, .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    var metrics: adapter.Metrics = .{};
    var journal: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = config.bucket, .name = config.journal }, .observer = diagnostics, .metrics = if (config.request_metrics) &metrics else null } };
    var pages = try adapter.PackedPageStore.init(init.gpa, journal.journal, config.resident_pages);
    defer pages.deinit();
    pages.limits = config.storage.limits;
    if (mode.initialize or mode.bootstrap) {
        var existing = try journal.journal.send(.{ .head = .{ .stream = journal.journal.stream } });
        defer existing.deinit();
        if (existing.head.status == .not_found) try journal.journal.create() else try existing.head.requireSuccess();
        if (try journal.tail() == 0) {
            try pages.create();
        } else {
            // Validate the existing definition/genesis before creating any
            // current-layout work ledger on an incompatible installation.
            _ = try Engine.open(&journal, &pages, config.genesis);
        }
    }
    var recovery = observations.begin(diagnostics, .recovery, if (mode.initialize or mode.bootstrap) "bootstrap" else "open", null);
    journal.journal.parent_context = recovery.span.context;
    pages.authority.parent_context = recovery.span.context;
    var engine = (if (mode.initialize or mode.bootstrap) Engine.bootstrap(&journal, &pages, config.genesis) else openRetained(init.io, &journal, &pages, config.genesis)) catch |err| {
        recovery.fail(err);
        recovery.finish();
        return err;
    };
    var allocation_queue = try pages.allocations();
    _ = try allocation_queue.current();
    var collection = adapter.StorageCollection.init(journal.journal);
    _ = try collection.current();
    recovery.event.realm = config.genesis.realm;
    recovery.event.position = engine.head.position;
    recovery.finish();
    journal.journal.parent_context = null;
    pages.authority.parent_context = null;
    if (mode.initialize) return;
    var clock_context: u8 = 0;
    if (config.genesis.max_clock_error_ms != null) engine.clock = .{ .context = &clock_context, .read = @import("Clock.zig").read };
    if (mode.maintain) {
        var maintenance = config.maintenance orelse return error.MissingMaintenanceConfig;
        maintenance.storage = config.storage.maintenance;
        return Maintenance.run(@This(), init, &engine, maintenance, diagnostics, null);
    }
    var snapshot_epoch: [16]u8 = undefined;
    try init.io.randomSecure(&snapshot_epoch);
    engine.snapshot_epoch = snapshot_epoch;
    const lanes = try init.gpa.alloc(Lane, lane_count);
    defer init.gpa.free(lanes);
    var initialized: usize = 0;
    defer for (lanes[0..initialized]) |*lane| lane.deinit();
    for (lanes) |*lane| {
        try lane.init(init.gpa, init.io, config, engine, diagnostics);
        initialized += 1;
    }
    return @import("NativeServer.zig").Host(@This()).serve(init, &engine, lanes, config, diagnostics);
}

pub const Lane = struct {
    client: adapter.ursula.Client,
    metrics: adapter.Metrics,
    journal: adapter.Store,
    pages: adapter.PackedPageStore,
    engine: Engine,
    busy: bool = false,
    pages_epoch: u64 = 0,
    acquired_access: u64 = 0,
    acquired_created: u64 = 0,
    acquired_misses: u64 = 0,
    fn init(self: *Lane, allocator: std.mem.Allocator, io: std.Io, config: Config, basis: Engine, diagnostics: *telemetry.Runtime) !void {
        self.* = undefined;
        self.busy = false;
        self.pages_epoch = 0;
        self.acquired_access = 0;
        self.acquired_created = 0;
        self.acquired_misses = 0;
        self.client = try adapter.ursula.Client.init(allocator, io, .{ .base_url = config.ursula_url, .max_response_bytes = 256 * 1024 });
        errdefer self.client.deinit();
        self.metrics = .{};
        self.journal = .{ .journal = .{ .client = &self.client, .stream = .{ .bucket = config.bucket, .name = config.journal }, .observer = diagnostics, .metrics = if (config.request_metrics) &self.metrics else null } };
        self.pages = try adapter.PackedPageStore.init(allocator, self.journal.journal, config.resident_pages);
        self.pages.limits = config.storage.limits;
        self.engine = basis;
        self.engine.journal = &self.journal;
        self.engine.page_store = &self.pages;
    }
    fn deinit(self: *Lane) void {
        self.pages.deinit();
        self.client.deinit();
    }
};

fn openRetained(io: std.Io, journal: *adapter.Store, pages: *adapter.PackedPageStore, genesis: core.growing.Genesis) !Engine {
    // Ordinary recovery only reads published history. A transient provider
    // failure can be retried without creating a realm or replaying effects.
    // Corrupt, missing, denied or incompatible history remains a hard failure.
    for (0..3) |attempt| {
        return Engine.open(journal, pages, genesis) catch |err| {
            const temporary = switch (err) {
                error.ServiceUnavailable,
                error.NameServerFailure,
                error.ConnectionRefused,
                error.ConnectionTimedOut,
                error.NetworkUnreachable,
                error.HostUnreachable,
                error.ConnectionResetByPeer,
                error.HttpConnectionClosing,
                error.EndOfStream,
                error.ReadFailed,
                error.WriteFailed,
                => true,
                else => false,
            };
            if (!temporary or attempt == 2) return err;
            try io.sleep(.fromMilliseconds(100), .awake);
            continue;
        };
    }
    unreachable;
}

pub fn readMetrics(engine: *Engine) ?@import("NativeServer.zig").Metrics {
    const counters = engine.journal.journal.metrics orelse return null;
    var result: @import("NativeServer.zig").Metrics = undefined;
    inline for (@typeInfo(@TypeOf(result)).@"struct".field_names) |field| @field(result, field) = @field(counters.*, field);
    return result;
}

pub fn trace(engine: *Engine, parent: ?telemetry.Context) void {
    engine.journal.journal.parent_context = parent;
    engine.page_store.authority.parent_context = parent;
}

pub fn maintain(engine: *Engine, authorized: core.growing.Head) !bool {
    try engine.journal.maintain(authorized);
    return true;
}

pub fn collect(engine: *Engine, config: Maintenance.Config, key: core.Ed25519.KeyPair, request: *g.Request) !bool {
    var collection = adapter.StorageCollection.init(engine.journal.journal);
    const saved = try collection.current();
    if (saved != null and saved.?.phase != .complete) {
        const now = try engine.clock.?.sample();
        if (saved.?.phase == .wait and now.lower() > saved.?.grace_until_ms and engine.head.time_floor_ms <= saved.?.grace_until_ms) {
            request.command = .{ .storage_fence = {} };
            _ = try engine.submit(try g.sign(request.*, key));
            return true;
        }
        return collection.step(engine, now);
    }
    var queue = try engine.page_store.allocations();
    const inventory = try queue.current();
    const previous = if (saved) |value| value.inventory_end else 0;
    if ((saved != null and saved.?.aborted) or inventory.position + 1 - previous >= config.storage.collection_every_records) {
        if (config.storage.compact and engine.head.compaction.phase != .complete) {
            request.command = .{ .storage_compact = {} };
            _ = try engine.submit(try g.sign(request.*, key));
            return true;
        }
        request.command = .{ .storage_fence = {} };
        const fence = try engine.submit(try g.sign(request.*, key));
        try collection.start(engine, fence);
        return true;
    }
    return false;
}

pub fn reclaimPayload(engine: *Engine, payload: g.Payload, signed: g.SignedRequest) !void {
    try engine.authorizePayloadRetirement(signed);
    var payloads: adapter.PayloadStore = .{ .journal = &engine.journal.journal };
    try payloads.reclaimPayload(payload);
}
