const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const p = root.protocol;
const Turn = root.station.Turn;
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
    const F = struct { failure: root.MigrationFailure.Record, failure_hex: p.Value, witness: root.MigrationFailure.Witness, witness_hex: p.Value, version: u8, plan: M.Plan, plan_hex: p.Value, step: M.Step, step_digest: [32]u8, pending: M.Pending, pending_hex: p.Value, progress: M.Progress, progress_hex: p.Value, receipt: M.Receipt, receipt_hex: p.Value, key_hex: p.Value };
    const fixture = try p.Json.parseFromSlice(F, t.allocator, @embedFile("fixtures/migration-v1.json"));
    defer fixture.deinit();
    const value = fixture.value;
    try t.expectEqual(@as(u8, 1), value.version);
    try t.expectEqualSlices(u8, &value.plan.digest, &try owner().proposalDigest(value.plan.proposal));
    try t.expectEqualSlices(u8, &value.step_digest, &try owner().stepDigest(value.plan, value.step));
    try t.expect(value.key_hex.eql(M.key(9, 'S', value.step.plan.value, value.step.ordinal.value)));
    var store: Store = .{};
    defer store.entries.deinit();
    var turn = try store.turn(44);
    turn.delivery.input.position = value.failure.input;
    try t.expectEqualDeep(value.failure, try root.MigrationFailure.capture(&turn, "MigrationStepConflict", value.failure.plan, value.failure.ordinal, 4));
    try (try root.MigrationFailure.project(9, 49, 7, value.failure, value.witness, root.MigrationFailure.classification("MigrationStepConflict").?)).validate();
    inline for (.{ .{ "plan", "plan_hex", 'A', M.Plan }, .{ "pending", "pending_hex", 'T', M.Pending }, .{ "progress", "progress_hex", 'G', M.Progress }, .{ "receipt", "receipt_hex", 'S', M.Receipt }, .{ "failure", "failure_hex", 'e', root.MigrationFailure.Record }, .{ "witness", "witness_hex", 'f', root.MigrationFailure.Witness } }) |item| {
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

test "migration rejection witnesses preserve original ordinal commitment epoch and policy" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var context: root.MigrationFailure.Witness = .none;
    var selected = owner();
    selected.failure = &context;
    var begin = try store.turn(44);
    _ = try selected.begin(&begin, proposal(7));
    try store.commit(&begin);
    var failed = try store.turn(44);
    try t.expectError(error.MigrationBusy, selected.begin(&failed, proposal(8)));
    try t.expectEqual(@as(u64, 7), context.head.active.value);
    try t.expectEqual(@as(u64, 1), context.head.actual.value);
    var domain: Domain = .{};
    const future: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 3 }, .operation = 1 };
    try t.expectError(error.MigrationStepConflict, selected.apply(&failed, future, &domain));
    try t.expectEqual(@as(u64, 1), context.progress.next.value);
    try t.expectEqual(@as(u64, 3), context.progress.supplied.value);
    try t.expectEqual(@as(usize, 0), domain.calls);
    const first: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 };
    var applied = try store.turn(44);
    const receipt = try selected.apply(&applied, first, &domain);
    try store.commit(&applied);
    var altered = first;
    altered.operation = 2;
    try t.expectError(error.MigrationStepConflict, selected.apply(&failed, altered, &domain));
    try t.expectEqualSlices(u8, &receipt.digest, &context.step.expected);
    try t.expect(!std.mem.eql(u8, &context.step.expected, &context.step.actual));
    var revoke = try store.turn(33);
    try selected.setPolicy(&revoke, 44, .{ .value = 1 }, .{ .revision = .{ .value = 2 }, .migrate = false });
    try store.commit(&revoke);
    try t.expectError(error.MigrationDenied, selected.apply(&failed, first, &domain));
    try t.expectEqual(@as(u64, 2), context.policy.actual.value);
    try t.expect(!context.policy.migrate);
    const retained = context;
    var restore = try store.turn(33);
    try selected.setPolicy(&restore, 44, .{ .value = 2 }, .{ .revision = .{ .value = 3 }, .migrate = true });
    try store.commit(&restore);
    try t.expectEqualDeep(retained, context);
    var abandon = try store.turn(44);
    _ = try selected.abandon(&abandon, .{ .value = 7 });
    try store.commit(&abandon);
    var changed = proposal(8);
    changed.source = @splat(9);
    try t.expectError(error.MigrationSourceChanged, selected.begin(&failed, changed));
    try t.expectEqualSlices(u8, &changed.source, &context.head.source);
    try t.expectEqualSlices(u8, &owner().configuration.initial_contract, &context.head.observed);
    try t.expectEqual(@as(usize, 0), mutations(failed));
}

