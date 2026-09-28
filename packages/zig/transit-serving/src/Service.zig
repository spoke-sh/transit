//! One durable service owner. All admission state lives in the owning Station
//! turn; gateways and sockets have no independent sequence or dedup database.
const std = @import("std");
const root = @import("root.zig");
const s = root.station;
const p = root.protocol;
const m = root.Model;
const c = root.Codec;
const Turn = s.GrowingTurn;
const Self = @This();
configuration: m.Configuration,

pub fn interface(self: *Self) s.GrowingGenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GrowingGenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
pub fn binding(reader: anytype) !?m.Binding {
    return if (try reader.read(m.key('b', 0, 0))) |value| try c.decode(m.Binding, 'b', value) else null;
}
pub fn policy(reader: anytype, principal: u64) !?m.Policy {
    return if (try reader.read(m.key('p', principal, 0))) |value| try c.decode(m.Policy, 'p', value) else null;
}
pub fn operation(reader: anytype, principal: u64, id: u64) !?m.Operation {
    return if (try reader.read(m.key('o', principal, id))) |value| try c.decode(m.Operation, 'o', value) else null;
}
pub fn active(reader: anytype) !m.Active {
    return if (try reader.read(m.key('a', 0, 0))) |value| try c.decode(m.Active, 'a', value) else .{};
}
fn disposition(turn: *Turn, reason: []const u8) !void {
    const principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0;
    try turn.write(m.key('e', principal, turn.delivery.input.position), try p.Value.init(reason));
}
fn reject(turn: *Turn, reason: []const u8) !bool {
    try disposition(turn, reason);
    return true;
}
fn configurationCheck(self: Self, turn: *Turn) !void {
    const stored = (try turn.read(m.key('c', 0, 0))) orelse return error.UninitializedService;
    if (!stored.eql(try c.encode('g', self.configuration))) return error.ServingConfigurationChanged;
}
fn initialize(raw: ?*anyopaque, turn: *Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    inline for (.{ "service", "administrator", "observer" }) |field| try m.identity(@field(self.configuration, field));
    try turn.write(m.key('c', 0, 0), try c.encode('g', self.configuration));
}
/// This guard runs before Station interprets frames. Invalid caller data becomes
/// a disposition; a failed read still poisons/aborts the private proposal.
fn rejectInput(raw: ?*anyopaque, turn: *Turn) anyerror!bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = s.Frame.decode(turn.delivery.input.value) catch return reject(turn, "InvalidServingFrame");
    switch (frame.kind) {
        .cast => {
            if (turn.delivery.input.origin != .external) return reject(turn, "ServingExternalOriginRequired");
            _ = m.Command.decode(frame.payload) catch return reject(turn, "InvalidServingCommand");
        },
        .reply => {
            const wait = (try turn.waiting(frame.correlation)) orelse return reject(turn, "UnknownServingCorrelation");
            if ((s.Frame.source(turn.delivery.input) catch 0) != wait.target) return reject(turn, "UnexpectedServingReplySource");
        },
        .timeout => {
            if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.configuration.observer) return reject(turn, "UnexpectedTimerObserver");
            const wait = (try turn.waiting(frame.correlation)) orelse return reject(turn, "UnknownServingCorrelation");
            if (wait.observer != self.configuration.observer or frame.payload.len != 12 or !std.mem.eql(u8, frame.payload.data[0..4], "TMO1")) return reject(turn, "InvalidTimerObservation");
            if (std.mem.readInt(u64, frame.payload.data[4..12], .little) < (wait.deadline_ms orelse return reject(turn, "InvalidTimerObservation"))) return reject(turn, "PrematureTimer");
        },
        else => return reject(turn, "UnsupportedServingFrame"),
    }
    return false;
}
fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (frame.kind == .reply or frame.kind == .timeout) {
        try self.configurationCheck(turn);
        return self.resolve(turn, frame);
    }
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return disposition(turn, "UnexpectedServingOrigin");
    const command = m.Command.decode(frame.payload) catch return disposition(turn, "InvalidServingCommand");
    const before = turn.decision;
    self.apply(turn, command, turn.delivery.input.origin.external.principal) catch |err| {
        turn.decision = before;
        if (turn.read_error != null or !requestError(err)) return err;
        try disposition(turn, @errorName(err));
    };
}
pub fn apply(self: Self, turn: *Turn, command: m.Command, principal: u64) !void {
    // Public composition still requires the authority-derived external identity.
    if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != principal) return error.ServingDenied;
    try self.configurationCheck(turn);
    const before = turn.decision;
    errdefer turn.decision = before;
    switch (command) {
        .initialize => if (principal != self.configuration.administrator) return error.ServingDenied,
        .publish => |request| {
            if (principal != self.configuration.administrator) return error.ServingDenied;
            try request.binding.validate();
            const previous = try binding(turn);
            if (request.expected != (if (previous) |value| value.revision else 0) or request.binding.revision != try std.math.add(u64, request.expected, 1)) return error.ServiceRevisionConflict;
            const encoded = try c.encode('b', request.binding);
            try turn.write(m.key('b', 0, 0), encoded);
            try turn.write(m.key('v', request.binding.revision, 0), encoded);
        },
        .policy => |request| {
            if (principal != self.configuration.administrator) return error.ServingDenied;
            try m.identity(request.principal);
            try request.policy.validate();
            const previous = try policy(turn, request.principal);
            if (request.expected != (if (previous) |value| value.revision else 0) or request.policy.revision != try std.math.add(u64, request.expected, 1)) return error.ServiceRevisionConflict;
            try turn.write(m.key('p', request.principal, 0), try c.encode('p', request.policy));
        },
        .refresh => return error.InvalidServingCommand, // Requires the explicitly composed live-query owner.
        .reactive => |request| try root.ReactiveService.apply(self.configuration, turn, principal, request),
        .submit => |request| try self.submit(turn, principal, request),
        .cancel => |id| {
            const rights = (try policy(turn, principal)) orelse return error.ServingDenied;
            if (!rights.commands) return error.ServingDenied;
            var record = (try operation(turn, principal, id)) orelse return error.ServingOperationNotFound;
            if (record.phase != .admitted) return;
            if (!try s.Waiting.cancel(turn, record.correlation)) return error.ServingStateConflict;
            record.phase = .cancelled;
            try complete(turn, &record);
        },
    }
}
fn submit(self: Self, turn: *Turn, principal: u64, request: m.Submit) !void {
    try request.validate();
    const rights = (try policy(turn, principal)) orelse return error.ServingDenied;
    if (!rights.commands) return error.ServingDenied;
    const digest = try request.digest();
    if (try operation(turn, principal, request.operation)) |old| {
        if (!std.mem.eql(u8, &old.digest, &digest)) return error.ServingIdentityConflict;
        return;
    }
    const route = (try binding(turn)) orelse return error.ServiceUnpublished;
    if (!route.published) return error.ServiceUnpublished;
    if (route.revision != request.binding or route.codec != request.codec) return error.ServiceRevisionConflict;
    if (request.deadline_ms > route.wait_before_ms) return error.InvalidWaitLifetime;
    var slots = try active(turn);
    var total: usize = 0;
    var caller: usize = 0;
    var free: ?usize = null;
    for (slots.slots, 0..) |slot, i| {
        if (slot.correlation == 0) {
            if (free == null) free = i;
        } else {
            total += 1;
            if (slot.principal == principal) caller += 1;
        }
    }
    if (total >= route.active_limit or caller >= rights.active_limit or free == null) return error.ServingCapacity;
    const invocation: m.Invocation = .{ .service = self.configuration.service, .principal = principal, .operation = request.operation, .binding = route.revision, .codec = route.codec, .payload = request.payload };
    const correlation = try turn.callWithTimer(route.target, try c.encode('i', invocation), request.deadline_ms, self.configuration.observer);
    const record: m.Operation = .{ .principal = principal, .operation = request.operation, .binding = route.revision, .codec = route.codec, .deadline_ms = request.deadline_ms, .digest = digest, .target = route.target, .correlation = correlation, .policy_revision = rights.revision };
    slots.slots[free.?] = .{ .correlation = correlation, .principal = principal, .operation = request.operation };
    try turn.write(m.key('a', 0, 0), try c.encode('a', slots));
    try turn.write(m.key('o', principal, request.operation), try c.encode('o', record));
}
fn complete(turn: *Turn, record: *m.Operation) !void {
    var slots = try active(turn);
    var found = false;
    for (&slots.slots) |*slot| if (slot.correlation == record.correlation) {
        if (slot.principal != record.principal or slot.operation != record.operation or found) return error.ServingStateConflict;
        slot.* = .{};
        found = true;
    };
    if (!found) return error.ServingStateConflict;
    record.resolution_input = turn.delivery.input.position;
    try turn.write(m.key('a', 0, 0), try c.encode('a', slots));
    try turn.write(m.key('o', record.principal, record.operation), try c.encode('o', record.*));
}
fn resolve(self: Self, turn: *Turn, frame: s.Frame) !void {
    _ = self;
    const slots = try active(turn);
    const slot = for (slots.slots) |candidate| {
        if (candidate.correlation == frame.correlation) break candidate;
    } else return error.ServingStateConflict;
    var record = (try operation(turn, slot.principal, slot.operation)) orelse return error.ServingStateConflict;
    const wait = (try turn.waiting(frame.correlation)) orelse return error.ServingStateConflict;
    if (record.phase != .admitted or record.correlation != frame.correlation or record.target != wait.target or wait.resolution_input != turn.delivery.input.position) return error.ServingStateConflict;
    if (frame.kind == .reply) {
        if (wait.phase != .replied or (try s.Frame.source(turn.delivery.input)) != record.target) return error.ServingStateConflict;
        record.phase = if (frame.payload.len <= m.inline_bytes) .completed else .failed;
        record.result = if (frame.payload.len <= m.inline_bytes) frame.payload else try p.Value.init("ServingResultTooLarge");
    } else {
        if (wait.phase != .timed_out) return error.ServingStateConflict;
        record.phase = .timed_out;
    }
    try complete(turn, &record);
}
fn requestError(err: anyerror) bool {
    if (root.ReactiveService.requestError(err)) return true;
    return switch (err) {
        error.InvalidServingIdentity, error.InvalidServiceBinding, error.InvalidServicePolicy, error.InvalidServingCommand, error.ServingDenied, error.ServiceRevisionConflict, error.ServingIdentityConflict, error.ServingCapacity, error.ServiceUnpublished, error.InvalidWaitLifetime, error.ServingOperationNotFound => true,
        else => false,
    };
}
