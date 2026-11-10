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
const Block = enum { body, conditional, expression, loop };
const Self = @This();
scan: input.SourceScan,

pub fn init(text: []const u8) !Self {
    return .{ .scan = try input.SourceScan.init(text) };
}

fn word(text: []const u8, token: anytype, value: []const u8) bool {
    return token.kind == .word and std.ascii.eqlIgnoreCase(text[token.start..token.end], value);
}

fn followingWord(scan: anytype, value: []const u8) !bool {
    var following = scan.*;
    while (try following.next()) |token| {
        if (token.kind == .space or token.kind == .comment) continue;
        return word(following.text, token, value);
    }
    return false;
}

pub const Compiler = struct {
    scan: input.CompilerScan,
    pub fn init(text: []const u8) !Compiler {
        return .{ .scan = try input.CompilerScan.init(text) };
    }
    pub fn next(self: *Compiler) !?Statement {
        return nextFrame(&self.scan);
    }
};
pub fn next(self: *Self) !?Statement {
    return nextFrame(&self.scan);
}
fn nextFrame(scan: anytype) !?Statement {
    const text = scan.text;
    var result: ?Statement = null;
    var count: usize = 0;
    var parentheses: usize = 0;
    var blocks: [max_depth]Block = undefined;
    var depth: usize = 0;
    var compound = false;
    var body = false;
    var after_as = false;
    var instruction_start = false;
    var suffix: ?Block = null;
    var create_header = false;
    var test_header = false;
    while (try scan.next()) |token| {
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
        if (count < 3) result.?.first[count] = .{ .kind = token.kind, .start = token.start, .end = token.end, .closed = token.closed };
        count += 1;
        if (count == 1) {
            create_header = word(text, token, "CREATE");
            compound = word(text, token, "TEST");
        }
        if (create_header and count <= 5) {
            inline for (.{ "DATAFLOW", "PROCEDURE", "FUNCTION", "GUARD", "MODULE", "TARGET" }) |kind|
                if (word(text, token, kind)) {
                    compound = true;
                };
        }
        // A finite query owns its contextual aliases. Once AS SELECT starts
        // that query, a later AS begin cannot open a compound declaration.
        if (compound and !body and after_as and word(text, token, "SELECT")) compound = false;
        if (body and instruction_start and word(text, token, "TEST")) test_header = true;
        const opens_body = compound and (!body or test_header) and after_as and word(text, token, "BEGIN");
        if (opens_body) body = true;
        if (opens_body) test_header = false;
        after_as = word(text, token, "AS");
        if (suffix) |kind| {
            suffix = null;
            const expected = switch (kind) {
                .conditional => "IF",
                .loop => "FOR",
                .expression => "CASE",
                .body => unreachable,
            };
            if (word(text, token, expected)) {
                result.?.end = token.end;
                continue;
            }
            if (kind != .expression) return error.UnbalancedSqlBlock;
        }
        if (symbol and byte == '(') {
            if (parentheses == max_depth) return error.SqlNestingTooDeep;
            parentheses += 1;
        } else if (symbol and byte == ')') {
            if (parentheses == 0) return error.UnbalancedSqlParentheses;
            parentheses -= 1;
        }
        if (body) {
            // These words remain identifiers outside their control positions.
            // BEGIN ATOMIC also starts the first failure-handler instruction;
            // searched CASE owns its expression END, unlike a name such as
            // table.case or a SELECT alias named end.
            const block: ?Block = if (word(text, token, "BEGIN") and (opens_body or instruction_start or try followingWord(scan, "ATOMIC"))) .body else if (word(text, token, "CASE") and try followingWord(scan, "WHEN")) .expression else if (instruction_start and word(text, token, "IF")) .conditional else if (instruction_start and word(text, token, "FOR")) .loop else null;
            if (block) |kind| {
                if (depth == blocks.len) return error.SqlNestingTooDeep;
                blocks[depth] = kind;
                depth += 1;
                instruction_start = kind == .body;
            } else if (word(text, token, "END") and (instruction_start or depth > 0 and blocks[depth - 1] == .expression)) {
                if (depth == 0) return error.UnbalancedSqlBlock;
                depth -= 1;
                suffix = if (blocks[depth] == .body) null else blocks[depth];
                instruction_start = false;
            } else if (depth > 0 and (blocks[depth - 1] == .conditional or blocks[depth - 1] == .loop) and
                (word(text, token, "THEN") or word(text, token, "ELSE") or word(text, token, "DO")))
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
    if (depth != 0 or (suffix != null and suffix.? != .expression)) return error.UnbalancedSqlBlock;
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

test "script framing keeps finite dataflow query aliases contextual" {
    const t = std.testing;
    const query = "SELECT id AS begin FROM input";
    _ = try @import("Sql.zig").parse(query);
    const statement = "CREATE DATAFLOW projection INTO output AS " ++ query;
    const source = statement ++ "; ACTIVATE DATAFLOW projection;";
    inline for (.{ Self, Compiler }) |Framer| {
        var script = try Framer.init(source);
        const first = (try script.next()).?;
        try t.expectEqualStrings(statement, source[first.start..first.end]);
        const second = (try script.next()).?;
        try t.expectEqualStrings("ACTIVATE DATAFLOW projection", source[second.start..second.end]);
        try t.expectEqual(null, try script.next());
    }
}

test "compound framing keeps SQL and source names contextual" {
    const t = std.testing;
    const statement = "CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE case (begin BIGINT, end BIGINT); INSERT INTO case VALUES (1, 2); SELECT begin AS end, end AS begin FROM case; USE begin(1); IF end THEN SELECT begin FROM case; END IF; END";
    const source = statement ++ "; SELECT 1;";
    inline for (.{ Self, Compiler }) |Framer| {
        var script = try Framer.init(source);
        const first = (try script.next()).?;
        try t.expectEqualStrings(statement, source[first.start..first.end]);
        const second = (try script.next()).?;
        try t.expectEqualStrings("SELECT 1", source[second.start..second.end]);
        try t.expectEqual(null, try script.next());
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

test "source framing covers constructors commands procedures tests and FOR suffixes" {
    const t = std.testing;
    inline for (.{ "CREATE PUBLIC MODULE m(x BIGINT)", "CREATE TARGET default", "CREATE PROCEDURE p()", "CREATE FUNCTION fn()", "CREATE DATAFLOW cmd FROM COMMAND (x BIGINT)", "TEST 'nested'" }) |header| {
        const source = header ++ " AS BEGIN IF TRUE THEN FOR row IN items DO SELECT CASE WHEN TRUE THEN 1 ELSE 2 END CASE; END FOR; ELSIF FALSE THEN SELECT 0; ELSE SELECT 3; END IF; ON FAILURE e BEGIN ATOMIC SELECT 4; END; END; SELECT 5;";
        var script = try Compiler.init(source);
        const first = (try script.next()).?;
        try t.expect(std.mem.endsWith(u8, source[first.start..first.end], "END"));
        const second = (try script.next()).?;
        try t.expectEqualStrings("SELECT 5", source[second.start..second.end]);
        try t.expectEqual(null, try script.next());
    }
    var bad = try Compiler.init("CREATE TARGET x AS BEGIN FOR x IN y DO SELECT 1; END IF; END;");
    try t.expectError(error.UnbalancedSqlBlock, bad.next());
}

test "compiler files exceed migration input without widening runtime admission" {
    const t = std.testing;
    const text = try t.allocator.alloc(u8, 1024 * 1024 + 1);
    defer t.allocator.free(text);
    @memset(text, ' ');
    @memcpy(text[70000..70009], "SELECT 1;");
    var script = try Compiler.init(text[0 .. 1024 * 1024]);
    try t.expectEqual(@as(u32, 70000), (try script.next()).?.start);
    try t.expectEqual(null, try script.next());
    try t.expectError(error.StatementTooLarge, Compiler.init(text));
    try t.expectError(error.StatementTooLarge, init(text[0..70010]));
}
