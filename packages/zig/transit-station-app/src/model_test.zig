const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const m = root.Model;
const sql = root.Sql;
const fixture = @embedFile("fixtures/board.sql");
fn canonical(allocator: std.mem.Allocator, definition: m.Definition) ![]u8 {
    var bytes: [m.max_program_bytes]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try sql.format(definition, &out);
    return allocator.dupe(u8, out.buffered());
}
test "SQL model form SQL preserves identities and explicit operation classes" {
    var parsed = try sql.parse(t.allocator, fixture);
    defer parsed.deinit();
    try t.expectEqual(std.math.maxInt(u64), parsed.definition.revision.value);
    const before = try canonical(t.allocator, parsed.definition);
    defer t.allocator.free(before);
    var again = try sql.parse(t.allocator, before);
    defer again.deinit();
    const after = try canonical(t.allocator, again.definition);
    defer t.allocator.free(after);
    try t.expectEqualStrings(before, after);
    try t.expect(again.definition.bindings[0].source == .inspection);
    try t.expect(again.definition.bindings[1].source == .query);
    try t.expect(again.definition.bindings[2].source == .command);
    again.definition.theme = "dense";
    const edited = try canonical(t.allocator, again.definition);
    defer t.allocator.free(edited);
    var roundtrip = try sql.parse(t.allocator, edited);
    defer roundtrip.deinit();
    try t.expectEqualStrings("dense", roundtrip.definition.theme);
    try t.expectEqualDeep(parsed.definition.bindings, roundtrip.definition.bindings);
    const json = try root.protocol.Json.valueAlloc(t.allocator, roundtrip.definition);
    defer t.allocator.free(json);
    try t.expect(std.mem.indexOf(u8, json, "\"revision\":\"18446744073709551615\"") != null);
}
test "whole-program validation rejects unknown unsupported and cross-kind definitions" {
    const cases = .{
        .{ "page_budget = 1", "page_budget = 2", error.UnsupportedInspectionBudget },
        .{ "page_budget = 1", "page_budget = 1, ignored = 'hidden'", error.UnknownInterfaceOption },
        .{ "page_budget = 1", "page_budget = 1, page_budget = 1", error.DuplicateInterfaceOption },
        .{ "renderer = 'worksheet'", "renderer = 'operations'", error.IncompatibleRenderer },
        .{ "target = 'update'", "target = 'items'", error.IncompatibleAction },
        .{ "binding = 'catalog'", "binding = 'missing'", error.MissingInterfaceReference },
        .{ "CREATE THEME board.mono", "CREATE THEME other.mono", error.ForeignInterfaceDeclaration },
        .{ "components = 1", "components = 2", error.UnsupportedInterfaceVersion },
        .{ "revision = 18446744073709551615", "revision = 18446744073709551616", error.InvalidInterfaceOption },
        .{ "SELECT id, value FROM items", "DELETE FROM items", error.UnsupportedStatement },
        .{ "path = '/explore'", "path = '/atlas'", error.DuplicateInterfacePath },
        .{ "path = '/explore'", "path = '//evil'", error.InvalidInterfacePath },
        .{ "profile = 'unified_v2'", "profile = 'table_v1'", error.UnsupportedInterfaceWatch },
        .{ "source_kind = 'table'", "source_kind = 'kv'", error.UnsupportedInterfaceWatch },
        .{ "source_kind = 'table'", "source_kind = 'document'", error.UnsupportedInterfaceWatch },
    };
    inline for (cases) |case| {
        const changed = try std.mem.replaceOwned(u8, t.allocator, fixture, case[0], case[1]);
        defer t.allocator.free(changed);
        try t.expectError(case[2], sql.parse(t.allocator, changed));
    }
    const extra = try std.mem.concat(t.allocator, u8, &.{ fixture, "GRANT admin ON anything;" });
    defer t.allocator.free(extra);
    try t.expectError(error.UnsupportedInterfaceStatement, sql.parse(t.allocator, extra));
}
test "owned parse remains valid after source storage is released and rejects incomplete text" {
    const temporary = try t.allocator.dupe(u8, fixture);
    var parsed = try sql.parse(t.allocator, temporary);
    defer parsed.deinit();
    t.allocator.free(temporary);
    try parsed.definition.validate();
    try t.expectError(error.InvalidInterfaceSyntax, sql.parse(t.allocator, fixture[0 .. fixture.len - 2]));
    const comment = try std.mem.concat(t.allocator, u8, &.{ fixture, "/* unclosed" });
    defer t.allocator.free(comment);
    try t.expectError(error.UnterminatedInterfaceComment, sql.parse(t.allocator, comment));
}
fn allocations(allocator: std.mem.Allocator) !void {
    var parsed = try sql.parse(allocator, fixture);
    defer parsed.deinit();
    try parsed.definition.validate();
}
test "allocation failure never returns a partial application definition" {
    try t.checkAllAllocationFailures(t.allocator, allocations, .{});
}
