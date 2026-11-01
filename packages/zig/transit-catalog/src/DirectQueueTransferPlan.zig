//! Frozen inputs for an exhausted Queue item's original paired transaction.
//! This descriptor neither admits work nor owns scheduling or completion. Its
//! catalog owner must retain the plan and payload before dispatch, serialize
//! sourceKey admission, and recover the original attempt before fresh discovery.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const x = p.Transaction;
const Self = @This();

definition: p.Growth.Definition,
key: c.DirectClientToken.Key,
namespace: u64,
operation: d.Operation,
transfer: x.TerminalTransfer,
limits: x.Limits,
budget: c.DirectClientToken.Budget,
settlement: d.Operation,

pub const format: u32 = 0x44515031; // DQP1, immutable plan, never progress.
pub const max_bytes = 8192;

pub fn validate(self: Self) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.key.validate();
    try c.Model.nativeId(self.namespace);
    try (c.DirectTransactionLogWork.Work{ .queue_transfer = self.transfer }).validate();
    try self.limits.validate();
    try self.budget.validate();
    if (self.transfer.source != .exhausted or self.limits.participants != 2 or self.limits.statements != 1)
        return error.InvalidTransactionTransfer;
    // Retain the frozen plan and payload even before a workspace is acquired.
    if (self.budget.bytes < try std.math.add(u64, max_bytes, self.transfer.destination.payload.bytes)) return error.ClientTokenBudget;
    try self.key.connection.object(self.transfer.target().interpretation.object);
    try self.key.connection.object(self.transfer.destination.target.interpretation.object);
    const identities = [_]d.Operation{ self.operation, self.settlement, self.transfer.operation, self.transfer.destination.operation };
    for (identities, 0..) |identity, i| {
        try self.key.connection.owner(identity);
        for (identities[0..i]) |earlier| if (std.meta.eql(identity, earlier)) return error.TransactionIdentityConflict;
    }
}

/// Global exhausted-item identity, independent of caller/account/role, policy
/// revision and proposed destination. A changed plan under this key conflicts;
/// changing the maintenance signer must not implicitly create a fresh attempt.
pub fn sourceKey(self: Self) ![32]u8 {
    try self.validate();
    return sourceDigest(self.transfer.source.exhausted);
}

/// Identity only; discovery and admission separately validate this tuple. This
/// lets a scheduler inspect the permanent binding before proposing new work.
pub fn sourceDigest(source: @FieldType(@FieldType(x.TerminalTransfer, "source"), "exhausted")) [32]u8 {
    const object = source.target.interpretation.object;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.queue-transfer.source.v1\x00");
    hash.update(&p.Growth.definition_bytes);
    var bytes: [8]u8 = undefined;
    inline for (.{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, source.target.partition, source.offset, source.lease_epoch, source.attempt, source.not_before_ms }) |value| {
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    return hash.finalResult();
}

pub fn encode(self: Self, output: *[max_bytes]u8) ![]const u8 {
    try self.validate();
    var writer: std.Io.Writer = .fixed(output);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(self, &encoder);
    return writer.buffered();
}

pub fn digest(self: Self) ![32]u8 {
    var bytes: [max_bytes]u8 = undefined;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.queue-transfer.plan.v1\x00");
    hash.update(try self.encode(&bytes));
    return hash.finalResult();
}

/// Owns all fields. Missing/foreign definitions and noncanonical bytes reject;
/// no current compatibility or transaction identity is filled into old work.
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len == 0 or bytes.len > max_bytes) return error.InvalidTransactionTransfer;
    const parsed = try p.Json.parseFromSlice(Self, allocator, bytes);
    defer parsed.deinit();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try parsed.value.encode(&canonical))) return error.InvalidTransactionTransfer;
    return parsed.value;
}

pub fn store(self: Self, objects: c.storage.TransitObjectStore.ObjectStore) !c.DirectRecord.Reference {
    var bytes: [max_bytes]u8 = undefined;
    return c.DirectRecord.store(objects, self.key.scope(), format, try self.encode(&bytes));
}

pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, reference: c.DirectRecord.Reference) !Self {
    try reference.validate();
    if (reference.format != format or reference.content.bytes > max_bytes) return error.InvalidTransactionTransfer;
    const bytes = try c.DirectRecord.load(allocator, objects, reference);
    defer allocator.free(bytes);
    const value = try decode(allocator, bytes);
    if (!std.meta.eql(value.key.scope(), reference.scope)) return error.TransactionIdentityConflict;
    return value;
}

