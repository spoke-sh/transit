const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const d = p.DataLifecycle;

const scope: d.Scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) };
const object: d.Object = .{ .scope = scope, .branch = 1, .object = 42 };
const interpretation: d.Definition = .{ .object = object, .revision = 3, .digest = @splat(23) };
const binding: d.Binding = .{
    .definition = p.Growth.current_definition,
    .identity = .{ .scope = scope, .principal = 0, .operation = std.math.maxInt(u64) },
    .target = object,
    .action = .insert,
    .expected_definition = interpretation,
    .expected_data = .{ .partition = 8, .next_lsn = 11 },
    .intent = @splat(61),
};
const commit: d.Commit = .{
    .binding = binding,
    .position = .{ .partition = 8, .next_lsn = 12 },
    .resulting_definition = interpretation,
    .result = .{ .bytes = 64, .sha256 = @splat(78) },
    .ingestion = .point,
};
const cut: d.SourceCut = .{
    .interpretation = interpretation,
    .manifest = .{ .bytes = 256, .sha256 = @splat(9) },
    .checkpoint_lsn = 8,
    .accepted = .{ .partition = 8, .next_lsn = 12 },
};
const snapshot: d.Snapshot = .{
    .definition = p.Growth.current_definition,
    .owner = .{ .scope = scope, .principal = 17, .operation = 101 },
    .branch = 1,
    .catalog_root = .{ .bytes = 1024, .sha256 = @splat(14) },
    .sources_root = .{ .bytes = 8192, .sha256 = @splat(15) },
    .source_count = 10_003,
    .consistency = .{ .single_partition = .{ .partition = 8, .next_lsn = 12 } },
};

test "a lost reply binds the original accepted operation despite later name or schema replacement" {
    try commit.requireBinding(binding);
    var replacement = binding;
    replacement.target.object += 1;
    replacement.expected_definition.?.object = replacement.target;
    try t.expectError(error.DataIdentityConflict, commit.requireBinding(replacement));
    replacement = binding;
    replacement.expected_definition.?.revision += 1;
    try t.expectError(error.DataIdentityConflict, commit.requireBinding(replacement));
    replacement = binding;
    replacement.intent[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, commit.requireBinding(replacement));
    replacement = binding;
    replacement.target.branch += 1;
    replacement.expected_definition.?.object.branch += 1;
    try t.expectError(error.DataIdentityConflict, commit.requireBinding(replacement));
    replacement = binding;
    replacement.identity.principal += 1;
    try t.expectError(error.DataIdentityConflict, commit.requireBinding(replacement));
}

test "point and bulk commits require the same identity and advancing accepted frontier" {
    var bulk = commit;
    bulk.ingestion = .bulk;
    try bulk.requireBinding(binding);
    bulk.position.next_lsn = 11;
    try t.expectError(error.InvalidDataPosition, bulk.validate());
    bulk = commit;
    bulk.position.partition = 9;
    try t.expectError(error.InvalidDataPosition, bulk.validate());
    bulk = commit;
    bulk.resulting_definition.revision += 1;
    try t.expectError(error.InvalidDataDefinition, bulk.validate());
    bulk = commit;
    bulk.binding.action = .alter;
    try t.expectError(error.InvalidDataDefinition, bulk.validate());
    bulk.resulting_definition.revision += 1;
    try bulk.validate();
}

