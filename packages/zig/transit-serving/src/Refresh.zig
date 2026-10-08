//! Durable demand coalescing and fair finite-query scheduling. All stored state
//! belongs to the existing requester resource. Readers supply qualified current
//! authority and source/result observations; clocks are explicit inputs.
const std = @import("std");
const root = @import("root.zig");
const m = root.RefreshModel;
const r = root.ReactiveModel;
const c = root.Codec;
const q = root.query;
const Turn = root.station.Turn;
const f = root.ServingFailure;
const failure = root.RefreshFailure;
const Self = @This();
principal: u64,
source: u64,
diagnostic: ?*f.Context = null,

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
fn policy(turn: *Turn, principal: u64, context: ?*f.Context) !void {
    _ = try root.Service.rights(turn, principal, true, context);
}
fn ownedSession(turn: *Turn, principal: u64, identity: r.SessionIdentity, context: ?*f.Context) !r.Session {
    const value = (try root.ReactiveService.session(turn, principal, identity.session)) orelse return error.ReactiveSessionNotFound;
    if (value.generation != identity.generation) {
        f.remember(context, .{ .generation = .{ .expected = identity.generation, .actual = value.generation } });
        return error.ReactiveGenerationConflict;
    }
    return value;
}
fn live(turn: *Turn, principal: u64, identity: r.SessionIdentity, upper_ms: u64, context: ?*f.Context) !r.Source {
    try policy(turn, principal, context);
    const owner = try ownedSession(turn, principal, identity, context);
    if (owner.phase != .open) {
        f.remember(context, .{ .session = .{ .phase = owner.phase, .deadline = owner.lease_before_ms, .observed = 0, .clock_known = false } });
        return if (owner.phase == .closed) error.ReactiveSessionClosed else error.ReactiveSessionExpired;
    }
    const observed = @max(upper_ms, try root.ReactiveService.clock(turn));
    if (owner.lease_before_ms <= observed) {
        f.remember(context, .{ .session = .{ .phase = owner.phase, .deadline = owner.lease_before_ms, .observed = observed, .clock_known = true } });
        return error.ReactiveSessionExpired;
    }
    const watch = try root.ReactiveService.source(turn);
    if (watch == null or !watch.?.published or owner.source_revision != watch.?.revision) {
        f.remember(context, f.sourceWitness(watch, owner.source_revision));
        return error.ReactiveResetRequired;
    }
    const binding = try root.Service.binding(turn);
    if (binding == null or !binding.?.published) {
        f.remember(context, f.bindingWitness(binding, 0, 0));
        return error.ServiceUnpublished;
    }
    if (binding.?.target != watch.?.target) {
        f.remember(context, .{ .target = .{ .expected = watch.?.target, .actual = binding.?.target, .kind = .source } });
        return error.ReactiveResetRequired;
    }
    return watch.?;
}
fn selected(turn: *Turn, principal: u64, selection: m.Selection, context: ?*f.Context) !m.View {
    const generation = try head(turn, principal, selection.session.session);
    if (generation != selection.generation) {
        f.remember(context, .{ .revision = .{ .kind = .refresh, .expected = selection.generation, .actual = generation, .proposed = selection.generation, .present = generation != 0 } });
        return error.RefreshGenerationConflict;
    }
    const value = (try view(turn, principal, selection.generation)) orelse return error.RefreshNotFound;
    if (!std.meta.eql(value.session, selection.session)) {
        f.remember(context, .{ .generation = .{ .expected = selection.session.generation, .actual = value.session.generation } });
        return error.ReactiveGenerationConflict;
    }
    return value;
}
fn proof(turn: *Turn, value: m.View) !m.Proof {
    return c.decode(m.Proof, 'I', (try turn.read(m.proofKey(value.principal, value.generation))) orelse return error.InvalidServingRecord);
}
fn sameBasis(watch: root.TableWatch.Observation, captured: q.Basis, context: ?*f.Context) !void {
    var basis = captured;
    basis.cut.revision = watch.data_revision;
    if (!root.TableWatch.covered(watch, basis)) {
        const witness: f.Witness = if (captured.cut.kind != .table)
            .{ .source_kind = .{ .expected = .table, .actual = captured.cut.kind } }
        else if (captured.cut.resource != watch.basis.cut.resource)
            .{ .target = .{ .expected = watch.basis.cut.resource, .actual = captured.cut.resource, .kind = .resource } }
        else if (!std.mem.eql(u8, &captured.contract, &watch.basis.contract))
            .{ .basis = .{ .kind = .contract, .expected = watch.basis.contract, .actual = captured.contract } }
        else
            .{ .basis = .{ .kind = .schema, .expected = watch.basis.schema, .actual = captured.schema } };
        f.remember(context, witness);
        return error.InvalidRefreshTemplate;
    }
}
/// Reader contract: authorize(principal, source, proof), observe(principal, source), and
/// result(turn, namespace, source). Result must use the shared manifest/current
/// result reader. No caller-supplied watermark is trusted for scheduling.
pub fn apply(self: Self, turn: *Turn, principal: u64, command: m.Command, input_reader: anytype, upper_ms: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    const reader = input_reader.withDiagnostic(self.diagnostic);
    if (principal != self.principal or turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != principal) return error.ServingDenied;
    switch (command) {
        .follow => |input| {
            if (input.view.limit == 0 or input.view.limit > m.max_starts or input.view.template.value == 0) return error.InvalidRefreshBudget;
            const watch = try live(turn, principal, input.view.session, upper_ms, self.diagnostic);
            if (watch.target != self.source) {
                f.remember(self.diagnostic, .{ .target = .{ .expected = self.source, .actual = watch.target, .kind = .source } });
                return error.InvalidRefreshTemplate;
            }
            const generation = try head(turn, principal, input.view.session.session);
            if (input.view.expected != generation) {
                f.remember(self.diagnostic, .{ .revision = .{ .kind = .refresh, .expected = input.view.expected, .actual = generation, .proposed = turn.delivery.input.position, .present = generation != 0 } });
                return error.RefreshGenerationConflict;
            }
            try reader.authorize(principal, watch, input.proof);
            const captured = try reader.result(turn, input.view.template.value, watch);
            const observed = try reader.observe(principal, watch);
            try sameBasis(observed, captured, self.diagnostic);
            const value: m.View = .{ .principal = principal, .session = input.view.session, .generation = turn.delivery.input.position, .source = watch, .template = input.view.template, .namespace = input.view.template, .dirty = observed.data_revision, .covered = captured.cut.revision, .limit = input.view.limit };
            try save(turn, value);
            try turn.write(m.proofKey(principal, value.generation), try c.encode('I', input.proof));
            try turn.write(m.headKey(principal, value.session.session), try c.encode('F', value.generation));
        },
        .invalidate => |selection| {
            const watch = try live(turn, principal, selection.session, upper_ms, self.diagnostic);
            var value = try selected(turn, principal, selection, self.diagnostic);
            if (!std.meta.eql(watch, value.source)) {
                f.remember(self.diagnostic, f.sourceWitness(watch, value.source.revision));
                return error.ReactiveResetRequired;
            }
            if (!value.enabled) return;
            try reader.authorize(principal, watch, try proof(turn, value));
            const observed = try reader.observe(principal, watch);
            if (observed.data_revision > value.dirty) {
                value.dirty = observed.data_revision;
                try save(turn, value);
            }
        },
        .acknowledged => |input| {
            try policy(turn, principal, self.diagnostic);
            var value = try selected(turn, principal, input.selection, self.diagnostic);
            if (value.namespace.value != input.namespace.value or value.phase != .ready) {
                f.remember(self.diagnostic, .{ .refresh = .{ .expected = input.namespace, .actual = value.namespace, .phase = value.phase } });
                return error.RefreshResultConflict;
            }
            try reader.authorize(principal, value.source, try proof(turn, value));
            const captured = try reader.result(turn, value.namespace.value, value.source);
            const observed = try reader.observe(principal, value.source);
            try sameBasis(observed, captured, self.diagnostic);
            value.covered = captured.cut.revision;
            value.dirty = @max(value.dirty, observed.data_revision);
            value.phase = if (!value.enabled) .paused else if (value.starts >= value.limit) .exhausted else .idle;
            if (value.phase == .exhausted) value.failure = failure.record(turn.delivery.input.position, .budget_exhausted, .{});
            try save(turn, value);
        },
        .pause => |selection| {
            // Releasing scheduling never authorizes disclosure or cancellation.
            _ = try ownedSession(turn, principal, selection.session, self.diagnostic);
            var value = try selected(turn, principal, selection, self.diagnostic);
            value.enabled = false;
            if (value.failure == .none) value.failure = failure.record(turn.delivery.input.position, .paused, .{});
            if (value.phase == .idle) value.phase = .paused;
            try save(turn, value);
        },
    }
}
/// Composed with the successful session closure/expiry in the same turn. No
/// query cancellation or replacement is inferred. At most one additional write.
pub fn sessionStopped(turn: *Turn, principal: u64, identity: r.SessionIdentity) !void {
    const generation = try head(turn, principal, identity.session);
    if (generation == 0) return;
    var value = (try view(turn, principal, generation)) orelse return error.InvalidServingRecord;
    if (!std.meta.eql(value.session, identity)) return; // A different session generation owns this view.
    const owner = try ownedSession(turn, principal, identity, null);
    if (owner.phase == .open) return error.InvalidServingRecord;
    const before = value;
    value.enabled = false;
    if (value.failure == .none) value.failure = failure.record(turn.delivery.input.position, if (owner.phase == .closed) .session_closed else .session_expired, .{ .witness = .{ .session = .{ .phase = owner.phase, .deadline = owner.lease_before_ms, .observed = 0, .clock_known = false } } });
    if (value.phase == .idle) value.phase = .paused;
    if (!std.meta.eql(value, before)) try save(turn, value);
}
fn denial(err: anyerror) bool {
    return switch (err) {
        error.ServingDenied, error.AccessDenied, error.QueryDenied, error.CatalogDenied, error.ResourceUnavailable, error.QuerySourceUnavailable, error.ResultUnavailable, error.PublicationNotPublished => true,
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
                value.phase = if (work.phase == .complete) .ready else if (work.failure.?.category() == .access) .denied else .failed;
                if (work.phase != .complete) {
                    value.enabled = false;
                    if (value.failure == .none) value.failure = failure.record(turn.delivery.input.position, .query_rejected, .{});
                }
                try save(turn, value);
                state.principal = 0;
                state.generation = 0;
                try saveScheduler(turn, state);
                return true;
            },
            .cancelled, .retired => {
                const previous = value;
                value.enabled = false;
                if (value.phase == .copying or value.phase == .admitted or value.phase == .ready) value.phase = .paused;
                if (value.failure == .none) value.failure = failure.record(turn.delivery.input.position, if (work.phase == .cancelled) .query_cancelled else .query_retired, .{});
                if (!std.meta.eql(previous, value)) {
                    // Record the stop separately from bounded upload cleanup,
                    // which may already consume the complete mutation budget.
                    try save(turn, value);
                    return true;
                }
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
        var context: f.Context = .{};
        var owner = self;
        owner.diagnostic = &context;
        return owner.advance(turn, value, reader.withDiagnostic(&context)) catch |err| {
            turn.decision = before;
            if (turn.read_error != null or (!denial(err) and err != error.QueryUploadClosed and err != error.InvalidRefreshTemplate)) return err;
            const why = failure.reason(err) orelse return err;
            value.phase = if (failure.denied(why)) .denied else .failed;
            value.failure = failure.record(turn.delivery.input.position, why, context);
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
        var context: f.Context = .{};
        const watch = live(turn, slot.principal, value.session, upper_ms, &context) catch |err| {
            if (turn.read_error != null or (!denial(err) and err != error.ReactiveSessionClosed and err != error.ReactiveSessionExpired and err != error.ReactiveResetRequired and err != error.ServiceUnpublished)) return err;
            value.enabled = false;
            const why = failure.reason(err) orelse return err;
            value.phase = if (failure.denied(why)) .denied else .paused;
            value.failure = failure.record(turn.delivery.input.position, why, context);
            try save(turn, value);
            return true;
        };
        if (!std.meta.eql(watch, value.source)) {
            value.enabled = false;
            value.phase = .paused;
            value.failure = failure.record(turn.delivery.input.position, .source_changed, .{ .witness = f.sourceWitness(watch, value.source.revision) });
            try save(turn, value);
            return true;
        }
        if (value.starts >= value.limit) {
            value.phase = .exhausted;
            value.failure = failure.record(turn.delivery.input.position, .budget_exhausted, .{});
            try save(turn, value);
            return true;
        }
        reader.withDiagnostic(&context).authorize(slot.principal, watch, try proof(turn, value)) catch |err| {
            if (!denial(err)) return err;
            value.enabled = false;
            const why = failure.reason(err) orelse return err;
            value.phase = if (failure.denied(why)) .denied else .failed;
            value.failure = failure.record(turn.delivery.input.position, why, context);
            try save(turn, value);
            return true;
        };
        // Reserved high-bit namespace domain plus the globally unique committed
        // input position. Explicit old user choices can collide, never overwrite.
        const namespace = (@as(u64, 1) << 63) | turn.delivery.input.position;
        if (try q.UnifiedUpload.status(turn, namespace) != null or try turn.read(root.station.Publication.key(.query_request, namespace, 'b', 0, 0)) != null) {
            value.enabled = false;
            value.phase = .failed;
            value.failure = failure.record(turn.delivery.input.position, .namespace_occupied, .{ .witness = .{ .refresh = .{ .expected = .{ .value = namespace }, .actual = .{ .value = namespace }, .phase = value.phase } } });
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
    try policy(turn, value.principal, self.diagnostic);
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
