const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const b = p.Branch;
const d = p.DataLifecycle;
const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 5 };
const operation: d.Operation = .{ .scope = scope, .principal = 7, .operation = 11 };

fn reference(branch: u64, version: u64) b.Reference {
    return .{ .identity = .{ .scope = scope, .branch = branch }, .version = version, .content = .{ .bytes = 256, .sha256 = @splat(@intCast(branch)) } };
}
fn manifest() b.Manifest {
    return .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = scope, .branch = 2 },
        .version = 1,
        .kind = .fork,
        .mode = .full_data,
        .catalog = .{ .partition = 13, .next_lsn = 17 },
        .objects = .{ .content = .{ .bytes = 512, .sha256 = @splat(3) }, .objects = 10000 },
        .retention_owner = operation,
        .parent = reference(1, 99),
        .merge_parent = null,
        .restored_from = null,
    };
}
fn attempt() b.Attempt {
    return .{
        .definition = p.Growth.current_definition,
        .operation = operation,
        .request = @splat(9),
        .intent = .{ .merge = .{ .base = reference(1, 99), .source = reference(2, 4), .target = .{ .reference = reference(1, 101), .generation = 103 } } },
        .limits = .{ .resident_bytes = 4096, .staged_bytes = 1024 * 1024, .objects = 10000, .work = 100000 },
    };
}

test "branch manifest distinguishes fork ancestry from a forward local successor" {
    var value = manifest();
    try value.validate(); // Source version 99 is not in the new branch's clock.
    value.parent.?.identity.branch = 2;
    try t.expectError(error.InvalidBranchAncestry, value.validate());
    value = manifest();
    value.kind = .restore;
    value.version = 8;
    value.parent = reference(2, 7);
    value.restored_from = reference(2, 3);
    try value.validate();
    value.parent.?.version = 6;
    try t.expectError(error.InvalidBranchAncestry, value.validate());
    value.parent.?.version = 7;
    value.restored_from.?.version = 8;
    try t.expectError(error.InvalidBranchAncestry, value.validate());
    value.restored_from = reference(1, 1000);
    try value.validate();
    value.retention_owner.scope.catalog += 1;
    try t.expectError(error.BranchIdentityConflict, value.validate());
}

test "branch manifest rejects absent and foreign contract identity" {
    const encoded = try std.json.Stringify.valueAlloc(t.allocator, manifest(), .{});
    defer t.allocator.free(encoded);
    const parsed = try std.json.parseFromSlice(b.Manifest, t.allocator, encoded, .{});
    defer parsed.deinit();
    try parsed.value.validate();
    try t.expectEqualDeep(manifest(), parsed.value);
    const boundary = std.mem.indexOfScalar(u8, encoded, ',').?;
    const missing = try std.mem.concat(t.allocator, u8, &.{ "{", encoded[boundary + 1 ..] });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, std.json.parseFromSlice(b.Manifest, t.allocator, missing, .{}));
    const foreign = try t.allocator.dupe(u8, encoded);
    defer t.allocator.free(foreign);
    const start = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    foreign[start] = if (foreign[start] == '0') '1' else '0';
    try t.expectError(error.InvalidEnumTag, std.json.parseFromSlice(b.Manifest, t.allocator, foreign, .{}));
}

test "branch retry binds source target generation options and original operation" {
    const original = attempt();
    try original.validate();
    try original.requireSame(original);
    var changed = original;
    changed.intent.merge.target.generation += 1;
    try t.expectError(error.BranchIdentityConflict, original.requireSame(changed));
    changed = original;
    changed.intent.merge.source.content.sha256[0] ^= 1;
    try t.expectError(error.BranchIdentityConflict, original.requireSame(changed));
    changed = original;
    changed.limits.work += 1;
    try t.expectError(error.BranchIdentityConflict, original.requireSame(changed));
    changed = original;
    changed.operation.operation += 1;
    try t.expectError(error.BranchIdentityConflict, original.requireSame(changed));
    changed.intent.merge.source.identity.scope.realm += 1;
    try t.expectError(error.BranchIdentityConflict, changed.validate());
    changed = original;
    changed.intent.merge.base.version = 102;
    try t.expectError(error.InvalidBranchAncestry, changed.validate());
}

test "branch validation requires complete candidate coverage and resolved conflicts" {
    const content: d.Content = .{ .bytes = 512, .sha256 = @splat(8) };
    var value: b.Validation = .{ .attempt = attempt(), .candidate = content, .checked_objects = 0, .conflicts = 0, .complete = false };
    try t.expectError(error.IncompleteBranchValidation, value.requirePublishable(content, 0));
    value.complete = true;
    try t.expectError(error.IncompleteBranchValidation, value.requirePublishable(content, 10000));
    value.checked_objects = 10000;
    try value.requirePublishable(content, 10000);
    value.conflicts = 1;
    try t.expectError(error.UnresolvedBranchConflicts, value.requirePublishable(content, 10000));
    var changed = content;
    changed.sha256[0] ^= 1;
    try t.expectError(error.BranchIdentityConflict, value.requirePublishable(changed, 10000));
}

test "branch decision advances data and generation without rewinding publication authority" {
    var value: b.Decision = .{
        .attempt = attempt(),
        .position = .{ .partition = 13, .next_lsn = 18 },
        .writer_epoch = 2,
        .policy_epoch = 9,
        .outcome = .{ .published = .{ .reference = reference(1, 102), .generation = 104 } },
    };
    try value.validate();
    value.outcome.published.generation = 103;
    try t.expectError(error.InvalidBranchDecision, value.validate());
    value.outcome.published.generation = 104;
    value.outcome.published.reference.version = 101;
    try t.expectError(error.InvalidBranchDecision, value.validate());
    value.outcome = .dropped;
    try t.expectError(error.InvalidBranchDecision, value.validate());
    value.outcome = .cancelled;
    try value.validate();
    value.policy_epoch = 0;
    try t.expectError(error.InvalidBranchDecision, value.validate());
}
