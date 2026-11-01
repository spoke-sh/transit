//! Exact private log work. These values and their provisional summaries are
//! neither public operation receipts nor permission to append or settle input.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const x = p.Transaction;
const q = p.StreamQueue;
const Actions = c.storage.LogTransactionActions;

pub const Work = union(enum) {
    append: q.Append,
    stream_offset: @FieldType(c.DirectStreamMutation.Request, "offset"),
    queue_ack: q.Settlement,

    pub fn validate(self: Work) !void {
        switch (self) {
            .append => |value| {
                try value.validate();
                if (value.payload.bytes > Actions.max_payload_bytes) return error.InvalidStreamPayload;
            },
            .stream_offset => |value| try value.validate(),
            .queue_ack => |value| {
                try value.validate();
                if (value.action != .ack) return error.InvalidTransactionSettlement;
            },
        }
    }
    pub fn operation(self: Work) d.Operation {
        return switch (self) {
            .stream_offset => |value| value.commit.operation,
            inline else => |value| value.operation,
        };
    }
    pub fn target(self: Work) q.Partition {
        return switch (self) {
            .append => |value| value.target,
            .stream_offset => |value| value.commit.coverage.cut.target,
            .queue_ack => |value| value.lease.target,
        };
    }
    pub fn kind(self: Work) p.StreamQueueDeclaration.Kind {
        return switch (self) {
            .append => |value| switch (value.kind) {
                .stream => .stream,
                .queue => .queue,
            },
            .stream_offset => .stream,
            .queue_ack => .queue,
        };
    }
    pub fn access(self: Work) c.LogAuthority.Access {
        return switch (self) {
            .append => .append,
            .stream_offset, .queue_ack => .settle,
        };
    }
    /// Payload bytes are committed by Append.payload; coverage includes the
    /// exact owner-issued cursor, not a reconstructed coverage descriptor.
    pub fn digest(self: Work) ![32]u8 {
        try self.validate();
        var bytes: [Actions.max_object_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.transaction.log.work.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(writer.buffered());
        return hash.finalResult();
    }
    pub fn entry(self: Work, statement: x.Statement) Actions.Entry {
        return .{ .work = .{ .statement = statement, .ordinal = 1, .action = switch (self) {
            .append => |value| .{ .append = value },
            .stream_offset => |value| .{ .stream_offset = value.commit },
            .queue_ack => |value| .{ .queue_ack = value },
        } }, .offset_cursor = if (self == .stream_offset) self.stream_offset.cursor else null };
    }
};

pub const Request = struct {
    statement: x.Statement,
    basis: d.Position,
    guard: x.LogGuard,
    work: Work,

    pub fn validate(self: Request) !void {
        try self.statement.validate();
        try self.basis.validate();
        try self.guard.validate();
        try self.work.validate();
        if (self.basis.next_lsn == 0) return error.InvalidTransactionWorkspace;
        if (!std.mem.eql(u8, &self.statement.intent, &try self.work.digest())) return error.TransactionIdentityConflict;
        try self.work.entry(self.statement).work.validate(self.guard);
    }
    pub fn binding(self: Request) !Binding {
        try self.validate();
        var bytes: [Actions.max_object_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.transaction.log.statement.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(writer.buffered());
        const result: Binding = .{ .statement = self.statement, .basis = self.basis, .operation = self.work.operation(), .target = self.work.target(), .request = hash.finalResult() };
        try result.validate();
        return result;
    }
};

pub fn stagePayload(objects: c.storage.TransitObjectStore.ObjectStore, work: Work, payload: ?[]const u8) !void {
    try work.validate();
    if ((work == .append) != (payload != null)) return error.InvalidStreamPayload;
    if (payload) |bytes| {
        const content = work.append.payload;
        if (!std.meta.eql(c.storage.LogBatch.content(bytes), content)) return error.LogPayloadConflict;
        var key: [96]u8 = undefined;
        const stored = try objects.putImmutable(try Actions.payloadKey(content, &key), bytes, content.sha256);
        if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.LogPayloadConflict;
    }
}

pub fn loadPayload(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, work: Work) !?[]u8 {
    if (work != .append) return null;
    const content = work.append.payload;
    if (content.bytes > Actions.max_payload_bytes) return error.InvalidStreamPayload;
    var key: [96]u8 = undefined;
    const name = try Actions.payloadKey(content, &key);
    const stored = try objects.head(name) orelse return error.MissingLogPayload;
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.LogPayloadConflict;
    const bytes = try allocator.alloc(u8, @intCast(content.bytes));
    errdefer allocator.free(bytes);
    const read = try objects.getRange(name, 0, @intCast(bytes.len), bytes);
    if (read.len != bytes.len or !std.meta.eql(c.storage.LogBatch.content(read), content)) return error.LogPayloadConflict;
    return bytes;
}

pub fn evaluationLimits(begin: x.Begin, last_statement: u64) c.storage.LogTransaction.EvaluationLimits {
    return .{ .actions = begin.limits.statements, .payload_bytes = begin.limits.workspace_bytes, .resident_bytes = @intCast(begin.limits.resident_bytes), .last_statement = last_statement };
}

/// Compact permanent identity reservation. The accepted workspace retains the
/// complete request; this digest also binds its guard, basis and exact cursor.
pub const Binding = struct {
    statement: x.Statement,
    basis: d.Position,
    operation: d.Operation,
    target: q.Partition,
    request: [32]u8,
    pub fn validate(self: Binding) !void {
        try self.statement.validate();
        try self.basis.validate();
        try self.target.requireOperation(self.operation);
        try self.statement.transaction.requireObject(self.target.interpretation.object);
        if (self.basis.next_lsn == 0 or self.statement.transaction.begin.principal != self.operation.principal or self.statement.transaction.begin.operation == self.operation.operation) return error.TransactionIdentityConflict;
    }
};

/// A private evaluation describes its proposed action without exposing a
/// receipt that claims public acceptance. Commit is observed separately.
pub const Summary = union(enum) {
    append: struct { rows: u64 },
    stream_offset: struct { next: u64 },
    queue_ack: struct { offset: u64, lease_epoch: u64 },

    pub fn proposed(work: Work) Summary {
        return switch (work) {
            .append => |value| .{ .append = .{ .rows = value.rows } },
            .stream_offset => |value| .{ .stream_offset = .{ .next = value.commit.next } },
            .queue_ack => |value| .{ .queue_ack = .{ .offset = value.lease.offset, .lease_epoch = value.lease.epoch } },
        };
    }
};

pub const Outcome = union(enum) {
    provisional: struct { statement: x.Statement, proposed: Summary },
    rejected: struct { statement: x.Statement, reason: Reason },

    pub const Reason = enum { conflict, lease_expired, lease_fenced, producer_conflict, offset_conflict };
    pub fn statement(self: Outcome) x.Statement {
        return switch (self) {
            inline else => |value| value.statement,
        };
    }
};

pub const Completed = struct {
    request: Request,
    outcome: Outcome,
    pub fn validate(self: Completed) !void {
        try self.request.validate();
        if (!std.meta.eql(self.request.statement, self.outcome.statement())) return error.InvalidTransactionWorkspace;
        if (self.outcome == .provisional and !std.meta.eql(self.outcome.provisional.proposed, Summary.proposed(self.request.work))) return error.InvalidTransactionWorkspace;
    }
};
