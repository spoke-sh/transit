const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const p = root.protocol;
const Turn = root.station.GrowingTurn;
const M = root.Migration;
const Store = struct {
    entries: std.AutoHashMap(p.Value, p.Value) = .init(t.allocator),
    position: u64 = 0,
    reads: usize = 0,
    fail_at: ?usize = null,
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) anyerror!?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.reads += 1;
        if (self.fail_at == self.reads) return error.Unavailable;
        return self.entries.get(key);
    }
    fn turn(self: *Store, principal: u64) !Turn {
        self.position += 1;
        return Turn.init(.{ .realm = 49, .principal = 77, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = self.position, .ordinal = 1, .value = try p.Value.init("proposal"), .origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 77, .generation = 3, .input = self.position, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100000 }, .{ .context = self, .read = read });
    }
    fn commit(self: *Store, turn_value: *Turn) !void {
        try turn_value.validate();
        for (turn_value.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.entries.put(mutation.key, value) else _ = self.entries.remove(mutation.key);
        };
    }
};

fn owner() M {
    return .{ .configuration = .{ .application = 9, .realm = 49, .administrator = 33, .initial_epoch = .{ .value = 1 }, .initial_contract = @splat(1) } };
}
fn setup(store: *Store) !void {
    var boot = try store.turn(33);
    try owner().initialize(&boot);
    try store.commit(&boot);
    for ([_]u64{ 44, 45 }) |principal| {
        var grant = try store.turn(33);
        try owner().setPolicy(&grant, principal, .{}, .{ .revision = .{ .value = 1 }, .migrate = true });
        try store.commit(&grant);
    }
}
fn proposal(id: u64) M.Proposal {
    return .{ .plan = .{ .value = id }, .expected = .{ .value = 1 }, .next = .{ .value = 2 }, .transform = 1, .source = @splat(1), .target = @splat(2) };
}
const Domain = struct {
    calls: usize = 0,
    writes: u8 = 2,
    fail: bool = false,
    activate: bool = false,
    pub fn apply(self: *@This(), turn: *Turn, _: M.Plan, previous: M.Progress, step: M.Step) !M.Transition {
        self.calls += 1;
        if (!previous.cursor.eql(step.arguments)) return error.StaleDomainCursor;
        for (0..self.writes) |i| {
            var key: [2]u8 = .{ 'd', @intCast(i) };
            try turn.write(try p.Value.init(&key), try p.Value.init("changed"));
        }
        if (self.fail) return error.DomainFailure;
        return if (self.activate) .{ .activate = {} } else .{ .advance = try p.Value.init("cursor") };
    }
};
fn mutations(turn: Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |item| {
        if (item != null) count += 1;
    }
    return count;
}
test "independent migration layouts bind full-width identities and exact step arguments" {
    const F = struct { version: u8, plan: M.Plan, plan_hex: p.Value, step: M.Step, step_digest: [32]u8, progress: M.Progress, progress_hex: p.Value, receipt: M.Receipt, receipt_hex: p.Value, key_hex: p.Value };
    const fixture = try p.Json.parseFromSlice(F, t.allocator, @embedFile("fixtures/migration-v1.json"));
    defer fixture.deinit();
    const value = fixture.value;
    try t.expectEqual(@as(u8, 1), value.version);
    try t.expectEqualSlices(u8, &value.plan.digest, &try owner().proposalDigest(value.plan.proposal));
    try t.expectEqualSlices(u8, &value.step_digest, &try owner().stepDigest(value.plan, value.step));
    try t.expect(value.key_hex.eql(M.key(9, 'S', value.step.plan.value, value.step.ordinal.value)));
    inline for (.{ .{ "plan", "plan_hex", 'A', M.Plan }, .{ "progress", "progress_hex", 'G', M.Progress }, .{ "receipt", "receipt_hex", 'S', M.Receipt } }) |item| {
        const encoded = @field(value, item[1]);
        try t.expect(encoded.eql(try root.Records.encode(item[2], @field(value, item[0]))));
        try t.expectEqualDeep(@field(value, item[0]), try root.Records.decode(item[3], item[2], encoded));
        var invalid = encoded;
        invalid.data[invalid.len] = 0;
        invalid.len += 1;
        try t.expectError(error.InvalidApplicationRecord, root.Records.decode(item[3], item[2], invalid));
    }
}
test "migration receipts recover once across reconstruction and retained step growth" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    try t.expectEqual(@as(usize, 3), mutations(begin));
    var domain: Domain = .{};
    var cursor: p.Value = .{};
    for (1..21) |ordinal| {
        const step: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = ordinal }, .operation = 1, .arguments = cursor };
        var turn = try store.turn(44);
        const receipt = try owner().apply(&turn, step, &domain);
        try t.expectEqual(@as(usize, 4), mutations(turn));
        try store.commit(&turn);
        cursor = receipt.progress.cursor;
        var retry = try store.turn(44);
        try t.expectEqualDeep(receipt, try owner().apply(&retry, step, &domain));
        try t.expectEqual(@as(usize, 0), mutations(retry));
        var changed = step;
        changed.operation = 2;
        try t.expectError(error.MigrationStepConflict, owner().apply(&retry, changed, &domain));
    }
    try t.expectEqual(@as(usize, 20), domain.calls);
    var finish = try store.turn(44);
    domain.writes = 0;
    domain.activate = true;
    _ = try owner().apply(&finish, .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 21 }, .operation = 2, .arguments = cursor }, &domain);
    try t.expectEqual(@as(usize, 3), mutations(finish));
    try store.commit(&finish);
    var read = try store.turn(44);
    const head = try owner().head(&read);
    try t.expectEqual(@as(u64, 2), head.epoch.value);
    try t.expectEqual(@as(u64, 0), head.active.value);
    try t.expectEqual(M.Phase.applied, (try owner().begin(&read, proposal(7))).phase);
    try t.expectError(error.MigrationAlreadyApplied, owner().abandon(&read, .{ .value = 7 }));
}
test "current authority concurrent plans source conflicts and rollback of failed domain steps" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    var conflict = try store.turn(45);
    try t.expectError(error.MigrationPlanConflict, owner().begin(&conflict, proposal(7)));
    try t.expectError(error.MigrationBusy, owner().begin(&conflict, proposal(8)));
    const step: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 };
    var domain: Domain = .{ .fail = true };
    var failed = try store.turn(44);
    try t.expectError(error.DomainFailure, owner().apply(&failed, step, &domain));
    try t.expectEqual(@as(usize, 0), mutations(failed));
    domain.fail = false;
    domain.writes = 3;
    try t.expectError(error.MutationBudgetExceeded, owner().apply(&failed, step, &domain));
    try t.expectEqual(@as(usize, 0), mutations(failed));
    domain.writes = 2;
    var future = step;
    future.ordinal.value = 2;
    try t.expectError(error.MigrationStepConflict, owner().apply(&failed, future, &domain));
    var revoke = try store.turn(33);
    try owner().setPolicy(&revoke, 44, .{ .value = 1 }, .{ .revision = .{ .value = 2 }, .migrate = false });
    try store.commit(&revoke);
    try t.expectError(error.MigrationDenied, owner().apply(&failed, step, &domain));
    try t.expectError(error.MigrationDenied, owner().abandon(&failed, .{ .value = 7 }));
    var grant = try store.turn(33);
    try owner().setPolicy(&grant, 44, .{ .value = 2 }, .{ .revision = .{ .value = 3 }, .migrate = true });
    try store.commit(&grant);
    var abandon = try store.turn(44);
    _ = try owner().abandon(&abandon, .{ .value = 7 });
    try store.commit(&abandon);
    var retry = try store.turn(44);
    try t.expectEqual(M.Phase.abandoned, (try owner().abandon(&retry, .{ .value = 7 })).phase);
    try t.expectError(error.MigrationNotActive, owner().apply(&retry, step, &domain));
    var changed = proposal(8);
    changed.source = @splat(9);
    try t.expectError(error.MigrationSourceChanged, owner().begin(&retry, changed));
    retry.delivery.input.origin = .{ .process = .{ .pid = 1, .turn = 1, .output = 1 } };
    try t.expectError(error.MigrationDenied, owner().begin(&retry, proposal(8)));
}

test "unavailable ledger reads never settle a step or alter prior turn work" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    const step: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 };
    for (1..7) |offset| {
        var turn = try store.turn(44);
        try turn.write(try p.Value.init("prior"), try p.Value.init("retained"));
        const before = turn.decision;
        var domain: Domain = .{};
        store.fail_at = store.reads + offset;
        try t.expectError(error.Unavailable, owner().apply(&turn, step, &domain));
        try t.expectEqualDeep(before, turn.decision);
        store.fail_at = null;
    }
    var turn = try store.turn(44);
    try turn.write(try p.Value.init("prior"), try p.Value.init("retained"));
    const before = turn.decision;
    var domain: Domain = .{ .fail = true };
    try t.expectError(error.DomainFailure, owner().apply(&turn, step, &domain));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqual(@as(?M.Receipt, null), try owner().receipt(&turn, step));
}
