//! Installed named KV through signed database calls; no Station writer or turns.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const data = @import("transit_data_client");
const p = c.protocol;
const d = p.DataLifecycle;
const K = c.DirectKV;
const Client = c.DirectKVClient;
const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };
const payload: [1024]u8 = @splat(0xa5);
const Pin = struct { definition: p.Growth.Definition, request: @FieldType(K.Request, "pin") };
const Caller = struct {
    context: *data.Context,
    handle: data.Context.Handle,
    fn deinit(self: *Caller) void {
        const allocator = self.context.allocator;
        self.context.close(.none) catch unreachable;
        self.context.deinit() catch unreachable;
        allocator.destroy(self.context);
    }
    fn callKV(self: *Caller, output: *std.heap.ArenaAllocator, action: Client.Action) !data.Catalog.KVOutcome {
        return self.context.callKV(self.handle, output, action);
    }
};
fn callerFor(init: std.process.Init, client: c.DirectTableClient) !Caller {
    const context = try init.gpa.create(data.Context);
    errdefer init.gpa.destroy(context);
    context.* = try data.Context.init(init.gpa, init.io, .{ .catalogs = 2, .active = .{ .data = 1, .control = 1 } });
    errdefer {
        context.close(.none) catch unreachable;
        context.deinit() catch unreachable;
    }
    const handle = try context.openCatalog(.{ .url = client.authority.url, .service_url = client.service.url, .connection = client.connection, .timeout_ms = 30000 }, client.key.secret_key.seed());
    return .{ .context = context, .handle = handle };
}
fn call(caller: *Caller, output: *std.heap.ArenaAllocator, action: Client.Action) !Client.Result {
    const outcome = try caller.callKV(output, action);
    return switch (outcome.value) {
        .result => |value| value,
        .failure => |failure| failure.cause,
    };
}
fn unknown(caller: *Caller, output: *std.heap.ArenaAllocator, action: Client.Action, identity: d.Operation) !void {
    const outcome = try caller.callKV(output, action);
    try t.expect(outcome.value == .failure);
    try t.expectEqual(error.InvalidTableResponse, outcome.value.failure.cause);
    try t.expect(outcome.mutationAttempted());
    try t.expectEqualDeep(identity, outcome.attempt.mutation.?.identity.?);
    try t.expectEqual(.unknown, outcome.value.failure.diagnostic.?.outcome);
}
fn finish(caller: *Caller, output: *std.heap.ArenaAllocator, declaration: K.Declaration) !void {
    _ = try call(caller, output, .{ .declaration = .{ .declaration = declaration, .command = .admit, .steps = 1 } });
    const found = try call(caller, output, .{ .declaration = .{ .declaration = declaration, .command = .execute, .steps = 64 } });
    try t.expect(found.declaration.operation == .committed);
}
fn mutation(init: std.process.Init, path: []const u8) !std.json.Parsed(Client.Saved) {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(c.DirectTableProtocol.max_request_bytes));
    return Client.load(init.gpa, bytes);
}
fn pinPath(init: std.process.Init, path: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}.pin", .{path});
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const declaration = try Client.prepareDeclaration(init.gpa, .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 641000 }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = 641000 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = undefined },
        .namespace = 1,
        .name = try .init("direct_state"),
        .action = .{ .create = .{ .owner = role, .spec = spec } },
    });
    const preview = (try call(&caller, &output, .{ .declaration = .{ .declaration = declaration, .command = .preview, .steps = 1 } })).declaration.preview;
    try t.expectEqual(.none, preview.reason);
    try t.expect((try call(&caller, &output, .{ .lookup = .{ .namespace = 1, .name = "direct_state" } })).lookup == null);
    try finish(&caller, &output, declaration);
    const metadata = (try call(&caller, &output, .{ .lookup = .{ .namespace = 1, .name = "direct_state" } })).lookup.?;
    var binding = declaration.binding;
    binding.identity.operation = 641001;
    binding.action = .insert;
    binding.expected_definition = metadata.interpretation.interpretation;
    binding.expected_data = metadata.position;
    var keys: [8][2]u8 = undefined;
    var changes: [8]c.storage.KVPartition.Change = undefined;
    for (&keys, &changes, 0..) |*key, *change, index| {
        key.* = .{ 0, @intCast(index) };
        change.* = .{ .put = .{ .key = key, .value = .{ .value = .{ .atom = .{ .bytes = &payload } } }, .expect = .absent } };
    }
    const work = try Client.prepareMutation(&output, binding, spec, &changes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try Client.save(init.arena.allocator(), client.connection, work) });
    try unknown(&caller, &output, .{ .mutate = work }, work.binding.identity);
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try mutation(init, path);
    defer saved.deinit();
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const work = saved.value.mutation;
    const original = (try call(&caller, &output, .{ .operation = work.binding })).operation.?;
    try t.expectEqual(@as(u64, 8), original.outcome.affected);
    try t.expectEqualDeep(original, (try call(&caller, &output, .{ .mutate = work })).operation.?);
    for (0..8) |index| {
        const key = [_]u8{ 0, @intCast(index) };
        const found = (try call(&caller, &output, .{ .get = .{ .object = work.binding.target, .key = &key } })).value;
        try t.expectEqualSlices(u8, &payload, found.value.?.value.atom.bytes);
        _ = output.reset(.retain_capacity);
    }
    const metadata = (try call(&caller, &output, .{ .observe = work.binding.target })).definition;
    var owner = work.binding.identity;
    owner.operation = 641002;
    const planned: Pin = .{ .definition = p.Growth.current_definition, .request = .{ .object = work.binding.target, .owner = owner, .expected = metadata.position } };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try pinPath(init, path), .data = try p.Json.valueAlloc(init.arena.allocator(), planned) });
    try unknown(&caller, &output, .{ .pin = planned.request }, owner);
}
pub fn verify(init: std.process.Init, client: c.DirectTableClient, admin: anytype, path: []const u8) !void {
    const saved = try mutation(init, path);
    defer saved.deinit();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, try pinPath(init, path), init.arena.allocator(), .limited(8192));
    const planned = try p.Json.parseFromSliceOwned(Pin, init.gpa, bytes);
    defer planned.deinit();
    if (planned.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const work = saved.value.mutation;
    const original = (try call(&caller, &output, .{ .operation = work.binding })).operation.?;
    const retained = (try call(&caller, &output, .{ .pin_status = .{ .object = work.binding.target, .owner = planned.value.request.owner } })).pin_status.handle.?;
    try t.expectEqualDeep(retained, (try call(&caller, &output, .{ .pin = planned.value.request })).pin);
    const metadata = (try call(&caller, &output, .{ .observe = work.binding.target })).definition;
    var binding = work.binding;
    binding.identity.operation = 641003;
    binding.expected_data = null;
    const replacement = try Client.prepareMutation(&output, binding, spec, &.{.{ .put = .{ .key = &.{ 0, 0 }, .value = .{ .value = .{ .atom = .{ .bytes = "replacement" } } }, .expect = .present } }});
    _ = try call(&caller, &output, .{ .mutate = replacement });
    const previous = (try call(&caller, &output, .{ .get = .{ .object = work.binding.target, .key = &.{ 0, 0 }, .source = retained } })).value;
    const current = (try call(&caller, &output, .{ .get = .{ .object = work.binding.target, .key = &.{ 0, 0 } } })).value;
    try t.expectEqualStrings("replacement", current.value.?.value.atom.bytes);
    try t.expectEqualSlices(u8, &payload, previous.value.?.value.atom.bytes);
    // A separate signed caller receives current data rights, never ownership.
    const reader_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(31));
    const reader_role = (try client.authority.query(.{ .realm = 42, .principal = 102, .kind = .{ .authorization = .{ .kind = .identity } } }, reader_key)).body.authorization.body.identity.login_role;
    const config = try client.call(.describe);
    defer config.deinit();
    const authority = config.value.result.description.authority;
    for ([_]struct { id: u64, rights: u64 }{ .{ .id = authority.database, .rights = c.TableAuthority.connect }, .{ .id = authority.initial_schema_authority, .rights = c.TableAuthority.usage }, .{ .id = metadata.authorization, .rights = c.KVAuthority.inspect | c.KVAuthority.read } }) |grant|
        _ = try admin.change(.{ .grant = .{ .object = c.TableAuthority.reference(grant.id), .grantee = reader_role, .privileges = grant.rights } });
    var reader = client;
    reader.connection.principal = 102;
    reader.key = reader_key;
    var viewer = try callerFor(init, reader);
    defer viewer.deinit();
    _ = try call(&viewer, &output, .{ .get = .{ .object = work.binding.target, .key = &.{ 0, 0 } } });
    _ = try admin.change(.{ .revoke_privileges = .{ .object = c.TableAuthority.reference(metadata.authorization), .grantee = reader_role, .privileges = c.KVAuthority.read } });
    try t.expectError(error.AccessDenied, call(&viewer, &output, .{ .get = .{ .object = work.binding.target, .key = &.{ 0, 0 } } }));
    _ = try call(&viewer, &output, .{ .observe = work.binding.target });
    var rename: K.Declaration = .{ .binding = binding, .namespace = metadata.namespace, .name = metadata.name, .action = .{ .rename = try .init("renamed_state") } };
    rename.binding.identity.operation = 641004;
    rename.binding.action = .rename;
    rename = try Client.prepareDeclaration(init.gpa, rename);
    try finish(&caller, &output, rename);
    const renamed = (try call(&caller, &output, .{ .lookup = .{ .namespace = 1, .name = "renamed_state" } })).lookup.?;
    var drop = rename;
    drop.binding.identity.operation = 641005;
    drop.binding.action = .drop;
    drop.binding.expected_definition = renamed.interpretation.interpretation;
    drop.name = renamed.name;
    drop.action = .drop;
    drop = try Client.prepareDeclaration(init.gpa, drop);
    try finish(&caller, &output, drop);
    try t.expectEqualDeep(original, (try call(&caller, &output, .{ .mutate = work })).operation.?);
    const after_drop = (try call(&caller, &output, .{ .get = .{ .object = work.binding.target, .key = &.{ 0, 0 }, .source = retained } })).value;
    try t.expectEqualSlices(u8, &payload, after_drop.value.?.value.atom.bytes);
    caller.context.beginClose();
    try t.expectError(error.ClientContextClosed, call(&caller, &output, .{ .mutate = work }));
    // Original outcome observation and explicit cleanup retain control capacity
    // while closing, without permitting another data mutation.
    try t.expectEqualDeep(original, (try call(&caller, &output, .{ .operation = work.binding })).operation.?);
    _ = try call(&caller, &output, .{ .release = .{ .object = work.binding.target, .source = retained } });
    try t.expect((try call(&caller, &output, .{ .pin_status = .{ .object = work.binding.target, .owner = retained.owner } })).pin_status.released);
}
