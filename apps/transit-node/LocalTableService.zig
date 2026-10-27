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
/// Inject a real authority change after response serialization in fault proofs.
before_reply: ?struct { context: *anyopaque, run: *const fn (*anyopaque, *backend.DataAuthority.Engine) anyerror!void } = null,

/// All borrowed result fields live in the request arena until the buffered
/// response is sent. The final fence can discard it after a revocation race.
pub fn execute(self: *Self, arena: *std.heap.ArenaAllocator, request: w.Request, output: []u8) ![]const u8 {
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
    const owner = self.engine.journal.backend;
    var observation = self.engine.journal.observe;
    observation.metrics = .{};
    var control: backend.DataStore = .{ .backend = owner, .control = true, .observe = observation };
    var data: backend.DataStore = .{ .backend = owner, .observe = observation };
    // These request-owned adapters borrow the lane's trace context, not its
    // counters. Merge their completed attempts even when execution fails.
    defer inline for (@typeInfo(@TypeOf(observation.metrics)).@"struct".field_names) |name| {
        @field(self.engine.journal.observe.metrics, name) +|= @field(control.observe.metrics, name);
        @field(self.engine.journal.observe.metrics, name) +|= @field(data.observe.metrics, name);
    };
    var catalog = try D.init(allocator, self.configuration, control.log(), control.objects(), data.log(), data.objects(), self.options);
    defer catalog.deinit();
    if (self.recovery_state) |prior| try catalog.recoverSince(prior.*) else try catalog.recover();
    // Preserve fully accepted progress even when final disclosure is denied.
    // An uncertain append leaves recovery required and cannot advance this hint.
    defer if (self.recovery_state) |prior| {
        if (catalog.recoveryState()) |known| prior.* = known else |_| {}
    };
    const result = try c.DirectTableDispatch.apply(allocator, &catalog, policy.policy(), request.action, request.delegation, .{ .context = self, .ddl = executeDdl, .namespace = executeNamespace, .resource = executeResource });
    const observed = try policy.observation();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, w.max_response_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try c.protocol.Json.write(w.Response{ .definition = c.protocol.Growth.current_definition, .context = context, .policy_revision = observed.revision, .subject = observed.subject, .result = result }, &encoder);
    if (self.before_reply) |inject| try inject.run(inject.context, self.engine);
    if (!std.meta.eql(try policy.observation(), observed)) return error.AuthorizationChanged;
    return writer.buffered();
}

fn executeDdl(raw: *anyopaque, catalog: *D, binding: d.Binding, policy: D.Policy, steps: u16) !D.Observation {
    const self: *Self = @ptrCast(@alignCast(raw));
    var runner: Runner = .{ .engine = self.engine, .principal = self.registrar.principal, .key = self.registrar.key, .role = self.registrar.role };
    return (try runner.run(catalog, binding, policy, steps)).observation;
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
