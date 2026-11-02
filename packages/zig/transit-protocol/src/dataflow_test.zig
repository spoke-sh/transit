const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const f = p.Dataflow;

test "retained revision binds a common decision and rejects zero revision and aliased objects" {
    const fixture = try p.Json.parseFromSlice(p.DataLifecycle.SchemaTypes, t.allocator, @embedFile("fixtures/data-lifecycle-v1.json"));
    defer fixture.deinit();
    var revision = fixture.value.dataflow.revision;
    const decision = fixture.value.transaction.observation.decided;
    try revision.requireDecision(decision);
    revision.revision = 0;
    try t.expectError(error.InvalidDataflowRevision, revision.validate());
    revision = fixture.value.dataflow.revision;
    revision.output = revision.source;
    try t.expectError(error.InvalidDataflowRevision, revision.validate());
    revision = fixture.value.dataflow.revision;
    var aborted = decision;
    aborted.outcome = .aborted;
    try t.expectError(error.IncompleteDataflowCoverage, revision.requireDecision(aborted));
    var other = decision;
    other.attempt.transaction.begin.operation -= 1;
    try t.expectError(error.IncompleteDataflowCoverage, revision.requireDecision(other));
}
const d = p.DataLifecycle;
const scope: d.Scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) };
const target: d.Definition = .{ .object = .{ .scope = scope, .branch = 1, .object = std.math.maxInt(u64) }, .revision = 1, .digest = @splat(23) };
const operation: d.Operation = .{ .scope = scope, .principal = 0, .operation = 42 };
const active: f.Control = .{ .state = .active, .epoch = 3, .refresh = 0 };
const lease: f.Lease = .{ .target = target, .control = active, .owner = operation, .epoch = 9 };
const source: f.Source = .{ .interpretation = target, .kind = .table, .position = .{ .partition = 17, .next_lsn = 100 }, .retention_owner = operation };

test "dataflow control transition table and retired permanence" {
    // Rows: published, authorized, active, suspended, retired.
    // Columns: authorize, activate, suspend, resume, refresh, retire.
    const expected = [_][6]?f.State{
        .{ .authorized, null, null, null, null, .retired },
        .{ null, .active, null, null, null, .retired },
        .{ null, null, .suspended, null, .active, .retired },
        .{ null, null, null, .active, .suspended, .retired },
        .{ null, null, null, null, null, null },
    };
    inline for (std.meta.tags(f.State), 0..) |state, row| {
        inline for (std.meta.tags(f.Command), 0..) |command, column| {
            const previous: f.Control = .{ .state = state, .epoch = 100, .refresh = 5 };
            if (expected[row][column]) |next| {
                const actual = try previous.apply(command);
                try t.expectEqual(next, actual.state);
                try t.expectEqual(@as(u64, 101), actual.epoch);
                try t.expectEqual(@as(u64, if (command == .refresh) 6 else 5), actual.refresh);
            } else try t.expectError(if (state == .retired) error.DataflowRetired else error.InvalidDataflowTransition, previous.apply(command));
        }
    }
    const exhausted: f.Control = .{ .state = .active, .epoch = std.math.maxInt(u64), .refresh = 0 };
    try t.expectError(error.Overflow, exhausted.apply(.suspend_computation));
}

test "suspend resume refresh definition replacement and worker replacement fence old candidates" {
    try lease.requireCurrent(target, active, 9);
    const suspended = try active.apply(.suspend_computation);
    try t.expectError(error.DataflowLeaseFenced, lease.requireCurrent(target, suspended, 9));
    const resumed = try suspended.apply(.resume_computation);
    try t.expectError(error.DataflowLeaseFenced, lease.requireCurrent(target, resumed, 9));
    try t.expectError(error.DataflowLeaseFenced, lease.requireCurrent(target, try active.apply(.refresh), 9));
    try t.expectError(error.DataflowLeaseFenced, lease.requireCurrent(target, active, 10));
    var replaced = target;
    replaced.digest[0] ^= 1;
    try t.expectError(error.DataflowLeaseFenced, lease.requireCurrent(replaced, active, 9));
}

