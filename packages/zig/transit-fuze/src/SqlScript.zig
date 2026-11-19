//! Bounded and streaming source-file framing. Preserves compound declarations as
//! one installation step; the statement owner still validates every instruction.
const std = @import("std");
const input = @import("SqlInput.zig");
pub const max_source_bytes = input.max_script_bytes;
pub const max_depth = 64;
pub const Token = input.ScriptScan.Token;
pub const Statement = struct {
    start: u32,
    end: u32,
    first: [3]?Token,
};
pub const StreamStatement = struct {
    start: u64,
    end: u64,
    terminator_end: u64,
    line: u64,
    column: u64,
    terminated: bool = false,
    first: [3]?input.StreamToken = @splat(null),
};
const Block = enum { body, conditional, expression, loop, match };
const Pending = enum { none, begin, case_word };
const Step = union(enum) {
    more,
    incomplete,
    statement: StreamStatement,
};
const Self = @This();
scan: input.ScriptScan,

/// Allocation-free incremental SQL statement framer over arbitrary byte chunks.
pub const StreamFramer = struct {
    lexer: input.StreamLexer = .{},
    current: ?StreamStatement = null,
    count: usize = 0,
    parentheses: usize = 0,
    blocks: [max_depth]Block = undefined,
    depth: usize = 0,
    compound: bool = false,
    body: bool = false,
    after_as: bool = false,
    instruction_start: bool = false,
    suffix: ?Block = null,
    create_header: bool = false,
    explain_header: bool = false,
    test_header: bool = false,
    pending: Pending = .none,

    pub fn hasStatement(self: StreamFramer) bool {
        return self.current != null;
    }

    pub fn resetStatement(self: *StreamFramer) void {
        self.current = null;
        self.count = 0;
        self.parentheses = 0;
        self.depth = 0;
        self.compound = false;
        self.body = false;
        self.after_as = false;
        self.instruction_start = false;
        self.suffix = null;
        self.create_header = false;
        self.explain_header = false;
        self.test_header = false;
        self.pending = .none;
    }

    fn pushBlock(self: *StreamFramer, kind: Block) error{SqlNestingTooDeep}!void {
        if (self.depth == self.blocks.len) return error.SqlNestingTooDeep;
        self.blocks[self.depth] = kind;
        self.depth += 1;
        self.instruction_start = kind == .body;
    }

    pub fn feedToken(self: *StreamFramer, token: input.StreamToken, comptime editing: bool) !Step {
        if (!token.closed and (token.kind == .string or token.kind == .quoted or
            (token.kind == .comment and token.first_byte == '/')))
        {
            if (editing) {
                self.resetStatement();
                return .incomplete;
            }
            return error.UnterminatedSqlToken;
        }
        if (token.kind == .space or token.kind == .comment) return .more;

        const symbol = token.kind == .symbol;
        const byte = token.first_byte;
        if (self.current == null) {
            if (symbol and byte == ';') {
                if (editing) return .{ .statement = .{
                    .start = token.start,
                    .end = token.end,
                    .terminator_end = token.end,
                    .line = token.line,
                    .column = token.column,
                    .terminated = true,
                } };
                return .more;
            }
            self.current = .{
                .start = token.start,
                .end = token.end,
                .terminator_end = token.end,
                .line = token.line,
                .column = token.column,
            };
        }
        if (self.count < 3) self.current.?.first[self.count] = token;
        self.count += 1;

        if (self.pending != .none) {
            const previous = self.pending;
            self.pending = .none;
            if (previous == .begin and token.isWord("ATOMIC")) {
                try self.pushBlock(.body);
            } else if (previous == .case_word and token.isWord("WHEN")) {
                try self.pushBlock(.expression);
            }
        }

        if (self.count == 1) {
            self.create_header = token.isWord("CREATE");
            self.explain_header = token.isWord("EXPLAIN");
            self.compound = token.isWord("TEST");
        }
        if (self.count == 2 and self.explain_header) self.create_header = token.isWord("CREATE");
        if (self.create_header and self.count <= (if (self.explain_header) @as(usize, 6) else 5)) {
            inline for (.{ "DATAFLOW", "PROCEDURE", "FUNCTION", "GUARD", "MODULE", "TARGET" }) |kind| {
                if (token.isWord(kind)) self.compound = true;
            }
        }
        // A finite query or guard expression list owns its contextual words.
        // Once AS SELECT or AS REQUIRE starts, a later AS begin cannot open a body.
        if (self.compound and !self.body and self.after_as and (token.isWord("SELECT") or token.isWord("REQUIRE"))) self.compound = false;
        if (self.body and self.instruction_start and token.isWord("TEST")) self.test_header = true;
        const opens_body = self.compound and (!self.body or self.test_header) and self.after_as and token.isWord("BEGIN");
        if (opens_body) {
            self.body = true;
            self.test_header = false;
        }
        self.after_as = token.isWord("AS");

        if (self.suffix) |kind| {
            self.suffix = null;
            const expected = switch (kind) {
                .conditional => "IF",
                .loop => "FOR",
                .match => "MATCH",
                .expression => "CASE",
                .body => unreachable,
            };
            if (token.isWord(expected)) {
                self.current.?.end = token.end;
                self.current.?.terminator_end = token.end;
                return .more;
            }
            if (editing and token.at_eof and token.isWordPrefixOf(expected)) {
                self.resetStatement();
                return .incomplete;
            }
            if (kind != .expression) return error.UnbalancedSqlBlock;
        }

        if (symbol and byte == '(') {
            if (self.parentheses == max_depth) return error.SqlNestingTooDeep;
            self.parentheses += 1;
        } else if (symbol and byte == ')') {
            if (self.parentheses == 0) return error.UnbalancedSqlParentheses;
            self.parentheses -= 1;
        }

        if (self.body) {
            // These words remain identifiers outside their control positions.
            // BEGIN ATOMIC also starts the first failure-handler instruction;
            // searched CASE owns its expression END, unlike a name such as
            // table.case or a SELECT alias named end.
            if (token.isWord("BEGIN")) {
                if (opens_body or self.instruction_start) {
                    try self.pushBlock(.body);
                } else {
                    self.instruction_start = false;
                    self.pending = .begin;
                }
            } else if (token.isWord("CASE")) {
                self.instruction_start = false;
                self.pending = .case_word;
            } else if (self.instruction_start and token.isWord("IF")) {
                try self.pushBlock(.conditional);
            } else if (self.instruction_start and token.isWord("FOR")) {
                try self.pushBlock(.loop);
            } else if (self.instruction_start and token.isWord("MATCH")) {
                try self.pushBlock(.match);
            } else if (token.isWord("END") and (self.instruction_start or (self.depth > 0 and self.blocks[self.depth - 1] == .expression))) {
                if (self.depth == 0) return error.UnbalancedSqlBlock;
                self.depth -= 1;
                self.suffix = if (self.blocks[self.depth] == .body) null else self.blocks[self.depth];
                self.instruction_start = false;
            } else if (self.depth > 0 and (self.blocks[self.depth - 1] == .conditional or self.blocks[self.depth - 1] == .loop or self.blocks[self.depth - 1] == .match) and
                (token.isWord("THEN") or token.isWord("ELSE") or token.isWord("DO")))
            {
                self.instruction_start = true;
            } else if (!token.isWord("ATOMIC")) {
                self.instruction_start = false;
            }
        }

        if (symbol and byte == ';') {
            if (self.parentheses != 0) return error.UnbalancedSqlParentheses;
            if (self.depth == 0) {
                var finished = self.current.?;
                finished.terminator_end = token.end;
                finished.terminated = true;
                self.resetStatement();
                return .{ .statement = finished };
            }
            self.instruction_start = true;
        }
        self.current.?.end = token.end;
        self.current.?.terminator_end = token.end;
        return .more;
    }

    pub fn finishTokens(self: *StreamFramer, comptime editing: bool) !?StreamStatement {
        defer self.resetStatement();
        if (editing) return null;
        if (self.depth != 0 or (self.suffix != null and self.suffix.? != .expression)) return error.UnbalancedSqlBlock;
        if (self.parentheses != 0) return error.UnbalancedSqlParentheses;
        return self.current;
    }

    pub fn nextInChunk(self: *StreamFramer, chunk: []const u8, index: *usize) !?StreamStatement {
        while (try self.lexer.nextInChunk(chunk, index)) |token| {
            switch (try self.feedToken(token, false)) {
                .more => {},
                .incomplete => unreachable,
                .statement => |stmt| return stmt,
            }
        }
        return null;
    }

    pub fn finish(self: *StreamFramer) !?StreamStatement {
        if (try self.lexer.finish()) |token| {
            switch (try self.feedToken(token, false)) {
                .more => {},
                .incomplete => unreachable,
                .statement => |stmt| return stmt,
            }
        }
        return self.finishTokens(false);
    }
};

