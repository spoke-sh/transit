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
        fn reject(turn: *Turn, caller: u64, frame: Frame, detail: Rejection) !void {
            const original = detail.original(turn.delivery.input.position, frame.payload);
            try turn.send(caller, .{ .kind = .reply, .correlation = frame.correlation, .payload = try x.codec.encode(original) });
        }
        pub fn rejectCall(turn: *Turn, detail: Rejection) !void {
            const frame = try Frame.decode(turn.delivery.input.value);
            if (frame.kind != .call) return Adapter.expected_call_error;
            try reject(turn, try Frame.source(turn.delivery.input), frame, detail);
        }
        fn callerDenied(caller: u64) Rejection {
            return Rejection.detail(.denied, .policy, "caller", .redacted, .{ .unsigned = caller }, null);
        }
        fn referenceFailure(reference: Reference, policy: Admission, comptime prefix: []const u8) ?Rejection {
            if (reference.resource != policy.resource) return Rejection.detail(.denied, .equal, prefix ++ "resource", .{ .unsigned = policy.resource }, .{ .unsigned = reference.resource }, null);
            if (reference.endpoint_revision != policy.endpoint_revision) return Rejection.detail(.denied, .equal, prefix ++ "endpoint_revision", .{ .unsigned = policy.endpoint_revision }, .{ .unsigned = reference.endpoint_revision }, null);
            if (reference.reconcile_before_ms > policy.reconcile_before_ms) return Rejection.detail(.denied, .maximum, prefix ++ "reconcile_before_ms", .{ .unsigned = policy.reconcile_before_ms }, .{ .unsigned = reference.reconcile_before_ms }, null);
            if (reference.max_attempts > policy.max_attempts) return Rejection.detail(.denied, .maximum, prefix ++ "max_attempts", .{ .unsigned = policy.max_attempts }, .{ .unsigned = reference.max_attempts }, null);
            return null;
        }
        fn unavailableParent(parent: u64) Rejection {
            // Missing and foreign-caller parents have the same disclosure.
            return Rejection.detail(.denied, .available, "parent", .redacted, .{ .unsigned = parent }, null);
        }
        fn unpublished(phase: @FieldType(Route, "phase")) Rejection {
            return Rejection.detail(.busy, .state, "route.phase", .{ .text = "published" }, .{ .text = @tagName(phase) }, null);
        }
        pub fn admit(turn: *Turn, id: u64, policy: Admission, limits: x.Limits) !enum { admitted, duplicate, rejected } {
            const before = turn.decision;
            errdefer turn.decision = before;
            const frame = try Frame.decode(turn.delivery.input.value);
            if (frame.kind != .call) return Adapter.expected_call_error;
            const caller = try Frame.source(turn.delivery.input);
            if (caller != policy.caller) {
                try reject(turn, caller, frame, callerDenied(caller));
                return .rejected;
            }
            const reference = Reference.decode(frame.payload) catch |err| {
                try reject(turn, caller, frame, Rejection.detail(.invalid_request, .decode, "request", .{ .unsigned = x.codec.size(Reference) }, .{ .unsigned = frame.payload.len }, err));
                return .rejected;
            };
            if (referenceFailure(reference, policy, "request.")) |detail| {
                try reject(turn, caller, frame, detail);
                return .rejected;
            }
            const ex: x.Exchange = .{ .resource = turn.view.resource, .id = id };
            if (try route(ex, turn)) |previous| {
                if (previous.caller == caller and previous.correlation == frame.correlation and std.mem.eql(u8, &previous.request, frame.payload.slice())) return .duplicate;
                try reject(turn, caller, frame, Rejection.detail(.busy, .occupied, "exchange", .unrecorded, .unrecorded, null));
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
            if (caller != policy.caller) {
                try reject(turn, caller, frame, callerDenied(caller));
                return .rejected;
            }
            const follow = Followup.decode(frame.payload) catch |err| {
                try reject(turn, caller, frame, Rejection.detail(.invalid_request, .decode, "followup", .{ .unsigned = x.codec.size(Followup) }, .{ .unsigned = frame.payload.len }, err));
                return .rejected;
            };
            const reference = try follow.reference();
            const target_failure: ?Rejection = if (follow.resource != turn.view.resource)
                Rejection.detail(.denied, .equal, "followup.resource", .{ .unsigned = turn.view.resource }, .{ .unsigned = follow.resource }, null)
            else if (follow.parent != target.parent)
                Rejection.detail(.denied, .equal, "followup.parent", .{ .unsigned = target.parent }, .{ .unsigned = follow.parent }, null)
            else if (follow.reason != target.reason)
                Rejection.detail(.denied, .equal, "followup.reason", .{ .text = @tagName(target.reason) }, .{ .text = @tagName(follow.reason) }, null)
            else if (follow.parent == id)
                Rejection.detail(.denied, .different, "followup.parent", .{ .unsigned = id }, .{ .unsigned = follow.parent }, null)
            else
                referenceFailure(reference, policy, "request.");
            if (target_failure) |detail| {
                try reject(turn, caller, frame, detail);
                return .rejected;
            }
            const ex: x.Exchange = .{ .resource = turn.view.resource, .id = id };
            if (try route(ex, turn)) |previous| {
                const linked = try ex.lineage(turn);
                if (previous.caller == caller and previous.correlation == frame.correlation and std.mem.eql(u8, &previous.request, &follow.request) and
                    linked != null and linked.?.lineage.parent == follow.parent and linked.?.lineage.reason == follow.reason) return .duplicate;
                try reject(turn, caller, frame, Rejection.detail(.busy, .occupied, "exchange", .unrecorded, .unrecorded, null));
                return .rejected;
            }
            if (try turn.read(x.Exchange.key(id, 'd', 0)) != null) {
                try reject(turn, caller, frame, Rejection.detail(.busy, .occupied, "exchange", .unrecorded, .unrecorded, null));
                return .rejected;
            }
            const parent: x.Exchange = .{ .resource = follow.resource, .id = follow.parent };
            const original = (try route(parent, turn)) orelse {
                try reject(turn, caller, frame, unavailableParent(follow.parent));
                return .rejected;
            };
            if (original.caller != caller) {
                try reject(turn, caller, frame, unavailableParent(follow.parent));
                return .rejected;
            }
            if (referenceFailure(try original.reference(), policy, "parent.")) |detail| {
                try reject(turn, caller, frame, detail);
                return .rejected;
            }
            if (original.phase != .published) {
                try reject(turn, caller, frame, unpublished(original.phase));
                return .rejected;
            }
            const descriptor = try parent.inspect(turn);
            const prior_request = try original.reference();
            if (descriptor.owner != turn.delivery.pid or descriptor.caller != original.caller or descriptor.input != original.input or descriptor.protocol != Adapter.protocol_format) return Adapter.invalid_route_error;
            const frozen_failure: ?Rejection = if (descriptor.phase == .retired)
                Rejection.detail(.denied, .state, "parent.phase", .{ .text = "retained" }, .{ .text = "retired" }, null)
            else if (reference.reconcile_before_ms != descriptor.reconcile_before_ms)
                Rejection.detail(.denied, .equal, "parent.reconcile_before_ms", .{ .unsigned = descriptor.reconcile_before_ms }, .{ .unsigned = reference.reconcile_before_ms }, null)
            else if (reference.max_attempts != prior_request.max_attempts)
                Rejection.detail(.denied, .equal, "parent.max_attempts", .{ .unsigned = prior_request.max_attempts }, .{ .unsigned = reference.max_attempts }, null)
            else
                null;
            if (frozen_failure) |detail| {
                try reject(turn, caller, frame, detail);
                return .rejected;
            }
            const terminal = try parent.control(turn);
            const expected_disposition: @FieldType(@TypeOf(terminal), "disposition") = if (follow.reason == .redirect) .observed else .closed_unknown;
            if (terminal.disposition != expected_disposition) {
                try reject(turn, caller, frame, Rejection.detail(.denied, .state, "parent.disposition", .{ .text = @tagName(expected_disposition) }, .{ .text = @tagName(terminal.disposition) }, null));
                return .rejected;
            }
            const expected_phase: x.Phase = if (follow.reason == .redirect) .complete else .unknown;
            if (descriptor.phase != expected_phase) {
                try reject(turn, caller, frame, Rejection.detail(.denied, .state, "parent.phase", .{ .text = @tagName(expected_phase) }, .{ .text = @tagName(descriptor.phase) }, null));
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
            var attempt_failure: ?x.Exchange.AttemptFailure = null;
            _ = parent.followupWithContextDiagnostic(turn, id, follow.reason, decision.id, decision.revision, limits, try x.codec.encode(stored), &attempt_failure) catch |err| switch (err) {
                error.ExchangeAttemptBudgetExceeded => {
                    const detail = attempt_failure orelse return err;
                    try reject(turn, caller, frame, if (detail.present)
                        Rejection.detail(.denied, .maximum, "lineage.attempts", .{ .unsigned = detail.limit }, .{ .unsigned = @as(u64, detail.used) + 1 }, err)
                    else
                        Rejection.detail(.denied, .available, "lineage.attempt_budget", .unrecorded, .inapplicable, err));
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
            if (caller != policy.caller) return reject(turn, caller, frame, callerDenied(caller));
            const request = Release.decode(frame.payload) catch |err| return reject(turn, caller, frame, Rejection.detail(.invalid_request, .decode, "release", .{ .unsigned = x.codec.size(Release) }, .{ .unsigned = frame.payload.len }, err));
            if (request.resource != ex.resource) return reject(turn, caller, frame, Rejection.detail(.denied, .equal, "release.resource", .{ .unsigned = ex.resource }, .{ .unsigned = request.resource }, null));
            if (request.exchange != ex.id) return reject(turn, caller, frame, Rejection.detail(.denied, .equal, "release.exchange", .{ .unsigned = ex.id }, .{ .unsigned = request.exchange }, null));
            const record = (try route(ex, turn)) orelse return reject(turn, caller, frame, unavailableParent(request.exchange));
            if (record.caller != caller) return reject(turn, caller, frame, unavailableParent(request.exchange));
            if (referenceFailure(try record.reference(), policy, "original.")) |detail| return reject(turn, caller, frame, detail);
            if (record.phase != .published) return reject(turn, caller, frame, unpublished(record.phase));
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
