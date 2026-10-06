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
