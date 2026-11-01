//! Signed transaction controls over the existing Catalog token authority.
const std = @import("std");
const c = @import("root.zig");
const x = c.protocol.Transaction;
const d = c.protocol.DataLifecycle;
pub const Begin = struct {
    key: c.DirectClientToken.Key,
    fingerprint: [32]u8,
    operation: d.Operation,
    namespace: u64,
    mode: x.Mode,
    selection: union(enum) {
        pub const json_schema_sequence_bounds = .{ .explicit_objects = 100_000 };
        explicit_objects: []const x.Target,
        authorized_catalog_tables,
    },
    limits: x.Limits,
    budget: c.DirectClientToken.Budget,
    pub fn validate(self: Begin) !void {
        try self.key.validate();
        try self.key.connection.owner(self.operation);
        try c.Model.nativeId(self.namespace);
        try self.limits.validate();
        try self.budget.validate();
        if (std.mem.allEqual(u8, &self.fingerprint, 0)) return error.InvalidClientToken;
        if (self.selection == .explicit_objects) {
            const ids = self.selection.explicit_objects;
            if (ids.len > 100_000 or ids.len > self.limits.participants) return error.TransactionCapacity;
            var previous: ?x.Target = null;
            const identity: x.Identity = .{ .begin = self.operation, .branch = self.key.connection.branch };
            for (ids) |target| {
                try target.validate();
                try identity.requireObject(target.object);
                if (previous) |prior| {
                    if (prior.order(target) != .lt or (prior.object.object == target.object.object and prior.kind != target.kind)) return error.InvalidTransactionBegin;
                }
                previous = target;
            }
        }
    }
};
pub const Request = union(enum) {
    call: struct { key: c.DirectClientToken.Key, steps: u16, control: bool, cancel: bool },
    call_outcome: c.DirectClientToken.Key,
    begin: Begin,
    acquire: c.DirectClientToken.Key,
    inspect: c.DirectClientToken.Key,
    stage: struct { key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: c.DirectTableIntent.Work },
    stage_kv: struct { key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: c.DirectKV.Mutation },
    stage_log: struct { key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: c.DirectTransactionLogWork.Work, payload: ?c.DirectTableProtocol.Binary },
    log_statement: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionLogWork.Request, execute: bool },
    log_outcome: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionLogWork.Request },
    statement: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request, execute: bool },
    statement_outcome: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request },
    savepoint_outcome: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request },
    savepoint: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request, steps: u16 },
    advance: struct { key: c.DirectClientToken.Key, steps: u16 },
    settle: struct { key: c.DirectClientToken.Key, operation: d.Operation, command: c.DirectTransactionControl.Command, steps: u16 },
    pub fn key(self: Request) c.DirectClientToken.Key {
        return switch (self) {
            .begin => |value| value.key,
            inline .acquire, .inspect, .call_outcome => |value| value,
            inline .stage, .stage_kv, .stage_log, .log_statement, .log_outcome, .statement, .settle, .advance, .savepoint, .statement_outcome, .savepoint_outcome, .call => |value| value.key,
        };
    }
    pub fn validate(self: Request) !void {
        try self.key().validate();
        switch (self) {
            .begin => |value| try value.validate(),
            .acquire, .inspect, .call_outcome => {},
            .call => |value| if (value.steps == 0 or value.steps > 256) return error.InvalidTransactionWork,
            .stage => |value| {
                try value.basis.validate();
                if (value.basis.next_lsn == 0) return error.InvalidTransactionWork;
                if (value.sequence == 0 or value.work == .ddl) return error.InvalidTransactionWork;
                try value.key.connection.binding(value.work.binding());
            },
            .stage_kv => |value| {
                try value.basis.validate();
                if (value.basis.next_lsn == 0 or value.sequence == 0) return error.InvalidTransactionWork;
                try value.key.connection.binding(value.work.binding);
            },
            .stage_log => |value| {
                try value.basis.validate();
                try value.work.validate();
                if (value.basis.next_lsn == 0 or value.sequence == 0 or (value.work.appendPayload() != null) != (value.payload != null)) return error.InvalidTransactionWork;
                try value.key.connection.owner(value.work.operation());
            },
            inline .statement, .statement_outcome, .log_statement, .log_outcome => |value| {
                try value.request.validate();
                try value.key.connection.owner(value.request.statement.transaction.begin);
            },
            .savepoint_outcome => |value| {
                try value.request.validate();
                try value.key.connection.owner(value.request.operation);
            },
            .savepoint => |value| {
                try value.request.validate();
                try value.key.connection.owner(value.request.operation);
                if (value.steps == 0 or value.steps > 256) return error.InvalidTransactionWork;
            },
            .advance => |value| if (value.steps == 0 or value.steps > 256) return error.InvalidTransactionWork,
            .settle => |value| {
                try value.key.connection.owner(value.operation);
                if (value.steps == 0 or value.steps > 256) return error.InvalidTransactionWork;
            },
        }
    }
    pub fn mutation(self: Request) bool {
        return self != .inspect and self != .statement_outcome and self != .log_outcome and self != .savepoint_outcome and self != .call_outcome;
    }
    pub fn control(self: Request) bool {
        return self == .call_outcome or (self == .call and self.call.control) or self == .inspect or self == .settle or self == .statement_outcome or self == .log_outcome or self == .savepoint_outcome;
    }
};
pub const Result = union(enum) {
    call: ?c.DirectTransactionCall.Result,
    begun: c.DirectClientToken.Receipt,
    acquired: c.DirectTransaction.Acquired,
    staged: c.DirectTransactionWorkspace.Request,
    staged_log: c.DirectTransactionLogWork.Request,
    log_statement: ?c.DirectTransactionLogWork.Outcome,
    statement: ?c.storage.TableWorkspace.Outcome,
    status: c.DirectTransactionControl.Status,
    savepoint: c.DirectTransactionSavepoint.Result,
    savepoint_outcome: ?c.DirectTransactionSavepoint.Result,
};

