//! Publication and fenced lifecycle of ordered Queue programs. The declaration
//! and control row use existing catalog, owned-record and KV operations.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const d = p.DataLifecycle;
const flow = p.Dataflow;
const KV = c.DirectKVClient;
const Self = @This();
pub const Declaration = q.ApplicationDeclaration;
pub const declaration_format: u32 = 0x41504431; // APD1
pub const head_key = "\x00application/head";
pub const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };
client: c.DirectTableClient,

pub const Head = struct {
    definition: p.Growth.Definition,
    declaration: [32]u8,
    control: flow.Control,
    executor_role: ?u64,
    attempt: u64,
    pending: ?c.DirectClientToken.Key,
    completed: u64,
    refused: u64,
    retirement_complete: bool,
    pub fn initial(digest: [32]u8) Head {
        return .{ .definition = p.Growth.current_definition, .declaration = digest, .control = .initial(), .executor_role = null, .attempt = 0, .pending = null, .completed = 0, .refused = 0, .retirement_complete = false };
    }
    pub fn validate(self: Head) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.control.validate();
        if (self.executor_role) |role| try p.Authorization.roleId(role);
        if ((self.control.state == .published and self.executor_role != null) or
            ((self.control.state == .authorized or self.control.state == .active or self.control.state == .suspended) and self.executor_role == null) or
            (self.retirement_complete and (self.control.state != .retired or self.pending != null)) or
            self.completed > self.attempt or self.refused > self.attempt - self.completed) return error.InvalidDataflowControl;
        if (self.pending) |key| {
            try key.validate();
            if (self.attempt == 0 or self.attempt == self.completed + self.refused) return error.InvalidDataflowControl;
        }
    }
};
pub const Observation = struct { head: Head, storage: d.Definition, position: d.Position };
pub fn account() [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.application.declarations.v1", &result, .{});
    return result;
}
pub fn workAccount() [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.application.invocations.v1", &result, .{});
    return result;
}
pub fn nameKey(self: Self, namespace: u64, name: c.TableAuthority.Name) c.DirectClientToken.Key {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, namespace, .big);
    hash.update(&bytes);
    hash.update(name.slice());
    return .{ .definition = p.Growth.current_definition, .connection = self.client.connection, .account = account(), .token = hash.finalResult()[0..16].* };
}
fn operation(self: Self, value: Declaration, label: []const u8, ordinal: u64) d.Operation {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.application.operation.v1\x00");
    hash.update(label);
    var bytes: [8]u8 = undefined;
    for ([_]u64{ value.object.object, value.operation.operation, ordinal }) |number| {
        std.mem.writeInt(u64, &bytes, number, .big);
        hash.update(&bytes);
    }
    return .{ .scope = self.client.connection.scope, .principal = self.client.connection.principal, .operation = std.mem.readInt(u64, hash.finalResult()[0..8], .big) | 1 };
}
fn requireCaller(self: Self, value: Declaration) !void {
    try value.validate(self.client.allocator);
    if (!std.meta.eql(value.connection, self.client.connection) or self.client.transaction != null) return error.DataflowIdentityConflict;
}
pub fn load(self: Self, reference: c.DirectRecord.Reference) !std.json.Parsed(Declaration) {
    if (reference.format != c.DirectOwnedRecord.format or !std.meta.eql(reference.scope.connection, self.client.connection)) return error.InvalidDirectRecord;
    const bytes = try c.DirectRecord.read(self.client.allocator, self.client, reference);
    defer self.client.allocator.free(bytes);
    const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, self.client.allocator, bytes);
    defer envelope.deinit();
    try envelope.value.validate(reference);
    if (envelope.value.format != declaration_format) return error.InvalidDirectRecord;
    const payload = try envelope.value.bytes.decode(self.client.allocator, Declaration.max_bytes);
    defer self.client.allocator.free(payload);
    const result = try Declaration.decode(self.client.allocator, payload);
    errdefer result.deinit();
    try self.requireCaller(result.value);
    return result;
}
pub fn find(self: Self, namespace: u64, name: c.TableAuthority.Name) !?std.json.Parsed(Declaration) {
    const progress = try c.DirectClientToken.inspect(self.client, self.nameKey(namespace, name)) orelse return null;
    if (progress.receipt.binding.intent != .external) return error.InvalidDirectRecord;
    const result = try self.load(progress.receipt.binding.intent.external.record);
    errdefer result.deinit();
    if (result.value.namespace != namespace or !std.meta.eql(result.value.name, name) or
        !std.mem.eql(u8, &progress.receipt.binding.fingerprint, &try result.value.digest(self.client.allocator))) return error.DataflowIdentityConflict;
    return result;
}
pub fn publish(self: Self, value: Declaration) !Observation {
    try self.requireCaller(value);
    const key = self.nameKey(value.namespace, value.name);
    const fingerprint = try value.digest(self.client.allocator);
    if (try c.DirectClientToken.lookup(self.client, key)) |known| {
        if (!std.mem.eql(u8, &known.binding.fingerprint, &fingerprint)) return error.DataflowIdentityConflict;
    } else {
        for (value.resources) |resource| try resource.requireCurrent(self.client);
    }
    const bytes = try value.encode(self.client.allocator);
    defer self.client.allocator.free(bytes);
    const progress = try c.DirectOwnedRecord.stage(self.client, key, value.namespace, value.operation.operation, fingerprint, .{ .bytes = 2 * Declaration.max_bytes }, declaration_format, bytes);
    if (progress.original.?.phase == .closed or progress.cancel) return error.OwnedRecordClosed;
    return self.initialize(value, key);
}
fn edge(value: Declaration, storage: d.Definition, use: q.fuze.ApplicationProgram.Types.Use) !c.DirectDependency.Edge {
    const resource = value.resources[use.resource];
    return .{ .source = resource.interpretation(), .dependent = .{ .kind = .application, .interpretation = storage }, .privileges = try resource.privileges(use) };
}
pub fn initialize(self: Self, value: Declaration, key: c.DirectClientToken.Key) !Observation {
    try self.requireCaller(value);
    try key.requireSame(self.nameKey(value.namespace, value.name));
    const staged = try c.DirectClientToken.inspect(self.client, key) orelse return error.ClientOperationMissing;
    if (!std.mem.eql(u8, &staged.receipt.binding.fingerprint, &try value.digest(self.client.allocator)) or staged.cancel) return error.DataflowIdentityConflict;
    _ = try c.DirectOwnedRecord.call(self.client, .{ .retain_original = .{ .key = key, .expected = staged.revision } });
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const owner = (try self.client.require(.{ .namespace = value.namespace, .target = null, .access = .create_table })).role;
    const create = try KV.prepareDeclaration(self.client.allocator, .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = self.operation(value, "create", 0), .target = value.object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) },
        .namespace = value.namespace,
        .name = value.name,
        .action = .{ .create = .{ .owner = owner, .spec = spec } },
    });
    _ = try KV.apply(&output, self.client, .{ .declaration = .{ .declaration = create, .command = .admit, .steps = 1 } });
    const installed = try KV.apply(&output, self.client, .{ .declaration = .{ .declaration = create, .command = .execute, .steps = 64 } });
    if (installed.declaration.operation != .committed) return error.ManagedTableInitializationPending;
    const metadata = (try KV.apply(&output, self.client, .{ .observe = value.object })).definition;
    const initial = Head.initial(try value.digest(self.client.allocator));
    _ = try KV.apply(&output, self.client, .{ .mutate = try self.mutation(&output, value, metadata.interpretation.interpretation, null, initial, self.operation(value, "initial", 0), .absent) });
    var bound = try value.bind(self.client.allocator);
    defer bound.deinit();
    for (bound.uses, 0..) |use, index| {
        const response = try self.client.call(.{ .dependency_operation = .{ .binding = .{
            .definition = p.Growth.current_definition,
            .connection = self.client.connection,
            .operation = self.operation(value, "dependency", index).operation,
            .edge = try edge(value, metadata.interpretation.interpretation, use),
            .action = .register,
            .authority = .dependent,
        }, .command = .accept } });
        defer response.deinit();
        if (response.value.result.dependency_operation != .outcome or response.value.result.dependency_operation.outcome.phase != .applied)
            return error.DataflowSourceChanged;
    }
    const progress = (try c.DirectClientToken.inspect(self.client, key)).?;
    if (progress.pending) _ = try c.DirectClientToken.update(self.client, .{ .key = key, .expected = progress.revision, .pending = false, .cancel = false, .record = null });
    return self.inspect(value);
}
pub fn inspect(self: Self, value: Declaration) !Observation {
    try self.requireCaller(value);
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const read = (try KV.apply(&output, self.client, .{ .get = .{ .object = value.object, .key = head_key } })).value;
    const cell = read.value orelse return error.ManagedTableInitializationPending;
    if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidDirectRecord;
    const parsed = try p.Json.parseFromSlice(Head, self.client.allocator, cell.value.atom.bytes);
    defer parsed.deinit();
    try parsed.value.validate();
    if (!std.mem.eql(u8, &parsed.value.declaration, &try value.digest(self.client.allocator)) or
        (parsed.value.executor_role != null and parsed.value.executor_role.? != value.executor_role)) return error.DataflowIdentityConflict;
    return .{ .head = parsed.value, .storage = read.interpretation.interpretation, .position = read.position };
}
fn mutation(_: Self, arena: *std.heap.ArenaAllocator, value: Declaration, storage: d.Definition, position: ?d.Position, head: Head, identity: d.Operation, expect: @FieldType(@FieldType(c.storage.KVPartition.Change, "put"), "expect")) !c.DirectKV.Mutation {
    try head.validate();
    const bytes = try p.Json.valueAllocBounded(arena.allocator(), head, 16 * 1024);
    return KV.prepareMutation(arena, .{ .definition = p.Growth.current_definition, .identity = identity, .target = value.object, .action = .insert, .expected_definition = storage, .expected_data = position, .intent = @splat(0) }, spec, &.{.{ .put = .{ .key = head_key, .value = .{ .value = .{ .atom = .{ .bytes = bytes } } }, .expect = expect } }});
}
pub fn executor(self: Self, value: Declaration, observed: Observation) !c.DirectTableClient {
    const role = observed.head.executor_role orelse return error.InvalidDataflowTransition;
    if (role != value.executor_role) return error.DataflowIdentityConflict;
    try p.Authorization.roleId(role);
    var result = self.client;
    result.connection.role = role;
    return result;
}
pub fn requireDependencies(self: Self, value: Declaration, observed: Observation) !void {
    var bound = try value.bind(self.client.allocator);
    defer bound.deinit();
    var checks: [Declaration.max_resources]c.DirectTableProtocol.ReadCheck = undefined;
    for (bound.uses, checks[0..bound.uses.len]) |use, *check| check.* = .{ .dependency = try edge(value, observed.storage, use) };
    const response = try (try self.executor(value, observed)).call(.{ .check_set = checks[0..bound.uses.len] });
    response.deinit();
}
/// Save this exact request before admission. AS ROLE is mandatory for
/// authorization and cannot silently change the executor on later controls.
pub fn prepareControl(self: Self, value: Declaration, attempt: flow.ControlAttempt, role: ?u64) ![]u8 {
    try self.requireCaller(value);
    try attempt.validate();
    if (!std.meta.eql(attempt.target, try value.interpretation(self.client.allocator)) or attempt.command == .refresh) return error.InvalidDataflowTransition;
    const observed = try self.inspect(value);
    if (!std.meta.eql(observed.head.control, attempt.expected)) return error.DataflowLeaseFenced;
    var next = observed;
    next.head.control = try next.head.control.apply(attempt.command);
    if (attempt.command == .authorize) {
        next.head.executor_role = role orelse return error.InvalidDataflowTransition;
        if (next.head.executor_role.? != value.executor_role) return error.DataflowIdentityConflict;
        try p.Authorization.roleId(next.head.executor_role.?);
    } else if (role != null) return error.InvalidDataflowTransition;
    switch (attempt.command) {
        .authorize, .activate, .resume_computation => try self.requireDependencies(value, next),
        .suspend_computation, .retire => {},
        .refresh => unreachable,
    }
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const request = try self.mutation(&output, value, observed.storage, observed.position, next.head, attempt.operation, .present);
    return KV.save(self.client.allocator, self.client.connection, request);
}
/// No new identity is manufactured after a lost reply. Callers retain these
/// bytes and may use the ordinary KV operation observation to settle uncertainty.
pub fn applyControl(self: Self, saved: []const u8) !c.storage.TablePartition.Evidence {
    const parsed = try KV.load(self.client.allocator, saved);
    defer parsed.deinit();
    if (!std.meta.eql(parsed.value.connection, self.client.connection)) return error.DataflowIdentityConflict;
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    return (try KV.apply(&output, self.client, .{ .mutate = parsed.value.mutation })).operation orelse error.InvalidKVResponse;
}

