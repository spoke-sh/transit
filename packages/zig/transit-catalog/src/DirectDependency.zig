//! Explicit definition dependencies owned by the direct catalog. A registration
//! protects its source against DROP; it neither publishes the dependent nor pins
//! a read cut. The dependent's owner registers before publication and removes
//! the edge only after retirement or abandoned-publication recovery.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const pages = c.storage.TreeStore.pages;

pub const Dependent = struct {
    kind: enum(u8) { kv = 1, document = 2, captured = 3, maintained = 4 },
    interpretation: d.Definition,

    pub fn validate(self: Dependent) !void {
        try self.interpretation.validate();
        if (self.interpretation.object.branch != 1) return error.InvalidCatalogDependency;
    }
};

pub const Edge = struct {
    source: d.Definition,
    dependent: Dependent,
    /// Required Table actions, checked at registration. This declaration never
    /// grants those actions; execution must check current policy independently.
    privileges: u64,

    pub fn validate(self: Edge) !void {
        try self.source.validate();
        try self.dependent.validate();
        if (self.source.object.branch != 1 or
            self.source.object.scope.realm != self.dependent.interpretation.object.scope.realm or
            self.privileges == 0 or self.privileges & ~c.TableAuthority.table_actions != 0)
            return error.InvalidCatalogDependency;
    }

    pub fn digest(self: Edge) ![32]u8 {
        try self.validate();
        var bytes: [169]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writeDefinition(&writer, self.source);
        try writer.writeByte(@backingInt(self.dependent.kind));
        try writeDefinition(&writer, self.dependent.interpretation);
        try writer.writeInt(u64, self.privileges, .big);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.dependency.v1\x00");
        hash.update(writer.buffered());
        return hash.finalResult();
    }

    pub fn forwardKey(self: Edge) !pages.Key {
        var bytes: [40]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.source.object.object, .big);
        bytes[8..40].* = try self.digest();
        return pages.Key.init(&bytes);
    }

    pub fn reverseKey(self: Edge) !pages.Key {
        var bytes: [64]u8 = undefined;
        bytes[0..32].* = try dependentKey(self.dependent.interpretation.object);
        bytes[32..64].* = try self.digest();
        return pages.Key.init(&bytes);
    }
};

fn writeDefinition(writer: *std.Io.Writer, value: d.Definition) !void {
    const object = value.object;
    for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, value.revision }) |field|
        try writer.writeInt(u64, field, .big);
    try writer.writeAll(&value.digest);
}

/// Stable dependent object prefix, shared by all its immutable revisions.
/// Full records are compared whenever a digest key already exists.
pub fn dependentKey(object: d.Object) ![32]u8 {
    try object.validate();
    var bytes: [40]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object }) |value|
        try writer.writeInt(u64, value, .big);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.dependent.v1\x00");
    hash.update(&bytes);
    return hash.finalResult();
}

pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    operation: u64,
    edge: Edge,
    action: enum { register, remove },
    authority: Authority,

    pub fn identity(self: Binding) d.Operation {
        return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
    }

    pub fn validate(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.identity().validate();
        try self.edge.validate();
        try self.connection.object(self.edge.source.object);
        if (self.authority == .catalog_administrator and self.action != .remove) return error.InvalidCatalogDependency;
    }

    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

pub const Command = enum { inspect, accept, cancel };
/// Normal lifecycle operations require the dependent's metadata permissions.
/// Explicit orphan cleanup requires current realm ADMIN and source ownership;
/// it changes only the registration, never retires or executes a consumer.
pub const Authority = enum { dependent, catalog_administrator };
pub const Outcome = struct {
    binding: Binding,
    position: d.Position,
    phase: enum { applied, rejected, cancelled },
    reason: enum { none, stale_definition, source_busy },
    changed: bool,

    pub fn validate(self: Outcome) !void {
        try self.binding.validate();
        try self.position.validate();
        if (self.position.next_lsn == 0 or (self.phase == .rejected) != (self.reason != .none) or
            (self.changed and self.phase != .applied) or (self.phase == .rejected and self.binding.action != .register))
            return error.InvalidCatalogDependency;
    }
};
pub const Observation = union(enum) { not_observed, outcome: Outcome };

pub const Selection = union(enum) { dependents: d.Object, dependencies: d.Object };
pub const Cursor = struct { selection: Selection, authority: Authority, position: d.Position, after: [32]u8 };
// Four distinct source schemas/Tables plus the database and dependent resource
// fit the native guard's 16 requirements, including the final disclosure fence.
pub const page_entries = 4;
pub const Page = struct {
    entries: [page_entries]?Edge = @splat(null),
    next: ?Cursor = null,
    position: d.Position,
};

test "direct dependency keys match independent full-width big-endian fixtures" {
    const t = std.testing;
    const maximum = std.math.maxInt(u64);
    const edge: Edge = .{
        .source = .{ .object = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = maximum }, .branch = 1, .object = maximum - 1 }, .revision = maximum - 2, .digest = @splat(3) },
        .dependent = .{ .kind = .captured, .interpretation = .{ .object = .{ .scope = .{ .realm = 42, .resource = 9, .catalog = 8 }, .branch = 1, .object = 99 }, .revision = maximum, .digest = @splat(4) } },
        .privileges = 1,
    };
    // Independent Python struct.pack and hashlib.sha256 over two 80-byte
    // definitions, a one-byte kind and an eight-byte privilege mask.
    var expected: [64]u8 = undefined;
    const digest = try edge.digest();
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, "8d932f49874790531cfa8a4de80e87cf9a6e6ec3b5ddc3468fe3578f1f4fdec9"), &digest);
    const forward = try edge.forwardKey();
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, "fffffffffffffffe8d932f49874790531cfa8a4de80e87cf9a6e6ec3b5ddc3468fe3578f1f4fdec9"), forward.slice());
    const reverse = try edge.reverseKey();
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, "9c758b9a8f7db68b40ee5494890400e7076c0be2bbf8cacbbfeecb87b229ef138d932f49874790531cfa8a4de80e87cf9a6e6ec3b5ddc3468fe3578f1f4fdec9"), reverse.slice());
    var changed = edge;
    changed.privileges = 0;
    try t.expectError(error.InvalidCatalogDependency, changed.validate());
    changed = edge;
    changed.dependent.interpretation.object.scope.realm += 1;
    try t.expectError(error.InvalidCatalogDependency, changed.validate());
}
