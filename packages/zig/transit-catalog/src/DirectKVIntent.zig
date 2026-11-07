//! Frozen KV declaration and mutation work for database-owned caller tokens.
//! Staging preserves complete bytes; only the existing KV owner admits or executes it.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();

pub const format: u32 = 0x4b564931; // KVI1
pub const Kind = enum { ddl, put, delete };

pub const Work = union(enum) {
    ddl: c.DirectKV.Declaration,
    put: c.DirectKV.Mutation,
    delete: c.DirectKV.Mutation,

    pub fn kind(self: Work) Kind {
        return switch (self) {
            .ddl => .ddl,
            .put => .put,
            .delete => .delete,
        };
    }

    pub fn binding(self: Work) p.DataLifecycle.Binding {
        return switch (self) {
            .ddl => |value| value.binding,
            .put, .delete => |value| value.binding,
        };
    }

    pub fn mutation(self: Work) ?c.DirectKV.Mutation {
        return switch (self) {
            .ddl => null,
            .put, .delete => |value| value,
        };
    }

    pub fn validate(self: Work, allocator: std.mem.Allocator, connection: w.Connection, namespace: u64) !void {
        try c.Model.nativeId(namespace);
        switch (self) {
            .ddl => |value| {
                if (value.namespace != namespace) return error.InvalidKVOperation;
                try (c.DirectKV.DeclarationRequest{ .declaration = value, .command = .preview, .steps = 1 }).validate(allocator, connection);
            },
            .put, .delete => |value| {
                try connection.binding(value.binding);
                try value.validate(allocator);
            },
        }
    }
};

pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    namespace: u64,
    work: Work,

    pub fn validate(self: Saved, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        var scratch = std.heap.ArenaAllocator.init(allocator);
        defer scratch.deinit();
        try self.work.validate(scratch.allocator(), self.connection, self.namespace);
    }
};

pub const Reference = struct {
    connection: w.Connection,
    namespace: u64,
    kind: Kind,
    binding: p.DataLifecycle.Binding,
    record: c.DirectRecord.Reference,

    pub fn validate(self: Reference) !void {
        try self.connection.validate();
        try self.connection.binding(self.binding);
        try c.Model.nativeId(self.namespace);
        try self.record.validate();
        if (self.record.format != format or !std.meta.eql(self.connection, self.record.scope.connection)) return error.InvalidKVOperation;
        switch (self.kind) {
            .ddl => switch (self.binding.action) {
                .create, .rename, .drop => {},
                else => return error.InvalidKVOperation,
            },
            .put, .delete => if (self.binding.action != .insert) return error.InvalidKVOperation,
        }
    }

    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }

    pub fn admit(self: Reference, client: c.DirectTableClient) !c.DirectTableClient.OwnedResponse {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        const bytes = try c.DirectRecord.read(client.allocator, client, self.record);
        defer client.allocator.free(bytes);
        var intent = try restore(client.allocator, bytes);
        defer intent.deinit();
        try self.requireSame(try intent.reference(self.record.scope.account));
        return switch (intent.parsed.value.work) {
            .ddl => |decl| client.call(.{ .kv_declaration = .{ .declaration = decl, .command = .admit, .steps = 1 } }),
            .put, .delete => |mut| client.call(.{ .kv = .{ .mutate = mut } }),
        };
    }

    pub fn operation(self: Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !c.DirectTableClient.OwnedResponse {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        if (self.kind != .ddl and command == .inspect) {
            return client.call(.{ .kv = .{ .operation = self.binding } });
        }
        const bytes = try c.DirectRecord.read(client.allocator, client, self.record);
        defer client.allocator.free(bytes);
        var intent = try restore(client.allocator, bytes);
        defer intent.deinit();
        try self.requireSame(try intent.reference(self.record.scope.account));
        return switch (intent.parsed.value.work) {
            .ddl => |decl| client.call(.{ .kv_declaration = .{ .declaration = decl, .command = switch (command) {
                .inspect => .inspect,
                .execute => .execute,
                .cancel => .cancel,
            }, .steps = steps } }),
            .put, .delete => |mut| switch (command) {
                .inspect => client.call(.{ .kv = .{ .operation = self.binding } }),
                .execute => client.call(.{ .kv = .{ .mutate = mut } }),
                .cancel => client.call(.{ .kv = .{ .operation = self.binding } }),
            },
        };
    }
};

allocator: std.mem.Allocator,
bytes: []u8,
parsed: std.json.Parsed(Saved),

pub fn create(allocator: std.mem.Allocator, connection: w.Connection, namespace: u64, work: Work) !Self {
    const value: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .namespace = namespace, .work = work };
    try value.validate(allocator);
    const bytes = try p.Json.valueAlloc(allocator, value);
    errdefer allocator.free(bytes);
    if (bytes.len > c.DirectRecord.max_bytes) return error.CatalogRecordTooLarge;
    return .{ .allocator = allocator, .bytes = bytes, .parsed = try p.Json.parseFromSlice(Saved, allocator, bytes) };
}

pub fn deinit(self: *Self) void {
    self.parsed.deinit();
    self.allocator.free(self.bytes);
    self.* = undefined;
}

pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len == 0 or bytes.len > c.DirectRecord.max_bytes) return error.InvalidKVOperation;
    const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes);
    defer parsed.deinit();
    try parsed.value.validate(allocator);
    var result = try create(allocator, parsed.value.connection, parsed.value.namespace, parsed.value.work);
    errdefer result.deinit();
    if (!std.mem.eql(u8, bytes, result.bytes)) return error.InvalidKVOperation;
    return result;
}

pub fn reference(self: *const Self, account: [32]u8) !Reference {
    const value = self.parsed.value;
    const result: Reference = .{
        .connection = value.connection,
        .namespace = value.namespace,
        .kind = value.work.kind(),
        .binding = value.work.binding(),
        .record = try c.DirectRecord.reference(.{ .definition = value.definition, .connection = value.connection, .account = account }, format, self.bytes),
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
