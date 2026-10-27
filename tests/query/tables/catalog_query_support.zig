//! Independent direct Table storage and native captured-query progress fixtures.
const std = @import("std");
const q = @import("transit_query");
const s = @import("transit_station");
const c = q.catalog;
const p = s.protocol;
const Admin = @import("fixture_growing_support").Admin(46);
pub const authorization = @import("fixture_table_authorization_support");
pub const Profile = struct { definition: p.Growth.Definition, catalog: c.DirectCatalog.Configuration, owner: u64 };
pub fn key() !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(12));
}
pub fn provision(admin: *Admin) !Profile {
    const pid = try admin.submit(.{ .spawn = .{} });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
    const owner_role = try authorization.login(c, admin, "query-catalog-owner", 42, try key(), null);
    const scope: p.DataLifecycle.Scope = .{ .realm = 46, .resource = resource, .catalog = 1 };
    return .{ .definition = p.Growth.current_definition, .owner = owner_role, .catalog = .{
        .scope = scope,
        .branch = 1,
        .partition = 1,
        .audience = 100,
        .authority = try authorization.profile(c, admin, scope, 0, owner_role),
        .database_name = try .init("transit"),
        .initial_schema_name = try .init("public"),
    } };
}
pub fn configuration(init: std.process.Init, directory: []const u8) !Profile {
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/catalog-profile.json", .{directory});
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(16384));
    const parsed = try std.json.parseFromSlice(Profile, init.arena.allocator(), bytes, .{});
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return parsed.value;
}
pub fn grant(admin: *Admin, config: Profile) !void {
    const reader = try authorization.loginRole(c, admin.wire, 46, 1234, try p.Ed25519.KeyPair.generateDeterministic(@splat(10)));
    try authorization.grantDefaults(c, admin, config.catalog.authority, config.owner, reader, c.TableAuthority.table_actions);
    try authorization.grantDefaults(c, admin, config.catalog.authority, reader, config.owner, c.TableAuthority.table_actions);
    _ = try admin.authorization(.{ .grant = .{ .object = c.TableAuthority.reference(config.catalog.authority.initial_schema_authority), .grantee = reader, .privileges = c.TableAuthority.create } });
}
pub fn caller(allocator: std.mem.Allocator, wire: *s.client.Client, config: Profile) !c.DirectTableClient {
    return .{ .allocator = allocator, .authority = wire, .service = wire, .connection = .{ .scope = config.catalog.scope, .branch = config.catalog.branch, .audience = config.catalog.audience, .principal = 42, .role = config.owner }, .key = try key() };
}
pub fn owner(init: std.process.Init, wire: *s.client.Client, config: Profile, peer: u64) !*q.UnifiedBehavior.Source {
    const allocator = init.arena.allocator();
    const cancellation = try allocator.create(q.fuze.execution.Cancellation);
    cancellation.* = .init(false);
    const result = try allocator.create(q.UnifiedBehavior.Source);
    var tables = try caller(init.gpa, wire, config);
    tables.connection.principal = 65536;
    tables.connection.role = null;
    tables.key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    result.* = .{ .peer = peer, .initializer = 42, .tables = tables, .resources = .{ .wire = wire, .realm = 46, .principal = 65536, .key = tables.key }, .adapter = try allocator.alloc(u8, q.UnifiedBehavior.adapter_bytes), .workspace = try allocator.alloc(u8, q.fuze.LogicalArrow.working_bytes), .cancellation = cancellation };
    return result;
}
pub fn drive(init: std.process.Init, server: *s.GenServer, handler: s.GenServer.Handler) !void {
    const started = std.Io.Clock.awake.now(init.io);
    var steps: usize = 0;
    while (steps < 20) {
        const step = server.step(handler, @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 30000) catch |err| {
            if (!s.client.Client.unavailable(err) or started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= 10000) return err;
            if (server.pending == null and server.ready != null) try server.discard();
            try init.io.sleep(.fromMilliseconds(25), .awake);
            continue;
        };
        steps += 1;
        switch (step) {
            .committed => return,
            .blocked => return server.handler_error orelse error.Blocked,
            .idle => return error.NoInput,
            .progress => {},
        }
    }
    return error.StepBudgetExceeded;
}
pub fn execute(client: c.DirectTableClient, intent: *const c.DirectTableIntent) !void {
    const admitted = try intent.admit(client);
    admitted.deinit();
    for (0..128) |_| {
        const response = try intent.operation(client, .execute, 32);
        defer response.deinit();
        switch (response.value.result) {
            .ddl => |result| switch (result) {
                .committed => return,
                .admitted => {},
                else => return error.CatalogSeedRejected,
            },
            .rows => |result| switch (result) {
                .committed => return,
                .admitted => {},
                else => return error.CatalogSeedRejected,
            },
            else => return error.InvalidTableResponse,
        }
    }
    return error.CatalogSeedBudgetExceeded;
}
pub fn initialize(init: std.process.Init, client: c.DirectTableClient, rows: usize) !q.SourceDefinition {
    const initialized = try client.call(.initialize);
    initialized.deinit();
    var prepared = try c.DirectTablePreparedDdl.prepare(init.gpa, client, 1, "CREATE TABLE items (id INT64 PRIMARY KEY, value UTF8)", .transit, null);
    defer prepared.deinit();
    var ddl = try prepared.bind(init.gpa, client, 1, 1);
    defer ddl.deinit();
    if (ddl != .table) return error.CatalogSeedRejected;
    try execute(client, &ddl.table);
    var bytes: [4096]u8 = undefined;
    for (0..(rows + 15) / 16) |batch| {
        var sql: std.Io.Writer = .fixed(&bytes);
        try sql.writeAll("INSERT INTO items (id,value) VALUES ");
        const start = batch * 16;
        for (start..@min(start + 16, rows)) |i| {
            if (i != start) try sql.writeByte(',');
            try sql.print("({d},'東京🙂/{s}/{d:0>2}')", .{ i, @as([128]u8, @splat('x')), i });
        }
        var dml = try c.DirectTablePreparedDml.prepare(init.gpa, client, 1, sql.buffered(), .transit, null);
        defer dml.deinit();
        var intent = try dml.bind(init.gpa, client, batch + 2, &.{}, .point, null);
        defer intent.deinit();
        try execute(client, &intent);
    }
    const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = "items" } });
    defer found.deinit();
    const source = try q.TableSource.from(init.arena.allocator(), client.connection, found.value.result.lookup orelse return error.MissingSeededTable);
    return .{ .resource = client.connection.scope.resource, .source = .{ .table = source.source } };
}
pub fn send(wire: *s.client.Client, pid: u64, payload: p.Value) !p.Receipt {
    const identity = try key();
    const current = try wire.query(.{ .realm = 46, .principal = 42, .kind = .capabilities }, identity);
    return wire.submit(try p.Growth.sign(.{ .realm = 46, .principal = 42, .sequence = current.principal_sequence + 1, .command = .{ .send = .{ .pid = pid, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, identity));
}
pub fn delegate(wire: *s.client.Client, config: Profile, source: u64, peer: u64, requests: u64, limits: q.Bundle.Limits, revision: u64) !p.Receipt {
    return send(wire, source, try (q.UnifiedBehavior.PolicyChange{ .expected_revision = revision - 1, .policy = .{ .peer = peer, .requests = requests, .revision = revision, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = config.catalog.scope, .owner = config.catalog.audience, .principal = 1234 } } } }).encode());
}
