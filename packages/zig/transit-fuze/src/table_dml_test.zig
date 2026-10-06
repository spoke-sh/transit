const std = @import("std");
const e = std.testing;
const dml = @import("TableDml.zig");
const ddl = @import("TableDdl.zig");
const s = @import("TableSchema.zig");
const Cell = @import("Types.zig").Values.Cell;
const schema: s.Schema = .{ .object = 7, .revision = 2, .next_column = 10, .columns = &.{
    .{ .id = 3, .name = "id", .type = .int32, .nullable = false },
    .{ .id = 6, .name = "name", .type = .utf8, .max_characters = 5 },
    .{ .id = 9, .name = "active", .type = .boolean, .default = .{ .value = .{ .atom = .{ .boolean = true } } } },
}, .primary_key = &.{3} };
fn integer(value: i128) Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}
test "general INSERT owns reordered multiple rows, defaults, NULL and nonpositional keys" {
    const source = try e.allocator.dupe(u8, "INSERT INTO people (name, id) VALUES ('Ada', 1), (NULL, 2), (DEFAULT, 3);");
    defer e.allocator.free(source);
    var owned = try dml.compile(e.allocator, source, "people", schema, null);
    defer owned.deinit();
    @memset(source, 0);
    try e.expectEqualStrings("people", owned.plan.name);
    try e.expectEqual(@as(usize, 3), owned.plan.action.insert.len);
    const rows = owned.plan.action.insert;
    try e.expectEqual(@as(i128, 1), rows[0][0].value.atom.signed);
    try e.expectEqualStrings("Ada", rows[0][1].value.atom.bytes);
    try e.expect(rows[0][2].value.atom.boolean);
    try e.expect(rows[1][1] == .null and rows[2][1] == .null);
    var unkeyed = schema;
    unkeyed.primary_key = &.{};
    var duplicates = try dml.compile(e.allocator, "INSERT INTO people VALUES (1,'Ada',TRUE),(1,'Ada',TRUE)", "people", unkeyed, null);
    defer duplicates.deinit();
    try e.expectEqualDeep(duplicates.plan.action.insert[0], duplicates.plan.action.insert[1]);
    var nullable_columns = schema.columns[0..3].*;
    nullable_columns[0].nullable = true;
    unkeyed.columns = &nullable_columns;
    var defaults = try dml.compile(e.allocator, "INSERT INTO people DEFAULT VALUES", "people", unkeyed, null);
    defer defaults.deinit();
    try e.expect(defaults.plan.action.insert[0][0] == .null);
    try e.expect(defaults.plan.action.insert[0][2].value.atom.boolean);
}
test "UPDATE and DELETE use shared eager Boolean and five-state predicate semantics" {
    var owned = try dml.compile(e.allocator, "UPDATE people SET name='Grace', active=DEFAULT, id=9 WHERE (people.id >= 1 AND NOT name IS NULL) OR id = 0", "people", schema, null);
    defer owned.deinit();
    try e.expectEqualSlices(u64, &.{ 6, 9, 3 }, &.{ owned.plan.action.update[0].column, owned.plan.action.update[1].column, owned.plan.action.update[2].column });
    var inserted = try dml.compile(e.allocator, "INSERT INTO people (id,name) VALUES (1,'Ada'),(2,NULL),(0,NULL)", "people", schema, null);
    defer inserted.deinit();
    try e.expect(try owned.plan.matches(inserted.plan.action.insert[0]));
    try e.expect(!try owned.plan.matches(inserted.plan.action.insert[1]));
    try e.expect(try owned.plan.matches(inserted.plan.action.insert[2]));
    var cells: [3]Cell = undefined;
    const changed = try owned.plan.schema.update(inserted.plan.action.insert[0], owned.plan.action.update, &cells);
    try e.expectEqual(@as(i128, 9), changed[0].value.atom.signed);
    try e.expectEqualStrings("Grace", changed[1].value.atom.bytes);
    var removed = try dml.compile(e.allocator, "DELETE FROM people WHERE NOT name='Ada'", "people", schema, null);
    defer removed.deinit();
    try e.expect(!try removed.plan.matches(inserted.plan.action.insert[0]));
    try e.expect(!try removed.plan.matches(inserted.plan.action.insert[1]));
    var all = try dml.compile(e.allocator, "DELETE FROM people", "people", schema, null);
    defer all.deinit();
    try e.expect(try all.plan.matches(inserted.plan.action.insert[1]));
}
test "typed DML owns recursive values and quoted Unicode bindings from DDL" {
    var created = try ddl.compile(e.allocator, "CREATE TABLE \"人\" (\"識別\" INT PRIMARY KEY, payload STRUCT(n INT32 NOT NULL, xs LIST(TEXT)), amount DECIMAL(18,2), date DATE)", null, null);
    defer created.deinit();
    var owned = try dml.compile(e.allocator, "INSERT INTO \"人\" VALUES (1, STRUCT(2, LIST('one',NULL)), 12.50, DATE '2000-02-29')", "人", try created.statement.create.bind(31), null);
    defer owned.deinit();
    const row = owned.plan.action.insert[0];
    try e.expectEqual(@as(i128, 2), row[1].value.structure[0].value.atom.signed);
    try e.expectEqualStrings("one", row[1].value.structure[1].value.list[0].value.atom.bytes);
    var compare = try dml.compile(e.allocator, "DELETE FROM \"人\" WHERE \"人\".\"識別\"=1 AND amount >= 12.00 AND date = DATE '2000-02-29'", "人", owned.plan.schema, null);
    defer compare.deinit();
    try e.expect(try compare.plan.matches(row));
}
test "DML rejects invalid complete inputs and unsupported predicates before row execution" {
    const cases = .{
        .{ "INSERT INTO people (id) VALUES(1),(NULL)", error.NullNotAllowed },
        .{ "INSERT INTO people (name) VALUES('Ada')", error.MissingRequiredField },
        .{ "INSERT INTO people (id,id) VALUES(1,1)", error.DuplicateAssignment },
        .{ "INSERT INTO people (id,other) VALUES(1,1)", error.UnknownColumn },
        .{ "UPDATE people SET name='Too long'", error.CharacterLimitExceeded },
        .{ "UPDATE people SET id=DEFAULT", error.MissingRequiredField },
        .{ "UPDATE people SET name='Ada',name='Grace'", error.DuplicateAssignment },
        .{ "DELETE FROM people WHERE id=NULL", error.UnsupportedNullComparison },
        .{ "DELETE FROM people WHERE other.id=1", error.UnknownQualifier },
        .{ "DELETE FROM missing", error.UnknownSource },
        .{ "DELETE FROM people WHERE id=1; DROP TABLE people", error.UnsupportedConstruct },
        .{ "DELETE FROM people WHERE name='\x00'", error.InvalidSqlEncoding },
    };
    inline for (cases) |case| try e.expectError(case[1], dml.compile(e.allocator, case[0], "people", schema, null));
    var deeply_nested: [512]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&deeply_nested);
    try writer.writeAll("DELETE FROM people WHERE ");
    for (0..16) |_| try writer.writeByte('(');
    try writer.writeAll("id=1");
    for (0..16) |_| try writer.writeByte(')');
    try e.expectError(error.PredicateTooDeep, dml.compile(e.allocator, writer.buffered(), "people", schema, null));
}
fn allocationCase(allocator: std.mem.Allocator) !void {
    var owned = try dml.compile(allocator, "UPDATE people SET name='Ada',active=DEFAULT WHERE NOT(id=1 OR name IS NULL)", "people", schema, null);
    defer owned.deinit();
    try owned.plan.validate();
    _ = try owned.plan.fingerprint(allocator);
    var inserted = try dml.compile(allocator, "INSERT INTO people(id,name) VALUES (1,'one'),(2,'two')", "people", schema, null);
    defer inserted.deinit();
    _ = try inserted.plan.fingerprint(allocator);
}
test "DML compiler frees cloned schemas and literal arenas at every allocation failure" {
    try e.checkAllAllocationFailures(e.allocator, allocationCase, .{});
}