/// The frozen plan belongs to this original standard transaction. An ordinary
/// transaction cannot adopt it, nor may another account or begin identity use it.
pub fn requireReceipt(self: Self, receipt: c.DirectClientToken.Receipt) !void {
    try self.validate();
    try receipt.validate();
    try self.key.requireSame(receipt.binding.key);
    if (receipt.binding.intent != .transaction) return error.InvalidTransactionTransfer;
    const reference = receipt.binding.intent.transaction;
    const begin_value = reference.begin;
    if (reference.purpose != .queue_transfer or reference.namespace != self.namespace or
        !std.meta.eql(begin_value.identity.begin, self.operation) or
        !std.meta.eql(begin_value.limits, self.limits) or !std.meta.eql(receipt.binding.budget, self.budget) or
        begin_value.mode != .serializable or begin_value.selection != .explicit_objects or
        begin_value.objects.count != 2 or
        !std.mem.eql(u8, &receipt.binding.fingerprint, &try self.digest())) return error.InvalidTransactionTransfer;
}

pub fn fromReceipt(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, receipt: c.DirectClientToken.Receipt) !Self {
    try receipt.validate();
    if (receipt.binding.intent != .transaction or receipt.binding.intent.transaction.purpose != .queue_transfer) return error.TransactionOperationRequired;
    const value = try load(allocator, objects, receipt.binding.intent.transaction.purpose.queue_transfer);
    try value.requireReceipt(receipt);
    return value;
}

/// Recovery validates the protected purpose as well as the common transaction
/// envelope. A terminal index update must carry the original decision/cleanup.
pub fn requireProgress(self: Self, allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !void {
    try self.requireReceipt(progress.receipt);
    try progress.validate();
    if (progress.cancel) return error.InvalidTransactionTransfer;
    const reference = progress.record orelse {
        if (!progress.pending) return error.InvalidTransactionTransfer;
        return;
    };
    if (reference.format == c.DirectTransactionControl.format) {
        const control = try c.DirectTransactionControl.load(allocator, objects, progress);
        if (!std.meta.eql(control.binding.attempt.operation, self.settlement)) return error.TransactionIdentityConflict;
        if (control.workspace) |head| try self.requireWorkspace(head);
        if (control.decision) |decision| if (decision.outcome == .committed and
            (control.binding.attempt.last_statement != 1 or control.binding.attempt.writes != 2)) return error.InvalidTransactionTransfer;
    } else try self.requireWorkspace(try c.DirectTransactionWorkspace.recover(allocator, objects, progress));
}

pub fn requireWorkspace(self: Self, head: c.DirectTransactionWorkspace.Head) !void {
    if (head.last_control != 0 or head.controls != null or head.savepoints != null or head.savepoint_count != 0 or
        head.pending_control != null or head.tables != null or head.last_statement > 1) return error.InvalidTransactionWorkspace;
    if (head.pending) |pending| {
        if (pending != .log or pending.log.statement.sequence != 1 or pending.log.work != .queue_transfer or
            !std.meta.eql(pending.log.work.queue_transfer, self.transfer)) return error.InvalidTransactionWorkspace;
    }
}

/// The caller owns targets for the lifetime of the returned request. Resolving
/// this selection does not replace the exact definitions in transfer: staging
/// and decision must still validate those original interpretations and rights.
pub fn begin(self: Self, targets: *[2]x.Target) !c.DirectTransactionRequest.Begin {
    try self.validate();
    targets.* = .{
        .{ .object = self.transfer.target().interpretation.object, .kind = .queue, .partition = self.transfer.target().partition },
        .{ .object = self.transfer.destination.target.interpretation.object, .kind = .queue, .partition = self.transfer.destination.target.partition },
    };
    if (targets[0].order(targets[1]) == .gt) std.mem.swap(x.Target, &targets[0], &targets[1]);
    const result: c.DirectTransactionRequest.Begin = .{ .key = self.key, .fingerprint = try self.digest(), .operation = self.operation, .namespace = self.namespace, .mode = .serializable, .selection = .{ .explicit_objects = targets }, .limits = self.limits, .budget = self.budget };
    try result.validate();
    return result;
}

fn fixture() Self {
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null }, .account = @splat(8), .token = @splat(1) };
    return .{
        .definition = p.Growth.current_definition,
        .key = key,
        .namespace = 1,
        .operation = .{ .scope = scope, .principal = 1, .operation = 10 },
        .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 1024 * 1024, .participants = 2, .statements = 1, .savepoints = 1 },
        .budget = .{ .bytes = 16 * 1024 },
        .settlement = .{ .scope = scope, .principal = 1, .operation = 12 },
        .transfer = .{
            .operation = .{ .scope = scope, .principal = 1, .operation = 13 },
            .source = .{ .exhausted = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 9 }, .revision = 2, .digest = @splat(3) }, .partition = 1 }, .offset = 7, .lease_epoch = 3, .attempt = 2, .not_before_ms = 100 } },
            .destination = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 8 }, .revision = 1, .digest = @splat(4) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 1, .operation = 14 }, .kind = .queue, .producer = null, .rows = 1, .payload = .{ .bytes = 100, .sha256 = @splat(5) } },
        },
    };
}

