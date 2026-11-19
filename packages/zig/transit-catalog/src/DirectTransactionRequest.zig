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
        authorized_catalog_objects,
    },
    limits: x.Limits,
    deadline: ?x.Deadline,
    execution: ?x.Execution,
    budget: c.DirectClientToken.Budget,
    pub fn validate(self: Begin) !void {
        try self.key.validate();
        try self.key.connection.owner(self.operation);
        try c.Model.nativeId(self.namespace);
        try self.limits.validate();
        if (self.deadline) |deadline| try deadline.validate();
        if (self.execution) |execution| try execution.requireIdentity(.{ .begin = self.operation, .branch = self.key.connection.branch });
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
/// A current native recovery owner can observe or settle the saved original.
/// A settle request always aborts undecided work; it cannot request a commit.
pub const Recover = struct {
    key: c.DirectClientToken.Key,
    execution: x.Execution,
    work: union(enum) { inspect, settle: struct { operation: d.Operation, steps: u16 } },
    close_input: bool,
    pub fn validate(self: Recover) !void {
        try self.key.validate();
        try self.execution.validate();
        if (self.execution.realm != self.key.connection.scope.realm or self.execution.principal != self.key.connection.principal)
            return error.TransactionIdentityConflict;
        if (self.close_input and (self.work != .settle or self.execution.input == null)) return error.InvalidTransactionWork;
        if (self.work == .settle) {
            try self.key.connection.owner(self.work.settle.operation);
            if (self.work.settle.steps == 0 or self.work.settle.steps > 256) return error.InvalidTransactionWork;
        }
    }
};
pub const max_batch = 16;

pub const BatchWrite = union(enum) {
    table: c.DirectTableIntent.Work,
    kv: c.DirectKV.Mutation,
    log: struct { work: c.DirectTransactionLogWork.Work, payload: ?c.DirectTableProtocol.Binary },

    pub fn operation(self: BatchWrite) d.Operation {
        return switch (self) {
            .table => |value| value.binding().identity,
            .kv => |value| value.binding.identity,
            .log => |value| value.work.operation(),
        };
    }
    pub fn destinationOperation(self: BatchWrite) ?d.Operation {
        return if (self == .log and self.log.work == .queue_transfer) self.log.work.queue_transfer.destination.operation else null;
    }
    pub fn validate(self: BatchWrite, connection: c.DirectTableProtocol.Connection) !void {
        switch (self) {
            .table => |value| {
                if (value == .ddl) return error.InvalidTransactionWork;
                try connection.binding(value.binding());
            },
            .kv => |value| try connection.binding(value.binding),
            .log => |value| {
                try value.work.validate();
                if ((value.work.appendPayload() != null) != (value.payload != null)) return error.InvalidTransactionWork;
                try connection.owner(value.work.operation());
                if (value.work == .queue_transfer) {
                    const dest = value.work.queue_transfer.destination.operation;
                    try connection.owner(dest);
                    if (std.meta.eql(dest, value.work.operation())) return error.TransactionIdentityConflict;
                }
            },
        }
    }
};

fn pushDistinctOperation(seen: *[2 * max_batch]d.Operation, count: *usize, candidate: d.Operation) !void {
    for (seen[0..count.*]) |prior| {
        if (std.meta.eql(prior, candidate)) return error.TransactionIdentityConflict;
    }
    seen[count.*] = candidate;
    count.* += 1;
}

pub fn validateBatchItems(connection: c.DirectTableProtocol.Connection, items: []const c.DirectTransactionWorkspace.StatementWork) !void {
    if (items.len == 0 or items.len > max_batch) return error.InvalidTransactionWork;
    const first = items[0];
    try first.validate();
    const first_basis = switch (first) {
        inline else => |value| value.basis,
    };
    const tx_id = first.statement().transaction;
    try connection.owner(tx_id.begin);
    var seen: [2 * max_batch]d.Operation = undefined;
    var seen_count: usize = 0;
    for (items, 0..) |item, idx| {
        if (idx > 0) try item.validate();
        const expected_sequence = try std.math.add(u64, first.statement().sequence, idx);
        const basis = switch (item) {
            inline else => |value| value.basis,
        };
        if (!std.meta.eql(item.statement().transaction, tx_id) or item.statement().sequence != expected_sequence or !std.meta.eql(basis, first_basis))
            return error.InvalidTransactionWork;
        const primary = switch (item) {
            .state => |request| request.binding.identity,
            .log => |request| request.work.operation(),
        };
        try connection.owner(primary);
        if (std.meta.eql(primary, tx_id.begin)) return error.TransactionIdentityConflict;
        try pushDistinctOperation(&seen, &seen_count, primary);
        if (item == .log and item.log.work == .queue_transfer) {
            const dest = item.log.work.queue_transfer.destination.operation;
            try connection.owner(dest);
            if (std.meta.eql(dest, tx_id.begin)) return error.TransactionIdentityConflict;
            try pushDistinctOperation(&seen, &seen_count, dest);
        }
    }
}

pub const StageBatch = struct {
    pub const json_schema_sequence_bounds = .{ .items = max_batch };
    key: c.DirectClientToken.Key,
    basis: d.Position,
    sequence: u64,
    items: []const BatchWrite,

    pub fn validate(self: StageBatch) !void {
        try self.key.validate();
        try self.basis.validate();
        if (self.basis.next_lsn == 0 or self.sequence == 0 or self.items.len == 0 or self.items.len > max_batch)
            return error.InvalidTransactionWork;
        _ = try std.math.add(u64, self.sequence, self.items.len - 1);
        var seen: [2 * max_batch]d.Operation = undefined;
        var seen_count: usize = 0;
        for (self.items) |item| {
            try item.validate(self.key.connection);
            try pushDistinctOperation(&seen, &seen_count, item.operation());
            if (item.destinationOperation()) |dest| try pushDistinctOperation(&seen, &seen_count, dest);
        }
    }
};

pub const ExecuteBatch = struct {
    pub const json_schema_sequence_bounds = .{ .items = max_batch };
    key: c.DirectClientToken.Key,
    items: []const c.DirectTransactionWorkspace.StatementWork,

    pub fn validate(self: ExecuteBatch) !void {
        try self.key.validate();
        try validateBatchItems(self.key.connection, self.items);
    }
};

/// Self-contained caller checkpoint for up to `max_batch` staged statements.
/// Unused entries are always null so structural equality is deterministic.
pub const StagedBatch = struct {
    entries: [max_batch]?c.DirectTransactionWorkspace.StatementWork = @splat(null),
    count: u8 = 0,

    pub fn fromSlice(items: []const c.DirectTransactionWorkspace.StatementWork) !StagedBatch {
        if (items.len == 0 or items.len > max_batch) return error.InvalidTransactionWork;
        var result: StagedBatch = .{ .count = @intCast(items.len) };
        for (items, 0..) |item, idx| result.entries[idx] = item;
        return result;
    }
    pub fn copyTo(self: *const StagedBatch, out: *[max_batch]c.DirectTransactionWorkspace.StatementWork) ![]const c.DirectTransactionWorkspace.StatementWork {
        if (self.count == 0 or self.count > max_batch) return error.InvalidTransactionWork;
        for (0..self.count) |idx| out[idx] = self.entries[idx] orelse return error.InvalidTransactionWork;
        return out[0..self.count];
    }
    pub fn firstSequence(self: *const StagedBatch) u64 {
        return self.entries[0].?.statement().sequence;
    }
    pub fn lastSequence(self: *const StagedBatch) u64 {
        return self.entries[self.count - 1].?.statement().sequence;
    }
    pub fn validate(self: *const StagedBatch, connection: c.DirectTableProtocol.Connection) !void {
        if (self.count == 0 or self.count > max_batch) return error.InvalidTransactionWork;
        for (self.count..max_batch) |idx| if (self.entries[idx] != null) return error.InvalidTransactionWork;
        var items: [max_batch]c.DirectTransactionWorkspace.StatementWork = undefined;
        const active = try self.copyTo(&items);
        try validateBatchItems(connection, active);
    }
    pub fn jsonStringify(self: StagedBatch, out: *std.json.Stringify) std.Io.Writer.Error!void {
        if (self.count == 0 or self.count > max_batch) return error.WriteFailed;
        try out.beginArray();
        for (0..self.count) |idx| {
            const entry = self.entries[idx] orelse return error.WriteFailed;
            try c.protocol.Json.write(entry, out);
        }
        try out.endArray();
    }
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!StagedBatch {
        const value = try std.json.innerParse(std.json.Value, allocator, source, options);
        return jsonParseFromValue(allocator, value, options);
    }
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) std.json.ParseFromValueError!StagedBatch {
        c.protocol.Json.validateShape([]const c.DirectTransactionWorkspace.StatementWork, source) catch return error.UnexpectedToken;
        const items = try std.json.innerParseFromValue([]const c.DirectTransactionWorkspace.StatementWork, allocator, source, options);
        defer allocator.free(items);
        return fromSlice(items) catch return error.LengthMismatch;
    }
};

