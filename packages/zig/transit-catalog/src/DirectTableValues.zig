//! Lossless host values for the direct Table boundary. Conversions preserve
//! exact identities; they perform no lookup, admission or authorization.
//! Use a request arena for foreign conversions: returned strings and partial
//! allocations on failure belong to that arena, not a separately owned value.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const v = c.TableValues;
const Allocator = std.mem.Allocator;

pub const Scope = v.Scope;
pub const Connection = struct {
    scope: Scope,
    branch: []const u8,
    audience: u64,
    principal: u64,
    role: ?u64,
    pub fn native(self: Connection) !w.Connection {
        const result: w.Connection = .{ .scope = try self.scope.native(), .branch = try v.unsigned(self.branch), .audience = self.audience, .principal = self.principal, .role = self.role };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: w.Connection) !Connection {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .branch = try v.decimal(allocator, value.branch), .audience = value.audience, .principal = value.principal, .role = value.role };
    }
};
pub const Object = struct {
    scope: Scope,
    branch: []const u8,
    object: []const u8,
    pub fn native(self: Object) !d.Object {
        const result: d.Object = .{ .scope = try self.scope.native(), .branch = try v.unsigned(self.branch), .object = try v.unsigned(self.object) };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Object) !Object {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .branch = try v.decimal(allocator, value.branch), .object = try v.decimal(allocator, value.object) };
    }
};
pub const Interpretation = struct {
    object: Object,
    revision: []const u8,
    digest: []const u8,
    pub fn native(self: Interpretation) !d.Definition {
        const result: d.Definition = .{ .object = try self.object.native(), .revision = try v.unsigned(self.revision), .digest = try v.digest(self.digest) };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Definition) !Interpretation {
        try value.validate();
        return .{ .object = try Object.foreign(allocator, value.object), .revision = try v.decimal(allocator, value.revision), .digest = try v.hex(allocator, &value.digest) };
    }
};
pub const Content = struct {
    bytes: []const u8,
    sha256: []const u8,
    pub fn native(self: Content) !d.Content {
        const result: d.Content = .{ .bytes = try v.unsigned(self.bytes), .sha256 = try v.digest(self.sha256) };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Content) !Content {
        try value.validate();
        return .{ .bytes = try v.decimal(allocator, value.bytes), .sha256 = try v.hex(allocator, &value.sha256) };
    }
};
pub const Stored = struct {
    interpretation: Interpretation,
    content: Content,
    schema_fingerprint: []const u8,
    retired: bool,
    pub fn native(self: Stored) !c.storage.TableDeclaration.Stored {
        const result: c.storage.TableDeclaration.Stored = .{ .interpretation = try self.interpretation.native(), .content = try self.content.native(), .schema_fingerprint = try v.digest(self.schema_fingerprint), .retired = self.retired };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: c.storage.TableDeclaration.Stored) !Stored {
        try value.validate();
        return .{ .interpretation = try Interpretation.foreign(allocator, value.interpretation), .content = try Content.foreign(allocator, value.content), .schema_fingerprint = try v.hex(allocator, &value.schema_fingerprint), .retired = value.retired };
    }
};
pub const Position = struct {
    partition: []const u8,
    next_lsn: []const u8,
    pub fn native(self: Position) !d.Position {
        const result: d.Position = .{ .partition = try v.unsigned(self.partition), .next_lsn = try v.unsigned(self.next_lsn) };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Position) !Position {
        try value.validate();
        return .{ .partition = try v.decimal(allocator, value.partition), .next_lsn = try v.decimal(allocator, value.next_lsn) };
    }
};
pub const Operation = struct {
    scope: Scope,
    principal: u64,
    operation: []const u8,
    pub fn native(self: Operation) !d.Operation {
        const result: d.Operation = .{ .scope = try self.scope.native(), .principal = self.principal, .operation = try v.unsigned(self.operation) };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Operation) !Operation {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .principal = value.principal, .operation = try v.decimal(allocator, value.operation) };
    }
};
pub const Binding = struct {
    definition: p.Growth.Definition,
    identity: Operation,
    target: Object,
    action: d.Action,
    expected_definition: ?Interpretation,
    expected_data: ?Position,
    intent: []const u8,
    prerequisite: ?p.Authorization.Guard,
    pub fn native(self: Binding) !d.Binding {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        const result: d.Binding = .{ .definition = self.definition, .identity = try self.identity.native(), .target = try self.target.native(), .action = self.action, .expected_definition = if (self.expected_definition) |value| try value.native() else null, .expected_data = if (self.expected_data) |value| try value.native() else null, .intent = try v.digest(self.intent), .prerequisite = self.prerequisite };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: d.Binding) !Binding {
        if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try value.validate();
        return .{ .definition = value.definition, .identity = try Operation.foreign(allocator, value.identity), .target = try Object.foreign(allocator, value.target), .action = value.action, .expected_definition = if (value.expected_definition) |item| try Interpretation.foreign(allocator, item) else null, .expected_data = if (value.expected_data) |item| try Position.foreign(allocator, item) else null, .intent = try v.hex(allocator, &value.intent), .prerequisite = value.prerequisite };
    }
};
pub const PreparedBinding = struct {
    definition: p.Growth.Definition,
    connection: Connection,
    namespace: u64,
    name: []const u8,
    interpretation: Stored,
    pub fn native(self: PreparedBinding) !c.DirectTableBinding {
        const result: c.DirectTableBinding = .{ .definition = self.definition, .connection = try self.connection.native(), .namespace = self.namespace, .name = try .init(self.name), .interpretation = try self.interpretation.native() };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: c.DirectTableBinding) !PreparedBinding {
        try value.validate();
        return .{ .definition = value.definition, .connection = try Connection.foreign(allocator, value.connection), .namespace = value.namespace, .name = try allocator.dupe(u8, value.name.slice()), .interpretation = try Stored.foreign(allocator, value.interpretation) };
    }
};
pub const Reference = struct {
    definition: p.Growth.Definition,
    connection: Connection,
    namespace: u64,
    binding: Binding,
    content: Content,
    pub fn native(self: Reference) !c.DirectTableIntent.Reference {
        const result: c.DirectTableIntent.Reference = .{ .definition = self.definition, .connection = try self.connection.native(), .namespace = self.namespace, .binding = try self.binding.native(), .content = try self.content.native() };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: c.DirectTableIntent.Reference) !Reference {
        try value.validate();
        return .{ .definition = value.definition, .connection = try Connection.foreign(allocator, value.connection), .namespace = value.namespace, .binding = try Binding.foreign(allocator, value.binding), .content = try Content.foreign(allocator, value.content) };
    }
};

