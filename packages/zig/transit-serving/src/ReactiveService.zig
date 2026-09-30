//! Deterministic reactive lifecycle, committed by the existing ingress owner.
const std = @import("std");
const root = @import("root.zig");
const m = root.Model;
const r = root.ReactiveModel;
const c = root.Codec;
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
fn get(turn: *Turn, principal: u64, identity: r.SessionIdentity) !r.Session {
    try m.identity(identity.session);
    try m.identity(identity.generation);
    const value = (try session(turn, principal, identity.session)) orelse return error.ReactiveSessionNotFound;
    if (value.generation != identity.generation) return error.ReactiveGenerationConflict;
    return value;
}
fn rights(turn: *Turn, principal: u64) !void {
    const policy = (try root.Service.policy(turn, principal)) orelse return error.ServingDenied;
    if (!policy.reads) return error.ServingDenied;
}
fn live(turn: *Turn, value: r.Session) !void {
    try rights(turn, value.principal);
    if (value.phase != .open or value.lease_before_ms <= try clock(turn)) return error.ReactiveSessionExpired;
    const watch = (try source(turn)) orelse return error.ReactiveResetRequired;
    if (!watch.published or watch.revision != value.source_revision) return error.ReactiveResetRequired;
    const binding = (try root.Service.binding(turn)) orelse return error.ServiceUnpublished;
    if (!binding.published or binding.target != watch.target) return error.ServiceUnpublished;
}
fn lease(turn: *Turn, deadline: u64) !void {
    try m.identity(deadline);
    const now = try clock(turn);
    if (now == 0 or deadline <= now or deadline - now > r.max_lease_ms) return error.InvalidReactiveLease;
    const binding = (try root.Service.binding(turn)) orelse return error.ServiceUnpublished;
    if (!binding.published) return error.ServiceUnpublished;
    if (deadline > binding.wait_before_ms) return error.InvalidReactiveLease;
    if (turn.delivery.work_before_ms) |limit| if (deadline > limit) return error.InvalidReactiveLease;
    if (turn.resource_deadline_ms) |limit| if (deadline > limit) return error.InvalidReactiveLease;
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
    switch (command) {
        .publish => |request| {
            if (principal != configuration.administrator) return error.ServingDenied;
            try request.source.validate();
            const old = try source(turn);
            if (request.expected != (if (old) |v| v.revision else 0) or request.expected >= root.protocol.max_counter or request.source.revision != request.expected + 1) return error.ServiceRevisionConflict;
            const binding = (try root.Service.binding(turn)) orelse return error.ServiceUnpublished;
            if (request.source.published and (!binding.published or binding.target != request.source.target)) return error.InvalidReactiveSource;
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
            try rights(turn, principal);
            try m.identity(request.session);
            try m.identity(request.source_revision);
            var hash = std.crypto.hash.sha2.Sha256.init(.{});
            hash.update("transit.reactive.open.v1\x00");
            hash.update((try c.encode('O', request)).slice());
            const digest = hash.finalResult();
            if (try session(turn, principal, request.session)) |old| {
                if (!std.mem.eql(u8, &old.open_digest, &digest)) return error.ServingIdentityConflict;
                return;
            }
            try lease(turn, request.lease_before_ms);
            const watch = (try source(turn)) orelse return error.ReactiveResetRequired;
            if (!watch.published or watch.revision != request.source_revision) return error.ReactiveResetRequired;
            const binding = (try root.Service.binding(turn)).?;
            if (binding.target != watch.target) return error.ReactiveResetRequired;
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
            if (free == null or caller >= r.max_caller_sessions) return error.ReactiveCapacity;
            slots.slots[free.?] = .{ .principal = principal, .session = request.session };
            try save(turn, .{ .principal = principal, .session = request.session, .generation = turn.delivery.input.position, .source_revision = watch.revision, .open_digest = digest, .lease_before_ms = request.lease_before_ms });
            try turn.write(m.key('L', 0, 0), try c.encode('L', slots));
        },
        .attach => |request| {
            var value = try get(turn, principal, request.identity);
            try live(turn, value);
            if (std.mem.allEqual(u8, &request.nonce, 0)) return error.InvalidReactiveAttachment;
            if (request.expected != value.attachment or request.expected >= root.protocol.max_counter) return error.ReactiveAttachmentConflict;
            value.attachment += 1;
            value.nonce = request.nonce;
            try save(turn, value);
        },
        .subscribe => |request| {
            var value = try get(turn, principal, request.identity);
            try live(turn, value);
            try m.identity(request.subscription);
            if (request.operation > root.protocol.max_counter) return error.InvalidServingIdentity;
            if (request.expected != value.subscription_generation or value.subscription != 0) return error.ReactiveSubscriptionConflict;
            value.subscription = request.subscription;
            value.subscription_generation = turn.delivery.input.position;
            value.operation = request.operation;
            try save(turn, value);
        },
        .renew => |request| {
            var value = try get(turn, principal, request.identity);
            try live(turn, value);
            if (request.expected != value.lease_before_ms or request.lease_before_ms <= request.expected) return error.ReactiveLeaseConflict;
            try lease(turn, request.lease_before_ms);
            value.lease_before_ms = request.lease_before_ms;
            try save(turn, value);
        },
        .unsubscribe => |request| {
            var value = try get(turn, principal, request.identity);
            if (request.subscription == 0 or value.subscription != request.subscription or value.subscription_generation != request.generation) return error.ReactiveSubscriptionConflict;
            value.subscription = 0;
            value.operation = 0;
            try save(turn, value);
        },
        .close => |identity| {
            var value = try get(turn, principal, identity);
            try finish(turn, &value, .closed);
        },
        .expire => |request| {
            if (principal != configuration.observer) return error.ServingDenied;
            try m.identity(request.principal);
            try m.identity(request.observed_ms);
            var value = try get(turn, request.principal, request.identity);
            if (request.observed_ms < value.lease_before_ms) return error.InvalidReactiveLease;
            try finish(turn, &value, .expired);
        },
    }
}
pub fn requestError(err: anyerror) bool {
    return switch (err) {
        error.InvalidReactiveSource, error.ReactiveSessionNotFound, error.ReactiveGenerationConflict, error.ReactiveSessionExpired, error.ReactiveResetRequired, error.InvalidReactiveLease, error.ReactiveCapacity, error.InvalidReactiveAttachment, error.ReactiveAttachmentConflict, error.ReactiveSubscriptionConflict, error.ReactiveLeaseConflict => true,
        else => false,
    };
}
