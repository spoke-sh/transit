//! Direct catalog control records. Name candidates publish no Table state;
//! visibility is determined by the exact accepted Table declaration.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const a = c.TableAuthority;
const storage = c.storage;
const pages = storage.TreeStore.pages;
pub const max_record_bytes = 16 * 1024;
pub const max_intent_bytes = storage.TransitLog.max_payload_bytes;

pub const Configuration = struct {
    scope: d.Scope,
    branch: u64,
    partition: u64,
    audience: u64,
    authority: a.Profile,
    database_name: a.Name,
    initial_schema_name: a.Name,
    pub fn validate(self: Configuration) !void {
        try self.scope.validate();
        try self.authority.validate();
        try self.database_name.validate();
        try self.initial_schema_name.validate();
        try c.Model.nativeId(self.audience);
        if (self.branch != 1 or self.partition == 0 or self.partition == std.math.maxInt(u64)) return error.InvalidDirectCatalogConfiguration;
    }
};

/// Canonical TableDeclaration.properties. The current native object remains the
/// role/permission authority; this record only names its stable reference.
pub const Properties = struct {
    namespace: u64,
    authorization: u64,
    name: a.Name,
    pub fn validate(self: Properties) !void {
        try c.Model.nativeId(self.namespace);
        try c.Model.nativeId(self.authorization);
        try self.name.validate();
    }
    pub fn encode(self: Properties, output: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(output);
        try std.json.Stringify.value(self, .{}, &writer);
        return writer.buffered();
    }
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Properties {
        if (bytes.len > storage.TableDeclaration.max_properties_bytes) return error.InvalidDirectCatalogProperties;
        const parsed = try std.json.parseFromSlice(Properties, allocator, bytes, .{});
        defer parsed.deinit();
        var canonical: [storage.TableDeclaration.max_properties_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try parsed.value.encode(&canonical))) return error.InvalidDirectCatalogProperties;
        return parsed.value;
    }
    pub fn target(self: Properties, id: u64) a.Table {
        return .{ .id = id, .schema = self.namespace, .authorization = self.authorization };
    }
};

pub const Entry = struct {
    object: u64,
    partition: u64,
    seed: ?storage.TableDeclaration.Stored,
    /// Control-log record owning the latest named native-resource state.
    /// Mandatory null for Tables; no second name or object directory exists.
    resource: ?u64,
    /// Latest Stream/Queue lifecycle record in this same control log.
    log: ?u64,
    pub fn validate(self: Entry, config: Configuration) !void {
        if (self.object == 0) return error.InvalidDirectCatalogEntry;
        if (self.log) |at| {
            if (at == 0 or self.resource != null or self.seed != null or self.partition <= config.partition) return error.InvalidDirectCatalogEntry;
            return;
        }
        if (self.resource) |at| {
            if (at == 0 or self.partition != 0 or self.seed != null) return error.InvalidDirectCatalogEntry;
            return;
        }
        if (self.partition <= config.partition) return error.InvalidDirectCatalogEntry;
        if (self.seed) |seed| {
            try seed.validate();
            const id = seed.interpretation.object;
            if (self.object != id.object or !std.meta.eql(id.scope, config.scope) or id.branch != config.branch or
                seed.interpretation.revision != 1 or seed.retired) return error.InvalidDirectCatalogEntry;
        }
    }
};

pub const Name = struct {
    namespace: u64,
    name: a.Name,
    object: u64,
    reservation: d.Operation,
    pub fn validate(self: Name, config: Configuration) !void {
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        try self.reservation.validate();
        if (self.object == 0 or !std.meta.eql(self.reservation.scope, config.scope)) return error.InvalidDirectCatalogName;
    }
};

