//! Selected SQL authorization syntax. Names remain unresolved; Catalog/native
//! authority own identity, permission, preview and publication. No I/O here.
const std = @import("std");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
pub const max_name_bytes = 63;
pub const Kind = enum { database, schema, table };
pub const Name = struct { schema: ?[]const u8 = null, name: []const u8 };
pub const Object = struct { kind: Kind, name: Name };
pub const Role = union(enum) { named: []const u8, public, current_role, session_user };
pub const Behavior = enum { restrict, cascade };
pub const Option = enum { admin, inherit, set };
pub const Privilege = enum(u3) { connect, usage, create, select, insert, update, delete };
pub fn bit(value: Privilege) u8 {
    return @as(u8, 1) << @backingInt(value);
}
pub fn available(kind: Kind) u8 {
    return switch (kind) {
        .database => bit(.connect),
        .schema => bit(.usage) | bit(.create),
        .table => bit(.select) | bit(.insert) | bit(.update) | bit(.delete),
    };
}
pub const Privileges = struct {
    all: bool = false,
    mask: u8 = 0,
    pub fn forKind(self: Privileges, kind: Kind) !u8 {
        if (self.all) return available(kind);
        if (self.mask == 0 or self.mask & ~available(kind) != 0) return error.InvalidSqlPrivilege;
        return self.mask;
    }
};
pub const Grant = struct { object: Object, privileges: Privileges, grantee: Role, grant_option: bool = false };
pub const Revoke = struct { grant: Grant, option_only: bool = false, behavior: Behavior = .restrict };
pub const Membership = struct { role: []const u8, member: Role, admin: ?bool = null, inherit: ?bool = null, set: ?bool = null };
pub const RoleOptions = struct { login: ?bool = null, create_role: ?bool = null };
pub const Defaults = struct { creator: Role = .current_role, schema: []const u8, privileges: Privileges, grantee: Role, grant_option: bool = false };
pub const Statement = union(enum) {
    create_role: struct { name: []const u8, options: RoleOptions },
    alter_role: struct { name: []const u8, options: RoleOptions },
    rename_role: struct { name: []const u8, to: []const u8 },
    drop_role: []const u8,
    membership: Membership,
    revoke_membership: struct { role: []const u8, member: Role, option: ?Option = null, behavior: Behavior = .restrict },
    grant: Grant,
    revoke: Revoke,
    default_grant: Defaults,
    default_revoke: struct { defaults: Defaults, option_only: bool, behavior: Behavior },
    create_schema: struct { name: []const u8, owner: Role = .current_role },
    rename_schema: struct { name: []const u8, to: []const u8 },
    drop_schema: []const u8,
    transfer: struct { object: Object, owner: Role },
    set_role: ?[]const u8,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn compile(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.init(arena.allocator(), text, location);
    const statement = try parse(&parser);
    try parser.finish();
    return .{ .arena = arena, .statement = statement };
}
fn name(parser: *Parser) ![]const u8 {
    const value = try parser.name();
    if (value.len > max_name_bytes) return error.InvalidSqlAuthorizationName;
    return value;
}
fn qualified(parser: *Parser, kind: Kind) !Name {
    const first = try name(parser);
    if (kind == .table and try parser.take(.dot)) return .{ .schema = first, .name = try name(parser) };
    return .{ .name = first };
}
fn role(parser: *Parser, public: bool) !Role {
    if (try parser.takeWord("PUBLIC")) return if (public) .public else error.InvalidSqlRole;
    if (try parser.takeWord("CURRENT_ROLE") or try parser.takeWord("CURRENT_USER")) return .current_role;
    if (try parser.takeWord("SESSION_USER")) return .session_user;
    return .{ .named = try name(parser) };
}
fn objectKind(parser: *Parser) !Kind {
    if (try parser.takeWord("DATABASE")) return .database;
    if (try parser.takeWord("SCHEMA")) return .schema;
    _ = try parser.takeWord("TABLE");
    return .table;
}
fn privilegeStart(parser: *Parser) bool {
    if (parser.word("ALL")) return true;
    inline for (std.enums.values(Privilege)) |value| if (parser.word(@tagName(value))) return true;
    return false;
}
fn privileges(parser: *Parser) !Privileges {
    if (try parser.takeWord("ALL")) {
        _ = try parser.takeWord("PRIVILEGES");
        return .{ .all = true };
    }
    var result: Privileges = .{};
    while (true) {
        const selected: Privilege = find: {
            inline for (std.enums.values(Privilege)) |value| if (try parser.takeWord(@tagName(value))) break :find value;
            return error.InvalidSqlPrivilege;
        };
        if (result.mask & bit(selected) != 0) return error.DuplicateSqlPrivilege;
        result.mask |= bit(selected);
        if (!try parser.take(.comma)) break;
    }
    return result;
}
fn grantOption(parser: *Parser, grantee: Role) !bool {
    if (!try parser.takeWord("WITH")) return false;
    try parser.requireWord("GRANT");
    try parser.requireWord("OPTION");
    if (grantee == .public) return error.InvalidSqlPrivilege;
    return true;
}
fn behavior(parser: *Parser) !Behavior {
    if (try parser.takeWord("CASCADE")) return .cascade;
    _ = try parser.takeWord("RESTRICT");
    return .restrict;
}
fn boolean(parser: *Parser) !bool {
    if (try parser.takeWord("TRUE") or try parser.takeWord("OPTION")) return true;
    try parser.requireWord("FALSE");
    return false;
}
fn membership(parser: *Parser, granted: []const u8) !Statement {
    try parser.requireWord("TO");
    var result: Membership = .{ .role = granted, .member = try role(parser, false) };
    if (try parser.takeWord("WITH")) while (true) {
        const option: Option = if (try parser.takeWord("ADMIN")) .admin else if (try parser.takeWord("INHERIT")) .inherit else if (try parser.takeWord("SET")) .set else return error.UnsupportedAuthorizationSql;
        const selected = try boolean(parser);
        switch (option) {
            inline else => |value| {
                const field = &@field(result, @tagName(value));
                if (field.* != null) return error.DuplicateRoleOption;
                field.* = selected;
            },
        }
        if (!try parser.take(.comma)) break;
    };
    return .{ .membership = result };
}
fn grant(parser: *Parser) !Statement {
    if (!privilegeStart(parser)) return membership(parser, try name(parser));
    const rights = try privileges(parser);
    try parser.requireWord("ON");
    const target_kind = try objectKind(parser);
    _ = try rights.forKind(target_kind);
    const target: Object = .{ .kind = target_kind, .name = try qualified(parser, target_kind) };
    try parser.requireWord("TO");
    const grantee = try role(parser, true);
    return .{ .grant = .{ .object = target, .privileges = rights, .grantee = grantee, .grant_option = try grantOption(parser, grantee) } };
}
fn revoke(parser: *Parser) !Statement {
    var option_only = false;
    var member_option: ?Option = null;
    if (try parser.takeWord("GRANT")) {
        try parser.requireWord("OPTION");
        try parser.requireWord("FOR");
        option_only = true;
    } else {
        for (std.enums.values(Option)) |option| {
            if (try parser.takeWord(@tagName(option))) {
                try parser.requireWord("OPTION");
                try parser.requireWord("FOR");
                member_option = option;
                break;
            }
        }
    }
    if (member_option != null or !privilegeStart(parser)) {
        if (option_only) return error.InvalidSqlPrivilege;
        const granted = try name(parser);
        try parser.requireWord("FROM");
        const member = try role(parser, false);
        return .{ .revoke_membership = .{ .role = granted, .member = member, .option = member_option, .behavior = try behavior(parser) } };
    }
    const rights = try privileges(parser);
    try parser.requireWord("ON");
    const target_kind = try objectKind(parser);
    _ = try rights.forKind(target_kind);
    const target: Object = .{ .kind = target_kind, .name = try qualified(parser, target_kind) };
    try parser.requireWord("FROM");
    const grantee = try role(parser, true);
    if (grantee == .public and option_only) return error.InvalidSqlPrivilege;
    return .{ .revoke = .{ .grant = .{ .object = target, .privileges = rights, .grantee = grantee }, .option_only = option_only, .behavior = try behavior(parser) } };
}
fn options(parser: *Parser, require: bool) !RoleOptions {
    const with = try parser.takeWord("WITH");
    var result: RoleOptions = .{};
    var count: u8 = 0;
    while (true) {
        if (parser.word("LOGIN") or parser.word("NOLOGIN")) {
            if (result.login != null) return error.DuplicateRoleOption;
            result.login = try parser.takeWord("LOGIN");
            if (!result.login.?) try parser.requireWord("NOLOGIN");
        } else if (parser.word("CREATEROLE") or parser.word("NOCREATEROLE")) {
            if (result.create_role != null) return error.DuplicateRoleOption;
            result.create_role = try parser.takeWord("CREATEROLE");
            if (!result.create_role.?) try parser.requireWord("NOCREATEROLE");
        } else break;
        count += 1;
    }
    if ((require or with) and count == 0) return error.UnsupportedAuthorizationSql;
    return result;
}
fn defaults(parser: *Parser) !Statement {
    try parser.requireWord("PRIVILEGES");
    var creator: Role = .current_role;
    if (try parser.takeWord("FOR")) {
        try parser.requireWord("ROLE");
        creator = try role(parser, false);
    }
    try parser.requireWord("IN");
    try parser.requireWord("SCHEMA");
    const namespace = try name(parser);
    const is_grant = try parser.takeWord("GRANT");
    var option_only = false;
    if (!is_grant) {
        try parser.requireWord("REVOKE");
        if (try parser.takeWord("GRANT")) {
            try parser.requireWord("OPTION");
            try parser.requireWord("FOR");
            option_only = true;
        }
    }
    const rights = try privileges(parser);
    _ = try rights.forKind(.table);
    try parser.requireWord("ON");
    try parser.requireWord("TABLES");
    try parser.requireWord(if (is_grant) "TO" else "FROM");
    const grantee = try role(parser, true);
    const value: Defaults = .{ .creator = creator, .schema = namespace, .privileges = rights, .grantee = grantee, .grant_option = if (is_grant) try grantOption(parser, grantee) else false };
    if (grantee == .public and option_only) return error.InvalidSqlPrivilege;
    return if (is_grant) .{ .default_grant = value } else .{ .default_revoke = .{ .defaults = value, .option_only = option_only, .behavior = try behavior(parser) } };
}
fn parse(parser: *Parser) !Statement {
    if (try parser.takeWord("GRANT")) return grant(parser);
    if (try parser.takeWord("REVOKE")) return revoke(parser);
    if (try parser.takeWord("SET")) {
        try parser.requireWord("ROLE");
        return .{ .set_role = if (try parser.takeWord("NONE")) null else try name(parser) };
    }
    if (try parser.takeWord("RESET")) {
        try parser.requireWord("ROLE");
        return .{ .set_role = null };
    }
    if (try parser.takeWord("CREATE")) {
        if (try parser.takeWord("ROLE")) {
            const who = try name(parser);
            return .{ .create_role = .{ .name = who, .options = try options(parser, false) } };
        }
        try parser.requireWord("SCHEMA");
        const namespace = try name(parser);
        return .{ .create_schema = .{ .name = namespace, .owner = if (try parser.takeWord("AUTHORIZATION")) try role(parser, false) else .current_role } };
    }
    if (try parser.takeWord("DROP")) {
        if (try parser.takeWord("ROLE")) return .{ .drop_role = try name(parser) };
        try parser.requireWord("SCHEMA");
        const namespace = try name(parser);
        _ = try parser.takeWord("RESTRICT");
        return .{ .drop_schema = namespace };
    }
    if (try parser.takeWord("ALTER")) {
        if (try parser.takeWord("DEFAULT")) return defaults(parser);
        if (try parser.takeWord("ROLE")) {
            const who = try name(parser);
            if (try parser.takeWord("RENAME")) {
                try parser.requireWord("TO");
                return .{ .rename_role = .{ .name = who, .to = try name(parser) } };
            }
            return .{ .alter_role = .{ .name = who, .options = try options(parser, true) } };
        }
        if (!parser.word("DATABASE") and !parser.word("SCHEMA") and !parser.word("TABLE")) return error.UnsupportedAuthorizationSql;
        const target_kind = try objectKind(parser);
        const target: Object = .{ .kind = target_kind, .name = try qualified(parser, target_kind) };
        if (target_kind == .schema and try parser.takeWord("RENAME")) {
            try parser.requireWord("TO");
            return .{ .rename_schema = .{ .name = target.name.name, .to = try name(parser) } };
        }
        try parser.requireWord("OWNER");
        try parser.requireWord("TO");
        return .{ .transfer = .{ .object = target, .owner = try role(parser, false) } };
    }
    return error.UnsupportedAuthorizationSql;
}

test "authorization syntax owns names and distinguishes object privileges from membership options" {
    const t = std.testing;
    var object = try compile(t.allocator, "GRANT SELECT, UPDATE ON TABLE \"Data\".items TO reader WITH GRANT OPTION;", null);
    defer object.deinit();
    try t.expectEqualStrings("Data", object.statement.grant.object.name.schema.?);
    try t.expectEqualStrings("items", object.statement.grant.object.name.name);
    try t.expectEqual(bit(.select) | bit(.update), try object.statement.grant.privileges.forKind(.table));
    try t.expect(object.statement.grant.grant_option);
    var member = try compile(t.allocator, "GRANT writer TO analyst WITH ADMIN OPTION, INHERIT FALSE, SET TRUE", null);
    defer member.deinit();
    try t.expectEqual(@as(?bool, true), member.statement.membership.admin);
    try t.expectEqual(@as(?bool, false), member.statement.membership.inherit);
    try t.expectEqual(@as(?bool, true), member.statement.membership.set);
    var revoke_member = try compile(t.allocator, "REVOKE INHERIT OPTION FOR writer FROM analyst CASCADE", null);
    defer revoke_member.deinit();
    try t.expectEqual(@as(?Option, .inherit), revoke_member.statement.revoke_membership.option);
    try t.expectEqual(.cascade, revoke_member.statement.revoke_membership.behavior);
    var revoke_object = try compile(t.allocator, "REVOKE GRANT OPTION FOR SELECT ON items FROM analyst RESTRICT", null);
    defer revoke_object.deinit();
    try t.expect(revoke_object.statement.revoke.option_only);
    var future = try compile(t.allocator, "ALTER DEFAULT PRIVILEGES FOR ROLE writer IN SCHEMA app GRANT ALL PRIVILEGES ON TABLES TO reader", null);
    defer future.deinit();
    try t.expectEqualStrings("writer", future.statement.default_grant.creator.named);
    try t.expect(future.statement.default_grant.privileges.all);
}
fn parseOwned(allocator: std.mem.Allocator, text: []const u8) !void {
    var result = try compile(allocator, text, null);
    defer result.deinit();
}
test "role and namespace statements require complete bounded supported forms" {
    const t = std.testing;
    for ([_][]const u8{
        "CREATE ROLE reader WITH LOGIN NOCREATEROLE",  "CREATE ROLE group_role",                                                                              "ALTER ROLE reader NOLOGIN",
        "ALTER ROLE reader RENAME TO renamed",         "DROP ROLE reader",                                                                                    "CREATE SCHEMA app AUTHORIZATION owner_role",
        "ALTER SCHEMA app RENAME TO renamed",          "ALTER SCHEMA app OWNER TO owner_role",                                                                "DROP SCHEMA app RESTRICT",
        "ALTER TABLE app.items OWNER TO owner_role",   "ALTER DATABASE transit OWNER TO owner_role",                                                          "SET ROLE writer",
        "SET ROLE NONE",                               "RESET ROLE",                                                                                          "GRANT CONNECT ON DATABASE transit TO PUBLIC",
        "GRANT USAGE, CREATE ON SCHEMA app TO writer", "ALTER DEFAULT PRIVILEGES IN SCHEMA app REVOKE GRANT OPTION FOR SELECT ON TABLES FROM reader CASCADE",
    }) |text| {
        try parseOwned(t.allocator, text);
        try t.checkAllAllocationFailures(t.allocator, parseOwned, .{text});
    }
    for ([_][]const u8{
        "GRANT CONNECT ON TABLE items TO reader",                    "GRANT SELECT ON SCHEMA app TO reader",                "GRANT SELECT, SELECT ON items TO reader",
        "GRANT SELECT ON items TO PUBLIC WITH GRANT OPTION",         "GRANT writer TO PUBLIC",                              "CREATE ROLE reader PASSWORD 'secret'",
        "CREATE ROLE reader LOGIN NOLOGIN",                          "CREATE ROLE reader WITH",                             "ALTER ROLE reader",
        "CREATE ROLE reader SUPERUSER",                              "GRANT writer TO reader WITH ADMIN TRUE, ADMIN FALSE", "GRANT SELECT ON items TO a, b",
        "GRANT SELECT ON a, b TO reader",                            "DROP SCHEMA app CASCADE",                             "DROP ROLE reader CASCADE",
        "ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO reader", "GRANT TRUNCATE ON items TO reader",                   "GRANT SELECT (id) ON items TO reader",
        "SET ROLE writer; DROP ROLE other_role",                     "ALTER items OWNER TO reader",
    }) |text| {
        if (compile(t.allocator, text, null)) |result| {
            var unexpected = result;
            unexpected.deinit();
            std.debug.print("unexpected authorization SQL: {s}\n", .{text});
            return error.AcceptedUnsupportedAuthorizationSql;
        } else |_| {}
    }
}
