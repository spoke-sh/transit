//! Named native data through public catalog and Station callers only.
const std = @import("std");
const c = @import("transit_catalog");
const app = @import("transit_station_app");
const s = c.station;
const p = c.protocol;
const g = p.Growth;
const R = c.DirectResource;
const h = c.DirectCatalogResources;
const Owner = app.NamedResource;
const doc = app.query.document;
const t = std.testing;
pub const State = struct { bindings: [2]R.Binding, saved: [2]h.Binding, dependencies: ?[2]c.DirectDependency.Binding = null };

// Exercise the shared serialized host boundary while the fixture's assertions
// keep using the existing fixed-size native types. Original CREATE operations
// use the saved host binding read from disk, never a reconstructed replacement.
const HostClient = struct {
    catalog: c.DirectTableClient,
    state: ?*const State = null,
    fn binding(self: HostClient, allocator: std.mem.Allocator, value: R.Binding) !h.Binding {
        if (self.state) |state| for (state.bindings, state.saved) |original, saved| {
            if (std.meta.eql(original.identity(), value.identity())) {
                try original.requireSame(value);
                try original.requireSame(try saved.native());
                return saved;
            }
        };
        return h.Binding.foreign(allocator, value);
    }
    fn call(self: HostClient, arena: *std.heap.ArenaAllocator, action: h.Action) !h.Result {
        var session: c.DirectTableBridge.Session = .{ .allocator = self.catalog.allocator };
        defer session.deinit();
        const bytes = try p.Json.valueAlloc(arena.allocator(), c.DirectTableBridge.Action{ .resources = action });
        const parsed = try c.DirectTableBridge.parse(arena.allocator(), bytes);
        defer parsed.deinit();
        return (try session.apply(arena, self.catalog, parsed.value, null)).resources;
    }
    fn operation(self: HostClient, original: R.Binding, command: R.Command, steps: u16) !R.Observation {
        var arena = std.heap.ArenaAllocator.init(self.catalog.allocator);
        defer arena.deinit();
        const result = (try self.call(&arena, .{ .operation = .{ .binding = try self.binding(arena.allocator(), original), .command = command, .steps = steps } })).observation;
        return switch (result) {
            .not_observed => .not_observed,
            .operation => |value| .{ .operation = try value.native() },
        };
    }
    fn preview(self: HostClient, original: R.Binding) !R.Preview {
        var arena = std.heap.ArenaAllocator.init(self.catalog.allocator);
        defer arena.deinit();
        const result = (try self.call(&arena, .{ .preview = try self.binding(arena.allocator(), original) })).preview;
        return .{ .binding = try result.binding.native(), .position = try result.position.native(), .current = if (result.current) |value| try value.native() else null, .reason = result.reason };
    }
    fn view(value: h.View) !c.DirectCatalog.ResourceView {
        return .{ .definition = try value.definition.native(), .interpretation = try value.interpretation.native(), .position = try value.position.native() };
    }
    fn lookup(self: HostClient, namespace: u64, name: []const u8) !?c.DirectCatalog.ResourceView {
        var arena = std.heap.ArenaAllocator.init(self.catalog.allocator);
        defer arena.deinit();
        const result = (try self.call(&arena, .{ .lookup = .{ .namespace = namespace, .name = name } })).lookup;
        return if (result) |value| try view(value) else null;
    }
    fn list(self: HostClient, namespace: u64) !@FieldType(c.DirectTableProtocol.Result, "resource_list") {
        var arena = std.heap.ArenaAllocator.init(self.catalog.allocator);
        defer arena.deinit();
        const result = (try self.call(&arena, .{ .list = .{ .namespace = namespace, .cursor = null } })).list;
        var entries: [8]?c.DirectCatalog.ResourceView = @splat(null);
        for (result.entries, &entries) |slot, *entry| if (slot) |value| {
            entry.* = try view(value);
        };
        return .{ .entries = entries, .next = if (result.next) |next| try next.check(self.catalog.connection, .{ .resources = namespace }) else null, .position = try result.position.native() };
    }
};

fn key(seed: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(seed));
}