pub const Root = struct {
    configuration: Configuration,
    next_lsn: u64,
    next_partition: u64,
    initialized: bool,
    schemas: ?pages.Reference,
    schema_names: ?pages.Reference,
    namespace_claims: ?pages.Reference,
    namespace_pending: ?pages.Reference,
    objects: ?pages.Reference,
    names: ?pages.Reference,
    operations: ?pages.Reference,
    pending: ?pages.Reference,
    native_allocations: ?pages.Reference,
    dependents: ?pages.Reference,
    dependencies: ?pages.Reference,
    client_tokens: ?pages.Reference,
    client_token_count: u64,
    client_operations: ?pages.Reference,
    client_pending: ?pages.Reference,
    client_accounts: ?pages.Reference,
    pub fn empty(config: Configuration) !Root {
        try config.validate();
        return .{ .configuration = config, .next_lsn = 0, .next_partition = config.partition + 1, .initialized = false, .schemas = null, .schema_names = null, .namespace_claims = null, .namespace_pending = null, .objects = null, .names = null, .operations = null, .pending = null, .native_allocations = null, .dependents = null, .dependencies = null, .client_tokens = null, .client_token_count = 0, .client_operations = null, .client_pending = null, .client_accounts = null };
    }
    pub fn validate(self: Root) !void {
        try self.configuration.validate();
        if (self.next_partition <= self.configuration.partition or self.initialized != (self.next_lsn != 0)) return error.InvalidDirectCatalogRoot;
        if ((self.client_operations == null) != (self.client_token_count == 0)) return error.InvalidDirectCatalogRoot;
        if ((self.client_accounts == null) != (self.client_token_count == 0)) return error.InvalidDirectCatalogRoot;
        if ((self.client_tokens == null) != (self.client_token_count == 0) or self.client_token_count >= self.next_lsn and self.client_token_count != 0) return error.InvalidDirectCatalogRoot;
    }
};

pub const Phase = enum { admitted, ready, rejected, cancelled, settled };
pub const Reason = enum { none, name_conflict, object_conflict, stale_definition, stale_data, dependency, constraint };
pub const Operation = struct {
    binding: d.Binding,
    intent: d.Content,
    phase: Phase,
    reason: Reason,
    pub fn pending(self: Operation) bool {
        return self.phase == .admitted or self.phase == .ready;
    }
    pub fn validate(self: Operation, config: Configuration) !void {
        try self.binding.validate();
        try self.intent.validate();
        if (!std.meta.eql(self.binding.identity.scope, config.scope) or self.binding.target.branch != config.branch or self.intent.bytes > max_intent_bytes or
            (self.phase == .rejected) != (self.reason != .none) or (self.phase == .ready and self.binding.action != .create)) return error.InvalidDirectCatalogOperation;
        switch (self.binding.action) {
            .create, .alter, .rename, .drop => {},
            else => return error.InvalidDirectCatalogOperation,
        }
    }
};

pub const Record = struct {
    definition: p.Growth.Definition,
    previous: [32]u8,
    root: Root,
    action: union(enum) { initialize, operation: Operation, assertion: c.NameAssertion.Outcome, namespace: c.DirectNamespace.Operation, dependency: c.DirectDependency.Outcome, resource: c.DirectResource.Operation, log: c.DirectLog.Operation, client_token: c.DirectClientToken.Progress },
    pub fn validate(self: Record, position: u64) !void {
        try self.root.validate();
        if (self.root.next_lsn != try std.math.add(u64, position, 1) or !self.root.initialized) return error.InvalidDirectCatalogHistory;
        switch (self.action) {
            .log => |value| {
                try value.validate();
                if (position == 0 or !std.meta.eql(value.binding.target.scope, self.root.configuration.scope) or
                    value.binding.target.branch != self.root.configuration.branch or
                    value.position.partition != self.root.configuration.partition or value.position.next_lsn != self.root.next_lsn) return error.InvalidDirectCatalogHistory;
            },
            .client_token => |value| {
                try value.validate();
                if (position == 0 or !value.receipt.binding.key.connection.matches(self.root.configuration) or value.revision.partition != self.root.configuration.partition or value.revision.next_lsn != self.root.next_lsn) return error.InvalidDirectCatalogHistory;
            },
            .resource => |value| {
                try value.validate();
                if (position == 0 or !value.binding.connection.matches(self.root.configuration) or value.position.partition != self.root.configuration.partition or value.position.next_lsn != self.root.next_lsn) return error.InvalidDirectCatalogHistory;
            },
            .dependency => |value| {
                try value.validate();
                if (position == 0 or !value.binding.connection.matches(self.root.configuration) or value.position.partition != self.root.configuration.partition or value.position.next_lsn != self.root.next_lsn) return error.InvalidDirectCatalogHistory;
            },
            .namespace => |value| {
                try value.validate();
                if (position == 0 or !value.binding.connection.matches(self.root.configuration) or value.position.partition != self.root.configuration.partition or value.position.next_lsn != self.root.next_lsn) return error.InvalidDirectCatalogHistory;
            },
            .initialize => if (position != 0) return error.InvalidDirectCatalogHistory,
            .operation => |value| {
                if (position == 0) return error.InvalidDirectCatalogHistory;
                try value.validate(self.root.configuration);
            },
            .assertion => |value| {
                try value.validate();
                const connection = value.binding.connection;
                if (position == 0 or !connection.matches(self.root.configuration) or value.position.partition != self.root.configuration.partition or value.position.next_lsn != self.root.next_lsn) return error.InvalidDirectCatalogHistory;
            },
        }
    }
};

