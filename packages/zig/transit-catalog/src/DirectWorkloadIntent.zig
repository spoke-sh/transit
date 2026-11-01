//! Complete frozen Stream/Queue work over the existing immutable record store.
//! Staging is neither token acceptance nor operation admission. Native owners
//! retain all publication, authorization, recovery and cancellation semantics.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const s = c.storage;
const Self = @This();
pub const format = 0x574c4931;

pub const Work = union(enum) {
    stream: @FieldType(c.DirectStream.Request, "mutate"),
    queue: @FieldType(c.DirectQueue.Request, "mutate"),

    pub fn identity(self: Work) p.DataLifecycle.Operation {
        return switch (self) {
            inline else => |value| value.work.identity(),
        };
    }
    pub fn target(self: Work) p.StreamQueue.Partition {
        return switch (self) {
            inline else => |value| value.work.target(),
        };
    }
    pub fn binding(self: Work, scratch: std.mem.Allocator) !p.LogWorkload.Binding {
        return switch (self) {
            .stream => |value| .{ .stream = try value.work.binding(scratch) },
            .queue => |value| .{ .queue = try value.work.binding(scratch) },
        };
    }
    pub fn access(self: Work) p.LogWorkload.Access {
        return switch (self) {
            inline else => |value| value.work.access(),
        };
    }
    pub fn validate(self: Work, connection: w.Connection) !void {
        switch (self) {
            .stream => |value| try (c.DirectStream.Request{ .mutate = value }).validate(connection.principal, connection.scope),
            .queue => |value| try (c.DirectQueue.Request{ .mutate = value }).validate(connection.principal, connection.scope),
        }
        try connection.object(self.target().interpretation.object);
    }
    fn append(self: Work) ?p.StreamQueue.Append {
        return switch (self) {
            .stream => |value| if (value.work == .append) value.work.append else null,
            .queue => |value| if (value.work == .enqueue) value.work.enqueue else null,
        };
    }
    fn payload(self: Work) ?w.Binary {
        return switch (self) {
            inline else => |value| value.payload,
        };
    }
};

pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    source: c.DirectLogProtocol.Definition,
    work: Work,

    pub fn validate(self: Saved, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.work.validate(self.connection);
        const target = self.work.target();
        if (self.source.declaration.stored.retired or
            !std.meta.eql(target.interpretation, self.source.declaration.stored.declaration.interpretation) or
            !std.mem.eql(u8, @tagName(self.work), @tagName(self.source.declaration.kind()))) return error.InvalidWorkloadIntent;
        _ = try self.source.declaration.partition(target.partition);
        var declaration = try c.DirectLogProtocol.decodeMetadata(allocator, self.connection, self.source);
        defer declaration.deinit();
        if (self.work.append()) |request| {
            const bytes = try self.work.payload().?.decode(allocator, c.DirectRecord.max_bytes);
            defer allocator.free(bytes);
            var scratch: std.heap.ArenaAllocator = .init(allocator);
            defer scratch.deinit();
            var key_buffer: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
            try s.LogBatch.validate(bytes, &declaration, request, &scratch, &key_buffer);
        }
    }
};

pub const Reference = struct {
    connection: w.Connection,
    namespace: u64,
    binding: p.LogWorkload.Binding,
    source: s.LogDeclaration.Stored,
    record: c.DirectRecord.Reference,

    pub fn identity(self: Reference) p.DataLifecycle.Operation {
        return self.binding.operation();
    }
    pub fn validate(self: Reference) !void {
        try self.connection.validate();
        try c.Model.nativeId(self.namespace);
        try self.binding.validate();
        try self.source.validate();
        try self.record.validate();
        try self.connection.object(self.binding.target().interpretation.object);
        if (self.identity().principal != self.connection.principal or self.source.retired or
            !std.meta.eql(self.binding.target().interpretation, self.source.declaration.interpretation) or
            self.binding.target().partition >= self.source.declaration.configuration.partitioning.count or
            !std.mem.eql(u8, @tagName(self.binding), @tagName(self.source.declaration.configuration.policy)) or
            self.record.format != format or !std.meta.eql(self.connection, self.record.scope.connection)) return error.InvalidWorkloadIntent;
    }
    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
    /// Resolve or execute only the retained body. Loading and current native
    /// authorization are separate; neither this descriptor nor its digest grants
    /// rights or supplies completion. No new operation identity is generated.
    pub fn operation(self: Reference, client: c.DirectTableClient, command: enum { inspect, execute, cancel }) !std.json.Parsed(w.Response) {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        const bytes = try c.DirectRecord.read(client.allocator, client, self.record);
        defer client.allocator.free(bytes);
        var intent = try restore(client.allocator, bytes);
        defer intent.deinit();
        try self.requireSame(try intent.reference(self.record.scope.account));
        return switch (intent.parsed.value.work) {
            .stream => |work| client.call(.{ .stream = switch (command) {
                .inspect => .{ .operation = work.work },
                .execute => .{ .mutate = work },
                .cancel => .{ .cancel = work.work },
            } }),
            .queue => |work| client.call(.{ .queue = switch (command) {
                .inspect => .{ .operation = work.work },
                .execute => .{ .mutate = work },
                .cancel => .{ .cancel = work.work },
            } }),
        };
    }
};

allocator: std.mem.Allocator,
bytes: []u8,
parsed: std.json.Parsed(Saved),

pub fn create(allocator: std.mem.Allocator, connection: w.Connection, source: c.DirectLogProtocol.Definition, work: Work) !Self {
    const value: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .source = source, .work = work };
    try value.validate(allocator);
    const bytes = p.Json.valueAllocBounded(allocator, value, c.DirectRecord.max_bytes) catch |err| return if (err == error.WriteFailed) error.CatalogRecordTooLarge else err;
    errdefer allocator.free(bytes);
    return .{ .allocator = allocator, .bytes = bytes, .parsed = try p.Json.parseFromSlice(Saved, allocator, bytes) };
}
pub fn deinit(self: *Self) void {
    self.parsed.deinit();
    self.allocator.free(self.bytes);
    self.* = undefined;
}
pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len == 0 or bytes.len > c.DirectRecord.max_bytes) return error.InvalidWorkloadIntent;
    const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes);
    defer parsed.deinit();
    var result = try create(allocator, parsed.value.connection, parsed.value.source, parsed.value.work);
    errdefer result.deinit();
    if (!std.mem.eql(u8, bytes, result.bytes)) return error.InvalidWorkloadIntent;
    return result;
}
pub fn reference(self: *const Self, account: [32]u8) !Reference {
    const value = self.parsed.value;
    const result: Reference = .{
        .connection = value.connection,
        .namespace = value.source.declaration.properties.namespace,
        .binding = try value.work.binding(self.allocator),
        .source = value.source.declaration.stored,
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
pub fn load(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, expected: Reference) !Self {
    try expected.validate();
    const bytes = try c.DirectRecord.load(allocator, objects, expected.record);
    defer allocator.free(bytes);
    var intent = try restore(allocator, bytes);
    errdefer intent.deinit();
    try expected.requireSame(try intent.reference(expected.record.scope.account));
    return intent;
}
