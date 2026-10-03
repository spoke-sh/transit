//! One durable service owner. All admission state lives in the owning Station
//! turn; gateways and sockets have no independent sequence or dedup database.
const std = @import("std");
const root = @import("root.zig");
const s = root.station;
const p = root.protocol;
const m = root.Model;
const c = root.Codec;
const f = root.ServingFailure;
const Turn = s.Turn;
const Self = @This();
configuration: m.Configuration,
diagnostic: ?*f.Context = null,

pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
pub fn binding(reader: anytype) !?m.Binding {
    return if (try reader.read(m.key('b', 0, 0))) |value| try c.decode(m.Binding, 'b', value) else null;
}
pub fn policy(reader: anytype, principal: u64) !?m.Policy {
    return if (try reader.read(m.key('p', principal, 0))) |value| try c.decode(m.Policy, 'p', value) else null;
}
pub fn operation(reader: anytype, principal: u64, id: u64) !?m.Operation {
    const value = (try reader.read(m.key('o', principal, id))) orelse return null;
    const record = c.decode(m.Operation, 'o', value) catch return error.InvalidServingRecord;
    try record.validate();
    if (record.principal != principal or record.operation != id) return error.InvalidServingRecord;
    return record;
}
pub fn active(reader: anytype) !m.Active {
    return if (try reader.read(m.key('a', 0, 0))) |value| try c.decode(m.Active, 'a', value) else .{};
}
fn disposition(turn: *Turn, command: ?m.Command, reason: f.Reason, context: f.Context) !void {
    try f.record(turn, command, reason, context);
}
fn reject(turn: *Turn, reason: f.Reason, context: f.Context) !bool {
    try disposition(turn, null, reason, context);
    return true;
}
pub fn rights(turn: *Turn, principal: u64, reads: bool, context: ?*f.Context) !m.Policy {
    const observed = try policy(turn, principal);
    if (observed == null or (if (reads) !observed.?.reads else !observed.?.commands)) {
        f.remember(context, .{ .policy = .{ .principal = principal, .revision = if (observed) |v| v.revision else 0, .present = observed != null, .commands = if (observed) |v| v.commands else false, .reads = if (observed) |v| v.reads else false } });
        return error.ServingDenied;
    }
    return observed.?;
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
    const frame = s.Frame.decode(turn.delivery.input.value) catch |err| return reject(turn, .InvalidServingFrame, .{ .cause = err });
    switch (frame.kind) {
        .cast => {
            if (turn.delivery.input.origin != .external) return reject(turn, .ServingExternalOriginRequired, .{});
            _ = m.Command.decode(frame.payload) catch |err| return reject(turn, .InvalidServingCommand, .{ .cause = err });
        },
        .reply => {
            const wait = (try turn.waiting(frame.correlation)) orelse return reject(turn, .UnknownServingCorrelation, .{});
            if ((s.Frame.source(turn.delivery.input) catch 0) != wait.target) return reject(turn, .UnexpectedServingReplySource, .{ .witness = .{ .frame = .{ .correlation = frame.correlation, .expected = wait.target, .actual = s.Frame.source(turn.delivery.input) catch 0, .kind = .reply_source, .actual_known = turn.delivery.input.origin == .process } } });
        },
        .timeout => {
            if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.configuration.observer) return reject(turn, .UnexpectedTimerObserver, .{ .witness = .{ .frame = .{ .correlation = frame.correlation, .expected = self.configuration.observer, .actual = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0, .kind = .observer, .actual_known = turn.delivery.input.origin == .external } } });
            const wait = (try turn.waiting(frame.correlation)) orelse return reject(turn, .UnknownServingCorrelation, .{});
            if (wait.observer != self.configuration.observer or frame.payload.len != 12 or !std.mem.eql(u8, frame.payload.data[0..4], "TMO1")) return reject(turn, .InvalidTimerObservation, .{});
            if (std.mem.readInt(u64, frame.payload.data[4..12], .little) < (wait.deadline_ms orelse return reject(turn, .InvalidTimerObservation, .{}))) return reject(turn, .PrematureTimer, .{ .witness = .{ .frame = .{ .correlation = frame.correlation, .expected = wait.deadline_ms.?, .actual = std.mem.readInt(u64, frame.payload.data[4..12], .little), .kind = .timer } } });
        },
        else => return reject(turn, .UnsupportedServingFrame, .{}),
    }
    return false;
}
fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (frame.kind == .reply or frame.kind == .timeout) {
        try self.configurationCheck(turn);
        return self.resolve(turn, frame);
    }
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return disposition(turn, null, .UnexpectedServingOrigin, .{});
    const command = m.Command.decode(frame.payload) catch |err| return disposition(turn, null, .InvalidServingCommand, .{ .cause = err });
    _ = try self.dispatchCommand(turn, command, turn.delivery.input.origin.external.principal);
}
/// Returns false only for a committed input rejection. Composed owners may add
/// their own successful control transition to this same atomic proposal.
pub fn dispatchCommand(self: Self, turn: *Turn, command: m.Command, principal: u64) !bool {
    const before = turn.decision;
    var context: f.Context = .{};
    var owner = self;
    owner.diagnostic = &context;
    owner.apply(turn, command, principal) catch |err| {
        turn.decision = before;
        if (turn.read_error != null or !requestError(err)) return err;
        try disposition(turn, command, f.reason(err).?, context);
        return false;
    };
    return true;
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
            if (request.expected != (if (previous) |value| value.revision else 0) or request.expected >= p.max_counter or request.binding.revision != request.expected + 1) {
                f.remember(self.diagnostic, .{ .revision = .{ .kind = .binding, .expected = request.expected, .actual = if (previous) |v| v.revision else 0, .proposed = request.binding.revision, .present = previous != null } });
                return error.ServiceRevisionConflict;
            }
            const encoded = try c.encode('b', request.binding);
            try turn.write(m.key('b', 0, 0), encoded);
            try turn.write(m.key('v', request.binding.revision, 0), encoded);
        },
        .policy => |request| {
            if (principal != self.configuration.administrator) return error.ServingDenied;
            try m.identity(request.principal);
            try request.policy.validate();
            const previous = try policy(turn, request.principal);
            if (request.expected != (if (previous) |value| value.revision else 0) or request.expected >= p.max_counter or request.policy.revision != request.expected + 1) {
                f.remember(self.diagnostic, .{ .revision = .{ .kind = .policy, .expected = request.expected, .actual = if (previous) |v| v.revision else 0, .proposed = request.policy.revision, .present = previous != null } });
                return error.ServiceRevisionConflict;
            }
            try turn.write(m.key('p', request.principal, 0), try c.encode('p', request.policy));
        },
        .refresh => return error.InvalidServingCommand, // Requires the explicitly composed live-query owner.
        .reactive => |request| try root.ReactiveService.applyDiagnostic(self.configuration, turn, principal, request, self.diagnostic),
        .submit => |request| try self.submit(turn, principal, request),
        .cancel => |id| {
            _ = try rights(turn, principal, false, self.diagnostic);
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
    const permission = try rights(turn, principal, false, self.diagnostic);
    const digest = try request.digest();
    if (try operation(turn, principal, request.operation)) |old| {
        if (!std.mem.eql(u8, &old.digest, &digest)) {
            f.remember(self.diagnostic, .{ .identity = .{ .expected = old.digest, .actual = digest } });
            return error.ServingIdentityConflict;
        }
        return;
    }
    const observed = try binding(turn);
    if (observed == null or !observed.?.published or observed.?.revision != request.binding or observed.?.codec != request.codec) {
        f.remember(self.diagnostic, f.bindingWitness(observed, request.binding, request.codec));
        return if (observed == null or !observed.?.published) error.ServiceUnpublished else error.ServiceRevisionConflict;
    }
    const route = observed.?;
    if (request.deadline_ms > route.wait_before_ms) {
        f.remember(self.diagnostic, .{ .lease = .{ .kind = .binding, .requested = request.deadline_ms, .observed = 0, .limit = route.wait_before_ms } });
        return error.InvalidWaitLifetime;
    }
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
    if (total >= route.active_limit or caller >= permission.active_limit or free == null) {
        const global = total >= route.active_limit;
        f.remember(self.diagnostic, .{ .capacity = .{ .kind = if (global) .service else if (caller >= permission.active_limit) .caller else .service_slots, .actual = @intCast(if (global or free == null) total else caller), .limit = if (global) route.active_limit else if (caller >= permission.active_limit) permission.active_limit else m.max_active } });
        return error.ServingCapacity;
    }
    const invocation: m.Invocation = .{ .service = self.configuration.service, .principal = principal, .operation = request.operation, .binding = route.revision, .codec = route.codec, .payload = request.payload };
    const correlation = turn.callWithTimer(route.target, try c.encode('i', invocation), request.deadline_ms, self.configuration.observer) catch |err| {
        if (err == error.InvalidWaitLifetime) {
            const work = turn.delivery.work_before_ms;
            const resource = turn.resource_deadline_ms;
            const process = work != null and (resource == null or work.? <= resource.?);
            f.remember(self.diagnostic, .{ .lease = .{ .kind = if (process) .process else .resource, .requested = request.deadline_ms, .observed = 0, .limit = if (process) work.? else resource.? } });
        }
        return err;
    };
    const record: m.Operation = .{ .principal = principal, .operation = request.operation, .binding = route.revision, .codec = route.codec, .deadline_ms = request.deadline_ms, .digest = digest, .target = route.target, .correlation = correlation, .policy_revision = permission.revision };
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
    try record.validate();
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
        record.reply_bytes = frame.payload.len;
        record.result = if (frame.payload.len <= m.inline_bytes) frame.payload else .{};
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
