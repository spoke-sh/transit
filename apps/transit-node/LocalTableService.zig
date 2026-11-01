//! Direct Table dispatch inside the local storage owner. The host coordinates
//! catalog DDL/admission and each Table's mutations before entering this helper.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Policy = @import("LocalCatalogPolicy.zig");
const Runner = @import("LocalCatalogRunner.zig");
const w = c.DirectTableProtocol;
const d = c.protocol.DataLifecycle;
const D = c.DirectCatalog;
const Self = @This();

engine: *backend.DataAuthority.Engine,
configuration: D.Configuration,
registrar: struct { principal: u64, key: c.protocol.Ed25519.KeyPair, role: ?u64 = null },
options: D.Options = .{},
/// Request-owned copy of the live host's validated catalog prefix. It contains
/// no policy, native owner, result buffer, or borrowed request allocation.
recovery_state: ?*D.RecoveryState = null,
resident: ?*Resident = null,
waiting: @FieldType(c.DirectStream.Environment, "waiting") = null,
/// Inject a real authority change after response serialization in fault proofs.
before_reply: ?struct { context: *anyopaque, run: *const fn (*anyopaque, *backend.DataAuthority.Engine) anyerror!void } = null,

/// One exclusively borrowed request workspace. Providers and retained owners
/// share this stable allocation; no policy, request scratch or result is kept.
pub const Resident = struct {
    allocator: std.mem.Allocator,
    memory: @import("transit_memory").Budget,
    probe: @import("transit_memory").AllocationProbe,
    control: backend.DataStore,
    data: backend.DataStore,
    catalog: D,
    table: ?D.CachedTable = null,
    stream: ?c.DirectStream.Cached = null,
    queue: ?c.DirectQueue.Cached = null,

    pub fn create(allocator: std.mem.Allocator, memory: @import("transit_memory").Budget, owner: *backend.Backend, configuration: D.Configuration, options: D.Options, prior: D.RecoveryState) !*Resident {
        const self = try allocator.create(Resident);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .memory = memory, .probe = .{ .parent = allocator }, .control = .{ .backend = owner, .control = true }, .data = .{ .backend = owner }, .catalog = undefined };
        self.memory.parent = self.probe.allocator();
        var cached_options = options;
        cached_options.table_owner = &self.table;
        self.catalog = D.init(self.memory.allocator(), configuration, self.control.log(), self.control.objects(), self.data.log(), self.data.objects(), cached_options) catch |err| return if (err == error.OutOfMemory and self.memory.exhausted) error.TableResidentCapacity else err;
        errdefer self.catalog.deinit();
        self.catalog.recoverSince(prior) catch |err| return if (err == error.OutOfMemory and self.memory.exhausted) error.TableResidentCapacity else err;
        return self;
    }
    pub fn destroy(self: *Resident) void {
        if (self.queue) |*cached| cached.deinit();
        if (self.stream) |*cached| cached.deinit();
        if (self.table) |*cached| cached.table.deinit();
        self.catalog.deinit();
        std.debug.assert(self.memory.used == 0);
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};

