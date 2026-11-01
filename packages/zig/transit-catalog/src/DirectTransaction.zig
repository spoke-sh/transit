//! Catalog admission of a local transaction's original begin request. Admission
//! reserves a coordination partition; it does not acquire pins or publish data.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;

/// The catalog publishes this immutable record only after every selected pin
/// has been checked under one database publication fence. The position is the
/// catalog acceptance of that complete cut, never a participant commit LSN.
pub const Acquired = struct {
    definition: p.Growth.Definition,
    cut: p.Transaction.Cut,
    coordination: u64,

    pub const format: u32 = 0x54584331;
    pub const max_bytes = 16 * 1024;

    pub fn validate(self: Acquired, receipt: c.DirectClientToken.Receipt) !void {
        try receipt.validate();
        try self.cut.validate();
        if (receipt.binding.intent != .transaction or
            receipt.coordination != self.coordination or self.cut.acquired.partition != receipt.position.partition or
            self.cut.acquired.next_lsn <= receipt.position.next_lsn) return error.InvalidTransactionCut;
        try receipt.binding.intent.transaction.begin.requireSame(self.cut.begin);
    }

    pub fn stage(self: Acquired, objects: c.storage.TransitObjectStore.ObjectStore, receipt: c.DirectClientToken.Receipt) !c.DirectRecord.Reference {
        try self.validate(receipt);
        var bytes: [max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        return c.DirectRecord.store(objects, receipt.binding.key.scope(), format, writer.buffered());
    }

    pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, state: c.DirectClientToken.Progress) !Acquired {
        const record = state.record orelse return error.TransactionCutNotAcquired;
        if (record.format == c.DirectTransactionWorkspace.head_format) {
            const W = c.DirectTransactionWorkspace;
            const head = try W.load(W.Head, allocator, objects, record, state.receipt.binding.key.scope(), W.head_format);
            try head.validate(state);
            return head.acquired;
        }
        if (record.format != format or record.content.bytes > max_bytes or
            !std.meta.eql(record.scope, state.receipt.binding.key.scope())) return error.InvalidTransactionCut;
        const bytes = try c.DirectRecord.load(allocator, objects, record);
        defer allocator.free(bytes);
        var scratch: [max_bytes]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(&scratch);
        const value = try std.json.parseFromSliceLeaky(Acquired, fixed.allocator(), bytes, .{});
        try value.validate(state.receipt);
        if (!std.meta.eql(value.cut.acquired, state.revision)) return error.InvalidTransactionCut;
        var canonical: [max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&canonical);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(value, &encoder);
        if (!std.mem.eql(u8, bytes, writer.buffered())) return error.InvalidTransactionCut;
        return value;
    }
};

pub const Reference = struct {
    connection: c.DirectTableProtocol.Connection,
    namespace: u64,
    begin: p.Transaction.Begin,
    /// Mandatory on saved work. Protected purposes use the same transaction
    /// decision and workspace; generic callers cannot choose or replace them.
    purpose: union(enum) { interactive, queue_transfer: c.DirectRecord.Reference },

    pub fn validate(self: Reference) !void {
        try self.connection.validate();
        try c.Model.nativeId(self.namespace);
        try self.begin.validate();
        if (self.purpose == .queue_transfer) {
            const plan = self.purpose.queue_transfer;
            try plan.validate();
            if (plan.format != c.DirectQueueTransferPlan.format or plan.content.bytes > c.DirectQueueTransferPlan.max_bytes or
                !std.meta.eql(plan.scope.connection, self.connection)) return error.InvalidTransactionTransfer;
        }
        if (!std.meta.eql(self.connection.scope, self.begin.identity.begin.scope) or
            self.connection.principal != self.begin.identity.begin.principal or self.connection.branch != self.begin.identity.branch)
            return error.TransactionIdentityConflict;
    }

    pub fn identity(self: Reference) p.DataLifecycle.Operation {
        return self.begin.identity.begin;
    }
};

/// Server admission ceilings, independent of the account's durable token quota.
pub const default_limits: p.Transaction.Limits = .{
    .resident_bytes = 16 * 1024 * 1024,
    .workspace_bytes = 1024 * 1024 * 1024,
    .participants = 100_000,
    .statements = 100_000,
    .savepoints = 1024,
};

pub fn requireLimits(requested: p.Transaction.Limits, maximum: p.Transaction.Limits) !void {
    try requested.validate();
    try maximum.validate();
    inline for (@typeInfo(p.Transaction.Limits).@"struct".field_names) |name| {
        if (@field(requested, name) > @field(maximum, name)) return error.TransactionCapacity;
    }
}

/// Validate all immutable selection entries before reserving a partition. This
/// is a descriptor check, not proof of a consistent cut or read authorization.
pub fn inspectSelection(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, reference: Reference, options: c.DirectCatalog.Options, server_selection: bool) !void {
    try reference.validate();
    // A caller-built subset cannot establish the complete authorized catalog
    // selection. That mode requires server-owned discovery under the cut fence.
    if (!server_selection and reference.begin.selection != .explicit_objects) return error.InvalidTransactionBegin;
    try requireLimits(reference.begin.limits, options.transaction_limits);
    var directory = try c.storage.TransactionDirectory.init(allocator, objects, reference.begin.identity, .participants, reference.begin.limits.participants, options.resident_pages, options.index_work_bytes);
    defer directory.deinit();
    try directory.restore(reference.begin.objects);
    var after: ?c.storage.TransactionDirectory.Cursor = null;
    var count: u64 = 0;
    while (true) {
        const page = try directory.page(after);
        for (page.entries) |slot| if (slot) |entry| {
            count = try std.math.add(u64, count, 1);
            if (count > directory.root.count) return error.InvalidTransactionDirectory;
            try entry.participant.validate(reference.begin.identity);
            switch (entry.participant) {
                .state => try entry.participant.requireLocalState(reference.begin),
                .log => if (reference.begin.selection != .explicit_objects) return error.InvalidTransactionBegin,
            }
            if (entry.participant.writes()) return error.InvalidTransactionBegin;
        };
        after = page.next orelse break;
    }
    if (count != directory.root.count or directory.root.writes != 0) return error.InvalidTransactionDirectory;
}