pub fn prepare(client: c.DirectTableClient, admin: anytype, role: u64) !State {
    (try client.call(.initialize)).deinit();
    const worker_role = (try admin.client.query(.{ .realm = 42, .principal = 102, .kind = .{ .authorization = .{ .kind = .identity } } }, try key(31))).body.authorization.body.identity.login_role;
    for ([_]u64{ role, worker_role }) |native_role| _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = native_role, .privileges = p.permission(.inspect) } });
    var result: State = .{ .bindings = undefined, .saved = undefined };
    for (&result.bindings, 0..) |*binding, i| {
        const writer = try admin.submit(.{ .spawn = .{} });
        _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = writer }, .grantee = role, .privileges = p.permission(.admin) | p.permission(.send) } });
        _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = writer }, .grantee = worker_role, .privileges = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish) } });
        binding.* = .{ .definition = g.current_definition, .connection = client.connection, .operation = 80000 + i, .object = .{ .scope = client.connection.scope, .branch = 1, .object = 800 + i }, .expected = null, .action = .{ .create = .{
            .namespace = 1,
            .name = try .init(if (i == 0) "named_kv" else "named_document"),
            .owner = role,
            .writer = writer,
            .owned = false,
            .deadline_ms = null,
            .history_ms = null,
            .spec = if (i == 0) .{ .kv = .{ .value_type = .utf8, .nullable = true, .key_encoding = .native_bytes, .value_encoding = .fvl1 } } else .{ .document = .{ .document = 91, .type_revision = 1, .limits = .{ .record_bytes = 4096, .staging_bytes = 16384, .staging_records = 4 } } },
        } } };
        result.saved[i] = try h.Binding.foreign(client.allocator, binding.*);
        const resources: HostClient = .{ .catalog = client };
        const preview = try resources.preview(binding.*);
        try t.expectEqual(.none, preview.reason);
        try t.expectEqual(.not_observed, try resources.operation(binding.*, .inspect, 1));
        const saved = try c.DirectResourceClient.save(client.allocator, binding.*);
        defer client.allocator.free(saved);
        try t.expectEqualDeep(binding.*, try c.DirectResourceClient.load(client.allocator, saved));
    }
    return result;
}

pub fn admit(client: c.DirectTableClient, state: State) !void {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    for (state.bindings) |binding| try t.expectError(error.InvalidTableResponse, resources.operation(binding, .admit, 1));
}
pub fn allocationPlan(client: c.DirectTableClient, state: State, index: usize) !void {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    const binding = state.bindings[index];
    try t.expectEqual(.admitted, (try resources.operation(binding, .inspect, 1)).operation.phase);
    try t.expectError(error.InvalidTableResponse, resources.operation(binding, .execute, 64));
    if (index == 0) {
        try t.expectError(error.Conflict, resources.operation(state.bindings[1], .execute, 64));
        try t.expectEqual(.admitted, (try resources.operation(state.bindings[1], .inspect, 1)).operation.phase);
    }
}
pub fn allocate(client: c.DirectTableClient, admin: anytype, state: State, index: usize) !void {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    const binding = state.bindings[index];
    const prepared = (try resources.operation(binding, .inspect, 1)).operation;
    try t.expectEqual(.prepared, prepared.phase);
    try t.expectError(error.AccessDenied, resources.operation(binding, .execute, 64));
    // Allocation is already accepted, but it grants no data access. Recover
    // the original caller's native receipt before granting explicit rights.
    const request = try binding.allocation(prepared.allocation.?);
    const receipt = (try client.authority.query(.{ .realm = 42, .principal = 101, .kind = .{ .authorization = .{ .kind = .{ .receipt = request } } } }, client.key)).body.authorization.body.receipt.?;
    for ([_]u64{ 0, 101, 102 }) |subject| _ = try admin.submit(.{ .grant_resource = .{ .resource = receipt.position, .subject = subject, .permissions = p.State.all_permissions } });
    try t.expectError(error.InvalidTableResponse, resources.operation(binding, .execute, 64));
}

