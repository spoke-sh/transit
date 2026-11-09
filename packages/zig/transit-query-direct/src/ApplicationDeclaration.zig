//! Frozen ordered program with exact native resource definitions. Compilation
//! and canonical decoding are local; publication and activation are separate.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const a = q.fuze.ApplicationProgram;
const d = p.DataLifecycle;
const Binding = q.ApplicationBinding;
const Self = @This();
pub const max_bytes = a.Codec.max_bytes;
// One instruction may retain values from every declared input plus the control
// resource. This is the native authorization budget, not a collection limit.
pub const max_resources = c.DirectRecord.max_guard_objects - 1;
pub const json_schema_sequence_bounds = .{ .resources = max_resources };
pub const Limits = struct {
    requests: u64,
    scan_rows: u64,
    result_bytes: u32,
    continuation_bytes: u32,
    retained_bytes: u64,
    transaction: p.Transaction.Limits,
    pub fn validate(self: Limits) !void {
        if (self.requests == 0 or self.scan_rows == 0 or self.result_bytes == 0 or self.result_bytes > a.Codec.max_bytes or
            self.continuation_bytes == 0 or self.continuation_bytes > a.Codec.max_bytes or self.retained_bytes < self.continuation_bytes) return error.InvalidQueryBudget;
        try self.transaction.validate();
    }
};
definition: p.Growth.Definition,
connection: c.DirectTableProtocol.Connection,
executor_role: u64,
namespace: u64,
name: c.TableAuthority.Name,
object: d.Object,
operation: d.Operation,
source_digest: [32]u8,
program: a.Program,
resources: []const Binding,
limits: Limits,

pub const Input = struct {
    connection: c.DirectTableProtocol.Connection,
    executor_role: u64,
    namespace: u64,
    object: u64,
    operation: u64,
    source: []const u8,
    resources: []const Binding,
    limits: Limits,
};
/// Compile once and own the complete native binding. The caller supplies
/// resolved schemas and the reviewed executor role; this performs no I/O.
pub fn prepare(allocator: std.mem.Allocator, input: Input) !std.json.Parsed(Self) {
    var parsed = try a.parse(allocator, input.source, null);
    defer parsed.deinit();
    var source_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(input.source, &source_digest, .{});
    const value: Self = .{ .definition = p.Growth.current_definition, .connection = input.connection, .executor_role = input.executor_role, .namespace = input.namespace, .name = try .init(parsed.program.name), .object = .{ .scope = input.connection.scope, .branch = input.connection.branch, .object = input.object }, .operation = .{ .scope = input.connection.scope, .principal = input.connection.principal, .operation = input.operation }, .source_digest = source_digest, .program = parsed.program, .resources = input.resources, .limits = input.limits };
    const bytes = try value.encode(allocator);
    defer allocator.free(bytes);
    return decode(allocator, bytes);
}