test "transaction admission signature binds the complete independent begin fixture" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-transaction-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    try t.expect(fixture.request.transport().mutation);
    var changed = fixture.request;
    changed.action.client_token.bind.intent.transaction.begin.limits.workspace_bytes += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.client_token.bind.intent.transaction.begin.identity.begin.principal += 1;
    try t.expectError(error.TransactionIdentityConflict, changed.action.client_token.bind.intent.transaction.validate());
}

test "transaction selection signature binds partition ordinals and rejects ambiguous targets" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-transaction-begin-v1.json"));
    defer parsed.deinit();
    const original = parsed.value.request;
    try original.validate(t.allocator);
    try original.proof.verify(parsed.value.public_key);
    const selected = original.action.transaction.begin.selection.explicit_objects;
    try t.expectEqual(@as(usize, 2), selected.len);
    try t.expectEqual(@as(u32, 0), selected[0].partition.?);
    try t.expectEqual(std.math.maxInt(u32), selected[1].partition.?);
    var targets = [2]p.Transaction.Target{ selected[0], selected[1] };
    var changed = original;
    changed.action.transaction.begin.selection = .{ .explicit_objects = &targets };
    targets[0].partition = 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    targets[0] = targets[1];
    try t.expectError(error.InvalidTransactionBegin, changed.action.transaction.begin.validate());
    targets[0] = selected[0];
    targets[0].partition = null;
    try t.expectError(error.InvalidTransactionTarget, changed.action.transaction.begin.validate());
    targets[0] = selected[0];
    targets[0].object.scope.realm += 1;
    try t.expectError(error.TransactionIdentityConflict, changed.action.transaction.begin.validate());
    targets[0] = selected[0];
    targets[1].kind = .stream;
    try t.expectError(error.InvalidTransactionBegin, changed.action.transaction.begin.validate());
}

test "transaction KV admission binds independent mutation bytes and private sequence" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-transaction-kv-v1.json"));
    defer parsed.deinit();
    const original = parsed.value.request;
    try original.validate(t.allocator);
    try original.proof.verify(parsed.value.public_key);
    try original.action.transaction.stage_kv.work.validate(t.allocator);
    var changed = original;
    changed.action.transaction.stage_kv.sequence += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = original;
    changed.action.transaction.stage_kv.basis.next_lsn += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = original;
    changed.action.transaction.stage_kv.work.binding.identity.operation -= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = original;
    changed.action.transaction.stage_kv.key.token[0] ^= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
}

test "transaction log admission binds independent source work and reservation commitments" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8, intent_digest: [32]u8, request_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-transaction-log-v1.json"));
    defer parsed.deinit();
    const original = parsed.value.request;
    try original.validate(t.allocator);
    try original.proof.verify(parsed.value.public_key);
    const request = original.action.transaction.log_statement.request;
    try request.validate();
    try t.expectEqual(parsed.value.intent_digest, try request.work.digest());
    try t.expectEqual(parsed.value.request_digest, (try request.binding()).request);
    var changed = original;
    changed.action.transaction.log_statement.request.basis.next_lsn += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = original;
    changed.action.transaction.log_statement.request.guard.source.accepted.next_lsn += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = original;
    changed.action.transaction.log_statement.execute = true;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = original;
    changed.action.transaction.log_statement.request.work.append.rows += 1;
    try t.expectError(error.TransactionIdentityConflict, changed.action.transaction.log_statement.request.validate());
}

test "transaction transfer reservations bind one statement and distinct public observations" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8, intent_digest: [32]u8, request_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-transaction-log-v1.json"));
    defer parsed.deinit();
    var request = parsed.value.request.action.transaction.log_statement.request;
    const original = request.work.append;
    var destination = original;
    destination.kind = .queue;
    destination.target.interpretation.object.object -= 1;
    destination.operation.operation -= 1;
    request.guard.kind = .queue;
    request.guard.source.next = 2;
    request.work = .{ .queue_transfer = .{ .operation = original.operation, .source = .{ .exhausted = .{ .target = original.target, .offset = 0, .lease_epoch = 2, .attempt = 1, .not_before_ms = 0 } }, .destination = destination } };
    request.statement.intent = try request.work.digest();
    const source = try request.binding();
    const target = (try request.destinationBinding()).?;
    try t.expectEqualDeep(source.statement, target.statement);
    try t.expectEqualDeep(source.request, target.request);
    try t.expectEqualDeep(original.operation, source.operation);
    try t.expectEqualDeep(destination.operation, target.operation);
    try t.expectEqualDeep(try request.work.digest(), source.operation_intent);
    try t.expectEqualDeep(try (c.DirectTransactionLogWork.Work{ .append = destination }).digest(), target.operation_intent);
    try t.expect(!std.mem.eql(u8, &source.operation_intent, &target.operation_intent));
    request.work.queue_transfer.source.exhausted.offset = 1;
    request.statement.intent = try request.work.digest();
    const changed = (try request.destinationBinding()).?;
    // An unchanged destination append cannot be reused for another source.
    try t.expectEqualDeep(target.operation_intent, changed.operation_intent);
    try t.expect(!std.mem.eql(u8, &target.request, &changed.request));
}
