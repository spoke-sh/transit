const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const x = p.Transaction;
const A = s.LogTransactionActions;
const f = @import("transaction_test_support.zig");
const payload = "private payload; schema validation belongs to the partition";
const guard: x.LogGuard = .{
    .kind = .queue,
    .source = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = f.participant(7).participant.state.guard.source.interpretation, .partition = 2 }, .accepted = .{ .partition = 17, .next_lsn = 5 }, .retained_from = 0, .next = 10 },
    .changed_lsn = 3,
};
fn append(sequence: u64) x.LogAction {
    return .{ .statement = .{ .transaction = f.identity, .sequence = sequence, .intent = @splat(8) }, .ordinal = 1, .action = .{ .append = .{
        .target = guard.source.target,
        .operation = .{ .scope = f.scope, .principal = f.identity.begin.principal, .operation = 1000 + sequence },
        .kind = .queue,
        .producer = null,
        .rows = 1,
        .payload = s.LogBatch.content(payload),
    } } };
}
fn ack(sequence: u64) x.LogAction {
    var action = append(sequence);
    const original = action.action.append.operation;
    action.action = .{ .queue_ack = .{ .operation = original, .lease = .{ .target = guard.source.target, .claim = .{ .scope = f.scope, .principal = 0, .operation = 700 }, .offset = 4, .epoch = 9, .attempt = 1, .expires_ms = 9000 }, .action = .ack } };
    return action;
}

test "log transaction actions retain mixed private work across disk reopen beyond one resident page" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var earlier: x.Directory = undefined;
    var full: x.Directory = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var actions = try A.init(t.allocator, objects.objectStore(), f.identity, guard, 1000, 1024 * 1024, 1, 1024 * 1024);
        defer actions.deinit();
        for (1..74) |i| {
            try actions.put(if (i % 2 == 1) append(i) else ack(i), if (i % 2 == 1) payload else null);
            if (i == 8) earlier = try actions.seal();
        }
        full = try actions.seal();
        try actions.verify();
        try t.expectEqual(@as(usize, 1), actions.index.cache.len);
        const pages_before = actions.index.staged_pages;
        try actions.put(append(1), payload);
        try t.expectEqual(pages_before, actions.index.staged_pages);
        try t.expectEqualDeep(full, try actions.seal());
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var actions = try A.init(t.allocator, objects.objectStore(), f.identity, guard, 1000, 1024 * 1024, 0, 1024 * 1024);
    defer actions.deinit();
    for ([_]x.Directory{ full, earlier }) |selected| {
        try actions.restore(selected);
        try actions.verify();
        var after: ?A.Cursor = null;
        var count: u64 = 0;
        var bytes: [payload.len]u8 = undefined;
        while (true) {
            const page = try actions.page(after);
            for (page.entries) |slot| if (slot) |entry| {
                const action = entry.work;
                try t.expect(entry.offset_progress == null);
                count += 1;
                try t.expectEqualDeep(if (count % 2 == 1) append(count) else ack(count), action);
                if (action.action == .append) try t.expectEqualStrings(payload, try actions.readPayload(action, &bytes));
            };
            after = page.next orelse break;
        }
        try t.expectEqual(selected.count, count);
    }
    var changed_guard = guard;
    changed_guard.source.target.partition += 1;
    var foreign = try A.init(t.allocator, objects.objectStore(), f.identity, changed_guard, 1000, 1024 * 1024, 0, 1024 * 1024);
    defer foreign.deinit();
    try t.expectError(error.InvalidTransactionActions, foreign.restore(full));
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try A.payloadKey(append(1).action.append.payload, &name));
    var bytes: [payload.len]u8 = undefined;
    try t.expectError(error.MissingTransactionPayload, actions.readPayload(append(1), &bytes));
}

