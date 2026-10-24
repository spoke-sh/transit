//! Bounded host inspection over the public direct catalog. Cursors bind the
//! original connection, selection and directory position, never authority.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const h = c.DirectTableValues;
const v = c.TableValues;
const w = c.DirectTableProtocol;
const Allocator = std.mem.Allocator;
pub const Selection = union(enum) { namespaces, tables: u64, resources: u64 };
pub const Cursor = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    selection: Selection,
    position: h.Position,
    after: []const u8,
    pub fn check(self: Cursor, connection: w.Connection, selection: Selection) !u64 {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (!std.meta.eql(try self.connection.native(), connection) or !std.meta.eql(self.selection, selection)) return error.InvalidCatalogCursor;
        if ((try self.position.native()).next_lsn == 0) return error.InvalidCatalogCursor;
        const after = try v.unsigned(self.after);
        if (after == 0) return error.InvalidCatalogCursor;
        if (selection == .namespaces) try c.Model.nativeId(after);
        return after;
    }
};
pub const Capabilities = struct {
    version: u8 = 1,
    definition: p.Growth.Definition = p.Growth.current_definition,
    max_columns: u16 = c.fuze.TableSchema.max_columns,
    max_rows: u16 = c.fuze.TableDml.max_rows,
    max_sql_bytes: u16 = 4096,
    max_intent_bytes: u32 = c.DirectTableIntent.max_bytes,
    max_action_bytes: u32 = c.DirectTableBridge.max_input_bytes,
    metadata_page_entries: u8 = 8,
    resident_intents: u8 = 1,
};
pub const Configuration = struct {
    scope: h.Scope,
    branch: []const u8,
    partition: []const u8,
    audience: u64,
    authority: c.TableAuthority.Profile,
    database_name: []const u8,
    initial_schema_name: []const u8,
    fn foreign(allocator: Allocator, value: c.DirectCatalog.Configuration) !Configuration {
        try value.validate();
        return .{ .scope = try h.Scope.foreign(allocator, value.scope), .branch = try v.decimal(allocator, value.branch), .partition = try v.decimal(allocator, value.partition), .audience = value.audience, .authority = value.authority, .database_name = try allocator.dupe(u8, value.database_name.slice()), .initial_schema_name = try allocator.dupe(u8, value.initial_schema_name.slice()) };
    }
};
pub const Listed = struct { interpretation: h.Interpretation, namespace: u64, name: []const u8, position: h.Position, changed_lsn: []const u8 };
pub const Action = union(enum) {
    capabilities,
    describe,
    namespace: u64,
    namespaces: ?Cursor,
    tables: struct { namespace: u64, cursor: ?Cursor },
};
pub const Result = union(enum) {
    capabilities: Capabilities,
    description: struct { configuration: Configuration, subject: p.Authorization.Verified, policy_revision: u64 },
    namespace: ?v.Namespace,
    namespaces: struct { entries: [8]?v.Namespace, next: ?Cursor, position: h.Position },
    tables: struct { entries: [8]?Listed, next: ?Cursor, position: h.Position, consistency: enum { independent } },
};
pub fn continuation(allocator: Allocator, connection: w.Connection, selection: Selection, previous: ?Cursor, position: p.DataLifecycle.Position, next: ?u64) !?Cursor {
    if (previous) |cursor| if (!std.meta.eql(try cursor.position.native(), position)) return error.CatalogObservationChanged;
    return if (next) |after| .{ .definition = p.Growth.current_definition, .connection = try h.Connection.foreign(allocator, connection), .selection = selection, .position = try h.Position.foreign(allocator, position), .after = try v.decimal(allocator, after) } else null;
}
/// Each call makes at most one catalog request; no hidden enumeration, retries,
/// provisioning, admission or replacement of the session's loaded work occurs.
pub fn apply(allocator: Allocator, client: c.DirectTableClient, action: Action) !Result {
    if (action == .capabilities) return .{ .capabilities = .{} };
    try client.connection.validate();
    const request: w.Action = switch (action) {
        .capabilities => unreachable,
        .describe => .describe,
        .namespace => |id| .{ .namespace = id },
        .namespaces => |cursor| .{ .namespaces = .{ .after = if (cursor) |value| try value.check(client.connection, .namespaces) else null } },
        .tables => |input| .{ .list = .{ .namespace = input.namespace, .after = if (input.cursor) |value| try value.check(client.connection, .{ .tables = input.namespace }) else null } },
    };
    const response = try client.call(request);
    defer response.deinit();
    return switch (response.value.result) {
        .description => |value| .{ .description = .{ .configuration = try Configuration.foreign(allocator, value), .subject = response.value.subject, .policy_revision = response.value.policy_revision } },
        .namespace => |value| .{ .namespace = if (value) |found| try v.Namespace.foreign(allocator, found) else null },
        .namespaces => |page| result: {
            const next = try continuation(allocator, client.connection, .namespaces, action.namespaces, page.directory_position, page.next);
            var entries: [8]?v.Namespace = @splat(null);
            for (page.entries, &entries) |slot, *entry| if (slot) |found| {
                entry.* = try v.Namespace.foreign(allocator, found);
            };
            break :result .{ .namespaces = .{ .entries = entries, .next = next, .position = try h.Position.foreign(allocator, page.directory_position) } };
        },
        .list => |page| result: {
            const input = action.tables;
            const next = try continuation(allocator, client.connection, .{ .tables = input.namespace }, input.cursor, page.directory_position, page.next);
            var entries: [8]?Listed = @splat(null);
            for (page.entries, &entries) |slot, *entry| if (slot) |found| {
                entry.* = .{ .interpretation = try h.Interpretation.foreign(allocator, found.interpretation), .namespace = found.namespace, .name = try allocator.dupe(u8, found.name.slice()), .position = try h.Position.foreign(allocator, found.position), .changed_lsn = try v.decimal(allocator, found.changed_lsn) };
            };
            break :result .{ .tables = .{ .entries = entries, .next = next, .position = try h.Position.foreign(allocator, page.directory_position), .consistency = .independent } };
        },
        else => error.InvalidTableResponse,
    };
}

test "direct catalog cursors bind full-width positions and exact selections" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = std.math.maxInt(u64) }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const position: p.DataLifecycle.Position = .{ .partition = std.math.maxInt(u64), .next_lsn = std.math.maxInt(u64) };
    const cursor = (try continuation(arena.allocator(), connection, .{ .tables = 1 }, null, position, std.math.maxInt(u64))).?;
    try t.expectEqual(std.math.maxInt(u64), try cursor.check(connection, .{ .tables = 1 }));
    try t.expectError(error.InvalidCatalogCursor, cursor.check(connection, .{ .tables = 2 }));
    try t.expectError(error.InvalidCatalogCursor, cursor.check(connection, .namespaces));
    var other_connection = connection;
    other_connection.principal += 1;
    try t.expectError(error.InvalidCatalogCursor, cursor.check(other_connection, .{ .tables = 1 }));
    try t.expectError(error.CatalogObservationChanged, continuation(arena.allocator(), connection, .{ .tables = 1 }, cursor, .{ .partition = position.partition, .next_lsn = position.next_lsn - 1 }, null));
    try t.expect(try continuation(arena.allocator(), connection, .{ .tables = 1 }, cursor, position, null) == null);
    const encoded = try p.Json.valueAlloc(arena.allocator(), cursor);
    const restored = try p.Json.parseFromSlice(Cursor, t.allocator, encoded);
    defer restored.deinit();
    try t.expectEqual(std.math.maxInt(u64), try restored.value.check(connection, .{ .tables = 1 }));
}