pub fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}

pub fn idKey(id: u64) !pages.Key {
    if (id == 0) return error.InvalidCatalogIdentity;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, id, .big);
    return pages.Key.init(&bytes);
}

pub fn operationKey(operation: d.Operation) !pages.Key {
    try operation.validate();
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], operation.principal, .big);
    std.mem.writeInt(u64, bytes[8..16], operation.operation, .big);
    return pages.Key.init(&bytes);
}

pub fn principalKey(principal: u64) !pages.Key {
    if (principal > p.max_counter) return error.InvalidCatalogIdentity;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, principal, .big);
    return pages.Key.init(&bytes);
}

pub fn nameKey(namespace: u64, name: a.Name) !pages.Key {
    try c.Model.nativeId(namespace);
    try name.validate();
    var bytes: [8 + p.Authorization.max_name_bytes]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], namespace, .big);
    @memcpy(bytes[8..][0..name.len], name.slice());
    return pages.Key.init(&hash(bytes[0 .. 8 + name.len]));
}

pub fn pageValue(input: anytype) !pages.Value {
    var bytes: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(input, .{}, &writer);
    return pages.Value.init(writer.buffered());
}

/// Only use for fixed-owning records. Borrowed schemas/intents need their own
/// parsed ownership and must never outlive a temporary JSON arena.
pub fn fromValue(comptime T: type, allocator: std.mem.Allocator, input: pages.Value) !T {
    const parsed = try std.json.parseFromSlice(T, allocator, input.slice(), .{});
    defer parsed.deinit();
    return parsed.value;
}

/// Canonical frozen DDL intent, independent of transport nonce or credentials.
/// CREATE freezes the selected owner role. Its native registration ID is a
/// later accepted provisioning result, never part of caller-chosen intent.
pub const Intent = struct {
    namespace: u64,
    name: a.Name,
    action: union(enum) {
        create: struct { schema: c.fuze.TableSchema.Schema, owner: u64 },
        rename: a.Name,
        alter: c.fuze.TableEvolution.Change,
        drop,
    },
    pub fn validate(self: Intent, binding: d.Binding) !void {
        try binding.validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        const action: d.Action = switch (self.action) {
            .create => .create,
            .rename => .rename,
            .alter => .alter,
            .drop => .drop,
        };
        if (binding.action != action) return error.InvalidDirectCatalogOperation;
        switch (self.action) {
            .create => |value| {
                try value.schema.validate();
                if (value.owner > p.max_counter) return error.InvalidCatalogIdentity;
                if (value.schema.object != binding.target.object or value.schema.revision != 1) return error.InvalidDirectCatalogOperation;
            },
            .rename => |name| try name.validate(),
            .alter, .drop => {},
        }
    }
    pub fn digest(self: Intent, _: std.mem.Allocator) ![32]u8 {
        // Hash canonical JSON through a bounded stack buffer. A tiny declaration
        // must not reserve the maximum WAL payload merely to compute its hash.
        var scratch: [1024]u8 = undefined;
        var output: IntentHash = .{ .writer = .{ .buffer = &scratch, .vtable = &.{ .drain = IntentHash.drain } } };
        output.hash.update("transit.catalog.ddl.intent.v1\x00");
        try std.json.Stringify.value(self, .{}, &output.writer);
        try output.writer.flush();
        return output.hash.finalResult();
    }
};