const Handler = struct {
    owner: Owner,
    allocator: std.mem.Allocator,
    done: bool = false,
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
        const self: *@This() = @ptrCast(@alignCast(raw.?));
        const code = try frame.payload.asInteger();
        if (code == 0) {
            _ = try self.owner.initialize(self.allocator, turn, 101);
            return;
        }
        if (self.owner.initial.creation.spec == .kv) {
            if (code == 1) try self.owner.put(self.allocator, turn, 101, "message", .{ .value = .{ .atom = .{ .bytes = "durable named value" } } }) else if (code == 2) try self.owner.remove(self.allocator, turn, 101, "message") else return error.UnexpectedCommand;
        } else {
            const service = try self.owner.document();
            const change: doc.Change = .{ .document = 91, .epoch = 1, .replica = 1, .previous = 0, .first = 1, .len = 1, .operations = blk: {
                var operations: @FieldType(doc.Change, "operations") = undefined;
                operations[0] = .{ .assign = .{ .field = try doc.Model.Name.init("answer"), .value = .{ .signed = 42 } } };
                break :blk operations;
            } };
            switch (code) {
                1 => _ = try service.prepare(turn, 1, change, 256),
                2 => self.done = try service.upload(turn, 1, change),
                3 => self.done = (try service.advance(turn, 1)) != .progress,
                else => return error.UnexpectedCommand,
            }
        }
    }
};

fn send(client: c.DirectTableClient, pid: u64, code: i64) !void {
    const identity = try client.authority.query(.{ .realm = 42, .principal = 101, .kind = .{ .authorization = .{ .kind = .identity } } }, client.key);
    _ = try client.authority.submit(try g.sign(.{ .realm = 42, .principal = 101, .sequence = identity.principal_sequence + 1, .command = .{ .send = .{ .pid = pid, .value = try (s.Frame{ .kind = .cast, .payload = p.Value.integer(code) }).encode() } } }, client.key));
}
fn runTurn(io: std.Io, client: c.DirectTableClient, admin: anytype, definition: R.Definition, code: i64) !bool {
    const pid = definition.creation.writer;
    const process = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = pid } }, try key(17))).body.process.process;
    var server = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = 102, .pid = pid, .generation = process.generation, .key = try key(31) }, "state");
    var handler: Handler = .{ .owner = .{ .initial = definition }, .allocator = client.allocator };
    try send(client, pid, code);
    for (0..32) |_| {
        const step = try server.step(.{ .context = &handler, .handle = Handler.handle }, @as(u64, @intCast(std.Io.Clock.real.now(io).toMilliseconds())) + 30000);
        switch (step) {
            .committed => return handler.done,
            .blocked => return server.handler_error orelse error.NamedResourceBehaviorBlocked,
            .idle => return error.MissingInput,
            .progress => {},
        }
    }
    return error.NamedResourceStepBudget;
}

