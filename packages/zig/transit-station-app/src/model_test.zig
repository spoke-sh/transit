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
        .{ "profile = 'unified_v1'", "profile = 'table_v1'", error.UnsupportedInterfaceOption },
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
    var diagnostic: root.Diagnostic = .{};
    var parsed = try sql.parseDiagnostic(allocator, fixture, &diagnostic);
    defer parsed.deinit();
    try parsed.definition.validate();
}
test "allocation failure never returns a partial application definition" {
    try t.checkAllAllocationFailures(t.allocator, allocations, .{});
}

test "system and recovery routes cannot be replaced by declarations" {
    for ([_][]const u8{ "/api", "/api/v1/x", "/assets/x", "/health", "/openapi/x", "/recovery/definition", "/processes/3" }) |value| try std.testing.expectError(error.ReservedInterfacePath, m.path(value));
    try m.path("/neighborhood");
    try m.path("/healthcare");
}

test "failed declaration diagnostics own their member and option after parse storage is freed" {
    const source = try std.mem.replaceOwned(u8, t.allocator, fixture, "starts = 8", "starts = 9");
    var diagnostic: root.Diagnostic = .{};
    try t.expectError(error.InvalidQueryBudget, sql.parseDiagnostic(t.allocator, source, &diagnostic));
    t.allocator.free(source);
    var bytes: [4096]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try diagnostic.render(&out, error.InvalidQueryBudget);
    try t.expectEqualStrings("items", diagnostic.member[0..diagnostic.member_len]);
    try t.expectEqualStrings("starts", diagnostic.option[0..diagnostic.option_len]);
    try t.expectEqual(8, diagnostic.line);
    try t.expect(std.mem.indexOf(u8, out.buffered(), "No application was published.") != null);
}

test "application capacity witnesses identify the first dimension and exact bound" {
    var parsed = try sql.parse(t.allocator, fixture);
    defer parsed.deinit();
    var detail: root.Diagnostic = .{};
    var definition = parsed.definition;
    definition.themes = &.{};
    try t.expectError(error.InterfaceCapacity, definition.validateDiagnostic(&detail));
    try t.expectEqualStrings("themes", detail.bound.?.dimension);
    try t.expect(detail.bound.?.minimum);
    try t.expectEqual(@as(usize, 1), detail.bound.?.limit);
    try t.expectEqual(@as(usize, 0), detail.bound.?.actual);
    definition = parsed.definition;
    definition.screens = &.{};
    try t.expectError(error.InterfaceCapacity, definition.validateDiagnostic(&detail));
    try t.expectEqualStrings("screens", detail.bound.?.dimension);
    inline for (.{ "themes", "screens", "bindings", "actions" }) |name| {
        definition = parsed.definition;
        const maximum = if (comptime std.mem.eql(u8, name, "themes")) 2 else m.max_members;
        const Item = std.meta.Child(@FieldType(m.Definition, name));
        const excess: [maximum + 1]Item = @splat(@field(definition, name)[0]);
        @field(definition, name) = &excess;
        try t.expectError(error.InterfaceCapacity, definition.validateDiagnostic(&detail));
        try t.expectEqualStrings(name, detail.bound.?.dimension);
        try t.expect(!detail.bound.?.minimum);
        try t.expectEqual(@as(usize, maximum), detail.bound.?.limit);
        try t.expectEqual(@as(usize, maximum + 1), detail.bound.?.actual);
        try (try detail.structured(error.InterfaceCapacity)).validate();
    }
    const extra = fixture ++ "CREATE THEME board.extra WITH (density = 'compact');";
    try t.expectError(error.InterfaceCapacity, sql.parseDiagnostic(t.allocator, extra, &detail));
    try t.expectEqualStrings("themes", detail.bound.?.dimension);
    try t.expectEqual(@as(usize, 3), detail.bound.?.actual);
    var oversize: [m.max_program_bytes + 1]u8 = @splat(' ');
    try t.expectError(error.InterfaceProgramTooLarge, sql.parseDiagnostic(t.allocator, &oversize, &detail));
    try t.expectEqualStrings("application program", detail.bound.?.dimension);
    try t.expectEqual(@as(usize, oversize.len), detail.bound.?.actual);
    try t.expect(detail.offset == null);
    const nested = "/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/**/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/" ++ fixture;
    try t.expectError(error.InterfaceCommentDepth, sql.parseDiagnostic(t.allocator, nested, &detail));
    try t.expectEqualStrings("comment nesting", detail.bound.?.dimension);
    try t.expectEqual(@as(usize, 17), detail.bound.?.actual);
    const literal: [4097]u8 = @splat('x');
    const long_literal = try std.fmt.allocPrint(t.allocator, "CREATE INTERFACE board WITH (entry = '{s}');", .{literal});
    defer t.allocator.free(long_literal);
    try t.expectError(error.InterfaceLiteralTooLarge, sql.parseDiagnostic(t.allocator, long_literal, &detail));
    try t.expectEqualStrings("decoded literal", detail.bound.?.dimension);
    try t.expectEqual(@as(usize, 4097), detail.bound.?.actual);
    const too_many_options = "CREATE INTERFACE board WITH (a=1,b=1,c=1,d=1,e=1,f=1,g=1,h=1,i=1,j=1,k=1,l=1,m=1,n=1,o=1,p=1,q=1);";
    try t.expectError(error.InterfaceOptionCapacity, sql.parseDiagnostic(t.allocator, too_many_options, &detail));
    try t.expectEqualStrings("option slots", detail.bound.?.dimension);
    try t.expectEqual(@as(usize, 17), detail.bound.?.actual);
}
