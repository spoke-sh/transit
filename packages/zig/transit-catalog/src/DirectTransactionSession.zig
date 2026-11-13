//! Shared caller lifecycle over the database transaction owner. The journal
//! retains exact requests before dispatch; it is storage, never an authority.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const Tx = c.DirectTransactionClient;
const W = c.DirectTransactionWorkspace;
const Self = @This();

pub const State = struct {
    begin: c.DirectTransactionRequest.Begin,
    settlement: d.Operation,
    last_statement: u64 = 0,
    statement: ?W.StatementWork = null,
    last_control: u64 = 0,
    control: ?c.DirectTransactionSavepoint.Request = null,
    command: ?c.DirectTransactionControl.Command = null,

    pub fn validate(self: State) !void {
        try self.begin.validate();
        try self.begin.key.connection.owner(self.settlement);
        if (std.meta.eql(self.begin.operation, self.settlement) or
            self.last_statement > self.begin.limits.statements or self.last_control > self.begin.limits.statements or
            (self.statement != null and self.control != null)) return error.InvalidTransactionSession;
        const identity: p.Transaction.Identity = .{ .begin = self.begin.operation, .branch = self.begin.key.connection.branch };
        if (self.statement) |work| {
            try work.validate();
            const value = work.statement();
            const operation = switch (work) {
                .state => |request| request.binding.identity,
                .log => |request| request.work.operation(),
            };
            if (std.meta.eql(operation, self.settlement) or !std.meta.eql(value.transaction, identity) or value.sequence != try std.math.add(u64, self.last_statement, 1) or
                value.sequence > self.begin.limits.statements) return error.InvalidTransactionSession;
        }
        if (self.control) |value| {
            try value.validate();
            if (std.meta.eql(value.operation, self.settlement) or !std.meta.eql(value.transaction, identity) or value.sequence != try std.math.add(u64, self.last_control, 1) or
                value.sequence > self.begin.limits.statements) return error.InvalidTransactionSession;
        }
    }
};

pub const Event = enum { original, statement, statement_complete, control, control_complete, settlement };
/// Receives the previous and proposed state; reject a stale previous basis.
/// Must durably retain the proposed state before returning. A failed save prevents dispatch
/// or cursor advancement. Callbacks may not reenter this session. Begin's target
/// slice belongs to the caller and must outlive the session and its callbacks.
pub const Journal = struct {
    context: *anyopaque,
    save: *const fn (*anyopaque, State, State, Event) anyerror!void,
};
pub const Write = union(enum) {
    table: c.DirectTableIntent.Work,
    kv: c.DirectKV.Mutation,
    log: struct { work: c.DirectTransactionLogWork.Work, payload: ?c.DirectTableProtocol.Binary = null },
    fn operation(self: Write) d.Operation {
        return switch (self) {
            .table => |value| value.binding().identity,
            .kv => |value| value.binding.identity,
            .log => |value| value.work.operation(),
        };
    }
};
pub const Action = union(enum) {
    begin,
    acquire,
    inspect,
    write: Write,
    advance: u16,
    savepoint: struct { operation: d.Operation, action: @FieldType(c.DirectTransactionSavepoint.Request, "action"), steps: u16 = 8 },
    settle: struct { command: c.DirectTransactionControl.Command, steps: u16 = 8 },
    /// Native execution-bound recovery fences the original activation. Ordinary
    /// callers resume their saved request or explicitly settle the original ID.
    recover: struct { steps: u16 = 8, close_input: bool = false },

    pub fn control(self: Action) bool {
        return switch (self) {
            .inspect, .settle, .recover => true,
            else => false,
        };
    }
};
pub const Result = union(enum) {
    begun: c.DirectClientToken.Receipt,
    acquired: c.DirectTransaction.Acquired,
    status: c.DirectTransactionControl.Status,
    statement: W.StatementCompletion,
    savepoint: c.DirectTransactionSavepoint.Result,
    recovered: ?c.DirectTransactionRequest.Recovery,
    /// A verified completion survives a failure to checkpoint local progress.
    /// The saved pending request remains the only permitted resume identity.
    checkpoint_failed: struct {
        cause: anyerror,
        completion: union(enum) { statement: W.StatementCompletion, savepoint: c.DirectTransactionSavepoint.Result },
    },
};

state: *State,
journal: Journal,

