//! Historical plan progress, projected only after an authorized owner read.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;

pub fn progress(application: u64, realm: u64, resource: u64, plan: root.Migration.Plan, state: root.Migration.Progress) !d {
    inline for (.{ application, realm, resource, plan.principal, plan.input, state.input }) |id| {
        if (id == 0 or id > p.max_counter) return error.InvalidMigrationRecord;
    }
    const proposal = plan.proposal;
    if (proposal.plan.value == 0 or proposal.expected.value == 0 or proposal.transform == 0 or
        proposal.next.value != (std.math.add(u64, proposal.expected.value, 1) catch return error.InvalidMigrationRecord) or
        state.next.value == 0 or state.input < plan.input or state.cursor.len > 128 or
        (state.next.value == 1 and (state.cursor.len != 0 or state.phase == .applied))) return error.InvalidMigrationRecord;
    try state.cursor.validate();
    const description: struct { code: []const u8, outcome: d.Outcome, message: []const u8 } = switch (state.phase) {
        .active => .{ .code = "migration.active", .outcome = .pending, .message = "The reviewed migration plan is active. Earlier steps may already have committed staged data. Inspect the exact plan, next step ordinal and application cursor before continuing; a rejected input or lost reply does not abandon this plan." },
        .applied => .{ .code = "migration.applied", .outcome = .applied, .message = "This migration activated its reviewed target epoch and contract. Its activation and final step receipt committed together. Abandonment cannot undo activation. Interface publication and application write release remain separate operations." },
        .abandoned => .{ .code = "migration.abandoned", .outcome = .cancelled, .message = "This migration plan was explicitly abandoned without activating its target epoch. Earlier committed steps and staged data remain recorded; abandonment does not prove their physical cleanup or cancel another plan." },
    };
    var result = try d.init(description.code, .lifecycle, if (state.phase == .abandoned) .control else .execute, description.outcome, .domain_status, description.message);
    result.identity = .{ .domain = .migration, .id = .init(proposal.plan.value), .realm = .init(realm), .resource = .init(resource) };
    try result.fact(.object, .owner, .{ .unsigned = .init(application) });
    try result.fact(.principal, .owner, .{ .unsigned = .init(plan.principal) });
    try result.fact(.first_occurrence, .owner, .{ .unsigned = .init(plan.input) });
    try result.fact(.native_input, .owner, .{ .unsigned = .init(state.input) });
    try result.fact(.source_basis, .owner, .{ .digest = plan.digest });
    try result.fact(.expected_revision, .owner, .{ .unsigned = .init(proposal.expected.value) });
    try result.fact(.required, .owner, .{ .unsigned = .init(proposal.next.value) });
    try result.fact(.expected_schema, .owner, .{ .digest = proposal.source });
    try result.fact(.proposal, .owner, .{ .digest = proposal.target });
    try result.fact(.step, .owner, .{ .unsigned = .init(state.next.value) });
    try result.text(.operation, .owner, @tagName(state.phase));
    // Generic migration cannot select application transform arguments, prove
    // external cancellation, or silently authorize the next ordinal.
    try result.action(.inspect_status);
    try result.validate();
    return result;
}

test "migration progress preserves reviewed plan and does not invent continuation arguments" {
    const t = std.testing;
    const plan: root.Migration.Plan = .{ .proposal = .{ .plan = .{ .value = std.math.maxInt(u64) }, .expected = .{ .value = 1 }, .next = .{ .value = 2 }, .source = @splat(1), .target = @splat(2), .transform = 1 }, .digest = @splat(3), .principal = 9, .input = 11 };
    inline for (.{ .{ root.Migration.Phase.active, d.Outcome.pending }, .{ root.Migration.Phase.applied, d.Outcome.applied }, .{ root.Migration.Phase.abandoned, d.Outcome.cancelled } }) |case| {
        const detail = try progress(9, 1, 7, plan, .{ .phase = case[0], .next = .{ .value = 2 }, .input = 12, .cursor = try p.Value.init("application cursor") });
        try t.expectEqual(case[1], detail.outcome);
        try t.expectEqual(std.math.maxInt(u64), try detail.identity.?.id.value());
        try t.expectEqual(.inspect_status, detail.actions[0].?.kind);
        try t.expectEqualDeep(detail.identity, detail.actions[0].?.target);
        try t.expectEqual(null, detail.actions[1]);
    }
    try t.expectError(error.InvalidMigrationRecord, progress(9, 1, 7, plan, .{ .input = 10 }));
    try t.expectError(error.InvalidMigrationRecord, progress(9, 1, 7, plan, .{ .input = 12, .phase = .applied }));
    try t.expectError(error.InvalidMigrationRecord, progress(9, 1, 7, plan, .{ .input = 12, .next = .{ .value = 0 } }));
    try t.expectError(error.InvalidMigrationRecord, progress(9, 1, 7, plan, .{ .input = 12, .next = .{ .value = 2 }, .cursor = try p.Value.init(&@as([129]u8, @splat(0))) }));
}
