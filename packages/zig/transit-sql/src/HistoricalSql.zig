//! Statement-level immutable catalog selection, resolved before name binding.
const std = @import("std");
const g = @import("root.zig");
const sql = g.fuze.Sql;
const Selector = g.catalog.DirectHistory.Selector;
pub const Selected = struct {
    statement: []const u8,
    snapshot: ?g.catalog.protocol.DataLifecycle.Snapshot,
    namespace: ?g.catalog.TableAuthority.Name = null,

    /// Resolve only inside the already published selection. The returned stable
    /// namespace is frozen into the prepared binding, never a live search path.
    pub fn resolveNamespace(self: Selected, client: g.catalog.DirectTableClient, fallback: u64) !u64 {
        const name = self.namespace orelse return fallback;
        const snapshot = self.snapshot orelse return error.InvalidHistoricalSelector;
        const response = try g.catalog.DirectHistory.call(client, .{ .namespace = .{ .snapshot = snapshot, .name = name } });
        defer response.deinit();
        return (response.value.result.historical_catalog.namespace orelse return error.HistoricalObjectNotSelected).id;
    }
};
fn word(token: sql.Token, expected: []const u8) bool {
    return token.tag == .word and std.ascii.eqlIgnoreCase(token.text, expected);
}
/// Returned text borrows the original statement. The selector owns every field.
/// Strings, comments and nested expressions never become selector clauses.
pub fn select(text: []const u8, dialect: sql.Dialect) !Selected {
    try sql.validateText(text);
    var lexer: sql.Lexer = .{ .text = text, .dialect = dialect, .parameters_enabled = true };
    // Dialect setup and administrative commands have their own lexers. Only
    // row-returning statements admit a historical catalog suffix.
    const first = try lexer.next();
    if (!word(first, "SELECT") and !word(first, "SHOW") and !word(first, "DESCRIBE") and !word(first, "EXPLAIN")) return .{ .statement = text, .snapshot = null };
    var depth: usize = 0;
    while (true) {
        const token = try lexer.next();
        if (token.tag == .eof) return .{ .statement = text, .snapshot = null };
        if (token.tag == .left) depth += 1;
        if (token.tag == .right) {
            if (depth == 0) return error.InvalidSqlSyntax;
            depth -= 1;
        }
        if (depth != 0 or !word(token, "AS")) continue;
        const start = lexer.start;
        var suffix = lexer;
        if (!word(try suffix.next(), "OF") or !word(try suffix.next(), "SNAPSHOT")) continue;
        const literal = try suffix.next();
        if (literal.tag != .string) return error.InvalidHistoricalSelector;
        const snapshot = try Selector.decode(literal.text[1 .. literal.text.len - 1]);
        var end = try suffix.next();
        var namespace: ?g.catalog.TableAuthority.Name = null;
        if (word(end, "IN")) {
            // Reuse identifier folding/unquoting with a bounded scratch owner.
            // No arbitrary statement-sized allocation is needed for one name.
            var bytes: [512]u8 = undefined;
            var scratch = std.heap.FixedBufferAllocator.init(&bytes);
            var parser = try g.fuze.SqlTyped.initDialect(scratch.allocator(), text[suffix.start..], null, false, dialect);
            try parser.requireWord("IN");
            try parser.requireWord("SCHEMA");
            if (parser.token.text.len > bytes.len) return error.InvalidCatalogName;
            namespace = try .init(try parser.name());
            try parser.finish();
            return .{ .statement = text[0..start], .snapshot = snapshot, .namespace = namespace };
        }
        if (end.tag == .semi) end = try suffix.next();
        if (end.tag != .eof) return error.InvalidHistoricalSelector;
        return .{ .statement = text[0..start], .snapshot = snapshot };
    }
}

test "historical SQL selector is canonical and cannot be a comment string or new statement" {
    const t = std.testing;
    const p = g.catalog.protocol;
    const snapshot: p.DataLifecycle.Snapshot = .{ .definition = p.Growth.current_definition, .owner = .{ .scope = .{ .realm = 1, .resource = 3, .catalog = 1 }, .principal = 1, .operation = std.math.maxInt(u64) }, .branch = 1, .catalog_root = .{ .bytes = 42, .sha256 = @splat(3) }, .sources_root = .{ .bytes = 43, .sha256 = @splat(4) }, .source_count = 1, .consistency = .{ .single_partition = .{ .partition = 7, .next_lsn = std.math.maxInt(u64) } } };
    var buffer: [Selector.text_bytes]u8 = undefined;
    const encoded = try Selector.encode(snapshot, &buffer);
    const query = try std.fmt.allocPrint(t.allocator, "SELECT id FROM events WHERE id=$1 LIMIT 2 AS OF SNAPSHOT '{s}'; -- trailing", .{encoded});
    defer t.allocator.free(query);
    const result = try select(query, .transit);
    try t.expectEqualDeep(snapshot, result.snapshot.?);
    try t.expectEqualStrings("SELECT id FROM events WHERE id=$1 LIMIT 2 ", result.statement);
    for ([_]struct { name: []const u8, expected: []const u8 }{
        .{ .name = "PUBLIC", .expected = "public" },
        .{ .name = "\"Old Schema\"", .expected = "Old Schema" },
        .{ .name = "\"old\"\"name\"", .expected = "old\"name" },
    }) |case| {
        const named = try std.fmt.allocPrint(t.allocator, "SELECT id FROM events AS OF SNAPSHOT '{s}' IN SCHEMA {s}; -- retained namespace", .{ encoded, case.name });
        defer t.allocator.free(named);
        const selected = try select(named, .transit);
        try t.expectEqualStrings(case.expected, selected.namespace.?.slice());
        try t.expectEqualDeep(snapshot, selected.snapshot.?);
    }
    const duplicate = try std.fmt.allocPrint(t.allocator, "SHOW TABLES AS OF SNAPSHOT '{s}' IN SCHEMA public IN SCHEMA other", .{encoded});
    defer t.allocator.free(duplicate);
    try t.expectError(error.UnsupportedConstruct, select(duplicate, .transit));
    for ([_][]const u8{ "SELECT 'AS OF SNAPSHOT' FROM events", "SELECT id FROM events /* AS OF SNAPSHOT 'bad' */", "SELECT id AS snapshot FROM events" }) |text| try t.expect((try select(text, .transit)).snapshot == null);
    for ([_][]const u8{ "SET @@session.autocommit = ON", "SET NAMES 'utf8mb4' COLLATE 'utf8mb4_0900_bin'", "SET @@session.sql_mode = 'ANSI_QUOTES,NO_BACKSLASH_ESCAPES'" }) |text| {
        const setup = try select(text, .mysql);
        try t.expect(setup.snapshot == null);
        try t.expectEqualStrings(text, setup.statement);
    }
    try t.expectError(error.InvalidHistoricalSelector, select("SELECT id FROM events AS OF SNAPSHOT '123'", .transit));
    const trailing = try std.fmt.allocPrint(t.allocator, "SELECT id FROM events AS OF SNAPSHOT '{s}'; DELETE FROM events", .{encoded});
    defer t.allocator.free(trailing);
    try t.expectError(error.InvalidHistoricalSelector, select(trailing, .transit));
    var upper = buffer;
    for (&upper) |*byte| byte.* = std.ascii.toUpper(byte.*);
    try t.expectError(error.InvalidHistoricalSelector, Selector.decode(&upper));
    var foreign = buffer;
    foreign[16] = if (foreign[16] == '0') '1' else '0';
    try t.expectError(error.IncompatibleDefinition, Selector.decode(&foreign));
}
