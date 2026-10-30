const std = @import("std");
const p = @import("transit_protocol");
const t = std.testing;
const s = @import("root.zig");
const I = s.LogInitialization;
const support = @import("log_test_support.zig");

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

fn request(stored: s.LogDeclaration.Stored) I.Request {
    return .{ .definition = p.Growth.current_definition, .declared = stored, .operation = .{ .scope = stored.declaration.interpretation.object.scope, .principal = 7, .operation = 8 }, .ordinal = 1, .partition = 99 };
}

test "log initialization survives disk reopen and retry keeps the exact original genesis" {
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
        var owned = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
        defer owned.deinit();
        original = request(try s.LogDeclaration.stage(objects.objectStore(), &owned));
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
    try t.expectError(error.LogInitializationConflict, I.initialize(t.allocator, wal.log(), objects.objectStore(), changed, policy.guard()));
    changed = original;
    changed.ordinal = 0;
    try t.expectError(error.LogInitializationConflict, I.observe(t.allocator, wal.log(), objects.objectStore(), changed, policy.guard()));
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, I.observe(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
    try t.expect(!policy.held);
}

test "log initialization refuses missing dependencies stale writers and post-buffer revocation" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var owned = try s.LogDeclaration.prepare(t.allocator, support.definition(.queue));
    defer owned.deinit();
    const original = request(try owned.stored());
    var policy: Policy = .{};
    try t.expectError(error.LogDeclarationMissing, I.initialize(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
    _ = try s.LogDeclaration.stage(objects.objectStore(), &owned);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, I.initialize(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
    try t.expectEqual(@as(u64, 0), try wal.log().tail(99));
    policy.deny_at = std.math.maxInt(usize);
    try wal.log().fence(99, 4, 4);
    try t.expectError(error.WalEpochRegression, I.initialize(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
    try t.expectEqual(@as(u64, 0), try wal.log().tail(99));
    policy.epoch = 4;
    _ = try I.initialize(t.allocator, wal.log(), objects.objectStore(), original, policy.guard());
    var changed = original;
    changed.ordinal = 2;
    try t.expectError(error.InvalidLogInitialization, I.initialize(t.allocator, wal.log(), objects.objectStore(), changed, policy.guard()));
}

const Fault = struct {
    underlying: s.TransitLog.Log,
    lose_reply: bool = true,
    fn log(self: *Fault) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
    fn cast(context: *anyopaque) *Fault {
        return @ptrCast(@alignCast(context));
    }
    fn append(context: *anyopaque, partition: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, bytes: []const u8) !s.TransitLog.AppendReceipt {
        const self = cast(context);
        const receipt = try self.underlying.append(partition, expected, writer, policy, kind, bytes);
        if (self.lose_reply) {
            self.lose_reply = false;
            return error.InjectedReplyLoss;
        }
        return receipt;
    }
    fn read(context: *anyopaque, allocator: std.mem.Allocator, partition: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        return cast(context).underlying.read(allocator, partition, from, count);
    }
    fn tail(context: *anyopaque, partition: u64) !u64 {
        return cast(context).underlying.tail(partition);
    }
    fn trim(context: *anyopaque, partition: u64, until: u64) !void {
        return cast(context).underlying.trim(partition, until);
    }
    fn fence(context: *anyopaque, partition: u64, writer: u64, policy: u64) !void {
        return cast(context).underlying.fence(partition, writer, policy);
    }
};

test "log initialization resolves lost accepted receipt and never resets foreign history" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var owned = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer owned.deinit();
    const original = request(try s.LogDeclaration.stage(objects.objectStore(), &owned));
    var policy: Policy = .{};
    var fault: Fault = .{ .underlying = wal.log() };
    try t.expectError(error.LogInitializationUncertain, I.initialize(t.allocator, fault.log(), objects.objectStore(), original, policy.guard()));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(99));
    wal.deinit();
    wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    fault.underlying = wal.log();
    const accepted = try I.initialize(t.allocator, fault.log(), objects.objectStore(), original, policy.guard());
    try t.expectEqualDeep(original, accepted.request);
    try t.expectEqual(@as(u64, 0), wal.appends);
    var other = original;
    other.partition = 100;
    _ = try wal.log().append(100, 0, 1, 1, .genesis, "foreign history");
    try t.expectError(error.InvalidLogInitialization, I.initialize(t.allocator, fault.log(), objects.objectStore(), other, policy.guard()));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(100));
    // Missing initialization after trimming is unavailable evidence, never an
    // instruction to recreate an empty partition over accepted work.
    try wal.log().trim(99, 1);
    try t.expectError(error.WalHistoryTrimmed, I.observe(t.allocator, wal.log(), objects.objectStore(), original, policy.guard()));
}
