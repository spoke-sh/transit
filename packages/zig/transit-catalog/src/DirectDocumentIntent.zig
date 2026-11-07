//! Frozen Document collection declaration work for database-owned caller tokens.
//! Staging preserves complete bytes; only the existing catalog owner admits or executes it.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();

pub const format: u32 = 0x44434931; // DCI1

pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    namespace: u64,
    declaration: c.DirectDocument.Declaration,

    pub fn validate(self: Saved, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try c.Model.nativeId(self.namespace);
        if (self.declaration.ddl.namespace != self.namespace) return error.InvalidDirectCatalogOperation;
        var scratch = std.heap.ArenaAllocator.init(allocator);
        defer scratch.deinit();
        try self.declaration.validate(scratch.allocator(), self.connection);
    }
};

pub const Reference = struct {
    connection: w.Connection,
    namespace: u64,
    binding: p.DataLifecycle.Binding,
    record: c.DirectRecord.Reference,

    pub fn validate(self: Reference) !void {
        try self.connection.validate();
        try self.connection.binding(self.binding);
        try c.Model.nativeId(self.namespace);
        try self.record.validate();
        if (self.record.format != format or !std.meta.eql(self.connection, self.record.scope.connection)) return error.InvalidDirectCatalogOperation;
        switch (self.binding.action) {
            .create, .alter, .rename, .drop => {},
            else => return error.InvalidDirectCatalogOperation,
        }
    }

    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }

    pub fn admit(self: Reference, client: c.DirectTableClient) !std.json.Parsed(w.Response) {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        const bytes = try c.DirectRecord.read(client.allocator, client, self.record);
        defer client.allocator.free(bytes);
        var intent = try restore(client.allocator, bytes);
        defer intent.deinit();
        try self.requireSame(try intent.reference(self.record.scope.account));
        return client.call(.{ .document_declaration = .{ .declaration = intent.parsed.value.declaration, .command = .admit, .steps = 1 } });
    }

    pub fn operation(self: Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !std.json.Parsed(w.Response) {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        const bytes = try c.DirectRecord.read(client.allocator, client, self.record);
        defer client.allocator.free(bytes);
        var intent = try restore(client.allocator, bytes);
        defer intent.deinit();
        try self.requireSame(try intent.reference(self.record.scope.account));
        const decl_cmd: @FieldType(c.DirectDocument.DeclarationRequest, "command") = switch (command) {
            .inspect => .inspect,
            .execute => .execute,
            .cancel => .cancel,
        };
        return client.call(.{ .document_declaration = .{ .declaration = intent.parsed.value.declaration, .command = decl_cmd, .steps = steps } });
    }
};

bytes: []u8,
parsed: std.json.Parsed(Saved),

pub fn create(allocator: std.mem.Allocator, connection: w.Connection, namespace: u64, declaration: c.DirectDocument.Declaration) !Self {
    const saved: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .namespace = namespace, .declaration = declaration };
    try saved.validate(allocator);
    const bytes = try p.Json.valueAlloc(allocator, saved);
    errdefer allocator.free(bytes);
    if (bytes.len > c.DirectRecord.max_bytes) return error.TablePayloadTooLarge;
    return .{ .bytes = bytes, .parsed = try p.Json.parseFromSlice(Saved, allocator, bytes) };
}

pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len == 0 or bytes.len > c.DirectRecord.max_bytes) return error.InvalidDirectCatalogOperation;
    const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes);
    defer parsed.deinit();
    try parsed.value.validate(allocator);
    var result = try create(allocator, parsed.value.connection, parsed.value.namespace, parsed.value.declaration);
    errdefer result.deinit();
    if (!std.mem.eql(u8, bytes, result.bytes)) return error.InvalidDirectCatalogOperation;
    return result;
}

pub fn deinit(self: *Self) void {
    const allocator = self.parsed.arena.child_allocator;
    self.parsed.deinit();
    allocator.free(self.bytes);
    self.* = undefined;
}

pub fn binding(self: *const Self) p.DataLifecycle.Binding {
    return self.parsed.value.declaration.ddl.binding;
}

pub fn reference(self: *const Self, account: [32]u8) !Reference {
    const saved = self.parsed.value;
    const result: Reference = .{
        .connection = saved.connection,
        .namespace = saved.namespace,
        .binding = saved.declaration.ddl.binding,
        .record = try c.DirectRecord.reference(.{ .definition = saved.definition, .connection = saved.connection, .account = account }, format, self.bytes),
    };
    try result.validate();
    return result;
}

pub fn stage(self: *const Self, client: c.DirectTableClient, account: [32]u8) !Reference {
    const expected = try self.reference(account);
    if (!std.meta.eql(expected.connection, client.connection)) return error.CatalogIdentityConflict;
    try expected.record.requireSame(try c.DirectRecord.stage(client, account, format, self.bytes));
    return expected;
}

pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, expected: Reference) !Self {
    try expected.validate();
    const bytes = try c.DirectRecord.load(allocator, objects, expected.record);
    defer allocator.free(bytes);
    var intent = try restore(allocator, bytes);
    errdefer intent.deinit();
    try expected.requireSame(try intent.reference(expected.record.scope.account));
    return intent;
}
