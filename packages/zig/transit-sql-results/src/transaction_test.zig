const std = @import("std");
const r = @import("root.zig");
const p = r.protocol;
const x = p.Transaction;
const t = std.testing;
const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
const identity: x.Identity = .{ .begin = .{ .scope = scope, .principal = 4, .operation = 5 }, .branch = 1 };
const handle: x.Handle = .{ .definition = p.Growth.current_definition, .identity = identity, .account = @splat(1), .token = @splat(2), .audience = 6, .role = null };
const directory: x.Directory = .{ .content = .{ .sha256 = @splat(7), .bytes = 128 }, .count = 1 };
const cut: x.Cut = .{
    .begin = .{ .definition = p.Growth.current_definition, .identity = identity, .mode = .serializable, .selection = .authorized_catalog_tables, .objects = directory, .catalog = .{ .partition = 8, .next_lsn = 9 }, .limits = .{ .resident_bytes = 1024 * 1024, .workspace_bytes = 16 * 1024 * 1024, .participants = 10, .statements = 20, .savepoints = 3 } },
    .sources = directory,
    .acquired = .{ .partition = 8, .next_lsn = 10 },
};
fn completion(kind: r.Command, outcome: r.Outcome, evidence: @FieldType(r.Transaction, "evidence")) r.CommandCompletion {
    return .{ .kind = kind, .outcome = outcome, .counts = if (kind == .insert) .{ .matched = 2, .changed = 1 } else null, .operation = .{ .account = @splat(3), .id = 11, .kind = .transaction }, .pending_restart = false, .diagnostic = null, .transaction = .{ .handle = handle, .evidence = evidence } };
}
test "provisional SQL counts cannot claim commit or omit their transaction identity" {
    const statement: x.Statement = .{ .transaction = identity, .sequence = 1, .intent = @splat(12) };
    const original = completion(.insert, .provisional, .{ .statement = .{ .identity = statement, .refusal = null } });
    try original.validate();
    var wrong = original;
    wrong.outcome = .applied;
    try t.expectError(error.InvalidTransactionCompletion, wrong.validate());
    wrong = original;
    wrong.transaction = null;
    try t.expectError(error.InvalidCommandCompletion, wrong.validate());
    wrong = original;
    wrong.transaction.?.handle.identity.begin.operation += 1;
    try t.expectError(error.InvalidTransactionCompletion, wrong.validate());
    wrong = original;
    wrong.operation.?.kind = .table;
    try t.expectError(error.InvalidCommandCompletion, wrong.validate());
    wrong = original;
    wrong.outcome = .rejected;
    wrong.counts = .{ .matched = 0, .changed = 0 };
    wrong.transaction.?.evidence.statement.refusal = .duplicate_key;
    try wrong.validate();
    wrong.outcome = .provisional;
    try t.expectError(error.InvalidTransactionCompletion, wrong.validate());
}
test "SQL transaction controls distinguish acquired cuts, refusals and actual decisions" {
    try completion(.begin, .applied, .{ .begun = cut }).validate();
    try t.expectError(error.InvalidTransactionCompletion, completion(.commit, .applied, .{ .begun = cut }).validate());
    try completion(.savepoint, .applied, .{ .savepoint = .{ .sequence = 1, .operation = .{ .scope = scope, .principal = 4, .operation = 13 }, .accepted = .{ .partition = 8, .next_lsn = 14 }, .completed = .{ .partition = 8, .next_lsn = 15 } } }).validate();
    try completion(.rollback_to_savepoint, .rejected, .{ .refused = .control_conflict }).validate();
    var decision: x.Decision = .{
        .attempt = .{ .definition = p.Growth.current_definition, .transaction = identity, .operation = .{ .scope = scope, .principal = 4, .operation = 16 }, .cut = directory.content, .workspace = directory.content, .participants = directory, .writes = 1, .last_statement = 1 },
        .outcome = .committed,
        .prepared = directory,
        .position = .{ .partition = 17, .next_lsn = 2 },
        .coordinator_epoch = 1,
        .policy_epoch = 2,
    };
    try completion(.commit, .applied, .{ .decided = .{ .decision = decision, .cleanup_complete = false } }).validate();
    try completion(.rollback, .rejected, .{ .decided = .{ .decision = decision, .cleanup_complete = true } }).validate();
    try t.expectError(error.InvalidTransactionCompletion, completion(.rollback, .applied, .{ .decided = .{ .decision = decision, .cleanup_complete = true } }).validate());
    decision.outcome = .aborted;
    try completion(.commit, .rejected, .{ .decided = .{ .decision = decision, .cleanup_complete = false } }).validate();
}
test "private SQL read observations reject mixed transaction cuts and revisions" {
    var sources = [_]x.ReadView{.{
        .cut = cut,
        .revision = .{ .partition = 8, .next_lsn = 18 },
        .last_statement = 1,
        .source = .{ .source = .{ .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 19 }, .revision = 1, .digest = @splat(20) }, .accepted = .{ .partition = 21, .next_lsn = 5 } }, .changed_lsn = 4 },
        .private_position = .{ .partition = 21, .next_lsn = 7 },
        .private = .{ .sha256 = @splat(22), .bytes = 256 },
    }};
    const observation: r.Observation.Value = .{ .data = .{ .transaction = .{ .handle = handle, .cut = cut, .revision = sources[0].revision, .last_statement = 1, .sources = &sources } } };
    const before = try r.Observation.fingerprint(t.allocator, observation);
    sources[0].private_position.partition += 1;
    try t.expectError(error.InvalidTransactionRead, r.Observation.fingerprint(t.allocator, observation));
    sources[0].private_position.partition -= 1;
    sources[0].revision.next_lsn += 1;
    try t.expectError(error.InvalidTransactionObservation, r.Observation.fingerprint(t.allocator, observation));
    sources[0].revision.next_lsn -= 1;
    sources[0].cut.begin.catalog.next_lsn -= 1;
    try t.expectError(error.InvalidTransactionObservation, r.Observation.fingerprint(t.allocator, observation));
    sources[0].cut = cut;
    sources[0].private.sha256[0] ^= 1;
    try t.expect(!std.mem.eql(u8, &before, &(try r.Observation.fingerprint(t.allocator, observation))));
}