test "log transaction actions refuse identity substitution and quotas without changing private roots" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var actions = try A.init(t.allocator, objects.objectStore(), f.identity, guard, 2, payload.len, 1, 1024 * 1024);
    defer actions.deinit();
    try actions.put(append(1), payload);
    const before = try actions.seal();
    try t.expectError(error.LogPayloadConflict, actions.put(append(1), "changed"));
    var changed = append(1);
    changed.action.append.rows = 2;
    try t.expectError(error.TransactionIdentityConflict, actions.put(changed, payload));
    changed = append(2);
    changed.action.append.operation = append(1).action.append.operation;
    try t.expectError(error.TransactionIdentityConflict, actions.put(changed, payload));
    try t.expectError(error.TransactionWorkspaceLimit, actions.put(append(2), payload));
    try t.expectEqualDeep(before, try actions.seal());
    try actions.put(ack(2), null);
    const full = try actions.seal();
    try t.expectError(error.TransactionActionLimit, actions.put(ack(3), null));
    changed = ack(3);
    changed.statement.transaction.begin.operation += 1;
    try t.expectError(error.TransactionIdentityConflict, actions.put(changed, null));
    changed = ack(2);
    changed.ordinal = 2;
    changed.action.queue_ack.operation.operation += 10;
    changed.statement.intent[0] ^= 1;
    try t.expectError(error.InvalidTransactionStatement, actions.put(changed, null));
    try t.expectEqualDeep(full, try actions.seal());
    try actions.verify();
    var short: [1]u8 = undefined;
    try t.expectError(error.TransactionMemoryLimit, actions.readPayload(append(1), &short));
    var forged = full;
    forged.count -= 1;
    try t.expectError(error.InvalidTransactionActions, actions.restore(forged));
}

test "log transaction actions allocate no owner heap while staging and paging after initialization" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var allocator = t.FailingAllocator.init(t.allocator, .{});
    var actions = try A.init(allocator.allocator(), objects.objectStore(), f.identity, guard, 1000, 1024 * 1024, 1, 1024 * 1024);
    defer actions.deinit();
    allocator.fail_index = allocator.alloc_index;
    const allocated = allocator.allocated_bytes;
    for (1..42) |sequence| try actions.put(append(sequence), payload);
    const sealed = try actions.seal();
    actions.index.clearCache();
    try actions.restore(sealed);
    try actions.verify();
    var bytes: [payload.len]u8 = undefined;
    for (1..42) |sequence| {
        const action = (try actions.get(.{ .sequence = sequence, .ordinal = 1 })).?.work;
        try t.expectEqualStrings(payload, try actions.readPayload(action, &bytes));
    }
    try t.expectEqual(allocated, allocator.allocated_bytes);
    try t.expect(!allocator.has_induced_failure);
    // Provider allocations are independent of this bounded directory owner.
}

test "log transaction actions reject a foreign definition before decoding a retained root" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var actions = try A.init(t.allocator, objects.objectStore(), f.identity, guard, 100, 1024 * 1024, 1, 1024 * 1024);
    defer actions.deinit();
    try actions.put(append(1), payload);
    const original = try actions.seal();
    var name: [96]u8 = undefined;
    var buffer: [A.max_object_bytes]u8 = undefined;
    const borrowed = try objects.objectStore().getRange(try A.objectKey(original.content, &name), 0, @intCast(original.content.bytes), &buffer);
    buffer[8] ^= 1;
    const foreign = s.LogBatch.content(buffer[0..borrowed.len]);
    _ = try objects.objectStore().putImmutable(try A.objectKey(foreign, &name), buffer[0..borrowed.len], foreign.sha256);
    try t.expectError(error.IncompatibleDefinition, actions.restore(.{ .content = foreign, .count = original.count }));
    try t.expectEqualDeep(original, try actions.seal());
}

