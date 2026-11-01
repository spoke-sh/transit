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

/// Request-local bridge to the host's existing bounded native owners. It must
/// inspect the original work under current policy, never dispatch a mutation.
/// The reader owns no independent receipt cache, recovery loop or authority.
pub const Reader = struct {
    pub const Result = union(enum) { stream: c.DirectStream.Result, queue: c.DirectQueue.Result };
    context: *anyopaque,
    inspect: *const fn (*anyopaque, std.mem.Allocator, *c.DirectCatalog, c.DirectCatalog.Policy, Work) anyerror!Result,

    pub fn requireTerminal(self: Reader, allocator: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, expected: Reference) !void {
        var intent = try load(allocator, catalog.data_objects, expected);
        defer intent.deinit();
        const work = intent.parsed.value.work;
        const observed = try self.inspect(self.context, allocator, catalog, policy, work);
        switch (observed) {
            .stream => |result| {
                defer result.deinit(allocator);
                if (work != .stream) return error.InvalidWorkloadIntent;
                try c.DirectStreamResponse.validate(allocator, expected.connection, .{ .operation = work.stream.work }, result);
                if (result == .recovering or result.operation == null) return error.ClientOperationPending;
            },
            .queue => |result| {
                defer result.deinit(allocator);
                if (work != .queue) return error.InvalidWorkloadIntent;
                try c.DirectQueueResponse.validate(allocator, expected.connection, .{ .operation = work.queue.work }, result);
                if (result == .recovering or result.operation == null) return error.ClientOperationPending;
            },
        }
    }
};

/// Borrowed input descriptor; createProjected copies it into the canonical
/// body. Fuze owns interpretation. This descriptor grants no source authority.
pub const Projection = struct {
    pub const json_schema_sequence_bounds = .{ .fields = c.fuze.TableSchema.max_columns };
    fields: []const c.fuze.WorkloadProjection.Field,
    plan: w.Binary,

    pub fn restore(self: Projection, allocator: std.mem.Allocator, source: c.fuze.WorkloadProjection.Source) !c.fuze.LogicalPlanCodec.Owned {
        const bytes = self.plan.decode(allocator, c.fuze.LogicalPlanCodec.max_bytes) catch |err| return refusal(err);
        defer allocator.free(bytes);
        return c.fuze.WorkloadProjection.restore(allocator, source, self.fields, bytes) catch |err| return refusal(err);
    }

    // This boundary only decodes and validates caller-supplied data. Preserve
    // allocation failure and source conflicts; malformed layouts/plans are not
    // temporary owner failures and must never invite a recovery retry.
    fn refusal(err: anyerror) anyerror {
        return switch (err) {
            error.OutOfMemory, error.SourceChanged, error.WorkloadProjectionSourceChanged => err,
            else => error.InvalidWorkloadProjection,
        };
    }
};

pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    source: c.DirectLogProtocol.Definition,
    work: Work,
    projection: ?Projection,

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
        if (self.projection) |projection| {
            var plan = try projection.restore(allocator, .{ .binding = try self.work.binding(allocator), .schema = declaration.definition.schema });
            defer plan.deinit();
        }
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
    /// Logical retained-work reservation: complete body, bounded reference and
    /// token bookkeeping. Native payload/result storage has its own quotas.
    pub fn reservationBytes(self: Reference) !u64 {
        try self.validate();
        return std.math.add(u64, self.record.content.bytes, c.DirectIntent.max_bytes + 512);
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
    return createProjected(allocator, connection, source, work, null);
}
pub fn createProjected(allocator: std.mem.Allocator, connection: w.Connection, source: c.DirectLogProtocol.Definition, work: Work, projection: ?Projection) !Self {
    const value: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .source = source, .work = work, .projection = projection };
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
    var result = try createProjected(allocator, parsed.value.connection, parsed.value.source, parsed.value.work, parsed.value.projection);
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

test "workload token verifies independent signed references and exact commitments" {
    const t = std.testing;
    const Fixture = struct { request: w.Request, public_key: [32]u8, digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice([2]Fixture, t.allocator, @embedFile("fixtures/direct-workload-token-v1.json"));
    defer parsed.deinit();
    for (parsed.value) |fixture| {
        try fixture.request.validate(t.allocator);
        try fixture.request.proof.verify(fixture.public_key);
        const selected = fixture.request.action.client_token.bind.intent;
        try t.expectEqualSlices(u8, &fixture.digest, &try selected.digest());
        var changed = fixture.request;
        changed.action.client_token.bind.intent.workload.namespace += 1;
        try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
        changed = fixture.request;
        changed.action.client_token.bind.key.account[0] ^= 1;
        try t.expectError(error.InvalidClientToken, changed.action.client_token.bind.validate());
        changed = fixture.request;
        changed.action.client_token.bind.budget.bytes -= 1;
        try t.expectError(error.ClientTokenBudget, changed.action.client_token.bind.validate());
        var transport = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
        defer transport.deinit();
        const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = .{ .scope = fixture.request.connection.scope, .branch = 2, .audience = fixture.request.connection.audience, .principal = fixture.request.connection.principal, .role = null }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1)) };
        try t.expectError(error.CatalogIdentityConflict, selected.admit(caller));
        try t.expectError(error.CatalogIdentityConflict, selected.operation(caller, .inspect, 1));
        try t.expectError(error.CatalogIdentityConflict, selected.operation(caller, .cancel, 1));
    }
}