test "migration diagnostic bounds and unsigned exhaustion never invoke the transform" {
    const failure = root.MigrationFailure;
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var context: failure.Witness = .none;
    var selected = owner();
    selected.failure = &context;
    var begin = try store.turn(44);
    _ = try selected.begin(&begin, proposal(7));
    try store.commit(&begin);
    try store.entries.put(M.key(9, 'G', 7, 0), try root.Records.encode('G', M.Progress{ .next = .{ .value = std.math.maxInt(u64) } }));
    var turn = try store.turn(44);
    var domain: Domain = .{};
    try t.expectError(error.MigrationOrdinalExhausted, selected.apply(&turn, .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = std.math.maxInt(u64) }, .operation = 1 }, &domain));
    try t.expectEqual(@as(usize, 0), domain.calls);
    try t.expectEqual(@as(usize, 0), mutations(turn));
    var invalid = proposal(8);
    invalid.expected.value = std.math.maxInt(u64);
    try t.expectError(error.InvalidMigrationProposal, selected.proposalDigest(invalid));
    var policy_turn = try store.turn(33);
    try t.expectError(error.InvalidMigrationPolicy, selected.setPolicy(&policy_turn, 44, .{ .value = std.math.maxInt(u64) }, .{ .revision = .{}, .migrate = true }));
    const record = try failure.capture(&turn, &@as([96]u8, @splat('a')), .{ .value = 7 }, .{ .value = 1 }, 1);
    try t.expectEqual(@as(u16, 159), (try root.Records.encode('e', record)).len);
    const witness: failure.Witness = .{ .head = .{ .expected = .{ .value = 1 }, .actual = .{ .value = 2 }, .source = @splat(1), .observed = @splat(2), .target = @splat(3), .active = .{ .value = 7 } } };
    try t.expectEqual(@as(u16, 125), (try root.Records.encode('f', witness)).len);
    inline for (.{ "MigrationDenied", "MigrationPolicyConflict", "InvalidMigrationPolicy", "InvalidMigrationProposal", "InvalidMigrationStep", "MigrationPlanConflict", "MigrationBusy", "MigrationSourceChanged", "MigrationPlanAbsent", "MigrationStepConflict", "MigrationNotActive", "MigrationAlreadyApplied", "MigrationOrdinalExhausted" }) |cause| {
        const detail = try failure.project(9, 49, 7, try failure.capture(&turn, cause, .{ .value = 7 }, .{ .value = 1 }, 1), .none, failure.classification(cause).?);
        try t.expectEqual(p.Diagnostic.Outcome.input_rejected, detail.outcome);
        try t.expectEqual(p.Diagnostic.Evidence.domain_status, detail.evidence);
        for (detail.actions) |slot| if (slot) |action| try t.expect(action.kind == .inspect_status or action.kind == .inspect_scope);
    }
    try t.expect(failure.classification("OutOfMemory") == null);
    try t.expect(failure.classification("Unavailable") == null);
}

test "migration configuration and transform faults remain unresolved without changing decisions" {
    const failure = root.MigrationFailure;
    inline for (.{ error.InvalidMigrationConfiguration, error.MigrationConfigurationChanged, error.MigrationNotInitialized, error.MigrationCursorTooLarge, error.OutOfMemory, error.Unavailable }) |cause| try t.expect(!failure.expected(cause));
    var store: Store = .{};
    defer store.entries.deinit();
    var turn = try store.turn(33);
    try t.expectError(error.MigrationNotInitialized, owner().begin(&turn, proposal(7)));
    try t.expectEqual(@as(usize, 0), mutations(turn));
    var invalid = owner();
    invalid.configuration.application = 0;
    try t.expectError(error.InvalidMigrationConfiguration, invalid.initialize(&turn));
    try t.expectEqual(@as(usize, 0), mutations(turn));
    try setup(&store);
    invalid = owner();
    invalid.configuration.initial_contract = @splat(9);
    try t.expectError(error.MigrationConfigurationChanged, invalid.initialize(&turn));
    try t.expectEqual(@as(usize, 0), mutations(turn));
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    var input = try store.turn(44);
    const original = input.decision;
    var bad_transform: struct {
        pub fn apply(_: *@This(), target: *Turn, _: M.Plan, _: M.Progress, _: M.Step) !M.Transition {
            try target.write(try p.Value.init("tentative"), try p.Value.init("must roll back"));
            return .{ .advance = try p.Value.init(&@as([129]u8, @splat(0))) };
        }
    } = .{};
    try t.expectError(error.MigrationCursorTooLarge, owner().apply(&input, .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 }, &bad_transform));
    try t.expectEqualDeep(original, input.decision);
}

