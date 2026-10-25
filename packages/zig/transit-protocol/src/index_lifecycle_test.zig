const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const d = p.DataLifecycle;
const i = p.IndexLifecycle;

fn fixture() !std.json.Parsed(i.SchemaTypes) {
    return p.Json.parseFromSlice(i.SchemaTypes, t.allocator, @embedFile("fixtures/index-lifecycle-v1.json"));
}
fn snapshot(source: d.SourceCut) d.Snapshot {
    return .{
        .definition = p.Growth.current_definition,
        .owner = .{ .scope = source.interpretation.object.scope, .principal = 0, .operation = 999 },
        .branch = source.interpretation.object.branch,
        .catalog_root = .{ .bytes = 256, .sha256 = @splat(5) },
        .sources_root = .{ .bytes = 8192, .sha256 = @splat(6) },
        .source_count = 10_003,
        .consistency = .independent,
    };
}

test "independent index commitments preserve full-width identities and WAL-inclusive coverage" {
    const parsed = try fixture();
    defer parsed.deinit();
    const f = parsed.value;
    try f.declaration.validate();
    try f.constraint_declaration.validate();
    try f.progress.validate();
    try f.publication.validate();
    try f.coverage.requireBasis(f.declaration, snapshot(f.coverage.source), f.coverage.source);
    try t.expectEqual(std.math.maxInt(u64), f.coverage.build.generation);
    try t.expectEqual(std.math.maxInt(u64), f.declaration.source.object.scope.catalog);
    try t.expect(try f.coverage.source.needsWal());
    try t.expect(try f.coverage.build.base.needsWal());
    try t.expect(!std.mem.eql(u8, &f.declaration.interpretation.digest, &f.constraint_declaration.interpretation.digest));
}

test "key semantics source interpretation includes and constraint ownership are immutable" {
    const parsed = try fixture();
    defer parsed.deinit();
    const original = parsed.value.declaration;
    var changed = original;
    var keys = [_]i.Key{ original.keys[0], original.keys[1] };
    changed.keys = &keys;
    keys[0].direction = .descending;
    try t.expectError(error.IndexDefinitionMismatch, changed.validate());
    keys[0] = original.keys[0];
    keys[0].nulls = .first;
    try t.expectError(error.IndexDefinitionMismatch, changed.validate());
    keys = .{ original.keys[1], original.keys[0] };
    try t.expectError(error.IndexDefinitionMismatch, changed.validate());
    changed = original;
    changed.included = &.{24};
    try t.expectError(error.IndexDefinitionMismatch, changed.validate());
    changed = original;
    changed.source.digest[0] ^= 1;
    try t.expectError(error.IndexDefinitionMismatch, changed.validate());
    changed = original;
    changed.purpose = parsed.value.constraint_declaration.purpose;
    try t.expectError(error.IndexDefinitionMismatch, changed.validate());
    changed = parsed.value.constraint_declaration;
    changed.purpose.constraint.nulls = .equal;
    try t.expectError(error.IndexDefinitionMismatch, changed.validate());
}

test "index declarations reject cross-branch and self dependencies and ambiguous columns" {
    const parsed = try fixture();
    defer parsed.deinit();
    const original = parsed.value.declaration;
    var changed = original;
    changed.source.object.branch += 1;
    try t.expectError(error.InvalidIndexDependency, changed.validate());
    changed = original;
    changed.source.object.scope.resource += 1;
    try t.expectError(error.InvalidIndexDependency, changed.validate());
    changed = original;
    changed.source.object = changed.interpretation.object;
    try t.expectError(error.InvalidIndexDependency, changed.validate());
    changed = parsed.value.constraint_declaration;
    changed.purpose.constraint.interpretation.object = changed.source.object;
    try t.expectError(error.InvalidIndexDependency, changed.validate());
    changed = parsed.value.constraint_declaration;
    changed.purpose.constraint.kind = .primary_key;
    try t.expectError(error.InvalidIndexConstraint, changed.validate());
    changed.purpose.constraint.nulls = .forbidden;
    changed.interpretation.digest = try changed.fingerprint();
    try changed.validate();
    changed = original;
    changed.keys = &.{};
    try t.expectError(error.InvalidIndexColumns, changed.validate());
    changed = original;
    changed.keys = &.{ original.keys[0], original.keys[0] };
    try t.expectError(error.InvalidIndexColumns, changed.validate());
    changed = original;
    changed.included = &.{original.keys[0].column};
    try t.expectError(error.InvalidIndexColumns, changed.validate());
    changed.included = &.{ 23, 23 };
    try t.expectError(error.InvalidIndexColumns, changed.validate());
    changed.included = &.{0};
    try t.expectError(error.InvalidIndexColumns, changed.validate());
    const excessive: [i.max_columns + 1]i.Key = @splat(original.keys[0]);
    changed = original;
    changed.keys = &excessive;
    try t.expectError(error.InvalidIndexColumns, changed.validate());
    var columns: [i.max_columns - 1]u64 = undefined;
    for (&columns, 0..) |*column, n| column.* = @as(u64, @intCast(n)) + 100;
    changed = original;
    changed.keys = original.keys[0..1];
    changed.included = &columns;
    changed.interpretation.digest = try changed.fingerprint();
    try changed.validate();
    changed.keys = original.keys;
    try t.expectError(error.InvalidIndexColumns, changed.validate());
}