/// Retirement fences new work first. Edges remain until every original
/// invocation has settled; lack of read rights never authorizes dropping it.
pub fn cleanup(self: Self, value: Declaration) !bool {
    const observed = try self.inspect(value);
    if (observed.head.control.state != .retired or observed.head.pending != null) return false;
    if (observed.head.retirement_complete) return true;
    var bound = try value.bind(self.client.allocator);
    defer bound.deinit();
    for (bound.uses, 0..) |use, index| {
        const response = try self.client.call(.{ .dependency_operation = .{ .binding = .{
            .definition = p.Growth.current_definition,
            .connection = self.client.connection,
            .operation = self.operation(value, "retire-dependency", index).operation,
            .edge = try edge(value, observed.storage, use),
            .action = .remove,
            .authority = .dependent,
        }, .command = .accept } });
        defer response.deinit();
        if (response.value.result.dependency_operation != .outcome or response.value.result.dependency_operation.outcome.phase != .applied)
            return error.ManagedTableCleanupPending;
    }
    var head = observed.head;
    head.retirement_complete = true;
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const request = try self.mutation(&output, value, observed.storage, observed.position, head, self.operation(value, "retired", observed.position.next_lsn), .present);
    _ = try KV.apply(&output, self.client, .{ .mutate = request });
    return true;
}