test "typed DML diagnostics preserve compile rejection without narrow-profile or recovery advice" {
    const diagnostic = @import("SqlDiagnostic.zig");
    const errors = .{ error.InvalidMutationColumns, error.UnsupportedMutationPredicate, error.PredicateTooDeep, error.UnsupportedComparison, error.MutationBatchTooLarge };
    inline for (errors) |cause| {
        const failure = diagnostic.tableDml("UPDATE people SET name='Ada' WHERE id>1", cause, .{ .offset = 18 }).?;
        try e.expectEqual(cause, failure.cause);
        try e.expectEqual(.mutation, failure.route);
        try e.expectEqual(@as(usize, 18), failure.location.?.offset);
        const structured = try failure.structured();
        try e.expectEqual(.not_submitted, structured.outcome);
        try e.expect(std.mem.indexOf(u8, failure.hint, ".resume") == null);
        try e.expect(std.mem.indexOf(u8, failure.hint, "primary-key DELETE") == null);
        try e.expect(std.mem.indexOf(u8, failure.hint, "one to three") == null);
        if (cause == error.MutationBatchTooLarge) try e.expect(std.mem.indexOf(u8, failure.hint, "4 MiB") != null);
    }
    try e.expectEqual(null, diagnostic.tableDml("DELETE FROM people", error.OutOfMemory, .{}));
    try e.expectEqual(null, diagnostic.tableDml("DELETE FROM people", error.UnknownWriterFailure, .{}));
}

