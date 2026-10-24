//! Deterministic reactive lifecycle, committed by the existing ingress owner.
const std = @import("std");
const root = @import("root.zig");
const m = root.Model;
const r = root.ReactiveModel;
const c = root.Codec;
const f = root.ServingFailure;
const Turn = root.station.Turn;

pub fn source(reader: anytype) !?r.Source {
    return if (try reader.read(m.key('W', 0, 0))) |v| try c.decode(r.Source, 'W', v) else null;
}
pub fn session(reader: anytype, principal: u64, id: u64) !?r.Session {
    return if (try reader.read(m.key('S', principal, id))) |v| try c.decode(r.Session, 'S', v) else null;
}
pub fn clock(reader: anytype) !u64 {
    return if (try reader.read(m.key('T', 0, 0))) |v| try c.decode(u64, 'T', v) else 0;
}
pub fn active(reader: anytype) !r.Active {
    return if (try reader.read(m.key('L', 0, 0))) |v| try c.decode(r.Active, 'L', v) else .{};
}
fn save(turn: *Turn, value: r.Session) !void {
    try turn.write(m.key('S', value.principal, value.session), try c.encode('S', value));
}
fn get(turn: *Turn, principal: u64, identity: r.SessionIdentity, context: ?*f.Context) !r.Session {
    try m.identity(identity.session);
    try m.identity(identity.generation);
    const value = (try session(turn, principal, identity.session)) orelse return error.ReactiveSessionNotFound;
    if (value.generation != identity.generation) {
        f.remember(context, .{ .generation = .{ .expected = identity.generation, .actual = value.generation } });
        return error.ReactiveGenerationConflict;
    }
    return value;
}
fn rights(turn: *Turn, principal: u64, context: ?*f.Context) !void {
    _ = try root.Service.rights(turn, principal, true, context);
}
fn live(turn: *Turn, value: r.Session, context: ?*f.Context) !void {
    try rights(turn, value.principal, context);
    if (value.phase != .open) {
        f.remember(context, .{ .session = .{ .phase = value.phase, .deadline = value.lease_before_ms, .observed = 0, .clock_known = false } });
        return if (value.phase == .closed) error.ReactiveSessionClosed else error.ReactiveSessionExpired;
    }
    const now = try clock(turn);
    if (value.lease_before_ms <= now) {
        f.remember(context, .{ .session = .{ .phase = value.phase, .deadline = value.lease_before_ms, .observed = now, .clock_known = true } });
        return error.ReactiveSessionExpired;
    }
    const watch = try source(turn);
    if (watch == null or !watch.?.published or watch.?.revision != value.source_revision) {
        f.remember(context, f.sourceWitness(watch, value.source_revision));
        return error.ReactiveResetRequired;
    }
    const binding = try root.Service.binding(turn);
    if (binding == null or !binding.?.published) {
        f.remember(context, f.bindingWitness(binding, 0, 0));
        return error.ServiceUnpublished;
    }
}
fn lease(turn: *Turn, deadline: u64, context: ?*f.Context) !void {
    try m.identity(deadline);
    const now = try clock(turn);
    if (now == 0 or deadline <= now or deadline - now > r.max_lease_ms) {
        f.remember(context, .{ .lease = .{ .kind = if (now == 0 or deadline <= now) .clock else .interval, .requested = deadline, .observed = now, .limit = if (now == 0 or deadline <= now) now else now + r.max_lease_ms } });
        return error.InvalidReactiveLease;
    }
    const observed = try root.Service.binding(turn);
    if (observed == null or !observed.?.published) {
        f.remember(context, f.bindingWitness(observed, 0, 0));
        return error.ServiceUnpublished;
    }
    const binding = observed.?;
    if (deadline > binding.wait_before_ms) {
        f.remember(context, .{ .lease = .{ .kind = .binding, .requested = deadline, .observed = now, .limit = binding.wait_before_ms } });
        return error.InvalidReactiveLease;
    }
    if (turn.delivery.work_before_ms) |limit| if (deadline > limit) {
        f.remember(context, .{ .lease = .{ .kind = .process, .requested = deadline, .observed = now, .limit = limit } });
        return error.InvalidReactiveLease;
    };
    if (turn.resource_deadline_ms) |limit| if (deadline > limit) {
        f.remember(context, .{ .lease = .{ .kind = .resource, .requested = deadline, .observed = now, .limit = limit } });
        return error.InvalidReactiveLease;
    };
}
fn finish(turn: *Turn, value: *r.Session, phase: r.Phase) !void {
    if (value.phase != .open) return;
    var slots = try active(turn);
    var found = false;
    for (&slots.slots) |*slot| if (slot.principal == value.principal and slot.session == value.session) {
        if (found) return error.ServingStateConflict;
        found = true;
        slot.* = .{};
    };
    if (!found) return error.ServingStateConflict;
    value.phase = phase;
    try save(turn, value.*);
    try turn.write(m.key('L', 0, 0), try c.encode('L', slots));
}
/// Called inside Service.apply's rollback boundary after configuration and origin
/// validation. Read failures abort the private proposal; only caller errors become
/// dispositions. This owner has no ambient clock or connection-local quota.
pub fn apply(configuration: m.Configuration, turn: *Turn, principal: u64, command: r.Command) !void {
    return applyDiagnostic(configuration, turn, principal, command, null);
}
pub fn applyDiagnostic(configuration: m.Configuration, turn: *Turn, principal: u64, command: r.Command, context: ?*f.Context) !void {
    switch (command) {
        .publish => |request| {
            if (principal != configuration.administrator) return error.ServingDenied;
            try request.source.validate();
            const old = try source(turn);
            if (request.expected != (if (old) |v| v.revision else 0) or request.expected >= root.protocol.max_counter or request.source.revision != request.expected + 1) {
                f.remember(context, .{ .revision = .{ .kind = .watch, .expected = request.expected, .actual = if (old) |v| v.revision else 0, .proposed = request.source.revision, .present = old != null } });
                return error.ServiceRevisionConflict;
            }
            const binding = (try root.Service.binding(turn)) orelse return error.ServiceUnpublished;
            if (request.source.published and !binding.published) return error.InvalidReactiveSource;
            const encoded = try c.encode('W', request.source);
            try turn.write(m.key('W', 0, 0), encoded);
            try turn.write(m.key('V', request.source.revision, 0), encoded);
        },
        .observe_clock => |observed| {
            if (principal != configuration.observer) return error.ServingDenied;
            try m.identity(observed);
            if (observed > try clock(turn)) try turn.write(m.key('T', 0, 0), try c.encode('T', observed));
        },
        .open => |request| {
            try rights(turn, principal, context);
            try m.identity(request.session);
            try m.identity(request.source_revision);
            var hash = std.crypto.hash.sha2.Sha256.init(.{});
            hash.update("transit.reactive.open.v1\x00");
            hash.update((try c.encode('O', request)).slice());
            const digest = hash.finalResult();
            if (try session(turn, principal, request.session)) |old| {
                if (!std.mem.eql(u8, &old.open_digest, &digest)) {
                    f.remember(context, .{ .identity = .{ .expected = old.open_digest, .actual = digest } });
                    return error.ServingIdentityConflict;
                }
                return;
            }
            try lease(turn, request.lease_before_ms, context);
            const observed = try source(turn);
            if (observed == null or !observed.?.published or observed.?.revision != request.source_revision) {
                f.remember(context, f.sourceWitness(observed, request.source_revision));
                return error.ReactiveResetRequired;
            }
            var slots = try active(turn);
            var caller: usize = 0;
            var free: ?usize = null;
            for (slots.slots, 0..) |slot, i| {
                if (slot.session == 0) {
                    if (free == null) free = i;
                } else if (slot.principal == principal) {
                    caller += 1;
                }
            }
            if (free == null or caller >= r.max_caller_sessions) {
                f.remember(context, .{ .capacity = .{ .kind = if (free == null) .sessions else .caller_sessions, .actual = @intCast(if (free == null) r.max_sessions else caller), .limit = if (free == null) r.max_sessions else r.max_caller_sessions } });
                return error.ReactiveCapacity;
            }
            slots.slots[free.?] = .{ .principal = principal, .session = request.session };
            try save(turn, .{ .principal = principal, .session = request.session, .generation = turn.delivery.input.position, .source_revision = observed.?.revision, .open_digest = digest, .lease_before_ms = request.lease_before_ms });
            try turn.write(m.key('L', 0, 0), try c.encode('L', slots));
        },
        .attach => |request| {
            var value = try get(turn, principal, request.identity, context);
            try live(turn, value, context);
            if (std.mem.allEqual(u8, &request.nonce, 0)) return error.InvalidReactiveAttachment;
            if (request.expected != value.attachment or request.expected >= root.protocol.max_counter) {
                f.remember(context, .{ .attachment = .{ .expected = request.expected, .actual = value.attachment } });
                return error.ReactiveAttachmentConflict;
            }
            value.attachment += 1;
            value.nonce = request.nonce;
            try save(turn, value);
        },
        .subscribe => |request| {
            var value = try get(turn, principal, request.identity, context);
            try live(turn, value, context);
            try m.identity(request.subscription);
            if (request.operation > root.protocol.max_counter) return error.InvalidServingIdentity;
            if (request.expected != value.subscription_generation or value.subscription != 0) {
                f.remember(context, .{ .subscription = .{ .expected = request.expected, .actual = value.subscription_generation, .requested = request.subscription, .active = value.subscription } });
                return error.ReactiveSubscriptionConflict;
            }
            value.subscription = request.subscription;
            value.subscription_generation = turn.delivery.input.position;
            value.operation = request.operation;
            try save(turn, value);
        },
        .renew => |request| {
            var value = try get(turn, principal, request.identity, context);
            try live(turn, value, context);
            if (request.expected != value.lease_before_ms or request.lease_before_ms <= request.expected) {
                f.remember(context, .{ .renewal = .{ .expected = request.expected, .actual = value.lease_before_ms, .proposed = request.lease_before_ms } });
                return error.ReactiveLeaseConflict;
            }
            try lease(turn, request.lease_before_ms, context);
            value.lease_before_ms = request.lease_before_ms;
            try save(turn, value);
        },
        .unsubscribe => |request| {
            var value = try get(turn, principal, request.identity, context);
            if (request.subscription == 0 or value.subscription != request.subscription or value.subscription_generation != request.generation) {
                f.remember(context, .{ .subscription = .{ .expected = request.generation, .actual = value.subscription_generation, .requested = request.subscription, .active = value.subscription } });
                return error.ReactiveSubscriptionConflict;
            }
            value.subscription = 0;
            value.operation = 0;
            try save(turn, value);
        },
        .close => |identity| {
            var value = try get(turn, principal, identity, context);
            try finish(turn, &value, .closed);
        },
        .expire => |request| {
            if (principal != configuration.observer) return error.ServingDenied;
            try m.identity(request.principal);
            try m.identity(request.observed_ms);
            var value = try get(turn, request.principal, request.identity, context);
            if (request.observed_ms < value.lease_before_ms) {
                f.remember(context, .{ .lease = .{ .kind = .observer, .requested = request.observed_ms, .observed = request.observed_ms, .limit = value.lease_before_ms } });
                return error.InvalidReactiveLease;
            }
            try finish(turn, &value, .expired);
        },
    }
}
pub fn requestError(err: anyerror) bool {
    return switch (err) {
        error.InvalidReactiveSource, error.UnsupportedReactiveSource, error.InvalidReactiveProgress, error.TableNotFound, error.ReactiveSessionNotFound, error.ReactiveGenerationConflict, error.ReactiveSessionClosed, error.ReactiveSessionExpired, error.ReactiveResetRequired, error.InvalidReactiveLease, error.ReactiveCapacity, error.InvalidReactiveAttachment, error.ReactiveAttachmentConflict, error.ReactiveSubscriptionConflict, error.ReactiveLeaseConflict => true,
        else => false,
    };
}