const IntentHash = struct {
    writer: std.Io.Writer,
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    bytes: usize = 0,
    limit: usize = max_intent_bytes,
    fn drain(writer: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *IntentHash = @alignCast(@fieldParentPtr("writer", writer));
        var size = std.math.mul(usize, data[data.len - 1].len, splat) catch return error.WriteFailed;
        for (data[0 .. data.len - 1]) |part| size = std.math.add(usize, size, part.len) catch return error.WriteFailed;
        const total = std.math.add(usize, writer.end, size) catch return error.WriteFailed;
        if (total > self.limit - self.bytes) return error.WriteFailed;
        self.hash.update(writer.buffered());
        for (data[0 .. data.len - 1]) |part| self.hash.update(part);
        for (0..splat) |_| self.hash.update(data[data.len - 1]);
        self.bytes += total;
        writer.end = 0;
        return size;
    }
};

test "streamed DDL hashes preserve canonical identity without allocating maximum intent storage" {
    const t = std.testing;
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    const name = try a.Name.init("x");
    const drop: Intent = .{ .namespace = 1, .name = name, .action = .drop };
    // Independent Python hashlib over compact JSON: namespace=1, Name len=1,
    // bytes="x" + 62 NULs, action={drop:{}}; same domain prefix including NUL.
    // Zig JSON encodes this valid UTF-8 byte array as a string.
    const canonical = comptime json: {
        var bytes: []const u8 = "{\"namespace\":1,\"name\":{\"len\":1,\"bytes\":\"x";
        for (0..62) |_| bytes = bytes ++ "\\u0000";
        break :json bytes ++ "\"},\"action\":{\"drop\":{}}}";
    };
    var canonical_buffer: [1024]u8 = undefined;
    var canonical_writer: std.Io.Writer = .fixed(&canonical_buffer);
    try std.json.Stringify.value(drop, .{}, &canonical_writer);
    try t.expectEqualStrings(canonical, canonical_writer.buffered());
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "2b954fe77c9bc081ca58e185ff0df0d20854ed54b7209f2bfa1a54abac792660");
    try t.expectEqual(expected, try drop.digest(failing.allocator()));
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 17, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const escaped: [2048]u8 = @splat('\n');
    const actions = [_]@FieldType(Intent, "action"){
        .{ .create = .{ .schema = schema, .owner = 7 } },
        .{ .rename = try a.Name.init("snow ☃") },
        .{ .alter = .{ .add = .{ .name = "label", .type = .utf8, .default = .{ .value = .{ .atom = .{ .bytes = &escaped } } } } } },
        .drop,
    };
    for (actions) |action| {
        const intent: Intent = .{ .namespace = 1, .name = name, .action = action };
        var buffer: [16384]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try std.json.Stringify.value(intent, .{}, &writer);
        var expected_hash = std.crypto.hash.sha2.Sha256.init(.{});
        expected_hash.update("transit.catalog.ddl.intent.v1\x00");
        expected_hash.update(writer.buffered());
        try t.expectEqual(expected_hash.finalResult(), try intent.digest(failing.allocator()));
    }
    try t.expectEqual(0, failing.alloc_index);
}

test "streamed intent hashing rejects the original exact byte bound" {
    const t = std.testing;
    var scratch: [7]u8 = undefined;
    var output: IntentHash = .{ .limit = 37, .writer = .{ .buffer = &scratch, .vtable = &.{ .drain = IntentHash.drain } } };
    try output.writer.splatByteAll('x', 37);
    try output.writer.flush();
    var expected: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&@as([37]u8, @splat('x')), &expected, .{});
    try t.expectEqual(expected, output.hash.finalResult());
    try output.writer.writeByte('x');
    try t.expectError(error.WriteFailed, output.writer.flush());
    output = .{ .writer = .{ .buffer = &scratch, .vtable = &.{ .drain = IntentHash.drain } } };
    try t.expectError(error.WriteFailed, output.writer.splatByteAll('x', max_intent_bytes + 1));
    try t.expectEqual(0, output.bytes);
}

pub const Request = struct {
    binding: d.Binding,
    intent: Intent,
    pub fn validate(self: Request, allocator: std.mem.Allocator, configuration: Configuration) !void {
        try self.intent.validate(self.binding);
        if (!std.meta.eql(self.binding.target.scope, configuration.scope) or self.binding.target.branch != configuration.branch or
            !std.mem.eql(u8, &try self.intent.digest(allocator), &self.binding.intent)) return error.DataIdentityConflict;
    }
};