pub const BatchRejection = struct {
    statement: x.Statement,
    reason: union(enum) {
        state: @FieldType(@FieldType(c.storage.TableWorkspace.Outcome, "rejected"), "reason"),
        log: c.DirectTransactionLogWork.Outcome.Reason,
    },
    pub fn validate(self: BatchRejection) !void {
        try self.statement.validate();
    }
};

pub const BatchSummary = struct {
    first_sequence: u64,
    last_sequence: u64,
    evaluated_count: u8,
    provisional_count: u8,
    rows_matched: u64,
    rows_affected: u64,
    log_appended_rows: u64,
    log_settled_acks: u64,
    log_advanced_offsets: u64,
    log_transfers: u64,
    rejection: ?BatchRejection,

    pub fn validate(self: BatchSummary) !void {
        if (self.first_sequence == 0 or self.evaluated_count == 0 or self.evaluated_count > max_batch)
            return error.InvalidTransactionWork;
        if (self.last_sequence != try std.math.add(u64, self.first_sequence, self.evaluated_count - 1))
            return error.InvalidTransactionWork;
        if (self.rejection) |rejected| {
            try rejected.validate();
            if (self.provisional_count + 1 != self.evaluated_count or rejected.statement.sequence != self.last_sequence)
                return error.InvalidTransactionWork;
        } else if (self.provisional_count != self.evaluated_count) {
            return error.InvalidTransactionWork;
        }
        if (self.rows_affected > self.rows_matched) return error.InvalidTransactionWork;
    }
};

