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
    kind: enum(u8) { kv = 1, document = 2, captured = 3, maintained = 4, stream = 5, queue = 6, table = 7 },
    interpretation: d.Definition,

    pub fn validate(self: Dependent) !void {
        try self.interpretation.validate();
        if (self.interpretation.object.branch != 1) return error.InvalidCatalogDependency;
    }
};

pub const Edge = struct {
    source: d.Definition,
    dependent: Dependent,
    /// Required logical actions, checked at registration. KV sources use
    /// KVAuthority privileges; Document SELECT maps to native INSPECT/READ. This never
    /// grants access; execution checks current policy independently.
    privileges: u64,
    foreign_key: ?struct { constraint: u32, column: u64 } = null,

    pub fn validate(self: Edge) !void {
        try self.source.validate();
        if (self.foreign_key) |fk| if (self.dependent.kind != .table or fk.constraint == 0 or fk.column == 0) return error.InvalidCatalogDependency;
        if (self.dependent.kind == .table and self.foreign_key == null) return error.InvalidCatalogDependency;
        try self.dependent.validate();
        if (self.source.object.branch != 1 or
            self.source.object.scope.realm != self.dependent.interpretation.object.scope.realm or
            (self.privileges == 0 and self.foreign_key == null) or self.privileges & ~c.LogAuthority.all_privileges != 0)
            return error.InvalidCatalogDependency;
    }

    pub fn digest(self: Edge) ![32]u8 {
        try self.validate();
        var bytes: [181]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writeDefinition(&writer, self.source);
        try writer.writeByte(@backingInt(self.dependent.kind));
        try writeDefinition(&writer, self.dependent.interpretation);
        try writer.writeInt(u64, self.privileges, .big);
        if (self.foreign_key) |fk| {
            try writer.writeInt(u32, fk.constraint, .big);
            try writer.writeInt(u64, fk.column, .big);
        }
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.dependency.v1\x00");
        hash.update(writer.buffered());
        return hash.finalResult();
    }

    pub fn forwardKey(self: Edge) !pages.Key {
        var bytes: [49]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.source.object.object, .big);
        bytes[8] = @intFromBool(self.foreign_key != null);
        const offset: usize = if (self.foreign_key) |fk| blk: {
            std.mem.writeInt(u64, bytes[9..17], fk.column, .big);
            break :blk 17;
        } else 9;
        bytes[offset..][0..32].* = try self.digest();
        return pages.Key.init(bytes[0 .. offset + 32]);
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
/// Current graph membership is distinct from an immutable operation receipt.
pub const State = struct { edge: Edge, position: d.Position, present: bool };

pub const Selection = union(enum) { dependents: d.Object, dependencies: d.Object };
pub const Cursor = struct {
    selection: Selection,
    authority: Authority,
    position: d.Position,
    after: pages.Key,
    pub fn validate(self: Cursor) !void {
        try self.position.validate();
        self.after.validate() catch return error.InvalidCatalogCursor;
        if (self.position.next_lsn == 0) return error.InvalidCatalogCursor;
        switch (self.selection) {
            .dependencies => |object| {
                const prefix = try dependentKey(object);
                if (self.after.len != 64 or !std.mem.startsWith(u8, self.after.slice(), &prefix)) return error.InvalidCatalogCursor;
            },
            .dependents => |object| {
                try object.validate();
                if ((self.after.len != 41 and self.after.len != 49) or std.mem.readInt(u64, self.after.data[0..8], .big) != object.object or self.after.data[8] != @intFromBool(self.after.len == 49)) return error.InvalidCatalogCursor;
                if (self.after.len == 49 and std.mem.readInt(u64, self.after.data[9..17], .big) == 0) return error.InvalidCatalogCursor;
            },
        }
    }
};
// Four distinct source schemas/objects plus the database and dependent authority
// fit the native guard's 16 requirements. Graph inspection uses metadata rights;
// data access is checked separately during registration and execution.
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
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, "fffffffffffffffe008d932f49874790531cfa8a4de80e87cf9a6e6ec3b5ddc3468fe3578f1f4fdec9"), forward.slice());
    const reverse = try edge.reverseKey();
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, "9c758b9a8f7db68b40ee5494890400e7076c0be2bbf8cacbbfeecb87b229ef138d932f49874790531cfa8a4de80e87cf9a6e6ec3b5ddc3468fe3578f1f4fdec9"), reverse.slice());
    var changed = edge;
    changed.privileges = 0;
    try t.expectError(error.InvalidCatalogDependency, changed.validate());
    changed = edge;
    changed.dependent.interpretation.object.scope.realm += 1;
    try t.expectError(error.InvalidCatalogDependency, changed.validate());
}