test "log transaction actions require and retain exact Stream coverage credentials" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var stream_guard = guard;
    stream_guard.kind = .stream;
    var actions = try A.init(t.allocator, objects.objectStore(), f.identity, stream_guard, 100, 1024 * 1024, 1, 1024 * 1024);
    defer actions.deinit();
    const coverage: p.StreamQueue.Coverage = .{ .cut = guard.source, .from = 0, .until = 10, .through = 10, .rows = 10, .complete = true };
    const issued: p.StreamRead.Cursor = .{ .read = .{ .owner = .{ .scope = f.scope, .principal = 0, .operation = 700 }, .source = f.content }, .coverage = coverage, .authentication = @splat(2) };
    var action = append(1);
    const original = action.action.append.operation;
    action.action = .{ .stream_offset = .{ .operation = original, .group = .{ .id = 1, .generation = 1, .principal = 0 }, .coverage = coverage, .expected_next = 0, .next = 10 } };
    try t.expectError(error.InvalidTransactionCoverage, actions.put(action, null));
    var wrong = issued;
    wrong.coverage.rows -= 1;
    try t.expectError(error.InvalidTransactionCoverage, actions.putOffset(action, .{ .exhausted = wrong }));
    wrong = issued;
    wrong.read.owner.principal = 1;
    try t.expectError(error.InvalidTransactionCoverage, actions.putOffset(action, .{ .exhausted = wrong }));
    try actions.putOffset(action, .{ .exhausted = issued });
    const saved = try actions.seal();
    actions.index.clearCache();
    try actions.restore(saved);
    const entry = (try actions.get(A.cursor(action))).?;
    try t.expectEqualDeep(action, entry.work);
    try t.expectEqualDeep(issued, entry.offset_progress.?.exhausted);
    try actions.putOffset(action, .{ .exhausted = issued });
    wrong = issued;
    wrong.authentication[0] ^= 1;
    try t.expectError(error.TransactionIdentityConflict, actions.putOffset(action, .{ .exhausted = wrong }));
    try actions.verify();
    // The partition owner must verify the credential's MAC and retained source.
    // A stored, structurally valid credential alone settles no consumer offset.
}

const Fault = struct {
    underlying: s.TransitObjectStore.ObjectStore,
    puts: usize = 0,
    at: ?usize = null,
    after: bool = false,
    fn objectStore(self: *@This()) s.TransitObjectStore.ObjectStore {
        return .{ .context = self, .vtable = &.{ .putImmutable = immutable, .putConditional = conditional, .getRange = get, .head = head, .delete = delete } };
    }
    fn immutable(ctx: *anyopaque, name: []const u8, value: []const u8, digest: [32]u8) !s.TransitObjectStore.ObjectMeta {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.puts += 1;
        if (self.at == self.puts and !self.after) return error.TestObjectFailure;
        const result = try self.underlying.putImmutable(name, value, digest);
        if (self.at == self.puts) return error.TestObjectFailure;
        return result;
    }
    fn conditional(ctx: *anyopaque, name: []const u8, condition: s.TransitObjectStore.Condition, value: []const u8) !bool {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.putConditional(name, condition, value);
    }
    fn get(ctx: *anyopaque, name: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.getRange(name, offset, length, out);
    }
    fn head(ctx: *anyopaque, name: []const u8) !?s.TransitObjectStore.ObjectMeta {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.head(name);
    }
    fn delete(ctx: *anyopaque, name: []const u8) !void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.delete(name);
    }
};

test "log transaction actions preserve the prior root at every object staging and acknowledgement failure" {
    var stages: usize = 0;
    {
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var fault: Fault = .{ .underlying = objects.objectStore() };
        var actions = try A.init(t.allocator, fault.objectStore(), f.identity, guard, 100, 1024 * 1024, 1, 1024 * 1024);
        defer actions.deinit();
        try actions.put(append(1), payload);
        const before = fault.puts;
        try actions.put(append(2), payload);
        stages = fault.puts - before;
    }
    try t.expect(stages > 2);
    for ([_]bool{ false, true }) |after| for (1..stages + 1) |stage| {
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var fault: Fault = .{ .underlying = objects.objectStore(), .after = after };
        var actions = try A.init(t.allocator, fault.objectStore(), f.identity, guard, 100, 1024 * 1024, 1, 1024 * 1024);
        defer actions.deinit();
        try actions.put(append(1), payload);
        const original = try actions.seal();
        fault.at = fault.puts + stage;
        try t.expectError(error.TestObjectFailure, actions.put(append(2), payload));
        try t.expectEqualDeep(original, try actions.seal());
        actions.index.clearCache();
        try actions.restore(original);
        try actions.verify();
        try t.expect(try actions.get(.{ .sequence = 2, .ordinal = 1 }) == null);
        fault.at = null;
        try actions.put(append(2), payload);
        try actions.verify();
        try t.expectEqual(@as(u64, 2), actions.root.count);
    };
}
