//! Evidence retained at a rejected migration input, independent of step receipts.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;
const Wide = root.Model.Wide;
pub const Record = struct { cause: p.Value, input: u64, plan: Wide, ordinal: Wide, operation: u16, payload: [32]u8 };
pub const Witness = union(enum(u8)) {
    none = 0,
    policy: struct { principal: u64, expected: Wide, actual: Wide, present: bool, migrate: bool } = 1,
    head: struct { expected: Wide, actual: Wide, source: [32]u8, observed: [32]u8, target: [32]u8, active: Wide } = 2,
    plan: struct { expected: [32]u8, actual: [32]u8, owner: u64, caller: u64 } = 3,
    step: struct { expected: [32]u8, actual: [32]u8 } = 4,
    progress: struct { next: Wide, supplied: Wide, phase: root.Migration.Phase, active: Wide, active_known: bool } = 5,
    owner: struct { principal: u64, caller: u64 } = 6,
};
pub const Class = struct { code: []const u8, category: d.Category, stage: d.Stage = .admission, message: []const u8 };
pub fn classification(cause: []const u8) ?Class {
    const Mapping = struct { name: []const u8, value: Class };
    const mappings = [_]Mapping{
        .{ .name = "MigrationDenied", .value = .{ .code = "migration.denied", .category = .access, .message = "This input lacked current migration permission or ownership of the selected plan. It did not advance a step or abandon a plan. Inspect the original policy and plan before continuing under restored rights." } },
        .{ .name = "MigrationPolicyConflict", .value = .{ .code = "migration.policy_conflict", .category = .conflict, .stage = .control, .message = "The migration policy revision differed from the expected revision. This input did not replace it. Compare the recorded revisions before reviewing another policy update." } },
        .{ .name = "InvalidMigrationPolicy", .value = .{ .code = "migration.invalid_policy", .category = .binding, .stage = .input, .message = "A migration policy needs a nonzero native principal and a next revision exactly one greater than the expected uint64 revision, without overflow. This input did not change policy." } },
        .{ .name = "InvalidMigrationProposal", .value = .{ .code = "migration.invalid_proposal", .category = .binding, .stage = .input, .message = "A migration proposal needs nonzero plan and source epoch identities, next epoch exactly source plus one without overflow, and a supported nonzero transform. This input did not begin a plan." } },
        .{ .name = "InvalidMigrationStep", .value = .{ .code = "migration.invalid_step", .category = .binding, .stage = .input, .message = "A migration step needs the selected plan identity, a nonzero ordinal and operation, and at most 128 argument bytes. This input did not apply a step. Inspect the exact plan and original step arguments." } },
        .{ .name = "MigrationPlanConflict", .value = .{ .code = "migration.plan_conflict", .category = .conflict, .message = "This plan identity already belongs to a different reviewed proposal or operator. This input did not replace it. Inspect the original plan and compare its commitment and owner with this request." } },
        .{ .name = "MigrationBusy", .value = .{ .code = "migration.active_plan", .category = .conflict, .message = "Another migration plan is active for this data owner. This input did not replace it or release its write pause. Inspect the recorded active plan before requesting another migration." } },
        .{ .name = "MigrationSourceChanged", .value = .{ .code = "migration.source_changed", .category = .conflict, .message = "The data epoch or source contract differs from the reviewed migration proposal. This input did not advance the migration. Compare the original expected and observed basis; retain existing plan and step receipts." } },
        .{ .name = "MigrationPlanAbsent", .value = .{ .code = "migration.plan_absent", .category = .lifecycle, .message = "The owner found no plan for this input's selected identity. This input did not apply a step or create a plan. Check the exact reviewed plan identity and its admission receipt." } },
        .{ .name = "MigrationStepConflict", .value = .{ .code = "migration.step_conflict", .category = .conflict, .message = "This step has a different commitment at an already completed ordinal, or its ordinal differs from the next required step. This input did not advance the plan. Compare the recorded commitments or ordinals and inspect the exact original receipt." } },
        .{ .name = "MigrationNotActive", .value = .{ .code = "migration.not_active", .category = .lifecycle, .message = "The selected plan is no longer the owner's active migration. This input did not advance or abandon it. Inspect its retained phase and the active plan; a rejected input cannot undo earlier committed steps." } },
        .{ .name = "MigrationOrdinalExhausted", .value = .{ .code = "migration.ordinal_exhausted", .category = .limit, .stage = .execute, .message = "The migration has reached the maximum uint64 step ordinal and cannot record a successor. This input did not run its transform or change progress. Retain the plan and consult its application owner; a new identity cannot safely skip this limit." } },
        .{ .name = "MigrationAlreadyApplied", .value = .{ .code = "migration.already_applied", .category = .lifecycle, .stage = .cleanup, .message = "The migration already activated its target epoch. This abandonment input was rejected. Activation cannot be rolled back by abandonment; retain its original plan and step receipts." } },
    };
    for (mappings) |mapping| if (std.mem.eql(u8, cause, mapping.name)) return mapping.value;
    return null;
}
pub fn expected(cause: anyerror) bool {
    return classification(@errorName(cause)) != null;
}
pub fn capture(turn: *const root.station.Turn, cause: []const u8, plan: Wide, ordinal: Wide, operation: u16) !Record {
    if (cause.len == 0 or cause.len > 96) return error.InvalidMigrationFailure;
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.application.migration.input.v1\x00");
    digest.update(turn.delivery.input.value.slice());
    return .{ .cause = try p.Value.init(cause), .input = turn.delivery.input.position, .plan = plan, .ordinal = ordinal, .operation = operation, .payload = digest.finalResult() };
}
/// Applications supply their own finite classification for domain rejections.
/// This projection uses only the original retained evidence, after authorized read.
pub fn project(application: u64, realm: u64, resource: u64, value: Record, witness: Witness, info: Class) !d {
    if (application == 0 or application > p.max_counter or value.input == 0 or value.input > p.max_counter or value.cause.len == 0 or value.cause.len > 96 or (value.ordinal.value != 0 and value.plan.value == 0)) return error.InvalidMigrationFailure;
    var result = try d.init(info.code, info.category, info.stage, .input_rejected, .domain_status, info.message);
    result.cause = try d.Code.init(value.cause.slice());
    result.identity = .{ .domain = if (value.plan.value == 0) .application else .migration, .id = .init(if (value.plan.value == 0) application else value.plan.value), .realm = .init(realm), .resource = .init(resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.source_basis, .owner, .{ .digest = value.payload });
    if (value.ordinal.value != 0) {
        try result.fact(.step, .owner, .{ .unsigned = .init(value.ordinal.value) });
        try result.fact(.operation, .owner, .{ .unsigned = .init(value.operation) });
    }
    switch (witness) {
        .none => {},
        .policy => |policy| {
            if (policy.principal == 0 or policy.principal > p.max_counter or (policy.present and policy.actual.value == 0) or (!policy.present and (policy.actual.value != 0 or policy.migrate))) return error.InvalidMigrationFailure;
            try result.fact(.scope, .owner, .{ .unsigned = .init(policy.principal) });
            if (std.mem.eql(u8, value.cause.slice(), "MigrationPolicyConflict")) try result.fact(.expected_policy, .owner, .{ .unsigned = .init(policy.expected.value) }) else try result.absent(.expected_policy, .owner, .inapplicable);
            try result.fact(.actual_policy, .owner, .{ .unsigned = .init(policy.actual.value) });
            try result.fact(.permissions, .owner, .{ .boolean = policy.migrate });
            try result.fact(.object, .owner, .{ .boolean = policy.present });
        },
        .head => |head| {
            if (head.expected.value == 0 or head.actual.value == 0) return error.InvalidMigrationFailure;
            try result.text(.schema_origin, .owner, "migration data epoch and complete source/target contracts");
            try result.fact(.expected_revision, .owner, .{ .unsigned = .init(head.expected.value) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(head.actual.value) });
            try result.fact(.expected_schema, .owner, .{ .digest = head.source });
            try result.fact(.actual_schema, .owner, .{ .digest = head.observed });
            try result.fact(.proposal, .owner, .{ .digest = head.target });
            try result.fact(.object, .owner, .{ .unsigned = .init(head.active.value) });
        },
        .plan => |plan| {
            if (plan.owner == 0 or plan.owner > p.max_counter or plan.caller == 0 or plan.caller > p.max_counter) return error.InvalidMigrationFailure;
            try result.text(.schema_origin, .owner, "original and submitted migration plan commitments");
            try result.fact(.expected_schema, .owner, .{ .digest = plan.expected });
            try result.fact(.actual_schema, .owner, .{ .digest = plan.actual });
            try result.fact(.object, .owner, .{ .unsigned = .init(plan.owner) });
            try result.fact(.scope, .owner, .{ .unsigned = .init(plan.caller) });
        },
        .step => |step| {
            try result.text(.schema_origin, .owner, "original and submitted migration step commitments");
            try result.fact(.expected_schema, .owner, .{ .digest = step.expected });
            try result.fact(.actual_schema, .owner, .{ .digest = step.actual });
        },
        .owner => |owner| {
            if (owner.principal == 0 or owner.principal > p.max_counter or owner.caller == 0 or owner.caller > p.max_counter) return error.InvalidMigrationFailure;
            try result.fact(.object, .owner, .{ .unsigned = .init(owner.principal) });
            try result.fact(.scope, .owner, .{ .unsigned = .init(owner.caller) });
        },
        .progress => |progress| {
            if (progress.next.value == 0) return error.InvalidMigrationFailure;
            try result.text(.object, .owner, @tagName(progress.phase));
            try result.text(.unit, .owner, "migration step ordinal");
            try result.fact(.expected_count, .owner, .{ .unsigned = .init(progress.next.value) });
            if (progress.supplied.value != 0) try result.fact(.actual_count, .owner, .{ .unsigned = .init(progress.supplied.value) }) else try result.absent(.actual_count, .owner, .inapplicable);
            if (progress.active_known) try result.fact(.proposal, .owner, .{ .unsigned = .init(progress.active.value) }) else try result.absent(.proposal, .owner, .unrecorded);
        },
    }
    try result.action(.inspect_status);
    if (info.category == .access) try result.action(.inspect_scope);
    try result.validate();
    return result;
}
