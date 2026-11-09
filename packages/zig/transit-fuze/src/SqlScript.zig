//! Bounded source-file framing. This preserves compound declarations as one
//! installation step; the statement owner still validates every instruction.
const std = @import("std");
const input = @import("SqlInput.zig");
pub const max_source_bytes = input.max_source_bytes;
pub const max_depth = 64;
pub const Token = input.SourceScan.Token;
pub const Statement = struct {
    start: u32,
    end: u32,
    first: [3]?Token,
};
const Block = enum { body, conditional, expression };
const Self = @This();
scan: input.SourceScan,

pub fn init(text: []const u8) !Self {
    return .{ .scan = try input.SourceScan.init(text) };
}

fn word(text: []const u8, token: Token, value: []const u8) bool {
    return token.kind == .word and std.ascii.eqlIgnoreCase(text[token.start..token.end], value);
}

pub fn next(self: *Self) !?Statement {
    const text = self.scan.text;
    var result: ?Statement = null;
    var count: usize = 0;
    var parentheses: usize = 0;
    var blocks: [max_depth]Block = undefined;
    var depth: usize = 0;
    var compound = false;
    var body = false;
    var after_as = false;
    var instruction_start = false;
    var end_if = false;
    while (try self.scan.next()) |token| {
        if (!token.closed and (token.kind == .string or token.kind == .quoted or
            token.kind == .comment and std.mem.startsWith(u8, text[token.start..token.end], "/*")))
            return error.UnterminatedSqlToken;
        if (token.kind == .space or token.kind == .comment) continue;
        const symbol = token.kind == .symbol;
        const byte = text[token.start];
        if (result == null) {
            if (symbol and byte == ';') continue;
            result = .{ .start = token.start, .end = token.end, .first = @splat(null) };
        }
        if (count < 3) result.?.first[count] = token;
        count += 1;
        if (count == 2) compound = word(text, result.?.first[0].?, "CREATE") and word(text, token, "DATAFLOW");
        if (count == 4) compound = compound and word(text, token, "FROM");
        if (count == 5) compound = compound and word(text, token, "QUEUE");
        if (compound and count > 5 and after_as and word(text, token, "BEGIN")) body = true;
        after_as = word(text, token, "AS");
        if (end_if) {
            if (!word(text, token, "IF")) return error.UnbalancedSqlBlock;
            end_if = false;
            result.?.end = token.end;
            continue;
        }
        if (symbol and byte == '(') {
            if (parentheses == max_depth) return error.SqlNestingTooDeep;
            parentheses += 1;
        } else if (symbol and byte == ')') {
            if (parentheses == 0) return error.UnbalancedSqlParentheses;
            parentheses -= 1;
        }
        if (body) {
            const block: ?Block = if (word(text, token, "BEGIN")) .body else if (word(text, token, "CASE")) .expression else if (instruction_start and word(text, token, "IF")) .conditional else null;
            if (block) |kind| {
                if (depth == blocks.len) return error.SqlNestingTooDeep;
                blocks[depth] = kind;
                depth += 1;
                instruction_start = kind == .body;
            } else if (word(text, token, "END")) {
                if (depth == 0) return error.UnbalancedSqlBlock;
                depth -= 1;
                end_if = blocks[depth] == .conditional;
                instruction_start = false;
            } else if (depth > 0 and blocks[depth - 1] == .conditional and
                (word(text, token, "THEN") or word(text, token, "ELSE")))
            {
                instruction_start = true;
            } else if (!word(text, token, "ATOMIC")) instruction_start = false;
        }
        if (symbol and byte == ';') {
            if (parentheses != 0) return error.UnbalancedSqlParentheses;
            if (depth == 0) return result;
            instruction_start = true;
        }
        result.?.end = token.end;
    }
    if (depth != 0 or end_if) return error.UnbalancedSqlBlock;
    if (parentheses != 0) return error.UnbalancedSqlParentheses;
    return result;
}

test "script framing preserves compound blocks and independent step boundaries" {
    const t = std.testing;
    const text =
        \\-- ; BEGIN
        \\CREATE DATAFLOW action FROM QUEUE requests AS request AS BEGIN
        \\  LET value = 'it''s; END';
        \\  BEGIN ATOMIC
        \\    IF value IS NOT NULL THEN
        \\      PUT INTO values KEY 'k' VALUE CASE WHEN TRUE THEN 'END IF;' ELSE NULL END IF ABSENT;
        \\    ELSE
        \\      REQUIRE FALSE ELSE 'Refused';
        \\    END IF;
        \\  END;
        \\ON FAILURE failure
        \\  BEGIN ATOMIC
        \\    REQUIRE FALSE ELSE 'Failed';
        \\  END;
        \\END;
        \\ACTIVATE DATAFLOW action;
        \\SELECT 'last'; -- no final newline required
    ;
    var script = try init(text);
    const first = (try script.next()).?;
    try t.expect(std.mem.startsWith(u8, text[first.start..first.end], "CREATE DATAFLOW"));
    try t.expect(std.mem.endsWith(u8, text[first.start..first.end], "END"));
    const second = (try script.next()).?;
    try t.expectEqualStrings("ACTIVATE DATAFLOW action", text[second.start..second.end]);
    const third = (try script.next()).?;
    try t.expectEqualStrings("SELECT 'last'", text[third.start..third.end]);
    try t.expectEqual(null, try script.next());
}

test "script framing keeps transaction controls separate and rejects incomplete tails" {
    const t = std.testing;
    var script = try init("BEGIN; SELECT 1; COMMIT;");
    var count: usize = 0;
    while (try script.next()) |_| count += 1;
    try t.expectEqual(3, count);
    const invalid = .{
        .{ "SELECT ('x';", error.UnbalancedSqlParentheses },
        .{ "SELECT 'x')", error.UnbalancedSqlParentheses },
        .{ "SELECT 'unfinished", error.UnterminatedSqlToken },
        .{ "SELECT \"unfinished", error.UnterminatedSqlToken },
        .{ "/* unfinished", error.UnterminatedSqlToken },
        .{ "CREATE DATAFLOW x FROM QUEUE q AS BEGIN LET x = 1;", error.UnbalancedSqlBlock },
        .{ "CREATE DATAFLOW x FROM QUEUE q AS BEGIN IF TRUE THEN LET x = 1; END; END", error.UnbalancedSqlBlock },
        .{ "CREATE DATAFLOW x FROM QUEUE q AS BEGIN LET x = CASE WHEN TRUE THEN 1; END", error.UnbalancedSqlBlock },
    };
    inline for (invalid) |entry| {
        var broken = try init(entry[0]);
        try t.expectError(entry[1], broken.next());
    }
}

test "script framing admits bounded files independently of interactive SQL" {
    const t = std.testing;
    const text = try t.allocator.alloc(u8, max_source_bytes + 1);
    defer t.allocator.free(text);
    @memset(text, ' ');
    const statement = "SELECT 1";
    @memcpy(text[max_source_bytes - statement.len .. max_source_bytes], statement);
    var script = try init(text[0..max_source_bytes]);
    const framed = (try script.next()).?;
    try t.expectEqual(max_source_bytes, framed.end);
    try t.expectEqualStrings(statement, text[framed.start..framed.end]);
    try t.expectError(error.StatementTooLarge, init(text));
    try t.expectError(error.StatementTooLarge, input.Scan.init(text[0..max_source_bytes]));
    try t.expectError(error.InvalidSqlEncoding, init("SELECT\x00x"));
    try t.expectError(error.InvalidSqlEncoding, init("SELECT\xff"));
}