test "saved acceptance prerequisites cannot be removed or rebound on retry" {
    var conditioned = binding;
    conditioned.prerequisite = .{ .subject = .{ .accepted = .{ .pid = 9, .input = 10, .principal = 11 } }, .requirements = @splat(null) };
    conditioned.prerequisite.?.requirements[0] = .{ .object = .{ .kind = .resource, .id = 7 }, .privileges = p.State.permission(.read) };
    try conditioned.validate();
    const bytes = try p.Json.valueAlloc(t.allocator, conditioned);
    defer t.allocator.free(bytes);
    const saved = try p.Json.parseFromSlice(d.Binding, t.allocator, bytes);
    defer saved.deinit();
    try conditioned.requireSame(saved.value);
    try t.expectError(error.DataIdentityConflict, conditioned.requireSame(binding));
    var changed = conditioned;
    changed.prerequisite.?.subject.accepted.input += 1;
    try t.expectError(error.DataIdentityConflict, conditioned.requireSame(changed));
    changed = conditioned;
    changed.prerequisite.?.requirements[0].?.privileges = p.State.permission(.write);
    try t.expectError(error.DataIdentityConflict, conditioned.requireSame(changed));
    changed = conditioned;
    changed.prerequisite.?.requirements[0] = null;
    try t.expectError(error.InvalidAuthorizationPrivilege, changed.validate());
}

test "snapshots preserve accepted unflushed rows and reject incomplete checkpoint coverage" {
    try snapshot.requireSource(cut);
    try t.expect(try cut.needsWal());
    var flushed = cut;
    flushed.checkpoint_lsn = flushed.accepted.next_lsn;
    try snapshot.requireSource(flushed);
    try t.expect(!try flushed.needsWal());
    flushed.checkpoint_lsn += 1;
    try t.expectError(error.InvalidSnapshotCoverage, flushed.validate());
    var wal_only = cut;
    wal_only.manifest = null;
    try t.expectError(error.InvalidSnapshotCoverage, wal_only.validate());
    wal_only.checkpoint_lsn = 0;
    try snapshot.requireSource(wal_only);
    try t.expect(try wal_only.needsWal());
}

test "independent source versions cannot be labelled a consistent single-partition cut" {
    var other = cut;
    other.accepted.next_lsn += 1;
    try t.expectError(error.InconsistentSnapshot, snapshot.requireSource(other));
    other = cut;
    other.accepted.partition += 1;
    try t.expectError(error.InconsistentSnapshot, snapshot.requireSource(other));
    var independent = snapshot;
    independent.consistency = .independent;
    try independent.requireSource(other);
    other.interpretation.object.branch += 1;
    try t.expectError(error.DataIdentityConflict, independent.requireSource(other));
}

test "lifecycle JSON requires an exact definition and preserves full-width identities" {
    const encoded = try p.Json.valueAlloc(t.allocator, binding);
    defer t.allocator.free(encoded);
    const parsed = try p.Json.parseFromSlice(d.Binding, t.allocator, encoded);
    defer parsed.deinit();
    try parsed.value.requireSame(binding);
    const first_comma = std.mem.indexOfScalar(u8, encoded, ',').?;
    const missing = try std.fmt.allocPrint(t.allocator, "{{{s}", .{encoded[first_comma + 1 ..]});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(d.Binding, t.allocator, missing));
    const foreign = try t.allocator.dupe(u8, encoded);
    defer t.allocator.free(foreign);
    const identifier = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    foreign[identifier] = if (foreign[identifier] == '0') '1' else '0';
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(d.Binding, t.allocator, foreign));
    const unknown: d.Observation = .unavailable;
    const absent: d.Observation = .not_observed;
    try unknown.validate();
    try absent.validate();
    try t.expect(std.meta.activeTag(unknown) != std.meta.activeTag(absent));
}

test "independent lifecycle fixture binds the accepted write and its unflushed snapshot" {
    const parsed = try p.Json.parseFromSlice(d.SchemaTypes, t.allocator, @embedFile("fixtures/data-lifecycle-v1.json"));
    defer parsed.deinit();
    try t.expectEqualDeep(binding, parsed.value.binding);
    try t.expectEqualDeep(commit, parsed.value.commit);
    try t.expectEqualDeep(cut, parsed.value.source_cut);
    try parsed.value.commit.requireBinding(parsed.value.binding);
    try parsed.value.snapshot.requireSource(parsed.value.source_cut);
    try t.expect(try parsed.value.source_cut.needsWal());
    try t.expectEqual(.not_observed, std.meta.activeTag(parsed.value.observation));
}