test "point-key qualification preserves every predicate and declared composite key order" {
    var output: [s.max_columns]Cell = undefined;
    var point = try dml.compile(e.allocator, "UPDATE people SET name='Ada' WHERE id=1", "people", schema, null);
    defer point.deinit();
    try e.expectEqualDeep(integer(1), (try point.plan.primaryKeyEquality(&output)).?[0]);
    inline for (.{ "id=1 AND active=TRUE", "id=1 OR id=2", "NOT id=1", "id=1 AND id=1", "id>0", "name IS NULL" }) |predicate| {
        var scan = try dml.compile(e.allocator, "DELETE FROM people WHERE " ++ predicate, "people", schema, null);
        defer scan.deinit();
        try e.expectEqual(null, try scan.plan.primaryKeyEquality(&output));
    }
    var columns = schema.columns[0..3].*;
    columns[1].nullable = false;
    var composite = schema;
    composite.columns = &columns;
    composite.primary_key = &.{ 6, 3 };
    var both = try dml.compile(e.allocator, "DELETE FROM people WHERE id=1 AND name='Ada'", "people", composite, null);
    defer both.deinit();
    const key = (try both.plan.primaryKeyEquality(&output)).?;
    try e.expectEqualStrings("Ada", key[0].value.atom.bytes);
    try e.expectEqualDeep(integer(1), key[1]);
    var incomplete = try dml.compile(e.allocator, "DELETE FROM people WHERE id=1", "people", composite, null);
    defer incomplete.deinit();
    try e.expectEqual(null, try incomplete.plan.primaryKeyEquality(&output));
}

test "typed intent binds complete rows, predicates and assignment semantics" {
    var original = try dml.compile(e.allocator, "UPDATE people SET name='Ada' WHERE id=1", "people", schema, null);
    defer original.deinit();
    const digest = try original.plan.fingerprint(e.allocator);
    var same = try dml.compile(e.allocator, "update people set name = 'Ada' where id = 1;", "people", schema, null);
    defer same.deinit();
    try e.expectEqual(digest, try same.plan.fingerprint(e.allocator));
    inline for (.{ "UPDATE people SET name='Grace' WHERE id=1", "UPDATE people SET name='Ada' WHERE id=2", "UPDATE people SET name='Ada'", "DELETE FROM people WHERE id=1" }) |text| {
        var changed = try dml.compile(e.allocator, text, "people", schema, null);
        defer changed.deinit();
        try e.expect(!std.mem.eql(u8, &digest, &try changed.plan.fingerprint(e.allocator)));
    }
    var changed_schema = original.plan;
    changed_schema.schema.revision += 1;
    try e.expect(!std.mem.eql(u8, &digest, &try changed_schema.fingerprint(e.allocator)));

    const bytes = try e.allocator.alloc(u8, 800 * 1024);
    defer e.allocator.free(bytes);
    @memset(bytes, 'a');
    const cells: [1]Cell = .{.{ .value = .{ .atom = .{ .bytes = bytes } } }};
    const rows: [6][]const Cell = @splat(&cells);
    const plan: dml.Plan = .{ .name = "large", .schema = .{ .object = 4, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "payload", .type = .binary }}, .primary_key = &.{} }, .action = .{ .insert = &rows } };
    try e.expectError(error.MutationBatchTooLarge, plan.fingerprint(e.allocator));
}
