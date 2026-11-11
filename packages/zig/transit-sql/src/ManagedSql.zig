//! Managed computation syntax shared by SQL callers. Parsing admits no work.
const std = @import("std");
const g = @import("root.zig");
const f = g.fuze;
const Name = g.catalog.TableAuthority.Name;
pub const Statement = union(enum) {
    create: struct { name: Name, output: Name, sql: []const u8 },
    program: struct { name: Name, sql: []const u8 },
    control: struct { name: Name, command: g.catalog.protocol.Dataflow.Command, role: ?f.AuthorizationSql.Role = null },
};
pub const Prepared = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    pub fn deinit(self: *Prepared) void {
        self.arena.deinit();
    }
};
pub const Inspection = struct { name: Name, revision: ?u64 };
pub fn inspect(allocator: std.mem.Allocator, sql: []const u8, dialect: f.Sql.Dialect) !?Inspection {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var parser = try f.SqlTyped.initDialect(arena.allocator(), sql, null, false, dialect);
    if (!try parser.takeWord("SHOW") or !try parser.takeWord("DATAFLOW")) return null;
    const name = try Name.init(try parser.name());
    const revision: ?u64 = if (try parser.takeWord("REVISION")) blk: {
        if (parser.token.tag != .integer) return error.InvalidDataflowRevision;
        const value = std.fmt.parseInt(u64, parser.token.text, 10) catch return error.InvalidDataflowRevision;
        if (value == 0) return error.InvalidDataflowRevision;
        try parser.advance();
        break :blk value;
    } else null;
    try parser.finish();
    return .{ .name = name, .revision = revision };
}
pub fn parse(allocator: std.mem.Allocator, sql: []const u8, dialect: f.Sql.Dialect) !?Prepared {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const owned = try a.dupe(u8, sql);
    var parser = try f.SqlTyped.initDialect(a, owned, null, false, dialect);
    if (try parser.takeWord("CREATE")) {
        if (!try parser.takeWord("DATAFLOW")) {
            arena.deinit();
            return null;
        }
        const name = try Name.init(try parser.name());
        if (parser.word("FROM")) {
            var program = try f.ApplicationProgram.parse(a, owned, null);
            defer program.deinit();
            return .{ .arena = arena, .statement = .{ .program = .{ .name = name, .sql = owned } } };
        }
        if (!try parser.takeWord("INTO")) return error.InvalidSqlSyntax;
        const output = try Name.init(try parser.name());
        if (!try parser.takeWord("AS")) return error.InvalidSqlSyntax;
        const tail = owned[parser.lexer.start..];
        if (!try parser.takeWord("SELECT")) return error.UnsupportedManagedTable;
        return .{ .arena = arena, .statement = .{ .create = .{ .name = name, .output = output, .sql = tail } } };
    }
    const commands = .{ .{ "AUTHORIZE", .authorize }, .{ "ACTIVATE", .activate }, .{ "SUSPEND", .suspend_computation }, .{ "RESUME", .resume_computation }, .{ "REFRESH", .refresh }, .{ "RETIRE", .retire } };
    inline for (commands) |entry| {
        if (try parser.takeWord(entry[0])) {
            if (!try parser.takeWord("DATAFLOW")) return error.InvalidSqlSyntax;
            const name = try Name.init(try parser.name());
            const role = if (try parser.takeWord("AS")) selected: {
                if (entry[1] != .authorize) return error.InvalidDataflowTransition;
                try parser.requireWord("ROLE");
                break :selected try f.AuthorizationSql.role(&parser, false);
            } else null;
            try parser.finish();
            return .{ .arena = arena, .statement = .{ .control = .{ .name = name, .command = entry[1], .role = role } } };
        }
    }
    arena.deinit();
    return null;
}
test "managed SQL preserves names and query text and rejects trailing controls" {
    const t = std.testing;
    var create = (try parse(t.allocator, "CREATE DATAFLOW projection INTO output AS SELECT id FROM input", .transit)).?;
    defer create.deinit();
    try t.expectEqualStrings("projection", create.statement.create.name.slice());
    try t.expectEqualStrings("SELECT id FROM input", create.statement.create.sql);
    var control = (try parse(t.allocator, "SUSPEND DATAFLOW \"Case Name\";", .transit)).?;
    defer control.deinit();
    try t.expectEqualStrings("Case Name", control.statement.control.name.slice());
    try t.expectEqual(g.catalog.protocol.Dataflow.Command.suspend_computation, control.statement.control.command);
    try t.expectError(error.UnsupportedConstruct, parse(t.allocator, "ACTIVATE DATAFLOW item trailing", .transit));
    try t.expect(try parse(t.allocator, "CREATE TABLE input (id BIGINT)", .transit) == null);
}

test "lowered Queue programs retain the complete ordered body and explicit executor" {
    const t = std.testing;
    const sql = "CREATE DATAFLOW action FROM QUEUE requests AS request AS BEGIN BEGIN ATOMIC IF request.id > 0 THEN REQUIRE TRUE ELSE 'Denied'; END IF; END; END;";
    var program = (try parse(t.allocator, sql, .transit)).?;
    defer program.deinit();
    try t.expectEqualStrings(sql, program.statement.program.sql);
    try t.expectEqualStrings("action", program.statement.program.name.slice());
    var control = (try parse(t.allocator, "AUTHORIZE DATAFLOW action AS ROLE CURRENT_ROLE", .transit)).?;
    defer control.deinit();
    try t.expectEqual(.current_role, control.statement.control.role.?);
    try t.expectError(error.InvalidDataflowTransition, parse(t.allocator, "ACTIVATE DATAFLOW action AS ROLE writer", .transit));
    try t.expectError(error.MutationOutsideAtomic, parse(t.allocator, "CREATE DATAFLOW action FROM QUEUE requests AS request AS BEGIN INSERT INTO rows VALUES (request.id) ON CONFLICT (id) DO ASSERT SAME ROW; END;", .transit));
}
