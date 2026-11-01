//! Immutable catalog-scoped operation-to-target binding. This is an internal
//! identity reservation, never admission, authorization or operation completion.
//! The service authorizes the original caller before using this storage owner.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const Objects = c.storage.TransitObjectStore;
const header_bytes = 40;
pub const max_bytes = 4096;
const Stored = union(enum) {
    transaction_call: c.DirectTransactionCall,
    transaction_savepoint: c.DirectTransactionSavepoint.Request,
    transaction_attempt: c.storage.TransactionDecisionLog.Binding,
    transaction_statement: c.DirectTransactionWorkspace.Request,
    transaction_log_statement: c.DirectTransactionLogWork.Binding,
    transaction: struct {
        reference: c.DirectTransaction.Reference,
        token: [32]u8,
        pub fn validate(self: @This()) !void {
            try self.reference.validate();
            if (std.mem.allEqual(u8, &self.token, 0)) return error.InvalidClientToken;
        }
    },
    external: c.DirectIntent.External,
    data: d.Binding,
    name_assertion: c.NameAssertion.Binding,
    namespace: c.DirectNamespace.Binding,
    dependency: c.DirectDependency.Binding,
    resource: c.DirectResource.Binding,
    stream: c.DirectStreamMutation.Binding,
    queue: c.DirectQueueMutation.Binding,
    fn validate(self: Stored) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
    }
    fn identity(self: Stored) d.Operation {
        return switch (self) {
            .transaction_call => |value| value.identity(),
            .transaction_savepoint => |value| value.operation,
            .transaction_attempt => |value| value.attempt.operation,
            .transaction => |value| value.reference.identity(),
            .transaction_statement => |value| value.binding.identity,
            .transaction_log_statement => |value| value.operation,
            .external => |value| value.identity(),
            .data => |value| value.identity,
            .name_assertion => |value| value.identity(),
            .namespace => |value| value.identity(),
            .dependency => |value| value.identity(),
            .resource => |value| value.identity(),
            .stream => |value| value.operation,
            .queue => |value| value.operation,
        };
    }
    fn requireSame(self: Stored, other: Stored) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

pub fn key(operation: d.Operation, output: *[96]u8) ![]const u8 {
    try operation.validate();
    var bytes: [40]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    for ([_]u64{ operation.scope.realm, operation.scope.resource, operation.scope.catalog, operation.principal, operation.operation }) |value| try writer.writeInt(u64, value, .little);
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.catalog.operation.binding.v1\x00");
    digest.update(&bytes);
    return std.fmt.bufPrint(output, "data-operations/{x}.data", .{&digest.finalResult()});
}

fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

