//! Temporary SQL attachment. Catalog owns admission, sequencing and decisions;
//! this state only prevents a connection from starting unrelated uncertain work.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const x = c.protocol.Transaction;
const Work = g.database.TransactionWork;
const Native = c.DirectTransactionClient;
pub const State = struct {
    handle: ?x.Handle = null,
    pending: ?g.DatabaseRuntime.TransactionSubmission = null,
    failed: bool = false,
    pub fn active(self: State) bool {
        return self.handle != null or self.pending != null;
    }
};
/// A rejected settlement still carries the original durable decision. Never
/// label an already committed transaction as a serialization abort: a caller
/// could otherwise retry the transaction and duplicate its committed work.
pub fn decisionDiagnostic(outcome: @FieldType(x.Decision, "outcome")) struct { [5]u8, []const u8 } {
    return switch (outcome) {
        .committed => .{ "25000".*, "The transaction already committed; ROLLBACK cannot reverse its original decision" },
        .aborted => .{ "40001".*, "The transaction aborted; inspect its original decision" },
    };
}

test "rejected rollback preserves a committed decision without an abort SQLSTATE" {
    const committed = decisionDiagnostic(.committed);
    try std.testing.expectEqualStrings("25000", &committed[0]);
    try std.testing.expect(std.mem.indexOf(u8, committed[1], "already committed") != null);
    const aborted = decisionDiagnostic(.aborted);
    try std.testing.expectEqualStrings("40001", &aborted[0]);
    try std.testing.expect(std.mem.indexOf(u8, aborted[1], "aborted") != null);
}

