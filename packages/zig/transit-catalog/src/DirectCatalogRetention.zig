//! Explicit saved snapshot acquisition and cleanup for general callers. Local
//! handles never own expiry or silently release accepted retention on destruction.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const h = c.DirectTableValues;
const v = c.TableValues;
const w = c.DirectTableProtocol;
const Allocator = std.mem.Allocator;
pub const Owner = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    object: h.Object,
    operation: []const u8,
    pub fn identity(self: Owner) !p.DataLifecycle.Operation {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        const connection = try self.connection.native();
        const result: p.DataLifecycle.Operation = .{ .scope = connection.scope, .principal = connection.principal, .operation = try v.unsigned(self.operation) };
        try connection.object(try self.object.native());
        try connection.owner(result);
        return result;
    }
    fn check(self: Owner, connection: w.Connection) !p.DataLifecycle.Operation {
        const result = try self.identity();
        if (!std.meta.eql(try self.connection.native(), connection)) return error.CatalogIdentityConflict;
        return result;
    }
    fn copy(self: Owner, allocator: Allocator) !Owner {
        const operation = try self.identity();
        return .{ .definition = self.definition, .connection = try h.Connection.foreign(allocator, try self.connection.native()), .object = try h.Object.foreign(allocator, try self.object.native()), .operation = try v.decimal(allocator, operation.operation) };
    }
};
/// Save before acquiring. Exact selection never substitutes a later frontier.
pub const Acquisition = struct { owner: Owner, expected: h.Position };
pub const Snapshot = struct {
    owner: Owner,
    content: h.Content,
    pub fn native(self: Snapshot, connection: w.Connection) !w.Snapshot {
        return .{ .object = try self.owner.object.native(), .handle = .{ .owner = try self.owner.check(connection), .content = try self.content.native() } };
    }
    fn foreign(allocator: Allocator, owner: Owner, handle: c.storage.TablePartition.SnapshotHandle) !Snapshot {
        if (!std.meta.eql(try owner.identity(), handle.owner)) return error.InvalidTableResponse;
        return .{ .owner = try owner.copy(allocator), .content = try h.Content.foreign(allocator, handle.content) };
    }
};
pub const Status = struct {
    owner: Owner,
    current_interpretation: h.Interpretation,
    current_position: h.Position,
    retired: bool,
    snapshot: ?Snapshot,
    released: bool,
    authority: c.DirectReadAuthority,
};
pub const Metadata = struct {
    snapshot: Snapshot,
    interpretation: h.Stored,
    accepted: h.Position,
    changed_lsn: []const u8,
    row_count: []const u8,
    schema: c.fuze.TableSchemaJson.Schema,
    authority: c.DirectReadAuthority,
};
pub const Action = union(enum) { acquire: Acquisition, status: Owner, metadata: Snapshot, release: Snapshot };
pub const Result = union(enum) { acquired: Snapshot, status: Status, metadata: Metadata, released: Snapshot };
/// One public request per action. Status identifies the original retention owner;
/// its current Table fields do not relabel the retained snapshot's data basis.
pub fn apply(allocator: Allocator, client: c.DirectTableClient, action: Action) !Result {
    const request: w.Action = switch (action) {
        .acquire => |value| .{ .pin = .{ .object = try value.owner.object.native(), .owner = try value.owner.check(client.connection), .expected = try value.expected.native(), .selection = .exact } },
        .status => |owner| .{ .pin_status = .{ .object = try owner.object.native(), .owner = try owner.check(client.connection) } },
        .metadata => |value| .{ .snapshot = try value.native(client.connection) },
        .release => |value| .{ .release = try value.native(client.connection) },
    };
    const response = try client.call(request);
    defer response.deinit();
    return switch (action) {
        .acquire => |value| .{ .acquired = try Snapshot.foreign(allocator, value.owner, response.value.result.pin) },
        .status => |owner| status: {
            const value = response.value.result.pin_state;
            break :status .{ .status = .{ .owner = try owner.copy(allocator), .current_interpretation = try h.Interpretation.foreign(allocator, value.interpretation), .current_position = try h.Position.foreign(allocator, value.position), .retired = value.retired, .snapshot = if (value.handle) |handle| try Snapshot.foreign(allocator, owner, handle) else null, .released = value.released, .authority = value.authority } };
        },
        .metadata => |snapshot| metadata: {
            const value = response.value.result.snapshot;
            var temporary = std.heap.ArenaAllocator.init(allocator);
            defer temporary.deinit();
            var schema = try c.fuze.TableSchema.decode(allocator, try value.schema.decode(temporary.allocator(), c.fuze.TableSchema.max_bytes));
            defer schema.deinit();
            if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &value.interpretation.schema_fingerprint)) return error.InvalidTableResponse;
            break :metadata .{ .metadata = .{ .snapshot = try Snapshot.foreign(allocator, snapshot.owner, value.snapshot.handle), .interpretation = try h.Stored.foreign(allocator, value.interpretation), .accepted = try h.Position.foreign(allocator, value.accepted), .changed_lsn = try v.decimal(allocator, value.changed_lsn), .row_count = try v.decimal(allocator, value.row_count), .schema = try c.fuze.TableSchemaJson.foreignInto(allocator, schema.schema), .authority = value.authority } };
        },
        .release => |value| .{ .released = try Snapshot.foreign(allocator, value.owner, (try value.native(client.connection)).handle) },
    };
}

test "direct retention references own full-width identities and reject caller substitution" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    const a = arena.allocator();
    const connection: w.Connection = .{ .scope = .{ .realm = 46, .resource = 3, .catalog = std.math.maxInt(u64) }, .branch = 1, .principal = 17, .audience = 5, .role = null };
    const owner: Owner = .{ .definition = p.Growth.current_definition, .connection = try h.Connection.foreign(a, connection), .object = try h.Object.foreign(a, .{ .scope = connection.scope, .branch = 1, .object = std.math.maxInt(u64) - 1 }), .operation = "18446744073709551615" };
    const snapshot = try Snapshot.foreign(a, owner, .{ .owner = try owner.identity(), .content = .{ .bytes = std.math.maxInt(u64), .sha256 = @splat(8) } });
    var restored = try p.Json.parseFromSliceOwned(Snapshot, t.allocator, try p.Json.valueAlloc(a, snapshot));
    defer restored.deinit();
    arena.deinit();
    const native = try restored.value.native(connection);
    try t.expectEqual(std.math.maxInt(u64), native.handle.owner.operation);
    try t.expectEqual(std.math.maxInt(u64) - 1, native.object.object);
    try t.expectEqual(std.math.maxInt(u64), native.handle.content.bytes);
    var other = connection;
    other.principal += 1;
    try t.expectError(error.CatalogIdentityConflict, restored.value.native(other));
    other = connection;
    other.audience += 1;
    try t.expectError(error.CatalogIdentityConflict, restored.value.native(other));
}
