//! Per-evaluation composition of a transient request, scoped native authority
//! and private secret mount. The original Queue input selects the reservation;
//! no current environment value or ambient worker context can replace it.
const std = @import("std");
const q = @import("transit_query_direct");
const c = q.catalog;
const a = q.fuze.ApplicationProgram;
const V = a.Values.Value;
const Requests = @import("ApplicationRequests.zig");
const Reservation = @import("ApplicationReservation.zig");
const Protected = @import("ApplicationProtectedHost.zig");
const Secrets = @import("ApplicationSecrets.zig");
const Authority = @import("ApplicationAuthority.zig");
const Self = @This();

pub const Mount = struct {
    scope: c.protocol.DataLifecycle.Scope,
    namespace: u64,
    directory: std.Io.Dir,
};
registry: *Requests,
/// Immutable deployment-owned mounts; directories and this slice outlive all
/// evaluations. A mount is physical placement, never a native permission grant.
mounts: []const Mount,

pub fn init(registry: *Requests, mounts: []const Mount) !Self {
    for (mounts, 0..) |mount, index| {
        try mount.scope.validate();
        try c.Model.nativeId(mount.namespace);
        for (mounts[0..index]) |previous| if (previous.namespace == mount.namespace and std.meta.eql(previous.scope, mount.scope)) return error.DuplicateProgramNativeBinding;
    }
    return .{ .registry = registry, .mounts = mounts };
}
pub fn host(self: *Self) q.ApplicationExecution.Host {
    return .{ .context = self, .ready = requireReady, .bind = bind };
}
pub fn available() a.Types.Requirements {
    var result = q.ApplicationHost.available();
    result.functions = result.functions.unionWith(.initMany(&.{ .secret, .random_secret, .derive_secret, .secret_current, .http_query, .http_query_unique, .http_secret_query_unique, .http_secret_cookie_unique, .secret_json_value, .bearer }));
    result.features.insert(.protected_values);
    return result;
}
fn requireReady(context: *anyopaque, allocator: std.mem.Allocator, declaration: q.ManagedApplication.Declaration) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    var bound = try declaration.bind(allocator);
    defer bound.deinit();
    try bound.requirements.requireAvailable(available());
    if (bound.native.contains(.secret_references)) {
        const binding = try secretBinding(declaration) orelse return error.ApplicationHostUnavailable;
        if (self.findMount(binding) == null) return error.ApplicationHostUnavailable;
    }
}
fn requestReference(input: q.ApplicationInvocation.Input) !?a.Values.Reference {
    if (input.definition != c.protocol.Growth.current_definition or input.environment.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    if (input.environment.values.len != 1 or input.environment.values[0].instruction != 0 or input.environment.values[0].value != .record) return error.InvalidDirectRecord;
    var selected: ?a.Values.Reference = null;
    for (input.environment.values[0].value.record) |field| if (field.value == .capability) {
        if (selected != null) return error.ProgramArgumentMismatch;
        selected = field.value.capability;
    };
    return selected;
}
fn secretBinding(declaration: q.ManagedApplication.Declaration) !?c.DirectSecret.Binding {
    var selected: ?c.DirectSecret.Binding = null;
    for (declaration.resources) |resource| if (resource.nativeBinding() == .secret_references) {
        if (selected != null) return error.DuplicateProgramNativeBinding;
        selected = .{ .namespace = resource.namespace(), .interpretation = resource.interpretation() };
    };
    if (selected) |binding| try binding.validate();
    return selected;
}
fn findMount(self: *Self, binding: c.DirectSecret.Binding) ?std.Io.Dir {
    for (self.mounts) |entry| {
        if (entry.namespace == binding.namespace and std.meta.eql(entry.scope, binding.interpretation.object.scope)) return entry.directory;
    }
    return null;
}
fn secret(self: *Self, scope: q.ApplicationExecution.Context) !?Secrets {
    const binding = try secretBinding(scope.declaration) orelse return null;
    return .{ .client = scope.client, .binding = binding, .io = self.registry.io, .directory = self.findMount(binding) orelse return null };
}
fn bind(context: *anyopaque, scope: q.ApplicationExecution.Context) !q.ApplicationExecution.BoundHost {
    const self: *Self = @ptrCast(@alignCast(context));
    const reference = try requestReference(scope.input);
    const binding = try scope.scratch.create(Binding);
    binding.* = .{ .ordinary = .{ .scratch = scope.scratch, .io = self.registry.io, .scope = scope } };
    errdefer binding.finish();
    if (reference) |request| {
        binding.borrow = self.registry.borrow(.{ .reference = request }, scope.input.source) catch |err| switch (err) {
            // Transient loss cannot prevent a failure handler from recording
            // public state/receipts. Only use of the missing request fails.
            error.ApplicationReservationLost, error.ApplicationReservationExpired => lost: {
                binding.unavailable = err;
                break :lost null;
            },
            else => return err,
        };
        if (binding.borrow) |borrowed| {
            const view = try borrowed.view();
            binding.secrets = try self.secret(scope);
            binding.authority = .{ .scope = scope, .secrets = if (binding.secrets) |*value| value else null };
            view.reservation.authority = .{ .context = binding, .check = Binding.check };
            binding.protected = .{
                .reservation = view.reservation,
                .access = .{ .owner = scope.invocation, .input = scope.input.source, .now_ms = std.math.cast(u64, std.Io.Clock.awake.now(self.registry.io).toMilliseconds()) orelse return error.ClockUnavailable },
                .step = scope.step,
                .io = self.registry.io,
                .output = scope.scratch,
                .private_memory = view.private_memory,
                .request = view.request,
                .secrets = .{ .context = binding, .lookup = Binding.secretLookup, .current = Binding.secretCurrent },
                .ordinary = binding.ordinary.host(),
            };
        }
    }
    return .{ .expressions = .{ .context = binding, .lookup = Binding.lookup, .evaluate = Binding.evaluate, .condition = Binding.condition }, .release = Binding.release };
}
const Binding = struct {
    ordinary: q.ApplicationHost,
    borrow: ?Requests.Borrow = null,
    secrets: ?Secrets = null,
    authority: ?Authority = null,
    protected: ?Protected = null,
    unavailable: anyerror = error.MissingProgramNativeBinding,

    fn finish(self: *Binding) void {
        if (self.borrow) |*borrowed| borrowed.deinit();
        // Optional payloads contain scoped clients, including their signing
        // keys. Clearing only the optional tags leaves those copies in scratch.
        // Remove callbacks from the registry first, then erase this whole borrow.
        std.crypto.secureZero(u8, std.mem.asBytes(self));
    }
    fn release(context: *anyopaque) void {
        const self: *Binding = @ptrCast(@alignCast(context));
        self.finish();
    }
    fn check(context: *anyopaque, evidence: Reservation.Evidence) !void {
        const self: *Binding = @ptrCast(@alignCast(context));
        const borrowed = self.borrow orelse return error.ApplicationReservationLost;
        try borrowed.requireLive();
        const authority = if (self.authority) |*value| value.authority() else return error.MissingProgramNativeBinding;
        try authority.check(authority.context, evidence);
    }
    fn secretLookup(context: *anyopaque, private: std.mem.Allocator, name: []const u8) !Reservation.Material {
        const self: *Binding = @ptrCast(@alignCast(context));
        const callbacks = if (self.secrets) |*value| value.callbacks() else return error.MissingProgramNativeBinding;
        return callbacks.lookup(callbacks.context, private, name);
    }
    fn secretCurrent(context: *anyopaque, revision: []const u8) !bool {
        const self: *Binding = @ptrCast(@alignCast(context));
        const callbacks = if (self.secrets) |*value| value.callbacks() else return error.MissingProgramNativeBinding;
        return callbacks.current(callbacks.context, revision);
    }
    fn lookup(context: *anyopaque, name: []const u8) !V {
        const self: *Binding = @ptrCast(@alignCast(context));
        const ordinary = self.ordinary.host();
        return ordinary.lookup(ordinary.context, name);
    }
    fn evaluate(context: *anyopaque, node: a.Id, operation: a.Evaluation.Operation, args: []const V) !V {
        const self: *Binding = @ptrCast(@alignCast(context));
        if (self.protected) |*protected| {
            const borrowed = self.borrow orelse return error.ApplicationReservationLost;
            try borrowed.requireLive();
            const selected = protected.host();
            const result = try selected.evaluate(selected.context, node, operation, args);
            try borrowed.requireLive();
            return result;
        }
        // Public time, identifiers, receipts and guarded state observations
        // remain available after the request is gone. Never recreate a secret
        // or protected observation under a replacement reservation.
        if (operation != .function) return self.unavailable;
        for (args) |arg| arg.public() catch return self.unavailable;
        switch (operation.function) {
            .secret,
            .random_secret,
            .derive_secret,
            .secret_current,
            .http_query,
            .http_query_unique,
            .http_secret_query_unique,
            .http_secret_cookie_unique,
            .secret_json_value,
            .bearer,
            => return self.unavailable,
            else => {},
        }
        const ordinary = self.ordinary.host();
        return ordinary.evaluate(ordinary.context, node, operation, args);
    }
    fn condition(context: *anyopaque, value: V) !bool {
        const self: *Binding = @ptrCast(@alignCast(context));
        const selected = if (self.protected) |*protected| protected.host() else return self.unavailable;
        const borrowed = self.borrow orelse return error.ApplicationReservationLost;
        try borrowed.requireLive();
        const result = try selected.condition(selected.context, value);
        try borrowed.requireLive();
        return result;
    }
};

test "application request host selection uses only the original input and keeps public failure observations available" {
    const t = std.testing;
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    var registry = try Requests.init(t.allocator, t.io, .{ .active_requests = 1, .request_bytes = 512, .protected_bytes = 1024, .protected_values = 4, .scratch_bytes = 1024, .resident_bytes = 64 * 1024 });
    defer registry.deinit();
    var self = try init(&registry, &.{});
    const factory = self.host();
    var fields = [_]a.Values.Field{.{ .name = "request", .value = .{ .capability = .{ .id = @splat(9) } } }};
    const input: q.ApplicationInvocation.Input = .{
        .definition = c.protocol.Growth.current_definition,
        .source = undefined,
        .claim = undefined,
        .lease = undefined,
        .environment = .{ .definition = c.protocol.Growth.current_definition, .binding_digest = @splat(1), .cursor = undefined, .values = &.{.{ .instruction = 0, .value = .{ .record = &fields } }} },
    };
    // A missing reference refuses before inspecting source/client authority.
    // These deliberately absent native objects must never be consulted here.
    const scope: q.ApplicationExecution.Context = .{ .client = undefined, .declaration = undefined, .work = undefined, .invocation = undefined, .input = input, .step = 1, .scratch = scratch.allocator() };
    var bound = try factory.bind(factory.context, scope);
    defer bound.deinit();
    const expressions = bound.expressions;
    try t.expectEqualStrings("public receipt", (try expressions.evaluate(expressions.context, 1, .{ .function = .json_value }, &.{ .{ .json = "{\"value\":\"public receipt\"}" }, .{ .text = "$.value" } })).text);
    try t.expectError(error.ApplicationReservationLost, expressions.evaluate(expressions.context, 2, .{ .function = .http_query_unique }, &.{ fields[0].value, .{ .text = "state" } }));
    try t.expectError(error.ApplicationReservationLost, expressions.evaluate(expressions.context, 3, .{ .function = .random_secret }, &.{.{ .integer = 32 }}));
    try t.expectError(error.ApplicationReservationLost, expressions.condition(expressions.context, .{ .sealed = .{ .kind = .boolean, .reference = .{ .id = @splat(1) } } }));
    try t.expectError(error.ApplicationReservationLost, expressions.evaluate(expressions.context, 4, .protect, &.{.{ .text = "cannot retain" }}));
    try t.expect(std.mem.allEqual(u8, registry.memory, 0));
    var malformed = input;
    malformed.environment.values = &.{.{ .instruction = 1, .value = input.environment.values[0].value }};
    try t.expectError(error.InvalidDirectRecord, requestReference(malformed));
    malformed = input;
    malformed.environment.values = &.{.{ .instruction = 0, .value = .{ .record = &.{ fields[0], fields[0] } } }};
    try t.expectError(error.ProgramArgumentMismatch, requestReference(malformed));
    fields[0].value = .{ .integer = 3 };
    try t.expectEqual(null, try requestReference(input));
    var ordinary = try factory.bind(factory.context, scope);
    const owned: *Binding = @ptrCast(@alignCast(ordinary.expressions.context));
    {
        defer ordinary.deinit();
        try t.expectError(error.MissingProgramNativeBinding, ordinary.expressions.evaluate(ordinary.expressions.context, 1, .{ .function = .secret }, &.{.{ .text = "cookie-key" }}));
    }
    try t.expect(std.mem.allEqual(u8, std.mem.asBytes(owned), 0));
}
