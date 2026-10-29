const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const x = p.Transaction;

fn fixture() !std.json.Parsed(x.SchemaTypes) {
    return p.Json.parseFromSlice(x.SchemaTypes, t.allocator, @embedFile("fixtures/transaction-v1.json"));
}

test "transaction fixture preserves scoped identities and distinct log positions" {
    const parsed = try fixture();
    defer parsed.deinit();
    const value = parsed.value;
    try value.begin.validate();
    try value.cut.validate();
    try value.participant.requireLocalTable(value.begin);
    try value.statement.validate();
    try value.prepared.validate();
    try value.observation.validate();
    try t.expectEqual(std.math.maxInt(u64), value.begin.identity.begin.operation);
    try t.expectEqual(@as(u64, 3), value.begin.catalog.partition);
    try t.expectEqual(@as(u64, 9), value.prepared.position.partition);
    try t.expectEqual(@as(u64, 4), value.observation.decided.position.partition);
    try value.observation.decided.requireAttempt(value.prepared.attempt);
}

test "transaction whole Table guard rejects phantoms and definition changes but permits maintenance" {
    const parsed = try fixture();
    defer parsed.deinit();
    const basis = parsed.value.participant.state.guard;
    var current = basis;
    current.source.accepted.next_lsn += 8;
    try basis.requireUnchanged(current);
    // Any logical write, including outside a predicate's returned rows, conflicts.
    current.changed_lsn = current.source.accepted.next_lsn;
    try t.expectError(error.TransactionConflict, basis.requireUnchanged(current));
    current = basis;
    current.source.interpretation.revision += 1;
    try t.expectError(error.TransactionConflict, basis.requireUnchanged(current));
    current = basis;
    current.source.interpretation.digest[0] ^= 1;
    try t.expectError(error.TransactionConflict, basis.requireUnchanged(current));
    current = basis;
    current.source.accepted.partition += 1;
    try t.expectError(error.TransactionConflict, basis.requireUnchanged(current));
    current = basis;
    current.changed_lsn -= 1;
    try t.expectError(error.TransactionConflict, basis.requireUnchanged(current));
}

test "transaction cuts cannot claim incomplete coverage or silently change scope" {
    const parsed = try fixture();
    defer parsed.deinit();
    var cut = parsed.value.cut;
    cut.sources.count -= 1;
    try t.expectError(error.IncompleteTransactionCut, cut.validate());
    var begin = parsed.value.begin;
    begin.tables.count = begin.limits.participants + 1;
    try t.expectError(error.InvalidTransactionBegin, begin.validate());
    begin = parsed.value.begin;
    begin.selection = .authorized_catalog_tables;
    try t.expectError(error.TransactionIdentityConflict, parsed.value.begin.requireSame(begin));
    begin = parsed.value.begin;
    begin.identity.branch = 2;
    try t.expectError(error.UnsupportedTransactionDomain, begin.validate());
    var participant = parsed.value.participant;
    participant.state.guard.source.interpretation.object.scope.catalog += 1;
    try t.expectError(error.TransactionIdentityConflict, participant.requireLocalTable(parsed.value.begin));
}

test "transaction logical guards reject snapshot coverage fields" {
    const parsed = try fixture();
    defer parsed.deinit();
    const guard = parsed.value.participant.state.guard;
    const bytes = try p.Json.valueAlloc(t.allocator, guard);
    defer t.allocator.free(bytes);
    const at = std.mem.indexOf(u8, bytes, "\"source\":{").? + "\"source\":{".len;
    const former_shape = try std.fmt.allocPrint(t.allocator, "{s}\"manifest\":null,\"checkpoint_lsn\":0,{s}", .{ bytes[0..at], bytes[at..] });
    defer t.allocator.free(former_shape);
    try t.expectError(error.UnknownField, p.Json.parseFromSlice(x.TableGuard, t.allocator, former_shape));
}

test "transaction participant vocabulary does not enable unsupported owners" {
    const parsed = try fixture();
    defer parsed.deinit();
    const begin = parsed.value.begin;
    var participant = parsed.value.participant;
    participant.state.kind = .kv;
    try t.expectError(error.UnsupportedTransactionParticipant, participant.requireLocalTable(begin));
    participant.state.kind = .document;
    try t.expectError(error.UnsupportedTransactionParticipant, participant.requireLocalTable(begin));
    const object = participant.state.guard.source.interpretation.object;
    participant = .{ .append = .{ .object = object, .kind = .queue, .intent = begin.tables.content } };
    try participant.validate(begin.identity);
    try t.expectError(error.UnsupportedTransactionParticipant, participant.requireLocalTable(begin));
    participant = .{ .settlement = .{ .object = object, .kind = .queue_ack, .lease_epoch = 7, .intent = begin.tables.content } };
    try participant.validate(begin.identity);
    try t.expectError(error.UnsupportedTransactionParticipant, participant.requireLocalTable(begin));
    participant.settlement.lease_epoch = 0;
    try t.expectError(error.InvalidTransactionGuard, participant.validate(begin.identity));
    var readonly = begin;
    readonly.mode = .read_only;
    try t.expectError(error.ReadOnlyTransaction, parsed.value.participant.requireLocalTable(readonly));
    participant = parsed.value.participant;
    participant.state.access = .read;
    try participant.requireLocalTable(readonly);
}

test "transaction decisions bind the original complete attempt across lost replies" {
    const parsed = try fixture();
    defer parsed.deinit();
    const decision = parsed.value.observation.decided;
    var attempt = decision.attempt;
    attempt.workspace.sha256[0] ^= 1;
    try t.expectError(error.TransactionIdentityConflict, decision.requireAttempt(attempt));
    attempt = decision.attempt;
    attempt.operation.operation += 1;
    try t.expectError(error.TransactionIdentityConflict, decision.requireAttempt(attempt));
    attempt = decision.attempt;
    attempt.participants.content.sha256[0] ^= 1;
    try t.expectError(error.TransactionIdentityConflict, decision.requireAttempt(attempt));
    var incomplete = decision;
    incomplete.prepared.count -= 1;
    try t.expectError(error.InvalidTransactionDecision, incomplete.validate());
    incomplete.outcome = .aborted;
    try incomplete.validate();
    incomplete.prepared.count = incomplete.attempt.writes + 1;
    try t.expectError(error.InvalidTransactionDecision, incomplete.validate());
    var wrong = parsed.value.prepared;
    wrong.position.partition += 1;
    try t.expectError(error.InvalidTransactionPreparation, wrong.validate());
    wrong = parsed.value.prepared;
    wrong.position = wrong.predecessor.source.accepted;
    try t.expectError(error.InvalidTransactionPreparation, wrong.validate());
}

test "transaction recovery material requires exact current definition" {
    const parsed = try fixture();
    defer parsed.deinit();
    const bytes = try p.Json.valueAlloc(t.allocator, parsed.value.prepared.attempt);
    defer t.allocator.free(bytes);
    const comma = std.mem.indexOfScalar(u8, bytes, ',').?;
    const missing = try std.fmt.allocPrint(t.allocator, "{{{s}", .{bytes[comma + 1 ..]});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(x.Attempt, t.allocator, missing));
    const foreign = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(foreign);
    const at = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    foreign[at] = if (foreign[at] == '0') '1' else '0';
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(x.Attempt, t.allocator, foreign));
}