pub const Recovery = struct { status: c.DirectTransactionControl.Status, input: ?c.DirectQueue.Receipt };
pub const Request = union(enum) {
    recover: Recover,
    call: struct { key: c.DirectClientToken.Key, steps: u16, control: bool, cancel: bool },
    call_outcome: c.DirectClientToken.Key,
    begin: Begin,
    acquire: c.DirectClientToken.Key,
    inspect: c.DirectClientToken.Key,
    stage: struct { key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: c.DirectTableIntent.Work },
    stage_kv: struct { key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: c.DirectKV.Mutation },
    stage_log: struct { key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: c.DirectTransactionLogWork.Work, payload: ?c.DirectTableProtocol.Binary },
    stage_batch: StageBatch,
    log_statement: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionLogWork.Request, execute: bool },
    log_outcome: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionLogWork.Request },
    statement: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request, execute: bool },
    statement_outcome: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request },
    batch: ExecuteBatch,
    savepoint_outcome: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request },
    savepoint: struct { key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request, steps: u16 },
    advance: struct { key: c.DirectClientToken.Key, steps: u16 },
    settle: struct { key: c.DirectClientToken.Key, operation: d.Operation, command: c.DirectTransactionControl.Command, steps: u16 },
    pub fn key(self: Request) c.DirectClientToken.Key {
        return switch (self) {
            inline .begin, .recover => |value| value.key,
            inline .acquire, .inspect, .call_outcome => |value| value,
            inline .stage, .stage_kv, .stage_log, .stage_batch, .log_statement, .log_outcome, .statement, .batch, .settle, .advance, .savepoint, .statement_outcome, .savepoint_outcome, .call => |value| value.key,
        };
    }
    pub fn validate(self: Request) !void {
        try self.key().validate();
        switch (self) {
            .recover => |value| try value.validate(),
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
            .stage_batch => |value| try value.validate(),
            .batch => |value| try value.validate(),
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
        if (self == .recover) return self.recover.work != .inspect;
        return self != .inspect and self != .statement_outcome and self != .log_outcome and self != .savepoint_outcome and self != .call_outcome;
    }
    pub fn control(self: Request) bool {
        return self == .recover or self == .call_outcome or (self == .call and self.call.control) or self == .inspect or self == .settle or self == .statement_outcome or self == .log_outcome or self == .savepoint_outcome;
    }
};
pub const Result = union(enum) {
    recovered: ?Recovery,
    call: ?c.DirectTransactionCall.Result,
    begun: c.DirectClientToken.Receipt,
    acquired: c.DirectTransaction.Acquired,
    staged: c.DirectTransactionWorkspace.Request,
    staged_log: c.DirectTransactionLogWork.Request,
    staged_batch: struct {
        pub const json_schema_sequence_bounds = .{ .items = max_batch };
        items: []const c.DirectTransactionWorkspace.StatementWork,
    },
    log_statement: ?c.DirectTransactionLogWork.Outcome,
    statement: ?c.storage.TableWorkspace.Outcome,
    batch: BatchSummary,
    status: c.DirectTransactionControl.Status,
    savepoint: c.DirectTransactionSavepoint.Result,
    savepoint_outcome: ?c.DirectTransactionSavepoint.Result,
};