fn lookupStored(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?Stored {
    var name: [96]u8 = undefined;
    const object_key = try key(operation, &name);
    const metadata = try objects.head(object_key) orelse return null;
    if (metadata.size < header_bytes or metadata.size > max_bytes) return error.InvalidOperationBinding;
    var bytes: [max_bytes]u8 = undefined;
    const stored = try objects.getRange(object_key, 0, @intCast(metadata.size), &bytes);
    if (stored.len != metadata.size or !std.mem.eql(u8, &hash(stored), &metadata.sha256)) return error.InvalidOperationBinding;
    if (!std.mem.eql(u8, stored[0..8], "TOPBIND1")) return error.InvalidOperationBinding;
    if (!std.mem.eql(u8, stored[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try std.json.parseFromSlice(Stored, allocator, stored[header_bytes..], .{});
    defer parsed.deinit();
    try parsed.value.validate();
    if (!std.meta.eql(parsed.value.identity(), operation)) return error.InvalidOperationBinding;
    return parsed.value;
}

/// Exact retry is idempotent even if the prior immutable publication lost its
/// reply. The full binding is compared on conflict, never just the target ID.
pub fn encodeData(binding: d.Binding, output: *[max_bytes]u8) !struct { bytes: []const u8, sha256: [32]u8 } {
    const stored: Stored = .{ .data = binding };
    try stored.validate();
    output[0..8].* = "TOPBIND1".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    try std.json.Stringify.value(stored, .{}, &writer);
    const encoded = output[0 .. header_bytes + writer.end];
    return .{ .bytes = encoded, .sha256 = hash(encoded) };
}
pub fn claim(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: d.Binding) !void {
    return claimStored(allocator, objects, .{ .data = binding });
}
pub fn claimInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, binding: d.Binding) !void {
    return claimStoredInTree(allocator, index, .{ .data = binding });
}
pub fn claimExternal(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectIntent.External) !void {
    return claimStored(allocator, objects, .{ .external = binding });
}
pub fn claimExternalInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, binding: c.DirectIntent.External) !void {
    return claimStoredInTree(allocator, index, .{ .external = binding });
}
pub fn claimStream(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectStreamMutation.Binding) !void {
    return claimStored(allocator, objects, .{ .stream = binding });
}
pub fn lookupStream(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectStreamMutation.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .stream => |value| value,
        .queue, .external, .data, .name_assertion, .namespace, .dependency, .resource, .transaction, .transaction_statement, .transaction_log_statement, .transaction_attempt, .transaction_savepoint, .transaction_call => error.DataIdentityConflict,
    };
}
pub fn claimQueue(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectQueueMutation.Binding) !void {
    return claimStored(allocator, objects, .{ .queue = binding });
}
pub fn lookupQueue(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectQueueMutation.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .queue => |value| value,
        else => error.DataIdentityConflict,
    };
}
pub fn claimTransactionStatement(allocator: std.mem.Allocator, objects: Objects.ObjectStore, request: c.DirectTransactionWorkspace.Request) !void {
    return claimStored(allocator, objects, .{ .transaction_statement = request });
}
pub fn claimTransactionLogStatement(allocator: std.mem.Allocator, objects: Objects.ObjectStore, request: c.DirectTransactionLogWork.Request) !void {
    try claimStored(allocator, objects, .{ .transaction_log_statement = try request.binding() });
    // Either immutable reservation may survive a failed attempt. Retrying the
    // same complete request repairs the pair; neither identity is reusable.
    if (try request.destinationBinding()) |destination| try claimStored(allocator, objects, .{ .transaction_log_statement = destination });
}
/// A read-only operation lookup may disclose an actual published receipt for
/// this exact work. This neither releases its reservation nor permits autocommit;
/// before a common commit, the public owner has no such receipt to disclose.
pub fn transactionLogObservation(allocator: std.mem.Allocator, objects: Objects.ObjectStore, work: c.DirectTransactionLogWork.Work) !bool {
    try work.validate();
    const stored = try lookupStored(allocator, objects, work.operation()) orelse return false;
    if (stored != .transaction_log_statement) return false;
    const reservation = stored.transaction_log_statement;
    if (!std.meta.eql(reservation.operation, work.operation()) or !std.meta.eql(reservation.target, work.target()) or
        !std.mem.eql(u8, &reservation.operation_intent, &try work.digest())) return error.DataIdentityConflict;
    return true;
}
pub fn claimTransactionCall(allocator: std.mem.Allocator, objects: Objects.ObjectStore, request: c.DirectTransactionCall) !void {
    return claimStored(allocator, objects, .{ .transaction_call = request });
}
pub fn claimTransactionCallInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, request: c.DirectTransactionCall) !void {
    return claimStoredInTree(allocator, index, .{ .transaction_call = request });
}
pub fn claimTransactionSavepoint(allocator: std.mem.Allocator, objects: Objects.ObjectStore, request: c.DirectTransactionSavepoint.Request) !void {
    return claimStored(allocator, objects, .{ .transaction_savepoint = request });
}
pub fn claimTransactionAttempt(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.storage.TransactionDecisionLog.Binding) !void {
    return claimStored(allocator, objects, .{ .transaction_attempt = binding });
}
pub fn claimTransaction(allocator: std.mem.Allocator, objects: Objects.ObjectStore, reference: c.DirectTransaction.Reference, token: [32]u8) !void {
    return claimStored(allocator, objects, .{ .transaction = .{ .reference = reference, .token = token } });
}
pub fn claimTransactionInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, reference: c.DirectTransaction.Reference, token: [32]u8) !void {
    return claimStoredInTree(allocator, index, .{ .transaction = .{ .reference = reference, .token = token } });
}
pub fn lookup(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?d.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .data => |value| value,
        .queue, .stream, .external, .name_assertion, .namespace, .dependency, .resource, .transaction, .transaction_statement, .transaction_log_statement, .transaction_attempt, .transaction_savepoint, .transaction_call => error.DataIdentityConflict,
    };
}
pub fn claimAssertion(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.NameAssertion.Binding) !void {
    return claimStored(allocator, objects, .{ .name_assertion = binding });
}
pub fn claimAssertionInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, binding: c.NameAssertion.Binding) !void {
    return claimStoredInTree(allocator, index, .{ .name_assertion = binding });
}
pub fn lookupAssertion(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.NameAssertion.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .name_assertion => |value| value,
        .queue, .stream, .external, .data, .namespace, .dependency, .resource, .transaction, .transaction_statement, .transaction_log_statement, .transaction_attempt, .transaction_savepoint, .transaction_call => error.DataIdentityConflict,
    };
}
pub fn claimNamespace(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectNamespace.Binding) !void {
    return claimStored(allocator, objects, .{ .namespace = binding });
}
pub fn claimNamespaceInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, binding: c.DirectNamespace.Binding) !void {
    return claimStoredInTree(allocator, index, .{ .namespace = binding });
}
pub fn lookupNamespace(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectNamespace.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .namespace => |value| value,
        .queue, .stream, .external, .data, .name_assertion, .dependency, .resource, .transaction, .transaction_statement, .transaction_log_statement, .transaction_attempt, .transaction_savepoint, .transaction_call => error.DataIdentityConflict,
    };
}
pub fn claimDependency(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectDependency.Binding) !void {
    return claimStored(allocator, objects, .{ .dependency = binding });
}
pub fn claimDependencyInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, binding: c.DirectDependency.Binding) !void {
    return claimStoredInTree(allocator, index, .{ .dependency = binding });
}
pub fn lookupDependency(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectDependency.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .dependency => |value| value,
        .queue, .stream, .external, .data, .name_assertion, .namespace, .resource, .transaction, .transaction_statement, .transaction_log_statement, .transaction_attempt, .transaction_savepoint, .transaction_call => error.DataIdentityConflict,
    };
}
pub fn claimResource(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectResource.Binding) !void {
    return claimStored(allocator, objects, .{ .resource = binding });
}
pub fn claimResourceInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, binding: c.DirectResource.Binding) !void {
    return claimStoredInTree(allocator, index, .{ .resource = binding });
}
pub fn lookupResource(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectResource.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .resource => |value| value,
        .queue, .stream, .external, .data, .name_assertion, .namespace, .dependency, .transaction, .transaction_statement, .transaction_log_statement, .transaction_attempt, .transaction_savepoint, .transaction_call => error.DataIdentityConflict,
    };
}
fn claimStored(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: Stored) !void {
    try binding.validate();
    var bytes: [max_bytes]u8 = undefined;
    bytes[0..8].* = "TOPBIND1".*;
    bytes[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(bytes[header_bytes..]);
    try std.json.Stringify.value(binding, .{}, &writer);
    const encoded = bytes[0 .. header_bytes + writer.end];
    const digest = hash(encoded);
    var name: [96]u8 = undefined;
    const object_key = try key(binding.identity(), &name);
    if (try objects.head(object_key)) |existing| {
        const previous = try lookupStored(allocator, objects, binding.identity()) orelse return error.InvalidOperationBinding;
        try previous.requireSame(binding);
        if (existing.size != encoded.len or !std.mem.eql(u8, &existing.sha256, &digest)) return error.InvalidOperationBinding;
        return;
    }
    const accepted = objects.putImmutable(object_key, encoded, digest) catch |err| {
        if (err != error.ImmutableObjectConflict) return err;
        const previous = try lookupStored(allocator, objects, binding.identity()) orelse return error.InvalidOperationBinding;
        try previous.requireSame(binding);
        return;
    };
    if (accepted.size != encoded.len or !std.mem.eql(u8, &accepted.sha256, &digest)) return error.InvalidOperationBinding;
}
fn claimStoredInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, binding: Stored) !void {
    try binding.validate();
    var bytes: [max_bytes]u8 = undefined;
    bytes[0..8].* = "TOPBIND1".*;
    bytes[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(bytes[header_bytes..]);
    try std.json.Stringify.value(binding, .{}, &writer);
    const encoded = bytes[0 .. header_bytes + writer.end];
    const digest = hash(encoded);
    var name: [96]u8 = undefined;
    const object_key = try key(binding.identity(), &name);
    if (try index.store.head(object_key)) |existing| {
        const previous = try lookupStored(allocator, index.store, binding.identity()) orelse return error.InvalidOperationBinding;
        try previous.requireSame(binding);
        if (existing.size != encoded.len or !std.mem.eql(u8, &existing.sha256, &digest)) return error.InvalidOperationBinding;
        return;
    }
    const accepted = try index.stageObject(object_key, encoded, digest);
    if (accepted.size != encoded.len or !std.mem.eql(u8, &accepted.sha256, &digest)) return error.InvalidOperationBinding;
}

test "catalog operation bindings prevent retargeting across object and branch replacement after disk reopen" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = std.math.maxInt(u64) };
    const binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 0, .operation = std.math.maxInt(u64) }, .target = .{ .scope = scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(3) };
    // Independent Python hashlib/struct oracle, with full-width catalog and
    // operation IDs. The key deliberately excludes the target and intent.
    var name: [96]u8 = undefined;
    try t.expectEqualStrings("data-operations/8d2458f690d14349b17512d5d791113ed482f3fd268c6267752ee2324220bffe.data", try key(binding.identity, &name));
    {
        var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        try t.expect((try lookup(t.allocator, objects.objectStore(), binding.identity)) == null);
        try claim(t.allocator, objects.objectStore(), binding);
    }
    var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    try claim(t.allocator, objects.objectStore(), binding);
    try t.expectEqualDeep(binding, (try lookup(t.allocator, objects.objectStore(), binding.identity)).?);
    var replacement = binding;
    replacement.target.object = 8;
    try t.expectError(error.DataIdentityConflict, claim(t.allocator, objects.objectStore(), replacement));
    replacement = binding;
    replacement.target.branch = 2;
    try t.expectError(error.DataIdentityConflict, claim(t.allocator, objects.objectStore(), replacement));
    replacement = binding;
    replacement.intent[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, claim(t.allocator, objects.objectStore(), replacement));
    // Many operations share no in-memory directory or global root mutation.
    for (1..130) |operation| {
        var independent = binding;
        independent.identity.operation = operation;
        independent.target.object = operation;
        try claim(t.allocator, objects.objectStore(), independent);
    }
    try t.expectEqualDeep(binding, (try lookup(t.allocator, objects.objectStore(), binding.identity)).?);
}