pub fn validate(self: Self, allocator: std.mem.Allocator) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.connection.validate();
    try p.Authorization.roleId(self.executor_role);
    if (self.executor_role == 0) return error.InvalidAuthorizationRole;
    try self.connection.object(self.object);
    try self.connection.owner(self.operation);
    try c.Model.nativeId(self.namespace);
    try self.name.validate();
    try self.limits.validate();
    try a.Codec.validate(self.program);
    if (!std.mem.eql(u8, self.name.slice(), self.program.name) or self.resources.len == 0 or self.resources.len > max_resources)
        return error.DataflowIdentityConflict;
    for (self.resources, 0..) |resource, index| {
        try resource.validate(allocator, self.connection);
        if (resource.namespace() != self.namespace or std.meta.eql(resource.interpretation().object, self.object)) return error.DataflowIdentityConflict;
        for (self.resources[0..index]) |prior| {
            if (std.meta.eql(prior.interpretation().object, resource.interpretation().object) or
                std.meta.eql(prior.name(), resource.name())) return error.DuplicateProgramResource;
        }
    }
}
pub fn bind(self: Self, allocator: std.mem.Allocator) !a.Types.Bound {
    try self.validate(allocator);
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const resources = try scratch.allocator().alloc(a.Types.Resource, self.resources.len);
    for (self.resources, resources) |resource, *target| target.* = try resource.resource(scratch.allocator(), self.connection);
    var result = try a.Types.bind(allocator, self.program, resources, null);
    errdefer result.deinit();
    // Helpers such as SECRET have no SQL resource operand. Pin their canonical
    // native owner in the same dependency set and common transaction as reads
    // named in the program. Resource metadata cannot grant permission itself.
    const uses = try result.arena.allocator().alloc(a.Types.Use, self.resources.len);
    @memcpy(uses[0..result.uses.len], result.uses);
    var count = result.uses.len;
    var native = result.native.iterator();
    while (native.next()) |kind| {
        var found: ?u16 = null;
        for (self.resources, 0..) |resource, index| if (resource.nativeBinding() == kind) {
            if (found != null) return error.DuplicateProgramNativeBinding;
            found = @intCast(index);
        };
        const index = found orelse return error.MissingProgramNativeBinding;
        var existing: ?*a.Types.Use = null;
        for (uses[0..count]) |*use| if (use.resource == index) {
            existing = use;
            break;
        };
        if (existing) |use| {
            use.read = true;
            use.guard = true;
        } else {
            uses[count] = .{ .resource = index, .read = true, .guard = true };
            count += 1;
        }
    }
    result.uses = uses[0..count];
    // A retained definition carries exactly its used dependencies, not a set of
    // ambient bindings that could silently gain authority after replacement.
    if (result.uses.len != self.resources.len) return error.DataflowIdentityConflict;
    for (result.uses) |use| if (try self.resources[use.resource].privileges(use) == 0) return error.ProgramResourceKindMismatch;
    // Reject predicates that the Queue acquisition owner cannot execute before
    // publication. Actual invocations retain their selected partition and
    // original claim identity; the compiler never acquires input here.
    _ = try self.inputClaim(allocator, 0, self.operation);
    return result;
}
pub fn inputClaim(self: Self, allocator: std.mem.Allocator, partition: u32, operation: d.Operation) !p.StreamQueue.Claim {
    try self.validate(allocator);
    try self.connection.owner(operation);
    for (self.resources) |resource| {
        if (!std.mem.eql(u8, resource.name().slice(), self.program.queue)) continue;
        if (resource.value != .log or resource.value.log.declaration.kind() != .queue) return error.ProgramResourceKindMismatch;
        const queue = resource.value.log;
        _ = try queue.declaration.partition(partition);
        const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = resource.interpretation(), .partition = partition };
        var metadata = try c.DirectLogProtocol.decodeMetadata(allocator, self.connection, queue);
        defer metadata.deinit();
        return .{
            .target = target,
            .operation = operation,
            .maximum = 1,
            .lease_ms = queue.declaration.stored.declaration.configuration.policy.queue.lease_ms,
            .predicate = try a.Predicate.compile(allocator, self.program, target, metadata.definition.schema),
        };
    }
    return error.UnknownProgramResource;
}
pub fn digest(self: Self, allocator: std.mem.Allocator) ![32]u8 {
    var bound = try self.bind(allocator);
    defer bound.deinit();
    return p.Json.hashBounded("transit.application.program.definition.v1\x00", self, max_bytes);
}
pub fn interpretation(self: Self, allocator: std.mem.Allocator) !d.Definition {
    return .{ .object = self.object, .revision = 1, .digest = try self.digest(allocator) };
}
pub fn encode(self: Self, allocator: std.mem.Allocator) ![]u8 {
    var bound = try self.bind(allocator);
    defer bound.deinit();
    return p.Json.valueAllocBounded(allocator, self, max_bytes);
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Self) {
    // The program codec owns the syntax/node limits for pointer-rich JSON.
    try a.Codec.validateEncoding(bytes);
    const parsed = try std.json.parseFromSlice(Self, allocator, bytes, .{ .allocate = .alloc_always, .max_value_len = max_bytes });
    errdefer parsed.deinit();
    const canonical = try parsed.value.encode(allocator);
    defer allocator.free(canonical);
    if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidProgramNode;
    return parsed;
}