test "managed application control requires explicit executor and preserves pending recovery" {
    const t = std.testing;
    const initial = Head.initial(@splat(1));
    try initial.validate();
    var changed = initial;
    changed.control = try initial.control.apply(.authorize);
    try t.expectError(error.InvalidDataflowControl, changed.validate());
    changed.executor_role = 7;
    try changed.validate();
    changed.control = try changed.control.apply(.activate);
    try changed.validate();
    changed.refused = 1;
    try t.expectError(error.InvalidDataflowControl, changed.validate());
    changed.refused = 0;
    changed.control = try changed.control.apply(.retire);
    changed.retirement_complete = true;
    try changed.validate();

    const client: c.DirectTableClient = .{ .allocator = t.allocator, .authority = undefined, .service = undefined, .connection = undefined, .key = undefined };
    const manager: Self = .{ .client = client };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 9 }, .branch = 1, .audience = 5, .principal = 4, .role = null };
    const invalid: Declaration = .{ .definition = p.Growth.current_definition, .connection = connection, .executor_role = 6, .namespace = 1, .name = try .init("invalid"), .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .operation = .{ .scope = connection.scope, .principal = 4, .operation = 8 }, .source_digest = @splat(1), .program = undefined, .resources = &.{}, .limits = .{ .requests = 0, .scan_rows = 0, .result_bytes = 0, .continuation_bytes = 0 } };
    try t.expectError(error.InvalidQueryBudget, manager.publish(invalid));
    try t.expectError(error.InvalidQueryBudget, manager.prepareControl(invalid, undefined, null));
    try t.expectError(error.InvalidDataflowTransition, manager.executor(invalid, .{ .head = initial, .storage = undefined, .position = undefined }));
    try t.expectError(error.DataflowIdentityConflict, manager.executor(invalid, .{ .head = changed, .storage = undefined, .position = undefined }));
}