test "catalog operation claims reject damaged and foreign bytes even under their retained key" {
    const t = std.testing;
    var objects = c.storage.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
    const binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 1 }, .target = .{ .scope = scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(3) };
    try claim(t.allocator, objects.objectStore(), binding);
    const stored = &objects.objects.items[0];
    stored.bytes[8] ^= 1;
    try t.expectError(error.InvalidOperationBinding, lookup(t.allocator, objects.objectStore(), binding.identity));
    stored.sha256 = hash(stored.bytes);
    try t.expectError(error.IncompatibleDefinition, lookup(t.allocator, objects.objectStore(), binding.identity));
    try t.expectError(error.IncompatibleDefinition, claim(t.allocator, objects.objectStore(), binding));
}

test "Queue reservations freeze lease intent and exclude other catalog operation kinds on disk" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 9 };
    const claim_work: c.DirectQueueMutation.Request = .{ .claim = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(3) }, .partition = 2 },
        .operation = .{ .scope = scope, .principal = 0, .operation = std.math.maxInt(u64) },
        .maximum = 2,
        .lease_ms = 100,
    } };
    const binding = try claim_work.binding(t.allocator);
    {
        var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        try claimQueue(t.allocator, objects.objectStore(), binding);
    }
    var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    try t.expectEqualDeep(binding, (try lookupQueue(t.allocator, objects.objectStore(), binding.operation)).?);
    for (0..4) |change| {
        var changed = claim_work;
        switch (change) {
            0 => changed.claim.maximum += 1,
            1 => changed.claim.lease_ms += 1,
            2 => changed.claim.target.partition += 1,
            3 => changed.claim.target.interpretation.revision += 1,
            else => unreachable,
        }
        try t.expectError(error.DataIdentityConflict, claimQueue(t.allocator, objects.objectStore(), try changed.binding(t.allocator)));
    }
    const stream: c.DirectStreamMutation.Request = .{ .consume = .{ .target = claim_work.target(), .operation = claim_work.identity(), .group = null, .from = 0, .until = null, .timestamp = null } };
    try t.expectError(error.DataIdentityConflict, claimStream(t.allocator, objects.objectStore(), try stream.binding(t.allocator)));
    var settlement: c.DirectQueueMutation.Request = .{ .settle = .{
        .operation = .{ .scope = scope, .principal = 0, .operation = 11 },
        .lease = .{ .target = claim_work.target(), .claim = claim_work.identity(), .offset = 9, .epoch = 3, .attempt = 2, .expires_ms = 200 },
        .action = .{ .extend = .{ .expires_ms = 300 } },
    } };
    const original = try settlement.binding(t.allocator);
    try claimQueue(t.allocator, objects.objectStore(), original);
    settlement.settle.action.extend.expires_ms += 1;
    try t.expectError(error.DataIdentityConflict, claimQueue(t.allocator, objects.objectStore(), try settlement.binding(t.allocator)));
    settlement.settle.action = .ack;
    try t.expectError(error.DataIdentityConflict, claimQueue(t.allocator, objects.objectStore(), try settlement.binding(t.allocator)));
    try claimQueue(t.allocator, objects.objectStore(), original);
}

