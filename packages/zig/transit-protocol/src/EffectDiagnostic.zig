//! Pure projection of retained native decisions. The caller must authorize the
//! underlying read; no transport outcome is inferred from an authorization.
const std = @import("std");
const p = @import("root.zig");
const g = p.Growth;
const d = p.Diagnostic;

pub fn from(realm: u64, position: u64, effect: g.Effect) !d {
    try g.validateEffect(effect, position);
    const Descriptor = struct { code: []const u8, category: d.Category = .lifecycle, outcome: d.Outcome, message: []const u8 };
    const descriptor: Descriptor = switch (effect.phase) {
        .pending => .{ .code = "effect.intent_pending", .outcome = .pending, .message = "The effect intent is recorded. No attempt has been authorized for this intent." },
        .authorized => .{ .code = "effect.attempt_authorized", .outcome = .unknown, .message = "An attempt is authorized, but no observation is recorded. Authorization does not establish whether the remote request was sent or completed." },
        .unknown => .{ .code = "effect.observation_unknown", .outcome = .unknown, .message = "The executor recorded an observation without a result. The remote outcome remains unknown; further reconciliation requires current authority and connector policy." },
        .observed => .{ .code = "effect.result_recorded", .outcome = .completed, .message = "The authority accepted the executor's result observation. Its application meaning belongs to the connector; this does not prove honest remote computation or business success." },
        .cancelled => .{ .code = "effect.unattempted_cancelled", .outcome = .cancelled, .message = "The unattempted intent was cancelled after its caller became terminal. No attempt was authorized for this intent. This is not cancellation of a remote request." },
        .closed_unknown => switch (effect.closure.?.reason) {
            .observation_budget => .{ .code = "effect.observation_limit", .category = .limit, .outcome = .closed_unknown, .message = "Reconciliation closed after the final permitted observation still had no result. The remote outcome remains unknown; closure does not make a new attempt safe." },
            .deadline => .{ .code = "effect.reconciliation_expired", .outcome = .closed_unknown, .message = "The authority closed reconciliation after its trusted clock reached the recorded deadline. The remote outcome remains unknown; this does not cancel or undo remote work." },
            .abandoned => .{ .code = "effect.reconciliation_abandoned", .outcome = .closed_unknown, .message = "An authorized principal explicitly closed reconciliation without a result. The remote outcome remains unknown; closure does not establish remote failure or permit a fresh retry." },
            else => return error.InvalidRead,
        },
    };
    var value = try d.init(descriptor.code, descriptor.category, .reconcile, descriptor.outcome, .domain_status, descriptor.message);
    value.identity = .{ .domain = .effect, .realm = .init(realm), .id = .init(effect.id) };
    try value.fact(.object, .execution, .{ .unsigned = .init(effect.pid) });
    try value.text(.operation, .execution, @tagName(effect.phase));
    if (effect.attempt) |attempt| try value.fact(.attempt, .authority, .{ .unsigned = .init(attempt) });
    if (effect.executor) |executor| try value.fact(.executor, .authority, .{ .unsigned = .init(executor) });
    if (effect.authorization_policy) |revision| try value.fact(.authorization_policy, .authority, .{ .unsigned = .init(revision) });
    try value.text(.budget, .authority, "observations");
    try value.fact(.actual_count, .execution, .{ .unsigned = .init(effect.observations) });
    try value.fact(.limit, .authority, .{ .unsigned = .init(effect.max_observations) });
    if (effect.reconcile_before_ms) |deadline| try value.fact(.deadline, .authority, .{ .unsigned = .init(deadline) });
    if (effect.closed_at orelse if (effect.last_observation) |last| last.input else null) |input| try value.fact(.native_input, .authority, .{ .unsigned = .init(input) });
    if (effect.closure) |closure| {
        try value.text(.resolution_reason, .authority, @tagName(closure.reason));
        try value.fact(.principal, .authority, .{ .unsigned = .init(closure.principal) });
        try value.fact(.resolution_policy, .authority, .{ .unsigned = .init(closure.policy_revision) });
        if (closure.clock_lower_ms) |clock| try value.fact(.observed_clock, .authority, .{ .unsigned = .init(clock) });
    } else if (effect.last_observation) |last| try value.fact(.resolution_policy, .authority, .{ .unsigned = .init(last.policy_revision) });
    try value.action(.inspect_status);
    try value.validate();
    return value;
}

test "effect projection distinguishes every phase and every unknown closure without fresh retry advice" {
    const t = std.testing;
    var effect: g.Effect = .{ .id = 2, .pid = 1, .payload = .{}, .max_observations = 2 };
    try t.expectEqualStrings("effect.intent_pending", (try from(1, 10, effect)).code.slice());
    effect.phase = .authorized;
    effect.attempt = 3;
    effect.executor = 4;
    effect.authorization_policy = 1;
    try t.expectEqual(.unknown, (try from(1, 10, effect)).outcome);
    effect.phase = .unknown;
    effect.observations = 1;
    effect.last_observation = .{ .input = 5, .policy_revision = 4 };
    try t.expectEqualStrings("effect.observation_unknown", (try from(1, 10, effect)).code.slice());
    effect.phase = .closed_unknown;
    effect.closed_at = 6;
    effect.reconcile_before_ms = 100;
    inline for (.{ .abandoned, .deadline, .observation_budget }) |reason| {
        var closed = effect;
        closed.closure = .{ .reason = reason, .principal = 4, .policy_revision = 4, .clock_lower_ms = if (reason == .deadline) 100 else null };
        if (reason == .observation_budget) {
            closed.observations = 2;
            closed.last_observation.?.input = 6;
        }
        const diagnostic = try from(1, 10, closed);
        try t.expectEqual(.closed_unknown, diagnostic.outcome);
        try t.expectEqual(.inspect_status, diagnostic.actions[0].?.kind);
        try t.expectEqual(null, diagnostic.actions[1]);
        var bytes: [4096]u8 = undefined;
        _ = try diagnostic.encode(&bytes);
    }
    effect.phase = .observed;
    effect.result = .integer(7);
    effect.last_observation.?.input = 6;
    effect.closure = .{ .reason = .observed, .principal = 4, .policy_revision = 4 };
    try t.expectEqual(.completed, (try from(1, 10, effect)).outcome);
    effect = .{ .id = 2, .pid = 1, .payload = .{}, .phase = .cancelled, .closed_at = 6, .closure = .{ .reason = .unattempted_cancel, .principal = 0, .policy_revision = 0 } };
    try t.expectEqual(.cancelled, (try from(1, 10, effect)).outcome);
    effect.closure = null;
    try t.expectError(error.InvalidRead, from(1, 10, effect));
}
