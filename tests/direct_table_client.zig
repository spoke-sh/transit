//! Real public typed caller; no node, core, backend or provider imports.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query");
const wire = c.station.client;
const p = c.protocol;
const g = p.Growth;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const t = std.testing;
const Lifecycle = @import("direct_table_lifecycle.zig");
const Saved = struct { create: d.Binding, insert: d.Binding, snapshot: w.Snapshot, first: c.storage.TablePartition.Evidence, second: c.storage.TablePartition.Evidence };
const Profile = struct { definition: g.Definition, catalog: c.DirectCatalog.Configuration, role: u64, saved: ?Saved = null, lifecycle: ?Lifecycle.State = null };
const Admin = struct {
    client: *wire.Client,
    fn query(self: *@This(), kind: @FieldType(p.Authorization.Query, "kind")) !g.Response {
        return self.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .authorization = .{ .kind = kind } } }, try key(17));
    }
    fn submit(self: *@This(), command: g.Command) !u64 {
        const identity = try self.query(.identity);
        return (try self.client.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = identity.principal_sequence + 1, .command = command }, try key(17)))).position;
    }
    fn change(self: *@This(), action: p.Authorization.Action) !?u64 {
        const revision = (try self.query(.identity)).body.authorization.revision;
        const id = try self.submit(.{ .authorization = .{ .begin = .{ .expected_revision = revision, .action = action } } });
        for (0..256) |_| {
            const found = (try self.query(.{ .change = id })).body.authorization.body.change;
            switch (found.status) {
                .preparing => _ = try self.submit(.{ .authorization = .{ .advance = id } }),
                .ready => _ = try self.submit(.{ .authorization = .{ .publish = id } }),
                .published => return found.created_id,
                .abandoned => return error.UnexpectedAbandonedChange,
            }
        }
        return error.AuthorizationStepBudget;
    }
};
fn key(seed: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(seed));
}
fn save(init: std.process.Init, path: []const u8, value: Profile) !void {
    const bytes = try p.Json.valueAlloc(init.arena.allocator(), value);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
}
fn provision(admin: *Admin) !Profile {
    const pid = try admin.submit(.{ .spawn = .{} });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
    const role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("table-owner"), .login = true } })).?;
    _ = try admin.change(.{ .bind_credential = .{ .principal = 101, .role = role, .public_key = (try key(29)).public_key.toBytes() } });
    const database_domain = (try admin.change(.{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.connect } })).?;
    const schema_domain = (try admin.change(.{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.usage | c.TableAuthority.create } })).?;
    const table_domain = (try admin.change(.{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.table_actions } })).?;
    const scope: d.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try admin.change(.{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try admin.change(.{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    return .{ .definition = g.current_definition, .role = role, .catalog = .{
        .scope = scope,
        .branch = 1,
        .partition = 1,
        .audience = 100,
        .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace },
        .database_name = try .init("transit"),
        .initial_schema_name = try .init("public"),
    } };
}
const columns = [_]c.fuze.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "payload", .type = .binary },
};
const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
fn execute(client: c.DirectTableClient, binding: d.Binding) !w.Result {
    const response = try client.call(.{ .operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
    defer response.deinit();
    // Operation results contain only fixed owning evidence.
    return response.value.result;
}
fn inspect(client: c.DirectTableClient, binding: d.Binding) !w.Result {
    const response = try client.call(.{ .operation = .{ .binding = binding, .command = .inspect, .steps = 1 } });
    defer response.deinit();
    return response.value.result;
}
fn binarySchema(allocator: std.mem.Allocator) !w.Binary {
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    return w.Binary.encode(allocator, try schema.encode(&bytes));
}
fn binaryRow(allocator: std.mem.Allocator, id: i64, operation: u64, payload: []const u8) !w.Binary {
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = id } } }, .{ .value = .{ .atom = .{ .bytes = payload } } } };
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = operation, .ordinal = 0 }, .cells = &cells };
    const bytes = try allocator.alloc(u8, c.fuze.TableRow.max_bytes);
    defer allocator.free(bytes);
    return w.Binary.encode(allocator, try row.encode(schema, bytes));
}
fn write(init: std.process.Init, client: c.DirectTableClient, profile: *Profile) !void {
    const alloc = init.arena.allocator();
    const initialized = try client.call(.initialize);
    defer initialized.deinit();
    const intent: c.DirectCatalog.Intent = .{ .namespace = 1, .name = try .init("events"), .action = .{ .create = .{ .schema = schema, .owner = profile.role } } };
    const binding: d.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = profile.catalog.scope, .principal = 101, .operation = 1 }, .target = .{ .scope = profile.catalog.scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(alloc) };
    const admitted = try client.call(.{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = "events", .action = .{ .create = .{ .owner = profile.role, .schema = try binarySchema(alloc) } } } });
    defer admitted.deinit();
    try t.expect(admitted.value.result.ddl == .admitted);
    const missing = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer missing.deinit();
    try t.expect(missing.value.result.lookup == null);
    const created = (try execute(client, binding)).ddl.committed;
    var payload: [64 * 1024]u8 = undefined;
    for (&payload, 0..) |*byte, i| byte.* = @truncate(i);
    var work: w.Rows = .{ .binding = binding, .interpretation = created.resulting, .schema = try binarySchema(alloc), .changes = &.{.{ .insert = try binaryRow(alloc, 1, 2, &payload) }}, .ingestion = .point };
    work.binding.action = .insert;
    work.binding.identity.operation = 2;
    work.binding.expected_definition = created.resulting.interpretation;
    work.binding.intent = try work.digest(alloc);
    const row_admitted = try client.call(.{ .admit_rows = work });
    defer row_admitted.deinit();
    // The independent proxy corrupts the first successful execution reply.
    try t.expectError(error.InvalidTableResponse, execute(client, work.binding));
    const first = (try inspect(client, work.binding)).rows.committed;
    try t.expectEqual(@as(u64, 1), first.outcome.affected);
    const pinned = try client.call(.{ .pin = .{ .object = binding.target, .owner = .{ .scope = profile.catalog.scope, .principal = 101, .operation = 90 }, .expected = first.outcome.position } });
    defer pinned.deinit();
    const snapshot: w.Snapshot = .{ .object = binding.target, .handle = pinned.value.result.pin };
    work.binding.identity.operation = 3;
    work.binding.expected_data = first.outcome.position;
    work.changes = &.{.{ .insert = try binaryRow(alloc, 2, 3, "bulk") }};
    work.ingestion = .bulk;
    work.binding.intent = try work.digest(alloc);
    const bulk_admitted = try client.call(.{ .admit_rows = work });
    defer bulk_admitted.deinit();
    try t.expect(bulk_admitted.value.result.rows == .admitted);
    const second = (try execute(client, work.binding)).rows.committed;
    try t.expectEqual(@as(u64, 2), second.outcome.live_rows);
    profile.saved = .{ .create = binding, .insert = work.binding, .snapshot = snapshot, .first = first, .second = second };
}
fn recover(init: std.process.Init, client: c.DirectTableClient, admin: *Admin, profile: Profile) !void {
    const saved = profile.saved.?;
    try t.expectEqualDeep(saved.second, (try inspect(client, saved.insert)).rows.committed);
    try t.expectEqualDeep(saved.second, (try execute(client, saved.insert)).rows.committed);
    var reader = try c.DirectTableReader.open(init.gpa, client, saved.snapshot);
    defer reader.deinit();
    try t.expectEqual(@as(u64, 1), reader.basis.row_count);
    try t.expectEqualDeep(saved.first.outcome.position, reader.basis.accepted);
    var page = (try reader.next(client, .{})).?;
    defer page.deinit();
    try t.expect(page.complete);
    try t.expectEqual(@as(usize, 1), page.count);
    const value = page.rows[0].?.row().cells[1].value.atom.bytes;
    try t.expectEqual(@as(usize, 64 * 1024), value.len);
    for (value, 0..) |byte, i| try t.expectEqual(@as(u8, @truncate(i)), byte);
    try t.expect(try reader.next(client, .{}) == null);
    var foreign = client;
    foreign.connection.role = profile.role;
    try t.expectError(error.CatalogIdentityConflict, reader.check(foreign));
    const current = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer current.deinit();
    try t.expectEqual(@as(u64, 2), current.value.result.lookup.?.row_count);
    var empty_query = try q.DirectTableQuery.openRetained(init.gpa, client, saved.snapshot, "events", "SELECT id FROM events LIMIT 0", .{ .requests = 100, .rows = 10, .result_bytes = 1024 }, null, null, .{});
    defer empty_query.deinit();
    const native_table = (try admin.query(.{ .binding = .{ .domain = profile.catalog.authority.table_domain, .key = try c.TableAuthority.binding(profile.catalog.scope, .table, 7) } })).body.authorization.body.binding.?.reference.id;
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = 0 } });
    try t.expectError(error.AccessDenied, client.call(.{ .scan = .{ .snapshot = saved.snapshot, .after = null, .limits = .{} } }));
    try t.expectError(error.AccessDenied, reader.check(client));
    try t.expectError(error.AccessDenied, reader.next(client, .{}));
    try t.expectError(error.AccessDenied, empty_query.nextBatch(8));
    try t.expectError(error.AccessDenied, inspect(client, saved.insert));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = profile.role } });
    try reader.check(client);
    try reader.release(client);
    try reader.release(client);
    try t.expectError(error.TableSnapshotReleased, reader.check(client));
    try t.expectError(error.Conflict, c.DirectTableReader.open(init.gpa, client, saved.snapshot));
    try t.expectEqual(p.ErrorCode.QueryExpired, client.service.last_rejection.?);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        var encoder: std.json.Stringify = .{ .writer = &output.interface };
        try p.Json.write((try key(17)).public_key.toBytes(), &encoder);
        return output.interface.flush();
    }
    if (args.len != 4) return error.ExpectedUrlPhaseProfile;
    var native = wire.Client.init(init.gpa, init.io, args[1]);
    defer native.deinit();
    native.timeout_ms = 30000;
    var service = wire.Client.init(init.gpa, init.io, args[1]);
    defer service.deinit();
    service.timeout_ms = 30000;
    var admin: Admin = .{ .client = &native };
    if (std.mem.eql(u8, args[2], "provision")) {
        try save(init, args[3], try provision(&admin));
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.arena.allocator(), .limited(1024 * 1024));
        var profile = (try p.Json.parseFromSlice(Profile, init.arena.allocator(), bytes)).value;
        const client: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &native, .service = &service, .connection = .{ .scope = profile.catalog.scope, .branch = 1, .audience = profile.catalog.audience, .principal = 101, .role = null }, .key = try key(29) };
        if (std.mem.eql(u8, args[2], "write")) {
            try write(init, client, &profile);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "recover")) {
            try recover(init, client, &admin, profile);
            var lifecycle = try Lifecycle.evolve(init.gpa, client, profile.role);
            defer lifecycle.deinit();
            profile.lifecycle = lifecycle.value;
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "lifecycle")) try Lifecycle.verify(init.gpa, client, profile.lifecycle.?, true) else return error.UnknownProofPhase;
    }
    try output.interface.print("Direct Table {s}: passed\n", .{args[2]});
    try output.interface.flush();
}
