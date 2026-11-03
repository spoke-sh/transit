//! Pure preparation of authenticated Stream progress settlement.
const std = @import("std");
const f = @import("root.zig");
const p = @import("transit_protocol");
const Parser = f.SqlTyped;
const Reference = @import("SqlReference.zig");
const Operand = @import("LogReadSql.zig").TypedOperand;

fn header(parser: *Parser) !Reference {
    try parser.requireWord("COMMIT");
    try parser.requireWord("OFFSET");
    try parser.requireWord("ON");
    try parser.requireWord("STREAM");
    return Reference.unqualified(parser, .source);
}
pub fn target(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Reference {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    return header(&parser);
}

pub const Prepared = struct {
    arena: std.heap.ArenaAllocator,
    source: Reference,
    receipt: Operand,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Prepared {
        try f.Sql.validateText(text);
        var arena: std.heap.ArenaAllocator = .init(allocator);
        errdefer arena.deinit();
        var parser = try Parser.initDialect(arena.allocator(), try arena.allocator().dupe(u8, text), location, true, dialect);
        const source = try header(&parser);
        try parser.requireWord("RECEIPT");
        const receipt = try Operand.parse(&parser, .binary);
        if (receipt.value == .parameter and receipt.value.parameter.index != 1) return error.ParameterGap;
        try parser.finish();
        return .{ .arena = arena, .source = source, .receipt = receipt };
    }
    pub fn deinit(self: *Prepared) void {
        self.arena.deinit();
        self.* = undefined;
    }
    pub fn parameterTypes(self: *const Prepared) []const f.Types.Type {
        return if (self.receipt.value == .parameter) &.{.binary} else &.{};
    }
    pub fn bind(self: *const Prepared, allocator: std.mem.Allocator, values: []const ?f.Types.Values.Atom, diagnostic: ?*f.Sql.Binding) !p.StreamHandle.Progress {
        if (values.len != self.parameterTypes().len) return error.ParameterCountMismatch;
        errdefer self.receipt.at(diagnostic);
        return p.StreamHandle.decode(p.StreamHandle.Progress, allocator, (try self.receipt.bind(values, diagnostic)).bytes);
    }
};
