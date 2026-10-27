//! Direct catalog setup shared by the public query and Flight executable proofs.
//! All declarations and data use the public owner; query workers own progress only.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const p = q.protocol;
const authorization = @import("fixture_table_authorization_support");

pub const Profile = struct {
    definition: p.Growth.Definition,
    catalog: c.DirectCatalog.Configuration,
    owner: u64,
};

pub fn bootstrap(admin: anytype) !Profile {
    const pid = try admin.submit(.{ .spawn = .{} });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
    const owner = try authorization.login(c, admin, "catalog-owner", 42, try p.Ed25519.KeyPair.generateDeterministic(@splat(14)), null);
    const scope: p.DataLifecycle.Scope = .{ .realm = 45, .resource = resource, .catalog = 1 };
    return .{ .definition = p.Growth.current_definition, .owner = owner, .catalog = .{
        .scope = scope,
        .branch = 1,
        .partition = 1,
        .audience = 100,
        .authority = try authorization.profile(c, admin, scope, 0, owner),
        .database_name = try .init("transit"),
        .initial_schema_name = try .init("public"),
    } };
}

pub fn load(init: std.process.Init, directory: []const u8) !Profile {
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/catalog-profile.json", .{directory});
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(16384));
    const parsed = try std.json.parseFromSlice(Profile, init.arena.allocator(), bytes, .{});
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return parsed.value;
}

pub fn client(allocator: std.mem.Allocator, wire: *q.wire.Client, profile: Profile) !c.DirectTableClient {
    return .{ .allocator = allocator, .authority = wire, .service = wire, .connection = .{ .scope = profile.catalog.scope, .branch = profile.catalog.branch, .audience = profile.catalog.audience, .principal = 42, .role = profile.owner }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(14)) };
}

fn execute(caller: c.DirectTableClient, intent: *const c.DirectTableIntent) !void {
    const admission = try intent.admit(caller);
    defer admission.deinit();
    for (0..32) |_| {
        const response = try intent.operation(caller, .execute, 32);
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

pub fn seed(allocator: std.mem.Allocator, caller: c.DirectTableClient, object: u64, name: []const u8, overflow: bool) !void {
    const create = try std.fmt.allocPrint(allocator, "CREATE TABLE {s} (id INT64 PRIMARY KEY, value INT64)", .{name});
    defer allocator.free(create);
    var prepared = try c.DirectTablePreparedDdl.prepare(allocator, caller, 1, create, .transit, null);
    defer prepared.deinit();
    var ddl = try prepared.bind(allocator, caller, object * 2 - 1, object);
    defer ddl.deinit();
    if (ddl != .table) return error.CatalogSeedRejected;
    try execute(caller, &ddl.table);
    var bytes: [4096]u8 = undefined;
    var sql: std.Io.Writer = .fixed(&bytes);
    try sql.print("INSERT INTO {s} (id, value) VALUES ", .{name});
    for (0..41) |i| {
        if (i != 0) try sql.writeAll(", ");
        try sql.print("({d}, ", .{i});
        if (i % 5 == 0) try sql.writeAll("NULL") else try sql.print("{d}", .{if (overflow and i == 1) std.math.maxInt(i64) else @as(i64, @intCast(9007199254740993 + i))});
        try sql.writeByte(')');
    }
    var dml = try c.DirectTablePreparedDml.prepare(allocator, caller, 1, sql.buffered(), .transit, null);
    defer dml.deinit();
    var rows = try dml.bind(allocator, caller, object * 2, &.{}, .point, null);
    defer rows.deinit();
    try execute(caller, &rows);
}

pub fn mutate(allocator: std.mem.Allocator, caller: c.DirectTableClient, restore: bool) !void {
    var prepared = try c.DirectTablePreparedDml.prepare(allocator, caller, 1, if (restore) "UPDATE items SET value = 9007199254740994 WHERE id = 1" else "UPDATE items SET value = 42 WHERE id = 1", .transit, null);
    defer prepared.deinit();
    var intent = try prepared.bind(allocator, caller, if (restore) 1001 else 1000, &.{}, .point, null);
    defer intent.deinit();
    try execute(caller, &intent);
}