test "coverage matches exactly one logical source cut rather than a high-water mark" {
    const parsed = try fixture();
    defer parsed.deinit();
    const f = parsed.value;
    const snap = snapshot(f.coverage.source);
    var requested = f.coverage.source;
    requested.accepted.next_lsn -= 1;
    try t.expectError(error.IndexCoverageMismatch, f.coverage.requireBasis(f.declaration, snap, requested));
    requested = f.coverage.source;
    requested.accepted.next_lsn += 1;
    try t.expectError(error.IndexCoverageMismatch, f.coverage.requireBasis(f.declaration, snap, requested));
    requested = f.coverage.source;
    requested.accepted.partition += 1;
    try t.expectError(error.IndexCoverageMismatch, f.coverage.requireBasis(f.declaration, snap, requested));
    requested = f.coverage.source;
    requested.interpretation.revision += 1;
    try t.expectError(error.IndexCoverageMismatch, f.coverage.requireBasis(f.declaration, snap, requested));
    requested = f.coverage.source;
    requested.interpretation.object.object += 1;
    try t.expectError(error.IndexCoverageMismatch, f.coverage.requireBasis(f.declaration, snap, requested));
    requested = f.coverage.source;
    requested.interpretation.object.branch += 1;
    try t.expectError(error.DataIdentityConflict, f.coverage.requireBasis(f.declaration, snap, requested));
    requested = f.coverage.source;
    requested.manifest = .{ .bytes = 4096, .sha256 = @splat(8) };
    requested.checkpoint_lsn = requested.accepted.next_lsn;
    try f.coverage.requireBasis(f.declaration, snap, requested);
    // A different physical checkpoint at the identical logical cut is valid.
    // Its retention/membership still has to be proved by the source owner.
    var consistent = snap;
    consistent.consistency = .{ .single_partition = requested.accepted };
    try f.coverage.requireBasis(f.declaration, consistent, requested);
    consistent.consistency.single_partition.next_lsn += 1;
    try t.expectError(error.InconsistentSnapshot, f.coverage.requireBasis(f.declaration, consistent, requested));
}

test "build progress cannot drop WAL coverage change generation source or move backwards" {
    const parsed = try fixture();
    defer parsed.deinit();
    const f = parsed.value;
    var coverage = f.coverage;
    coverage.build.generation = 0;
    try t.expectError(error.InvalidIndexGeneration, coverage.validate());
    coverage = f.coverage;
    coverage.build.base.checkpoint_lsn = 1;
    try t.expectError(error.InvalidSnapshotCoverage, coverage.validate());
    coverage = f.coverage;
    coverage.source.accepted.next_lsn = coverage.build.base.accepted.next_lsn - 1;
    try t.expectError(error.InvalidIndexProgress, coverage.validate());
    coverage = f.coverage;
    coverage.source.accepted.partition += 1;
    try t.expectError(error.InvalidIndexProgress, coverage.validate());
    coverage = f.coverage;
    coverage.build.declaration = f.constraint_declaration.interpretation;
    try t.expectError(error.IndexDefinitionMismatch, coverage.requireBasis(f.declaration, snapshot(f.coverage.source), f.coverage.source));
    var progress = f.progress;
    progress.through = null;
    try t.expectError(error.InvalidIndexProgress, progress.validate());
    progress.phase = .backfill;
    try progress.validate();
    progress.through = f.progress.through;
    try t.expectError(error.InvalidIndexProgress, progress.validate());
    progress.phase = .catch_up;
    try progress.validate();
    progress.through.?.next_lsn = progress.build.base.accepted.next_lsn - 1;
    try t.expectError(error.InvalidIndexProgress, progress.validate());
}

test "publication retries preserve original generation root caller and compare-and-publish expectation" {
    const parsed = try fixture();
    defer parsed.deinit();
    const original = parsed.value.publication;
    const bytes = try p.Json.valueAlloc(t.allocator, original);
    defer t.allocator.free(bytes);
    const saved = try p.Json.parseFromSlice(i.Publication, t.allocator, bytes);
    defer saved.deinit();
    try original.requireSame(saved.value);
    var changed = original;
    changed.coverage.root.sha256[0] ^= 1;
    try t.expectError(error.IndexPublicationConflict, original.requireSame(changed));
    changed = original;
    changed.coverage.build.generation -= 1;
    try t.expectError(error.IndexPublicationConflict, original.requireSame(changed));
    changed = original;
    changed.operation.principal += 1;
    try t.expectError(error.IndexPublicationConflict, original.requireSame(changed));
    changed = original;
    changed.expected = null;
    try t.expectError(error.IndexPublicationConflict, original.requireSame(changed));
    const comma = std.mem.indexOfScalar(u8, bytes, ',').?;
    const missing = try std.fmt.allocPrint(t.allocator, "{{{s}", .{bytes[comma + 1 ..]});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(i.Publication, t.allocator, missing));
    const foreign = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(foreign);
    const identifier = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    foreign[identifier] = if (foreign[identifier] == '0') '1' else '0';
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(i.Publication, t.allocator, foreign));
}