test "Queue transfer plan retains global source identity across policy and caller changes" {
    const t = std.testing;
    const original = fixture();
    const source = try original.sourceKey();
    var changed = original;
    changed.transfer.source.exhausted.target.interpretation.revision += 1;
    changed.transfer.source.exhausted.target.interpretation.digest = @splat(7);
    changed.transfer.destination.target.interpretation.revision += 1;
    changed.key.account = @splat(9);
    changed.key.connection.principal = 2;
    inline for (.{ "operation", "settlement" }) |name| @field(changed, name).principal = 2;
    changed.transfer.operation.principal = 2;
    changed.transfer.destination.operation.principal = 2;
    try t.expectEqual(source, try changed.sourceKey());
    try t.expect(!std.mem.eql(u8, &try original.digest(), &try changed.digest()));
    inline for (.{ "offset", "lease_epoch", "attempt", "not_before_ms" }) |name| {
        changed = original;
        @field(changed.transfer.source.exhausted, name) += 1;
        try t.expect(!std.mem.eql(u8, &source, &try changed.sourceKey()));
    }
    changed = original;
    changed.transfer.source.exhausted.target.partition += 1;
    try t.expect(!std.mem.eql(u8, &source, &try changed.sourceKey()));
    changed = original;
    changed.transfer.source.exhausted.target.interpretation.object.object += 1;
    try t.expect(!std.mem.eql(u8, &source, &try changed.sourceKey()));
}

test "Queue transfer plan binds distinct original identities and caller-owned sorted selection" {
    const t = std.testing;
    const original = fixture();
    var targets: [2]x.Target = undefined;
    const request = try original.begin(&targets);
    try t.expectEqual(@as(u64, 8), targets[0].object.object);
    try t.expectEqual(@as(u64, 9), targets[1].object.object);
    try t.expectEqual(@as(u32, 1), targets[1].partition.?);
    try t.expectEqualDeep(original.key, request.key);
    try t.expectEqualDeep(original.operation, request.operation);
    try t.expectEqual(try original.digest(), request.fingerprint);
    var changed = original;
    changed.settlement = changed.transfer.operation;
    try t.expectError(error.TransactionIdentityConflict, changed.validate());
    changed = original;
    changed.limits.statements = 2;
    try t.expectError(error.InvalidTransactionTransfer, changed.validate());
    changed = original;
    changed.budget.bytes = 512;
    try t.expectError(error.ClientTokenBudget, changed.validate());
    changed = original;
    changed.limits.participants = 1;
    try t.expectError(error.InvalidTransactionTransfer, changed.validate());
}

test "Queue transfer plan reopens exact disk records and refuses scope or canonical substitution" {
    const t = std.testing;
    const original = fixture();
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var reference: c.DirectRecord.Reference = undefined;
    {
        var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        reference = try original.store(objects.objectStore());
        try reference.requireSame(try original.store(objects.objectStore()));
    }
    var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    try t.expectEqualDeep(original, try load(t.allocator, objects.objectStore(), reference));
    var bytes: [max_bytes]u8 = undefined;
    const canonical = try original.encode(&bytes);
    var other_scope = original.key.scope();
    other_scope.account[0] ^= 1;
    const moved = try c.DirectRecord.store(objects.objectStore(), other_scope, format, canonical);
    try t.expectError(error.TransactionIdentityConflict, load(t.allocator, objects.objectStore(), moved));
    var foreign_format = reference;
    foreign_format.format = c.DirectBranch.format;
    try t.expectError(error.InvalidTransactionTransfer, load(t.allocator, objects.objectStore(), foreign_format));
    bytes[canonical.len] = ' ';
    try t.expectError(error.InvalidTransactionTransfer, decode(t.allocator, bytes[0 .. canonical.len + 1]));
    var missing: [max_bytes]u8 = undefined;
    const first_comma = std.mem.indexOfScalar(u8, canonical, ',').?;
    missing[0] = '{';
    @memcpy(missing[1 .. canonical.len - first_comma], canonical[first_comma + 1 ..]);
    try t.expectError(error.MissingField, decode(t.allocator, missing[0 .. canonical.len - first_comma]));
    const definition_at = std.mem.indexOf(u8, canonical, @tagName(p.Growth.current_definition)).?;
    @memset(bytes[definition_at .. definition_at + 64], '0');
    try t.expectError(error.InvalidJsonShape, decode(t.allocator, bytes[0..canonical.len]));
}