fn reader(client: c.DirectTableClient) s.client.ResourceReader {
    return .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
}
fn inspect(client: c.DirectTableClient, definition: R.Definition) !?Owner.Step {
    var raw = try reader(client).open(definition.resource);
    const owner: Owner = .{ .initial = definition };
    return owner.inspect(client.allocator, &raw, 101);
}
pub fn initialize(io: std.Io, client: c.DirectTableClient, admin: anytype, state: State, phase: u8) !void {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    for (state.bindings, 0..) |binding, i| {
        const allocated = (try resources.operation(binding, .inspect, 1)).operation;
        try t.expectEqual(.allocated, allocated.phase);
        const definition = allocated.resulting.?;
        try t.expectEqual(null, try resources.lookup(1, binding.action.create.name.slice()));
        if (phase == 0) {
            try t.expectEqual(null, try inspect(client, definition));
            _ = try admin.submit(.{ .associate = .{ .pid = definition.creation.writer, .name = try .init("state"), .resource = definition.resource } });
            const process = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = definition.creation.writer } }, try key(17))).body.process.process;
            _ = try admin.submit(.{ .own = .{ .pid = definition.creation.writer, .expected_generation = process.generation, .worker = 102 } });
        } else try t.expectEqual(if (i == 0) Owner.Step.complete else if (phase == 1) Owner.Step.reserved else Owner.Step.initialized, (try inspect(client, definition)).?);
        _ = try runTurn(io, client, admin, definition, 0);
        try t.expectEqual(if (i == 0 or phase == 2) Owner.Step.complete else if (phase == 0) Owner.Step.reserved else Owner.Step.initialized, (try inspect(client, definition)).?);
    }
}
pub fn publish(client: c.DirectTableClient, state: State) !void {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    for (state.bindings) |binding| try t.expectError(error.InvalidTableResponse, resources.operation(binding, .execute, 64));
}
pub fn dependencyPlan(client: c.DirectTableClient, state: State) ![2]c.DirectDependency.Binding {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    var definitions: [2]R.Definition = undefined;
    for (state.bindings, &definitions) |binding, *definition| {
        const known = (try resources.operation(binding, .inspect, 1)).operation;
        try t.expectEqual(.complete, known.phase);
        definition.* = known.resulting.?;
    }
    var result: [2]c.DirectDependency.Binding = undefined;
    for (&result, 0..) |*binding, i| binding.* = .{
        .definition = g.current_definition,
        .connection = client.connection,
        .operation = 83000 + i,
        .action = .register,
        .authority = .dependent,
        .edge = .{ .source = try definitions[i].interpretation(client.allocator), .dependent = try definitions[1 - i].dependent(client.allocator), .privileges = c.TableAuthority.select },
    };
    return result;
}
fn dependency(client: c.DirectTableClient, binding: c.DirectDependency.Binding, command: c.DirectDependency.Command) !c.DirectDependency.Observation {
    const response = try client.call(.{ .dependency_operation = .{ .binding = binding, .command = command } });
    defer response.deinit();
    return response.value.result.dependency_operation;
}
fn graph(client: c.DirectTableClient, selection: c.DirectDependency.Selection) !c.DirectDependency.Page {
    const response = try client.call(.{ .dependencies = .{ .selection = selection, .cursor = null, .authority = .dependent } });
    defer response.deinit();
    return response.value.result.dependencies;
}
fn removal(registration: c.DirectDependency.Binding) c.DirectDependency.Binding {
    var result = registration;
    result.operation += 10;
    result.action = .remove;
    return result;
}
pub fn dependencyUncertain(client: c.DirectTableClient, state: State, remove: bool) !void {
    for (state.dependencies.?) |binding| try t.expectError(error.InvalidTableResponse, dependency(client, if (remove) removal(binding) else binding, .accept));
}
pub fn dependencyRecover(client: c.DirectTableClient, admin: anytype, state: State) !void {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    for (state.dependencies.?, 0..) |binding, i| {
        const receipt = (try dependency(client, binding, .inspect)).outcome;
        try t.expect(receipt.changed and receipt.phase == .applied);
        try t.expectEqualDeep(receipt, (try dependency(client, binding, .accept)).outcome);
        try t.expectEqualDeep(binding.edge, (try graph(client, .{ .dependents = binding.edge.source.object })).entries[0].?);
        try t.expectEqualDeep(binding.edge, (try graph(client, .{ .dependencies = binding.edge.dependent.interpretation.object })).entries[0].?);
        var drop = state.bindings[i];
        drop.operation = 83100 + i;
        drop.expected = binding.edge.source;
        drop.action = .drop;
        try t.expectEqual(.dependency, (try resources.preview(drop)).reason);
        try t.expectEqual(.dependency, (try resources.operation(drop, .admit, 1)).operation.reason);
        const definition = (try resources.operation(state.bindings[i], .inspect, 1)).operation.resulting.?;
        _ = try admin.submit(.{ .grant_resource = .{ .resource = definition.resource, .subject = 101, .permissions = 0 } });
        var retry = binding;
        retry.operation = 83200 + i;
        try t.expectError(error.AccessDenied, dependency(client, retry, .accept));
        try t.expectEqualDeep(binding.edge, (try graph(client, .{ .dependents = binding.edge.source.object })).entries[0].?);
        try t.expectEqualDeep(receipt, (try dependency(client, binding, .inspect)).outcome);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = definition.resource, .subject = 101, .permissions = p.State.all_permissions } });
    }
}
pub fn verify(io: std.Io, client: c.DirectTableClient, admin: anytype, state: State) !void {
    const resources: HostClient = .{ .catalog = client, .state = &state };
    for (state.dependencies.?) |binding| {
        const closed = (try dependency(client, removal(binding), .inspect)).outcome;
        try t.expect(closed.changed and closed.phase == .applied);
        try t.expectEqualDeep(closed, (try dependency(client, removal(binding), .accept)).outcome);
        try t.expect((try dependency(client, binding, .accept)).outcome.position.next_lsn < closed.position.next_lsn);
        try t.expectEqual(null, (try graph(client, .{ .dependents = binding.edge.source.object })).entries[0]);
        try t.expectEqual(null, (try graph(client, .{ .dependencies = binding.edge.dependent.interpretation.object })).entries[0]);
    }
    for (state.bindings, 0..) |binding, i| {
        const original = (try resources.operation(binding, .inspect, 1)).operation;
        try t.expectEqual(.complete, original.phase);
        try t.expectEqualDeep(original, (try resources.operation(binding, .execute, 64)).operation);
        const selected = (try resources.lookup(1, binding.action.create.name.slice())).?;
        try t.expectEqualDeep(original.resulting.?, selected.definition);
        _ = try runTurn(io, client, admin, selected.definition, 1);
        if (i == 0) {
            var raw = try reader(client).open(selected.definition.resource);
            const owner: Owner = .{ .initial = selected.definition };
            var value = (try owner.get(client.allocator, &raw, 101, "message")).?;
            defer value.deinit();
            try t.expectEqualStrings("durable named value", value.cell.value.atom.bytes);
            _ = try runTurn(io, client, admin, selected.definition, 2);
            raw = try reader(client).open(selected.definition.resource);
            try t.expectEqual(null, try owner.get(client.allocator, &raw, 101, "message"));
        } else {
            for ([_]i64{ 2, 3 }) |code| {
                for (0..128) |_| {
                    if (try runTurn(io, client, admin, selected.definition, code)) break;
                } else return error.DocumentDidNotComplete;
            }
            const document: doc.Client = .{ .source = reader(client) };
            const found = try document.describe(.{ .resource = selected.definition.resource, .document = 91 });
            try t.expectEqual(@as(u64, 1), found.reference.revision);
            const value = try document.readPath(found.reference, &.{try doc.Model.Name.init("answer")});
            try t.expectEqual(.scalar, value.value.status());
            try t.expectEqual(@as(i64, 42), value.value.assignments[0].value.signed);
        }
        // Metadata visibility grants no data permission; native revocation does
        // not retroactively turn a completed catalog receipt into a failure.
        _ = try admin.submit(.{ .grant_resource = .{ .resource = selected.definition.resource, .subject = 101, .permissions = 0 } });
        try t.expectError(error.AccessDenied, reader(client).open(selected.definition.resource));
        try t.expectEqualDeep(original, (try resources.operation(binding, .inspect, 1)).operation);
        try t.expectEqualDeep(selected, (try resources.lookup(1, binding.action.create.name.slice())).?);
        var rename = binding;
        rename.operation = 81000 + i;
        rename.expected = selected.interpretation;
        rename.action = .{ .rename = try .init(if (i == 0) "renamed_kv" else "renamed_document") };
        _ = try resources.operation(rename, .admit, 1);
        const renamed = (try resources.operation(rename, .execute, 1)).operation;
        try t.expectEqual(.complete, renamed.phase);
        try t.expectEqualDeep(selected.definition, try renamed.resulting.?.initial());
        try t.expectEqual(null, try resources.lookup(1, binding.action.create.name.slice()));
        const current = (try resources.lookup(1, rename.action.rename.slice())).?;
        var drop = rename;
        drop.operation = 82000 + i;
        drop.expected = current.interpretation;
        drop.action = .drop;
        _ = try resources.operation(drop, .admit, 1);
        try t.expect((try resources.operation(drop, .execute, 1)).operation.retired);
        try t.expectEqual(null, try resources.lookup(1, rename.action.rename.slice()));
        try t.expectEqualDeep(original, (try resources.operation(binding, .inspect, 1)).operation);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = selected.definition.resource, .subject = 101, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        try t.expectEqual(Owner.Step.complete, (try inspect(client, selected.definition)).?);
    }
    const page = try resources.list(1);
    for (page.entries) |entry| try t.expectEqual(null, entry);
    try t.expectEqual(null, page.next);
}