pub fn validateResult(request: Request, result: Result) !void {
    const expected: std.meta.Tag(Result) = switch (request) {
        .call, .call_outcome => .call,
        .begin => .begun,
        .acquire => .acquired,
        .inspect, .settle, .advance => .status,
        .stage, .stage_kv => .staged,
        .stage_log => .staged_log,
        .log_statement, .log_outcome => .log_statement,
        .statement, .statement_outcome => .statement,
        .savepoint_outcome => .savepoint_outcome,
        .savepoint => .savepoint,
    };
    if (std.meta.activeTag(result) != expected) return error.InvalidTableResponse;
    switch (result) {
        .call => |value| if (value) |found| try found.validate(request.key().connection),
        .begun => |receipt| {
            try receipt.validate();
            try request.key().requireSame(receipt.binding.key);
            if (receipt.binding.intent != .transaction or !std.mem.eql(u8, &request.begin.fingerprint, &receipt.binding.fingerprint)) return error.InvalidTableResponse;
        },
        .acquired => |value| {
            try value.cut.validate();
            try request.key().connection.owner(value.cut.begin.identity.begin);
            if (value.cut.acquired.partition != value.cut.begin.catalog.partition or value.cut.acquired.next_lsn <= value.cut.begin.catalog.next_lsn or value.coordination <= value.cut.acquired.partition) return error.InvalidTableResponse;
        },
        .staged => |value| {
            try value.validate();
            const binding = if (request == .stage) request.stage.work.binding() else request.stage_kv.work.binding;
            const basis = if (request == .stage) request.stage.basis else request.stage_kv.basis;
            const sequence = if (request == .stage) request.stage.sequence else request.stage_kv.sequence;
            try binding.requireSame(value.binding);
            if (!std.meta.eql(value.basis, basis)) return error.InvalidTableResponse;
            if (value.statement.sequence != sequence) return error.InvalidTableResponse;
            try request.key().connection.owner(value.statement.transaction.begin);
        },
        .staged_log => |value| {
            try value.validate();
            if (!std.meta.eql(value.basis, request.stage_log.basis) or value.statement.sequence != request.stage_log.sequence or
                !std.meta.eql(value.work, request.stage_log.work)) return error.InvalidTableResponse;
            try request.key().connection.owner(value.statement.transaction.begin);
        },
        .log_statement => |outcome| {
            const original = if (request == .log_statement) request.log_statement.request else request.log_outcome.request;
            if (outcome) |value| {
                try (c.DirectTransactionLogWork.Completed{ .request = original, .outcome = value }).validate();
            } else if (request == .log_statement and request.log_statement.execute) return error.InvalidTableResponse;
        },
        .statement => |outcome| {
            const original = if (request == .statement) request.statement.request else request.statement_outcome.request;
            if (outcome) |value| switch (value) {
                inline else => |found| if (!std.meta.eql(found.statement, original.statement)) return error.InvalidTableResponse,
            } else if (request == .statement and request.statement.execute) return error.InvalidTableResponse;
        },
        .savepoint_outcome => |observed| if (observed) |value| {
            try value.validate();
            if (!std.meta.eql(value.request, request.savepoint_outcome.request)) return error.InvalidTableResponse;
        },
        .savepoint => |value| {
            try value.validate();
            if (!std.meta.eql(value.request, request.savepoint.request)) return error.InvalidTableResponse;
        },
        .status => |status| {
            try status.validate();
            try request.key().connection.owner(status.begin.identity.begin);
            if (request == .settle) {
                const attempt = status.attempt orelse return error.InvalidTableResponse;
                if (!std.meta.eql(attempt.operation, request.settle.operation)) return error.InvalidTableResponse;
            }
        },
    }
}