pub fn native(host: *g.Session) Native {
    return .{ .catalog = host.table };
}
/// The current command starts with an ordinary authorization check. A private
/// context is installed only for reads and DML compilation at this exact head.
pub fn refresh(host: *g.Session) !void {
    host.table.transaction = null;
    const attachment = host.transaction.handle orelse return;
    if (host.transaction.failed) return error.SqlTransactionFailed;
    const owner = try Work.key(attachment);
    const current = try native(host).inspect(owner);
    if (!std.meta.eql(current.begin.identity, attachment.identity)) return error.TransactionIdentityConflict;
    if (current.attempt != null or !current.acquired) return error.SqlTransactionClosed;
    if (current.pending_statement or current.pending_control) return error.SqlTransactionPending;
    host.table.transaction = .{ .key = owner, .revision = current.revision };
}
pub fn attach(host: *g.Session, attachment: x.Handle) !void {
    try host.current();
    const owner = try Work.key(attachment);
    if (!std.meta.eql(owner.connection, host.table.connection)) return error.CatalogIdentityConflict;
    if (host.transaction.active()) return error.SqlTransactionActive;
    const current = try native(host).inspect(owner);
    if (!std.meta.eql(current.begin.identity, attachment.identity)) return error.TransactionIdentityConflict;
    if (current.observation == .decided) return error.SqlTransactionClosed;
    if (!current.acquired) return error.SqlTransactionPending;
    host.transaction.handle = attachment;
    // A prepared decision can only be inspected/resolved, not accept more SQL.
    host.transaction.failed = current.attempt != null or current.pending_statement or current.pending_control;
}
pub fn require(host: *g.Session, prepared: *const g.Session.Prepared) !void {
    if (host.transaction.pending != null) return error.SqlTransactionPending;
    if (prepared.* == .transaction) {
        if (host.source != null) return error.UnsupportedTransactionStatement;
        if (prepared.transaction == .begin) {
            if (host.transaction.handle != null) return error.SqlTransactionActive;
        } else {
            if (host.transaction.handle == null) return error.SqlTransactionRequired;
            if (host.transaction.failed and prepared.transaction != .rollback and prepared.transaction != .rollback_to_savepoint) return error.SqlTransactionFailed;
        }
        return;
    }
    if (host.transaction.handle == null) return;
    if (host.transaction.failed) return error.SqlTransactionFailed;
    switch (prepared.*) {
        .native => |statement| switch (statement.plan) {
            .select, .dml, .kv_get, .kv_write, .log_offset => {},
            .relational => for (statement.plan.relational.streams[0..statement.plan.relational.plan.sources.len]) |stream| if (stream != null) return error.UnsupportedTransactionStatement,
            .log_append => if (statement.output != null) return error.UnsupportedTransactionStatement,
            .log_settlement => if (statement.kind() != .ack) return error.UnsupportedTransactionStatement,
            else => return error.UnsupportedTransactionStatement,
        },
        .source, .captured, .workload, .managed, .connector => return error.UnsupportedTransactionStatement,
        .settings => |settings| if (settings.plan.statement == .reload or settings.plan.statement == .set or settings.plan.statement == .reset) return error.UnsupportedTransactionStatement,
        .probe => |probe| if (probe.kind == .set) return error.UnsupportedTransactionStatement,
        .inspection => {},
        .transaction => unreachable,
    }
}
pub fn request(host: *g.Session, prepared: *const g.Session.Prepared, values: []const ?g.fuze.Types.Values.Atom) !Work.Request {
    try require(host, prepared);
    if (prepared.* == .transaction) return switch (prepared.transaction) {
        .begin => |mode| .{ .begin = mode },
        .commit => .{ .settle = .{ .handle = host.transaction.handle.?, .command = .commit } },
        .rollback => .{ .settle = .{ .handle = host.transaction.handle.?, .command = .abort } },
        .savepoint => |name| .{ .savepoint = .{ .handle = host.transaction.handle.?, .action = .{ .create = name } } },
        .release_savepoint => |name| .{ .savepoint = .{ .handle = host.transaction.handle.?, .action = .{ .release = name } } },
        .rollback_to_savepoint => |name| .{ .savepoint = .{ .handle = host.transaction.handle.?, .action = .{ .rollback = name } } },
    };
    if (prepared.* != .native or host.transaction.handle == null) return error.UnsupportedTransactionStatement;
    return .{ .statement = .{ .handle = host.transaction.handle.?, .statement = &prepared.native, .values = values } };
}
pub fn cleanupPending(operation: g.session_protocol.Operation) bool {
    if (operation.phase != .terminal) return false;
    const attribution = operation.transaction orelse return false;
    return attribution.evidence == .decided and !attribution.evidence.decided.cleanup_complete;
}
fn applyAdopted(
    state: *State,
    native_profile: bool,
    operation: g.session_protocol.Operation,
    completion: g.results.CommandCompletion,
    attribution: g.results.Transaction,
) void {
    const same = if (state.handle) |attached| std.meta.eql(attached, attribution.handle) else false;
    if (completion.kind != .begin and same) {
        if (attribution.evidence == .decided) {
            state.handle = null;
            state.failed = false;
        } else if (completion.outcome == .rejected) {
            state.failed = true;
        } else if (completion.kind == .rollback_to_savepoint) state.failed = false;
    }
    if (state.pending) |pending| {
        if (std.mem.eql(u8, &pending.token, &operation.token) and (native_profile or !cleanupPending(operation))) {
            state.pending = null;
        }
    }
}
/// Apply a verified result only on explicit execution/recovery in this session.
/// Status inspection alone never attaches a transaction to another connection.
pub fn adopt(host: *g.Session, operation: g.session_protocol.Operation) !void {
    if (operation.identity.kind != .transaction) return;
    if (operation.phase != .terminal) return;
    const completion = try operation.completion();
    const attribution = completion.transaction orelse return;
    if (completion.kind == .begin and completion.outcome == .applied and host.transaction.handle == null) {
        const current = try native(host).inspect(try Work.key(attribution.handle));
        if (!std.meta.eql(current.begin.identity, attribution.handle.identity)) return error.TransactionIdentityConflict;
        // Replaying an old BEGIN token returns its old result, but cannot open
        // another lifetime after the original transaction has already closed.
        if (current.observation != .decided) {
            host.transaction.handle = attribution.handle;
            host.transaction.failed = current.attempt != null;
        }
    }
    applyAdopted(&host.transaction, host.native_profile, operation, completion, attribution);
    host.table.transaction = null;
}
pub fn submit(host: *g.Session, prepared: *const g.Session.Prepared, values: []const ?g.fuze.Types.Values.Atom, token: [16]u8, fingerprint: [32]u8) !g.session_protocol.Operation {
    const work = try request(host, prepared, values);
    errdefer if (host.transaction.handle != null) {
        host.transaction.failed = true;
    };
    const result = try host.runtime.submitTransaction(host.allocator, &host.observer, &host.table, host.namespace, work, token, fingerprint, host.deadline, &host.operation, &host.transaction.pending);
    try adopt(host, result);
    return result;
}
/// Resume only the frozen command retained before its first possible admission.
/// No SQL is recompiled, and no accepted identity is replaced after a timeout.
pub fn reconcile(host: *g.Session) !void {
    while (host.transaction.pending) |pending| {
        const result = try host.runtime.resumeTransactionSubmission(&host.observer, host.table, pending, host.deadline, &host.operation);
        try adopt(host, result);
        if (host.transaction.pending != null) {
            if (!cleanupPending(result)) return error.SqlTransactionPending;
            try host.deadline.check(host.io);
            try host.runtime.waitProgress(2);
        }
    }
}
pub fn execute(host: *g.Session, prepared: *const g.Session.Prepared, values: []const ?g.fuze.Types.Values.Atom) !g.results.CommandCompletion {
    var token: [16]u8 = undefined;
    try host.io.randomSecure(&token);
    // Wire adapters cannot supply a client token; retain this generated token
    // before submission and report it if the command's observation is uncertain.
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.transaction.wire-command.v1\x00");
    hash.update(&token);
    var operation = try submit(host, prepared, values, token, hash.finalResult());
    while (operation.phase != .terminal or cleanupPending(operation)) {
        try host.deadline.check(host.io);
        const pending = host.transaction.pending orelse return error.SqlTransactionPending;
        try host.runtime.waitProgress(2);
        operation = try host.runtime.resumeTransactionSubmission(&host.observer, host.table, pending, host.deadline, &host.operation);
        try adopt(host, operation);
    }
    const completion = try operation.completion();
    host.transaction_completion = completion;
    if (completion.outcome == .rejected) return error.SqlTransactionRejected;
    try host.current();
    return completion;
}

