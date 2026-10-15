//! Catalog Table provisioning through production handlers and signed public calls.
const std = @import("std");
const q = @import("transit_query");
const s = @import("transit_station");
const c = q.catalog;
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(46);
pub const authorization = @import("table_authorization_support.zig");
pub fn key() !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(12));
}
pub fn provision(admin: *Admin, resource: u64, owner_pid: u64) !c.TableCatalogRecords.Configuration {
    const owner_role = try authorization.login(c, admin, "query-catalog-owner", 42, try key(), owner_pid);
    const scope: c.Model.Scope = .{ .realm = 46, .resource = resource, .catalog = 1 };
    const authority = try authorization.profile(c, admin, scope, 65536, owner_role);
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 42, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    return .{ .scope = scope, .owner = owner_pid, .administrator = 42, .authority = authority, .database_name = try .init("transit"), .table_limits = .{ .record_bytes = q.fuze.TableRow.max_bytes, .staging_bytes = 2 * q.fuze.TableRow.max_bytes, .staging_records = 2 } };
}
pub fn configuration(wire: *s.client.Client, resource: u64, owner_pid: u64) !c.TableCatalogRecords.Configuration {
    var source = try (s.client.ResourceReader{ .wire = wire, .realm = 46, .principal = 42, .key = try key() }).open(resource);
    const value = try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', (try source.read(c.Records.key(1, 'c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (value.scope.realm != 46 or value.scope.resource != resource or value.scope.catalog != 1 or value.owner != owner_pid) return error.CatalogConfigurationChanged;
    return value;
}
pub fn grant(admin: *Admin, config: c.TableCatalogRecords.Configuration) !void {
    const database = (try admin.query(.{ .authorization = .{ .kind = .{ .object = c.TableAuthority.reference(config.authority.database) } } })).body.authorization.body.object;
    const reader = try authorization.loginRole(c, admin.wire, 46, 1234, try p.Ed25519.KeyPair.generateDeterministic(@splat(10)));
    try authorization.grantDefaults(c, admin, config.authority, database.owner, reader, c.TableAuthority.table_actions);
    try authorization.grantDefaults(c, admin, config.authority, reader, database.owner, c.TableAuthority.table_actions);
    _ = try admin.authorization(.{ .grant = .{ .object = c.TableAuthority.reference(config.authority.initial_schema_authority), .grantee = reader, .privileges = c.TableAuthority.create } });
}
pub fn owner(init: std.process.Init, wire: *s.client.Client, config: c.TableCatalogRecords.Configuration) !*q.CatalogQueryOwner {
    const allocator = init.arena.allocator();
    const cancellation = try allocator.create(q.fuze.execution.Cancellation);
    cancellation.* = .init(false);
    const result = try allocator.create(q.CatalogQueryOwner);
    result.* = .{ .tables = .{ .allocator = init.gpa, .configuration = config }, .resources = .{ .wire = wire, .realm = 46, .principal = 65536, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, .adapter = try allocator.alloc(u8, 1024 * 1024), .workspace = try allocator.alloc(u8, q.fuze.LogicalArrow.working_bytes), .cancellation = cancellation };
    return result;
}
pub fn caller(wire: *s.client.Client, config: c.TableCatalogRecords.Configuration) !c.TableClient {
    return .{ .transport = wire, .connection = .{ .scope = config.scope, .owner = config.owner, .principal = config.administrator }, .key = try key() };
}
pub fn drive(init: std.process.Init, server: *s.GenServer, handler: s.GenServer.Handler) !void {
    return driveRegistered(init, server, handler, null);
}
pub fn driveCatalog(init: std.process.Init, server: *s.GenServer, behavior: *q.CatalogQueryOwner) !void {
    return driveRegistered(init, server, behavior.interface(), &behavior.tables);
}
fn driveRegistered(init: std.process.Init, server: *s.GenServer, handler: s.GenServer.Handler, tables: ?*c.TableBehavior) !void {
    const started = std.Io.Clock.awake.now(init.io);
    var steps: usize = 0;
    while (steps < 20) {
        const step = server.step(handler, @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 30000) catch |err| {
            if (err == error.CatalogRegistrationRequired and tables != null) {
                try authorization.registration(c, tables.?, server);
                continue;
            }
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
pub fn statement(init: std.process.Init, admin: *Admin, server: *s.GenServer, behavior: *q.CatalogQueryOwner, client: *c.TableClient, text: []const u8, operation: u64, object: ?u64) !void {
    var intent = try client.compile(init.gpa, text, .{ .operation = operation, .namespace = operation, .create_object = object }, null);
    defer intent.deinit();
    for (0..4096) |_| {
        switch (try client.next(&intent)) {
            .send => |prepared| _ = try client.submit(prepared),
            .running => {
                const delivery = (try admin.query(.delivery)).body.delivery.next orelse return error.MissingCatalogContinuation;
                _ = try admin.submit(.{ .deliver = delivery });
            },
            .terminal => |result| {
                switch (result) {
                    .ddl => |value| if (value.operation.state != .applied) return error.CatalogSeedRejected,
                    .dml => |value| if (value.state != .applied) return error.CatalogSeedRejected,
                }
                return;
            },
            .upload_cancelled => return error.CatalogSeedCancelled,
        }
        try driveCatalog(init, server, behavior);
    }
    return error.CatalogSeedBudgetExceeded;
}
pub fn initialize(init: std.process.Init, admin: *Admin, server: *s.GenServer, behavior: *q.CatalogQueryOwner, client: *c.TableClient, config: c.TableCatalogRecords.Configuration, rows: usize) !q.SourceDefinition {
    _ = try client.submit(try client.prepareControl(.{ .initialize = config }));
    try driveCatalog(init, server, behavior);
    try statement(init, admin, server, behavior, client, "CREATE TABLE items (id INT64 PRIMARY KEY, value UTF8)", 1, 1);
    var bytes: [4096]u8 = undefined;
    for (0..(rows + 15) / 16) |batch| {
        var sql: std.Io.Writer = .fixed(&bytes);
        try sql.writeAll("INSERT INTO items (id,value) VALUES ");
        const start = batch * 16;
        for (start..@min(start + 16, rows)) |i| {
            if (i != start) try sql.writeByte(',');
            try sql.print("({d},'東京🙂/{s}/{d:0>2}')", .{ i, @as([128]u8, @splat('x')), i });
        }
        try statement(init, admin, server, behavior, client, sql.buffered(), batch + 2, null);
    }
    var found = (try client.lookup(init.gpa, try c.TableMetadata.Name.init("items"))) orelse return error.MissingSeededTable;
    defer found.deinit();
    // The source's borrowed descriptor belongs to the fixture process arena.
    const source = try q.TableSource.from(init.arena.allocator(), config, found);
    return .{ .resource = config.scope.resource, .source = .{ .table = source.source } };
}
pub fn send(wire: *s.client.Client, pid: u64, payload: p.Value) !p.Receipt {
    const identity = try key();
    const current = try wire.query(.{ .realm = 46, .principal = 42, .kind = .capabilities }, identity);
    return wire.submit(try p.Growth.sign(.{ .realm = 46, .principal = 42, .sequence = current.principal_sequence + 1, .command = .{ .send = .{ .pid = pid, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, identity));
}
pub fn delegate(wire: *s.client.Client, config: c.TableCatalogRecords.Configuration, peer: u64, requests: u64, limits: q.Bundle.Limits, revision: u64) !p.Receipt {
    return send(wire, config.owner, try (q.CatalogQueryOwner.PolicyChange{ .expected_revision = revision - 1, .policy = .{ .peer = peer, .requests = requests, .revision = revision, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = config.scope, .owner = config.owner, .principal = 1234 } } } }).encode());
}
