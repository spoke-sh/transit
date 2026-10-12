const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const p = root.protocol;
const g = p.Growth;
const h = root.WorkerHandoff;
const plan: h.Plan = .{ .id = 1, .realm = 2, .pid = 3, .resource = 4, .worker = 5, .generation = 7, .resume_before_ms = 10000, .expected_public_key = @splat(11), .public_key = @splat(12), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .application = @splat(13), .old_instance = @splat(14), .new_instance = @splat(15) };
const state: h.State = .{ .resource = 4, .writer = 3, .revision = 20, .entries = 19, .bytes = 1900, .digest = @splat(16) };
const Fixture = struct { record: []const u8, state_digest: []const u8 };
fn recover(record: h.Record) !h.Record {
    const bytes = try record.save(t.allocator);
    defer t.allocator.free(bytes);
    const restored = try h.Record.restore(t.allocator, bytes);
    try t.expectEqualDeep(record, restored);
    var truncated = bytes.len;
    while (truncated > 0) {
        truncated -= 1;
        if (h.Record.restore(t.allocator, bytes[0..truncated])) |_| return error.AcceptedTruncatedHandoff else |_| {}
    }
    return restored;
}
test "recorded handoff reconstructs at every boundary and never restores older mailbox progress" {
    var record = try recover(try h.Record.start(plan));
    try t.expectEqual(@as(u64, 7), (try record.command()).@"suspend".expected_generation);
    var process: g.Process = .{ .pid = 3, .code = 1, .generation = 8, .revision = 4, .consumed = 4, .admitted = 6, .control = .{ .phase = .suspended, .resume_before_ms = 10000 } };
    var changed = process;
    changed.owner = plan.worker;
    try t.expectError(error.WorkerHandoffConflict, record.quiesce(changed));
    changed = process;
    changed.turn_permit = .{ .id = 100, .input = 5 };
    try t.expectError(error.WorkerHandoffConflict, record.quiesce(changed));
    record = try recover(try record.quiesce(process));
    try t.expectError(error.InvalidWorkerHandoff, record.command());
    record = try recover(try record.capture(process, state));
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/worker-handoff.json"), .{});
    defer fixture.deinit();
    const encoded = try record.save(t.allocator);
    defer t.allocator.free(encoded);
    try t.expectEqualStrings(fixture.value.record, encoded);
    try t.expectEqual(@as(u64, 8), (try record.command()).@"resume".expected_generation);
    process.generation += 1;
    process.control = .{ .phase = .ready };
    process.admitted += 3;
    record = try recover(try record.fence(process));
    changed = process;
    changed.consumed += 1;
    try t.expectError(error.WorkerHandoffConflict, record.restored(changed, state, plan.application));
    var corrupt = state;
    corrupt.digest[0] ^= 1;
    try t.expectError(error.InvalidWorkerCheckpoint, record.restored(process, corrupt, plan.application));
    try t.expectError(error.InvalidWorkerCheckpoint, record.restored(process, state, @splat(0)));
    changed = process;
    changed.admitted = 5;
    try t.expectError(error.WorkerHandoffConflict, record.restored(changed, state, plan.application));
    record = try recover(try record.restored(process, state, plan.application));
    const command = (try record.command()).rotate_worker;
    try t.expectEqual(@as(u64, 9), command.expected_generation);
    try t.expectEqualSlices(u8, &plan.expected_public_key, &command.expected_public_key);
    try t.expectEqualSlices(u8, &plan.public_key, &command.public_key);
    process.generation += 1;
    process.owner = plan.worker;
    const grant: g.Grant = .{ .subject = plan.worker, .pid = plan.pid, .permissions = plan.permissions, .public_key = plan.public_key };
    var denied = grant;
    denied.permissions = 0;
    try t.expectError(error.WorkerHandoffConflict, record.activate(process, denied));
    denied = grant;
    denied.public_key = plan.expected_public_key;
    try t.expectError(error.WorkerHandoffConflict, record.activate(process, denied));
    record = try recover(try record.activate(process, grant));
    try t.expectError(error.WorkerHandoffConflict, record.retire(plan.new_instance));
    record = try recover(try record.retire(plan.old_instance));
    try t.expectEqual(.retired, record.phase);
    try t.expectError(error.InvalidWorkerHandoff, record.command());
    var missing = record;
    missing.checkpoint = null;
    try t.expectError(error.InvalidWorkerHandoff, missing.validate());
    const bytes = try record.save(t.allocator);
    defer t.allocator.free(bytes);
    const prefix = "{\"definition\":\"";
    bytes[prefix.len] = if (bytes[prefix.len] == '0') '1' else '0';
    if (h.Record.restore(t.allocator, bytes)) |_| return error.AcceptedForeignHandoff else |_| {}
    var same = plan;
    same.public_key = plan.expected_public_key;
    try t.expectError(error.InvalidWorkerHandoff, h.Record.start(same));
}
const Pages = struct {
    view: struct { resource: u64 = 4, revision: u64 = 20 } = .{},
    count: u64,
    corrupt: bool = false,
    reads: u64 = 0,
    pub fn page(self: *Pages, after: ?p.Value) !g.Batch(g.Entry, p.Value) {
        self.reads += 1;
        const start = if (after) |value| std.mem.readInt(u64, value.data[0..8], .big) + 1 else 0;
        var result: g.Batch(g.Entry, p.Value) = .{};
        for (start..@min(start + g.page_size, self.count), 0..) |index, slot| {
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, if (self.corrupt and slot == 1) start else index, .big);
            result.entries[slot] = .{ .key = try p.Value.init(&bytes), .value = try p.Value.init("value"), .revision = index % 20 };
        }
        if (start + g.page_size < self.count) result.next = result.entries[g.page_size - 1].?.key;
        return result;
    }
};
test "worker checkpoint hashes paged state with complete cardinality and order checks" {
    const resource: g.Resource = .{ .id = 4, .writer = 3, .owner = null, .revision = 20, .entries = 10003, .deadline_ms = null };
    var pages: Pages = .{ .count = resource.entries };
    const checkpoint = try h.snapshot(&pages, resource, 2000);
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/worker-handoff.json"), .{});
    defer fixture.deinit();
    var digest: [32]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&digest, fixture.value.state_digest), &checkpoint.digest);
    try t.expectEqual(@as(u64, 1251), pages.reads);
    try t.expectEqual(@as(u64, 130039), checkpoint.bytes);
    pages = .{ .count = resource.entries };
    try t.expectEqualDeep(checkpoint, try h.snapshot(&pages, resource, 2000));
    pages = .{ .count = resource.entries };
    try t.expectError(error.RequestBudgetExceeded, h.snapshot(&pages, resource, 1));
    pages = .{ .count = resource.entries - 1 };
    try t.expectError(error.InvalidWorkerCheckpoint, h.snapshot(&pages, resource, 2000));
    pages = .{ .count = resource.entries, .corrupt = true };
    try t.expectError(error.InvalidWorkerCheckpoint, h.snapshot(&pages, resource, 2000));
}
