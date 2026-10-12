const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const Index = f.RelationalIndex;
const State = q.RelationalState;
const Store = q.testing.Store;
const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "k", .type = .int64 }};
const sources = [_]r.Source{.{ .alias = "t", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = .{ .object = 11, .revision = 1, .next_column = 2, .columns = &columns } }};
const plan: r.Plan = .{ .sources = &sources, .group_by = &.{.{ .source = 0, .id = 1 }}, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = .captured, .budgets = .{ .resident_bytes = 4 * 1024 * 1024, .spill_bytes = 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 10000, .work_steps = 100000, .source_pins = 1 } };
const Candidate = State.Candidate(*q.station.Turn);
fn cut() ![1]r.Cut {
    return .{.{ .resource = 7, .revision = 1, .commitment = @splat(17), .schema = try sources[0].schema.fingerprint() }};
}
fn group(value: i64, count: u64) f.RelationalExecution.Group {
    var result: f.RelationalExecution.Group = .{ .key = .{ .len = 1 } };
    result.key.values[0] = value;
    result.states[0].rows = count;
    return result;
}
fn initial(bound: r.Bound) !f.RelationalCheckpoint {
    var fields: [r.max_outputs]f.Types.Field = undefined;
    var bytes: [f.Types.max_encoding_bytes]u8 = undefined;
    return .{ .binding = try bound.fingerprint(), .root = null, .result_bytes = (try (try bound.plan.outputSchema(&fields)).encode(&bytes)).len };
}
fn readHead(turn: *q.station.Turn) !?[3]u64 {
    const value = (try turn.read(try q.protocol.Value.init("relational-root"))) orelse return null;
    if (value.len != 24) return error.InvalidTestHead;
    return .{ std.mem.readInt(u64, value.data[0..8], .little), std.mem.readInt(u64, value.data[8..16], .little), std.mem.readInt(u64, value.data[16..24], .little) };
}
fn writeHead(turn: *q.station.Turn, head: [3]u64) !void {
    var bytes: [24]u8 = undefined;
    for (head, 0..) |value, i| std.mem.writeInt(u64, bytes[i * 8 ..][0..8], value, .little);
    try turn.write(try q.protocol.Value.init("relational-root"), try q.protocol.Value.init(&bytes));
}
test "publication staging restarts preserve the previous operator root until checkpoint publication" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    const pages = try State.create(&turn, 700);
    try store.commit(turn);
    const cuts = try cut();
    const bound: r.Bound = .{ .plan = plan, .cuts = &cuts };
    const candidate = try t.allocator.create(Candidate);
    defer t.allocator.destroy(candidate);
    var accepted = try initial(bound);
    var next: u64 = 1;
    var used: u64 = 0;
    var oldest: ?f.RelationalCheckpoint = null;
    var staging_turns: usize = 0;
    for (0..20) |i| {
        var complete = false;
        for (0..200) |_| {
            turn = try store.capture();
            const old_head = try readHead(&turn);
            if (old_head) |head| {
                // Host memory is dispensable: recover the exact accepted state.
                accepted = try pages.checkpoint(&turn, head[0], bound);
                next = head[1];
                used = head[2];
            }
            try t.expectEqual(i, accepted.group_count);
            candidate.* = try Candidate.init(pages, &turn, next, used, bound, 10000);
            var tree = try Index.init(bound, accepted.root);
            try tree.put(candidate, group(@intCast((i * 7) % 20), i + 1));
            var proposed = accepted;
            proposed.root = tree.root;
            proposed.group_count += 1;
            proposed.work += 1;
            proposed.after_left = .{ .origin = 1, .operation = i + 1, .ordinal = 0 };
            var bytes: [f.RelationalCheckpoint.max_bytes]u8 = undefined;
            const encoded = try proposed.encode(bound, &bytes);
            const total = try candidate.retainedBytes(encoded.len);
            const checkpoint_id = try candidate.checkpointId();
            var ready = try candidate.stage(&turn);
            if (ready) ready = pages.stageCheckpoint(&turn, checkpoint_id, bound, proposed) catch |err| blk: {
                if (err != error.MutationBudgetExceeded) return err;
                break :blk false;
            };
            if (ready) writeHead(&turn, .{ checkpoint_id, checkpoint_id + 1, total }) catch |err| {
                if (err != error.MutationBudgetExceeded) return err;
                ready = false;
            };
            if (!ready) {
                try t.expect(std.meta.eql(old_head, try readHead(&turn)));
                staging_turns += 1;
            }
            try store.commit(turn);
            // Drop all the candidate/proposed state as if the worker restarted.
            if (ready) {
                turn = try store.capture();
                const head = (try readHead(&turn)).?;
                accepted = try pages.checkpoint(&turn, head[0], bound);
                try t.expectEqual(i + 1, accepted.group_count);
                if (i == 4) oldest = accepted;
                complete = true;
                break;
            }
        }
        try t.expect(complete);
    }
    try t.expect(staging_turns > 20);
    turn = try store.capture();
    const head = (try readHead(&turn)).?;
    candidate.* = try Candidate.init(pages, &turn, head[1], head[2], bound, 10000);
    const old_tree = try Index.init(bound, oldest.?.root);
    var after: ?f.RelationalExecution.Key = null;
    var count: usize = 0;
    while (try old_tree.next(candidate, after)) |value| {
        count += 1;
        after = value.key;
    }
    try t.expectEqual(@as(usize, 5), count);
    store.denied = true;
    turn = try store.capture();
    try t.expectError(error.AccessDenied, pages.checkpoint(&turn, head[0], bound));
}
test "candidate quotas and identity conflicts fail before replacing accepted state" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    const pages = try State.create(&turn, 701);
    try store.commit(turn);
    const cuts = try cut();
    var requested = plan;
    requested.budgets.spill_bytes = 1;
    const candidate = try t.allocator.create(Candidate);
    defer t.allocator.destroy(candidate);
    turn = try store.capture();
    candidate.* = try Candidate.init(pages, &turn, 1, 0, .{ .plan = requested, .cuts = &cuts }, 100);
    var tree = try Index.init(.{ .plan = requested, .cuts = &cuts }, null);
    try t.expectError(error.RelationalSpillBudget, tree.put(candidate, group(1, 3)));
    try t.expect(tree.root == null);
    try t.expectEqual(@as(u16, 0), candidate.count);
    requested = plan;
    const bound: r.Bound = .{ .plan = requested, .cuts = &cuts };
    candidate.* = try Candidate.init(pages, &turn, 1, 0, bound, 1);
    tree = try Index.init(bound, null);
    try tree.put(candidate, group(1, 3));
    try t.expectError(error.RelationalWorkBudget, tree.put(candidate, group(2, 4)));
    try t.expectEqual(@as(u64, 1), tree.root.?.entries);
    _ = try candidate.stage(&turn);
    try store.commit(turn);
    turn = try store.capture();
    candidate.* = try Candidate.init(pages, &turn, 1, 0, bound, 100);
    tree = try Index.init(bound, null);
    try tree.put(candidate, group(1, 4));
    try t.expectError(error.PublicationIdentityConflict, candidate.stage(&turn));
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
    try t.expect(try readHead(&turn) == null);
}
