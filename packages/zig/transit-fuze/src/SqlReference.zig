//! Parsed names retain their source positions until an authorized schema binds
//! them. Qualifier/name lookup is separate from syntax and editor classification.
const std = @import("std");
const Parser = @import("SqlTyped.zig");
const sql = @import("Sql.zig");
const Self = @This();
name: []const u8,
span: Parser.Literal.Span,
qualifier: ?[]const u8 = null,
qualifier_span: ?Parser.Literal.Span = null,

pub const Wildcard = struct { qualifier: ?Self = null };
/// Only projection positions admit a wildcard. Leave ordinary references and
/// aggregate arguments to parse; looking ahead neither allocates nor consumes.
pub fn wildcard(parser: *Parser) !?Wildcard {
    if (try parser.take(.star)) return .{};
    if (parser.token.tag != .word and parser.token.tag != .quoted) return null;
    var lookahead = parser.lexer;
    // Let the consuming parser report lexical failures at their actual token.
    // A speculative lexer has a different position from parser.location.
    const dot = lookahead.next() catch return null;
    if (dot.tag != .dot) return null;
    const star = lookahead.next() catch return null;
    if (star.tag != .star) return null;
    const qualifier = try unqualified(parser, .column);
    try parser.require(.dot);
    try parser.require(.star);
    return .{ .qualifier = qualifier };
}

pub fn unqualified(parser: *Parser, role: Parser.NameRole) !Self {
    const start = parser.lexer.start;
    const name = try parser.named(role);
    return .{ .name = name, .span = .{ .start = start, .end = parser.previous_end } };
}
pub fn parse(parser: *Parser) !Self {
    const first = try unqualified(parser, .column);
    if (!try parser.take(.dot)) return first;
    if (parser.boundary()) |editor| editor.qualifier = .init(first.name);
    var column = try unqualified(parser, .column);
    column.qualifier = first.name;
    column.qualifier_span = first.span;
    return column;
}
/// Fields may be logical fields or Table columns; both expose canonical names.
pub fn resolve(self: Self, qualifier: []const u8, fields: anytype, location: ?*sql.Location) !usize {
    if (self.qualifier) |value| if (!std.mem.eql(u8, value, qualifier)) {
        if (location) |at| at.* = .{ .offset = (self.qualifier_span orelse self.span).start };
        return error.UnknownQualifier;
    };
    for (fields, 0..) |field, i| if (std.mem.eql(u8, self.name, field.name)) return i;
    if (location) |at| at.* = .{ .offset = self.span.start };
    return error.UnknownColumn;
}
