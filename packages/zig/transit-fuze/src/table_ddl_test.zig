const std = @import("std");
const e = std.testing;
const ddl = @import("TableDdl.zig");
const s = @import("TableSchema.zig");
test "MySQL DDL uses shared quoted names and literal backslashes without statement rewriting" {
    var owned = try ddl.compileDialect(e.allocator, "CREATE TABLE `people``archive` (`id` BIGINT PRIMARY KEY, `path` TEXT DEFAULT 'a\\b')", null, null, .mysql);
    defer owned.deinit();
    try e.expectEqualStrings("people`archive", owned.statement.create.name);
    const schema = try owned.statement.create.bind(7);
    try e.expectEqualStrings("a\\b", schema.columns[1].default.?.value.atom.bytes);
    try e.expectEqualSlices(u64, &.{1}, schema.primary_key);
    var ansi = try ddl.compileDialect(e.allocator, "CREATE TABLE \"quoted\" (\"field\" BIGINT)", null, null, .mysql);
    defer ansi.deinit();
    try e.expectEqualStrings("quoted", ansi.statement.create.name);
    try e.expectError(error.UnboundParameters, ddl.compileDialect(e.allocator, "CREATE TABLE t (id BIGINT DEFAULT ?)", null, null, .mysql));
}
test "CREATE compiles the reported nullable example and realistic typed schemas" {
    var simple = try ddl.compile(e.allocator, "CREATE TABLE people (id INT64, name UTF8);", null, null);
    defer simple.deinit();
    const result = try simple.statement.create.bind(42);
    try e.expect(result.columns[0].nullable and result.columns[1].nullable);
    try e.expectEqual(@as(usize, 0), result.primary_key.len);
    var people = try ddl.compile(e.allocator, "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL, department_id INTEGER, active BOOLEAN DEFAULT TRUE, salary DECIMAL(18, 2));", null, null);
    defer people.deinit();
    const schema = try people.statement.create.bind(43);
    try e.expectEqual(@as(usize, 5), schema.columns.len);
    try e.expect(!schema.columns[0].nullable and !schema.columns[1].nullable);
    try e.expectEqual(@as(?u32, 200), schema.columns[1].max_characters);
    try e.expect(schema.columns[3].default.?.value.atom.boolean);
    try e.expectEqualSlices(u64, &.{1}, schema.primary_key);
    try e.expectEqual(@as(u8, 2), schema.columns[4].type.decimal.scale);
}
test "DDL owns escaped Unicode names, composite keys and nested typed defaults" {
    var owned = try ddl.compile(e.allocator, "CREATE TABLE IF NOT EXISTS \"人\" (\"a\"\"b\" BIGINT, tenant TEXT, payload STRUCT(n INT32 NOT NULL, tags LIST(TEXT)) DEFAULT STRUCT(12, LIST('a', NULL)), choice UNION(left INT64, right TEXT) DEFAULT UNION(right, 'hello'), extras MAP(INT32, TEXT) DEFAULT MAP(1, 'one', 2, NULL), PRIMARY KEY(tenant, \"a\"\"b\"));", null, null);
    defer owned.deinit();
    try e.expect(owned.statement.create.if_not_exists);
    try e.expectEqualStrings("人", owned.statement.create.name);
    const schema = try owned.statement.create.bind(3);
    try e.expectEqualStrings("a\"b", schema.columns[0].name);
    try e.expectEqualSlices(u64, &.{ 2, 1 }, schema.primary_key);
    try e.expect(!schema.columns[0].nullable and !schema.columns[1].nullable);
    try e.expectEqual(@as(i128, 12), schema.columns[2].default.?.value.structure[0].value.atom.signed);
    try e.expectEqual(@as(u8, 1), schema.columns[3].default.?.value.tagged_union.index);
}
test "SQL defaults cover precise numeric temporal binary interval and JSON values" {
    var owned = try ddl.compile(e.allocator, "CREATE TABLE types (a UINT128 DEFAULT 340282366920938463463374607431768211455, b DECIMAL(18,2) DEFAULT -12.50, c FLOAT64 DEFAULT 1.25e-3, d DATE DEFAULT DATE '2000-02-29', e TIME(9) DEFAULT '23:59:59.123456789', f TIMESTAMP(6) WITH TIME ZONE DEFAULT '1969-12-31T23:59:59.999999Z', g BINARY DEFAULT X'00ff', h INTERVAL DEFAULT INTERVAL(-1,2,3), i JSON DEFAULT JSON '{\"n\":18446744073709551615}', j ARRAY(INT8,2) DEFAULT ARRAY(1,2), k UUID DEFAULT '00112233-4455-6677-8899-aabbccddeeff');", null, null);
    defer owned.deinit();
    const columns = owned.statement.create.columns;
    try e.expectEqual(std.math.maxInt(u128), columns[0].default.?.value.atom.unsigned);
    try e.expectEqual(@as(i128, -1250), columns[1].default.?.value.atom.decimal);
    try e.expectEqual(@as(i64, -1), columns[5].default.?.value.atom.timestamp);
    try e.expectEqualSlices(u8, &.{ 0, 255 }, columns[6].default.?.value.atom.bytes);
    try e.expectEqual(@as(i32, -1), columns[7].default.?.value.atom.interval.months);
}
test "DDL rejects unsupported semantics and conflicting constraints before mutation" {
    const cases = .{
        .{ "CREATE TABLE t (id , name TEXT)", error.InvalidSqlSyntax },
        .{ "CREATE TABLE t (id NO_SUCH_TYPE)", error.UnknownSqlType },
        .{ "CREATE TABLE t (id INT PRIMARY KEY NULL)", error.NullablePrimaryKey },
        .{ "CREATE TABLE t (id INT NULL, PRIMARY KEY(id))", error.NullablePrimaryKey },
        .{ "CREATE TABLE t (id INT PRIMARY KEY, v INT PRIMARY KEY)", error.MultiplePrimaryKeys },
        .{ "CREATE TABLE t (id INT, PRIMARY KEY(id,id))", error.DuplicatePrimaryKeyColumn },
        .{ "CREATE TABLE t (id INT, PRIMARY KEY(absent))", error.UnknownColumn },
        .{ "CREATE TABLE t (id INT NOT NULL DEFAULT NULL)", error.NullNotAllowed },
        .{ "CREATE TABLE t (id INT DEFAULT 1 DEFAULT 2)", error.DuplicateColumnConstraint },
        .{ "CREATE TABLE t (id INT UNIQUE)", error.UnsupportedTableConstraint },
        .{ "CREATE TABLE t (id INT CHECK(id > 0))", error.UnsupportedTableConstraint },
        .{ "CREATE TABLE t (name VARCHAR(2) DEFAULT '東京é')", error.CharacterLimitExceeded },
        .{ "CREATE TABLE t (x DECIMAL(3,1) DEFAULT 1.25)", error.Inexact },
        .{ "CREATE TABLE t (x LIST(VARCHAR(10)))", error.UnsupportedNestedCharacterLimit },
        .{ "CREATE TABLE t (x JSON PRIMARY KEY)", error.UnsupportedPrimaryKeyType },
        .{ "CREATE TABLE t (x TIME(6))", error.UnsupportedTemporalPrecision },
        .{ "CREATE TABLE t (x INT); DROP TABLE t", error.UnsupportedConstruct },
        .{ "CREATE TABLE t (x UTF8 DEFAULT '\x00')", error.InvalidSqlEncoding },
    };
    inline for (cases) |case| try e.expectError(case[1], ddl.compile(e.allocator, case[0], null, null));
}
test "ALTER binds stable identities and source revision; DROP cannot target a replacement by name" {
    var created = try ddl.compile(e.allocator, "CREATE TABLE t (id INTEGER PRIMARY KEY, name VARCHAR(200), n INTEGER DEFAULT 7)", null, null);
    defer created.deinit();
    const schema = try created.statement.create.bind(9);
    const statements = [_][]const u8{
        "ALTER TABLE t ADD COLUMN extra TEXT",
        "ALTER TABLE t DROP COLUMN name RESTRICT",
        "ALTER TABLE t RENAME COLUMN name TO full_name",
        "ALTER TABLE t RENAME TO renamed",
        "ALTER TABLE t ALTER COLUMN n SET DEFAULT 9",
        "ALTER TABLE t ALTER n DROP DEFAULT",
        "ALTER TABLE t ALTER name SET NOT NULL",
        "ALTER TABLE t ALTER name DROP NOT NULL",
        "ALTER TABLE t ALTER n TYPE BIGINT",
        "ALTER TABLE t ALTER n SET DATA TYPE DECIMAL(18,2)",
    };
    for (statements) |statement| {
        var owned = try ddl.compile(e.allocator, statement, schema, null);
        defer owned.deinit();
        try e.expectEqual(@as(u64, 9), owned.statement.alter.object);
        try e.expectEqualSlices(u8, &try schema.fingerprint(), &owned.statement.alter.schema);
    }
    try e.expectError(error.PrimaryKeyColumnRequired, ddl.compile(e.allocator, "ALTER TABLE t DROP id", schema, null));
    try e.expectError(error.UnsupportedCascade, ddl.compile(e.allocator, "DROP TABLE t CASCADE", schema, null));
    try e.expectError(error.TableNotFound, ddl.compile(e.allocator, "DROP TABLE absent", null, null));
    var absent = try ddl.compile(e.allocator, "DROP TABLE IF EXISTS absent", null, null);
    defer absent.deinit();
    try e.expectEqual(null, absent.statement.drop.object);
    var drop = try ddl.compile(e.allocator, "DROP TABLE t RESTRICT", schema, null);
    defer drop.deinit();
    try e.expectEqual(@as(?u64, 9), drop.statement.drop.object);
}
test "Table DDL allocation failures release recursive parsed names types and defaults" {
    try e.checkAllAllocationFailures(e.allocator, allocationCase, .{});
}
test "Table DDL diagnostics retain actual causes and never classify unknown execution failures" {
    const diagnostic = @import("SqlDiagnostic.zig");
    const cases = .{
        .{ "CREATE TABLE t (id INT NULL PRIMARY KEY)", "sql.nullable_primary_key" },
        .{ "CREATE TABLE t (name VARCHAR(2) DEFAULT '東京é')", "sql.character_limit_exceeded" },
        .{ "CREATE TABLE t (n DECIMAL(3,1) DEFAULT 1.25)", "sql.inexact" },
        .{ "CREATE TABLE t (n INTEGER DEFAULT )", "sql.invalid_sql_syntax" },
    };
    inline for (cases) |case| {
        var location: @import("Sql.zig").Location = .{};
        if (ddl.compile(e.allocator, case[0], null, &location)) |success| {
            var owned = success;
            owned.deinit();
            return error.ExpectedRejection;
        } else |cause| {
            const detail = diagnostic.tableDdl(case[0], cause, location).?;
            try e.expectEqual(cause, detail.cause);
            const envelope = try detail.structured();
            try e.expectEqualStrings(case[1], envelope.code.slice());
            try e.expectEqual(@import("transit_protocol").Diagnostic.Outcome.not_submitted, envelope.outcome);
            for (envelope.actions) |slot| if (slot) |action| try e.expect(action.kind != .resume_exact and action.kind != .cancel_mutation);
        }
    }
    try e.expect(diagnostic.tableDdl("CREATE TABLE t (id INT)", error.UnregisteredCallbackFailure, .{}) == null);
    try e.expect(diagnostic.tableDdl("CREATE TABLE t (id INT)", error.OutOfMemory, .{}) == null);
}
test "DDL target extraction is only routing and maps canonicalize keys without losing duplicates" {
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const target = try ddl.target(arena.allocator(), "ALTER TABLE \"人\" ALTER COLUMN x SET DEFAULT 'new'");
    try e.expectEqualStrings("人", target.name);
    try e.expectEqual(std.meta.Tag(ddl.Statement).alter, target.kind);
    var owned = try ddl.compile(e.allocator, "CREATE TABLE t (m MAP(INT32,TEXT) DEFAULT MAP(2,'two',1,'one'))", null, null);
    defer owned.deinit();
    try e.expectEqual(@as(i128, 1), owned.statement.create.columns[0].default.?.value.map[0].key.signed);
    try e.expectError(error.DuplicateMapKey, ddl.compile(e.allocator, "CREATE TABLE t (m MAP(INT32,TEXT) DEFAULT MAP(1,'one',1,'duplicate'))", null, null));
}
fn allocationCase(allocator: std.mem.Allocator) !void {
    var owned = try ddl.compile(allocator, "CREATE TABLE t (id INT PRIMARY KEY, v STRUCT(name TEXT, xs LIST(INT32)) DEFAULT STRUCT('Ada', LIST(1,2)))", null, null);
    defer owned.deinit();
    const schema: s.Schema = try owned.statement.create.bind(1);
    try schema.validate();
    var altered = try ddl.compile(allocator, "ALTER TABLE t ALTER v SET DEFAULT STRUCT('new', LIST(1,2))", schema, null);
    defer altered.deinit();
    try e.expectEqual(@as(u64, 2), altered.statement.alter.action.columns.default.column);
}

test "DDL retains unknown key and ALTER column positions through deferred binding" {
    var created = try ddl.compile(e.allocator, "CREATE TABLE people (id INT8, payload LIST(INT8))", null, null);
    defer created.deinit();
    const schema = try created.statement.create.bind(9);
    const cases = .{
        .{ "CREATE TABLE people (id INT8, PRIMARY KEY(absent))", error.UnknownColumn, "absent" },
        .{ "ALTER TABLE people RENAME COLUMN absent TO renamed", error.UnknownColumn, "absent" },
        .{ "ALTER TABLE people DROP COLUMN absent RESTRICT", error.UnknownColumn, "absent" },
        .{ "ALTER TABLE people ALTER payload SET DEFAULT LIST(1,128)", error.Overflow, "128" },
    };
    inline for (cases) |case| {
        var location: @import("Sql.zig").Location = .{};
        try e.expectError(case[1], ddl.compile(e.allocator, case[0], schema, &location));
        try e.expectEqual(std.mem.indexOf(u8, case[0], case[2]).?, location.offset);
    }
}
