//! Event-driven recovery of explicit captured/configuration operations. One
//! consumer owns persistent transports; scans rotate accounts and retain only
//! bounded cursors. Catalog records remain the restart/replacement authority.
const std = @import("std");
const g = @import("root.zig");
const Self = @This();
allocator: std.mem.Allocator,
io: std.Io,
runtimes: []const *g.DatabaseRuntime,
clients: []g.wire.Client,
work: g.database.RecoveryWork = .{},
generation: ?u64 = null,
index: usize = 0,
after: [g.Limits.max_accounts]u64 = @splat(0),
complete: [g.Limits.max_accounts]bool = @splat(false),
retry: bool = false,

pub fn init(allocator: std.mem.Allocator, io: std.Io, config: *const g.Configuration, runtimes: []const *g.DatabaseRuntime) !*Self {
    if (runtimes.len > g.Limits.max_accounts) return error.InvalidGatewayConfiguration;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    const clients = try allocator.alloc(g.wire.Client, runtimes.len);
    self.* = .{ .allocator = allocator, .io = io, .runtimes = runtimes, .clients = clients };
    for (clients, runtimes) |*client, runtime| {
        client.* = g.wire.Client.init(allocator, io, config.native_url);
        client.local = runtime.background.local;
        client.timeout_ms = config.request_timeout_ms;
        std.debug.assert(runtime.external_work == null);
        runtime.external_work = &self.work;
    }
    return self;
}
/// The host joins recovery and foreground borrowers before releasing this owner.
pub fn deinit(self: *Self) void {
    for (self.clients, self.runtimes) |*client, runtime| {
        std.debug.assert(runtime.external_work == &self.work);
        runtime.external_work = null;
        client.deinit();
    }
    self.allocator.free(self.clients);
    const allocator = self.allocator;
    allocator.destroy(self);
}
fn finish(self: *Self, retry: bool) void {
    self.work.finish(self.io, self.generation.?, retry);
    self.generation = null;
}
/// At most one indexed operation from one account per turn. Even a final page
/// containing several entries advances to its remaining suffix before parking.
pub fn step(self: *Self, registry: *g.Registry) !bool {
    if (self.generation == null) {
        self.generation = self.work.begin(self.io) orelse return false;
        self.after = @splat(0);
        self.complete = @splat(false);
        self.retry = false;
    }
    const index = for (0..self.runtimes.len) |_| {
        const next = self.index;
        self.index = (next + 1) % self.runtimes.len;
        if (!self.complete[next]) break next;
    } else {
        self.finish(self.retry);
        return false;
    };
    errdefer {
        // A failed account retains retry debt and cannot starve other accounts.
        self.complete[index] = true;
        self.retry = true;
    }
    const runtime = self.runtimes[index];
    if (!runtime.ready.load(.acquire)) {
        self.complete[index] = true;
        self.retry = true;
        return true;
    }
    const account = &registry.configuration.accounts[index];
    var observer: g.Client = .{ .transport = &self.clients[index], .execution = runtime.execution, .principal = account.execution.table_principal, .key = runtime.ingress.key, .lease = runtime.lease() };
    try runtime.fence(&observer);
    var source = try observer.source();
    const page = try g.SessionOperations.list(runtime.execution, &source, self.after[index], true);
    const reference = page.entries[0] orelse {
        self.complete[index] = page.next == null;
        if (page.next) |next| self.after[index] = next;
        return true;
    };
    self.after[index] = reference.id;
    if (page.next == null and page.entries[1] == null) self.complete[index] = true;
    if (reference.kind == .table or reference.kind == .transaction) return true;
    try self.advanceOperation(registry, index, &source, reference);
    // Terminal evidence can precede bookkeeping/cleanup. Only the durable
    // pending bit discharges this recovery obligation.
    if ((try source.operation(reference.id)).pending) self.retry = true;
    return true;
}
fn advanceOperation(self: *Self, registry: *g.Registry, index: usize, source: *g.Client.Source, reference: g.SessionOperations.Reference) !void {
    defer registry.recovery_reserve.reset(true) catch unreachable;
    var memory: g.query.QueryMemory = .{ .parent = registry.recovery_reserve.allocator(), .limit = registry.configuration.limits.session_bytes };
    const allocator = memory.allocator();
    const runtime = self.runtimes[index];
    const account = &registry.configuration.accounts[index];
    const item = try g.SessionOperations.external(runtime.execution, source, reference.id);
    const database = for (account.databases) |database| {
        if (std.meta.eql(database.binding, item.binding())) break database.name;
    } else return error.SqlOperationBindingChanged;
    var cancelled: std.atomic.Value(bool) = .init(false);
    var active: std.atomic.Value(bool) = .init(false);
    const host = try g.Session.init(allocator, self.io, registry.configuration, index, runtime, try g.Session.loadCredential(allocator, self.io, account), database, .transit, &cancelled, &active);
    defer host.deinit();
    host.recovering = true;
    try host.begin();
    defer host.end();
    switch (reference.kind) {
        .dataflow => _ = try g.ManagedOperations.resumeOperation(host, reference.id),
        .configuration => _ = try g.ConfigurationOperations.resumeOperation(host, reference.id),
        .captured => {
            try g.CapturedOperations.select(host, reference.id);
            _ = try g.CapturedOperations.resumeOperation(host, reference.id);
        },
        .table, .transaction => unreachable,
    }
}