test "application declarations retain exact typed programs and consume rights without row observations" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 9 }, .branch = 1, .audience = 5, .principal = 4, .role = 6 };
    var queue = try q.fuze.LogDdl.compile(t.allocator, "CREATE QUEUE input (id BIGINT NOT NULL)", .transit, null);
    defer queue.deinit();
    const schema = try queue.statement.action.create.bind(7);
    const configuration = try queue.statement.configure(null, schema);
    const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .name = try .init("input"), .authorization = 11 };
    var properties_buffer: [4096]u8 = undefined;
    var native = try c.storage.LogDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = connection.scope, .branch = 1, .object = 7 },
        .revision = 1,
        .schema = schema,
        .configuration = configuration.configuration,
        .limits = configuration.limits,
        .properties = try properties.encode(&properties_buffer),
    });
    defer native.deinit();
    const stored = try native.stored();
    var buffer: [q.fuze.TableSchema.max_bytes]u8 = undefined;
    var resources = [_]Binding{.{ .value = .{ .log = .{
        .declaration = .{ .stored = stored, .properties = properties, .seed = stored, .initialization = .{ .scope = connection.scope, .principal = 4, .operation = 12 }, .first_partition = 1 },
        .schema = try c.DirectTableProtocol.Binary.encode(arena.allocator(), try schema.encode(&buffer)),
    } } }};
    const source = "CREATE DATAFLOW example FROM QUEUE input AS event WHERE id > 0 AS BEGIN REQUIRE event.id > 0 ELSE 'InvalidId'; END;";
    var parsed = try a.parse(t.allocator, source, null);
    defer parsed.deinit();
    var source_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &source_digest, .{});
    const declaration: Self = .{
        .definition = p.Growth.current_definition,
        .connection = connection,
        .executor_role = 6,
        .namespace = 1,
        .name = try .init("example"),
        .object = .{ .scope = connection.scope, .branch = 1, .object = 8 },
        .operation = .{ .scope = connection.scope, .principal = 4, .operation = 13 },
        .source_digest = source_digest,
        .program = parsed.program,
        .resources = &resources,
        .limits = .{ .requests = 1000, .scan_rows = 1000, .result_bytes = 65536, .continuation_bytes = 65536, .retained_bytes = 64 * 1024 * 1024, .transaction = c.DirectTransaction.default_limits },
    };
    const bytes = try declaration.encode(t.allocator);
    defer t.allocator.free(bytes);
    const restored = try decode(t.allocator, bytes);
    defer restored.deinit();
    const compiled = try prepare(t.allocator, .{ .connection = connection, .executor_role = 6, .namespace = 1, .object = 8, .operation = 13, .source = source, .resources = &resources, .limits = declaration.limits });
    defer compiled.deinit();
    try t.expectEqualDeep(try declaration.digest(t.allocator), try compiled.value.digest(t.allocator));
    try t.expectEqualDeep(try declaration.interpretation(t.allocator), try restored.value.interpretation(t.allocator));
    const claim = try restored.value.inputClaim(t.allocator, 0, declaration.operation);
    try claim.validate();
    try t.expectEqual(@as(u32, 1), claim.maximum);
    try t.expect(claim.predicate != null);
    try t.expectEqualDeep(declaration.operation, claim.operation);
    try t.expectError(error.InvalidLogPartitioning, restored.value.inputClaim(t.allocator, 1, declaration.operation));
    var bound = try restored.value.bind(t.allocator);
    defer bound.deinit();
    try t.expectEqual(c.LogAuthority.read | c.LogAuthority.acquire | c.LogAuthority.settle, try restored.value.resources[0].privileges(bound.uses[0]));
    try t.expectEqual(c.LogAuthority.read | c.LogAuthority.append, try resources[0].privileges(.{ .resource = 0, .write = true }));
    var changed = declaration;
    changed.connection.role = 7;
    try t.expect(!std.meta.eql(try declaration.digest(t.allocator), try changed.digest(t.allocator)));
    changed = declaration;
    changed.executor_role = 7;
    try t.expect(!std.meta.eql(try declaration.digest(t.allocator), try changed.digest(t.allocator)));
    changed = declaration;
    changed.object.object = 7;
    try t.expectError(error.DataflowIdentityConflict, changed.validate(t.allocator));
    changed = declaration;
    changed.resources = &.{ resources[0], resources[0] };
    try t.expectError(error.DuplicateProgramResource, changed.validate(t.allocator));

    // A helper's implicit dependency must be canonical and explicit in the
    // retained declaration, even when no SQL GET names the secret resource.
    var secret_program = try a.parse(t.allocator, "CREATE DATAFLOW example FROM QUEUE input AS event AS BEGIN LET key = SECRET('browser.cookie_key'); BEGIN ATOMIC REQUIRE SECRET_CURRENT(key) ELSE 'Rotated'; END; END;", null);
    defer secret_program.deinit();
    var with_secret = declaration;
    with_secret.program = secret_program.program;
    try t.expectError(error.MissingProgramNativeBinding, with_secret.bind(t.allocator));
    const secret_binding = try testSecretBinding(arena.allocator(), connection, 9, "secrets", .secret_references);
    with_secret.resources = &.{ resources[0], secret_binding };
    var secret_bound = try with_secret.bind(t.allocator);
    defer secret_bound.deinit();
    try t.expectEqual(2, secret_bound.uses.len);
    try t.expect(secret_bound.native.contains(.secret_references));
    try t.expect(secret_bound.uses[1].read and secret_bound.uses[1].guard and !secret_bound.uses[1].write);
    try t.expectEqual(c.KVAuthority.read | c.KVAuthority.use_secret, try secret_binding.privileges(secret_bound.uses[1]));
    const secret_claim = try with_secret.inputClaim(t.allocator, 0, declaration.operation);
    const begin = try q.ApplicationTransaction.prepareBegin(arena.allocator(), with_secret, secret_claim, .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(3), .token = @splat(5) }, declaration.operation);
    try t.expectEqual(3, begin.selection.explicit_objects.len);
    try t.expectEqualDeep(secret_binding.interpretation().object, begin.selection.explicit_objects[2].object);

    var explicit = try a.parse(t.allocator, "CREATE DATAFLOW example FROM QUEUE input AS event AS BEGIN LET row = GET FROM secrets KEY DIGEST('key'); LET key = SECRET('browser.cookie_key'); END;", null);
    defer explicit.deinit();
    with_secret.program = explicit.program;
    var merged = try with_secret.bind(t.allocator);
    defer merged.deinit();
    try t.expectEqual(2, merged.uses.len);
    try t.expect(merged.uses[1].read and merged.uses[1].guard);

    with_secret.program = secret_program.program;
    with_secret.resources = &.{ resources[0], try testSecretBinding(arena.allocator(), connection, 9, "secrets", null) };
    try t.expectError(error.MissingProgramNativeBinding, with_secret.bind(t.allocator));
    with_secret.resources = &.{ resources[0], secret_binding, try testSecretBinding(arena.allocator(), connection, 10, "other_secrets", .secret_references) };
    try t.expectError(error.DuplicateProgramNativeBinding, with_secret.bind(t.allocator));
    with_secret.resources = &.{ resources[0], secret_binding };
    with_secret.program = declaration.program;
    try t.expectError(error.DataflowIdentityConflict, with_secret.bind(t.allocator));

    resources[0].value.log.declaration.properties.name = try .init("forged");
    try t.expectError(error.InvalidTableResponse, declaration.validate(t.allocator));
    const client: c.DirectTableClient = .{ .allocator = t.allocator, .authority = undefined, .service = undefined, .connection = connection, .key = undefined };
    try t.expectError(error.InvalidTableResponse, resources[0].requireCurrent(client));
}

fn testSecretBinding(allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, id: u64, name: []const u8, native: ?q.fuze.NativeBinding.Kind) !Binding {
    const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = id + 100, .name = try .init(name), .native_binding = native };
    const spec = try c.NativeBindingSchema.kvSpec(.secret_references);
    var buffer: [4096]u8 = undefined;
    var prepared = try c.storage.KVDeclaration.prepare(allocator, .{
        .object = .{ .scope = connection.scope, .branch = connection.branch, .object = id },
        .revision = 1,
        .spec = spec,
        .properties = try properties.encode(&buffer),
    });
    defer prepared.deinit();
    return .{ .value = .{ .kv = .{ .stored = try prepared.stored(), .properties = properties, .spec = spec } } };
}