test "dataflow coverage preserves independent LSN domains exact history and terminal evidence" {
    var interval: f.Coverage = .{ .from = source, .through = source, .complete = true };
    try interval.requireComplete(source); // A verified empty interval is complete.
    interval.through.position.next_lsn = 120;
    try interval.requireComplete(source);
    interval.complete = false;
    try t.expectError(error.IncompleteDataflowCoverage, interval.requireComplete(source));
    interval.complete = true;
    interval.from.position.next_lsn += 1;
    try t.expectError(error.DataflowCoverageGap, interval.requireComplete(source));
    interval.from = source;
    interval.through.position.partition += 1;
    try t.expectError(error.DataflowSourceChanged, interval.requireComplete(source));
    interval.through = source;
    interval.through.retention_owner.operation += 1;
    try t.expectError(error.DataflowSourceChanged, interval.requireComplete(source));
    interval.through = source;
    interval.through.interpretation.revision += 1;
    try t.expectError(error.DataflowSourceChanged, interval.requireComplete(source));
    interval.through = source;
    interval.through.position.next_lsn -= 1;
    try t.expectError(error.DataflowCoverageGap, interval.requireComplete(source));
}

test "dataflow saved control requires exact current definition and original attempt" {
    const attempt: f.ControlAttempt = .{ .definition = p.Growth.current_definition, .operation = operation, .target = target, .expected = active, .command = .retire };
    const encoded = try p.Json.valueAlloc(t.allocator, attempt);
    defer t.allocator.free(encoded);
    const parsed = try p.Json.parseFromSlice(f.ControlAttempt, t.allocator, encoded);
    defer parsed.deinit();
    try attempt.requireSame(parsed.value);
    var replaced = attempt;
    replaced.operation.operation += 1;
    try t.expectError(error.DataflowIdentityConflict, attempt.requireSame(replaced));
    replaced = attempt;
    replaced.target.revision += 1;
    try t.expectError(error.DataflowIdentityConflict, attempt.requireSame(replaced));
    const first_comma = std.mem.indexOfScalar(u8, encoded, ',').?;
    const missing = try std.fmt.allocPrint(t.allocator, "{{{s}", .{encoded[first_comma + 1 ..]});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(f.ControlAttempt, t.allocator, missing));
    const foreign = try t.allocator.dupe(u8, encoded);
    defer t.allocator.free(foreign);
    const definition_start = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    foreign[definition_start] = if (foreign[definition_start] == '0') '1' else '0';
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(f.ControlAttempt, t.allocator, foreign));
}

test "dataflow completion requires the committed common decision not a participant or caller tag" {
    const content: d.Content = .{ .bytes = 100, .sha256 = @splat(5) };
    var decided: p.Transaction.Decision = .{
        .attempt = .{
            .definition = p.Growth.current_definition,
            .transaction = .{ .begin = operation, .branch = 1 },
            .operation = .{ .scope = scope, .principal = 0, .operation = 43 },
            .cut = content,
            .workspace = content,
            .participants = .{ .content = content, .count = 2 },
            .writes = 2,
            .last_statement = 3,
        },
        .outcome = .committed,
        .prepared = .{ .content = content, .count = 2 },
        .position = .{ .partition = 19, .next_lsn = 7 },
        .coordinator_epoch = 8,
        .policy_epoch = 10,
    };
    const completion: f.Completion = .{
        .candidate = .{ .definition = p.Growth.current_definition, .lease = lease, .operation = operation, .previous_revision = 0, .sources = .{ .content = content, .count = 10_003 }, .result = content, .rows = 0 },
        .transaction = decided.attempt.transaction,
        .decision = decided.position,
    };
    try completion.requireDecision(decided);
    decided.outcome = .aborted;
    try t.expectError(error.InvalidDataflowCompletion, completion.requireDecision(decided));
    decided.outcome = .committed;
    decided.position.partition = 17;
    try t.expectError(error.InvalidDataflowCompletion, completion.requireDecision(decided));
    decided.position = completion.decision;
    decided.prepared.count = 1;
    try t.expectError(error.InvalidTransactionDecision, completion.requireDecision(decided));
}
