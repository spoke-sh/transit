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
    transaction_statement: c.DirectTransactionWorkspace.Request,
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
    fn validate(self: Stored) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
    }
    fn identity(self: Stored) d.Operation {
        return switch (self) {
            .transaction => |value| value.reference.identity(),
            .transaction_statement => |value| value.binding.identity,
            .external => |value| value.identity(),
            .data => |value| value.identity,
            .name_assertion => |value| value.identity(),
            .namespace => |value| value.identity(),
            .dependency => |value| value.identity(),
            .resource => |value| value.identity(),
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
pub fn claim(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: d.Binding) !void {
    return claimStored(allocator, objects, .{ .data = binding });
}
pub fn claimExternal(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectIntent.External) !void {
    return claimStored(allocator, objects, .{ .external = binding });
}
pub fn claimTransactionStatement(allocator: std.mem.Allocator, objects: Objects.ObjectStore, request: c.DirectTransactionWorkspace.Request) !void {
    return claimStored(allocator, objects, .{ .transaction_statement = request });
}
pub fn claimTransaction(allocator: std.mem.Allocator, objects: Objects.ObjectStore, reference: c.DirectTransaction.Reference, token: [32]u8) !void {
    return claimStored(allocator, objects, .{ .transaction = .{ .reference = reference, .token = token } });
}
pub fn lookup(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?d.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .data => |value| value,
        .external, .name_assertion, .namespace, .dependency, .resource, .transaction, .transaction_statement => error.DataIdentityConflict,
    };
}
pub fn claimAssertion(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.NameAssertion.Binding) !void {
    return claimStored(allocator, objects, .{ .name_assertion = binding });
}
pub fn lookupAssertion(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.NameAssertion.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .name_assertion => |value| value,
        .external, .data, .namespace, .dependency, .resource, .transaction, .transaction_statement => error.DataIdentityConflict,
    };
}
pub fn claimNamespace(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectNamespace.Binding) !void {
    return claimStored(allocator, objects, .{ .namespace = binding });
}
pub fn lookupNamespace(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectNamespace.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .namespace => |value| value,
        .external, .data, .name_assertion, .dependency, .resource, .transaction, .transaction_statement => error.DataIdentityConflict,
    };
}
pub fn claimDependency(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectDependency.Binding) !void {
    return claimStored(allocator, objects, .{ .dependency = binding });
}
pub fn lookupDependency(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectDependency.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .dependency => |value| value,
        .external, .data, .name_assertion, .namespace, .resource, .transaction, .transaction_statement => error.DataIdentityConflict,
    };
}
pub fn claimResource(allocator: std.mem.Allocator, objects: Objects.ObjectStore, binding: c.DirectResource.Binding) !void {
    return claimStored(allocator, objects, .{ .resource = binding });
}
pub fn lookupResource(allocator: std.mem.Allocator, objects: Objects.ObjectStore, operation: d.Operation) !?c.DirectResource.Binding {
    const stored = try lookupStored(allocator, objects, operation) orelse return null;
    return switch (stored) {
        .resource => |value| value,
        .external, .data, .name_assertion, .namespace, .dependency, .transaction, .transaction_statement => error.DataIdentityConflict,
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
    const accepted = objects.putImmutable(try key(binding.identity(), &name), encoded, digest) catch |err| {
        if (err != error.ImmutableObjectConflict) return err;
        const previous = try lookupStored(allocator, objects, binding.identity()) orelse return error.InvalidOperationBinding;
        try previous.requireSame(binding);
        return;
    };
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