pub fn validateResult(request: Request, result: Result) !void {
    const expected: std.meta.Tag(Result) = switch (request) {
        .recover => .recovered,
        .call, .call_outcome => .call,
        .begin => .begun,
        .acquire => .acquired,
        .inspect, .settle, .advance => .status,
        .stage, .stage_kv => .staged,
        .stage_log => .staged_log,
        .stage_batch => .staged_batch,
        .log_statement, .log_outcome => .log_statement,
        .statement, .statement_outcome => .statement,
        .batch => .batch,
        .savepoint_outcome => .savepoint_outcome,
        .savepoint => .savepoint,
    };
    if (std.meta.activeTag(result) != expected) return error.InvalidTableResponse;
    switch (result) {
        .recovered => |observed| if (observed) |recovery| {
            const status = recovery.status;
            try status.validate();
            try request.key().connection.owner(status.begin.identity.begin);
            if (!std.meta.eql(status.begin.execution, @as(?x.Execution, request.recover.execution))) return error.InvalidTableResponse;
            if (request.recover.work == .settle) {
                const attempt = status.attempt orelse return error.InvalidTableResponse;
                if (!std.meta.eql(attempt.operation, request.recover.work.settle.operation)) return error.InvalidTableResponse;
            }
            if ((recovery.input != null) != (request.recover.close_input and status.cleanup_complete)) return error.InvalidTableResponse;
            if (recovery.input) |input| switch (input) {
                .claim => |receipt| try receipt.requireClaim(request.recover.execution.input.?),
                .closed => |closed| try closed.requireQueue(.{ .claim = request.recover.execution.input.? }),
                else => return error.InvalidTableResponse,
            };
        },
        .call => |value| if (value) |found| try found.validate(request.key().connection),
        .begun => |receipt| {
            try receipt.validate();
            try request.key().requireSame(receipt.binding.key);
            if (receipt.binding.intent != .transaction or !std.mem.eql(u8, &request.begin.fingerprint, &receipt.binding.fingerprint)) return error.InvalidTableResponse;
            if (!std.meta.eql(receipt.binding.intent.transaction.begin.deadline, request.begin.deadline) or
                !std.meta.eql(receipt.binding.intent.transaction.begin.execution, request.begin.execution)) return error.InvalidTableResponse;
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
        .staged_batch => |value| {
            const items = value.items;
            if (items.len != request.stage_batch.items.len or items.len == 0 or items.len > max_batch) return error.InvalidTableResponse;
            validateBatchItems(request.key().connection, items) catch return error.InvalidTableResponse;
            for (request.stage_batch.items, items, 0..) |input, staged, index| {
                const sequence = std.math.add(u64, request.stage_batch.sequence, index) catch return error.InvalidTableResponse;
                switch (input) {
                    .table, .kv => {
                        if (staged != .state) return error.InvalidTableResponse;
                        const binding = if (input == .table) input.table.binding() else input.kv.binding;
                        binding.requireSame(staged.state.binding) catch return error.InvalidTableResponse;
                        if (!std.meta.eql(staged.state.basis, request.stage_batch.basis) or staged.state.statement.sequence != sequence) return error.InvalidTableResponse;
                    },
                    .log => |log_input| {
                        if (staged != .log) return error.InvalidTableResponse;
                        if (!std.meta.eql(staged.log.basis, request.stage_batch.basis) or staged.log.statement.sequence != sequence or
                            !std.meta.eql(staged.log.work, log_input.work)) return error.InvalidTableResponse;
                    },
                }
            }
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
        .batch => |value| {
            value.validate() catch return error.InvalidTableResponse;
            if (value.evaluated_count > request.batch.items.len or value.first_sequence != request.batch.items[0].statement().sequence)
                return error.InvalidTableResponse;
            if (value.rejection) |rejected| {
                const failed = request.batch.items[value.evaluated_count - 1];
                if (!std.meta.eql(rejected.statement, failed.statement()) or (failed == .state) != (rejected.reason == .state))
                    return error.InvalidTableResponse;
            } else if (value.evaluated_count != request.batch.items.len) {
                return error.InvalidTableResponse;
            }
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
