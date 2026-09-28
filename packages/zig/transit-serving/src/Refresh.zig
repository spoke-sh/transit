//! Durable demand coalescing and fair finite-query scheduling. All stored state
//! belongs to the existing requester resource. Readers supply qualified current
//! authority and source/result observations; clocks are explicit inputs.
const std = @import("std");
const root = @import("root.zig");
const m = root.RefreshModel;
const r = root.ReactiveModel;
const c = root.Codec;
const q = root.query;
const Turn = root.station.GrowingTurn;
const Self = @This();
principal: u64,
source: u64,

pub fn head(reader: anytype, principal: u64, session: u64) !u64 {
    return if (try reader.read(m.headKey(principal, session))) |value| try c.decode(u64, 'F', value) else 0;
}
pub fn view(reader: anytype, principal: u64, generation: u64) !?m.View {
    return if (try reader.read(m.viewKey(principal, generation))) |value| try c.decode(m.View, 'G', value) else null;
}
pub fn current(reader: anytype, principal: u64, session: r.SessionIdentity) !?m.View {
    const generation = try head(reader, principal, session.session);
    const value = (try view(reader, principal, generation)) orelse return null;
    if (!std.meta.eql(value.session, session)) return error.ReactiveGenerationConflict;
    return value;
}
pub fn scheduler(reader: anytype) !m.Scheduler {
    const state = if (try reader.read(m.scheduler_key)) |value| try c.decode(m.Scheduler, 'J', value) else m.Scheduler{};
    if (state.next >= r.max_sessions or (state.principal == 0) != (state.generation == 0)) return error.InvalidServingRecord;
    return state;
}
fn save(turn: *Turn, value: m.View) !void {
    try turn.write(m.viewKey(value.principal, value.generation), try c.encode('G', value));
}
fn saveScheduler(turn: *Turn, value: m.Scheduler) !void {
    try turn.write(m.scheduler_key, try c.encode('J', value));
}
fn policy(turn: *Turn, principal: u64) !void {
    if (!(try root.Service.policy(turn, principal) orelse return error.ServingDenied).reads) return error.ServingDenied;
}
fn ownedSession(turn: *Turn, principal: u64, identity: r.SessionIdentity) !r.Session {
    const value = (try root.ReactiveService.session(turn, principal, identity.session)) orelse return error.ReactiveSessionNotFound;
    if (value.generation != identity.generation) return error.ReactiveGenerationConflict;
    return value;
}
fn live(turn: *Turn, principal: u64, identity: r.SessionIdentity, upper_ms: u64) !r.Source {
    try policy(turn, principal);
    const owner = try ownedSession(turn, principal, identity);
    if (owner.phase != .open or owner.lease_before_ms <= @max(upper_ms, try root.ReactiveService.clock(turn))) return error.ReactiveSessionExpired;
    const watch = (try root.ReactiveService.source(turn)) orelse return error.ReactiveResetRequired;
    const binding = (try root.Service.binding(turn)) orelse return error.ServiceUnpublished;
    if (!watch.published or !binding.published or binding.target != watch.target or owner.source_revision != watch.revision) return error.ReactiveResetRequired;
    return watch;
}
fn selected(turn: *Turn, principal: u64, selection: m.Selection) !m.View {
    if (try head(turn, principal, selection.session.session) != selection.generation) return error.RefreshGenerationConflict;
    const value = (try view(turn, principal, selection.generation)) orelse return error.RefreshNotFound;
    if (!std.meta.eql(value.session, selection.session)) return error.ReactiveGenerationConflict;
    return value;
}
fn proof(turn: *Turn, value: m.View) !m.Proof {
    return c.decode(m.Proof, 'I', (try turn.read(m.proofKey(value.principal, value.generation))) orelse return error.InvalidServingRecord);
}
fn sameBasis(watch: root.TableWatch.Observation, captured: q.fuze.Unified.Basis) !void {
    var basis = captured;
    basis.revision = watch.data_revision;
    if (!root.TableWatch.covered(watch, basis)) return error.InvalidRefreshTemplate;
}
/// Reader contract: authorize(principal, source, proof), observe(source), and
/// result(turn, namespace, source). Result must use the shared manifest/current
/// result reader. No caller-supplied watermark is trusted for scheduling.
pub fn apply(self: Self, turn: *Turn, principal: u64, command: m.Command, reader: anytype, upper_ms: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (principal != self.principal or turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != principal) return error.ServingDenied;
    switch (command) {
        .follow => |input| {
            if (input.view.limit == 0 or input.view.limit > m.max_starts or input.view.template.value == 0) return error.InvalidRefreshBudget;
            const watch = try live(turn, principal, input.view.session, upper_ms);
            if (watch.target != self.source) return error.InvalidRefreshTemplate;
            if (input.view.expected != try head(turn, principal, input.view.session.session)) return error.RefreshGenerationConflict;
            try reader.authorize(principal, watch, input.proof);
            const captured = try reader.result(turn, input.view.template.value, watch);
            const observed = try reader.observe(watch);
            try sameBasis(observed, captured);
            const value: m.View = .{ .principal = principal, .session = input.view.session, .generation = turn.delivery.input.position, .source = watch, .template = input.view.template, .namespace = input.view.template, .dirty = observed.data_revision, .covered = captured.revision, .limit = input.view.limit };
            try save(turn, value);
            try turn.write(m.proofKey(principal, value.generation), try c.encode('I', input.proof));
            try turn.write(m.headKey(principal, value.session.session), try c.encode('F', value.generation));
        },
        .invalidate => |selection| {
            const watch = try live(turn, principal, selection.session, upper_ms);
            var value = try selected(turn, principal, selection);
            if (!std.meta.eql(watch, value.source)) return error.ReactiveResetRequired;
            if (!value.enabled) return;
            try reader.authorize(principal, watch, try proof(turn, value));
            const observed = try reader.observe(watch);
            if (observed.data_revision > value.dirty) {
                value.dirty = observed.data_revision;
                try save(turn, value);
            }
        },
        .acknowledged => |input| {
            try policy(turn, principal);
            var value = try selected(turn, principal, input.selection);
            if (value.namespace.value != input.namespace.value or value.phase != .ready) return error.RefreshResultConflict;
            try reader.authorize(principal, value.source, try proof(turn, value));
            const captured = try reader.result(turn, value.namespace.value, value.source);
            const observed = try reader.observe(value.source);
            try sameBasis(observed, captured);
            value.covered = captured.revision;
            value.dirty = @max(value.dirty, observed.data_revision);
            value.phase = if (!value.enabled) .paused else if (value.starts >= value.limit) .exhausted else .idle;
            try save(turn, value);
        },
        .pause => |selection| {
            // Releasing scheduling never authorizes disclosure or cancellation.
            _ = try ownedSession(turn, principal, selection.session);
            var value = try selected(turn, principal, selection);
            value.enabled = false;
            if (value.phase == .idle) value.phase = .paused;
            try save(turn, value);
        },
    }
}
fn denial(err: anyerror) bool {
    return switch (err) {
        error.ServingDenied, error.AccessDenied, error.QueryDenied, error.ResourceUnavailable, error.QuerySourceUnavailable, error.ResultUnavailable, error.PublicationNotPublished => true,
        else => false,
    };
}
/// Returns true when one further self-wakeup can make progress. A waiting source
/// call, spacing bound or quiescent source requires an actual external event.
/// Admission/copy/source call/result transition each has its own four-write turn.
pub fn drive(self: Self, turn: *Turn, reader: anytype, upper_ms: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var state = try scheduler(turn);
    if (state.generation != 0) {
        var value = (try view(turn, state.principal, state.generation)) orelse return error.InvalidServingRecord;
        const active = try q.UnifiedUpload.status(turn, value.namespace.value);
        if (active) |work| switch (work.phase) {
            .admitted => return false,
            .complete, .denied, .rejected => {
                value.phase = switch (work.phase) {
                    .complete => .ready,
                    .denied => .denied,
                    else => .failed,
                };
                try save(turn, value);
                state.principal = 0;
                state.generation = 0;
                try saveScheduler(turn, state);
                return true;
            },
            .cancelled, .retired => {
                if (!work.collected) {
                    _ = try q.UnifiedUpload.collect(turn, value.namespace.value);
                    return true;
                }
                state.principal = 0;
                state.generation = 0;
                try saveScheduler(turn, state);
                return true;
            },
            .uploading, .sealed => {},
        };
        // Already selected work is independent of pause/socket/session closure.
        // Current caller, service and resource grants still gate source admission.
        return self.advance(turn, value, reader) catch |err| {
            turn.decision = before;
            if (turn.read_error != null or (!denial(err) and err != error.QueryUploadClosed and err != error.InvalidRefreshTemplate)) return err;
            value.phase = if (denial(err)) .denied else .failed;
            value.enabled = false;
            try save(turn, value);
            if (active != null) try q.UnifiedUpload.cancel(turn, value.namespace.value) else {
                state.principal = 0;
                state.generation = 0;
                try saveScheduler(turn, state);
            }
            return true;
        };
    }
    if (try q.UnifiedUpload.active(turn) != null) return false;
    const slots = (try root.ReactiveService.active(turn)).slots;
    const now = try root.ReactiveService.clock(turn);
    for (0..slots.len) |offset| {
        const index = (state.next + offset) % slots.len;
        const slot = slots[index];
        if (slot.principal != self.principal) continue;
        var value = (try view(turn, slot.principal, try head(turn, slot.principal, slot.session))) orelse continue;
        if (!value.enabled or value.phase != .idle or value.dirty <= value.covered or value.next_start_ms > now) continue;
        const watch = live(turn, slot.principal, value.session, upper_ms) catch |err| {
            if (turn.read_error != null or (!denial(err) and err != error.ReactiveSessionExpired and err != error.ReactiveResetRequired and err != error.ServiceUnpublished)) return err;
            value.enabled = false;
            value.phase = if (denial(err)) .denied else .paused;
            try save(turn, value);
            return true;
        };
        if (!std.meta.eql(watch, value.source)) {
            value.enabled = false;
            value.phase = .paused;
            try save(turn, value);
            return true;
        }
        if (value.starts >= value.limit) {
            value.phase = .exhausted;
            try save(turn, value);
            return true;
        }
        reader.authorize(slot.principal, watch, try proof(turn, value)) catch |err| {
            if (!denial(err)) return err;
            value.enabled = false;
            value.phase = .denied;
            try save(turn, value);
            return true;
        };
        // Reserved high-bit namespace domain plus the globally unique committed
        // input position. Explicit old user choices can collide, never overwrite.
        const namespace = (@as(u64, 1) << 63) | turn.delivery.input.position;
        if (try q.UnifiedUpload.status(turn, namespace) != null or try turn.read(root.station.Publication.key(namespace, 'b', 0, 0)) != null) {
            value.enabled = false;
            value.phase = .failed;
            try save(turn, value);
            state.next = @intCast((index + 1) % slots.len);
            try saveScheduler(turn, state);
            return true;
        }
        value.namespace = .{ .value = namespace };
        value.phase = .copying;
        value.starts += 1;
        value.next_start_ms = try std.math.add(u64, now, m.start_interval_ms);
        state.next = @intCast((index + 1) % slots.len);
        state.principal = value.principal;
        state.generation = value.generation;
        try save(turn, value);
        try saveScheduler(turn, state);
        return true;
    }
    return false;
}
fn advance(self: Self, turn: *Turn, value: m.View, reader: anytype) !bool {
    try policy(turn, value.principal);
    try reader.authorize(value.principal, value.source, try proof(turn, value));
    if (try q.UnifiedUpload.active(turn)) |other| if (other != value.namespace.value) return false; // Explicit manual query won the intervening turn.
    if (!try q.UnifiedUpload.copyNext(turn, value.template.value, value.namespace.value)) return true;
    _ = try q.UnifiedUpload.submitWithObserver(turn, value.namespace.value, self.source, self.principal);
    var updated = value;
    updated.phase = .admitted;
    try save(turn, updated);
    return false;
}
pub fn requestError(err: anyerror) bool {
    return switch (err) {
        error.InvalidRefreshBudget, error.InvalidRefreshTemplate, error.RefreshGenerationConflict, error.RefreshNotFound, error.RefreshResultConflict => true,
        else => root.ReactiveService.requestError(err) or denial(err),
    };
}
