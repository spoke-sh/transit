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
        pub const json_schema_sequence_bounds = .{ .explicit_tables = 100_000 };
        explicit_tables: []const u64,
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
        if (self.selection == .explicit_tables) {
            const ids = self.selection.explicit_tables;
            if (ids.len > 100_000 or ids.len > self.limits.participants) return error.TransactionCapacity;
            var previous: u64 = 0;
            for (ids) |id| {
                try c.Model.nativeId(id);
                if (id <= previous) return error.InvalidTransactionBegin;
                previous = id;
            }
        }
    }
};
pub const Request = union(enum) {
    begin: Begin,
    acquire: c.DirectClientToken.Key,
    inspect: c.DirectClientToken.Key,
    stage: struct { key: c.DirectClientToken.Key, sequence: u64, work: c.DirectTableIntent.Work },
    statement: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request, execute: bool },
    advance: struct { key: c.DirectClientToken.Key, steps: u16 },
    settle: struct { key: c.DirectClientToken.Key, operation: d.Operation, command: c.DirectTransactionControl.Command, steps: u16 },
    pub fn key(self: Request) c.DirectClientToken.Key {
        return switch (self) {
            .begin => |value| value.key,
            inline .acquire, .inspect => |value| value,
            inline .stage, .statement, .settle, .advance => |value| value.key,
        };
    }
    pub fn validate(self: Request) !void {
        try self.key().validate();
        switch (self) {
            .begin => |value| try value.validate(),
            .acquire, .inspect => {},
            .stage => |value| {
                if (value.sequence == 0 or value.work == .ddl) return error.InvalidTransactionWork;
                try value.key.connection.binding(value.work.binding());
            },
            .statement => |value| {
                try value.request.validate();
                try value.key.connection.owner(value.request.statement.transaction.begin);
            },
            .advance => |value| if (value.steps == 0 or value.steps > 256) return error.InvalidTransactionWork,
            .settle => |value| {
                try value.key.connection.owner(value.operation);
                if (value.steps == 0 or value.steps > 256) return error.InvalidTransactionWork;
            },
        }
    }
    pub fn mutation(self: Request) bool {
        return self != .inspect;
    }
    pub fn control(self: Request) bool {
        return self == .inspect or self == .settle;
    }
};
pub const Result = union(enum) {
    begun: c.DirectClientToken.Receipt,
    acquired: c.DirectTransaction.Acquired,
    staged: c.DirectTransactionWorkspace.Request,
    statement: ?c.storage.TableWorkspace.Outcome,
    status: c.DirectTransactionControl.Status,
};

pub fn validateResult(request: Request, result: Result) !void {
    const expected: std.meta.Tag(Result) = switch (request) {
        .begin => .begun,
        .acquire => .acquired,
        .inspect, .settle, .advance => .status,
        .stage => .staged,
        .statement => .statement,
    };
    if (std.meta.activeTag(result) != expected) return error.InvalidTableResponse;
    switch (result) {
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
            try request.stage.work.binding().requireSame(value.binding);
            if (value.statement.sequence != request.stage.sequence) return error.InvalidTableResponse;
            try request.key().connection.owner(value.statement.transaction.begin);
        },
        .statement => |outcome| {
            if (outcome) |value| switch (value) {
                inline else => |found| if (!std.meta.eql(found.statement, request.statement.request.statement)) return error.InvalidTableResponse,
            } else if (request.statement.execute) return error.InvalidTableResponse;
        },
        .status => |status| {
            try status.begin.validate();
            try status.revision.validate();
            try request.key().connection.owner(status.begin.identity.begin);
            try status.observation.validate();
            if (status.last_statement > status.begin.limits.statements or status.revision.partition != status.begin.catalog.partition or status.revision.next_lsn <= status.begin.catalog.next_lsn or
                (status.cleanup_complete and status.observation != .decided) or (status.attempt != null and status.pending_statement)) return error.InvalidTableResponse;
            if (status.attempt) |attempt| {
                try attempt.validate();
                if (!std.meta.eql(attempt.transaction, status.begin.identity) or attempt.last_statement != status.last_statement) return error.InvalidTableResponse;
                if (request == .settle and !std.meta.eql(attempt.operation, request.settle.operation)) return error.InvalidTableResponse;
                switch (status.observation) {
                    .preparing => |found| try found.requireSame(attempt),
                    .decided => |decision| try decision.requireAttempt(attempt),
                    .not_observed, .unavailable, .denied => {},
                }
            } else if (status.observation == .decided or status.observation == .preparing or request == .settle) return error.InvalidTableResponse;
        },
    }
}
