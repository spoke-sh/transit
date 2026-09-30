//! Shared authenticated call routing above Exchange. Adapter-owned records and
//! policy decisions retain protocol meaning; this helper cannot dispatch I/O.
const std = @import("std");
const x = @import("root.zig");
const Turn = x.station.Turn;
const Frame = x.station.Frame;
pub fn For(comptime Adapter: type) type {
    return struct {
        const Reference = Adapter.Reference;
        const Admission = Adapter.Admission;
        const Route = Adapter.Route;
        const Outcome = Adapter.Outcome;
        const Rejection = Adapter.Rejection;
        const Release = Adapter.Release;
        const Released = Adapter.Released;
        const Followup = Adapter.Followup;
        const FollowupTarget = Adapter.FollowupTarget;
        pub fn route(exchange: x.Exchange, source: anytype) !?Route {
            if (try source.read(x.Exchange.key(exchange.id, 'r', 0))) |value| return try x.codec.decode(Route, value);
            const linked = (try exchange.lineage(source)) orelse return null;
            return if (linked.context.len != 0) try x.codec.decode(Route, linked.context) else null;
        }
        fn reject(turn: *Turn, caller: u64, frame: Frame, reason: @FieldType(Rejection, "reason")) !void {
            try turn.send(caller, .{ .kind = .reply, .correlation = frame.correlation, .payload = try x.codec.encode(Rejection{ .reason = reason }) });
        }
        pub fn rejectCall(turn: *Turn, reason: @FieldType(Rejection, "reason")) !void {
            const frame = try Frame.decode(turn.delivery.input.value);
            if (frame.kind != .call) return Adapter.expected_call_error;
            try reject(turn, try Frame.source(turn.delivery.input), frame, reason);
        }
        pub fn admit(turn: *Turn, id: u64, policy: Admission, limits: x.Limits) !enum { admitted, duplicate, rejected } {
            const before = turn.decision;
            errdefer turn.decision = before;
            const frame = try Frame.decode(turn.delivery.input.value);
            if (frame.kind != .call) return Adapter.expected_call_error;
            const caller = try Frame.source(turn.delivery.input);
            const reference = Reference.decode(frame.payload) catch {
                try reject(turn, caller, frame, .invalid_request);
                return .rejected;
            };
            if (caller != policy.caller or reference.resource != policy.resource or reference.endpoint_revision != policy.endpoint_revision or reference.reconcile_before_ms > policy.reconcile_before_ms or reference.max_attempts > policy.max_attempts) {
                try reject(turn, caller, frame, .denied);
                return .rejected;
            }
            const ex: x.Exchange = .{ .resource = turn.view.resource, .id = id };
            if (try route(ex, turn)) |previous| {
                if (previous.caller == caller and previous.correlation == frame.correlation and std.mem.eql(u8, &previous.request, frame.payload.slice())) return .duplicate;
                try reject(turn, caller, frame, .busy);
                return .rejected;
            }
            const created = try x.Exchange.create(turn, id, .{ .caller = caller, .input = turn.delivery.input.position, .protocol = Adapter.protocol_format }, limits, reference.reconcile_before_ms);
            const stored: Route = .{ .caller = caller, .input = turn.delivery.input.position, .correlation = frame.correlation, .request = frame.payload.data[0..x.codec.size(Reference)].* };
            try turn.write(x.Exchange.key(created.id, 'r', 0), try x.codec.encode(stored));
            return .admitted;
        }
        /// Current service policy is separate from PID ownership. No name lookup can
        /// redirect a previously accepted call to a replacement caller.
        pub fn allowed(record: Route, policy: Admission) bool {
            const reference = record.reference() catch return false;
            return record.caller == policy.caller and reference.resource == policy.resource and reference.endpoint_revision == policy.endpoint_revision and reference.max_attempts <= policy.max_attempts and reference.reconcile_before_ms <= policy.reconcile_before_ms;
        }
        /// The validator reads immutable published request bytes and checks the frozen
        /// parent policy without dispatching. Only then can this turn allocate a child.
        /// Validator I/O errors leave the input uncommitted for explicit recovery.
        pub fn admitFollowup(turn: *Turn, id: u64, policy: Admission, target: FollowupTarget, limits: x.Limits, validator: anytype) !enum { admitted, duplicate, rejected } {
            const before = turn.decision;
            errdefer turn.decision = before;
            const frame = try Frame.decode(turn.delivery.input.value);
            if (frame.kind != .call) return Adapter.expected_call_error;
            const caller = try Frame.source(turn.delivery.input);
            const follow = Followup.decode(frame.payload) catch {
                try reject(turn, caller, frame, .invalid_request);
                return .rejected;
            };
            const reference = try follow.reference();
            if (caller != policy.caller or follow.resource != turn.view.resource or follow.parent != target.parent or follow.reason != target.reason or follow.parent == id or
                reference.resource != policy.resource or reference.endpoint_revision != policy.endpoint_revision or reference.reconcile_before_ms > policy.reconcile_before_ms or reference.max_attempts > policy.max_attempts)
            {
                try reject(turn, caller, frame, .denied);
                return .rejected;
            }
            const ex: x.Exchange = .{ .resource = turn.view.resource, .id = id };
            if (try route(ex, turn)) |previous| {
                const linked = try ex.lineage(turn);
                if (previous.caller == caller and previous.correlation == frame.correlation and std.mem.eql(u8, &previous.request, &follow.request) and
                    linked != null and linked.?.lineage.parent == follow.parent and linked.?.lineage.reason == follow.reason) return .duplicate;
                try reject(turn, caller, frame, .busy);
                return .rejected;
            }
            if (try turn.read(x.Exchange.key(id, 'd', 0)) != null) {
                try reject(turn, caller, frame, .busy);
                return .rejected;
            }
            const parent: x.Exchange = .{ .resource = follow.resource, .id = follow.parent };
            const original = (try route(parent, turn)) orelse {
                try reject(turn, caller, frame, .denied);
                return .rejected;
            };
            if (!allowed(original, policy) or original.caller != caller) {
                try reject(turn, caller, frame, .denied);
                return .rejected;
            }
            if (original.phase != .published) {
                try reject(turn, caller, frame, .busy);
                return .rejected;
            }
            const descriptor = try parent.inspect(turn);
            const prior_request = try original.reference();
            if (descriptor.owner != turn.delivery.pid or descriptor.caller != original.caller or descriptor.input != original.input or descriptor.protocol != Adapter.protocol_format) return Adapter.invalid_route_error;
            if (descriptor.phase == .retired or reference.reconcile_before_ms != descriptor.reconcile_before_ms or reference.max_attempts != prior_request.max_attempts) {
                try reject(turn, caller, frame, .denied);
                return .rejected;
            }
            const terminal = try parent.control(turn);
            if (if (follow.reason == .redirect) terminal.disposition != .observed or descriptor.phase != .complete else terminal.disposition != .closed_unknown or descriptor.phase != .unknown) {
                try reject(turn, caller, frame, .denied);
                return .rejected;
            }
            const decision = switch (try validator.validateAdmission(follow)) {
                .accepted => |value| value,
                .rejected => |reason| {
                    try reject(turn, caller, frame, reason);
                    return .rejected;
                },
            };
            try decision.validate();
            const stored: Route = .{ .caller = caller, .input = original.input, .correlation = frame.correlation, .request = follow.request };
            _ = parent.followupWithContext(turn, id, follow.reason, decision.id, decision.revision, limits, try x.codec.encode(stored)) catch |err| switch (err) {
                error.ExchangeAttemptBudgetExceeded => {
                    try reject(turn, caller, frame, .denied);
                    return .rejected;
                },
                else => return err,
            };
            return .admitted;
        }
        /// Admit one authenticated disposal call against an already published route.
        /// Mutation and correlated acknowledgement share the same fenced turn. Duplicate
        /// disposal returns the same identity, including after explicit retirement.
        pub fn release(turn: *Turn, ex: x.Exchange, policy: Admission) !void {
            const before = turn.decision;
            errdefer turn.decision = before;
            const frame = try Frame.decode(turn.delivery.input.value);
            if (frame.kind != .call) return Adapter.expected_call_error;
            const caller = try Frame.source(turn.delivery.input);
            const request = Release.decode(frame.payload) catch return reject(turn, caller, frame, .invalid_request);
            if (caller != policy.caller or request.resource != ex.resource or request.exchange != ex.id) return reject(turn, caller, frame, .denied);
            const record = (try route(ex, turn)) orelse return reject(turn, caller, frame, .denied);
            if (record.caller != caller or !allowed(record, policy)) return reject(turn, caller, frame, .denied);
            if (record.phase != .published) return reject(turn, caller, frame, .busy);
            const descriptor = try ex.inspect(turn);
            if (descriptor.owner != turn.delivery.pid or descriptor.caller != record.caller or descriptor.input != record.input) return Adapter.invalid_route_error;
            // Abandoned preparation never acquired a caller hold or dispatch obligation.
            if ((try ex.control(turn)).disposition != .no_intent) _ = try ex.releaseCaller(turn, caller);
            try turn.send(caller, .{ .kind = .reply, .correlation = frame.correlation, .payload = try (Released{ .resource = ex.resource, .exchange = ex.id }).encode() });
        }
        pub fn publish(turn: *Turn, ex: x.Exchange) !bool {
            const before = turn.decision;
            errdefer turn.decision = before;
            var record = (try route(ex, turn)) orelse return false;
            if (record.phase == .published) return false;
            const descriptor = try ex.inspect(turn);
            if (descriptor.owner != turn.delivery.pid or descriptor.caller != record.caller or descriptor.input != record.input) return Adapter.invalid_route_error;
            const control = try ex.control(turn);
            const phase: @FieldType(Outcome, "phase") = switch (control.disposition) {
                .observed => if (descriptor.phase == .complete) .observed else return error.IncompleteExchange,
                .closed_unknown => .closed_unknown,
                .cancelled => .not_dispatched,
                .no_intent => if (descriptor.phase == .unknown) .not_dispatched else return error.UnsettledExchange,
                .pending => return error.UnsettledExchange,
            };
            const value: Outcome = .{ .phase = phase, .resource = ex.resource, .exchange = ex.id, .effect = control.effect, .attempt = descriptor.attempt, .status = if (phase == .observed) try Adapter.observedStatus(descriptor.terminal_code) else 0, .chain = if (phase == .observed) descriptor.chain else @splat(0) };
            try turn.send(record.caller, .{ .kind = .reply, .correlation = record.correlation, .payload = try value.encode() });
            record.phase = .published;
            try turn.write(x.Exchange.key(ex.id, 'r', 0), try x.codec.encode(record));
            return true;
        }
    };
}
