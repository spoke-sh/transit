//! Lossless host dependency operations over the existing catalog owner. A
//! retained operation outcome and current graph membership remain distinct.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = c.DirectDependency;
const h = c.DirectTableValues;
const v = c.TableValues;
const w = c.DirectTableProtocol;
const Allocator = std.mem.Allocator;
pub const Edge = struct {
    source: h.Interpretation,
    dependent: struct { kind: @FieldType(d.Dependent, "kind"), interpretation: h.Interpretation },
    privileges: u64,
    foreign_key: ?struct { constraint: u32, column: []const u8 } = null,
    pub fn native(self: Edge) !d.Edge {
        const result: d.Edge = .{ .source = try self.source.native(), .dependent = .{ .kind = self.dependent.kind, .interpretation = try self.dependent.interpretation.native() }, .privileges = self.privileges, .foreign_key = if (self.foreign_key) |fk| .{ .constraint = fk.constraint, .column = try v.unsigned(fk.column) } else null };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Edge) !Edge {
        try value.validate();
        return .{ .source = try h.Interpretation.foreign(allocator, value.source), .dependent = .{ .kind = value.dependent.kind, .interpretation = try h.Interpretation.foreign(allocator, value.dependent.interpretation) }, .privileges = value.privileges, .foreign_key = if (value.foreign_key) |fk| .{ .constraint = fk.constraint, .column = try v.decimal(allocator, fk.column) } else null };
    }
};
pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    operation: []const u8,
    edge: Edge,
    action: @FieldType(d.Binding, "action"),
    authority: d.Authority,
    pub fn native(self: Binding) !d.Binding {
        const result: d.Binding = .{ .definition = self.definition, .connection = try self.connection.native(), .operation = try v.unsigned(self.operation), .edge = try self.edge.native(), .action = self.action, .authority = self.authority };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Binding) !Binding {
        try value.validate();
        return .{ .definition = value.definition, .connection = try h.Connection.foreign(allocator, value.connection), .operation = try v.decimal(allocator, value.operation), .edge = try Edge.foreign(allocator, value.edge), .action = value.action, .authority = value.authority };
    }
};
pub const Selection = union(enum) {
    dependents: h.Object,
    dependencies: h.Object,
    pub fn native(self: Selection) !d.Selection {
        return switch (self) {
            .dependents => |value| .{ .dependents = try value.native() },
            .dependencies => |value| .{ .dependencies = try value.native() },
        };
    }
    pub fn foreign(allocator: Allocator, value: d.Selection) !Selection {
        return switch (value) {
            .dependents => |object| .{ .dependents = try h.Object.foreign(allocator, object) },
            .dependencies => |object| .{ .dependencies = try h.Object.foreign(allocator, object) },
        };
    }
};
pub const Cursor = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    selection: Selection,
    authority: d.Authority,
    position: h.Position,
    after: []const u8,
    pub fn native(self: Cursor, connection: w.Connection) !d.Cursor {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (!std.meta.eql(try self.connection.native(), connection)) return error.InvalidCatalogCursor;
        if (self.after.len > 128 or self.after.len % 2 != 0) return error.InvalidCatalogCursor;
        var bytes: [64]u8 = undefined;
        const after = std.fmt.hexToBytes(&bytes, self.after) catch return error.InvalidCatalogCursor;
        const result: d.Cursor = .{ .selection = try self.selection.native(), .authority = self.authority, .position = try self.position.native(), .after = try c.storage.TreeStore.pages.Key.init(after) };
        try result.validate();
        return result;
    }
    fn check(self: Cursor, connection: w.Connection, selection: d.Selection, authority: d.Authority) !d.Cursor {
        const result = try self.native(connection);
        if (!std.meta.eql(result.selection, selection) or result.authority != authority) return error.InvalidCatalogCursor;
        return result;
    }
    fn foreign(allocator: Allocator, connection: w.Connection, value: d.Cursor) !Cursor {
        return .{ .definition = p.Growth.current_definition, .connection = try h.Connection.foreign(allocator, connection), .selection = try Selection.foreign(allocator, value.selection), .authority = value.authority, .position = try h.Position.foreign(allocator, value.position), .after = try v.hex(allocator, value.after.slice()) };
    }
};
pub const Outcome = struct {
    binding: Binding,
    position: h.Position,
    phase: @FieldType(d.Outcome, "phase"),
    reason: @FieldType(d.Outcome, "reason"),
    changed: bool,
    pub fn native(self: Outcome) !d.Outcome {
        const result: d.Outcome = .{ .binding = try self.binding.native(), .position = try self.position.native(), .phase = self.phase, .reason = self.reason, .changed = self.changed };
        try result.validate();
        return result;
    }
    fn foreign(allocator: Allocator, value: d.Outcome) !Outcome {
        try value.validate();
        return .{ .binding = try Binding.foreign(allocator, value.binding), .position = try h.Position.foreign(allocator, value.position), .phase = value.phase, .reason = value.reason, .changed = value.changed };
    }
};
pub const Action = union(enum) {
    operation: struct { binding: Binding, command: d.Command },
    state: Edge,
    page: struct { selection: Selection, authority: d.Authority, cursor: ?Cursor },
};
pub const Result = union(enum) {
    observation: union(enum) { not_observed, outcome: Outcome },
    state: struct { edge: Edge, position: h.Position, present: bool },
    page: struct { entries: [d.page_entries]?Edge, next: ?Cursor, position: h.Position },
};
pub fn apply(allocator: Allocator, client: c.DirectTableClient, action: Action) !Result {
    const request: w.Action = switch (action) {
        .operation => |input| result: {
            const binding = try input.binding.native();
            if (!std.meta.eql(binding.connection, client.connection)) return error.CatalogIdentityConflict;
            break :result .{ .dependency_operation = .{ .binding = binding, .command = input.command } };
        },
        .state => |edge| .{ .dependency_state = try edge.native() },
        .page => |input| result: {
            const selection = try input.selection.native();
            break :result .{ .dependencies = .{ .selection = selection, .authority = input.authority, .cursor = if (input.cursor) |cursor| try cursor.check(client.connection, selection, input.authority) else null } };
        },
    };
    const response = try client.call(request);
    defer response.deinit();
    return switch (response.value.result) {
        .dependency_operation => |value| .{ .observation = switch (value) {
            .not_observed => .not_observed,
            .outcome => |outcome| .{ .outcome = try Outcome.foreign(allocator, outcome) },
        } },
        .dependency_state => |value| .{ .state = .{ .edge = try Edge.foreign(allocator, value.edge), .position = try h.Position.foreign(allocator, value.position), .present = value.present } },
        .dependencies => |value| result: {
            var entries: [d.page_entries]?Edge = @splat(null);
            for (value.entries, &entries) |slot, *entry| if (slot) |edge| {
                entry.* = try Edge.foreign(allocator, edge);
            };
            break :result .{ .page = .{ .entries = entries, .next = if (value.next) |cursor| try Cursor.foreign(allocator, client.connection, cursor) else null, .position = try h.Position.foreign(allocator, value.position) } };
        },
        else => error.InvalidTableResponse,
    };
}

