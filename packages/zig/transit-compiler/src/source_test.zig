const std = @import("std");
const c = @import("root.zig");
const p = @import("transit_protocol");

fn compile(text: []const u8) !*c.Product {
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = text }}, .{ .compiler_revision = "source-syntax-test" }, &diagnostic);
}
test "structural checking covers unused bodies and unselected branches" {
    const valid = "CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;";
    const result = try compile("CREATE MODULE unused() AS BEGIN SELECT * FROM unknown; END;" ++ valid);
    defer result.deinit();
    try std.testing.expectEqual(1, result.steps.len);
    try std.testing.expectError(error.InvalidSourceTemplate, compile("CREATE MODULE unused() AS BEGIN INSERT INTO unknown VALUES (1,); END;" ++ valid));
    try std.testing.expectError(error.InvalidSourceTemplate, compile("CREATE TARGET default AS BEGIN IF FALSE THEN ASSERT ROWS (SELECT * FROM t) EQUAL ((1,)); END IF; CREATE PUBLIC TABLE t (id BIGINT); END;"));
    try std.testing.expectError(error.UnsupportedBuildStatement, compile("CREATE MODULE unused() AS BEGIN COMMIT; END;" ++ valid));
    try std.testing.expectError(error.InvalidSourceOperand, compile("CREATE MODULE unused() AS BEGIN SELECT * FROM t WHERE id = $1; END;" ++ valid));
}
test "SQL lexical units survive source emission and independent rebind" {
    const result = try compile("CREATE MODULE m(n BIGINT, v TEXT) AS BEGIN CREATE PUBLIC TABLE t (id BIGINT, f FLOAT64, b BYTEA, u UINT64); INSERT INTO t VALUES (-$n, 1.25e-2, X 'abcd', $n); SELECT * FROM t WHERE id != 2; END; CREATE TARGET default AS BEGIN USE m(1, '7'); END;");
    defer result.deinit();
    try std.testing.expectEqual(3, result.steps.len);
    try std.testing.expect(std.mem.indexOf(u8, result.sql, "1.25e-2") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.sql, "X 'abcd'") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.sql, "!=") != null);
}
test "template diagnostic uses exact UTF8 bytes" {
    const source = "-- 雪\r\nCREATE MODULE m() AS BEGIN INSERT INTO t VALUES ('é',); END;";
    var diagnostic: ?p.Diagnostic = null;
    try std.testing.expectError(error.InvalidSourceTemplate, c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "source-syntax-test" }, &diagnostic));
    const at = std.mem.indexOf(u8, source, ");").?;
    try std.testing.expectEqual(at, try diagnostic.?.location.?.offset.value());
}
test "formatter bounds output and left-associated expression recursion" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var location: usize = 0;
    const text = "CREATE MODULE m() AS BEGIN USE f(-(1), 1 + 2 * 3, (1 + 2) * 3, 1 - (2 - 3)); END;";
    const ast = try c.Syntax.parse(arena.allocator(), text, &location);
    var tiny: [8]u8 = undefined;
    var short: std.Io.Writer = .fixed(&tiny);
    try std.testing.expectError(error.WriteFailed, c.Format.write(text, ast, &short));
    var buffer: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try c.Format.write(text, ast, &writer);
    const again = try c.Syntax.parse(arena.allocator(), writer.buffered(), &location);
    var second: [1024]u8 = undefined;
    var output: std.Io.Writer = .fixed(&second);
    try c.Format.write(writer.buffered(), again, &output);
    try std.testing.expectEqualStrings(writer.buffered(), output.buffered());
    const chain = try std.fmt.allocPrint(arena.allocator(), "CREATE MODULE m() AS BEGIN USE f({s}1); END;", .{try repeat(arena.allocator(), "1 + ", 100)});
    const large = try c.Syntax.parse(arena.allocator(), chain, &location);
    writer = .fixed(&buffer);
    try std.testing.expectError(error.SourceDepthLimit, c.Format.write(chain, large, &writer));
}
test "source byte and structural nesting bounds remain finite" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var offset: usize = 0;
    const text = try a.alloc(u8, 1024 * 1024 + 1);
    @memset(text, ' ');
    _ = try c.Syntax.parse(a, text[0 .. 1024 * 1024], &offset);
    try std.testing.expectError(error.StatementTooLarge, c.Syntax.parse(a, text, &offset));
    const deep = try std.fmt.allocPrint(a, "CREATE MODULE m() AS BEGIN INSERT INTO t VALUES ({s}1{s}); END;", .{ try repeat(a, "LIST(", 65), try repeat(a, ")", 65) });
    try std.testing.expectError(error.SqlNestingTooDeep, c.Syntax.parse(a, deep, &offset));
}

fn repeat(a: std.mem.Allocator, text: []const u8, n: usize) ![]const u8 {
    const bytes = try a.alloc(u8, text.len * n);
    for (0..n) |i| @memcpy(bytes[i * text.len ..][0..text.len], text);
    return bytes;
}
