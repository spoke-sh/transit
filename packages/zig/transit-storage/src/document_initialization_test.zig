const std = @import("std");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const t = std.testing;
const s = @import("root.zig");
const I = s.DocumentInitialization;

const Policy = struct {
    calls: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    held: bool = false,
    epoch: u64 = 1,
    fn guard(self: *Policy) s.PublicationGuard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn acquire(context: *anyopaque) !s.PublicationGuard.Fence {
        const self: *Policy = @ptrCast(@alignCast(context));
        t.expect(!self.held) catch unreachable;
        self.calls += 1;
        if (self.calls >= self.deny_at) return error.PermissionDenied;
        self.held = true;
        return .{ .writer_epoch = self.epoch, .policy_epoch = self.epoch };
    }
    fn release(context: *anyopaque) void {
        const self: *Policy = @ptrCast(@alignCast(context));
        t.expect(self.held) catch unreachable;
        self.held = false;
    }
};

const sample_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "doc_key", .type = .utf8, .nullable = false, .collation = .utf8_binary },
};

fn sampleDefinition() s.DocumentDeclaration.Definition {
    return .{
        .object = .{
            .scope = .{ .realm = 1, .resource = 2, .catalog = 3 },
            .branch = 1,
            .object = 502,
        },
        .revision = 1,
        .schema = .{
            .object = 502,
            .revision = 1,
            .next_column = 2,
            .columns = &sample_columns,
        },
        .configuration = .{
            .partitioning = .{ .count = 4, .key_column = 1, .hash = .sha256_64 },
            .profile = .causal_crdt,
            .shredding = .{
                .frequent_path_threshold = 64,
                .max_shredded_columns = 32,
                .default_collation = .utf8_binary,
            },
            .retention = .{ .max_age_ms = null, .merge_window_revisions = null },
        },
        .limits = .{
            .change_bytes = 65_536,
            .operations_per_change = 64,
            .path_depth = 32,
            .read_steps = 4096,
            .read_bytes = 262_144,
            .unresolved_conflicts = 16,
        },
        .properties = "doc-init-props",
    };
}

fn request(stored: s.DocumentDeclaration.Stored) I.Request {
    return .{
        .definition = p.Growth.current_definition,
        .declared = stored,
        .operation = .{
            .scope = stored.declaration.interpretation.object.scope,
            .principal = 7,
            .operation = 9,
        },
        .ordinal = 1,
        .partition = 109,
    };
}

test "document initialization survives disk reopen and retry keeps exact genesis" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var original: I.Request = undefined;
    var evidence: I.Evidence = undefined;
    var policy: Policy = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var owned = try s.DocumentDeclaration.prepare(t.allocator, sampleDefinition());
        defer owned.deinit();
        original = request(try s.DocumentDeclaration.stage(objects.objectStore(), &owned));
        evidence = try I.initialize(t.allocator, wal.log(), objects.objectStore(), original, policy.guard());
        try t.expectEqual(@as(u64, 1), evidence.accepted.next_lsn);
        try t.expectEqualDeep(evidence, try I.initialize(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
        try t.expectEqual(@as(u64, 1), wal.appends);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    policy.epoch = 2;
    try t.expectEqualDeep(evidence, try I.observe(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
    try t.expectEqualDeep(evidence, try I.initialize(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
    try t.expectEqual(@as(u64, 0), wal.appends);

    var changed = original;
    changed.operation.operation += 1;
    try t.expectError(error.DocumentInitializationConflict, I.initialize(t.allocator, wal.log(), objects.objectStore(), changed, policy.guard()));
}