test "stream mutation reservations share original catalog identity across kinds and restart" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = std.math.maxInt(u64) };
    const mutation: c.DirectStreamMutation.Request = .{ .consume = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(3) }, .partition = 2 },
        .operation = .{ .scope = scope, .principal = 0, .operation = std.math.maxInt(u64) },
        .from = 0,
        .until = null,
        .group = null,
        .timestamp = null,
    } };
    const binding = try mutation.binding(t.allocator);
    {
        var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        try t.expect((try lookupStream(t.allocator, objects.objectStore(), binding.operation)) == null);
        try claimStream(t.allocator, objects.objectStore(), binding);
    }
    var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    try claimStream(t.allocator, objects.objectStore(), binding);
    try t.expectEqualDeep(binding, (try lookupStream(t.allocator, objects.objectStore(), binding.operation)).?);
    var changed = mutation;
    changed.consume.target.partition += 1;
    try t.expectError(error.DataIdentityConflict, claimStream(t.allocator, objects.objectStore(), try changed.binding(t.allocator)));
    changed = mutation;
    changed.consume.until = 0;
    try t.expectError(error.DataIdentityConflict, claimStream(t.allocator, objects.objectStore(), try changed.binding(t.allocator)));
    var table: d.Binding = .{ .definition = p.Growth.current_definition, .identity = binding.operation, .target = binding.target.interpretation.object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(3) };
    try t.expectError(error.DataIdentityConflict, claim(t.allocator, objects.objectStore(), table));
    try t.expectError(error.DataIdentityConflict, lookup(t.allocator, objects.objectStore(), binding.operation));
    table.identity.operation -= 1;
    try claim(t.allocator, objects.objectStore(), table);
    changed = mutation;
    changed.consume.operation = table.identity;
    try t.expectError(error.DataIdentityConflict, claimStream(t.allocator, objects.objectStore(), try changed.binding(t.allocator)));
    try t.expectError(error.DataIdentityConflict, lookupStream(t.allocator, objects.objectStore(), table.identity));
    // A reservation retains the original input even before its actual read
    // acceptance. Replaying it cannot substitute another upper-bound choice.
    try t.expectEqualDeep(binding, (try lookupStream(t.allocator, objects.objectStore(), binding.operation)).?);
}
