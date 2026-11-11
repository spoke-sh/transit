//! SQL commands retain their exact native transaction request in Catalog before
//! execution. Recovery uses that reference, never SQL text or a replacement ID.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const x = p.Transaction;
const d = p.DataLifecycle;
const Call = c.DirectTransactionCall;
const Native = c.DirectTransactionClient;

pub const Request = union(enum) {
    begin: x.Mode,
    statement: struct { handle: x.Handle, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom },
    savepoint: struct { handle: x.Handle, action: @FieldType(c.DirectTransactionSavepoint.Request, "action") },
    settle: struct { handle: x.Handle, command: c.DirectTransactionControl.Command },
};

pub fn key(attachment: x.Handle) !c.DirectClientToken.Key {
    try attachment.validate();
    return .{ .definition = p.Growth.current_definition, .connection = .{ .scope = attachment.identity.begin.scope, .branch = attachment.identity.branch, .audience = attachment.audience, .principal = attachment.identity.begin.principal, .role = attachment.role }, .account = attachment.account, .token = attachment.token };
}
pub fn handle(value: c.DirectClientToken.Key, identity: x.Identity) !x.Handle {
    try value.validate();
    try value.connection.owner(identity.begin);
    const result: x.Handle = .{ .definition = p.Growth.current_definition, .identity = identity, .account = value.account, .token = value.token, .audience = value.connection.audience, .role = value.connection.role };
    try result.validate();
    return result;
}
pub fn command(call: Call) g.results.Command {
    return switch (call.work) {
        .begin => .begin,
        .statement => |work| if (work.kv_command) |kv_cmd| switch (kv_cmd) {
            .put => .put,
            .delete => .delete,
        } else switch (work.request.binding.action) {
            .insert => .insert,
            .update => .update,
            .delete => .delete,
            else => unreachable,
        },
        .log_statement => |work| switch (work.request.work) {
            .append => |append| if (append.kind == .stream) .produce else .enqueue,
            .stream_offset => .commit_offset,
            .queue_ack => .ack,
            .queue_transfer => unreachable,
        },
        .savepoint => |work| switch (work.request.action) {
            .create => .savepoint,
            .release => .release_savepoint,
            .rollback => .rollback_to_savepoint,
        },
        .settle => |work| if (work.command == .commit) .commit else .rollback,
    };
}
fn randomOperation(io: std.Io, connection: c.DirectTableProtocol.Connection) !d.Operation {
    var bytes: [8]u8 = undefined;
    try io.randomSecure(&bytes);
    return .{ .scope = connection.scope, .principal = connection.principal, .operation = (std.mem.readInt(u64, &bytes, .little) % p.max_counter) + 1 };
}
/// Build only after looking up the original SQL token. Staging does not admit a
/// native statement; the caller must retain this complete value before dispatch.
pub fn build(allocator: std.mem.Allocator, io: std.Io, config: g.DatabaseAccount.Configuration, caller: c.DirectTableClient, namespace: u64, token: [16]u8, fingerprint: [32]u8, request: Request) !Call {
    const native: Native = .{ .catalog = caller };
    const outer = try randomOperation(io, caller.connection);
    var operation = try randomOperation(io, caller.connection);
    while (operation.operation == outer.operation) operation = try randomOperation(io, caller.connection);
    var result: Call = .{ .connection = caller.connection, .namespace = namespace, .operation = outer.operation, .work = undefined };
    switch (request) {
        .begin => |mode| {
            result.work = .{ .begin = .{
                .key = .{ .definition = p.Growth.current_definition, .connection = caller.connection, .account = g.AccountIdentity.internal(config.account, "transactions", ""), .token = token },
                .fingerprint = fingerprint,
                .operation = operation,
                .mode = mode,
                .limits = config.transaction_limits,
                .budget = config.budget(config.reservation()),
            } };
        },
        inline .statement, .savepoint, .settle => |value, tag| {
            const owner = try key(value.handle);
            if (!std.meta.eql(owner.connection, caller.connection)) return error.CatalogIdentityConflict;
            const current = try native.inspect(owner);
            if (!std.meta.eql(current.begin.identity, value.handle.identity)) return error.TransactionIdentityConflict;
            if (comptime tag == .settle) {
                // An unresolved COMMIT and a later explicit ROLLBACK address
                // the same attempt. The recorded decision always wins the race.
                result.work = .{ .settle = .{ .key = owner, .operation = if (current.attempt) |attempt| attempt.operation else operation, .command = value.command } };
            } else {
                if (current.attempt != null or !current.acquired) return error.SqlTransactionClosed;
                if (current.pending_statement or current.pending_control) return error.SqlTransactionPending;
                if (comptime tag == .savepoint) {
                    if (current.last_control >= current.begin.limits.statements or
                        (value.action == .create and current.savepoints >= current.begin.limits.savepoints)) return error.SqlTransactionLimit;
                    result.work = .{ .savepoint = .{ .key = owner, .request = .{ .transaction = value.handle.identity, .operation = operation, .sequence = try std.math.add(u64, current.last_control, 1), .basis = current.revision, .action = value.action } } };
                } else {
                    switch (value.statement.plan) {
                        .dml, .kv_write, .log_offset => {},
                        .log_append => if (value.statement.output != null) return error.UnsupportedTransactionStatement,
                        .log_settlement => if (value.statement.kind() != .ack) return error.UnsupportedTransactionStatement,
                        else => return error.UnsupportedTransactionStatement,
                    }
                    if (current.begin.mode == .read_only) return error.ReadOnlyTransaction;
                    if (current.last_statement >= current.begin.limits.statements) return error.SqlTransactionLimit;
                    var private = caller;
                    private.transaction = .{ .key = owner, .revision = current.revision };
                    var write = try value.statement.bindWrite(allocator, &private, value.values, operation.operation);
                    defer write.deinit();
                    if (try write.workBytes() > config.intent_bytes) return error.GatewayRecordTooLarge;
                    const next_sequence = try std.math.add(u64, current.last_statement, 1);
                    switch (write) {
                        .table => |table| result.work = .{ .statement = .{ .key = owner, .request = try native.stage(owner, current.revision, next_sequence, table.parsed.value.work) } },
                        .kv => |kv| {
                            const kv_cmd: Call.KVCommand = switch (kv.parsed.value.work) {
                                .put => .put,
                                .delete => .delete,
                                .ddl => return error.UnsupportedTransactionStatement,
                            };
                            result.work = .{ .statement = .{ .key = owner, .kv_command = kv_cmd, .request = try native.stageKV(owner, current.revision, next_sequence, kv.parsed.value.work.mutation().?) } };
                        },
                        .workload => |workload| {
                            if (workload.parsed.value.projection != null or workload.parsed.value.wait_ms != null) return error.UnsupportedTransactionStatement;
                            var payload: ?c.DirectTableProtocol.Binary = null;
                            const log_work: c.DirectTransactionLogWork.Work = switch (workload.parsed.value.work) {
                                .stream => |stream| switch (stream.work) {
                                    .append => |append| blk: {
                                        payload = stream.payload;
                                        break :blk .{ .append = append };
                                    },
                                    .offset => |offset| .{ .stream_offset = offset },
                                    else => return error.UnsupportedTransactionStatement,
                                },
                                .queue => |queue| switch (queue.work) {
                                    .enqueue => |enqueue| blk: {
                                        payload = queue.payload;
                                        break :blk .{ .append = enqueue };
                                    },
                                    .settle => |settle| if (settle.action == .ack) .{ .queue_ack = settle } else return error.UnsupportedTransactionStatement,
                                    else => return error.UnsupportedTransactionStatement,
                                },
                            };
                            result.work = .{ .log_statement = .{ .key = owner, .request = try native.stageLog(owner, current.revision, next_sequence, log_work, payload) } };
                        },
                        else => return error.UnsupportedTransactionStatement,
                    }
                }
            }
        },
    }
    try result.validate();
    return result;
}
pub fn advance(caller: c.DirectTableClient, state: c.DirectClientToken.Progress, cancel: bool) !?Call.Result {
    if (state.receipt.binding.intent != .transaction_call) return error.TransactionOperationRequired;
    const call = state.receipt.binding.intent.transaction_call;
    const native: Native = .{ .catalog = caller };
    const result = try native.advanceCall(state.receipt.binding.key, 8, call.work == .settle, cancel);
    if (result) |value| try value.requireCall(call);
    return result;
}
pub fn status(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !g.session_protocol.Operation {
    const native: Native = .{ .catalog = caller };
    return project(caller, state, try native.callOutcome(state.receipt.binding.key));
}
pub fn project(caller: c.DirectTableClient, state: c.DirectClientToken.Progress, result: ?Call.Result) !g.session_protocol.Operation {
    if (state.receipt.binding.intent != .transaction_call) return error.TransactionOperationRequired;
    const call = state.receipt.binding.intent.transaction_call;
    var output: g.session_protocol.Operation = .{
        .identity = .{ .account = state.receipt.binding.key.account, .id = state.id(), .kind = .transaction },
        .command = command(call),
        .token = state.receipt.binding.key.token,
        .phase = .ready,
        .cancellation_requested = state.cancel,
    };
    const value = result orelse {
        if (!state.pending) return error.MissingGatewayTerminal;
        return output;
    };
    try value.requireCall(call);
    const identity: x.Identity = switch (call.work) {
        .begin => |work| .{ .begin = work.operation, .branch = call.connection.branch },
        .statement => |work| work.request.statement.transaction,
        .log_statement => |work| work.request.statement.transaction,
        .savepoint => |work| work.request.transaction,
        .settle => |work| if (value == .settled) value.settled.begin.identity else (try (Native{ .catalog = caller }).inspect(work.key)).begin.identity,
    };
    var attribution: g.results.Transaction = .{ .handle = try handle(call.key(), identity), .evidence = undefined };
    output.phase = .terminal;
    switch (value) {
        .rejected => |reason| {
            attribution.evidence = .{ .refused = reason };
            output.outcome = .rejected;
        },
        .begun => |cut| {
            attribution.evidence = .{ .begun = cut };
            output.outcome = .applied;
        },
        .statement => |outcome| switch (outcome) {
            .provisional => |row| {
                attribution.evidence = .{ .statement = .{ .identity = row.statement, .refusal = null } };
                output.outcome = .provisional;
                output.matched = row.matched;
                output.changed = row.affected;
            },
            .rejected => |row| {
                attribution.evidence = .{ .statement = .{ .identity = row.statement, .refusal = std.meta.stringToEnum(g.results.Transaction.StatementRefusal, @tagName(row.reason)) orelse return error.InvalidTransactionCompletion } };
                output.outcome = .rejected;
            },
        },
        .log_statement => |outcome| switch (outcome) {
            .provisional => |row| {
                attribution.evidence = .{ .statement = .{ .identity = row.statement, .refusal = null } };
                output.outcome = .provisional;
                if (row.proposed == .append) {
                    output.matched = row.proposed.append.rows;
                    output.changed = row.proposed.append.rows;
                }
            },
            .rejected => |row| {
                attribution.evidence = .{ .statement = .{ .identity = row.statement, .refusal = std.meta.stringToEnum(g.results.Transaction.StatementRefusal, @tagName(row.reason)) orelse return error.InvalidTransactionCompletion } };
                output.outcome = .rejected;
            },
        },
        .savepoint => |saved| {
            attribution.evidence = .{ .savepoint = .{ .sequence = saved.request.sequence, .operation = saved.request.operation, .accepted = saved.accepted, .completed = saved.completed.? } };
            output.outcome = .applied;
        },
        .settled => |settled| {
            attribution.evidence = .{ .decided = .{ .decision = settled.observation.decided, .cleanup_complete = settled.cleanup_complete } };
            output.outcome = if ((call.work.settle.command == .commit) == (settled.observation.decided.outcome == .committed)) .applied else .rejected;
        },
    }
    output.transaction = attribution;
    try output.validate();
    return output;
}