const StagedDomain = struct {
    calls: usize = 0,
    terminal: bool = false,
    activate: bool = false,
    fail: bool = false,
    overflow: bool = false,
    original: u64 = 0,
    pub fn stage(self: *@This(), turn: *Turn, _: M.Plan, previous: M.Progress, pending: M.Pending) !?M.Transition {
        self.calls += 1;
        if (!previous.cursor.eql(pending.step.arguments)) return error.StaleDomainCursor;
        try t.expectEqual(self.original, pending.input);
        const count: usize = if (!self.terminal or self.overflow) 4 else if (self.activate) 1 else 2;
        for (0..count) |i| {
            const key: [2]u8 = .{ 's', @intCast(i) };
            try turn.write(try p.Value.init(&key), try p.Value.init(if (self.terminal) "published" else "staged"));
        }
        if (self.fail) return error.DomainFailure;
        return if (!self.terminal) null else if (self.activate) .{ .activate = {} } else .{ .advance = try p.Value.init("cursor") };
    }
};

test "staged migration freezes admission before domain work and completes atomically" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    const step: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 };
    var domain: StagedDomain = .{};
    var admission = try store.turn(44);
    const admission_before = admission.decision;
    const input = admission.delivery.input.position;
    domain.original = input;
    try t.expectEqual(@as(?M.Receipt, null), try owner().stage(&admission, step, &domain));
    try t.expectEqual(1, mutations(admission));
    try t.expectEqual(0, domain.calls);
    const admission_decision = admission.decision;
    admission.decision = admission_before;
    _ = try owner().stage(&admission, step, &domain);
    try t.expectEqualDeep(admission_decision, admission.decision);
    try store.commit(&admission);
    var read = try store.turn(44);
    try t.expectEqualDeep(M.Pending{ .step = step, .digest = try owner().stepDigest((try owner().plan(&read, step.plan)).?, step), .input = input }, (try owner().pending(&read, step)).?);
    try t.expectEqual(@as(?M.Receipt, null), try owner().receipt(&read, step));
    var changed = step;
    changed.arguments = try p.Value.init("changed");
    try t.expectError(error.MigrationStepConflict, owner().stage(&read, changed, &domain));
    try t.expectEqual(0, domain.calls);
    for (0..3) |_| {
        var staging = try store.turn(44);
        const staging_before = staging.decision;
        _ = try owner().stage(&staging, step, &domain);
        try t.expectEqual(4, mutations(staging));
        const decision = staging.decision;
        staging.decision = staging_before;
        _ = try owner().stage(&staging, step, &domain);
        try t.expectEqualDeep(decision, staging.decision);
        try store.commit(&staging);
        try t.expectEqual(1, (try owner().progress(&read, step.plan)).next.value);
        try t.expectEqual(@as(?M.Receipt, null), try owner().receipt(&read, step));
    }
    domain.terminal = true;
    domain.overflow = true;
    var completion = try store.turn(44);
    const completion_before = completion.decision;
    try t.expectError(error.MutationBudgetExceeded, owner().stage(&completion, step, &domain));
    try t.expectEqual(0, mutations(completion));
    domain.overflow = false;
    domain.fail = true;
    try t.expectError(error.DomainFailure, owner().stage(&completion, step, &domain));
    try t.expectEqual(0, mutations(completion));
    domain.fail = false;
    const result = (try owner().stage(&completion, step, &domain)).?;
    try t.expectEqual(input, result.input);
    try t.expectEqual(completion.delivery.input.position, result.progress.input);
    try t.expectEqual(4, mutations(completion));
    const decision = completion.decision;
    completion.decision = completion_before;
    try t.expectEqualDeep(result, (try owner().stage(&completion, step, &domain)).?);
    try t.expectEqualDeep(decision, completion.decision);
    try store.commit(&completion);
    const calls = domain.calls;
    try t.expectEqualDeep(result, (try owner().stage(&read, step, &domain)).?);
    try t.expectEqual(@as(?M.Pending, null), try owner().pending(&read, step));
    try t.expectEqual(calls, domain.calls);
    try t.expectEqual(0, mutations(read));
    const finish: M.Step = .{ .plan = step.plan, .ordinal = .{ .value = 2 }, .operation = 2, .arguments = result.progress.cursor };
    var activate = try store.turn(44);
    domain.original = activate.delivery.input.position;
    try t.expectEqual(@as(?M.Receipt, null), try owner().stage(&activate, finish, &domain));
    try store.commit(&activate);
    activate = try store.turn(44);
    domain.activate = true;
    const activated = (try owner().stage(&activate, finish, &domain)).?;
    try t.expectEqual(M.Phase.applied, activated.progress.phase);
    try t.expectEqual(4, mutations(activate));
    try store.commit(&activate);
    try t.expectEqual(2, (try owner().head(&read)).epoch.value);
}