test "direct dependency host recovery preserves original bindings and cursor scope" {
    const t = std.testing;
    const fixture = try p.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8, edge_digest: [32]u8 }, t.allocator, @embedFile("fixtures/direct-dependency-v1.json"));
    defer fixture.deinit();
    const original = fixture.value.request.action.dependency_operation.binding;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const converted = try Binding.foreign(arena.allocator(), original);
    const bytes = try p.Json.valueAlloc(arena.allocator(), converted);
    const parsed = try p.Json.parseFromSliceOwned(Binding, t.allocator, bytes);
    defer parsed.deinit();
    _ = arena.reset(.free_all);
    try original.requireSame(try parsed.value.native());
    try t.expectEqual(std.math.maxInt(u64), (try parsed.value.native()).operation);
    var changed = parsed.value;
    changed.operation = "18446744073709551616";
    try t.expectError(error.InvalidCatalogInteger, changed.native());
    const cursor: d.Cursor = .{ .selection = .{ .dependents = original.edge.source.object }, .authority = .dependent, .position = .{ .partition = std.math.maxInt(u64), .next_lsn = std.math.maxInt(u64) }, .after = try original.edge.forwardKey() };
    const host_cursor = try Cursor.foreign(arena.allocator(), original.connection, cursor);
    try t.expectEqualDeep(cursor, try host_cursor.check(original.connection, cursor.selection, .dependent));
    try t.expectError(error.InvalidCatalogCursor, host_cursor.check(original.connection, .{ .dependencies = original.edge.dependent.interpretation.object }, .dependent));
    try t.expectError(error.InvalidCatalogCursor, host_cursor.check(original.connection, cursor.selection, .catalog_administrator));
    var other = original.connection;
    other.principal += 1;
    try t.expectError(error.InvalidCatalogCursor, host_cursor.native(other));
}
