//! Transaction attribution for a logical command result, separate from row
//! delivery and from the service's accepted caller-command identity.
const std = @import("std");
const r = @import("root.zig");
const x = r.protocol.Transaction;
const d = r.protocol.DataLifecycle;
const Self = @This();
pub const SessionState = enum { idle, active, failed };
pub const StatementRefusal = enum { definition_changed, data_changed, duplicate_key, missing_row, invalid_rows, work_limit };
handle: x.Handle,
evidence: union(enum) {
    refused: x.CallRefusal,
    begun: x.Cut,
    statement: struct { identity: x.Statement, refusal: ?StatementRefusal },
    savepoint: struct { sequence: u64, operation: d.Operation, accepted: d.Position, completed: d.Position },
    decided: struct { decision: x.Decision, cleanup_complete: bool },
},
pub fn validate(self: Self, command: r.Command, outcome: r.Outcome) !void {
    try self.handle.validate();
    switch (self.evidence) {
        .refused => {
            if (outcome != .rejected) return error.InvalidTransactionCompletion;
            switch (command) {
                .begin, .commit, .rollback, .savepoint, .release_savepoint, .rollback_to_savepoint, .insert, .update, .delete => {},
                else => return error.InvalidTransactionCompletion,
            }
        },
        .begun => |cut| {
            try cut.validate();
            if (command != .begin or outcome != .applied or !std.meta.eql(cut.begin.identity, self.handle.identity)) return error.InvalidTransactionCompletion;
        },
        .statement => |value| {
            const statement = value.identity;
            try statement.validate();
            if ((outcome == .rejected) != (value.refusal != null)) return error.InvalidTransactionCompletion;
            if (!std.meta.eql(statement.transaction, self.handle.identity) or (outcome != .provisional and outcome != .rejected)) return error.InvalidTransactionCompletion;
            switch (command) {
                .insert, .update, .delete => {},
                else => return error.InvalidTransactionCompletion,
            }
        },
        .savepoint => |value| {
            try value.operation.validate();
            try value.accepted.validate();
            try value.completed.validate();
            if (value.sequence == 0 or value.accepted.next_lsn == 0 or value.accepted.partition != value.completed.partition or
                value.completed.next_lsn < value.accepted.next_lsn or outcome != .applied or
                !std.meta.eql(value.operation.scope, self.handle.identity.begin.scope) or value.operation.principal != self.handle.identity.begin.principal)
                return error.InvalidTransactionCompletion;
            switch (command) {
                .savepoint, .release_savepoint, .rollback_to_savepoint => {},
                else => return error.InvalidTransactionCompletion,
            }
        },
        .decided => |value| {
            try value.decision.validate();
            if (!std.meta.eql(value.decision.attempt.transaction, self.handle.identity)) return error.InvalidTransactionCompletion;
            const expected: @FieldType(x.Decision, "outcome") = switch (command) {
                .commit => .committed,
                .rollback => .aborted,
                else => return error.InvalidTransactionCompletion,
            };
            if (outcome != (if (value.decision.outcome == expected) r.Outcome.applied else .rejected)) return error.InvalidTransactionCompletion;
        },
    }
}