test "staged migration checks current authority and retains abandoned admission" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    const step: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 };
    var domain: StagedDomain = .{};
    var admit = try store.turn(44);
    domain.original = admit.delivery.input.position;
    _ = try owner().stage(&admit, step, &domain);
    try store.commit(&admit);
    var failed = try store.turn(45);
    try t.expectError(error.MigrationDenied, owner().stage(&failed, step, &domain));
    var revoke = try store.turn(33);
    try owner().setPolicy(&revoke, 44, .{ .value = 1 }, .{ .revision = .{ .value = 2 }, .migrate = false });
    try store.commit(&revoke);
    failed = try store.turn(44);
    try t.expectError(error.MigrationDenied, owner().stage(&failed, step, &domain));
    try t.expectEqual(0, domain.calls);
    var restore = try store.turn(33);
    try owner().setPolicy(&restore, 44, .{ .value = 2 }, .{ .revision = .{ .value = 3 }, .migrate = true });
    try store.commit(&restore);
    for (1..7) |offset| {
        failed = try store.turn(44);
        try failed.write(try p.Value.init("prior"), try p.Value.init("retained"));
        const before = failed.decision;
        store.fail_at = store.reads + offset;
        try t.expectError(error.Unavailable, owner().stage(&failed, step, &domain));
        try t.expectEqualDeep(before, failed.decision);
        store.fail_at = null;
    }
    try t.expectEqual(0, domain.calls);
    var abandon = try store.turn(44);
    _ = try owner().abandon(&abandon, step.plan);
    try store.commit(&abandon);
    failed = try store.turn(44);
    try t.expectError(error.MigrationNotActive, owner().stage(&failed, step, &domain));
    try t.expect((try owner().pending(&failed, step)) != null);
    try t.expectEqual(@as(?M.Receipt, null), try owner().receipt(&failed, step));
    try t.expectEqual(0, domain.calls);
}

test "only owner self messages continue an admitted migration under current policy" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    const step: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 };
    var domain: StagedDomain = .{};
    var continuation = try store.turn(44);
    try t.expectError(error.MigrationDenied, owner().continueStage(&continuation, step, &domain));
    continuation.delivery.input.origin = .{ .process = .{ .pid = 99, .turn = 1, .output = 1 } };
    try t.expectError(error.MigrationDenied, owner().continueStage(&continuation, step, &domain));
    continuation.delivery.input.origin.process.pid = continuation.delivery.pid;
    try t.expectError(error.MigrationDenied, owner().continueStage(&continuation, step, &domain));
    var admission = try store.turn(44);
    domain.original = admission.delivery.input.position;
    _ = try owner().stage(&admission, step, &domain);
    try store.commit(&admission);
    _ = try owner().continueStage(&continuation, step, &domain);
    try t.expectEqual(4, mutations(continuation));
    try store.commit(&continuation);
    var revoke = try store.turn(33);
    try owner().setPolicy(&revoke, 44, .{ .value = 1 }, .{ .revision = .{ .value = 2 }, .migrate = false });
    try store.commit(&revoke);
    const before = continuation.decision;
    try t.expectError(error.MigrationDenied, owner().continueStage(&continuation, step, &domain));
    try t.expectEqualDeep(before, continuation.decision);
    try t.expectEqual(1, domain.calls);
}

test "corrupt staged migration evidence stays unresolved before caller attribution" {
    var store: Store = .{};
    defer store.entries.deinit();
    try setup(&store);
    var begin = try store.turn(44);
    _ = try owner().begin(&begin, proposal(7));
    try store.commit(&begin);
    const step: M.Step = .{ .plan = .{ .value = 7 }, .ordinal = .{ .value = 1 }, .operation = 1 };
    var domain: StagedDomain = .{};
    var admit = try store.turn(44);
    _ = try owner().stage(&admit, step, &domain);
    try store.commit(&admit);
    var read = try store.turn(44);
    const original = (try owner().pending(&read, step)).?;
    const address = M.key(9, 'S', 7, 1);
    for (0..5) |variant| {
        var corrupt = original;
        switch (variant) {
            0 => corrupt.input = 0,
            1 => corrupt.step.ordinal.value = 2,
            2 => corrupt.digest[0] ^= 1,
            3 => corrupt.step.operation = 0,
            4 => corrupt.step.arguments = try p.Value.init("corrupt"),
            else => unreachable,
        }
        try store.entries.put(address, try root.Records.encode('T', corrupt));
        var failed = try store.turn(44);
        try failed.write(try p.Value.init("prior"), try p.Value.init("retained"));
        const before = failed.decision;
        try t.expectError(error.InvalidApplicationRecord, owner().stage(&failed, step, &domain));
        try t.expectEqualDeep(before, failed.decision);
        try t.expectEqual(0, domain.calls);
    }
    try t.expect(!root.MigrationFailure.expected(error.InvalidApplicationRecord));
}