test "wire settlement detaches decided handle while retaining pending token until cleanup_complete" {
    const t = std.testing;
    const scope: c.protocol.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const begin_op: c.protocol.DataLifecycle.Operation = .{ .scope = scope, .principal = 4, .operation = 5 };
    const settle_op: c.protocol.DataLifecycle.Operation = .{ .scope = scope, .principal = 4, .operation = 6 };
    const tx_id: x.Identity = .{ .begin = begin_op, .branch = 1 };
    const handle: x.Handle = .{
        .definition = c.protocol.Growth.current_definition,
        .identity = tx_id,
        .account = @splat(7),
        .token = @splat(8),
        .audience = 9,
        .role = 10,
    };
    const directory: x.Directory = .{ .content = .{ .sha256 = @splat(14), .bytes = 128 }, .count = 1 };
    const decision: x.Decision = .{
        .attempt = .{
            .definition = c.protocol.Growth.current_definition,
            .transaction = tx_id,
            .operation = settle_op,
            .cut = directory.content,
            .workspace = directory.content,
            .participants = directory,
            .writes = 1,
            .last_statement = 1,
        },
        .outcome = .committed,
        .prepared = directory,
        .position = .{ .partition = 17, .next_lsn = 2 },
        .coordinator_epoch = 1,
        .policy_epoch = 2,
    };
    const token: [16]u8 = @splat(11);
    const fingerprint: [32]u8 = @splat(12);
    const key = try Work.key(handle);
    const pending: g.DatabaseRuntime.TransactionSubmission = .{
        .token = token,
        .fingerprint = fingerprint,
        .call = .{
            .connection = key.connection,
            .namespace = 1,
            .operation = 13,
            .work = .{ .settle = .{ .key = key, .operation = settle_op, .command = .commit } },
        },
    };
    var operation: g.session_protocol.Operation = .{
        .identity = .{ .account = @splat(7), .id = 99, .kind = .transaction },
        .command = .commit,
        .token = token,
        .phase = .terminal,
        .outcome = .applied,
        .transaction = .{
            .handle = handle,
            .evidence = .{ .decided = .{ .decision = decision, .cleanup_complete = false } },
        },
    };
    try operation.validate();
    try t.expect(cleanupPending(operation));

    // Native SQL sessions return terminal decisions immediately with cleanup_complete = false.
    var native_state: State = .{ .handle = handle, .pending = pending, .failed = true };
    applyAdopted(&native_state, true, operation, try operation.completion(), operation.transaction.?);
    try t.expect(native_state.handle == null);
    try t.expect(!native_state.failed);
    try t.expect(native_state.pending == null);

    // PostgreSQL and MySQL wire sessions (native_profile = false) detach the decided handle
    // immediately, while retaining the original settle token until participant barriers release.
    var wire_state: State = .{ .handle = handle, .pending = pending, .failed = true };
    applyAdopted(&wire_state, false, operation, try operation.completion(), operation.transaction.?);
    try t.expect(wire_state.handle == null);
    try t.expect(!wire_state.failed);
    try t.expect(wire_state.pending != null);

    var cleaned = operation;
    cleaned.transaction = .{
        .handle = handle,
        .evidence = .{ .decided = .{ .decision = decision, .cleanup_complete = true } },
    };
    try cleaned.validate();
    try t.expect(!cleanupPending(cleaned));
    applyAdopted(&wire_state, false, cleaned, try cleaned.completion(), cleaned.transaction.?);
    try t.expect(wire_state.handle == null);
    try t.expect(wire_state.pending == null);
}
