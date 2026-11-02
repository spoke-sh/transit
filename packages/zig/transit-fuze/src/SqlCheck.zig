//! Bounded deterministic CHECK syntax. Name binding happens after the complete
//! Table column list is known. No data, parameters, subqueries or effects occur.
const std = @import("std");
const Parser = @import("SqlTyped.zig");
const Reference = @import("SqlReference.zig");
const sql = @import("Sql.zig");
const s = @import("TableSchema.zig");
const c = @import("TableConstraints.zig");

pub const Syntax = struct {
    const Atom = union(enum) {
        compare: struct { left: Reference, op: std.math.CompareOperator, right: union(enum) { column: Reference, literal: Parser.Literal } },
        is_null: Reference,
        is_not_null: Reference,
    };
    name: []const u8,
    validated: bool,
    atoms: []const Atom,

    pub fn bind(self: Syntax, a: std.mem.Allocator, schema: s.Schema, table: []const u8, id: c.ConstraintId, location: ?*sql.Location) !c.CheckConstraint {
        const atoms = try a.alloc(c.CheckAtom, self.atoms.len);
        for (atoms, self.atoms) |*out, input| out.* = switch (input) {
            .is_null => |ref| .{ .is_null = schema.columns[try ref.resolve(table, schema.columns, location)].id },
            .is_not_null => |ref| .{ .is_not_null = schema.columns[try ref.resolve(table, schema.columns, location)].id },
            .compare => |cmp| blk: {
                const left = schema.columns[try cmp.left.resolve(table, schema.columns, location)];
                break :blk switch (cmp.right) {
                    .column => |ref| .{ .compare_columns = .{ .left_column = left.id, .op = cmp.op, .right_column = schema.columns[try ref.resolve(table, schema.columns, location)].id } },
                    .literal => |literal| literal_blk: {
                        var failure: ?Parser.Literal.Span = null;
                        const cell = literal.bind(a, left.type, &failure) catch |err| {
                            if (location) |at| at.* = .{ .offset = (failure orelse literal.span).start };
                            return err;
                        };
                        if (cell != .value or cell.value != .atom) return error.UnsupportedCheckExpression;
                        break :literal_blk .{ .compare_literal = .{ .column = left.id, .op = cmp.op, .literal = cell.value.atom } };
                    },
                };
            },
        };
        const result: c.CheckConstraint = .{ .id = id, .name = self.name, .validated = self.validated, .atoms = atoms };
        try result.validateShape(schema);
        return result;
    }
};

pub fn parse(parser: *Parser, name: []const u8) !Syntax {
    try parser.requireWord("CHECK");
    try parser.require(.left);
    var atoms: std.ArrayList(Syntax.Atom) = .empty;
    while (true) {
        if (atoms.items.len == 32) return error.InvalidCheckConstraint;
        const left = try Reference.parse(parser);
        const atom: Syntax.Atom = if (try parser.takeWord("IS")) blk: {
            const negate = try parser.takeWord("NOT");
            try parser.requireWord("NULL");
            break :blk if (negate) .{ .is_not_null = left } else .{ .is_null = left };
        } else blk: {
            const op: std.math.CompareOperator = switch (parser.token.tag) {
                .eq => .eq,
                .ne => .neq,
                .lt => .lt,
                .le => .lte,
                .gt => .gt,
                .ge => .gte,
                else => return error.UnsupportedCheckExpression,
            };
            try parser.advance();
            const is_column = parser.token.tag == .quoted or (parser.token.tag == .word and !literalWord(parser.*));
            break :blk .{ .compare = .{ .left = left, .op = op, .right = if (is_column) .{ .column = try Reference.parse(parser) } else .{ .literal = try parser.literal(null) } } };
        };
        try atoms.append(parser.allocator, atom);
        if (!try parser.takeWord("AND")) break;
    }
    if (parser.word("OR") or parser.token.tag != .right) return error.UnsupportedCheckExpression;
    try parser.require(.right);
    const not_valid = try parser.takeWord("NOT");
    if (not_valid) try parser.requireWord("VALID");
    return .{ .name = name, .validated = !not_valid, .atoms = try atoms.toOwnedSlice(parser.allocator) };
}
fn literalWord(parser: Parser) bool {
    inline for (.{ "TRUE", "FALSE", "NULL", "DATE", "TIME", "TIMESTAMP", "INTERVAL", "UUID", "X", "JSON" }) |word| if (parser.word(word)) return true;
    return false;
}