/// Temporary results borrow the work arena. The caller owns the separately
/// allocated response and may destroy the arena before sending it. The final
/// fence can still discard that response after a revocation race.
pub fn execute(self: *Self, arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: w.Request) ![]const u8 {
    return self.executeResult(.json, arena, output_allocator, request);
}
pub const Output = enum { json, typed };
pub fn Result(comptime output: Output) type {
    return if (output == .json) []const u8 else w.Response;
}
pub fn executeResult(self: *Self, comptime format: Output, arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: w.Request) !Result(format) {
    // An uncertain append, failed recovery or failed disclosure cannot leave a
    // warm Table hint behind. Full replay remains the next request's fallback.
    errdefer if (self.options.table_recovery) |slot| {
        slot.* = null;
    };
    const allocator = arena.allocator();
    try request.validate(allocator);
    if (!request.connection.matches(self.configuration)) return error.CatalogDenied;
    const context = try w.Request.context(request.input(), allocator);
    const original = if (request.closure) |closure|
        try closure.proof(request.delegation.?, allocator)
    else if (request.borrow) |borrow| try borrow.proof(request.delegation.?, allocator) else if (request.delegation) |delegation| delegation.proof else request.proof;
    const original_context = if (request.closure != null or request.borrow != null) original.claim.context else if (request.delegation) |delegation| try delegation.binding.context(allocator) else context;
    var policy = try Policy.init(self.engine, self.configuration, original, original_context, if (request.delegation != null) request.proof else null);
    policy.paged = request.action == .transaction or request.transaction != null;
    const owner = self.engine.journal.backend;
    var observation = self.engine.journal.observe;
    observation.metrics = .{};
    var request_control: backend.DataStore = .{ .backend = owner, .control = true };
    var request_data: backend.DataStore = .{ .backend = owner };
    const control = if (self.resident) |resident| &resident.control else &request_control;
    const data = if (self.resident) |resident| &resident.data else &request_data;
    if (control.backend != owner or data.backend != owner) return error.InvalidTableOwner;
    control.observe = observation;
    data.observe = observation;
    // These request-owned adapters borrow the lane's trace context, not its
    // counters. Merge their completed attempts even when execution fails.
    defer inline for (@typeInfo(@TypeOf(observation.metrics)).@"struct".field_names) |name| {
        @field(self.engine.journal.observe.metrics, name) +|= @field(control.observe.metrics, name);
        @field(self.engine.journal.observe.metrics, name) +|= @field(data.observe.metrics, name);
    };
    // Recovery, page owners and encoding scratch must actually release their
    // allocations when their scopes end. Only returned values borrow the arena.
    var request_catalog: ?D = null;
    defer if (request_catalog) |*catalog| catalog.deinit();
    const catalog = if (self.resident) |resident| blk: {
        resident.catalog.options.table_recovery = self.options.table_recovery;
        try resident.catalog.store.refresh();
        break :blk &resident.catalog;
    } else blk: {
        request_catalog = try D.init(arena.child_allocator, self.configuration, control.log(), control.objects(), data.log(), data.objects(), self.options);
        const catalog = &request_catalog.?;
        if (self.recovery_state) |prior| try catalog.recoverSince(prior.*) else try catalog.recover();
        break :blk catalog;
    };
    // Preserve fully accepted progress even when final disclosure is denied.
    // An uncertain append leaves recovery required and cannot advance this hint.
    defer if (self.recovery_state) |prior| {
        if (catalog.recoveryState()) |known| prior.* = known else |_| {}
    };
    if (request.lease) |lease| try catalog.requireClientLease(lease, policy.policy());
    const execution: c.DirectTableDispatch.Execution = .{ .context = self, .ddl = executeDdl, .namespace = executeNamespace, .resource = executeResource, .log = executeLog, .stream = executeStream, .queue = executeQueue };
    const result = if (request.transaction) |selected|
        try c.DirectTransactionRead.apply(allocator, catalog, policy.policy(), selected, request.action, execution)
    else
        try c.DirectTableDispatch.apply(allocator, catalog, policy.policy(), request.action, request.delegation, execution);
    const observed = try policy.observation();
    const response: w.Response = .{ .definition = c.protocol.Growth.current_definition, .context = context, .policy_revision = observed.revision, .subject = observed.subject, .result = result };
    // Both placements finish materialization before the same current-policy
    // fence. Typed outputs own their slices; they borrow neither request nor
    // resident workspace. The typed caller supplies a response arena.
    const output = if (format == .json)
        try c.protocol.Json.valueAllocBounded(output_allocator, response, w.max_response_bytes)
    else
        try c.client.LocalEndpoint.clone(output_allocator, response);
    errdefer if (format == .json) output_allocator.free(output);
    if (self.before_reply) |inject| try inject.run(inject.context, self.engine);
    if (!std.meta.eql(try policy.observation(), observed)) return error.AuthorizationChanged;
    return output;
}