test "direct host references preserve full-width identities and reject missing compatibility" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = std.math.maxInt(u64) };
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 5, .principal = 7, .role = null };
    const original: c.DirectTableIntent.Reference = .{
        .definition = p.Growth.current_definition,
        .connection = connection,
        .namespace = 1,
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 7, .operation = std.math.maxInt(u64) }, .target = .{ .scope = scope, .branch = 1, .object = std.math.maxInt(u64) - 1 }, .action = .drop, .expected_definition = .{ .object = .{ .scope = scope, .branch = 1, .object = std.math.maxInt(u64) - 1 }, .revision = std.math.maxInt(u64), .digest = @splat(1) }, .expected_data = .{ .partition = 2, .next_lsn = std.math.maxInt(u64) }, .intent = @splat(2) },
        .content = .{ .bytes = 1024, .sha256 = @splat(3) },
    };
    const foreign = try Reference.foreign(a, original);
    try t.expectEqualStrings("18446744073709551615", foreign.binding.identity.operation);
    try t.expectEqualStrings("18446744073709551614", foreign.binding.target.object);
    const bytes = try p.Json.valueAlloc(a, foreign);
    var parsed = try p.Json.parseFromSliceOwned(Reference, t.allocator, bytes);
    defer parsed.deinit();
    _ = arena.reset(.free_all);
    try original.requireSame(try parsed.value.native());
    var invalid = parsed.value;
    invalid.binding.identity.operation = "018446744073709551615";
    try t.expectError(error.InvalidCatalogInteger, invalid.native());
    var tree = try std.json.parseFromSlice(std.json.Value, a, try p.Json.valueAlloc(a, parsed.value), .{});
    _ = tree.value.object.swapRemove("definition");
    const missing = try std.json.Stringify.valueAlloc(a, tree.value, .{});
    try t.expectError(error.MissingField, p.Json.parseFromSlice(Reference, a, missing));
}

test "direct host references agree with independent saved-intent bytes" {
    const t = std.testing;
    const Fixture = struct { native: c.DirectTableIntent.Reference, host: Reference };
    const fixture = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-host-reference-v1.json"));
    defer fixture.deinit();
    try fixture.value.native.requireSame(try fixture.value.host.native());
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const binding: c.DirectTableBinding = .{ .definition = p.Growth.current_definition, .connection = fixture.value.native.connection, .namespace = 1, .name = try .init("events"), .interpretation = .{ .interpretation = fixture.value.native.binding.expected_definition.?, .content = .{ .bytes = 104, .sha256 = @splat(3) }, .schema_fingerprint = @splat(9), .retired = false } };
    const host = try PreparedBinding.foreign(arena.allocator(), binding);
    try t.expectEqualDeep(binding, try host.native());
    var substituted = host;
    const wrong: [32]u8 = @splat(1);
    substituted.interpretation.content.sha256 = try v.hex(arena.allocator(), &wrong);
    try t.expectError(error.InvalidTableDeclaration, substituted.native());
}
