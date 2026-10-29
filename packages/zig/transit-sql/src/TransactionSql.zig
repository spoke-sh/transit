//! Transaction syntax lowers to one typed control shared by every SQL adapter.
const std = @import("std");
const g = @import("root.zig");
const sql = g.fuze.Sql;
const Name = g.catalog.TableAuthority.Name;
pub const Control = union(enum) {
    begin: g.catalog.protocol.Transaction.Mode,
    commit,
    rollback,
    savepoint: Name,
    release_savepoint: Name,
    rollback_to_savepoint: Name,
};
const Word = enum { begin, start, transaction, work, isolation, level, serializable, read, only, write, commit, rollback, to, savepoint, release };
const words = std.StaticStringMapWithEql(Word, std.ascii.eqlIgnoreCase).initComptime(.{
    .{ "BEGIN", .begin },         .{ "START", .start },         .{ "TRANSACTION", .transaction },   .{ "WORK", .work },
    .{ "ISOLATION", .isolation }, .{ "LEVEL", .level },         .{ "SERIALIZABLE", .serializable }, .{ "READ", .read },
    .{ "ONLY", .only },           .{ "WRITE", .write },         .{ "COMMIT", .commit },             .{ "ROLLBACK", .rollback },
    .{ "TO", .to },               .{ "SAVEPOINT", .savepoint }, .{ "RELEASE", .release },
});
const Parser = struct {
    lexer: sql.Lexer,
    token: sql.Token,
    fn advance(self: *Parser) !void {
        self.token = try self.lexer.next();
    }
    fn word(self: Parser) ?Word {
        return if (self.token.tag == .word) words.get(self.token.text) else null;
    }
    fn eat(self: *Parser, value: Word) !bool {
        if (self.word() != value) return false;
        try self.advance();
        return true;
    }
    fn require(self: *Parser, value: Word) !void {
        if (!try self.eat(value)) return error.InvalidSqlSyntax;
    }
    fn name(self: *Parser) !Name {
        const token = self.token;
        if (token.tag != .word and token.tag != .quoted) return error.ExpectedIdentifier;
        if (token.tag == .word and sql.isReserved(token.text)) return error.ExpectedIdentifier;
        var bytes: [@sizeOf(Name) - 1]u8 = undefined;
        const raw = if (token.tag == .quoted) token.text[1 .. token.text.len - 1] else token.text;
        var count: usize = 0;
        var at: usize = 0;
        while (at < raw.len) : (at += 1) {
            if (count == bytes.len) return error.InvalidCatalogName;
            bytes[count] = if (token.tag == .word) std.ascii.toLower(raw[at]) else raw[at];
            count += 1;
            if (token.tag == .quoted and raw[at] == token.text[0] and at + 1 < raw.len and raw[at + 1] == raw[at]) at += 1;
        }
        try self.advance();
        return Name.init(bytes[0..count]);
    }
};
pub fn parse(text: []const u8, dialect: sql.Dialect) !?Control {
    try sql.validateText(text);
    var lexer: sql.Lexer = .{ .text = text, .dialect = dialect };
    var parser: Parser = .{ .token = try lexer.next(), .lexer = undefined };
    parser.lexer = lexer;
    const first = parser.word() orelse return null;
    switch (first) {
        .begin, .start, .commit, .rollback, .savepoint, .release => {},
        else => return null,
    }
    try parser.advance();
    const result: Control = switch (first) {
        .begin, .start => blk: {
            if (first == .start) try parser.require(.transaction) else if (!try parser.eat(.transaction)) _ = try parser.eat(.work);
            var mode: g.catalog.protocol.Transaction.Mode = .serializable;
            var saw_isolation = false;
            var saw_access = false;
            while (parser.token.tag != .eof and parser.token.tag != .semi) {
                if (try parser.eat(.isolation)) {
                    if (saw_isolation) return error.InvalidSqlSyntax;
                    saw_isolation = true;
                    try parser.require(.level);
                    if (!try parser.eat(.serializable)) return error.UnsupportedTransactionIsolation;
                } else if (try parser.eat(.read)) {
                    if (saw_access) return error.InvalidSqlSyntax;
                    saw_access = true;
                    if (try parser.eat(.only)) mode = .read_only else try parser.require(.write);
                } else return error.UnsupportedTransactionStatement;
            }
            break :blk .{ .begin = mode };
        },
        .commit => blk: {
            if (!try parser.eat(.work)) _ = try parser.eat(.transaction);
            break :blk .commit;
        },
        .rollback => blk: {
            if (!try parser.eat(.work)) _ = try parser.eat(.transaction);
            if (try parser.eat(.to)) {
                _ = try parser.eat(.savepoint);
                break :blk .{ .rollback_to_savepoint = try parser.name() };
            }
            break :blk .rollback;
        },
        .savepoint => .{ .savepoint = try parser.name() },
        .release => blk: {
            _ = try parser.eat(.savepoint);
            break :blk .{ .release_savepoint = try parser.name() };
        },
        else => unreachable,
    };
    if (parser.token.tag == .semi) try parser.advance();
    if (parser.token.tag != .eof) return error.UnsupportedTransactionStatement;
    return result;
}
test "SQL transaction controls use one typed grammar and reject unsupported semantics" {
    const t = std.testing;
    try t.expectEqualDeep(Control{ .begin = .serializable }, (try parse("/* cut */ BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE READ WRITE;", .transit)).?);
    try t.expectEqualDeep(Control{ .begin = .read_only }, (try parse("START TRANSACTION READ ONLY", .transit)).?);
    try t.expectEqualDeep(Control{ .savepoint = try Name.init("first") }, (try parse("SAVEPOINT First", .transit)).?);
    try t.expectEqualDeep(Control{ .rollback_to_savepoint = try Name.init("First") }, (try parse("ROLLBACK WORK TO SAVEPOINT \"First\"", .transit)).?);
    try t.expectEqualDeep(Control{ .release_savepoint = try Name.init("first") }, (try parse("RELEASE first; -- done", .mysql)).?);
    try t.expectEqual(Control.commit, (try parse("COMMIT WORK", .mysql)).?);
    try t.expectEqual(Control.rollback, (try parse("ROLLBACK TRANSACTION", .transit)).?);
    try t.expect(try parse("SELECT 'BEGIN'", .transit) == null);
    try t.expectError(error.UnsupportedTransactionIsolation, parse("BEGIN ISOLATION LEVEL READ COMMITTED", .transit));
    for ([_][]const u8{ "COMMIT AND CHAIN", "ROLLBACK AND NO CHAIN", "BEGIN; COMMIT", "START TRANSACTION WITH CONSISTENT SNAPSHOT", "BEGIN DEFERRABLE", "SAVEPOINT x.y" }) |text| try t.expectError(error.UnsupportedTransactionStatement, parse(text, .transit));
    try t.expectError(error.InvalidSqlSyntax, parse("BEGIN READ ONLY READ WRITE", .transit));
    try t.expectError(error.ExpectedIdentifier, parse("SAVEPOINT", .transit));
}