pub fn init(text: []const u8) !Self {
    return .{ .scan = try input.ScriptScan.init(text) };
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
/// Editor input may end at any token or block boundary. Return only an explicit
/// outer terminator, using the same compound grammar as source-file framing.
pub fn editorTerminator(text: []const u8) !?u32 {
    var scan = try input.ScriptScan.init(text);
    var framer: StreamFramer = .{};
    while (try scan.next()) |token| {
        switch (try framer.feedToken(toStreamToken(scan.text, scan.position, token), true)) {
            .more => {},
            .incomplete => return null,
            .statement => |stmt| return @intCast(stmt.terminator_end),
        }
    }
    return null;
}

fn toStreamToken(text: []const u8, position: usize, token: anytype) input.StreamToken {
    const slice = text[token.start..token.end];
    var word_buf: [16]u8 = @splat(0);
    const word_len: u5 = if (token.kind == .word) @intCast(@min(slice.len, word_buf.len)) else 0;
    @memcpy(word_buf[0..word_len], slice[0..word_len]);
    return .{
        .kind = token.kind,
        .start = token.start,
        .end = token.end,
        .line = 1,
        .column = 1,
        .first_byte = slice[0],
        .closed = token.closed,
        .at_eof = position == text.len,
        .word_buf = word_buf,
        .word_len = word_len,
    };
}

fn toStatement(stmt: StreamStatement) Statement {
    var first: [3]?Token = @splat(null);
    for (stmt.first, &first) |maybe_tok, *slot| {
        if (maybe_tok) |tok| slot.* = .{
            .kind = tok.kind,
            .start = @intCast(tok.start),
            .end = @intCast(tok.end),
            .closed = tok.closed,
        };
    }
    return .{
        .start = @intCast(stmt.start),
        .end = @intCast(stmt.end),
        .first = first,
    };
}

fn nextFrame(scan: anytype) !?Statement {
    var framer: StreamFramer = .{};
    while (try scan.next()) |token| {
        switch (try framer.feedToken(toStreamToken(scan.text, scan.position, token), false)) {
            .more => {},
            .incomplete => unreachable,
            .statement => |stmt| return toStatement(stmt),
        }
    }
    return if (try framer.finishTokens(false)) |stmt| toStatement(stmt) else null;
}

test "script framing keeps EXPLAIN Queue programs intact" {
    const t = std.testing;
    const statement = "EXPLAIN CREATE DATAFLOW action FROM QUEUE input AS event AS BEGIN BEGIN ATOMIC REQUIRE event.id > 0 ELSE 'Invalid'; END; END";
    const source = statement ++ "; SHOW DATAFLOW action;";
    var scan = try Self.init(source);
    const first = (try scan.next()).?;
    try t.expectEqualStrings(statement, source[first.start..first.end]);
    const second = (try scan.next()).?;
    try t.expectEqualStrings("SHOW DATAFLOW action", source[second.start..second.end]);
    try t.expect(try scan.next() == null);
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

test "migration scripts admit multiple 1 MiB statements while compiler modules cap at 1 MiB" {
    const t = std.testing;
    const text = try t.allocator.alloc(u8, max_source_bytes + 1);
    defer t.allocator.free(text);
    @memset(text, ' ');
    @memcpy(text[70000..70009], "SELECT 1;");
    var compiler_script = try Compiler.init(text[0 .. 1024 * 1024]);
    try t.expectEqual(@as(u32, 70000), (try compiler_script.next()).?.start);
    try t.expectEqual(null, try compiler_script.next());
    try t.expectError(error.StatementTooLarge, Compiler.init(text[0 .. 1024 * 1024 + 1]));
    var migration_script = try init(text[0..max_source_bytes]);
    try t.expectEqual(@as(u32, 70000), (try migration_script.next()).?.start);
    try t.expectEqual(null, try migration_script.next());
    try t.expectError(error.StatementTooLarge, init(text));
}

test "source MATCH framing nests with IF and preserves contextual SQL words" {
    const source = "CREATE MODULE route(value Target) AS BEGIN MATCH value WHEN Target.One(id) THEN IF TRUE THEN SELECT match, when FROM items; END IF; WHEN Target.Two(id) THEN MATCH value WHEN Target.One(x) THEN WHEN Target.Two(y) THEN END MATCH; END MATCH; END; SELECT 7;";
    var script = try Compiler.init(source);
    const first = (try script.next()).?;
    try std.testing.expectEqualStrings(source[0 .. source.len - " SELECT 7;".len - 1], source[first.start..first.end]);
    // The editor shares this framer: nested arm terminators must not submit
    // an incomplete source declaration, including a partial END MATCH suffix.
    for (0..first.end + 1) |end| try std.testing.expectEqual(null, try editorTerminator(source[0..end]));
    try std.testing.expectEqual(first.end + 1, (try editorTerminator(source)).?);
    try std.testing.expectEqualStrings("SELECT 7", blk: {
        const following = (try script.next()).?;
        break :blk source[following.start..following.end];
    });
    try std.testing.expect((try script.next()) == null);
    var invalid = try Compiler.init("CREATE TARGET default AS BEGIN MATCH value WHEN Choice.One() THEN END IF; END;");
    try std.testing.expectError(error.UnbalancedSqlBlock, invalid.next());
}

test "streaming framer matches bounded script framer across arbitrary chunk splits and zero heap allocations" {
    const t = std.testing;
    const memory = @import("transit_memory");
    const source =
        "-- leading comment 🌱\n" ++
        "EXPLAIN CREATE DATAFLOW action FROM QUEUE requests AS request AS BEGIN\n" ++
        "  LET value = 'it''s; END; 🌱';\n" ++
        "  BEGIN ATOMIC\n" ++
        "    IF value IS NOT NULL THEN\n" ++
        "      PUT INTO values KEY 'k' VALUE CASE WHEN TRUE THEN 'END IF;' ELSE NULL END IF ABSENT;\n" ++
        "    ELSE\n" ++
        "      FOR row IN items DO SELECT CASE WHEN TRUE THEN 1 ELSE 2 END CASE; END FOR;\n" ++
        "    END IF;\n" ++
        "  END;\n" ++
        "ON FAILURE failure\n" ++
        "  BEGIN ATOMIC\n" ++
        "    MATCH value WHEN Choice.One(id) THEN SELECT begin AS end, end AS begin FROM case; END MATCH;\n" ++
        "  END;\n" ++
        "END;\n" ++
        "/* inter-statement /* nested */ comment ; */\n" ++
        "CREATE DATAFLOW projection INTO output AS SELECT id AS begin FROM input;\n" ++
        ";;\n" ++
        "ACTIVATE DATAFLOW projection;\n" ++
        "SELECT 'final' -- trailing comment without semicolon";

    var baseline = try Compiler.init(source);
    var expected: [8]Statement = undefined;
    var expected_len: usize = 0;
    while (try baseline.next()) |stmt| {
        expected[expected_len] = stmt;
        expected_len += 1;
    }
    try t.expectEqual(@as(usize, 4), expected_len);

    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var workspace = try memory.Workspace.init(probe.allocator(), 4096);
    defer workspace.deinit();

    // Seal backing allocator: steady-state streaming framing + reusable workspace
    // lease resets must perform zero OS/heap allocations across all chunk splits.
    probe.begin(true);

    for ([_]usize{ 1, 2, 3, 5, 11, 29, source.len }) |step| {
        var framer: StreamFramer = .{};
        var actual_index: usize = 0;
        var offset: usize = 0;
        while (offset < source.len) {
            const chunk = source[offset..@min(source.len, offset + step)];
            var idx: usize = 0;
            while (try framer.nextInChunk(chunk, &idx)) |stmt| {
                const lease = try workspace.acquire();
                defer lease.release(false) catch unreachable;
                const a = try lease.allocator();
                const copy = try a.dupe(u8, source[@intCast(stmt.start)..@intCast(stmt.end)]);
                const want = expected[actual_index];
                try t.expectEqual(@as(u64, want.start), stmt.start);
                try t.expectEqual(@as(u64, want.end), stmt.end);
                try t.expect(stmt.terminated);
                try t.expectEqualStrings(source[want.start..want.end], copy);
                actual_index += 1;
            }
            try t.expectEqual(chunk.len, idx);
            offset += chunk.len;
        }
        if (try framer.finish()) |stmt| {
            const want = expected[actual_index];
            try t.expectEqual(@as(u64, want.start), stmt.start);
            try t.expectEqual(@as(u64, want.end), stmt.end);
            try t.expect(!stmt.terminated);
            actual_index += 1;
        }
        try t.expectEqual(expected_len, actual_index);
    }

    // Stream an unbounded (> 4 MiB) multi-statement input in fixed 256-byte chunks
    // with zero heap allocations.
    var unbounded_framer: StreamFramer = .{};
    const unit = "/* header comment */\nSELECT 1, 'ok;still-string';\n";
    const total_units = 90_000; // > 4.4 MiB total stream
    var emitted: usize = 0;
    var pending_chunk: [256]u8 = undefined;
    var pending_len: usize = 0;
    for (0..total_units) |_| {
        for (unit) |b| {
            pending_chunk[pending_len] = b;
            pending_len += 1;
            if (pending_len == pending_chunk.len) {
                var idx: usize = 0;
                while (try unbounded_framer.nextInChunk(&pending_chunk, &idx)) |stmt| {
                    try t.expect(stmt.terminated);
                    emitted += 1;
                }
                pending_len = 0;
            }
        }
    }
    if (pending_len > 0) {
        var idx: usize = 0;
        while (try unbounded_framer.nextInChunk(pending_chunk[0..pending_len], &idx)) |stmt| {
            try t.expect(stmt.terminated);
            emitted += 1;
        }
    }
    try t.expectEqual(null, try unbounded_framer.finish());
    try t.expectEqual(total_units, emitted);
    try probe.verify();
}
