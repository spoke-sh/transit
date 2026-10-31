const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const b = p.Branch;
const A = s.BranchAncestry;
const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
const limits: A.Limits = .{ .visits = 10000, .staged_bytes = 64 * 1024 * 1024, .step_bytes = 1024 * 1024, .resident_pages = 1 };

fn manifest(objects: s.TransitObjectStore.ObjectStore, branch: u64, version: u64, kind: b.Kind, parent: ?b.Reference, merged: ?b.Reference, restored: ?b.Reference) !b.Reference {
    const identity: b.Identity = .{ .scope = scope, .branch = branch };
    const owner: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 4, .operation = branch * 10000 + version };
    var directory = try s.BranchSnapshot.init(t.allocator, objects, identity, owner, 1000, 0, 1024 * 1024);
    defer directory.deinit();
    return directory.stageManifest(.{
        .definition = p.Growth.current_definition,
        .identity = identity,
        .version = version,
        .kind = kind,
        .mode = .full_data,
        .catalog = .{ .partition = 17, .next_lsn = version },
        .objects = try directory.commitment(),
        .retention_owner = owner,
        .parent = parent,
        .merge_parent = merged,
        .restored_from = restored,
    });
}

fn resolve(objects: s.TransitObjectStore.ObjectStore, left: b.Reference, right: b.Reference) !A.Resolution {
    var ancestry = try A.init(t.allocator, objects, left, right, limits);
    defer ancestry.deinit();
    try t.expectError(error.IncompleteBranchAncestry, ancestry.result());
    var steps: usize = 0;
    while (!try ancestry.step()) : (steps += 1) try t.expect(steps < 10000);
    const result = try ancestry.result();
    const visits = ancestry.visits;
    try t.expect(try ancestry.step());
    try t.expectEqual(visits, ancestry.visits);
    return result;
}

test "branch ancestry resolves deep disk history beyond cache and branch-local clocks" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var base: b.Reference = undefined;
    var left: b.Reference = undefined;
    var right: b.Reference = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var tip = try manifest(objects.objectStore(), 1, 1, .genesis, null, null, null);
        for (2..271) |version| {
            tip = try manifest(objects.objectStore(), 1, version, .commit, tip, null, null);
            if (version == 260) base = tip;
        }
        left = tip;
        right = try manifest(objects.objectStore(), 2, 1, .fork, base, null, null);
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    try t.expectEqualDeep(A.Resolution{ .unique = base }, try resolve(objects.objectStore(), left, right));
}

test "branch ancestry detects criss-cross bases and ignores restore provenance as ancestry" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const store = objects.objectStore();
    const genesis = try manifest(store, 1, 1, .genesis, null, null, null);
    const a1 = try manifest(store, 2, 1, .fork, genesis, null, null);
    const b1 = try manifest(store, 3, 1, .fork, genesis, null, null);
    const a2 = try manifest(store, 2, 2, .merge, a1, b1, null);
    const b2 = try manifest(store, 3, 2, .merge, b1, a1, null);
    try t.expectEqualDeep(A.Resolution{ .unique = a2 }, try resolve(store, a2, a2));
    try t.expectEqual(A.Resolution.ambiguous, try resolve(store, a2, b2));
    try t.expectEqualDeep(A.Resolution{ .unique = a1 }, try resolve(store, a2, a1));
    const unrelated = try manifest(store, 4, 1, .genesis, null, null, null);
    const restored = try manifest(store, 2, 3, .restore, a2, null, unrelated);
    try t.expectEqual(A.Resolution.unrelated, try resolve(store, restored, unrelated));
    try t.expectEqualDeep(A.Resolution{ .unique = a2 }, try resolve(store, restored, a2));
}

test "branch ancestry missing content and budgets cannot manufacture a complete base" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const store = objects.objectStore();
    const genesis = try manifest(store, 1, 1, .genesis, null, null, null);
    var missing = genesis;
    missing.content.sha256[0] ^= 1;
    const fork = try manifest(store, 2, 1, .fork, missing, null, null);
    var ancestry = try A.init(t.allocator, store, fork, genesis, limits);
    defer ancestry.deinit();
    try t.expect(!try ancestry.step());
    const before = ancestry.state;
    try t.expectError(error.BranchArtifactMissing, ancestry.step());
    try t.expectEqualDeep(before, ancestry.state);
    try t.expectError(error.IncompleteBranchAncestry, ancestry.result());

    var bounded_limits = limits;
    bounded_limits.visits = 1;
    var bounded = try A.init(t.allocator, store, genesis, genesis, bounded_limits);
    defer bounded.deinit();
    try t.expect(!try bounded.step());
    try t.expect(!try bounded.step());
    try t.expectError(error.BranchAncestryWorkLimit, bounded.step());
    try t.expectError(error.IncompleteBranchAncestry, bounded.result());

    bounded_limits = limits;
    bounded_limits.staged_bytes = 1;
    try t.expectError(error.StorageCandidateTooLarge, A.init(t.allocator, store, genesis, genesis, bounded_limits));
}

test "branch ancestry rejects conflicting contents for one branch version" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const store = objects.objectStore();
    const genesis = try manifest(store, 1, 1, .genesis, null, null, null);
    const original = try manifest(store, 2, 1, .fork, genesis, null, null);
    const other_parent = try manifest(store, 1, 2, .commit, genesis, null, null);
    const changed = try manifest(store, 2, 1, .fork, other_parent, null, null);
    try t.expectError(error.BranchIdentityConflict, resolve(store, original, changed));
}

test "branch ancestry matches independent transitive-closure oracle" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const store = objects.objectStore();
    // This oracle materializes the complete relation in bitsets. Production
    // walks paged frontiers and excludes dominated direct parents instead.
    const parents = [_][2]?usize{
        .{ null, null }, .{ 0, null }, .{ 0, null }, .{ 1, 2 }, .{ 2, 1 },
        .{ 3, null },    .{ 4, 5 },    .{ 5, 4 },    .{ 6, 7 }, .{ 7, 6 },
    };
    const branches = [_]u64{ 1, 2, 3, 2, 3, 2, 3, 2, 3, 2 };
    const versions = [_]u64{ 1, 1, 1, 2, 2, 3, 3, 4, 4, 5 };
    var refs: [parents.len]b.Reference = undefined;
    var closure: [parents.len]u16 = undefined;
    for (parents, 0..) |edges, i| {
        closure[i] = @as(u16, 1) << @intCast(i);
        for (edges) |edge| if (edge) |at| {
            closure[i] |= closure[at];
        };
        const first = if (edges[0]) |at| refs[at] else null;
        const second = if (edges[1]) |at| refs[at] else null;
        const kind: b.Kind = if (first == null) .genesis else if (versions[i] == 1) .fork else if (second != null) .merge else .commit;
        refs[i] = try manifest(store, branches[i], versions[i], kind, first, second, null);
    }
    for (refs, 0..) |left, i| for (refs[0 .. i + 1], 0..) |right, j| {
        const common = closure[i] & closure[j];
        var maximal = common;
        for (closure, 0..) |ancestors, k| {
            const bit = @as(u16, 1) << @intCast(k);
            if (common & bit != 0) maximal &= ~(ancestors & ~bit);
        }
        const expected: A.Resolution = switch (@popCount(maximal)) {
            0 => .unrelated,
            1 => .{ .unique = refs[@ctz(maximal)] },
            else => .ambiguous,
        };
        try t.expectEqualDeep(expected, try resolve(store, left, right));
    };
}