fn checkpoint(self: Self, next: State, event: Event) !void {
    try next.validate();
    try self.journal.save(self.journal.context, self.state.*, next, event);
    self.state.* = next;
}
fn ready(self: Self, client: c.DirectTableClient) !c.DirectTransactionControl.Status {
    if (self.state.statement != null or self.state.control != null) return error.TransactionSessionPending;
    if (self.state.command != null) return error.TransactionSessionSettling;
    const status = try (Tx{ .catalog = client }).inspect(self.state.begin.key);
    try writable(status);
    if (status.last_statement != self.state.last_statement or status.last_control != self.state.last_control)
        return error.TransactionSessionChanged;
    return status;
}
pub fn apply(self: Self, client: c.DirectTableClient, action: Action) !Result {
    try self.state.validate();
    const tx: Tx = .{ .catalog = client };
    const key = self.state.begin.key;
    switch (action) {
        .begin => {
            try self.checkpoint(self.state.*, .original);
            return .{ .begun = try tx.begin(self.state.begin) };
        },
        .acquire => return .{ .acquired = try tx.acquire(key) },
        .inspect => return .{ .status = try tx.inspect(key) },
        .write => |work| {
            if (std.meta.eql(work.operation(), self.state.settlement)) return error.TransactionIdentityConflict;
            const status = try self.ready(client);
            var next = self.state.*;
            next.statement = try prepare(client, key, status, work);
            try self.checkpoint(next, .statement);
            return self.resumePending(client, 8);
        },
        .advance => |steps| return self.resumePending(client, steps),
        .savepoint => |value| {
            try stepsValid(value.steps);
            if (std.meta.eql(value.operation, self.state.settlement)) return error.TransactionIdentityConflict;
            const status = try self.ready(client);
            var next = self.state.*;
            next.control = try prepareSavepoint(status, value.operation, value.action);
            try self.checkpoint(next, .control);
            return self.resumePending(client, value.steps);
        },
        .settle => |value| {
            try stepsValid(value.steps);
            // An abort may close uncertain work. A commit must first observe
            // the saved statement/control result; it cannot skip that prefix.
            if (value.command == .commit and (self.state.statement != null or self.state.control != null))
                return error.TransactionSessionPending;
            if (self.state.command == .abort and value.command == .commit) return error.TransactionSessionSettling;
            var next = self.state.*;
            next.command = value.command;
            try self.checkpoint(next, .settlement);
            return .{ .status = try tx.settle(key, self.state.settlement, value.command, value.steps) };
        },
        .recover => |value| {
            try stepsValid(value.steps);
            return .{ .recovered = try tx.recover(.{ .key = key, .execution = self.state.begin.execution orelse return error.TransactionExecutionRequired, .work = .{ .settle = .{ .operation = self.state.settlement, .steps = value.steps } }, .close_input = value.close_input }) };
        },
    }
}
fn resumePending(self: Self, client: c.DirectTableClient, steps: u16) !Result {
    try stepsValid(steps);
    const tx: Tx = .{ .catalog = client };
    const key = self.state.begin.key;
    if (self.state.command) |command|
        return .{ .status = try tx.settle(key, self.state.settlement, command, steps) };
    if (self.state.statement) |work| {
        const result = try execute(client, key, work);
        var next = self.state.*;
        next.last_statement = work.statement().sequence;
        next.statement = null;
        self.checkpoint(next, .statement_complete) catch |err|
            return .{ .checkpoint_failed = .{ .cause = err, .completion = .{ .statement = result } } };
        return .{ .statement = result };
    }
    if (self.state.control) |request| {
        const result = try tx.savepoint(key, request, steps);
        if (result.completed != null) {
            var next = self.state.*;
            next.last_control = request.sequence;
            next.control = null;
            self.checkpoint(next, .control_complete) catch |err|
                return .{ .checkpoint_failed = .{ .cause = err, .completion = .{ .savepoint = result } } };
        }
        return .{ .savepoint = result };
    }
    return error.TransactionSessionIdle;
}
fn stepsValid(steps: u16) !void {
    if (steps == 0 or steps > 256) return error.InvalidTransactionSteps;
}

/// Shared preparation also serves hosts whose original request is retained by
/// the service (SQL commands and managed program continuations).
pub fn writable(status: c.DirectTransactionControl.Status) !void {
    if (!status.acquired) return error.TransactionCutNotAcquired;
    if (status.attempt != null) return error.TransactionFrozen;
    if (status.pending_statement or status.pending_control) return error.TransactionSessionPending;
}
pub fn prepare(client: c.DirectTableClient, key: c.DirectClientToken.Key, status: c.DirectTransactionControl.Status, work: Write) !W.StatementWork {
    try writable(status);
    if (status.begin.mode == .read_only) return error.ReadOnlyTransaction;
    if (status.last_statement >= status.begin.limits.statements) return error.TransactionStatementLimit;
    const tx: Tx = .{ .catalog = client };
    const sequence = try std.math.add(u64, status.last_statement, 1);
    return switch (work) {
        .table => |value| .{ .state = try tx.stage(key, status.revision, sequence, value) },
        .kv => |value| .{ .state = try tx.stageKV(key, status.revision, sequence, value) },
        .log => |value| .{ .log = try tx.stageLog(key, status.revision, sequence, value.work, value.payload) },
    };
}
pub fn prepareSavepoint(status: c.DirectTransactionControl.Status, operation: d.Operation, action: @FieldType(c.DirectTransactionSavepoint.Request, "action")) !c.DirectTransactionSavepoint.Request {
    try writable(status);
    if (status.last_control >= status.begin.limits.statements or (action == .create and status.savepoints >= status.begin.limits.savepoints))
        return error.TransactionSavepointLimit;
    const request: c.DirectTransactionSavepoint.Request = .{ .transaction = status.begin.identity, .operation = operation, .sequence = try std.math.add(u64, status.last_control, 1), .basis = status.revision, .action = action };
    try request.validate();
    return request;
}
pub fn privateClient(client: c.DirectTableClient, key: c.DirectClientToken.Key) !c.DirectTableClient {
    if (!std.meta.eql(client.connection, key.connection)) return error.CatalogIdentityConflict;
    const status = try (Tx{ .catalog = client }).inspect(key);
    try writable(status);
    var result = client;
    result.transaction = .{ .key = key, .revision = status.revision };
    return result;
}
pub fn execute(client: c.DirectTableClient, key: c.DirectClientToken.Key, work: W.StatementWork) !W.StatementCompletion {
    try work.validate();
    const tx: Tx = .{ .catalog = client };
    const result: W.StatementCompletion = switch (work) {
        .state => |request| .{ .state = .{ .request = request, .outcome = try tx.execute(key, request) } },
        .log => |request| .{ .log = .{ .request = request, .outcome = try tx.executeLog(key, request) } },
    };
    try result.validate();
    return result;
}