fn streamTime(raw: *anyopaque) !?c.storage.LogTime.Sample {
    const self: *Self = @ptrCast(@alignCast(raw));
    const source = @import("LocalLogClock.zig").source(self.engine);
    return source.read(source.context);
}

fn executeStream(raw: *anyopaque, output: std.mem.Allocator, catalog: *D, policy: D.Policy, request: c.DirectStream.Request) !c.DirectStream.Result {
    const self: *Self = @ptrCast(@alignCast(raw));
    var scratch: std.heap.ArenaAllocator = .init(catalog.allocator);
    defer scratch.deinit();
    var temporary: ?c.DirectStream.Cached = null;
    defer if (temporary) |*cached| cached.deinit();
    const slot = if (self.resident) |resident| &resident.stream else &temporary;
    var seed = self.registrar.key.secret_key.seed();
    defer std.crypto.secureZero(u8, &seed);
    var secret: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &secret);
    std.crypto.auth.hmac.sha2.HmacSha256.create(&secret, "transit.catalog.stream.cursor.v1\x00", &seed);
    return c.DirectStream.apply(scratch.allocator(), output, catalog, slot, catalog.options.logs.stream, .{
        .authority = .{ .secret = secret },
        .clock = if (self.engine.clock != null) .{ .context = self, .read = streamTime } else null,
        .waiting = self.waiting,
    }, request, policy);
}

fn executeDdl(raw: *anyopaque, catalog: *D, binding: d.Binding, policy: D.Policy, steps: u16) !D.Observation {
    const self: *Self = @ptrCast(@alignCast(raw));
    var runner: Runner = .{ .engine = self.engine, .principal = self.registrar.principal, .key = self.registrar.key, .role = self.registrar.role };
    return (try runner.run(catalog, binding, policy, steps)).observation;
}
fn executeQueue(raw: *anyopaque, output: std.mem.Allocator, catalog: *D, policy: D.Policy, request: c.DirectQueue.Request) !c.DirectQueue.Result {
    const self: *Self = @ptrCast(@alignCast(raw));
    var scratch: std.heap.ArenaAllocator = .init(catalog.allocator);
    defer scratch.deinit();
    var temporary: ?c.DirectQueue.Cached = null;
    defer if (temporary) |*cached| cached.deinit();
    const slot = if (self.resident) |resident| &resident.queue else &temporary;
    return c.DirectQueue.apply(scratch.allocator(), output, catalog, slot, catalog.options.logs.queue, .{
        .waiting = self.waiting,
        .clock = if (self.engine.clock != null) .{ .context = self, .read = streamTime } else null,
    }, request, policy);
}
fn executeNamespace(raw: *anyopaque, catalog: *D, binding: c.DirectNamespace.Binding, policy: D.Policy, steps: u16) !c.DirectNamespace.Observation {
    const self: *Self = @ptrCast(@alignCast(raw));
    var runner: Runner = .{ .engine = self.engine, .principal = self.registrar.principal, .key = self.registrar.key, .role = self.registrar.role };
    return (try runner.runNamespace(catalog, binding, policy, steps)).observation;
}

fn executeResource(raw: *anyopaque, catalog: *D, binding: c.DirectResource.Binding, policy: D.Policy, command: c.DirectResource.Command, steps: u16, signed_allocation: ?c.DirectResource.SignedAllocation) !c.DirectResource.Observation {
    const self: *Self = @ptrCast(@alignCast(raw));
    var runner: Runner = .{ .engine = self.engine, .principal = self.registrar.principal, .key = self.registrar.key, .role = self.registrar.role };
    return (try runner.runResource(catalog, binding, policy, command, steps, signed_allocation)).observation;
}
fn executeLog(raw: *anyopaque, catalog: *D, binding: d.Binding, policy: D.Policy, steps: u16) !c.DirectLog.Observation {
    const self: *Self = @ptrCast(@alignCast(raw));
    var runner: Runner = .{ .engine = self.engine, .principal = self.registrar.principal, .key = self.registrar.key, .role = self.registrar.role };
    return runner.runLog(catalog, binding, policy, steps);
}
