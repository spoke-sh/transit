const std = @import("std");
const Self = @import("Style.zig");
const fuze = @import("transit_query").fuze;
test "diagnostic colors use original context after redaction and clipping" {
    for ([_][]const u8{
        "SELECT value FROM items " ++ @as([80]u8, @splat(' ')) ++ "WHERE value IS VALUE LIMIT;",
        "SELECT value FROM items " ++ @as([80]u8, @splat(' ')) ++ "WHERE value = '99.123'::FLOAT64 LIMIT;",
    }, [_][]const u8{ "VALUE", "FLOAT64" }) |value, keyword| {
        const diagnostic = fuze.SqlDiagnostic.query(value, error.InvalidSqlSyntax, true).?;
        try std.testing.expect(std.mem.startsWith(u8, diagnostic.context[0..diagnostic.context_len], "..."));
        for (diagnostic.context[0..diagnostic.context_len], diagnostic.context_roles[0..diagnostic.context_len]) |byte, role| {
            if (byte == '*') try std.testing.expectEqual(fuze.Sql.TokenRole.unknown, role);
        }
        var buffer: [4096]u8 = undefined;
        var out: std.Io.Writer = .fixed(&buffer);
        try diagnostic.renderStyled(&out, Self{ .enabled = true });
        var token_buffer: [64]u8 = undefined;
        const colored = try std.fmt.bufPrint(&token_buffer, "\x1b[36m{s}\x1b[0m", .{keyword});
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), colored) != null);
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "\x1b[36mvalue") == null);
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "99.123") == null);
        var plain_buffer: [4096]u8 = undefined;
        var plain: std.Io.Writer = .fixed(&plain_buffer);
        try diagnostic.render(&plain);
        out.end = 0;
        try diagnostic.renderStyled(&out, Self{});
        try std.testing.expectEqualStrings(plain.buffered(), out.buffered());
    }
}
