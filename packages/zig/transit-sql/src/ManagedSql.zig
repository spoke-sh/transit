//! Managed computation syntax shared by SQL callers. Parsing admits no work.
const std = @import("std");
const g = @import("root.zig");
const f = g.fuze;
const Name = g.catalog.TableAuthority.Name;
pub const Statement = union(enum) {
    create: struct { name: Name, output: Name, sql: []const u8 },
    control: struct { name: Name, command: g.catalog.protocol.Dataflow.Command },
};
pub const Prepared = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    pub fn deinit(self: *Prepared) void {
        self.arena.deinit();
    }
};
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
            try parser.finish();
            return .{ .arena = arena, .statement = .{ .control = .{ .name = name, .command = entry[1] } } };
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
