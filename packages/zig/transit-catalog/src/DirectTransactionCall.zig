//! A frozen caller command over the transaction owner. Binding its token admits
//! this exact call for recovery; the transaction's own records decide its work.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const Self = @This();
connection: c.DirectTableProtocol.Connection,
namespace: u64,
/// Caller-command identity, distinct from the operation executed by its owner.
operation: u64,
work: union(enum) {
    begin: struct { key: c.DirectClientToken.Key, fingerprint: [32]u8, operation: d.Operation, mode: p.Transaction.Mode, limits: p.Transaction.Limits, budget: c.DirectClientToken.Budget },
    statement: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request },
    savepoint: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request },
    settle: struct { key: c.DirectClientToken.Key, operation: d.Operation, command: c.DirectTransactionControl.Command },
},
pub fn identity(self: Self) d.Operation {
    return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
}
pub fn key(self: Self) c.DirectClientToken.Key {
    return switch (self.work) {
        inline else => |value| value.key,
    };
}
pub fn validate(self: Self) !void {
    try self.connection.validate();
    try c.Model.nativeId(self.namespace);
    try self.identity().validate();
    try self.key().validate();
    if (!std.meta.eql(self.connection, self.key().connection)) return error.CatalogIdentityConflict;
    const owner: d.Operation = switch (self.work) {
        .begin => |value| blk: {
            try value.limits.validate();
            try value.budget.validate();
            if (std.mem.allEqual(u8, &value.fingerprint, 0)) return error.InvalidClientToken;
            break :blk value.operation;
        },
        .statement => |value| blk: {
            try value.request.validate();
            break :blk value.request.binding.identity;
        },
        .savepoint => |value| blk: {
            try value.request.validate();
            break :blk value.request.operation;
        },
        .settle => |value| value.operation,
    };
    try self.connection.owner(owner);
    if (std.meta.eql(owner, self.identity())) return error.TransactionIdentityConflict;
}
pub fn beginRequest(self: Self) !c.DirectTransactionRequest.Begin {
    try self.validate();
    if (self.work != .begin) return error.TransactionOperationRequired;
    const value = self.work.begin;
    return .{ .key = value.key, .fingerprint = value.fingerprint, .operation = value.operation, .namespace = self.namespace, .mode = value.mode, .selection = .authorized_catalog_tables, .limits = value.limits, .budget = value.budget };
}
pub const reservation_bytes = c.DirectTransactionWorkspace.max_bytes + c.DirectIntent.max_bytes + 512;
pub const format: u32 = 0x54584931;
pub const Refusal = p.Transaction.CallRefusal;
pub const Result = union(enum) {
    rejected: Refusal,
    begun: p.Transaction.Cut,
    statement: c.storage.TableWorkspace.Outcome,
    savepoint: c.DirectTransactionSavepoint.Result,
    settled: c.DirectTransactionControl.Status,
    pub fn validate(self: Result, connection: c.DirectTableProtocol.Connection) !void {
        switch (self) {
            .rejected => {},
            .begun => |cut| {
                try cut.validate();
                try connection.owner(cut.begin.identity.begin);
                if (cut.acquired.partition != cut.begin.catalog.partition or cut.acquired.next_lsn <= cut.begin.catalog.next_lsn) return error.InvalidTableResponse;
            },
            .statement => |outcome| {
                switch (outcome) {
                    inline else => |value| {
                        try value.statement.validate();
                        try connection.owner(value.statement.transaction.begin);
                    },
                }
                if (outcome == .provisional and outcome.provisional.affected > outcome.provisional.matched) return error.InvalidTableResponse;
            },
            .savepoint => |value| {
                try value.validate();
                try connection.owner(value.request.operation);
                if (value.completed == null) return error.InvalidTableResponse;
            },
            .settled => |value| {
                try value.validate();
                try connection.owner(value.begin.identity.begin);
                if (value.observation != .decided) return error.InvalidTableResponse;
            },
        }
    }
    pub fn requireCall(self: Result, call: Self) !void {
        try call.validate();
        try self.validate(call.connection);
        if (self == .rejected) return;
        switch (call.work) {
            .begin => |work| {
                if (self != .begun or !std.meta.eql(self.begun.begin.identity.begin, work.operation) or self.begun.begin.mode != work.mode or !std.meta.eql(self.begun.begin.limits, work.limits)) return error.InvalidTableResponse;
            },
            .statement => |work| {
                if (self != .statement) return error.InvalidTableResponse;
                const statement = switch (self.statement) {
                    inline else => |value| value.statement,
                };
                if (!std.meta.eql(statement, work.request.statement)) return error.InvalidTableResponse;
            },
            .savepoint => |work| {
                if (self != .savepoint or !std.meta.eql(self.savepoint.request, work.request)) return error.InvalidTableResponse;
            },
            .settle => |work| {
                if (self != .settled or !std.meta.eql(self.settled.observation.decided.attempt.operation, work.operation)) return error.InvalidTableResponse;
            },
        }
    }
};

pub const Stored = struct {
    definition: p.Growth.Definition,
    call: Self,
    result: Result,
    pub fn validate(self: Stored) !void {
        try self.result.requireCall(self.call);
    }
};
pub fn refusal(err: anyerror) ?Refusal {
    return switch (err) {
        error.TransactionReadChanged => .stale_workspace,
        error.TransactionStatementConflict, error.TransactionStatementPending => .statement_conflict,
        error.TransactionControlConflict, error.TransactionControlPending, error.TransactionSavepointMissing => .control_conflict,
        error.TransactionFrozen, error.TransactionCutNotAcquired => .transaction_closed,
        error.TransactionObjectNotSelected, error.ReadOnlyTransaction, error.InvalidTransactionWork => .unsupported_scope,
        error.TransactionIdentityConflict, error.DataIdentityConflict => .identity_conflict,
        else => null,
    };
}
